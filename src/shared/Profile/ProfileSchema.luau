--!strict
-- Esquema do perfil persistente: padrão, migrações puras e idempotentes, validação.
local Types = require(script.Parent.Parent.Types)
local Balance = require(script.Parent.Parent.Config.Balance)
local Catalog = require(script.Parent.Parent.Config.Catalog)
local Products = require(script.Parent.Parent.Config.Products)
local DevFlags = require(script.Parent.Parent.Config.DevFlags)

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 2
ProfileSchema.REWARD_RETENTION_SECONDS = 30 * 24 * 3600
ProfileSchema.REWARD_LEDGER_LIMIT = 1024
ProfileSchema.TUTORIAL_KEY = "tutorial-v1"

function ProfileSchema.defaultSettings(): Types.ProfileSettings
	return {
		musicVolume = 0.6,
		sfxVolume = 0.8,
		reducedMotion = false,
		reducedParticles = false,
		damageNumbers = true,
		circuitPattern = "solid",
		locale = "pt-br",
	}
end

function ProfileSchema.default(now: number): Types.Profile
	return {
		schemaVersion = ProfileSchema.CURRENT_VERSION,
		buttons = 0,
		ownedTowerIds = Catalog.starterTowerIds(),
		loadout = Catalog.starterTowerIds(),
		cosmeticsOwned = {},
		cosmeticLoadout = {},
		masteryByTower = {},
		mapUnlocks = {},
		tutorialRewardClaimed = false,
		tutorialCompleted = false,
		settings = ProfileSchema.defaultSettings(),
		lifetimeStats = {
			matches = 0,
			wins = 0,
			losses = 0,
			wavesCleared = 0,
			enemiesDefeated = 0,
			towersPlaced = 0,
			buttonsEarned = 0,
		},
		recentMatchRewards = {},
		pendingResults = {},
		sessionLock = nil,
		createdAt = now,
		updatedAt = now,
	}
end

-- Migrações: cada função recebe a tabela crua e devolve a versão seguinte. São idempotentes por versão.
local migrations: { [number]: (any, number) -> any } = {}

-- v1 -> v2: acrescenta tutorialCompleted, pendingResults e lifetimeStats.buttonsEarned
migrations[1] = function(data: any, now: number): any
	data.schemaVersion = 2
	if data.tutorialCompleted == nil then
		data.tutorialCompleted = data.tutorialRewardClaimed == true
	end
	if typeof(data.pendingResults) ~= "table" then
		data.pendingResults = {}
	end
	if typeof(data.lifetimeStats) ~= "table" then
		data.lifetimeStats = {}
	end
	if data.lifetimeStats.buttonsEarned == nil then
		data.lifetimeStats.buttonsEarned = 0
	end
	data.updatedAt = now
	return data
end

-- Aplica migrações em sequência. Retorna (perfil, alterado).
function ProfileSchema.migrate(raw: any, now: number): (Types.Profile?, boolean)
	if typeof(raw) ~= "table" then
		return nil, false
	end
	local data = raw
	local changed = false
	local version = data.schemaVersion
	if typeof(version) ~= "number" then
		version = 1
		data.schemaVersion = 1
		changed = true
	end
	while version < ProfileSchema.CURRENT_VERSION do
		local step = migrations[version]
		if not step then
			return nil, changed
		end
		data = step(data, now)
		version = data.schemaVersion
		changed = true
	end
	if version > ProfileSchema.CURRENT_VERSION then
		-- perfil de versão futura: não tocar
		return nil, changed
	end
	-- preenche campos ausentes com padrões sem apagar dados existentes
	local defaults = ProfileSchema.default(now)
	for key, value in pairs(defaults :: any) do
		if (data :: any)[key] == nil and key ~= "sessionLock" then
			(data :: any)[key] = value
			changed = true
		end
	end
	for key, value in pairs(defaults.settings :: any) do
		if data.settings[key] == nil then
			data.settings[key] = value
			changed = true
		end
	end
	return data :: Types.Profile, changed
end

local function isNonNegativeInt(v: any): boolean
	return typeof(v) == "number" and v == v and v >= 0 and math.floor(v) == v and v < 2 ^ 50
end

