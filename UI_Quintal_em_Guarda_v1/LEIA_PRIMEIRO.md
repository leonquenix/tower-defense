# Interfaces de Quintal em Guarda

Este pacote reúne 49 pranchas de telas, variantes de dispositivo e feedbacks, documentação detalhada e fontes editáveis para implementar a UI no Roblox Studio com Claude Code.

1. Abra **GUIA_COMPLETO_UI.pdf** para ler o guia com todas as imagens.
2. Abra **PREVIA_INTERATIVA.html** no navegador para navegar nas referências e testar exemplos de feedback. Funciona localmente, sem internet.
3. Disponibilize a pasta inteira ao Claude Code junto ao projeto atual e copie **PROMPT_PARA_CLAUDE.txt**.
4. Confira **MATRIZ_COBERTURA.md** ao revisar a implementação.

## Conteúdo

- GUIA_COMPLETO_UI.docx — documento editável, com todas as pranchas.
- GUIA_COMPLETO_UI.md — versão textual para Claude, com referências relativas às imagens.
- png/ — 49 PNGs individuais. Desktop exportado em 1920×1080; variantes compactas em 1,5× da referência.
- svg/ — fontes vetoriais das pranchas, com imagens incorporadas. Referência de construção, não arquivo de upload direto no Roblox.
- icones/ — 24 ícones funcionais em SVG e PNG transparente de 128×128.
- assets/ — cópias dos personagens e terrenos existentes usados como referência. Preserve os arquivos originais.
- dados/ — tokens, timings, catálogo de telas, contratos de interação e balanceamento existente.
- exemplos/ — dois módulos Luau de apoio para tema e feedback de botão, com instruções.
- referencias/ — especificações existentes para manter a integração coerente.
- manifesto_assets.json — caminhos e hashes dos assets, com IDs Roblox vazios até upload real.

Os PNGs de telas não são sprites para preencher a tela do jogo. Recrie os componentes com elementos nativos Roblox para manter texto vivo, layout responsivo e botões funcionais. As imagens têm valores e nomes demonstrativos de estados independentes, não a progressão de uma única conta.

A galeria navega por telas e mostra microinterações locais; não executa combate, compra ou rede. Há transições simplificadas entre desktop e celular para facilitar a consulta. O contrato no guia é a referência de comportamento final. Pranchas 31 e 37–46/49 são bibliotecas de estados, não telas de produto a publicar.

As skins do passe e os efeitos sonoros finais não foram produzidos neste pacote. A tela de loja mostra indisponibilidade e estados de integração; não oferecer uma aparência ainda sem arte final. Os exemplos Luau precisam ser integrados e validados no Studio.

## Referências oficiais consultadas

- https://create.roblox.com/docs/reference/engine/classes/ScreenGui
- https://create.roblox.com/docs/reference/engine/classes/GuiService
- https://create.roblox.com/docs/tutorials/building/ui/interactive-buttons
- https://create.roblox.com/docs/reference/engine/classes/TweenService

A pasta foi salva localmente em outputs/UI_Quintal_em_Guarda_v1. O ZIP inclui a estrutura completa e deve ser extraído antes de abrir a prévia.
