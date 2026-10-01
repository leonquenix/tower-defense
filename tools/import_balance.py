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


ITEMS = {"retry", "support"}

# Campos de estado de torre que a simulação entende. Campo fora daqui é erro: um nome digitado
# errado no JSON viraria uma mecânica que não liga.
STAT_KEYS = {
    "cost", "damage", "interval", "range", "splash", "maxTargets", "armorIgnore", "bossBonus", "mark",
    "markDuration", "slow", "slowDuration", "chains", "chainRadius", "chainFalloff", "haste",
    # encomenda v2
    "shred", "shredDuration", "shredStacks", "burn", "burnDuration", "focusRamp", "focusMax",
    "burnSpread", "burnSpreadRadius", "push", "grab", "allTargets", "freeze", "frozenBonus",
    "damageBoost", "baseHeal",
}
# Habilidades de chefe que Simulation.updateBosses resolve.
MECHANICS = {"dust_pulse", "armor_cycle", "summon", "frost_blast", "soak", "wrap", "dust_cloud"}
EFFECT_KEYS = {
    "slowCap", "bossSlowStrength", "physicalArmorCap", "hasteStacking", "slowStacking", "markStacking",
    "shredCap", "pushCooldown", "maxPushPerEnemy", "bossPushFactor", "freezeImmunity", "frozenBossSlow",
    "damageBoostStacking", "burnStacking", "baseHealPerWaveCap",
}


class ValidationError(Exception):
    pass


def validate_bundle(bundle, where, required=False):
    """Pacote de recompensa: botões e fichas. Chave desconhecida ou valor não inteiro é erro."""
    if bundle is None:
        return [f"{where}: vazio"] if required else []
    errors = []
    if not bundle:
        errors.append(f"{where}: vazio")
    for key, value in bundle.items():
        if key != "buttons" and key not in ITEMS:
            errors.append(f"{where}: chave desconhecida {key}")
        elif not isinstance(value, int) or value <= 0:
            errors.append(f"{where}: {key} deve ser inteiro positivo")
    return errors