-- Validação estrutural antes de aceitar um perfil carregado.
function ProfileSchema.validate(profile: any): (boolean, string?)
	if typeof(profile) ~= "table" then
		return false, "não é tabela"
	end
	if profile.schemaVersion ~= ProfileSchema.CURRENT_VERSION then
		return false, "versão de esquema inesperada"
	end
	if not isNonNegativeInt(profile.buttons) then
		return false, "buttons inválido"
	end
	if typeof(profile.ownedTowerIds) ~= "table" or typeof(profile.loadout) ~= "table" then
		return false, "listas de torres ausentes"
	end
	for _, id in ipairs(profile.ownedTowerIds) do
		if not Catalog.getTower(id) then
			return false, "torre desconhecida no perfil: " .. tostring(id)
		end
	end
	for _, id in ipairs(profile.loadout) do
		if not Catalog.getTower(id) then
			return false, "torre desconhecida no loadout: " .. tostring(id)
		end
	end
	if #profile.loadout > Balance.loadoutSlots then
		return false, "loadout excede vagas"
	end
	if typeof(profile.masteryByTower) ~= "table" or typeof(profile.mapUnlocks) ~= "table" then
		return false, "domínio ou mapas ausentes"
	end
	for towerId, record in pairs(profile.masteryByTower) do
		if not Catalog.getTower(towerId) or typeof(record) ~= "table" or not isNonNegativeInt(record.points) then
			return false, "registro de domínio inválido"
		end
	end
	if typeof(profile.recentMatchRewards) ~= "table" or typeof(profile.settings) ~= "table" then
		return false, "ledger ou configurações ausentes"
	end
	return true, nil
end

function ProfileSchema.sanitizeSettings(input: { [string]: any }, current: Types.ProfileSettings): Types.ProfileSettings
	local out = table.clone(current)
	if typeof(input.musicVolume) == "number" then
		out.musicVolume = math.clamp(input.musicVolume, 0, 1)
	end
	if typeof(input.sfxVolume) == "number" then
		out.sfxVolume = math.clamp(input.sfxVolume, 0, 1)
	end
	if typeof(input.reducedMotion) == "boolean" then
		out.reducedMotion = input.reducedMotion
	end
	if typeof(input.reducedParticles) == "boolean" then
		out.reducedParticles = input.reducedParticles
	end
	if typeof(input.damageNumbers) == "boolean" then
		out.damageNumbers = input.damageNumbers
	end
	if input.circuitPattern == "solid" or input.circuitPattern == "dashed" then
		out.circuitPattern = input.circuitPattern
	end
	if input.locale == "pt-br" or input.locale == "en" then
		out.locale = input.locale
	end
	return out
end

-- Regras de desbloqueio de mapa/dificuldade. Chaves: "jardim:normal", "oficina:desafio" ...
function ProfileSchema.unlockKey(mapId: string, difficulty: string): string
	return mapId .. ":" .. difficulty
end

-- Regra da campanha, sem atalho: é ela que o jogo de verdade usa e o teste cobre.
function ProfileSchema.campaignUnlocked(profile: Types.Profile, mapId: string, difficulty: string): boolean
	if mapId == "jardim" and difficulty == "normal" then
		return profile.tutorialCompleted or profile.mapUnlocks["jardim:normal"] == true
	end
	return profile.mapUnlocks[ProfileSchema.unlockKey(mapId, difficulty)] == true
end

-- O que o jogo pergunta. Com o interruptor de desenvolvimento ligado, tudo abre.
function ProfileSchema.isMapUnlocked(profile: Types.Profile, mapId: string, difficulty: string): boolean
	if DevFlags.unlockAllMaps then
		return true
	end
	return ProfileSchema.campaignUnlocked(profile, mapId, difficulty)
end

-- Aplica desbloqueios após vitória normal/desafio. Retorna chaves novas.
function ProfileSchema.applyWinUnlocks(profile: Types.Profile, mapId: string, difficulty: string): { string }
	local added = {}
	local function unlock(key: string)
		if not profile.mapUnlocks[key] then
			profile.mapUnlocks[key] = true
			table.insert(added, key)
		end
	end
	if difficulty == "normal" then
		unlock(ProfileSchema.unlockKey(mapId, "desafio"))
		local nextMap: string? = nil
		if mapId == "jardim" then
			nextMap = "oficina"
		elseif mapId == "oficina" then
			nextMap = "sotao"
		end
		if nextMap then
			unlock(ProfileSchema.unlockKey(nextMap, "normal"))
		end
	end
	return added
end

-- Limpa o ledger de recompensas: remove entradas mais antigas que 30 dias. Retorna se atingiu o limite.
function ProfileSchema.pruneRewardLedger(profile: Types.Profile, now: number): boolean
	local cutoff = now - ProfileSchema.REWARD_RETENTION_SECONDS
	local count = 0
	for matchId, appliedAt in pairs(profile.recentMatchRewards) do
		if appliedAt < cutoff then
			profile.recentMatchRewards[matchId] = nil
		else
			count += 1
		end
	end
	return count >= ProfileSchema.REWARD_LEDGER_LIMIT
end

export type ApplyResultInput = {
	matchId: string,
	buttons: number,
	masteryByTower: { [string]: number },
	outcome: string,
	mode: Types.MatchMode,
	mapId: string,
	difficulty: string,
	wavesCompleted: number,
	enemiesDefeated: number?,
	towersPlaced: number?,
	createdAt: number,
	now: number,
}

export type ApplyResultOutcome = {
	applied: boolean,
	reason: string?,
	newMilestones: { [string]: { number } },
	unlocked: { string },
	-- Cosméticos concedidos pelos marcos de domínio cruzados neste resultado (30/100/250).
	grantedCosmetics: { string },
}

