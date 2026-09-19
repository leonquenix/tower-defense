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

