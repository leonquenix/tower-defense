--!strict
-- Fluxos do jogo que atravessam telas: começar fase, sair, revanche, comandos de combate.
--
-- As telas chamam estas funções em vez de receber uma sopa de callbacks. Nenhuma delas decide
-- resultado: tudo é pedido ao servidor e confirmado pela resposta ou pelo próximo quadro.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
function GameFlow.startLevel(levelId: string, difficulty: string?)
	if Commands.isPending("match:start") then
		return
	end
	local level = Catalog.getLevel(levelId)
	if not level then
		return
	end
	Atoms.loadout(GameFlow.loadout())
	Actions.navigate("loading", {
		levelId = levelId,
		mapId = level.mapId,
		difficulty = difficulty or "normal",
		startedAt = os.clock(),
	})
	Commands.send(
		"match:start",
		"StartMatch",
		{ levelId = levelId, mode = difficulty or "normal", matchMode = "campaign" },
		{
			onError = function(code, response)
				Actions.navigate("menu")
				if response.reason == "level_locked" then
					Actions.toast(L("campaign.locked"), "error")
				elseif response.reason == "not_ready" then
					Actions.toast(L("party.waitingReady"), "error")
				elseif response.reason == "empty_loadout" then
					Actions.toast(L("menu.teamEmpty"), "error")
				else
					Actions.toast(L("error." .. code), "error")
				end
			end,
		}
	)
end

-- Sair da tela de resultado direto para outra fase. A partida anterior já acabou: o servidor
-- solta o jogador dela ao receber o StartMatch, e o "left" atrasado não derruba a nova.
function GameFlow.goToLevel(levelId: string)
	Atoms.matchResult(nil)
	Commands.send("match:leave", "LeaveMatch", {}, nil)
	GameFlow.startLevel(levelId)
end

function GameFlow.startTraining(mapId: string?)
	if Commands.isPending("match:start") then
		return
	end
	Atoms.loadout(GameFlow.loadout())
	Actions.navigate("loading", { mapId = mapId or "jardim", difficulty = "normal", startedAt = os.clock() })
	Commands.send("match:start", "StartMatch", { mapId = mapId or "jardim", matchMode = "training" }, {
		onError = function(code)
			Actions.navigate("menu")
			Actions.toast(L("error." .. code), "error")
		end,
	})
end

-- Sair da partida pede confirmação: o combate continua rodando no servidor enquanto isso.
function GameFlow.confirmLeave()
	Actions.openModal({
		title = L("hud.leave"),
		body = L("hud.leaveConfirm"),
		confirmText = L("hud.leave"),
		danger = true,
		onConfirm = function()
			Actions.closeModal()
			GameFlow.leaveMatch()
		end,
	})
end

-- Sair da partida sem depender da resposta do servidor.
--
-- O caminho normal é: pede LeaveMatch, o servidor manda o quadro "left" e MatchController limpa
-- tudo. Mas no fim de uma fase a partida já foi encerrada no servidor, então o pedido volta com
-- erro e o "left" nunca chega — o jogador ficava preso na tela de combate com o resultado fechado
-- (trava relatada em 19/09). Agora, se o quadro não vier, o cliente volta sozinho para o menu.
local LEAVE_TIMEOUT = 2

function GameFlow.leaveMatch()
	local snapshot = Atoms.snapshot()
	local matchId = if snapshot then snapshot.matchId else nil
	Commands.send("match:leave", "LeaveMatch", {}, {
		onError = function()
			GameFlow.forceReturnToMenu(matchId)
		end,
	})
	task.delay(LEAVE_TIMEOUT, function()
		GameFlow.forceReturnToMenu(matchId)
	end)
end

