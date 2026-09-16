# Catálogo numérico para implementação

Valores iniciais propostos, sem playtest. Custos de L1, L2 e L3 são incrementais; L3A e L3B são exclusivos. Dano por acerto, intervalo em segundos e alcance em células. Regras de efeitos e precedência estão na especificação técnica.

## Dardo

ID `dardo`. Ataque direto. Desbloqueio: inicial. Máximo por jogador: 6.

| Estado | Custo | Dano | Intervalo | Alcance | Efeito |
| --- | --- | --- | --- | --- | --- |
| L0 | 250 | 10 | 0.8 | 2.5 | Acerto simples |
| L1 | 200 | 16 | 0.75 | 2.7 | Acerto simples |
| L2 | 450 | 28 | 0.7 | 2.9 | Acerto simples |
| L3A | 900 | 46 | 0.55 | 3.1 | Acerto simples |
| L3B | 1000 | 42 | 0.75 | 3.4 | armorIgnore=1 |

L3A: Rajada. L3B: Fura lata.

## Pipoca

ID `pipoca`. Explosão em área. Desbloqueio: inicial. Máximo por jogador: 4.

| Estado | Custo | Dano | Intervalo | Alcance | Efeito |
| --- | --- | --- | --- | --- | --- |
| L0 | 450 | 20 | 1.8 | 2.8 | splash=1, maxTargets=6 |
| L1 | 300 | 34 | 1.7 | 3 | splash=1.1, maxTargets=6 |
| L2 | 600 | 60 | 1.6 | 3.2 | splash=1.2, maxTargets=8 |
| L3A | 1200 | 95 | 1.4 | 3.4 | splash=1.7, maxTargets=10 |
| L3B | 1200 | 115 | 1.8 | 3.6 | splash=1.1, maxTargets=6, armorIgnore=0.5 |

L3A: Festival. L3B: Demolidora.

## Lupa

ID `lupa`. Dano contra elites. Desbloqueio: 240 botões. Máximo por jogador: 4.

| Estado | Custo | Dano | Intervalo | Alcance | Efeito |
| --- | --- | --- | --- | --- | --- |
| L0 | 500 | 55 | 2.5 | 5 | Acerto simples |
| L1 | 350 | 85 | 2.3 | 5.3 | Acerto simples |
| L2 | 700 | 145 | 2.1 | 5.6 | Acerto simples |
| L3A | 1400 | 280 | 2.2 | 6 | bossBonus=0.25 |
| L3B | 1300 | 170 | 1.6 | 6 | mark=0.1, markDuration=3 |

L3A: Olho de águia. L3B: Observadora.

## Goma

ID `goma`. Lentidão. Desbloqueio: inicial. Máximo por jogador: 4.

| Estado | Custo | Dano | Intervalo | Alcance | Efeito |
| --- | --- | --- | --- | --- | --- |
| L0 | 300 | 3 | 1 | 2.3 | slow=0.2, slowDuration=1.5 |
| L1 | 200 | 5 | 1 | 2.5 | slow=0.25, slowDuration=1.8 |
| L2 | 400 | 8 | 0.9 | 2.7 | slow=0.3, slowDuration=2 |
| L3A | 850 | 10 | 0.9 | 3 | slow=0.3, slowDuration=2, splash=1, maxTargets=5 |
| L3B | 850 | 12 | 0.8 | 3 | slow=0.45, slowDuration=2.5 |

L3A: Poça. L3B: Supercola.

## Voltz

ID `voltz`. Corrente elétrica. Desbloqueio: 600 botões. Máximo por jogador: 4.

| Estado | Custo | Dano | Intervalo | Alcance | Efeito |
| --- | --- | --- | --- | --- | --- |
| L0 | 550 | 20 | 1.3 | 2.4 | chains=2, chainRadius=1.5, chainFalloff=0.75 |
| L1 | 350 | 30 | 1.2 | 2.6 | chains=3, chainRadius=1.5, chainFalloff=0.75 |
| L2 | 650 | 48 | 1.1 | 2.8 | chains=3, chainRadius=1.5, chainFalloff=0.75 |
| L3A | 1250 | 60 | 1 | 3 | chains=5, chainRadius=1.7, chainFalloff=0.8 |
| L3B | 1250 | 90 | 1.15 | 3 | chains=2, chainRadius=1.5, chainFalloff=0.75, bossBonus=0.2 |

L3A: Tempestade. L3B: Alta tensão.

## Maestro

ID `maestro`. Apoio de velocidade. Desbloqueio: 450 botões. Máximo por jogador: 2.

| Estado | Custo | Dano | Intervalo | Alcance | Efeito |
| --- | --- | --- | --- | --- | --- |
| L0 | 500 | 0 | 0 | 2.2 | haste=0.08 |
| L1 | 300 | 0 | 0 | 2.4 | haste=0.12 |
| L2 | 600 | 0 | 0 | 2.6 | haste=0.16 |
| L3A | 1150 | 0 | 0 | 3.2 | haste=0.18 |
| L3B | 1150 | 0 | 0 | 2.6 | haste=0.25 |

