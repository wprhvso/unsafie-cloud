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
    uv run pytest tests/ -v

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
