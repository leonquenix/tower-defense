# MANUAL_ACTIONS — ações externas necessárias

Lista objetiva do que depende da conta Roblox, de produção artística ou de decisão do responsável. Nada abaixo foi executado automaticamente.

## Antes de qualquer coisa (depois do revamp de 2026-09-19)

A. **Instalar as dependências**: `.toolchain/bin/wally install`. Sem isso, `Packages/` e
   `ServerPackages/` não existem e nem o Studio nem os testes carregam (Fusion, Charm, ByteNet,
   Trove e ProfileStore vêm daí). As pastas são geradas e ficam fora do git; `wally.lock` é quem
   garante as mesmas versões para todo mundo.
B. **Conferir a preferência de movimento reduzido** ao avaliar a apresentação: nesta máquina
   `GuiService.ReducedMotionEnabled` está **ligado**, e o jogo respeita isso desligando tremor,
   partículas e deslocamentos. Para ver o acabamento completo, desligue "Reduced Motion" nas
   configurações do Roblox/Studio (ou em Configurações → Conforto, dentro do jogo).
C. **Verificação visual das telas** continua pendente: a sessão de Play desta entrega rodou com a
   janela sem renderizar (viewport 1×1), então a conferência foi por árvore de Gui e console, sem
   captura de tela. Repetir com a janela visível e preencher `docs/ui_coverage.json`.

## Publicação e conta

0. **Salvar o place** depois de sincronizar pelo Rojo: File → Save to Roblox. *Atualizado em 2026-09-18*: o place aberto é `Tower Defense`, PlaceId `85307223725202`, universo `10766698519`, pertencente a um **grupo** (CreatorId 926034474). Ele nasceu como cópia do place do Board Games Club; o conteúdo do outro jogo foi removido nesta sessão e a limpeza precisa ser salva.
1. **Ativar Game Settings → Security → Enable Studio Access to API Services** se quiser testar DataStore dentro do Studio (os nomes de store usam sufixo `_studio` nesse caso). Garantir que o universo de teste seja diferente do de produção, ou aceitar o namespace `_studio`.
2. **Assets de imagem**: os 40 PNGs originais, os 11 placeholders antigos e os 11 inimigos/chefes foram enviados pela **conta pessoal** logada no Studio (IDs em `assets/export/upload_log.json`, `runtime_asset_registry.json` e `Config/Assets.luau`). Verificado em 2026-09-18 que eles carregam no place do grupo. Se a experiência for movida para outro grupo, os assets precisam ser reenviados ou o grupo precisa de permissão de uso; repita `tools/update_asset_registry.py` com o novo `upload_log.json`.
3. **Moderação**: o carregamento dos 58 + 11 assets antigos e dos 11 novos de inimigos/chefes foi verificado no Studio (os novos por `IsLoaded` nos sprites em partida). A moderação assíncrona do Roblox pode remover um asset depois; conferir no Creator Hub → Development Items → Images antes do lançamento.
4. **Configuração de idade/conteúdo, descrição, ícone e thumbnails** no Creator Hub. Ícone e thumbnails ainda não foram produzidos (direção de arte, seção Divulgação).

## Loja (mantida desativada)

5. Criar o **passe Pacote Fundador** no Creator Hub (preço de teste proposto: 149 Robux). Preencher `founderPassId` em `Pacote_Claude_Code/dados/balanceamento_v1.json` (`shop.founderPassId`) e rodar `tools/import_balance.py`. Só então definir `shop.enabledByDefault = true`. Sem ID válido e preço consultado, a loja fica oculta e nada é concedido.
6. Produzir as **seis skins Fundador, estandarte e título** (arte não produzida). Os IDs de cosmético já existem em `Config/Products.luau`; a apresentação usa a arte padrão até haver skins.

## Arte e áudio pendentes

