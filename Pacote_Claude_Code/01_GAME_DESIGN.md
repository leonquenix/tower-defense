# Quintal em Guarda

## Proposta de jogo 2D para Roblox

Versão 1.1 de 15 de setembro de 2026. Preparado para Breno e para implementação pelo Claude Code. O nome é provisório. Este documento define um produto inicial completo e publicável após implementação, produção de assets e validação. Nenhum jogo foi implementado ou testado neste trabalho.

Recomendação: criar um tower defense cooperativo de brinquedos vivos, com partidas de 10 a 15 minutos, visão superior em 2D, seis torres colecionáveis e combinações por proximidade chamadas Circuitos. O jogador monta uma pequena equipe, posiciona seus personagens e escolhe especializações durante a partida para proteger um farol de brinquedo contra criaturas de poeira.

A aposta de produto é tornar a estratégia legível no celular e dar identidade aos personagens. A satisfação deve vir de perceber que uma combinação funcionou, ver uma torre mudar de aparência e terminar uma defesa com amigos. A hipótese ainda precisa ser validada com jogadores; pesquisa de jogos existentes não comprova retenção ou receita deste projeto.

### Decisões de partida

| Tema | Decisão para a versão 1 |
| --- | --- |
| Plataforma | Roblox com Luau e Rojo |
| Apresentação | Tabuleiro e personagens 2D em ScreenGui |
| Público de projeto | Jogadores casuais e intermediários, familiaridade variável com TD |
| Dispositivos | Computador, celular e tablet em paisagem |
| Grupo | Solo ou cooperação de 2 a 4 pessoas |
| Conteúdo | Tutorial, treino, 3 mapas, 20 ondas, 6 torres, 8 inimigos e 3 chefes |
| Progressão | Desbloqueios determinísticos de personagens e domínio cosmético |
| Monetização | Cosméticos opcionais, inicialmente um passe permanente |
| Idiomas | Português brasileiro e inglês desde a estrutura inicial |
| Principal diferencial | Três Circuitos visíveis entre pares de torres adjacentes |

## Referências atuais e método de seleção

“Melhores” significa aqui as referências mais úteis para este projeto: profundidade estratégica, identidade, cooperação, progressão e capacidade de ensinar uma mecânica. Não é um ranking absoluto de popularidade. A pesquisa foi realizada em 15 de setembro de 2026 com páginas oficiais dos jogos, páginas dos desenvolvedores e documentação da plataforma. Não houve sessão prática nesses jogos nem acesso às suas métricas internas.

As páginas do Roblox podem apresentar conteúdo carregado por JavaScript e textos genéricos de ausência de servidores. Esse texto não foi interpretado como encerramento dos jogos. Números indexados de jogadores simultâneos não foram usados como medição em tempo real. As conclusões abaixo distinguem características anunciadas dos jogos e nossas decisões de design.

### Tower Defense Simulator

