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
