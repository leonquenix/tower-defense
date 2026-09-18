# Interfaces de Quintal em Guarda


Versão 1 • 18 de setembro de 2026



## Interfaces de Quintal em Guarda


### Objetivo

Implementar a interface completa da versão 1 como componentes nativos do Roblox, com navegação simples, feedback imediato e dados confirmados pelo servidor. Este guia reúne 49 pranchas visuais de telas e estados, incluindo seis composições compactas e a orientação vertical. Cada prancha tem um PNG separado e fonte SVG.


### O que deve ficar pronto

Menu, mapas, salas, convites, grupo, coleção, equipe, desbloqueio, cosméticos, loja opcional, configurações, carregamento, tutorial, treino, combate, posicionamento, inspeção, especialização, venda, chefes, Pulso, resultados e recuperação de falhas. As variantes de dados reutilizam componentes; não construir uma tela nova por torre ou mapa.


### Como ler e implementar

Leia primeiro as regras globais e depois as fichas ilustradas. As imagens definem composição, hierarquia e aparência. Os contratos de cada ficha definem cliques, validações e estados. Valores visuais são exemplos; o JSON de balanceamento e o servidor fornecem valores reais. A loja permanece desligada por padrão.


### Arquivos principais

GUIA_COMPLETO_UI.docx é editável; GUIA_COMPLETO_UI.pdf é para leitura; GUIA_COMPLETO_UI.md é a versão textual com links relativos. PREVIA_INTERATIVA.html permite navegar pelas referências e testar microinterações de exemplo. dados/telas.json contém dimensões e áreas interativas; dados/design_tokens.json e animacoes.json centralizam aparência e movimento.


### Prioridade e limites

Regras de combate, economia e persistência do projeto original continuam válidas. Este documento detalha apresentação e decisões de UX. Novas decisões: confirmação de desbloqueio, recuperação de carregamento com limites de tempo, convite de 30 s e debounce de preferências. Não altera atributos, custos, prêmios ou número de torres.


### Estado da entrega

Pranchas, documentação, assets existentes e exemplos de componentes estão disponíveis. Não são capturas de uma experiência Roblox executada. A implementação no jogo, upload de imagens, licença e disponibilidade de fontes, áudio final e testes no Studio fazem parte da integração. O prompt para Claude fica em arquivo separado.


## Mapa de navegação e prioridades


### Fluxo principal

Entrada → Menu → Mapas → Solo ou Salas → Grupo → Carregamento → Preparação → Ondas → Resultado → Revanche ou Menu. Perfil inválido oferece Treino. Tutorial é um modo solo com três ondas e 1x. Revanche cria um novo matchId após confirmação de todos os presentes.


### Navegação secundária

Menu → Coleção → Torre → Desbloqueio ou Equipar → Aparência e Domínio. Loja é um ramo opcional e nunca bloqueia jogar. Configurações abre de qualquer origem e volta à mesma origem. A referência visual de Voltar ao menu na galeria não substitui essa pilha de retorno.


### Camadas e foco

Apenas uma tela principal; no máximo um painel contextual e um modal bloqueador acima. Abrir especialização fecha menu de alvo. Fechar modal retorna foco ao botão que o abriu, desde que ainda exista. Toasts não recebem foco e não cobrem controles. Convite é cartão discreto, sem roubar foco em combate.


### Prioridade durante combate

Informações permanentes: base, onda, sucata pessoal, slots, Pulso e velocidade. Contextuais: dono, limite, alcance, alvo, upgrade, resistências e Circuito. Não mostrar a loja. Inspecionar não pausa o mundo. Opções e saídas explicam que a partida continua.


### Desktop e atalhos

Tab percorre ações visíveis em ordem de leitura. Enter/Espaço ativa foco. 1–4 escolhem slot; U melhora quando existe uma transição única válida. Escape cancela camada local apenas quando não consumido por CoreGui. Não interferir no menu Roblox nem executar atalho ao digitar.


### Estados terminais

Won/Lost só pelo servidor. RewardPending impede apresentar saldo como salvo. Closed remove painel da partida e limpa seleção, timers, callbacks e efeitos. Ao retornar, reaproveitar componentes sem carregar comandos antigos. Dados externos atualizam o store mesmo se a tela de origem já fechou.


## Direção visual e componentes


### Materiais e identidade

Painéis parecem fichas de papel creme, com cantos arredondados, contorno azul-escuro e pequenos detalhes de fita dourada. Fundo verde suave e personagens originais trazem o tema artesanal. Decoração é não interativa e fica fora das áreas de toque. Sem metal brilhante, neon dominante ou painéis militares.


### Paleta funcional

Ink #19283F: texto e contorno. Cream #FFF3D6 e Paper #FFFAEC: superfícies. Gold #FFC857: ação primária e sucata. Teal #2FB7A0: sucesso. Coral #FF775E: atenção. Danger #B63E48: confirmação destrutiva. Cyan #63CDE8: alcance e foco. Enemy #7D63B8: inimigos. Texto secundário #526174 escurece o muted original para melhorar contraste.


### Tipografia

Títulos arredondados quando Fredoka estiver disponível e aprovada; fallback Builder Sans Bold. Corpo e números Builder Sans. As pranchas usam Arial para exportação consistente. Título 30 px, corpo 18, botão 19 e legenda 14 na referência desktop; valores finais após escala. No celular corpo mínimo 16 e ação 18 quando couber. Localização não pode depender de texto embutido em imagem.


### Geometria

Espaçamento em múltiplos de 4; preferir 8, 12, 16, 24 e 32. Painel raio 20, botão raio 12 e contorno 2 px. Sombra curta por Frame deslocado 4 px. Área clicável mínima 44×44, meta 48×48. Ícone sozinho precisa de nome acessível e descrição visível por foco ou toque.


### Biblioteca nativa

PaperPanel = Frame + UICorner + UIStroke + UIPadding. ActionButton = TextButton, UIScale e rótulo nativo. StatChip, TowerCard, LoadoutSlot, Modal, Toast, Toggle, Slider, ProgressBar, Tooltip, BossBar, TargetMenu e EmptyState são componentes compartilhados. Listas usam UIListLayout/UIGridLayout e ScrollingFrame com tamanho de conteúdo automático.


### Importação correta

Não importar a tela completa como um único ImageLabel clicável. PNGs de telas são referências. Importar somente arte e ícones necessários e montar textos, formas, barras e controles nativos. Preservar originais de assets; aplicar recorte apenas em export explícito, sem editar o arquivo fonte.


## Layout responsivo e entrada


### Área segura

Separar ScreenGui decorativa da interativa. Na interativa, usar ScreenInsets=CoreUISafeInsets e considerar dimensões efetivas da área segura; não somar GetGuiInset novamente na transformação do tabuleiro. Reservar espaço para controles nativos. Fundo pode preencher a tela toda sem conter botões.


### Breakpoints

A partir de 1100 px úteis de largura e 600 de altura: desktop com painel lateral de 278 px. Em paisagem abaixo disso: compacto, topo de 44–48 px, controles de 48 px embaixo e painel recolhível. Em tablet 4:3, usar o espaço vertical extra mantendo tabuleiro 16:10. Vertical mostra tela 30. Faixas são decisões de layout a validar com a área segura real.


### Tabuleiro

BoardTransform calcula encaixe 16:10 dentro do retângulo livre, descontando HUD e painel. Célula = larguraDoTabuleiro/16. Se menor que 36 px ao construir, ampliar a região. Salvar e restaurar zoom e pan após confirmar/cancelar. Sprites, alcance e telegraph usam a mesma transformação do mundo.


### Toque

Selecionar unidade → tocar célula → confirmar. Um dedo indica; dois dedos movem a região ampliada e cancelam seleção pendente do gesto. Botões nunca exigem segurar ou arrastar. Um toque dentro de painel é consumido ali. Mobile não usa hover como único modo de descobrir custo ou habilidade.


### Texto e localização

Todos os rótulos têm chaves em tabela de localização PT-BR/EN. Número e plural são formatados por locale. Reservar 35% de expansão, quebrar linha e rolar painéis antes de reduzir fonte. Nomes de jogador têm limite visual com reticências e versão completa na ficha. Não cortar preço, motivo de bloqueio ou verbo da ação.


