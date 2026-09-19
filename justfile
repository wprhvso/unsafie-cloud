set dotenv-load := true
export ANSIBLE_CONFIG := "ansible/ansible.cfg"

default:
    @just --list

sync:
    uv sync --all-packages

lint:
    uv run ruff check .

format:
    uv run ruff format .

fix:
    uv run ruff check --fix .
    uv run ruff format .

typecheck:
    uv run pyright

test:
    python3 tests/test_quantity.py
    python3 tests/test_domains.py
    uv run pytest tests/test_db_schema.py tests/test_api_endpoints.py

dev-api:
    uv run --package infra-api uvicorn infra_api.main:app --reload --port 8000

db-migrate:
    uv run --package infra-db alembic upgrade head

ansible-check:
    ansible-playbook -i ansible/hosts.ini ansible/site.yml --syntax-check

awg-mesh:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/awg_mesh.yml

bootstrap:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/bootstrap.yml

db-deploy:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/databases.yml

db-only db:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/databases.yml --tags {{ db }}

db-status:
    ansible all -i ansible/hosts.ini -m shell -a "systemctl is-active postgresql@17-main valkey-server mongod clickhouse-server redpanda rabbitmq-server qdrant meilisearch nats pocketbase"

k3s-init:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/k3s_cluster.yml

tenants-sync:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/tenants.yml

obs-deploy:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/observability.yml

backup-wal:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/backups.yml
