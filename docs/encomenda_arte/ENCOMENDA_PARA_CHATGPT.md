# Quintal em Guarda — encomenda de imagens para o ChatGPT

## Para o Breno: como usar este documento

1. **Abra uma conversa nova no ChatGPT para cada lote.** Assim ele não mistura personagens.
2. Na primeira mensagem de cada conversa:
   - envie **este arquivo**;
   - envie **todas as imagens da pasta do lote** (`docs/encomenda_arte/para_chatgpt/lote_XX_…/`);
   - escreva: **`Faça o Lote XX`**.
3. O ChatGPT gera **uma imagem por resposta**, sempre com o nome do arquivo antes da imagem.
   - Se a imagem estiver boa, responda **`ok`** e ele passa para a próxima.
   - Se não estiver, descreva a correção. Exemplo: `os pés subiram, desça até a linha de antes`.
4. No fim do lote, o ChatGPT entrega um **`Lote_XX.zip`**. Descompacte-o **na raiz do projeto**
   (`tower-defense/`): ele já traz `Assets_Encomenda_v2/<pasta>/` com os nomes certos.
   - Se ele avisar que não conseguiu montar o ZIP, baixe cada imagem aprovada.
   - Salve cada uma com o nome que ele anunciou, na pasta indicada no cabeçalho do lote.
5. Quando terminar um lote, me avise. Eu recorto, normalizo, publico no Roblox e ligo no jogo.

A ordem dos lotes é a prioridade: **01 a 11 são o P1** (antes do teste fechado), **12 a 18 são o
P2** e **19 a 22 são o P3**. Dá para parar a qualquer momento e mandar o que já estiver pronto.

---

## Para o ChatGPT: quem você é e como trabalhar

Você é o ilustrador de **Quintal em Guarda**, um jogo de tower defense em 2D para o Roblox.

**Fantasia do jogo:** brinquedos esquecidos defendem o **Farol de Pilha** contra criaturas de
poeira, à noite, enquanto a casa dorme. O público é infantil: tudo é fofo e engraçado, nada é
assustador ou violento de verdade.

**Regras de trabalho (siga sempre):**

1. **Leia o lote pedido inteiro antes de começar.** Gere as imagens **na ordem**, **uma por
   resposta**.
2. **Antes de cada imagem**, escreva numa linha só: `Arquivo: <nome_do_arquivo.png>`. Depois da
   imagem, escreva no máximo uma frase.
3. **Depois de cada imagem, pare e espere.**
   - `ok` significa aprovada: siga para o próximo item.
   - Qualquer outra resposta é uma correção: refaça **o mesmo item** com a correção.
4. **"Base" diz de qual imagem partir.** Pode ser um anexo (pelo nome do arquivo) ou uma imagem que
   você já gerou e que foi aprovada nesta conversa (pelo nome que você anunciou). Use a base como
   ponto de partida: edite a partir dela, mantendo tudo o que o item não mandar mudar. **Nunca
   comece do zero quando houver base.**
5. **Os anexos cujo nome começa com `estilo_` são só referência de estilo.** Não copie esses
   personagens para dentro da imagem nova.
6. **Nunca escreva texto, letras, números, logotipos ou marca d'água dentro das imagens.**
7. **Não pule itens nem mude a ordem.** Se um item for impossível, diga por quê e proponha a
   alternativa mais próxima.
8. **Guarde cada imagem aprovada numa pasta.** Use sua ferramenta de arquivos (Python) e salve em
   `Assets_Encomenda_v2/<pasta do lote>/<nome exato do arquivo>`. A pasta está no cabeçalho do
   lote, em "Salvar em". Mantenha o PNG com transparência.
9. **Ao terminar o lote:**
   - liste os arquivos aprovados;
   - entregue um **ZIP para download** chamado `Lote_XX.zip`, com a estrutura
     `Assets_Encomenda_v2/<pasta>/<arquivos>`.

   Se a ferramenta de arquivos não conseguir acessar as imagens que você gerou, **diga isso
   claramente** e não entregue um ZIP vazio nem incompleto: eu baixo as imagens uma a uma.

---

## Regras de arte (valem para todos os lotes)

**Estilo.**
- Ilustração 2D cartoon de brinquedo feito à mão.
- Contorno grosso azul-marinho `#19283F`.
- Cores chapadas, com no máximo duas faixas de sombra.
- Textura leve de papel, madeira, lata ou tecido, conforme o material.
- Luz pintada vinda do alto à esquerda.
- Nada de 3D brilhante nem de fotorrealismo.

**Cores com significado.**
- Aliados (torres) são arredondados e estáveis, com cores vivas.
- Inimigos são da família da poeira: violeta `#7D63B8`, macios e assimétricos, com olhos creme
  `#FFF3D6`.
- **Nunca pinte um aliado de violeta.**

**Legibilidade.** Silhueta reconhecível mesmo reduzida a 32 px. Evite detalhes minúsculos.

### Formatos

| Tipo | Tamanho | Fundo | Enquadramento |
|---|---|---|---|
| Torre, inimigo, chefe, farol | **1024×1024** | **transparente de verdade** (PNG com alpha) | uma figura inteira e centralizada, com margem vazia em volta |
| Efeito ou projétil | **1024×1024** | transparente | o efeito ocupa o centro, com cerca de 55% do quadro; projéteis apontam para a **direita** |
| Mapa | **1536×1024** (paisagem) | opaco | segue o gabarito anexado, pixel por pixel |

**Transparência:**
- Nunca desenhe um xadrez cinza imitando transparência.
- Se a transparência falhar, use fundo **magenta chapado #FF00FF**, sem sombra nem degradê.

### Modelos de prompt

Os itens dos lotes dizem qual modelo usar e o que colocar nos campos entre `< >`.

