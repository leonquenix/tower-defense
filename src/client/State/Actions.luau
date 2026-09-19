--!strict
-- Mutações de estado do cliente. Só mexem em átomos: quem fala com o servidor é Net/Commands.
-- Manter as duas coisas separadas deixa esta camada testável fora do Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Atoms = require(script.Parent.Atoms)

local Actions = {}

local nextToastId = 0

-- ---------------------------------------------------------------------------
-- Lobby, perfil e convites
-- ---------------------------------------------------------------------------

function Actions.setLobby(lobby: { [string]: any })
	Atoms.lobby(lobby)
	local profile = lobby.profile
	Atoms.profileStatus(if profile then tostring(profile.status) else "loading")
	if profile and (profile.status == "ready" or profile.status == "volatile") then
		Atoms.profile(profile)
	elseif not profile then
		Atoms.profile(nil)
	end
end

function Actions.setProfile(profile: { [string]: any }?)
	if not profile then
		return
	end
	Atoms.profile(profile)
	Atoms.profileStatus(tostring(profile.status or "ready"))
	local lobby = Atoms.lobby()
	if lobby then
		local copy = table.clone(lobby)
		copy.profile = profile
		Atoms.lobby(copy)
	end
	if profile.settings then
		Atoms.settings(profile.settings)
	end
end

function Actions.addInvite(invite: Atoms.Invite)
	for _, existing in ipairs(Atoms.invites()) do
		if existing.inviteId == invite.inviteId then
			return
		end
	end
	Atoms.mutate(Atoms.invites, function(list)
		table.insert(list, invite)
	end)
end

function Actions.setInviteState(inviteId: string, state: string)
	Atoms.mutate(Atoms.invites, function(list)
		for index, invite in ipairs(list) do
			if invite.inviteId == inviteId then
				local copy = table.clone(invite)
				copy.state = state :: any
				list[index] = copy
			end
		end
	end)
end

function Actions.removeInvite(inviteId: string)
	Atoms.mutate(Atoms.invites, function(list)
		for index = #list, 1, -1 do
			if list[index].inviteId == inviteId then
				table.remove(list, index)
			end
		end
	end)
end

-- Convite vencido nunca é aceito só porque o cartão continuava na tela: primeiro vira "expirado"
-- (o jogador entende o que aconteceu) e três segundos depois sai da lista.
function Actions.expireInvites(now: number): boolean
	local changed = false
	local list = table.clone(Atoms.invites())
	for index = #list, 1, -1 do
		local invite = list[index]
		if now >= invite.expiresAt then
			if invite.state == "pending" then
				local copy = table.clone(invite)
				copy.state = "expired"
				list[index] = copy
				changed = true
			elseif now >= invite.expiresAt + 3 then
				table.remove(list, index)
				changed = true
			end
		end
	end
	if changed then
		Atoms.invites(list)
	end
	return changed
end

function Actions.markInviteSent(userId: number, state: string, now: number?)
	Atoms.mutateMap(Atoms.sentInvites, function(map)
		map[userId] = { at = now or os.clock(), state = state }
	end)
end

-- ---------------------------------------------------------------------------
-- Conexão
-- ---------------------------------------------------------------------------

function Actions.noteFrame(now: number?)
	Atoms.lastFrameAt(now or os.clock())
	if Atoms.connection() ~= "ok" then
		Atoms.connection("ok")
	end
end

-- 2 s sem quadro mostra "sinal instável"; 5 s bloqueia mutações e reconcilia.
-- O tabuleiro nunca é apagado no primeiro atraso.
function Actions.updateConnection(now: number): Atoms.Connection
	local silence = now - Atoms.lastFrameAt()
	local next_: Atoms.Connection = if silence >= 5 then "reconciling" elseif silence >= 2 then "unstable" else "ok"
	if next_ ~= Atoms.connection() then
		Atoms.connection(next_)
	end
	return next_
end

function Actions.setConnection(value: Atoms.Connection)
	Atoms.connection(value)
end

-- ---------------------------------------------------------------------------
-- Navegação e avisos curtos
-- ---------------------------------------------------------------------------

-- Troca a tela atual e esquece a origem (usado na navegação lateral do menu).
function Actions.navigate(route: Atoms.Route, params: { [string]: any }?)
	Atoms.history({})
	Atoms.route(route)
	Atoms.routeParams(params or {})
end

-- Abre uma tela guardando de onde veio (Configurações, detalhe de torre, convites…).
function Actions.push(route: Atoms.Route, params: { [string]: any }?)
	local origin: { route: Atoms.Route, params: { [string]: any } } =
		{ route = Atoms.route() :: Atoms.Route, params = Atoms.routeParams() }
	Atoms.mutate(Atoms.history, function(stack)
		table.insert(stack, origin)
	end)
	Atoms.route(route)
	Atoms.routeParams(params or {})
