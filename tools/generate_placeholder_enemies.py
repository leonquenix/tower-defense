#!/usr/bin/env python3
"""Gera sprites PROVISÓRIOS dos oito inimigos e três chefes (128x128 / 256x256), identificados como placeholder.

Os sprites finais (96 + 48 quadros) ainda precisam de produção artística. Estes desenhos procedurais
seguem a paleta (enemy #7D63B8, ink #19283F) e as silhuetas descritas na direção de arte para permitir
leitura em jogo. Saída: assets/export/placeholders/enemy_<id>_placeholder_128.png e boss_<id>_placeholder_256.png.
"""
import json
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "export", "placeholders")
INK = (25, 40, 63, 255)
ENEMY = (125, 99, 184, 255)
ENEMY_DARK = (96, 74, 150, 255)
ENEMY_LIGHT = (160, 138, 210, 255)
EYE = (240, 240, 255, 255)
PUPIL = (25, 40, 63, 255)
TIN = (176, 184, 196, 255)
TIN_DARK = (120, 128, 140, 255)
CORAL = (255, 119, 94, 255)
GOLD = (255, 200, 87, 255)
CREAM = (255, 243, 214, 255)
SCALE = 4  # desenha em 4x e reduz (antialias)


def canvas(size):
    return Image.new("RGBA", (size * SCALE, size * SCALE), (0, 0, 0, 0))


def finish(im, size, name):
    out = im.resize((size, size), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    out.save(path, optimize=True)
    return os.path.relpath(path, ROOT)


def eyes(d, cx, cy, spacing, r, pupil_r=None, glow=EYE):
    pupil_r = pupil_r or r * 0.5
    for sx in (-1, 1):
        x = cx + sx * spacing
        d.ellipse((x - r, cy - r, x + r, cy + r), fill=glow, outline=INK, width=int(1.5 * SCALE))
        d.ellipse((x - pupil_r, cy - pupil_r, x + pupil_r, cy + pupil_r), fill=PUPIL)


def blob(d, box, fill=ENEMY, outline=INK, width=None):
    d.ellipse(box, fill=fill, outline=outline, width=width or int(3 * SCALE))


def shadow(d, cx, cy, rx, ry):
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(25, 40, 63, 70))


def S(v):
    return v * SCALE


def draw_fiapo(d):  # pequena bola violeta com dois olhos, saltos curtos
    shadow(d, S(64), S(104), S(22), S(6))
    blob(d, (S(34), S(44), S(94), S(102)))
    # fiapos soltos
    for ang in (200, 250, 300, 340):
        x = S(64) + math.cos(math.radians(ang)) * S(30)
        y = S(72) + math.sin(math.radians(ang)) * S(28)
        d.line((x, y, x + math.cos(math.radians(ang)) * S(8), y + math.sin(math.radians(ang)) * S(8)), fill=INK, width=int(2.5 * SCALE))
    eyes(d, S(64), S(70), S(12), S(7))


def draw_corrisco(d):  # gota estreita com rastro curto, corrida inclinada
    shadow(d, S(60), S(104), S(20), S(5))
    d.polygon([(S(96), S(70)), (S(70), S(46)), (S(40), S(56)), (S(28), S(80)), (S(44), S(100)), (S(74), S(96))], fill=ENEMY, outline=INK)
    d.line([(S(96), S(70)), (S(70), S(46)), (S(40), S(56)), (S(28), S(80)), (S(44), S(100)), (S(74), S(96)), (S(96), S(70))], fill=INK, width=int(3 * SCALE), joint="curve")
    for i in range(3):
        d.line((S(20 - i * 6), S(70 + i * 8), S(8 - i * 4), S(72 + i * 8)), fill=ENEMY_LIGHT, width=int(3 * SCALE))
    eyes(d, S(66), S(74), S(9), S(6))


def draw_bolota(d):  # corpo redondo largo e pesado
    shadow(d, S(64), S(108), S(34), S(7))
    blob(d, (S(18), S(34), S(110), S(106)), fill=ENEMY_DARK)
    blob(d, (S(30), S(44), S(98), S(94)), fill=ENEMY, outline=None, width=0)
    eyes(d, S(64), S(66), S(15), S(8))
    d.arc((S(52), S(74), S(76), S(92)), 20, 160, fill=INK, width=int(2.5 * SCALE))


def draw_latinha(d):  # poeira dentro de lata quadrada, escudo visível
    shadow(d, S(64), S(108), S(28), S(6))
    d.rounded_rectangle((S(30), S(38), S(98), S(104)), radius=S(8), fill=TIN, outline=INK, width=int(3 * SCALE))
    d.rectangle((S(30), S(50), S(98), S(56)), fill=TIN_DARK)
    d.rectangle((S(30), S(86), S(98), S(92)), fill=TIN_DARK)
    blob(d, (S(46), S(20), S(84), S(50)), fill=ENEMY)
    eyes(d, S(65), S(36), S(9), S(5))
    # escudo pequeno
    d.polygon([(S(96), S(60)), (S(112), S(66)), (S(110), S(84)), (S(96), S(92)), (S(82), S(84)), (S(80), S(66))], fill=CREAM, outline=INK)


