#!/usr/bin/env python3
"""Atualiza runtime_asset_registry.json com exports e IDs de upload verificados e gera
src/shared/Config/Assets.luau. Nunca inventa IDs: só usa o que está em assets/export/upload_log.json.

Uso: python3 tools/update_asset_registry.py [--checked-in-studio]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from luau_emit import emit  # noqa: E402

REGISTRY = os.path.join(ROOT, "runtime_asset_registry.json")
EXPORT_MANIFEST = os.path.join(ROOT, "assets", "export", "export_manifest.json")
UPLOAD_LOG = os.path.join(ROOT, "assets", "export", "upload_log.json")
INDEX = os.path.join(ROOT, "asset_index.json")
OUT = os.path.join(ROOT, "src", "shared", "Config", "Assets.luau")


def main():
    checked = "--checked-in-studio" in sys.argv
    registry = json.load(open(REGISTRY))
    manifest = json.load(open(EXPORT_MANIFEST))["assets"]
    uploads = json.load(open(UPLOAD_LOG))["uploads"] if os.path.exists(UPLOAD_LOG) else {}
    index = json.load(open(INDEX))
    index_keys = {a["assetKey"] for a in index["assets"]}
    reg_keys = {a["assetKey"] for a in registry["assets"]}
    if index_keys != reg_keys:
        print("ERRO: cobertura do registro difere do índice:", index_keys ^ reg_keys)
        sys.exit(1)

    def rel(exp):
        return "assets/export/" + exp

    luau_assets = {}
    pending = []
    for entry in registry["assets"]:
        key = entry["assetKey"]
        if entry.get("entityType") in ("enemy", "boss"):
            continue  # inimigos e chefes usam enemy_export_manifest.json (bloco abaixo)
        m = manifest.get(key)
        if not m:
            pending.append(key)
            continue
        exports = m["exports"]
        if m["category"] == "torres":
            game = exports["game128"]
            portrait = exports.get("portrait256")
            game_rel = game["file"].replace("assets/export/", "")
            entry["exportFile"] = game["file"]
            entry["exportSha256"] = game["sha256"]
            aid = uploads.get(game_rel)
            pid = uploads.get(portrait["file"].replace("assets/export/", "")) if portrait else None
            entry["robloxAssetId"] = aid
            entry["uploadedWidth"] = game["width"] if aid else None
            entry["uploadedHeight"] = game["height"] if aid else None
            entry["portraitExportFile"] = portrait["file"] if portrait else None
            entry["portraitRobloxAssetId"] = pid
            entry["runtimeAnchor"] = m["anchor"]
            entry["status"] = "uploaded" if aid else "exported_pending_upload"
            luau_assets[key] = {
                "image": f"rbxassetid://{aid}" if aid else None,
                "portrait": f"rbxassetid://{pid}" if pid else None,
                "width": game["width"], "height": game["height"], "anchorX": m["anchor"][0], "anchorY": m["anchor"][1],
                "contentHeight": m["contentHeight128"], "kind": "tower", "towerId": m["towerId"], "state": m["state"],
            }
        elif m["category"] == "cenario":
            prop = exports["prop256"]
            prel = prop["file"].replace("assets/export/", "")
            aid = uploads.get(prel)
            entry["exportFile"] = prop["file"]
            entry["exportSha256"] = prop["sha256"]
            entry["robloxAssetId"] = aid
            entry["uploadedWidth"] = prop["width"] if aid else None
            entry["uploadedHeight"] = prop["height"] if aid else None
            entry["runtimeAnchor"] = m["anchor"]
            entry["status"] = "uploaded" if aid else "exported_pending_upload"
            luau_assets[key] = {
                "image": f"rbxassetid://{aid}" if aid else None, "width": prop["width"], "height": prop["height"],
                "anchorX": m["anchor"][0], "anchorY": m["anchor"][1], "kind": "prop",
            }
        else:
            master = exports["master1600"]
            up = exports["upload1024"]
            urel = up["file"].replace("assets/export/", "")
            aid = uploads.get(urel)
            entry["exportFile"] = master["file"]
            entry["exportSha256"] = master["sha256"]
            entry["uploadFile"] = up["file"]
            entry["robloxAssetId"] = aid
            entry["uploadedWidth"] = up["width"] if aid else None
            entry["uploadedHeight"] = up["height"] if aid else None
            entry["runtimeAnchor"] = m["anchor"]
            entry["backingColor"] = m["backingColor"]
            entry["status"] = "uploaded" if aid else "exported_pending_upload"
            luau_assets[key] = {
                "image": f"rbxassetid://{aid}" if aid else None, "width": up["width"], "height": up["height"],
                "anchorX": 0.5, "anchorY": 0.5, "kind": "ground",
                "backingColor": m["backingColor"],
            }
        entry["checkedInStudio"] = bool(entry.get("robloxAssetId")) and checked
    # arte real de inimigos e chefes (Assets_Inimigos_Bosses_v1), por entityId do catálogo
    enemy_manifest = os.path.join(ROOT, "assets", "export", "enemy_export_manifest.json")
    real_enemy_keys = set()
    enemy_entries = {}
    if os.path.exists(enemy_manifest):
        em = json.load(open(enemy_manifest))["assets"]
        by_key = {a["assetKey"]: a for a in registry["assets"]}
        for pack_key, exp in em.items():
            is_boss = exp["entityType"] == "boss"
            key = ("boss_" if is_boss else "enemy_") + exp["entityId"]
            rel = exp["file"].replace("assets/export/", "")
            aid = uploads.get(rel)
            real_enemy_keys.add(key)
            enemy_entries[key] = {
                "image": f"rbxassetid://{aid}" if aid else None,
                "width": exp["width"], "height": exp["height"],
                "anchorX": exp["anchor"][0], "anchorY": exp["anchor"][1],
                "kind": "boss" if is_boss else "enemy", "entityId": exp["entityId"],
                "frameWidthCells": exp["frameWidthCells"], "visibleWidthCells": exp["visibleWidthCells"],
            }
            reg = by_key.get(pack_key)
            if reg is not None:
                reg["robloxAssetId"] = aid
                reg["uploadedWidth"] = exp["width"] if aid else None
                reg["uploadedHeight"] = exp["height"] if aid else None
                reg["status"] = "uploaded" if aid else "exported_pending_upload"
                reg["checkedInStudio"] = bool(aid) and checked

    registry["schemaNotes"] = (
        "Campos adicionais: exportSha256, portraitExportFile, portraitRobloxAssetId, uploadFile, backingColor, "
        "visibleWidthCells/frameWidthCells (inimigos e chefes). "
        "Status: pending_upload | exported_pending_upload | uploaded. checkedInStudio só após carregamento verificado."
    )
    registry["uploadLog"] = "assets/export/upload_log.json"
    with open(REGISTRY, "w") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)
        f.write("\n")

    # placeholders procedurais: só para chaves que ainda não têm arte real (identificados)
    ph_path = os.path.join(ROOT, "assets", "export", "placeholders", "placeholder_manifest.json")
    if os.path.exists(ph_path):
        ph = json.load(open(ph_path))
        for key, entry in ph["assets"].items():
            if key in real_enemy_keys:
                continue
            rel = entry["file"].replace("assets/export/", "")
            aid = uploads.get(rel)
            luau_assets[key] = {
                "image": f"rbxassetid://{aid}" if aid else None, "width": entry["width"], "height": entry["height"],
                "anchorX": entry["anchor"][0], "anchorY": entry["anchor"][1],
                "kind": "boss" if key.startswith("boss_") else "enemy", "placeholder": True,
            }
    luau_assets.update(enemy_entries)
    header = (
        "--!strict\n"
        "-- ARQUIVO GERADO por tools/update_asset_registry.py a partir de runtime_asset_registry.json.\n"
        "-- IDs presentes aqui vieram de uploads reais registrados em assets/export/upload_log.json.\n"
        "-- image == nil significa asset ainda não publicado: o cliente usa um visual provisório identificado.\n\n"
        "export type AssetEntry = {\n"
        "\timage: string?,\n\tportrait: string?,\n\twidth: number,\n\theight: number,\n\tanchorX: number,\n\tanchorY: number,\n"
        "\tcontentHeight: number?,\n\tkind: string,\n\ttowerId: string?,\n\tstate: string?,\n\tbackingColor: { number }?,\n\tplaceholder: boolean?,\n"
        "\tentityId: string?,\n\tframeWidthCells: number?,\n\tvisibleWidthCells: number?,\n}\n\n"
    )
    body = "local entries: { [string]: AssetEntry } = " + emit(luau_assets) + "\n\n"
    body += (
        "local Assets = {}\n\nAssets.entries = entries\n\n"
        "function Assets.get(key: string): AssetEntry?\n\treturn entries[key]\nend\n\n"
        "function Assets.image(key: string): string?\n\tlocal e = entries[key]\n\treturn if e then e.image else nil\nend\n\n"
        "function Assets.towerKey(towerId: string, state: string): string\n\treturn \"tower_\" .. towerId .. \"_\" .. state\nend\n\n"
        "function Assets.groundKey(mapId: string): string\n\treturn \"map_\" .. mapId .. \"_ground\"\nend\n\n"
        "function Assets.enemyKey(defId: string, isBoss: boolean): string\n\treturn (if isBoss then \"boss_\" else \"enemy_\") .. defId\nend\n\n"
        "function Assets.uploadedCount(): (number, number)\n\tlocal uploaded, total = 0, 0\n\tfor _, e in pairs(entries) do\n\t\ttotal += 1\n\t\tif e.image then\n\t\t\tuploaded += 1\n\t\tend\n\tend\n\treturn uploaded, total\nend\n\n"
        "return Assets\n"
    )
    with open(OUT, "w") as f:
        f.write(header + body)
    uploaded = sum(1 for e in registry["assets"] if e.get("robloxAssetId"))
    print(f"registro atualizado: {uploaded}/{len(registry['assets'])} com ID; pendentes de export: {pending or 'nenhum'}")
    print("gerado", OUT)


if __name__ == "__main__":
    main()