end

-- Volta para a tela anterior. Devolve false quando não havia origem guardada.
function Actions.back(): boolean
	local stack = Atoms.history()
	local last = stack[#stack]
	if not last then
		return false
	end
	Atoms.mutate(Atoms.history, function(list)
		table.remove(list)
	end)
	Atoms.route(last.route)
	Atoms.routeParams(last.params)
	return true
end

-- Volta empilhando até uma tela específica (ex.: sair do detalhe direto para a coleção).
function Actions.backTo(route: Atoms.Route): boolean
	local stack = table.clone(Atoms.history())
	for index = #stack, 1, -1 do
		if stack[index].route == route then
			local target = stack[index]
			for _ = index, #stack do
				table.remove(stack)
			end
			Atoms.history(stack)
			Atoms.route(target.route)
			Atoms.routeParams(target.params)
			return true
		end
	end
	return false
end

-- Um modal por vez: abrir outro substitui o anterior (nunca empilha dois bloqueadores).
function Actions.openModal(modal: Atoms.Modal)
	Atoms.modal(modal)
end

function Actions.setModalPending(pending: boolean)
	local current = Atoms.modal()
	if not current then
		return
	end
	local copy = table.clone(current)
	copy.pending = pending
	Atoms.modal(copy)
end

function Actions.closeModal()
	Atoms.modal(nil)
end

Actions.TOAST_LIMIT = 3
Actions.TOAST_SECONDS = 2.5

-- Fila de no máximo três avisos, sem repetir o mesmo texto em menos de um segundo.
function Actions.toast(text: string, kind: Atoms.ToastKind?, now: number?)
	local clock = now or os.clock()
	for _, toast in ipairs(Atoms.toasts()) do
		if toast.text == text and toast.expiresAt - Actions.TOAST_SECONDS > clock - 1 then
			return
		end
	end
	nextToastId += 1
	local toast: Atoms.Toast = {
		id = nextToastId,
		text = text,
		kind = kind or "info",
		expiresAt = clock + Actions.TOAST_SECONDS,
	}
	Atoms.mutate(Atoms.toasts, function(list)
		table.insert(list, toast)
		while #list > Actions.TOAST_LIMIT do
			table.remove(list, 1)
		end
	end)
end

function Actions.expireToasts(now: number): boolean
	local changed = false
	local list = table.clone(Atoms.toasts())
	for index = #list, 1, -1 do
		if now >= list[index].expiresAt then
			table.remove(list, index)
			changed = true
		end
	end
	if changed then
		Atoms.toasts(list)
	end
	return changed
end

-- ---------------------------------------------------------------------------
-- Partida
-- ---------------------------------------------------------------------------

function Actions.setSnapshot(snapshot: Types.MatchSnapshot?)
	Atoms.snapshot(snapshot)
end

function Actions.setPendingResult(result: { matchId: string, status: string, buttons: number? }?)
	Atoms.pendingResult(result)
end

function Actions.selectTower(entityId: number?)
	Atoms.selectedTowerId(entityId)
	if entityId ~= nil then
		Atoms.selectedEnemyId(nil)
	end
end

function Actions.selectEnemy(entityId: number?)
	Atoms.selectedEnemyId(entityId)
	if entityId ~= nil then
		Atoms.selectedTowerId(nil)
	end
end

function Actions.enterBuild(towerId: string)
	Atoms.buildTowerId(towerId)
	Atoms.buildCell(nil)
	Atoms.buildBlockedReason(nil)
	Atoms.selectedTowerId(nil)
	Atoms.selectedEnemyId(nil)
end

function Actions.exitBuild()
	Atoms.buildTowerId(nil)
	Atoms.buildCell(nil)
	Atoms.buildBlockedReason(nil)
end

function Actions.setBuildCell(cell: Types.Cell?, blockedReason: string?)
	Atoms.buildCell(cell)
	Atoms.buildBlockedReason(blockedReason)
end

-- Guia da primeira fase: avança por ação do jogador, nunca por tempo.
function Actions.setIntroStep(step: number?)
	Atoms.introStep(step)
end

function Actions.setBossBanner(text: string?)
	Atoms.bossBanner(text)
end

-- Aviso grande de uma linha. Ele mesmo não some: quem limpa é o relógio curto do App.
function Actions.announce(text: string, sub: string?, tone: ("good" | "warn")?)
	Atoms.announce({ text = text, sub = sub, tone = tone or "good", at = os.clock() })
end

Actions.ANNOUNCE_SECONDS = 2.8

-- Chamado pelo relógio da interface: devolve true quando apagou o aviso.
function Actions.expireAnnounce(now: number): boolean
	local current = Atoms.announce()
	if current and now - current.at >= Actions.ANNOUNCE_SECONDS then
		Atoms.announce(nil)
		return true
	end
	return false
end

return Actions