def draw_nevoa(d):  # espiral achatada com borda pontilhada
    shadow(d, S(64), S(104), S(30), S(5))
    d.ellipse((S(14), S(52), S(114), S(100)), fill=(125, 99, 184, 200), outline=INK, width=int(3 * SCALE))
    for i in range(14):
        ang = i * 360 / 14
        x = S(64) + math.cos(math.radians(ang)) * S(56)
        y = S(76) + math.sin(math.radians(ang)) * S(30)
        d.ellipse((x - S(3), y - S(3), x + S(3), y + S(3)), fill=INK)
    # espiral
    pts = []
    for t in range(0, 720, 15):
        r = S(4) + t / 720 * S(26)
        pts.append((S(64) + math.cos(math.radians(t)) * r, S(76) + math.sin(math.radians(t)) * r * 0.5))
    d.line(pts, fill=ENEMY_LIGHT, width=int(2.5 * SCALE))
    eyes(d, S(64), S(72), S(12), S(6))


def draw_remendo(d):  # saquinho com costura em cruz
    shadow(d, S(64), S(108), S(26), S(6))
    d.rounded_rectangle((S(30), S(34), S(98), S(106)), radius=S(18), fill=ENEMY, outline=INK, width=int(3 * SCALE))
    d.rectangle((S(52), S(18), S(76), S(40)), fill=ENEMY_DARK, outline=INK, width=int(3 * SCALE))
    # remendo com costura
    d.rounded_rectangle((S(60), S(70), S(92), S(98)), radius=S(4), fill=CORAL, outline=INK, width=int(2 * SCALE))
    d.line((S(64), S(84), S(88), S(84)), fill=INK, width=int(2 * SCALE))
    d.line((S(76), S(74), S(76), S(94)), fill=INK, width=int(2 * SCALE))
    eyes(d, S(56), S(58), S(11), S(6))


def draw_casulo(d):  # casca oval rachada
    shadow(d, S(64), S(110), S(24), S(6))
    d.ellipse((S(34), S(18), S(94), S(108)), fill=ENEMY_DARK, outline=INK, width=int(3 * SCALE))
    d.line([(S(64), S(20)), (S(58), S(40)), (S(70), S(56)), (S(60), S(76)), (S(68), S(96))], fill=ENEMY_LIGHT, width=int(3 * SCALE), joint="curve")
    eyes(d, S(64), S(64), S(10), S(5), glow=(200, 190, 255, 255))


def draw_brutamontes(d):  # corpo largo e dois braços de pano, ombros altos
    shadow(d, S(64), S(112), S(40), S(7))
    d.rounded_rectangle((S(22), S(30), S(106), S(108)), radius=S(22), fill=ENEMY_DARK, outline=INK, width=int(3 * SCALE))
    d.rounded_rectangle((S(4), S(44), S(30), S(100)), radius=S(10), fill=ENEMY, outline=INK, width=int(3 * SCALE))
    d.rounded_rectangle((S(98), S(44), S(124), S(100)), radius=S(10), fill=ENEMY, outline=INK, width=int(3 * SCALE))
    eyes(d, S(64), S(60), S(16), S(8))
    d.line((S(50), S(84), S(78), S(84)), fill=INK, width=int(3 * SCALE))


def draw_aspirador(d):  # corpo oval, mangueira e cara irritada
    shadow(d, S(128), S(220), S(70), S(12))
    d.ellipse((S(50), S(80), S(210), S(220)), fill=ENEMY_DARK, outline=INK, width=int(5 * SCALE))
    d.ellipse((S(66), S(96), S(194), S(190)), fill=ENEMY, outline=None)
    # mangueira
    pts = [(S(200), S(120)), (S(230), S(90)), (S(236), S(50)), (S(210), S(30))]
    d.line(pts, fill=INK, width=int(16 * SCALE), joint="curve")
    d.line(pts, fill=TIN, width=int(10 * SCALE), joint="curve")
    d.ellipse((S(194), S(16), S(226), S(48)), fill=TIN_DARK, outline=INK, width=int(4 * SCALE))
    # rodinhas
    for x in (S(84), S(176)):
        d.ellipse((x - S(16), S(200), x + S(16), S(232)), fill=INK)
    # olhos irritados
    eyes(d, S(128), S(140), S(30), S(16))
    d.line((S(84), S(110), S(116), S(124)), fill=INK, width=int(6 * SCALE))
    d.line((S(172), S(110), S(140), S(124)), fill=INK, width=int(6 * SCALE))
    d.arc((S(100), S(160), S(156), S(190)), 200, 340, fill=INK, width=int(5 * SCALE))


