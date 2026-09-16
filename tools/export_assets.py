#!/usr/bin/env python3
"""Gera exports normalizados dos 40 PNGs originais (que são preservados intactos).

- Torres: escala uniforme por família (5 estados), pés alinhados em (0.5, 0.82) de um quadro quadrado.
  Fonte normalizada 512x512 (assets/export/source512) e export de jogo 128x128 (assets/export/game).
  Retratos 256x256 para coleção (assets/export/portraits).
- Cenário e base: quadro 256x256 com o mesmo apoio (0.5, 0.82) e escala por arquivo.
- Terrenos: master 1600x1000 (16:10) e variante de upload 1024x640 (limite de textura do Roblox).
- Escreve assets/export/export_manifest.json e uma prancha de revisão (assets/export/review_*.png).
"""
import hashlib
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
INDEX = os.path.join(ROOT, "asset_index.json")
OUT = os.path.join(ROOT, "assets", "export")
ANCHOR = (0.5, 0.82)
ALPHA_THRESHOLD = 128
TOWER_ORDER = ["dardo", "pipoca", "lupa", "goma", "voltz", "maestro"]
STATES = ["L0", "L1", "L2", "L3A", "L3B"]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def content_bounds(im):
    a = im.getchannel("A").point(lambda v: 255 if v >= ALPHA_THRESHOLD else 0)
    return a.getbbox()  # (l, t, r, b) exclusivo em r/b


def feet_x(im, bbox):
    """Centro horizontal dos pixels opacos nas últimas 5% de linhas do conteúdo (região dos pés)."""
    l, t, r, b = bbox
    band_h = max(4, int((b - t) * 0.05))
    a = im.getchannel("A").crop((l, b - band_h, r, b))
    px = a.load()
    xs = []
    w, h = a.size
    for y in range(h):
        for x in range(w):
            if px[x, y] >= ALPHA_THRESHOLD:
                xs.append(x)
    if not xs:
        return (l + r) / 2
    return l + (min(xs) + max(xs)) / 2


def normalize(im, scale, feet, frame):
    """Aplica escala uniforme e translação para levar `feet` (x, y na fonte) até ANCHOR*frame."""
    w, h = im.size
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    resized = im.resize((nw, nh), Image.LANCZOS)
    tx = ANCHOR[0] * frame - feet[0] * scale
    ty = ANCHOR[1] * frame - feet[1] * scale
    canvas = Image.new("RGBA", (frame, frame), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (round(tx), round(ty)))
    return canvas


def fit_scale_for_family(entries, frame, margin_frac=0.0625):
    """Escala uniforme (fonte->frame) que faz todos os estados caberem na área segura."""
    safe = frame * (1 - 2 * margin_frac)
    top_room = ANCHOR[1] * frame - margin_frac * frame
    bottom_room = (1 - ANCHOR[1]) * frame - margin_frac * frame
    half = safe / 2
    scale = float("inf")
    for e in entries:
        l, t, r, b = e["bbox"]
        fx, fy = e["feet"]
        above = fy - t
        below = b - fy
        left = fx - l
        right = r - fx
        scale = min(scale, top_room / max(above, 1), (bottom_room + 1e-9) / max(below, 1e-9) if below > 0 else scale,
                    half / max(left, 1), half / max(right, 1))
    return scale


