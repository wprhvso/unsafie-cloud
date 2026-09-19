output "read_only_token" {
  value     = selectel_craas_token_v2.cr_token_read_only.token
  sensitive = true
}

output "full_access_token" {
  value     = selectel_craas_token_v2.cr_token_full_access.token
  sensitive = true
}

output "s3_access_key" {
  value     = selectel_iam_s3_credentials_v1.s3_credentials.access_key
  sensitive = true
}

output "s3_secret_key" {
  value     = selectel_iam_s3_credentials_v1.s3_credentials.secret_key
  sensitive = true
}

output "s3_bucket_name" {
  value = openstack_objectstorage_container_v1.bucket.name
}

output "s3_endpoint" {
  value = "https://s3.${var.selectel_region}.storage.selcloud.ru"
}

output "container_registry_id" {
  value = selectel_craas_registry_v1.registry.id
}

output "r2_backups_bucket_name" {
  value = length(cloudflare_r2_bucket.backups) > 0 ? cloudflare_r2_bucket.backups[0].name : ""
}

output "r2_media_bucket_name" {
  value = length(cloudflare_r2_bucket.media) > 0 ? cloudflare_r2_bucket.media[0].name : ""
}

output "dedicated_server_ips" {
  value = var.dedicated_server_ips
}
