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

## Revamp: arquitetura atual (2026-09-19)

O projeto deixou de ser um MVP escrito à mão. As dependências vêm do **Wally** (`wally.toml`,
`wally.lock`; `Packages/` e `ServerPackages/` são gerados e não entram no git — rode
`.toolchain/bin/wally install`):

- **Fusion 0.3** desenha toda a interface (`src/client/UI`): `Kit` é a biblioteca de componentes,
  `Skin` a camada de profundidade/cenário, `App` monta camadas e rotas, `Screens/` e `Overlays/`
  são as telas. Não crie botão, modal ou aviso fora do Kit.
- **Charm 0.10** guarda o estado do cliente (`src/client/State`): `Atoms` (fatos), `Selectors`
  (derivações), `Actions` (mutações) e `Bridge` (Charm → Fusion). A interface só lê.
- **ByteNet 0.4.6** é o transporte (`src/shared/Net/Packets`). `Enums` e `Codec` são puros e
  testados; `Protocol` continua com validação, limites de taxa e deduplicação.
- **ProfileStore 1.0.3** persiste perfis em `src/server/Services/PlayerDataService.luau`.
- Fachadas tipadas em `src/shared/Lib/` fixam o caminho do índice do Wally;
  `tools/check_package_facades.py` confere contra o lock.

O tabuleiro (`src/client/View`) continua imperativo de propósito: é um renderizador de sprites a
60 Hz com pool. `View/Juice` concentra tremor, clarão, partículas e números, sempre atrás das
preferências de conforto e sempre disparado por evento já confirmado pelo servidor.

Removidos no revamp (não recrie): `UI/Router`, `UI/Store`, `UI/Modal`, `UI/Toasts`,
`UI/Components`, `UI/Focus`, `UI/Layers`, `UI/CommandAdapter`, `View/Ui`, `View/Motion`,
`View/Hud`, `View/HudPanels`, `Controllers/PlayController` e `Controllers/ScreenController`.

## Estado da implementação (2026-09-16)

O jogo foi implementado nesta raiz: `src/` (Luau estrito), `tests/` (Lune), `tools/` (geradores), `assets/export/` (exports e uploads), `docs/` (SETUP, TEST_REPORT, MANUAL_ACTIONS, MILESTONES) e `build/`. Leia `docs/SETUP.md` para abrir e testar. `Config/Balance.luau`, `Config/Maps.luau` e `Config/Assets.luau` são gerados: altere o JSON ou o registro e rode as ferramentas em `tools/`, nunca edite os módulos gerados à mão.

## Inimigos e chefes (2026-09-18)

`Assets_Inimigos_Bosses_v1/` traz 11 poses estáticas (8 inimigos e 3 chefes) e `enemy_visuals.json`, com o comportamento especificado em `Assets_Inimigos_Bosses_v1/GUIA_MONSTROS_E_BOSSES.pdf`. Os `localFile` desse manifesto são relativos a essa pasta; os `sourceFile`, a esta raiz. Pipeline: `tools/export_enemy_assets.py` → `tools/merge_enemy_index.py` → `tools/update_asset_registry.py`. O movimento 2D fica em `src/client/View/EnemyAnimator.luau` (espelho de `enemy_visuals.json`); as poses não são atlas e os 96 + 48 quadros desenhados continuam pendentes.

## Interface completa (2026-09-18)

As 49 pranchas de `UI_Quintal_em_Guarda_v1` estão implementadas como componentes nativos. Os insumos de build (dados, ícones, guia, exemplos) foram copiados para `UI_Quintal_em_Guarda_v1/` na raiz; as pranchas PNG/SVG continuam no Drive e são **referência**, nunca interface — nada de `ImageLabel` de tela inteira.

A base **era** `src/client/UI/` (Anim, Components, Modal, Toasts, Router, Store…) com `View/Hud`
para o combate. Depois do revamp de 2026-09-19 tudo isso foi substituído por Fusion + Charm: veja a
seção "Revamp" acima. A tabela prancha → módulo vive em `docs/ui_coverage.json`.