def draw_rei_ferrugem(d):  # lata alta com coroa de tampinhas
    shadow(d, S(128), S(236), S(60), S(10))
    d.rounded_rectangle((S(70), S(70), S(186), S(232)), radius=S(14), fill=TIN, outline=INK, width=int(5 * SCALE))
    for y in (S(100), S(150), S(200)):
        d.rectangle((S(70), y, S(186), y + S(10)), fill=TIN_DARK)
    # ferrugem
    for (x, y, r) in ((S(90), S(120), S(10)), (S(160), S(180), S(14)), (S(120), S(214), S(8))):
        d.ellipse((x - r, y - r, x + r, y + r), fill=(176, 96, 60, 255))
    # coroa de tampinhas
    for i in range(5):
        x = S(84) + i * S(22)
        d.ellipse((x - S(10), S(44), x + S(10), S(64)), fill=GOLD, outline=INK, width=int(3 * SCALE))
    d.rectangle((S(74), S(58), S(182), S(74)), fill=GOLD, outline=INK, width=int(3 * SCALE))
    blob(d, (S(92), S(84), S(164), S(140)), fill=ENEMY)
    eyes(d, S(128), S(112), S(18), S(10))


def draw_breu(d):  # cobertor estrelado com olhos e pernas curtas
    shadow(d, S(128), S(236), S(76), S(10))
    d.polygon([(S(40), S(226)), (S(56), S(90)), (S(96), S(50)), (S(160), S(50)), (S(200), S(90)), (S(216), S(226)), (S(190), S(214)), (S(160), S(230)), (S(128), S(212)), (S(96), S(230)), (S(66), S(214))], fill=(58, 44, 96, 255), outline=INK)
    d.line([(S(40), S(226)), (S(56), S(90)), (S(96), S(50)), (S(160), S(50)), (S(200), S(90)), (S(216), S(226)), (S(190), S(214)), (S(160), S(230)), (S(128), S(212)), (S(96), S(230)), (S(66), S(214)), (S(40), S(226))], fill=INK, width=int(5 * SCALE), joint="curve")
    # estrelas
    for (x, y) in ((S(80), S(120)), (S(150), S(100)), (S(176), S(170)), (S(100), S(184))):
        pts = []
        for i in range(10):
            r = S(10) if i % 2 == 0 else S(4)
            a = math.radians(i * 36 - 90)
            pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
        d.polygon(pts, fill=GOLD, outline=INK)
    eyes(d, S(128), S(140), S(26), S(14), glow=(255, 255, 230, 255))
    # pernas curtas
    for x in (S(96), S(160)):
        d.rounded_rectangle((x - S(12), S(222), x + S(12), S(246)), radius=S(6), fill=ENEMY_DARK, outline=INK, width=int(4 * SCALE))


ENEMIES = {
    "fiapo": draw_fiapo, "corrisco": draw_corrisco, "bolota": draw_bolota, "latinha": draw_latinha,
    "nevoa": draw_nevoa, "remendo": draw_remendo, "casulo": draw_casulo, "brutamontes": draw_brutamontes,
}
BOSSES = {"aspirador": draw_aspirador, "rei_ferrugem": draw_rei_ferrugem, "breu": draw_breu}


def main():
    manifest = {"status": "placeholder_procedural", "note": "Visuais provisórios gerados por tools/generate_placeholder_enemies.py. Substituir pelos 96 + 48 quadros desenhados.", "assets": {}}
    for eid, fn in ENEMIES.items():
        im = canvas(128)
        fn(ImageDraw.Draw(im))
        rel = finish(im, 128, f"enemy_{eid}_placeholder_128.png")
        manifest["assets"][f"enemy_{eid}"] = {"file": rel, "width": 128, "height": 128, "anchor": [0.5, 0.82], "placeholder": True}
    for bid, fn in BOSSES.items():
        im = canvas(256)
        fn(ImageDraw.Draw(im))
        rel = finish(im, 256, f"boss_{bid}_placeholder_256.png")
        manifest["assets"][f"boss_{bid}"] = {"file": rel, "width": 256, "height": 256, "anchor": [0.5, 0.9], "placeholder": True}
    # prancha de revisão
    sheet = Image.new("RGBA", (11 * 140, 150), (47, 183, 160, 255))
    d = ImageDraw.Draw(sheet)
    i = 0
    for key, entry in manifest["assets"].items():
        im = Image.open(os.path.join(ROOT, entry["file"])).convert("RGBA").resize((128, 128), Image.LANCZOS)
        sheet.alpha_composite(im, (i * 140 + 6, 14))
        d.text((i * 140 + 6, 2), key, fill=INK)
        i += 1
    sheet.convert("RGB").save(os.path.join(OUT, "review_placeholders.png"))
    with open(os.path.join(OUT, "placeholder_manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print("placeholders:", len(manifest["assets"]))


if __name__ == "__main__":
    main()