### Acessibilidade

Respeitar GuiService.PreferredTextSize e ReducedMotionEnabled, observando mudanças. Combinar preferências do Roblox e do jogo: qualquer pedido de redução ativa o modo. Texto normal com contraste mínimo 4,5:1 e grande 3:1. Cor sempre acompanhada de texto, ícone ou padrão; grupo usa círculo, quadrado, triângulo e losango. Não depender de áudio ou vibração.


## Cliques e estados de componentes


### Contrato de botão

Idle → Hover/Focus → Pressed → Pending → Success ou Error → Idle. Disabled continua legível e explica o motivo. GuiButton.Activated cobre clique e toque; não registrar outra confirmação redundante em InputEnded. AutoButtonColor=false quando a aparência é controlada pelo componente.


### Confirmação

Construção exige célula e botão; venda, especialização, desbloqueio e Pulso têm confirmação contextual. Upgrade linear tem comparação inline e um clique. Durante Pending, desabilitar apenas as ações incompatíveis e manter fechar/cancelar onde seguro. Fechar a UI não cancela um comando já aceito pelo servidor.


### Resposta imediata e confirmação real

Pressionamento visual é imediato; em até 100 ms mostrar que o toque foi recebido. Sucesso e som de moeda dependem do ACK. Se exceder 1 s real, mostrar Confirmando. Aos 5 s, indicar demora e pedir reconciliação, sem presumir falha. Não reenviar compra com um novo requestId automaticamente.


### Erros e recuperação

INVALID_CELL: Escolha uma célula livre. OCCUPIED: Alguém ocupou este lugar. INSUFFICIENT_FUNDS: Faltam N sucatas ou botões conforme contexto. NOT_OWNER: Esta torre pertence a nome. LIMIT_REACHED: Limite de torres atingido. PROFILE_UNAVAILABLE: Progresso indisponível. RATE_LIMIT: Aguarde um instante. STALE_REQUEST/INVALID_STATE: atualizar estado e explicar ação não disponível.


### Feedback global

Sucesso breve em toast de 2,5 s; informação em 4 s. Erro que exige decisão permanece inline. Máximo de três toasts e deduplicação por tipo/entidade em 1 s. Não colocar toasts sobre os quatro slots ou a confirmação. Alterações de grupo não produzem som a cada snapshot.


### Áudio de UI

Quatro famílias de efeitos a produzir: toque de madeira, confirmação suave, erro discreto e mudança de painel. Cooldown local de 60 ms para cliques; erro sem alarme repetido. IDs vazios até assets licenciados e aprovados. Nenhum áudio foi incluído; até lá, feedback visual é completo. Volume de efeitos acompanha preferências e som nunca é único aviso.


## Animações e desempenho


### Relógios

Microinterações de botão, modal e toast usam tempo real do cliente. Cooldowns, aviso de chefe, preparação e 1x/2x usam simTime do servidor. A barra de recarga é derivada de readyAt, sem Tween de 60 s que fique incorreto após voto de velocidade.


### Receitas

Hover/foco: 100 ms, Quad Out, escala 1,03. Press: 80 ms até 0,97 e retorno de 100 ms. Painel: 180 ms de entrada, alpha e deslocamento de 12 px; saída 120 ms. Modal: 180 ms, escala 0,96→1 e scrim até 45%. Toast: 160 ms, deslocamento de 8 px. Arquivo animacoes.json inclui todos os estados e a versão reduzida.


### Combate e resultado

Construção: 180 ms, sprite 0,90→1. Upgrade: 350 ms, troca de silhueta no meio. Saldo: contagem visual de 200 ms; precisão lógica imediata. Resultado: painel 240 ms e até 12 partículas por 450 ms. Aviso de chefe mantém os 2 s definidos no combate, nunca encurtados por preferência visual.


### Interrupção e prioridade

Cada propriedade tem um controlador. Cancelar Tween anterior antes de criar outro para a mesma propriedade. Estado Pending/Disabled prevalece sobre hover; remover componente desconecta eventos. A morte ou fim de partida cancela callbacks cosméticos relacionados. Pooling sempre limpa estado anterior.


### Movimento reduzido

Substituir movimento e escala por preenchimento, borda e fades de no máximo 80 ms. Desligar partículas decorativas, saltos, tremor e pulsação. Avisos de gameplay continuam com rótulo, ícone e contagem. Não usar flashes em tela inteira em nenhum modo.


### Orçamentos

Um controlador de renderização para objetos ativos; não criar um loop por botão ou contador. Atualizar rótulos quando valor mudar; timers visuais no máximo 10 Hz e números inteiros só quando o segundo mudar. Limitar toasts a 3; não acumular instâncias após 30 aberturas de painel. Medir FPS e memória em dispositivos reais, sem prometer taxa fixa a partir das pranchas.


## Implementação no Roblox Studio


### Estrutura proposta

Client/UI: Theme, Motion, Components, Screens, Router, FocusManager, UIStore, CommandAdapter, BoardInput e Localization. Shared: tipos, catálogos e contratos. Server: serviços existentes de partida, party, perfil e loja. UIStore recebe snapshot/revision; componentes leem dados e emitem intenções. Não duplicar simulação ou economia.


### Camadas de renderização

WorldGui DisplayOrder 0; HUDGui 10; MenuGui 20; ModalGui 30; ToastGui 40. Esses valores são decisões locais, não substituem CoreGui. Usar ZIndexBehavior consistente em cada camada. Scrim intercepta toque no mundo; toast não é modal. Modal da compra é o nativo Roblox.


### Bindings existentes

PlaceTower, UpgradeTower, SellTower, SetTarget, CastPulse, SetReady, VoteSpeed, SetLoadout, BuyTower e StartMatch usam o protocolo existente {protocolVersion, sessionSequence, requestId, action, payload}. Guardar estado pendente por requestId. Resposta traz ok, errorCode, balance e revision. Ignorar revisões antigas, sem ignorar o resultado de uma transação válida.


### Bindings a integrar

Party precisa listar/criar/entrar/sair/convidar/responder; preferências precisam salvar; cosméticos precisam equipar; treino precisa gerar/limpar; resultado precisa consultar/revanche. Reutilizar handlers do projeto. Se não existirem, adicionar contratos explícitos e validação no servidor; nomes da galeria não são nomes de remotes. Convites expiram por relógio real.


### Assets e componentes de exemplo

exemplos/ButtonFeedback.luau demonstra escala, foco, clique e cleanup. exemplos/Theme.luau contém tokens. São auxiliares de UI, não telas implementadas nem integração validada. Assets em assets/ são cópias dos originais do projeto. manifesto_assets.json relaciona arquivos e hashes; robloxAssetId fica vazio até upload real.


### Segurança e persistência

Botão oculto não é autorização. Servidor verifica dono, fase, saldo, desbloqueio e limites em toda mutação. Sem perfil válido, nenhum default persistido. Salvo só aparece com confirmação durável. Preços de passe são obtidos pela API, nunca pela figura. Comandos de treino devem ser restritos ao modo autorizado e não conceder progresso.


## Testes de aceite e entrega


### Cobertura funcional

Percorrer todas as 49 referências e seus estados alternativos descritos. Testar tutorial completo, treino com seis torres, solo, grupo de quatro, vitória, derrota, revanche, compra de Lupa, troca de equipe e retorno de preferências. Toda ação visível deve funcionar ou explicar indisponibilidade; sem botões decorativos que parecem ativos.


### Concorrência e rede

Latência simulada 100/300/1000 ms; cliques repetidos; duas compras disputando célula; Pulso simultâneo; aliado usando recurso durante modal; venda e atualização de seleção; reconnect; snapshot antigo; recompensa pendente. Contar pedidos e confirmar que cada ação confirmada debita/concede uma vez.


### Matriz visual

844×390, 896×414, 1280×720, 1920×1080, tablet 1024×768 e vertical 390×844. Repetir com PT-BR/EN, texto ampliado, movimento reduzido e notch/insets. Nenhum botão menor que 44 px finais. Nenhum preço ou ação cortado. Tabuleiro 16:10, rota e base legíveis.


