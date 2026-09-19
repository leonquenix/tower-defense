--!strict
-- Regra de "o que este toque significa" no modo de construção.
--
-- Mirar e apertar um botão ao mesmo tempo não funciona: no computador o clique na célula já
-- constrói. No toque, o dedo cobre a célula, então o primeiro toque posiciona e o segundo
-- constrói (o botão Construir continua existindo no celular como alternativa).
--
-- Módulo puro de propósito: é a regra mais sensível da interação e está coberta por teste.
local BuildIntent = {}

export type Decision = "place" | "position" | "blocked"

export type Tap = {
	touch: boolean, -- aparelho de toque
	guided: boolean, -- tutorial mandando a célula
	sameCell: boolean, -- o toque caiu na célula que já estava escolhida
	valid: boolean, -- a célula aceita a torre (regra local; o servidor confere de novo)
}

function BuildIntent.decide(tap: Tap): Decision
	if not tap.valid then
		return "blocked"
	end
	if tap.guided then
		-- no tutorial a célula é uma só: o primeiro toque já constrói
		return "place"
	end
	if not tap.touch then
		return "place"
	end
	return if tap.sameCell then "place" else "position"
end

return BuildIntent
