#!/usr/bin/env python3
"""Exporta os 24 ícones funcionais da UI e gera src/shared/Config/UiIcons.luau.

Fonte: UI_Quintal_em_Guarda_v1/icones/*.png (128x128, fundo transparente, preservados intactos).
Saída: assets/export/ui/<chave>_128.png + ui_asset_registry.json + Config/UiIcons.luau.

robloxAssetId permanece null até upload real registrado em assets/export/ui_upload_log.json
(mesmo formato do upload_log.json principal: {"uploads": {"ui/ui_back_128.png": 123456}}).
Nenhum ID é inventado: sem log, o módulo gerado traz image = nil e o cliente usa o glifo de reserva.

Uso: python3 tools/export_ui_icons.py
"""
import hashlib
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from luau_emit import emit  # noqa: E402

SRC_DIR = os.path.join(ROOT, "UI_Quintal_em_Guarda_v1", "icones")
OUT_DIR = os.path.join(ROOT, "assets", "export", "ui")
REGISTRY = os.path.join(ROOT, "ui_asset_registry.json")
UPLOAD_LOG = os.path.join(ROOT, "assets", "export", "ui_upload_log.json")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "Config", "UiIcons.luau")

SIZE = 128

# Glifo de reserva enquanto o ícone não estiver publicado, e a chave de rótulo acessível.
# Um ícone nunca é a única explicação: o rótulo textual acompanha a ação (guia, prancha 49).
ICONS = {
    "back": ("‹", "icon.back"),
    "base": ("⌂", "icon.base"),
    "buttons": ("◉", "icon.buttons"),
    "check": ("✓", "icon.check"),
    "close": ("✕", "icon.close"),
    "cooldown": ("◷", "icon.cooldown"),
    "energy": ("◈", "icon.energy"),
    "error": ("!", "icon.error"),
    "group": ("◍", "icon.group"),
    "heal": ("+", "icon.heal"),
    "lock": ("🔒", "icon.lock"),
    "minus": ("−", "icon.minus"),
    "physical": ("⛨", "icon.physical"),
    "play": ("▶", "icon.play"),
    "plus": ("+", "icon.plus"),
    "pulse": ("✷", "icon.pulse"),
    "scrap": ("✦", "icon.scrap"),
    "sell": ("⌫", "icon.sell"),
    "settings": ("⚙", "icon.settings"),
    "speed": ("»", "icon.speed"),
    "target": ("◎", "icon.target"),
    "upgrade": ("▲", "icon.upgrade"),
    "volume": ("🔊", "icon.volume"),
    "wave": ("〜", "icon.wave"),
}


class ValidationError(Exception):
    pass


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    if not os.path.isdir(SRC_DIR):
        raise ValidationError(f"pasta de ícones ausente: {SRC_DIR}")
    os.makedirs(OUT_DIR, exist_ok=True)
    uploads = {}
    if os.path.exists(UPLOAD_LOG):
        uploads = json.load(open(UPLOAD_LOG, encoding="utf-8")).get("uploads", {})

    assets = []
    luau = {}
    pending = []
    for name in sorted(ICONS):
        source = os.path.join(SRC_DIR, f"ui_{name}_v001.png")
        if not os.path.exists(source):
            raise ValidationError(f"ícone ausente no pacote: {os.path.basename(source)}")
        image = Image.open(source).convert("RGBA")
        if image.size != (SIZE, SIZE):
            raise ValidationError(f"{name}: esperado {SIZE}x{SIZE}, veio {image.size}")
        alpha = image.getchannel("A")
        if alpha.getextrema()[0] != 0:
            raise ValidationError(f"{name}: PNG sem pixels transparentes (fundo não recortado)")
        key = f"ui_{name}"
        export_name = f"{key}_{SIZE}.png"
        export_path = os.path.join(OUT_DIR, export_name)
        image.save(export_path, "PNG", optimize=True)
        upload_key = f"ui/{export_name}"
        asset_id = uploads.get(upload_key)
        glyph, label = ICONS[name]
        assets.append(
            {
                "assetKey": key,
                "sourceFile": f"UI_Quintal_em_Guarda_v1/icones/ui_{name}_v001.png",
                "sourceSha256": sha256(source),
                "exportFile": f"assets/export/ui/{export_name}",
                "exportSha256": sha256(export_path),
                "uploadFile": upload_key,
                "width": SIZE,
                "height": SIZE,
                "robloxAssetId": asset_id,
                "status": "uploaded" if asset_id else "exported_pending_upload",
                "checkedInStudio": False,
                "fallbackGlyph": glyph,
                "labelKey": label,
            }
        )
        luau[key] = {
            "image": f"rbxassetid://{asset_id}" if asset_id else None,
            "glyph": glyph,
            "labelKey": label,
            "size": SIZE,
        }
        if not asset_id:
            pending.append(upload_key)

    registry = {
        "schemaVersion": 1,
        "pathBase": "Tower Defense root",
        "purpose": (
            "Ícones funcionais da UI. Preencha robloxAssetId apenas depois de upload verificado, "
            "registrando em assets/export/ui_upload_log.json e rodando tools/export_ui_icons.py."
        ),
        "assets": assets,
    }
    with open(REGISTRY, "w", encoding="utf-8") as fh:
        json.dump(registry, fh, ensure_ascii=False, indent=2, sort_keys=False)
        fh.write("\n")

    header = (
        "--!strict\n"
        "-- ARQUIVO GERADO por tools/export_ui_icons.py a partir de ui_asset_registry.json.\n"
        "-- image == nil significa ícone ainda não publicado: o cliente desenha o glifo de reserva\n"
        "-- e mantém o rótulo textual, que nunca depende do desenho.\n\n"
        "export type Icon = { image: string?, glyph: string, labelKey: string, size: number }\n\n"
        "local UiIcons: { [string]: Icon } = "
    )
    with open(OUT_LUAU, "w", encoding="utf-8") as fh:
        fh.write(header + emit(luau) + "\n\nreturn UiIcons\n")

    print(f"exportados {len(assets)} ícones para assets/export/ui")
    print("gerado", os.path.relpath(OUT_LUAU, ROOT), "e", os.path.relpath(REGISTRY, ROOT))
    if pending:
        print(f"pendentes de upload: {len(pending)} (robloxAssetId permanece null)")


if __name__ == "__main__":
    try:
        main()
    except ValidationError as err:
        print("ERRO:", err)
        sys.exit(1)
