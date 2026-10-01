--!strict
-- Regras puras de combate: dano, resistências, efeitos, aquisição de alvos, explosão e corrente.
local Types = require(script.Parent.Parent.Types)
local Grid = require(script.Parent.Parent.Math.Grid)

local Combat = {}

export type DamageInput = {
	baseDamage: number,
	damageType: Types.DamageType,
	bossBonus: number?, -- bônus contra chefe da torre (só vale se isBoss)
	circuitBonus: number?, -- bônus de Circuito aplicável a este acerto
	armorIgnore: number?,
	mark: number, -- maior marca ativa no alvo
	armor: number, -- armadura atual do alvo (inclui bônus de chefe)
	energyResistance: number,
	isBoss: boolean,
	armorCap: number,
	boost: number?, -- aura de dano (Fofo) da torre que atira
	frozenBonus: number?, -- dano extra no alvo congelado (Geladeira)
}

function Combat.effectiveArmor(armor: number, armorIgnore: number?, armorCap: number): number
	local ignore = armorIgnore or 0
	return math.clamp(armor * (1 - ignore), 0, armorCap)
end

function Combat.computeDamage(input: DamageInput): number
	local bossBonus = if input.isBoss then (input.bossBonus or 0) else 0
	local bonus = (1 + bossBonus) * (1 + (input.circuitBonus or 0)) * (1 + (input.boost or 0))
	local vulnerability = (1 + input.mark) * (1 + (input.frozenBonus or 0))
	local resistance = 0
	if input.damageType == "physical" then
		resistance = Combat.effectiveArmor(input.armor, input.armorIgnore, input.armorCap)
	elseif input.damageType == "energy" then
		resistance = math.clamp(input.energyResistance, 0, 1)
	end
	return input.baseDamage * bonus * vulnerability * (1 - resistance)
end

-- Remove efeitos expirados (in place) e devolve a maior força ativa.
function Combat.pruneAndMax(effects: { Types.TimedEffect }, simTime: number): number
	local maxStrength = 0
	local i = 1
	while i <= #effects do
		local e = effects[i]
		if e.expiresAt <= simTime then
			table.remove(effects, i)
		else
			if e.strength > maxStrength then
				maxStrength = e.strength
			end
			i += 1
		end
	end
	return maxStrength
end

-- Lentidão ativa efetiva: maior força; chefes multiplicam por bossSlowStrength antes do limite.
function Combat.activeSlow(enemy: Types.Enemy, simTime: number, effects: Types.EffectsDef): number
	local strength = Combat.pruneAndMax(enemy.slows, simTime)
	if strength <= 0 then
		return 0
	end
	if enemy.isBoss then
		strength *= effects.bossSlowStrength
	end
	return math.min(strength, effects.slowCap)
end

function Combat.activeMark(enemy: Types.Enemy, simTime: number): number
	return Combat.pruneAndMax(enemy.marks, simTime)
end

function Combat.isSlowed(enemy: Types.Enemy, simTime: number): boolean
	return Combat.pruneAndMax(enemy.slows, simTime) > 0
end

-- Aplica/renova um efeito temporizado. Marcas e lentidões não se somam: guardamos todas
-- e usamos a maior ativa; a mesma fonte renova sua duração em vez de duplicar.
function Combat.applyEffect(
	effects: { Types.TimedEffect },
	strength: number,
	duration: number,
	sourceTowerId: number,
	simTime: number
)
	local expiresAt = simTime + duration
	for _, e in ipairs(effects) do
		if e.sourceTowerId == sourceTowerId and e.strength == strength then
			e.expiresAt = math.max(e.expiresAt, expiresAt)
			return
		end
	end
	table.insert(effects, { strength = strength, expiresAt = expiresAt, sourceTowerId = sourceTowerId })
end

