#!/usr/bin/env python3
"""Gera exports normalizados dos 11 PNGs de inimigos e chefes (os originais são preservados).

- Inimigos: quadro 128x128; chefes: quadro 256x256. Apoio em (0.5, 0.82) do quadro.
- Escala por arquivo: o conteúdo (alpha >= 128) cabe na área segura sem cortar detalhes; o alpha
  original é preservado (nada é recortado, só transladado e reescalado).
- Calcula frameWidthCells a partir de suggestedVisibleWidthCells (enemy_visuals.json) e da fração
  realmente ocupada pelo conteúdo no quadro exportado, para que a largura visível em células
  corresponda ao pedido no guia sem confundir margem transparente com corpo.
- Escreve assets/export/enemy_export_manifest.json e pranchas de revisão em fundo claro e escuro.

Uso: python3 tools/export_enemy_assets.py
"""
import hashlib
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PACK = os.path.join(ROOT, "Assets_Inimigos_Bosses_v1")
MANIFEST = os.path.join(PACK, "manifesto_inimigos_bosses.json")
VISUALS = os.path.join(PACK, "enemy_visuals.json")
OUT = os.path.join(ROOT, "assets", "export")
ANCHOR = (0.5, 0.82)
ALPHA_THRESHOLD = 128
MARGIN_FRAC = 0.0625
ENEMY_FRAME = 128
BOSS_FRAME = 256


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def content_bounds(im):
    a = im.getchannel("A").point(lambda v: 255 if v >= ALPHA_THRESHOLD else 0)
    return a.getbbox()


def measured_feet(im, bbox):
    """Centro horizontal dos pixels opacos na faixa inferior do conteúdo, e a linha de apoio."""
    l, t, r, b = bbox
    band_h = max(4, int((b - t) * 0.05))
    a = im.getchannel("A").crop((l, b - band_h, r, b))
    px = a.load()
    w, h = a.size
    xs = []
    for y in range(h):
        for x in range(w):
            if px[x, y] >= ALPHA_THRESHOLD:
                xs.append(x)
    fx = (l + r) / 2 if not xs else l + (min(xs) + max(xs)) / 2
    return (fx, float(b))


def suggested_feet(asset, size):
    """Âncora sugerida pelo autor da arte (manifesto), em pixels da fonte.

    O manifesto marca anchorRequiresReview: Névoa flutua e usa apoio virtual, Corrisco tem rastro
    desenhado na silhueta, então o centro do corpo não coincide com o centro do conteúdo.
    """
    ax, ay = asset["sourceAnchorSuggested"]
    w, h = size
    return (ax * w, ay * h)


def fit_scale(bbox, feet, frame):
    """Maior escala que mantém o conteúdo dentro da área segura, com o apoio em ANCHOR."""
    l, t, r, b = bbox
    fx, fy = feet
    margin = MARGIN_FRAC * frame
    safe_w = frame - 2 * margin
    above = fy - t
    below = b - fy
    left = fx - l
    right = r - fx
    room_above = ANCHOR[1] * frame - margin
    room_below = (1 - ANCHOR[1]) * frame - margin
    room_left = ANCHOR[0] * frame - margin
    room_right = (1 - ANCHOR[0]) * frame - margin
    limits = [safe_w / max(1e-6, r - l)]
    if above > 0:
        limits.append(room_above / above)
    if below > 0:
        limits.append(room_below / below)
    if left > 0:
        limits.append(room_left / left)
    if right > 0:
        limits.append(room_right / right)
    return min(limits)


def normalize(im, scale, feet, frame):
    w, h = im.size
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    resized = im.resize((nw, nh), Image.LANCZOS)
    tx = ANCHOR[0] * frame - feet[0] * scale
    ty = ANCHOR[1] * frame - feet[1] * scale
    canvas = Image.new("RGBA", (frame, frame), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (round(tx), round(ty)))
    return canvas


