# MILESTONES — registro dos marcos M0 a M6

Registro de progresso por marco (o que mudou, o que foi verificado, o que falta). Datas em 2026-09-16.

## M0 Fundação — concluído
- Projeto Rojo (`default.project.json`), toolchain fixada (`rokit.toml`, `tools/bootstrap_toolchain.sh`), `.luaurc` estrito, selene e StyLua.
- Geração de `Config/Balance.luau` e `Config/Maps.luau` a partir do JSON com validação (`tools/import_balance.py`).
- Export dos 40 PNGs (`tools/export_assets.py`), upload real de 58 imagens + 11 placeholders, `Config/Assets.luau` gerado a partir do registro.
- Cliente 2D em ScreenGui: `BoardTransform` (16:10, zoom, pan, inversa), render do chão/caminho/props/base com as coordenadas canônicas.
- Verificado: sync Rojo no place aberto, Play no Studio abre o menu e a partida; entrada por mouse resolve célula correta (torres colocadas nas células esperadas).

## M1 Combate — concluído
- Simulação pura (`Sim/Simulation.luau`) com passo 0,05 s, ordem por passo da especificação, ondas/grupos, movimento, vazamentos, mortes e pagamentos.
- Regras puras (`Rules/Combat`, `Rules/Circuits`, `Rules/Rewards`) com testes T01–T20 (Lune).
- Verificado no Studio: tutorial completo do início à vitória (3 ondas) e derrota headless sem torres (teste automatizado).

## M2 Diferencial — concluído
- Seis torres e 30 estados (troca de imagem por estado, upgrade com fração de cooldown preservada), especializações L3A/L3B com confirmação, três Circuitos determinísticos com prévia, treino (sucata infinita, todas as torres, gerar/limpar, alcances e Circuitos).
- Verificado: Circuito Dardo–Goma em partida (fio no chão, painel de detalhe com parceiro e bônus), Dardo L3B (Fura lata) com `armorIgnore 1`, testes T07–T13.

## M3 Conteúdo — concluído (verificação parcial no Studio)
- Três mapas, vinte ondas, oito inimigos (Remendo cura, Casulo divide, Névoa/Latinha resistências), três chefes (poeira, armadura, invocação), duas dificuldades, Pulso de Luz.
- Verificado por testes automatizados (T14–T19, vida por cooperação/dificuldade/mapa). No Studio: ondas 1–6 do Jardim Normal em 1x e 2x; chefe e ondas finais verificados por salto de desenvolvimento (ver TEST_REPORT).
- Pendente: execução completa das 24 combinações mapa × dificuldade × grupo.

## M4 Serviço — código concluído; testes de concorrência real pendentes
- Party no servidor (líder, membros, prontidão, salas, convites), congelamento de participantes, presença (30 s inatividade, 60 s abandono), revanche, perfis com lock de sessão/UpdateAsync/migrações, ledger de resultados idempotente, recompensas pendentes reconciliadas na entrada.
- Verificado: fronteira de rede (envelope, deduplicação, limites de taxa, rejeições P08/P09) com testes e chamadas reais; perfil volátil no Studio sem DataStore.
- Pendente: quatro clientes reais, DataStore real (place publicado), latência simulada.

## M5 Apresentação — concluído com visuais provisórios identificados
- HUD conforme wireframe, detalhe lateral/folha, prévia de onda, banner de chefe, tutorial guiado, resultado, coleção, configurações (acessibilidade), localização pt-BR/en, movimentos procedurais das torres (`TowerAnimator`), projéteis/correntes/explosões/números de dano cosméticos, poeira do chefe.
- Responsividade (2026-09-16): escala uniforme por janela, troca automática computador/compacto, cartas adaptativas, grade da coleção por colunas, linhas com quebra no menu; transições animadas (cortina, painéis, avisos, contadores) com respeito ao movimento reduzido. Verificado em 1313×693, 1920×1080, 1024×768 e 750×361.
- Pendente: quadros desenhados (240 torres, 96 inimigos, 48 chefes), áudio, ícones, testes em celular real.

## Adendo 2026-09-18 — inimigos, chefes e animação 2D
- Entrada: `GUIA_MONSTROS_E_BOSSES.pdf` e `Assets_Inimigos_Bosses_v1/` (11 poses). Os 8 inimigos e 3 chefes já existiam na simulação desde M3; esta etapa integrou a arte real, o movimento 2D e os eventos de apresentação, e cobriu a tabela de aceite do guia com testes.
- Novo: `tools/export_enemy_assets.py`, `tools/merge_enemy_index.py`, `src/client/View/EnemyAnimator.luau`, `tests/specs/06_enemies_bosses.spec.luau` (27 testes).
- Servidor: eventos de chefe passaram a levar prazo (`resolveAt`, `expiresAt`), alvos (`entityIds`, `towerIds`) e cancelamento (`bossCancel`) quando o chefe morre ou escapa durante o aviso; o evento de cura lista os alvos curados; o snapshot leva prazo do aviso, armadura atual e resistência de energia.
- Verificado no Studio: 11/11 sprites carregados no place do grupo, largura por tipo, ciclos de movimento com as amplitudes do guia, selo de aviso com contagem e poeira na torre. Ver `docs/TEST_REPORT.md` seção 7.
- Pendente: quadros desenhados (96 + 48), movimento reduzido conferido em tela, partida completa de 20 ondas por mapa.

