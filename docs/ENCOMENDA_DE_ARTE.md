# Encomenda de arte v2 — mapas, torres e personagens

Lista do que gerar para a próxima versão do Quintal em Guarda, com design, estados, animação e o
prompt pronto de cada peça. Escrita em 2026-09-29 sobre o estado do jogo daquele dia.

**Versão para mandar ao ChatGPT:** `docs/encomenda_arte/ENCOMENDA_PARA_CHATGPT.md`. É o mesmo
conteúdo, dividido em 22 lotes com as referências de cada lote em
`docs/encomenda_arte/para_chatgpt/lote_XX_…/` e mapas em 1536×1024, o formato que o ChatGPT gera.
A pasta de referências é cópia regerável e fica fora do git.

- A **direção de arte** continua valendo (`Pacote_Claude_Code/03_DIRECAO_DE_ARTE.md`).
- A **geometria de mapa** segue `docs/GUIA_ARTE_DE_MAPA.md`.
- Os **gabaritos** dos mapas novos estão em `docs/encomenda_arte/mapas/`. As rotas são propostas
  validadas por script (entram em x=0, saem em x=15, não se cruzam e ficam longe dos cantos que
  o HUD cobre).
- Os **números de jogo** das torres novas ficam para mim no `balanceamento_v1.json`. Aqui está a
  intenção, não o balanceamento.

---

## 0. Resumo da encomenda

| Prioridade | O quê | Imagens |
|---|---|---|
| **P1** — antes do teste fechado | Arte do Sótão, Oficina (arte + rota nova), Inverno (a neve atual refeita com rota própria) | 3 |
| P1 | 3 torres novas: **Escovinha, Lumi, Pula** (5 estados cada) | 15 |
| P1 | Quadro de **disparo** (`fire`) para os 30 estados atuais + 15 novos | 45 |
| P1 | Pacote de efeitos e projéteis | 14 |
| P1 | Farol danificado e crítico | 2 |
| **P2** | Mapas **Cozinha** e **Quarto de Brinquedos** | 2 |
| P2 | Chefes novos: **Boneco de Poeira, Esponjão, Meia Sem Par** (3 poses cada) | 9 |
| P2 | Torres **Pião** e **Picolé** (5 estados + 2 quadros por estado) | 30 |
| P2 | Quadro de **antecipação** (`windup`) para todos os estados | 45 |
| P2 | Segundo passo (`walk_b`) dos 8 inimigos; `walk_b` + habilidade dos 3 chefes atuais | 14 |
| **P3** | Mapa **Porão da Poeira** + chefe final **Traça Rainha** | 1 + 3 |
| P3 | Torre **Fofo** (apoio) | 15 |
| P3 | 4 inimigos comuns novos (opcional) | 8 |
| P3 | Ícone e thumbnails de divulgação (depois do jogo pronto, com captura real) | 3 |

O P1 dá conta do principal: os três mapas atuais ficam realmente diferentes entre si, e o combate
ganha movimento desenhado e projéteis de verdade no lugar de bolinhas.

---

## 1. Como produzir

### Fluxo

1. **Anexe as referências.** Mande sempre a prancha
   `Pacote_Claude_Code/arte/prancha_conceito.png`. Junte também um sprite aprovado da mesma
   família, por exemplo `Assets_Quintal_em_Guarda_v1/torres/tower_dardo_L0_v001.png`.
2. **Gere e aprove o L0 primeiro.** Os outros estados e quadros saem **a partir da imagem do L0**
   (edição de imagem com o L0 anexado), nunca do zero. É isso que mantém o personagem igual.
3. **Uma conversa por torre** no gerador: ele lembra do personagem.
4. **Confira em tamanho de jogo.** Reduza a imagem para 128 px e veja se a silhueta ainda diz o que
   a torre faz. A régua da direção de arte: reconhecível a 32 px e função legível a 48 px.
5. **Salve com o nome exato** (seção 2) na pasta de entrega e me avise. Eu cuido do resto
   (seção 10).

### Transparência

- Peça **PNG com fundo transparente** (o gerador do ChatGPT faz).
- Se a ferramenta não conseguir, use **fundo magenta chapado #FF00FF**, sem degradê nem sombra, e
  eu recorto.
- **Nunca** aceite xadrez cinza desenhado dentro da imagem: parece transparência, mas não é.

### Pasta de entrega

```text
Assets_Encomenda_v2/
  mapas/     map_<id>_scene_v001.png
  torres/    tower_<id>_<estado>_v001.png e tower_<id>_<estado>_<quadro>_v001.png
  inimigos/  enemy_<id>_base_v001.png, enemy_<id>_walk_b_v001.png
  chefes/    boss_<id>_base_v001.png, boss_<id>_walk_b_v001.png, boss_<id>_ability_v001.png
  efeitos/   fx_<nome>_v001.png
  farol/     base_farol_pilha_<estado>_v001.png
```

- `<estado>` é `L0`, `L1`, `L2`, `L3A` ou `L3B`.
- `<quadro>` é `windup` (antecipação) ou `fire` (disparo). Nas torres de apoio o disparo se chama
  `pulse`.
- Refez uma imagem? Suba a versão (`_v002`) em vez de sobrescrever.

---

## 2. Regras técnicas por tipo