def sheet(entries, path, background, label_color):
    cols = 4
    cell = 200
    rows = (len(entries) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell, rows * cell + 28), background)
    draw = ImageDraw.Draw(img)
    draw.text((8, 8), os.path.basename(path), fill=label_color)
    for i, e in enumerate(entries):
        cx = (i % cols) * cell
        cy = (i // cols) * cell + 28
        src = Image.open(os.path.join(ROOT, e["file"])).convert("RGBA")
        src = src.resize((cell - 40, cell - 40), Image.LANCZOS)
        img.alpha_composite(src, (cx + 20, cy + 10))
        # linha de apoio real do quadro (0.82)
        y = cy + 10 + round((cell - 40) * ANCHOR[1])
        draw.line([(cx + 10, y), (cx + cell - 10, y)], fill=(255, 120, 120, 200))
        draw.text((cx + 8, cy + cell - 18), e["entityId"], fill=label_color)
    img.convert("RGB").save(path)


def main():
    if not os.path.exists(MANIFEST):
        print("ERRO: falta", MANIFEST)
        sys.exit(1)
    manifest = json.load(open(MANIFEST))
    visuals = json.load(open(VISUALS))["entities"]
    os.makedirs(os.path.join(OUT, "enemies"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "bosses"), exist_ok=True)

    out_assets = {}
    listed = []
    for asset in manifest["assets"]:
        key = asset["assetKey"]
        entity = asset["entityId"]
        is_boss = asset["entityType"] == "boss"
        frame = BOSS_FRAME if is_boss else ENEMY_FRAME
        src_path = os.path.join(PACK, asset["localFile"])
        im = Image.open(src_path).convert("RGBA")
        bbox = content_bounds(im)
        if bbox is None:
            print("ERRO: imagem sem conteúdo opaco:", key)
            sys.exit(1)
        feet = suggested_feet(asset, im.size)
        mfx, mfy = measured_feet(im, bbox)
        scale = fit_scale(bbox, feet, frame)
        canvas = normalize(im, scale, feet, frame)
        out_bbox = content_bounds(canvas)
        content_w = out_bbox[2] - out_bbox[0]
        content_h = out_bbox[3] - out_bbox[1]
        sub = "bosses" if is_boss else "enemies"
        rel = f"{sub}/{key}_{frame}.png"
        dest = os.path.join(OUT, rel)
        canvas.save(dest)

        vis = visuals.get(entity, {})
        visible_cells = vis.get("suggestedVisibleWidthCells") or asset["suggestedVisibleWidthCells"]
        frame_cells = round(visible_cells * frame / content_w, 4)
        record = {
            "assetKey": key,
            "entityId": entity,
            "entityType": asset["entityType"],
            "displayName": asset["displayName"],
            "category": "inimigos" if not is_boss else "bosses",
            "sourceFile": asset["sourceFile"],
            "sourceSha256": asset["sha256"],
            "file": f"assets/export/{rel}",
            "sha256": sha256(dest),
            "width": frame,
            "height": frame,
            "scaleFromSource": round(scale, 6),
            "anchor": [ANCHOR[0], ANCHOR[1]],
            "sourceAnchorUsed": asset["sourceAnchorSuggested"],
            "sourceAnchorMeasured": [round(mfx / im.size[0], 4), round(mfy / im.size[1], 4)],
            "anchorRequiresReview": True,
            "contentBoundsPx": list(out_bbox),
            "contentWidthPx": content_w,
            "contentHeightPx": content_h,
            "visibleWidthCells": visible_cells,
            "frameWidthCells": frame_cells,
            "renderMode": "single_static",
            "frameCount": 1,
            "drawnAnimationStatus": "not_produced",
        }
        out_assets[key] = record
        listed.append(record)
        print(
            f"{key:24s} quadro {frame:3d}  conteúdo {content_w:3d}x{content_h:3d}px  "
            f"escala {scale:.4f}  visível {visible_cells} células -> quadro {frame_cells} células"
        )

    sheet(listed, os.path.join(OUT, "review_enemies_light.png"), (236, 232, 220, 255), (40, 40, 40, 255))
    sheet(listed, os.path.join(OUT, "review_enemies_dark.png"), (20, 32, 47, 255), (230, 230, 230, 255))

    out = {
        "generatedBy": "tools/export_enemy_assets.py",
        "sourcePack": "Assets_Inimigos_Bosses_v1",
        "anchor": list(ANCHOR),
        "alphaThreshold": ALPHA_THRESHOLD,
        "note": (
            "Exports normalizados das 11 poses estáticas. frameWidthCells é a largura do quadro "
            "quadrado em células do tabuleiro para que a largura visível corresponda a "
            "visibleWidthCells. Não são atlas: frameCount = 1."
        ),
        "assets": out_assets,
    }
    path = os.path.join(OUT, "enemy_export_manifest.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"\n{len(listed)} exports gerados; manifesto em {path}")
    print("pranchas: assets/export/review_enemies_light.png e review_enemies_dark.png")


if __name__ == "__main__":
    main()