7. **240 quadros de animação das torres** (4 repouso + 4 ataque/apoio × 5 estados × 6 torres) e os seis atlas 1024×1024 conforme `animation_plan.json`. Hoje o jogo usa movimentos procedurais sobre as poses estáticas (`TowerAnimator.luau`). Ao produzir os atlas, mudar `renderMode` de `single_static` para `atlas` em `runtime_asset_registry.json` e implementar o recorte (`ImageRectOffset`/`ImageRectSize`) em `BoardRenderer`.
8. **Quadros desenhados de inimigos (8 × 12) e chefes (3 × 16)**. *Atualizado em 2026-09-18*: as 11 poses estáticas de `Assets_Inimigos_Bosses_v1/` foram exportadas, enviadas (IDs reais em `assets/export/upload_log.json`) e integradas; os placeholders procedurais deixaram de ser usados. O movimento é procedural (`EnemyAnimator.luau`) sobre uma pose por tipo. Continuam pendentes os 96 quadros de inimigos e 48 de chefes para animação desenhada; ao produzi-los, trocar `renderMode` no registro e implementar o recorte de atlas. Também dependem de arte nova: abrir a casca do Casulo, mover a mangueira do Aspirador e fechar as placas do Rei Ferrugem.
9. **Áudio**: nenhum som ou música foi incluído. `AudioController.luau` tem 27 chaves com ID vazio (4 loops de música + 23 efeitos). Registrar origem e direito de uso de cada áudio no manifesto antes de preencher.
10. **Ícones de interface (24), retratos com área segura e efeitos em atlas**: a interface usa formas nativas, glifos de texto e os retratos 256 px derivados das poses.
11. Revisar os **apoios (pés)** dos sprites em aparelhos reais: a normalização usa escala uniforme por família e apoio em (0,5; 0,82); `assets/export/review_towers.png` mostra os 30 estados alinhados. Maestro L3A ficou visivelmente menor que os demais estados (o original tem conteúdo menor); avaliar redesenho ou escala específica.
12. Revisar os **apoios sugeridos dos 11 inimigos e chefes**: o manifesto marca `anchorRequiresReview` e o export usou a âncora sugerida pelo autor (Corrisco 0,66 por causa do rastro desenhado; Névoa com apoio virtual sob o corpo flutuante). Conferir em `assets/export/review_enemies_light.png`, `review_enemies_dark.png` e no tabuleiro; se algum personagem parecer flutuar ou afundar, ajustar `sourceAnchorSuggested` no manifesto e rodar `tools/export_enemy_assets.py` de novo.
13. Verificar **movimento reduzido nos inimigos** pela tela de Configurações (a verificação desta sessão usou o remote `SaveSettings` e não mediu o que pretendia — ver TEST_REPORT 7.3). Esperado: ciclos decorativos param; posição lógica, barras e avisos continuam.

## Ícones da interface (24 arquivos) — **enviados em 2026-09-18**

Os 24 ícones funcionais foram exportados em 128×128 com fundo transparente para `assets/export/ui/`
a partir de `UI_Quintal_em_Guarda_v1/icones/` (originais preservados, nada recortado) e **enviados ao
Asset Server pela conta logada no Studio**, com os IDs reais em `assets/export/ui_upload_log.json`,
`ui_asset_registry.json` e `Config/UiIcons.luau`. Verificado numa sessão de Play: **24/24 com
`IsLoaded = true`**.

Os `.svg` não foram enviados: são fonte de manutenção fora do Studio.

O código continua tolerando a ausência de qualquer ícone — sem `image`, o cliente desenha o glifo de
reserva e mantém o rótulo textual, então nenhum ícone é a única explicação de nada.

**O que ainda depende de você:**

1. **Moderação**: o Roblox modera imagens de forma assíncrona e pode remover um asset depois.
   Conferir em Creator Hub → Development Items → Images antes do lançamento. `checkedInStudio`
   segue `false` no registro até essa conferência.
2. Se a experiência mudar de grupo, os assets precisam ser reenviados ou o grupo precisa de
   permissão de uso; repetir `tools/export_ui_icons.py` com o novo `ui_upload_log.json`.

Para reenviar (outra conta, outro grupo ou arte revisada), o caminho é o mesmo: anotar cada ID em
`assets/export/ui_upload_log.json` no formato `{"uploads": {"ui/ui_back_128.png": 123456789, ...}}`
e rodar `python3 tools/export_ui_icons.py`, que reescreve `ui_asset_registry.json` e regenera
`src/shared/Config/UiIcons.luau`. A ferramenta nunca inventa ID: sem log, volta para `image = nil`.

