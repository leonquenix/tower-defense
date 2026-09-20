# SETUP — Quintal em Guarda

Projeto Roblox 2D (Luau estrito + Rojo). Esta pasta (`Quintal_em_Guarda_Pacote_Completo_v1_1`) é a raiz do projeto: documentação, 40 PNGs originais, `src/`, `tests/`, `tools/`, `assets/export/` e `build/`.

## Requisitos

| Ferramenta | Versão fixada | Uso |
| --- | --- | --- |
| Rojo | 7.5.1 | sync com o Studio e build do `.rbxl` |
| Wally | 0.3.2 | dependências de terceiros (`wally.toml` / `wally.lock`) |
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

## Dependências (Wally)

```bash
.toolchain/bin/wally install
```

Cria `Packages/` (compartilhado) e `ServerPackages/` (só servidor). As duas pastas são geradas e
não entram no git; `wally.lock` entra, então todo mundo instala exatamente as mesmas versões.

| Pacote | Versão | Para quê |
| --- | --- | --- |
| `elttob/fusion` | 0.3.0 | interface reativa: todas as telas e o HUD |
| `littensy/charm` | 0.10.0 | átomos de estado do cliente (0.10 usa `require` clássico, que Lune e luau-lsp resolvem) |
| `ffrostflame/bytenet` | 0.4.6 | pacotes binários tipados no lugar de RemoteEvents à mão |
| `sleitnick/trove` | 1.8.0 | limpeza determinística de conexões |
| `lm-loleris/profilestore` | 1.0.3 | perfis com trava de sessão (só servidor) |
| `evaera/cmdr` | 1.12.0 | console de teste em jogo, tecla F2 (só servidor; a interface é publicada por ele) |

As fachadas tipadas em `src/shared/Lib/` fixam o caminho do índice do Wally porque o arquivo de
ligação gerado esconde os tipos do analisador. `python3 tools/check_package_facades.py` confere se
esses caminhos continuam iguais ao `wally.lock` depois de qualquer atualização.

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

### Console em jogo (Cmdr, tecla F2)

Ligado por `DevFlags.testConsole` e aberto com **F2** dentro da partida. Quem pode usá-lo é a mesma
regra do `DevCommand`: Studio ou UserId em `DEV_ALLOWLIST` (`MatchService.luau`). Fora disso o
gancho `BeforeRun` recusa, e sem o gancho o próprio Cmdr recusaria tudo.

| Comando | Argumento | O que faz |
| --- | --- | --- |
| `setCoins <amount>` | inteiro | define a sucata do jogador na partida (apelidos: `setScrap`, `coins`) |
| `setHealth <health>` | inteiro | define a vida do Farol; zero derruba no passo seguinte (apelidos: `setHp`, `hp`) |
| `forceWin [stars]` | inteiro 0–3, opcional | encerra como vitória com as estrelas pedidas (padrão 3); apelido `win` |
| `forceLoss` | — | encerra como derrota; apelido `lose` |

Os nomes dos comandos são em inglês de propósito (é a convenção do Cmdr e do que se digita num
console); o resto do código e os recados continuam em português.

As definições ficam em `src/server/Console/Commands/`: `<nome>.luau` descreve o comando e é
replicado ao cliente pelo Cmdr, `<nome>Server.luau` executa e nunca sai do servidor. Toda ordem cai
nas funções `cheat*` do `MatchService`, que validam estado e permissão — o console não escreve no
estado da partida. `forceWin`/`forceLoss` passam pelo `Simulation.devFinish`, o mesmo caminho do
fim normal: o laço do MatchService vê `state.result` pronto, paga e salva as estrelas.

### DevCommand

Ação `DevCommand` (aceita apenas no Studio ou para UserIds em `DEV_ALLOWLIST` de `MatchService.luau`): `grantScrap`, `startWave`, `killAll`, `setBaseHP`, `summary`. Exemplo pelo console do cliente:

```lua
-- o transporte é ByteNet: o caminho normal é o mesmo do jogo
local Client = require(game.Players.LocalPlayer.PlayerScripts.Client.Net.Client)
Client.request("DevCommand", { command = "grantScrap", arg = 5000 })
```

