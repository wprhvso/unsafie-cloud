from __future__ import annotations

import re
from collections.abc import Callable, Mapping, Sequence
from typing import Any

from ansible.errors import AnsibleFilterError

_LABEL = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")


def _entries(domains: object, where: str) -> list[object]:
    if domains is None:
        return []
    if isinstance(domains, (str, bytes)) or not isinstance(domains, Sequence):
        raise AnsibleFilterError(f"{where}: domains must be a list, got {domains!r}")
    return list(domains)


def _split(entry: object) -> tuple[bool, str]:
    text = str(entry).strip()
    if not text:
        raise AnsibleFilterError("empty domain entry")
    wildcard = text.startswith("*.")
    rest = text[2:] if wildcard else text
    if not rest or rest.startswith(".") or rest.endswith("."):
        raise AnsibleFilterError(f"not a domain entry: {entry!r}")
    for label in rest.split("."):
        if label == "*":
            raise AnsibleFilterError(f"'*' is only allowed as the leftmost label: {entry!r}")
        if not _LABEL.match(label):
            raise AnsibleFilterError(f"not a DNS label: {label!r} in {entry!r}")
    return wildcard, rest


def tenant_dns_names(domains: object, domain: str) -> list[str]:
    names: list[str] = []
    for entry in _entries(domains, "dns names"):
        wildcard, rest = _split(entry)
        names.append(f"*.{rest}.{domain}" if wildcard else f"{rest}.{domain}")
    return names


def tenant_host_grants(domains: object, domain: str) -> dict[str, list[str]]:
    exact: list[str] = []
    suffix: list[str] = []
    for entry in _entries(domains, "host grants"):
        wildcard, rest = _split(entry)
        if wildcard:
            suffix.append(f".{rest}.{domain}")
        else:
            exact.append(f"{rest}.{domain}")
    return {"exact": exact, "suffix": suffix}


def tenant_domain_conflicts(tenants: object, domain: str) -> list[str]:
    if tenants is None:
        return []
    if not isinstance(tenants, Mapping):
        raise AnsibleFilterError(f"tenants must be a mapping, got {tenants!r}")

    owner_of_entry: dict[tuple[str, str], str] = {}
    exact_owner: dict[str, str] = {}
    wildcard_owner: dict[str, str] = {}
    problems: list[str] = []

    for name in sorted(tenants):
        settings: Any = tenants[name] or {}
        if not isinstance(settings, Mapping):
            raise AnsibleFilterError(f"tenant {name!r} must be a mapping, got {settings!r}")
        for entry in _entries(settings.get("domains"), f"tenant {name!r}"):
            wildcard, rest = _split(entry)
            key = ("*", rest) if wildcard else ("", rest)
            owner = owner_of_entry.get(key)
            if owner == name:
                problems.append(f"{name!r} declares {entry!r} twice")
                continue
            if owner is not None:
                problems.append(f"{entry!r} is declared by both {owner!r} and {name!r}")
                continue
            owner_of_entry[key] = name
            if wildcard:
                wildcard_owner[rest] = name
            else:
                exact_owner[rest] = name

    for rest, name in sorted(exact_owner.items()):
        parent = rest.split(".", 1)[1] if "." in rest else None
        if parent and parent in wildcard_owner and wildcard_owner[parent] != name:
            problems.append(
                f"{name!r} claims {rest}.{domain} but {wildcard_owner[parent]!r} "
                f"owns *.{parent}.{domain}, which already covers it"
            )

    return problems


def _declared(tenants: object) -> list[tuple[str, list[object]]]:
    if tenants is None:
        return []
    if not isinstance(tenants, Mapping):
        raise AnsibleFilterError(f"tenants must be a mapping, got {tenants!r}")
    out: list[tuple[str, list[object]]] = []
    for name in sorted(tenants):
        settings: Any = tenants[name] or {}
        if not isinstance(settings, Mapping):
            raise AnsibleFilterError(f"tenant {name!r} must be a mapping, got {settings!r}")
        entries = sorted(str(e).strip() for e in _entries(settings.get("domains"), f"tenant {name!r}"))
        if entries:
            out.append((name, entries))
    return out


def tenant_certificates(tenants: object, domain: str, prefix: str = "tls-") -> list[dict[str, Any]]:
    return [
        {"tenant": name, "secret": f"{prefix}{name}", "dns_names": tenant_dns_names(entries, domain)}
        for name, entries in _declared(tenants)
    ]


def tenant_gateway_listeners(
    tenants: object, domain: str, prefix: str = "tls-"
) -> list[dict[str, str]]:
    listeners: list[dict[str, str]] = []
    for name, entries in _declared(tenants):
        for index, entry in enumerate(entries):
            wildcard, rest = _split(entry)
            listeners.append({
                "name": f"{name}-{index}",
                "tenant": name,
                "secret": f"{prefix}{name}",
                "hostname": f"*.{rest}.{domain}" if wildcard else f"{rest}.{domain}",
            })
    return listeners


class FilterModule:
    def filters(self) -> dict[str, Callable[..., object]]:
        return {
            "tenant_dns_names": tenant_dns_names,
            "tenant_host_grants": tenant_host_grants,
            "tenant_domain_conflicts": tenant_domain_conflicts,
            "tenant_certificates": tenant_certificates,
            "tenant_gateway_listeners": tenant_gateway_listeners,
        }
