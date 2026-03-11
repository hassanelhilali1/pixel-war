variable "namespace" {
  description = "Namespace Kubernetes pour l'application Pixel War"
  type        = string
  default     = "pixel-war"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.namespace))
    error_message = "Le namespace ne doit contenir que des lettres minuscules, chiffres et tirets."
  }
}

variable "environment" {
  description = "Environnement de déploiement (staging | production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "L'environnement doit être 'staging' ou 'production'."
  }
}

variable "db_user" {
  description = "Nom d'utilisateur PostgreSQL"
  type        = string
  default     = "pixelwar"
}

variable "db_password" {
  description = "Mot de passe PostgreSQL (sensible)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "Le mot de passe doit contenir au moins 12 caractères."
  }
}

variable "db_name" {
  description = "Nom de la base de données PostgreSQL"
  type        = string
  default     = "pixelwar"
}

variable "grid_size" {
  description = "Taille de la grille (N×N pixels)"
  type        = number
  default     = 50

  validation {
    condition     = var.grid_size >= 10 && var.grid_size <= 500
    error_message = "La taille de la grille doit être entre 10 et 500."
  }
}

variable "log_level" {
  description = "Niveau de log applicatif (debug | info | warn | error)"
  type        = string
  default     = "info"

  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Valeurs acceptées : debug, info, warn, error."
  }
}

variable "postgresql_chart_version" {
  description = "Version du chart Helm Bitnami PostgreSQL (conservé pour compatibilité)"
  type        = string
  default     = "13.2.24"
}




