#!/usr/bin/env python3
"""Gera src/shared/Config/Brand.luau a partir de assets/export/brand_assets.json.

Arte de marca (logotipo, fundo das telas) não passa pelo pipeline de sprites: não tem âncora,
não tem estado e não é recortada. Mesmo assim o id nunca é escrito à mão no Luau — sem entrada
no JSON, a chave sai como nil e a tela usa o desenho de reserva.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from luau_emit import emit  # noqa: E402

SRC = os.path.join(ROOT, "assets", "export", "brand_assets.json")
OUT = os.path.join(ROOT, "src", "shared", "Config", "Brand.luau")


def main():
    data = json.load(open(SRC, encoding="utf-8"))["assets"]
    entries = {}
    for key in sorted(data):
        entry = data[key]
        entries[key] = {
            "image": entry.get("image"),
            "width": entry["width"],
            "height": entry["height"],
            "aspect": round(entry["width"] / entry["height"], 4),
        }
    body = (
        "--!strict\n"
        "-- ARQUIVO GERADO por tools/import_brand_assets.py a partir de assets/export/brand_assets.json.\n"
        "-- Arte de marca: logotipo e fundo das telas de menu. image == nil quando ainda não foi\n"
        "-- publicado; nesse caso a tela desenha o próprio título e o cenário de reserva.\n\n"
        "export type BrandAsset = {\n\timage: string?,\n\twidth: number,\n\theight: number,\n\taspect: number,\n}\n\n"
        "local Brand: { [string]: BrandAsset } = " + emit(entries, 0) + "\n\nreturn Brand\n"
    )
    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write(body)
    print("gerado " + os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