| Tipo | Canvas | Enquadramento | Vista | Não pode |
|---|---|---|---|---|
| Torre (pose e quadros) | 1024×1024 | personagem dentro de x 140–884 e y 100–900; **pés na linha y=900**; olhando um pouco para a direita | três quartos de frente, levemente de cima | pedestal, sombra no chão, texto, cenário |
| Quadro de animação | igual à pose do mesmo estado | **mesmo tamanho, mesma posição, mesma linha dos pés** | igual | efeito solto longe do corpo (o projétil é outra imagem) |
| Inimigo | 1024×1024 | silhueta entre 15% e 85% da largura e da altura | três quartos, levemente de cima | sombra, chão, partículas soltas |
| Chefe | 1024×1024 | silhueta entre 10% e 90%; pés embaixo | três quartos | idem |
| Efeito / projétil | 256×256 | centralizado; **projétil aponta para a direita** | lateral ou de cima | fundo, texto |
| Mapa | 1936×1056 (22×12 ladrilhos de 88 px) | campo 16×10 centrado, moldura de 3 ladrilhos nos lados e 1 em cima e embaixo | **de cima a 90°**, sem perspectiva | farol, torres, inimigos, texto, setas, vinheta |

Estilo comum a tudo: contorno azul-marinho `#19283F` grosso, cores chapadas com no máximo duas
faixas de sombra, textura leve de papel, madeira ou tecido, luz vinda do alto à esquerda, brinquedo
feito à mão. Os aliados são arredondados e estáveis. Os inimigos são macios, assimétricos,
violeta-poeira `#7D63B8` e têm olhos claros. Nada assustador de verdade: o público é infantil.

---

## 3. Modelos de prompt (em inglês — os geradores obedecem melhor)

### Modelo A — torre, estado L0

Cole o bloco inteiro e troque a última linha (`Subject:`) pela da torre.

```text
Use case: stylized-concept. Production asset for the original 2D Roblox tower defense "Quintal em Guarda".
Input image 1 is ONLY a character/style reference. Create one independent single sprite, not a crop, not a sheet, no other characters.
Style: charming handcrafted toy, bold dark navy #19283F contour, clean large flat color shapes and at most two cel-shaded bands, slight paper/wood/fabric texture, painted light from upper left. Match the charm and proportions of the characters in the reference lineup but simplify tiny details for legibility at 128 pixels. Camera slightly elevated three-quarter front, upright whole body, faces a little right, feet at bottom. No pedestal and no ground shadow.
Composition: square 1024x1024 PNG. Exactly one centered character fitting within x=140..884 and y=100..900, feet baseline y=900, entire silhouette and appendages visible with empty margin.
BACKGROUND MUST BE ACTUAL TRANSPARENT ALPHA. No solid white background, no checkerboard drawn into the image, no scenery, no ground, no text, no numbers, no labels, no frame, no watermark. Only the opaque painted toy with transparent pixels around it.
Subject: <cole aqui a linha Subject da torre>
```

### Modelo B — torre, estado seguinte (L1, L2, L3A, L3B)

Anexe a imagem do estado anterior. Para L3A e L3B, anexe o L2.

```text
Input image 1 is the approved sprite of <NOME> at <ESTADO ANTERIOR>. Create the next upgrade state of the SAME character.
Keep EXACTLY: character identity, face, proportions, camera, line weight, palette, rendering style, 1024x1024 transparent canvas, horizontal centering and feet baseline at y=900. The body size stays the same; only equipment and materials change.
Change only: <cole aqui a linha "Muda" do estado>
The upgrade must be visible as a change of SHAPE or MATERIAL (not just glow or color). Transparent background, no ground shadow, no text.
```

### Modelo C — quadro de animação

Anexe a pose do mesmo estado.

```text
Input image 1 is the approved sprite of <NOME> at <ESTADO>. Draw the SAME character in a new pose for an animation frame: <cole aqui a pose>.
Absolutely identical: size, proportions, camera, outline, colors, equipment of this state. Feet (or base) stay on the same baseline y=900 and the body stays centered at the same x. Only the pose changes.
Do not draw projectiles, sparks, motion lines or anything detached from the body. Transparent background, no ground shadow, no text.
```

### Modelo D — inimigo e chefe

```text
Use case: stylized-concept.
Asset type: one reusable transparent PNG <enemy|boss> sprite for the Roblox 2D tower-defense game Quintal em Guarda.
Primary request: <cole aqui a descrição>
Style/medium: polished hand-painted 2D cartoon game illustration, handmade paper/felt feeling, large clean color areas with at most two shading bands, bold dark navy #19283F contour, dusty violet #7D63B8 as the enemy family color, cream #FFF3D6 eyes, soft top-left drawn lighting. Lovable toy-world villain for kids, funny not scary. No photorealism or glossy 3D rendering.
Composition: square 1024x1024 canvas; exactly ONE full-body character centered, gently viewed from above in three-quarter view with face clearly readable. Silhouette within 15%-85% (boss: 10%-90%) of width and height, feet at the bottom. Distinct and readable at 32 pixels (boss: 64 pixels).
Background: TRUE TRANSPARENT ALPHA. No floor, no cast shadow, no pedestal, no border, no labels, no letters, no checkerboard drawn into image, no watermark, no extra creatures or particles detached from body.
```

### Modelo E — efeito ou projétil

```text
One small transparent PNG game effect sprite for a cute 2D toy-world tower defense, 256x256 canvas, centered, bold dark navy #19283F contour where it has a solid shape, flat colors with one shading band, hand-painted cartoon style. Projectiles point to the RIGHT. TRUE TRANSPARENT background, no text, no frame, no extra objects.
Effect: <cole aqui a descrição>
```

### Modelo M — mapa

Anexe o gabarito do mapa (`docs/encomenda_arte/mapas/<id>_template.png`). A IA deve repintar por
cima dele, mantendo a geometria.

