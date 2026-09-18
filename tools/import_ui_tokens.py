#!/usr/bin/env python3
"""Gera src/shared/Config/UiTokens.luau e UiMotion.luau a partir do pacote de UI.

Entradas (cópia versionada do pacote, ver UI_Quintal_em_Guarda_v1/LEIA_ESTA_COPIA.md):
  UI_Quintal_em_Guarda_v1/dados/design_tokens.json
  UI_Quintal_em_Guarda_v1/dados/animacoes.json

Saída determinística: chaves ordenadas e checksum das fontes. Não edite os .luau à mão.
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from luau_emit import emit  # noqa: E402

PKG = os.path.join(ROOT, "UI_Quintal_em_Guarda_v1", "dados")
SRC_TOKENS = os.path.join(PKG, "design_tokens.json")
SRC_MOTION = os.path.join(PKG, "animacoes.json")
OUT_TOKENS = os.path.join(ROOT, "src", "shared", "Config", "UiTokens.luau")
OUT_MOTION = os.path.join(ROOT, "src", "shared", "Config", "UiMotion.luau")

# Camadas de renderização definidas no guia (decisões locais; não substituem a CoreGui).
DISPLAY_ORDER = {"world": 0, "hud": 10, "menu": 20, "modal": 30, "toast": 40}

# Mapeia "Quad Out" -> Enum.EasingStyle.Quad / Enum.EasingDirection.Out
EASING_STYLES = {"quad": "Quad", "back": "Back", "linear": "Linear", "sine": "Sine"}
EASING_DIRECTIONS = {"in": "In", "out": "Out", "inout": "InOut"}


class ValidationError(Exception):
    pass


def sha(path: str) -> str:
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def hex_to_rgb(value: str):
    v = value.lstrip("#")
    if len(v) != 6:
        raise ValidationError(f"cor inválida: {value}")
    return [int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16)]


def parse_easing(text: str):
    parts = text.strip().split()
    style = EASING_STYLES.get(parts[0].lower())
    if not style:
        raise ValidationError(f"easing desconhecido: {text}")
    direction = "Out"
    if len(parts) > 1:
        direction = EASING_DIRECTIONS.get(parts[1].lower().replace("-", ""))
        if not direction:
            raise ValidationError(f"direção de easing desconhecida: {text}")
    return style, direction


def build_tokens(data):
    colors = {}
    for name, value in data["colors"].items():
        colors[name] = hex_to_rgb(value)
    radius = dict(data["radius"])
    text = dict(data["text"])
    for key in ("panel", "button", "pill"):
        if key not in radius:
            raise ValidationError(f"raio ausente: {key}")
    for key in ("caption", "body", "button", "title", "hero"):
        if key not in text:
            raise ValidationError(f"tamanho de texto ausente: {key}")
    touch = int(data["minimumTouchTarget"])
    if touch < 44:
        raise ValidationError("alvo de toque mínimo abaixo de 44 px")
    return {
        "colors": colors,
        "radius": radius,
        "stroke": data["stroke"],
        "spacing": data["spacing"],
        "text": text,
        "touchMinimum": 44,
        "touchTarget": touch,
        "referenceDesktop": data["referenceDesktop"],
        "referenceMobile": data["referenceMobile"],
        "displayOrder": DISPLAY_ORDER,
    }


def build_motion(data):
    out = {}
    for recipe in data:
        style, direction = parse_easing(recipe["easing"])
        duration = recipe["durationMs"] / 1000.0
        if duration < 0:
            raise ValidationError(f"duração negativa em {recipe['id']}")
        out[recipe["id"]] = {
            "duration": duration,
            "style": style,
            "direction": direction,
            "normal": recipe["normal"],
            "reduced": recipe["reduced"],
        }
    for required in ("hover_focus", "press", "panel_enter", "panel_exit", "modal_enter", "toast"):
        if required not in out:
            raise ValidationError(f"receita ausente: {required}")
    return out


def write(path: str, header: str, body: str):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(header + body + "\n")
    print("gerado", os.path.relpath(path, ROOT))


def main():
    tokens = build_tokens(json.load(open(SRC_TOKENS, encoding="utf-8")))
    motion = build_motion(json.load(open(SRC_MOTION, encoding="utf-8")))

    header = (
        "--!strict\n"
        "-- ARQUIVO GERADO por tools/import_ui_tokens.py a partir de\n"
        "-- UI_Quintal_em_Guarda_v1/dados/design_tokens.json (sha256 {})\n"
        "-- Não edite à mão: altere o JSON e rode a ferramenta.\n"
        "-- Cores em RGB 0-255; use UiTokens.color(name) para obter um Color3.\n\n"
        "local UiTokens = "
    ).format(sha(SRC_TOKENS))
    body = emit(tokens) + "\n\n" + (
        "local cache: { [string]: Color3 } = {}\n\n"
        "-- Color3 memoizado a partir do RGB do token.\n"
        "function UiTokens.color(name: string): Color3\n"
        "\tlocal hit = cache[name]\n"
        "\tif hit then\n"
        "\t\treturn hit\n"
        "\tend\n"
        "\tlocal rgb = (UiTokens.colors :: any)[name]\n"
        "\tassert(rgb, `token de cor desconhecido: {name}`)\n"
        "\tlocal made = Color3.fromRGB(rgb[1], rgb[2], rgb[3])\n"
        "\tcache[name] = made\n"
        "\treturn made\n"
        "end\n\n"
        "return UiTokens"
    )
    write(OUT_TOKENS, header, body)

    header = (
        "--!strict\n"
        "-- ARQUIVO GERADO por tools/import_ui_tokens.py a partir de\n"
        "-- UI_Quintal_em_Guarda_v1/dados/animacoes.json (sha256 {})\n"
        "-- Não edite à mão: altere o JSON e rode a ferramenta.\n"
        "-- duration em segundos; style/direction nomeiam Enum.EasingStyle/Enum.EasingDirection.\n"
        "-- normal e reduced descrevem o efeito esperado (o código lê as duas variantes).\n\n"
        "export type Recipe = {{\n"
        "\tduration: number,\n"
        "\tstyle: string,\n"
        "\tdirection: string,\n"
        "\tnormal: string,\n"
        "\treduced: string,\n"
        "}}\n\n"
        "local UiMotion: {{ [string]: Recipe }} = "
    ).format(sha(SRC_MOTION))
    write(OUT_MOTION, header, emit(motion) + "\n\nreturn UiMotion")


if __name__ == "__main__":
    try:
        main()
    except ValidationError as err:
        print("ERRO:", err)
        sys.exit(1)
