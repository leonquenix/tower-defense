# Integração das imagens e animações

## O que mudou na versão 1.1

O projeto agora acompanha 40 PNGs individuais produzidos a partir da direção de arte. São 30 visuais de torres, três terrenos, seis objetos de cenário e um Farol de Pilha. Use esses arquivos na implementação; a prancha conceitual continua sendo referência de estilo. Este capítulo define onde localizar a arte, como integrá-la, como animar as poses disponíveis e o que ainda falta produzir.

As imagens já foram salvas em arquivos, com canal alpha verificado. Ainda não houve upload, aprovação de moderação nem integração no Roblox Studio. Os PNGs são poses estáticas em alta resolução; não são os 240 quadros de torres previstos para a animação final. O plano artístico completo do capítulo 3 continua válido.

## Pasta de trabalho e ordem de leitura

Abra no Claude Code a pasta Tower Defense indicada pelo responsável. Todos os caminhos abaixo são relativos a essa raiz; não dependa do caminho pessoal do computador, do histórico desta conversa nem de uma imagem anexada ao chat. A organização permite copiar a pasta para outro computador sem reescrever as referências.

```text
Tower Defense/
  00_COMECE_AQUI.md
  CLAUDE.md
  Quintal_em_Guarda_Documento_Completo.pdf
  Quintal_em_Guarda_Documento_Completo.docx
  Pacote_Claude_Code/
    00_LEIA_PRIMEIRO.md
    01_GAME_DESIGN.md
    02_ESPECIFICACAO_TECNICA.md
    03_DIRECAO_DE_ARTE.md
    04_TESTES_E_ACEITE.md
    05_PROMPT_PARA_CLAUDE_CODE.md
    06_CATALOGO_NUMERICO.md
    07_FONTES.md
    08_USO_DE_ASSETS_E_ANIMACOES.md
    dados/balanceamento_v1.json
    arte/
  Assets_Quintal_em_Guarda_v1/
    torres/
    fases/
    cenario/
    manifesto_assets.json
    CATALOGO.html
    PREVIA_FASES.html
    layout_fases.json
    LEIA_PRIMEIRO.md
    PROMPT_CLAUDE_INTEGRACAO.md
    prompts_geracao.json
    verificacao_arquivos.json
  asset_index.json
  runtime_asset_registry.json
  animation_plan.json
  INVENTARIO_ARQUIVOS.json
```

Comece por 00_COMECE_AQUI.md e CLAUDE.md. Leia a especificação de gameplay e técnica antes de modificar regras. Para usar a arte, leia este capítulo e asset_index.json. O catálogo HTML ajuda a escolher imagens; a prévia HTML demonstra composição, sem simular uma partida. Abra os HTMLs junto de suas subpastas, após o download completo dos arquivos.

## Estado real da biblioteca

| Grupo | Arquivos disponíveis | Uso imediato | Produção pendente |
| --- | --- | --- | --- |
| Torres | 30 PNGs de 1254 × 1254 | Repouso, melhoria, retrato e coleção | Quadros de repouso e ataque ou apoio |
| Terrenos | 3 PNGs de 1586 × 992 | Camada de chão de cada fase | Export final e ajuste da área do tabuleiro |
| Cenário e base | 7 PNGs de 1254 × 1254 | Decoração e Farol de Pilha | Efeitos opcionais e export final |
| Inimigos e chefes | Nenhum sprite neste lote | Usar visuais provisórios identificados | Oito inimigos e três chefes |
| Outros | Nenhum áudio ou skin final neste lote | Implementar pontos de integração | Áudio, efeitos, interface e cosméticos |

Cada PNG tem transparência verdadeira ao redor da silhueta. O piso dos terrenos permanece opaco e sua margem externa é transparente. A Goma tem vidro pintado por áreas de cor; não deve ficar invisível ao aplicar transparência adicional. Não remover automaticamente fundos de arquivos que já possuem alpha.

## Nomes e localização exata

Os nomes foram padronizados sem espaços nem acentos. Não renomear só para traduzir para a interface; o nome apresentado ao jogador vem da localização. Estado L0 é a base; L1 e L2 são melhorias sequenciais; L3A e L3B são alternativas finais exclusivas.

