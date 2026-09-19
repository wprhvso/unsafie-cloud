import sys

sys.dont_write_bytecode = True

import types  # noqa: E402
from pathlib import Path  # noqa: E402

_errors = types.ModuleType("ansible.errors")


class AnsibleFilterError(Exception):
    pass


_errors.AnsibleFilterError = AnsibleFilterError
sys.modules.setdefault("ansible", types.ModuleType("ansible"))
sys.modules["ansible.errors"] = _errors
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ansible" / "filter_plugins"))

import domains as d  # noqa: E402

DOMAIN = "apps.example.com"
FAILURES = []


def check(name, got, want):
    if got != want:
        FAILURES.append(f"{name}: got {got!r}, want {want!r}")


def check_true(name, cond):
    if not cond:
        FAILURES.append(name)


def check_raises(name, fn, *args):
    try:
        fn(*args)
    except AnsibleFilterError:
        return
    except Exception as exc:
        FAILURES.append(f"{name} raised {type(exc).__name__}, want AnsibleFilterError")
        return
    FAILURES.append(f"{name} should raise")


def conflicts(tenants):
    return d.tenant_domain_conflicts(tenants, DOMAIN)


def test_filters_registered():
    check(
        "filters",
        sorted(d.FilterModule().filters()),
        [
            "tenant_certificates",
            "tenant_dns_names",
            "tenant_domain_conflicts",
            "tenant_gateway_listeners",
            "tenant_host_grants",
        ],
    )


def test_dns_names_append_the_ingress_domain():
    check("exact", d.tenant_dns_names(["volkov"], DOMAIN), ["volkov." + DOMAIN])
    check("wildcard", d.tenant_dns_names(["*.volkov"], DOMAIN), ["*.volkov." + DOMAIN])
    check(
        "several",
        d.tenant_dns_names(["demo", "*.demo", "*.dev.demo"], DOMAIN),
        ["demo." + DOMAIN, "*.demo." + DOMAIN, "*.dev.demo." + DOMAIN],
    )
    check("none", d.tenant_dns_names(None, DOMAIN), [])
    check("empty", d.tenant_dns_names([], DOMAIN), [])


def test_host_grants_split_exact_from_suffix():
    check(
        "split",
        d.tenant_host_grants(["demo", "*.demo"], DOMAIN),
        {"exact": ["demo." + DOMAIN], "suffix": [".demo." + DOMAIN]},
    )
    check("none", d.tenant_host_grants(None, DOMAIN), {"exact": [], "suffix": []})


def test_a_bare_string_is_not_a_list_of_domains():
    check_raises("dns names from str", d.tenant_dns_names, "volkov", DOMAIN)
    check_raises("host grants from str", d.tenant_host_grants, "volkov", DOMAIN)
    check_raises("conflicts from str", conflicts, {"volkov": {"domains": "volkov"}})


def test_bad_entries_are_refused():
    for bad in ("", "  ", ".demo", "demo.", "*", "a.*.b", "Demo", "de_mo", "-demo", "demo-",
                "*.", "a" * 64):
        check_raises(f"entry {bad!r}", d.tenant_dns_names, [bad], DOMAIN)
    check_true("63-label ok", d.tenant_dns_names(["a" * 63], DOMAIN) == ["a" * 63 + "." + DOMAIN])


def test_the_same_name_cannot_go_to_two_tenants():
    check(
        "duplicate exact",
        conflicts({"x": {"domains": ["demo"]}, "y": {"domains": ["demo"]}}),
        ["'demo' is declared by both 'x' and 'y'"],
    )
    check(
        "duplicate wildcard",
        conflicts({"x": {"domains": ["*.demo"]}, "y": {"domains": ["*.demo"]}}),
        ["'*.demo' is declared by both 'x' and 'y'"],
    )


def test_an_exact_name_under_another_wildcard_is_refused():
    got = conflicts({"x": {"domains": ["*.demo"]}, "y": {"domains": ["app.demo"]}})
    check_true(f"exact under wildcard: {got}", len(got) == 1 and "already covers it" in got[0])


def test_a_wildcard_covers_exactly_one_label():
    check_true(
        "*.demo does not cover demo",
        conflicts({"x": {"domains": ["*.demo"]}, "y": {"domains": ["demo"]}}) == [],
    )
    check_true(
        "*.demo does not cover a.b.demo",
        conflicts({"x": {"domains": ["*.demo"]}, "y": {"domains": ["a.b.demo"]}}) == [],
    )
    check_true(
        "*.dev.demo does not clash with *.demo",
        conflicts({"x": {"domains": ["*.demo"]}, "y": {"domains": ["*.dev.demo"]}}) == [],
    )


