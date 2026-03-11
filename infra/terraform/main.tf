terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# ── Providers ─────────────────────────────────────────────────────────────────
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

# ── Namespace ─────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "pixel_war" {
  metadata {
    name = var.namespace

    labels = {
      app        = "pixel-war"
      env        = var.environment
      managed-by = "terraform"
    }

    annotations = {
      description = "ISIMA Pixel War 2026 — Namespace géré par Terraform"
    }
  }
}

# ── Resource Quota ─────────────────────────────────────────────────────────────
resource "kubernetes_resource_quota" "pixel_war" {
  metadata {
    name      = "pixel-war-quota"
    namespace = kubernetes_namespace.pixel_war.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "2"
      "requests.memory" = "2Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "4Gi"
      pods              = "20"
      services          = "10"
    }
  }
}

# ── Limit Range ────────────────────────────────────────────────────────────────
resource "kubernetes_limit_range" "pixel_war" {
  metadata {
    name      = "pixel-war-limits"
    namespace = kubernetes_namespace.pixel_war.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = "200m"
        memory = "256Mi"
      }

      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }

      max = {
        cpu    = "1"
        memory = "1Gi"
      }
    }
  }
}

# ── Secret : identifiants base de données ────────────────────────────────────
resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "db-credentials"
    namespace = kubernetes_namespace.pixel_war.metadata[0].name

    labels = {
      app        = "pixel-war"
      managed-by = "terraform"
    }
  }

  data = {
    POSTGRES_USER     = var.db_user
    POSTGRES_PASSWORD = var.db_password
    POSTGRES_DB       = var.db_name
    # URL complète injectée directement dans le backend
    DATABASE_URL = "postgresql://${var.db_user}:${var.db_password}@postgresql.${var.namespace}.svc.cluster.local:5432/${var.db_name}"
  }

  type = "Opaque"
}

# ── ConfigMap : variables non-sensibles ───────────────────────────────────────
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace.pixel_war.metadata[0].name

    labels = {
      app        = "pixel-war"
      managed-by = "terraform"
    }
  }

  data = {
    DB_HOST   = "postgresql.${var.namespace}.svc.cluster.local"
    DB_PORT   = "5432"
    GRID_SIZE = tostring(var.grid_size)
    LOG_LEVEL = var.log_level
    PORT      = "3000"
  }
}

# ── PostgreSQL — StatefulSet natif (postgres:16-alpine) ──────────────────────
# Déployé directement via Terraform sans chart Bitnami (image locale disponible)
resource "kubernetes_stateful_set" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.pixel_war.metadata[0].name
    labels = {
      app        = "postgresql"
      managed-by = "terraform"
    }
  }

  spec {
    service_name = "postgresql-hl"
    replicas     = 1

    selector {
      match_labels = {
        app = "postgresql"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgresql"
        }
      }

      spec {
        security_context {
          fs_group = 999
        }

        container {
          name              = "postgresql"
          image             = "postgres:16-alpine"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "postgresql"
            container_port = 5432
            protocol       = "TCP"
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          readiness_probe {
            exec {
              command = ["sh", "-c", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 6
          }

          liveness_probe {
            exec {
              command = ["sh", "-c", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"]
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            failure_threshold     = 6
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "standard"
        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.pixel_war]
}

# ── Service ClusterIP PostgreSQL ──────────────────────────────────────────────
resource "kubernetes_service" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.pixel_war.metadata[0].name
    labels = {
      app        = "postgresql"
      managed-by = "terraform"
    }
  }

  spec {
    selector = {
      app = "postgresql"
    }
    port {
      name        = "postgresql"
      port        = 5432
      target_port = "postgresql"
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# ── Service Headless PostgreSQL (StatefulSet) ─────────────────────────────────
resource "kubernetes_service" "postgresql_hl" {
  metadata {
    name      = "postgresql-hl"
    namespace = kubernetes_namespace.pixel_war.metadata[0].name
    labels = {
      app        = "postgresql"
      managed-by = "terraform"
    }
  }

  spec {
    selector = {
      app = "postgresql"
    }
    cluster_ip = "None"
    port {
      name        = "postgresql"
      port        = 5432
      target_port = "postgresql"
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