O padrão de torre é Assets_Quintal_em_Guarda_v1/torres/tower_{id}_{estado}_v001.png. Substitua {id} e {estado} pelos valores da tabela. Há exatamente cinco arquivos por torre.

| ID da torre | Estados presentes | L3A | L3B |
| --- | --- | --- | --- |
| dardo | L0 L1 L2 L3A L3B | Rajada | Fura lata |
| pipoca | L0 L1 L2 L3A L3B | Festival | Demolidora |
| lupa | L0 L1 L2 L3A L3B | Olho de águia | Observadora |
| goma | L0 L1 L2 L3A L3B | Poça | Supercola |
| voltz | L0 L1 L2 L3A L3B | Tempestade | Alta tensão |
| maestro | L0 L1 L2 L3A L3B | Orquestra | Solo |

Exemplo completo: Assets_Quintal_em_Guarda_v1/torres/tower_dardo_L3A_v001.png. Sua chave estável é tower_dardo_L3A. A extensão e o sufixo de versão pertencem ao arquivo; a chave é usada pelo jogo e pelo registro de upload.

Os terrenos ficam em fases, com os nomes map_jardim_ground_v001.png, map_oficina_ground_v001.png e map_sotao_ground_v001.png. Os objetos ficam em cenario. O inventário inclui todos os caminhos completos relativos à raiz, evitando depender de glob ou de ordem alfabética para decidir qual estado carregar.

## Qual arquivo de dados usar

asset_index.json é o índice portátil para o Claude. Seus sourceFile partem da raiz Tower Defense. Ele associa cada imagem à torre, estado ou mapa e registra dimensões, checksum e ponto de apoio sugerido. manifesto_assets.json é o registro original da geração; seus localFile partem da pasta Assets_Quintal_em_Guarda_v1. Não concatenar essas duas bases por engano.

runtime_asset_registry.json é o modelo de registro de integração. Começa com os 40 IDs Roblox vazios e status pending_upload. Preencha exportFile, robloxAssetId, status e dimensões efetivamente importadas somente quando existirem. Gere Config/Assets.luau desse registro e valide sua cobertura contra asset_index.json. Não alterar o manifesto original para fingir que uma imagem foi publicada.

animation_plan.json descreve movimentos, duração, comportamento em 2x e quadros futuros. Trata-se de configuração e especificação; não contém um animador implementado. As imagens continuam sendo os mesmos 40 originais. O arquivo INVENTARIO_ARQUIVOS.json permite verificar que os documentos, imagens e dados foram copiados integralmente.

## Preparação para renderização

Preserve os originais. Gere cópias em assets/export durante a implementação, sem gravar por cima de torres, fases ou cenario. Para sprites de torres, prepare fonte normalizada em 512 × 512 e export de 128 × 128, como definido na direção de arte. A área desenhada deve respeitar a margem de segurança, com apoio em (0,5; 0,82) no quadro normalizado. Produza miniaturas maiores separadas se a coleção precisar delas.

Os originais têm enquadramentos diferentes. anchorNormalizedSuggested foi estimado pela região dos pés e precisa de revisão; contentBoundsPx considera pixels com alpha de pelo menos 128 e não é uma máscara de recorte. Preserve a suavização de bordas. Aplique uma transformação de escala uniforme e translação por arquivo, validada com os cinco estados lado a lado. Se um acessório não couber, reduza a família inteira ou ajuste explicitamente o enquadramento; não corte lunetas, orelhas ou alto-falantes.

Mantenha a escala aparente do corpo coerente entre níveis. Não normalize cada torre apenas pela largura total: a cauda de Dardo e os alto-falantes de Maestro fazem parte da silhueta. No código, o ponto lógico da célula pertence a um contêiner estável; a imagem é filha dele. Ajustes visuais e animações ocorrem nessa filha, sem mover a célula ou mudar a seleção.

Para os três terrenos, a pequena diferença entre a proporção original e 16:10 deve ser resolvida na exportação por enquadramento ou margem. Não inferir o caminho pelo desenho do piso. Mantenha um fundo sólido coerente abaixo da imagem para que a margem transparente não revele uma área branca ou o ambiente 3D.

## Upload e carregamento no Roblox

