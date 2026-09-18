# TEST_REPORT — Quintal em Guarda (2026-09-16)

Este relatório separa **executado**, **não executado** e **bloqueado**. Nenhum número de balanceamento foi validado com jogadores; os valores continuam sendo o catálogo inicial.

## 1. Verificações automatizadas (executadas)

| Verificação | Comando | Resultado |
| --- | --- | --- |
| Testes de regras (Lune 0.9.3) | `lune run tests/run.luau` | **88 aprovados, 0 reprovados** (`tests/last_run.json`) |
| Análise estática estrita (luau-lsp 1.69.0, `--!strict` em todos os módulos) | `luau-lsp analyze … src/` | 0 erros |
| Lint (selene 0.31.0) | `selene src/` | 0 erros, 6 avisos (variáveis não usadas em `Ui.luau`, `Hud.luau`, `Menu.luau`, `Collection.luau`) |
| Formatação (StyLua 2.1.0) | `stylua --check src/ tests/` | conforme |
| Validação de dados | `python3 tools/import_balance.py` | OK: 6 torres × 5 estados, 8 inimigos, 3 chefes, 20 ondas, 3 mapas ortogonais, bloqueios fora do caminho, células guiadas válidas |
| Cobertura de assets | `python3 tools/update_asset_registry.py` | 40/40 originais exportados e com ID Roblox; 11 placeholders identificados |
| Build do lugar | `rojo build default.project.json -o build/QuintalEmGuarda.rbxl` | gerado (170 KB, só código/configuração) |

### Cenários do capítulo 4 cobertos por teste automatizado

| ID | Spec | Status |
| --- | --- | --- |
| T01 Colocar Dardo com 650 → 400 e L0 | `03_simulation` | ✅ |
| T02 Repetir requestId | `04_protocol` (deduplicação devolve a resposta anterior) | ✅ |
| T03 Dois jogadores na mesma célula | `03_simulation` (OCCUPIED, sem gasto) | ✅ |
| T04 Caminho/bloqueio/fora do mapa/não inteiro | `03_simulation` (INVALID_CELL) | ✅ |
| T05 L0 → L2 direto | `03_simulation` (INVALID_STATE) | ✅ |
| T06 Dardo L0+L1 vendido → 315 | `03_simulation` e `02_rules` | ✅ |
| T07 Fura lata ignora armadura | `02_rules` | ✅ |
| T08 Goma + Pulso: maior slow, sem soma | `02_rules` | ✅ |
| T09 Supercola em chefe → 15,75% | `02_rules` | ✅ |
| T10 Dois Maestros → intervalo / 1,25 | `02_rules` | ✅ |
| T11 Três torres disputam Circuito | `02_rules` (determinístico por ID) | ✅ |
| T12 Vender parceiro remove bônus no mesmo passo | `03_simulation` | ✅ |
| T13 Voltz L0: 20 e 15 | `02_rules` | ✅ |
| T14 Casulo → três Fiapos sem bounty | `03_simulation` | ✅ |
| T15 Casulo vaza sem dividir | `03_simulation` | ✅ |
| T16 Derrota prevalece no mesmo passo | `03_simulation` | ✅ |
| T17 Dois Pulsos no mesmo passo → um efeito | `03_simulation` | ✅ |
| T18 Fiapo 4 jogadores = 75 | `03_simulation` | ✅ |
| T19 Aspirador Desafio solo = 10150 | `03_simulation` | ✅ |
| T20 Bounty 10 / 3 jogadores = 4,3,3 com cursor | `02_rules` | ✅ |
| P05 Mesmo matchId não paga duas vezes | `05_profile` | ✅ |
| P06 Tutorial pago uma vez (`tutorial-v1`) | `05_profile` | ✅ |
| P07 Migração v1→v2 idempotente | `05_profile` | ✅ |
| P08 Preço/recompensa fabricados | `04_protocol` (nenhuma ação aceita esses campos) | ✅ |
| P09 NaN, infinito, string enorme, match alheio | `04_protocol` + chamada real no Studio | ✅ |
| P10 Vender torre alheia → NOT_OWNER | `03_simulation` | ✅ |
| Extras | tutorial só avança com Pronto; 2x por unanimidade; ausente 30 s não conta; limites por pessoa/espécie; treino libera todas | ✅ |