### Validação de interação

Mouse, teclado e toque real. Foco visível, retorno ao fechar modal, sliders sem arrasto obrigatório e gestos sem atravessar painéis. Cinco colocações seguidas sem erro acidental. Salvar captura real no Studio para comparar com PNG da referência; registrar divergência necessária por plataforma.


### Critério de pronto

Todos os fluxos integrados ao projeto e testes executáveis aprovados; lista objetiva de testes feitos, ambiente e resultados. Separar implementação, validação em Studio, upload e publicação. Não declarar jogo validado se apenas compilou scripts. Não publicar ou comprar nada como parte desta entrega de UI.


### Fontes e autoridade

Direção de arte, game design, especificação técnica e balanceamento existentes do projeto. Referências oficiais consultadas em 18/09/2026: ScreenGui, GuiService e guia de botões interativos no Creator Hub. URLs completos estão ao fim da versão Markdown e no LEIA_PRIMEIRO. O catálogo de telas e as medidas são decisões de design deste pacote.


## 01_entrada Entrada e perfil

Carregar perfil sem bloquear indefinidamente.

![Entrada e perfil](png/01_entrada.png)


**Quando aparece** — Ao entrar na experiência, antes de qualquer tela que dependa de dados persistentes.


**Cliques e ações** — Carregar perfil e assets essenciais em paralelo. Configurações abre preferências locais. Avançar automaticamente quando perfil válido e imagens mínimas estiverem prontos.


**Estados e feedback** — Texto por etapa, nunca porcentagem inventada. Após 10 s reais mostrar Tentar novamente e Treino; timeout não cria perfil vazio. Uma tentativa pendente por vez.


**Regras de implementação** — Dados indisponíveis levam à tela 26. Falha de imagem oferece nome e silhueta local, sem bloquear o acesso para sempre.


**Aceite** — Falhar o carregamento e repetir: nenhum perfil sobrescrito e nenhuma navegação duplicada.


## 02_inicio Menu inicial

Começar a jogar com uma única ação principal.

![Menu inicial](png/02_inicio.png)


**Quando aparece** — Perfil carregado. Primeiro acesso oferece tutorial com opção clara de pular.


**Cliques e ações** — Jogar abre mapas; Coleção abre equipe; Treino inicia modo sem progresso; Tutorial pode ser reaberto; Configurações retorna à origem.


**Estados e feedback** — Jogar é a única ação dourada dominante. Loja só existe com feature flag e produto válido; esconder seu espaço quando desativada.


**Regras de implementação** — Não inserir missões diárias, gacha, popups de compra ou menus de funcionalidades fora da versão 1. Saldo de botões vem do perfil.


**Aceite** — Um novo jogador encontra Jogar em até 5 s. Menu acessível com teclado e toque, sem hover obrigatório.


## 03_mapas Escolher mapa

Selecionar uma missão e entrar solo ou com amigos.

![Escolher mapa](png/03_mapas.png)


**Quando aparece** — Jogar a partir do menu ou alteração de mapa pelo líder.


**Cliques e ações** — Selecionar cartão muda mapa; Normal e Desafio são seleção exclusiva. Jogar solo valida e inicia; Jogar com amigos abre salas. Desafio só após vitória Normal daquele mapa.


**Estados e feedback** — Mapa bloqueado mostra sua condição em texto. Começar desabilitado explica qual integrante ainda não desbloqueou o mapa. Imagem escolhida recebe borda e marcador.


**Regras de implementação** — Dados de desbloqueio são do servidor. Normal é padrão. Não cobrar botões para entrar. No celular, um cartão por vez com anterior e próximo, sem arrasto obrigatório.


**Aceite** — Não iniciar mapa bloqueado por atalho ou pedido adulterado. Seleção preservada ao voltar das salas.


## 04_salas Salas e convites

Encontrar pessoas presentes neste servidor.

![Salas e convites](png/04_salas.png)


**Quando aparece** — Escolha de cooperação; lista limitada ao servidor atual.


**Cliques e ações** — Entrar solicita vaga atômica. Criar sala cria grupo local e torna o jogador líder. Convidar presentes abre tela 33.


**Estados e feedback** — Estados: carregando, lista disponível, vazia com Criar sala e Jogar solo, sala cheia, partida já iniciada, erro com Atualizar. Não mostrar falsa fila global.


**Regras de implementação** — Atualizações podem retirar uma vaga antes do clique: aceitar resposta do servidor e manter a lista. Impedir duas entradas simultâneas.


**Aceite** — Duas pessoas disputando a última vaga: apenas uma entra; a outra lê Sala lotada e pode tentar outra.


## 05_grupo Grupo e prontidão

Revisar equipe e confirmar que todos podem começar.

![Grupo e prontidão](png/05_grupo.png)


**Quando aparece** — Grupo formado com um a quatro integrantes.


**Cliques e ações** — Líder escolhe mapa e dificuldade; cada pessoa altera sua equipe e prontidão. Começar é exclusivo do líder e exige todos os presentes prontos. Convidar abre 33.


**Estados e feedback** — Cartões mostram nome, líder, forma do dono e pronto. Mudança de mapa, dificuldade ou membros limpa prontidão. Alterar equipe limpa a prontidão desse jogador.


**Regras de implementação** — Menu usa perfis atuais, mas congela loadouts e participantes ao começar. Saída transfere liderança ao membro mais antigo. Revanche nunca transporta quem escolheu voltar ao menu.


**Aceite** — Começar duplicado gera uma só partida. No celular, lista vertical rolável de membros e barra fixa de prontidão.


## 06_colecao Coleção e equipe

Escolher até quatro torres diferentes.

![Coleção e equipe](png/06_colecao.png)


**Quando aparece** — Menu ou preparação do grupo, fora de partida ativa.


**Cliques e ações** — Tocar personagem abre 07. Equipar adiciona ao primeiro espaço vazio; com quatro preenchidos, pedir qual substituir. Tocar espaço equipado permite remover. Salvar envia SetLoadout.


**Estados e feedback** — Identificar possuída, equipada e bloqueada com rótulos. Conta nova tem Dardo, Pipoca e Goma; quarta vaga opcional. Salvar mostra Confirmando e depois Equipe salva.


**Regras de implementação** — Até quatro IDs distintos e possuídos. Não exigir equipe cheia. Seleções locais só viram equipe real após confirmação. Em partida, permitir leitura sem editar.


**Aceite** — Rejeitar duplicata e torre bloqueada. Celular em paisagem usa a lista paginada da prancha 47; tablet alto pode usar duas colunas. Equipe permanece acessível.


## 07_torre Detalhe e desbloqueio

Entender a função antes de gastar botões.

![Detalhe e desbloqueio](png/07_torre.png)


**Quando aparece** — Seleção de uma torre na coleção; Lupa é o exemplo visual.


**Cliques e ações** — Mostrar custo de desbloqueio em botões separado do custo de construção em sucata. Desbloquear abre 32; possuída oferece Equipar, Aparência e Domínio; Experimentar abre treino.


**Estados e feedback** — Atributos vêm do catálogo, com unidades e função. Especializações mostram comparação, sem aplicar upgrade persistente. Maestro mostra bônus de cadência, não DPS zero.


**Regras de implementação** — Se saldo insuficiente, botão informa Faltam N botões e não abre loja de Robux. Dados de exemplos da imagem nunca substituem o catálogo real.


**Aceite** — Lupa exibe 240 botões para desbloquear e 500 sucatas para construir. Nenhuma troca de moeda implícita.


## 08_cosmeticos Domínio e aparência

Personalizar sem alterar atributos.

![Domínio e aparência](png/08_cosmeticos.png)


**Quando aparece** — Detalhe de torre possuída.


**Cliques e ações** — Alternar aparência, adesivo ou título muda prévia; Equipar confirma um item já possuído. Marcos de domínio: 30 adesivo, 100 título, 250 aparência.


**Estados e feedback** — Mostrar progresso atual e requisito; após equipar, selo Equipado. Aparência sem arte final ou sem ID aprovado não deve aparecer como produto acabado.


