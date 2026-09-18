# SETUP — Quintal em Guarda

Projeto Roblox 2D (Luau estrito + Rojo). Esta pasta (`Quintal_em_Guarda_Pacote_Completo_v1_1`) é a raiz do projeto: documentação, 40 PNGs originais, `src/`, `tests/`, `tools/`, `assets/export/` e `build/`.

## Requisitos

| Ferramenta | Versão fixada | Uso |
| --- | --- | --- |
| Rojo | 7.5.1 | sync com o Studio e build do `.rbxl` |
| Lune | 0.9.3 | testes de regras fora do Studio (`tests/`) |
| luau-lsp | 1.69.0 | análise estática estrita (`--!strict`) |
| selene | 0.31.0 | lint |
| StyLua | 2.1.0 | formatação |
| Python | 3.9+ com Pillow | geração de módulos de dados e exports de imagem |
| Roblox Studio | 0.739+ | execução e testes no motor |

Instalação reproduzível (macOS arm64/x86_64):

```bash
bash tools/bootstrap_toolchain.sh
```

O script baixa os binários fixados em `rokit.toml` para `.toolchain/bin/` e o arquivo de tipos do Roblox (`.toolchain/globalTypes.d.luau`). Quem usa [rokit](https://github.com/rojo-rbx/rokit) pode simplesmente rodar `rokit install`.

## Gerar dados e assets

```bash
python3 tools/import_balance.py          # valida dados/balanceamento_v1.json e gera Config/Balance.luau + Config/Maps.luau
python3 tools/export_assets.py           # exports normalizados dos 40 PNGs em assets/export (originais preservados)
python3 tools/export_enemy_assets.py     # exports dos 11 PNGs de inimigos/chefes (128 px) e chefes (256 px)
python3 tools/merge_enemy_index.py       # acrescenta os 11 registros ao asset_index.json e ao registro de runtime
python3 tools/update_asset_registry.py   # atualiza runtime_asset_registry.json e gera Config/Assets.luau (só com IDs de uploads reais)
python3 tools/import_ui_tokens.py        # gera Config/UiTokens.luau e Config/UiMotion.luau do pacote de UI
python3 tools/export_ui_icons.py         # exporta os 24 ícones para assets/export/ui e gera Config/UiIcons.luau
python3 tools/check_ui_coverage.py       # valida docs/ui_coverage.json contra as 49 pranchas e gera docs/UI_COVERAGE.md
```

`import_ui_tokens.py` também confere o contraste dos pares texto/fundo declarados e falha (exit 1)
quando algum cai abaixo de 4,5:1 (3:1 para texto grande). Foi assim que `dangerSoft` e `tealDark`
acabaram ajustados e `goldText` passou a existir separado de `goldDark`, que virou cor só de
preenchimento.

`export_ui_icons.py` nunca inventa `rbxassetid`: sem `assets/export/ui_upload_log.json`, o módulo
gerado traz `image = nil` e o cliente desenha o glifo de reserva. A tabela de upload está em
`docs/MANUAL_ACTIONS.md`.

`import_balance.py` falha com código 1 se houver ID desconhecido, custo inválido, salto de evolução, caminho diagonal, bloqueio sobre caminho ou célula fora da grade. Os módulos gerados carregam o sha256 do JSON de origem.

`export_enemy_assets.py` normaliza as 11 poses de `Assets_Inimigos_Bosses_v1/` com apoio em (0,5; 0,82) e calcula `frameWidthCells` por tipo, de modo que a largura visível em células corresponda a `enemy_visuals.json`. Ele grava `assets/export/enemy_export_manifest.json` e as pranchas `review_enemies_light.png` e `review_enemies_dark.png` (conferência sobre fundo claro e escuro). `tools/generate_placeholder_enemies.py` continua existindo, mas os placeholders procedurais deixaram de ser usados: `update_asset_registry.py` só os emite para chaves sem arte real.

## Verificações

```bash
.toolchain/bin/lune run tests/run.luau                      # testes de regras (Combat, Circuits, Rewards, Simulation, Protocol, Profile)
.toolchain/bin/rojo sourcemap default.project.json -o build/sourcemap.json
.toolchain/bin/luau-lsp analyze --definitions=.toolchain/globalTypes.d.luau --base-luaurc=.luaurc --sourcemap=build/sourcemap.json --ignore="**/Balance.luau" src/
.toolchain/bin/selene src/
.toolchain/bin/stylua --check src/
```

`tests/run.luau` escreve um resumo em `tests/last_run.json`. Um filtro opcional seleciona specs por nome: `lune run tests/run.luau 03_`.

Os specs `07_ui_tokens` e `08_ui_state` cobrem a parte da interface que roda fora do motor: contraste
da paleta, durações das animações, biblioteca de ícones, expiração e cooldown de convites, máquina de
estados da conexão e cobertura de texto nos dois idiomas. O que depende de `Instance` (layout, foco,
toque) só pode ser verificado no Studio — ver `docs/UI_COVERAGE.md`.

## Estrutura da interface

```
src/client/UI/
  Accessibility  preferências efetivas (Roblox + jogo): movimento reduzido e texto ampliado
  Anim           animações guiadas por Config/UiMotion, um controlador por propriedade
  Focus          Tab/setas/Enter, escopos de camada e retorno de foco ao fechar modal
  Components     PaperPanel, ActionButton (oito estados), chip, barra, toggle, slider, tooltip, ícone
  Modal          família compartilhada de confirmações (prancha 38)
  Toasts         fila de no máximo três, deduplicada por 1 s
  CommandAdapter um pedido pendente por ação, mesmo requestId na reconciliação
  Layers         ScreenGuis mundo/HUD/menu/modal/toast (DisplayOrder 0/10/20/30/40)
  Router         pilha de telas; Configurações volta para a origem
  Store          perfil, grupo, salas, convites, conexão e recompensa pendente
  InviteCards    cartões de convite recebidos, com contagem de 30 s
  Screens/       as telas de menu, uma por arquivo
src/client/View/
  Hud            HUD de combate (faixas, cartas, construção, detalhe, tutorial e treino)
  HudPanels      barra de chefe, menu de alvo, popover de velocidade, opções e aviso de conexão
  Ui             adaptador fino sobre Components/Modal/Toasts para o código de combate
```

A regra de ouro do pacote de UI vale aqui: **as 49 pranchas são referência**. Nenhuma foi importada
como imagem de tela; só a arte de personagens, terrenos e os 24 ícones entram como `ImageLabel`.

## Abrir no Roblox Studio

Opção A — sincronizar com o place aberto (recomendado durante o desenvolvimento):

1. `.toolchain/bin/rojo serve default.project.json --port 34872`
2. No Studio, aba **Plugins → Rojo → Connect** (`localhost:34872`). O plugin pode ser instalado com `.toolchain/bin/rojo plugin install` (grava em `~/Documents/Roblox/Plugins`).
3. Aperte **Play** (F5). O servidor cria os remotes em `ReplicatedStorage/QuintalNet`; o cliente monta o `ScreenGui` `QuintalApp` em `PlayerGui`.

Opção B — abrir o arquivo de lugar gerado:

```bash
.toolchain/bin/rojo build default.project.json -o build/QuintalEmGuarda.rbxl
```

Abra `build/QuintalEmGuarda.rbxl` no Studio e aperte Play. O arquivo contém apenas a árvore do projeto (código e configuração); as imagens são referenciadas por `rbxassetid://` e exigem que a conta que abre o place tenha acesso aos assets (foram enviados pela conta logada no Studio durante a implementação — ver `assets/export/upload_log.json`).

## Como jogar

- **Menu**: Jogar (abre o tutorial na primeira vez), Coleção, Treino, Configurações, Loja (desativada).
- **Combate**: toque em uma carta de torre, toque em uma célula e confirme o preço. Selecione uma torre para melhorar, mudar alvo ou vender. Pulso de Luz exige dois toques. 2x é votado pelo grupo.
- Teclado: `1`–`4` escolhe torre, `Esc` cancela, `U` melhora a torre selecionada quando há uma única evolução. Roda do mouse dá zoom; botão direito/meio arrasta. Toque: pinça e dois dedos arrastam; **Ver tudo** volta à visão completa.
- **Treino**: sucata infinita, todas as torres, gerar 1 ou 10 inimigos, limpar tabuleiro, alcances e Circuitos visíveis.
- **Grupo**: Criar grupo → outros jogadores do mesmo servidor entram pelas salas ou por convite; o líder escolhe mapa e dificuldade; membros marcam Pronto.

## Dados no Studio

Sem "Enable Studio Access to API Services" (padrão de um place não publicado), o `DataStoreService` não está disponível. O servidor detecta isso e usa um **perfil volátil** (apenas no Studio) para permitir testar; a interface mostra "Progresso não salvo". Em produção, a mesma falha mantém o jogador no menu com opção de tentar novamente ou treinar, sem gravar padrões sobre um perfil existente.

Os DataStores usam nomes com sufixo `_studio` quando rodando no Studio, separando dados de teste dos de produção.

## Ferramentas de desenvolvimento

Ação `DevCommand` (aceita apenas no Studio ou para UserIds em `DEV_ALLOWLIST` de `MatchService.luau`): `grantScrap`, `startWave`, `killAll`, `setBaseHP`, `summary`. Exemplo pelo console do cliente:

```lua
game.ReplicatedStorage.QuintalNet.Command:InvokeServer({protocolVersion=1, sessionSequence=999990, requestId="dev-1", action="DevCommand", payload={command="grantScrap", arg=5000}})
```

## Estrutura

```
default.project.json     árvore Rojo (ReplicatedStorage/Shared, ServerScriptService/Server, StarterPlayerScripts/Client)
src/shared               Types, Config (gerados), Math, Rules, Sim (simulação pura), Net/Protocol, Profile, Util
src/server               Bootstrap + Services (Match, Command, Party, Menu, Profile, Reward, Shop, Telemetry)
src/client               Bootstrap + Controllers (Screen, Play, Match, Input, Settings, Audio) + View (Board, Hud, Menu, TowerAnimator, EnemyAnimator, ...)
tests/                   runner Lune, loader Roblox-like e specs
tools/                   geradores e exportadores (Python) + bootstrap da toolchain
assets/export            exports normalizados, manifesto de export, log de uploads e placeholders
docs/                    SETUP, TEST_REPORT, MANUAL_ACTIONS, MILESTONES
```

## Inimigos, chefes e movimento

`src/client/View/EnemyAnimator.luau` é o espelho tipado de `Assets_Inimigos_Bosses_v1/enemy_visuals.json`: um ciclo por tipo (salto, corrida, compressão, passada, flutuação, balanço), impacto de 0,12 s, tremor do Casulo na morte, pose de aviso e de habilidade dos chefes. As amplitudes são frações do quadro de referência de 128 px, então valem em qualquer resolução. O relógio é o tempo de simulação (1x e 2x usam o mesmo ciclo lógico) e movimento reduzido desliga os ciclos decorativos sem afetar posição, barra de vida nem avisos.

As 11 poses são estáticas: não existe atlas nem recorte por quadro. Ao produzir os 96 quadros de inimigos e 48 de chefes, trocar `renderMode` em `runtime_asset_registry.json` e implementar o recorte em `BoardRenderer`.

## Responsividade

`View/Responsive.luau` escolhe o modo de layout (computador ou compacto) e uma escala uniforme (≥ 1) a partir do tamanho real da janela; `View/Motion.luau` concentra as transições. Para ajustar limites, edite `Responsive.MIN_DESKTOP` e as referências `REFERENCE_DESKTOP`/`REFERENCE_COMPACT`. O HUD e o menu são reconstruídos automaticamente quando o modo muda.
