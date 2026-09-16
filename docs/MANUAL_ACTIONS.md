# MANUAL_ACTIONS — ações externas necessárias

Lista objetiva do que depende da conta Roblox, de produção artística ou de decisão do responsável. Nada abaixo foi executado automaticamente.

## Publicação e conta

0. **Salvar o place aberto** (`Place2`, ainda não salvo): File → Save to File / Publish. O código foi sincronizado pelo Rojo no place aberto; `build/QuintalEmGuarda.rbxl` é um build equivalente gerado do repositório.
1. **Publicar a experiência** (File → Publish to Roblox As…). O place aberto (`Place2`, PlaceId 0) não foi publicado por falta de autorização específica. Após publicar:
   - Ativar **Game Settings → Security → Enable Studio Access to API Services** somente se quiser testar DataStore dentro do Studio (os nomes de store usam sufixo `_studio` nesse caso).
   - Garantir que o universo de teste seja diferente do de produção, ou aceitar o namespace `_studio`.
2. **Assets de imagem**: os 40 PNGs e os 11 placeholders foram enviados pela conta logada no Studio (IDs em `assets/export/upload_log.json`, `runtime_asset_registry.json` e `Config/Assets.luau`). Se a experiência for publicada em um grupo, os assets precisam ser reenviados/transferidos para o grupo (ou o grupo precisa de permissão de uso); repita `tools/update_asset_registry.py` com o novo `upload_log.json`.
3. **Moderação**: o carregamento de todos os 58 + 11 assets foi verificado no Studio (`ContentProvider:PreloadAsync` sem falhas). A moderação assíncrona do Roblox pode remover um asset depois; conferir no Creator Hub → Development Items → Images antes do lançamento.
4. **Configuração de idade/conteúdo, descrição, ícone e thumbnails** no Creator Hub. Ícone e thumbnails ainda não foram produzidos (direção de arte, seção Divulgação).

## Loja (mantida desativada)

5. Criar o **passe Pacote Fundador** no Creator Hub (preço de teste proposto: 149 Robux). Preencher `founderPassId` em `Pacote_Claude_Code/dados/balanceamento_v1.json` (`shop.founderPassId`) e rodar `tools/import_balance.py`. Só então definir `shop.enabledByDefault = true`. Sem ID válido e preço consultado, a loja fica oculta e nada é concedido.
6. Produzir as **seis skins Fundador, estandarte e título** (arte não produzida). Os IDs de cosmético já existem em `Config/Products.luau`; a apresentação usa a arte padrão até haver skins.

## Arte e áudio pendentes

7. **240 quadros de animação das torres** (4 repouso + 4 ataque/apoio × 5 estados × 6 torres) e os seis atlas 1024×1024 conforme `animation_plan.json`. Hoje o jogo usa movimentos procedurais sobre as poses estáticas (`TowerAnimator.luau`). Ao produzir os atlas, mudar `renderMode` de `single_static` para `atlas` em `runtime_asset_registry.json` e implementar o recorte (`ImageRectOffset`/`ImageRectSize`) em `BoardRenderer`.
8. **Sprites de inimigos (8 × 12 quadros) e chefes (3 × 16 quadros)**. Os visuais atuais são placeholders procedurais gerados por `tools/generate_placeholder_enemies.py` (`assets/export/placeholders/`), identificados como tal no registro.
9. **Áudio**: nenhum som ou música foi incluído. `AudioController.luau` tem 27 chaves com ID vazio (4 loops de música + 23 efeitos). Registrar origem e direito de uso de cada áudio no manifesto antes de preencher.
10. **Ícones de interface (24), retratos com área segura e efeitos em atlas**: a interface usa formas nativas, glifos de texto e os retratos 256 px derivados das poses.
11. Revisar os **apoios (pés)** dos sprites em aparelhos reais: a normalização usa escala uniforme por família e apoio em (0,5; 0,82); `assets/export/review_towers.png` mostra os 30 estados alinhados. Maestro L3A ficou visivelmente menor que os demais estados (o original tem conteúdo menor); avaliar redesenho ou escala específica.

## Testes que exigem pessoas ou dispositivos

12. Teste com **quatro clientes** reais (Studio: Test → Clients and Servers → 4 players) cobrindo compras simultâneas, votação de 2x, desconexão e revanche. Ver `docs/TEST_REPORT.md` para o que já foi executado com um cliente.
13. Teste em **celular real** (844×390, 896×414 e tablet 4:3) do fluxo completo, pinça/zoom, ampliação automática de célula, folha de detalhe recolhível e áreas seguras.
14. **Latência simulada** de 150–250 ms (Studio → Settings → Network → Incoming Replication Lag).
15. **Carga**: três partidas de quatro e doze partidas solo em um servidor; medir p95 do passo de simulação, memória e tráfego.
16. **Playtest de diversão** com 8 a 12 pessoas e revisão do balanceamento (os números são o catálogo inicial, não validados).

## Decisões pendentes do responsável

17. Autorizar a publicação e o preço do passe.
18. Definir se `DEV_ALLOWLIST` (MatchService) recebe UserIds de QA fora do Studio.
19. Decidir política de telemetria (AnalyticsService está preparado; eventos são enviados só fora do Studio e nunca interrompem o jogo).
