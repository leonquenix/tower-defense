# Contexto do projeto Quintal em Guarda

Esta pasta é a raiz da entrega e futura pasta de trabalho do projeto Roblox. O jogo ainda deve ser implementado. Há documentação e 40 PNGs reais disponíveis; não procure as imagens em caminhos pessoais de outro computador ou na conversa anterior.

## Ordem de leitura

1. 00_COMECE_AQUI.md.
2. Pacote_Claude_Code/00_LEIA_PRIMEIRO.md e 05_PROMPT_PARA_CLAUDE_CODE.md.
3. Pacote_Claude_Code/01_GAME_DESIGN.md, 02_ESPECIFICACAO_TECNICA.md e dados/balanceamento_v1.json.
4. Pacote_Claude_Code/03_DIRECAO_DE_ARTE.md, 08_USO_DE_ASSETS_E_ANIMACOES.md, asset_index.json, runtime_asset_registry.json e animation_plan.json.
5. Pacote_Claude_Code/04_TESTES_E_ACEITE.md, 06_CATALOGO_NUMERICO.md e 07_FONTES.md.

## Uso dos arquivos

Todos os sourceFile de asset_index.json são relativos a esta raiz. Os localFile do manifesto original são relativos a Assets_Quintal_em_Guarda_v1. Preserve essas bases diferentes. Leia os PNGs antes de montar a interface. Não recorte a prancha de conceito para substituir os sprites existentes.

O balanceamento_v1.json é canônico para números e caminhos de gameplay. O capítulo técnico define semântica e autoridade do servidor. O capítulo 8 define o uso da biblioteca de imagens atual. animation_plan.json é uma especificação de movimentos, não um animador pronto. A pasta de arte contém 40 poses/terrenos/objetos estáticos, sem atlas ou inimigos finais.

Preserve documentação e fontes PNG. Implemente src, tests, assets/export, tools e docs conforme a especificação, respeitando qualquer trabalho que o responsável já tenha acrescentado. Gere Config/Assets.luau a partir do registro de runtime. Preencha IDs e status somente após export/upload verificados; arquivos locais não equivalem a conteúdo Roblox publicado.

## Execução e validação

Siga os marcos M0 a M6 do documento e o prompt completo. Faça primeiro a partida curta funcionar com as imagens existentes, depois amplie conteúdo e serviços. O jogo deve continuar em ScreenGui 2D e combate autoritativo no servidor. Animação e projéteis nunca decidem dano.

Implemente movimentos procedurais como apresentação inicial e registre que os quadros finais ainda faltam. Não pare em um plano, não invente resultados de Studio e não publique a experiência sem autorização específica. Entregue evidências, testes disponíveis e ações manuais reais.

## Estado da implementação (2026-09-16)

O jogo foi implementado nesta raiz: `src/` (Luau estrito), `tests/` (Lune), `tools/` (geradores), `assets/export/` (exports e uploads), `docs/` (SETUP, TEST_REPORT, MANUAL_ACTIONS, MILESTONES) e `build/`. Leia `docs/SETUP.md` para abrir e testar. `Config/Balance.luau`, `Config/Maps.luau` e `Config/Assets.luau` são gerados: altere o JSON ou o registro e rode as ferramentas em `tools/`, nunca edite os módulos gerados à mão.
