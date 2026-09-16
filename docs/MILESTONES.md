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

## M6 Candidato — não iniciado (depende de ações externas)
- Publicação, DataStore em produção, telemetria em produção, desempenho medido em aparelhos nomeados, playtest. Ver `docs/MANUAL_ACTIONS.md`.
