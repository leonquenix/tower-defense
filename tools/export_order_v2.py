#!/usr/bin/env python3
"""Exports normalizados da encomenda de arte v2 (215 PNGs em Assets_Encomenda_v2/, preservados).

Regra central: um quadro de animação usa EXATAMENTE a transformação da pose do mesmo estado.
O gerador manteve o enquadramento da pose (mesmos pés, mesmo tamanho no canvas normalizado), então
reaplicar a transformação da pose mantém pose -> antecipação -> disparo no lugar. Remedir os pés
quadro a quadro faria o boneco "andar" quando ele só se inclina para atirar.

- Torres atuais (Dardo ... Maestro): as poses já publicadas não mudam. O quadro de 1024 px recebe a
  escala da família (export_manifest.json) multiplicada por 1254/1024 (o canvas da pose original) e
  os mesmos pés, levados para o canvas de 1024.
- Torres novas (Escovinha ... Fofo): escala única por família, calculada sobre poses E quadros,
  com pés em (0,5; 0,82). Fonte 512, jogo 128 e retrato 256 (só poses).
- Inimigos e chefes atuais: walk_b e ability com a transformação da pose base
  (enemy_export_manifest.json). Novos: âncora medida na pose base, escala que cabe a base e todos os
  quadros, largura visível escolhida por tipo (VISIBLE_CELLS).
- Farol danificado e crítico: transformação do Farol publicado (export_manifest.json).
- Efeitos: centrados pelo conteúdo, 128 px (projéteis e sinais) ou 256 px (estouros e áreas).
- Cenas de mapa: 1536x1024 -> 1024x683 para upload (limite de textura); o playRect é fração, então
  vale para os dois tamanhos.

Escreve assets/export/order_v2_manifest.json e pranchas de revisão (assets/export/review_v2_*.png).
Uso: python3 tools/export_order_v2.py
"""
import hashlib
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PACK = "Assets_Encomenda_v2"
OUT = os.path.join(ROOT, "assets", "export")
ANCHOR = (0.5, 0.82)
ALPHA_THRESHOLD = 128
MARGIN = 0.0625
STATES = ["L0", "L1", "L2", "L3A", "L3B"]
OLD_TOWERS = ["dardo", "pipoca", "lupa", "goma", "voltz", "maestro"]
NEW_TOWERS = ["escova", "lumi", "pula", "piao", "picole", "fofo"]
# o quadro de ação das torres de apoio chama "pulse" (Maestro e Fofo)
ACTION = {t: "fire" for t in OLD_TOWERS + NEW_TOWERS}
ACTION["maestro"] = "pulse"
ACTION["fofo"] = "pulse"
OLD_ENEMIES = ["fiapo", "corrisco", "bolota", "latinha", "nevoa", "remendo", "casulo", "brutamontes"]
OLD_BOSSES = ["aspirador", "rei_ferrugem", "breu"]
NEW_ENEMIES = ["migalha", "floquinho", "novelo", "traca"]
NEW_BOSSES = ["boneco_poeira", "esponjao", "meia", "traca_rainha"]
DISPLAY = {
    "migalha": "Migalha", "floquinho": "Floquinho", "novelo": "Novelo", "traca": "Traça",
    "boneco_poeira": "Boneco de Poeira", "esponjao": "Esponjão", "meia": "Meia Sem Par",
    "traca_rainha": "Traça Rainha",
}
# largura visível em células (a régua dos atuais: Fiapo 0,68, Bolota 1,1, Aspirador 1,8)
VISIBLE_CELLS = {
    "migalha": 0.55, "floquinho": 0.72, "novelo": 0.78, "traca": 0.82,
    "boneco_poeira": 1.5, "esponjao": 1.6, "meia": 1.4, "traca_rainha": 2.0,
}
# efeitos: tamanho do export (estouro e área em 256, projétil e sinal em 128)
FX_256 = {
    "pipoca_pop", "dust_poof_1", "dust_poof_2", "dust_poof_3", "build_puff", "upgrade_stars",
    "frost_burst", "whirl", "scrub_arc", "rust_flakes", "push", "boing", "goma_puddle",
}
MAPS = ["sotao", "oficina", "inverno", "cozinha", "quarto", "porao"]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def rel(path):
    return os.path.relpath(path, ROOT)


def load(path):
    return Image.open(os.path.join(ROOT, path)).convert("RGBA")


def bounds(im):
    return im.getchannel("A").point(lambda v: 255 if v >= ALPHA_THRESHOLD else 0).getbbox()


