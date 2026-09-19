variable "selectel_username" {
  type      = string
  default   = ""
  sensitive = true
}

variable "selectel_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "selectel_domain_name" {
  type      = string
  default   = ""
  sensitive = true
}

variable "selectel_auth_url" {
  type    = string
  default = "https://cloud.api.selcloud.ru/identity/v3"
}

variable "selectel_region" {
  type    = string
  default = "ru-7"
}

variable "selectel_project_name" {
  type    = string
  default = "infra_project"
}

variable "selectel_project_id" {
  type    = string
  default = ""
}

variable "selectel_project_user_name" {
  type    = string
  default = "infra_service_user"
}

variable "selectel_project_user_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "cloudflare_api_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "cloudflare_account_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "cloudflare_zone_id" {
  type    = string
  default = ""
}

variable "base_domain" {
  type    = string
  default = ""
}

variable "dns_ttl" {
  type    = number
  default = 300
}

variable "dedicated_server_ips" {
  type    = map(string)
  default = {}
}

variable "dns_extra_records" {
  type = list(object({
    name     = string
    type     = string
    content  = string
    ttl      = optional(number)
    priority = optional(number)
  }))
  default = []
}

variable "s3_backups_bucket_name" {
  type    = string
  default = "infra-backups"
}

variable "r2_backups_bucket_name" {
  type    = string
  default = "infra-r2-backups"
}

variable "r2_media_bucket_name" {
  type    = string
  default = "infra-r2-media"
}

variable "r2_bucket_location" {
  type    = string
  default = "EEUR"
}

variable "container_registry_name" {
  type    = string
  default = "infra-cr"
}

variable "container_registry_token_expires_at" {
  type    = string
  default = "2029-01-01T00:00:00Z"
}

variable "s3_backup_retention_days" {
  type    = number
  default = 14
}

variable "s3_backup_cold_days" {
  type    = number
  default = 60
}

variable "s3_backup_archive_days" {
  type    = number
  default = 365
}