```text
Illustrate a tower defense game map seen from directly ABOVE at 90 degrees (orthographic top-down, no perspective, no tilt, no vanishing point), in a charming handcrafted cartoon style with saturated colors, soft paper texture and dark navy #19283F outlines on objects — like a polished mobile game map.
MANDATORY GEOMETRY — follow the attached blueprint image exactly:
- The playable area is a rectangle of exactly 16 x 10 square tiles (ratio 16:10), centered in the image. Keep the tile grid VISIBLE and UNIFORM across the whole area: every tile the same size, with a subtle seam between tiles (slight tone variation, no hard lines).
- The path (the sand-colored cells in the blueprint) is EXACTLY one tile wide everywhere. Corners are 90 degrees and fill the whole corner tile. No diagonal shortcuts, no narrowing or widening.
- The path touches the left edge of the playable area at the entrance and keeps going through the frame until it leaves the image; same at the exit on the right.
- Each gray square in the blueprint is an obstacle cell: draw one clear obstacle CENTERED in that tile, one per tile (see obstacle list below).
- Around the playable area, a decorative frame 3 tiles wide on the left and right and 1 tile on top and bottom. The frame is full of art, but nothing important goes there (it gets cropped on small screens).
DO NOT DRAW: lighthouse, towers, characters, creatures, UI, text, numbers, arrows, watermark, picture frame, big cast shadows, dark vignette, strong light effects.
Keep the buildable tiles CALM: small details are fine, but each stays inside its tile and away from the tile center (that is where towers are placed).
Lighting: flat and even, as if the sun (or lamp) were straight above. No long shadows crossing tiles, no strong gradient across the map.
Theme: <cole aqui o tema>
Buildable tile look: <cole aqui>
Path look: <cole aqui>
Obstacles: <cole aqui>
Frame decoration: <cole aqui>
```

---

## 4. Mapas

Ordem sugerida da campanha: Jardim → Oficina → Inverno → Cozinha → Quarto → Sótão → Porão. A
história é a casa dormindo: os brinquedos defendem o Farol de Pilha de fora para dentro, até o
ninho da poeira.

Regras que valem para todos:
- **Não desenhar o Farol.** Ele é desenhado pelo jogo na última célula do caminho.
- **Obstáculo em toda célula cinza do gabarito.** Senão o jogador vê chão livre, tenta construir
  e leva uma recusa sem entender.
- **Caminho sempre mais claro que o chão**, com borda visível.

### 4.1 Jardim de Papel (`jardim`) — **já existe, nada a gerar**

Continua como mapa de entrada. Chefe: Aspirador.

### 4.2 Oficina de Lata (`oficina`) — P1, arte nova e rota nova

A arte de hoje é de neve e usa quase a mesma rota do Jardim; por isso as fases 1 a 9 parecem um
mapa só. A neve vira o mapa Inverno (4.3), e a Oficina ganha arte própria.

- **Jogabilidade: serpentina.** Três faixas horizontais longas com duas linhas de chão entre elas.
  Uma torre no meio alcança duas faixas; é o mapa que ensina área (Pipoca) e alcance.
  44 células; entrada (0,2); Farol em (15,8).
- **Gabarito:** `docs/encomenda_arte/mapas/oficina_template.png`
- **Rota:** (0,2) → (13,2) → (13,5) → (2,5) → (2,8) → (15,8)
- **Bloqueios:** (0,0) (14,0) (15,0) (6,3) (9,4) (5,7) (10,6) (0,9) (1,9)
- **Chefe:** Rei Ferrugem (já existe).

```text
Theme: the top of a toy maker's workbench at night, seen from above. Cozy, lamp-lit, blue-grey painted wood.
Buildable tile look: blue-grey painted workbench boards (#6F8AA3 to #7E97AE) cut into square tiles, faint wood grain, a few tiny screws, pencil marks and sawdust specks kept inside tiles.
Path look: a strip of creamy masking tape (#F3E3BF) exactly one tile wide, with slightly torn edges and a subtle shadow, following the blueprint.
Obstacles: a giant hex nut, a small closed toolbox, a paint can, a stack of wooden blocks, a spool of thread — one per gray cell, centered.
Frame decoration: a vise on the left, rulers and a measuring tape, jars of buttons and screws, a wind-up key, pliers, a small desk lamp glow at the top edge (no strong light), scattered springs and gears.
```

### 4.3 Quintal de Inverno (`inverno`) — P1, a arte de neve refeita com rota própria

- **Jogabilidade: curto e apertado.** Rota curta (25 células) e um lago congelado no meio onde não
  se constrói, então os lugares bons são poucos e disputados. É fase de pressão.
  Entrada (0,6); Farol em (15,7).
- **Gabarito:** `docs/encomenda_arte/mapas/inverno_template.png`
- **Rota:** (0,6) → (4,6) → (4,2) → (11,2) → (11,7) → (15,7)
- **Bloqueios:** o **lago** ocupa o bloco (6..9, 4..5), 8 células num lago só. Mais pedras ou
  pinheiros em (0,0) (1,0) (14,0) (15,0) (0,9) (15,9).
- **Chefe:** Boneco de Poeira (novo, P2). Até ele existir, uso o Aspirador.
- **Referência:** anexe também `Assets_Mapas_v2/neve_v2.png` para manter o visual aprovado.

```text
Theme: the backyard covered in fresh snow on a winter night, same art style as the attached snow reference image but following the NEW blueprint.
Buildable tile look: pale icy-blue packed snow tiles (#DDEFF8 / #CFE6F3) with visible uniform tile seams, tiny snow tufts inside tiles.
Path look: a warm sandy-orange trodden trail (#EFC98A) exactly one tile wide with a darker edge, like the reference.
Obstacles: the 8 center cells form ONE frozen pond (smooth light-blue ice with cracks and a little snow on the rim) that exactly covers those tiles; the other gray cells get a snow-capped rock or a small pine tree each.
Frame decoration: snowy pine trees, snow-covered rocks, red winter berries, a frozen creek on the right side, a wooden fence with snow on the left.
```

### 4.4 Sótão das Estrelas (`sotao`) — P1, falta a arte (hoje o chão é desenhado por código)

- **Jogabilidade: em S, com trecho de volta.** 39 células; a rota volta para a esquerda no meio e
  cria bolsões. Entrada (0,1); Farol em (15,6). A rota é a atual, que já está no JSON.
