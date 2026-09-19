--!strict
-- Espelho do estado da partida no cliente: frames a 10 Hz, buffer de interpolação de 100 ms,
-- eventos cosméticos deduplicados. Nunca decide dano, preço ou resultado.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Actions = require(script.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.State.Atoms)
local Client = require(script.Parent.Parent.Net.Client)

local MatchController = {}

export type EnemyView = {
	id: number,
	defId: string,
	isBoss: boolean,
	isSummon: boolean,
	hp: number,
	maxHp: number,
	slow: number,
	mark: number,
	telegraphing: boolean,
	telegraphAt: number?, -- simTime da resolução do aviso (reconstrói a contagem após atraso)
	armorBonus: number, -- reforço ativo do Rei Ferrugem
	armor: number, -- armadura atual efetiva
	energyResistance: number,
	samples: { { t: number, s: number, v: number } },
	lastSeen: number,
}

export type MatchView = {
	snapshot: Types.MatchSnapshot,
	receivedAt: number,
	enemies: { [number]: EnemyView },
	towers: { [number]: Types.TowerSnapshot },
	tutorialStep: number,
	result: any?,
	rewardOutcome: any?,
	rematch: { ready: number, total: number }?,
}

MatchController.INTERP_DELAY = 0.1
MatchController.localUserId = Players.LocalPlayer.UserId

local view: MatchView? = nil
local lastRevision = -1
local listeners: { [string]: { (...any) -> () } } = {}

local function emit(kind: string, ...: any)
	local list = listeners[kind]
	if list then
		for _, fn in ipairs(list) do
			task.spawn(fn, ...)
		end
	end
end

function MatchController.on(kind: string, fn: (...any) -> ())
	listeners[kind] = listeners[kind] or {}
	table.insert(listeners[kind], fn)
end

function MatchController.current(): MatchView?
	return view
end

function MatchController.inMatch(): boolean
	return view ~= nil
end

function MatchController.estimateSimTime(): number
	local v = view
	if not v then
		return 0
	end
	local snap = v.snapshot
	local running = snap.phase == "Wave" or snap.phase == "Preparation" or snap.phase == "Intermission"
	if not running then
		return snap.simTime
	end
	return snap.simTime + (os.clock() - v.receivedAt) * snap.speedMultiplier
end

function MatchController.renderTime(): number
	return MatchController.estimateSimTime() - MatchController.INTERP_DELAY
end

-- Distância s interpolada/extrapolada no relógio de apresentação
function MatchController.enemyS(enemy: EnemyView, renderTime: number): number
	local samples = enemy.samples
	local n = #samples
	if n == 0 then
		return 0
	end
	if n == 1 or renderTime >= samples[n].t then
		local last = samples[n]
		return last.s + math.max(0, renderTime - last.t) * last.v
	end
	for i = n - 1, 1, -1 do
		local a, b = samples[i], samples[i + 1]
		if renderTime >= a.t then
			local span = b.t - a.t
			local k = if span > 0 then (renderTime - a.t) / span else 1
			return a.s + (b.s - a.s) * math.clamp(k, 0, 1)
		end
	end
	return samples[1].s
end

