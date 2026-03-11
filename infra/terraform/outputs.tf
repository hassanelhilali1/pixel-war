output "namespace" {
  description = "Namespace cree"
  value       = kubernetes_namespace.pixel_war.metadata[0].name
}

output "postgresql_service_host" {
  description = "Adresse du service PostgreSQL"
  value       = "postgresql.${var.namespace}.svc.cluster.local"
}

output "db_secret_name" {
  description = "Nom du secret DB"
  value       = kubernetes_secret.db_credentials.metadata[0].name
}

output "app_configmap_name" {
  description = "Nom du ConfigMap"
  value       = kubernetes_config_map.app_config.metadata[0].name
}

output "postgresql_release_status" {
  description = "Nom du StatefulSet PostgreSQL"
  value       = kubernetes_stateful_set.postgresql.metadata[0].name
}
