--!strict
-- Perfis persistentes com DataStore: lock de sessão, UpdateAsync, migrações puras, gravação serializada.
-- Falha de carregamento nunca grava defaults sobre um perfil existente.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local ProfileSchema = require(Shared.Profile.ProfileSchema)
local TableUtil = require(Shared.Util.TableUtil)
local TelemetryService = require(script.Parent.TelemetryService)

local ProfileService = {}

export type Status = "loading" | "ready" | "unavailable" | "locked" | "volatile"

export type Session = {
	userId: number,
	player: Player?,
	profile: Types.Profile?,
	status: Status,
	token: string,
	dirty: boolean,
	saving: boolean,
	pendingSave: boolean,
	lockLost: boolean,
	lastSaveAt: number,
	lastError: string?,
	loadAttempts: number,
}

local STORE_NAME = if RunService:IsStudio() then "QuintalProfiles_v1_studio" else "QuintalProfiles_v1"
local LOCK_TTL = 120
local LOCK_RENEW = 30
local MAX_LOAD_ATTEMPTS = 3
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local store: DataStore? = nil
local sessions: { [number]: Session } = {}
local listeners: { (Player, Session) -> () } = {}
local dataStoreBroken = false

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	dataStoreBroken = true
	return nil
end

local function key(userId: number): string
	return "u_" .. tostring(userId)
end

local function isAccessError(err: string): boolean
	local lower = err:lower()
	return lower:find("not allowed") ~= nil or lower:find("api access") ~= nil or lower:find("http 403") ~= nil
end

local function notify(session: Session)
	if session.player then
		for _, fn in ipairs(listeners) do
			task.spawn(fn, session.player :: Player, session)
		end
	end
end

function ProfileService.onSessionChanged(fn: (Player, Session) -> ())
	table.insert(listeners, fn)
end

-- Tenta adquirir o lock e carregar o perfil. Retorna (status, perfil?).
local function tryLoad(session: Session): (Status, Types.Profile?, string?)
	local ds = getStore()
	if not ds then
		return "unavailable", nil, "DataStore indisponível"
	end
	local outcome: string? = nil
	local loaded: Types.Profile? = nil
	local ok, err = pcall(function()
		ds:UpdateAsync(key(session.userId), function(old: any)
			local now = os.time()
			if typeof(old) == "table" and typeof(old.sessionLock) == "table" then
				local lock = old.sessionLock
				if typeof(lock.expiresAt) == "number" and lock.expiresAt > now and lock.jobId ~= JOB_ID then
					outcome = "locked"
					return nil
				end
			end
			local data = old
			if data == nil then
				data = ProfileSchema.default(now)
			end
			if typeof(data) ~= "table" then
				outcome = "corrupt"
				return nil
			end
			local migrated = ProfileSchema.migrate(TableUtil.deepClone(data), now)
			if not migrated then
				outcome = "corrupt"
				return nil
			end
			local valid, why = ProfileSchema.validate(migrated)
			if not valid then
				outcome = "invalid:" .. tostring(why)
				return nil
			end
			migrated.sessionLock = { jobId = JOB_ID, token = session.token, expiresAt = now + LOCK_TTL }
			loaded = migrated
			outcome = "ok"
			return migrated
		end)
	end)
	if not ok then
		return "unavailable", nil, tostring(err)
	end
	if outcome == "locked" then
		return "locked", nil, "perfil em uso por outro servidor"
	end
	if outcome ~= "ok" or not loaded then
		return "unavailable", nil, outcome
	end
	return "ready", loaded, nil
end