-- Encerra a partida do lado do cliente. Só age se ainda estivermos na mesma partida: um "left"
-- que chegou primeiro, ou uma revanche que já começou outra partida, não são desfeitos aqui.
function GameFlow.forceReturnToMenu(matchId: string?)
	if not Atoms.inMatch() then
		return
	end
	local snapshot = Atoms.snapshot()
	if matchId and snapshot and snapshot.matchId ~= matchId then
		return
	end
	Atoms.inMatch(false)
	Atoms.matchResult(nil)
	Atoms.towers({})
	Actions.setSnapshot(nil)
	Actions.setIntroStep(nil)
	Actions.exitBuild()
	Actions.selectTower(nil)
	Actions.selectEnemy(nil)
	Actions.navigate("menu")
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
	local payload: { [string]: any } = { towerId = towerId, x = x, y = y }
	local snapshot = Atoms.snapshot()
	-- Reforço armado e ainda válido: a torre vai como grátis (o servidor confere e gasta a ficha)
	if Atoms.supportArmed() and snapshot and snapshot.supportAvailable then
		payload.support = true
		Actions.setSupportArmed(false)
		local id = matchId()
		if id and Selectors.canMutate() then
			payload.matchId = id
			Commands.send("build:place", "PlaceTower", payload, {
				onSuccess = function()
					Actions.toast(L("support.used"), "success")
				end,
				onError = function(code)
					Actions.toast(L("error." .. code), "error")
				end,
			})
		end
	else
		combat("build:place", "PlaceTower", payload)
	end
	Actions.exitBuild()
	-- posicionou: a doca encolhe sozinha para o tabuleiro voltar inteiro (layout compacto)
	Actions.setBuildDockOpen(false)
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

function GameFlow.trainingSpawn(enemyId: string, count: number)
	combat("training:spawn", "TrainingSpawn", { enemyId = enemyId, count = count })
end

function GameFlow.trainingClear()
	combat("training:clear", "TrainingClear", {})
end

-- O Pulso é compartilhado pelo grupo, então gastar a recarga precisa ser um ato deliberado.
-- A confirmação agora é o próprio gesto: segurar 1,5 s no Farol, com a barra enchendo à vista
-- (BoardPresenter). Por isso aqui não abre mais modal — quando esta função é chamada, o jogador
-- já segurou o tempo inteiro.
function GameFlow.pulse()
	if not Atoms.snapshot() then
		return
	end
	combat("match:pulse", "CastPulse", {})
end

-- ---------------------------------------------------------------------------
-- Fichas: Retomada, Reforço e loja
-- ---------------------------------------------------------------------------

-- Arma (ou desarma) o Reforço. Armado, a doca abre para o jogador escolher a torre grátis.
function GameFlow.toggleSupport()
	local armed = not Atoms.supportArmed()
	Actions.setSupportArmed(armed)
	if armed then
		Actions.setBuildDockOpen(true)
	end
end

function GameFlow.useRetry()
	combat("match:retry", "UseRetry", {})
end

function GameFlow.declineRetry()
	Actions.setRetryDeclined(true)
	combat("match:retryDecline", "DeclineRetry", {})
end

-- Consulta a vitrine (preços reais). As telas chamam ao abrir; o resultado fica em Atoms.shop.
function GameFlow.queryShop()
	Commands.send("shop:query", "QueryShop", {}, {
		onSuccess = function(response)
			if typeof(response.shop) == "table" then
				Actions.setShop(response.shop)
			end
		end,
	})
end

-- Abre a janela oficial do Roblox. A ficha só chega pelo recibo (aviso "purchase").
function GameFlow.buyProduct(productKey: string)
	Commands.send("shop:prompt:" .. productKey, "PromptProduct", { productKey = productKey }, {
		onSuccess = function()
			Actions.toast(L("shop.promptOpened"), "info")
		end,
		onError = function(code)
			Actions.toast(L("error." .. code), "error")
		end,
	})
end

function GameFlow.buyRetryWithButtons(onDone: (() -> ())?)
	Commands.send("shop:buttons:retry", "BuyWithButtons", { item = "retry" }, {
		onSuccess = function()
			Actions.purchaseDelivered("retry", 1)
			if onDone then
				onDone()
			end
		end,
		onError = function(code)
			Actions.toast(L("error." .. code), "error")
		end,
	})
end

function GameFlow.claimDaily()
	Commands.send("reward:daily", "ClaimDaily", {}, {
		onSuccess = function(response)
			Actions.toast(L("daily.got", { text = Selectors.rewardText(response.reward) }), "success")
		end,
		onError = function(code)
			Actions.toast(L("error." .. code), "error")
		end,
	})
end

function GameFlow.claimGift(index: number)
	Commands.send("reward:gift", "ClaimSessionGift", { index = index }, {
		onSuccess = function(response)
			Actions.toast(L("gifts.got", { text = Selectors.rewardText(response.reward) }), "success")
		end,
		onError = function(code)
			Actions.toast(L("error." .. code), "error")
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
