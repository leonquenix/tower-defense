#!/usr/bin/env python3
"""Gera src/shared/Config/Balance.luau e Maps.luau a partir de dados/balanceamento_v1.json.

Falha (exit 1) quando encontra ID desconhecido, custo inválido, transição inexistente,
caminho não ortogonal, bloqueio sobre caminho ou célula fora da grade.
Saída determinística: chaves ordenadas e checksum do JSON de origem.
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from luau_emit import emit  # noqa: E402

SRC = os.path.join(ROOT, "Pacote_Claude_Code", "dados", "balanceamento_v1.json")
OUT_BAL = os.path.join(ROOT, "src", "shared", "Config", "Balance.luau")
OUT_MAPS = os.path.join(ROOT, "src", "shared", "Config", "Maps.luau")

STATES = ["L0", "L1", "L2", "L3A", "L3B"]
TRANSITIONS = {"L0": ["L1"], "L1": ["L2"], "L2": ["L3A", "L3B"], "L3A": [], "L3B": []}
DAMAGE_TYPES = {"physical", "energy", "none"}
TARGETS = {"first", "last", "strongest", "closest", "none"}


class ValidationError(Exception):
    pass


def path_cells(path):
    cells = []
    for i in range(len(path) - 1):
        (x0, y0), (x1, y1) = path[i], path[i + 1]
        if x0 != x1 and y0 != y1:
            raise ValidationError(f"segmento diagonal {path[i]} -> {path[i+1]}")
        if x0 == x1 and y0 == y1:
            raise ValidationError(f"segmento de comprimento zero em {path[i]}")
        dx = (x1 > x0) - (x1 < x0)
        dy = (y1 > y0) - (y1 < y0)
        x, y = x0, y0
        while (x, y) != (x1, y1):
            if not cells or cells[-1] != (x, y):
                cells.append((x, y))
            x += dx
            y += dy
    cells.append(tuple(path[-1]))
    return cells


def validate(data):
    errors = []
    grid = data["grid"]
    cols, rows = grid["columns"], grid["rows"]
    tower_ids = [t["id"] for t in data["towers"]]
    enemy_ids = [e["id"] for e in data["enemies"]]
    boss_ids = [b["id"] for b in data["bosses"]]
    map_ids = [m["id"] for m in data["maps"]]
    for name, ids in (("towers", tower_ids), ("enemies", enemy_ids), ("bosses", boss_ids), ("maps", map_ids)):
        if len(ids) != len(set(ids)):
            errors.append(f"IDs duplicados em {name}: {ids}")
    for t in data["towers"]:
        if t["damageType"] not in DAMAGE_TYPES:
            errors.append(f"{t['id']}: damageType inválido {t['damageType']}")
        if t["target"] not in TARGETS:
            errors.append(f"{t['id']}: target inválido {t['target']}")
        if set(t["states"].keys()) != set(STATES):
            errors.append(f"{t['id']}: estados {sorted(t['states'].keys())} != {STATES}")
        for sid, st in t["states"].items():
            if not isinstance(st.get("cost"), (int, float)) or st["cost"] <= 0:
                errors.append(f"{t['id']}.{sid}: custo inválido {st.get('cost')}")
            if st.get("interval", 0) < 0 or st.get("range", 0) <= 0:
                errors.append(f"{t['id']}.{sid}: intervalo/alcance inválidos")
            if t["damageType"] == "none" and st.get("damage", 0) != 0:
                errors.append(f"{t['id']}.{sid}: torre de apoio com dano")
            if t["damageType"] != "none" and st.get("interval", 0) <= 0:
                errors.append(f"{t['id']}.{sid}: torre de dano com intervalo 0")
        if len(t.get("branchNames", [])) != 2:
            errors.append(f"{t['id']}: branchNames deve ter 2 nomes")
        if t["perPlayerLimit"] <= 0:
            errors.append(f"{t['id']}: perPlayerLimit inválido")
        if t["unlock"] < 0 or (t["starter"] and t["unlock"] != 0):
            errors.append(f"{t['id']}: unlock incoerente com starter")
    for e in data["enemies"]:
        for k in ("hp", "speed", "bounty", "leak"):
            if e[k] < 0:
                errors.append(f"{e['id']}: {k} negativo")
        if not 0 <= e["armor"] < 1:
            errors.append(f"{e['id']}: armadura fora de [0,1)")
        if not 0 <= e.get("energyResistance", 0) < 1:
            errors.append(f"{e['id']}: energyResistance fora de [0,1)")
    for b in data["bosses"]:
        if b["period"] <= b["telegraph"]:
            errors.append(f"{b['id']}: period deve exceder telegraph")
        if b["mechanic"] == "summon" and b.get("summonType") not in enemy_ids:
            errors.append(f"{b['id']}: summonType desconhecido")
    for i, w in enumerate(data["waves"], start=1):
        if w["wave"] != i:
            errors.append(f"onda {i}: numeração {w['wave']} fora de ordem")
        if not w["groups"]:
            errors.append(f"onda {i}: sem grupos")
        for g in w["groups"]:
            if g["enemy"] not in enemy_ids:
                errors.append(f"onda {i}: inimigo desconhecido {g['enemy']}")
            if g["count"] <= 0:
                errors.append(f"onda {i}: contagem inválida")
        if w["spawnInterval"] <= 0 or w["groupGap"] < 0:
            errors.append(f"onda {i}: intervalos inválidos")
        expected_income = 120 + 15 * i
        if w["income"] != expected_income:
            errors.append(f"onda {i}: income {w['income']} != 120+15*{i}={expected_income}")
    if len(data["waves"]) != 20:
        errors.append(f"esperadas 20 ondas, há {len(data['waves'])}")
    if not data["waves"][-1]["bossAfterGroups"]:
        errors.append("onda 20 deve ter bossAfterGroups=true")
    for m in data["maps"]:
        if m["boss"] not in boss_ids:
            errors.append(f"mapa {m['id']}: chefe desconhecido {m['boss']}")
        try:
            cells = path_cells(m["path"])
        except ValidationError as exc:
            errors.append(f"mapa {m['id']}: {exc}")
            continue
        for (x, y) in cells:
            if not (0 <= x < cols and 0 <= y < rows):
                errors.append(f"mapa {m['id']}: célula de caminho fora da grade {(x, y)}")
        if len(set(cells)) != len(cells):
            errors.append(f"mapa {m['id']}: caminho se cruza")
        if m["path"][0][0] != 0 or m["path"][-1][0] != cols - 1:
            errors.append(f"mapa {m['id']}: caminho deve entrar em x=0 e sair em x={cols-1}")
        cellset = set(cells)
        for b in m["blocked"]:
            bt = tuple(b)
            if not (0 <= bt[0] < cols and 0 <= bt[1] < rows):
                errors.append(f"mapa {m['id']}: bloqueio fora da grade {bt}")
            if bt in cellset:
                errors.append(f"mapa {m['id']}: bloqueio sobre caminho {bt}")
        if m["unlock"] != "tutorial" and not m["unlock"].startswith("win:"):
            errors.append(f"mapa {m['id']}: regra de desbloqueio desconhecida {m['unlock']}")
    for c in data["circuits"]:
        for tid in c["pair"]:
            if tid not in tower_ids:
                errors.append(f"circuito {c['id']}: torre desconhecida {tid}")
        if c["effect"] not in {"damage_vs_slowed", "splash_radius_add", "chain_falloff_add"}:
            errors.append(f"circuito {c['id']}: efeito desconhecido {c['effect']}")
    tut = data["tutorial"]
    jardim = next(m for m in data["maps"] if m["id"] == "jardim")
    jcells = set(path_cells(jardim["path"])) | {tuple(b) for b in jardim["blocked"]}
    for tid, cell in tut["guidedCells"].items():
        if tid not in tower_ids:
            errors.append(f"tutorial: torre guiada desconhecida {tid}")
        if tuple(cell) in jcells:
            errors.append(f"tutorial: célula guiada {cell} inválida no Jardim")
    for wave in tut["waves"]:
        for g in wave:
            if g["enemy"] not in enemy_ids:
                errors.append(f"tutorial: inimigo desconhecido {g['enemy']}")
    for d in ("normal", "desafio"):
        if d not in data["difficulties"]:
            errors.append(f"dificuldade {d} ausente")
    if len(data["playerTowerLimitsByPartySize"]) != data["partyMax"]:
        errors.append("playerTowerLimitsByPartySize deve ter partyMax entradas")
    return errors


def main():
    raw = open(SRC, "rb").read()
    checksum = hashlib.sha256(raw).hexdigest()
    data = json.loads(raw)
    errors = validate(data)
    if errors:
        print("ERROS DE VALIDAÇÃO DO BALANCEAMENTO:")
        for e in errors:
            print(" -", e)
        sys.exit(1)

    towers = []
    for t in data["towers"]:
        towers.append({
            "id": t["id"], "name": t["name"], "role": t["role"], "starter": t["starter"], "unlock": t["unlock"],
            "damageType": t["damageType"], "target": t["target"], "perPlayerLimit": t["perPlayerLimit"],
            "states": {k: t["states"][k] for k in STATES}, "branchNames": t["branchNames"],
        })
    balance = {
        "version": data["version"], "status": data["status"], "checksum": checksum,
        "grid": data["grid"], "baseHP": data["baseHP"], "startingCash": data["startingCash"],
        "tickRate": data["tickRate"], "snapshotRate": data["snapshotRate"],
        "towers": towers, "enemies": data["enemies"], "bosses": data["bosses"], "waves": data["waves"],
        "difficulties": data["difficulties"], "circuits": data["circuits"], "pulse": data["pulse"],
        "effects": data["effects"], "rewards": data["rewards"], "tutorial": data["tutorial"], "shop": data["shop"],
        "partyMax": data["partyMax"], "serverMaxPlayers": data["serverMaxPlayers"], "loadoutSlots": data["loadoutSlots"],
        "playerTowerLimitsByPartySize": data["playerTowerLimitsByPartySize"],
        "coopAdditionalHPPerPlayer": data["coopAdditionalHPPerPlayer"],
        "preparationSeconds": data["preparationSeconds"], "intermissionSeconds": data["intermissionSeconds"],
        "sellRefund": data["sellRefund"],
    }
    header = (
        "--!strict\n"
        "-- ARQUIVO GERADO por tools/import_balance.py a partir de Pacote_Claude_Code/dados/balanceamento_v1.json\n"
        f"-- Não edite à mão. sha256 da origem: {checksum}\n"
        "local Types = require(script.Parent.Parent.Types)\n\n"
    )
    body = "local Balance: Types.BalanceData = " + emit(balance) + "\n\nreturn Balance\n"
    with open(OUT_BAL, "w") as f:
        f.write(header + body)

    maps = []
    for m in data["maps"]:
        cells = path_cells(m["path"])
        maps.append({
            "id": m["id"], "name": m["name"], "unlock": m["unlock"], "hpMultiplier": m["hpMultiplier"],
            "path": m["path"], "blocked": m["blocked"], "boss": m["boss"],
            "pathCells": [list(c) for c in cells],
        })
    header2 = (
        "--!strict\n"
        "-- ARQUIVO GERADO por tools/import_balance.py a partir de Pacote_Claude_Code/dados/balanceamento_v1.json\n"
        f"-- Não edite à mão. sha256 da origem: {checksum}\n"
        "local Types = require(script.Parent.Parent.Types)\n\n"
        "export type MapEntry = Types.MapDef & { pathCells: { Types.Cell } }\n\n"
    )
    body2 = "local Maps: { MapEntry } = " + emit(maps) + "\n\nreturn Maps\n"
    with open(OUT_MAPS, "w") as f:
        f.write(header2 + body2)
    print(f"OK: {OUT_BAL}\nOK: {OUT_MAPS}\nchecksum {checksum}")
    for m in maps:
        print(f"  mapa {m['id']}: {len(m['pathCells'])} células de caminho, {len(m['blocked'])} bloqueios")


if __name__ == "__main__":
    main()
