# Monstrinhos e chefes reutilizáveis — Quintal em Guarda

Entrega de 17 de setembro de 2026: oito inimigos comuns e três chefes, em 11 PNGs RGBA individuais de 1254 × 1254, com transparência real. Cada arquivo contém uma pose base completa. Nenhuma imagem inclui texto de nível, cenário, barra de vida ou efeitos de habilidade permanentes.

## Estado da entrega e relação com o documento principal

Este complemento atualiza o inventário da versão 1.2 do documento principal: agora existem 51 imagens de jogo, somando as 40 anteriores e estas 11. As referências antigas a “nenhum sprite de inimigos e chefes” deixam de valer. O game design e os números continuam no documento principal e em dados/balanceamento_v1.json. Os 96 quadros desenhados dos inimigos e os 48 dos chefes continuam pendentes; estas 11 poses não são atlas nem animações quadro a quadro. Não houve upload ou teste no Roblox Studio.

## Onde estão os arquivos

Na raiz do projeto, mantenha Assets_Inimigos_Bosses_v1 ao lado de Assets_Quintal_em_Guarda_v1 e Pacote_Claude_Code. Os caminhos sourceFile do índice principal partem dessa raiz. Os caminhos localFile do manifesto deste complemento partem de Assets_Inimigos_Bosses_v1.

Abra CATALOGO.html para visualizar as imagens, trocar a cor de fundo e baixar cada PNG. O catálogo inclui uma demonstração de movimentos sobre as poses estáticas; não é o jogo Roblox. Os prompts utilizados estão em prompts_geracao.json e a verificação de dimensões, transparência e integridade está em verificacao_arquivos.json.

| ID do jogo | Personagem e função | Arquivo dentro deste complemento |
| --- | --- | --- |
| fiapo | Fiapo — Básico | inimigos/enemy_fiapo_base_v001.png |
| corrisco | Corrisco — Veloz | inimigos/enemy_corrisco_base_v001.png |
| bolota | Bolota — Pesado | inimigos/enemy_bolota_base_v001.png |
| latinha | Latinha — Armadura física | inimigos/enemy_latinha_base_v001.png |
| nevoa | Névoa — Resistência à energia | inimigos/enemy_nevoa_base_v001.png |
| remendo | Remendo — Cura | inimigos/enemy_remendo_base_v001.png |
| casulo | Casulo — Divide ao morrer | inimigos/enemy_casulo_base_v001.png |
| brutamontes | Brutamontes — Bruto resistente | inimigos/enemy_brutamontes_base_v001.png |
| aspirador | Aspirador Rabugento — Pulso de poeira | bosses/boss_aspirador_base_v001.png |
| rei_ferrugem | Rei Ferrugem — Ciclo de armadura | bosses/boss_rei_ferrugem_base_v001.png |
| breu | Breu debaixo da cama — Invoca Corriscos | bosses/boss_breu_base_v001.png |

## Como reutilizar em todos os níveis

Busque a arte pelo ID do tipo de inimigo, nunca pelo número da onda ou pelo mapa. Exemplo: fiapo usa sempre enemy_fiapo_base. A mesma imagem serve no Jardim, na Oficina e no Sótão, no Normal e no Desafio, com um a quatro jogadores. O servidor aplica os atributos e multiplicadores canônicos; o sprite não decide vida, velocidade, recompensa ou dano.

Os chefes também são independentes do cenário. A campanha mantém as associações originais: Jardim → aspirador, Oficina → rei_ferrugem, Sótão → breu. Outras associações podem reutilizar a arte se um novo modo for especificado, sem exigir redesenho. Este pacote não altera as ondas nem acrescenta chefes às fases automaticamente.

Reutilize Fiapo em escala visual 0,7 para os filhos do Casulo. A ausência de recompensa desses filhos é regra do servidor, não uma característica do PNG. Os Corriscos invocados por Breu usam o mesmo sprite de Corrisco. Registre origem e regras da invocação separadamente.

