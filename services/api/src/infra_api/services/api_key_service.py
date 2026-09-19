import hashlib
import secrets


class ApiKeyService:
    @staticmethod
    def generate_api_key() -> tuple[str, str, str]:
        raw_secret = secrets.token_urlsafe(32)
        key_prefix = "live_"
        full_key = f"{key_prefix}{raw_secret}"
        key_hash = hashlib.sha256(full_key.encode("utf-8")).hexdigest()
        return full_key, key_prefix, key_hash

    @staticmethod
    def verify_api_key(full_key: str, stored_hash: str) -> bool:
        calculated_hash = hashlib.sha256(full_key.encode("utf-8")).hexdigest()
        return secrets.compare_digest(calculated_hash, stored_hash)


api_key_service = ApiKeyService()
