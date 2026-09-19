provider "selectel" {
  username    = var.selectel_username
  password    = var.selectel_password
  domain_name = var.selectel_domain_name
  auth_region = var.selectel_region
  auth_url    = var.selectel_auth_url
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "openstack" {
  user_name           = var.selectel_project_user_name != "" ? var.selectel_project_user_name : var.selectel_username
  password            = var.selectel_project_user_password != "" ? var.selectel_project_user_password : var.selectel_password
  tenant_name         = var.selectel_project_name
  project_domain_name = var.selectel_domain_name
  user_domain_name    = var.selectel_domain_name
  auth_url            = var.selectel_auth_url
  region              = var.selectel_region
}

resource "selectel_vpc_project_v2" "project" {
  count = var.selectel_project_id == "" ? 1 : 0
  name  = var.selectel_project_name
}

locals {
  project_id = var.selectel_project_id != "" ? var.selectel_project_id : (length(selectel_vpc_project_v2.project) > 0 ? selectel_vpc_project_v2.project[0].id : "")
}

resource "random_password" "project_user_password" {
  length  = 24
  special = false
}

resource "selectel_iam_serviceuser_v1" "project_user" {
  name     = var.selectel_project_user_name
  password = var.selectel_project_user_password != "" ? var.selectel_project_user_password : random_password.project_user_password.result

  role {
    role_name  = "member"
    scope      = "project"
    project_id = local.project_id
  }
}

resource "selectel_iam_s3_credentials_v1" "s3_credentials" {
  user_id    = selectel_iam_serviceuser_v1.project_user.id
  project_id = local.project_id
  name       = "infrastructure-s3-credentials"
}

resource "selectel_craas_registry_v1" "registry" {
  name       = var.container_registry_name
  project_id = local.project_id
}

resource "selectel_craas_token_v2" "cr_token_full_access" {
  is_set         = true
  project_id     = local.project_id
  name           = "ci-full-access"
  mode_rw        = true
  all_registries = false
  registry_ids   = [selectel_craas_registry_v1.registry.id]
  expires_at     = var.container_registry_token_expires_at
}

resource "selectel_craas_token_v2" "cr_token_read_only" {
  is_set         = true
  project_id     = local.project_id
  name           = "app-read-only"
  mode_rw        = false
  all_registries = false
  registry_ids   = [selectel_craas_registry_v1.registry.id]
  expires_at     = var.container_registry_token_expires_at
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

resource "openstack_objectstorage_container_v1" "bucket" {
  region = var.selectel_region
  name   = var.s3_backups_bucket_name
}