L3A: Orquestra. L3B: Solo.

## Inimigos comuns

| ID | Vida | Velocidade | Sucata | Dano na base | Armadura |
| --- | --- | --- | --- | --- | --- |
| fiapo | 24 | 1.25 | 8 | 2 | 0 |
| corrisco | 32 | 2.05 | 10 | 3 | 0 |
| bolota | 150 | 0.85 | 22 | 6 | 0 |
| latinha | 115 | 1 | 20 | 5 | 0.45 |
| nevoa | 75 | 1.45 | 17 | 4 | 0 |
| remendo | 180 | 1 | 28 | 6 | 0 |
| casulo | 230 | 0.9 | 30 | 8 | 0.15 |
| brutamontes | 600 | 0.65 | 65 | 14 | 0.25 |

## Chefes

A vida abaixo já corresponde ao chefe do seu mapa. Aplicar somente cooperação e dificuldade, sem multiplicador adicional do mapa. Todos causam 100 de dano ao vazar, não dão sucata própria e recebem apenas 35% da força normal de lentidão.

| Chefe | Vida | Velocidade | Armadura | Período da habilidade |
| --- | --- | --- | --- | --- |
| Aspirador Rabugento | 7000 | 0.4 | 0.15 | 14 s |
| Rei Ferrugem | 8500 | 0.4 | 0.2 | 14 s |
| Breu debaixo da cama | 10000 | 0.4 | 0.1 | 16 s |

## Roteiro das ondas

Grupos aparecem na ordem da tabela. Há dois segundos entre grupos. O chefe entra dois segundos após o último grupo da onda 20. Intervalos: 1,1 s nas ondas 1 a 4; 0,85 s nas ondas 5 a 10; 0,65 s nas ondas 11 a 20.

| Onda | Composição | Sucata por jogador ao concluir |
| --- | --- | --- |
| 1 | 12 fiapo | 135 |
| 2 | 16 fiapo | 150 |
| 3 | 12 fiapo; 6 corrisco | 165 |
| 4 | 20 fiapo; 2 bolota | 180 |
| 5 | 12 corrisco; 4 bolota | 195 |
| 6 | 20 fiapo; 6 latinha | 210 |
| 7 | 16 corrisco; 8 latinha | 225 |
| 8 | 6 bolota; 12 nevoa | 240 |
| 9 | 24 fiapo; 10 latinha; 2 remendo | 255 |
| 10 | 20 corrisco; 8 bolota; 3 remendo | 270 |
| 11 | 18 nevoa; 5 casulo | 285 |
| 12 | 16 latinha; 6 casulo | 300 |
| 13 | 24 corrisco; 2 brutamontes; 4 remendo | 315 |
| 14 | 20 nevoa; 18 latinha; 6 casulo | 330 |
| 15 | 4 brutamontes; 5 remendo; 12 bolota | 345 |
| 16 | 30 corrisco; 10 casulo; 18 latinha | 360 |
| 17 | 6 brutamontes; 24 nevoa; 6 remendo | 375 |
| 18 | 25 latinha; 12 casulo; 5 brutamontes | 390 |
| 19 | 32 corrisco; 8 brutamontes; 7 remendo | 405 |
| 20 | 20 fiapo; 14 latinha; 4 remendo | 420 |

## Coordenadas dos mapas

Coordenadas inteiras de centro de célula, origem no canto superior esquerdo. Todos os segmentos são ortogonais. O caminho ocupa cada célula atravessada, inclusive as extremidades. Células bloqueadas são adicionais ao caminho.

### Jardim de Papel

ID `jardim`. Multiplicador de vida dos inimigos comuns: 1. Chefe: `aspirador`.

Caminho: [[0, 2], [4, 2], [4, 6], [9, 6], [9, 3], [13, 3], [13, 8], [15, 8]].

Bloqueios: [[1, 8], [2, 8], [11, 0], [12, 0], [0, 9]].

### Oficina de Lata

ID `oficina`. Multiplicador de vida dos inimigos comuns: 1.12. Chefe: `rei_ferrugem`.

Caminho: [[0, 7], [3, 7], [3, 2], [7, 2], [7, 7], [11, 7], [11, 3], [15, 3]].

Bloqueios: [[0, 0], [1, 0], [14, 9], [15, 9], [8, 9]].

### Sótão das Estrelas

ID `sotao`. Multiplicador de vida dos inimigos comuns: 1.25. Chefe: `breu`.

Caminho: [[0, 1], [5, 1], [5, 5], [2, 5], [2, 8], [10, 8], [10, 2], [14, 2], [14, 6], [15, 6]].

Bloqueios: [[8, 0], [9, 0], [6, 9], [7, 9], [15, 0]].
