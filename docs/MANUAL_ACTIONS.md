# MANUAL_ACTIONS — ações externas necessárias

Lista objetiva do que depende da conta Roblox, de produção artística ou de decisão do responsável. Nada abaixo foi executado automaticamente.

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

## Testes que exigem pessoas ou dispositivos

14. Teste com **quatro clientes** reais (Studio: Test → Clients and Servers → 4 players) cobrindo compras simultâneas, votação de 2x, desconexão e revanche. Ver `docs/TEST_REPORT.md` para o que já foi executado com um cliente.
15. Teste em **celular real** (844×390, 896×414 e tablet 4:3) do fluxo completo, pinça/zoom, ampliação automática de célula, folha de detalhe recolhível e áreas seguras.
16. **Latência simulada** de 150–250 ms (Studio → Settings → Network → Incoming Replication Lag).
17. **Carga**: três partidas de quatro e doze partidas solo em um servidor; medir p95 do passo de simulação, memória e tráfego.
18. **Playtest de diversão** com 8 a 12 pessoas e revisão do balanceamento (os números são o catálogo inicial, não validados).

## Decisões pendentes do responsável

19. Autorizar a publicação e o preço do passe.
20. Definir se `DEV_ALLOWLIST` (MatchService) recebe UserIds de QA fora do Studio.
21. Decidir política de telemetria (AnalyticsService está preparado; eventos são enviados só fora do Studio e nunca interrompem o jogo).
