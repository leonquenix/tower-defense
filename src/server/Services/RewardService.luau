--!strict
-- Registro durável de resultados (ledger por matchId) e aplicação idempotente aos perfis.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local ProfileSchema = require(Shared.Profile.ProfileSchema)
local ProfileService = require(script.Parent.ProfileService)
local TelemetryService = require(script.Parent.TelemetryService)

local RewardService = {}

local LEDGER_NAME = if RunService:IsStudio() then "QuintalMatchResults_v1_studio" else "QuintalMatchResults_v1"
local ledger: DataStore? = nil

export type UserOutcome = {
	status: "saved" | "pending" | "duplicate" | "unsaved" | "unavailable" | "ineligible" | "none",
	buttons: number,
	mastery: { [string]: number },
	milestones: { [string]: { number } },
	unlocked: { string },
}

local function getLedger(): DataStore?
	if ledger then
		return ledger
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(LEDGER_NAME)
	end)
	if ok then
		ledger = result
	end
	return ledger
end

local function writeRecord(record: Types.MatchResultRecord): boolean
	local ds = getLedger()
	if not ds then
		return false
	end
	local ok, err = pcall(function()
		ds:UpdateAsync(record.matchId, function(old: any)
			if old ~= nil then
				return nil -- já existe: idempotente
			end
			return record
		end)
	end)
	if not ok then
		TelemetryService.log("ledger_write_failed", { matchId = record.matchId, error = tostring(err) })
	end
	return ok
end

local function markApplied(matchId: string, userId: number)
	local ds = getLedger()
	if not ds then
		return
	end
	task.spawn(function()
		pcall(function()
			ds:UpdateAsync(matchId, function(old: any)
				if typeof(old) ~= "table" then
					return nil
				end
				old.appliedUserIds = old.appliedUserIds or {}
				if table.find(old.appliedUserIds, userId) == nil then
					table.insert(old.appliedUserIds, userId)
				end
				return old
			end)
		end)
	end)
end

local function applyToPlayer(
	player: Player,
	record: Types.MatchResultRecord,
	stats: Types.PlayerMatchStats?
): UserOutcome
	local outcome: UserOutcome = { status = "none", buttons = 0, mastery = {}, milestones = {}, unlocked = {} }
	local profile = ProfileService.get(player)
	local session = ProfileService.getSession(player)
	if not profile or not session then
		outcome.status = "unavailable"
		return outcome
	end
	local masteryForUser = record.masteryByUser[tostring(player.UserId)] or {}
	local now = os.time()
	local applyResult: ProfileSchema.ApplyResultOutcome? = nil
	local mutated = ProfileService.mutate(player, function(p: Types.Profile)
		applyResult = ProfileSchema.applyMatchResult(p, {
			matchId = record.matchId,
			buttons = record.buttonsPerPlayer,
			masteryByTower = masteryForUser,
			outcome = record.outcome,
			mode = record.mode,
			mapId = record.mapId,
			difficulty = record.difficulty,
			wavesCompleted = record.wavesCompleted,
			enemiesDefeated = nil,
			towersPlaced = if stats then stats.towersPlaced else nil,
			createdAt = record.createdAt,
			now = now,
		})
	end)
	if not mutated or not applyResult then
		outcome.status = "unavailable"
		return outcome
	end
	local result = applyResult :: ProfileSchema.ApplyResultOutcome
	outcome.buttons = record.buttonsPerPlayer
	outcome.mastery = masteryForUser
	outcome.milestones = result.newMilestones
	outcome.unlocked = result.unlocked
	if not result.applied then
		outcome.status = if result.reason == "duplicate" then "duplicate" else "pending"
		return outcome
	end
	if session.status == "volatile" then
		outcome.status = "unsaved"
		return outcome
	end
	local saved = ProfileService.save(player, false)
	if saved then
		outcome.status = "saved"
		markApplied(record.matchId, player.UserId)
	else
		outcome.status = "pending"
	end
	return outcome
end

-- Antes da largada: registra referência pendente nos perfis (consulta na próxima sessão)
function RewardService.registerPending(players: { Player }, matchId: string)
	local now = os.time()
	for _, player in ipairs(players) do
		ProfileService.mutate(player, function(p: Types.Profile)
			table.insert(p.pendingResults, { matchId = matchId, createdAt = now })
			while #p.pendingResults > 16 do
				table.remove(p.pendingResults, 1)
			end
		end)
		task.spawn(function()
			ProfileService.save(player, false)
		end)
	end
end