## Estrutura

```
default.project.json     árvore Rojo (Shared, Packages, Server, ServerPackages, Client)
wally.toml / wally.lock  dependências de terceiros
src/shared               Types, Config (gerados), Math, Rules, Sim (simulação pura), Profile, Util
  Lib/                   fachadas tipadas de Fusion, Charm e Trove
  Net/                   Protocol (validação pura), Enums + Codec (puros), Packets (ByteNet)
src/server               Bootstrap + Net/Server (fachada ByteNet) + Services
                         (Match, Command, Console, Party, Menu, PlayerData, Reward, Shop, Telemetry)
  Console/Commands/      comandos do console de teste (definição + par `*Server`)
src/client
  State/                 Atoms (Charm), Selectors, Actions, Bridge (Charm -> Fusion)
  Net/                   Client (pedido/resposta sobre ByteNet) e Commands (uma pendência por chave)
  UI/                    Kit (componentes Fusion), Skin (profundidade e cenário), App (camadas e rotas),
                         Screens/ e Overlays/
  View/                  tabuleiro imperativo: BoardTransform, BoardRenderer, Juice, animadores, Theme
  Controllers/           Match (rede -> átomos), BoardPresenter, GameFlow, Input, Settings, Audio, Console
tests/                   runner Lune, loader Roblox-like (inclui Packages) e specs
tools/                   geradores e exportadores (Python) + bootstrap da toolchain
assets/export            exports normalizados, manifesto de export, log de uploads e placeholders
docs/                    SETUP, TEST_REPORT, MANUAL_ACTIONS, MILESTONES, UI_COVERAGE
```

## Arquitetura do cliente (revamp 2026-09-19)

Fluxo de um toque, do botão ao pixel:

1. a tela (Fusion) chama `Controllers/GameFlow`;
2. `GameFlow` chama `Net/Commands`, que garante **uma pendência por chave** e preserva o
   `requestId` numa repetição (o servidor deduplica em vez de cobrar duas vezes);
3. `Net/Client` manda o pacote `command` e espera o `result` correlacionado;
4. o servidor valida em `Net/Protocol`, aplica na simulação e responde;
5. o próximo quadro chega como pacote `frame` (snapshot + eventos), é decodificado por
   `Net/Codec` e escrito nos átomos Charm;
6. a interface reage por leitura dos átomos; o tabuleiro (imperativo, 60 Hz) desenha o que
   `MatchController` interpolou.

Nenhum passo do caminho de volta confia no cliente: dano, preço e resultado continuam sendo do
servidor. `View/Juice` só é chamado por eventos que o servidor já confirmou.

## Inimigos, chefes e movimento

`src/client/View/EnemyAnimator.luau` é o espelho tipado de `Assets_Inimigos_Bosses_v1/enemy_visuals.json`: um ciclo por tipo (salto, corrida, compressão, passada, flutuação, balanço), impacto de 0,12 s, tremor do Casulo na morte, pose de aviso e de habilidade dos chefes. As amplitudes são frações do quadro de referência de 128 px, então valem em qualquer resolução. O relógio é o tempo de simulação (1x e 2x usam o mesmo ciclo lógico) e movimento reduzido desliga os ciclos decorativos sem afetar posição, barra de vida nem avisos.

As 11 poses são estáticas: não existe atlas nem recorte por quadro. Ao produzir os 96 quadros de inimigos e 48 de chefes, trocar `renderMode` em `runtime_asset_registry.json` e implementar o recorte em `BoardRenderer`.

## Responsividade

`View/Responsive.luau` escolhe o modo de layout (computador ou compacto) e uma escala uniforme (≥ 1)
a partir do tamanho real da janela. As transições vivem nos próprios componentes (molas e tweens do
Fusion, com durações de `Config/UiMotion`). Para ajustar limites, edite `Responsive.MIN_DESKTOP` e as
referências `REFERENCE_DESKTOP`/`REFERENCE_COMPACT`. Quando o modo muda — ou quando o idioma muda —
`UI/App.mount()` remonta a árvore inteira: texto e layout são escritos na construção.