-- Armadura raspada ativa: a maior entre as fontes (cada Escovinha guarda a sua, e a Escova de Aço
-- acumula na própria entrada), limitada por shredCap.
function Combat.activeShred(enemy: Types.Enemy, simTime: number, shredCap: number?): number
	return math.min(Combat.pruneAndMax(enemy.shreds, simTime), shredCap or 1)
end

-- Armadura atual: base + reforço do Rei Ferrugem - raspagem, nunca negativa.
function Combat.currentArmor(enemy: Types.Enemy, simTime: number, shredCap: number?): number
	local armor = enemy.armor
	if enemy.isBoss and enemy.bossArmorUntil > simTime then
		armor += enemy.bossArmorBonus
	end
	if #enemy.shreds > 0 then
		armor -= Combat.activeShred(enemy, simTime, shredCap)
	end
	return math.max(armor, 0)
end

-- Raspa a armadura. Sem acúmulo, a mesma fonte só renova; com acúmulo (stacks > 1) cada acerto
-- soma `amount` até amount x stacks na entrada da própria torre, e renova a duração.
function Combat.applyShred(
	effects: { Types.TimedEffect },
	amount: number,
	duration: number,
	sourceTowerId: number,
	simTime: number,
	stacks: number?
)
	local maxStacks = stacks or 1
	if maxStacks <= 1 then
		Combat.applyEffect(effects, amount, duration, sourceTowerId, simTime)
		return
	end
	local expiresAt = simTime + duration
	for _, e in ipairs(effects) do
		if e.sourceTowerId == sourceTowerId then
			if e.expiresAt <= simTime then
				e.strength = amount
			else
				e.strength = math.min(e.strength + amount, amount * maxStacks)
			end
			e.expiresAt = expiresAt
			return
		end
	end
	table.insert(effects, { strength = amount, expiresAt = expiresAt, sourceTowerId = sourceTowerId })
end

-- Queimadura: uma entrada por torre. Reacender renova a duração e adota a força nova (a torre pode
-- ter melhorado); entre torres diferentes vale a mais forte, sem somar.
function Combat.applyBurn(
	burns: { Types.BurnEffect },
	dps: number,
	duration: number,
	sourceTowerId: number,
	ownerUserId: number,
	simTime: number
)
	local expiresAt = simTime + duration
	for _, b in ipairs(burns) do
		if b.sourceTowerId == sourceTowerId then
			b.strength = dps
			b.expiresAt = math.max(b.expiresAt, expiresAt)
			b.ownerUserId = ownerUserId
			return
		end
	end
	table.insert(
		burns,
		{ strength = dps, expiresAt = expiresAt, sourceTowerId = sourceTowerId, ownerUserId = ownerUserId }
	)
end

-- A queimadura mais forte ativa (poda as vencidas). nil quando nada queima.
function Combat.activeBurn(enemy: Types.Enemy, simTime: number): Types.BurnEffect?
	local best: Types.BurnEffect? = nil
	local i = 1
	local burns = enemy.burns
	while i <= #burns do
		local b = burns[i]
		if b.expiresAt <= simTime then
			table.remove(burns, i)
		else
			if best == nil or b.strength > best.strength then
				best = b
			end
			i += 1
		end
	end
	return best
end

-- Enquanto queima, o inimigo não recebe cura de ninguém (Remendo, Esponjão encharcado).
function Combat.isHealBlocked(enemy: Types.Enemy, simTime: number): boolean
	return Combat.activeBurn(enemy, simTime) ~= nil
end

function Combat.isFrozen(enemy: Types.Enemy, simTime: number): boolean
	return enemy.freezeUntil > simTime
end

-- Quanto um empurrão realmente anda: zero em recarga ou com o teto da vida esgotado; chefe recebe
-- só bossPushFactor. Nunca passa do começo do caminho (o inimigo não sai da rota).
function Combat.pushDistance(enemy: Types.Enemy, push: number, simTime: number, effects: Types.EffectsDef): number
	if simTime < enemy.pushReadyAt then
		return 0
	end
	local amount = push * (if enemy.isBoss then effects.bossPushFactor else 1)
	amount = math.min(amount, math.max(effects.maxPushPerEnemy - enemy.pushedTotal, 0), math.max(enemy.s, 0))
	return math.max(amount, 0)
