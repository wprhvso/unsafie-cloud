import sys

sys.dont_write_bytecode = True

import types  # noqa: E402
from fractions import Fraction  # noqa: E402
from pathlib import Path  # noqa: E402

_errors = types.ModuleType("ansible.errors")


class AnsibleFilterError(Exception):
    pass


_errors.AnsibleFilterError = AnsibleFilterError
sys.modules.setdefault("ansible", types.ModuleType("ansible"))
sys.modules["ansible.errors"] = _errors
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ansible" / "filter_plugins"))

import quantity as q  # noqa: E402

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


def test_filters_registered():
    check(
        "filters",
        sorted(q.FilterModule().filters()),
        [
            "k8s_quantity_add",
            "k8s_quantity_add_dict",
            "k8s_quantity_clamp",
            "k8s_quantity_div",
            "k8s_quantity_valid",
        ],
    )


def test_add_renders_in_left_unit():
    check("1+200m", q.k8s_quantity_add("1", "200m"), "1200m")
    check("2Gi+256Mi", q.k8s_quantity_add("2Gi", "256Mi"), "2304Mi")
    check("1Gi+256Mi", q.k8s_quantity_add("1Gi", "256Mi"), "1280Mi")
    check("40Gi+3Gi", q.k8s_quantity_add("40Gi", "3Gi"), "43Gi")
    check("15+2", q.k8s_quantity_add("15", "2"), "17")
    check("int left", q.k8s_quantity_add(5, "2"), "7")


def test_div_truncates_down():
    check("2/15", q.k8s_quantity_div("2", "15"), "133m")
    check("4Gi/15", q.k8s_quantity_div("4Gi", "15"), "273Mi")
    check("40Gi/15", q.k8s_quantity_div("40Gi", "15"), "2Gi")


def test_div_rejects_nonpositive_divisor():
    for bad in ("0", "-1"):
        check_raises(f"div by {bad}", q.k8s_quantity_div, "1", bad)


def test_promised_pods_fit_in_quota():
    for total in ("1", "2", "8", "500m", "1Gi", "4Gi", "32Gi", "40Gi", "100Gi"):
        for pods in ("1", "2", "3", "7", "15", "50", "60"):
            share = q.k8s_quantity_div(total, pods)
            used = q._parse(share)[0] * Fraction(int(pods))
            check_true(
                f"{pods} x div({total},{pods})={share} must fit in {total}",
                used <= q._parse(total)[0],
            )


def test_valid():
    for good in ("2", "500m", "4Gi", "2.5", "1Ki", "+5", "0.5", "  3  "):
        check_true(f"valid({good})", q.k8s_quantity_valid(good))
    for bad in ("0", "-1", "abc", "", "1e3", "4gb", "Gi", "1 Gi"):
        check_true(f"invalid({bad})", not q.k8s_quantity_valid(bad))


def test_clamp_takes_the_lower_bound():
    check("clamp below", q.k8s_quantity_clamp({"cpu": "500m"}, {"cpu": "133m"}), {"cpu": "133m"})
    check("clamp above", q.k8s_quantity_clamp({"cpu": "50m"}, {"cpu": "133m"}), {"cpu": "50m"})
    check("clamp missing ceiling", q.k8s_quantity_clamp({"cpu": "50m"}, {}), {"cpu": "50m"})
    check(
        "clamp mixed units",
        q.k8s_quantity_clamp({"memory": "512Mi"}, {"memory": "1Gi"}),
        {"memory": "512Mi"},
    )


def test_render_never_returns_zero():
    for total in ("1", "1Gi"):
        for pods in ("1000", "1000000", "1000000000000"):
            share = q.k8s_quantity_div(total, pods)
            check_true(f"div({total},{pods})={share} > 0", q.k8s_quantity_valid(share))


def test_add_dict_adds_key_by_key():
    check(
        "add_dict",
        q.k8s_quantity_add_dict(
            {"cpu": "2", "memory": "4Gi", "pods": "15", "storage": "10Gi"},
            {"cpu": "1200m", "memory": "2304Mi", "pods": "2", "storage": "2Gi"},
        ),
        {"cpu": "3200m", "memory": "6400Mi", "pods": "17", "storage": "12Gi"},
    )


def test_add_dict_passes_through_keys_without_addend():
    check(
        "add_dict passthrough",
        q.k8s_quantity_add_dict({"cpu": "2", "pods": "15"}, {"pods": "2"}),
        {"cpu": "2", "pods": "17"},
    )


def test_add_dict_refuses_an_addend_it_cannot_apply():
    check_raises(
        "add_dict unknown key", q.k8s_quantity_add_dict, {"cpu": "1"}, {"cpu": "1", "memory": "1Gi"}
    )


def test_clamp_refuses_a_ceiling_it_cannot_apply():
    check_raises(
        "clamp unknown key", q.k8s_quantity_clamp, {"cpu": "1"}, {"cpu": "1", "memory": "1Gi"}
    )


def test_dict_filters_reject_non_dicts():
    check_raises("add_dict non-dict", q.k8s_quantity_add_dict, "1", {"cpu": "1"})
    check_raises("clamp non-dict", q.k8s_quantity_clamp, {"cpu": "1"}, "1")


def test_vcluster_overhead_leaves_the_granted_size_intact():
    overhead = {"cpu": "1200m", "memory": "2304Mi", "pods": "2", "storage": "2Gi"}
    for cpu, memory, pods, storage in (
        ("2", "4Gi", "15", "10Gi"),
        ("500m", "512Mi", "1", "1Gi"),
        ("8", "32Gi", "60", "100Gi"),
    ):
        granted = {"cpu": cpu, "memory": memory, "pods": pods, "storage": storage}
        effective = q.k8s_quantity_add_dict(granted, overhead)
        for key in granted:
            left = q._parse(effective[key])[0] - q._parse(overhead[key])[0]
            check_true(
                f"{key}: {granted[key]} + overhead - overhead == {granted[key]}",
                left >= q._parse(granted[key])[0],
            )


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