**Regras de implementação** — Skins mantêm stats, silhueta e Circuitos. Mudança de aparência em menu vale para a próxima partida; não trocar o snapshot visual de uma partida em curso.


**Aceite** — Repetir Equipar é idempotente. Estado bloqueado não envia comando de concessão. Nenhum atributo sobe com domínio.


## 09_loja Loja opcional

Exibir cosméticos com preço e posse verificados.

![Loja opcional](png/09_loja.png)


**Quando aparece** — Somente quando shopEnabled e disponibilidade permitirem; a imagem demonstra indisponibilidade segura.


**Cliques e ações** — Consultar preço real e posse do passe. Estado disponível mostra Comprar por preço recebido e abre o fluxo nativo Roblox. Possuído mostra Equipar aparências.


**Estados e feedback** — Carregando preço, indisponível, disponível, aguardando Roblox, cancelado e possuído. Cancelamento é neutro e não concede itens.


**Regras de implementação** — Não desenhar um checkout falso, fixar 149 Robux ou conceder pelo fechamento do popup. Preço e posse são verificados. Sem loja válida, esconder acesso no menu. Arte ilustrativa base não é skin à venda.


**Aceite** — Falha de consulta remove compra e mantém Voltar. Testar cancelamento, compra válida e posse anterior sem cobrança repetida.


## 10_opcoes Configurações

Ajustar conforto sem abandonar a partida.

![Configurações](png/10_opcoes.png)


**Quando aparece** — Menu ou combate; guardar origem para retornar à mesma tela.


**Cliques e ações** — Sliders Música e Efeitos com botões menos e mais; toggles de movimento, partículas, dano e padrões; idioma PT-BR/EN. Mudanças locais imediatas, salvamento agrupado após 500 ms.


**Estados e feedback** — Slider aceita clique, arrasto e teclado; passos de 5%. Toggles têm texto Ligado/Desligado e ícone. Concluído fecha; falha de salvar mostra Preferências não salvas e permite repetir.


**Regras de implementação** — Combate não pausa, mesmo solo. Respeitar preferência de movimento reduzido do Roblox junto à opção do jogo. Não ocultar CoreGui. Idioma pode ampliar o painel e provocar rolagem.


**Aceite** — Configuração persiste após reabrir. Não gerar pedidos por frame do slider nem desconectar áudio de alertas visuais.


## 11_carregamento Carregamento de partida

Mostrar progresso real e recuperar falhas.

![Carregamento de partida](png/11_carregamento.png)


**Quando aparece** — StartMatch aceito, antes de Preparation.


**Cliques e ações** — Mostrar mapa, dificuldade e equipe congelada. Carregar primeiro terreno, elenco usado e chefe do mapa. Progresso é quantidade resolvida de assets essenciais.


**Estados e feedback** — Falha parcial de imagem mantém fallback e opção repetir. Aos 10 s informar demora; aos 20 s permitir Voltar, respeitando o estado real da partida no servidor.


**Regras de implementação** — Cliente não decide quando combate começa. Se preparação já iniciou, reconciliar snapshot e mostrar tempo restante. Não reiniciar o contador para cada cliente.


**Aceite** — Imagem rejeitada não impede ver rota e botões. Com rede lenta, relógio exibido converge ao snapshot sem dupla largada.


## 12_preparacao Preparação e intervalo

Construir antes da chegada dos inimigos.

![Preparação e intervalo](png/12_preparacao.png)


**Quando aparece** — Preparation de 15 s ou Intermission de 8 s.


**Cliques e ações** — Construir continua disponível. Pronto envia SetReady; pode cancelar enquanto fase aceita. Grupo inicia mais cedo por unanimidade ativa. Intervalo troca título e mostra próxima onda.


**Estados e feedback** — Contagem deriva do fim da fase em simTime; nunca de tween. Texto Preparação ou Próxima onda. Ao zerar por servidor, botão some e HUD muda para onda ativa.


**Regras de implementação** — Não oferecer pular onda quando houver inimigos vivos. Participante ausente há 30 s deixa de contar para unanimidade. Tutorial usa checkpoints próprios.


**Aceite** — Dois cliques de pronto não iniciam duas ondas. Mudar a velocidade atualiza contagem de forma coerente.


## 13_combate Combate principal

Manter rota, recursos e ações sempre legíveis.

![Combate principal](png/13_combate.png)


**Quando aparece** — Wave ativa; UI de referência usa valores demonstrativos de uma sessão cooperativa.


**Cliques e ações** — Quatro slots selecionam torre; toque no tabuleiro seleciona entidade ou célula; Pulso abre confirmação; 2x vota; Opções abre painel sem pausar. Atalhos 1–4 e U conforme contexto.


**Estados e feedback** — Vida da base, onda, sucata pessoal, grupo e limite sempre legíveis. Alteração de saldo interpola em 200 ms apenas visualmente; autoridade e preço usam valor confirmado.


**Regras de implementação** — HUD não cobre entrada, saída ou rota. Detalhes fecham ao tocar vazio. Inimigo inspecionado abre 34. Grupo durante combate é leitura de participantes, sem editar equipe nem entrar em outra sala.


**Aceite** — Com 32 torres e chefe, ainda é possível selecionar e construir. Não há faixa comercial no combate.


## 14_posicionar Posicionar uma torre

Confirmar posição e custo antes de gastar.

![Posicionar uma torre](png/14_posicionar.png)


**Quando aparece** — Slot de torre equipado selecionado e célula candidata válida.


**Cliques e ações** — Toque na célula move o fantasma; Construir envia PlaceTower com coordenadas inteiras; Cancelar ou Esc sai sem gasto. Mostrar alcance e Circuito previsto a partir das regras reais.


**Estados e feedback** — Estados: escolhendo célula, válida, pendente, construída ou rejeitada. Construída usa escala 0,90→1 em 180 ms; só confirmar gasto e som de sucesso após ACK.


**Regras de implementação** — Sem movimento de torre após compra. Um comando pendente por ação. Outra pessoa pode ocupar célula antes do ACK; atualizar e manter fantasma para nova escolha. Limite geral e por espécie visíveis.


**Aceite** — Selecionar e cancelar dez vezes não gasta sucata. Na disputa de célula, apenas um gasto e uma torre.


## 15_posicao_invalida Posicionamento inválido

Confirmar posição e custo antes de gastar.

![Posicionamento inválido](png/15_posicao_invalida.png)


**Quando aparece** — Célula de caminho, bloqueadora, ocupada, fora do tabuleiro ou fora de alcance do input válido.


**Cliques e ações** — Mover fantasma para outra célula; Cancelar volta ao combate. Confirmar fica indisponível e traz motivo específico: Caminho, Ocupada, Limite atingido ou Faltam N sucatas.


**Estados e feedback** — Célula usa X e contorno além de cor. Nunca vibração obrigatória. Erro do servidor vira texto perto do botão, sem toast cobrindo a posição.


**Regras de implementação** — Escala de zoom não altera coordenada lógica. Toque sobre HUD nunca atravessa para o mapa. Célula inválida não manda pedido de compra.


**Aceite** — Testar quatro bordas, safe area, zoom, pan e orientação; mesma célula mostrada e enviada.


## 16_torre_selecionada Torre selecionada

Inspecionar, melhorar e alterar o alvo.

![Torre selecionada](png/16_torre_selecionada.png)


**Quando aparece** — Torre ainda ativa escolhida no tabuleiro.


**Cliques e ações** — Mostrar dono, estado, dano, intervalo, alcance e Circuito. Melhorar L0/L1 avança um estado; L2 abre 17. Alvo abre Primeiro, Último, Forte e Perto. Vender abre 18.


**Estados e feedback** — Comparação antes/depois inclui custo incremental. Apenas proprietário vê ações de mutação. Torre aliada mostra dono e atributos em leitura. L3 exibe Especialização máxima.


**Regras de implementação** — Se entidade sumir, fechar painel e limpar alcance. Comando pendente bloqueia somente suas ações. U funciona apenas com upgrade único válido e sem campo de texto focado.


**Aceite** — Não vender ou melhorar aliado. Atualizar alvo só após confirmação; manter seleção se outra pessoa construir perto.


