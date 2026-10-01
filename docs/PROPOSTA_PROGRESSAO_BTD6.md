# Quintal em Guarda — Progressão, economia, melhorias e multiplayer no modelo Bloons TD6

*Documento de análise e proposta. Versão de 2026-09-26, escrita sobre a branch `feature/revamp` (commit `4e0bde3`). A seção 1 descreve o jogo como ele está no código e nos dados; as seções 2 a 9 são proposta, não implementação. Todos os números novos são hipóteses sem playtest, no mesmo espírito do `balanceamento_v1.json` (`status: seed_balance_not_playtested`).*

## 0. Guia para quem revisa

**O que este documento é.** Três coisas: um retrato factual do estado atual do jogo, extraído do código e dos dados (seção 1); uma proposta de sistemas novos de progressão, economia, melhorias e multiplayer inspirada em Bloons TD 6 (seções 2 a 7); um roteiro em etapas e uma lista de decisões em aberto (seções 8 e 9).

**Como ler.** Seção 1 é fato. Seções 2 a 9 são proposta. Toda tabela numérica da proposta é chute inicial para calibrar em playtest, não balanceamento comprovado.

**Princípios que a proposta não pode violar** (vêm do design original e do código):

- Nada que se compra com dinheiro real afeta o combate. Vende-se aparência e tempo.
- Combate autoritativo no servidor; animação e projéteis nunca decidem dano; regras de jogo são módulos puros e testáveis sem Roblox.
- Legível no celular em paisagem: poucos botões, grandes, sem depender de chat.
- Interface 2D em ScreenGui; nada de lobby 3D.
- Sem herói móvel, sem PvP, sem gacha, sem labirinto livre na primeira versão.

**O que pedimos à revisão:**

1. Onde a proposta contradiz o estado atual, os princípios acima ou a si mesma?
2. A curva de XP e os custos de Domínio criam paredes ou buracos de ritmo? Em quantas partidas um jogador novo chega ao nível 9 (Voltz) e ao primeiro L3? Isso é rápido ou lento demais para o público do Roblox?
3. A economia de coop (sucata inicial e renda de onda inteiras por jogador, abate dividido, vida dos inimigos +70 % por jogador extra) continua coerente quando entram zonas de construção?
4. Zonas em um tabuleiro de 16×10 com caminho fixo: cabem 4 jogadores sem sufocar? Há alternativa melhor que zonas para o problema "quem chega primeiro pega a célula boa"?
5. Os modos propostos (Só Iniciais, Sucata Contada, Meia Sucata, Chefes Reforçados, Apocalipse, Farol Frágil, Reverso, Sem Muletas) são jogáveis no celular e fazem sentido com 6 torres e 8 inimigos? Qual cortar, qual falta?
6. A grade mapa × dificuldade × modo entrega replay suficiente com 3 mapas? O que fazer até os mapas Praia e Neve chegarem?
7. Botões: a fórmula proporcional às ondas mais o bônus de primeira medalha sustenta a loja de cosméticos e os pacotes de botões do plano de monetização sem parecer pay-to-win?
8. Riscos técnicos: MemoryStore e Teleport para código de sala e fila rápida; migração de perfil v3→v4; custo de simulação com Apocalipse (duas ondas vivas) e com o modo infinito.
9. Retenção: o que Tower Defense Simulator, Tower Heroes ou o próprio BTD6 fazem que ainda falta aqui (recompensa diária, conquistas, eventos, coleção, ranking)? Priorize por custo/benefício para uma equipe de duas pessoas.
10. Onboarding: a fase 1 com guia de três passos e ondas manuais continua adequada com os sistemas novos por cima? Onde um jogador novo se perderia?
11. Há áreas que a proposta não toca e deveria: chefes, Circuitos, acessibilidade, telemetria, anti-abuso de comandos, desempenho em servidor com várias partidas?

## 1. Estado atual do jogo (fatos, setembro de 2026)

### 1.1 Ficha técnica

| Item | Estado |
|---|---|
| Nome | Quintal em Guarda (provisório). Fantasia: brinquedos esquecidos defendem o Farol de Pilha contra criaturas de poeira quando a casa dorme. |
| Plataforma | Roblox; Luau estrito; Rojo 7.5.1; dependências pelo Wally (Fusion 0.3, Charm 0.10, ByteNet 0.4.6, ProfileStore 1.0.3, Trove; Cmdr só no servidor). |
| Apresentação | 2D em ScreenGui. Tabuleiro de 16 colunas × 10 linhas, célula lógica 1, cena única por mapa (piso, caminho e cenário numa imagem), sprites com pool a 60 Hz. |
| Simulação | Servidor autoritativo, passo fixo de 0,05 s (20 Hz), até 6 passos por Heartbeat, snapshots a 10 Hz com quadro completo a cada 2 s. Determinística e sem dependência do Roblox (roda nos testes Lune). |
| Dispositivos | Computador, celular e tablet em paisagem. Régua de 1280×720 (computador) e 760×340 (compacto), escalada por UIScale. Menus encolhem inteiros em tela pequena. |
| Idiomas | Português do Brasil e inglês, em `Config/Localization`. |
| Grupo | Solo ou 2 a 4 jogadores no mesmo servidor. Servidor de 12 jogadores. |
| Publicação | Não publicado. Loja desligada. `DevFlags.unlockAllMaps = true` e `testConsole = true` para teste; devem voltar a `false` antes de publicar. |
| Testes | 179 testes Lune aprovados em 13 specs (verificado em 2026-09-26 após `wally install`); selene, StyLua e luau-lsp limpos no último relatório. |
| Marcos | M0 Fundação, M1 Combate, M2 Diferencial e M3 Conteúdo concluídos; M4 Serviço com código pronto e testes de concorrência real pendentes; M5 Apresentação concluído com visuais provisórios; M6 Candidato não iniciado (depende de ações externas); M7 Revamp de arquitetura e apresentação feito entre 19 e 21/09. |

### 1.2 Arquitetura

