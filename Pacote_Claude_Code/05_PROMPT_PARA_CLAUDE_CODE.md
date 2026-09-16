# Instrução de implementação para Claude Code

Abra a pasta Tower Defense completa no Claude Code e copie a mensagem abaixo. Mantenha documentos, imagens e índices na organização entregue. A pasta contém documentação e recursos de arte; ainda não contém o jogo Roblox implementado.

## Mensagem para iniciar

Você é responsável por implementar o jogo Roblox Quintal em Guarda a partir deste pacote. Construa a versão 1 completa descrita, em Luau com tipagem estrita e Rojo. Trabalhe no repositório atual, preserve alterações existentes e leia instruções locais antes de editar.

Na raiz Tower Defense, leia primeiro 00_COMECE_AQUI.md e CLAUDE.md. Dentro de Pacote_Claude_Code, leia 00_LEIA_PRIMEIRO.md, 01_GAME_DESIGN.md, 02_ESPECIFICACAO_TECNICA.md, 03_DIRECAO_DE_ARTE.md, 04_TESTES_E_ACEITE.md, 06_CATALOGO_NUMERICO.md, 08_USO_DE_ASSETS_E_ANIMACOES.md e dados/balanceamento_v1.json. Leia também asset_index.json, runtime_asset_registry.json e animation_plan.json na raiz. Consulte 07_FONTES.md quando precisar confirmar uma API. Veja as imagens de arte antes de implementar a interface. O JSON é canônico para números; os textos definem semântica, experiência e qualidade visual. Identifique conflitos concretos antes de alterar essas decisões.

Entregue gameplay realmente 2D por ScreenGui, com simulação autoritativa no servidor, caminho fixo e sprites. Não converta o produto em mundo 3D ou apenas em protótipo de interface. O produto obrigatório inclui tutorial, treino, seis torres e seus trinta estados, três Circuitos, oito inimigos, três chefes, três mapas, vinte ondas, duas dificuldades, Pulso de Luz, cooperação de até quatro pessoas, coleção, domínio, persistência, resultado, revanche e configurações. A loja de passe cosmético deve poder permanecer desativada sem afetar o jogo.

Comece inspecionando ferramentas disponíveis, o estado do repositório e acesso ao Studio. Registre um plano por marcos M0 a M6 com critérios de verificação, e então implemente. Não pare depois de propor o plano, desenhar telas ou terminar a primeira fase. Continue até concluir o escopo implementável e verificar as partes acessíveis. Se uma dependência externa bloquear algo, registre a pendência específica e avance nas demais partes independentes.

Crie um projeto que possa ser sincronizado com Rojo e aberto no Roblox Studio, com dependências fixadas e instruções reproduzíveis. Gere os módulos de configuração a partir do JSON e escreva validações para IDs, custos, ondas e caminhos. Use módulos de regras puras para combate, alcance, Circuitos e recompensas. Não coloque economia ou decisão de dano no cliente. Nenhum RemoteEvent pode aceitar dano, preço ou resultado arbitrário enviado pelo jogador.

Construa primeiro uma partida curta do início à vitória e derrota; depois complete as torres, Circuitos, conteúdo e cooperação. Implemente as regras completas, incluindo empate, acumulação de efeitos, dono, limites, desconexão e duplicação de pedidos. Não substitua funcionalidades obrigatórias por TODOs silenciosos. Evite sistemas extras fora do escopo e abstrações que não ajudem o produto.

Use o catálogo como balanceamento inicial. Execute testes das regras e documente alterações justificadas por simulação ou playtest. Não declare que os números estão equilibrados sem evidência. Preserve a viabilidade da equipe inicial e a diferença entre especializações. Qualquer mudança numérica deve atualizar o JSON, os módulos gerados e os testes relevantes.

Implemente o fluxo visual usando os 40 PNGs existentes em Assets_Quintal_em_Guarda_v1, localizados por asset_index.json. São 30 estados estáticos de torres, três terrenos e sete imagens de cenário e base. Preserve os originais, prepare exports, valide apoios e preencha IDs somente após upload real. Implemente movimentos procedurais conforme animation_plan.json e capítulo 8, sem confundi-los com atlas finais. Produza depois os quadros de animação, inimigos, chefes e demais assets ausentes. Se uploads ou ferramentas de arte estiverem indisponíveis, mantenha a integração preparada, use visuais provisórios identificados somente onde necessário e registre as pendências.

Nunca invente IDs Roblox, sons licenciados, passes, experiência publicada, credenciais ou resultado de moderação. Configure placeholders tipados e desligamento seguro para recursos externos. Guarde scripts e documentação no repositório. Quando houver ferramentas disponíveis, produza o build de lugar e registre o caminho real.

Valide com testes automatizados de regras, análise estática e testes reais no Studio. Priorize os cenários de 04_TESTES_E_ACEITE.md, incluindo compras simultâneas, recompensa duplicada, DataStore indisponível, quatro clientes e interface de celular. Se não puder executar Studio, mantenha uma lista explícita dos testes não executados e das ações necessárias; não use essa limitação como motivo para deixar módulos implementáveis incompletos.

Ao concluir cada marco, registre o que mudou, o que foi verificado e o que falta. Ao concluir a execução, entregue código, estrutura Rojo, dados, assets disponíveis, manifesto, SETUP.md, TEST_REPORT.md e MANUAL_ACTIONS.md. Diferencie claramente código implementado, experiência testada, arte integrada e publicação. Não publique nem efetue compras em conta externa sem autorização do responsável.

Considere o objetivo concluído somente quando o escopo obrigatório implementável estiver entregue, as verificações disponíveis tiverem sido executadas e qualquer pendência externa estiver descrita de forma acionável. O relatório final deve citar falhas reais e limitações, sem afirmar que uma experiência comercial completa foi validada apenas porque os arquivos foram gerados.

## Instrução para retomar uma execução interrompida

Leia o pacote de especificação e o registro de marcos do repositório. Verifique o estado atual do código e o último relatório de testes. Continue do primeiro requisito obrigatório incompleto; não recomece o projeto nem substitua regras já implementadas sem motivo. Atualize testes e documentação junto com cada mudança e prossiga até a conclusão do escopo acessível.
