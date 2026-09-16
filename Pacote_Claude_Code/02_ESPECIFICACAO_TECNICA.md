# Especificação técnica para Roblox

## Contrato de implementação

Implementar Quintal em Guarda em Luau com tipagem estrita, Roblox Studio e projeto Rojo. O gameplay deve ser 2D real: dados de posição em duas dimensões e apresentação por objetos de interface. Não substituir por um mundo 3D com câmera distante. A arte conceitual usa volume desenhado para comunicar materiais; não exige modelos 3D.

O JSON em dados/balanceamento_v1.json é a fonte canônica dos parâmetros numéricos. Este documento define a semântica desses campos e os contratos de sistemas. O game design define o comportamento do produto; o documento de arte define sua apresentação. Se surgir conflito, registrar a divergência, corrigir os arquivos afetados e manter uma única versão, sem inventar silenciosamente uma regra.

Congelar versões das ferramentas no repositório no início da implementação. Usar APIs documentadas no Creator Hub e verificar os nomes atuais no ambiente de destino. As taxas de atualização e os limites abaixo são escolhas do projeto, não garantias da plataforma.

## Arquitetura 2D

Usar um ScreenGui de aplicação, com telas de menu e combate, um Frame para o tabuleiro e ImageLabels para cenário, unidades e efeitos. ImageRectOffset e ImageRectSize permitem recortes de atlas. Uma moldura de interface não deve participar do cálculo de combate. [Contêineres de interface](https://create.roblox.com/docs/ui/on-screen-containers) e [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).

Desativar CharacterAutoLoads no servidor e criar explicitamente o ScreenGui em PlayerGui no bootstrap do cliente. Não depender da cópia automática de StarterGui quando o avatar não é carregado. Manter um ambiente 3D vazio e estável atrás da aplicação, câmera Scriptable e painel de fundo opaco. Não criar Humanoids, Parts de inimigos, física, colisão ou PathfindingService para este tabuleiro.

Coordenadas lógicas são centros de células inteiras: x de 0 a 15 e y de 0 a 9. Uma célula ocupa [x-0,5, x+0,5) por [y-0,5, y+0,5). O tabuleiro desenhado mede 960 por 600 unidades visuais. No estado sem zoom, px = left + (x + 0,5) × largura/16; py = top + (y + 0,5) × altura/10. A transformação inversa arredonda pela célula correspondente e rejeita pontos fora dos limites.

BoardTransform centraliza escala, zoom e deslocamento; todo input passa por sua transformação inversa. Ela considera AbsolutePosition, AbsoluteSize e a área segura do ScreenGui. Não somar um inset duas vezes. Testar bordas, mudança de resolução e zoom. A proporção do mapa permanece 16:10. HUD é responsivo e não estica o tabuleiro.

### Apresentação e seleção

Separar a lógica de seleção do sprite. Usar célula, entidade e distância ao ponto lógico para resolver sobreposição; priorizar a torre da célula tocada, depois o inimigo mais próximo dentro do raio de seleção. Tocar em área vazia fecha o detalhe. Entrada com mouse oferece 1 a 4 para escolher torre, Esc para cancelar e U para melhorar quando a escolha é única. Especialização e venda sempre mostram confirmação.

Sprites normalizados se ancoram nos pés, em (0,5; 0,82) de um quadro quadrado. Os PNGs originais entregues têm enquadramentos distintos; validar as âncoras sugeridas no manifesto e normalizar conforme o capítulo 8 antes de aplicar esse padrão. ZIndex do mundo usa faixas: chão 0 a 9, caminho 10 a 19, Circuitos 20 a 29, sombras 30 a 39, entidades 100 + floor(y × 100) com pequeno desempate por tipo, efeitos 1200 a 1299, seleção 1300 a 1399. Menus usam outro DisplayOrder. Atualizar profundidade apenas quando necessário. Não usar uma imagem que contenha texto para substituir um botão acessível.

## Organização dos arquivos

```text
default.project.json
toolchain.toml
src/
  shared/
    Types.luau
    Config/Balance.luau
    Config/Maps.luau
    Config/Assets.luau
    Config/Products.luau
    Config/Localization.luau
    Math/Path.luau
    Math/Grid.luau
    Rules/Combat.luau
    Rules/Circuits.luau
    Rules/Rewards.luau
    Net/Protocol.luau
  server/
    Bootstrap.server.luau
    Services/MatchService.luau
    Services/WaveService.luau
    Services/TowerService.luau
    Services/EnemyService.luau
    Services/EconomyService.luau
    Services/PartyService.luau
    Services/ProfileService.luau
    Services/RewardService.luau
    Services/ShopService.luau
    Services/TelemetryService.luau
  client/
    Bootstrap.client.luau
    Controllers/ScreenController.luau
    Controllers/InputController.luau
    Controllers/MatchController.luau
    Controllers/AudioController.luau
    View/BoardRenderer.luau
    View/BoardTransform.luau
    View/SpritePool.luau
    View/Hud.luau
    View/Collection.luau
    View/Party.luau
    View/Settings.luau
tests/
assets/source/
assets/export/
tools/import_balance.py
docs/SETUP.md
docs/TEST_REPORT.md
docs/MANUAL_ACTIONS.md
```

shared vai para ReplicatedStorage; server para ServerScriptService; client para StarterPlayerScripts. Os nomes são uma estrutura recomendada, e podem mudar mantendo separação de responsabilidades. Dados de perfil, recompensas e validação nunca ficam sob controle do cliente. Regras puras recebem dados e retornam resultados sem depender de interface ou serviços Roblox, permitindo teste determinístico.

Gerar Balance.luau a partir do JSON com validação e saída determinística; o jogo não deve baixar configuração da internet durante a partida. O build falha quando há ID desconhecido, custo inválido, salto de evolução inexistente, caminho diagonal, bloqueio sobre caminho ou frame fora do atlas. Manter relatório de versão e checksum dos dados usados.

## Estado e relógio

MatchState contém matchId único, configVersion, participantes da largada, seed, modo, mapa, dificuldade, fase, waveIndex, baseHP, simTime, speedMultiplier, entidades, carteiras e recompensa. Fases válidas: Lobby, Loading, Preparation, Wave, Intermission, Won, Lost, RewardPending e Closed. Treino e tutorial são modos explícitos, não flags esquecidas em uma partida recompensada.

Um servidor público aceita até 12 pessoas e gerencia instâncias lógicas de partidas isoladas. Cada partida admite de uma a quatro. A implementação inicial não depende de teleportes ou fila global; party e seleção de grupo operam entre jogadores presentes no mesmo servidor. O menu permite solo imediato ou salas com lugares disponíveis. Uma pessoa pertence a apenas uma partida ativa.

Simulação no servidor em passos de 0,05 s, usando acumulador. O multiplicador 2x aumenta o tempo simulado, mantendo o tamanho do passo. Máximo de seis passos por Heartbeat; preservar o restante limitado a 0,5 s e registrar sobrecarga. Se o limite for repetidamente atingido, reduzir 2x para 1x com aviso. Não pular movimento, dano ou pagamentos para recuperar frames.

Todos os cooldowns de jogo usam simTime. Temporizadores de sessão, desconexão, rede e salvamento usam relógio real do servidor. Ao pausar a renderização de um cliente, a partida do grupo continua. O modo solo não ganha pausa global no lançamento.

Ordem por passo: processar comandos validados em ordem de chegada; criar inimigos agendados; mover; resolver chegadas à base; atualizar estados; resolver cura; atualizar chefes; adquirir alvos; aplicar ataques ordenados pelo ID da torre; processar mortes, divisões e pagamentos; verificar fim da onda e da partida. Se a base zerar na etapa de movimento, encerrar em derrota antes de executar novos ataques. Entidades mortas não voltam a atacar nem geram dois pagamentos.

## Movimento e combate

Pré-calcular comprimentos dos segmentos e comprimento acumulado do caminho. Inimigo mantém distância escalar s, velocidade, vida e estados. Posição é a interpolação no segmento correspondente a s. Alvo First é a maior razão s/comprimento total; Last é a menor; Strongest é a maior vida atual; Closest é a menor distância euclidiana à torre. Empates usam menor ID. Todas as torres de dano permitem esses quatro modos; apoio não recebe seletor.

Adquirir um alvo somente se vivo, no mesmo match e dentro de alcance, incluindo igualdade. Acerto é instantâneo na simulação; projéteis desenhados são cosméticos. Assim, o ponto visual de um projétil não decide dano. A primeira aquisição permite disparo imediato. Um upgrade conserva a fração restante do cooldown, recalculada pelo novo intervalo, para evitar disparos grátis ao comprar. Sem alvo, o cooldown chega a zero e permanece pronto.

### Fórmula de dano

```text
bonus = (1 + bonusContraChefe) * (1 + bonusCircuito)
vulnerabilidade = 1 + maiorMarcaAtiva
armaduraEfetiva = clamp(armaduraAtual * (1 - armorIgnore), 0, 0.80)
resistencia = armaduraEfetiva para physical
resistencia = energyResistance para energy
danoFinal = danoBase * bonus * vulnerabilidade * (1 - resistencia)
```

Campos ausentes valem zero, exceto multiplicadores cuja base é 1. armorIgnore vale fração de armadura ignorada: 0,5 remove metade; 1 remove toda. Vida e dano interno usam valores decimais; arredondar apenas para a interface. A vida inicial é arredondada para cima uma vez. Resistência de energia padrão é zero. Bônus contra chefe só vale para entidades com isBoss.

Lupa Observadora aplica marca de 10% por 3 s depois de seu acerto; o próprio acerto inicial não recebe a nova marca. Marcas não se somam: vale a maior, renovando duração quando reaplicada. Cada efeito recebe sourceTowerId e expiresAt. Nunca executar um task.wait por efeito ou inimigo.

### Área corrente e apoio

Explosão afeta o alvo primário e os inimigos mais próximos do seu centro, em raio inclusive, até maxTargets no total; dano é igual por alvo. Empates usam ID. O bônus Mira explosiva aumenta apenas splash, não alcance, dano ou limite de alvos.

chains é o número total de alvos, incluindo o primeiro. Cada salto procura o inimigo ainda não atingido mais próximo do anterior dentro de chainRadius, sem exigir alcance direto da torre. Dano do alvo de índice k, começando em zero, é damage × chainFalloff^k. Recalcular alvo a cada disparo; uma corrente nunca atinge a mesma entidade duas vezes.

Lentidões não se somam; usar a maior ainda ativa, limitada a 50%. Em chefes, multiplicar a força por 0,35 antes do limite. Goma L3A aplica seu slow e dano a todos os alvos da explosão. Um alvo lento continua elegível para Pega e acerta independentemente da fonte da lentidão.

Aura do Maestro só afeta torres de dano; vale o maior haste em alcance, inclusive entre donos diferentes. Maestro não acelera a si mesmo nem outros Maestros. Intervalo efetivo = intervaloBase / (1 + maiorHaste). Poeira do Aspirador aplica depois / 0,75 durante a duração; áreas de poeira não se acumulam. Sem críticos, esquiva ou aleatoriedade de acerto na versão 1.

Remendo cura a cada três segundos de simulação, até a vida máxima, os demais inimigos comuns a até 1,5 célula, excluindo a si, chefes e outros Remendos. Cada alvo recebe no máximo um pulso de cura por passo, mesmo com vários curadores. Pulso é 12 × fator de vida comum da partida. Casulo cria três Fiapos na própria posição ao morrer, com hp = 12 × fator de vida comum, velocidade 1,6, leak 1 e bounty 0. Se Casulo vaza na base, não se divide. Criaturas do Breu também têm bounty 0.

## Chefes e ondas

Catálogo traz vinte listas ordenadas de grupos. Criar o primeiro membro imediatamente ao começar cada grupo; demais respeitam spawnInterval; groupGap ocorre entre o último spawn de um grupo e o primeiro do próximo. Após todos os grupos da onda 20, aguardar dois segundos e criar o chefe do mapa. Invocações do chefe contam para a conclusão da onda.

A vida dos chefes é fixa por mapa no catálogo, multiplicada apenas por cooperação e dificuldade. Slow afeta movimento, sem mudar cadência de habilidades. O relógio de cada habilidade começa no nascimento; ao chegar a period, iniciar o aviso de telegraph segundos e então executar. O próximo aviso começa period segundos após o anterior. Fases terminais cancelam eventos agendados.

Aspirador escolhe a torre com maior sucata investida, desempate por ID, e fixa um círculo de raio 2 no local durante o aviso. Ao resolver, torres naquele círculo sofrem poeira por 4 s, mesmo que o chefe se mova. Nenhuma torre é removida. Rei Ferrugem recebe mais 0,35 de armadura por 5 s após seu aviso, depois retorna ao valor base. Breu invoca quatro Corriscos em s + 0,5 célula, limitado ao comprimento do caminho menos 0,1; não invocar atrás da base.

O Pulso de Luz é resolvido no passo em que o comando é aceito. Seu dano base 180 é multiplicado por [1 + 0,7 × (N - 1)] e processado como energia para cada inimigo vivo. Não multiplicar pelo mapa ou pelo modo Desafio. A marca de vulnerabilidade do alvo se aplica; bônus de torres não. A lentidão segue as regras gerais. Disponibilidade, consumo e efeito são atômicos para impedir dois usos no mesmo passo.

## Rede e autoridade

O cliente envia intenções. O servidor valida estado, dono, saldo, configuração, cooldown, coordenadas, tamanho e frequência. Vida, dano, recompensa e preço são calculados no servidor. Essa separação segue a orientação de segurança do Roblox. [Validação da fronteira cliente servidor](https://create.roblox.com/docs/scripting/security/client-server-boundary).

Um RemoteEvent Command recebe {protocolVersion, sessionSequence, requestId, action, payload}. requestId é uma string de até 40 caracteres; sessionSequence é um inteiro crescente por sessão de cliente. Rejeitar repetição já processada por usuário e match, devolvendo a resposta anterior sem repetir gasto. Guardar 128 respostas recentes e a maior sequência aceita; comandos antigos fora da janela são rejeitados. A reconexão inicia uma nova sessão autenticada pelo servidor. Campos desconhecidos, tabelas profundas, strings excessivas, valores NaN ou infinitos são recusados antes de qualquer operação custosa.

| Ação | Payload permitido | Validação central |
| --- | --- | --- |
| PlaceTower | matchId, towerId, x, y | Equipada, desbloqueada, célula inteira válida, saldo e limites |
| UpgradeTower | matchId, entityId, nextState | Dono, transição legal e saldo |
| SellTower | matchId, entityId | Dono e entidade ainda ativa |
| SetTarget | matchId, entityId, mode | Dono e enum válido |
| CastPulse | matchId | Participante ativo, fase de combate e recarga |
| SetReady | matchId, ready | Preparação ou intervalo |
| VoteSpeed | matchId, value | Valor 1 ou 2, voto atual do participante |
| SetLoadout | towerIds | Menu, até quatro IDs distintos desbloqueados |
| BuyTower | towerId | Menu, preço do catálogo, saldo e ainda não possuída |
| StartMatch | partyId, mapId, mode | Líder, presentes prontos, mapa liberado para todos |

Respostas incluem requestId, ok, errorCode, balance e revision. Erros previstos: INVALID_CELL, OCCUPIED, NOT_OWNER, INSUFFICIENT_FUNDS, LIMIT_REACHED, INVALID_STATE, PROFILE_UNAVAILABLE, RATE_LIMIT e STALE_REQUEST. A interface traduz códigos em mensagens úteis e remove estado pendente. Nada de entregar ao cliente a responsabilidade de desfazer um gasto confirmado.

Aplicar limite inicial de dez comandos de combate por segundo por usuário com rajada de vinte. Compras persistentes: uma por segundo, rajada de duas. Pedidos de snapshot completo: um a cada dois segundos. Valores são orçamento do projeto e precisam ser medidos. Não banir automaticamente por um erro de rede; registrar violações repetidas e descartar pedidos inválidos.

Replicação: estado inicial completo, mudanças a 10 Hz com revision crescente e snapshot de reconciliação a cada 2 s. Agrupar spawn, death, dano, torres, carteira e fase. Eventos cosméticos podem ser agregados. Cliente mantém buffer de 100 ms para interpolar posição, ignorando revisões antigas. Morte confirmada remove a entidade sem esperar projétil. Solicitação de recuperação é validada e o snapshot nunca inclui perfil de outro jogador.

Enviar somente dados da partida do destinatário. Não usar FireAllClients para expor todas as salas. Não transmitir posição individual de cada inimigo a cada frame se distância s, velocidade e timestamp já permitem apresentação. Seleção, alcance desenhado, câmera e animação são locais.

## Party e ciclo de sessão

Um servidor mantém parties de até quatro pessoas, com líder, membros, prontidão e sala. Convites internos usam lista de presentes; convite nativo de amigos só aparece quando a API informar disponibilidade. Entrar pelo Roblox não garante vaga no servidor cheio; mostrar estado real e permitir solo. Não prometer matchmaking entre servidores nesta versão.

O líder escolhe mapa e dificuldade que todos possuem. Trocar a composição limpa a prontidão. Uma saída no menu transfere liderança ao membro mais antigo. Ao começar, o servidor cria matchId e congela participantes. Quem chega durante a partida aguarda no menu e pode entrar na próxima. Sem recompensas para espectadores.

Ao desconectar, manter carteira e torres até o término; não permitir que outro jogador venda ou gaste por esse dono. Um retorno ao mesmo servidor e match restaura o controle por UserId e snapshot. Isso é retomada limitada, sem garantia de roteamento Roblox ao mesmo servidor. Depois de 30 s ausente, a pessoa deixa de contar para unanimidade de Pronto e 2x. Os fatores de combate permanecem os da largada.

Se não houver nenhum participante conectado por 60 s, encerrar como Abandoned, sem recompensa de conclusão. Quem estiver ausente no instante do resultado não recebe o prêmio; informar essa regra no diálogo de saída. Quem participou e está conectado recebe o mesmo resultado, sem exigência de último acerto. Sessões sem nenhuma ação e sem torre colocada durante toda a partida não recebem domínio, mas recebem os botões de participação; acompanhar abuso antes de adicionar regras punitivas.

No resultado, o clique de revanche marca prontidão. Após todos os presentes confirmarem, iniciar nova partida com novo ID. Ausentes saem da party de revanche após 30 s. O líder pode voltar ao menu sem transportar outros jogadores contra sua escolha.

## Persistência e recompensa

Perfil persistente por UserId: schemaVersion, buttons, ownedTowerIds, loadout, cosmeticsOwned, cosmeticLoadout, masteryByTower, mapUnlocks, tutorialRewardClaimed, settings, lifetimeStats, recentMatchRewards e sessionLock. Valores monetários são inteiros não negativos; validar catálogo e migração antes de aceitar perfil.

Usar DataStoreService apenas no servidor, com UpdateAsync para alterações concorrentes, pcall e repetição com espera progressiva. A documentação alerta que o Studio pode acessar os mesmos dados de produção; o ambiente de teste deve ter outro universo ou namespace. [Data stores](https://create.roblox.com/docs/cloud-services/data-stores).

Adquirir lock de sessão por UpdateAsync contendo JobId, token e expiresAt de 120 s; renovar a cada 30 s. Toda gravação compara o token. Se perder o lock, suspender novas mutações persistentes e compras, mantendo a interface com mensagem clara. Quando outro servidor possui lock válido, permitir tentar novamente ou entrar em treino sem progresso; nunca substituir por perfil vazio.

Salvar alterações sujas a cada 60 s com jitter, em desbloqueios, resultado, saída e BindToClose. Serializar gravações por usuário e verificar orçamento disponível. Callback de UpdateAsync não pode ceder execução nem gerar efeitos externos. Falha de carregamento nunca autoriza gravar defaults sobre um perfil existente. Migrações v1 para v2 etc. são puras, idempotentes e cobertas por teste com cópias.

Resultado deve criar um registro durável MatchResult com matchId, versão, resultado, participantes elegíveis e valores calculados. A fase RewardPending só exibe “salvo” depois de confirmar persistência. Cada perfil aplica o resultado junto com o registro matchId na mesma alteração atômica, sem dar recompensa duas vezes. Se aplicar a alguns perfis e falhar em outros, o registro permite repetir somente os pendentes.

Guardar IDs de recompensa por 30 dias, com limite de 1.024 entradas por perfil; bloquear reprocessamento de resultados mais antigos que 30 dias antes da consulta à lista. Ao atingir o limite dentro da janela, preservar a proteção e registrar necessidade de migração para ledger particionado, sem descartar IDs ainda válidos. Manter referências de resultados pendentes no perfil antes de iniciar a partida, para consulta na próxima sessão. Remover referência apenas após liquidar ou registrar abandono.

Se o servidor cair antes de criar um resultado durável, uma partida ainda em andamento não é recuperada nesta versão. Não prometer recompensa que não foi registrada. Em falha no final, mostrar “recompensa pendente” e reconciliar na próxima entrada. O tutorial segue o mesmo princípio, com chave única tutorial-v1 por conta.

## Loja e configuração externa

O único produto da versão 1 é um passe permanente. Products.luau contém founderPassId opcional e shopEnabled falso por padrão. Sem ID válido ou consulta de preço bem-sucedida, ocultar o botão de compra e manter o restante jogável. Validar posse do passe no servidor, consultar preço pela API e tratar cancelamento sem conceder itens. [Passes no Creator Hub](https://create.roblox.com/docs/production/monetization/passes).

Não implementar developer products apenas por hábito. Se forem autorizados em uma expansão, conceder itens com ProcessReceipt e ledger idempotente por PurchaseId, nunca pelo evento que apenas indica fechamento do popup. [Developer products](https://create.roblox.com/docs/production/monetization/developer-products).

Todos os assets e IDs de conta ficam em manifesto. Cada entrada especifica id lógico, ContentId, arquivo de origem, autor, direito de uso, dimensões e status de moderação. Arquivo local PNG não funciona automaticamente como ContentId Roblox. Sem upload aprovado, usar formas de interface provisórias claramente identificadas no modo de desenvolvimento; não alegar que a arte final está integrada.

## Orçamentos e desempenho

| Item | Meta inicial para medir |
| --- | --- |
| Inimigos vivos por partida | Até 180 no conteúdo normal; estresse com 250 |
| Torres por partida | Até 32 |
| Servidor com 12 jogadores | Validar três partidas de quatro e doze partidas solo |
| Renderização | 60 fps em computador de referência e 30 fps estáveis no celular de referência |
| Passo de simulação | p95 abaixo de 8 ms no cenário de carga definido |
| Tráfego por cliente em combate | Meta média abaixo de 35 KB/s, medir no profiler |
| Objetos visuais simultâneos | Meta abaixo de 1.800 GuiObjects por cliente |
| Texturas decodificadas próprias | Meta abaixo de 96 MiB residentes por partida |
| Áudio simultâneo | Até 16 vozes, com prioridade para avisos |

Esses valores são critérios de projeto a validar em dispositivos nomeados no relatório. Não são limites oficiais nem resultados obtidos. Se um spawn superar 250 inimigos, adiar spawns normais; uma invocação aguarda espaço, sem desaparecer nem render moeda. O roteiro normal deve ser ajustado para não depender desse mecanismo.

Usar pools de sprites e efeitos; não criar e destruir toda a interface por onda. Um único loop visual atualiza os objetos ativos. Para alvos, começar com busca simples medida e migrar a índice espacial por células se o profiler mostrar necessidade. Nunca escolher arquitetura mais complexa sem evidência. Carregar assets do mapa e equipe primeiro; carregar menu e demais skins sob demanda.

## Telemetria e depuração

Logar eventos com versão, matchId, modo, mapa, onda, duração, grupo e categoria de dispositivo, sem texto livre de chat. O ID do evento de resultado é estável para deduplicação. Funis podem ser enviados ao AnalyticsService conforme a documentação vigente; falha de telemetria não pode interromper combate ou salvamento. [Eventos de funil](https://create.roblox.com/docs/production/analytics/funnel-events).

Ferramentas de desenvolvimento: iniciar em uma onda, conceder sucata de teste, mostrar caminhos, inspecionar alvos, alternar profundidade de desenho e exportar resumo da partida. Autorizar somente em Studio ou por allowlist de UserIds no servidor de teste. Nenhum comando administrativo deve confiar em um botão escondido no cliente. Não publicar remotes de depuração abertos.

## Entregáveis exigidos do Claude Code

Código organizado, projeto Rojo, instruções de instalação, geração dos dados, testes de regras, build de lugar quando as ferramentas estiverem disponíveis, manifesto de assets, relatório de verificações e lista objetiva de passos manuais. Não incluir segredos ou credenciais. Não automatizar publicação em conta sem autorização de quem a controla.

Rojo permite trabalhar nos arquivos e sincronizá-los com Studio, mas não substitui o teste no motor. Validar combate solo, simulação cliente servidor e vários clientes. [Documentação Rojo](https://rojo.space/docs/v7/) e [Modos de teste do Studio](https://create.roblox.com/docs/studio/testing-modes).

Entrega “código pronto” significa que os módulos e testes disponíveis foram concluídos. Entrega “jogo validado” exige execução no Roblox Studio e em clientes reais. Entrega “publicado” exige um lugar publicado, permissões e assets aprovados. O relatório deve distinguir esses estados com precisão.
