"""Emissor determinístico de tabelas Luau a partir de valores Python."""
import re

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
KEYWORDS = {"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while","continue"}


def lstr(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lnum(n) -> str:
    if isinstance(n, bool):
        raise TypeError
    if isinstance(n, int):
        return str(n)
    r = repr(float(n))
    if r.endswith(".0"):
        r = r[:-2]
    return r


def emit(value, indent=0, key_order=None) -> str:
    pad = "\t" * indent
    pad1 = "\t" * (indent + 1)
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return lnum(value)
    if isinstance(value, str):
        return lstr(value)
    if isinstance(value, list):
        if not value:
            return "{}"
        simple = all(isinstance(v, (int, float, str, bool)) and not isinstance(v, bool) for v in value)
        if simple and len(value) <= 12:
            return "{ " + ", ".join(emit(v, indent + 1) for v in value) + " }"
        out = "{\n"
        for v in value:
            out += pad1 + emit(v, indent + 1) + ",\n"
        return out + pad + "}"
    if isinstance(value, dict):
        if not value:
            return "{}"
        keys = list(value.keys())
        if key_order is None:
            keys = sorted(keys)
        out = "{\n"
        for k in keys:
            v = value[k]
            if v is None:
                continue
            ks = k if (IDENT.match(k) and k not in KEYWORDS) else "[" + lstr(k) + "]"
            out += pad1 + ks + " = " + emit(v, indent + 1) + ",\n"
        return out + pad + "}"
    raise TypeError(f"tipo não suportado: {type(value)}")
