--!strict
-- Estado do cliente em átomos Charm. Um átomo por fato; nada de "estado derivado" guardado.
--
-- Regras:
--  * quem escreve são as ações (State/Actions) e a rede; a interface só lê;
--  * valores de tabela são trocados por cópias novas (Charm compara por identidade);
--  * nada aqui simula economia, dano ou preço: é espelho do que o servidor mandou.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Charm = require(ReplicatedStorage.Shared.Lib.Charm)

local Atoms = {}

export type Atom<T> = Charm.Atom<T>

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

export type SentInvite = { at: number, state: string }

export type Route =
	"boot"
	| "menu"
	| "campaign"
	| "collection"
	| "shop"
	| "party"
	| "rooms"
	| "invites"
	| "settings"
	| "cosmetics"
	| "loading"
	| "play"
	| "result"

-- Modal bloqueador: um por vez, sempre com uma saída clara.
export type Modal = {
	title: string,
	body: string?,
	confirmText: string?,
	cancelText: string?,
	danger: boolean?,
	pending: boolean?,
	onConfirm: (() -> ())?,
	onCancel: (() -> ())?,
}

export type ToastKind = "info" | "success" | "error"
export type Toast = { id: number, text: string, kind: ToastKind, expiresAt: number }

-- ---------------------------------------------------------------------------
-- Conta e lobby
-- ---------------------------------------------------------------------------

Atoms.lobby = Charm.atom(nil :: { [string]: any }?)
Atoms.profile = Charm.atom(nil :: { [string]: any }?)
Atoms.profileStatus = Charm.atom("loading" :: string)
Atoms.invites = Charm.atom({} :: { Invite })
Atoms.sentInvites = Charm.atom({} :: { [number]: SentInvite })
Atoms.pendingResult = Charm.atom(nil :: { matchId: string, status: string, buttons: number? }?)

-- ---------------------------------------------------------------------------
-- Conexão
-- ---------------------------------------------------------------------------

Atoms.connection = Charm.atom("ok" :: Connection)
Atoms.lastFrameAt = Charm.atom(os.clock() :: number)

-- ---------------------------------------------------------------------------
-- Navegação e sobreposições
-- ---------------------------------------------------------------------------

Atoms.route = Charm.atom("boot" :: Route)
Atoms.routeParams = Charm.atom({} :: { [string]: any })
-- Pilha de telas para o "voltar" (Configurações abre de qualquer lugar e volta para a origem).
Atoms.history = Charm.atom({} :: { { route: Route, params: { [string]: any } } })
-- Combate aberto: o roteador de menu fica suspenso enquanto isto é verdadeiro.
Atoms.inMatch = Charm.atom(false :: boolean)
Atoms.toasts = Charm.atom({} :: { Toast })
Atoms.modal = Charm.atom(nil :: Modal?)
Atoms.orientationWarning = Charm.atom(false :: boolean)

-- ---------------------------------------------------------------------------
-- Partida
-- ---------------------------------------------------------------------------

Atoms.snapshot = Charm.atom(nil :: Types.MatchSnapshot?)
-- Espelho acumulado das torres: o snapshot parcial só traz inimigos, então as torres vivem aqui
-- entre dois quadros completos (os inimigos são lidos direto do snapshot, que sempre os traz).
Atoms.towers = Charm.atom({} :: { [number]: Types.TowerSnapshot })
Atoms.matchResult = Charm.atom(nil :: { [string]: any }?)
Atoms.rematch = Charm.atom(nil :: { ready: number, total: number }?)
-- Guia da primeira fase (passo 1 escolher o Dardo, 2 posicionar, 3 chamar a onda). É só
-- apresentação: nada aqui muda regra, e some assim que a primeira onda começa.
Atoms.introStep = Charm.atom(nil :: number?)

Atoms.bossBanner = Charm.atom(nil :: string?)

-- Aviso grande e curto no meio da tela ("Onda 3 concluída!"). Só apresentação: quem decide
-- onda, recompensa e fase continua sendo o servidor. `at` é relógio local, para o aviso sumir.
export type Announce = {
	text: string,
	sub: string?,
	tone: "good" | "warn",
	at: number,
}
Atoms.announce = Charm.atom(nil :: Announce?)

-- Interação de combate (só cliente: o servidor confirma tudo de novo)
Atoms.selectedTowerId = Charm.atom(nil :: number?)
Atoms.selectedEnemyId = Charm.atom(nil :: number?)
Atoms.buildTowerId = Charm.atom(nil :: string?)
Atoms.buildCell = Charm.atom(nil :: Types.Cell?)
Atoms.buildBlockedReason = Charm.atom(nil :: string?)
Atoms.loadout = Charm.atom({} :: { string })
Atoms.zoomed = Charm.atom(false :: boolean)
-- Menu de pausa aberto. É só a tela: a partida é do servidor e continua correndo (em grupo não
-- daria para parar o relógio de todo mundo).
Atoms.paused = Charm.atom(false :: boolean)
-- Doca de torres expandida. Só vale no layout compacto, onde ela fica encolhida num botão para
-- não cobrir o Farol.
Atoms.buildDockOpen = Charm.atom(false :: boolean)

-- ---------------------------------------------------------------------------
-- Preferências (espelho local do que foi salvo no perfil)
-- ---------------------------------------------------------------------------

Atoms.settings = Charm.atom(nil :: Types.ProfileSettings?)
Atoms.compact = Charm.atom(false :: boolean) -- layout de celular em paisagem

-- ---------------------------------------------------------------------------
-- Auxiliares
-- ---------------------------------------------------------------------------

-- Atualiza um átomo de tabela com uma cópia modificada (mantém o valor anterior intacto).
function Atoms.mutate<T>(atom: Atom<{ T }>, fn: (list: { T }) -> ())
	local copy = table.clone(atom())
	fn(copy)
	atom(copy)
end

function Atoms.mutateMap<K, V>(atom: Atom<{ [K]: V }>, fn: (map: { [K]: V }) -> ())
	local copy = table.clone(atom())
	fn(copy)
	atom(copy)
end

-- Zera tudo que é de sessão (usado ao sair da experiência ou em teste).
function Atoms.clear()
	Atoms.lobby(nil)
	Atoms.profile(nil)
	Atoms.profileStatus("loading")
	Atoms.invites({})
	Atoms.sentInvites({})
	Atoms.pendingResult(nil)
	Atoms.connection("ok")
	Atoms.lastFrameAt(os.clock())
	Atoms.snapshot(nil)
	Atoms.matchResult(nil)
	Atoms.introStep(nil)
	Atoms.bossBanner(nil)
	Atoms.announce(nil)
	Atoms.selectedTowerId(nil)
	Atoms.selectedEnemyId(nil)
	Atoms.buildTowerId(nil)
	Atoms.buildCell(nil)
	Atoms.toasts({})
end

return Atoms
