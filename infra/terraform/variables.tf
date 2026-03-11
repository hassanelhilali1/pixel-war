variable "namespace" {
  description = "Namespace Kubernetes"
  type        = string
  default     = "pixel-war"
}

variable "environment" {
  description = "Environnement (staging ou production)"
  type        = string
  default     = "production"
}

variable "db_user" {
  description = "User PostgreSQL"
  type        = string
  default     = "pixelwar"
}

variable "db_password" {
  description = "Mot de passe PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nom de la base de donnees"
  type        = string
  default     = "pixelwar"
}

variable "grid_size" {
  description = "Taille de la grille (NxN)"
  type        = number
  default     = 50
}

variable "log_level" {
  description = "Niveau de log (debug, info, warn, error)"
  type        = string
  default     = "info"
}

variable "postgresql_chart_version" {
  description = "Version du chart PostgreSQL"
  type        = string
  default     = "13.2.24"
}


