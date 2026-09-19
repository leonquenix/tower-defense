# Guia para encomendar a arte de um mapa

Como pedir a imagem de cenário de um mapa para uma IA de imagem (ou para um ilustrador) de um
jeito que ela **encaixe na grade do jogo sem remendo**. O jogo lê a imagem inteira como cena:
grama, caminho e cenário vêm desenhados, e só o Farol, as torres e os inimigos são desenhados por
código em cima.

Junto deste guia existe um **gabarito** por mapa em `docs/map_templates/` (gerado por
`tools/make_map_template.py` a partir do `balanceamento_v1.json`). Anexar o gabarito no pedido vale
mais que qualquer descrição: a IA repinta por cima e a geometria sai certa.

---

## 1. A geometria, em uma frase

A área jogável é uma grade de **16 colunas × 10 linhas de ladrilhos quadrados** (proporção exata
**16:10**), e o caminho tem **exatamente 1 ladrilho de largura** do começo ao fim.

Em volta dessa área vai uma **moldura decorativa** — folhagem, praia, chão de oficina, o que o tema
pedir — de **3 ladrilhos à esquerda e à direita e 1 acima e abaixo**. A moldura não é área de jogo:
ela existe para a arte sangrar até as bordas da tela em monitores largos. Isso dá um quadro de
**22 × 12 ladrilhos**; com ladrilho de 88 px, uma imagem de **1936 × 1056**.

Se a ferramenta não deixar escolher o tamanho exato, tudo bem: o que **não** pode mudar é a
proporção 16:10 do campo, o ladrilho quadrado e o caminho de um ladrilho. O resto da imagem é
moldura e pode sobrar.

## 2. As rotas (coordenadas de célula)

Coluna `x` cresce para a direita (0 a 15), linha `y` cresce para baixo (0 a 9). "Bloqueadas" são
células onde o jogador **não pode** construir: elas precisam ter um obstáculo desenhado (pedra,
caixa, tronco), senão o jogador vê grama limpa e leva uma recusa sem entender.

### Jardim de Papel (`jardim`)

- Rota: entra na **borda esquerda, linha 2** → direita até a coluna 4 → desce até a linha 6 →
  direita até a coluna 9 → sobe até a linha 3 → direita até a coluna 13 → desce até a linha 8 →
  direita até a coluna 15 e sai pela borda direita. São 28 células de caminho.
- Bloqueadas: (1,8), (2,8), (11,0), (12,0), (0,9).
- Última célula do caminho: **(15,8)** — é onde o jogo desenha o Farol. Não desenhe farol nenhum.

### Oficina de Lata (`oficina`)

- Rota: entra na **borda esquerda, linha 7** → direita até a coluna 3 → sobe até a linha 2 →
  direita até a coluna 7 → desce até a linha 7 → direita até a coluna 11 → sobe até a linha 3 →
  direita até a coluna 15 e sai. São 30 células.
- Bloqueadas: (0,0), (1,0), (14,9), (15,9), (8,9).
- Última célula: **(15,3)**.

### Sótão das Estrelas (`sotao`)

- Rota: entra na **borda esquerda, linha 1** → direita até a coluna 5 → desce até a linha 5 →
  **esquerda** até a coluna 2 → desce até a linha 8 → direita até a coluna 10 → sobe até a linha 2
  → direita até a coluna 14 → desce até a linha 6 → direita até a coluna 15 e sai. São 39 células.
- Bloqueadas: (8,0), (9,0), (6,9), (7,9), (15,0).
- Última célula: **(15,6)**.

## 3. Pedido pronto para colar