## 2. Testes executados no Roblox Studio (0.739, place não publicado, um cliente)

Sync via Rojo 7.5.1 (servidor) + plugin Rojo no Studio; Play solo; interação por cliques reais (ferramenta de entrada do Studio) e inspeção do estado por script.

| Cenário | Resultado |
| --- | --- |
| Boot: servidor cria remotes, cliente monta `QuintalApp`, câmera Scriptable, sem avatar | ✅ sem erros no console |
| Perfil: DataStore indisponível (API desligada) → perfil volátil só no Studio, aviso "Progresso não salvo" | ✅ (produção: menu com tentar novamente/treino, sem gravar padrões) |
| Menu: Jogar (tutorial primeiro), Coleção, Treino, Configurações, Loja desativada, mapas/dificuldades bloqueados com motivo | ✅ |
| Tutorial completo: Dardo guiado em (3,3) → Pronto → onda 1 → Goma guiada em (3,4) com Circuito "Pega e acerta" → Dardo L1 pelo painel → ondas 2 e 3 → vitória, 180 botões, marcos de domínio | ✅ (com perfil volátil o status foi "não salvo", como esperado) |
| Fases do tutorial não avançam por cronômetro; retentativa por checkpoint implementada (não exercitada) | ✅ / ⏳ |
| Partida Normal (Jardim): 6 torres colocadas por toque em célula + confirmação, prévia de Circuito, painel de detalhe com estatísticas, melhoria L1/L2, especialização com confirmação (Fura lata, Festival, Rajada) | ✅ |
| Voto 2x solo → "Velocidade 2x" | ✅ |
| Pulso de Luz: dois toques, anel de energia, dano a todos os inimigos | ✅ |
| Salto de desenvolvimento para a onda 20: Latinhas, Remendos, chefe Aspirador com nome/barra, aviso "prepara Poeira" e área de poeira; derrota por vazamento do chefe → resultado com 19/20 ondas, 60 botões (4×19 limitado a 60), domínio +4 por torre, contribuição por dano/lentidão/apoio | ✅ |
| Revanche (solo) cria nova partida; Sair com confirmação volta ao menu | ✅ |
| Treino: seis torres, sucata ∞, gerar 10 Brutamontes, alcances visíveis, sem recompensas | ✅ |
| Coleção: compra bloqueada por botões insuficientes com "Faltam N", equipar/retirar (lógica testada em Lune) | ✅ visual / ⏳ compra real |
| Configurações: movimento reduzido, idioma en (textos trocam) | ✅ |
| Rejeições na fronteira de rede com chamadas reais: NaN, infinito, string de 5000 caracteres, campo `price`, match alheio, lista aninhada, compra sem botões | ✅ |
| Mobile (emulador iPhone 17 Pro, 750×361): menu compacto; HUD em colunas laterais com tabuleiro em altura total (célula 29 px); nenhum botão visível fora da tela; toques em Jogar e Pronto funcionaram | ✅ layout |
| Mobile: confirmar construção por toque, pinça/zoom, folha de detalhe | ⚠️ não verificável no emulador: a ferramenta de entrada sintética não posiciona cliques corretamente sob emulação (cliques em botões pequenos não chegam ao alvo); exige aparelho real |

Observações corrigidas durante os testes: tutorial iniciava a onda pelo cronômetro; detecção de layout móvel antes de o viewport existir; hover por baixo da barra de construção movia o fantasma; subtexto "…" preso após resposta; `:upper()` quebrava acentos; painel de detalhe sem rolagem; sobreposição do painel de treino/banner com o tabuleiro; cabeçalhos não seguiam o idioma.

## 3. Não executado (precisa de pessoas, dispositivos ou conta)

- Dois e quatro clientes (Test → Clients and Servers): compras simultâneas, voto de 2x com desconexão, revanche em grupo, salas e convites. A lógica está coberta por testes de simulação, não por sessão real.
- Latência simulada de 150–250 ms.
- DataStore real: lock de sessão entre servidores (P02/P03), gravação após resultado (P04), encerramento com perfis sujos (P12), reconciliação de pendências. Requer place publicado com API habilitada.
- As 24 combinações mapa × dificuldade × grupo com execução completa; Oficina e Sótão só foram validados por dados, testes e pré-carregamento das imagens.
- Uma partida Normal completa de 20 ondas sem salto de desenvolvimento (duração alvo de 10 a 15 min) e medição de duração real.
- Carga (3×4 e 12 solo), p95 do passo, memória, tráfego; o servidor registra `sim_overload` quando o Heartbeat atrasa (ocorreu apenas durante inspeções pesadas do Studio).
- Celular real: tutorial, construir, cancelar, ampliar, melhorar, vender, Pulso; movimento reduzido, números desligados; tablet 4:3; 844×390 e 896×414.
- Playtest com 8–12 pessoas e revisão de balanceamento.