Tabela de arquivo → chave → ID enviado:

| Fonte (preservada) | Export enviado | Chave em `ui_upload_log.json` | Chave do asset | ID no Roblox | Reserva sem imagem |
|---|---|---|---|---|---|
| `UI_Quintal_em_Guarda_v1/icones/ui_back_v001.png` | `assets/export/ui/ui_back_128.png` | `ui/ui_back_128.png` | `ui_back` | `88491749815381` | `‹` |
| `UI_Quintal_em_Guarda_v1/icones/ui_base_v001.png` | `assets/export/ui/ui_base_128.png` | `ui/ui_base_128.png` | `ui_base` | `111920601725235` | `⌂` |
| `UI_Quintal_em_Guarda_v1/icones/ui_buttons_v001.png` | `assets/export/ui/ui_buttons_128.png` | `ui/ui_buttons_128.png` | `ui_buttons` | `101246403255603` | `◉` |
| `UI_Quintal_em_Guarda_v1/icones/ui_check_v001.png` | `assets/export/ui/ui_check_128.png` | `ui/ui_check_128.png` | `ui_check` | `104059787042270` | `✓` |
| `UI_Quintal_em_Guarda_v1/icones/ui_close_v001.png` | `assets/export/ui/ui_close_128.png` | `ui/ui_close_128.png` | `ui_close` | `118214159540710` | `✕` |
| `UI_Quintal_em_Guarda_v1/icones/ui_cooldown_v001.png` | `assets/export/ui/ui_cooldown_128.png` | `ui/ui_cooldown_128.png` | `ui_cooldown` | `82684451501253` | `◷` |
| `UI_Quintal_em_Guarda_v1/icones/ui_energy_v001.png` | `assets/export/ui/ui_energy_128.png` | `ui/ui_energy_128.png` | `ui_energy` | `131805218762416` | `◈` |
| `UI_Quintal_em_Guarda_v1/icones/ui_error_v001.png` | `assets/export/ui/ui_error_128.png` | `ui/ui_error_128.png` | `ui_error` | `104020383943624` | `!` |
| `UI_Quintal_em_Guarda_v1/icones/ui_group_v001.png` | `assets/export/ui/ui_group_128.png` | `ui/ui_group_128.png` | `ui_group` | `101185371000335` | `◍` |
| `UI_Quintal_em_Guarda_v1/icones/ui_heal_v001.png` | `assets/export/ui/ui_heal_128.png` | `ui/ui_heal_128.png` | `ui_heal` | `83533878039427` | `+` |
| `UI_Quintal_em_Guarda_v1/icones/ui_lock_v001.png` | `assets/export/ui/ui_lock_128.png` | `ui/ui_lock_128.png` | `ui_lock` | `104319975182301` | `🔒` |
| `UI_Quintal_em_Guarda_v1/icones/ui_minus_v001.png` | `assets/export/ui/ui_minus_128.png` | `ui/ui_minus_128.png` | `ui_minus` | `139587755350316` | `−` |
| `UI_Quintal_em_Guarda_v1/icones/ui_physical_v001.png` | `assets/export/ui/ui_physical_128.png` | `ui/ui_physical_128.png` | `ui_physical` | `110488708842551` | `⛨` |
| `UI_Quintal_em_Guarda_v1/icones/ui_play_v001.png` | `assets/export/ui/ui_play_128.png` | `ui/ui_play_128.png` | `ui_play` | `76972323672777` | `▶` |
| `UI_Quintal_em_Guarda_v1/icones/ui_plus_v001.png` | `assets/export/ui/ui_plus_128.png` | `ui/ui_plus_128.png` | `ui_plus` | `112814833650940` | `+` |
| `UI_Quintal_em_Guarda_v1/icones/ui_pulse_v001.png` | `assets/export/ui/ui_pulse_128.png` | `ui/ui_pulse_128.png` | `ui_pulse` | `77488608610057` | `✷` |
| `UI_Quintal_em_Guarda_v1/icones/ui_scrap_v001.png` | `assets/export/ui/ui_scrap_128.png` | `ui/ui_scrap_128.png` | `ui_scrap` | `93292805807152` | `✦` |
| `UI_Quintal_em_Guarda_v1/icones/ui_sell_v001.png` | `assets/export/ui/ui_sell_128.png` | `ui/ui_sell_128.png` | `ui_sell` | `101007725063284` | `⌫` |
| `UI_Quintal_em_Guarda_v1/icones/ui_settings_v001.png` | `assets/export/ui/ui_settings_128.png` | `ui/ui_settings_128.png` | `ui_settings` | `110525661692700` | `⚙` |
| `UI_Quintal_em_Guarda_v1/icones/ui_speed_v001.png` | `assets/export/ui/ui_speed_128.png` | `ui/ui_speed_128.png` | `ui_speed` | `78000524487354` | `»` |
| `UI_Quintal_em_Guarda_v1/icones/ui_target_v001.png` | `assets/export/ui/ui_target_128.png` | `ui/ui_target_128.png` | `ui_target` | `94414571956685` | `◎` |
| `UI_Quintal_em_Guarda_v1/icones/ui_upgrade_v001.png` | `assets/export/ui/ui_upgrade_128.png` | `ui/ui_upgrade_128.png` | `ui_upgrade` | `125880091131026` | `▲` |
| `UI_Quintal_em_Guarda_v1/icones/ui_volume_v001.png` | `assets/export/ui/ui_volume_128.png` | `ui/ui_volume_128.png` | `ui_volume` | `100558525605931` | `🔊` |
| `UI_Quintal_em_Guarda_v1/icones/ui_wave_v001.png` | `assets/export/ui/ui_wave_128.png` | `ui/ui_wave_128.png` | `ui_wave` | `126556458277057` | `〜` |