Para dificuldade, elite ou modificadores futuros, mantenha a silhueta e use rótulos, ícones e efeitos separados. Não crie nem publique cópias da mesma imagem por nível. Uma cor diferente sozinha não deve ser a única indicação de resistência ou habilidade. Não implemente novos modificadores de combate sem especificação.

## Escala, apoio e preparação

Preserve os 11 originais. Gere exports em assets/export durante a integração: 128 × 128 para inimigos e 256 × 256 para chefes, normalizando a silhueta com margens e sem cortar seus detalhes. Evite gerar o atlas final repetindo a mesma pose e declará-lo animado.

O manifesto registra contentBoundsPx com limiar de alpha 128 apenas para medir a silhueta principal; isso não é uma máscara de recorte. Há pixels suaves nas bordas e o alpha original deve ser preservado. As âncoras sourceAnchorSuggested são estimativas visuais e exigem validação no tabuleiro. Recomenda-se normalizar o ponto de apoio em (0,5; 0,82) nos exports e atualizar o registro de runtime após medir o resultado.

enemy_visuals.json propõe a largura visível de cada personagem em células. Não aplique a mesma largura de quadro a todos os originais, pois as margens variam. Ao usar diretamente um original quadrado, largura do quadro em células = largura visível desejada × sourceWidth / (contentBoundsPx[2] − contentBoundsPx[0]). Preserve a proporção e use o apoio indicado, sem confundir margem transparente com tamanho do corpo. Após normalizar os exports, recalcule essa relação.

O ponto lógico acompanha o caminho. A imagem é filha de um contêiner visual, onde ocorrem salto e compressão. Barra de vida, ícones, seleção e efeitos de habilidade ficam separados. Não gire o personagem inteiro nas curvas do caminho nem espelhe costuras e acessórios automaticamente. Para Névoa, use um apoio virtual sob o corpo flutuante.

## Movimentos reutilizáveis com uma pose

Os parâmetros em enemy_visuals.json descrevem movimentos a implementar. Fiapo pode saltar levemente; Corrisco oscilar ao correr; Bolota comprimir devagar; Latinha e Brutamontes marcar passos; Névoa flutuar; Remendo e Casulo balançar discretamente. Os chefes usam movimento contido para preservar legibilidade. Todos usam a mesma imagem entre repouso e deslocamento.

No impacto, faça um contorno curto ou uma pequena variação de cor e restaure o estado. Ao morrer, use desaparecimento de aproximadamente 0,3 s e efeitos separados, depois devolva o objeto ao pool. As ações dependem de eventos confirmados do servidor; a animação nunca gera dano ou recompensa.

As habilidades precisam de efeitos próprios: pulso ao redor do Aspirador, símbolo de armadura no Rei Ferrugem, aviso e efeito de invocação de Breu, costura destacada ao curar com Remendo. A pose atual não permite mover a mangueira ou fechar placas isoladamente. Para isso, produza quadros desenhados ou camadas novas. Respeite os dois segundos de aviso dos chefes definidos no balanceamento.

Use um controlador central, baseado no tempo da simulação e na identidade da entidade. Em 2x, acompanhe o tempo da partida. Ao remover ou reutilizar a entidade, cancele seus efeitos e restaure escala, transparência e rotação. Movimento reduzido desliga os ciclos decorativos, preservando deslocamento lógico e avisos legíveis.

## Integração no Roblox e aceite

Use asset_index.json e runtime_asset_registry.json do pacote consolidado. No complemento isolado, use manifesto_inimigos_bosses.json para acrescentar os 11 registros sem apagar os 40 anteriores. Importe os exports, preencha apenas os IDs reais retornados e verifique acesso à experiência. Os campos vazios de upload são intencionais. Não aplique recortes de atlas às poses individuais.

Confira os 11 personagens sobre fundos claros e escuros, no tamanho de jogo e com a transparência ativa. Valide que Corrisco, Bolota e Brutamontes continuam distintos em tela pequena; que os chefes não ocultam o caminho ou a base; que os pés não saltam ao mudar de estado; e que todos os IDs canônicos têm arte. Teste a mesma imagem nas três fases, nas duas dificuldades e no cooperativo. A confirmação em Studio ainda deve ser registrada pelo implementador.
