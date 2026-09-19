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
