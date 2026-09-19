#!/usr/bin/env python3
"""Mede uma arte de mapa e devolve playRect, rota e bloqueios em coordenadas de célula.

    python3 tools/fit_map_scene.py Assets_Mapas_v2/arte.png [--json]

Como mede (e por que):
  1. A malha de ladrilhos desenhada é periódica. O passo e a fase que maximizam a soma do
     gradiente nas bordas dão a célula e a origem — é medida, não estimativa (a primeira arte do
     Jardim foi encaixada "no olho" pelas bordas do corredor e saiu 20% de célula deslocada).
  2. Com a malha em mãos, cada ladrilho vira uma classe: piso, corredor (a pista clara) ou outra
     coisa (folhagem, pedra, água, neve fofa).
  3. A área jogável é a janela de 16x10 ladrilhos que mais cobre piso+corredor. É ela que vira
     o playRect.
  4. Dentro da janela, os ladrilhos de corredor viram a rota (andando da entrada até a saída) e
     os "outra coisa" viram bloqueios.

Sem dependências externas: lê PNG com zlib e escreve só no stdout.
"""
import argparse
import json
import os
import struct
import sys
import zlib

COLUMNS, ROWS = 16, 10


# ---------------------------------------------------------------------------
# PNG
# ---------------------------------------------------------------------------
def load_png(path):
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path} não é PNG")
    pos, idat, width, height, depth, color = 8, b"", 0, 0, 0, 0
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        tag = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + length]
        if tag == b"IHDR":
            width, height, depth, color = struct.unpack(">IIBB", body[:10])
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break
        pos += 12 + length
    if depth != 8 or color not in (2, 6):
        raise SystemExit("esperado PNG de 8 bits RGB ou RGBA")
    bpp = 3 if color == 2 else 4
    raw = zlib.decompress(idat)
    stride = width * bpp
    rows, previous = [], bytearray(stride)
    pos = 0
    for _ in range(height):
        filt = raw[pos]
        line = bytearray(raw[pos + 1 : pos + 1 + stride])
        pos += 1 + stride
        if filt == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif filt == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filt == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif filt == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = previous[i]
                c = previous[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        rows.append(line)
        previous = line
    return width, height, bpp, rows


# ---------------------------------------------------------------------------
# Classificação de cor
# ---------------------------------------------------------------------------
def make_probes(width, height, bpp, rows):
    def rgb(x, y):
        x, y = int(x), int(y)
        if x < 0 or y < 0 or x >= width or y >= height:
            return (0, 0, 0)
        o = x * bpp
        row = rows[y]
        return row[o], row[o + 1], row[o + 2]

    def road(x, y):
        # pista clara (areia/terra batida): quente e bem mais vermelha que azul
        r, g, b = rgb(x, y)
        return r > 190 and g > 150 and b < 205 and r > b + 30

    def lum(x, y):
        r, g, b = rgb(x, y)
        return 0.299 * r + 0.587 * g + 0.114 * b

    # O piso não dá para descrever por regra de cor: grama, gelo e chão de oficina são coisas
    # diferentes. Ele é descoberto na imagem — as duas cores mais comuns do miolo (o xadrez do
    # ladrilho tem dois tons) são o piso, e tudo que foge delas é folhagem, pedra, neve ou água.
    buckets = {}
    for y in range(int(height * 0.2), int(height * 0.8), 3):
        for x in range(int(width * 0.15), int(width * 0.7), 3):
            if road(x, y):
                continue
            r, g, b = rgb(x, y)
            key = (r // 16, g // 16, b // 16)
            buckets[key] = buckets.get(key, 0) + 1
    top = sorted(buckets.items(), key=lambda kv: -kv[1])[:2]
    floor_refs = [(k[0] * 16 + 8, k[1] * 16 + 8, k[2] * 16 + 8) for k, _ in top]

    def floor(x, y):
        r, g, b = rgb(x, y)
        for fr, fg, fb in floor_refs:
            if (r - fr) ** 2 + (g - fg) ** 2 + (b - fb) ** 2 < 55 * 55:
                return True
        return False

    return rgb, road, floor, floor_refs, lum


def best_period(grad, lo, hi, span):
    best = None
    for step10 in range(int(lo * 10), int(hi * 10)):
        step = step10 / 10
        for phase10 in range(0, int(step * 10)):
            phase = phase10 / 10
            total, count, k = 0.0, 0, phase
            while k < span:
                i = int(k)
                if 1 <= i < len(grad) - 1:
                    total += grad[i] + 0.5 * grad[i - 1] + 0.5 * grad[i + 1]
                    count += 1
                k += step
            if count > 3:
                score = total / count
                if best is None or score > best[0]:
                    best = (score, step, phase)
    return best


def corridor_thickness(width, height, road):
    """Mediana da largura dos trechos de pista — a pista tem uma célula de largura."""
    runs = []
    for y in range(int(height * 0.1), int(height * 0.95), 3):
        start = None
        for x in range(width):
            if road(x, y):
                if start is None:
                    start = x
            elif start is not None:
                if 6 < x - start < width * 0.25:
                    runs.append(x - start)
                start = None
    for x in range(int(width * 0.05), int(width * 0.9), 3):
        start = None
        for y in range(height):
            if road(x, y):
                if start is None:
                    start = y
            elif start is not None:
                if 6 < y - start < height * 0.35:
                    runs.append(y - start)
                start = None
    if not runs:
        raise SystemExit("não achei corredor: a pista não bate com o teste de cor")
    runs.sort()
    return runs[len(runs) // 2]


def largest_road_component(cells):
    """Só o corredor ligado à entrada conta: assim a praia (também cor de areia) fica de fora."""
    remaining = set(cells)
    best = set()
    while remaining:
        seed = min(remaining)
        stack, group = [seed], set()
        remaining.discard(seed)
        while stack:
            cx, cy = stack.pop()
            group.add((cx, cy))
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (cx + d[0], cy + d[1])
                if nxt in remaining:
                    remaining.discard(nxt)
                    stack.append(nxt)
        if len(group) > len(best):
            best = group
    return best


def fit(path, verbose=True):
    width, height, bpp, rows = load_png(path)
    rgb, road, floor, floor_refs, lum = make_probes(width, height, bpp, rows)

    # 1. passo e fase da malha, medidos só sobre o piso (nem pista, nem folhagem, nem água)
    def floorish(x, y):
        return floor(x, y)

    gradx = [0.0] * width
    grady = [0.0] * height
    for y in range(int(height * 0.12), int(height * 0.9), 2):
        for x in range(4, width - 4):
            if floorish(x, y) and floorish(x - 2, y) and floorish(x + 2, y):
                gradx[x] += abs(lum(x + 1, y) - lum(x - 1, y))
    for x in range(int(width * 0.1), int(width * 0.8), 2):
        for y in range(4, height - 4):
            if floorish(x, y) and floorish(x, y - 2) and floorish(x, y + 2):
                grady[y] += abs(lum(x, y + 1) - lum(x, y - 1))
    # A espessura do corredor desenhado limita a busca: ele mede uma célula (menos a borda
    # escura do desenho). Sem esse limite a busca acha harmônicos e a célula sai pela metade.
    thickness = corridor_thickness(width, height, road)
    lo, hi = max(thickness * 0.95, 8.0), thickness * 1.45
    bx = best_period(gradx, lo, hi, width)
    by = best_period(grady, lo, hi, height)
    cell = (bx[1] + by[1]) / 2
    phase_x, phase_y = bx[2], by[2]
    if verbose:
        print(
            "piso reconhecido nas cores %s | corredor de %d px | malha: passo x=%.2f y=%.2f -> célula %.2f px"
            % (floor_refs, thickness, bx[1], by[1], cell)
        )

    # 2. classifica cada ladrilho possível
    def classify(px, py):
        hits = {"road": 0, "floor": 0, "other": 0}
        total = 0
        for dy in range(-6, 7, 2):
            for dx in range(-6, 7, 2):
                sx, sy = px + dx * cell / 18, py + dy * cell / 18
                total += 1
                if road(sx, sy):
                    hits["road"] += 1
                elif floor(sx, sy):
                    hits["floor"] += 1
                else:
                    hits["other"] += 1
        if hits["road"] >= total * 0.45:
            return "road", hits
        # um enfeite pequeno (flor, tufo) não tira a célula do jogo; pedra e árvore tiram
        if hits["floor"] + hits["road"] >= total * 0.62:
            return "floor", hits
        return "other", hits

    max_col = int((width - phase_x) // cell)
    max_row = int((height - phase_y) // cell)
    grid = {}
    for cy in range(max_row):
        for cx in range(max_col):
            px = phase_x + (cx + 0.5) * cell
            py = phase_y + (cy + 0.5) * cell
            grid[(cx, cy)] = classify(px, py)[0]
    corridor = largest_road_component({c for c, kind in grid.items() if kind == "road"})
    for c, kind in list(grid.items()):
        if kind == "road" and c not in corridor:
            grid[c] = "other"  # praia: cor de areia, mas não é caminho

    # 3. janela 16x10 que melhor cobre piso + corredor
    best_window = None
    for oy in range(0, max(max_row - ROWS + 1, 1)):
        for ox in range(0, max(max_col - COLUMNS + 1, 1)):
            score = 0
            for cy in range(ROWS):
                for cx in range(COLUMNS):
                    kind = grid.get((ox + cx, oy + cy), "other")
                    score += 2 if kind == "road" else (1 if kind == "floor" else -2)
            # a rota entra pela borda esquerda e sai pela direita: janela que perde uma das
            # pontas está deslocada
            if any(grid.get((ox, oy + cy)) == "road" for cy in range(ROWS)):
                score += 8
            if any(grid.get((ox + COLUMNS - 1, oy + cy)) == "road" for cy in range(ROWS)):
                score += 8
            # e o corredor inteiro tem de caber dentro dela
            outside = sum(
                1 for (cx, cy) in corridor if not (ox <= cx < ox + COLUMNS and oy <= cy < oy + ROWS)
            )
            score -= outside * 3
            if best_window is None or score > best_window[0]:
                best_window = (score, ox, oy)
    _, ox, oy = best_window
    x0 = phase_x + ox * cell
    y0 = phase_y + oy * cell
    play_rect = [x0 / width, y0 / height, (x0 + COLUMNS * cell) / width, (y0 + ROWS * cell) / height]

    # 4. rota e bloqueios dentro da janela
    road_cells = set()
    blocked = []
    for cy in range(ROWS):
        for cx in range(COLUMNS):
            kind = grid.get((ox + cx, oy + cy), "other")
            if kind == "road":
                road_cells.add((cx, cy))
            elif kind == "other":
                blocked.append([cx, cy])

    route = trace_route(road_cells)
    if verbose:
        print("janela: origem (%.1f, %.1f) px, célula %.2f" % (x0, y0, cell))
        print("playRect: [%.4f, %.4f, %.4f, %.4f]" % tuple(play_rect))
        print("proporção da área jogável: %.3f" % ((COLUMNS * cell) / (ROWS * cell)))
        print("corredor: %d células" % len(road_cells))
        print("rota: %s" % (json.dumps(route) if route else "NÃO FOI POSSÍVEL TRAÇAR"))
        print("bloqueios: %s" % json.dumps(blocked))
        render(grid, ox, oy, road_cells, set(map(tuple, blocked)))
    return {
        "cell": cell,
        "playRect": [round(v, 4) for v in play_rect],
        "path": route,
        "blocked": blocked,
        "roadCells": sorted(road_cells),
    }


def trace_route(road_cells):
    """Do corredor desenhado para a lista de vértices que o jogo usa."""
    if not road_cells:
        return None
    starts = [c for c in road_cells if c[0] == 0]
    if not starts:
        starts = sorted(road_cells)[:1]
    start = min(starts, key=lambda c: c[1])
    route = [list(start)]
    visited = {start}
    current = start
    direction = (1, 0)
    while True:
        options = [direction, (0, 1), (0, -1), (1, 0), (-1, 0)]
        moved = False
        for d in options:
            nxt = (current[0] + d[0], current[1] + d[1])
            if nxt in road_cells and nxt not in visited:
                if d != direction:
                    route.append(list(current))
                    direction = d
                visited.add(nxt)
                current = nxt
                moved = True
                break
        if not moved:
            break
    route.append(list(current))
    return route if len(visited) == len(road_cells) else route


def render(grid, ox, oy, road_cells, blocked):
    print("mapa classificado (janela 16x10; '#' corredor, 'x' bloqueio, '.' piso):")
    for cy in range(ROWS):
        line = ""
        for cx in range(COLUMNS):
            if (cx, cy) in road_cells:
                line += "#"
            elif (cx, cy) in blocked:
                line += "x"
            else:
                line += "."
        print("  " + line)


def write_overlay(src, out, result):
    """Desenha a grade medida por cima da arte, para conferir de olho antes de publicar."""
    width, height, bpp, rows = load_png(src)
    cell = result["cell"]
    rect = result["playRect"]
    x0, y0 = rect[0] * width, rect[1] * height
    pixels = [bytearray(r) for r in rows]

    def put(x, y, color):
        x, y = int(x), int(y)
        if 0 <= x < width and 0 <= y < height:
            o = x * bpp
            pixels[y][o : o + 3] = bytes(color)

    for i in range(COLUMNS + 1):
        for y in range(int(y0), int(y0 + ROWS * cell)):
            put(x0 + i * cell, y, (255, 0, 0))
    for j in range(ROWS + 1):
        for x in range(int(x0), int(x0 + COLUMNS * cell)):
            put(x, y0 + j * cell, (255, 0, 0))
    for cx, cy in result["roadCells"]:
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                put(x0 + (cx + 0.5) * cell + dx, y0 + (cy + 0.5) * cell + dy, (0, 80, 255))
    for cx, cy in result["blocked"]:
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                put(x0 + (cx + 0.5) * cell + dx, y0 + (cy + 0.5) * cell + dy, (255, 0, 255))
    raw = b"".join(b"\x00" + bytes(row) for row in pixels)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", width, height, 8, 6 if bpp == 4 else 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    with open(out, "wb") as handle:
        handle.write(png)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--json", action="store_true", help="imprime só o resultado em JSON")
    parser.add_argument("--overlay", help="grava a arte com a grade medida por cima")
    args = parser.parse_args()
    if not os.path.exists(args.image):
        raise SystemExit(f"não achei {args.image}")
    result = fit(args.image, verbose=not args.json)
    if args.overlay:
        write_overlay(args.image, args.overlay, result)
        if not args.json:
            print("grade desenhada em " + args.overlay)
    if args.json:
        json.dump(result, sys.stdout, ensure_ascii=False)
        print()


if __name__ == "__main__":
    main()
