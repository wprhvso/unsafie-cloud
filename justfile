set dotenv-load := true

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
