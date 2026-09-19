import secrets


class DatabaseProvisioner:
    DEFAULT_PORTS = {
        "postgres": 5432,
        "valkey": 6379,
        "mongo": 27017,
        "clickhouse": 8123,
        "redpanda": 9092,
        "rabbitmq": 5672,
        "nats": 4222,
        "meilisearch": 7700,
        "qdrant": 6333,
        "pocketbase": 8090,
    }

    @staticmethod
    def generate_credentials(
        db_type: str, db_name: str, username: str, host: str = "10.42.0.1"
    ) -> tuple[str, str, int, str]:
        port = DatabaseProvisioner.DEFAULT_PORTS.get(db_type, 5432)
        password = secrets.token_urlsafe(18)

        if db_type == "postgres":
            url = f"postgresql://{username}:{password}@{host}:{port}/{db_name}"
        elif db_type == "valkey":
            url = f"redis://:{password}@{host}:{port}/0"
        elif db_type == "mongo":
            url = f"mongodb://{username}:{password}@{host}:{port}/{db_name}?authSource={db_name}"
        elif db_type == "clickhouse":
            url = f"clickhouse://{username}:{password}@{host}:{port}/{db_name}"
        else:
            url = f"{db_type}://{username}:{password}@{host}:{port}/{db_name}"

        return username, password, port, url


db_provisioner = DatabaseProvisioner()
