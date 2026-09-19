#!/usr/bin/env python3
"""Gera o gabarito de geometria de cada mapa (docs/map_templates/<id>_template.png).

O gabarito é o desenho técnico que vai junto com o pedido de arte: malha de ladrilhos,
corredor de uma célula, células bloqueadas e a moldura decorativa. Quem for pintar a cena
repinta por cima dele; quem for conferir compara com ele.

Canvas = 22x12 ladrilhos: a área jogável é o retângulo interno de 16x10, com 3 ladrilhos de
moldura à esquerda e à direita e 1 acima e abaixo. A moldura larga nos lados é o que faz a arte
cobrir telas bem mais largas que 16:10 sem aparecer fundo. Sem texto: qualquer letra no gabarito
acaba reproduzida pela IA de imagem. Saída determinística, escrita sem dependências externas.
"""
import json
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BALANCE = os.path.join(ROOT, "Pacote_Claude_Code", "dados", "balanceamento_v1.json")
OUT_DIR = os.path.join(ROOT, "docs", "map_templates")

TILE = 88  # px por célula
BORDER_X = 3  # ladrilhos de moldura decorativa à esquerda e à direita
BORDER_Y = 1  # ladrilhos de moldura decorativa acima e abaixo
COLUMNS, ROWS = 16, 10

GRASS_A = (126, 186, 96)
GRASS_B = (118, 178, 90)
SEAM = (98, 156, 74)
SAND = (238, 214, 160)
SAND_EDGE = (206, 176, 118)
BORDER_BG = (58, 96, 62)
FIELD_EDGE = (72, 118, 70)
BLOCKED = (128, 128, 132)
BLOCKED_EDGE = (96, 96, 100)


def path_cells(path):
    cells = []
    for i in range(len(path) - 1):
        (ax, ay), (bx, by) = path[i], path[i + 1]
        dx = (bx > ax) - (bx < ax)
        dy = (by > ay) - (by < ay)
        x, y = ax, ay
        if not cells:
            cells.append((x, y))
        while (x, y) != (bx, by):
            x += dx
            y += dy
            cells.append((x, y))
    return cells


def write_png(path, width, height, pixels):
    raw = b"".join(b"\x00" + bytes(row) for row in pixels)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def render(map_data):
    width = (COLUMNS + BORDER_X * 2) * TILE
    height = (ROWS + BORDER_Y * 2) * TILE
    ox, oy = BORDER_X * TILE, BORDER_Y * TILE
    pixels = [bytearray(BORDER_BG * width) for _ in range(height)]

    def fill(x0, y0, x1, y1, color):
        for y in range(max(int(y0), 0), min(int(y1), height)):
            row = pixels[y]
            for x in range(max(int(x0), 0), min(int(x1), width)):
                row[x * 3 : x * 3 + 3] = bytes(color)

    def tile_rect(cx, cy):
        return ox + cx * TILE, oy + cy * TILE, ox + (cx + 1) * TILE, oy + (cy + 1) * TILE

    # campo em xadrez discreto + costura dos ladrilhos
    for cy in range(ROWS):
        for cx in range(COLUMNS):
            x0, y0, x1, y1 = tile_rect(cx, cy)
            fill(x0, y0, x1, y1, GRASS_A if (cx + cy) % 2 == 0 else GRASS_B)
            fill(x0, y0, x1, y0 + 2, SEAM)
            fill(x0, y0, x0 + 2, y1, SEAM)
    fill(ox, oy + ROWS * TILE - 2, ox + COLUMNS * TILE, oy + ROWS * TILE, SEAM)
    fill(ox + COLUMNS * TILE - 2, oy, ox + COLUMNS * TILE, oy + ROWS * TILE, SEAM)

    # corredor de uma célula
    cells = path_cells(map_data["path"])
    for cx, cy in cells:
        x0, y0, x1, y1 = tile_rect(cx, cy)
        fill(x0, y0, x1, y1, SAND)
    # o corredor entra e sai pela moldura, para a entrada e a saída não morrerem na borda
    first, last = cells[0], cells[-1]
    if first[0] == 0:
        fill(0, oy + first[1] * TILE, ox, oy + (first[1] + 1) * TILE, SAND)
    if last[0] == COLUMNS - 1:
        fill(ox + COLUMNS * TILE, oy + last[1] * TILE, width, oy + (last[1] + 1) * TILE, SAND)
    # contorno fino do corredor onde ele encosta na grama
    occupied = set(cells)
    for cx, cy in cells:
        x0, y0, x1, y1 = tile_rect(cx, cy)
        if (cx, cy - 1) not in occupied and cy > 0:
            fill(x0, y0, x1, y0 + 3, SAND_EDGE)
        if (cx, cy + 1) not in occupied and cy < ROWS - 1:
            fill(x0, y1 - 3, x1, y1, SAND_EDGE)
        if (cx - 1, cy) not in occupied and cx > 0:
            fill(x0, y0, x0 + 3, y1, SAND_EDGE)
        if (cx + 1, cy) not in occupied and cx < COLUMNS - 1:
            fill(x1 - 3, y0, x1, y1, SAND_EDGE)

    # células bloqueadas: obstáculo tem de estar desenhado na arte final
    for cx, cy in map_data.get("blocked", []):
        x0, y0, x1, y1 = tile_rect(cx, cy)
        fill(x0 + 10, y0 + 10, x1 - 10, y1 - 10, BLOCKED)
        fill(x0 + 10, y0 + 10, x1 - 10, y0 + 14, BLOCKED_EDGE)
        fill(x0 + 10, y1 - 14, x1 - 10, y1 - 10, BLOCKED_EDGE)
        fill(x0 + 10, y0 + 10, x0 + 14, y1 - 10, BLOCKED_EDGE)
        fill(x1 - 14, y0 + 10, x1 - 10, y1 - 10, BLOCKED_EDGE)

    # limite da área jogável
    fill(ox - 4, oy - 4, ox + COLUMNS * TILE + 4, oy, FIELD_EDGE)
    fill(ox - 4, oy + ROWS * TILE, ox + COLUMNS * TILE + 4, oy + ROWS * TILE + 4, FIELD_EDGE)
    fill(ox - 4, oy - 4, ox, oy + ROWS * TILE + 4, FIELD_EDGE)
    fill(ox + COLUMNS * TILE, oy - 4, ox + COLUMNS * TILE + 4, oy + ROWS * TILE + 4, FIELD_EDGE)
    return width, height, pixels


def main():
    data = json.load(open(BALANCE, encoding="utf-8"))
    os.makedirs(OUT_DIR, exist_ok=True)
    for map_data in data["maps"]:
        width, height, pixels = render(map_data)
        out = os.path.join(OUT_DIR, map_data["id"] + "_template.png")
        write_png(out, width, height, pixels)
        cells = path_cells(map_data["path"])
        print(
            "gerado %s (%dx%d, %d células de caminho, base em %s)"
            % (os.path.relpath(out, ROOT), width, height, len(cells), cells[-1])
        )
    print(
        "playRect do gabarito: [%.4f, %.4f, %.4f, %.4f]"
        % (
            BORDER_X / (COLUMNS + BORDER_X * 2),
            BORDER_Y / (ROWS + BORDER_Y * 2),
            (BORDER_X + COLUMNS) / (COLUMNS + BORDER_X * 2),
            (BORDER_Y + ROWS) / (ROWS + BORDER_Y * 2),
        )
    )


if __name__ == "__main__":
    main()