## 4. Bloqueado por decisão do responsável

- Publicação da experiência e ativação do passe (loja permanece desativada).
- Produção artística final (quadros de animação, inimigos, chefes, skins, ícones) e áudio licenciado.

## 5. Evidências

- `tests/last_run.json` — resumo da última execução Lune.
- `assets/export/upload_log.json` — IDs reais retornados no upload; `ContentProvider:PreloadAsync` no Studio: 58 + 11 assets carregados sem falha.
- `assets/export/review_towers.png`, `review_props.png`, `placeholders/review_placeholders.png` — pranchas de revisão de apoio/escala.
- Console do Studio durante os testes: apenas eventos `[telemetria]`, sem erros de script.

## 6. Responsividade e fluidez (adendo 2026-09-16)

Sistema: `View/Responsive.luau` decide o modo (computador ≥ 1000×540 lógicos; senão compacto, ou toque sem teclado) e uma escala uniforme nunca menor que 1 (referência 1280×720; até 1,8× em telas grandes), aplicada por `UIScale` na camada de telas. Ao redimensionar a janela (debounce 150 ms) o HUD é reconstruído se o modo mudar, as cartas da faixa inferior se reajustam à largura disponível, o menu troca de layout e a grade da coleção recalcula colunas. `View/Motion.luau` anima cortina entre telas, painel de detalhe, barra de construção, banner do tutorial, painel de treino, aviso de chefe, avisos (toast), contador de sucata e barra do farol; tudo desligado em movimento reduzido.

| Viewport (emulador) | Modo | Escala | Observado |
| --- | --- | --- | --- |
| 1313×693 (janela do Studio) | computador | 1,00 | menu com linhas que quebram (`Wraps`), partida com cartas 128 px, barra de construção entra/sai deslizando, detalhe desliza da direita e repousa sob o banner do tutorial |
| 1920×1080 | computador | 1,42 | faixa superior 79 px, cartas 181 px, tabuleiro 1188×742 (célula 74 px), tudo proporcional, sem erros de console |
| 1024×768 (tablet) | computador | 1,00 | cartas reduzidas a 117 px, faixa inferior cabe (Pronto termina em x=895 de 1023); botão Sair da faixa superior ultrapassava 10 px → corrigido tornando a área de participantes flexível (verificado por aritmética: 976 < 1007 px; não re-executado no emulador) |
| 750×361 (iPhone 17 Pro, teste anterior) | compacto | 1,00 | colunas laterais e tabuleiro em altura total |

Não executado: redimensionamento contínuo da janela durante a partida (o Studio não expõe isso pelo MCP) e rotação em aparelho real.

## 7. Inimigos, chefes e animação 2D (adendo 2026-09-18)

Entrada: `GUIA_MONSTROS_E_BOSSES.pdf` (18 páginas) e `Assets_Inimigos_Bosses_v1/` (11 PNGs 1254×1254, manifesto, `enemy_visuals.json`).

### 7.1 Executado fora do Studio

| Verificação | Comando | Resultado |
| --- | --- | --- |
| Integridade das 11 origens | sha256 × `manifesto_inimigos_bosses.json` | 11/11 conferem |
| Export normalizado | `python3 tools/export_enemy_assets.py` | 11 quadros (8 × 128 px, 3 × 256 px), apoio (0,5; 0,82), alpha preservado |
| Cobertura do índice | `python3 tools/merge_enemy_index.py` | 40 → 51 assets no índice e no registro de runtime |
| Geração de `Config/Assets.luau` | `python3 tools/update_asset_registry.py` | 51/51 com ID do Roblox; 11 placeholders procedurais deixaram de ser emitidos |
| Testes de regras | `lune run tests/run.luau` | **115 aprovados, 0 reprovados** (88 anteriores + 27 novos) |
| Análise estática estrita | `luau-lsp analyze … src/` | 0 erros |
| Lint | `selene src/` | 0 erros, 6 avisos (os mesmos de antes) |
| Formatação | `stylua --check src/ tests/` | conforme |

