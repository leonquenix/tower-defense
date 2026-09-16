# Pacote de criação de Quintal em Guarda

Documento preparado em 15 de setembro de 2026 para criar um tower defense 2D no Roblox. A proposta usa personagens originais, cooperação de até quatro pessoas e Circuitos entre torres adjacentes. O nome é provisório.

## Como usar

1. Coloque esta pasta no repositório de trabalho do Claude Code.
2. Abra 05_PROMPT_PARA_CLAUDE_CODE.md e copie a mensagem de implementação.
3. Mantenha esta pasta e Assets_Quintal_em_Guarda_v1 lado a lado na raiz Tower Defense. A pasta arte contém referências; os 40 PNGs individuais para integração ficam em Assets_Quintal_em_Guarda_v1. Leia 08_USO_DE_ASSETS_E_ANIMACOES.md e o asset_index.json da raiz.
4. Use o documento consolidado PDF para leitura e compartilhamento, e o DOCX para revisão editorial. Os arquivos desta pasta facilitam a leitura e implementação pelo agente.

## Conteúdo

| Arquivo | Finalidade |
| --- | --- |
| 01_GAME_DESIGN.md | Proposta, referências atuais, experiência, regras e escopo |
| 02_ESPECIFICACAO_TECNICA.md | Arquitetura, simulação, rede, dados e integração Roblox |
| 03_DIRECAO_DE_ARTE.md | Personagens, paleta, interface, animação e produção de assets |
| 04_TESTES_E_ACEITE.md | Cenários de verificação e definição de pronto |
| 05_PROMPT_PARA_CLAUDE_CODE.md | Mensagem pronta para iniciar e retomar a construção |
| 06_CATALOGO_NUMERICO.md | Tabelas legíveis de torres, inimigos, ondas e mapas |
| 07_FONTES.md | Fontes consultadas e limites da pesquisa |
| 08_USO_DE_ASSETS_E_ANIMACOES.md | Localização dos PNGs, importação, âncoras, movimentos e animação final |
| dados/balanceamento_v1.json | Parâmetros numéricos canônicos e IDs |
| arte/prancha_conceito.png | Referência original de mundo e personagens |
| arte/interface_combate.png | Wireframe de distribuição e hierarquia do combate |
| arte/paleta.png | Cores e semântica visual |
| arte/PROMPT_CONCEITO.txt | Prompt e ferramenta da imagem conceitual |

## Premissas e limites

Foi adotada a direção de tabuleiro 2D, câmera superior, personagens originais cartoon e foco em computador e celular. O orçamento, a equipe e o cronograma não foram informados. Por isso, o trabalho define um escopo e uma sequência de marcos, sem prometer custo ou prazo de produção.

Este pacote é uma especificação de produto e implementação. Não contém um jogo já criado, publicado ou balanceado. O Claude Code ainda precisará escrever o projeto, executar verificações e integrar assets aprovados. Recursos da conta Roblox, publicação, moderação, testes no motor e produção artística final não surgem automaticamente a partir de um documento.

Em conflitos numéricos, o JSON prevalece; em comportamento, a especificação técnica esclarece o game design. Mudanças de escopo devem atualizar todos os arquivos afetados. Valores marcados como metas e hipóteses precisam de validação, e não devem ser divulgados como resultados medidos.
