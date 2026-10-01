# Quintal em Guarda — Estratégia de monetização

*Documento de pitch. Versão de 2026-09-20.*

## A tese em uma frase

Tower defense de campanha no Roblox, com progressão por estrelas e coleção de torres: o jogador
volta pelas fases, e **paga por identidade e por tempo — nunca por poder**.

## Política (revista em 2026-09-28)

A regra "nada que se compra afeta o combate" foi **substituída** por decisão do responsável: vender
ajuda de jogo é permitido (repetir onda, torre extra e, depois, outras vantagens). O que continua
valendo, por política do Roblox, pelo público infantil e por coerência de dados:

- **Nada aleatório pago**: sem caixa surpresa nem gacha.
- **Recomeçar a fase é sempre grátis** e está sempre à vista na derrota.
- **Compra só por ação do jogador**, num botão com o preço real do Roblox. Nada abre sozinho, sem
  cronômetro falso, sem escassez inventada, sem dificuldade ajustada pelo que a pessoa já gastou.
- **Comprar guarda; usar é outra ação.** A ficha nunca é consumida automaticamente.
- **Ajuda não compra estrela de objetivo**: vitória com Retomada ou Reforço abre a próxima fase,
  mas as estrelas 2 e 3 pedem uma partida sem ajuda.
- **A campanha precisa dar para vencer de graça.** Dificuldade que "pede" compra fica no conteúdo
  opcional.

### Implementado nesta versão (Teste 1)

| Produto | Entrega | Regra de uso | Fontes grátis |
|---|---|---|---|
| Retomada (`retry_1`, `retry_3`) | repete a onda perdida com o Farol cheio; torres e sucata voltam ao início da onda | uma por partida, cobre o grupo; fora da fase 1 e do treino | 1ª vitória da fase 2, dia 7 da diária, presente de 45 min, níveis múltiplos de 5, 300 botões |
| Reforço (`support_1`, `support_3`) | uma torre da equipe no L0 de graça | só na preparação, um por jogador; venda devolve só as melhorias | 1ª vitória da fase 3, dia 3 da diária, presente de 20 min |

Técnica: `ShopService` é o roteador único de `ProcessReceipt`; a entrega é idempotente pelo
`PurchaseId` guardado no perfil (`ProfileSchema.applyPurchase`) e só responde "entregue" depois
de o ProfileStore confirmar a gravação. Retomada e Reforço são validados pela simulação
(`Simulation.applyRetry`, `placeTower { free = true }`), e a ficha só é gasta quando o efeito
acontece. Números e produtos vivem em `balanceamento_v1.json` (`shop`, `progression`, `retention`).

## As três fontes de receita

| # | Produto | O que é | Preço sugerido | Quando entra |
|---|---------|---------|----------------|--------------|
| 1 | **Passe Fundador** | Passe único: skin das 6 torres + banner + título exclusivos. Some do catálogo depois da janela de lançamento. | 149 Robux | Lançamento |
| 2 | **Pacotes de Botões** | Moeda do jogo (hoje só se ganha jogando; abre torres: 240, 450 e 600 botões). Compra é atalho, não exclusividade. | 3 pacotes: 80 / 400 / 1.000 Robux | Mês 1 |
| 3 | **Temporadas** | A cada 6–8 semanas: fases novas de graça + passe cosmético da temporada (skins, molduras, títulos). | 199 Robux por temporada | Mês 3 |

Passiva, sem produto: **Premium Payouts** do Roblox, proporcional ao tempo que assinantes passam
no jogo. Não se vende nada — entra por retenção.

**Já pronto no código:** passe fundador (desligado, à espera do ID no Creator Hub), fichas de
Retomada e Reforço (à espera dos IDs dos Developer Products), moeda de botões, nível de conta,
recompensa diária, presentes de sessão, catálogo de cosméticos e recompensas por domínio de torre. Falta a arte dos cosméticos e
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