| Camada | Módulos | Papel |
|---|---|---|
| Cliente, interface | `UI/App`, `UI/Kit`, `UI/Skin`, `UI/Screens/*`, `UI/Overlays/*`, `UI/Accessibility` | Fusion 0.3. O Kit é a única fonte de botões, painéis, modais e avisos; Skin dá profundidade e cenário; App monta camadas e rotas. |
| Cliente, estado | `State/Atoms`, `State/Selectors`, `State/Actions`, `State/Bridge` | Charm 0.10. Átomos são fatos, seletores derivam, ações mudam; a interface só lê. |
| Cliente, tabuleiro | `View/BoardRenderer`, `BoardTransform`, `SpritePool`, `EnemyAnimator`, `TowerAnimator`, `Juice`, `Responsive`, `Theme` | Renderizador imperativo de sprites. Tremor, clarão, partículas e números só depois de evento confirmado pelo servidor e sempre atrás das preferências de conforto. |
| Cliente, controle | `Controllers/GameFlow`, `BoardPresenter`, `MatchController`, `InputController`, `BuildIntent`, `SettingsController`, `AudioController`, `ConsoleController` | Fluxo de telas, intenção de construção (clique parado constrói, arrastar move câmera), gesto do Pulso, áudio, console. |
| Rede | `Net/Enums`, `Net/Packets` (ByteNet), `Net/Codec`, `Net/Protocol`, `Net/Client`, `Net/Commands`; servidor `Net/Server` | Enums e Codec puros e testados; Protocol valida, limita taxa e deduplica; comando pendente do cliente expira em 12 s. |
| Compartilhado | `Config/*`, `Rules/Combat`, `Rules/Circuits`, `Rules/Rewards`, `Rules/Stars`, `Sim/Simulation`, `Sim/Snapshot`, `Profile/ProfileSchema`, `Math/Grid`, `Math/Path`, `Types` | `Balance`, `Maps`, `Assets`, `UiTokens`, `UiMotion`, `UiIcons` e `Brand` são gerados por ferramentas; `Catalog`, `Products`, `DevFlags` e `Localization` são escritos à mão. Regras são módulos puros. |
| Servidor | `MatchService`, `PartyService`, `PlayerDataService`, `RewardService`, `MenuService`, `ShopService`, `TelemetryService`, `ConsoleService`, `Console/Commands/*` | Partidas (laço, comandos, presença, resultado, revanche, atalhos de teste), parties e salas, perfis (ProfileStore), ledger de resultados, menu, loja, telemetria, console Cmdr. |
| Ferramentas | `tools/import_balance.py`, `update_asset_registry.py`, `export_*.py`, `merge_enemy_index.py`, `import_ui_tokens.py`, `export_ui_icons.py`, `import_brand_assets.py`, `fit_map_scene.py`, `make_map_template.py`, `check_ui_coverage.py`, `check_package_facades.py` | JSON canônico → módulos Luau; registro de assets → `Config/Assets`; medição de arte de mapa; cobertura das 49 pranchas de interface. |
| Testes | `tests/run.luau` (Lune 0.9.3), specs 01 grade e caminho, 02 regras, 03 simulação, 04 protocolo, 05 perfil, 06 inimigos e chefes, 07 tokens de UI, 08 estado de UI, 09 codec, 10 estado, 11 juice, 12 intenção de construção, 13 estrelas | Cobrem regras, simulação, migrações de perfil, codec e estado; não cobrem Roblox de verdade (Studio é ação manual registrada em `docs/`). |

### 1.3 Fluxo do jogador e telas

Fluxo: entrada sobre a ilustração de marca → espera do perfil → menu → Jogar Campanha (lista de fases) ou party/salas → partida → resultado → Próxima fase, Revanche ou Menu. Não há tutorial separado: a fase 1 da campanha é o tutorial.

| Tela | O que faz hoje |
|---|---|
| Boot e Loading | Logotipo e fundo de marca; espera o perfil carregar; erro e "tentar de novo" quando o perfil não vem. |
| MainMenu | Jogar Campanha em destaque, Coleção, Cosméticos, Configurações; Loja aparece só quando habilitada. |
| Campaign | As 12 fases em cartões de três colunas com arte do mapa, etiqueta do cenário, nome, três estrelas, os dois objetivos escritos, cadeado nas fases fechadas, contorno dourado na próxima ou nas completas; cabeçalho com contador X/36 estrelas. |
| Party, Rooms, Invites | Criar party, escolher fase e dificuldade (líder), prontidão, lista de salas abertas do servidor, convites com token de 30 s e cartão de convite. |
| Collection | Torres possuídas, torres compráveis com botões (Lupa 240, Maestro 450, Voltz 600), equipe de até 4 vagas, pontos de domínio e marcos. |
| Cosmetics | Equipar adesivo, título, skin e estandarte entre os cosméticos possuídos (domínio ou passe fundador). |
| Shop | Passe Fundador; desligado enquanto não houver ID de passe no Creator Hub. |
| Settings | Volume de música e efeitos, redução de movimento, partículas reduzidas, números de dano, padrão visual do Circuito, idioma. |
| Hud e HudDetail | Combate (abaixo). HudDetail é o painel da torre selecionada: estado, próximos níveis com custo, ramos L3A/L3B, modo de alvo, venda, parceiro de Circuito e bônus. |
| Result | Cartão com mola; três estrelas entrando uma a uma; recompensa em botões, domínio, status de gravação; botão da direita vira Próxima fase (vitória), Revanche (derrota) ou Campanha (última fase). |
| Overlays | ModalHost, Toasts, InviteCards, Orientation (pede paisagem no celular). |

**HUD de combate.** Fichas de estado (vida do Farol, onda, sucata pessoal, torres) em bloco de duas linhas no canto inferior direito (no compacto, no topo à esquerda); velocidade e Pausa no superior direito; doca TORRES à direita com as até quatro torres da equipe (no compacto vira o botão BUILD que abre e fecha); painel de objetivos da fase com estado ao vivo; contexto de construção no inferior esquerdo; rodapé só com o botão verde Iniciar Onda. Fim de onda aparece como aviso grande e a contagem da próxima é desenhada na entrada do caminho. Pausa é uma cortina com objetivos, Continuar, Opções e Sair: não para a simulação (em grupo pausaria o jogo dos outros). Construir: no computador o clique parado constrói; no toque, o segundo toque na mesma célula; arrastar sempre move a câmera. Pulso de Luz: quando recarregado o Farol acende e o jogador segura 1,5 s sobre ele. Melhorar uma torre dispara anéis, faíscas, texto do novo estado e tremor curto.

### 1.4 Regras de partida

| Regra | Valor atual |
|---|---|
| Farol | 100 de vida. Derrota ao chegar a zero; no mesmo passo, derrota tem precedência sobre vitória. |
| Ritmo | 15 s de preparação, 8 s entre ondas. Fase 1: ondas manuais (o jogador chama). Pronto por unanimidade dos ativos adianta; adiantar rende 5 sucatas por segundo restante, máximo 80, a cada jogador. |
| Velocidade | 1×; 2× por unanimidade; qualquer um volta a 1×; o servidor força 1× após sobrecarga repetida. |
| Ações | Colocar, melhorar, escolher alvo e vender durante a onda. Venda devolve 70 % do investido, arredondado para baixo. Sem mover torre depois de confirmar. |
| Teto de torres | Por jogador: 18 (solo), 12 (2), 10 (3), 8 (4). Mais o limite por espécie de cada torre. Congelado na largada. |
| Combate | Alcance circular, sem linha de visão; todos os inimigos terrestres; modos de alvo primeiro, último, mais forte, mais perto. Dano físico (Dardo, Pipoca, Lupa) e de energia (Goma, Voltz, Pulso). |
| Pulso de Luz | 180 de dano de energia em todos os vivos e 30 % de lentidão por 3 s; recarga de 60 s; começa carregado; compartilhado pelo grupo (a primeira solicitação consome); escala com o fator de coop; chefes recebem 35 % da lentidão. |
| Efeitos | Teto de lentidão 50 %; teto de armadura física 80 %; cadência, lentidão e marca não acumulam (vale o maior). |
| Presença | 30 s ausente → inativo (sai da unanimidade); todos ausentes por 60 s → abandono; resultado fecha em 120 s; torres de quem saiu continuam atirando; carteira fica em memória. |
| Vida dos inimigos | Comum = catálogo × multiplicador do mapa × dificuldade × `hpScale` da fase × (1 + 0,7 × (jogadores − 1)). Chefe usa a própria vida com dificuldade, coop e `hpScale`, sem o fator do mapa. Arredonda uma vez, para cima. |
| Dificuldades | Normal: vida ×1, 120 botões. Desafio: vida ×1,45, velocidade ×1,10, 160 botões. Sem trava entre elas. |
| Atalhos de teste | Console Cmdr (F2, `DevFlags.testConsole`): `setCoins`, `setHealth`, `forceWin [estrelas]`, `forceLoss`; só no Studio ou para UserIds em `DEV_ALLOWLIST`. |

