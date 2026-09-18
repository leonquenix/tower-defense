# Exemplos de componentes

Theme e ButtonFeedback são pontos de partida, não uma UI inteira implementada. Não foram executados no Roblox Studio.

O chamador cria um TextButton com UICorner, UIStroke, UIPadding e TextLabel nativo. Reserve espaço para a escala sem mudar a célula do layout. Não aplique dois UIScale ao mesmo botão; uma escala global deve ficar no ancestral.

ButtonFeedback.bind recebe o botão, uma callback que emite a intenção e uma função que retorna a preferência efetiva de movimento reduzido. Para ação remota, a callback deve chamar setState(true, true) antes de enviar o pedido. Ao receber ACK ou rejeição reconciliada, atualizar o store, texto e cores e chamar setState(true, false). Para indisponível, usar setState(false, false) e mostrar o motivo em texto.

A resposta tardia atualiza o store mesmo que o componente tenha sido destruído; não capturar uma instância antiga em callback. Chame destroy ao desmontar. Cancele operações locais por token; não tente desfazer transações aceitas no servidor. refreshMotion deve ser chamado quando a preferência de movimento mudar.

FocusRing usa ink para contraste; seletores podem usar um acento cyan adicional. A callback deve ser segura contra erro; produção deve passar pelo CommandAdapter central. O módulo não faz autenticação, debounce de rede, persistência, áudio, tradução nem roteamento. Implementar esses serviços conforme o guia e testar no Studio.