A página oficial apresenta defesa por unidades, cooperação contra chefes e desbloqueio de novas torres. Na consulta, anunciava a versão 2.10.0 e a unidade Pulse Trooper. É a referência principal para o ciclo de melhorar a coleção e enfrentar desafios com amigos. [Página oficial de Tower Defense Simulator](https://www.roblox.com/games/3260590327/Tower-Defense-Simulator).

Aplicação proposta: deixar a próxima torre e seu custo sempre visíveis; apresentar um chefe como objetivo reconhecível; permitir repetir uma partida com o mesmo grupo em um toque. Risco a evitar no nosso projeto: esconder a diversão inicial atrás de muitas partidas repetidas. O tutorial já entrega três funções complementares.

### Tower Defense X

A descrição oficial destaca torres de ar, terra e mar, chefes capazes de destruir torres e um modo PvP. Serve como referência de ameaças que exigem adaptação, além de simplesmente elevar a vida dos inimigos. [Página oficial de Tower Defense X](https://www.roblox.com/games/9503261072/PVP-MODE-Tower-Defense-X-BETA).

Aplicação proposta: três chefes com comportamentos legíveis e contrajogo. Para o primeiro lançamento, ataques dos chefes podem reduzir temporariamente a cadência, mas não apagam torres compradas pelo jogador. Isso reduz a punição enquanto se aprende a economia. PvP fica para uma avaliação futura, pois exigiria outro balanceamento e outra estrutura de partidas.

### Tower Heroes

A página oficial descreve heróis distintos, mapas com chefes próprios, campanha cooperativa e coleção de skins, adesivos e modificadores. É a principal referência de identidade e vínculo com o elenco. [Página oficial de Tower Heroes](https://www.roblox.com/games/4646477729/Tower-Heroes).

Aplicação proposta: seis silhuetas fáceis de reconhecer, reações expressivas e uma ficha de coleção por personagem. Cada mapa terá um chefe que pertence visualmente àquele lugar. Cosméticos precisam parecer desejáveis porque o personagem é querido, e essa aceitação deve ser medida no teste de conceito.

### Anime Vanguards

A descrição oficial enfatiza invocar unidades, subir de nível, evoluí-las e jogar em grupo em diferentes modos. Sua utilidade para a proposta é a força da fantasia de coleção e transformação de personagens. [Página oficial de Anime Vanguards](https://www.roblox.com/games/16146832113/Anime-Vanguards).

Aplicação proposta: upgrades com mudança visual forte e revelação curta ao desbloquear uma unidade. Não adotaremos personagens de franquias de anime nem rolagens aleatórias de poder. A coleção será original e terá preço conhecido em moeda obtida jogando. Isso também deixa o balanceamento e os testes reproduzíveis.

### Doomspire Defense

A página oficial descreve defesa de uma torre, recompensas em moedas e experiência, compra de unidades e combinações de equipamentos com funções diferentes. É uma referência de como um tema familiar à cultura do Roblox pode dar coesão a um TD. [Página oficial de Doomspire Defense](https://www.roblox.com/games/15549445942/KORBLOX-Doomspire-Defense).

Aplicação proposta: formas de brinquedos, feedback imediato e humor visual. Cada nova torre deve abrir uma estratégia. Não precisamos reproduzir a estética de blocos ou o universo de Doomspire para aproveitar esse princípio.

### Referências fora do Roblox

Bloons TD 6 combina caminhos de upgrade, heróis, desafios e cooperação para quatro jogadores. É a referência principal para escolhas de especialização e repetição com novas composições. Adaptaremos a clareza das funções para duas opções finais por torre, evitando oferecer muitas árvores de evolução ao iniciante. [Bloons TD 6 na Steam](https://store.steampowered.com/app/960090/BloonsTD6/?l=english).

Kingdom Rush 5 Alliance trabalha com controle de dois heróis e campanha com desafios próprios por fase. A proposta aproveita a ideia de ameaças com identidade e encontros preparados. Não inclui herói móvel na versão 1, para concentrar os controles de celular em posicionar e melhorar torres. [Perguntas respondidas pelos desenvolvedores de Alliance](https://www.ironhidegames.com/News/Details/341).

Emberward usa blocos para construir labirintos e torres que tornam o posicionamento relevante. É a referência para fazer o tabuleiro importar. Adotaremos adjacência e Circuitos em caminhos fixos; construção livre de labirintos aumentaria a complexidade de navegação, cooperação e balanceamento. [Emberward na Steam](https://store.steampowered.com/app/2459550/Emberward/).

### Prioridade das referências para este projeto

| Referência | Melhor aprendizado | Decisão concreta |
| --- | --- | --- |
| Tower Heroes | Personalidade do elenco | Seis personagens com silhuetas e expressões próprias |
| Tower Defense Simulator | Ciclo de coleção e cooperação | Coleção visível e revanche com o grupo |
| Bloons TD 6 | Especialização tática | Duas escolhas finais exclusivas por torre |
| Tower Defense X | Chefes alteram decisões | Três mecânicas anunciadas antes de acontecer |
| Anime Vanguards | Desejo de evoluir personagens | Transformação visual a cada estado |
| Doomspire Defense | Identidade coerente e composições | Tema de brinquedos e funções complementares |
| Kingdom Rush Alliance | Encontros com personalidade | Campanha curta com chefes distintos |
| Emberward | Posição é parte da estratégia | Circuitos por adjacência |

## Fantasia e experiência do jogador

O quintal fica vivo quando a casa dorme. Brinquedos esquecidos mantêm aceso o Farol de Pilha, enquanto Fiapos e criaturas do Breu tentam apagar sua luz. Os jogadores são os organizadores dessa defesa. O tom é de aventura leve, humor e engenhosidade: madeira, papelão, molas e potes viram equipamentos.

O jogador deve entender três coisas ao ver uma captura de tela: por onde os inimigos caminham, o que está protegendo e onde pode construir. O primeiro minuto deve terminar com uma torre disparando, moedas aumentando e uma decisão simples de melhoria. A coleção e a loja entram depois dessa primeira experiência.

### Necessidades de um jogador de Roblox

| Necessidade | Resposta do jogo | Verificação |
| --- | --- | --- |
| Entender rapidamente | Primeiro inimigo e primeiro disparo em até 45 s como meta | Observar novos jogadores sem explicar |
| Jogar com amigos | Party no mesmo servidor, convite nativo quando permitido e revanche | Grupo de quatro conclui uma partida |
| Mostrar identidade | Skin, retrato, título e estandarte visíveis ao grupo | Reconhecer quem colocou cada torre |
| Sentir evolução | Compra de unidades por preço fixo e domínio cosmético | Jogador identifica próximo objetivo |
| Perceber contribuição | Dano, controle e apoio no resultado | Apoio não aparece como jogador inútil |
| Não se perder no celular | Botões grandes, confirmação e zoom de construção | Colocar cinco torres sem erro recorrente |
| Ter motivo para voltar | Novo mapa, especializações, desafios semanais futuros | Intenção espontânea de outra partida |

Estas necessidades são hipóteses de design informadas pelas referências, e não resultados de entrevistas já realizadas.

## Ciclo de jogo e telas

A sessão segue: entrar, escolher modo, montar equipe, defender, receber resultado e decidir a próxima partida. A campanha se divide em Jardim de Papel, Oficina de Lata e Sótão das Estrelas. Cada vitória normal abre o mapa seguinte. O modo Desafio de um mapa abre após vencer seu modo Normal.

O menu inicial é um painel 2D com Jogar em destaque, Coleção, Treino e Configurações. A loja é secundária. Retratos dos participantes e estado de prontidão ficam visíveis. Não há lobby 3D obrigatório, deslocamento até portais ou fila que impeça começar sozinho.

Cada jogador equipa até quatro torres diferentes; os quatro espaços existem desde o início. A conta nova possui Dardo, Pipoca e Goma. A quarta vaga pode ficar vazia. O menu sugere Lupa como próxima compra, sem obrigar essa ordem. A equipe fica travada quando a partida começa. Skins não alteram os atributos.

### Primeiro contato e tutorial

O tutorial solo usa uma versão curta do Jardim, três ondas e as três torres iniciais. Dinheiro inicial de 1.200 sucatas, sem persistência do saldo. Onda 1: seis Fiapos; onda 2: seis Fiapos e quatro Corriscos; onda 3: duas Bolotas e oito Fiapos. Usa os mesmos atributos do Normal e os mesmos serviços de combate.

1. Mostrar caminho e farol; pedir para posicionar Dardo na célula (3,3).
2. Iniciar a primeira onda após confirmação; realçar dano, vida da base e sucata.
3. Após a primeira onda, guiar Goma para (3,4), formando um Circuito com Dardo. Explicar o bônus em uma frase.
4. Pedir uma melhoria de Dardo para L1 e mostrar o antes e depois. Oferecer Pipoca sem obrigar sua colocação.
5. Concluir a terceira onda e conceder 180 botões, uma única vez, quando o resultado for salvo.

Em falha, reiniciar a onda do tutorial a partir de um checkpoint em memória. Permitir pular explicações; pular não concede a recompensa, mas mantém as três unidades iniciais. O tutorial pode ser reaberto pelo menu. Nada de popup de compra durante essa sequência.

### Treino

Treino solo libera temporariamente as seis torres, todas as especializações e sucata infinita. O jogador pode escolher inimigo, gerar 1 ou 10, limpar o tabuleiro e ligar indicadores de alcance e Circuitos. Não concede moeda, experiência, domínio, conquistas ou compras. Facilita testar uma torre antes de desbloqueá-la e serve como ferramenta de QA.

## Regras da partida

O tabuleiro tem 16 colunas e 10 linhas, com células de tamanho lógico 1. O caminho é fixo. Uma torre ocupa uma célula fora do caminho e fora das decorações bloqueadoras. Alcance é circular e não há bloqueio de linha de visão. Todos os inimigos são terrestres; nenhuma unidade precisa de detecção oculta ou antiaérea nesta versão.

A base começa com 100 de vida. A onda só termina quando todos os seus grupos nasceram e não existe inimigo vivo. O grupo perde quando a base chega a zero e vence ao eliminar todos os inimigos da onda 20, incluindo o chefe. Se houver derrota e morte do último inimigo no mesmo passo da simulação, derrota tem precedência.

Há 15 segundos de preparação antes da primeira onda e 8 entre ondas. O botão Pronto antecipa o fim da preparação quando todos os participantes ativos concordam. Não antecipa ondas com inimigos vivos. A velocidade é 1x; 2x é gratuita e precisa de unanimidade no grupo. Um jogador pode solicitar retorno imediato a 1x. Tutorial fica em 1x.

Torres atacam automaticamente. O jogador pode colocar, melhorar, selecionar alvo e vender durante a onda. Venda devolve 70% da sucata investida, arredondada para baixo. Não há movimentação gratuita após confirmar a compra. Antes da confirmação, o fantasma de posicionamento pode ser movido livremente. Vender ou comprar nunca exige arrastar com precisão.

### Limites de construção

| Jogadores na largada | Torres por pessoa | Total máximo |
| --- | --- | --- |
| 1 | 18 | 18 |
| 2 | 12 | 24 |
| 3 | 10 | 30 |
| 4 | 8 | 32 |

O limite por espécie no catálogo também se aplica. O número de participantes, os multiplicadores e os limites são congelados na largada. Em uma saída, as torres continuam operando; não reduzir instantaneamente a vida dos inimigos. Regras de saída e retorno estão na especificação técnica.

## Torres e escolhas de especialização

| Torre | Personagem | Função | Especialização A | Especialização B |
| --- | --- | --- | --- | --- |
| Dardo | Raposa de madeira | Ataque barato e constante | Rajada aumenta cadência | Fura lata ignora armadura |
| Pipoca | Tartaruga de corda | Explosão contra grupos | Festival amplia área | Demolidora enfrenta armadura |
| Lupa | Coruja de papelão | Longo alcance e elites | Olho de águia causa bônus em chefes | Observadora marca um alvo |
| Goma | Criatura em pote de cola | Reduz velocidade | Poça afeta um grupo | Supercola aplica lentidão maior |
| Voltz | Robô de mola | Corrente entre inimigos | Tempestade alcança mais alvos | Alta tensão concentra dano |
| Maestro | Caranguejo de rádio | Melhora cadência ao redor | Orquestra amplia alcance | Solo aumenta o bônus |

Cada torre tem L0, L1, L2 e uma escolha exclusiva L3A ou L3B. Custos são pagos a cada avanço; não se pode ir diretamente de L0 para L3. A escolha final não muda até vender a torre. Não existe melhoria permanente de dano por nível de conta. Novos personagens ampliam opções, e domínio concede identidade visual.

Os números completos estão no catálogo e no JSON. São parâmetros iniciais de design, não balanceamento comprovado. A tabela inclui custo, dano, intervalo, alcance e efeitos para todos os 30 estados.

## Circuitos por adjacência

Circuitos são o diferencial central e devem aparecer até o terceiro minuto do tutorial. Um par compatível em células ortogonalmente vizinhas se conecta por um fio discreto no chão. Diagonal não conta. Cada torre participa de no máximo um Circuito. A mesma regra funciona entre torres de jogadores diferentes, incentivando cooperação.

| Par | Nome | Efeito |
| --- | --- | --- |
| Dardo e Goma | Pega e acerta | Dardo causa 15% mais dano a qualquer inimigo com lentidão ativa |
| Pipoca e Lupa | Mira explosiva | Pipoca recebe mais 0,2 célula de raio de explosão |
| Voltz e Maestro | Ritmo elétrico | Queda de dano por salto melhora em 0,10, limitada a 0,90 |

Se houver vários vizinhos compatíveis, o servidor ordena os pares pela menor identificação de torre e depois pela maior, conectando o primeiro par livre. Identificações crescem conforme a construção é confirmada. Não reordenar por dano, preço ou dono. A prévia deve mostrar exatamente qual par será ativado e que conexão poderá mudar após uma venda.

O efeito existe apenas enquanto as duas torres permanecem colocadas. Recalcular ao comprar e vender. Maestro mantém sua aura independentemente do Circuito. Desligar visual de fios nas configurações não desliga os efeitos; ao selecionar uma torre, mostrar sempre seu parceiro e o bônus numérico.

## Inimigos e contrajogo

Fiapo ensina o básico. Corrisco exige cobertura de caminho. Bolota permite perceber dano constante. Latinha reduz dano físico e estimula uso de energia. Névoa reduz parte do dano de energia e favorece ataques físicos. Remendo cura aliados próximos e pode ser priorizado. Casulo deixa três Fiapos pequenos ao morrer. Brutamontes exige investimento em dano contra alvo único.

As resistências reduzem dano e nunca tornam um inimigo totalmente invulnerável. Exibir a característica no aviso da onda e no detalhe do inimigo. Não exigir que o jogador consulte uma wiki para compreender uma derrota.

### Chefes

| Chefe | Mapa | Comportamento | Resposta do jogador |
| --- | --- | --- | --- |
| Aspirador Rabugento | Jardim | Anuncia área de poeira e reduz cadência de torres nela por 4 s | Distribuir o investimento e usar o poder da base |
| Rei Ferrugem | Oficina | Alterna períodos de armadura maior | Preparar dano de energia ou Fura lata |
| Breu debaixo da cama | Sótão | Invoca quatro Corriscos à frente de seu progresso | Guardar cobertura e explosão para os reforços |

Todos mostram barra de vida, nome, ícone da habilidade e anúncio visual antes da ação. Não há dano súbito sem aviso, efeitos que escondem o caminho ou compra de ressurreição na tela de derrota.

### Poder compartilhado do farol

Pulso de Luz causa 180 de dano de energia a cada inimigo vivo e aplica 30% de lentidão por 3 segundos. Tem 60 segundos de recarga em tempo de simulação e começa carregado. Dano recebe as resistências normais e o multiplicador cooperativo de vida; não recebe bônus de torres. Chefes sofrem lentidão reduzida pela regra global. Todos podem ativar, e a primeira solicitação válida consome a recarga para o grupo. Prévia explica o efeito; um segundo toque confirma. O poder existe para oferecer uma decisão de emergência sem exigir controle de um herói.

## Economia e progressão

Sucata é exclusiva da partida: começa em 650 por pessoa, compra e melhora torres, e desaparece ao encerrar. Botões persistem na conta: desbloqueiam personagens e itens cosméticos obtidos jogando. Não existe conversão de Robux para sucata ou botões na versão 1. Nenhum terceiro saldo é necessário.

Cada inimigo morto gera a recompensa indicada no catálogo para a equipe inteira, dividida em partes iguais entre os participantes da largada. O resto inteiro vai, um por vez, para jogadores em ordem crescente de UserId, com um cursor que gira entre mortes. A carteira do jogador ausente permanece em memória. Não há prêmio por último acerto, por dano individual ou por matar criaturas invocadas.

Concluir uma onda dá 120 + 15 × número da onda de sucata a cada participante. Vencer concede 120 botões no Normal e 160 no Desafio. Perder concede 4 × ondas concluídas, limitado a 60. Sair antes do resultado não concede recompensa de conclusão. Tutorial dá 180 uma única vez. Treino dá zero.

Lupa custa 240 botões, Maestro 450 e Voltz 600. A primeira vitória normal, somada ao tutorial, já permite comprar Lupa. As três compras somam 1.290 botões: dez vitórias normais mais o tutorial rendem 1.380. Essa conta dimensiona o esforço nominal; duração real, derrotas e preferência de compra dependem dos testes.

Cada torre equipada recebe 10 pontos de domínio ao vencer, desde que tenha sido colocada ou prestado apoio por pelo menos 30 segundos. Derrota após concluir cinco ondas rende 4 pontos sob a mesma condição. Marcos de 30, 100 e 250 pontos entregam adesivo, título e uma variação de skin, respectivamente. Domínio não muda atributos nem Circuitos. Não limitar pontos diários.

### Cooperação e dificuldade

Vida dos inimigos comuns = vida do catálogo × multiplicador do mapa × multiplicador da dificuldade × [1 + 0,7 × (jogadores na largada - 1)]. Vida dos chefes usa sua própria vida de catálogo e os dois últimos fatores, sem aplicar novamente o multiplicador do mapa.

Normal usa fator 1. Desafio usa fator de vida 1,45 e velocidade 1,10. Não alterar quantidade, sucata ou resistências no Desafio. Arredondar vida uma única vez, para cima. A renda e o limite de torres devem ser testados em solo e em quatro pessoas; não assumir equilíbrio apenas porque a fórmula escala.

## Interface e acessibilidade

No combate, a faixa superior mostra vida do farol, onda, sucata pessoal e participantes. O tabuleiro fica centralizado. A faixa inferior apresenta as quatro torres da equipe, Pulso de Luz e velocidade. O detalhe de torre abre em painel lateral no computador e em folha recolhível no celular, sem cobrir permanentemente o caminho.

Posicionamento tem três passos: tocar a unidade, tocar a célula e confirmar o preço. Mostrar fantasma, alcance, validade e Circuito previsto. Célula inválida tem ícone e texto, além de cor. Se a célula ocupar menos de 36 pixels físicos de interface, ativar ampliação da região ao escolher a unidade; botões continuam com pelo menos 44 × 44 pixels de interface, meta de 48. Permitir arrastar o mapa com dois dedos e voltar à visão completa com um botão.

Mostrar informações da próxima onda com ícones e frase curta. O resultado informa ondas superadas, recompensa, progresso de domínio e contribuição por dano, tempo de lentidão e dano adicional produzido por apoio. Esses dados são informativos; não mudam o pagamento. Oferecer Tentar novamente e Voltar ao menu, mantendo a party quando possível.

Incluir volume separado para música e efeitos, redução de movimento, partículas reduzidas, números de dano opcionais e padrão visual alternativo para Circuitos. Usar formas e ícones para equipe, resistência e estado. Preservar menus e controles nativos do Roblox. Console e VR não entram na validação inicial nem devem ser anunciados como suportados.

## Monetização e retorno

A versão inicial pode ser lançada gratuitamente com a loja desligada. Após validar diversão e salvar dados com segurança, ativar um passe permanente Pacote Fundador: seis skins visuais em paleta de oficina, um estandarte e um título. Preço inicial de teste: 149 Robux, definido no painel da plataforma e consultado pela interface. É hipótese de produto, não estimativa de receita. Conferir preço e disponibilidade reais antes de mostrar a compra.

O passe não concede dano, dinheiro de partida, aceleração exclusiva, vagas extras, desconto em torres ou vantagem de domínio. Não incluir recompensas aleatórias pagas, anúncios obrigatórios, troca de itens, caixas ou revenda. A decisão reduz o trabalho de economia e deixa o mérito da estratégia observável.

O retorno no lançamento vem da campanha, do Desafio e do domínio dos seis personagens. Após observar jogadores, avaliar desafios semanais com equipe fixa, novo mapa e eventos cosméticos. Não prometer uma atualização por semana sem capacidade de produção. Toda adição deve preservar a utilidade das torres já existentes.

## Escopo de produção e lançamento

### Obrigatório para a versão 1

Tutorial, treino, coleção, equipe, três mapas, duas dificuldades, vinte ondas por mapa com parâmetros definidos, seis torres completas, três Circuitos, oito inimigos comuns, três chefes, Pulso de Luz, modo solo, cooperação, persistência, configurações, localização, resultado e revanche. A infraestrutura de loja deve existir com desligamento seguro; ativá-la é uma decisão separada de publicação.

### Fora da versão 1

PvP, mercado entre jogadores, personagens licenciados, gacha, clãs, passe de temporada, campanha narrativa longa, labirinto livre, torre de renda, herói móvel, múltiplos caminhos simultâneos, modo infinito com economia própria, reconexão garantida entre servidores e suporte a console. Essas ideias não devem aparecer como botões inativos no produto.

### Marcos de trabalho

| Marco | Entrega | Condição para avançar |
| --- | --- | --- |
| M0 Fundação | Projeto abre no Studio e renderiza tabuleiro 2D | Entrada, resolução e coordenadas corretas |
| M1 Combate | Jardim, Dardo, Goma, inimigos e três ondas | Uma partida curta pode ser vencida e perdida |
| M2 Diferencial | Seis torres, especializações, Circuitos e treino | Combinações verificadas sem ambiguidade |
| M3 Conteúdo | Três mapas, vinte ondas, chefes e Desafio | Todas as condições de vitória e derrota funcionam |
| M4 Serviço | Cooperação, party, perfis e recompensas | Concorrência e falhas de salvamento testadas |
| M5 Apresentação | Arte, áudio, tutorial e interface final | Leitura no celular e testes com jogadores |
| M6 Candidato | Desempenho, telemetria e publicação de teste | Critérios técnicos e de produto atendidos |

Não existe estimativa responsável de prazo completo sem conhecer a equipe, a qualidade dos assets e a capacidade de teste. O Claude Code pode implementar scripts, estrutura e ferramentas; produção visual final, uploads, configurações de conta e avaliação de diversão exigem recursos e validação próprios. Os marcos são uma ordem de construção, não uma promessa de geração integral em uma execução.

## Validação de diversão e métricas

Fazer primeiro uma rodada observada com 8 a 12 pessoas, parte iniciante em TD e parte habituada ao Roblox, incluindo uso real de celular. Essa amostra serve para localizar problemas, não para provar retenção. Pedir que joguem sem explicação externa e observar onde deixam de entender a interface.

Critérios iniciais propostos: pelo menos 8 de 10 participantes conseguem colocar e melhorar uma torre; pelo menos 7 explicam um Circuito depois do tutorial; pelo menos 6 escolhem espontaneamente uma segunda partida. Se não ocorrer, revisar tutorial, duração e feedback antes de ampliar conteúdo ou comprar tráfego.

Instrumentar entrada, início do tutorial, primeira torre, primeira melhoria, primeiro Circuito, fim do tutorial, início da partida, onda atingida, fim, recompensa salva e início da segunda partida. Registrar build, mapa, dificuldade, tamanho do grupo e dispositivo. O servidor emite resultados; pedidos do cliente não são prova de vitória.

Em beta, acompanhar taxa de conclusão do tutorial, tempo até primeiro disparo, abandono por onda, duração, vitórias por mapa e grupo, seleção de torres, segunda partida e retorno D1 e D7. D1 e D7 são retorno no dia de calendário UTC correspondente após a primeira sessão, com denominador apenas de coortes já maduras. Separar celular de computador. Metas de retenção comercial precisam ser fixadas após o primeiro baseline; não apresentamos benchmarks inventados.

### Riscos e decisões de resposta

O 2D pode perder parte da expressão do avatar típica do Roblox. Compensar com retratos, estandartes, torres do jogador e presença da party; medir se o grupo se reconhece. A adjacência pode parecer difícil no celular: priorizar prévia e ampliação contextual. Um elenco pequeno pode parecer pouco colecionável: investir em duas especializações e domínio antes de multiplicar personagens. Nenhuma dessas hipóteses substitui teste com jogadores.
