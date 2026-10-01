--!strict
-- Progressão da conta: XP, nível, o que cada nível entrega, recompensa diária e presentes de
-- sessão. Regras puras: recebem números e o perfil, devolvem o que mudou. Quem grava é o servidor.
local Types = require(script.Parent.Parent.Types)
local Balance = require(script.Parent.Parent.Config.Balance)

local Progression = {}

Progression.DAY_SECONDS = 86400

local function prog(): Types.ProgressionDef
	return Balance.progression
end

-- ---------------------------------------------------------------------------
-- XP e nível
-- ---------------------------------------------------------------------------

-- XP para ir do nível `level` ao seguinte.
function Progression.xpToNext(level: number): number
	local p = prog()
	return p.levelBase + p.levelStep * (math.max(level, 1) - 1)
end

-- XP total acumulado para chegar ao início de `level` (nível 1 = 0).
function Progression.xpForLevel(level: number): number
	local total = 0
	for n = 1, math.min(level, prog().maxLevel) - 1 do
		total += Progression.xpToNext(n)
	end
	return total
end

export type LevelInfo = { level: number, into: number, needed: number, maxed: boolean }

-- Nível a partir do XP total, com o quanto já andou dentro do nível (barra do menu).
function Progression.levelInfo(xp: number): LevelInfo
	local p = prog()
	local level = 1
	local remaining = math.max(math.floor(xp), 0)
	while level < p.maxLevel do
		local need = Progression.xpToNext(level)
		if remaining < need then
			return { level = level, into = remaining, needed = need, maxed = false }
		end
		remaining -= need
		level += 1
	end
	return { level = p.maxLevel, into = 0, needed = 0, maxed = true }
end

function Progression.levelOf(xp: number): number
	return Progression.levelInfo(xp).level
end

-- XP de uma partida, igual para cada participante da largada. Treino e abandono não pagam.
function Progression.matchXp(
	mode: Types.MatchMode,
	outcome: string,
	wavesCompleted: number,
	difficulty: string,
	partySize: number
): number
	if mode == "training" or (outcome ~= "won" and outcome ~= "lost") then
		return 0
	end
	local p = prog()
	local diff = p.xpDifficulty[difficulty] or 1
	local group = 1 + math.min(p.xpPerExtraPlayer * math.max(partySize - 1, 0), p.xpGroupCap)
	local base = p.xpPerWave * math.max(wavesCompleted, 0) * diff * group
	local bonus = if outcome == "won" then p.xpWinBonus else 0
	return math.floor(base + bonus + 0.5)
end

-- Torres que o nível libera de graça (as iniciais contam como nível 1).
function Progression.towersForLevel(level: number): { string }
	local list: { string } = {}
	for _, tower in ipairs(Balance.towers) do
		if tower.unlockLevel <= level then
			table.insert(list, tower.id)
		end
	end
	return list
end

-- Recompensa de chegar a `level` (sem as torres, que vêm de towersForLevel).
function Progression.levelReward(level: number): Types.RewardBundle
	local p = prog()
	local bundle: Types.RewardBundle = { buttons = p.levelButtons }
	if p.levelRetryEvery > 0 and level % p.levelRetryEvery == 0 then
		bundle.retry = 1
	end
	return bundle
end

-- ---------------------------------------------------------------------------
-- Pacotes de recompensa
-- ---------------------------------------------------------------------------

-- Soma um pacote no perfil. Devolve os botões somados (para as estatísticas).
function Progression.grant(profile: Types.Profile, bundle: Types.RewardBundle): number
	local buttons = math.max(math.floor(bundle.buttons or 0), 0)
	profile.buttons += buttons
	profile.lifetimeStats.buttonsEarned += buttons
	profile.inventory.retry += math.max(math.floor(bundle.retry or 0), 0)
	profile.inventory.support += math.max(math.floor(bundle.support or 0), 0)
	return buttons
end

function Progression.mergeBundles(a: Types.RewardBundle, b: Types.RewardBundle): Types.RewardBundle
	return {
		buttons = (a.buttons or 0) + (b.buttons or 0),
		retry = (a.retry or 0) + (b.retry or 0),
		support = (a.support or 0) + (b.support or 0),
	}
end

export type XpOutcome = {
	xpGained: number,
	levelBefore: number,
	levelAfter: number,
	rewards: Types.RewardBundle, -- soma do que os níveis novos entregaram
	towersUnlocked: { string },
}