Novo spec `tests/specs/06_enemies_bosses.spec.luau` (27 testes) cobrindo a tabela de aceite do guia:

| Caso do guia | Resultado |
| --- | --- |
| Cobertura de tipos e atributos das páginas 2 e 4 a 14 | ✅ 8 inimigos e 3 chefes conferem com o catálogo |
| Resistências: Latinha 20→11, Névoa 20→13, Bolota 20→20, Brutamontes 20→15 | ✅ |
| `armorIgnore = 1` na Latinha → 20 | ✅ |
| Pulso de Luz na Névoa, solo, sem marca → 117 | ✅ |
| Escala de vida: Fiapo 4 pessoas → 75; Aspirador solo Desafio → 10150 | ✅ |
| Velocidade do Corrisco no Desafio → 2,255 | ✅ |
| Cura concorrente: dois Remendos, Fiapo 10/24 → 22/24 | ✅ |
| Remendo não cura a si, outro Remendo nem chefe; pulso = 12 × fator | ✅ |
| Casulo letal: uma morte, três filhos, uma recompensa, filhos sem bounty e sem efeitos herdados | ✅ |
| Casulo na base: leak 8, zero filhos, zero recompensa | ✅ |
| Poeira: aviso aos 14 s, resolução aos 16 s, expira em 20 s; intervalo 1 s → 1,333 s | ✅ |
| Centro da poeira fixo após vender a torre marcada; sem torres o ciclo é consumido | ✅ |
| Armadura do Rei: 20% → 55% por 5 s → 20%; físico 100 → 80/45/80; sem acúmulo | ✅ |
| Breu: quatro Corriscos em s + 0,5, bounty 0, leak 3 preservado | ✅ |
| Breu morto durante o aviso não invoca; morto depois não apaga os invocados | ✅ |
| Fim de onda espera filhos e invocados | ✅ |
| Snapshot leva prazo do aviso, armadura atual e resistência de energia | ✅ |

### 7.2 Executado no Roblox Studio (place do grupo, Play solo, um cliente)

| Cenário | Resultado |
| --- | --- |
| Upload dos 11 exports pela conta logada no Studio | ✅ IDs reais em `assets/export/upload_log.json` (69 → 80 entradas) |
| Treino com os 11 tipos no tabuleiro | ✅ 11/11 sprites com `IsLoaded = true`, nenhum fallback visível |
| Largura por tipo | ✅ quadros de 44 px (Fiapo) a 130 px (Aspirador), proporcionais a `enemy_visuals.json` |
| Ciclos de movimento | ✅ 11/11 com ciclo ativo; amplitudes medidas batem com o guia (Fiapo 1,94 px; Corrisco 1,50; Bolota ±1; Névoa ±2; Aspirador ±0,7; Rei 0,73; Breu ±1, na referência de 128 px) |
| Aviso de chefe com contagem | ✅ selo com ícone e segundos restantes derivados do prazo do servidor |
| Poeira do Aspirador | ✅ anel no tabuleiro e ícone de poeira na torre atingida |
| Console durante a sessão | ✅ sem erros de script (só telemetria e o aviso de DataStore desligado) |

Defeito encontrado e corrigido durante a verificação: o deslocamento vertical usava o campo `Offset` de `UDim2`, que é inteiro — um salto de 0,7 px em um sprite de 44 px truncava para zero e nenhum inimigo subia. Passou a ser fração do quadro de referência, medido depois em 11/11 sprites.

### 7.3 Não executado

- **Movimento reduzido nos inimigos**: a tentativa desta sessão alterou a configuração pelo remote `SaveSettings`, que grava no servidor mas não atualiza o espelho local do cliente; o teste não mediu o que pretendia. O caminho real é a tela de Configurações. O código do `EnemyAnimator` trata a opção, mas a verificação em tela continua pendente.
- Partida completa de 20 ondas com os chefes no fim de cada mapa (só o treino e o salto de desenvolvimento foram exercitados nesta sessão).
- Impacto, morte e cura observados a olho: os eventos existem e os testes cobrem a lógica, mas não foram capturados em vídeo nem medidos em tela.
- Celular real, quatro clientes, latência simulada e carga — continuam pendentes como no relatório principal.
- Moderação dos 11 assets novos: o carregamento foi verificado agora, mas a moderação do Roblox é assíncrona e pode remover um asset depois.


