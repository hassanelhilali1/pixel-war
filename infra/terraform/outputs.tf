output "namespace" {
  description = "Namespace Kubernetes créé pour Pixel War"
  value       = kubernetes_namespace.pixel_war.metadata[0].name
}

output "postgresql_service_host" {
  description = "DNS interne du service PostgreSQL (ClusterIP)"
  value       = "postgresql.${var.namespace}.svc.cluster.local"
}

output "db_secret_name" {
  description = "Nom du Secret Kubernetes contenant les identifiants DB"
  value       = kubernetes_secret.db_credentials.metadata[0].name
}

output "app_configmap_name" {
  description = "Nom du ConfigMap applicatif"
  value       = kubernetes_config_map.app_config.metadata[0].name
}

output "postgresql_release_status" {
  description = "Statut du StatefulSet PostgreSQL"
  value       = kubernetes_stateful_set.postgresql.metadata[0].name
}