### 1.5 Torres

Seis torres, cinco estados cada: L0 → L1 → L2 → escolha exclusiva L3A ou L3B. Custos são pagos a cada avanço; a escolha final só muda vendendo. Skins não alteram atributos.

| Torre | Personagem | Função | Dano | Alvo padrão | Limite por jogador | Desbloqueio | Custos L0 / L1 / L2 / L3A / L3B | Ramos (L3A / L3B) |
|---|---|---|---|---|---|---|---|---|
| Dardo | Raposa de madeira | Ataque barato e constante | Físico | Primeiro | 6 | Inicial | 250 / 200 / 450 / 900 / 1000 | Rajada / Fura lata |
| Pipoca | Tartaruga de corda | Explosão contra grupos | Físico | Primeiro | 4 | Inicial | 450 / 300 / 600 / 1200 / 1200 | Festival / Demolidora |
| Lupa | Coruja de papelão | Longo alcance, elites e chefes | Físico | Mais forte | 4 | 240 botões | 500 / 350 / 700 / 1400 / 1300 | Olho de águia / Observadora |
| Goma | Criatura em pote de cola | Lentidão | Energia | Primeiro | 4 | Inicial | 300 / 200 / 400 / 850 / 850 | Poça / Supercola |
| Voltz | Robô de mola | Corrente entre inimigos | Energia | Primeiro | 4 | 600 botões | 550 / 350 / 650 / 1250 / 1250 | Tempestade / Alta tensão |
| Maestro | Caranguejo de rádio | Cadência das torres ao redor | Nenhum | — | 2 | 450 botões | 500 / 300 / 600 / 1150 / 1150 | Orquestra / Solo |

| Torre | L0 (dano · intervalo s · alcance) | L2 | L3A | L3B |
|---|---|---|---|---|
| Dardo | 10 · 0,80 · 2,5 | 28 · 0,70 · 2,9 | 46 · 0,55 · 3,1 | 42 · 0,75 · 3,4; ignora armadura |
| Pipoca | 20 · 1,8 · 2,8; raio 1,0; 6 alvos | 60 · 1,6 · 3,2; raio 1,2; 8 alvos | 95 · 1,4 · 3,4; raio 1,7; 10 alvos | 115 · 1,8 · 3,6; raio 1,1; ignora 50 % da armadura |
| Lupa | 55 · 2,5 · 5,0 | 145 · 2,1 · 5,6 | 280 · 2,2 · 6,0; +25 % em chefes | 170 · 1,6 · 6,0; marca o alvo (+10 % de dano por 3 s) |
| Goma | 3 · 1,0 · 2,3; lentidão 20 % por 1,5 s | 8 · 0,9 · 2,7; 30 % por 2 s | 10 · 0,9 · 3,0; 30 % em área (5 alvos) | 12 · 0,8 · 3,0; 45 % por 2,5 s |
| Voltz | 20 · 1,3 · 2,4; 2 saltos, queda 0,75 | 48 · 1,1 · 2,8; 3 saltos | 60 · 1,0 · 3,0; 5 saltos, raio 1,7, queda 0,80 | 90 · 1,15 · 3,0; 2 saltos, +20 % em chefes |
| Maestro | cadência +8 % no alcance 2,2 | +16 % no 2,6 | +18 % no 3,2 | +25 % no 2,6 |

### 1.6 Circuitos

Par compatível em células ortogonalmente vizinhas se conecta por um fio no chão. Cada torre participa de no máximo um Circuito; vale entre torres de jogadores diferentes; pareamento determinístico pelo menor id de torre e depois pelo maior; recalculado ao comprar e vender; prévia mostra o par que será ativado.

| Par | Nome | Efeito |
|---|---|---|
| Dardo + Goma | Pega e acerta | Dardo causa +15 % de dano a inimigo com lentidão ativa |
| Pipoca + Lupa | Mira explosiva | Pipoca ganha +0,2 célula de raio de explosão |
| Voltz + Maestro | Ritmo elétrico | Queda de dano por salto melhora em 0,10, limitada a 0,90 |

### 1.7 Inimigos e chefes

| Inimigo | Vida | Velocidade | Sucata | Dano no Farol | Armadura | Especial |
|---|---|---|---|---|---|---|
| Fiapo | 24 | 1,25 | 8 | 2 | 0 | Ensina o básico |
| Corrisco | 32 | 2,05 | 10 | 3 | 0 | Rápido; exige cobertura do caminho |
| Bolota | 150 | 0,85 | 22 | 6 | 0 | Lento e resistente |
| Latinha | 115 | 1,00 | 20 | 5 | 0,45 | Reduz dano físico; pede energia ou Fura lata |
| Névoa | 75 | 1,45 | 17 | 4 | 0 | Resiste 35 % ao dano de energia |
| Remendo | 180 | 1,00 | 28 | 6 | 0 | Cura 12 de vida a cada 3 s num raio de 1,5 |
| Casulo | 230 | 0,90 | 30 | 8 | 0,15 | Ao morrer solta 3 Fiapos pequenos (12 de vida, velocidade 1,6, dano 1, sem sucata) |
| Brutamontes | 600 | 0,65 | 65 | 14 | 0,25 | Alvo único pesado |

| Chefe | Mapa | Vida | Velocidade | Armadura | Mecânica | Período |
|---|---|---|---|---|---|---|
| Aspirador Rabugento | Jardim | 7 000 | 0,4 | 0,15 | Anuncia por 2 s uma área de poeira (raio 2) e reduz em 25 % a cadência das torres nela por 4 s | 14 s |
| Rei Ferrugem | Oficina | 8 500 | 0,4 | 0,20 | Anuncia e ganha +0,35 de armadura por 5 s | 14 s |
| Breu debaixo da cama | Sótão | 10 000 | 0,4 | 0,10 | Anuncia e invoca 4 Corriscos à frente do seu progresso (sem sucata) | 16 s |

Todo chefe tira 100 do Farol se vazar, não dá sucata, recebe 35 % da lentidão normal, mostra barra de vida, nome e anúncio antes de agir. As resistências nunca tornam um inimigo invulnerável.

### 1.8 Ondas

Tabela global de 20 ondas; cada fase da campanha usa as N primeiras. Dois segundos entre grupos; chefe do mapa entra 2 s após o último grupo da onda 20. Intervalo de nascimento: 1,9 → 1,3 s nas ondas 1 a 4, 0,85 s nas ondas 5 a 10, 0,65 s nas ondas 11 a 20.

