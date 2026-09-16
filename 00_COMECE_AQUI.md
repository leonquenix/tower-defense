# Quintal em Guarda

Esta é a entrega consolidada para construir o tower defense 2D no Roblox. Documento principal versão 1.1, com 40 PNGs individuais, especificação de integração e plano de animação.

## Para usar com o Claude Code

1. Abra esta pasta Tower Defense como pasta de trabalho do Claude Code. Se estiver usando outro computador, aguarde o Google Drive baixar o conteúdo completo.
2. Envie a mensagem abaixo. Os caminhos são relativos a esta pasta e funcionam sem o histórico da conversa.
3. Mantenha as pastas Pacote_Claude_Code e Assets_Quintal_em_Guarda_v1 junto deste arquivo.

> Leia CLAUDE.md e siga Pacote_Claude_Code/05_PROMPT_PARA_CLAUDE_CODE.md para implementar Quintal em Guarda. Use as imagens já existentes por meio de asset_index.json. Siga Pacote_Claude_Code/08_USO_DE_ASSETS_E_ANIMACOES.md e animation_plan.json para integração, movimentos e animação. Implemente e verifique os marcos, registrando pendências externas sem inventar uploads, IDs ou testes executados.

## Arquivos de entrada

| Arquivo | Para que serve |
| --- | --- |
| Quintal_em_Guarda_Documento_Completo.pdf | Leitura e compartilhamento do documento principal |
| Quintal_em_Guarda_Documento_Completo.docx | Versão editável do documento principal |
| CLAUDE.md | Contexto do projeto e ordem de leitura |
| Pacote_Claude_Code/ | Regras, técnica, arte, testes, catálogo e prompt completo |
| asset_index.json | Os 40 caminhos de imagens a partir desta raiz |
| runtime_asset_registry.json | Registro dos 40 assets, com exports e IDs do Roblox ainda não preenchidos |
| animation_plan.json | Movimentos especificados e plano de atlas a produzir |
| Assets_Quintal_em_Guarda_v1/CATALOGO.html | Catálogo local das 40 imagens |
| Assets_Quintal_em_Guarda_v1/PREVIA_FASES.html | Prévia estática da composição dos três mapas |
| INVENTARIO_ARQUIVOS.json | Lista e hashes para conferir integridade da entrega |

## O que está pronto e o que falta

Os 40 PNGs estão nesta pasta, em arquivos separados, com nomes estáveis e transparência. São 30 poses de torres, três terrenos e sete objetos de cenário e base. As imagens não estão publicadas no Roblox. Exportação para tamanho de distribuição, integração, animações desenhadas, inimigos, chefes, áudio e validação em jogo continuam sendo etapas de produção.

Não confunda a prévia HTML com o jogo implementado, nem as poses estáticas com os 240 quadros finais de torres. O código pode criar movimentos leves com as imagens atuais, conforme o capítulo 8.
