--!strict
-- Perfis persistentes sobre ProfileStore (loleris): trava de sessão, autosave periódico,
-- reconciliação com o modelo e fechamento no BindToClose vêm do pacote.
--
-- O que continua sendo nosso: migração de esquema e validação (Shared/Profile/ProfileSchema),
-- a visão enviada ao cliente e a política de "nunca sobrescrever um perfil que não carregou".
--
-- Antes do revamp isto era ~250 linhas de UpdateAsync, token de lock, renovação a cada 30 s e
-- fila de gravação escritas à mão. Tudo isso agora é responsabilidade do ProfileStore.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local ProfileSchema = require(Shared.Profile.ProfileSchema)
local TableUtil = require(Shared.Util.TableUtil)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local TelemetryService = require(script.Parent.TelemetryService)

local PlayerDataService = {}

export type Status = "loading" | "ready" | "unavailable" | "locked" | "volatile"

export type Session = {
	userId: number,
	player: Player?,
	profile: Types.Profile?,
	status: Status,
	lastError: string?,
	handle: any?, -- Profile do ProfileStore (nil quando volátil/indisponível)
}

local STORE_NAME = "QuintalProfiles_v1"

local template = ProfileSchema.default(os.time())
local store = ProfileStore.New(STORE_NAME, template)
-- DataStoreState é membro do módulo, mas não aparece no tipo exportado do pacote.
local storeState = ProfileStore :: any

local sessions: { [number]: Session } = {}
local listeners: { (Player, Session) -> () } = {}
local dataStoreBroken = false

local function notify(session: Session)
	if session.player then
		for _, fn in ipairs(listeners) do
			task.spawn(fn, session.player :: Player, session)
		end
	end
end

function PlayerDataService.onSessionChanged(fn: (Player, Session) -> ())
	table.insert(listeners, fn)
end

-- No Studio sem acesso a DataStore o jogo continua jogável com a loja fictícia do ProfileStore:
-- o perfil existe em memória, some ao sair e nunca é confundido com progresso real.
local function activeStore(): (any, boolean)
	local state = storeState.DataStoreState
	if state == "NoAccess" or state == "NoInternet" then
		dataStoreBroken = true
		return store.Mock, true
	end
	if RunService:IsStudio() and state == "NotReady" then
		-- ainda indefinido: o Studio costuma responder "NoAccess" logo depois
		return store, false
	end
	return store, false
end

local function startSession(session: Session)
	session.status = "loading"
	notify(session)
	local target, isMock = activeStore()
	local handle = target:StartSessionAsync(`u_{session.userId}`, {
		Cancel = function()
			return session.player == nil or (session.player :: Player).Parent ~= Players
		end,
	})
	if handle == nil then
		-- o jogador saiu durante a espera, ou o ProfileStore desistiu do acesso
		local mockStore, mockActive = activeStore()
		if not mockActive and RunService:IsStudio() then
			handle = (mockStore.Mock :: any):StartSessionAsync(`u_{session.userId}`, {})
			isMock = true
		end
	end
	if handle == nil then
		session.status = "unavailable"
		session.lastError = "sessão de perfil não iniciada"
		TelemetryService.log("profile_unavailable", { userId = session.userId, state = storeState.DataStoreState })
		notify(session)
		return
	end
	local player = session.player
	if player then
		handle:AddUserId(session.userId)
	end
	handle:Reconcile()
	local now = os.time()
	local migrated = ProfileSchema.migrate(handle.Data, now)
	if not migrated then
		-- dado irreconhecível: encerra sem tocar no conteúdo e avisa o jogador
		handle:EndSession()
		session.status = "unavailable"
		session.lastError = "perfil corrompido"
		TelemetryService.log("profile_corrupt", { userId = session.userId })
		notify(session)
		return
	end
	local valid, why = ProfileSchema.validate(migrated)
	if not valid then
		handle:EndSession()
		session.status = "unavailable"
		session.lastError = "perfil inválido: " .. tostring(why)
		TelemetryService.log("profile_invalid", { userId = session.userId, reason = why })
		notify(session)
		return
	end
	handle.Data = migrated
	handle.OnSessionEnd:Connect(function()
		-- outro servidor assumiu o perfil (ou o jogo fechou): nada mais é gravado daqui
		if sessions[session.userId] == session then
			session.status = if isMock then "volatile" else "locked"
			session.handle = nil
			notify(session)
		end
	end)
	session.handle = handle
	session.profile = handle.Data
	session.status = if isMock then "volatile" else "ready"
	session.lastError = nil
	TelemetryService.log("profile_loaded", { userId = session.userId, mock = isMock })
	notify(session)
end

-- Garante que existe uma sessão para quem está no servidor. Sem isto, um jogador cuja sessão
-- foi encerrada (troca de servidor, queda do DataStore, saída e volta rápida) ficaria preso em
-- "carregando" para sempre — foi exatamente o que apareceu no primeiro teste no Studio.
local function ensureSession(player: Player): Session
	local existing = sessions[player.UserId]
	if existing then
		existing.player = player
		return existing
	end
	local session: Session = {
		userId = player.UserId,
		player = player,
		profile = nil,
		status = "loading",
		lastError = nil,
		handle = nil,
	}
	sessions[player.UserId] = session
	task.spawn(startSession, session)
	return session
end

function PlayerDataService.onPlayerAdded(player: Player)
	local existing = sessions[player.UserId]
	if existing and (existing.status == "ready" or existing.status == "volatile") then
		existing.player = player
		notify(existing)
		return
	end
	ensureSession(player)
end