def feet_of(im, bbox):
    """Centro horizontal dos pixels opacos nas últimas 5% de linhas do conteúdo; linha de apoio."""
    l, t, r, b = bbox
    band_h = max(4, int((b - t) * 0.05))
    band = im.getchannel("A").crop((l, b - band_h, r, b)).point(lambda v: 255 if v >= ALPHA_THRESHOLD else 0)
    bb = band.getbbox()
    fx = l + (bb[0] + bb[2]) / 2 if bb else (l + r) / 2
    return (fx, float(b - 1))


def normalize(im, scale, feet, frame):
    w, h = im.size
    resized = im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    tx = ANCHOR[0] * frame - feet[0] * scale
    ty = ANCHOR[1] * frame - feet[1] * scale
    canvas = Image.new("RGBA", (frame, frame), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (round(tx), round(ty)))
    return canvas


def fit_scale(items, frame):
    """Maior escala em que todos os itens (bbox, pés) cabem na área segura com os pés no apoio."""
    margin = MARGIN * frame
    room_above = ANCHOR[1] * frame - margin
    room_below = (1 - ANCHOR[1]) * frame - margin
    half_left = ANCHOR[0] * frame - margin
    half_right = (1 - ANCHOR[0]) * frame - margin
    scale = float("inf")
    for (l, t, r, b), (fx, fy) in items:
        if fy - t > 0:
            scale = min(scale, room_above / (fy - t))
        if b - fy > 0:
            scale = min(scale, room_below / (b - fy))
        if fx - l > 0:
            scale = min(scale, half_left / (fx - l))
        if r - fx > 0:
            scale = min(scale, half_right / (r - fx))
    return scale


def clipped(canvas):
    bb = bounds(canvas)
    w, h = canvas.size
    return bb is None or bb[0] <= 0 or bb[1] <= 0 or bb[2] >= w or bb[3] >= h