- **Gabarito:** `docs/encomenda_arte/mapas/sotao_template.png`
- **Rota:** (0,1) → (5,1) → (5,5) → (2,5) → (2,8) → (10,8) → (10,2) → (14,2) → (14,6) → (15,6)
- **Bloqueios:** (8,0) (9,0) (6,9) (7,9) (15,0)
- **Chefe:** Breu (já existe).

```text
Theme: a cozy attic at night lit by paper stars and moonlight from a round window. Magical but calm, not dark.
Buildable tile look: desaturated dark wooden floorboards (#5C4A5E to #6A5670) cut into square tiles, soft blue fabric patches (#3E5A8C) on a few tiles, tiny paper stars inside tiles.
Path look: a light cream quilted fabric runner (#F2E6CC) exactly one tile wide with stitched edges, clearly brighter than the floor.
Obstacles: a stack of old books, a wooden trunk corner, a folded blanket, a jar of buttons, a paper star lamp — one per gray cell, centered.
Frame decoration: sloped roof beams at the top, a round window with moonlight on the left, hanging paper stars and a mobile, old suitcases, a rocking horse silhouette in soft focus at the edges.
```

### 4.5 Cozinha da Madrugada (`cozinha`) — P2

- **Jogabilidade: escadaria.** Rota curta (24 células) em degraus e um "bolso" perto do fim; as
  quinas valem muito. Bom para Goma e Circuitos. Entrada (0,1); Farol em (15,5).
- **Gabarito:** `docs/encomenda_arte/mapas/cozinha_template.png`
- **Rota:** (0,1) → (3,1) → (3,3) → (6,3) → (6,5) → (9,5) → (9,7) → (12,7) → (12,5) → (15,5)
- **Bloqueios:** (8,1) (9,1) (1,6) (1,7) (14,2) (15,2) (5,8) (4,9) (14,8)
- **Chefe:** Esponjão (novo).

```text
Theme: a kitchen floor at 3 a.m., lit by the soft light of an open fridge door. Cozy and funny.
Buildable tile look: classic checkered floor tiles in cream (#F4EBD6) and pale blue (#BFD6E6) — each floor tile is exactly one game tile.
Path look: a trail of spilled flour and sugar, warm off-white (#FFF6E3) with a sandy edge, exactly one tile wide, clearly readable against the checkerboard.
Obstacles: a cooking pot, a salt shaker, a stack of plates, a chair leg, a cookie jar, a rolled kitchen towel, a mug — one per gray cell, centered.
Frame decoration: the bottom of an open fridge on the right with a soft light spill, kitchen cabinets and a mop bucket on the left, a cat food bowl, fallen cereal, a broom.
```

### 4.6 Quarto de Brinquedos (`quarto`) — P2

- **Jogabilidade: trenzinho com ilha.** O trilho contorna uma ilha de chão fechada por três lados:
  as células de dentro são as mais disputadas. 41 células; entrada (0,6); Farol em (15,7).
- **Gabarito:** `docs/encomenda_arte/mapas/quarto_template.png`
- **Rota:** (0,6) → (3,6) → (3,1) → (13,1) → (13,4) → (6,4) → (6,7) → (15,7)
- **Bloqueios:** (8,2) (9,2) (0,0) (1,0) (15,0) (15,1) (10,9) (11,9)
- **Chefe:** Meia Sem Par (novo).

```text
Theme: a child's bedroom floor at night, a big patterned rug with a wooden toy train track running across it. Warm night-light glow.
Buildable tile look: a soft woven rug with a square-tile pattern in warm colors (#E8C9A0 / #DDB98E) with small stitched motifs inside each tile.
Path look: a light wooden toy train track (#E9CFA0 rails with darker wooden sleepers) exactly one tile wide, following the blueprint, corners as curved track pieces that still fill exactly one tile.
Obstacles: a stack of alphabet blocks WITHOUT letters (plain colored faces), a toy drum, a rubber ball, a folded sock, a small book — one per gray cell, centered.
Frame decoration: bed legs and a hanging blanket at the top, a toy chest on the left, a night-light, crayons, a paper airplane, slippers.
```

### 4.7 Porão da Poeira (`porao`) — P3, mapa final

- **Jogabilidade: serpentina vertical longa.** Cinco colunas de caminho com duas colunas de chão
  entre elas; toda torre alcança duas faixas. É o mapa das fases finais, com muitas ondas.
  50 células; entrada (0,1); Farol em (15,7).
- **Gabarito:** `docs/encomenda_arte/mapas/porao_template.png`
- **Rota:** (0,1) → (2,1) → (2,8) → (5,8) → (5,1) → (8,1) → (8,8) → (11,8) → (11,1) → (14,1) → (14,7) → (15,7)
- **Bloqueios:** (0,0) (15,0) (0,9) (15,9) (3,0) (12,9)
- **Chefe:** Traça Rainha (novo, chefe final).

```text
Theme: the dusty basement where the dust creatures nest, lit by one warm hanging bulb. Mysterious but cute, never scary.
Buildable tile look: grey-violet concrete floor tiles (#8E8AA0 / #9A96AB) with a thin layer of dust, small footprints and lint inside tiles.
Path look: a clean light strip of an old rolled-out carpet runner (#EADFC8) exactly one tile wide, bright against the dusty floor.
Obstacles: a cardboard box, an old paint tin, a coil of rope, a broken toy car, a wooden crate — one per gray cell, centered.
Frame decoration: a boiler and pipes on the right, wooden stairs going up on the left, shelves with jars, soft cobwebs, piles of dust bunnies (tiny, cute, not creatures).
```

---

## 5. Torres novas

As seis cobrem funções que hoje não existem no jogo: tirar armadura, queimar e impedir cura,
empurrar, girar em volta, congelar e fortalecer o dano. Todas respeitam o design original: nada
de torre de renda nem de herói móvel, e são brinquedos com silhueta e cor próprias. Cada mecânica
nova pede código meu (seção 10).