def validate_stats(t, sid, st):
    """Faixas e pares obrigatórios dos efeitos novos (Escovinha, Lumi, Pula, Pião, Picolé, Fofo)."""
    where = f"{t['id']}.{sid}"
    errors = []

    def frac(key, lo=0.0, hi=1.0):
        v = st.get(key)
        if v is not None and not (lo < v <= hi):
            errors.append(f"{where}: {key} fora de ({lo}, {hi}]")

    def pair(a, b):
        if (a in st) != (b in st):
            errors.append(f"{where}: {a} e {b} andam juntos")

    for key in ("shred", "frozenBonus", "focusRamp"):
        frac(key)
    frac("damageBoost", 0.0, 0.5)
    pair("shred", "shredDuration")
    pair("burn", "burnDuration")
    pair("burnSpread", "burnSpreadRadius")
    pair("focusRamp", "focusMax")
    pair("splash", "maxTargets")
    for key in ("shredStacks", "allTargets", "burnSpread", "baseHeal", "grab", "maxTargets", "chains"):
        v = st.get(key)
        if v is not None and (not isinstance(v, int) or v < 1):
            errors.append(f"{where}: {key} deve ser inteiro >= 1")
    for key in ("shredDuration", "burn", "burnDuration", "push", "freeze", "burnSpreadRadius", "focusMax"):
        v = st.get(key)
        if v is not None and v <= 0:
            errors.append(f"{where}: {key} deve ser positivo")
    if "shredStacks" in st and "shred" not in st:
        errors.append(f"{where}: shredStacks sem shred")
    if "grab" in st and "push" not in st:
        errors.append(f"{where}: grab (puxão) precisa de push")
    if ("damageBoost" in st or "baseHeal" in st) and t["damageType"] != "none":
        errors.append(f"{where}: damageBoost/baseHeal só em torre de apoio")
    if "allTargets" in st and ("splash" in st or "chains" in st):
        errors.append(f"{where}: allTargets não combina com splash/chains")
    return errors


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
            unknown = set(st) - STAT_KEYS
            if unknown:
                errors.append(f"{t['id']}.{sid}: campos desconhecidos {sorted(unknown)}")
            errors.extend(validate_stats(t, sid, st))
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
        level = t.get("unlockLevel")
        if not isinstance(level, int) or level < 1 or (t["starter"] and level != 1):
            errors.append(f"{t['id']}: unlockLevel deve ser inteiro >= 1 (1 para as iniciais)")
        elif level > data["progression"]["maxLevel"]:
            errors.append(f"{t['id']}: unlockLevel {level} acima do nível máximo")
    for e in data["enemies"]:
        for k in ("hp", "speed", "bounty", "leak"):
            if e[k] < 0:
                errors.append(f"{e['id']}: {k} negativo")
        if not 0 <= e["armor"] < 1:
            errors.append(f"{e['id']}: armadura fora de [0,1)")
        if not 0 <= e.get("energyResistance", 0) < 1:
            errors.append(f"{e['id']}: energyResistance fora de [0,1)")
        if "slowImmune" in e and not isinstance(e["slowImmune"], bool):
            errors.append(f"{e['id']}: slowImmune deve ser booleano")
        if e.get("dodgeInterval") is not None and e["dodgeInterval"] <= 0:
            errors.append(f"{e['id']}: dodgeInterval deve ser positivo")
    for b in data["bosses"]:
        if b["period"] <= b["telegraph"]:
            errors.append(f"{b['id']}: period deve exceder telegraph")
        if b["mechanic"] not in MECHANICS:
            errors.append(f"{b['id']}: habilidade desconhecida {b['mechanic']}")
        if b["mechanic"] in ("summon", "dust_cloud") and b.get("summonType") not in enemy_ids:
            errors.append(f"{b['id']}: summonType desconhecido")
        if b["mechanic"] in ("frost_blast", "soak", "wrap", "dust_cloud") and not b.get("duration", 0) > 0:
            errors.append(f"{b['id']}: {b['mechanic']} precisa de duration positiva")
        if b["mechanic"] == "frost_blast" and not (isinstance(b.get("targetCount"), int) and b["targetCount"] >= 1):
            errors.append(f"{b['id']}: frost_blast precisa de targetCount inteiro >= 1")
        if b["mechanic"] == "soak" and not (0 <= b.get("soakHeal", -1) <= 1):
            errors.append(f"{b['id']}: soakHeal fora de [0,1]")
        if b["mechanic"] == "dust_cloud" and not b.get("cloudLength", 0) > 0:
            errors.append(f"{b['id']}: dust_cloud precisa de cloudLength positivo")
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
        if m["unlock"] is not None and not m["unlock"].startswith("win:"):
            errors.append(f"mapa {m['id']}: regra de desbloqueio desconhecida {m['unlock']}")
        for g in m.get("mapGroups", []):
            if g.get("enemy") not in enemy_ids:
                errors.append(f"mapa {m['id']}: mapGroups com inimigo desconhecido {g.get('enemy')}")
            if not (isinstance(g.get("fromWave"), int) and 1 <= g["fromWave"] <= len(data["waves"])):
                errors.append(f"mapa {m['id']}: mapGroups.fromWave fora da tabela")
            if not (isinstance(g.get("count"), int) and g["count"] >= 1) or g.get("perWave", 0) < 0:
                errors.append(f"mapa {m['id']}: mapGroups com count/perWave inválidos")
    for c in data["circuits"]:
        for tid in c["pair"]:
            if tid not in tower_ids:
                errors.append(f"circuito {c['id']}: torre desconhecida {tid}")
        if c["effect"] not in {"damage_vs_slowed", "splash_radius_add", "chain_falloff_add"}:
            errors.append(f"circuito {c['id']}: efeito desconhecido {c['effect']}")
    # campanha: cada fase aponta para um mapa existente, cabe na tabela de ondas e tem
    # objetivos que o servidor sabe avaliar (Rules/Stars)
    map_ids = {m["id"] for m in data["maps"]}
    known_objectives = {"noLeak", "maxDamage", "maxTowers", "onlyTowers", "rushAll", "noSell", "minCircuits"}
    seen_levels = set()
    intro_levels = 0
    for index, level in enumerate(data["campaign"]["levels"], start=1):
        where = f"fase {level['id']}"
        if level["id"] in seen_levels:
            errors.append(f"{where}: id repetido")
        seen_levels.add(level["id"])
        if level["mapId"] not in map_ids:
            errors.append(f"{where}: mapa desconhecido {level['mapId']}")
        if not (1 <= level["waves"] <= len(data["waves"])):
            errors.append(f"{where}: {level['waves']} ondas fora da tabela (1..{len(data['waves'])})")
        if level["startingCash"] < 0 or level["hpScale"] <= 0:
            errors.append(f"{where}: sucata inicial ou escala de vida inválida")
        if len(level["objectives"]) != 2:
            errors.append(f"{where}: são duas estrelas além da vitória, veio {len(level['objectives'])}")
        for objective in level["objectives"]:
            kind = objective["kind"]
            if kind not in known_objectives:
                errors.append(f"{where}: objetivo desconhecido {kind}")
            if kind in ("maxDamage", "maxTowers", "minCircuits") and "value" not in objective:
                errors.append(f"{where}: objetivo {kind} sem value")
            if kind == "onlyTowers":
                for tid in objective["towers"]:
                    if tid not in tower_ids:
                        errors.append(f"{where}: torre desconhecida {tid}")
        scale = level.get("bossHpScale")
        if scale is not None and not (0 < scale <= 2):
            errors.append(f"{where}: bossHpScale fora de (0, 2]")
        errors.extend(validate_bundle(level.get("firstClearReward"), f"{where}: firstClearReward"))
        if level.get("intro"):
            if level.get("firstClearReward"):
                errors.append(f"{where}: a fase do guia não entrega fichas")
            intro_levels += 1
            if index != 1:
                errors.append(f"{where}: o guia inicial só existe na primeira fase")
            if level.get("introTower") not in tower_ids:
                errors.append(f"{where}: torre do guia desconhecida")
            level_map = next(m for m in data["maps"] if m["id"] == level["mapId"])
            busy = set(path_cells(level_map["path"])) | {tuple(b) for b in level_map["blocked"]}
            cell = tuple(level.get("introCell") or ())
            if len(cell) != 2 or cell in busy:
                errors.append(f"{where}: célula do guia {cell} não é grama livre")
    if intro_levels != 1:
        errors.append("a campanha precisa de exatamente uma fase com o guia inicial")
    for d in ("normal", "desafio"):
        if d not in data["difficulties"]:
            errors.append(f"dificuldade {d} ausente")
        if d not in data["progression"]["xpDifficulty"]:
            errors.append(f"progression.xpDifficulty sem {d}")
    if data["rewards"].get("winButtonsReferenceWaves", 0) <= 0:
        errors.append("rewards.winButtonsReferenceWaves deve ser positivo")
    prog = data["progression"]
    for key in ("xpPerWave", "xpWinBonus", "levelBase", "levelStep", "maxLevel", "levelButtons", "levelRetryEvery"):
        if not isinstance(prog.get(key), int) or prog[key] < 0:
            errors.append(f"progression.{key} deve ser inteiro >= 0")
    if prog.get("maxLevel", 0) < 2 or prog.get("levelBase", 0) <= 0:
        errors.append("progression: maxLevel >= 2 e levelBase > 0")
    retention = data["retention"]
    if len(retention["dailyRewards"]) != 7:
        errors.append("retention.dailyRewards deve ter 7 dias")
    for i, bundle in enumerate(retention["dailyRewards"], start=1):
        errors.extend(validate_bundle(bundle, f"dia {i}", required=True))
    last = 0
    for i, gift in enumerate(retention["sessionGifts"], start=1):
        minutes = gift.get("minutes")
        if not isinstance(minutes, (int, float)) or minutes <= last:
            errors.append(f"presente {i}: minutes deve crescer")
        else:
            last = minutes
        errors.extend(validate_bundle({k: v for k, v in gift.items() if k != "minutes"}, f"presente {i}", required=True))
    seen_products = set()
    for product in data["shop"]["products"]:
        if product["id"] in seen_products:
            errors.append(f"produto {product['id']} repetido")
        seen_products.add(product["id"])
        if product["item"] not in ITEMS:
            errors.append(f"produto {product['id']}: item desconhecido {product['item']}")
        if not isinstance(product["quantity"], int) or product["quantity"] < 1:
            errors.append(f"produto {product['id']}: quantidade inválida")
        if product["productId"] is not None and (not isinstance(product["productId"], int) or product["productId"] <= 0):
            errors.append(f"produto {product['id']}: productId deve ser null ou inteiro positivo")
    ids = [p["productId"] for p in data["shop"]["products"] if p["productId"] is not None]
    if len(ids) != len(set(ids)):
        errors.append("productId repetido entre produtos")
    retry = data["shop"]["retry"]
    for key in ("decisionSeconds", "promptGraceSeconds", "prepSeconds", "buttonsPrice"):
        if not isinstance(retry.get(key), (int, float)) or retry[key] <= 0:
            errors.append(f"shop.retry.{key} deve ser positivo")
    missing_effects = EFFECT_KEYS - set(data["effects"])
    if missing_effects:
        errors.append(f"effects sem {sorted(missing_effects)}")
    if not 0 < data["effects"].get("shredCap", 0) <= data["effects"].get("physicalArmorCap", 1):
        errors.append("effects.shredCap deve estar em (0, physicalArmorCap]")
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
            "unlockLevel": t["unlockLevel"],
            "damageType": t["damageType"], "target": t["target"], "perPlayerLimit": t["perPlayerLimit"],
            "states": {k: t["states"][k] for k in STATES}, "branchNames": t["branchNames"],
        })
    balance = {
        "version": data["version"], "status": data["status"], "checksum": checksum,
        "grid": data["grid"], "baseHP": data["baseHP"], "startingCash": data["startingCash"],
        "tickRate": data["tickRate"], "snapshotRate": data["snapshotRate"],
        "towers": towers, "enemies": data["enemies"], "bosses": data["bosses"], "waves": data["waves"],
        "difficulties": data["difficulties"], "circuits": data["circuits"], "pulse": data["pulse"],
        "effects": data["effects"], "rewards": data["rewards"], "campaign": data["campaign"],
        "shop": {k: v for k, v in data["shop"].items() if k != "note"},
        "partyMax": data["partyMax"], "serverMaxPlayers": data["serverMaxPlayers"], "loadoutSlots": data["loadoutSlots"],
        "playerTowerLimitsByPartySize": data["playerTowerLimitsByPartySize"],
        "coopAdditionalHPPerPlayer": data["coopAdditionalHPPerPlayer"],
        "preparationSeconds": data["preparationSeconds"], "intermissionSeconds": data["intermissionSeconds"],
        "earlyWaveBonusPerSecond": data["earlyWaveBonusPerSecond"], "earlyWaveBonusMax": data["earlyWaveBonusMax"],
        "sellRefund": data["sellRefund"],
        "progression": {k: v for k, v in data["progression"].items() if k != "note"},
        "retention": {k: v for k, v in data["retention"].items() if k != "note"},
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
            "mapGroups": m.get("mapGroups", []),
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
