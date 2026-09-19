--!strict
-- Fluxos do jogo que atravessam telas: começar partida, sair, revanche, tutorial.
--
-- As telas chamam estas funções em vez de receber uma sopa de callbacks. Nenhuma delas decide
-- resultado: tudo é pedido ao servidor e confirmado pela resposta ou pelo próximo quadro.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Actions = require(script.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.State.Atoms)
local Selectors = require(script.Parent.Parent.State.Selectors)
local Commands = require(script.Parent.Parent.Net.Commands)

local GameFlow = {}

local L = Localization.get

-- Equipe efetiva: a do perfil quando existe, senão as torres iniciais.
function GameFlow.loadout(): { string }
	local loadout = Selectors.loadout()
	if #loadout > 0 then
		return table.clone(loadout)
	end
	return Catalog.starterTowerIds()
end

-- Começa uma partida. "Começar" apertado dez vezes continua gerando uma partida só
-- (uma pendência por chave em Net/Commands).
function GameFlow.startMatch(mapId: string, difficulty: string, matchMode: string)
	if Commands.isPending("match:start") then
		return
	end
	Atoms.loadout(GameFlow.loadout())
	Actions.navigate("loading", {
		mapId = if matchMode == "tutorial" then "jardim" else mapId,
		difficulty = difficulty,
		startedAt = os.clock(),
	})
	Commands.send("match:start", "StartMatch", { mapId = mapId, mode = difficulty, matchMode = matchMode }, {
		onError = function(code, response)
			Actions.navigate("menu")
			if response.reason == "map_locked" then
				Actions.toast(L("menu.notAllUnlocked"), "error")
			elseif response.reason == "not_ready" then
				Actions.toast(L("party.waitingReady"), "error")
			elseif response.reason == "empty_loadout" then
				Actions.toast(L("menu.teamEmpty"), "error")
			else
				Actions.toast(L("error." .. code), "error")
			end
		end,
	})
end

function GameFlow.startTutorial()
	GameFlow.startMatch("jardim", "normal", "tutorial")
end

function GameFlow.startTraining(mapId: string?)
	GameFlow.startMatch(mapId or "jardim", "normal", "training")
end

-- Sair da partida pede confirmação: o combate continua rodando no servidor enquanto isso.
function GameFlow.confirmLeave()
	Actions.openModal({
		title = L("hud.leave"),
		body = L("hud.leaveConfirm"),
		confirmText = L("hud.leave"),
		danger = true,
		onConfirm = function()
			Actions.setModalPending(true)
			Commands.send("match:leave", "LeaveMatch", {}, {
				onSuccess = function()
					Actions.closeModal()
				end,
				onError = function(code)
					Actions.closeModal()
					Actions.toast(L("error." .. code), "error")
				end,
			})
		end,
	})
end

function GameFlow.leaveMatch()
	Commands.send("match:leave", "LeaveMatch", {}, nil)
end

function GameFlow.rematch(ready: boolean)
	Commands.send("match:rematch", "Rematch", { ready = ready }, {
		onError = function(code)
			Actions.toast(L("error." .. code), "error")
		end,
	})
end

-- Recompensas registradas mas ainda não creditadas (queda de conexão no fim da partida).
function GameFlow.claimPending()
	Commands.send("result:claim", "ClaimPending", {}, nil)
end

-- ---------------------------------------------------------------------------
-- Combate
-- ---------------------------------------------------------------------------

local function matchId(): string?
	local snapshot = Atoms.snapshot()
	return if snapshot then snapshot.matchId else nil
end

-- Toda ação de combate passa por aqui: uma pendência por chave, e o servidor decide o resto.
local function combat(key: string, action: string, payload: { [string]: any })
	local id = matchId()
	if not id then
		return
	end
	if not Selectors.canMutate() then
		Actions.toast(L("connection.blocked"), "error")
		return
	end
	payload.matchId = id
	Commands.send(key, action, payload, {
		onError = function(code)
			Actions.toast(L("error." .. code), "error")
		end,
	})
end

function GameFlow.placeTower(towerId: string, x: number, y: number)
	combat("build:place", "PlaceTower", { towerId = towerId, x = x, y = y })
	Actions.exitBuild()
end

function GameFlow.upgradeTower(entityId: number, nextState: string)
	combat("tower:upgrade:" .. tostring(entityId), "UpgradeTower", { entityId = entityId, nextState = nextState })
end

function GameFlow.sellTower(entityId: number)
	combat("tower:sell:" .. tostring(entityId), "SellTower", { entityId = entityId })
	Actions.selectTower(nil)
end

function GameFlow.setTarget(entityId: number, mode: string)
	combat("tower:target:" .. tostring(entityId), "SetTarget", { entityId = entityId, mode = mode })
end

function GameFlow.voteSpeed(value: number)
	combat("match:speed", "VoteSpeed", { value = value })
end

function GameFlow.setReady(ready: boolean)
	combat("match:ready", "SetReady", { ready = ready })
end

function GameFlow.tutorialAdvance(step: number)
	combat("tutorial:next", "TutorialAdvance", { step = step })
end

function GameFlow.tutorialSkip()
	Actions.openModal({
		title = L("tutorial.skip"),
		body = L("tutorial.skipConfirm"),
		confirmText = L("tutorial.skip"),
		onConfirm = function()
			Actions.closeModal()
			combat("tutorial:skip", "TutorialSkip", {})
		end,
	})
end

function GameFlow.trainingSpawn(enemyId: string, count: number)
	combat("training:spawn", "TrainingSpawn", { enemyId = enemyId, count = count })
end

function GameFlow.trainingClear()
	combat("training:clear", "TrainingClear", {})
end

-- O Pulso é compartilhado pelo grupo: sempre confirma antes de gastar a recarga de todo mundo.
function GameFlow.pulse()
	local snapshot = Atoms.snapshot()
	if not snapshot then
		return
	end
	local players = #snapshot.participants
	local damage = math.floor(Balance.pulse.damage * (1 + Balance.coopAdditionalHPPerPlayer * (players - 1)) + 0.5)
	Actions.openModal({
		title = L("hud.pulse"),
		body = L("hud.pulseSummary", {
			damage = damage,
			slow = math.floor(Balance.pulse.slow * 100 + 0.5),
			duration = string.format("%.1f", Balance.pulse.slowDuration):gsub("%.", ","),
			cooldown = Balance.pulse.cooldown,
		}),
		confirmText = L("hud.pulseUse"),
		onConfirm = function()
			Actions.closeModal()
			combat("match:pulse", "CastPulse", {})
		end,
	})
end

function GameFlow.retryProfile()
	Commands.send("boot:retry", "RetryProfile", {}, {
		onSuccess = function()
			Actions.toast(L("boot.retrying"), "info")
		end,
	})
end

return GameFlow