| ID | Nome | Brinquedo | Função | Dano | Abre no nível | Prioridade |
|---|---|---|---|---|---|---|
| `escova` | Escovinha | ouriço de escova de lavar | tira armadura | físico | 4 | P1 |
| `lumi` | Lumi | vaga-lume de lanterna de papel | queima e impede cura | energia | 5 | P1 |
| `pula` | Pula | sapo de lata com molas | empurra para trás | físico (baixo) | 7 | P1 |
| `piao` | Pião | pião de madeira | acerta tudo em volta | físico | 11 | P2 |
| `picole` | Picolé | pinguim ímã de geladeira | congela em área | energia (baixo) | 13 | P2 |
| `fofo` | Fofo | ursinho de pelúcia remendado | aumenta o dano vizinho | nenhum | 15 | P3 |

Cores já usadas pelas torres atuais: laranja, amarelo e verde, marrom, menta, ciano e coral. As
novas ficam em azul-real, lima, vermelho e creme, azul-ardósia e caramelo. Violeta é da família
dos inimigos: nunca em aliado.

### 5.1 Escovinha (`escova`) — P1

- **Função:** corpo a corpo rápido, alcance curto, que **esfrega a armadura** do alvo (reduz a
  armadura por alguns segundos). É a resposta a Latinha, Casulo, Brutamontes e Rei Ferrugem.
- **Silhueta:** baixa, larga e espetada.
- **Paleta:** madeira mel `#C98A4B`, cerdas água-marinha `#3FC1B0`, creme e nariz coral.
- **Ramos:** L3A **Esfregão** (esfrega em área, todos os inimigos colados) e L3B **Escova de Aço**
  (arranca mais armadura e acumula).
- **Efeitos:** `fx_scrub_arc`, `fx_rust_flakes`.
- **Circuito sugerido:** com o Dardo ("Lixa e Flecha": o Dardo causa mais dano em quem está sem
  armadura).

```text
Subject: ESCOVINHA at L0 base level: a small round hedgehog toy made from a wooden scrub brush. The oval wooden brush back (warm honey wood #C98A4B with visible grain) is the body; short stiff aqua bristles #3FC1B0 stand up like spines along the back; cream #FFF3D6 face and belly, small coral #FF775E nose, big friendly black eyes with white highlights, tiny wooden paws. A short wooden brush handle sticks out behind as a tail. Plain base equipment only: no headband, no metal parts, no mop.
```