| Onda | Composição | Renda por jogador ao concluir |
|---|---|---|
| 1 | 8 Fiapos | 135 |
| 2 | 11 Fiapos | 150 |
| 3 | 10 Fiapos, 5 Corriscos | 165 |
| 4 | 16 Fiapos, 2 Bolotas | 180 |
| 5 | 12 Corriscos, 4 Bolotas | 195 |
| 6 | 20 Fiapos, 6 Latinhas | 210 |
| 7 | 16 Corriscos, 8 Latinhas | 225 |
| 8 | 6 Bolotas, 12 Névoas | 240 |
| 9 | 24 Fiapos, 10 Latinhas, 2 Remendos | 255 |
| 10 | 20 Corriscos, 8 Bolotas, 3 Remendos | 270 |
| 11 | 18 Névoas, 5 Casulos | 285 |
| 12 | 16 Latinhas, 6 Casulos | 300 |
| 13 | 24 Corriscos, 2 Brutamontes, 4 Remendos | 315 |
| 14 | 20 Névoas, 18 Latinhas, 6 Casulos | 330 |
| 15 | 4 Brutamontes, 5 Remendos, 12 Bolotas | 345 |
| 16 | 30 Corriscos, 10 Casulos, 18 Latinhas | 360 |
| 17 | 6 Brutamontes, 24 Névoas, 6 Remendos | 375 |
| 18 | 25 Latinhas, 12 Casulos, 5 Brutamontes | 390 |
| 19 | 32 Corriscos, 8 Brutamontes, 7 Remendos | 405 |
| 20 | 20 Fiapos, 14 Latinhas, 4 Remendos, depois o chefe | 420 |

### 1.9 Mapas

| Mapa | Vida dos comuns | Chefe | Caminho | Arte |
|---|---|---|---|---|
| Jardim de Papel | ×1,00 | Aspirador Rabugento | Ortogonal fixo, 8 vértices, ajustado ao desenho | Cena única publicada; `playRect` medido por `fit_map_scene.py` |
| Oficina de Lata | ×1,12 | Rei Ferrugem | Ortogonal fixo, 8 vértices | Cena única publicada |
| Sótão das Estrelas | ×1,25 | Breu debaixo da cama | Ortogonal fixo, 10 vértices | Cena única publicada |
| Praia e Neve | — | — | — | Artes v2 em `Assets_Mapas_v2/` já com registro em `map_scene_overrides.json`; sem caminho, chefe ou fase no JSON |

O Farol não vem desenhado nas artes: é desenhado por código na última célula do caminho. Bloqueios são células extras onde não se constrói. `Maps.unlock` (texto `win:jardim:normal`) e `profile.mapUnlocks` existem mas nada os lê.

### 1.10 Campanha (12 fases)

| Fase | Mapa | Ondas | Vida ×  | Sucata inicial | Objetivo 2 | Objetivo 3 |
|---|---|---|---|---|---|---|
| 1 | Jardim | 3 | 1,00 | 650 | Sem levar dano | No máximo 3 torres |
| 2 | Jardim | 5 | 1,00 | 650 | Sem levar dano | Só Dardo e Pipoca |
| 3 | Jardim | 7 | 1,00 | 700 | Sem levar dano | Adiantar todas as hordas |
| 4 | Jardim | 9 | 1,00 | 700 | Perder no máximo 20 de vida | No máximo 6 torres |
| 5 | Jardim | 12 | 1,10 | 750 | Sem levar dano | Adiantar todas as hordas |
| 6 | Oficina | 8 | 1,00 | 700 | Sem levar dano | No máximo 5 torres |
| 7 | Oficina | 10 | 1,10 | 750 | Perder no máximo 15 de vida | Adiantar todas as hordas |
| 8 | Oficina | 14 | 1,15 | 800 | Sem levar dano | Só Dardo, Pipoca e Goma |
| 9 | Oficina | 16 | 1,20 | 850 | Perder no máximo 25 de vida | No máximo 9 torres |
| 10 | Sótão | 12 | 1,20 | 800 | Sem levar dano | No máximo 7 torres |
| 11 | Sótão | 16 | 1,30 | 850 | Perder no máximo 20 de vida | Adiantar todas as hordas |
| 12 | Sótão | 20 + chefe | 1,40 | 900 | Sem levar dano | Adiantar todas as hordas |

Regras: a primeira estrela é vencer; as outras duas são os objetivos, avaliados no servidor por `Rules/Stars` sobre estatísticas medidas pela simulação (dano levado, torres construídas, quais torres entraram, ondas adiantadas). Só conta com vitória. O perfil guarda o melhor resultado por fase; a fase N+1 abre com pelo menos uma estrela na N; cada estrela nova paga 25 botões; 36 estrelas no total. A fase 1 é a única com ondas manuais e com o guia de três passos (escolher o Dardo, posicionar na célula marcada, chamar a horda), mostrado uma vez por perfil. Tipos de objetivo existentes: `noLeak`, `maxDamage`, `maxTowers`, `onlyTowers`, `rushAll`. Um chefe só aparece na fase 12.

### 1.11 Economia

**Sucata (só dentro da partida).** Carteira por jogador. Sucata inicial da fase inteira para cada participante (650 a 900). Renda de onda `120 + 15 × onda` inteira para cada um. Recompensa por abate dividida em partes iguais entre os participantes da largada (o resto gira por um cursor em ordem de UserId); invocados não pagam. Bônus de adiantar onda (5/s, máximo 80) para cada um. Venda devolve 70 %. No treino a sucata é infinita. Em grupo de 4 a economia total é cerca de 4× a solo, a vida dos inimigos é 3,1× e o teto de torres cai para 8 por pessoa.

**Botões (na conta).** Vitória paga 120 (Normal) ou 160 (Desafio), independente do número de ondas; derrota paga 4 × ondas concluídas, máximo 60; cada estrela nova paga 25. Treino paga zero; abandono não paga. Único uso: comprar Lupa (240), Maestro (450) e Voltz (600). Em 10 vitórias completas + estrelas o jogador compra as três.

**Domínio (por torre).** 10 pontos por vitória e 4 por derrota com pelo menos 5 ondas, para cada torre equipada que ficou pelo menos 30 s em campo. Marcos em 30, 100 e 250 pontos concedem adesivo, título e variação de skin, sem efeito de jogo. Não há limite diário.

Não há conversão de Robux em sucata ou botões, nem terceira moeda.

### 1.12 Perfil e persistência

Perfil em ProfileStore (`QuintalProfiles_v1`), esquema v3, com migrações puras e idempotentes (v1→v2 tutorial e pendências; v2→v3 campanha). Campos: `buttons`, `ownedTowerIds`, `loadout` (até 4), `cosmeticsOwned`, `cosmeticLoadout`, `masteryByTower` (pontos e marcos), `mapUnlocks` (morto), `campaign` (estrelas por fase), `campaignIntroSeen`, campos legados do tutorial, `settings`, `lifetimeStats` (partidas, vitórias, derrotas, ondas, inimigos, torres, botões ganhos), `recentMatchRewards` (ledger por partida, 30 dias, limite 1024), `pendingResults` (até 16), datas.

Resultado de partida: antes da largada o servidor registra a referência pendente em cada perfil; ao terminar grava um registro durável por `matchId` em DataStore (`QuintalMatchResults_v1`, escrita idempotente) e aplica a cada participante conectado; quem não estava recebe na próxima sessão pela reconciliação. Perfil que não carregou nunca é sobrescrito. No Studio sem DataStore o perfil é volátil e o resultado sai como "não salvo". O cliente recebe uma visão segura (`clientView`) que nunca inclui perfil de outro jogador.

### 1.13 Multiplayer

Parties no mesmo servidor: líder, membros em ordem de entrada, prontidão por membro, fase e dificuldade escolhidas pelo líder, salas abertas listadas para todos os presentes, convite interno com token de 30 s e cooldown de 5 s por destinatário, expulsão pelo líder, largada exige todos prontos e presentes. Início de fase solta o jogador da partida anterior. Revanche: nova partida com quem confirmou, mesma fase e dificuldade. Ao sair do servidor, o jogador some da party e os convites dele caem.

