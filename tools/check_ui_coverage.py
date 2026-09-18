#!/usr/bin/env python3
"""Valida a cobertura das 49 pranchas e gera docs/UI_COVERAGE.md.

Compara docs/ui_coverage.json com o catálogo de telas do pacote
(UI_Quintal_em_Guarda_v1/dados/telas.json) e falha (exit 1) quando:
  * uma prancha do catálogo não foi declarada, ou uma declaração não existe no catálogo;
  * um módulo declarado não existe em disco;
  * uma prancha de biblioteca (31, 37-46, 49) foi declarada como tela de produto;
  * uma linha diz "testado no Studio" sem evidência escrita.

Uso: python3 tools/check_ui_coverage.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CATALOG = os.path.join(ROOT, "UI_Quintal_em_Guarda_v1", "dados", "telas.json")
DECLARATION = os.path.join(ROOT, "docs", "ui_coverage.json")
OUT = os.path.join(ROOT, "docs", "UI_COVERAGE.md")

# Pranchas que o guia declara como bibliotecas de estado: não viram menu no jogo publicado.
LIBRARY_BOARDS = {
    "31_estados",
    "37_botoes",
    "38_confirmacoes",
    "39_erros",
    "40_grupo_estados",
    "41_boss_estados",
    "42_recuperacao",
    "43_colecao_estados",
    "44_resultados_estados",
    "45_menus_contextuais",
    "46_loja_estados",
    "49_icones",
}


class ValidationError(Exception):
    pass


def main():
    catalog = json.load(open(CATALOG, encoding="utf-8"))
    declaration = json.load(open(DECLARATION, encoding="utf-8"))
    boards = declaration["boards"]

    catalog_ids = [screen["id"] for screen in catalog]
    missing = [board for board in catalog_ids if board not in boards]
    extra = [board for board in boards if board not in catalog_ids]
    if missing:
        raise ValidationError(f"pranchas sem declaração: {', '.join(missing)}")
    if extra:
        raise ValidationError(f"declarações sem prancha correspondente: {', '.join(extra)}")

    for board_id, entry in boards.items():
        for module in entry["modules"]:
            if not os.path.exists(os.path.join(ROOT, module)):
                raise ValidationError(f"{board_id}: módulo inexistente {module}")
        if not entry["states"]:
            raise ValidationError(f"{board_id}: nenhum estado declarado")
        expected_kind = "library" if board_id in LIBRARY_BOARDS else "screen"
        if entry["kind"] != expected_kind:
            raise ValidationError(
                f"{board_id}: declarado como {entry['kind']}, esperado {expected_kind} "
                "(pranchas de componentes não podem virar menu publicado)"
            )
        if entry["studio"] and not entry.get("evidence"):
            raise ValidationError(f"{board_id}: marcado como testado no Studio sem evidência")

    titles = {screen["id"]: screen["title"] for screen in catalog}
    implemented = sum(1 for entry in boards.values() if entry["implemented"])
    tested = sum(1 for entry in boards.values() if entry["studio"])

    lines = [
        "# Matriz de cobertura da interface",
        "",
        "ARQUIVO GERADO por `tools/check_ui_coverage.py` a partir de `docs/ui_coverage.json` e do",
        "catálogo `UI_Quintal_em_Guarda_v1/dados/telas.json`. Não edite à mão: altere o JSON e rode a",
        "ferramenta.",
        "",
        f"**{implemented} de {len(boards)} pranchas implementadas** · "
        f"**{tested} exercitadas numa sessão de Play do Studio nesta entrega**.",
        "",
        "As colunas separam propositalmente o que está montado do que foi visto rodando. Uma prancha",
        "existente nunca comprova que um botão funciona; por isso a coluna *Studio* só marca o que foi",
        "percorrido de verdade, e a *Evidência* diz o que aconteceu.",
        "",
        "Nenhuma prancha de biblioteca (31, 37–46, 49) virou menu no jogo: elas descrevem componentes",
        "compartilhados. Upload dos 24 ícones e publicação continuam pendentes — ver",
        "`docs/MANUAL_ACTIONS.md`.",
        "",
        "| Prancha | Tela ou estado | Tipo | Onde vive | Estados | Implementado | Studio | Evidência |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for board_id in catalog_ids:
        entry = boards[board_id]
        modules = "<br>".join("`" + module.replace("src/", "") + "`" for module in entry["modules"])
        states = ", ".join(entry["states"])
        lines.append(
            "| {board} | {title} | {kind} | {modules} | {states} | {implemented} | {studio} | {evidence} |".format(
                board=board_id,
                title=titles[board_id],
                kind="tela" if entry["kind"] == "screen" else "biblioteca",
                modules=modules,
                states=states,
                implemented="sim" if entry["implemented"] else "não",
                studio="sim" if entry["studio"] else "pendente",
                evidence=entry.get("evidence", ""),
            )
        )

    lines += [
        "",
        "## O que ainda não foi exercitado",
        "",
        "As linhas com *Studio: pendente* precisam de condições que uma sessão local de Play não cria:",
        "",
        "- dois clientes conectados (salas, grupo, convites, votação de 2x, Pulso simultâneo);",
        "- perfil persistido (desbloqueio por botões, domínio, vitória, derrota, recompensa pendente);",
        "- passe criado no Creator Hub (estados da loja);",
        "- emulação de dispositivo em 844×390, 896×414, 1024×768 e 390×844 (layouts compactos e vertical);",
        "- uma partida completa até a onda de chefe (BossBar, especialização, inspeção de inimigo).",
        "",
        "O passo a passo de cada um está em `docs/MANUAL_ACTIONS.md`.",
    ]

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"gerado docs/UI_COVERAGE.md ({implemented}/{len(boards)} implementadas, {tested} no Studio)")


if __name__ == "__main__":
    try:
        main()
    except ValidationError as err:
        print("ERRO:", err)
        sys.exit(1)