## 17_especializacao Especialização

Comparar duas escolhas permanentes para a torre.

![Especialização](png/17_especializacao.png)


**Quando aparece** — Torre própria em L2.


**Cliques e ações** — Mostrar dois caminhos com nomes, custo incremental, atributos e função. Escolher abre confirmação específica com torre, opção e preço; confirmar envia UpgradeTower L3A ou L3B.


**Estados e feedback** — Painel comparativo preserva estado do combate. Escolha pendente impede alternativa simultânea. Sucesso troca sprite e mostra especialização no detalhe.


**Regras de implementação** — Escolha exclusiva até vender. Cancelar mantém L2. Usar dados de cada torre, não os números de Dardo em todas. Saldo insuficiente identifica valor faltante.


**Aceite** — Confirmar Rajada e tentar Fura lata no mesmo frame produz somente uma compra. Fechar modal restaura foco à opção anterior.


## 18_venda Confirmação de venda

Evitar perdas por toque acidental.

![Confirmação de venda](png/18_venda.png)


**Quando aparece** — Vender acionado em torre própria.


**Cliques e ações** — Modal informa nome, reembolso floor(investido×0,70) e impacto no Circuito. Cancelar é foco inicial; Vender confirma SellTower.


**Estados e feedback** — Botão danger com texto claro. Pendente preserva modal; sucesso fecha, remove seleção e anuncia sucata devolvida. Erro mantém mensagem ou fecha se torre já não existe.


**Regras de implementação** — Valor vem do estado confirmado do servidor. Não vender por Delete, duplo toque no mapa ou Escape. Cancelar não manda comando.


**Aceite** — Dardo L0 devolve 175; L1 com total 450 devolve 315. Repetir pedido não duplica reembolso.


## 19_chefe Chefe e aviso de habilidade

Antecipar perigo sem esconder o caminho.

![Chefe e aviso de habilidade](png/19_chefe.png)


**Quando aparece** — Chefe vivo ou habilidade com telegraph ativo.


**Cliques e ações** — Barra de chefe mostra nome, vida e estado. Aviso fixo de área no tabuleiro e texto de contagem; seleção permite ver resistência e contrajogo.


**Estados e feedback** — Aspirador: Poeira em 2 s e área fixa. Rei: escudo e Armadura 55% por 5 s após aviso. Breu: estrela e Invocação em 2 s. Evitar flashes de tela inteira.


**Regras de implementação** — Um aviso não bloqueia controles. Texto persiste no modo reduzido; fim e cancelamento seguem eventos do servidor. Vida zero só encerra quando onda realmente termina.


**Aceite** — Morte durante aviso remove telegraph; invocados existentes permanecem. HUD do boss cabe no celular sem ocultar vida da base.


## 20_pulso Pulso compartilhado

Confirmar um recurso de emergência para o grupo.

![Pulso compartilhado](png/20_pulso.png)


**Quando aparece** — Pulso disponível tocado durante combate.


**Cliques e ações** — Primeiro toque abre resumo; Usar agora envia CastPulse. Cancelar fecha. Dano mostrado usa 180×fator cooperativo, com resistência por alvo; lentidão 30% por 3 s, atenuada em chefes.


**Estados e feedback** — Disponível, confirmação, pendente e recarga com segundos restantes. Se aliado usar enquanto modal aberto, fechar e informar Pulso usado por nome.


**Regras de implementação** — Recarga compartilhada de 60 s de simulação; começa pronta. Não cobrar recurso. Não criar voto ou usar só pelo primeiro toque.


**Aceite** — Dois clientes confirmando juntos consomem uma única carga. 2x reduz o tempo real da recarga sem reduzir seu valor em simTime.


## 21_tutorial Tutorial contextual

Ensinar uma decisão por vez.

![Tutorial contextual](png/21_tutorial.png)


**Quando aparece** — Conta nova aceita tutorial ou reabre no menu.


**Cliques e ações** — Cinco passos: Dardo (3,3); iniciar onda; Goma (3,4) e Circuito; Dardo L1; concluir terceira onda. Destaque acompanha o elemento e aceita a ação real como avanço.


**Estados e feedback** — Um balão por vez. Pular explicações encerra a sequência sem conceder 180 botões; unidades iniciais permanecem. Falha reinicia checkpoint da onda.


**Regras de implementação** — Tutorial usa 1.200 sucatas e velocidade 1x. Não reutilizar números do HUD de campanha. Bloqueio de clique limitado à tarefa, mantendo opções e saída acessíveis.


**Aceite** — Uma conta recebe recompensa tutorial uma vez, após salvar. Reabrir tutorial não duplica botões; passo não avança só por fechar balão.


## 22_treino Treino

Experimentar todas as torres sem gastar progresso.

![Treino](png/22_treino.png)


**Quando aparece** — Modo solo separado da campanha, inclusive quando perfil falha.


**Cliques e ações** — Disponibilizar seis torres por seletor de elenco no painel; usar slots rápidos para as escolhidas. Seletor de inimigo inclui comuns e chefes; Gerar 1/10, limpar e alternar indicadores.


**Estados e feedback** — Exibir Treino sem recompensa e Sucata ilimitada. Limpar pede confirmação e remove entidades do treino. Especializações livres respeitam caminho de estados para demonstração.


**Regras de implementação** — Sem persistência de moedas, domínio ou compras. Catálogo de treino não modifica ownedTowerIds. Falha de perfil continua permitindo sair e tentar recarregar.


**Aceite** — Gerar chefe no treino não dá vitória de campanha. Sair devolve perfil e equipe reais intactos.


## 23_vitoria Vitória e revanche

Entender o resultado e escolher a próxima ação.

![Vitória e revanche](png/23_vitoria.png)


**Quando aparece** — Servidor confirma Won e a recompensa foi persistida.


**Cliques e ações** — Mostrar mapa, dificuldade, ondas e ganho de botões; domínio somente para torres elegíveis e desbloqueios reais. Revanche marca pronto; Voltar ao menu é decisão individual.


**Estados e feedback** — Entrada de painel 240 ms e celebração curta 450 ms, desligada em movimento reduzido. Salvo só após ACK durável. Enquanto não salvo, usar 25.


**Regras de implementação** — Vitória Normal +120 e Desafio +160. Não mostrar todos os desbloqueios em toda vitória. Revanche espera presentes, com regra de ausentes de 30 s.


**Aceite** — Uma vitória já premiada não concede novamente ao reabrir resultado. Grupo não inicia revanche sem unanimidade dos presentes.


## 24_derrota Derrota

Entender o resultado e escolher a próxima ação.

![Derrota](png/24_derrota.png)


**Quando aparece** — Servidor confirma Lost e recompensa de participação foi salva.


**Cliques e ações** — Mostrar ondas concluídas e 4×ondas, máximo 60 botões; uma dica ligada à causa observada ou dica geral sem inventar diagnóstico. Revanche e Menu.


**Estados e feedback** — Tom acolhedor, sem culpa nem ranking de dano. Falha ao salvar usa 25. Dica não exige compra ou ressurreição.


**Regras de implementação** — Sem oferta paga para continuar. Derrota tem precedência se base zera no mesmo passo da última morte. Domínio só se as condições originais forem cumpridas.


**Aceite** — Sete ondas concluídas rendem 28, não a onda em andamento. Nunca mostrar vitória porque animação de chefe acabou.


## 25_recompensa_pendente Recompensa pendente

Explicar o salvamento sem prometer saldo confirmado.

![Recompensa pendente](png/25_recompensa_pendente.png)


**Quando aparece** — Resultado conhecido mas confirmação persistente ainda não concluída.


**Cliques e ações** — Mostrar pendência sem som de moeda. Verificar novamente dispara reconciliação limitada; Menu permite sair da tela sem apagar estado pendente.


**Estados e feedback** — Confirmado muda para resultado salvo. Indisponível mantém status e orientação. Atualização automática com espera progressiva, evitando spam manual.


**Regras de implementação** — Distinguir resultado durável registrado de tentativa ainda não registrada. Só prometer consulta futura quando houver registro. Caso contrário: Não foi possível confirmar o resultado. Nenhuma promessa de recompensa recuperável sem registro.