| Estado | Muda (Modelo B) |
|---|---|
| L1 | add a small coral sweatband on the forehead and a thin leather strap around the belly; bristles unchanged |
| L2 | bristles become longer, in a double row held by a thin brass clip; small white wraps on the paws; keep the sweatband |
| L3A Esfregão | lower body wrapped in a round cream-and-aqua mop fringe skirt that flares outward; a tiny bucket-shaped cap on the head; silhouette becomes wide and round |
| L3B Escova de Aço | bristles become shiny silver steel wire (#AEB8C4) with darker tips, a riveted metal plate on the back, small aviator goggles on the forehead; silhouette becomes spikier and taller at the back |

**Animação (Modelo C):**
- **Antecipação:** curls slightly into a ball, bristles raised and pointing forward, eyes squinting.
- **Disparo:** lunges forward and down with both paws out in a scrubbing motion, bristles flattened
  backward. No Esfregão: spinning pose with the mop fringe flared out.

### 5.2 Lumi (`lumi`) — P1

- **Função:** feixe de luz que **queima** (dano por segundo) e **impede cura** enquanto dura. É a
  resposta ao Remendo, e a luz contra a escuridão combina com o Farol e o Breu.
- **Silhueta:** redonda, com a lanterna como cauda.
- **Paleta:** azul-real `#3D6FD6`, lanterna amarela `#FFC857`, creme.
- **Ramos:** L3A **Holofote** (feixe único que esquenta quanto mais tempo fica no mesmo alvo — bom
  contra chefe) e L3B **Enxame** (a queimadura pula para os vizinhos).
- **Efeitos:** o feixe é desenhado pelo jogo; peça `fx_burn_spark`.
- **Circuito sugerido:** com a Goma ("Cola Quente": a queimadura dura mais em quem está lento).

```text
Subject: LUMI at L0 base level: a cute plush firefly toy standing upright on four short legs. Round royal blue #3D6FD6 felt body with a cream face, big shiny eyes, two short antennae each ending in a tiny yellow bulb, two small pale-blue wings drawn as flat opaque shapes (no real transparency). Its tail is a small round pleated paper lantern in warm yellow #FFC857 with navy ribs, drawn as bright flat color (no glow halo). Plain base equipment only.
```

| Estado | Muda |
|---|---|
| L1 | the lantern gets a thin copper wire ring and a small handle loop on top; a small cream scarf |
| L2 | the lantern becomes bigger with two pleated segments; antenna bulbs larger; wings slightly larger |
| L3A Holofote | the lantern tail is replaced by a chrome flashlight reflector cone pointing forward over its shoulder, with a round bright lens; small brass goggles; silhouette gains a strong forward cone |
| L3B Enxame | two tiny baby fireflies with yellow tails cling to its head and shoulder (touching the body, not floating away); the lantern has several small round windows |

**Animação:**
- **Antecipação:** leans back, lantern colored dim amber, wings pulled in.
- **Disparo:** leans forward, lantern colored bright pale yellow, wings spread.

### 5.3 Pula (`pula`) — P1

- **Função:** controle. Dá um salto e **empurra os inimigos para trás** no caminho; chefes resistem.
  Ganha tempo para as outras torres.
- **Silhueta:** agachada e larga, sobre molas.
- **Paleta:** lata verde-lima `#8BC34A`, faixa vermelha `#E2493F`, molas prateadas. **Sem chave de
  corda**: Pipoca e Maestro já têm.
- **Ramos:** L3A **Salto Gigante** (empurra em área ao aterrissar) e L3B **Língua de Sogra** (a
  língua-de-sogra agarra o inimigo mais forte que não seja chefe e o puxa para bem longe).
- **Efeitos:** `fx_boing`, `fx_push`.
- **Circuito sugerido:** com a Pipoca ("Arremesso": empurrado leva mais dano de área).

```text
Subject: PULA at L0 base level: a squat wind-up tin toy frog. Glossy lime green #8BC34A tin body with a cream belly, two big round eyes on top of the head with black pupils, wide happy mouth, visible stamped tin seams and a few round rivets. Instead of legs it sits on two chunky silver coil springs (#AEB8C4). Plain base: no helmet, no stripes, no party blower. No wind-up key.
```

| Estado | Muda |
|---|---|
| L1 | a single red #E2493F racing stripe from nose to back and small red rivets |
| L2 | springs become taller and thicker; a tiny red tin helmet with a chin strap |
| L3A Salto Gigante | huge accordion shock-absorber springs and round rubber landing pads; body sits higher; silhouette taller and bouncier |
| L3B Língua de Sogra | holds a curled striped red-and-yellow party blower in its mouth; a small ribbon spool on its belly; silhouette gains a curl in front of the mouth |

**Animação:**
- **Antecipação:** crouched low, springs compressed, determined eyes.
- **Disparo:** springs stretched up in a small hop; the bottom of the springs stays on the baseline.
  No L3B: party blower fully unrolled forward.

### 5.4 Pião (`piao`) — P2

- **Função:** gira e **acerta todos os inimigos à volta** (360°, alcance curto). Castiga enxames
  que passam colados.
- **Silhueta:** cone invertido apoiado na ponta.
- **Paleta:** faixas vermelho `#D8453B` e creme, puxador de madeira.
- **Ramos:** L3A **Furacão** (raio maior) e L3B **Pião de Ferro** (pesado, fura parte da armadura).
- **Efeito:** `fx_whirl`.
- **Circuito sugerido:** com o Maestro ("Ciranda": raio maior com cadência).

```text
Subject: PIAO at L0 base level: a classic wooden spinning top toy with a face, standing on its metal tip. Inverted cone body with rounded shoulders, alternating red #D8453B and cream #FFF3D6 painted bands, a small wooden knob handle on top, a friendly face painted on the upper band with big eyes and rosy cheeks, two tiny stubby wooden arms. Plain base: no string, no gold, no fins.
```

| Estado | Muda |
|---|---|
| L1 | a painted teal spiral line around the body and a white string wound around the middle |
| L2 | a shiny brass band at the widest part and a steel tip; a taller handle knob |
| L3A Furacão | four short rounded paper ribbons flare out from the widest band (red, yellow, teal, cream) like a pinwheel skirt; silhouette wider |
| L3B Pião de Ferro | body becomes dark iron #5B6570 with rivets and one red stripe, chunkier, with a thick steel tip; determined eyebrows |

**Animação:**
- **Antecipação:** tilted back about 15 degrees, one arm pulling the string.
- **Disparo:** spinning — same character with the painted bands smeared into horizontal motion
  streaks, face still readable.
- **Extra opcional:** um segundo quadro de giro (`fire_b`), com as faixas em outra posição.

### 5.5 Picolé (`picole`) — P2

- **Função:** a cada tantos segundos solta um sopro gelado que **congela** os inimigos comuns da
  área por cerca de 1 s. Chefes só ficam lentos.
- **Silhueta:** alta e gordinha, com o picolé na mão.
- **Paleta:** azul-ardósia `#34507A`, barriga branca, bico laranja, gelo `#9FE3F5`.
- **Ramos:** L3A **Nevasca** (área maior) e L3B **Geladeira** (congela um alvo por mais tempo, e
  congelado leva dano extra).
- **Efeitos:** `fx_frost_burst`, `fx_ice_block`.
- **Circuito sugerido:** com a Pipoca ("Quebra-Gelo").

```text
Subject: PICOLE at L0 base level: a chubby penguin toy that is a fridge magnet: slightly flat body with a thin visible magnet edge, slate blue #34507A back and head, white belly, orange beak and feet, big shiny eyes, rosy cheeks. It holds a small ice-blue #9FE3F5 popsicle on a wooden stick in one flipper. Plain base: no scarf, no earmuffs.
```

| Estado | Muda |
|---|---|
| L1 | a coral #FF775E knitted scarf |
| L2 | fluffy white earmuffs and a bigger two-color popsicle (ice-blue and white) |
| L3A Nevasca | holds a snow globe above its head with swirling snow inside; silhouette taller |
| L3B Geladeira | wears a small retro mint fridge as a backpack with frost on the door; holds a giant popsicle like a club; silhouette wider at the back |

**Animação:**
- **Antecipação:** puffs its cheeks and raises the popsicle.
- **Disparo:** a short frosty breath puff at the beak (touching the beak) and the popsicle pointing
  forward.

### 5.6 Fofo (`fofo`) — P3

- **Função:** apoio. Aura que **aumenta o dano** das torres vizinhas; o Maestro, em comparação,
  aumenta a cadência. O L3B também conserta o Farol aos pouquinhos entre as ondas.
- **Silhueta:** redonda e macia.
- **Paleta:** caramelo `#D9A066`, creme, coração coral. **Nada de cruz vermelha**: é símbolo
  protegido.
- **Ramos:** L3A **Abraço de Urso** (aura mais forte e maior) e L3B **Coração Remendado** (cura o
  Farol).
- **Efeito:** `fx_heart`.

```text
Subject: FOFO at L0 base level: a small plush teddy bear toy standing upright, soft caramel #D9A066 fabric with visible seams, cream muzzle and inner ears, shiny round black eyes with white highlights, a small smile, a coral #FF775E heart patch stitched on the belly with visible stitches. Plain base: no bow, no cape.
```

| Estado | Muda |
|---|---|
| L1 | a teal #2FB7A0 bow tie |
| L2 | a small cape made from a checkered cream-and-coral handkerchief; one ear with a cute stitched patch |
| L3A Abraço de Urso | bigger and fluffier, arms open wide with big round cushy paws, the cape flowing; silhouette wide |
| L3B Coração Remendado | hugs a big stitched heart pillow (coral with cream stitches); a thread spool with a blunt rounded wooden toy needle hangs at its side; no medical cross symbols |

**Animação (apoio):**
- **Antecipação:** arms open wide.
- **Pulso (`pulse`):** hugging tight with eyes closed happily and a small heart puff above the head,
  touching the head.

---

## 6. Animação das torres atuais

Hoje cada estado é uma pose parada, que o jogo balança por código. Com **dois quadros por
estado**, antecipação e disparo, o ataque passa a ser desenhado: pose → antecipação → disparo →
pose. O **mínimo para o P1 é o `fire`**; o `windup` entra no P2.

Use o Modelo C com a imagem do **mesmo estado** anexada. Fontes em
`Assets_Quintal_em_Guarda_v1/torres/tower_<id>_<estado>_v001.png`. São 5 estados × 2 quadros × 6
torres = 60 imagens.

| Torre | Antecipação (`windup`) | Disparo (`fire`, no Maestro `pulse`) |
|---|---|---|
| Dardo | pulls the elastic band back with the launcher raised to the eye, one eye squinting, tail tense | launcher snapped forward with the elastic relaxed, body leaning slightly back from recoil, tail up |
| Pipoca | shell pressed down, head pulled in, tube tilted up | tube kicked upward with a small white popcorn steam puff attached at the tube mouth, legs braced |
| Lupa | raises the spyglass to its eye, one wing steadying it | leaning forward, the spyglass lens drawn as a bright white-yellow glint (touching the lens) |
| Goma | slime squished to the bottom of the jar, cheeks puffed | slime stretched up against the cork, mouth wide open |
| Voltz | spring compressed, head lowered | spring fully extended, the antenna ball colored brighter cyan-white (flat color, no halo) |
| Maestro | claws raised, speakers pulled close to the body | speakers pushed outward, claws open, mouth open singing |

Nos ramos L3A e L3B, a pose é a mesma, adaptada ao equipamento; o tambor da Rajada, por exemplo,
gira para a frente.

---

## 7. Inimigos e chefes

### 7.1 Quadros dos atuais — P2

Fontes em `Assets_Inimigos_Bosses_v1/inimigos/` e `…/bosses/`. Use o Modelo C (trocando "tower"
por "enemy") com a imagem base anexada.

| Entidade | `walk_b` (segundo passo) | `ability` (só chefes) |
|---|---|---|
| Fiapo | squashed down mid-hop, tufts flying up | — |
| Corrisco | leaning further forward, body stretched, trail flicked back | — |
| Bolota | compressed wide, heavy step | — |
| Latinha | the other foot forward, can tilted the other way | — |
| Névoa | swirl rotated a quarter turn, edges wavier | — |
| Remendo | stitches glowing (lighter color), body puffed | — |
| Casulo | cracks wider, shell trembling tilt | — |
| Brutamontes | the other arm swinging forward, shoulders up | — |
| Aspirador | hose swinging the other way | inhaling: cheeks and hose puffed, body leaning back (2 s warning) |
| Rei Ferrugem | the other foot forward, crown tilted | armor plates closing around the body, eyes narrowed |
| Breu | blanket rippling the other way | stitches glowing brightly, arms raised to summon |

### 7.2 Chefes novos — P2/P3

Cada um precisa de `base`, `walk_b` e `ability`. Use o Modelo D com a linha abaixo. A habilidade
é nova e pede código.

| Chefe | Mapa | Habilidade (intenção) |
|---|---|---|
| **Boneco de Poeira** (`boneco_poeira`) | Inverno | *Rajada gelada*: com 2 s de aviso, congela 1 ou 2 torres por 2 s (cadência zerada) |
| **Esponjão** (`esponjao`) | Cozinha | *Encharcar*: por 3 s absorve dano de energia e se cura um pouco; físico passa |
| **Meia Sem Par** (`meia`) | Quarto | *Enrolar*: estica-se e desliga a torre mais próxima por 3 s, com aviso |
| **Traça Rainha** (`traca_rainha`) | Porão (final) | *Nuvem de pó*: esconde um trecho do caminho (torres não miram lá por 2 s) e invoca traças |

```text
Primary request (boneco_poeira): BONECO DE POEIRA, a big grumpy snowman made of dusty snow: three stacked lumpy balls of grey-lilac dusty snow (#C9C3E0 with violet #7D63B8 shading), glowing cream coal-button eyes, a crooked twig arm and one lint mitten, a knitted hat made of lint and fluff, a few dust bunnies stuck on it. Funny grumpy expression. Imposing size but cute.
```

```text
Primary request (esponjao): ESPONJAO, a big grimy kitchen sponge creature: rectangular yellow sponge body (#E8C64A) stained with violet dust patches #7D63B8, a dark green scrub layer on its back like a shell, many round pores, big cream eyes, a grumpy wide mouth, stubby legs, a few soap bubbles stuck to it. Funny, not gross.
```

```text
Primary request (meia): MEIA SEM PAR, a giant lost striped sock monster: long knitted sock body in faded violet and cream stripes, standing on its heel with the toe curled forward like a head, a hole in the toe with one big mischievous cream eye peeking out and a second eye stitched like a big round patch, dust bunnies falling from the opening, wobbly knitted feet. Playful, not creepy.
```

```text
Primary request (traca_rainha): TRACA RAINHA, a large moth queen made of old wool and dust: fuzzy grey-violet body, big wings with round eye-spots made of darned fabric patches, a tiny crown made of buttons, fluffy feather antennae, glowing cream eyes. Majestic and a little silly, kid-friendly. Wings spread but contained inside the canvas margins.
```

Poses (Modelo C):
- **`walk_b`:** "the other step of the walk, body tilted the other way".
- **`ability`:** a preparação da habilidade (Boneco: peito estufado e inspirando; Esponjão: inchado
  e pingando água; Meia: esticada para a frente; Traça: asas abertas para cima).

### 7.3 Inimigos comuns novos — P3, opcional

| Inimigo | Mapa | Mecânica | Descrição curta para o Modelo D |
|---|---|---|---|
| Migalha (`migalha`) | Cozinha | enxame de 6, muito rápido, pouca vida (só números) | tiny round bread-crumb dust ball, golden-brown speckled with violet dust, big eyes, running pose |
| Floquinho (`floquinho`) | Inverno | resiste a energia (mesmo sistema da Névoa) | small six-point snowflake made of lint, pale lilac, big eyes, floating just above its tiny feet |
| Novelo (`novelo`) | Quarto | imune a lentidão | a small tangled yarn ball in violet and cream with loose threads, two eyes peeking between threads |
| Traça (`traca`) | Porão | esquiva o primeiro acerto a cada 3 s | small fuzzy moth with patched wings, big eyes, fluttering |

Cada um precisa de `base` e `walk_b`.

---

## 8. Efeitos e projéteis — P1

Use o Modelo E, em 256×256, com o projétil apontando para a direita.

| Arquivo | Uso | Descrição (para o Modelo E) |
|---|---|---|
| `fx_dardo_dart` | projétil do Dardo | small wooden dart with a cyan tip and teal fletching |
| `fx_pipoca_kernel` | projétil da Pipoca | one fluffy popcorn kernel with a tiny motion tail |
| `fx_pipoca_pop` | explosão da Pipoca | burst of white-and-yellow popcorn puffs and small stars, round, top-down |
| `fx_lupa_glint` | disparo da Lupa | four-point white-yellow glint star with a short light streak to the right |
| `fx_goma_blob` | projétil da Goma | mint green glue blob with a highlight and a small drip |
| `fx_goma_puddle` | poça no chão | flat mint glue puddle seen from above, irregular round shape |
| `fx_voltz_spark` | ponto da corrente | cyan-white cartoon electric spark star |
| `fx_maestro_note` | apoio do Maestro | two coral music notes |
| `fx_dust_poof_1/2/3` | morte de inimigo (3 quadros) | violet dust cloud puff — frame 1 small dense, 2 bigger, 3 dissolving into specks |
| `fx_hit_star` | impacto | small cream-and-gold impact star |
| `fx_build_puff` | construir torre | ring of cream dust puffs with 3 small gold sparkles |
| `fx_upgrade_stars` | melhoria | burst of small gold stars |
| Torres novas | `fx_scrub_arc`, `fx_rust_flakes`, `fx_burn_spark`, `fx_boing`, `fx_push`, `fx_whirl`, `fx_frost_burst`, `fx_ice_block`, `fx_heart` | descrições nas seções 5.1 a 5.6; `fx_ice_block` é um cubo de gelo claro, opaco e pintado, que fica por cima do inimigo congelado |

---

## 9. Farol — P1

Anexe `Assets_Quintal_em_Guarda_v1/cenario/base_farol_pilha_v001.png` e peça o mesmo farol, no
mesmo canvas, tamanho e posição:

- `base_farol_pilha_danificado_v001.png`:
  ```text
  a few cracks, a strip of masking tape over one crack, the window light slightly dimmer, a small chip missing from the top rail
  ```
- `base_farol_pilha_critico_v001.png`:
  ```text
  many cracks, leaning very slightly, two tape patches, window light dim orange, a loose battery cap
  ```

O jogo troca a imagem pela vida: abaixo de 50% e abaixo de 20%.

---

## 10. O que eu faço quando as imagens chegarem

- **Mapas:**
  - `tools/fit_map_scene.py` mede o `playRect` e confere rota e bloqueios contra o desenho.
  - Publico o decalque e registro em `map_scene_overrides.json`.
  - Crio o mapa e as fases no `balanceamento_v1.json` e troco `oficina` ↔ `inverno` (a neve atual
    passa a ser o Inverno).
- **Torres:**
  - Normalizo em 512 e 128 com o mesmo apoio (0,5; 0,82) e publico.
  - Crio a entrada no JSON (custos, alcance, limites), os textos em `Localization`, a coleção e o
    desbloqueio por nível.
- **Mecânicas novas** (código e testes):
  - tirar armadura (Escovinha);
  - queimadura com bloqueio de cura (Lumi);
  - empurrão pelo caminho (Pula);
  - acerto em todos no alcance (Pião);
  - congelamento (Picolé);
  - aura de dano e cura do Farol (Fofo);
  - habilidades dos quatro chefes novos.
- **Quadros:** o registro de assets ganha o modo "pose + quadros" (`windup` e `fire`), e o
  `TowerAnimator`/`EnemyAnimator` passa a trocar a textura no ritmo do ataque confirmado pelo
  servidor. O dano nunca depende da animação.
- **Efeitos:** os projéteis e a poeira de morte substituem as bolinhas e o esmaecimento de hoje.

**Antes de mandar, confira:**
1. O fundo é transparente de verdade (ou magenta chapado)?
2. Os pés estão na mesma linha em todos os estados e quadros da mesma torre?
3. Não há texto, letra, número nem marca d'água?
4. A silhueta continua legível reduzida a 128 px?
5. No mapa: ladrilho uniforme, caminho de um ladrilho, rota e obstáculos iguais ao gabarito, e
   nenhum farol desenhado?
