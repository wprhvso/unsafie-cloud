from __future__ import annotations

import re
from collections.abc import Callable
from fractions import Fraction

from ansible.errors import AnsibleFilterError

Quantity = str | int | float

_BINARY: dict[str, int] = {
    "Ki": 2**10, "Mi": 2**20, "Gi": 2**30, "Ti": 2**40, "Pi": 2**50, "Ei": 2**60,
}
_DECIMAL: dict[str, Fraction | int] = {"n": Fraction(1, 10**9), "u": Fraction(1, 10**6), "m": Fraction(1, 10**3),
            "": 1, "k": 10**3, "M": 10**6, "G": 10**9, "T": 10**12, "P": 10**15, "E": 10**18}

_RE = re.compile(r"^(?P<num>[+-]?\d+(?:\.\d+)?)(?P<suffix>Ki|Mi|Gi|Ti|Pi|Ei|[numkMGTPE])?$")


_BINARY_LADDER: list[str] = ["Ei", "Pi", "Ti", "Gi", "Mi", "Ki", ""]
_DECIMAL_LADDER: list[str] = ["E", "P", "T", "G", "M", "k", "", "m", "u", "n"]


def _factor(suffix: str) -> Fraction:
    return Fraction(_BINARY.get(suffix) or _DECIMAL[suffix])


def _parse(value: Quantity) -> tuple[Fraction, str]:
    text = str(value).strip()
    match = _RE.match(text)
    if not match:
        raise AnsibleFilterError(f"not a Kubernetes quantity: {value!r}")
    suffix = match.group("suffix") or ""
    return Fraction(match.group("num")) * _factor(suffix), suffix


def _render(total: Fraction, suffix: str, round_up: bool = True) -> str:
    ladder = _BINARY_LADDER if suffix in _BINARY else _DECIMAL_LADDER
    candidates = ladder[ladder.index(suffix):]
    for candidate in candidates:
        scaled = total / _factor(candidate)
        if scaled.denominator == 1:
            return f"{int(scaled)}{candidate}"
        if not round_up and scaled >= 1:
            return f"{scaled.numerator // scaled.denominator}{candidate}"
    scaled = total / _factor(candidates[-1])
    whole = scaled.numerator // scaled.denominator
    rounded = whole + 1 if round_up else whole
    return f"{max(rounded, 1)}{candidates[-1]}"


def k8s_quantity_add(left: Quantity, right: Quantity) -> str:
    left_value, left_suffix = _parse(left)
    right_value, _ = _parse(right)
    return _render(left_value + right_value, left_suffix)


def k8s_quantity_div(value: Quantity, divisor: Quantity) -> str:
    total, suffix = _parse(value)
    parts, _ = _parse(divisor)
    if parts <= 0:
        raise AnsibleFilterError(f"divisor must be positive: {divisor!r}")
    return _render(total / parts, suffix, round_up=False)


def k8s_quantity_valid(value: Quantity) -> bool:
    try:
        parsed, _ = _parse(value)
    except AnsibleFilterError:
        return False
    return parsed > 0


def _reject_unknown(action: str, values: object, others: object) -> None:
    if not isinstance(values, dict) or not isinstance(others, dict):
        raise AnsibleFilterError(f"{action} needs two dicts: {values!r}, {others!r}")
    unknown = sorted(set(others) - set(values))
    if unknown:
        raise AnsibleFilterError(f"{action}: no such key on the left: {unknown}")


def k8s_quantity_clamp(
    values: dict[str, Quantity], ceilings: dict[str, Quantity]
) -> dict[str, Quantity]:
    _reject_unknown("clamp", values, ceilings)
    result: dict[str, Quantity] = {}
    for key, value in values.items():
        ceiling = ceilings.get(key)
        if ceiling is not None and _parse(ceiling)[0] < _parse(value)[0]:
            result[key] = ceiling
        else:
            result[key] = value
    return result


def k8s_quantity_add_dict(
    values: dict[str, Quantity], addends: dict[str, Quantity]
) -> dict[str, Quantity]:
    _reject_unknown("add_dict", values, addends)
    result: dict[str, Quantity] = {}
    for key, value in values.items():
        addend = addends.get(key)
        result[key] = k8s_quantity_add(value, addend) if addend is not None else value
    return result


class FilterModule:
    def filters(self) -> dict[str, Callable[..., object]]:
        return {
            "k8s_quantity_add": k8s_quantity_add,
            "k8s_quantity_add_dict": k8s_quantity_add_dict,
            "k8s_quantity_div": k8s_quantity_div,
            "k8s_quantity_valid": k8s_quantity_valid,
            "k8s_quantity_clamp": k8s_quantity_clamp,
        }