-- Aplica um resultado ao perfil de forma idempotente por matchId. Puro: não grava.
function ProfileSchema.applyMatchResult(profile: Types.Profile, input: ApplyResultInput): ApplyResultOutcome
	local out: ApplyResultOutcome =
		{ applied = false, reason = nil, newMilestones = {}, unlocked = {}, grantedCosmetics = {} }
	if input.now - input.createdAt > ProfileSchema.REWARD_RETENTION_SECONDS then
		out.reason = "expired"
		return out
	end
	if profile.recentMatchRewards[input.matchId] then
		out.reason = "duplicate"
		return out
	end
	local atLimit = ProfileSchema.pruneRewardLedger(profile, input.now)
	if atLimit then
		-- preserva proteção contra duplicidade: não aplica e registra necessidade de migração
		out.reason = "ledger_full"
		return out
	end
	profile.recentMatchRewards[input.matchId] = input.now
	profile.buttons += input.buttons
	profile.lifetimeStats.buttonsEarned += input.buttons
	profile.lifetimeStats.matches += 1
	if input.outcome == "won" then
		profile.lifetimeStats.wins += 1
	elseif input.outcome == "lost" then
		profile.lifetimeStats.losses += 1
	end
	profile.lifetimeStats.wavesCleared += input.wavesCompleted
	profile.lifetimeStats.enemiesDefeated += input.enemiesDefeated or 0
	profile.lifetimeStats.towersPlaced += input.towersPlaced or 0
	for towerId, points in pairs(input.masteryByTower) do
		if Catalog.getTower(towerId) and points > 0 then
			local record = profile.masteryByTower[towerId]
			if not record then
				record = { points = 0, milestones = {} }
				profile.masteryByTower[towerId] = record
			end
			local before = record.points
			record.points += points
			local reached = {}
			for _, m in ipairs(Balance.rewards.masteryMilestones) do
				if before < m and record.points >= m and table.find(record.milestones, m) == nil then
					table.insert(record.milestones, m)
					table.insert(reached, m)
				end
			end
			if #reached > 0 then
				out.newMilestones[towerId] = reached
				-- marco cruzado concede o cosmético correspondente (30 adesivo, 100 título, 250 aparência).
				-- A concessão é idempotente: o mesmo matchId nunca é aplicado duas vezes.
				local byMilestone = Products.masteryCosmetics(towerId)
				for _, milestone in ipairs(reached) do
					local cosmetic = byMilestone[milestone]
					if cosmetic and table.find(profile.cosmeticsOwned, cosmetic.id) == nil then
						table.insert(profile.cosmeticsOwned, cosmetic.id)
						table.insert(out.grantedCosmetics, cosmetic.id)
					end
				end
			end
		end
	end
	if input.mode == "normal" and input.outcome == "won" then
		out.unlocked = ProfileSchema.applyWinUnlocks(profile, input.mapId, input.difficulty)
	end
	if input.mode == "tutorial" and input.outcome == "won" then
		profile.tutorialCompleted = true
		profile.tutorialRewardClaimed = true
		profile.mapUnlocks["jardim:normal"] = true
	end
	-- remove referência pendente
	for i = #profile.pendingResults, 1, -1 do
		if profile.pendingResults[i].matchId == input.matchId then
			table.remove(profile.pendingResults, i)
		end
	end
	profile.updatedAt = input.now
	out.applied = true
	return out
end

function ProfileSchema.canBuyTower(profile: Types.Profile, towerId: string): (boolean, string?)
	local def = Catalog.getTower(towerId)
	if not def then
		return false, "INVALID_STATE"
	end
	if table.find(profile.ownedTowerIds, towerId) then
		return false, "INVALID_STATE"
	end
	if profile.buttons < def.unlock then
		return false, "INSUFFICIENT_FUNDS"
	end
	return true, nil
end

function ProfileSchema.buyTower(profile: Types.Profile, towerId: string, now: number): (boolean, string?)
	local ok, err = ProfileSchema.canBuyTower(profile, towerId)
	if not ok then
		return false, err
	end
	local def = Catalog.getTower(towerId) :: Types.TowerDef
	profile.buttons -= def.unlock
	table.insert(profile.ownedTowerIds, towerId)
	if #profile.loadout < Balance.loadoutSlots then
		table.insert(profile.loadout, towerId)
	end
	profile.updatedAt = now
	return true, nil
end

function ProfileSchema.setLoadout(profile: Types.Profile, towerIds: { string }, now: number): (boolean, string?)
	if #towerIds > Balance.loadoutSlots then
		return false, "INVALID_STATE"
	end
	local seen: { [string]: boolean } = {}
	for _, id in ipairs(towerIds) do
		if seen[id] or not Catalog.getTower(id) or table.find(profile.ownedTowerIds, id) == nil then
			return false, "INVALID_STATE"
		end
		seen[id] = true
	end
	profile.loadout = table.clone(towerIds)
	profile.updatedAt = now
	return true, nil
end

return ProfileSchema
