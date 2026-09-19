resource "cloudflare_record" "root_a" {
  for_each = var.cloudflare_zone_id != "" ? var.dedicated_server_ips : {}

  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "A"
  content = each.value
  ttl     = var.dns_ttl
  proxied = false
}

resource "cloudflare_record" "subdomains" {
  for_each = var.cloudflare_zone_id != "" ? toset([
    "api",
    "db-admin",
    "mongo-ui",
    "redis-ui",
    "kafka-ui",
    "rabbitmq-ui",
    "nats-ui",
    "clickhouse-ui",
    "qdrant-ui",
    "s3-ui",
    "pb-ui",
    "kameleo",
    "cdn",
    "*.app"
  ]) : toset([])

  zone_id = var.cloudflare_zone_id
  name    = each.value
  type    = "CNAME"
  content = var.base_domain != "" ? var.base_domain : "@"
  ttl     = var.dns_ttl
  proxied = false
}

resource "cloudflare_record" "mail_a" {
  count   = var.cloudflare_zone_id != "" && contains(keys(var.dedicated_server_ips), "node2") ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "mail"
  type    = "A"
  content = var.dedicated_server_ips["node2"]
  ttl     = var.dns_ttl
  proxied = false
}

resource "cloudflare_record" "mx" {
  count    = var.cloudflare_zone_id != "" && var.base_domain != "" ? 1 : 0
  zone_id  = var.cloudflare_zone_id
  name     = "@"
  type     = "MX"
  content  = "mail.${var.base_domain}"
  priority = 10
  ttl      = var.dns_ttl
  proxied  = false
}

resource "cloudflare_record" "spf" {
  count   = var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "TXT"
  content = "\"v=spf1 mx ~all\""
  ttl     = var.dns_ttl
  proxied = false
}

resource "cloudflare_record" "dmarc" {
  count   = var.cloudflare_zone_id != "" && var.base_domain != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "_dmarc"
  type    = "TXT"
  content = "\"v=DMARC1; p=quarantine; rua=mailto:admin@${var.base_domain}\""
  ttl     = var.dns_ttl
  proxied = false
}

resource "cloudflare_record" "extra" {
  for_each = var.cloudflare_zone_id != "" ? { for r in var.dns_extra_records : "${r.name}_${r.type}" => r } : {}

  zone_id  = var.cloudflare_zone_id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  ttl      = try(each.value.ttl, var.dns_ttl)
  priority = try(each.value.priority, null)
  proxied  = false
}
