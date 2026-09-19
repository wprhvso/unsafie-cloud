from infra_db import (
    Base,
    DatabaseInstance,
    KvmVm,
    Plan,
    S3Bucket,
    Tenant,
    User,
)


def test_models_metadata_registration():
    expected_tables = {
        "plans",
        "users",
        "tenants",
        "vms",
        "databases_instances",
        "s3_buckets",
        "domains",
        "api_keys",
        "kameleo_leases",
        "audit_logs",
    }
    actual_tables = set(Base.metadata.tables.keys())
    assert expected_tables.issubset(actual_tables)


def test_model_instantiation():
    plan = Plan(name="student-standard", max_vcpus=2, max_ram_mb=4096)
    user = User(
        github_id=12345,
        github_login="student_alex",
        email="alex@example.com",
        role="student",
    )
    tenant = Tenant(
        name="team-alpha",
        kind="ns",
        user_id=1,
    )
    vm = KvmVm(
        name="vm-prod",
        node="node1-aeza",
        user_id=1,
    )
    db = DatabaseInstance(
        db_type="postgres",
        db_name="db_alex",
        db_user="alex",
        password_hash="hash123",
        port=5432,
        user_id=1,
    )
    bucket = S3Bucket(
        bucket_name="alex-media",
        access_key_id="GK123",
        secret_access_key="sec123",
        user_id=1,
    )
    assert plan.name == "student-standard"
    assert user.github_login == "student_alex"
    assert tenant.name == "team-alpha"
    assert vm.node == "node1-aeza"
    assert db.db_type == "postgres"
    assert bucket.bucket_name == "alex-media"
