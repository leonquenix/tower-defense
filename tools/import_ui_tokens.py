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

# Variações de apoio derivadas da paleta funcional (sombras de botão, fundos de estado, caminhos
# dos três mapas). Não estão em design_tokens.json porque são decisões de implementação, mas ficam
# aqui para que a checagem de contraste em tests/specs/07_ui_tokens.spec.luau enxergue todas.
DERIVED = {
    "creamDark": "#F1E2BE",
    "tealDark": "#18705F",  # escurecido de #1F8C7A: títulos de seção são texto normal (4,5:1)
    "goldDark": "#D9A53E",  # só preenchimento (marca de pressionado, barras): não é cor de texto
    "goldText": "#8A5E12",  # âmbar de texto: 5,46:1 sobre paper, 4,48:1 sobre sage
    "dangerSoft": "#FCE6E2",  # clareado de #FBE0DC para chegar a 4,65:1 com danger (guia: 4,5:1)
    "sageDeep": "#CBDDC6",
    "white": "#FFFFFF",
    "backdrop": "#14202F",
    "sand": "#FFE1A0",
    "sandDark": "#CEAC71",
    "tape": "#F7EAC9",
    "tapeDark": "#C6BBA7",
    "night": "#DAD4ED",
    "nightDark": "#9F9CB2",
    # Revamp 2026-09-18 — cenário ilustrado em volta do tabuleiro e profundidade dos painéis.
    # Nenhuma delas é cor de texto: só preenchimento, gradiente, sombra e halo.
    "forest": "#0F2A1E",  # folhagem mais escura da moldura
    "forestMid": "#1B4630",  # folhagem média
    "leaf": "#2F7A4F",  # folha iluminada
    "leafLight": "#5FA86A",  # folha ao sol
    "skyHigh": "#1B3A52",  # topo do gradiente atrás do tabuleiro
    "glowWarm": "#FFE9A8",  # brilho quente (halo, lustro, faísca)
    "inkDeep": "#0D1626",  # sombra projetada e fundo de vinheta
}

# Pares texto/fundo que precisam passar em contraste. "large" segue o mínimo 3:1 do guia;
# o restante usa 4,5:1. A ferramenta falha quando um par cai abaixo do mínimo.
CONTRAST_PAIRS = [
    ("ink", "paper", 4.5),
    ("ink", "cream", 4.5),
    ("ink", "gold", 4.5),
    ("ink", "sage", 4.5),
    ("ink", "cyan", 4.5),
    ("ink", "creamDark", 4.5),
    ("ink", "sageDeep", 4.5),
    ("muted", "paper", 4.5),
    ("muted", "cream", 4.5),
    ("muted", "sage", 4.5),
    ("danger", "dangerSoft", 4.5),
    ("danger", "paper", 4.5),
    ("cream", "ink", 4.5),
    ("tealDark", "paper", 4.5),
    ("goldText", "paper", 4.5),
    ("goldText", "cream", 4.5),
    ("tealDark", "sage", 4.5),
]


def luminance(rgb):
    channels = []
    for value in rgb:
        c = value / 255.0
        channels.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    lighter, darker = max(la, lb), min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)

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
    for name, value in DERIVED.items():
        if name in colors:
            raise ValidationError(f"cor derivada colide com token: {name}")
        colors[name] = hex_to_rgb(value)
    touch = int(data["minimumTouchTarget"])
    if touch < 44:
        raise ValidationError("alvo de toque mínimo abaixo de 44 px")
    pairs = []
    for fg, bg, minimum in CONTRAST_PAIRS:
        ratio = contrast(colors[fg], colors[bg])
        if ratio < minimum:
            raise ValidationError(
                f"contraste insuficiente: {fg} sobre {bg} = {ratio:.2f}:1 (mínimo {minimum}:1)"
            )
        pairs.append({"text": fg, "background": bg, "minimum": minimum, "ratio": round(ratio, 2)})
    return {
        "colors": colors,
        "contrastPairs": pairs,
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