## Adendo 2026-09-18 — interface completa (49 pranchas)
- Entrada: `UI_Quintal_em_Guarda_v1` (guia, 49 pranchas, `telas.json`, `design_tokens.json`, `animacoes.json`, 24 ícones e dois módulos de exemplo). Os insumos de build foram copiados para `UI_Quintal_em_Guarda_v1/` na raiz; as pranchas continuam no Drive e são referência, nunca interface.
- Nova base: `src/client/UI/` com Accessibility, Anim, Focus, Components (ActionButton de oito estados), Modal, Toasts, CommandAdapter, Layers, Router, Store e InviteCards; 15 telas em `UI/Screens/`; `View/HudPanels.luau` com os painéis contextuais do combate. `View/Ui.luau` virou adaptador fino e as telas antigas (`Menu`, `Collection`, `Settings`, `Shop`, `Result`) foram removidas para não existirem duas implementações.
- Camadas: `QuintalWorld/Hud/Menu/Modal/Toast` com DisplayOrder 0/10/20/30/40; só as interativas usam `CoreUISafeInsets`, e a transformação do tabuleiro não soma o inset de novo.
- Gerados: `tools/import_ui_tokens.py` (Config/UiTokens + UiMotion, com checagem de contraste que falha o build), `tools/export_ui_icons.py` (24 ícones + Config/UiIcons, sem inventar IDs) e `tools/check_ui_coverage.py` (valida `docs/ui_coverage.json` contra as 49 pranchas e gera `docs/UI_COVERAGE.md`).
- Servidor: `RespondInvite` com token, expiração de 30 s e cooldown de 5 s por destinatário; os cosméticos dos marcos de domínio (30/100/250) passaram a ser concedidos de fato em `ProfileSchema.applyMatchResult` e chegam ao cliente pelo resultado.
- Localização: 247 chaves novas em PT-BR e EN (462 no total), incluindo os rótulos acessíveis dos 24 ícones.
- Verificado no Studio (sessão de Play, 1090×693): camadas, entrada com perfil indisponível, menu, coleção, detalhe de torre (Lupa 240 botões / 500 sucatas), carregamento, tutorial 1–3, construção com débito só após ACK, venda devolvendo 175, opções em combate e troca PT-BR/EN ao vivo, sem erro no console. Seis defeitos encontrados e corrigidos — ver `docs/TEST_REPORT.md` seção 8.
- Ícones enviados em 2026-09-18 pela conta logada no Studio (IDs em `assets/export/ui_upload_log.json`), com 24/24 carregando numa sessão de Play.
- Pendente: moderação dos ícones, dois a quatro clientes, perfil persistido, matriz de dispositivos, partida completa até o chefe e estados da loja. A matriz linha a linha está em `docs/UI_COVERAGE.md`.

## M6 Candidato — não iniciado (depende de ações externas)
- Publicação, DataStore em produção, telemetria em produção, desempenho medido em aparelhos nomeados, playtest. Ver `docs/MANUAL_ACTIONS.md`.

## M7 Revamp — arquitetura e apresentação (2026-09-19)

Pedido: sair do MVP "cópia de Bloons sem polimento" e virar um projeto sustentável, com interface
nova e mais reação no combate.

**Bibliotecas (Wally 0.3.2).** `wally.toml` fixa Fusion 0.3.0, Charm 0.10.0, ByteNet 0.4.6,
Trove 1.8.0 e ProfileStore 1.0.3. `Packages/` e `ServerPackages/` são gerados; `wally.lock` é
versionado. Fachadas tipadas em `src/shared/Lib/` (com `tools/check_package_facades.py` conferindo
as versões) porque o arquivo de ligação do Wally esconde os tipos do analisador.

**Estado (Charm).** `src/client/State`: átomos crus, seletores derivados e ações. O store escrito à
mão saiu. A troca de tabela é sempre por cópia, então quem já leu não vê o valor mudar por baixo —
tem teste para isso.

**Rede (ByteNet).** O par RemoteFunction + dois RemoteEvents virou um namespace de cinco pacotes.
`Net/Enums` e `Net/Codec` são puros: trocam `"fiapo"`, `"Preparation"` e `"L3A"` por inteiros e têm
teste de ida e volta fora do Studio. `Net/Protocol` continua dono da validação, dos baldes de taxa e
da deduplicação. Respostas de comando e avisos de lobby continuam em `unknown` (raros e de forma
variável) — está documentado no próprio módulo.

**Perfis (ProfileStore).** ~250 linhas de UpdateAsync, token de trava, renovação a cada 30 s e fila
de gravação saíram. `PlayerDataService` guarda migração, validação e a visão enviada ao cliente.

**Interface (Fusion).** As 15 telas, o HUD de combate e as sobreposições foram reescritas sobre
`UI/Kit` (componentes) e `UI/Skin` (profundidade, lustro, chanfro, cenário). Sumiram: Router, Store,
Modal, Toasts, Components, Focus, Layers, CommandAdapter, o adaptador `View/Ui` e `View/Motion`,
além de `PlayController` e `ScreenController` (viraram `BoardPresenter` + `GameFlow` + `UI/App`).

**Apresentação do combate.** `View/Juice` concentra tremor, clarão, estouro de partículas, anéis e
números em arco, todos atrás das preferências de conforto. O tabuleiro ganhou sombra projetada,
xadrez discreto, vinheta, trilha com sombra e halo no Farol.