end

-- Intervalo efetivo com aura (maior haste) e poeira do Aspirador.
function Combat.effectiveInterval(baseInterval: number, haste: number, dusted: boolean, dustFactor: number): number
	local interval = baseInterval / (1 + haste)
	if dusted then
		interval /= dustFactor
	end
	return interval
end

export type TowerPos = { x: number, y: number }

-- Maior aura de dano (Fofo) em alcance. Mesma regra da cadência: vale a maior, sem somar, e a
-- torre de apoio não reforça a si mesma.
function Combat.boostFor(
	tower: Types.Tower,
	towers: { Types.Tower },
	getBoost: (Types.Tower) -> number?,
	getRange: (Types.Tower) -> number
): number
	local best = 0
	for _, other in ipairs(towers) do
		if other.id ~= tower.id then
			local boost = getBoost(other)
			if boost and boost > best then
				if Grid.distance(tower.x, tower.y, other.x, other.y) <= getRange(other) + 1e-9 then
					best = boost
				end
			end
		end
	end
	return best
end

-- Maior haste de Maestros em alcance da torre (Maestro não acelera Maestro).
function Combat.hasteFor(
	tower: Types.Tower,
	towers: { Types.Tower },
	getHaste: (Types.Tower) -> number?,
	getRange: (Types.Tower) -> number
): number
	if tower.defId == "maestro" then
		return 0
	end
	local best = 0
	for _, other in ipairs(towers) do
		if other.id ~= tower.id then
			local haste = getHaste(other)
			if haste and haste > 0 then
				local d = Grid.distance(tower.x, tower.y, other.x, other.y)
				if d <= getRange(other) + 1e-9 and haste > best then
					best = haste
				end
			end
		end
	end
	return best
end

export type EnemyPos = { enemy: Types.Enemy, px: number, py: number }

-- Seleção de alvo entre inimigos vivos em alcance. Empates: menor ID.
function Combat.selectTarget(
	tower: Types.Tower,
	range: number,
	candidates: { EnemyPos },
	mode: Types.TargetMode
): EnemyPos?
	local best: EnemyPos? = nil
	local bestScore = 0
	for _, c in ipairs(candidates) do
		local e = c.enemy
		if e.alive then
			local d = Grid.distance(tower.x, tower.y, c.px, c.py)
			if d <= range + 1e-9 then
				local score: number
				if mode == "first" then
					score = e.s
				elseif mode == "last" then
					score = -e.s
				elseif mode == "strongest" then
					score = e.hp
				else
					score = -d
				end
				if
					best == nil
					or score > bestScore + 1e-9
					or (math.abs(score - bestScore) <= 1e-9 and e.id < best.enemy.id)
				then
					best = c
					bestScore = score
				end
			end
		end
	end
	return best
end

-- Língua de Sogra: o inimigo comum (não chefe) com mais vida no alcance. Empate: menor ID.
function Combat.selectGrabTarget(tower: Types.Tower, range: number, candidates: { EnemyPos }): EnemyPos?
	local best: EnemyPos? = nil
	for _, c in ipairs(candidates) do
		local e = c.enemy
		if e.alive and not e.isBoss and Grid.distance(tower.x, tower.y, c.px, c.py) <= range + 1e-9 then
			if
				best == nil
				or e.hp > best.enemy.hp + 1e-9
				or (math.abs(e.hp - best.enemy.hp) <= 1e-9 and e.id < best.enemy.id)
			then
				best = c
			end
		end
	end
	return best
end