---

## 8. Interface completa (2026-09-18)

Sessão de implementação das 49 pranchas do pacote `UI_Quintal_em_Guarda_v1`. Como nas seções
anteriores, o que está abaixo separa **executado** de **pendente**; nenhuma linha marca como testado
algo que não foi visto rodando.

### 8.1 Verificações automatizadas (executadas)

| Verificação | Comando | Resultado |
| --- | --- | --- |
| Testes de regras e de interface (Lune 0.9.3) | `lune run tests/run.luau` | **140 aprovados, 0 reprovados** (eram 115 antes desta sessão) |
| Análise estática estrita | `luau-lsp analyze … src/` | 0 erros em 60 módulos |
| Lint | `selene src/` | 0 erros, 4 avisos (todos anteriores a esta sessão) |
| Formatação | `stylua --check src/` | conforme |
| Tokens e animações | `python3 tools/import_ui_tokens.py` | OK, com checagem de contraste embutida |
| Ícones | `python3 tools/export_ui_icons.py` | 24 exportados e enviados; IDs reais no registro (nenhum id inventado) |
| Cobertura das pranchas | `python3 tools/check_ui_coverage.py` | 49/49 declaradas e validadas contra `telas.json` |
| Regeneração completa dos módulos gerados | `import_balance` + `update_asset_registry` + `import_ui_tokens` + `export_ui_icons` | sem diferença no repositório: o que está versionado é exatamente o que as ferramentas produzem |
| Build do lugar | `rojo build default.project.json -o build/QuintalEmGuarda.rbxl` | gerado (287 KB, só código e configuração) |

Specs novos: `07_ui_tokens` (paleta, contraste, receitas de animação, biblioteca de ícones) e
`08_ui_state` (convites com expiração e cooldown, máquina de estados da conexão, recompensa
pendente, validação de `RespondInvite` e cobertura de texto PT-BR/EN).

**Defeitos de acessibilidade encontrados pela ferramenta de contraste**, antes de qualquer teste
manual: `danger` sobre `dangerSoft` dava 4,45:1 e `tealDark` sobre `paper` dava 3,96:1, ambos abaixo
do mínimo de 4,5:1 do guia; `goldDark` sobre `paper` dava 2,14:1 e estava sendo usado como cor de
texto. Correções: `dangerSoft` clareado para `#FCE6E2` (4,65:1), `tealDark` escurecido para `#18705F`
(5,72:1) e criação de `goldText` `#8A5E12` (5,46:1), com `goldDark` reclassificado como cor só de
preenchimento — um teste garante que nenhum par de texto volte a usá-lo.

### 8.2 Sessão de Play no Studio (executada)

Place `Tower Defense` (PlaceId 85307223725202), viewport 1090×693, mouse e teclado reais via
automação do Studio, sem acesso a DataStore (o que exercitou justamente o caminho de perfil
indisponível).

| Cenário | Resultado |
| --- | --- |
| Camadas de renderização | ✅ `QuintalWorld/Hud/Menu/Modal/Toast` com DisplayOrder 0/10/20/30/40; só as interativas com `CoreUISafeInsets` |
| Entrada com perfil indisponível (01/26/42) | ✅ menu abriu em modo volátil com "Progresso não salvo" fixo, sem gravar defaults |
| Menu inicial (02) | ✅ "Jogar" como única ação dourada, saldo fora da faixa de ações, loja ausente com a flag desligada |
| Coleção (06/43) | ✅ seis cartas com custo de desbloqueio e de construção separados, quatro vagas, "Salvar" indisponível com o motivo "Nada mudou desde a última vez" |
| Detalhe da torre (07) | ✅ Lupa mostrou **240 botões** para desbloquear e **500 sucatas** para construir, com "Faltam 240 botões" no botão — critério de aceite do guia |
| Carregamento (11) | ✅ progresso contando assets essenciais resolvidos, sem porcentagem inventada |
| Tutorial passos 1–3 (21) | ✅ posicionar Dardo, iniciar onda e a instrução do Circuito com Goma |
| Construção (14) | ✅ 1.200 → 950 de sucata e 0 → 1 torre **apenas após o ACK**; a barra de construção fechou sozinha |
| Torre selecionada (16) | ✅ comparação inline (Dano 10 → 16 ↑, Intervalo 0,8 → 0,75 ↓, Alcance 2,5 → 2,7 ↑) e ações fixas |
| Venda (18) | ✅ modal com foco inicial em **Cancelar**, botão nomeando a ação ("Vender • 175") e **175 sucatas** devolvidas — critério de aceite do guia |
| Opções em combate (13/27) | ✅ painel com grupo em leitura, Configurações e Sair; a partida continuou correndo por trás |
| Configurações durante a onda (10) | ✅ sliders, toggles com texto, idioma; o combate não pausou e o texto diz isso |
| Troca PT-BR ↔ EN (10) | ✅ moldura, tela ativa e HUD reescritos ao vivo |
| Console | ✅ nenhum erro de script durante toda a sessão |
| Upload dos 24 ícones (49) | ✅ enviados pelo Studio e verificados em Play: **24/24 com `IsLoaded = true`** |