> Ilustre um cenário de tower defense visto **de cima, a 90° (sem perspectiva, sem inclinação,
> sem ponto de fuga)**, em estilo cartoon de doce, cores saturadas e contorno suave — como um mapa
> de jogo mobile.
>
> **Geometria obrigatória** (siga a imagem anexa como planta):
> - A área de jogo é um retângulo de **16 × 10 ladrilhos quadrados**, proporção 16:10, centrado na
>   imagem.
> - Desenhe a **malha de ladrilhos visível e uniforme** no gramado: mesma medida em toda a área,
>   com uma costura sutil entre eles (variação leve de tom, sem linhas duras).
> - O caminho tem **exatamente 1 ladrilho de largura** em todo o trajeto, com curvas em 90° que
>   ocupam o ladrilho da esquina inteiro. Nada de atalho diagonal, nada de estreitar ou alargar.
> - Rota: `<cole aqui a rota do mapa, da seção 2>`.
> - O caminho encosta na borda esquerda da área de jogo na entrada e continua por dentro da
>   moldura até sair da imagem; na saída, idem à direita.
> - Coloque um obstáculo claro (pedra, tronco, caixa) **centrado** nestas células, uma por célula:
>   `<cole as bloqueadas>`.
> - Em volta da área de jogo, uma moldura decorativa de **3 ladrilhos nos lados e 1 em cima e
>   embaixo** (folhagem densa, praia, o que o tema pedir). A moldura é cheia de arte, mas nada
>   importante fica nela: ela é cortada em telas menores.
>
> **Não desenhe**: farol, torre, personagem, inimigo, interface, texto, número, seta, marca d'água,
> moldura de quadro, sombra projetada grande, vinheta escura nas bordas, efeito de luz forte.
>
> **Mantenha o gramado calmo**: pequenas flores, tufos e detalhes miúdos são bem-vindos, mas cada
> um dentro de um ladrilho e sem cobrir o centro dele — é ali que as torres são colocadas.
>
> **Iluminação**: plana e uniforme, como se o sol estivesse a pino. Sem sombra longa atravessando
> ladrilhos, sem degradê forte de um canto para o outro.
>
> Tema desta cena: `<descreva: quintal com praia ao lado, oficina de lata, sótão à noite…>`.

## 4. Conferência antes de aceitar a imagem

1. **Ladrilho uniforme?** Meça um ladrilho perto da borda esquerda e outro perto da direita: têm de
   ter a mesma largura. É o erro mais comum quando a IA "desenha com perspectiva sem querer".
2. **Corredor de um ladrilho?** A largura da pista tem de bater com a largura de um ladrilho do
   gramado, nas retas e nas curvas.
3. **Rota certa?** Conte as curvas e compare com a rota da seção 2.
4. **Obstáculos nas células certas?**
5. **Proporção do campo?** Largura ÷ altura da área de jogo (sem a moldura) tem de dar **1,60**.
6. **Nada proibido desenhado?** Principalmente farol e torres.

Se a imagem passar, é só me mandar: eu meço o `playRect` pela malha de ladrilhos da própria arte,
publico o decalque e atualizo `assets/export/map_scene_overrides.json`.

## 5. Por que essas regras (resumo técnico)

- O jogo posiciona a imagem de forma que o retângulo `playRect` — a fração da imagem ocupada pela
  grade — caia exatamente sobre a grade lógica 16×10. Se o ladrilho desenhado não for uniforme,
  **não existe** `playRect` que alinhe tudo: uma parte do tabuleiro sempre fica torta.
- O `playRect` é medido na própria arte: o gradiente da imagem é periódico por causa da malha de
  ladrilhos, e o passo/fase que maximiza a soma nas bordas dá célula e origem. Sem malha visível, a
  medida vira chute (foi assim que a primeira versão do Jardim saiu 20% de célula deslocada).
- O caminho precisa ter 1 célula porque o jogo trata caminho como conjunto de células: uma pista
  desenhada com 1,3 célula faz o jogador tentar construir em cima de areia desenhada e levar
  "Não dá para construir no caminho".
- A moldura larga nos lados existe porque a tela quase nunca é 16:10. O jogo centra a grade e deixa
  a arte transbordar; onde ainda falta, ele repete a mesma imagem recortada atrás. Quanto mais
  moldura, menos esse remendo aparece.
- Farol e torres são desenhados por código porque reagem ao jogo (dano, brilho, melhoria). Se
  estiverem na arte, aparecem duas vezes — foi por isso que a arte do Jardim foi regerada sem o
  farol.
