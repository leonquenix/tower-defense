# Testes e critérios de aceite

## Estado desta entrega

Este pacote contém especificações, dados iniciais, referências e ilustrações. Os testes abaixo são obrigações para a implementação futura. Não foram executados contra um jogo Roblox nesta etapa. A validação do pacote cobre integridade de dados e apresentação dos documentos.

## Testes das regras

| ID | Cenário | Resultado esperado |
| --- | --- | --- |
| T01 | Colocar Dardo com 650 sucatas | Saldo 400 e uma torre L0 |
| T02 | Repetir requestId da mesma colocação | Mesmo resultado sem nova torre ou gasto |
| T03 | Dois jogadores compram na mesma célula | Apenas a primeira compra válida é aceita |
| T04 | Colocar sobre caminho, bloqueio ou fora do mapa | Pedido rejeitado sem gasto |
| T05 | Comprar L2 diretamente de L0 | INVALID_STATE |
| T06 | Dardo L0 e L1 são comprados e depois vendidos | Investido 450, devolução 315 |
| T07 | Dardo L3B atinge Latinha sem outros efeitos | Armadura física ignorada integralmente |
| T08 | Goma e Pulso aplicam slow ao mesmo inimigo | Maior slow ativo prevalece, sem soma |
| T09 | Supercola aplica 45% a chefe | Redução de velocidade 15,75% |
| T10 | Dois Maestros de 12% e 25% cobrem Dardo | Intervalo dividido por 1,25 |
| T11 | Três torres disputam um Circuito | Pares determinísticos por ID, sem dupla conexão |
| T12 | Vender parceiro conectado | Bônus removido no mesmo passo |
| T13 | Voltz L0 acerta dois alvos sem resistência | Dano 20 no primeiro e 15 no segundo |
| T14 | Casulo morre e cria três Fiapos | Um bounty de Casulo; zero dos filhos |
| T15 | Casulo vaza | Um leak de Casulo, nenhum filho |
| T16 | Chefe e base seriam eliminados no mesmo passo | Prevalece derrota pela ordem definida |
| T17 | Dois jogadores usam Pulso simultaneamente | Um efeito e uma recarga |
| T18 | Fiapo no Jardim Normal com quatro pessoas | Vida ceil(24 × 3,1) = 75 |
| T19 | Aspirador no Jardim Desafio solo | Vida ceil(7000 × 1,45) = 10150 |
| T20 | Bounty de 10 com três participantes | Distribuir 4,3,3 com cursor giratório |

## Persistência e resistência a abuso

| ID | Cenário | Resultado esperado |
| --- | --- | --- |
| P01 | DataStore indisponível na entrada | Não sobrescrever perfil; treino sem progresso disponível |
| P02 | Duas sessões disputam perfil | Uma adquire lock; outra não grava |
| P03 | Servidor perde token de lock | Mutação persistente suspensa |
| P04 | Falha de gravação após resultado | Mostrar pendente e reconciliar sem duplicação |
| P05 | Repetir o mesmo matchId de recompensa | Nenhum novo pagamento |
| P06 | Reprocessar tutorial concluído | Não conceder os 180 botões novamente |
| P07 | Perfil antigo é carregado duas vezes | Migração idempotente |
| P08 | Cliente envia preço zero ou recompensa fabricada | Campos rejeitados e nenhum saldo alterado |
| P09 | Enviar NaN, infinito, strings enormes e IDs de outro match | Rejeitar antes de processar |
| P10 | Jogador tenta vender torre alheia | NOT_OWNER |
| P11 | Passe cancelado ou ID ausente | Nenhuma skin paga concedida |
| P12 | Encerrar servidor com perfis sujos | Tentativa controlada de salvar, com resultado registrado |

## Testes no Studio e dispositivos

Executar um, dois e quatro clientes, construindo, votando 2x e recebendo resultados. Com 150 a 250 ms de latência simulada, saldo não duplica, comandos mostram espera e sprites se reconciliam sem alterar a simulação.

Testar as 24 combinações de três mapas, duas dificuldades e quatro tamanhos de grupo, com uma execução completa de cada. Registrar equipe, compras, vazamentos, duração e Pulso. Incluir equipes iniciais e avançadas.

Testar carga com três partidas de quatro pessoas e doze partidas solo. Registrar hardware, build, frames, p95 de simulação, memória e tráfego. Repetir 60 minutos de criação e encerramento; crescimento contínuo de instâncias ou conexões é falha.

No celular, concluir tutorial, construir, cancelar, ampliar, melhorar, vender e ativar Pulso. Manter confirmação e menus nativos acessíveis. Repetir com movimento reduzido, números desligados e áudio mudo.

## Balanceamento e diversão

O catálogo é um ponto de partida. Usar um simulador de regras ou partidas reproduzíveis para verificar que Dardo mais Goma consegue atravessar as ondas iniciais do Jardim sem depender de sorte. No Normal, a composição inicial deve ter um caminho plausível até vitória; unidades desbloqueadas oferecem alternativas e não corrigem um bloqueio artificial.

Comparar escolhas A e B de cada torre em situações adequadas às funções. Se uma opção for melhor em todos os cenários, mudar custos, alcance ou efeito. Medir a utilidade de Maestro pelo dano adicional produzido e de Goma por inimigos contidos, além do dano bruto. Verificar se comprar Circuito compensa o custo de posição sem tornar obrigatório empilhar todas as torres.

Medir duração no Normal 1x: meta de 10 a 15 minutos. Se sessões mais curtas forem melhores, atualizar a promessa e a economia, sem esticar ondas artificialmente.

## Definição de pronto

Todos os sistemas obrigatórios operam do início ao resultado; não há botão anunciado sem função. Dados e arte são carregados por manifesto; referências temporárias estão identificadas e removidas da versão final. Build abre, regras passam nos testes automatizados, partidas reais foram executadas e o relatório diferencia testado, não testado e bloqueado.

Lançamento exige ainda assets aprovados, descrição compatível com o produto, configuração de idade e conteúdo conforme o processo vigente do Roblox, dados de produção separados dos testes e opção de desativar a loja. Um problema de monetização não deve impedir jogar gratuitamente.
