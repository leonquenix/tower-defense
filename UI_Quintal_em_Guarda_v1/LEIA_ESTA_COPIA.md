# Cópia de trabalho do pacote de UI

Esta pasta guarda **apenas os arquivos que a implementação consome ou versiona**. O pacote completo
(`png/` com as 49 pranchas, `svg/` com as fontes vetoriais, `assets/` com cópias da arte já existente
no projeto, `GUIA_COMPLETO_UI.pdf`/`.docx` e `PREVIA_INTERATIVA.html`) continua em
`My Drive/Tower Defense/UI_Quintal_em_Guarda_v1` e **não** foi copiado para cá: são 472 MB e as
pranchas são referência visual, não insumo de build.

O que ficou aqui e por quê:

| Caminho | Uso |
|---|---|
| `dados/design_tokens.json` | entrada de `tools/import_ui_tokens.py` → `src/shared/Config/UiTokens.luau` |
| `dados/animacoes.json` | entrada de `tools/import_ui_tokens.py` → `src/shared/Config/UiMotion.luau` |
| `dados/telas.json` | catálogo das 49 pranchas; entrada de `tools/check_ui_coverage.py` |
| `dados/matriz_cobertura.csv` | matriz original, comparada com `docs/UI_COVERAGE.md` |
| `dados/balanceamento_v1.json` | cópia do balanceamento (idêntica à do pacote original do jogo) |
| `icones/*.png` | **fonte de upload** dos 24 ícones; entrada de `tools/export_ui_icons.py` |
| `icones/*.svg` | fonte de manutenção fora do Studio; nunca enviada ao Roblox |
| `exemplos/` | módulos de referência (`Theme`, `ButtonFeedback`) já integrados em `src/client/UI/` |
| `GUIA_COMPLETO_UI.md`, `MATRIZ_COBERTURA.md`, `LEIA_PRIMEIRO.md` | contrato de comportamento |
| `manifesto_assets.json`, `INVENTARIO_ARQUIVOS.json`, `VERIFICACAO_DA_ENTREGA.md` | procedência e hashes |

Os originais foram preservados: nada nesta pasta foi editado, recortado ou re-exportado no lugar.
Os recortes de upload vão para `assets/export/ui/`, gerados a partir de `icones/`.
