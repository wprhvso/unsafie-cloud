# Terraform Module

Provisions cloud resources in Selectel and Cloudflare:
- Selectel project and service user credentials
- Selectel Container Registry with read and full access tokens
- Selectel S3 container for database backups
- Cloudflare R2 object storage buckets for media and backups
- Cloudflare DNS records for root domain, subdomains and mail service

## Usage

1. Copy variables:
```shell
cp terraform.tfvars.example terraform.tfvars
```

2. Apply:
```shell
make apply
```

## QA

```shell
make qa_full
```
