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

dev-web:
    cd web && npm run dev

build-web:
    cd web && npm run build

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

backup-setup:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/backups.yml --tags common

backup-all:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/backups.yml

restore-pg host="mesh[0]" target="LATEST":
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/restores/restore_postgres.yml -e "target_host={{ host }} target={{ target }}"

restore-ch host="all" backup="":
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/restores/restore_clickhouse.yml -e "target_host={{ host }} backup_name={{ backup }}"

restore-mongo host="all" key="":
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/restores/restore_mongo.yml -e "target_host={{ host }} s3_archive_key={{ key }}"

restore-platform-db host="mesh[0]" key="":
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/restores/restore_platform_db.yml -e "target_host={{ host }} s3_archive_key={{ key }}"

restore-valkey host="all" key="":
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/restores/restore_valkey.yml -e "target_host={{ host }} s3_archive_key={{ key }}"

restore-redpanda host="all" key="":
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/restores/restore_redpanda.yml -e "target_host={{ host }} s3_archive_key={{ key }}"

restore-rabbitmq host="all" key="":
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/restores/restore_rabbitmq.yml -e "target_host={{ host }} s3_archive_key={{ key }}"

restore-nats host="all" key="":
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/restores/restore_nats.yml -e "target_host={{ host }} s3_archive_key={{ key }}"