**Aceite** — Repetir reconciliação preserva matchId e não duplica saldo. Reabrir sessão resolve registros reais pendentes.


## 26_conexao Falhas de perfil e conexão

Recuperar com opções claras e sem sobrescrever dados.

![Falhas de perfil e conexão](png/26_conexao.png)


**Quando aparece** — Falha inicial de perfil ou conexão perdida durante a sessão.


**Cliques e ações** — Perfil indisponível: Tentar novamente ou Treino. Em combate: aviso Reconectando, impedir comandos e pedir snapshot quando transporte retorna. Menu segue confirmação de saída.


**Estados e feedback** — Não apagar o tabuleiro no primeiro atraso. Após 2 s sem atualização, mostrar Sinal instável; após 5 s, reconciliação e bloqueio de novas mutações. Retomada depende do mesmo servidor.


**Regras de implementação** — Não prometer reconexão entre servidores. Sem perfil válido, nunca comprar ou salvar defaults. Se partida acabou, abrir resultado real ou menu com explicação.


**Aceite** — Simular rede lenta, indisponível e retorno: torres e carteira reconciliadas, nenhum gasto reenviado com novo ID automaticamente.


## 27_sair Sair da partida

Explicar consequências antes da saída.

![Sair da partida](png/27_sair.png)


**Quando aparece** — Sair acionado no menu de partida; também no modo vertical durante combate.


**Cliques e ações** — Cancelar retorna à seleção anterior; Sair solicita saída e volta ao menu após confirmação de estado. Texto explica ausência no resultado e combate contínuo.


**Estados e feedback** — Ação destrutiva visual em danger, Cancelar como foco inicial. Não usar frase absoluta de perda de toda a conta. Repetição fica bloqueada enquanto pedido pendente.


**Regras de implementação** — Não chamar saída do Roblox para voltar ao lobby 2D. Preferências locais e inventário persistem. Torres de ausente seguem regras do servidor.


**Aceite** — Abrir e cancelar preserva câmera e seleção. Não transportar companheiros ao menu.


## 28_mobile_combate Combate no celular

Reorganizar controles para paisagem sem reduzir alvos.

![Combate no celular](png/28_mobile_combate.png)


**Quando aparece** — Viewport em paisagem compacto; composição dedicada 844×390.


**Cliques e ações** — Topo mantém base, onda e sucata; slots ficam em faixa inferior. Opções inclui grupo e configurações. Pulso e velocidade continuam visíveis. Inimigo abre ficha compacta.


**Estados e feedback** — Tabuleiro completo mantém 16:10 e espaço livre de HUD. Células com menos de 36 px acionam modo ampliado ao construir, tela 29.


**Regras de implementação** — Botões mínimo 44 px, meta 48, após escala. Imagem exportada maior não define tamanho de toque. Em 896×414, distribuir espaço extra sem esticar o mundo.


**Aceite** — Cinco construções consecutivas com dedo sem acionar slot vizinho. Nenhuma ação depende de hover ou arrasto preciso.


## 29_mobile_posicionar Construção no celular

Ampliar a região de construção e manter confirmação acessível.

![Construção no celular](png/29_mobile_posicionar.png)


**Quando aparece** — Selecionar torre com células pequenas no celular.


**Cliques e ações** — Ampliar para célula mínima de 36 px; manter fantasma visível e painel lateral. Dois dedos movem mapa; Visão completa sai do zoom; confirmar ou cancelar restaura câmera anterior.


**Estados e feedback** — Mover não confirma. Um dedo seleciona célula; quando segundo dedo entrar, cancelar gesto de seleção pendente e iniciar pan. Soltar não compra.


**Regras de implementação** — Clamp do pan impede perder o tabuleiro. Screen→board deve descontar posição e escala reais uma vez; safe area não duplicada. Pinch opcional nunca único meio de zoom.


**Aceite** — Testar célula junto aos quatro cantos e área sob o painel: input bloqueado sobre interface, coordenada exata fora dela.


## 30_orientacao Orientação vertical

Explicar a orientação suportada e manter acesso às opções.

![Orientação vertical](png/30_orientacao.png)


**Quando aparece** — Viewport vertical ou área insuficiente para gameplay.


**Cliques e ações** — Pedir girar com ilustração simples. Configurações permanece disponível. Voltar ao menu passa por confirmação se houver partida ativa.


**Estados e feedback** — Ao girar, reconstruir layout mantendo seleção e estado. Durante combate mostrar A partida continua para evitar impressão de pausa.


**Regras de implementação** — Não forçar landscape por API sem alternativa. Não anunciar gameplay vertical otimizado. Todo menu preserva botão de saída, mesmo no telefone estreito.


**Aceite** — Girar durante modal ou pedido pendente não cria novo comando nem fecha confirmação inesperadamente.


## 31_estados Biblioteca de estados

Padronizar cliques, foco, erros, avisos e carregamento.

![Biblioteca de estados](png/31_estados.png)


**Quando aparece** — Referência de componentes, não uma tela navegável do jogo publicado.


**Cliques e ações** — Implementar botão normal, hover/foco, pressionado, indisponível e pendente. Dropdown de alvo tem quatro opções; popover 2x mostra votos, retorno 1x e participantes faltantes.


**Estados e feedback** — Toast de sucesso 2,5 s, informação 4 s; erro relevante fica inline até nova ação. Fila máxima de 3, deduplicada. Tooltip surge em foco e toque informativo, sem impedir tarefa.


**Regras de implementação** — Ícones e texto suplementam cor. Touch não fica preso em hover. A velocidade depende de unanimidade para 2x; qualquer participante pode retornar a 1x.


**Aceite** — Clicar dez vezes com 500 ms de latência envia uma única ação pendente. Encerrar painel cancela tweens e devolve foco.


## 32_desbloqueio Confirmar desbloqueio

Comprar uma torre com botões e confirmar o resultado.

![Confirmar desbloqueio](png/32_desbloqueio.png)


**Quando aparece** — Comprar torre bloqueada na coleção.


**Cliques e ações** — Confirmar mostra preço em botões, saldo atual e saldo projetado. Desbloquear envia BuyTower; cancelar volta ao detalhe. Sucesso oferece Equipar e Continuar.


**Estados e feedback** — Pendente mantém preço e bloqueia repetição. Falta de saldo apresenta valor atualizado. Já possuída é sucesso idempotente sem novo débito.


**Regras de implementação** — Preço não é enviado como autoridade. Persistência precisa confirmar antes de exibir propriedade definitiva. Nenhuma compra de Robux neste fluxo.


**Aceite** — Lupa com 300 botões deixa 60. Uma resposta atrasada de outra tela não abre modal fora de contexto, mas atualiza o estado global.


## 33_convites Convidar jogadores

Enviar convites somente a pessoas elegíveis.

![Convidar jogadores](png/33_convites.png)


**Quando aparece** — Grupo com vaga abre lista de presentes.


**Cliques e ações** — Convidar envia intenção ao servidor; destinatário recebe cartão com remetente, mapa, Aceitar e Recusar. Recusar fecha; Aceitar tenta ingresso atômico. Convite expira em 30 s reais como decisão de UI.


**Estados e feedback** — Enviado, aceito, recusado, expirado, grupo cheio e em partida. Cooldown de 5 s por destinatário; não repetir automaticamente. Mostrar convite nativo só se API disponível.


**Regras de implementação** — Servidor valida remetente, vaga, sessão e token de convite. Fechar cartão não altera partida atual; convites não forçam saída nem interrompem combate.


**Aceite** — Dois aceites para última vaga resultam em uma entrada. Convite expirado nunca é aceito só porque o botão ainda estava na tela.


## 34_inimigo Inspecionar inimigo

Entender resistência e habilidade sem interromper o combate.

![Inspecionar inimigo](png/34_inimigo.png)


**Quando aparece** — Toque no inimigo, com prioridade de torre na célula conforme seleção original.


**Cliques e ações** — Ficha mostra nome, vida atual/max, resistências e habilidade em frase curta. Fechar ou tocar vazio remove ficha. Não há comandos de ataque manual.


