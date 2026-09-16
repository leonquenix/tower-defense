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
