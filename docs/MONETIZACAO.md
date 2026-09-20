# Quintal em Guarda — Estratégia de monetização

*Documento de pitch. Versão de 2026-09-20.*

## A tese em uma frase

Tower defense de campanha no Roblox, com progressão por estrelas e coleção de torres: o jogador
volta pelas fases, e **paga por identidade e por tempo — nunca por poder**.

## O princípio que não se negocia

**Nada que se compra ganha partida.** Toda torre e toda melhoria são desbloqueadas jogando. O que
se vende é aparência, atalho de tempo e acesso antecipado. Isso protege o boca a boca (o público
do Roblox reage mal a pay-to-win) e mantém o balanceamento sob controle: uma única regra de
economia, sem variantes pagas para testar.

## As três fontes de receita

| # | Produto | O que é | Preço sugerido | Quando entra |
|---|---------|---------|----------------|--------------|
| 1 | **Passe Fundador** | Passe único: skin das 6 torres + banner + título exclusivos. Some do catálogo depois da janela de lançamento. | 149 Robux | Lançamento |
| 2 | **Pacotes de Botões** | Moeda do jogo (hoje só se ganha jogando; abre torres: 240, 450 e 600 botões). Compra é atalho, não exclusividade. | 3 pacotes: 80 / 400 / 1.000 Robux | Mês 1 |
| 3 | **Temporadas** | A cada 6–8 semanas: fases novas de graça + passe cosmético da temporada (skins, molduras, títulos). | 199 Robux por temporada | Mês 3 |

Passiva, sem produto: **Premium Payouts** do Roblox, proporcional ao tempo que assinantes passam
no jogo. Não se vende nada — entra por retenção.

**Já pronto no código:** passe fundador (desligado, à espera do ID no Creator Hub), moeda de
botões, catálogo de cosméticos e recompensas por domínio de torre. Falta a arte dos cosméticos e
criar os produtos no Creator Hub.

## Quanto isso pode dar

Cenário mensal, **hipótese** com as premissas à vista. Líquido = já descontada a taxa da
plataforma e a conversão para dólar (conferir a política vigente antes de fechar número).

| Jogadores/dia | Premissa de gasto | Receita bruta/mês | Líquido estimado/mês |
|---------------|-------------------|-------------------|----------------------|
| 1.000 | US$ 0,015 por jogador/dia | ~US$ 450 | ~US$ 110 |
| 5.000 | US$ 0,020 por jogador/dia | ~US$ 3.000 | ~US$ 735 |
| 20.000 | US$ 0,030 por jogador/dia | ~US$ 18.000 | ~US$ 4.400 |

A conta que importa não é o preço do passe: é **quantos jogadores por dia** e **quantos dias cada
um volta**. Monetização aqui é consequência de retenção.

## O que precisa ser verdade para funcionar

- **1 a 3%** dos jogadores comprando alguma coisa (patamar normal de jogo cosmético no Roblox).
- **Retenção D1 acima de 30%** — sem isso, tráfego pago e receita não se sustentam.
- **Campanha sempre à frente do jogador**: conteúdo novo antes de ele terminar o que tem.

## Primeiros 90 dias

1. **Lançar sem loja.** Medir retenção e sessão com o jogo inteiro de graça.
2. **Passe Fundador** quando a retenção D1 passar de 30%, com janela de tempo declarada.
3. **Pacotes de Botões** com a curva de ganho já calibrada pelos dados reais.
4. **Primeira temporada** no mês 3, com fases novas gratuitas puxando o passe.

## Riscos e como tratamos

| Risco | Tratamento |
|-------|-----------|
| Acusação de pay-to-win | Nada vendido afeta combate. Regra escrita no design e no código. |
| Caixa aleatória / sorte paga | Não existe. Todo produto mostra exatamente o que entrega. |
| Público infantil | Sem urgência artificial, sem contagem regressiva de compra, preços redondos e poucos. |
| Dependência de uma receita só | Três fontes independentes + Premium Payouts. |

## O que decidir nesta conversa

1. Preço do Passe Fundador: manter 149 Robux ou testar 99?
2. Janela do fundador: 30 dias ou até o fim da primeira temporada?
3. Orçamento de arte para os cosméticos (6 skins + banner + título) antes do lançamento.