`status` já está em `uploaded` para os 24. `checkedInStudio` continua `false`: o carregamento foi
verificado nesta sessão, mas a marcação só deve mudar depois da conferência de moderação no Creator
Hub.

## Testes que exigem pessoas ou dispositivos

14. Teste com **quatro clientes** reais (Studio: Test → Clients and Servers → 4 players) cobrindo compras simultâneas, votação de 2x, desconexão e revanche. Ver `docs/TEST_REPORT.md` para o que já foi executado com um cliente. Com a interface nova, isso também cobre: disputa da última vaga numa sala (04), prontidão e limpeza de prontidão no grupo (05), convite aceito por duas pessoas ao mesmo tempo (33/40), popover de velocidade com unanimidade e retorno a 1x (31/40) e dois clientes confirmando o Pulso no mesmo instante (20).
15. Teste em **celular real** (844×390, 896×414 e tablet 4:3) do fluxo completo, pinça/zoom, ampliação automática de célula, folha de detalhe recolhível e áreas seguras. Repetir a matriz visual do guia: 844×390, 896×414, 1280×720, 1920×1080, tablet 1024×768 e vertical 390×844, cada um em PT-BR e EN, com texto ampliado e movimento reduzido. As linhas *Studio: pendente* de `docs/UI_COVERAGE.md` listam exatamente o que falta.
16. **Latência simulada** de 150–250 ms (Studio → Settings → Network → Incoming Replication Lag).
17. **Carga**: três partidas de quatro e doze partidas solo em um servidor; medir p95 do passo de simulação, memória e tráfego.
18. **Playtest de diversão** com 8 a 12 pessoas e revisão do balanceamento (os números são o catálogo inicial, não validados).

## Decisões pendentes do responsável

19. Autorizar a publicação e o preço do passe.
19b. Decidir se os **cosméticos de domínio** (adesivo aos 30, título aos 100 e aparência aos 250) ganham arte própria. O servidor já concede os IDs ao cruzar cada marco (`ProfileSchema.applyMatchResult`), mas a arte não existe: a tela 08 mostra "Arte final ainda não produzida nesta versão" e mantém o Equipar indisponível em vez de oferecer um produto inexistente.
20. Definir se `DEV_ALLOWLIST` (MatchService) recebe UserIds de QA fora do Studio.
21. Decidir política de telemetria (AnalyticsService está preparado; eventos são enviados só fora do Studio e nunca interrompem o jogo).
