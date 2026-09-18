#!/usr/bin/env python3
"""Acrescenta os 11 registros de inimigos e chefes (Assets_Inimigos_Bosses_v1) ao asset_index.json
e ao runtime_asset_registry.json, sem apagar os 40 anteriores.

Idempotente: rodar de novo apenas atualiza os campos derivados dos exports. Nenhum ID do Roblox é
inventado aqui; os IDs continuam vindo de assets/export/upload_log.json.

Uso: python3 tools/merge_enemy_index.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PACK = os.path.join(ROOT, "Assets_Inimigos_Bosses_v1")
MANIFEST = os.path.join(PACK, "manifesto_inimigos_bosses.json")
EXPORTS = os.path.join(ROOT, "assets", "export", "enemy_export_manifest.json")
INDEX = os.path.join(ROOT, "asset_index.json")
REGISTRY = os.path.join(ROOT, "runtime_asset_registry.json")


def main():
    for path in (MANIFEST, EXPORTS):
        if not os.path.exists(path):
            print("ERRO: falta", path, "(rode tools/export_enemy_assets.py antes)")
            sys.exit(1)
    pack = json.load(open(MANIFEST))
    exports = json.load(open(EXPORTS))["assets"]
    index = json.load(open(INDEX))
    registry = json.load(open(REGISTRY))

    index_by_key = {a["assetKey"]: a for a in index["assets"]}
    reg_by_key = {a["assetKey"]: a for a in registry["assets"]}
    added = 0
    for asset in pack["assets"]:
        key = asset["assetKey"]
        exp = exports[key]
        entry = index_by_key.get(key)
        if entry is None:
            entry = {"assetKey": key}
            index["assets"].append(entry)
            index_by_key[key] = entry
            added += 1
        entry.update(
            {
                "displayName": asset["displayName"],
                "category": asset["category"],
                "entityId": asset["entityId"],
                "entityType": asset["entityType"],
                "towerId": None,
                "state": None,
                "sourceFile": asset["sourceFile"],
                "sourceWidth": asset["sourceWidth"],
                "sourceHeight": asset["sourceHeight"],
                "sourceFrames": asset["sourceFrames"],
                "alpha": asset["alpha"],
                "sourceAnchorSuggested": asset["sourceAnchorSuggested"],
                "anchorRequiresReview": asset["anchorRequiresReview"],
                "sha256": asset["sha256"],
                "normalization": {
                    "status": "exported",
                    "targetFrameWidth": exp["width"],
                    "targetFrameHeight": exp["height"],
                    "targetAnchor": exp["anchor"],
                    "preserveOriginal": True,
                },
            }
        )
        reg = reg_by_key.get(key)
        if reg is None:
            reg = {"assetKey": key}
            registry["assets"].append(reg)
            reg_by_key[key] = reg
        reg.update(
            {
                "sourceFile": asset["sourceFile"],
                "exportFile": exp["file"],
                "exportSha256": exp["sha256"],
                "renderMode": exp["renderMode"],
                "frameCount": exp["frameCount"],
                "runtimeAnchor": exp["anchor"],
                "visibleWidthCells": exp["visibleWidthCells"],
                "frameWidthCells": exp["frameWidthCells"],
                "entityId": exp["entityId"],
                "entityType": exp["entityType"],
                "drawnAnimationStatus": exp["drawnAnimationStatus"],
            }
        )
        reg.setdefault("robloxAssetId", None)
        reg.setdefault("status", "exported_pending_upload")
        reg.setdefault("checkedInStudio", False)

    index["sourceAssetCount"] = len(index["assets"])
    index["assetPacks"] = [
        "Assets_Quintal_em_Guarda_v1 (40 originais: torres, cenário e terrenos)",
        "Assets_Inimigos_Bosses_v1 (11 originais: 8 inimigos e 3 chefes)",
    ]
    with open(INDEX, "w") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
        f.write("\n")
    with open(REGISTRY, "w") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"índice: {len(index['assets'])} assets ({added} novos); registro: {len(registry['assets'])}")


if __name__ == "__main__":
    main()
