--!strict
-- Ponte Charm -> Fusion: transforma um átomo (ou qualquer leitura reativa) em um estado Fusion.
--
-- Charm é a fonte da verdade do jogo; Fusion só desenha. A assinatura é registrada no escopo
-- Fusion, então ela morre junto com a tela — sem listener órfão atualizando um Frame destruído.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Shared.Lib.Charm)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)

local Bridge = {}

export type Scope = Fusion.Scope<any>

-- Estado Fusion que acompanha uma leitura reativa de Charm.
function Bridge.use<T>(scope: Scope, source: () -> T): Fusion.Value<T>
	local value = Fusion.Value(scope, source())
	local unsubscribe = Charm.subscribe(source, function(newValue: T)
		value:set(newValue)
	end)
	table.insert(scope, unsubscribe)
	return value
end

-- Versão derivada: aplica uma função ao valor observado (evita um Computed extra por campo).
function Bridge.map<T, U>(scope: Scope, source: () -> T, transform: (T) -> U): Fusion.Value<U>
	local value = Fusion.Value(scope, transform(source()))
	local unsubscribe = Charm.subscribe(source, function(newValue: T)
		value:set(transform(newValue))
	end)
	table.insert(scope, unsubscribe)
	return value
end

-- Efeito colateral ligado ao ciclo de vida do escopo (câmera, som, foco…).
function Bridge.watch<T>(scope: Scope, source: () -> T, handler: (T) -> ())
	handler(source())
	local unsubscribe = Charm.subscribe(source, handler)
	table.insert(scope, unsubscribe)
end

-- Observação fora de um escopo Fusion (controladores e apresentação). Devolve o cancelamento.
function Bridge.watchAtom<T>(source: () -> T, handler: (T) -> ()): () -> ()
	handler(source())
	return Charm.subscribe(source, handler)
end

return Bridge