**Verificado no Studio (Play, 2026-09-19).** Menu montado com saldo e equipe; tutorial iniciado pelo
fluxo real; faixa superior com Farol 100/100, Onda 00/03, "Pronto →" e 1.200 de sucata; doca com
Dardo/Pipoca/Goma (retrato e custo); tabuleiro com 397 descendentes; console sem erros.

**Defeitos encontrados rodando (e corrigidos).**
1. Structs do ByteNet criadas fora do `defineNamespace` quebravam a primeira mensagem.
2. O primeiro envio a um jogador recém-entrado acontece antes de o ByteNet criar o canal dele:
   `Net/Server` passou a reenfileirar e repetir no Heartbeat seguinte.
3. `Kit.text` quebrava quando `TextSize` chegava como estado reativo.
4. Sessão de perfil sumia e deixava o jogador preso em "carregando" (e `StartMatch` recusando):
   agora a sessão é recriada sob demanda e a entrada só é descartada 60 s depois da saída.

**Pendente.** 44 das 49 pranchas ainda não foram exercitadas no Studio depois da reescrita
(`docs/UI_COVERAGE.md`); nada de multiplayer real, DataStore de produção, matriz de dispositivos ou
latência simulada foi refeito nesta sessão.

### Segunda rodada no Studio (2026-09-19, com a janela visível)

Rodando o jogo de verdade — e olhando para a tela — apareceram defeitos que nenhuma checagem
estática pega. Todos corrigidos nesta rodada:

1. **Remontar a interface matava o tabuleiro.** Trocar de layout (ou de idioma) destrói a árvore
   Fusion, e o viewport do tabuleiro ia junto: `attach` tentava reaproveitá-lo e o Roblox recusava
   ("The Parent property of BoardViewport is locked"). Agora o apresentador detecta o viewport
   morto, reconstrói tabuleiro e entrada e redesenha a partida em andamento.
2. **Cenário escuro sob texto escuro.** O fundo ilustrado nasceu noturno e o menu é tinta sobre
   papel: o título ficou ilegível. O quintal virou de dia (creme → sálvia) com a folhagem escura só
   nas bordas.
3. **Chanfro do botão em cima do rótulo.** A "espessura" era desenhada dentro do botão e cobria a
   segunda linha. Virou um suporte com a espessura atrás do corpo; apertar afunda o corpo 5 px.
4. **Cartas de torre sem nome nem custo.** Um UIListLayout enfileira todos os filhos — inclusive o
   lustro decorativo e o selo de atalho, que empurravam o conteúdo para fora. `Kit.panel` passou a
   pôr o conteúdo num quadro próprio, com `overlay` para o que é posicionado à mão.
5. **Cartão de tutorial com um vão enorme.** A sombra projetada é 8 px maior que o painel e
   `AutomaticSize` mede os filhos: o painel crescia sozinho a cada quadro. Painéis que crescem com
   o conteúdo deixaram de ter sombra.
6. **Ícones invisíveis na faixa escura.** A arte dos 24 ícones é tinta escura e `ImageColor3`
   multiplica, então não há tinta que os clareie. Em superfície escura eles passaram a vir sobre um
   disco creme (`Kit.iconBadge`).
7. **Tutorial travado.** "Entendi" mandava `TutorialAdvance` ao servidor, que é só um aceite — a
   etapa real muda por evento (colocar a torre certa, terminar a onda). O cartão nunca fechava.
   Agora "Entendi" fecha a explicação localmente, a última etapa encerra o tutorial, e as etapas de
   ação já abrem o posicionamento na torre e na célula marcadas.
8. **"Torres x/y" piscando em zero.** A contagem lia o snapshot parcial (que vem sem torres) em vez
   do espelho acumulado.
9. **Configurações no meio do combate apagavam o jogo.** O HUD estava preso à rota; passou a
   depender de haver partida, então a tela de opções abre por cima sem derrubar o tabuleiro.
   Junto: "Sair" ganhou botão próprio na faixa e "Ver tudo" voltou quando há zoom.
10. **"Pronto" não alternava** e o resultado mostrava o total de ondas errado.

### Terceira rodada: tutorial jogado do início ao fim (2026-09-19)

Defeitos encontrados **jogando** e corrigidos:

11. **Clicar na torre não selecionava nada.** O sprite tem apoio em (0,5; 0,82), então o corpo do
    bicho fica na célula de cima da base: o teste de acerto usava só a célula sob o cursor. Agora
    olha também a célula de baixo (e o mesmo ajuste vale para inimigos).
12. **Painéis do HUD não engoliam o toque**: clicar na doca ou na barra de construção também
    contava como toque no tabuleiro. `Kit.panel` ganhou `blocking`, ligado nos painéis do combate.
13. **Detalhe da torre atrás do cartão de tutorial.** Os dois eram ancorados no mesmo canto. Viraram
    itens de uma coluna rolável à direita (tutorial, detalhe, treino), que nunca invade a doca.
14. **O "✕" do detalhe virou item da lista** (aparecia como um quadradinho no topo): foi para
    `overlay`.
15. **Movimento reduzido apagava o combate inteiro.** `Accessibility` derivava "partículas
    reduzidas" de "movimento reduzido", e o Studio desta máquina tem Reduced Motion ligado: sem
    projétil, sem número de dano, sem clarão — o jogo parecia parado. Projétil, impacto e número
    são informação, não enfeite: agora só a preferência explícita de partículas os desliga.