Em partida: cada jogador tem carteira, equipe e torres próprias; só o dono melhora, vende ou muda o alvo; Circuitos valem entre donos diferentes; Pulso é do grupo; Pronto e 2× por unanimidade dos ativos; resultado mostra dano, tempo de lentidão e dano adicional por apoio de cada um (informativo, não muda o pagamento). Não há: matchmaking entre servidores, código de sala, envio de sucata, zonas de construção, chat ou ping próprio, pausa real.

### 1.14 Acessibilidade e configurações

Volume separado de música e efeitos; redução de movimento; partículas reduzidas; números de dano opcionais; padrão sólido ou tracejado para o fio dos Circuitos (desligar o visual não desliga o efeito); idioma. Alvos de toque de pelo menos 44 px, ampliação de região quando a célula fica menor que 36 px físicos. Console e VR fora do escopo.

### 1.15 Assets e pendências de produção

| Item | Estado |
|---|---|
| Arte base | 40 PNGs reais (poses de torres por estado, terrenos, objetos); sem atlas. |
| Inimigos e chefes | 11 poses estáticas (8 + 3); movimento é procedural (`EnemyAnimator` espelha `enemy_visuals.json`); 96 + 48 quadros desenhados continuam pendentes. |
| Torres | Espelham a própria textura para olhar o alvo; sem quadros de ataque. |
| Mapas | Três cenas únicas publicadas; Praia e Neve v2 recebidas, sem encaixe de caminho nem fase. |
| Interface | 49 pranchas implementadas como componentes nativos; 24 ícones enviados em 18/09 com IDs reais, moderação não conferida; código tolera ícone ausente. |
| Marca | Logotipo e fundo de entrada gerados e registrados em `Config/Brand`. |
| Cosméticos | Passe Fundador (6 skins, estandarte, título) e cosméticos de domínio previstos no catálogo, sem arte. |
| Som | Chaves de áudio definidas; arquivos ainda faltam (por exemplo `ui_upgrade`). |
| Ações externas | Criar passe no Creator Hub, conferir moderação dos ícones, publicar experiência de teste, testar concorrência real de perfis. |

### 1.16 Monetização planejada (`docs/MONETIZACAO.md`)

Passe Fundador (149 Robux, cosmético, janela de lançamento), pacotes de botões (80 / 400 / 1 000 Robux; atalho, não exclusividade), temporadas a cada 6 a 8 semanas com fases grátis e passe cosmético (199 Robux), mais Premium Payouts. Regra: nada vendido afeta combate. Plano dos 90 dias: lançar sem loja, ligar o passe quando D1 passar de 30 %, pacotes de botões com a curva calibrada por dados, primeira temporada no mês 3.

### 1.17 Fora de escopo declarado na primeira versão

PvP, mercado entre jogadores, personagens licenciados, gacha, clãs, passe de temporada (a monetização o reintroduz no mês 3), campanha narrativa longa, labirinto livre, torre de renda, herói móvel, múltiplos caminhos simultâneos, modo infinito com economia própria, reconexão garantida entre servidores, console.

### 1.18 Problemas concretos encontrados nesta análise

| # | Problema | Onde | Efeito |
|---|---|---|---|
| 1 | Botões de vitória não escalam com ondas | `Rules/Rewards.winButtons` | Repetir a fase 1 (3 ondas, cerca de 2 min) rende 120 botões; Voltz sai em 10 minutos. |
| 2 | Desafio sem trava e sem registro | `PartyService.StartMatch`, `Profile.campaign` | Desafio na fase 1 paga 160 e não deixa marca; não há razão para rejogar. |
| 3 | `unlockAllMaps` e `testConsole` ligados | `Config/DevFlags.luau` | Precisam voltar a `false` antes de publicar (o arquivo já avisa). |
| 4 | Objetivos repetitivos | `campaign.levels` | `noLeak` 7 vezes, `rushAll` 5 vezes; em grupo, `rushAll` depende de unanimidade. |
| 5 | Domínio sem consequência de jogo | `Rules/Rewards.masteryPoints` | 25 vitórias por torre para uma skin; a torre nunca parece crescer. |
| 6 | Economia de coop favorece o grupo sem contrapeso | `Simulation.new`, `completeWave` | 4× renda contra 3,1× vida; com teto por jogador vira disputa pela célula boa. |
| 7 | Dados mortos | `Maps.unlock`, `profile.mapUnlocks` | Confundem quem lê o esquema. |
| 8 | Chefe só na fase 12 | `waves[20].bossAfterGroups` | Cada mapa tem um chefe próprio, mas dois deles nunca aparecem na campanha. |
| 9 | Nenhum motivo de retorno diário ou semanal | — | Sem diário, conquistas, eventos ou ranking; a campanha acaba em uma tarde. |

## 2. O modelo do BTD6, traduzido para o Quintal

| Sistema no BTD6 | Equivalente proposto | Hoje |
|---|---|---|
| XP e nível de conta (torres liberadas por nível) | Nível de Guardião; torres liberadas por nível, botões antecipam | Não existe; torres só por botões |
| Mapas em faixas (Beginner a Expert), 3 dificuldades por mapa, modos por dificuldade, medalhas | Grade de cenários: mapa × {Tranquilo, Normal, Desafio} × modos, uma medalha por célula | Campanha linear de 12 fases |
| Monkey Money (medalha nova paga muito, repetição paga pouco) | Botões com fórmula proporcional e bônus de primeira medalha | Fixo por dificuldade |
| Tower XP destrava tiers 3 a 5 | Domínio destrava L3A/L3B e a Obra-prima L4 | Só cosmético |
| Tier 5 único por caminho por jogador | Obra-prima: uma por ramo por jogador | Não existe |
| Monkey Knowledge (pontos por nível, bônus pequenos, desligado em CHIMPS) | Sabedoria do Quintal | Não existe |
| Coop: cada um com dinheiro próprio, mapa dividido em zonas, enviar dinheiro, quick match e código | Zonas, Enviar Sucata, Código de Sala, Fila Rápida | Só party no mesmo servidor |
| Freeplay após vitória | Até o Amanhecer (opcional, etapa 3) | Excluído da v1 |
| Heróis | Fora: continua sem herói, como decidido | — |
| Powers e Insta-Monkeys | Fora: fere "nada comprado ganha partida" | — |

## 3. Progressão

### 3.1 Nível de Guardião (XP de conta)

Ganho por partida, inteiro para cada participante:

```
xp = 12 × ondasConcluídas × multDificuldade × multModo × multGrupo + (vitória ? 60 : 0)
multDificuldade: Tranquilo 0,8 · Normal 1,0 · Desafio 1,4
multModo:        Padrão 1,0 · qualquer modo especial 1,2
multGrupo:       1 + 0,10 × (jogadores − 1), teto 1,3
```

Vitória Normal completa (16 ondas) rende cerca de 250 XP; Desafio completo com chefe, cerca de 400; a fase 1 da campanha, cerca de 96.

Curva: XP para ir do nível n ao n+1 = `120 + 45 × (n − 1)`. Nível 10 por volta de 2 700 XP (cerca de 10 vitórias); nível 20 por volta de 10 000; nível 40 (teto inicial) por volta de 38 000.