function PlayerDataService.retryLoad(player: Player)
	local session = sessions[player.UserId]
	if session and (session.status == "unavailable" or session.status == "locked") then
		task.spawn(startSession, session)
	end
end

function PlayerDataService.getSession(player: Player): Session?
	return sessions[player.UserId]
end

function PlayerDataService.getStatus(player: Player): Status
	local session = sessions[player.UserId]
	if not session and player.Parent == Players then
		-- jogador presente sem sessão: recomeça o carregamento em vez de travar em "carregando"
		session = ensureSession(player)
	end
	return if session then session.status else "loading"
end

function PlayerDataService.get(player: Player): Types.Profile?
	local profile = PlayerDataService.getByUserId(player.UserId)
	if profile == nil and sessions[player.UserId] == nil and player.Parent == Players then
		ensureSession(player)
	end
	return profile
end

function PlayerDataService.getByUserId(userId: number): Types.Profile?
	local session = sessions[userId]
	if session and (session.status == "ready" or session.status == "volatile") then
		return session.profile
	end
	return nil
end

-- Perfil pronto e ainda com a sessão travada neste servidor.
function PlayerDataService.isWritable(player: Player): boolean
	local session = sessions[player.UserId]
	return session ~= nil and session.status == "ready" and session.handle ~= nil
end

function PlayerDataService.isPersistent(player: Player): boolean
	return PlayerDataService.isWritable(player)
end

-- Aplica uma mutação ao perfil. O ProfileStore grava sozinho; não existe "dirty" para acompanhar.
function PlayerDataService.mutate(player: Player, fn: (Types.Profile) -> ()): boolean
	local session = sessions[player.UserId]
	if not session or not session.profile then
		return false
	end
	if session.status ~= "ready" and session.status ~= "volatile" then
		return false
	end
	fn(session.profile :: Types.Profile);
	(session.profile :: Types.Profile).updatedAt = os.time()
	notify(session)
	return true
end

-- Gravação imediata (a periódica é do pacote). `release` encerra a sessão.
function PlayerDataService.save(player: Player, release: boolean?): (boolean, string?)
	local session = sessions[player.UserId]
	if not session then
		return false, "sem sessão"
	end
	return PlayerDataService.saveSession(session, release == true)
end

function PlayerDataService.saveSession(session: Session, release: boolean): (boolean, string?)
	local handle = session.handle
	if not handle then
		return false, "perfil não persistente"
	end
	if release then
		handle:EndSession()
		session.handle = nil
		session.status = "unavailable"
		session.profile = nil
		return true, nil
	end
	local ok, err = pcall(function()
		handle:Save()
	end)
	if not ok then
		session.lastError = tostring(err)
		TelemetryService.log("profile_save_failed", { userId = session.userId, error = session.lastError })
	end
	return ok, session.lastError
end

function PlayerDataService.onPlayerRemoving(player: Player)
	local session = sessions[player.UserId]
	if not session then
		return
	end
	session.player = nil
	local handle = session.handle
	if handle then
		handle:EndSession() -- grava e libera a trava para o próximo servidor
	end
	session.handle = nil
	session.profile = nil
	session.status = "unavailable"
	-- A entrada some depois de um minuto: quem cai e volta no mesmo servidor recomeça limpo,
	-- e nada fica preso se a saída acontecer no meio de uma gravação.
	task.delay(60, function()
		if sessions[player.UserId] == session and session.player == nil then
			sessions[player.UserId] = nil
		end
	end)
end

-- Subconjunto seguro para o cliente (nunca inclui o perfil de outro jogador)
function PlayerDataService.clientView(player: Player): { [string]: any }
	local session = sessions[player.UserId]
	if not session then
		return { status = "loading" }
	end
	local profile = session.profile
	local status: string = session.status
	if not profile or (status ~= "ready" and status ~= "volatile") then
		return { status = status, error = session.lastError }
	end
	return {
		status = status,
		persistent = status == "ready",
		lockLost = false, -- perfil carregado: a trava é deste servidor até OnSessionEnd
		buttons = profile.buttons,
		ownedTowerIds = table.clone(profile.ownedTowerIds),
		loadout = table.clone(profile.loadout),
		cosmeticsOwned = table.clone(profile.cosmeticsOwned),
		cosmeticLoadout = table.clone(profile.cosmeticLoadout),
		masteryByTower = TableUtil.deepClone(profile.masteryByTower),
		mapUnlocks = table.clone(profile.mapUnlocks),
		-- campanha: estrelas por fase e se o guia da primeira fase já foi visto
		campaign = table.clone(profile.campaign),
		campaignIntroSeen = profile.campaignIntroSeen,
		settings = table.clone(profile.settings),
		lifetimeStats = table.clone(profile.lifetimeStats),
		pendingResults = #profile.pendingResults,
	}
end

function PlayerDataService.flushAll(): { [number]: boolean }
	local results: { [number]: boolean } = {}
	for userId, session in pairs(sessions) do
		if session.handle then
			results[userId] = PlayerDataService.saveSession(session, true)
		end
	end
	TelemetryService.log("profiles_flushed", { count = TableUtil.count(results) })
	return results
end

function PlayerDataService.init()
	ProfileStore.OnError:Connect(function(message: string, storeName: string, profileKey: string)
		dataStoreBroken = true
		TelemetryService.log("profile_store_error", { message = message, store = storeName, key = profileKey })
	end)
	ProfileStore.OnOverwrite:Connect(function(storeName: string, profileKey: string)
		TelemetryService.log("profile_overwrite", { store = storeName, key = profileKey })
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataService.onPlayerAdded(player)
	end
end

function PlayerDataService.isDataStoreBroken(): boolean
	return dataStoreBroken
end

return PlayerDataService
