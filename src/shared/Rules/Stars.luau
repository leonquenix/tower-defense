--!strict
-- Estrelas de uma fase da campanha. Regra pura: recebe a fase e as estatísticas da partida,
-- devolve quantas estrelas e quais objetivos foram cumpridos.
--
-- A primeira estrela é sempre vencer. As outras duas são os `objectives` da fase, e só contam
-- se a partida foi vencida — não existe "perdi mas levei estrela".
local Types = require(script.Parent.Parent.Types)

local Stars = {}

export type Outcome = { stars: number, earned: { boolean } }

-- Um objetivo isolado. Devolve false para objetivo desconhecido: fase com dado novo num
-- cliente velho não vira estrela de graça.
function Stars.objectiveMet(objective: Types.ObjectiveDef, stats: Types.CampaignStats): boolean
	local kind = objective.kind
	if kind == "noLeak" then
		return stats.damageTaken <= 0
	elseif kind == "maxDamage" then
		return stats.damageTaken <= (objective.value or 0)
	elseif kind == "maxTowers" then
		return stats.towersBuilt <= (objective.value or 0)
	elseif kind == "onlyTowers" then
		local allowed: { [string]: boolean } = {}
		for _, towerId in ipairs(objective.towers or {}) do
			allowed[towerId] = true
		end
		for towerId in pairs(stats.towerIds) do
			if not allowed[towerId] then
				return false
			end
		end
		-- construir nenhuma torre não cumpre "só com estas": é preciso ter jogado com elas
		return next(stats.towerIds) ~= nil
	elseif kind == "rushAll" then
		return stats.wavesTotal > 0 and stats.wavesRushed >= stats.wavesTotal
	end
	return false
end

-- Texto de apoio fica na interface (Localization); aqui só a regra.
function Stars.evaluate(level: Types.LevelDef, won: boolean, stats: Types.CampaignStats): Outcome
	local earned: { boolean } = { won }
	for _, objective in ipairs(level.objectives) do
		table.insert(earned, won and Stars.objectiveMet(objective, stats))
	end
	local total = 0
	for _, ok in ipairs(earned) do
		if ok then
			total += 1
		end
	end
	return { stars = total, earned = earned }
end

return Stars