-- Pião: todos os inimigos no alcance, do mais adiantado para trás (empate: menor ID), até o teto.
function Combat.allInRange(tower: Types.Tower, range: number, candidates: { EnemyPos }, cap: number): { EnemyPos }
	local list: { EnemyPos } = {}
	for _, c in ipairs(candidates) do
		if c.enemy.alive and Grid.distance(tower.x, tower.y, c.px, c.py) <= range + 1e-9 then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		if math.abs(a.enemy.s - b.enemy.s) > 1e-9 then
			return a.enemy.s > b.enemy.s
		end
		return a.enemy.id < b.enemy.id
	end)
	while #list > cap do
		table.remove(list)
	end
	return list
end

-- Alvos da queimadura que pula (Enxame): os mais próximos do alvo principal, sem ele.
function Combat.spreadTargets(primary: EnemyPos, candidates: { EnemyPos }, radius: number, count: number): { EnemyPos }
	local others: { { pos: EnemyPos, d: number } } = {}
	for _, c in ipairs(candidates) do
		if c.enemy.alive and c.enemy.id ~= primary.enemy.id then
			local d = Grid.distance(primary.px, primary.py, c.px, c.py)
			if d <= radius + 1e-9 then
				table.insert(others, { pos = c, d = d })
			end
		end
	end
	table.sort(others, function(a, b)
		if math.abs(a.d - b.d) > 1e-9 then
			return a.d < b.d
		end
		return a.pos.enemy.id < b.pos.enemy.id
	end)
	local out: { EnemyPos } = {}
	for i = 1, math.min(count, #others) do
		table.insert(out, others[i].pos)
	end
	return out
end

-- Alvos de explosão: primário + mais próximos do centro do primário (raio inclusive), até maxTargets no total.
function Combat.splashTargets(
	primary: EnemyPos,
	candidates: { EnemyPos },
	radius: number,
	maxTargets: number
): { EnemyPos }
	local others: { { pos: EnemyPos, d: number } } = {}
	for _, c in ipairs(candidates) do
		if c.enemy.alive and c.enemy.id ~= primary.enemy.id then
			local d = Grid.distance(primary.px, primary.py, c.px, c.py)
			if d <= radius + 1e-9 then
				table.insert(others, { pos = c, d = d })
			end
		end
	end
	table.sort(others, function(a, b)
		if math.abs(a.d - b.d) > 1e-9 then
			return a.d < b.d
		end
		return a.pos.enemy.id < b.pos.enemy.id
	end)
	local result = { primary }
	for _, o in ipairs(others) do
		if #result >= maxTargets then
			break
		end
		table.insert(result, o.pos)
	end
	return result
end

-- Alvos de corrente: cada salto procura o inimigo ainda não atingido mais próximo do anterior dentro de chainRadius.
function Combat.chainTargets(
	primary: EnemyPos,
	candidates: { EnemyPos },
	chains: number,
	chainRadius: number
): { EnemyPos }
	local result = { primary }
	local hit: { [number]: boolean } = { [primary.enemy.id] = true }
	local last = primary
	while #result < chains do
		local best: EnemyPos? = nil
		local bestD = math.huge
		for _, c in ipairs(candidates) do
			local e = c.enemy
			if e.alive and not hit[e.id] then
				local d = Grid.distance(last.px, last.py, c.px, c.py)
				if d <= chainRadius + 1e-9 then
					if d < bestD - 1e-9 or (math.abs(d - bestD) <= 1e-9 and best ~= nil and e.id < best.enemy.id) then
						best = c
						bestD = d
					end
				end
			end
		end
		if best == nil then
			break
		end
		hit[best.enemy.id] = true
		table.insert(result, best)
		last = best
	end
	return result
end

-- Fração restante de cooldown preservada ao melhorar (evita disparo grátis ao comprar).
function Combat.carryCooldown(cooldown: number, oldInterval: number, newInterval: number): number
	if oldInterval <= 0 or cooldown <= 0 then
		return 0
	end
	return (cooldown / oldInterval) * newInterval
end

return Combat