local function applySnapshot(snapshot: Types.MatchSnapshot)
	local now = os.clock()
	local v = view
	if not v then
		v = {
			snapshot = snapshot,
			receivedAt = now,
			enemies = {},
			towers = {},
			tutorialStep = snapshot.tutorialStep or 0,
			result = nil,
			rewardOutcome = nil,
			rematch = nil,
		}
		view = v
	end
	local current = v :: MatchView
	current.snapshot = snapshot
	current.receivedAt = now
	current.tutorialStep = snapshot.tutorialStep or current.tutorialStep
	local seen: { [number]: boolean } = {}
	for _, e in ipairs(snapshot.enemies) do
		seen[e.id] = true
		local ev = current.enemies[e.id]
		if not ev then
			ev = {
				id = e.id,
				defId = e.d,
				isBoss = e.b,
				isSummon = e.sm,
				hp = e.hp,
				maxHp = e.mhp,
				slow = e.sl,
				mark = e.mk,
				telegraphing = e.tg,
				telegraphAt = e.tga,
				armorBonus = e.ab,
				armor = e.ar,
				energyResistance = e.er,
				samples = {},
				lastSeen = now,
			}
			current.enemies[e.id] = ev
		end
		ev.hp = e.hp
		ev.maxHp = e.mhp
		ev.slow = e.sl
		ev.mark = e.mk
		ev.telegraphing = e.tg
		ev.telegraphAt = e.tga
		ev.armorBonus = e.ab
		ev.armor = e.ar
		ev.energyResistance = e.er
		ev.lastSeen = now
		local samples = ev.samples
		local last = samples[#samples]
		if not last or snapshot.simTime > last.t then
			table.insert(samples, { t = snapshot.simTime, s = e.s, v = e.v })
			if #samples > 4 then
				table.remove(samples, 1)
			end
		end
	end
	for id in pairs(current.enemies) do
		if not seen[id] then
			current.enemies[id] = nil
		end
	end
	if snapshot.full then
		local towers: { [number]: Types.TowerSnapshot } = {}
		for _, t in ipairs(snapshot.towers) do
			towers[t.id] = t
		end
		current.towers = towers
		Atoms.towers(towers)
	end
	-- A interface lê os átomos; este módulo continua dono da interpolação para o tabuleiro.
	Actions.setSnapshot(snapshot)
	Actions.noteFrame(now)
end

local function onState(kind: string, payload: any, extra: any)
	if kind == "match" then
		view = nil
		lastRevision = -1
		applySnapshot(payload)
		if view and extra and typeof(extra) == "table" and extra.tutorialStep then
			(view :: MatchView).tutorialStep = extra.tutorialStep
		end
		Atoms.inMatch(true)
		Atoms.matchResult(nil)
		Atoms.rematch(nil)
		-- cartas da doca: treino libera todas, tutorial usa as iniciais, o resto usa a equipe salva
		local snapshot = payload :: Types.MatchSnapshot
		if snapshot.trainingUnlockAll then
			local all: { string } = {}
			for _, tower in ipairs(Balance.towers) do
				table.insert(all, tower.id)
			end
			Atoms.loadout(all)
		elseif snapshot.mode == "tutorial" or #Atoms.loadout() == 0 then
			-- tutorial usa as iniciais; equipe vazia também cai nelas para a doca nunca ficar vazia
			Atoms.loadout(Catalog.starterTowerIds())
		end
		Actions.setTutorial(if payload.mode == "tutorial" then (payload.tutorialStep or 1) else nil, false)
		Actions.navigate("play")
		emit("start", view, extra)
	elseif kind == "frame" then
		if not view then
			return
		end
		local snapshot = payload :: Types.MatchSnapshot
		if snapshot.revision < lastRevision then
			return -- revisão antiga
		end
		lastRevision = snapshot.revision
		applySnapshot(snapshot)
		emit("frame", view, extra or {})
	elseif kind == "result" then
		if view then
			(view :: MatchView).result = payload.result;
			(view :: MatchView).rewardOutcome = payload.outcome
		end
		Atoms.matchResult(payload)
		emit("result", payload)
	elseif kind == "left" then
		view = nil
		lastRevision = -1
		Atoms.inMatch(false)
		Atoms.matchResult(nil)
		Atoms.towers({})
		Actions.setSnapshot(nil)
		Actions.setTutorial(nil, false)
		Actions.exitBuild()
		Actions.selectTower(nil)
		Actions.selectEnemy(nil)
		Actions.navigate("menu")
		emit("left", payload)
	elseif kind == "tutorial" then
		if view then
			(view :: MatchView).tutorialStep = payload.step
		end
		Actions.setTutorial(payload.step, payload.retry == true)
		emit("tutorial", payload.step, payload.retry == true)
	elseif kind == "rematch" then
		if view then
			(view :: MatchView).rematch = { ready = payload.ready, total = payload.total }
		end
		Atoms.rematch({ ready = payload.ready, total = payload.total })
		emit("rematch", payload.ready, payload.total)
	end
end

function MatchController.init()
	Client.onState(onState)
end

-- Atalhos de comando (respostas tratadas pelo chamador)
function MatchController.command(action: string, payload: { [string]: any }?, callback: ((Client.Response) -> ())?)
	local v = view
	local body: { [string]: any } = payload or {}
	if v and body.matchId == nil then
		body.matchId = v.snapshot.matchId
	end
	Client.requestAsync(action, body, callback)
end

function MatchController.myTowerCount(): number
	local v = view
	if not v then
		return 0
	end
	local n = 0
	for _, t in pairs(v.towers) do
		if t.o == MatchController.localUserId then
			n += 1
		end
	end
	return n
end

function MatchController.myTowerCountOf(defId: string): number
	local v = view
	if not v then
		return 0
	end
	local n = 0
	for _, t in pairs(v.towers) do
		if t.o == MatchController.localUserId and t.d == defId then
			n += 1
		end
	end
	return n
end

function MatchController.towerAt(x: number, y: number): Types.TowerSnapshot?
	local v = view
	if not v then
		return nil
	end
	for _, t in pairs(v.towers) do
		if t.x == x and t.y == y then
			return t
		end
	end
	return nil
end

function MatchController.participantColor(userId: number): number
	local v = view
	if not v then
		return 1
	end
	for _, p in ipairs(v.snapshot.participants) do
		if p.userId == userId then
			return p.color
		end
	end
	return 1
end

function MatchController.participantName(userId: number): string
	local v = view
	if not v then
		return "?"
	end
	for _, p in ipairs(v.snapshot.participants) do
		if p.userId == userId then
			return p.name
		end
	end
	return "?"
end

function MatchController.clear()
	view = nil
	lastRevision = -1
end

return MatchController