| Nível | Liberação |
|---|---|
| 1 | Dardo, Pipoca, Goma; Jardim em Tranquilo e Normal |
| 3 | Lupa |
| 4 | Sabedoria do Quintal (1 ponto; depois 1 por nível) |
| 6 | Maestro |
| 9 | Voltz |
| 10 | Modo Até o Amanhecer (se a etapa 3 entrar) |
| 12, 20, 30, 40 | Título e moldura de perfil (cosmético) |

**Antecipar com botões.** Enquanto o nível não chega, a Coleção mostra a torre com cadeado, o nível que a abre e o botão "Antecipar por 240 / 450 / 600 botões" (preços atuais). É o papel que o Monkey Money tem para heróis: atalho de tempo, nunca exclusividade. A tela de compra que já existe continua servindo.

### 3.2 Grade de cenários: mapa × dificuldade × modo

Cada cenário (mapa) passa a ter três dificuldades, e cada dificuldade tem modos. Uma medalha por (cenário, dificuldade, modo), guardada no perfil com data. Vencer em grupo dá a medalha a todos os participantes da largada, como no BTD6.

| | Tranquilo | Normal | Desafio |
|---|---|---|---|
| Ondas do Padrão | 12 + chefe | 16 + chefe | 20 + chefe |
| Vida do Farol | 150 | 100 | 60 |
| Custo de torres e melhorias | ×0,85 | ×1,00 | ×1,08 |
| Vida dos inimigos | ×0,85 | ×1,00 | ×1,45 (atual) |
| Vida do chefe | ×0,60 | ×1,00 | ×1,45 |
| Velocidade | 1,00 | 1,00 | 1,10 |
| Sucata inicial | 650 | 650 | 650 |
| Botões por vitória (base, partida completa) | 60 | 100 | 160 |
| Bônus da primeira medalha | +100 | +150 | +250 |

O chefe do cenário aparece na última onda de qualquer dificuldade (hoje só na onda 20), para que cada mapa continue tendo o seu chefe como identidade mesmo no Tranquilo. Isso também resolve o problema 8 da seção 1.18.

Modos (todos são flags de configuração da simulação):

| Modo | Dificuldade | Regra | Espelho no BTD6 | Custo de implementação |
|---|---|---|---|---|
| Padrão | todas | como hoje | Standard | — |
| Só Iniciais | Tranquilo | equipe limitada a Dardo, Pipoca e Goma | Primary Only | baixo (`allowedTowerIds`) |
| Sucata Contada | Tranquilo | 4 500 de sucata inicial, sem renda de onda nem de abate | Deflation | baixo |
| Meia Sucata | Normal | toda renda e sucata inicial ×0,5 | Half Cash | baixo |
| Chefes Reforçados | Normal | vida do chefe ×2, chefe também na onda 8 | Double HP MOABs | baixo |
| Apocalipse | Normal | a onda seguinte sai assim que a atual termina de nascer, sem intervalo | Apopalypse | médio (spawner com duas ondas vivas) |
| Farol Frágil | Desafio | Farol com 10 de vida, custos ×1,20 | Impoppable | baixo |
| Reverso | Desafio | caminho invertido, Farol na antiga entrada | Reverse | médio (arte da entrada e saída) |
| Sem Muletas | Desafio | Farol com 1 de vida, sem Pulso, sem venda, sem bônus de adiantar, sem Sabedoria | CHIMPS | baixo |

Isso dá 10 medalhas por cenário: 30 com os três mapas atuais, 50 quando Praia e Neve entrarem.

Regras de liberação (todas puras, em `Rules/Medals`):

- Normal de um cenário abre ao vencer o Padrão do Tranquilo nele; Desafio abre ao vencer o Padrão do Normal.
- Os modos especiais de uma dificuldade abrem ao vencer o Padrão daquela dificuldade.
- Faixas de cenário: Oficina abre com 3 medalhas no Jardim ou com a fase 5 da campanha vencida; Sótão, com 3 medalhas na Oficina ou fase 9. Praia e Neve entram na faixa que o JSON disser. Assim quem prefere a campanha e quem prefere a grade chegam ao mesmo lugar.
- `DevFlags.unlockAllMaps` continua valendo para teste, e nada mais.

### 3.3 O que vira a campanha de 12 fases

Fica, com dois papéis: ensino (a fase 1 continua sendo o tutorial, com guia e ondas manuais) e caminho alternativo de liberação. Na tela, a campanha vira a primeira aba de "Jogar"; a grade de cenários, a segunda. Duas correções baratas:

- Trocar objetivos repetidos por variedade: `noCircuits` (vencer sem nenhum Circuito), `circuits` (ter 2 Circuitos ativos no fim), `noSell`, `underBudget` (gastar no máximo X), `bossFast` (chefe morto em Y s). Cada objetivo novo entra nos três lugares que o `CLAUDE.md` lista (regra, importador, texto).
- Estrelas continuam pagando 25 botões na primeira vez; a vitória da fase passa a pagar proporcional às ondas (seção 4.2).

## 4. Dinheiro

### 4.1 Sucata (dentro da partida)

- Custos por dificuldade (tabela 3.2) aplicados na simulação na hora de cobrar, arredondando para cima uma vez, como no BTD6 (Easy −15 %, Hard +8 %, Impoppable +20 %). O catálogo continua com um número só por estado.
- Renda de onda mantém `120 + 15 × onda`, multiplicada pelo modo (Meia Sucata 0,5; Sucata Contada 0).
- Coop: cada jogador continua com sucata inicial e renda de onda inteiras (é o que o BTD6 faz) e abate dividido igual (sem prêmio de último golpe, como já decidido). O contrapeso passa a ser as zonas (6.1), não o teto por jogador.
- Enviar Sucata (6.2) entra como comando de partida.
- Sem juros e sem torre de renda: continuam fora.

### 4.2 Botões (na conta)

```
vitória      = base(dificuldade) × ondasDaPartida / ondasPadrão(dificuldade) × multModo
               base: Tranquilo 60 · Normal 100 · Desafio 160 · multModo especial 1,25
derrota      = 2 × ondasConcluídas, teto 40
1ª medalha   = +100 / +150 / +250 (uma vez por célula da grade)
estrela nova = +25 (campanha, uma vez)
1ª vitória do dia (UTC) = +40  (opcional; comum no Roblox, não é do BTD6)
```

Fase 1 da campanha: 19 botões por repetição, até 94 na primeira vez. Normal completo: 100 por repetição, 250 na primeira. A jornada das 30 medalhas rende cerca de 5 000 botões, o preço de antecipar as três torres (1 290) mais cinco ou seis cosméticos.

Para que servem: antecipar torre (240 / 450 / 600), loja de cosméticos com rotação (skins 400 a 900, molduras 200, títulos 150), redistribuir Sabedoria (100). Os pacotes de botões do plano de monetização continuam fazendo sentido: compram tempo e aparência, nunca poder.

### 4.3 Moedas que não vamos criar

XP, botões, Domínio e Sabedoria são os quatro contadores; medalhas e estrelas são registros, não moeda. Nada de troféus, insta-torres ou moeda de evento na primeira versão.

## 5. Melhorias

### 5.1 Árvore em partida

Estados atuais L0 → L1 → L2 → (L3A | L3B) continuam como estão. Mudanças:

- L0, L1 e L2 sempre abertos. L3A e L3B precisam estar destravados na conta para aparecer na partida (o BTD6 faz exatamente isso com o tier 3). O painel da torre mostra o ramo travado com "Domínio 14/20".
- Obra-prima (L4A / L4B): um quarto nível por ramo, custo por volta de 2,2 × L3, efeito de transformação e só uma Obra-prima de cada ramo por jogador por partida (regra do tier 5 no BTD6, que também distribui papéis no coop). Doze estados novos:

| Torre | L4A (Obra-prima do ramo A) | L4B (Obra-prima do ramo B) |
|---|---|---|
| Dardo | Metralha: intervalo 0,30, dano 60, 2 alvos | Perfuradora: ignora armadura e atravessa 3 inimigos em linha |
| Pipoca | Quermesse: raio 2,2, 14 alvos, queimadura 3 s | Bigorna: 260 de dano, ignora armadura, atordoa 0,5 s |
| Lupa | Telescópio: bônus em chefe 0,60, alcance 7 | Vigia: marca 0,25 em todos no alcance |
| Goma | Alagamento: lentidão 0,40 contínua em toda a área | Cola Industrial: lentidão 0,60 por 3 s (teto próprio) |
| Voltz | Tempestade Elétrica: 8 saltos, raio 2,2 | Raio: 250 de dano único, bônus em chefe 0,40 |
| Maestro | Sinfonia: cadência +0,22 e dano +10 % no alcance 4 | Solo de Guitarra: cadência +0,40 em até 2 torres adjacentes |

Números são chute de partida; a validação é o mesmo caminho do resto do catálogo. Arte: 12 poses novas; até chegarem, a Obra-prima usa a pose L3 com aura dourada procedural e selo no `TowerAnimator`, e o registro de assets marca os quadros como pendentes, como já se faz.

### 5.2 Domínio como XP de torre

- Ganho por partida, por torre equipada com pelo menos 30 s em campo (regra atual mantida): `pontos = (vitória ? 10 : 4) × multDificuldade × ondasDaPartida / ondasPadrão`, teto 20. Na etapa 2, trocar por participação real: `4 + 6 × (parcela da torre no dano, lentidão e apoio do jogador)`, o que exige `damageByUserTower` na simulação (hoje só há `activeSecondsByUserTower` e `PlayerMatchStats` por jogador).
- Custos de destravar: L3A 20, L3B 20, L4A 90, L4B 90. Domínio passa a ser gasto, não só acumulado; os marcos cosméticos de 30/100/250 continuam contando o total ganho, não o saldo.
- Migração: torre com 20 pontos ou mais ganha L3A e L3B destravados de graça; o resto começa travado. Como o jogo não foi publicado, ninguém perde nada de fato.

### 5.3 Sabedoria do Quintal (Monkey Knowledge)

- Pontos: 1 por nível a partir do 4. Nível 40 dá cerca de 36 pontos; a árvore tem 21 nós, então sobra escolha, não sobra tudo.
- Três galhos, cada um com 7 nós em cadeia (o nó seguinte pede o anterior):

| Galho | Exemplos de nós (efeito pequeno, permanente) |
|---|---|
| Ataque | Mira Afiada (+3 % dano de Dardo e Lupa) · Pólvora Barata (Pipoca L0 −10 %) · Recarga (L1 de ataque −5 %) · Olho Treinado (Lupa +0,3 alcance) · Estilhaço (Pipoca +1 alvo) · Ponta Fina (Dardo ignora 0,05 de armadura) · Tiro de Abertura (1ª torre da partida −15 %) |
| Controle | Cola Fresca (Goma +0,3 s de lentidão) · Corrente Longa (Voltz +0,2 raio de salto) · Isolante (queda por salto +0,03) · Pegajoso (teto de lentidão 0,50 → 0,55) · Choque (Voltz +5 % em lentos) · Poça Rasa (Goma L0 −10 %) · Curto-circuito (Voltz +1 salto) |
| Apoio e Oficina | Bolso Fundo (+50 sucata inicial) · Sucateiro (venda 70 → 75 %) · Pilha Nova (Pulso −8 s) · Farol Reforçado (+10 vida) · Adiantar Vale Mais (+2/s no bônus) · Afinação (Maestro +0,02) · Reserva (+40 por onda a partir da 10) |

- Regras: bônus pessoais valem para as torres e a carteira de quem os tem; bônus compartilhados (Farol, Pulso) valem pelo maior entre os participantes (coop é para jogar com quem já andou mais). Desligada no Sem Muletas, como o Monkey Knowledge no CHIMPS. Redistribuir custa 100 botões. Tudo congelado na largada dentro de `MatchConfig`, para a simulação continuar pura.

## 6. Multiplayer

### 6.1 Zonas de construção

Como no coop do BTD6, o tabuleiro é dividido em zonas por jogador: cada mapa declara no JSON as partições para 2, 3 e 4 jogadores (`zones["2"]`, `zones["3"]`, `zones["4"]`, como retângulos ou uma grade 16×10 de índices). Regras:

- Zona atribuída pela ordem de entrada na party (líder primeiro); congelada na largada.
- `canPlaceAt` recusa célula fora da zona; Circuitos continuam valendo na fronteira entre zonas, o que faz da fronteira o lugar da cooperação (já funciona entre donos diferentes).
- O importador confere que toda zona tem pelo menos 8 células livres de caminho e bloqueio.
- Opção na party: Zonas divididas (padrão em 2 a 4) ou Livre (regra de hoje, com teto por jogador). Com zonas o teto por jogador vira só uma trava de segurança.

Exemplo para o Jardim com 2 jogadores: colunas 0 a 7 e 8 a 15; com 4: quadrantes.

### 6.2 Enviar Sucata e marcar célula

- Comando `SendScrap { toUserId, amount }`: inteiro de pelo menos 25, no máximo a carteira, destinatário ativo, 1 por segundo, em qualquer fase de combate. Evento `scrapSent` para o HUD; `scrapSent` e `scrapReceived` nas estatísticas e no resultado ("Banqueiro" ao lado de Dano, Controle e Apoio).
- Comando `PingCell { x, y }`: segurar 0,6 s numa célula vazia mostra um marcador de 3 s para todos (coordenação no celular sem chat), 1 a cada 2 s.

### 6.3 Código de sala e Fila Rápida (entre servidores)

- Etapa 2, Código de sala: o líder gera um código de 6 caracteres; `MemoryStoreService` (SortedMap, expira em 2 h) guarda código → {placeId, jobId, partyId}; quem digita o código é teletransportado com `TeleportToPlaceInstance` levando `partyId` nos dados de teleporte e entra na party ao chegar. É o "Join with code" do BTD6 e cobre a maior parte do coop entre amigos. Amigo que entra pelo botão do Roblox já cai no mesmo servidor e vê a lista de salas.
- Etapa 3, Fila Rápida: fila por (cenário, dificuldade) em MemoryStore Queue; cada servidor tenta formar grupos de 2 a 4 a cada 5 s, reserva um servidor (`ReserveServer`) e teletransporta com `TeleportAsync`; após 30 s sozinho, começa com quem houver. Só vale a pena quando houver gente suficiente online; até lá o código de sala resolve.

### 6.4 Prontidão e velocidade

- Onda adianta quando todos os ativos estão prontos ou quando pelo menos metade está pronta há 20 s (anti-AFK; hoje um ausente trava o grupo). 2× continua exigindo unanimidade, como no BTD6.
- Quando alguém sai, as torres dele ficam (regra atual) e a zona dele abre para os outros depois de 60 s.