def save(canvas, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    canvas.save(path, optimize=True)
    return {"file": rel(path), "width": canvas.size[0], "height": canvas.size[1], "sha256": sha256(path)}


def source_record(path):
    im = Image.open(os.path.join(ROOT, path))
    alpha = im.getchannel("A").getextrema() if im.mode == "RGBA" else None
    return {
        "sourceFile": path,
        "sourceSha256": sha256(os.path.join(ROOT, path)),
        "sourceWidth": im.size[0],
        "sourceHeight": im.size[1],
        "alpha": list(alpha) if alpha else None,
    }


def alignment(pose_im, pose_scale_to_1024, frame_im):
    """Desvio do quadro em relação à pose, no canvas normalizado de 1024 (só informação)."""
    pb = bounds(pose_im)
    fb = bounds(frame_im)
    k_pose = 1024 / pose_im.size[0]
    k_frame = 1024 / frame_im.size[0]
    pf = feet_of(pose_im, pb)
    ff = feet_of(frame_im, fb)
    return {
        "heightRatio": round(((fb[3] - fb[1]) * k_frame) / max(1, (pb[3] - pb[1]) * k_pose), 3),
        "widthRatio": round(((fb[2] - fb[0]) * k_frame) / max(1, (pb[2] - pb[0]) * k_pose), 3),
        "baselineDeltaPx1024": round(fb[3] * k_frame - pb[3] * k_pose, 1),
        "feetXDeltaPx1024": round(ff[0] * k_frame - pf[0] * k_pose, 1),
    }


# ---------------------------------------------------------------------------
# Torres
# ---------------------------------------------------------------------------
def tower_file(tower, state, action=None):
    suffix = f"_{action}" if action else ""
    return f"{PACK}/torres/tower_{tower}_{state}{suffix}_v001.png"


def export_tower_frame(manifest, key, src, im, scale, feet, tower, state, action, pose_im, family_scale512):
    src512 = normalize(im, scale, feet, 512)
    game128 = src512.resize((128, 128), Image.LANCZOS)
    record = {
        "category": "torres",
        "towerId": tower,
        "state": state,
        "action": action or "pose",
        **source_record(src),
        "familyScale512": round(family_scale512, 6),
        "appliedScale": round(scale, 6),
        "appliedFeet": [round(feet[0], 1), round(feet[1], 1)],
        "anchor": list(ANCHOR),
        "exports": {
            "source512": save(src512, os.path.join(OUT, "source512", f"{key}_512.png")),
            "game128": save(game128, os.path.join(OUT, "game", f"{key}_128.png")),
        },
        "clipped": clipped(src512),
    }
    nb = bounds(src512)
    record["normalizedBounds512"] = list(nb)
    record["contentHeight128"] = round((nb[3] - nb[1]) / 4, 1)
    if action is None:
        portrait = src512.resize((256, 256), Image.LANCZOS)
        record["exports"]["portrait256"] = save(portrait, os.path.join(OUT, "portraits", f"{key}_256.png"))
    else:
        record["alignmentToPose"] = alignment(pose_im, None, im)
    manifest[key] = record
    return game128


def export_towers(manifest, review_rows):
    old = json.load(open(os.path.join(OUT, "export_manifest.json")))["assets"]
    for tower in OLD_TOWERS + NEW_TOWERS:
        row = []
        poses = {}
        if tower in OLD_TOWERS:
            for state in STATES:
                m = old[f"tower_{tower}_{state}"]
                poses[state] = {
                    "im": load(m["sourceFile"]),
                    "scale": m["familyScale512"],
                    "feet": tuple(m["sourceFeet"]),
                    "file": m["sourceFile"],
                }
            family = old[f"tower_{tower}_L0"]["familyScale512"]
        else:
            items = []
            for state in STATES:
                path = tower_file(tower, state)
                im = load(path)
                bb = bounds(im)
                feet = feet_of(im, bb)
                poses[state] = {"im": im, "feet": feet, "file": path}
                items.append((bb, feet))
                for action in ("windup", ACTION[tower]):
                    fim = load(tower_file(tower, state, action))
                    items.append((bounds(fim), feet))
            family = fit_scale(items, 512)
            for state in STATES:
                poses[state]["scale"] = family
        for state in STATES:
            pose = poses[state]
            if tower in NEW_TOWERS:
                game = export_tower_frame(
                    manifest, f"tower_{tower}_{state}", pose["file"], pose["im"], pose["scale"], pose["feet"],
                    tower, state, None, None, family,
                )
            else:
                game = Image.open(os.path.join(OUT, "game", f"tower_{tower}_{state}_128.png")).convert("RGBA")
            row.append(game)
            for action in ("windup", ACTION[tower]):
                path = tower_file(tower, state, action)
                fim = load(path)
                k = pose["im"].size[0] / fim.size[0]
                scale = pose["scale"] * k
                feet = (pose["feet"][0] / k, pose["feet"][1] / k)
                row.append(
                    export_tower_frame(
                        manifest, f"tower_{tower}_{state}_{action}", path, fim, scale, feet, tower, state, action,
                        pose["im"], family,
                    )
                )
        review_rows.append((tower, row))


# ---------------------------------------------------------------------------
# Inimigos e chefes
# ---------------------------------------------------------------------------
def enemy_file(kind, entity, frame):
    folder = "chefes" if kind == "boss" else "inimigos"
    return f"{PACK}/{folder}/{kind}_{entity}_{frame}_v001.png"


def export_enemies(manifest, review_items):
    em = json.load(open(os.path.join(OUT, "enemy_export_manifest.json")))["assets"]
    for kind, entities, is_new in (
        ("enemy", OLD_ENEMIES, False), ("boss", OLD_BOSSES, False),
        ("enemy", NEW_ENEMIES, True), ("boss", NEW_BOSSES, True),
    ):
        frame_px = 256 if kind == "boss" else 128
        frames = ["walk_b", "ability"] if kind == "boss" else ["walk_b"]
        for entity in entities:
            if is_new:
                base_path = enemy_file(kind, entity, "base")
                base = load(base_path)
                bb = bounds(base)
                feet = feet_of(base, bb)
                items = [(bb, feet)] + [(bounds(load(enemy_file(kind, entity, f))), feet) for f in frames]
                scale = fit_scale(items, frame_px)
                canvas = normalize(base, scale, feet, frame_px)
                key = f"{kind}_{entity}_base"
                out = save(canvas, os.path.join(OUT, "bosses" if kind == "boss" else "enemies", f"{key}_{frame_px}.png"))
                cb = bounds(canvas)
                visible = VISIBLE_CELLS[entity]
                manifest[key] = {
                    "category": "chefes" if kind == "boss" else "inimigos",
                    "entityId": entity,
                    "entityType": kind,
                    "displayName": DISPLAY[entity],
                    "action": "base",
                    **source_record(base_path),
                    "appliedScale": round(scale, 6),
                    "appliedFeet": [round(feet[0], 1), round(feet[1], 1)],
                    "anchor": list(ANCHOR),
                    "exports": {"game": out},
                    "contentBoundsPx": list(cb),
                    "visibleWidthCells": visible,
                    "frameWidthCells": round(visible * frame_px / (cb[2] - cb[0]), 4),
                    "anchorRequiresReview": True,
                    "clipped": clipped(canvas),
                }
                review_items.append((key, canvas))
                pose_im = base
            else:
                base_key = f"{kind}_{entity}_base"
                b = em[base_key]
                pose_im = load(b["sourceFile"])
                w = pose_im.size[0]
                scale = b["scaleFromSource"]
                feet = (b["sourceAnchorUsed"][0] * w, b["sourceAnchorUsed"][1] * w)
                review_items.append((base_key, Image.open(os.path.join(ROOT, b["file"])).convert("RGBA")))
            for f in frames:
                path = enemy_file(kind, entity, f)
                fim = load(path)
                k = pose_im.size[0] / fim.size[0]
                canvas = normalize(fim, scale * k, (feet[0] / k, feet[1] / k), frame_px)
                key = f"{kind}_{entity}_{f}"
                out = save(canvas, os.path.join(OUT, "bosses" if kind == "boss" else "enemies", f"{key}_{frame_px}.png"))
                manifest[key] = {
                    "category": "chefes" if kind == "boss" else "inimigos",
                    "entityId": entity,
                    "entityType": kind,
                    "action": f,
                    **source_record(path),
                    "appliedScale": round(scale * k, 6),
                    "appliedFeet": [round(feet[0] / k, 1), round(feet[1] / k, 1)],
                    "anchor": list(ANCHOR),
                    "exports": {"game": out},
                    "alignmentToPose": alignment(pose_im, None, fim),
                    "clipped": clipped(canvas),
                }
                review_items.append((key, canvas))


# ---------------------------------------------------------------------------
# Farol, efeitos e cenas
# ---------------------------------------------------------------------------
def export_farol(manifest, review_items):
    base = json.load(open(os.path.join(OUT, "export_manifest.json")))["assets"]["base_farol_pilha"]
    pose_im = load(base["sourceFile"])
    review_items.append(("base_farol_pilha", Image.open(os.path.join(ROOT, base["exports"]["prop256"]["file"])).convert("RGBA")))
    for stage in ("danificado", "critico"):
        path = f"{PACK}/farol/base_farol_pilha_{stage}_v001.png"
        im = load(path)
        k = pose_im.size[0] / im.size[0]
        feet = (base["sourceFeet"][0] / k, base["sourceFeet"][1] / k)
        canvas = normalize(im, base["scale256"] * k, feet, 256)
        key = f"base_farol_pilha_{stage}"
        manifest[key] = {
            "category": "cenario",
            "action": stage,
            **source_record(path),
            "appliedScale": round(base["scale256"] * k, 6),
            "appliedFeet": [round(feet[0], 1), round(feet[1], 1)],
            "anchor": list(ANCHOR),
            "exports": {"prop256": save(canvas, os.path.join(OUT, "props", f"{key}_256.png"))},
            "alignmentToPose": alignment(pose_im, None, im),
            "clipped": clipped(canvas),
        }
        review_items.append((key, canvas))


def export_fx(manifest, review_items):
    folder = os.path.join(ROOT, PACK, "efeitos")
    for name in sorted(os.listdir(folder)):
        if not name.endswith("_v001.png"):
            continue
        fx = name[len("fx_") : -len("_v001.png")]
        path = f"{PACK}/efeitos/{name}"
        im = load(path)
        bb = bounds(im)
        size = 256 if fx in FX_256 else 128
        cw, ch = bb[2] - bb[0], bb[3] - bb[1]
        scale = (size * (1 - 2 * MARGIN)) / max(cw, ch)
        crop = im.crop(bb).resize((max(1, round(cw * scale)), max(1, round(ch * scale))), Image.LANCZOS)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.alpha_composite(crop, ((size - crop.size[0]) // 2, (size - crop.size[1]) // 2))
        key = f"fx_{fx}"
        manifest[key] = {
            "category": "efeitos",
            "action": fx,
            **source_record(path),
            "sourceBounds": list(bb),
            "anchor": [0.5, 0.5],
            # projétil aponta para a direita: o jogo gira em torno do centro
            "pointsRight": fx in ("dardo_dart", "pipoca_kernel", "goma_blob", "lupa_glint", "burn_spark", "frost_burst", "push", "scrub_arc"),
            "exports": {"fx": save(canvas, os.path.join(OUT, "fx", f"{key}_{size}.png"))},
            "clipped": False,
        }
        review_items.append((key, canvas))


def export_scenes(manifest):
    overrides = json.load(open(os.path.join(OUT, "map_scene_overrides.json")))
    for map_id in MAPS:
        path = f"{PACK}/mapas/map_{map_id}_scene_v001.png"
        im = load(path)
        w, h = im.size
        up = im.resize((1024, round(1024 * h / w)), Image.LANCZOS)
        out = save(up, os.path.join(OUT, "scenes", f"map_{map_id}_scene_{up.size[0]}x{up.size[1]}.png"))
        scene = overrides["scenes"].get(map_id, {})
        # cor média do campo jogável: fundo sólido atrás da arte quando a janela é mais larga
        rect = scene.get("playRect")
        if rect:
            box = (int(rect[0] * w), int(rect[1] * h), int(rect[2] * w), int(rect[3] * h))
            small = im.crop(box).resize((32, 20))
        else:
            small = im.resize((32, 20))
        px = list(small.getdata())
        avg = [sum(p[i] for p in px) // len(px) for i in range(3)]
        manifest[f"map_{map_id}_scene"] = {
            "category": "mapas",
            "mapId": map_id,
            "action": "scene",
            **source_record(path),
            "exports": {"upload": out},
            "backingColor": avg,
            "clipped": False,
        }


# ---------------------------------------------------------------------------
# Pranchas de revisão
# ---------------------------------------------------------------------------
def tower_sheets(rows):
    """Duas réguas: 96 px (computador) e 48 px (celular, ~1,6 célula de 30 px)."""
    for px, name in ((96, "desktop"), (48, "mobile")):
        cell = px + 8
        cols = 15
        sheet = Image.new("RGBA", (cols * cell + 70, len(rows) * cell), (98, 140, 120, 255))
        d = ImageDraw.Draw(sheet)
        for r, (tower, imgs) in enumerate(rows):
            d.text((4, r * cell + 4), tower, fill=(255, 255, 255, 255))
            for c, img in enumerate(imgs):
                x = 70 + c * cell
                y = r * cell
                if c % 3 == 0:
                    d.rectangle((x, y, x + cell * 3 - 2, y + cell - 2), outline=(25, 40, 63, 255))
                small = img.resize((px, px), Image.LANCZOS)
                sheet.alpha_composite(small, (x + 4, y + 4))
                base_y = y + 4 + round(ANCHOR[1] * px)
                d.line((x + 2, base_y, x + cell - 4, base_y), fill=(182, 62, 72, 160))
        sheet.convert("RGB").save(os.path.join(OUT, f"review_v2_towers_{name}.png"))


def item_sheet(items, path, bg, cell=140):
    cols = 8
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 14)), bg)
    d = ImageDraw.Draw(sheet)
    for i, (key, img) in enumerate(items):
        x = (i % cols) * cell
        y = (i // cols) * (cell + 14)
        sheet.alpha_composite(img.resize((cell - 12, cell - 12), Image.LANCZOS), (x + 6, y + 2))
        d.text((x + 3, y + cell - 8), key[:24], fill=(255, 255, 255, 255) if bg[0] < 128 else (25, 40, 63, 255))
    sheet.convert("RGB").save(path)


def main():
    manifest = {}
    tower_rows = []
    enemy_items = []
    prop_items = []
    fx_items = []
    export_towers(manifest, tower_rows)
    export_enemies(manifest, enemy_items)
    export_farol(manifest, prop_items)
    export_fx(manifest, fx_items)
    export_scenes(manifest)
    tower_sheets(tower_rows)
    item_sheet(enemy_items, os.path.join(OUT, "review_v2_enemies_light.png"), (236, 232, 220, 255))
    item_sheet(enemy_items, os.path.join(OUT, "review_v2_enemies_dark.png"), (20, 32, 47, 255))
    item_sheet(prop_items + fx_items, os.path.join(OUT, "review_v2_fx.png"), (60, 70, 90, 255))
    sources = {m["sourceFile"] for m in manifest.values()}
    doc = {
        "generatedBy": "tools/export_order_v2.py",
        "sourcePack": PACK,
        "anchor": list(ANCHOR),
        "alphaThreshold": ALPHA_THRESHOLD,
        "note": (
            "Exports da encomenda v2. Quadros (windup, fire, pulse, walk_b, ability) usam a "
            "transformação da pose do mesmo estado; alignmentToPose só informa o desvio desenhado. "
            "Não são atlas: cada quadro é uma imagem própria."
        ),
        "sourceCount": len(sources),
        "assets": dict(sorted(manifest.items())),
    }
    with open(os.path.join(OUT, "order_v2_manifest.json"), "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")
    clipped_keys = sorted(k for k, v in manifest.items() if v.get("clipped"))
    print(f"{len(manifest)} exports de {len(sources)} fontes; recortados: {clipped_keys or 'nenhum'}")
    if len(sources) != 215:
        print("ERRO: esperadas 215 fontes da encomenda")
        sys.exit(1)


if __name__ == "__main__":
    main()