**Modelo A — torre nova, estado L0**
```text
Production sprite for the original 2D Roblox tower defense "Quintal em Guarda". The attached images named estilo_* are ONLY style references: match their charm, proportions, outline weight and rendering; do not copy those characters.
Style: charming handcrafted toy, bold dark navy #19283F contour, clean large flat color shapes and at most two cel-shaded bands, slight paper/wood/fabric/tin texture, painted light from upper left. Simplify tiny details for legibility at 128 pixels.
Camera slightly elevated three-quarter front view, upright whole body, facing a little to the right, feet at the bottom. No pedestal and no ground shadow.
Square 1024x1024 PNG. Exactly one centered character fitting within x=140..884 and y=100..900, feet baseline at y=900, entire silhouette visible with empty margin.
TRUE TRANSPARENT BACKGROUND (alpha). No checkerboard, no scenery, no ground, no text, no numbers, no frame, no watermark.
Subject: <SUBJECT>
```

**Modelo B — próximo estado de melhoria (L1, L2, L3A, L3B)**
```text
Edit the base image (the approved sprite of <TOWER> at <PREVIOUS STATE>) to create the next upgrade state of the SAME character.
Keep EXACTLY: identity, face, body size and proportions, camera, outline weight, palette, rendering, the 1024x1024 transparent canvas, horizontal centering and the feet baseline at y=900.
Change only: <CHANGE>
The upgrade must read as a change of SHAPE or MATERIAL, not just glow or color. Transparent background, no ground shadow, no text.
```

**Modelo C — quadro de animação (torre, inimigo ou chefe)**
```text
Edit the base image to make an animation frame of the SAME character in the SAME state: <POSE>.
Keep absolutely identical: size, proportions, camera, outline, colors and all equipment of this state. The feet (or base) stay exactly on the same baseline and the body stays centered at the same x as in the base image. Only the pose changes.
Do not draw projectiles, sparks, motion lines or anything detached from the body. Transparent background, no ground shadow, no text.
```

**Modelo D — inimigo ou chefe novo**
```text
Transparent PNG <enemy|boss> sprite for the 2D toy-world tower defense "Quintal em Guarda". The attached estilo_* images are ONLY style references for the enemy family; do not copy those characters.
Character: <DESCRIPTION>
Style: polished hand-painted 2D cartoon, handmade paper/felt feeling, large clean color areas with at most two shading bands, bold dark navy #19283F contour, dusty violet #7D63B8 as the family color, cream #FFF3D6 eyes, soft top-left lighting. Lovable toy-world villain for kids, funny, not scary.
Square 1024x1024; exactly ONE full-body character centered, gently viewed from above in three-quarter view with the face clearly readable, feet at the bottom. Silhouette within 15%-85% of the canvas (boss: 10%-90%).
TRUE TRANSPARENT BACKGROUND. No floor, no cast shadow, no pedestal, no text, no checkerboard, no watermark, no extra creatures or particles detached from the body.
```

**Modelo E — efeito ou projétil**
```text
One game effect sprite for a cute 2D toy-world tower defense. Square 1024x1024, the effect centered and filling about 55% of the canvas, generous empty margin. Bold dark navy #19283F contour where the effect has a solid shape, flat colors with one shading band, hand-painted cartoon style. Projectiles point to the RIGHT. TRUE TRANSPARENT BACKGROUND, no text, no extra objects.
Effect: <DESCRIPTION>
```

**Modelo M — mapa (sempre com o gabarito anexado)**
```text
Paint a tower defense map over the attached blueprint (gabarito_*.png), keeping its geometry EXACTLY. Output 1536x1024 landscape.
View: straight top-down at 90 degrees (orthographic), no perspective, no tilt, no vanishing point. Charming handcrafted cartoon style, saturated colors, soft paper texture, dark navy #19283F outlines on objects, like a polished mobile game map.
MANDATORY GEOMETRY (from the blueprint):
- The playable field is the 1280x800 px rectangle starting at x=128, y=112: exactly 16 x 10 square tiles of 80x80 px. Keep the tile grid VISIBLE and UNIFORM (same size everywhere, a subtle seam between tiles, no hard lines).
- The path is exactly the sand-colored cells: ONE tile wide everywhere, 90-degree corners filling the whole corner tile, no diagonals, no widening. It continues through the frame to the left and right image edges at the entrance and exit.
- Each gray square is an obstacle tile: draw one clear obstacle CENTERED in that tile, one per tile, unless the item says a group of tiles is one big obstacle.
- Everything outside the field is a decorative frame: full of art, but nothing important there.
DO NOT DRAW: lighthouse, towers, characters, creatures, UI, text, numbers, arrows, watermark, picture frame, big cast shadows, dark vignette, strong light effects.
Keep buildable tiles CALM: small details stay inside their tile and away from the tile center.
Lighting: flat and even, as if the light were straight above. No long shadows crossing tiles, no strong gradient across the map.
Theme: <THEME>
Buildable tile look: <TILES>
Path look: <PATH>
Obstacles: <OBSTACLES>
Frame decoration: <FRAME>
```

---

# Lotes P1

## Lote 01 — Mapa: Sótão das Estrelas
Anexos: `gabarito_sotao.png`, `estilo_prancha.jpg` · Salvar em `Assets_Encomenda_v2/mapas/`

**01.1 — `map_sotao_scene_v001.png`** · Modelo M · Base: `gabarito_sotao.png`

