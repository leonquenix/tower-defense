# Matriz de cobertura da interface

ARQUIVO GERADO por `tools/check_ui_coverage.py` a partir de `docs/ui_coverage.json` e do
catálogo `UI_Quintal_em_Guarda_v1/dados/telas.json`. Não edite à mão: altere o JSON e rode a
ferramenta.

**49 de 49 pranchas implementadas** · **19 exercitadas numa sessão de Play do Studio nesta entrega**.

As colunas separam propositalmente o que está montado do que foi visto rodando. Uma prancha
existente nunca comprova que um botão funciona; por isso a coluna *Studio* só marca o que foi
percorrido de verdade, e a *Evidência* diz o que aconteceu.

Nenhuma prancha de biblioteca (31, 37–46, 49) virou menu no jogo: elas descrevem componentes
compartilhados. Upload dos 24 ícones e publicação continuam pendentes — ver
`docs/MANUAL_ACTIONS.md`.

| Prancha | Tela ou estado | Tipo | Onde vive | Estados | Implementado | Studio | Evidência |
|---|---|---|---|---|---|---|---|
| 01_entrada | Entrada e perfil | tela | `client/UI/Screens/Boot.luau` | carregando, demora 10 s, perfil indisponível, tentativa pendente | sim | sim | Play no Studio sem acesso a DataStore: a variante de perfil indisponível apareceu com Tentar novamente e Treino. |
| 02_inicio | Menu inicial | tela | `client/UI/Screens/MainMenu.luau` | perfil pronto, primeiro acesso (tutorial), perfil indisponível, loja oculta | sim | sim | Menu renderizado com Jogar dourado único, saldo separado e loja ausente (feature flag desligada). |
| 03_mapas | Escolher mapa | tela | `client/UI/Screens/Maps.luau` | seleção, mapa bloqueado, desafio bloqueado, integrante sem desbloqueio | sim | pendente | Estados de bloqueio vêm de profile.mapUnlocks; falta exercitar com perfil persistido. |
| 04_salas | Salas e convites | tela | `client/UI/Screens/Rooms.luau` | carregando, lista, vazia, sala cheia, já em grupo, erro | sim | pendente | Disputa da última vaga exige dois clientes; ver docs/MANUAL_ACTIONS.md. |
| 05_grupo | Grupo e prontidão | tela | `client/UI/Screens/PartyScreen.luau` | líder, membro, prontidão, vaga livre, mapa bloqueado para um membro | sim | pendente | Requer dois clientes. |
| 06_colecao | Coleção e equipe | tela | `client/UI/Screens/CollectionScreen.luau` | possuída, equipada, bloqueada, equipe cheia, salvando, leitura em partida | sim | sim | Seis cartas com custo de desbloqueio e de construção, quatro vagas e Salvar com motivo. |
| 07_torre | Detalhe e desbloqueio | tela | `client/UI/Screens/TowerDetail.luau` | possuída, bloqueada, saldo insuficiente, já equipada | sim | sim | Lupa mostrou 240 botões para desbloquear e 500 sucatas para construir, com Faltam 240 botões. |
| 08_cosmeticos | Domínio e aparência | tela | `client/UI/Screens/Cosmetics.luau` | marco alcançado, marco pendente, equipado, arte pendente | sim | pendente | Concessão por marco exige um resultado salvo; ver pendências. |
| 09_loja | Loja opcional | tela | `client/UI/Screens/ShopScreen.luau` | consultando, indisponível, disponível, aguardando Roblox, cancelado, possuído | sim | pendente | Sem passe criado, o servidor responde enabled=false; os demais estados dependem de um passe real. |
| 10_opcoes | Configurações | tela | `client/UI/Screens/SettingsScreen.luau` | sliders, toggles, idioma, falha ao salvar, aberta em partida | sim | sim | Aberta durante a onda 1 do tutorial: o combate seguiu e a troca PT-BR/EN reescreveu moldura, tela e HUD. |
| 11_carregamento | Carregamento de partida | tela | `client/UI/Screens/MatchLoading.luau` | progresso real, imagem falhou, demora 10 s, voltar aos 20 s | sim | sim | Exibida entre StartMatch e o primeiro snapshot; progresso contou os assets essenciais resolvidos. |
| 12_preparacao | Preparação e intervalo | tela | `client/View/Hud.luau` | preparação, intervalo, pronto, contagem por simTime | sim | sim | Faixa superior mostrou Farol 100/100, Onda 00/03 e Pronto; a onda começou pelo servidor. |
| 13_combate | Combate principal | tela | `client/View/Hud.luau`<br>`client/View/HudPanels.luau` | onda ativa, grupo, opções, limites | sim | sim | Onda 01/03 com HUD completo; Opções abriu com grupo em leitura, Configurações e Sair. |
| 14_posicionar | Posicionar uma torre | tela | `client/Controllers/PlayController.luau`<br>`client/View/Hud.luau` | escolhendo célula, válida, pendente, construída, rejeitada | sim | sim | Construir Dardo debitou 250 de 1.200 e o contador foi para 1/18 só após o ACK. |
| 15_posicao_invalida | Posicionamento inválido | tela | `client/Controllers/PlayController.luau`<br>`client/View/BoardRenderer.luau` | caminho, bloqueada, ocupada, limite, sem saldo | sim | pendente | Motivos vêm de evaluateCell; falta percorrer as quatro bordas com zoom e pan. |
| 16_torre_selecionada | Torre selecionada | tela | `client/View/Hud.luau` | própria, aliada (leitura), L3 máxima, comando pendente | sim | sim | Dardo L0 abriu com comparação inline e as ações fixas na base do painel. |
| 17_especializacao | Especialização | tela | `client/View/Hud.luau`<br>`client/UI/Modal.luau` | comparação, confirmação, pendente, saldo insuficiente | sim | pendente | Exige chegar a L2 numa partida completa. |
| 18_venda | Confirmação de venda | tela | `client/View/Hud.luau`<br>`client/UI/Modal.luau` | confirmação, pendente, sucesso, torre já removida | sim | sim | Dardo L0 devolveu 175 sucatas; Cancelar era o foco inicial e a seleção foi limpa no sucesso. |
| 19_chefe | Chefe e aviso de habilidade | tela | `client/View/HudPanels.luau` | vivo, aviso com contagem, efeito ativo | sim | pendente | Exige chegar à onda de chefe ou gerar no treino. |
| 20_pulso | Pulso compartilhado | tela | `client/Controllers/PlayController.luau`<br>`client/UI/Modal.luau` | disponível, confirmação, pendente, recarga, usado por aliado | sim | pendente | Confirmação simultânea exige dois clientes. |
| 21_tutorial | Tutorial contextual | tela | `client/View/Hud.luau`<br>`client/Controllers/PlayController.luau` | cinco passos, repetição, pular | sim | sim | Passos 1 a 3 percorridos: colocar Dardo, iniciar onda e a instrução do Circuito com Goma. |
| 22_treino | Treino | tela | `client/View/Hud.luau` | seletor de inimigo, gerar 1/10, limpar com confirmação, indicadores | sim | pendente | Falta uma sessão de treino completa com chefes. |
| 23_vitoria | Vitória e revanche | tela | `client/UI/Screens/ResultScreen.luau` | salvo, revanche, destaques | sim | pendente | Exige vencer uma partida com perfil persistido. |
| 24_derrota | Derrota | tela | `client/UI/Screens/ResultScreen.luau` | ondas concluídas, dica, revanche | sim | pendente | Exige perder uma partida. |
| 25_recompensa_pendente | Recompensa pendente | tela | `client/UI/Screens/ResultScreen.luau` | pendente, não registrado, confirmado, espera progressiva | sim | pendente | Exige falha de persistência controlada. |
| 26_conexao | Falhas de perfil e conexão | tela | `client/UI/Screens/Boot.luau`<br>`client/View/HudPanels.luau` | perfil indisponível, sinal instável, reconciliando | sim | sim | Perfil indisponível exercitado; os estados de rede têm cobertura em tests/specs/08_ui_state.spec.luau. |
| 27_sair | Sair da partida | tela | `client/Controllers/PlayController.luau`<br>`client/UI/Modal.luau` | confirmação, pendente | sim | pendente | Modal montado pelo mesmo caminho da venda, que foi verificado. |
| 28_mobile_combate | Combate no celular | tela | `client/View/Hud.luau` | colunas laterais, slots inferiores, alvos de 44 px | sim | pendente | Exige emulação de dispositivo em 844x390. |
| 29_mobile_posicionar | Construção no celular | tela | `client/View/BoardTransform.luau`<br>`client/Controllers/PlayController.luau` | região ampliada, pan com dois dedos, visão completa | sim | pendente | Exige toque real. |
| 30_orientacao | Orientação vertical | tela | `client/UI/Screens/Orientation.luau` | fora de partida, em partida | sim | pendente | Exige emulação em 390x844. |
| 31_estados | Biblioteca de estados | biblioteca | `client/UI/Components.luau`<br>`client/UI/Toasts.luau`<br>`client/View/HudPanels.luau` | botões, toasts, tooltip, dropdown de alvo, popover de velocidade | sim | sim | Componentes exercitados pelas telas; não existe página de biblioteca no jogo publicado. |
| 32_desbloqueio | Confirmar desbloqueio | tela | `client/UI/Screens/TowerDetail.luau`<br>`client/UI/Modal.luau` | confirmação, pendente, sem saldo, já possuída | sim | pendente | Exige saldo de botões num perfil persistido. |
| 33_convites | Convidar jogadores | tela | `client/UI/Screens/Invites.luau`<br>`client/UI/InviteCards.luau`<br>`server/Services/PartyService.luau` | convidar, enviado, cooldown, aceito, recusado, expirado, grupo cheio | sim | pendente | Token, expiração de 30 s e cooldown de 5 s cobertos em tests/specs/08_ui_state.spec.luau; o fluxo real exige dois clientes. |
| 34_inimigo | Inspecionar inimigo | tela | `client/View/Hud.luau` | vida, resistências, habilidade, morte fecha a ficha | sim | pendente | Exige inimigo vivo no tabuleiro. |
| 35_mobile_menu | Menu no celular | tela | `client/UI/Screens/MainMenu.luau` | compacto, texto ampliado sem arte | sim | pendente | Exige emulação em 844x390. |
| 36_mobile_detalhe | Detalhe no celular | tela | `client/View/Hud.luau` | folha inferior, recolher | sim | pendente | Exige emulação em 844x390. |
| 37_botoes | Todos os estados de botão | biblioteca | `client/UI/Components.luau` | normal, foco, pressionado, indisponível, pendente, sucesso, erro, selecionado | sim | sim | Um único componente cobre os oito estados; foco, pressionado, indisponível e sucesso vistos no Play. |
| 38_confirmacoes | Confirmações de ações | biblioteca | `client/UI/Modal.luau` | venda, especialização, substituição de slot, limpeza do treino, tutorial repetido | sim | sim | Família única de modais; foco inicial no cancelamento verificado na venda. |
| 39_erros | Erros e bloqueios | biblioteca | `client/UI/Toasts.luau`<br>`client/UI/Components.luau` | inline, toast, motivo no botão, código desconhecido | sim | pendente | Cobertura de códigos em tests/specs/08_ui_state.spec.luau. |
| 40_grupo_estados | Convites e votação | biblioteca | `client/UI/InviteCards.luau`<br>`client/View/HudPanels.luau` | convite, enviado, expirado, votação 2x, voltar a 1x | sim | pendente | Exige dois clientes. |
| 41_boss_estados | Avisos dos três chefes | biblioteca | `client/View/HudPanels.luau` | Aspirador, Rei Ferrugem, Breu, efeito ativo | sim | pendente | Uma BossBar por chefe ativo; nunca três painéis comparativos. |
| 42_recuperacao | Carregamento e recuperação | biblioteca | `client/UI/Screens/Boot.luau`<br>`client/UI/Screens/MatchLoading.luau`<br>`client/View/HudPanels.luau` | imagem faltando, recarregar, perfil bloqueado, resultado não registrado | sim | sim | Perfil bloqueado por falta de acesso a DataStore levou ao caminho de treino, sem salvar defaults. |
| 43_colecao_estados | Estados da coleção | biblioteca | `client/UI/Screens/CollectionScreen.luau` | vaga livre, compra salva, partida ativa, cosmético bloqueado | sim | sim | Vaga livre sem alerta e equipe em leitura durante a partida. |
| 44_resultados_estados | Recompensas e conquistas | biblioteca | `client/UI/Screens/ResultScreen.luau` | um destaque por vez, fila finita, revanche aguardando | sim | pendente | Exige resultados reais. |
| 45_menus_contextuais | Menus e feedbacks de combate | biblioteca | `client/View/HudPanels.luau`<br>`client/UI/Toasts.luau` | alvo, Circuito, recarga do Pulso, toast local | sim | pendente | Os quatro alvos vêm de Catalog.TARGET_MODES, sem tradução alterando o algoritmo. |
| 46_loja_estados | Estados da loja | biblioteca | `client/UI/Screens/ShopScreen.luau` | consulta, falha, cancelado, possuído | sim | pendente | Exige passe real. |
| 47_mobile_colecao | Coleção no celular | tela | `client/UI/Screens/CollectionScreen.luau` | paginada, equipe fixa, salvar fixo | sim | pendente | Exige emulação em 844x390. |
| 48_mobile_mapas | Mapas no celular | tela | `client/UI/Screens/Maps.luau` | um cartão por vez, indicador 1 de 3 | sim | pendente | Exige emulação em 844x390. |
| 49_icones | Ícones funcionais | biblioteca | `shared/Config/UiIcons.luau`<br>`client/UI/Components.luau` | 24 ícones, reserva por glifo, rótulo acessível | sim | sim | Sem upload, os 24 ícones desenham o glifo de reserva e mantêm o rótulo; nenhum rbxassetid inventado. |

## O que ainda não foi exercitado

As linhas com *Studio: pendente* precisam de condições que uma sessão local de Play não cria:

- dois clientes conectados (salas, grupo, convites, votação de 2x, Pulso simultâneo);
- perfil persistido (desbloqueio por botões, domínio, vitória, derrota, recompensa pendente);
- passe criado no Creator Hub (estados da loja);
- emulação de dispositivo em 844×390, 896×414, 1024×768 e 390×844 (layouts compactos e vertical);
- uma partida completa até a onda de chefe (BossBar, especialização, inspeção de inimigo).

O passo a passo de cada um está em `docs/MANUAL_ACTIONS.md`.
