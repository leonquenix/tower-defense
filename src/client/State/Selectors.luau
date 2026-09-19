--!strict
-- Leituras derivadas dos átomos. São funções puras para que qualquer uma possa virar
-- Charm.computed ou ser lida direto dentro de um efeito/Fusion sem guardar estado novo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Atoms = require(script.Parent.Atoms)

local Selectors = {}

Selectors.INVITE_COOLDOWN = 5 -- segundos por destinatário (guia, prancha 33)

function Selectors.profile(): { [string]: any }?
	return Atoms.profile()
end

function Selectors.buttons(): number
	local profile = Atoms.profile()
	return if profile then (profile.buttons or 0) else 0
end

function Selectors.isPersistent(): boolean
	local profile = Atoms.profile()
	return profile ~= nil and profile.persistent == true
end

function Selectors.party(): { [string]: any }?
	local lobby = Atoms.lobby()
	return if lobby then lobby.party else nil
end

function Selectors.rooms(): { any }
	local lobby = Atoms.lobby()
	return if lobby then (lobby.rooms or {}) else {}
end

function Selectors.players(): { any }
	local lobby = Atoms.lobby()
	return if lobby then (lobby.players or {}) else {}
end

function Selectors.ownedTowerIds(): { string }
	local profile = Atoms.profile()
	return if profile then (profile.ownedTowerIds or {}) else {}
end

function Selectors.owns(towerId: string): boolean
	for _, id in ipairs(Selectors.ownedTowerIds()) do
		if id == towerId then
			return true
		end
	end
	return false
end

function Selectors.loadout(): { string }
	local profile = Atoms.profile()
	if profile and profile.loadout then
		return profile.loadout
	end
	return Atoms.loadout()
end

-- Mutação permitida: com sinal instável ainda vale tentar; reconciliando, não.
function Selectors.canMutate(): boolean
	local connection = Atoms.connection()
	return connection == "ok" or connection == "unstable"
end

function Selectors.inviteCooldownLeft(userId: number, now: number?): number
	local sent = Atoms.sentInvites()[userId]
	if not sent then
		return 0
	end
	return math.max(0, Selectors.INVITE_COOLDOWN - ((now or os.clock()) - sent.at))
end

function Selectors.pendingInvites(): { Atoms.Invite }
	local out: { Atoms.Invite } = {}
	for _, invite in ipairs(Atoms.invites()) do
		if invite.state == "pending" then
			table.insert(out, invite)
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Partida
-- ---------------------------------------------------------------------------

function Selectors.inMatch(): boolean
	return Atoms.snapshot() ~= nil
end

function Selectors.wallet(): number
	local snapshot = Atoms.snapshot()
	return if snapshot then snapshot.wallet else 0
end

function Selectors.phase(): Types.Phase?
	local snapshot = Atoms.snapshot()
	return if snapshot then snapshot.phase else nil
end

function Selectors.isTraining(): boolean
	local snapshot = Atoms.snapshot()
	return snapshot ~= nil and snapshot.mode == "training"
end

function Selectors.participants(): { Types.ParticipantSnapshot }
	local snapshot = Atoms.snapshot()
	return if snapshot then snapshot.participants else {}
end

function Selectors.participantName(userId: number): string?
	for _, participant in ipairs(Selectors.participants()) do
		if participant.userId == userId then
			return participant.name
		end
	end
	return nil
end

-- Conta pelo espelho acumulado: o snapshot parcial vem sem torres (só o completo, a cada 2 s),
-- então contar por ele faria o "Torres 0/18" piscar para zero entre os quadros.
function Selectors.myTowerCount(localUserId: number): number
	local count = 0
	for _, tower in pairs(Atoms.towers()) do
		if tower.o == localUserId then
			count += 1
		end
	end
	return count
end

function Selectors.myTowerCountOf(localUserId: number, defId: string): number
	local count = 0
	for _, tower in pairs(Atoms.towers()) do
		if tower.o == localUserId and tower.d == defId then
			count += 1
		end
	end
	return count
end

return Selectors
