SHELL := $(shell command -v bash)
.SHELLFLAGS := -eu -o pipefail -c

all: apply

.PHONY: qa_full
qa_full: validate tflint security

.PHONY: init
init:
	terraform init $(ARGS)

.PHONY: init_no_backend
init_no_backend:
	terraform init -backend=false $(ARGS)

.PHONY: fmt
fmt:
	terraform fmt -recursive $(ARGS)

.PHONY: fmt_check
fmt_check:
	terraform fmt -recursive -check -diff $(ARGS)

.PHONY: validate
validate: fmt_check init_no_backend
	terraform validate $(ARGS)

.PHONY: tflint
tflint:
	tflint --init --config="$(CURDIR)/.tflint.hcl"
	tflint --config="$(CURDIR)/.tflint.hcl" $(ARGS)

.PHONY: security
security:
	trivy config --exit-code 1 . $(ARGS)

.PHONY: plan
plan: init
	terraform plan $(ARGS)

.PHONY: apply
apply: init
	terraform apply $(ARGS)

.PHONY: apply_f
apply_f: init
	terraform apply -auto-approve $(ARGS)

.PHONY: destroy
destroy: init
	terraform destroy $(ARGS)

.PHONY: destroy_f
destroy_f: init
	terraform destroy -auto-approve $(ARGS)

.PHONY: output
output:
	terraform output $(ARGS)

.PHONY: output_json
output_json:
	terraform output --json $(ARGS)
