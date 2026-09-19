output "r2_backups_bucket_name" {
  value = length(cloudflare_r2_bucket.backups) > 0 ? cloudflare_r2_bucket.backups[0].name : ""
}

output "r2_media_bucket_name" {
  value = length(cloudflare_r2_bucket.media) > 0 ? cloudflare_r2_bucket.media[0].name : ""
}

output "r2_endpoint" {
  value = var.cloudflare_account_id != "" ? "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com" : ""
}

output "dedicated_server_ips" {
  value = var.dedicated_server_ips
}