| Campo | Valor |
|---|---|
| Theme | a cozy attic at night lit by paper stars and moonlight from a round window; magical but calm, never dark |
| Buildable tile look | desaturated dark wooden floorboards (#5C4A5E to #6A5670) cut into square tiles, soft blue fabric patches (#3E5A8C) on a few tiles, tiny paper stars inside some tiles |
| Path look | a light cream quilted fabric runner (#F2E6CC) with stitched edges, clearly brighter than the floor |
| Obstacles | a stack of old books, the corner of a wooden trunk, a folded blanket, a jar of buttons, a paper star lamp |
| Frame decoration | sloped roof beams at the top, a round moonlit window on the left, hanging paper stars and a mobile, old suitcases, a rocking horse softly at an edge |

## Lote 02 — Mapa: Oficina de Lata
Anexos: `gabarito_oficina.png`, `estilo_prancha.jpg` · Salvar em `Assets_Encomenda_v2/mapas/`

**02.1 — `map_oficina_scene_v001.png`** · Modelo M · Base: `gabarito_oficina.png`

| Campo | Valor |
|---|---|
| Theme | the top of a toy maker's workbench at night, seen from above; cozy, lamp-lit, blue-grey painted wood |
| Buildable tile look | blue-grey painted workbench boards (#6F8AA3 to #7E97AE) cut into square tiles, faint wood grain, tiny screws, pencil marks and sawdust specks kept inside tiles |
| Path look | a strip of creamy masking tape (#F3E3BF) with slightly torn edges |
| Obstacles | a giant hex nut, a small closed toolbox, a paint can, a stack of plain wooden blocks, a spool of thread |
| Frame decoration | a vise on the left, rulers and a measuring tape without numbers, jars of buttons and screws, pliers, springs and gears, a soft desk-lamp glow at the top edge |

## Lote 03 — Mapa: Quintal de Inverno
Anexos: `gabarito_inverno.png`, `estilo_neve_atual.jpg` · Salvar em `Assets_Encomenda_v2/mapas/`

**03.1 — `map_inverno_scene_v001.png`** · Modelo M · Base: `gabarito_inverno.png`

Use `estilo_neve_atual.jpg` só como referência de visual. A rota e a geometria vêm do gabarito.

| Campo | Valor |
|---|---|
| Theme | the backyard covered in fresh snow on a winter night, same look as estilo_neve_atual.jpg but following the NEW blueprint |
| Buildable tile look | pale icy-blue packed snow tiles (#DDEFF8 / #CFE6F3) with uniform visible seams, tiny snow tufts inside tiles |
| Path look | a warm sandy-orange trodden trail (#EFC98A) with a darker edge |
| Obstacles | the 8 gray tiles in the center (2 rows x 4 columns) are ONE frozen pond that exactly covers those 8 tiles (smooth light-blue ice with cracks and snow on the rim); every other gray tile gets one snow-capped rock or one small pine tree |
| Frame decoration | snowy pine trees, snow-covered rocks, red winter berries, a frozen creek on the right side, a wooden fence with snow on the left |

---

## Lote 04 — Torre nova: Escovinha
Anexos: `estilo_prancha.jpg`, `estilo_dardo_L0.png`, `estilo_pipoca_L0.png` · Salvar em `Assets_Encomenda_v2/torres/`

**Quem é.** Um ouriço de brinquedo feito de uma escova de lavar. Esfrega a armadura dos inimigos.
- **Silhueta:** baixa, larga e espetada.
- **Ramos:** Esfregão (esfrega em volta) e Escova de Aço (arranca mais armadura).

| # | Arquivo | Modelo | Base | Conteúdo |
|---|---|---|---|---|
| 04.1 | `tower_escova_L0_v001.png` | A | — | **Subject:** ESCOVINHA at L0 base level: a small round hedgehog toy made from a wooden scrub brush. The oval wooden brush back (warm honey wood #C98A4B with visible grain) is the body; short stiff aqua bristles #3FC1B0 stand up like spines along the back; cream #FFF3D6 face and belly, small coral #FF775E nose, big friendly black eyes with white highlights, tiny wooden paws. A short wooden brush handle sticks out behind as a tail. Plain base equipment only: no headband, no metal parts, no mop. |
| 04.2 | `tower_escova_L1_v001.png` | B | 04.1 | **Change:** add a small coral sweatband on the forehead and a thin leather strap around the belly; bristles unchanged |
| 04.3 | `tower_escova_L2_v001.png` | B | 04.2 | **Change:** bristles become longer, in a double row held by a thin brass clip; small white wraps on the paws; keep the sweatband |
| 04.4 | `tower_escova_L3A_v001.png` | B | 04.3 | **Change (specialization ESFREGÃO):** the lower body is wrapped in a round cream-and-aqua mop fringe skirt that flares outward; a tiny bucket-shaped cap on the head; silhouette becomes wide and round |
| 04.5 | `tower_escova_L3B_v001.png` | B | 04.3 | **Change (specialization ESCOVA DE AÇO):** bristles become shiny silver steel wire (#AEB8C4) with darker tips, a riveted metal plate on the back, small aviator goggles on the forehead; silhouette spikier and taller at the back |
| 04.6–04.10 | `tower_escova_<L0,L1,L2,L3A,L3B>_fire_v001.png` | C | o estado correspondente (04.1 a 04.5) | **Pose:** lunging forward and down with both paws out in a scrubbing motion, bristles flattened backward (for L3A: spinning pose with the mop fringe flared out) |
| 04.11–04.15 | `tower_escova_<L0,L1,L2,L3A,L3B>_windup_v001.png` | C | o estado correspondente | **Pose:** curled slightly into a ball, bristles raised and pointing forward, eyes squinting |

## Lote 05 — Torre nova: Lumi
Anexos: `estilo_prancha.jpg`, `estilo_dardo_L0.png`, `estilo_pipoca_L0.png` · Salvar em `Assets_Encomenda_v2/torres/`

**Quem é.** Um vaga-lume de pelúcia com uma lanterna de papel no lugar da cauda. A luz queima a
poeira e impede o inimigo de se curar.
- **Ramos:** Holofote (feixe único forte) e Enxame (espalha a queimadura).

| # | Arquivo | Modelo | Base | Conteúdo |
|---|---|---|---|---|
| 05.1 | `tower_lumi_L0_v001.png` | A | — | **Subject:** LUMI at L0 base level: a cute plush firefly toy standing upright on four short legs. Round royal blue #3D6FD6 felt body with a cream face, big shiny eyes, two short antennae each ending in a tiny yellow bulb, two small pale-blue wings drawn as flat opaque shapes (no real transparency). Its tail is a small round pleated paper lantern in warm yellow #FFC857 with navy ribs, drawn as bright flat color (no glow halo). Plain base equipment only. |
| 05.2 | `tower_lumi_L1_v001.png` | B | 05.1 | **Change:** the lantern gets a thin copper wire ring and a small handle loop on top; add a small cream scarf |
| 05.3 | `tower_lumi_L2_v001.png` | B | 05.2 | **Change:** the lantern becomes bigger with two pleated segments; antenna bulbs larger; wings slightly larger |
| 05.4 | `tower_lumi_L3A_v001.png` | B | 05.3 | **Change (specialization HOLOFOTE):** the lantern tail is replaced by a chrome flashlight reflector cone pointing forward over its shoulder, with a round bright lens; small brass goggles on the head; silhouette gains a strong forward-pointing cone |
| 05.5 | `tower_lumi_L3B_v001.png` | B | 05.3 | **Change (specialization ENXAME):** two tiny baby fireflies with yellow tails cling to its head and shoulder (touching the body, not floating away); the lantern has several small round windows |
| 05.6–05.10 | `tower_lumi_<estado>_fire_v001.png` | C | o estado correspondente | **Pose:** leaning forward, lantern colored bright pale yellow, wings spread wide |
| 05.11–05.15 | `tower_lumi_<estado>_windup_v001.png` | C | o estado correspondente | **Pose:** leaning back, lantern colored dim amber, wings pulled in |

## Lote 06 — Torre nova: Pula
Anexos: `estilo_prancha.jpg`, `estilo_dardo_L0.png`, `estilo_pipoca_L0.png` · Salvar em `Assets_Encomenda_v2/torres/`

**Quem é.** Um sapo de lata que anda sobre molas. Salta e empurra os inimigos para trás no caminho.
- **Ramos:** Salto Gigante (empurra em área) e Língua de Sogra (puxa um inimigo para longe).
- **Sem chave de corda:** outras torres já têm.

| # | Arquivo | Modelo | Base | Conteúdo |
|---|---|---|---|---|
| 06.1 | `tower_pula_L0_v001.png` | A | — | **Subject:** PULA at L0 base level: a squat wind-up tin toy frog. Glossy lime green #8BC34A tin body with a cream belly, two big round eyes on top of the head with black pupils, wide happy mouth, visible stamped tin seams and a few round rivets. Instead of legs it sits on two chunky silver coil springs (#AEB8C4). Plain base: no helmet, no stripes, no party blower, no wind-up key. |
| 06.2 | `tower_pula_L1_v001.png` | B | 06.1 | **Change:** a single red #E2493F racing stripe from nose to back and small red rivets |
| 06.3 | `tower_pula_L2_v001.png` | B | 06.2 | **Change:** springs become taller and thicker; a tiny red tin helmet with a chin strap |
| 06.4 | `tower_pula_L3A_v001.png` | B | 06.3 | **Change (specialization SALTO GIGANTE):** huge accordion shock-absorber springs and round rubber landing pads; the body sits higher; silhouette taller and bouncier |
| 06.5 | `tower_pula_L3B_v001.png` | B | 06.3 | **Change (specialization LÍNGUA DE SOGRA):** holds a curled striped red-and-yellow party blower in its mouth; a small ribbon spool on its belly; silhouette gains a curl in front of the mouth |
| 06.6–06.10 | `tower_pula_<estado>_fire_v001.png` | C | o estado correspondente | **Pose:** springs stretched up in a small hop while the bottom of the springs stays on the baseline (for L3B: the party blower fully unrolled forward) |
| 06.11–06.15 | `tower_pula_<estado>_windup_v001.png` | C | o estado correspondente | **Pose:** crouched low with the springs compressed, determined eyes |

---

## Lote 07 — Animação das torres atuais: Dardo e Pipoca
Anexos: `tower_dardo_L0/L1/L2/L3A/L3B.png` e `tower_pipoca_L0/L1/L2/L3A/L3B.png` (10 arquivos) · Salvar em `Assets_Encomenda_v2/torres/`

Todos os itens usam o **Modelo C**. A base é o anexo do mesmo estado. Mantenha o enquadramento
exato do anexo: o mesmo tamanho e a mesma linha dos pés. Nas especializações (L3A e L3B), adapte a
pose ao equipamento do estado.

| # | Arquivos | Pose |
|---|---|---|
| 07.1–07.5 | `tower_dardo_<L0,L1,L2,L3A,L3B>_fire_v001.png` | the launcher snapped forward with the elastic relaxed, body leaning slightly back from the recoil, tail up |
| 07.6–07.10 | `tower_pipoca_<estado>_fire_v001.png` | the tube kicked upward with a small white popcorn steam puff touching the tube mouth, legs braced |
| 07.11–07.15 | `tower_dardo_<estado>_windup_v001.png` | pulling the elastic band back with the launcher raised to the eye, one eye squinting, tail tense |
| 07.16–07.20 | `tower_pipoca_<estado>_windup_v001.png` | shell pressed down, head pulled in, tube tilted up |

## Lote 08 — Animação das torres atuais: Lupa e Goma
Anexos: `tower_lupa_*` e `tower_goma_*` (10 arquivos) · Salvar em `Assets_Encomenda_v2/torres/`

As regras são as mesmas do Lote 07.

| # | Arquivos | Pose |
|---|---|---|
| 08.1–08.5 | `tower_lupa_<estado>_fire_v001.png` | leaning forward, the spyglass lens drawn as a bright white-yellow glint touching the lens |
| 08.6–08.10 | `tower_goma_<estado>_fire_v001.png` | the slime stretched up against the cork, mouth wide open |
| 08.11–08.15 | `tower_lupa_<estado>_windup_v001.png` | raising the spyglass to its eye, one wing steadying it |
| 08.16–08.20 | `tower_goma_<estado>_windup_v001.png` | the slime squished to the bottom of the jar, cheeks puffed |

## Lote 09 — Animação das torres atuais: Voltz e Maestro
Anexos: `tower_voltz_*` e `tower_maestro_*` (10 arquivos) · Salvar em `Assets_Encomenda_v2/torres/`

As regras são as mesmas do Lote 07. O Maestro é torre de apoio: o quadro de ação dele se chama
`pulse`.

| # | Arquivos | Pose |
|---|---|---|
| 09.1–09.5 | `tower_voltz_<estado>_fire_v001.png` | spring fully extended, the antenna ball colored brighter cyan-white (flat color, no halo) |
| 09.6–09.10 | `tower_maestro_<estado>_pulse_v001.png` | speakers pushed outward, claws open, mouth open singing |
| 09.11–09.15 | `tower_voltz_<estado>_windup_v001.png` | spring compressed, head lowered |
| 09.16–09.20 | `tower_maestro_<estado>_windup_v001.png` | claws raised, speakers pulled close to the body |

---

## Lote 10 — Efeitos e projéteis
Anexos: `estilo_dardo_L0.png`, `estilo_pipoca_L0.png`, `estilo_goma_L0.png`, `estilo_voltz_L0.png`, `estilo_maestro_L0.png`, `estilo_fiapo.png` · Salvar em `Assets_Encomenda_v2/efeitos/`

Todos os itens usam o **Modelo E**. Os anexos servem para acertar as cores de cada torre.
- **10.9 a 10.11:** gere nesta ordem; cada um usa o anterior como base.
- **10.15 a 10.23:** são efeitos das torres novas.

| # | Arquivo | Effect |
|---|---|---|
| 10.1 | `fx_dardo_dart_v001.png` | a small wooden dart with a cyan tip and teal fletching, pointing right |
| 10.2 | `fx_pipoca_kernel_v001.png` | one fluffy popcorn kernel flying right with a tiny motion tail attached |
| 10.3 | `fx_pipoca_pop_v001.png` | a round burst of white-and-yellow popcorn puffs and small stars, seen from above |
| 10.4 | `fx_lupa_glint_v001.png` | a four-point white-yellow glint star with a short light streak to the right |
| 10.5 | `fx_goma_blob_v001.png` | a mint green glue blob with a highlight and a small drip, flying right |
| 10.6 | `fx_goma_puddle_v001.png` | a flat mint glue puddle seen from above, irregular round shape |
| 10.7 | `fx_voltz_spark_v001.png` | a cyan-white cartoon electric spark star |
| 10.8 | `fx_maestro_note_v001.png` | two coral music notes |
| 10.9 | `fx_dust_poof_1_v001.png` | a small dense violet dust cloud puff (enemy defeated, frame 1) |
| 10.10 | `fx_dust_poof_2_v001.png` | the same violet dust puff, bigger and softer (frame 2) |
| 10.11 | `fx_dust_poof_3_v001.png` | the same puff dissolving into small scattered specks (frame 3) |
| 10.12 | `fx_hit_star_v001.png` | a small cream-and-gold impact star |
| 10.13 | `fx_build_puff_v001.png` | a ring of cream dust puffs with three small gold sparkles, seen from above |
| 10.14 | `fx_upgrade_stars_v001.png` | a burst of small gold stars |
| 10.15 | `fx_scrub_arc_v001.png` | a short curved aqua scrubbing swoosh with little bubbles |
| 10.16 | `fx_rust_flakes_v001.png` | small orange rust flakes and grey dust bits flying outward |
| 10.17 | `fx_burn_spark_v001.png` | small warm yellow-orange light embers and sparkles (cartoon light, not realistic fire) |
| 10.18 | `fx_boing_v001.png` | a cartoon bounce impact: a small ring with curved motion lines |
| 10.19 | `fx_push_v001.png` | an arrow-shaped puff of dust pointing right |
| 10.20 | `fx_whirl_v001.png` | a circular cream-and-red swirl swoosh, seen from above |
| 10.21 | `fx_frost_burst_v001.png` | a burst of icy-blue snowflakes and frost puffs |
| 10.22 | `fx_ice_block_v001.png` | a translucent-looking ice cube drawn with solid pale blue colors and white highlights (opaque paint), to be placed over a frozen enemy |
| 10.23 | `fx_heart_v001.png` | three small coral hearts floating upward |

## Lote 11 — Farol de Pilha danificado
Anexo: `base_farol_pilha.png` · Salvar em `Assets_Encomenda_v2/farol/`

Os dois itens partem de `base_farol_pilha.png`. Mantenha o **mesmo farol, o mesmo tamanho e a
mesma posição**, com fundo transparente.

| # | Arquivo | Mudança |
|---|---|---|
| 11.1 | `base_farol_pilha_danificado_v001.png` | a few cracks, a strip of masking tape over one crack, the window light slightly dimmer, a small chip missing from the top rail |
| 11.2 | `base_farol_pilha_critico_v001.png` | many cracks, leaning very slightly, two tape patches, window light dim orange, a loose battery cap |

---

# Lotes P2

## Lote 12 — Mapa: Cozinha da Madrugada
Anexos: `gabarito_cozinha.png`, `estilo_prancha.jpg` · Salvar em `Assets_Encomenda_v2/mapas/`

**12.1 — `map_cozinha_scene_v001.png`** · Modelo M · Base: `gabarito_cozinha.png`

| Campo | Valor |
|---|---|
| Theme | a kitchen floor at 3 a.m., lit by the soft light of an open fridge door; cozy and funny |
| Buildable tile look | classic checkered floor tiles in cream (#F4EBD6) and pale blue (#BFD6E6); each floor tile is exactly one game tile |
| Path look | a trail of spilled flour and sugar, warm off-white (#FFF6E3) with a sandy edge, clearly readable against the checkerboard |
| Obstacles | a cooking pot, a salt shaker, a stack of plates, a chair leg, a cookie jar, a rolled kitchen towel, a mug |
| Frame decoration | the bottom of an open fridge on the right with a soft light spill, kitchen cabinets and a mop bucket on the left, a cat food bowl, fallen cereal, a broom |

## Lote 13 — Mapa: Quarto de Brinquedos
Anexos: `gabarito_quarto.png`, `estilo_prancha.jpg` · Salvar em `Assets_Encomenda_v2/mapas/`

**13.1 — `map_quarto_scene_v001.png`** · Modelo M · Base: `gabarito_quarto.png`

| Campo | Valor |
|---|---|
| Theme | a child's bedroom floor at night: a big patterned rug with a wooden toy train track running across it; warm night-light glow |
| Buildable tile look | a soft woven rug with a square-tile pattern in warm colors (#E8C9A0 / #DDB98E) and small stitched motifs inside each tile |
| Path look | a light wooden toy train track (#E9CFA0 rails with darker wooden sleepers); corners are curved track pieces that still fill exactly one tile |
| Obstacles | a stack of plain colored toy blocks with NO letters, a toy drum, a rubber ball, a folded sock, a small closed book |
| Frame decoration | bed legs and a hanging blanket at the top, a toy chest on the left, a night-light, crayons, a paper airplane, slippers |

## Lote 14 — Torre nova: Pião
Anexos: `estilo_prancha.jpg`, `estilo_dardo_L0.png`, `estilo_pipoca_L0.png` · Salvar em `Assets_Encomenda_v2/torres/`

**Quem é.** Um pião de madeira com carinha. Gira e acerta todos os inimigos à volta.
- **Ramos:** Furacão (raio maior) e Pião de Ferro (pesado).

| # | Arquivo | Modelo | Base | Conteúdo |
|---|---|---|---|---|
| 14.1 | `tower_piao_L0_v001.png` | A | — | **Subject:** PIAO at L0 base level: a classic wooden spinning top toy with a face, standing on its metal tip (the tip is the "feet" on the baseline). Inverted cone body with rounded shoulders, alternating red #D8453B and cream #FFF3D6 painted bands, a small wooden knob handle on top, a friendly face painted on the upper band with big eyes and rosy cheeks, two tiny stubby wooden arms. Plain base: no string, no gold, no fins. |
| 14.2 | `tower_piao_L1_v001.png` | B | 14.1 | **Change:** a painted teal spiral line around the body and a white string wound around the middle |
| 14.3 | `tower_piao_L2_v001.png` | B | 14.2 | **Change:** a shiny brass band at the widest part and a steel tip; a taller handle knob |
| 14.4 | `tower_piao_L3A_v001.png` | B | 14.3 | **Change (specialization FURACÃO):** four short rounded paper ribbons (red, yellow, teal, cream) flare out from the widest band like a pinwheel skirt; silhouette wider |
| 14.5 | `tower_piao_L3B_v001.png` | B | 14.3 | **Change (specialization PIÃO DE FERRO):** body becomes dark iron #5B6570 with rivets and one red stripe, chunkier, with a thick steel tip; determined eyebrows |
| 14.6–14.10 | `tower_piao_<estado>_fire_v001.png` | C | o estado correspondente | **Pose:** spinning — the painted bands smeared into horizontal motion streaks, the face still readable |
| 14.11–14.15 | `tower_piao_<estado>_windup_v001.png` | C | o estado correspondente | **Pose:** tilted back about 15 degrees on its tip, one arm pulling the string |

## Lote 15 — Torre nova: Picolé
Anexos: `estilo_prancha.jpg`, `estilo_dardo_L0.png`, `estilo_pipoca_L0.png` · Salvar em `Assets_Encomenda_v2/torres/`

**Quem é.** Um pinguim ímã de geladeira segurando um picolé. Sopra ar gelado e congela os
inimigos.
- **Ramos:** Nevasca (área maior) e Geladeira (congela um alvo por mais tempo).

| # | Arquivo | Modelo | Base | Conteúdo |
|---|---|---|---|---|
| 15.1 | `tower_picole_L0_v001.png` | A | — | **Subject:** PICOLE at L0 base level: a chubby penguin toy that is a fridge magnet: slightly flat body with a thin visible magnet edge, slate blue #34507A back and head, white belly, orange beak and feet, big shiny eyes, rosy cheeks. It holds a small ice-blue #9FE3F5 popsicle on a wooden stick in one flipper. Plain base: no scarf, no earmuffs. |
| 15.2 | `tower_picole_L1_v001.png` | B | 15.1 | **Change:** a coral #FF775E knitted scarf |
| 15.3 | `tower_picole_L2_v001.png` | B | 15.2 | **Change:** fluffy white earmuffs and a bigger two-color popsicle (ice-blue and white) |
| 15.4 | `tower_picole_L3A_v001.png` | B | 15.3 | **Change (specialization NEVASCA):** holds a snow globe above its head with swirling snow inside; silhouette taller |
| 15.5 | `tower_picole_L3B_v001.png` | B | 15.3 | **Change (specialization GELADEIRA):** wears a small retro mint fridge as a backpack with frost on the door; holds a giant popsicle like a club; silhouette wider at the back |
| 15.6–15.10 | `tower_picole_<estado>_fire_v001.png` | C | o estado correspondente | **Pose:** a short frosty breath puff touching the beak, the popsicle pointing forward |
| 15.11–15.15 | `tower_picole_<estado>_windup_v001.png` | C | o estado correspondente | **Pose:** cheeks puffed, popsicle raised high |

## Lote 16 — Chefes novos: Boneco de Poeira, Esponjão e Meia Sem Par
Anexos: `estilo_aspirador.png`, `estilo_rei_ferrugem.png`, `estilo_breu.png`, `estilo_fiapo.png` · Salvar em `Assets_Encomenda_v2/chefes/`

Os itens `base` usam o **Modelo D** (boss). Os itens `walk_b` e `ability` usam o **Modelo C**,
tendo o `base` do mesmo chefe como base.

| # | Arquivo | Conteúdo |
|---|---|---|
| 16.1 | `boss_boneco_poeira_base_v001.png` | **Character:** BONECO DE POEIRA, a big grumpy snowman made of dusty snow: three stacked lumpy balls of grey-lilac dusty snow (#C9C3E0 with violet #7D63B8 shading), glowing cream coal-button eyes, a crooked twig arm and one lint mitten, a knitted hat made of lint and fluff, a few dust bunnies stuck on it. Funny grumpy expression. Imposing size but cute. |
| 16.2 | `boss_boneco_poeira_walk_b_v001.png` | **Pose:** the other step of its waddle, body tilted the other way |
| 16.3 | `boss_boneco_poeira_ability_v001.png` | **Pose:** chest puffed out and inhaling deeply, cheeks full, about to blow a freezing gust |
| 16.4 | `boss_esponjao_base_v001.png` | **Character:** ESPONJAO, a big grimy kitchen sponge creature: rectangular yellow sponge body (#E8C64A) stained with violet dust patches #7D63B8, a dark green scrub layer on its back like a shell, many round pores, big cream eyes, a grumpy wide mouth, stubby legs, a few soap bubbles stuck to it. Funny, not gross. |
| 16.5 | `boss_esponjao_walk_b_v001.png` | **Pose:** the other step, body squished the other way |
| 16.6 | `boss_esponjao_ability_v001.png` | **Pose:** swollen and soaked, dripping water drops attached to the body, smug face |
| 16.7 | `boss_meia_base_v001.png` | **Character:** MEIA SEM PAR, a giant lost striped sock monster: long knitted sock body in faded violet and cream stripes, standing on its heel with the toe curled forward like a head, a hole in the toe with one big mischievous cream eye peeking out and a second eye stitched like a big round patch, dust bunnies falling from the opening, wobbly knitted feet. Playful, not creepy. |
| 16.8 | `boss_meia_walk_b_v001.png` | **Pose:** the other wobble step, the toe swinging the other way |
| 16.9 | `boss_meia_ability_v001.png` | **Pose:** stretched long and leaning far forward, as if about to wrap around something |

## Lote 17 — Inimigos atuais: segundo passo
Anexos: `enemy_fiapo_base.png`, `enemy_corrisco_base.png`, `enemy_bolota_base.png`, `enemy_latinha_base.png`, `enemy_nevoa_base.png`, `enemy_remendo_base.png`, `enemy_casulo_base.png`, `enemy_brutamontes_base.png` · Salvar em `Assets_Encomenda_v2/inimigos/`

Todos os itens usam o **Modelo C**. A base é o anexo do mesmo inimigo.

| # | Arquivo | Pose |
|---|---|---|
| 17.1 | `enemy_fiapo_walk_b_v001.png` | squashed down mid-hop, tufts flying up |
| 17.2 | `enemy_corrisco_walk_b_v001.png` | leaning further forward, body stretched, trail flicked back |
| 17.3 | `enemy_bolota_walk_b_v001.png` | compressed wide in a heavy step |
| 17.4 | `enemy_latinha_walk_b_v001.png` | the other foot forward, the can tilted the other way |
| 17.5 | `enemy_nevoa_walk_b_v001.png` | the swirl rotated a quarter turn, edges wavier |
| 17.6 | `enemy_remendo_walk_b_v001.png` | body puffed, stitches in a lighter color |
| 17.7 | `enemy_casulo_walk_b_v001.png` | cracks slightly wider, shell tilted in a tremble |
| 17.8 | `enemy_brutamontes_walk_b_v001.png` | the other arm swinging forward, shoulders up |

## Lote 18 — Chefes atuais: passo e habilidade
Anexos: `boss_aspirador_base.png`, `boss_rei_ferrugem_base.png`, `boss_breu_base.png` · Salvar em `Assets_Encomenda_v2/chefes/`

Todos os itens usam o **Modelo C**. A base é o anexo do mesmo chefe.

| # | Arquivo | Pose |
|---|---|---|
| 18.1 | `boss_aspirador_walk_b_v001.png` | the hose swinging the other way, body tilted |
| 18.2 | `boss_aspirador_ability_v001.png` | inhaling: cheeks and hose puffed up, body leaning back |
| 18.3 | `boss_rei_ferrugem_walk_b_v001.png` | the other foot forward, crown tilted |
| 18.4 | `boss_rei_ferrugem_ability_v001.png` | armor plates closing around the body, eyes narrowed |
| 18.5 | `boss_breu_walk_b_v001.png` | the blanket rippling the other way |
| 18.6 | `boss_breu_ability_v001.png` | stitches colored bright, arms raised as if summoning |

---

# Lotes P3

## Lote 19 — Mapa: Porão da Poeira
Anexos: `gabarito_porao.png`, `estilo_prancha.jpg` · Salvar em `Assets_Encomenda_v2/mapas/`

**19.1 — `map_porao_scene_v001.png`** · Modelo M · Base: `gabarito_porao.png`

| Campo | Valor |
|---|---|
| Theme | the dusty basement where the dust creatures nest, lit by one warm hanging bulb; mysterious but cute, never scary |
| Buildable tile look | grey-violet concrete floor tiles (#8E8AA0 / #9A96AB) with a thin layer of dust, small footprints and lint inside tiles |
| Path look | a clean light strip of an old rolled-out carpet runner (#EADFC8), bright against the dusty floor |
| Obstacles | a cardboard box, an old paint tin, a coil of rope, a broken toy car, a wooden crate |
| Frame decoration | a boiler and pipes on the right, wooden stairs going up on the left, shelves with jars, soft cobwebs, tiny piles of dust bunnies (decoration, not creatures) |

## Lote 20 — Chefe final: Traça Rainha
Anexos: `estilo_aspirador.png`, `estilo_breu.png`, `estilo_fiapo.png` · Salvar em `Assets_Encomenda_v2/chefes/`

| # | Arquivo | Modelo | Base | Conteúdo |
|---|---|---|---|---|
| 20.1 | `boss_traca_rainha_base_v001.png` | D (boss) | — | **Character:** TRACA RAINHA, a large moth queen made of old wool and dust: fuzzy grey-violet body, big wings with round eye-spots made of darned fabric patches, a tiny crown made of buttons, fluffy feather antennae, glowing cream eyes. Majestic and a little silly, kid-friendly. Wings spread but fully inside the canvas margins. |
| 20.2 | `boss_traca_rainha_walk_b_v001.png` | C | 20.1 | **Pose:** wings lowered in the other half of the flap, body bobbing slightly |
| 20.3 | `boss_traca_rainha_ability_v001.png` | C | 20.1 | **Pose:** wings raised high and wide, antennae up, about to release a dust cloud |

## Lote 21 — Torre nova: Fofo
Anexos: `estilo_prancha.jpg`, `estilo_dardo_L0.png`, `estilo_pipoca_L0.png` · Salvar em `Assets_Encomenda_v2/torres/`

**Quem é.** Um ursinho de pelúcia remendado, torre de apoio. Fortalece as torres vizinhas e, num
dos ramos, conserta o Farol.
- **Ramos:** Abraço de Urso e Coração Remendado.
- **Nada de cruz vermelha** em lugar nenhum.

| # | Arquivo | Modelo | Base | Conteúdo |
|---|---|---|---|---|
| 21.1 | `tower_fofo_L0_v001.png` | A | — | **Subject:** FOFO at L0 base level: a small plush teddy bear toy standing upright, soft caramel #D9A066 fabric with visible seams, cream muzzle and inner ears, shiny round black eyes with white highlights, a small smile, a coral #FF775E heart patch stitched on the belly with visible stitches. Plain base: no bow, no cape. |
| 21.2 | `tower_fofo_L1_v001.png` | B | 21.1 | **Change:** a teal #2FB7A0 bow tie |
| 21.3 | `tower_fofo_L2_v001.png` | B | 21.2 | **Change:** a small cape made from a checkered cream-and-coral handkerchief; one ear with a cute stitched patch |
| 21.4 | `tower_fofo_L3A_v001.png` | B | 21.3 | **Change (specialization ABRAÇO DE URSO):** bigger and fluffier, arms open wide with big round cushy paws, the cape flowing; silhouette wide |
| 21.5 | `tower_fofo_L3B_v001.png` | B | 21.3 | **Change (specialization CORAÇÃO REMENDADO):** hugs a big stitched heart pillow (coral with cream stitches); a thread spool with a blunt rounded wooden toy needle hangs at its side; no medical cross symbols |
| 21.6–21.10 | `tower_fofo_<estado>_pulse_v001.png` | C | o estado correspondente | **Pose:** hugging tight with the eyes closed happily and a small heart puff touching the top of the head |
| 21.11–21.15 | `tower_fofo_<estado>_windup_v001.png` | C | o estado correspondente | **Pose:** arms opened wide |

## Lote 22 — Inimigos novos
Anexos: `estilo_fiapo.png`, `estilo_nevoa.png`, `estilo_corrisco.png`, `estilo_remendo.png` · Salvar em `Assets_Encomenda_v2/inimigos/`

Os itens `base` usam o **Modelo D** (enemy). Os itens `walk_b` usam o **Modelo C**, tendo o `base`
do mesmo inimigo como base.

| # | Arquivo | Conteúdo |
|---|---|---|
| 22.1 | `enemy_migalha_base_v001.png` | **Character:** MIGALHA, a tiny round bread-crumb dust ball, golden-brown speckled with violet dust, big eyes, in a running pose. Very small and simple. |
| 22.2 | `enemy_migalha_walk_b_v001.png` | **Pose:** the other running step |
| 22.3 | `enemy_floquinho_base_v001.png` | **Character:** FLOQUINHO, a small six-point snowflake made of lint, pale lilac, big eyes, standing on two tiny feet |
| 22.4 | `enemy_floquinho_walk_b_v001.png` | **Pose:** rotated slightly the other way in a little hop |
| 22.5 | `enemy_novelo_base_v001.png` | **Character:** NOVELO, a small tangled yarn ball in violet and cream with a few loose threads, two eyes peeking out between the threads |
| 22.6 | `enemy_novelo_walk_b_v001.png` | **Pose:** rolled a quarter turn, loose threads swinging the other way |
| 22.7 | `enemy_traca_base_v001.png` | **Character:** TRACA, a small fuzzy moth with patched wings, big eyes, fluttering just above its tiny feet |
| 22.8 | `enemy_traca_walk_b_v001.png` | **Pose:** wings in the other half of the flap |
