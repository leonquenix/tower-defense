--!strict
-- Estado compartilhado da interface: perfil, grupo, salas, convites, conexão e resultado pendente.
--
-- Os componentes leem daqui e emitem intenções; nada aqui simula economia ou combate.
-- Uma resposta atrasada atualiza o store mesmo que a tela de origem já tenha fechado.
local Store = {}

export type Invite = {
	inviteId: string,
	partyId: string,
	fromUserId: number,
	fromName: string,
	mapId: string?,
	difficulty: string?,
	-- Convites expiram em 30 s de relógio real (decisão de UI documentada no guia).
	expiresAt: number,
	state: "pending" | "accepted" | "declined" | "expired" | "full",
}

export type Connection = "ok" | "unstable" | "reconciling" | "lost"

export type State = {
	lobby: { [string]: any }?,
	profile: { [string]: any }?,
	profileStatus: string,
	invites: { Invite },
	-- Convites enviados: cooldown de 5 s por destinatário, sem repetição automática.
	sentInvites: { [number]: { at: number, state: string } },
	connection: Connection,
	lastFrameAt: number,
	pendingResult: { matchId: string, status: string, buttons: number? }?,
}

local state: State = {
	lobby = nil,
	profile = nil,
	profileStatus = "loading",
	invites = {},
	sentInvites = {},
	connection = "ok",
	lastFrameAt = os.clock(),
	pendingResult = nil,
}

local listeners: { (State) -> () } = {}
local notifyScheduled = false

local function notify()
	if notifyScheduled then
		return
	end
	notifyScheduled = true
	task.defer(function()
		notifyScheduled = false
		for _, fn in ipairs(listeners) do
			task.spawn(fn, state)
		end
	end)
end

function Store.get(): State
	return state
end

function Store.subscribe(fn: (State) -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		local index = table.find(listeners, fn)
		if index then
			table.remove(listeners, index)
		end
	end
end

function Store.setLobby(lobby: { [string]: any })
	state.lobby = lobby
	local profile = lobby.profile
	state.profileStatus = if profile then tostring(profile.status) else "loading"
	if profile and (profile.status == "ready" or profile.status == "volatile") then
		state.profile = profile
	elseif not profile then
		state.profile = nil
	end
	notify()
end

function Store.setProfile(profile: { [string]: any }?)
	if profile then
		state.profile = profile
		state.profileStatus = tostring(profile.status or "ready")
		if state.lobby then
			(state.lobby :: any).profile = profile
		end
	end
	notify()
end

function Store.profile(): { [string]: any }?
	return state.profile
end

function Store.party(): { [string]: any }?
	return if state.lobby then (state.lobby :: any).party else nil
end

function Store.rooms(): { any }
	return if state.lobby then ((state.lobby :: any).rooms or {}) else {}
end

function Store.players(): { any }
	return if state.lobby then ((state.lobby :: any).players or {}) else {}
end

function Store.buttons(): number
	local profile = state.profile
	return if profile then (profile.buttons or 0) else 0
end

function Store.isPersistent(): boolean
	local profile = state.profile
	return profile ~= nil and profile.persistent == true
end

-- ---------------------------------------------------------------------------
-- Convites
-- ---------------------------------------------------------------------------

function Store.addInvite(invite: Invite)
	for _, existing in ipairs(state.invites) do
		if existing.inviteId == invite.inviteId then
			return
		end
	end
	table.insert(state.invites, invite)
	notify()
end

function Store.setInviteState(inviteId: string, newState: string)
	for _, invite in ipairs(state.invites) do
		if invite.inviteId == inviteId then
			invite.state = newState :: any
			notify()
			return
		end
	end
end

function Store.removeInvite(inviteId: string)
	for index = #state.invites, 1, -1 do
		if state.invites[index].inviteId == inviteId then
			table.remove(state.invites, index)
		end
	end
	notify()
end

-- Remove convites expirados pelo relógio real. Um convite vencido nunca é aceito só porque
-- o botão continuava na tela.
function Store.expireInvites(now: number): boolean
	local changed = false
	for index = #state.invites, 1, -1 do
		local invite = state.invites[index]
		if now >= invite.expiresAt then
			if invite.state == "pending" then
				invite.state = "expired"
				changed = true
			elseif now >= invite.expiresAt + 3 then
				table.remove(state.invites, index)
				changed = true
			end
		end
	end
	if changed then
		notify()
	end
	return changed
end

function Store.markInviteSent(userId: number, inviteState: string)
	state.sentInvites[userId] = { at = os.clock(), state = inviteState }
	notify()
end

-- Cooldown de 5 s por destinatário (guia, prancha 33).
function Store.inviteCooldownLeft(userId: number): number
	local sent = state.sentInvites[userId]
	if not sent then
		return 0
	end
	return math.max(0, 5 - (os.clock() - sent.at))
end

-- ---------------------------------------------------------------------------
-- Conexão
-- ---------------------------------------------------------------------------

function Store.noteFrame()
	state.lastFrameAt = os.clock()
	if state.connection ~= "ok" then
		state.connection = "ok"
		notify()
	end
end

-- 2 s sem atualização mostra "Sinal instável"; 5 s bloqueia novas mutações e reconcilia.
-- O tabuleiro nunca é apagado no primeiro atraso.
function Store.updateConnection(now: number): Connection
	local silence = now - state.lastFrameAt
	local next_: Connection = if silence >= 5 then "reconciling" elseif silence >= 2 then "unstable" else "ok"
	if next_ ~= state.connection then
		state.connection = next_
		notify()
	end
	return state.connection
end

function Store.setConnection(value: Connection)
	if state.connection ~= value then
		state.connection = value
		notify()
	end
end

function Store.canMutate(): boolean
	return state.connection == "ok" or state.connection == "unstable"
end

-- ---------------------------------------------------------------------------
-- Resultado pendente
-- ---------------------------------------------------------------------------

function Store.setPendingResult(result: { matchId: string, status: string, buttons: number? }?)
	state.pendingResult = result
	notify()
end

function Store.clear()
	state.lobby = nil
	state.profile = nil
	state.profileStatus = "loading"
	table.clear(state.invites)
	table.clear(state.sentInvites)
	state.pendingResult = nil
	notify()
end

return Store