def test_a_tenant_may_own_both_a_wildcard_and_names_under_it():
    check_true(
        "own wildcard and exact",
        conflicts({"x": {"domains": ["*.demo", "app.demo", "demo"]}}) == [],
    )


def test_a_tenant_repeating_itself_is_named_once():
    check(
        "self duplicate",
        conflicts({"x": {"domains": ["demo", "demo"]}}),
        ["'x' declares 'demo' twice"],
    )


def test_empty_inputs_are_not_conflicts():
    for empty in (None, {}, {"x": None}, {"x": {}}, {"x": {"domains": []}}):
        check_true(f"empty {empty!r}", conflicts(empty) == [])


def test_malformed_tenant_entries_are_refused():
    check_raises("tenants is a list", conflicts, ["x"])
    check_raises("tenant is a string", conflicts, {"x": "oops"})
    check_raises("tenant is a list", conflicts, {"x": ["demo"]})


def test_conflicts_are_reported_for_every_pair():
    got = conflicts({
        "a": {"domains": ["demo", "*.demo"]},
        "b": {"domains": ["demo"]},
        "c": {"domains": ["app.demo"]},
    })
    check_true(f"two problems, got {got}", len(got) == 2)


def test_certificates_cover_every_declared_name():
    got = d.tenant_certificates({"volkov": {"domains": ["volkov", "*.volkov"]}}, DOMAIN)
    check("one tenant one certificate", len(got), 1)
    check("secret name", got[0]["secret"], "tls-volkov")
    check(
        "san list",
        sorted(got[0]["dns_names"]),
        sorted(["volkov." + DOMAIN, "*.volkov." + DOMAIN]),
    )


def test_tenants_without_domains_get_no_certificate():
    got = d.tenant_certificates({"a": {}, "b": None, "c": {"domains": []}}, DOMAIN)
    check("no certificates", got, [])
    check("no listeners", d.tenant_gateway_listeners({"a": {}}, DOMAIN), [])


def test_every_declared_name_becomes_one_listener():
    got = d.tenant_gateway_listeners({"volkov": {"domains": ["volkov", "*.volkov"]}}, DOMAIN)
    check("two listeners", len(got), 2)
    check(
        "hostnames",
        sorted(l["hostname"] for l in got),
        sorted(["volkov." + DOMAIN, "*.volkov." + DOMAIN]),
    )
    check_true("all point at the tenant secret", all(l["secret"] == "tls-volkov" for l in got))


def test_listener_names_are_unique_and_rfc1123():
    tenants = {
        "volkov": {"domains": ["volkov", "*.volkov", "demo", "*.demo", "*.dev.demo"]},
        "petrova": {"domains": ["petrova"]},
        "a" * 30: {"domains": ["x"]},
    }
    names = [l["name"] for l in d.tenant_gateway_listeners(tenants, DOMAIN)]
    check("unique", len(names), len(set(names)))
    for n in names:
        check_true(f"rfc1123 {n}", bool(d._LABEL.match(n)) and len(n) <= 63)


def test_listener_names_survive_reordering_the_file():
    a = d.tenant_gateway_listeners({"v": {"domains": ["b", "a", "c"]}}, DOMAIN)
    b = d.tenant_gateway_listeners({"v": {"domains": ["c", "b", "a"]}}, DOMAIN)
    check("stable under reordering", a, b)


def test_gateway_filters_refuse_the_same_malformed_input():
    check_raises("certificates from list", d.tenant_certificates, ["x"], DOMAIN)
    check_raises("listeners from list", d.tenant_gateway_listeners, ["x"], DOMAIN)
    check_raises("certificates bare string domains", d.tenant_certificates,
                 {"x": {"domains": "volkov"}}, DOMAIN)
    check_raises("listeners bare string domains", d.tenant_gateway_listeners,
                 {"x": {"domains": "volkov"}}, DOMAIN)
    check_raises("listeners bad entry", d.tenant_gateway_listeners,
                 {"x": {"domains": ["Bad"]}}, DOMAIN)


def main():
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
            except Exception as exc:
                FAILURES.append(f"{name} crashed: {type(exc).__name__}: {exc}")
    if FAILURES:
        print(f"FAILED ({len(FAILURES)})")
        for f in FAILURES:
            print("  " + f)
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
