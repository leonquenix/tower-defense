# Mensagem para integrar os assets no Claude Code

Integre `Assets_Quintal_em_Guarda_v1` ao projeto Roblox Quintal em Guarda seguindo o pacote de especificação já entregue. Leia `LEIA_PRIMEIRO.md` e `manifesto_assets.json`, e veja os PNGs antes de modificar a apresentação.

Use as 30 imagens de torres como estados estáticos L0, L1, L2, L3A e L3B dos seis personagens. Respeite os IDs do catálogo e não altere dano, custos ou progressão para combinar com o desenho. Troque a imagem ao melhorar a torre e preserve seu ponto de apoio no tabuleiro. Cada PNG tem um único quadro e não deve ser interpretado como atlas.

Preserve originais e crie exports de distribuição com alpha, proporção e escala consistentes, conforme a direção de arte. Normalize as margens e pontos de apoio das torres antes de montar atlas futuros. Valide as sugestões de âncora do manifesto em uma cena de teste e evite saltos de posição ao melhorar. Faça a exportação como etapa reproduzível, sem remover pixels do contorno nem adicionar fundo. Mantenha textos e números fora das imagens.

Use os três terrenos como camada de chão. Renderize o caminho em camada separada, exatamente a partir das coordenadas de `dados/balanceamento_v1.json`. O chão não é máscara de construção. Posicione o Farol de Pilha na saída e os seis props em áreas decorativas ou células bloqueadas previstas, sem ocultar o corredor ou células válidas.

Integre os arquivos ao manifesto de assets do jogo com nomes estáveis e campos separados para caminho local e ID Roblox. Não invente IDs nem diga que houve upload ou aprovação sem evidência. Na ausência de acesso à conta, deixe os campos de ID vazios, implemente o ponto de integração e registre em MANUAL_ACTIONS.md a lista de arquivos a enviar e campos a preencher.

Carregue apenas os visuais necessários à partida. Teste as torres a 128 px e em tamanhos efetivos menores, sobre os três terrenos. Garanta legibilidade de rosto, arma e especialização, alinhamento dos pés, ausência de recorte e transparência correta. Verifique celular e computador no Studio se houver acesso; caso contrário, registre esses testes como pendentes.

As imagens deste pacote já existem e devem ser utilizadas. Não volte a substituí-las pela prancha conceitual antiga nem trate as poses estáticas como animações completas. Faça o visual inicial funcionar com elas e mantenha a produção de animações, inimigos, chefes e skins como etapas explicitamente identificadas.