local function loadAsync(session: Session)
	session.status = "loading"
	notify(session)
	local delay = 1
	for attempt = 1, MAX_LOAD_ATTEMPTS do
		session.loadAttempts = attempt
		local status, profile, err = tryLoad(session)
		if status == "ready" and profile then
			session.profile = profile
			session.status = "ready"
			session.lastError = nil
			session.lockLost = false
			TelemetryService.log("profile_loaded", { userId = session.userId, attempt = attempt })
			notify(session)
			return
		end
		if status == "locked" then
			session.status = "locked"
			session.lastError = err
			TelemetryService.log("profile_locked", { userId = session.userId })
			notify(session)
			return
		end
		session.lastError = err
		if err and isAccessError(err) then
			break
		end
		if attempt < MAX_LOAD_ATTEMPTS then
			task.wait(delay)
			delay *= 2
		end
	end
	TelemetryService.log("profile_unavailable", { userId = session.userId, error = session.lastError })
	if RunService:IsStudio() then
		-- Somente no Studio: perfil volátil para permitir testes sem API. Nunca é gravado.
		session.profile = ProfileSchema.default(os.time())
		session.status = "volatile"
	else
		session.status = "unavailable"
	end
	notify(session)
end

function ProfileService.onPlayerAdded(player: Player)
	local existing = sessions[player.UserId]
	if existing and existing.status ~= "unavailable" and existing.status ~= "locked" then
		existing.player = player
		notify(existing)
		return
	end
	local session: Session = {
		userId = player.UserId,
		player = player,
		profile = nil,
		status = "loading",
		token = HttpService:GenerateGUID(false),
		dirty = false,
		saving = false,
		pendingSave = false,
		lockLost = false,
		lastSaveAt = os.clock(),
		lastError = nil,
		loadAttempts = 0,
	}
	sessions[player.UserId] = session
	task.spawn(loadAsync, session)
end

function ProfileService.retryLoad(player: Player)
	local session = sessions[player.UserId]
	if session and (session.status == "unavailable" or session.status == "locked") then
		task.spawn(loadAsync, session)
	end
end

function ProfileService.getSession(player: Player): Session?
	return sessions[player.UserId]
end

function ProfileService.getStatus(player: Player): Status
	local s = sessions[player.UserId]
	return if s then s.status else "loading"
end

function ProfileService.get(player: Player): Types.Profile?
	local s = sessions[player.UserId]
	if s and (s.status == "ready" or s.status == "volatile") then
		return s.profile
	end
	return nil
end

function ProfileService.getByUserId(userId: number): Types.Profile?
	local s = sessions[userId]
	if s and (s.status == "ready" or s.status == "volatile") then
		return s.profile
	end
	return nil
end

-- Perfil pronto e com lock válido (mutações persistentes permitidas)
function ProfileService.isWritable(player: Player): boolean
	local s = sessions[player.UserId]
	return s ~= nil and s.status == "ready" and not s.lockLost and s.profile ~= nil
end

function ProfileService.isPersistent(player: Player): boolean
	return ProfileService.isWritable(player)
end

-- Aplica uma mutação. Perfis voláteis (Studio sem DataStore) aceitam mutação em memória, sem persistir.
function ProfileService.mutate(player: Player, fn: (Types.Profile) -> ()): boolean
	local s = sessions[player.UserId]
	if not s or not s.profile then
		return false
	end
	if s.status == "volatile" then
		fn(s.profile)
		notify(s)
		return true
	end
	if s.status ~= "ready" or s.lockLost then
		return false
	end
	fn(s.profile)
	s.profile.updatedAt = os.time()
	s.dirty = true
	notify(s)
	return true
end

local function writeAsync(session: Session, release: boolean): (boolean, string?)
	local ds = getStore()
	local profile = session.profile
	if not ds or not profile then
		return false, "sem store ou perfil"
	end
	local outcome: string? = nil
	local ok, err = pcall(function()
		ds:UpdateAsync(key(session.userId), function(old: any)
			local now = os.time()
			if typeof(old) == "table" and typeof(old.sessionLock) == "table" then
				local lock = old.sessionLock
				if lock.token ~= session.token and typeof(lock.expiresAt) == "number" and lock.expiresAt > now then
					outcome = "lost_lock"
					return nil
				end
			end
			local data = TableUtil.deepClone(profile)
			data.sessionLock = if release
				then nil
				else { jobId = JOB_ID, token = session.token, expiresAt = now + LOCK_TTL }
			data.updatedAt = now
			outcome = "ok"
			return data
		end)
	end)
	if not ok then
		return false, tostring(err)
	end
	if outcome == "lost_lock" then
		session.lockLost = true
		TelemetryService.log("profile_lock_lost", { userId = session.userId })
		notify(session)
		return false, "lock perdido"
	end
	return true, nil