**Estados e feedback** — Atualizar só entidade selecionada; morte fecha e não troca automaticamente para outro inimigo. Boss usa mesma ficha com timers da habilidade.


**Regras de implementação** — Contrajogo deriva de resistência real. Não rotular Névoa como invisível nem inventar antiaéreo. Latinha tem 45% físico, não energia.


**Aceite** — Inimigo morto e sprite reutilizado não herda ficha antiga. Validação por entityId e geração do objeto.


## 35_mobile_menu Menu no celular

Manter o acesso principal sem navegação escondida.

![Menu no celular](png/35_mobile_menu.png)


**Quando aparece** — Versão compacta do menu 02.


**Cliques e ações** — Jogar dominante; Coleção e Treino na segunda linha; Configurações e Tutorial abaixo. Loja opcional fica em Coleção → Aparências quando habilitada, sem substituir Jogar.


**Estados e feedback** — Arte decorativa à direita pode diminuir ou desaparecer com fonte grande. Botões mantêm texto e altura. Saldo de botões separado da faixa de ações.


**Regras de implementação** — Não reduzir o desktop inteiro por UIScale. Menus de dados viram listas roláveis; topo e Voltar permanecem fixos.


**Aceite** — Testar 844×390 e texto ampliado: nenhuma ação sai da tela e nenhuma informação vital depende da ilustração.


## 36_mobile_detalhe Detalhe no celular

Melhorar uma torre sem cobrir sua posição.

![Detalhe no celular](png/36_mobile_detalhe.png)


**Quando aparece** — Torre selecionada no celular; folha lateral recolhível.


**Cliques e ações** — Melhorar envia upgrade único; Alvo abre lista; Vender abre confirmação; Recolher fecha. Ao abrir, reenquadrar mapa para manter torre selecionada visível.


**Estados e feedback** — Comparação compacta com unidade, expansão opcional para Circuito e atributos secundários. Folha adapta rolagem ao texto grande.


**Regras de implementação** — Esta folha lateral é a forma compacta do painel recolhível previsto no projeto. Não cobrir alvo por baixo; ajustar BoardTransform e restaurar câmera ao fechar.


**Aceite** — Abrir e recolher durante combate não move torre nem altera coordenada lógica. Botão vender nunca encosta no botão melhorar.


## 37_botoes Todos os estados de botão

Referência visual de resposta ao toque e ao teclado.

![Todos os estados de botão](png/37_botoes.png)


**Quando aparece** — Biblioteca de componentes, usada por todas as telas.


**Cliques e ações** — Implementar os oito estados apresentados em um único componente. Foco é navegação, selecionado é valor persistente de uma escolha; não confundir os dois.


**Estados e feedback** — Usar receita de animação correspondente, mas manter texto nativo. Confirmando inclui indicador discreto; no modo reduzido, usar texto estático em lugar de rotação.


**Regras de implementação** — Esta prancha não é tela do jogador. Pressionado tem compressão temporária; desabilitado não recebe ação. Foco continua visível em todos os temas.


**Aceite** — Passar por todos os estados com mouse, toque e teclado. Cada instância mantém uma só conexão de Activated e cancela efeitos no cleanup.


## 38_confirmacoes Confirmações de ações

Padronizar escolha, preço e cancelamento.

![Confirmações de ações](png/38_confirmacoes.png)


**Quando aparece** — Variantes do modal compartilhado para escolhas com consequência.


**Cliques e ações** — Especialização confirma ramo e preço. Substituição exige selecionar o slot antes do botão Trocar. Limpar remove apenas entidades do treino. Tutorial repetido explica ausência de nova recompensa.


**Estados e feedback** — Modal compartilha margens, scrim, foco inicial no cancelamento e retorno de foco. Botão principal inclui a ação específica, sem genérico Sim.


**Regras de implementação** — No modal de tutorial repetido, não precisa haver Cancelar no produto final; Continuar basta. Textos são dinâmicos por torre/valor. A referência mostra a família de modais.


**Aceite** — Confirmar uma vez, cancelar e fechar pelo teclado produzem resultados distintos e previsíveis; nunca enviar comando no simples abrir.


## 39_erros Erros e bloqueios

Dar uma ação de recuperação para cada problema.

![Erros e bloqueios](png/39_erros.png)


**Quando aparece** — Erros conhecidos retornados pelo servidor ou validados localmente.


**Cliques e ações** — Cada bloco representa um estado inline ou modal curto junto à ação original. Escolher célula restaura posicionamento. Ver minhas torres apenas muda seleção/câmera.


**Estados e feedback** — Não reiniciar interface inteira em erro. Preservar informação útil e remover pendência. Mensagem persistente some ao corrigir causa; erro de transação antiga fica em toast contextual.


**Regras de implementação** — Falta de saldo não direciona à monetização. Para taxa limitada, permitir repetir só após espera; botão não precisa piscar. Limites refletem participantes da largada.


**Aceite** — Testar todos os códigos do contrato de rede e um código desconhecido com fallback Não foi possível concluir. Tente novamente.


## 40_grupo_estados Convites e votação

Cooperação clara antes e durante a partida.

![Convites e votação](png/40_grupo_estados.png)


**Quando aparece** — Convite recebido, aceito/pendente ou mudança da velocidade e presença.


**Cliques e ações** — Convite oferece Aceitar e Recusar com alvos de 48 px; expiração remove ambos. Cancelar voto volta a 1x. Voltar a 1x envia solicitação sem exigir votação.


**Estados e feedback** — Cada cartão é exemplo independente. Prontidão e velocidade são contagens distintas. Nome, forma de dono e estado textual vêm de membros reais.


**Regras de implementação** — Recusar, desenhado como texto na prancha, deve ser TextButton com área mínima de 48 px no produto. Nenhum convite muda partida atual automaticamente.


**Aceite** — Ocultar convite expirado, remover ausente da unanimidade após regra de 30 s e reconciliar retorno pelo UserId.


## 41_boss_estados Avisos dos três chefes

Diferenciar habilidade, contagem e efeito ativo.

![Avisos dos três chefes](png/41_boss_estados.png)


**Quando aparece** — Comparação das três famílias de aviso e estado ativo.


**Cliques e ações** — Mesmo BossBar com dados específicos de cada chefe. No combate, apresentar apenas avisos dos chefes realmente ativos, nunca três painéis comparativos.


**Estados e feedback** — Aviso e efeito ativo são estados sucessivos. Poeira: contorno no chão. Escudo: ícone de lata. Invocação: estrela. A prancha compara textos; ícones funcionais devem acompanhar no produto.


**Regras de implementação** — Vida e resistência efetiva vêm do estado replicado. Sem assumir dano físico como energia. No celular usar faixa compacta abaixo do HUD e aviso curto lateral, sem cobrir rota.


**Aceite** — Cancelar aviso na morte, preservar invocados existentes e atualizar contagem em 1x/2x sem reiniciar timers.


## 42_recuperacao Carregamento e recuperação

Separar demora, falha e sucesso real.

![Carregamento e recuperação](png/42_recuperacao.png)


**Quando aparece** — Falhas de assets, sessão, transporte ou persistência.


**Cliques e ações** — Imagens faltantes usam retrato com nome e ícone neutro. Recarregar é limitado. Perfil bloqueado por outra sessão permite treino. Resultado não registrado tem mensagem diferente de pendente durável.


**Estados e feedback** — Enquanto reconecta, mostrar o último estado como desatualizado e impedir mutações. Não simular sucesso nem zerar carteira para esconder erro.


**Regras de implementação** — Continuar com fallback requer tabuleiro e controles legíveis. Bloqueio de perfil nunca autoriza salvar defaults. Tentativas usam cooldown real e não dependem de 2x.


**Aceite** — Desligar rede em cada etapa e confirmar caminho de volta. Sem estado impossível de Carregando permanente sem orientação.


## 43_colecao_estados Estados da coleção

Orientar equipe, desbloqueio e aparência.

![Estados da coleção](png/43_colecao_estados.png)


**Quando aparece** — Equipe com vaga, compra salva, partida ativa ou cosmético bloqueado.