### 6.5 Recompensas em grupo

Cada participante da largada recebe XP, botões e medalha inteiros; XP tem +10 % por jogador extra (teto +30 %) para puxar para o coop; Domínio conta só para as próprias torres. Vida dos inimigos: manter +0,7 por jogador na etapa 1 e testar +0,5 com zonas na etapa 2; o fator foi escrito para um coop sem zonas.

## 7. Modelo de dados e impacto no código

### 7.1 Perfil v4 (`ProfileSchema`)

```
xp: number, level: number, knowledgePoints: number, knowledgeOwned: { string },
medals: { [ "jardim:normal:padrao" ]: { at: number } },
masteryByTower[towerId] = { points, spent, milestones, unlocked: { "L3A", ... } },
towerUnlocks: { [towerId]: "level" | "buttons" },
daily: { lastWinDay: string? },
```

Migração v3→v4 (pura e idempotente, como as anteriores): `xp = 12 × wavesCleared + 60 × wins` a partir de `lifetimeStats`; `level` derivado; `knowledgePoints = max(level − 3, 0)`; `medals = {}`; Domínio de 20 ou mais destrava os dois L3; `mapUnlocks` sai do esquema (validação deixa de exigir).

### 7.2 Balanceamento (`balanceamento_v1.json` e `tools/import_balance.py`)

Blocos novos: `progression` (curva de XP, liberações por nível), `difficulties` (ganha `tranquilo`, `costMult`, `baseHP`, `bossHpMult`, `wavesStandard`, `buttonsBase`, `xpMult`, `firstMedalBonus`), `modes[]` (id, dificuldade, flags, regra de liberação), `mapTiers`, `maps[].zones`, `towers[].states.L4A/L4B`, `towers[].masteryUnlock`, `knowledge.nodes[]`, `rewards` (fórmula de botões). O importador valida cada um; fase ou modo malformado não chega no jogo, como hoje.

### 7.3 Regras puras (`src/shared/Rules/`, cada uma com spec no Lune)

| Módulo | Responsabilidade |
|---|---|
| `Progression.luau` (novo) | XP da partida, nível a partir do XP, liberações por nível |
| `Medals.luau` (novo) | chave da medalha, o que está liberado dado o perfil, faixas de cenário |
| `Knowledge.luau` (novo) | validar compra de nó, agregar bônus em `PerkSet` pessoal e compartilhado |
| `Zones.luau` (novo) | célula → zona, atribuição por ordem, validação de capacidade |
| `Rewards.luau` | fórmula nova de botões e de Domínio |
| `Stars.luau` | objetivos novos (`noCircuits`, `circuits`, `noSell`, `underBudget`, `bossFast`) |

### 7.4 Simulação (`Sim/Simulation.luau`)

`MatchConfig` ganha `mode` (flags: multiplicador de renda, `allowedTowerIds`, `pulseEnabled`, `sellEnabled`, `baseHP`, `costMult`, `bossAtLastWave`, `chainWaves`), `zonesByUser`, `perksByUser` e `unlockedStatesByUserTower`. `placeTower` checa zona e lista permitida; `upgradeTower` checa destravamento de L3/L4 e o limite de uma Obra-prima por ramo; `sellTower` respeita `sellEnabled`; custos passam por `costMult`; `updateSpawning` agenda o chefe na última onda; comandos `sendScrap` e `pingCell`. Tudo continua determinístico e sem Roblox, então os testes de `03_simulation` cobrem cada modo.

### 7.5 Rede e serviços

`Net/Enums`, `Packets` e `Codec`: comandos novos e campos de lobby (modos, medalhas, zonas). `MatchService.start` monta o `MatchConfig` a partir de cenário, dificuldade, modo e perfis. `RewardService` e `applyMatchResult`: XP, nível, medalha, Domínio gasto. `PartyService`: escolha de modo, opção de zonas, código de sala. `MenuService`: `BuyKnowledge`, `RespecKnowledge`, `UnlockTowerEarly`, `UnlockTowerState`. Novos: `RoomCodeService` (MemoryStore) e, na etapa 3, `MatchmakingService`.

### 7.6 Telas (Fusion e Charm)

`Atoms`: xp, nível, medalhas, sabedoria, zonas. `Screens/Campaign` ganha a aba Cenários (cartão do mapa → abas de dificuldade → lista de modos com medalha e cadeado). `Collection` e `HudDetail`: árvore com L3/L4 travados e custo em Domínio. `Knowledge` (nova). `Party`: modo, zonas, código. `Hud`: tinta da zona, Enviar Sucata na ficha do colega, marcador de ping. `Result`: barra de XP, subida de nível, medalha nova. `MainMenu`: nível e barra. Cada tela nova entra em `docs/ui_coverage.json`; textos em `Localization` nos dois idiomas.

## 8. Roteiro em três etapas

| Etapa | Entrega | Critério de aceite |
|---|---|---|
| E1, Conta que cresce | Perfil v4 e migração; Nível de Guardião; torres por nível e antecipar; botões proporcionais; Domínio destrava L3A/L3B; barra de XP no menu e no resultado; `DevFlags` documentados | Lune verde com specs novos; jogar fases 1 a 4 no Studio e ver nível 2, Lupa liberada no 3 e L3 do Dardo destravando; repetir a fase 1 não rende mais que 19 botões |
| E2, Grade e coop de verdade | Tranquilo, Normal e Desafio com custos e vida; modos Só Iniciais, Sucata Contada, Meia Sucata, Chefes Reforçados, Farol Frágil e Sem Muletas; medalhas e faixas; chefe na última onda; zonas; Enviar Sucata; ping; código de sala; prontidão anti-AFK | 30 medalhas visíveis com cadeado correto; partida de 2 no Studio com zonas e envio de sucata; código de sala testado entre dois clientes reais (ação manual, registrada em `MANUAL_ACTIONS.md`) |
| E3, Profundidade | Obra-prima L4 (12 estados, arte ou aura provisória); Sabedoria; Apocalipse e Reverso; Até o Amanhecer com ranking por cenário (`OrderedDataStore`); Fila Rápida; desafio semanal com semente fixa (gancho para as temporadas da monetização) | Uma Obra-prima por ramo por jogador verificada em teste; Sabedoria desligada no Sem Muletas; ranking gravado e lido; fila forma grupo de 2 em teste real |

Ordem de valor: E1 é a que mais muda retenção com menos arte; E2 é a que dá motivo de voltar (medalhas) e faz o coop parecer o BTD6; E3 é conteúdo.

## 9. Decisões em aberto

1. Torres por nível, botões só antecipam: muda a frase "compra de unidades por preço fixo" do design original. Aceita?
2. Obra-prima pede 12 poses novas. Entra com aura provisória ou espera arte?
3. Zonas divididas como padrão no coop, ou Livre como padrão e Zonas como opção?
4. Até o Amanhecer (modo infinito) estava fora da v1. Reabrir na E3?
5. Manter a campanha de 12 fases como aba própria (proposta) ou dissolvê-la na grade?
6. Fila Rápida entre servidores vale o custo antes de existir base de jogadores? (Proposta: não; código de sala primeiro.)
7. Vida dos inimigos em coop: manter +0,7 ou testar +0,5 com zonas?