`Config/UiTokens.luau`, `Config/UiMotion.luau` e `Config/UiIcons.luau` são **gerados** por `tools/import_ui_tokens.py` e `tools/export_ui_icons.py`; altere o JSON do pacote e rode as ferramentas. O gerador de tokens falha quando um par texto/fundo cai abaixo do contraste mínimo. `tools/check_ui_coverage.py` valida `docs/ui_coverage.json` contra as 49 pranchas e gera `docs/UI_COVERAGE.md`: ao mexer numa tela, atualize a linha dela.

Os 24 ícones foram enviados em 2026-09-18 e `UiIcons` traz os IDs reais; a moderação ainda não foi conferida. O código continua tolerando `image = nil` (glifo de reserva), e a ferramenta nunca inventa `rbxassetid`: sem `assets/export/ui_upload_log.json`, ela volta a emitir `nil`. Tabela e procedimento em `docs/MANUAL_ACTIONS.md`.

## Mapa desenhado e HUD sangrado (2026-09-19)

Cada mapa é uma **cena única** (piso, caminho e cenário na mesma imagem).
`assets/export/map_scene_overrides.json` guarda origem, sha256, id publicado, `playRect` (a fração
da imagem ocupada pela grade 16×10) e as chaves `includesPath` / `includesBase`;
`tools/update_asset_registry.py` leva isso para `Config/Assets.luau`. As artes atuais **não** trazem
o Farol: ele continua desenhado por código na última célula do caminho.

Arte nova nunca é encaixada no olho: `python3 tools/fit_map_scene.py <arte.png> --overlay g.png`
mede a malha de ladrilhos desenhada e devolve `playRect`, a rota em células e os bloqueios, mais
uma imagem de conferência. A rota do mapa em `balanceamento_v1.json` segue o desenho (e não o
contrário). Para encomendar arte nova, use `docs/GUIA_ARTE_DE_MAPA.md` e os gabaritos de
`docs/map_templates/` (gerados por `tools/make_map_template.py`).

`BoardTransform` tem três quadros: `window` (a tela inteira, que recorta), `stage` (a grade 16:10
centrada — é ele que manda em célula, zoom e deslocamento) e `world` (o zoom). O tabuleiro é
montado na camada do cenário (`QuintalWorld`, sem área segura) pelo `App`, não pelo HUD: a arte
passa por baixo da barra do Roblox e o HUD flutua por cima. Painel que engole toque precisa de
`Active` (`blocking = true` no `Kit.panel`), porque a decisão "toque no painel ou no tabuleiro?" é
por ordem de desenho.

O HUD de combate (`UI/Screens/Hud.luau`) segue a maquete: fichas no canto superior esquerdo,
velocidade/opções/sair no superior direito, coluna TORRES à direita, contexto no inferior esquerdo
e, no rodapé, Pulso de Luz e o botão verde Iniciar Onda. Não há mais faixa superior nem doca.

## Entrada, ritmo e interruptores (2026-09-19)

Arrastar (botão esquerdo ou um dedo) move a câmera e **nunca** constrói: o toque parado é que
constrói. O botão direito parado cancela o modo de construção. O zoom padrão deixa a grade em 86%
da janela (`BoardTransform.BASE_FIT`).

A torre olha para o alvo espelhando a própria textura (`ImageRectOffset = {w, 0}` com
`ImageRectSize = {-w, h}`), sem sprite espelhado e sem girar — não recrie o pipeline de espelho.

O **Pulso de Luz** não tem mais botão no rodapé: o Farol acende quando a recarga termina (halo
dourado e o aviso "Segure no Farol") e o jogador **segura 1,5 s em cima dele**, com a barra
enchendo acima do sprite. Mover o ponteiro vira deslocamento de câmera e cancela a carga. O gesto
é lido pelo `InputController` (`onHoldStart`/`onHoldEnd`), contado no `BoardPresenter` e desenhado
pelo `BoardRenderer`; o disparo continua sendo um pedido ao servidor.