-- Liquida um resultado: grava o registro durável e aplica aos participantes conectados e elegíveis.
function RewardService.settle(
	state: Types.MatchState,
	connectedPlayers: { [number]: Player },
	tutorialClaim: boolean
): { [number]: UserOutcome }
	local result = state.result
	local outcomes: { [number]: UserOutcome } = {}
	if not result then
		return outcomes
	end
	local masteryByUser: { [string]: { [string]: number } } = {}
	for userId, per in pairs(result.masteryByUser) do
		masteryByUser[tostring(userId)] = per
	end
	local eligible: { number } = {}
	for _, userId in ipairs(result.eligibleUserIds) do
		if connectedPlayers[userId] then
			table.insert(eligible, userId)
		end
	end
	local record: Types.MatchResultRecord = {
		matchId = if state.mode == "tutorial" then ProfileSchema.TUTORIAL_KEY else state.matchId,
		configVersion = state.configVersion,
		outcome = result.outcome,
		mode = state.mode,
		mapId = state.mapId,
		difficulty = state.difficulty,
		wavesCompleted = result.wavesCompleted,
		buttonsPerPlayer = result.buttonsPerPlayer,
		eligibleUserIds = eligible,
		masteryByUser = masteryByUser,
		appliedUserIds = {},
		createdAt = os.time(),
		partySize = #state.participants,
	}
	local rewardable = state.mode ~= "training" and result.outcome ~= "abandoned"
	if state.mode == "tutorial" and not tutorialClaim then
		rewardable = false
	end
	local ledgerOk = false
	if rewardable and #eligible > 0 and state.mode ~= "tutorial" then
		ledgerOk = writeRecord(record)
	end
	for _, participant in ipairs(state.participants) do
		local player = connectedPlayers[participant.userId]
		if not player then
			outcomes[participant.userId] =
				{ status = "ineligible", buttons = 0, mastery = {}, milestones = {}, unlocked = {} }
		elseif not rewardable then
			outcomes[participant.userId] =
				{ status = "none", buttons = 0, mastery = {}, milestones = {}, unlocked = {} }
			-- remove referência pendente mesmo sem recompensa
			ProfileService.mutate(player, function(p: Types.Profile)
				for i = #p.pendingResults, 1, -1 do
					if p.pendingResults[i].matchId == state.matchId then
						table.remove(p.pendingResults, i)
					end
				end
				if state.mode == "tutorial" then
					p.tutorialCompleted = true
				end
			end)
		else
			outcomes[participant.userId] = applyToPlayer(player, record, result.statsByUser[participant.userId])
		end
	end
	TelemetryService.log("match_settled", {
		matchId = state.matchId,
		outcome = result.outcome,
		mode = state.mode,
		mapId = state.mapId,
		difficulty = state.difficulty,
		waves = result.wavesCompleted,
		partySize = #state.participants,
		ledger = ledgerOk,
		durationSim = result.durationSim,
	})
	return outcomes
end

-- Ao carregar o perfil: reconcilia resultados pendentes com o ledger.
function RewardService.reconcilePending(player: Player)
	local profile = ProfileService.get(player)
	if not profile or #profile.pendingResults == 0 then
		return
	end
	local ds = getLedger()
	if not ds then
		return
	end
	local refs = table.clone(profile.pendingResults)
	local now = os.time()
	for _, ref in ipairs(refs) do
		if now - ref.createdAt > ProfileSchema.REWARD_RETENTION_SECONDS then
			ProfileService.mutate(player, function(p: Types.Profile)
				for i = #p.pendingResults, 1, -1 do
					if p.pendingResults[i].matchId == ref.matchId then
						table.remove(p.pendingResults, i)
					end
				end
			end)
		else
			local ok, record = pcall(function()
				return ds:GetAsync(ref.matchId)
			end)
			if ok and typeof(record) == "table" then
				local rec = record :: Types.MatchResultRecord
				if table.find(rec.eligibleUserIds, player.UserId) then
					local outcome = applyToPlayer(player, rec, nil)
					TelemetryService.log(
						"pending_reconciled",
						{ userId = player.UserId, matchId = ref.matchId, status = outcome.status }
					)
				else
					ProfileService.mutate(player, function(p: Types.Profile)
						for i = #p.pendingResults, 1, -1 do
							if p.pendingResults[i].matchId == ref.matchId then
								table.remove(p.pendingResults, i)
							end
						end
					end)
				end
			elseif ok and record == nil and now - ref.createdAt > 3600 then
				-- partida sem resultado durável há mais de 1 h: registra abandono e remove
				TelemetryService.log("pending_abandoned", { userId = player.UserId, matchId = ref.matchId })
				ProfileService.mutate(player, function(p: Types.Profile)
					for i = #p.pendingResults, 1, -1 do
						if p.pendingResults[i].matchId == ref.matchId then
							table.remove(p.pendingResults, i)
						end
					end
				end)
			end
		end
	end
end

function RewardService.init()
	ProfileService.onSessionChanged(function(player: Player, session: ProfileService.Session)
		if session.status == "ready" then
			task.spawn(RewardService.reconcilePending, player)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if ProfileService.getStatus(player) == "ready" then
			task.spawn(RewardService.reconcilePending, player)
		end
	end
end

return RewardService
