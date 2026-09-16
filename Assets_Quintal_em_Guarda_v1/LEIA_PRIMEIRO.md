# Quintal em Guarda — biblioteca de arte estática v001

40 imagens PNG individuais, seguindo os personagens e materiais da proposta original. Os arquivos foram gerados com a ferramenta integrada `image_gen`; os prompts finais e as referências constam em `prompts_geracao.json`.

## Conteúdo

- `torres/`: 30 imagens, uma por personagem e estado. Dardo, Pipoca, Lupa, Goma, Voltz e Maestro têm L0, L1, L2, L3A e L3B.
- `fases/`: três terrenos vistos de cima — Jardim de Papel, Oficina de Lata e Sótão das Estrelas.
- `cenario/`: seis peças decorativas e o Farol de Pilha, cada um em um PNG separado.
- `CATALOGO.html`: galeria local com busca, filtros, troca de fundo e visualização em 128 px. Abra depois de extrair o ZIP e mantenha as subpastas ao lado do HTML.
- `PREVIA_FASES.html`: montagem estática das três fases com troca de cenário, nível das torres e grade. Os caminhos seguem os dados do projeto; as posições de torres são exemplos visuais, não estratégias validadas.
- `manifesto_assets.json`: dimensões reais, nomes, estados, transparência, limites da silhueta e sugestão de ponto de apoio.
- `PROMPT_CLAUDE_INTEGRACAO.md`: mensagem pronta para integrar este pacote ao jogo.

## Transparência

Cada PNG possui canal alpha real. O fundo quadriculado exibido na galeria é apenas uma forma de inspecionar o recorte e não faz parte do arquivo. Os corpos dos personagens são pintados de forma opaca, inclusive o vidro estilizado da Goma, para manter a leitura em qualquer chão.

Nos terrenos, o piso é opaco e somente a margem externa é transparente. Um chão inteiramente transparente deixaria de aparecer. Os caminhos não estão pintados no piso: devem ser montados em outra camada, usando as coordenadas canônicas do pacote de game design. Assim, imagem e colisão não precisam seguir uma curva aproximada desenhada por IA.

## Uso no projeto

Copie esta pasta para o repositório junto de `Pacote_Claude_Code`. Preserve os originais. Os PNGs podem ser selecionados e importados individualmente; os IDs Roblox ainda não existem e precisam ser preenchidos após upload e aprovação.

Cada arquivo de torre é **uma pose estática**, não um atlas de animação. Use como visual de repouso, melhoria, retrato ou seleção. Não interprete a troca de L0 para L1 como quadros de animação. Os quadros de ataque, apoio e movimento previstos no documento original ainda devem ser produzidos.

As dimensões reais dos originais estão no manifesto. Eles são fontes em alta resolução; o tamanho pedido no prompt não é uma garantia do tamanho entregue pela ferramenta. Para a versão de distribuição, exporte cópias normalizadas para o tamanho definido na direção de arte, preservando alpha, proporção e ponto de apoio. Não carregue todos os originais em alta resolução de uma vez na partida.

O campo `anchorNormalizedSuggested` é estimado pelos pixels opacos perto dos pés, não medido no Roblox Studio. Ajuste o apoio e a escala por personagem em uma cena de teste, especialmente caudas, lunetas e alto-falantes largos. A margem e o enquadramento variam entre os originais. Não estique a imagem para caber na célula.

Monte cada fase nesta ordem: chão; caminho exato da grade; sombras leves; torres e inimigos; efeitos e interface. Coloque plantas, pedras, livros e ferramentas fora das células jogáveis, ou apenas nas células bloqueadas previstas nos dados. Decoração não define colisão.

## Correspondência das especializações

| Torre | L3A | L3B |
| --- | --- | --- |
| Dardo | Rajada | Fura lata |
| Pipoca | Festival | Demolidora |
| Lupa | Olho de águia | Observadora |
| Goma | Poça | Supercola |
| Voltz | Tempestade | Alta tensão |
| Maestro | Orquestra | Solo |

## Verificação

Foi feita inspeção visual dos resultados e verificação de leitura, formato PNG, canal alpha, dimensões, integridade e nomes. `verificacao_arquivos.json` registra os resultados. O pacote não foi importado, moderado ou testado dentro do Roblox Studio. Também não inclui inimigos, chefes, skins, áudio ou animações.

## Entrega consolidada da versão 1.1

Na raiz Tower Defense, use 00_COMECE_AQUI.md, CLAUDE.md e asset_index.json. O capítulo Pacote_Claude_Code/08_USO_DE_ASSETS_E_ANIMACOES.md integra estas imagens ao documento principal. runtime_asset_registry.json e animation_plan.json separam os IDs a preencher e os movimentos a implementar.