-- Soma XP, entrega a recompensa de cada nível novo uma única vez (rewardedLevel) e libera as
-- torres do nível. Idempotência por partida é do ledger de resultados, não daqui.
function Progression.addXp(profile: Types.Profile, amount: number): XpOutcome
	local before = Progression.levelOf(profile.xp)
	profile.xp += math.max(math.floor(amount), 0)
	local after = Progression.levelOf(profile.xp)
	local rewards: Types.RewardBundle = {}
	for level = math.max(profile.rewardedLevel, 1) + 1, after do
		local bundle = Progression.levelReward(level)
		Progression.grant(profile, bundle)
		rewards = Progression.mergeBundles(rewards, bundle)
	end
	if after > profile.rewardedLevel then
		profile.rewardedLevel = after
	end
	local unlocked: { string } = {}
	for _, towerId in ipairs(Progression.towersForLevel(after)) do
		if table.find(profile.ownedTowerIds, towerId) == nil then
			table.insert(profile.ownedTowerIds, towerId)
			table.insert(unlocked, towerId)
			if #profile.loadout < Balance.loadoutSlots then
				table.insert(profile.loadout, towerId)
			end
		end
	end
	return {
		xpGained = math.max(math.floor(amount), 0),
		levelBefore = before,
		levelAfter = after,
		rewards = rewards,
		towersUnlocked = unlocked,
	}
end

-- ---------------------------------------------------------------------------
-- Recompensa diária
-- ---------------------------------------------------------------------------

function Progression.dayOf(unixTime: number): number
	return math.floor(unixTime / Progression.DAY_SECONDS)
end

export type DailyStatus = { available: boolean, dayIndex: number, streak: number }

-- Qual dia da sequência de 7 está disponível hoje. Pular um dia volta a sequência para o 1.
function Progression.dailyStatus(profile: Types.Profile, now: number): DailyStatus
	local today = Progression.dayOf(now)
	local last = profile.daily.lastDay
	local streak = profile.daily.streak
	if last == today then
		return { available = false, dayIndex = ((streak - 1) % 7) + 1, streak = streak }
	end
	local nextStreak = if last == today - 1 then streak + 1 else 1
	return { available = true, dayIndex = ((nextStreak - 1) % 7) + 1, streak = nextStreak }
end

function Progression.claimDaily(profile: Types.Profile, now: number): (boolean, Types.RewardBundle?, number?)
	local status = Progression.dailyStatus(profile, now)
	if not status.available then
		return false, nil, nil
	end
	local bundle = Balance.retention.dailyRewards[status.dayIndex]
	profile.daily = { lastDay = Progression.dayOf(now), streak = status.streak }
	Progression.grant(profile, bundle)
	return true, bundle, status.dayIndex
end

-- ---------------------------------------------------------------------------
-- Presentes de sessão
-- ---------------------------------------------------------------------------

-- Lista de presentes resgatados hoje (vira vazia na virada do dia UTC).
function Progression.giftsClaimedToday(profile: Types.Profile, now: number): { number }
	if profile.sessionGifts.day ~= Progression.dayOf(now) then
		return {}
	end
	return profile.sessionGifts.claimed
end

-- Pode resgatar o presente `index` com `sessionSeconds` de sessão? Devolve o motivo quando não.
function Progression.canClaimGift(
	profile: Types.Profile,
	index: number,
	sessionSeconds: number,
	now: number
): (boolean, string?)
	local gift = Balance.retention.sessionGifts[index]
	if not gift then
		return false, "unknown"
	end
	if table.find(Progression.giftsClaimedToday(profile, now), index) then
		return false, "claimed"
	end
	if sessionSeconds < gift.minutes * 60 then
		return false, "early"
	end
	return true, nil
end

function Progression.claimGift(
	profile: Types.Profile,
	index: number,
	sessionSeconds: number,
	now: number
): (boolean, Types.RewardBundle?)
	local ok = Progression.canClaimGift(profile, index, sessionSeconds, now)
	if not ok then
		return false, nil
	end
	local gift = Balance.retention.sessionGifts[index]
	local today = Progression.dayOf(now)
	if profile.sessionGifts.day ~= today then
		profile.sessionGifts = { day = today, claimed = {} }
	end
	table.insert(profile.sessionGifts.claimed, index)
	local bundle: Types.RewardBundle = { buttons = gift.buttons, retry = gift.retry, support = gift.support }
	Progression.grant(profile, bundle)
	return true, bundle
end

return Progression