Prepare e revise os exports, importe as imagens pela ferramenta de assets do Studio usando o proprietário da experiência, aguarde o resultado e registre os IDs reais. Verifique acesso na experiência de destino e teste o carregamento no cliente. Rojo sincroniza a estrutura de código, mas o projeto ainda precisa referenciar os conteúdos importados. Consulte o [Asset Manager](https://create.roblox.com/docs/projects/assets/manager) para o fluxo vigente.

Um sprite estático usa ImageLabel com fundo da interface transparente, imagem visível e proporção preservada. Não aplicar o recorte de um atlas a um PNG individual. Apenas exports em atlas usam ImageRectOffset e ImageRectSize. Essas propriedades estão na referência de [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel); os nomes de pastas, escalas e âncoras deste capítulo são decisões deste projeto.

Carregue apenas o mapa e as unidades necessários à partida, incluindo os estados de melhoria que podem ser usados. Pré-carregue um conjunto limitado, trate falhas e limite a espera de carregamento na interface. Mantenha um visual de reserva legível se o asset não estiver disponível e registre sua chave. A documentação de [ContentProvider](https://create.roblox.com/docs/reference/engine/classes/ContentProvider) descreve o carregamento; não interprete download concluído como aprovação artística ou teste de desempenho.

## Montagem das fases

Use o terreno correspondente ao mapId. Desenhe o caminho em uma camada separada a partir de dados/balanceamento_v1.json, com segmentos ortogonais, entrada, saída e largura coerentes com a grade de 16 × 10. Mantenha as camadas de chão, caminho, Circuitos, sombras, entidades, efeitos e seleção nas faixas definidas na especificação técnica.

O Farol de Pilha representa a base na saída. Props decorativos ficam nas células bloqueadas ou fora da área interativa, sem alterar colisão ou esconder torres. layout_fases.json e PREVIA_FASES.html são exemplos de apresentação: seus caminhos reproduzem o catálogo, mas as posições de torres são demonstrativas. O balanceamento_v1.json continua prevalecendo para gameplay.

## Movimento possível com as imagens atuais

É possível dar vida ao jogo imediatamente por escala, pequeno deslocamento e rotação do sprite inteiro. Isso não cria quadros desenhados nem permite mover isoladamente braços, olhos ou armas. Não deformar a identidade para simular articulações que não existem. Use animação procedural como apresentação inicial identificada e mantenha a troca futura para atlas desacoplada das regras.

As metas abaixo são parâmetros iniciais de movimento. Duração se refere ao tempo de simulação, exceto interações de interface. Normalize amplitudes pelo tamanho exibido e preserve os pés sempre que possível. [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService) oferece interpolação; a divisão em contêiner lógico e visual e os valores propostos são decisões do projeto.

| Torre | Repouso com uma pose | Ataque ou apoio com uma pose |
| --- | --- | --- |
| Dardo | Escala vertical até 1,015 em 1,6 s | Recuo visual de até 3 px em 128 px e retorno em 0,22 s |
| Pipoca | Respiração discreta até 1,015 em 2 s | Compressão vertical até 0,94 e retorno em 0,30 s |
| Lupa | Escala vertical até 1,008 em 2,4 s | Recuo de até 2 px e retorno em 0,24 s |
| Goma | Largura até 1,02 e altura até 0,98 em 1,8 s | Compressão até 0,95 e retorno em 0,28 s |
| Voltz | Escala vertical até 1,025 em 1,2 s | Compressão até 0,92 e retorno em 0,20 s |
| Maestro | Inclinação de até 1 grau em 1,4 s | Escala até 1,03 em 0,30 s, no máximo um pulso visual por segundo |

Limite por padrão os movimentos aos sprites ativos na tela. Em movimento reduzido, desligue os ciclos contínuos, inclinação e deslocamento; mantenha mudança de estado e feedback curto no contorno. Não aplicar tremor global ou flashes de tela inteira. Sombras são elementos separados e não devem pulsar com a mesma intensidade do personagem.

Construção pode usar escala de 0,85 a 1 em 180 ms. Melhoria troca a imagem uma vez no meio de uma transição de 350 ms, preservando o apoio. Venda remove a representação depois da confirmação do servidor. Não use uma sequência L0 L1 L2 como animação de ataque: são estados de gameplay diferentes.

## Autoridade e ciclo do animador

O servidor resolve aquisição de alvo, dano e cooldown conforme o capítulo técnico. O cliente recebe um evento cosmético de ataque com entityId, attackSeq, simTime e informação mínima dos alvos confirmados. Deduplicar por entityId e attackSeq. Mudar a imagem ou terminar um tween nunca causa dano nem concede recompensa.

Projéteis, correntes e impactos são apresentação. Como o dano é instantâneo na simulação, o projétil pode ser breve; uma morte confirmada não espera a imagem alcançá-la. Um cliente lento pode omitir efeitos antigos, preservando o estado correto. Não enviar um comando de dano ao servidor a partir da animação.

Use um controlador central no cliente com atualização por delta de tempo. Mantenha posição lógica, transformação visual e seleção independentes. Idle só atua quando não há ação de maior prioridade. Ao atacar, cancela ou suspende o idle; ao concluir, restaura escala 1, rotação 0 e deslocamento zero antes de retomá-lo. Melhoria substitui a textura e reinicia a apresentação; remoção cancela tudo e libera conexões e efeitos.

Em 2x, animações de combate acompanham o relógio de simulação e ficam mais curtas em tempo real; cliques e painéis mantêm duração de interface. Se usar tweens de tempo real, calcule a duração efetiva e reconcilie ao mudar a velocidade. Um controlador por simTime facilita essa consistência. Não empilhe centenas de tweens, task.waits ou conexões por torre.

## Plano para animação desenhada

Produza quatro quadros de repouso e quatro de ataque ou apoio para cada estado. Isso corresponde a oito quadros por estado, 40 por personagem e 240 para as seis torres. As 30 imagens entregues são guias de identidade e pose, não 30 atlas. Não preencher quadros futuros com cópias iguais e declarar a animação concluída.

| Colunas no atlas | Conteúdo | Reprodução |
| --- | --- | --- |
| 0 a 3 | Repouso | Ciclo de quatro quadros |
| 4 a 7 | Ataque ou apoio | Uma passagem e retorno ao repouso |

As linhas 0 a 4 correspondem a L0, L1, L2, L3A e L3B. Um atlas de 1024 × 1024 com quadros de 128 × 128 tem oito colunas e oito linhas; as três linhas finais permanecem transparentes. Cada personagem recebe um atlas. A fórmula de offset é coluna × 128 e linha × 128, sem borda externa que altere a conta. Preserve margens internas, apoio e proporção em todos os quadros.

Use 12 fps como referência de leitura. Quatro quadros duram aproximadamente 333 ms; ajuste a duração de ataque ou o fps da ação para coincidir com o movimento aprovado, sem mudar o intervalo de dano. O manifesto de runtime deverá mudar de single_static para atlas apenas depois que o arquivo de atlas existir e seus recortes forem validados.

Para cada torre, desenhe antecipação, ação, recuperação e repouso coerentes com sua função. Dardo recua o disparador; Pipoca comprime o casco; Lupa ajusta a luneta; Goma movimenta a massa dentro do pote; Voltz comprime a mola; Maestro movimenta pinças e alto-falantes. Quando esses movimentos exigirem partes internas, produza quadros ou camadas próprios, mantendo o contorno e os materiais existentes.

Inimigos e chefes seguem o plano do capítulo 3: 96 quadros para os oito inimigos e 48 para os três chefes. Nada desse grupo foi incluído neste lote. Skins, efeitos e áudio também precisam de produção e aprovação próprias.

## Critérios de integração concluída

A integração inicial está pronta quando os 40 arquivos são localizados pelo índice, cada estado mostra a imagem correta, os apoios não saltam ao melhorar, as três fases respeitam o caminho canônico e a transparência funciona sobre os três terrenos. Verifique os sprites a 128 px e no tamanho efetivo do celular, inclusive as especializações mais largas.

Teste compra, melhoria, venda, ataque durante melhoria, mudança 1x para 2x, movimento reduzido, encerramento de partida, reuso do pool e falha de imagem. Nenhuma dessas ações pode duplicar dano, deixar animação presa ou acumular conexões. Perfis de desempenho devem usar os exports reais; tamanho comprimido dos PNGs não substitui medida de memória.

Registre separadamente arte importada, movimentos procedurais implementados, atlas produzidos e testes executados no Studio. A definição de pronto para animação final exige os quadros desenhados previstos e sua revisão em jogo. Um relatório deve informar pendências concretas, sem declarar animação final apenas porque a pose estática se moveu.