end

-- Gravação serializada por usuário. Retorna se persistiu.
function ProfileService.save(player: Player, release: boolean?): (boolean, string?)
	local session = sessions[player.UserId]
	if not session then
		return false, "sem sessão"
	end
	return ProfileService.saveSession(session, release == true)
end

function ProfileService.saveSession(session: Session, release: boolean): (boolean, string?)
	if session.status ~= "ready" or not session.profile then
		return false, "perfil não persistente"
	end
	if session.lockLost then
		return false, "lock perdido"
	end
	while session.saving do
		session.pendingSave = true
		task.wait(0.1)
	end
	session.saving = true
	session.pendingSave = false
	local ok, err = writeAsync(session, release)
	if ok then
		session.dirty = false
		session.lastSaveAt = os.clock()
	else
		session.lastError = err
		TelemetryService.log("profile_save_failed", { userId = session.userId, error = err })
	end
	session.saving = false
	return ok, err
end

function ProfileService.onPlayerRemoving(player: Player)
	local session = sessions[player.UserId]
	if not session then
		return
	end
	session.player = nil
	task.spawn(function()
		if session.status == "ready" then
			ProfileService.saveSession(session, true)
		end
		-- mantém a sessão por 5 min para retomada rápida no mesmo servidor (sem lock após release)
		task.delay(300, function()
			if sessions[player.UserId] == session and session.player == nil then
				sessions[player.UserId] = nil
			end
		end)
		if session.status == "ready" then
			-- após release, uma nova entrada precisa readquirir o lock
			session.status = "unavailable"
			session.profile = nil
		end
	end)
end

-- Subconjunto seguro para o cliente (nunca inclui o perfil de outro jogador)
function ProfileService.clientView(player: Player): { [string]: any }
	local session = sessions[player.UserId]
	if not session then
		return { status = "loading" }
	end
	local profile = session.profile
	if not profile or (session.status ~= "ready" and session.status ~= "volatile") then
		return { status = session.status, error = session.lastError }
	end
	return {
		status = session.status,
		persistent = session.status == "ready" and not session.lockLost,
		lockLost = session.lockLost,
		buttons = profile.buttons,
		ownedTowerIds = table.clone(profile.ownedTowerIds),
		loadout = table.clone(profile.loadout),
		cosmeticsOwned = table.clone(profile.cosmeticsOwned),
		cosmeticLoadout = table.clone(profile.cosmeticLoadout),
		masteryByTower = TableUtil.deepClone(profile.masteryByTower),
		mapUnlocks = table.clone(profile.mapUnlocks),
		tutorialCompleted = profile.tutorialCompleted,
		tutorialRewardClaimed = profile.tutorialRewardClaimed,
		settings = table.clone(profile.settings),
		lifetimeStats = table.clone(profile.lifetimeStats),
		pendingResults = #profile.pendingResults,
	}
end

function ProfileService.flushAll(): { [number]: boolean }
	local results: { [number]: boolean } = {}
	local threads = 0
	for userId, session in pairs(sessions) do
		if session.status == "ready" and session.profile then
			threads += 1
			task.spawn(function()
				local ok = ProfileService.saveSession(session, true)
				results[userId] = ok
				threads -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while threads > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	TelemetryService.log("profiles_flushed", { count = TableUtil.count(results) })
	return results
end

function ProfileService.init()
	-- renovação de lock e autosave
	task.spawn(function()
		while true do
			task.wait(LOCK_RENEW)
			for _, session in pairs(sessions) do
				if session.status == "ready" and session.player and session.profile then
					task.spawn(function()
						-- autosave de alterações sujas (60 s com jitter) e renovação do lock a cada 30 s:
						-- ambos passam pela mesma gravação serializada com comparação de token
						ProfileService.saveSession(session, false)
					end)
				end
			end
		end
	end)
	game:BindToClose(function()
		ProfileService.flushAll()
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		ProfileService.onPlayerAdded(player)
	end
end

function ProfileService.isDataStoreBroken(): boolean
	return dataStoreBroken
end

return ProfileService