def export_towers(index, manifest):
    towers = [a for a in index["assets"] if a["category"] == "torres"]
    by_family = {}
    for a in towers:
        im = Image.open(os.path.join(ROOT, a["sourceFile"])).convert("RGBA")
        bbox = content_bounds(im)
        fx = feet_x(im, bbox)
        fy = bbox[3] - 1
        by_family.setdefault(a["towerId"], []).append({"asset": a, "im": im, "bbox": bbox, "feet": (fx, fy)})
    review = Image.new("RGBA", (5 * 160, 6 * 160), (47, 183, 160, 255))
    draw = ImageDraw.Draw(review)
    for fi, family in enumerate(TOWER_ORDER):
        entries = sorted(by_family[family], key=lambda e: STATES.index(e["asset"]["state"]))
        scale512 = fit_scale_for_family(entries, 512)
        for si, e in enumerate(entries):
            a = e["asset"]
            src512 = normalize(e["im"], scale512, e["feet"], 512)
            game128 = src512.resize((128, 128), Image.LANCZOS)
            portrait256 = src512.resize((256, 256), Image.LANCZOS)
            key = a["assetKey"]
            p512 = os.path.join(OUT, "source512", f"{key}_512.png")
            p128 = os.path.join(OUT, "game", f"{key}_128.png")
            p256 = os.path.join(OUT, "portraits", f"{key}_256.png")
            for p in (p512, p128, p256):
                os.makedirs(os.path.dirname(p), exist_ok=True)
            src512.save(p512, optimize=True)
            game128.save(p128, optimize=True)
            portrait256.save(p256, optimize=True)
            nb = content_bounds(src512)
            clipped = nb[0] <= 0 or nb[1] <= 0 or nb[2] >= 512 or nb[3] >= 512
            manifest[key] = {
                "category": "torres", "towerId": family, "state": a["state"],
                "sourceFile": a["sourceFile"], "sourceSha256": a["sha256"],
                "sourceBounds": list(e["bbox"]), "sourceFeet": [round(e["feet"][0], 1), round(e["feet"][1], 1)],
                "familyScale512": round(scale512, 6),
                "exports": {
                    "source512": {"file": os.path.relpath(p512, ROOT), "width": 512, "height": 512, "sha256": sha256(p512)},
                    "game128": {"file": os.path.relpath(p128, ROOT), "width": 128, "height": 128, "sha256": sha256(p128)},
                    "portrait256": {"file": os.path.relpath(p256, ROOT), "width": 256, "height": 256, "sha256": sha256(p256)},
                },
                "anchor": list(ANCHOR), "normalizedBounds512": list(nb), "clipped": clipped,
                "contentHeight128": round((nb[3] - nb[1]) / 4, 1), "contentWidth128": round((nb[2] - nb[0]) / 4, 1),
            }
            # prancha de revisão: célula 60 px (escala 960x600) com sprite de 96 px e cruz no apoio
            ox, oy = si * 160, fi * 160
            cell = 60
            cx, cy = ox + 80, oy + 100
            draw.rectangle((cx - cell // 2, cy - cell // 2, cx + cell // 2, cy + cell // 2), outline=(25, 40, 63, 255), width=1)
            sprite = game128.resize((96, 96), Image.LANCZOS)
            review.alpha_composite(sprite, (int(cx - 48), int(cy - 0.82 * 96)))
            draw.line((cx - 6, cy, cx + 6, cy), fill=(182, 62, 72, 255), width=1)
            draw.line((cx, cy - 6, cx, cy + 6), fill=(182, 62, 72, 255), width=1)
            draw.text((ox + 4, oy + 4), key, fill=(25, 40, 63, 255))
    review.convert("RGB").save(os.path.join(OUT, "review_towers.png"))


def export_props(index, manifest):
    props = [a for a in index["assets"] if a["category"] == "cenario"]
    review = Image.new("RGBA", (7 * 160, 180), (255, 243, 214, 255))
    draw = ImageDraw.Draw(review)
    for i, a in enumerate(props):
        im = Image.open(os.path.join(ROOT, a["sourceFile"])).convert("RGBA")
        bbox = content_bounds(im)
        fx = (bbox[0] + bbox[2]) / 2  # props são simétricos o bastante; centro do conteúdo
        fy = bbox[3] - 1
        entry = {"bbox": bbox, "feet": (fx, fy)}
        scale = fit_scale_for_family([entry], 256)
        out = normalize(im, scale, (fx, fy), 256)
        key = a["assetKey"]
        p = os.path.join(OUT, "props", f"{key}_256.png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        out.save(p, optimize=True)
        nb = content_bounds(out)
        manifest[key] = {
            "category": "cenario", "sourceFile": a["sourceFile"], "sourceSha256": a["sha256"],
            "sourceBounds": list(bbox), "sourceFeet": [round(fx, 1), round(fy, 1)], "scale256": round(scale, 6),
            "exports": {"prop256": {"file": os.path.relpath(p, ROOT), "width": 256, "height": 256, "sha256": sha256(p)}},
            "anchor": list(ANCHOR), "normalizedBounds256": list(nb),
            "clipped": nb[0] <= 0 or nb[1] <= 0 or nb[2] >= 256 or nb[3] >= 256,
        }
        ox = i * 160
        review.alpha_composite(out.resize((128, 128), Image.LANCZOS), (ox + 16, 30))
        draw.text((ox + 4, 4), key, fill=(25, 40, 63, 255))
    review.convert("RGB").save(os.path.join(OUT, "review_props.png"))


def export_grounds(index, manifest):
    grounds = [a for a in index["assets"] if a["category"] == "fases"]
    for a in grounds:
        im = Image.open(os.path.join(ROOT, a["sourceFile"])).convert("RGBA")
        w, h = im.size
        # cobrir 16:10 e recortar o excedente centralizado (diferença original 1586x992 ~ 0.08%)
        target_w, target_h = 1600, 1000
        scale = max(target_w / w, target_h / h)
        rs = im.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
        left = (rs.width - target_w) // 2
        top = (rs.height - target_h) // 2
        master = rs.crop((left, top, left + target_w, top + target_h))
        key = a["assetKey"]
        pm = os.path.join(OUT, "grounds", f"{key}_1600x1000.png")
        pu = os.path.join(OUT, "grounds", f"{key}_1024x640.png")
        os.makedirs(os.path.dirname(pm), exist_ok=True)
        master.save(pm, optimize=True)
        master.resize((1024, 640), Image.LANCZOS).save(pu, optimize=True)
        # cor média do piso para o fundo sólido sob a margem transparente
        small = master.resize((64, 40))
        px = [p for p in small.getdata() if p[3] > 250]
        avg = tuple(sum(c[i] for c in px) // len(px) for i in range(3)) if px else (0, 0, 0)
        manifest[key] = {
            "category": "fases", "sourceFile": a["sourceFile"], "sourceSha256": a["sha256"],
            "exports": {
                "master1600": {"file": os.path.relpath(pm, ROOT), "width": 1600, "height": 1000, "sha256": sha256(pm)},
                "upload1024": {"file": os.path.relpath(pu, ROOT), "width": 1024, "height": 640, "sha256": sha256(pu)},
            },
            "anchor": [0.5, 0.5], "backingColor": list(avg), "coverScale": round(scale, 6), "crop": [left, top],
        }


def main():
    index = json.load(open(INDEX))
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    export_towers(index, manifest)
    export_props(index, manifest)
    export_grounds(index, manifest)
    doc = {
        "schemaVersion": 1,
        "generatedBy": "tools/export_assets.py",
        "anchorConvention": "pés/apoio em (0.5, 0.82) de um quadro quadrado; escala uniforme por família de torre",
        "alphaThreshold": ALPHA_THRESHOLD,
        "assets": dict(sorted(manifest.items())),
    }
    with open(os.path.join(OUT, "export_manifest.json"), "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
    clipped = [k for k, v in manifest.items() if v.get("clipped")]
    print(f"exportados {len(manifest)} assets; recortados: {clipped or 'nenhum'}")
    for fam in TOWER_ORDER:
        e = manifest[f"tower_{fam}_L0"]
        hs = [manifest[f"tower_{fam}_{s}"]["contentHeight128"] for s in STATES]
        ws = [manifest[f"tower_{fam}_{s}"]["contentWidth128"] for s in STATES]
        print(f"  {fam}: escala512={e['familyScale512']} alturas128={hs} larguras128={ws}")
    if clipped:
        sys.exit(1)


if __name__ == "__main__":
    main()