Verificado no fluxo real (clique a clique até a tela travar, depois pela mesma rede que a interface
usa): Dardo guiado → onda 1 → Goma guiada → melhoria L1/L2 → etapas 1..5 confirmadas pelo servidor →
vitória com "Farol protegido!", 3/3 ondas e "Recompensa 180 botões · Recompensa salva". Durante a
onda, a camada de efeitos mostrou projéteis, números de dano, anéis de impacto e partículas de morte
em quase todos os quadros amostrados.

### Construir no próprio clique (2026-09-19)

Mirar a célula e apertar um botão na tela ao mesmo tempo não funciona com um único ponteiro. O
fluxo de construção mudou:

- **Computador**: o clique na célula constrói. O fantasma já segue o cursor, então o alvo é o que
  está desenhado no tabuleiro.
- **Toque**: o primeiro toque posiciona (o dedo cobre a célula) e o segundo, na mesma célula,
  constrói. O botão "Construir por X" continua existindo **só no celular**, como alternativa.
- **Tutorial**: a célula é a marcada, então o primeiro toque constrói em qualquer aparelho.
- **Célula inválida**: nunca constrói e nunca gasta; o motivo vira aviso curto ("Não dá para
  construir no caminho", "Faltam N sucatas"…), com o fantasma parado na célula para o jogador ver.

A regra virou um módulo puro (`src/client/Controllers/BuildIntent.luau`) com teste próprio
(`tests/specs/12_build_intent.spec.luau`): é a interação mais sensível do jogo e agora está
coberta fora do Studio. A barra de construção deixou de ser confirmação e virou instrução.

### Ajustes de jogo pedidos em 19/09 (tarde)

1. **Trava ao sair do tutorial.** "Voltar ao menu" mandava `LeaveMatch` e esperava o quadro "left";
   no fim do tutorial a partida já estava encerrada no servidor, o pedido voltava com erro e o
   quadro nunca chegava — o jogador ficava preso na tela de combate. `GameFlow.leaveMatch` agora
   garante a volta ao menu (no erro e por prazo de 2 s), sem desfazer uma revanche que já começou.
2. **Menu depois do tutorial.** Com `tutorialCompleted`, o botão principal vira "Jogar" (leva aos
   mapas) e "Rever tutorial" fica como opção secundária.
3. **Torre olhando para o alvo.** `TowerAnimator` passou a guardar o par normal/espelhado e trocar
   a textura conforme o lado do disparo. Como o Roblox não espelha `ImageLabel` (ver
   `docs/MANUAL_ACTIONS.md`), os 30 sprites espelhados são gerados por
   `tools/mirror_tower_sprites.py` e esperam upload; sem eles a torre continua virada para a
   direita, sem erro.
4. **Ritmo das hordas.** Tutorial: onda 1 com **um** inimigo, onda 2 com 4 Fiapos + 2 Corriscos,
   onda 3 com 6 Fiapos + 1 Bolota (era 6 / 10 / 10). Mapa: as quatro primeiras ondas ficaram mais
   espaçadas (onda 1: 8 Fiapos a cada 1,9 s, contra 12 a cada 1,1 s) e voltam ao ritmo original a
   partir da onda 5. Alterado no JSON canônico + `tools/import_balance.py`.


### Mapa desenhado e HUD da maquete (2026-09-19, fim da tarde)

**Mapa.** A arte do Jardim de Papel virou uma cena única (grama, caminho, praia e folhagem na
mesma imagem), agora na versão **sem o farol** — ele continua desenhado por código na última
célula do caminho, com brilho e resposta a dano.

O encaixe da grade foi medido duas vezes. A primeira usou só as bordas dos corredores de areia e
errou o eixo X em cerca de 20% de uma célula (a areia tem borda macia, e o fim do corredor não é
o fim da célula): no Studio dava para ver a grade deslocada para a direita. A medida boa usa os
**ladrilhos desenhados na grama**, que são periódicos: o gradiente horizontal e vertical da arte
tem passo 35,6 px (metade da imagem) com fase 9,0 em x e 18,4 em y, e a origem da grade é um
desses limites. Daí sai `playRect` `[0.0533, 0.1149, 0.7347, 0.8723]` — proporção 1,600,
exatamente 16:10 — com as 28 células de caminho na areia e nenhuma de grama nela. Conferido no
Studio: as células do modo de construção coincidem com os ladrilhos desenhados nos dois lados do
tabuleiro. `assets/export/map_scene_overrides.json` guarda origem, sha256, id publicado
(`rbxassetid://85414482526997`), `playRect`, `includesPath = true` e `includesBase = false`.

**Sangria.** `BoardTransform` ganhou um **palco**: a janela passou a ocupar a área inteira (e
recortar), e a grade 16:10 fica centrada dentro dela. Toda a matemática de célula, zoom e
deslocamento usa o palco; a janela é só o recorte. O tabuleiro também saiu do HUD e foi para a
camada do cenário (`ScreenInsets.None`), então a arte passa por baixo da barra do Roblox. Onde a
janela é bem mais larga que 16:10, a mesma imagem entra atrás recortada (`SceneBackdrop`), em vez
de aparecer a cor de fundo. Com o tabuleiro fora do HUD, o teste "o toque foi no painel ou no
tabuleiro?" passou a ser por ordem de desenho, sem depender de parentesco.

**HUD.** Sumiram a faixa superior e a doca inferior. Agora: fichas no canto superior esquerdo
(Farol, Onda, Sucata, fase, limite), velocidade/opções/sair no canto superior direito, coluna
**TORRES** à direita, contexto (tutorial, detalhe da torre, treino) no canto inferior esquerdo e,
no rodapé, **Pulso de Luz** e o botão verde **Iniciar Onda** — centrados, e não no canto direito
da maquete, porque neste mapa o Farol fica justamente ali. O verde entrou como token
(`grass`/`grassDeep`, 7,25:1 com o texto) pelo gerador, não à mão.

**Correção no Kit.** `Kit.panel` com `AutomaticSize.X` inflava a cada quadro: a superfície media
1 de escala do suporte enquanto o suporte media a superfície, e a sombra somava 8 px por volta.
A pílula "Próxima onda" atravessava a tela. Agora o eixo que cresce não mede em escala e não
ganha sombra — o mesmo cuidado que já existia no eixo Y.

**Verificado no Studio (Play real, 2026-09-19):** menu → Jogar → Jardim de Papel → partida; arte
até as bordas sem faixa de fundo; Farol desenhado por código exatamente na ponta do caminho;
carta Dardo → clique na célula constrói (650 → 408 de sucata, Torres 1/18); clique no caminho
recusa com o motivo; onda 1 com Fiapos feridos pelo Dardo. A tela de carregamento passou a
preencher `{difficulty}` e `{team}` (antes mostrava as chaves cruas).

### Interação, ritmo das ondas e cenários novos (2026-09-19, noite)

**Arrastar move a câmera; o botão direito cancela.** Mirar uma célula e apertar um botão ao mesmo
tempo não funciona com um ponteiro só, então o gesto passou a mandar: assim que o ponteiro (ou o
dedo) anda mais que a tolerância de toque, o movimento vira deslocamento da câmera e **não**
constrói — mesmo com uma torre escolhida. O clique parado continua construindo. No computador, o
botão direito parado cancela o modo de construção (arrastado com ele, só desloca).

**Torres viradas no próprio eixo.** A tentativa anterior (gerar 30 sprites espelhados e publicar)
foi descartada: um teste no Studio mostrou que `ImageRectOffset = {w, 0}` com
`ImageRectSize = {-w, h}` **espelha a textura** de um `ImageLabel`. `TowerAnimator` agora guarda o
quadro em pixels e troca o retângulo conforme o lado do alvo. Saíram do projeto
`tools/mirror_tower_sprites.py`, `assets/export/mirror/`, o manifesto e o campo `mirror` do
registro — nada disso é mais necessário.

**Ritmo das ondas.** Ao terminar uma onda entra um aviso grande no meio da tela
("Onda 2 concluída!" com "+150 sucatas"), com salto de mola e sumiço automático. Na espera da
próxima, a contagem aparece **na entrada do caminho**, dentro do tabuleiro: uma bolha que pulsa a
cada segundo cheio e, nos últimos três, fica vermelha e treme. Quando a onda sai, a bolha vira um
estouro na própria entrada. A prévia "Próxima onda: …" saiu do canto superior esquerdo (onde agora
fica a contagem) e virou o último item da coluna de contexto.

**Zoom padrão mais largo.** O palco passou a ocupar 86% da janela (`BoardTransform.BASE_FIT`), o
que tira a sensação de aperto e deixa a cena desenhada aparecer em volta da grade.

**Dois cenários novos e uma ferramenta para medir.** As artes do Jardim e do segundo mapa foram
refeitas a partir dos gabaritos (`docs/map_templates/`, gerados por `tools/make_map_template.py`).
Como a IA de imagem não repete a rota exata, `tools/fit_map_scene.py` passou a medir tudo a partir
da arte: descobre as cores do piso na própria imagem, mede a malha pelo gradiente, escolhe a janela
16x10 que melhor cobre piso+corredor, e devolve `playRect`, a rota em células e os bloqueios. As
rotas e os bloqueios dos dois mapas vieram dessa medida, e `tests/specs/01_grid_path.spec.luau`
deixou de conferir números escritos à mão: agora cobre invariantes (soma dos trechos, células =
comprimento + 1, célula guiada do tutorial fora do caminho), que sobrevivem à próxima arte.

**Todos os mapas abertos (temporário).** `src/shared/Config/DevFlags.luau` traz
`unlockAllMaps = true`; cliente e servidor leem o mesmo arquivo. A regra de campanha continua
inteira em `ProfileSchema.campaignUnlocked` e continua testada. Desligar antes de publicar
(está anotado em `docs/MANUAL_ACTIONS.md`).

**Verificado no Studio (Play real):** os três mapas aparecem destravados; a cena de neve e a do
jardim entram com a grade batendo nos ladrilhos desenhados; arrastar com o botão esquerdo (com
Dardo escolhido) deslocou a câmera sem construir; o botão direito fechou a construção; as ondas 1
e 2 terminaram com o aviso grande e a recompensa; a contagem apareceu na entrada; e as duas torres
em campo aparecem **viradas para a esquerda** enquanto atiram nos Fiapos que vêm daquele lado.

### Tela de entrada sobre a ilustração de marca (2026-09-19, noite)

O logotipo e o fundo desenhados entraram no jogo. Os dois arquivos ficam em `assets/generated/`,
os ids em `assets/export/brand_assets.json`, e `tools/import_brand_assets.py` gera
`src/shared/Config/Brand.luau` — o mesmo contrato dos outros assets: **sem entrada no JSON, a
chave sai `nil`** e a tela desenha o título em texto, sem erro e sem buraco.

A ilustração é desenhada pela camada de cenário (sem área segura), então sangra até as bordas, com
um véu escuro só do lado esquerdo — é onde mora o texto. Ela aparece nas rotas `boot` e `menu`; nas
outras telas o cenário claro procedural volta, porque os painéis de Mapas, Coleção e Loja são tinta
escura e perdiam contraste sobre a arte.

O menu seguiu a maquete: logotipo e subtítulo à esquerda, "Jogar · Escolher mapa" grande em
dourado, "Rever tutorial · Aprenda o básico" e "Coleção · Veja seus itens" lado a lado, e
"Treino/Loja/Configurações" na linha escura de baixo. O saldo de botões fica no canto superior
direito e a equipe salva no inferior direito, agora com os retratos das três torres equipadas.
Os subtítulos entraram em `Config/Localization` (pt-br e inglês).

**Verificado no Studio:** entrada com a arte e o logotipo reais; ao entrar em "Escolher mapa" o
fundo volta ao cenário claro e o título da tela continua legível.

### Marca da entrada: menor, centrada e clicável (2026-09-19, noite)

A ficha "Preparação · Xs" saiu da faixa de fichas: quem conta o tempo agora é só a marca desenhada
na entrada do caminho. Ela ficou menor (0,95 célula), parada e com o número centrado — o
`Skin.label` alinha à esquerda por padrão, e era por isso que o número aparecia encostado no lado.
Nos **últimos 5 segundos** ela cresce para 1,2 célula, fica vermelha, pulsa a cada segundo e treme;
acima disso, nada se mexe.

**Clicar na marca chama a onda na hora e paga bônus.** A regra é do servidor, não da interface:
`Simulation.startWave` confere quanto tempo sobrava no cronômetro e, se sobrava, credita
`min(segundos × earlyWaveBonusPerSecond, earlyWaveBonusMax)` (5 por segundo, teto de 80, no
`balanceamento_v1.json`) para todos os participantes e emite o evento `earlyBonus`. Deixar o
cronômetro acabar não paga nada, e treino e tutorial ficam de fora. O botão "Iniciar Onda" usa o
mesmo caminho, então também paga — é bônus por adiantar, não por onde se clicou.

No cliente, o toque na marca é tratado em `BoardPresenter.onTap` **antes** da leitura de célula (se
fosse um botão de interface, o mesmo toque ainda tentaria construir no caminho). O começo da onda
com bônus troca o aviso de perigo por "Onda adiantada! +X sucatas", com estouro dourado e o número
subindo na entrada. Duas regressões cobertas em `tests/specs/03_simulation.spec.luau`: chamar cedo
paga o previsto, deixar o cronômetro acabar não paga.

Dois defeitos corrigidos no caminho: o `Computed` da ilustração de marca criava o `Bridge.use`
dentro dele (o Fusion avisava `possiblyOutlives` a cada montagem), e `BoardPresenter.attach`
estourava "Parent property of BoardViewport is locked" quando a interface era remontada (troca de
idioma) — agora ele tenta remanejar o quadro e, se ele já foi destruído junto com a montagem
antiga, refaz o tabuleiro do zero e reaplica a partida em andamento.

### Campanha por fases no lugar do tutorial (2026-09-19, noite)

O tutorial saiu do jogo — modo, comandos (`TutorialAdvance`/`TutorialSkip`), passos, cartão,
checkpoint de repetição, recompensa de 180 botões e o botão na tela inicial. No lugar entrou uma
**campanha declarada em dados**.

**Fases.** `balanceamento_v1.json` ganhou o bloco `campaign` com 12 fases: cada uma aponta um mapa,
quantas ondas da tabela global usa, escala de vida, sucata inicial e **dois objetivos**. O
importador valida tudo (mapa existe, ondas cabem na tabela, objetivo é conhecido, a fase do guia é
a primeira e a célula que ela indica é grama livre), então fase malformada não chega no jogo.

**Estrelas.** A primeira é sempre vencer; as outras duas são os objetivos, avaliados no servidor
por `Rules/Stars` (regra pura, 8 testes) sobre estatísticas que a simulação passou a medir: dano
levado, torres construídas, quais torres entraram em campo e quantas ondas foram adiantadas.
Objetivos de hoje: sem levar dano, dano máximo, teto de torres, só com certas torres e adiantar
todas as hordas. O perfil guarda o **melhor** resultado por fase (`campaign[levelId]`) e paga
botões só pela diferença de estrelas; a fase seguinte abre com pelo menos uma estrela na anterior.
Perfil migrou para v3: quem já tinha concluído o tutorial começa com a fase 1 vencida.

**Fase 1 é o tutorial.** Ela é a única com `manualWaveStart` (nenhum cronômetro: cada horda espera
o jogador chamar) e com `intro`. Na primeira vez que o perfil a joga, um guia de três passos
aparece: escolher o Dardo, posicionar na célula marcada, chamar a horda. Cada passo avança pela
ação do jogador, o guia some quando a primeira horda sai, e o perfil marca `campaignIntroSeen` no
servidor — não volta mais.

**Telas.** "Jogar Campanha" no menu (o botão de tutorial saiu), a tela de mapas virou a lista de
fases com estrelas, cadeado e os objetivos escritos, o HUD ganhou um painel de objetivos com o
estado ao vivo e o resultado mostra as três estrelas da partida. Party, salas e revanche passaram
a falar em fase (`levelId`) no lugar de mapa; o treino continua indo por mapa solto.

177 testes passando (novos: `13_stars.spec.luau` e os de fase em `03_simulation`), selene,
stylua e luau-lsp limpos.

### Juice da campanha e do level up (2026-09-19, madrugada)

**A lista de fases rolava?** Não: `Kit.screen` só monta um `ScrollingFrame` quando a tela pede
`scroll`, e a grade estava dentro de um quadro de altura automática — o canvas não enxergava o
conteúdo. Agora a grade é o layout do próprio corpo rolável, e a lista rola até a fase 12.

**Estrelas com peso.** O cartão de resultado entra com mola (`Kit.panel` ganhou `scale`) e as três
estrelas aparecem **uma de cada vez**, com salto: conquistada entra cheia e dourada, não
conquistada entra menor e apagada. A sequência é disparada por resultado novo, então revanche e
volta ao mesmo resultado não repetem a animação à toa.

**Level up deixou de ser sem graça.** Melhorar uma torre agora dispara, na célula: dois anéis
dourados em sequência, 16 faíscas, o novo estado subindo em texto grande, um clarão que cresce e
some por cima do sprite e um tremor curto do tabuleiro — mais o aviso "Dardo → L1!" no meio da
tela e uma chave de som própria (`ui_upgrade`, ainda sem arquivo).

**Interruptor novo:** `DevFlags.alwaysShowIntro` mostra o guia da primeira fase toda vez, sem
apagar o perfil. Fica **false** em produção; serviu para conferir o guia nesta sessão.

**Verificado no Studio (Play real):** menu com "Jogar Campanha" e sem tutorial; lista das 12 fases
com estrelas, objetivos escritos e rolagem até o fim; fase 1 com 3 ondas, sucata 650, objetivos no
HUD e **sem cronômetro**; o guia percorreu os três passos (escolher o Dardo → posicionar na célula
marcada → chamar a horda) e sumiu quando a onda saiu; melhoria do Dardo mostrou o efeito de level
up e o aviso. Não vi ao vivo a entrada das estrelas no resultado — para isso é preciso terminar as
três ondas da fase.

### Tela de campanha na direção da maquete (2026-09-19, madrugada)

A lista de fases foi refeita seguindo a referência: cartões largos em três colunas, com a arte do
mapa no topo (cantos arredondados e **etiqueta do cenário** no canto — folha, floco ou lua conforme
o mapa), o nome da fase, três estrelas grandes com contorno e um bloco claro com os dois objetivos,
cada um com a sua estrelinha acesa quando já foi cumprido. O cartão fica com contorno dourado
quando a fase tem as três estrelas **ou** quando é a próxima a jogar.

No cabeçalho entrou o painel de coleção: estrela grande, "X/36" e a frase que explica para que as
estrelas servem — o mesmo papel do painel da maquete.

**Verificado no Studio (Play real):** a tela abre com as 12 fases em três colunas, rola até o fim,
mostra 3/36 estrelas e destaca a fase 1 concluída.

### Resultado que empurra para a próxima fase (2026-09-20)

**Estrelas maiores.** No cartão de resultado as três estrelas passaram de 64 para 96 px (fonte 86,
contorno próprio) e a fileira ganhou altura e respiro. A entrada continua uma a uma, com mola.

**"Próxima fase" no lugar de "Tentar novamente".** O botão da direita agora olha o resultado: com
vitória e fase seguinte disponível ele vira **Próxima fase**, com o nome dela no subtítulo, e
chama `GameFlow.goToLevel` — a fase seguinte já entra selecionada, sem passar pela lista. Se a
fase vencida era a última, o botão volta para a campanha; em derrota, continua sendo a revanche.

**Dois defeitos corrigidos:**

- *As estrelas sumiam do menu.* O quadro de resultado traz o perfil já com a recompensa aplicada,
  mas o cliente ignorava esse campo e seguia com o perfil antigo até o próximo login.
  `MatchController` passou a aplicar `payload.profile` ao receber o resultado (o contador da
  campanha foi de 3/36 para 6/36 ao vivo).
- *"Ação indisponível agora" ao abrir outra fase.* Duas causas somadas: o servidor recusava o
  `StartMatch` de quem ainda constava na partida anterior, e o cliente guardava o comando pendente
  para sempre, bloqueando o envio seguinte. Agora `PartyService` solta o jogador da partida antiga
  (`MatchService.releasePlayer`) antes de validar, e o comando pendente do cliente expira em 12 s.
  O quadro `left` atrasado da partida anterior também deixou de derrubar a que acabou de começar.

**Lição de teste:** a janela do Studio usada nos testes não estava conectada ao Rojo — toda a
verificação anterior rodou em código velho. Antes de investigar qualquer defeito, confirmar
**Plugins → Rojo → Connect**.

**Verificado no Studio (Play real):** fase 1 vencida com 3 ondas e 3 torres — o resultado mostrou
"Farol protegido!", as estrelas grandes entrando uma a uma (duas douradas, a de "sem levar dano"
apagada), "Recompensa 120 botões · Recompensa salva" e o botão **Próxima fase · Fase 2 · Jardim de
Papel**, que abriu a fase 2 direto (5 ondas, 650 sucatas, objetivo "Usar só Dardo · Pipoca").
Sequência campanha → fase → Sair → menu → campanha → outra fase sem nenhum aviso de recusa.

**Limpeza:** saíram os dois `print("[diag] …")` do `GameFlow`. A telemetria `start_refused` do
`PartyService` fica: é registro de recusa, não depuração.

### Fichas no canto inferior direito e console de teste (2026-09-20)

**As fichas mudaram de canto.** Farol, onda, sucata e o limite de torres saíram do canto superior
esquerdo — onde cobriam a entrada do caminho e o desenho do cenário — e foram para o **canto
inferior direito**, em versão compacta (`Kit.chip` com `compact`). Compactas de propósito: o botão
de onda continua no centro do rodapé e a fileira não pode alcançá-lo. O topo esquerdo agora está
vazio, e é justamente ali que o console desenha a linha de comando.

**Console em jogo (Cmdr 1.12.0, tecla F2).** Entrou como dependência de **servidor**
(`ServerPackages`), então a biblioteca não é replicada: o cliente só recebe a interface que o
próprio Cmdr publica (`ReplicatedStorage.CmdrClient`) e as definições dos comandos. Ligado por
`DevFlags.testConsole`; quem pode usar é a mesma regra do `DevCommand` (Studio ou `DEV_ALLOWLIST`),
aplicada no gancho `BeforeRun` — sem esse gancho o Cmdr recusaria tudo por segurança.

Quatro comandos, com nome em inglês (convenção de console) e recados em português:

| Comando | O que faz |
| --- | --- |
| `setCoins <amount>` | define a sucata do jogador na partida |
| `setHealth <health>` | define a vida do Farol; zero derruba no passo seguinte |
| `forceWin [stars]` | encerra como vitória com 0 a 3 estrelas (padrão 3) |
| `forceLoss` | encerra como derrota |

Nada disso escreve no estado da partida por fora: cada comando chama uma função `cheat*` do
`MatchService`, que valida permissão e estado. O fim forçado passa pelo novo
`Simulation.devFinish`, que chama o mesmo `finishMatch` do fim normal e só troca as estrelas — o
laço do serviço continua sendo quem paga, salva e manda a tela de resultado. Das embutidas do
Cmdr só o `help` foi registrado: as outras pressupõem avatar, e aqui não existe avatar.

**Verificado no Studio (Play real):** as fichas aparecem no canto inferior direito sem tocar no
botão de onda; F2 abre o console; `setCoins 9999` levou a ficha para 9.999; `setHealth 42` levou o
Farol para 42/100; `forceWin` (sem valor) deu três estrelas e `forceWin 1` deu uma, ambas com
"Recompensa salva" e o botão "Próxima fase"; `forceLoss` fechou com "O farol apagou" e nenhuma
estrela. Testes: 179 aprovados (dois novos cobrem `devFinish`).

### Pulso no Farol e régua de layout por modo (2026-09-20)

**O Pulso de Luz virou gesto.** O botão saiu do rodapé. Quando a recarga termina, o próprio Farol
acende — halo dourado que respira e o aviso "Segure no Farol" — e o jogador **segura 1,5 s** em
cima dele, com uma barra enchendo acima do sprite. Soltar antes cancela; arrastar vira
deslocamento de câmera e cancela também (a mesma regra de qualquer arrasto). O toque curto que
vem depois de um disparo não constrói nem seleciona.

A leitura do gesto entrou no `InputController` (`onHoldStart`/`onHoldEnd`, que também é cancelado
por pinça, botão direito e ao desligar a entrada), a contagem no `BoardPresenter` e o desenho no
`BoardRenderer` (halo, barra, preenchimento e aviso, todos respeitando `reducedMotion`). O
`GameFlow.pulse` deixou de abrir modal: a confirmação agora é o próprio 1,5 s segurando.

**Responsividade.** O rodapé não cabia: numa tela de 1280 de referência a fileira de fichas
encostava no botão de onda — foi isso que apareceu na janela do responsável. Três mudanças:

- as fichas viraram um **bloco de duas linhas** no canto inferior direito (era uma fileira só);
- o rodapé ficou com **um botão** (o Pulso saiu), liberando o centro;
- o HUD ganhou uma tabela de **métricas por modo** (`Metrics`, escolhida na montagem): no compacto
  as fichas sobem para o topo à esquerda, a doca de torres vira **grade 2x2** ancorada no rodapé,
  os botões do topo ficam com ícone e número, e o preço sai do cartão (ele já está na barra de
  construção).

As telas de menu não ganharam layout compacto: elas **encolhem para caber** (`Responsive.menuScale`
aplicado pelo `App` nas camadas de menu e modal). Era o que faltava para o celular — antes, no
emulador, metade do menu e da campanha ficava fora da tela.

**Verificado no Studio (Play real):**

- *Computador (≈1280x720 de referência):* fichas em bloco 2x2 à direita sem encostar no "Iniciar
  Onda"; Farol aceso com o aviso durante a onda; barra desenhada acima do sprite (conferida com
  carga fixa); pulso disparado com o anel azul e os números de dano; toque curto não dispara.
- *Celular emulado (Samsung Galaxy A16, 780x360):* menu inteiro dentro da tela (antes o "Jogar
  Campanha" saía pela borda), campanha com os cartões e o painel de coleção visíveis, e o combate
  com fichas no topo, doca 2x2 e objetivos sem nada cortado.

**O que não deu para testar sozinho:** o gesto de 1,5 s contínuo — as ferramentas de automação
daqui não seguram o botão do mouse. O disparo foi verificado reduzindo o limiar e pelo caminho
completo (servidor + efeito); falta o responsável sentir o tempo e dizer se 1,5 s é muito ou pouco.