Régua de layout: a interface é escrita em pixels de referência (1280x720 no computador, 760x340 no
compacto) e escalada por um `UIScale`. O **HUD** tem métricas por modo (tabela `Metrics` em
`Screens/Hud.luau`: fichas no rodapé à direita no computador, no topo à esquerda no compacto; doca
de torres em coluna ou em grade 2x2). As **telas de menu** não têm layout compacto próprio: em tela
pequena elas encolhem inteiras (`Responsive.menuScale`, usado pelo `App` nas camadas de menu e
modal), porque é melhor um menu miúdo do que um botão fora da borda.

O fim de onda entra como aviso grande (`Atoms.announce` + `Actions.announce`, limpo pelo relógio
do `App`), e a contagem da próxima onda é desenhada na entrada do caminho pelo `BoardRenderer`.

`Config/Brand.luau` é **gerado** por `tools/import_brand_assets.py` a partir de
`assets/export/brand_assets.json` e guarda o logotipo e o fundo da tela de entrada. A ilustração
só aparece nas rotas `boot`/`menu`; nas outras telas o cenário claro procedural (`Skin.scenery`)
continua valendo, porque os painéis delas são tinta escura.

`src/shared/Config/DevFlags.luau` é escrito à mão (não é gerado) e vale para cliente e servidor.
Hoje `unlockAllMaps = true`: a regra de campanha continua em `ProfileSchema.campaignUnlocked`, que
é o que os testes cobrem. Desligar antes de publicar.

## Console de teste (2026-09-20)

`DevFlags.testConsole` publica o console **Cmdr** (tecla F2). O Cmdr é dependência de servidor
(`ServerPackages`): só a interface (`ReplicatedStorage.CmdrClient`) e as definições dos comandos
chegam ao cliente. Os comandos vivem em `src/server/Console/Commands/` aos pares — `<nome>.luau`
(definição, replicada) e `<nome>Server.luau` (execução, só servidor) — e são `setCoins`,
`setHealth`, `forceWin [stars]` e `forceLoss`. Nome de comando em inglês é a convenção do console;
comentários e recados continuam em português.

Nenhum comando escreve no estado da partida: todos chamam as funções `cheat*` do `MatchService`,
que validam permissão (`isDevAllowed`: Studio ou `DEV_ALLOWLIST`) e estado. O fim forçado usa
`Simulation.devFinish`, que reaproveita o `finishMatch` do fim normal e apenas troca as estrelas.

## Campanha por fases (2026-09-19)

Não existe mais tutorial: o jogo é uma campanha de fases declaradas em
`Pacote_Claude_Code/dados/balanceamento_v1.json` (bloco `campaign`), geradas em `Config/Balance`.
Cada fase aponta mapa, número de ondas, escala de vida, sucata inicial e **dois objetivos**; a
primeira estrela é sempre vencer e as outras duas saem desses objetivos, avaliados no servidor por
`Rules/Stars` (regra pura) sobre `MatchState.campaignStats`. Ao acrescentar um objetivo novo, ele
precisa existir em três lugares: `Stars.objectiveMet`, a validação em `tools/import_balance.py` e o
texto em `Localization` (a interface lê pelo mesmo `objectiveText`).

O perfil guarda o melhor resultado por fase em `campaign[levelId]` (v3 do esquema) e a fase
seguinte abre com pelo menos uma estrela na anterior — `ProfileSchema.campaignUnlocked` é a regra,
`isLevelUnlocked` é o que o jogo pergunta (respeita `DevFlags.unlockAllMaps`).

A fase 1 é a única com `manualWaveStart` (as ondas esperam o jogador chamar) e `intro`: um guia de
três passos mostrado uma vez por perfil (`campaignIntroSeen`, marcado pelo servidor quando a
primeira onda sai). O guia é só apresentação — quem valida construção continua sendo a simulação.