**Cliques e ações** — Equipar Lupa após sucesso abre escolha de slot se necessário. Ver atributos é leitura. Aparência bloqueada exibe critério de domínio sem botão de compra que burle a regra.


**Estados e feedback** — Novo desbloqueio pode usar estrela e fade curto; modo reduzido mantém rótulo estático. Espaço vazio é intencional e não recebe alerta vermelho.


**Regras de implementação** — Não equipar automaticamente uma torre sem pedido. Não trocar moedas. Perfil e partida possuem snapshots distintos para preservar loadout da largada.


**Aceite** — Reabrir coleção conserva seleção e saldo confirmado; recompensas de domínio não são dadas apenas por abrir o painel.


## 44_resultados_estados Recompensas e conquistas

Mostrar apenas o progresso que foi confirmado.

![Recompensas e conquistas](png/44_resultados_estados.png)


**Quando aparece** — Conclusão tutorial, mapa liberado, marco de domínio ou revanche aguardando.


**Cliques e ações** — Apresentar no máximo um destaque por vez no resultado, com fila finita. Ação direciona à seção relevante. Cancelar pronto retira intenção de revanche antes da nova partida.


**Estados e feedback** — Tutorial +180 uma única vez. Domínio +10 por vitória somente quando elegível; marco é cruzamento real. Mapas mostram apenas novo desbloqueio daquele resultado.


**Regras de implementação** — No atraso de persistência, segurar destaque Salvo e usar tela 25. Não confundir botões com sucata restante. Revanche não bloqueia Menu.


**Aceite** — Reprocessar matchId não repete popup de ganho nem desbloqueio; fila se limpa ao sair do resultado.


## 45_menus_contextuais Menus e feedbacks de combate

Detalhes aparecem quando o jogador precisa deles.

![Menus e feedbacks de combate](png/45_menus_contextuais.png)


**Quando aparece** — Alvo, Circuito selecionado, recarga do Pulso e toast local.


**Cliques e ações** — Quatro alvos mapeiam First, Last, Strongest e Closest conforme a especificação original. Circuito mostra parceiro e bônus reais. Toast é informativo e não é botão.


**Estados e feedback** — Menu de alvo fecha após seleção aceita ou toque fora. Recarga mostra segundos inteiros e preenchimento, sem contagem negativa. Pulso usado por aliado fecha confirmação obsoleta.


**Regras de implementação** — Verificar nomes reais dos enums antes de integrar; não alterar algoritmo de alvo para adequar a tradução. Resistências também usam tooltip com descrição em uma frase.


**Aceite** — Abrir alvo não vende torre. Selecionar modo atual é idempotente. Recarregar snapshot mantém cooldown correto.


## 46_loja_estados Estados da loja

Usar preço e confirmação reais da plataforma.

![Estados da loja](png/46_loja_estados.png)


**Quando aparece** — Produto opcional em consulta, disponível, cancelado ou já possuído.


**Cliques e ações** — Estado disponível substitui {preço} pelo valor localizado retornado pela plataforma. Botão abre PromptGamePassPurchase; a confirmação visual é do Roblox. Equipar só para posse validada.


**Estados e feedback** — Nunca apresentar a expressão {preço} no jogo. Se consulta falhar ou skins não estiverem prontas, ocultar compra e usar indisponibilidade da tela 09.


**Regras de implementação** — Preço regional e disponibilidade são dinâmicos. Cancelar não é erro e não mostra penalização. A arte comercial final precisa corresponder ao conteúdo entregue.


**Aceite** — Teste consulta pendente, falha, cancelamento, posse anterior e conclusão com nova consulta no servidor antes de conceder.


## 47_mobile_colecao Coleção no celular

Navegar no elenco com rolagem e equipe fixa.

![Coleção no celular](png/47_mobile_colecao.png)


**Quando aparece** — Coleção em paisagem com pouco espaço vertical.


**Cliques e ações** — Lista horizontal com Próximo/Anterior como alternativa ao deslize; equipe e Salvar ficam fixos. Escolher cartão abre detalhe compacto. Grade de duas colunas é alternativa para tablet alto.


**Estados e feedback** — No exemplo aparecem quatro dos seis personagens; Maestro e Voltz ficam na próxima página. Navegação preserva índice e não altera equipe sozinha.


**Regras de implementação** — Com texto ampliado, reduzir decoração e trocar para lista rolável; manter 44 px mínimos. Não encolher todas as seis cartas até ficarem ilegíveis.


**Aceite** — Acessar todos os seis personagens por toque e teclado, sem depender de gesto. Voltar restaura o menu compacto.


## 48_mobile_mapas Mapas no celular

Uma escolha clara, sem cartões minúsculos.

![Mapas no celular](png/48_mobile_mapas.png)


**Quando aparece** — Seleção de mapa no layout compacto.


**Cliques e ações** — Um cartão por vez, com anterior/próximo e indicador 1 de 3. Normal/Desafio mantêm seleção exclusiva. Solo inicia após validação; Amigos abre cooperação.


**Estados e feedback** — Mapa bloqueado continua consultável com requisito e botões de iniciar indisponíveis. Começar não muda ao apenas navegar a imagem.


**Regras de implementação** — Barra inferior e cartão respeitam safe area. Trocar índice invalida Desafio se o novo mapa não o possui; explicar a condição.


**Aceite** — Percorrer três mapas sem arrasto, conferir disponibilidade por grupo e manter conteúdo sem corte em inglês.


## 49_icones Ícones funcionais

Assets transparentes separados para a implementação.

![Ícones funcionais](png/49_icones.png)


**Quando aparece** — Biblioteca funcional compartilhada entre HUD, menus e feedbacks.


**Cliques e ações** — Importar PNGs individuais de icones/ ou usar SVG como fonte de manutenção fora do Studio. Aplicar ImageColor3 para temas compatíveis. Nomes técnicos não aparecem para o jogador.


**Estados e feedback** — Ícones de 128 px possuem fundo transparente e contorno ink. Uso usual 20–28 px; ampliar alvo clicável para 44–48 px independentemente do desenho. Texto acompanha ações principais.


**Regras de implementação** — Botões persistentes usam ícone buttons e sucata usa scrap; não reutilizar o mesmo símbolo. Escudo físico é physical; energia usa energy; cura usa heal. Ícone sozinho nunca substitui a explicação de resistência.


**Aceite** — Conferir alpha, legibilidade a 24 px e labels associados. robloxAssetId fica vazio no manifesto até upload real. Não enviar SVG diretamente como ImageLabel.


## Referências oficiais

https://create.roblox.com/docs/reference/engine/classes/ScreenGui

https://create.roblox.com/docs/reference/engine/classes/GuiService

https://create.roblox.com/docs/tutorials/building/ui/interactive-buttons

https://create.roblox.com/docs/reference/engine/classes/TweenService


## Matriz de cobertura visual

**Entrada e navegação** — pranchas 01–05, 11, 33, 35, 48. Perfil, menu, mapas, salas, grupo, carregamento e convite.

**Coleção e economia** — pranchas 06–09, 32, 43, 46–47. Equipe, desbloqueio, domínio, aparência, preço, posse e cancelamento.

**Combate e seleção** — pranchas 12–17, 28–29, 34, 36, 45. Preparação, construção, validade, limite, alvo, atributos, Circuito e zoom.

**Confirmações** — pranchas 18, 20, 27, 32, 38. Venda, Pulso, saída, compra, ramo, substituição e limpeza.

**Chefes e tempo** — pranchas 19–20, 31, 40–41, 45. Avisos dos três chefes, efeito ativo, vida, recarga e votação 1x/2x.

**Aprender e experimentar** — pranchas 21–22, 38, 44. Tutorial, checkpoint, conclusão única e treino sem progresso.

**Resultados e falhas** — pranchas 23–26, 39, 42, 44. Vitória, derrota, pendência, não confirmado, rede, perfil e assets.

**Preferências e acessibilidade** — pranchas 10, 28–30, 35–37, 47–49. Áudio, idioma, redução de movimento, foco, toque, orientação e ícones.

**Feedback compartilhado** — pranchas 31, 37–46. Normal, foco, press, bloqueado, pendente, sucesso, erro, toast e tooltip.