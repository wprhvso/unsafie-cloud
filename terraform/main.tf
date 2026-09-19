provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_r2_bucket" "backups" {
  count      = var.cloudflare_account_id != "" ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = var.r2_backups_bucket_name
  location   = var.r2_bucket_location
}

resource "cloudflare_r2_bucket" "media" {
  count      = var.cloudflare_account_id != "" ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = var.r2_media_bucket_name
  location   = var.r2_bucket_location
}
