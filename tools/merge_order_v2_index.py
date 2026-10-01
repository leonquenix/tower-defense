#!/usr/bin/env python3
"""Acrescenta as 215 fontes da encomenda v2 ao asset_index.json e ao runtime_asset_registry.json,
sem apagar as 51 anteriores.

Idempotente: rodar de novo só atualiza os campos derivados do export. Nenhum ID do Roblox é
inventado aqui: robloxAssetId continua vindo de assets/export/upload_log.json, aplicado por
tools/update_asset_registry.py.

Convenções de chave:
  tower_<id>_<estado>              pose (torres novas; as atuais já existiam)
  tower_<id>_<estado>_<ação>       quadro: windup (antecipação), fire (disparo) ou pulse (apoio)
  enemy_<id>_base / boss_<id>_base pose dos inimigos e chefes novos
  enemy_<id>_walk_b, boss_<id>_walk_b, boss_<id>_ability   quadros
  fx_<nome>                        efeito ou projétil
  base_farol_pilha_<estágio>       Farol danificado e crítico
  map_<id>_scene                   cena de mapa (o jogo lê pelo map_<id>_ground)

Uso: python3 tools/merge_order_v2_index.py   (depois de tools/export_order_v2.py)
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
EXPORTS = os.path.join(ROOT, "assets", "export", "order_v2_manifest.json")
INDEX = os.path.join(ROOT, "asset_index.json")
REGISTRY = os.path.join(ROOT, "runtime_asset_registry.json")
PACK = "Assets_Encomenda_v2"
ACTION_NAMES = {
    "windup": "antecipação",
    "fire": "disparo",
    "pulse": "pulso de apoio",
    "walk_b": "segundo passo",
    "ability": "habilidade",
    "danificado": "danificado",
    "critico": "crítico",
    "scene": "cena",
}


def frame_of(key, record):
    """Chave da pose a que um quadro pertence (nil para poses, efeitos e cenas)."""
    action = record.get("action")
    if record["category"] == "torres" and action != "pose":
        return f"tower_{record['towerId']}_{record['state']}"
    if record["category"] in ("inimigos", "chefes") and action != "base":
        prefix = "boss" if record["entityType"] == "boss" else "enemy"
        return f"{prefix}_{record['entityId']}_base"
    if key.startswith("base_farol_pilha_"):
        return "base_farol_pilha"
    return None


def display_name(key, record, balance_names):
    category = record["category"]
    action = record.get("action")
    if category == "torres":
        name = balance_names.get(record["towerId"], record["towerId"])
        suffix = "" if action == "pose" else f" ({ACTION_NAMES.get(action, action)})"
        return f"{name} · {record['state']}{suffix}"
    if category in ("inimigos", "chefes"):
        name = record.get("displayName") or balance_names.get(record["entityId"], record["entityId"])
        return name if action == "base" else f"{name} ({ACTION_NAMES.get(action, action)})"
    if category == "mapas":
        return f"{balance_names.get(record['mapId'], record['mapId'])} — cena"
    if category == "cenario":
        return f"Farol de Pilha ({ACTION_NAMES.get(action, action)})"
    return key


def main():
    if not os.path.exists(EXPORTS):
        print("ERRO: falta", EXPORTS, "(rode tools/export_order_v2.py antes)")
        sys.exit(1)
    exports = json.load(open(EXPORTS))["assets"]
    index = json.load(open(INDEX))
    registry = json.load(open(REGISTRY))
    balance = json.load(open(os.path.join(ROOT, "Pacote_Claude_Code", "dados", "balanceamento_v1.json")))
    names = {t["id"]: t["name"] for t in balance["towers"]}
    names.update({e["id"]: e["name"] for e in balance["enemies"]})
    names.update({b["id"]: b["name"] for b in balance["bosses"]})
    names.update({m["id"]: m["name"] for m in balance["maps"]})

    index_by_key = {a["assetKey"]: a for a in index["assets"]}
    reg_by_key = {a["assetKey"]: a for a in registry["assets"]}
    added = 0
    frames_by_pose = {}
    for key, record in exports.items():
        game = record["exports"].get("game128") or record["exports"].get("game") or record["exports"].get(
            "prop256"
        ) or record["exports"].get("fx") or record["exports"].get("upload")
        pose = frame_of(key, record)
        if pose:
            frames_by_pose.setdefault(pose, []).append(key)
        entry = index_by_key.get(key)
        if entry is None:
            entry = {"assetKey": key}
            index["assets"].append(entry)
            index_by_key[key] = entry
            added += 1
        entry.update(
            {
                "displayName": display_name(key, record, names),
                "category": record["category"],
                "pack": PACK,
                "towerId": record.get("towerId"),
                "state": record.get("state"),
                "action": record.get("action"),
                "entityId": record.get("entityId"),
                "entityType": record.get("entityType"),
                "mapId": record.get("mapId"),
                "frameOf": pose,
                "sourceFile": record["sourceFile"],
                "sourceWidth": record["sourceWidth"],
                "sourceHeight": record["sourceHeight"],
                "sourceFrames": 1,
                "alpha": record["alpha"] is not None and record["alpha"][0] < 255,
                "sha256": record["sourceSha256"],
                "normalization": {
                    "status": "exported",
                    "targetFrameWidth": game["width"],
                    "targetFrameHeight": game["height"],
                    "targetAnchor": record.get("anchor"),
                    "preserveOriginal": True,
                },
            }
        )
        reg = reg_by_key.get(key)
        if reg is None:
            reg = {"assetKey": key, "robloxAssetId": None, "status": "exported_pending_upload", "checkedInStudio": False}
            registry["assets"].append(reg)
            reg_by_key[key] = reg
        reg.update(
            {
                "sourceFile": record["sourceFile"],
                "exportFile": game["file"],
                "exportSha256": game["sha256"],
                "renderMode": "frame" if pose else "single_static",
                "frameOf": pose,
                "action": record.get("action"),
                "frameCount": 1,
                "runtimeAnchor": record.get("anchor"),
            }
        )
        if "portrait256" in record["exports"]:
            reg["portraitExportFile"] = record["exports"]["portrait256"]["file"]
        for field in ("visibleWidthCells", "frameWidthCells", "entityId", "entityType", "backingColor"):
            if field in record:
                reg[field] = record[field]
        if reg.get("robloxAssetId") is None:
            reg["status"] = "exported_pending_upload"
    # a pose passa a ser "pose + quadros" quando tem quadro desenhado
    for pose, frames in frames_by_pose.items():
        reg = reg_by_key.get(pose)
        if reg is not None:
            reg["renderMode"] = "pose_plus_frames"
            reg["frameKeys"] = sorted(frames)
            reg["drawnAnimationStatus"] = "partial_pose_plus_frames"
    # cabeçalho do índice
    index["sourceAssetCount"] = len(index["assets"])
    packs = index.setdefault("assetPacks", [])
    label = f"{PACK} (215 originais da encomenda v2: torres novas e quadros, inimigos e chefes, efeitos, Farol e mapas)"
    if not any(p.startswith(PACK) for p in packs):
        packs.append(label)
    for tower in ("escova", "lumi", "pula", "piao", "picole", "fofo"):
        index["towers"][tower] = {s: f"tower_{tower}_{s}" for s in ("L0", "L1", "L2", "L3A", "L3B")}
    for map_id in ("inverno", "cozinha", "quarto", "porao"):
        index["maps"][map_id] = {
            "groundAssetKey": f"map_{map_id}_ground",
            "sceneAssetKey": f"map_{map_id}_scene",
            "gameplayConfig": "Pacote_Claude_Code/dados/balanceamento_v1.json",
            "pathSource": "maps entry selected by id",
        }
    for map_id in ("oficina", "sotao"):
        index["maps"][map_id]["sceneAssetKey"] = f"map_{map_id}_scene"
    index["notIncluded"] = [
        "atlas de 8 quadros por estado (a encomenda v2 trouxe pose + antecipação + disparo/pulso por estado)",
        "quadros de inimigos além do segundo passo; chefes além de segundo passo e habilidade",
        "audio",
        "skins",
    ]
    registry["schemaNotes"] = (
        "Campos adicionais: exportSha256, portraitExportFile, portraitRobloxAssetId, uploadFile, backingColor, "
        "visibleWidthCells/frameWidthCells (inimigos e chefes), frameOf/action (quadro de uma pose), frameKeys "
        "(quadros desenhados de uma pose). renderMode: single_static | pose_plus_frames | frame. "
        "Status: pending_upload | exported_pending_upload | uploaded. checkedInStudio só após carregamento verificado."
    )
    with open(INDEX, "w") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
        f.write("\n")
    with open(REGISTRY, "w") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"índice: {len(index['assets'])} entradas ({added} novas); registro: {len(registry['assets'])}")


if __name__ == "__main__":
    main()