### 8.3 Defeitos encontrados no Studio e corrigidos nesta sessão

1. **Maiúsculas comiam acentos.** `string.upper` só trata ASCII: o selo do menu saiu como
   "BRINQUEDOS EM MISSãO". Virou `Components.upper`, usado em todos os títulos de seção.
2. **As ações da torre saíam do painel.** Com o balão do tutorial aberto o painel de detalhe encolhe
   para 315 px e Melhorar/Alvo/Vender ficavam fora da área visível — clicar onde o botão "estava"
   acertava a faixa inferior do HUD. Agora só os atributos rolam e as ações ficam ancoradas na base.
3. **Troca de idioma deixava texto antigo.** O HUD e a moldura das telas escrevem rótulos fixos na
   construção. Passou a existir um sinal de troca de idioma que reconstrói o HUD e redesenha a tela
   ativa.
4. **Números da comparação ignoravam o idioma.** "Intervalo: 0.8 → 0.75" convivia com "Intervalo 0,8 s"
   na mesma ficha; passou a usar a formatação decimal do idioma.
5. **Texto de venda se contradizia.** Dizia "Circuitos ligados serão desfeitos" logo acima da linha
   "Esta torre não participa de nenhum Circuito".
6. **Foco de teclado não tinha por onde começar.** O Tab é reservado pela CoreGui em parte dos
   clientes (o próprio Studio recusa enviá-lo), então clicar/tocar agora leva o foco junto e as setas
   movem o foco dentro da camada ativa. O Escape continua respeitando a CoreGui, como manda o guia.

### 8.4 Pendente (não executado)

Trinta das 49 pranchas dependem de condições que uma sessão local de Play não cria. A lista completa,
linha a linha, está em `docs/UI_COVERAGE.md`; em resumo:

- **Dois ou quatro clientes**: disputa da última vaga (04), prontidão do grupo (05), convites
  simultâneos (33/40), votação de 2x (31/40), Pulso confirmado ao mesmo tempo (20).
- **Perfil persistido** (exige Studio Access to API Services ou servidor real): desbloqueio por
  botões (32), domínio e cosméticos (08/43), vitória (23), derrota (24), recompensa pendente (25) e
  os destaques de resultado (44).
- **Matriz de dispositivos**: 844×390, 896×414, 1280×720, 1920×1080, tablet 1024×768 e vertical
  390×844, cada um em PT-BR e EN, com texto ampliado e movimento reduzido (28, 29, 30, 35, 36, 47, 48).
- **Partida completa**: barra e avisos dos três chefes (19/41), especialização em L2 (17), inspeção
  de inimigo (34), treino com chefes (22).
- **Loja**: todos os estados de 09/46 dependem de um passe criado no Creator Hub.
- **Latência simulada** de 100/300/1000 ms e contagem de pedidos por ação confirmada.
- **Moderação dos 24 ícones**: o carregamento foi verificado, mas a moderação do Roblox é
  assíncrona e pode remover um asset depois; conferir no Creator Hub antes do lançamento.

Nenhuma dessas linhas foi marcada como aprovada. A interface está implementada e integrada; a
validação em dispositivo e com várias pessoas continua sendo trabalho manual descrito em
`docs/MANUAL_ACTIONS.md`.
