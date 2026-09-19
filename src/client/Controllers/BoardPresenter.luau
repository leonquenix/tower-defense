--!strict
-- Apresentação do combate: tabuleiro, entrada e efeitos. Não desenha interface (o HUD é Fusion)
-- e não decide nada de jogo — só mostra o que o servidor mandou e manda a intenção de volta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Grid = require(ReplicatedStorage.Shared.Math.Grid)
local Circuits = require(ReplicatedStorage.Shared.Rules.Circuits)
local Simulation = require(ReplicatedStorage.Shared.Sim.Simulation)
local Types = require(ReplicatedStorage.Shared.Types)
local Actions = require(script.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.State.Bridge)
local BoardRenderer = require(script.Parent.Parent.View.BoardRenderer)
local BoardTransform = require(script.Parent.Parent.View.BoardTransform)
local Juice = require(script.Parent.Parent.View.Juice)
local AudioController = require(script.Parent.AudioController)
local BuildIntent = require(script.Parent.BuildIntent)
local GameFlow = require(script.Parent.GameFlow)
local InputController = require(script.Parent.InputController)
local MatchController = require(script.Parent.MatchController)
local SettingsController = require(script.Parent.SettingsController)

local BoardPresenter = {}

local L = Localization.get

local transform: BoardTransform.BoardTransform? = nil
local renderer: BoardRenderer.Renderer? = nil
local boardArea: Frame? = nil
local inputReady = false
local localUserId = Players.LocalPlayer.UserId

-- ---------------------------------------------------------------------------
-- Construção
-- ---------------------------------------------------------------------------

local function validCells(snapshot: Types.MatchSnapshot): { Types.Cell }
	local path = Simulation.getPath(snapshot.mapId)
	local blocked = Simulation.getBlocked(snapshot.mapId)
	local towers = Atoms.towers()
	local occupied: { [number]: boolean } = {}
	for _, tower in pairs(towers) do
		occupied[Grid.cellKey(tower.x, tower.y)] = true
	end
	local cells: { Types.Cell } = {}
	for x = 0, Grid.COLUMNS - 1 do
		for y = 0, Grid.ROWS - 1 do
			local key = Grid.cellKey(x, y)
			if not path.cellSet[key] and not blocked[key] and not occupied[key] then
				table.insert(cells, { x, y })
			end
		end
	end
	return cells
end

local function towerAt(x: number, y: number): Types.TowerSnapshot?
	for _, tower in pairs(Atoms.towers()) do
		if tower.x == x and tower.y == y then
			return tower
		end
	end
	return nil
end

-- Mesma regra do servidor, só que para explicar antes de gastar. O servidor decide de novo.
local function evaluateCell(towerId: string, x: number, y: number): (boolean, string?, number?)
	local snapshot = Atoms.snapshot()
	local def = Catalog.getTower(towerId)
	if not snapshot or not def then
		return false, "build.invalidCell", nil
	end
	if not Grid.inBounds(x, y) then
		return false, "build.invalidCell", nil
	end
	local key = Grid.cellKey(x, y)
	if Simulation.getPath(snapshot.mapId).cellSet[key] then
		return false, "build.onPath", nil
	end
	if Simulation.getBlocked(snapshot.mapId)[key] then
		return false, "build.blocked", nil
	end
	if towerAt(x, y) then
		return false, "build.occupied", nil
	end
	local mine, ofType = 0, 0
	for _, tower in pairs(Atoms.towers()) do
		if tower.o == localUserId then
			mine += 1
			if tower.d == towerId then
				ofType += 1
			end
		end
	end
	if mine >= snapshot.limits.perPlayer or ofType >= def.perPlayerLimit then
		return false, "build.limit", nil
	end
	local cost = def.states.L0.cost
	if snapshot.mode ~= "training" and snapshot.wallet < cost then
		return false, "build.noFunds", nil
	end
	-- prévia de Circuito com a mesma regra determinística do servidor
	local towers: { Types.Tower } = {}
	for id, snapshotTower in pairs(Atoms.towers()) do
		table.insert(towers, {
			id = id,
			ownerUserId = snapshotTower.o,
			defId = snapshotTower.d,
			state = snapshotTower.st :: any,
			x = snapshotTower.x,
			y = snapshotTower.y,
			cooldown = 0,
			targetMode = "first",
			invested = snapshotTower.inv,
			placedAt = 0,
			circuitPartnerId = nil,
			circuitId = nil,
			dustUntil = 0,
			attackSeq = 0,
			activeSeconds = 0,
		})
	end
	local hypothetical: Types.Tower = {
		id = -1,
		ownerUserId = localUserId,
		defId = towerId,
		state = "L0",
		x = x,
		y = y,
		cooldown = 0,
		targetMode = "first",
		invested = cost,
		placedAt = 0,
		circuitPartnerId = nil,
		circuitId = nil,
		dustUntil = 0,
		attackSeq = 0,
		activeSeconds = 0,
	}
	local preview = Circuits.preview(towers, hypothetical, Catalog.getCircuitFor)
	return true, nil, if preview then preview.partnerId else nil
end

local function refreshBuildPreview()
	local currentRenderer = renderer
	if not currentRenderer then
		return
	end
	local towerId = Atoms.buildTowerId()
	local snapshot = Atoms.snapshot()
	if not towerId or not snapshot then
		currentRenderer:setBuildPreview(nil)
		return
	end
	local cell = Atoms.buildCell()
	local cells = validCells(snapshot)
	if cell then
		local valid, reason, partnerId = evaluateCell(towerId, cell[1], cell[2])
		Actions.setBuildCell(cell, reason)
		currentRenderer:setBuildPreview({
			towerId = towerId,
			x = cell[1],
			y = cell[2],
			valid = valid,
			reason = reason,
			partnerId = partnerId,
			circuitId = nil,
			validCells = cells,
		})
	else
		currentRenderer:setBuildPreview({
			towerId = towerId,
			x = nil,
			y = nil,
			valid = false,
			reason = nil,
			partnerId = nil,
			circuitId = nil,
			validCells = cells,
		})
	end
end

-- No tutorial, a torre guiada fica travada na célula marcada.
local function guidedCellFor(towerId: string): Types.Cell?
	local snapshot = Atoms.snapshot()
	local step = Atoms.tutorialStep()
	if not snapshot or snapshot.mode ~= "tutorial" or not step then
		return nil
	end
	if (step == 1 and towerId == "dardo") or (step == 3 and towerId == "goma") then
		local guided = Balance.tutorial.guidedCells[towerId]
		return if guided then { guided[1], guided[2] } else nil
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Entrada
-- ---------------------------------------------------------------------------

-- Verdadeiro quando o ponto está sobre um painel da interface (e não sobre o tabuleiro).
-- O tabuleiro vive na camada do cenário e o HUD numa camada acima, então a checagem é por
-- ordem de desenho: o primeiro objeto que engole toque (Active) ganha, a menos que seja o
-- próprio tabuleiro.
local function isOverChrome(point: Vector2): boolean
	local area = boardArea
	if not area then
		return false
	end
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	local objects = playerGui:GetGuiObjectsAtPosition(point.X, point.Y)
	for _, object in ipairs(objects) do
		if object:IsDescendantOf(area) then
			return false
		end
		if object.Active then
			return true
		end
	end
	return false
end

local function onTap(screen: Vector2)
	local currentTransform = transform
	local currentRenderer = renderer
	if not currentTransform or not currentRenderer or not Atoms.snapshot() then
		return
	end
	if isOverChrome(screen) then
		return
	end
	local x, y = currentTransform:screenToCell(screen)
	local towerId = Atoms.buildTowerId()
	if towerId then
		-- No tutorial a célula é a marcada, doa onde o jogador tocar.
		local guided = guidedCellFor(towerId)
		local targetX: number? = if guided then guided[1] else x
		local targetY: number? = if guided then guided[2] else y
		if targetX == nil or targetY == nil then
			return
		end
		local previous = Atoms.buildCell()
		local sameCell = previous ~= nil and previous[1] == targetX and previous[2] == targetY
		Actions.setBuildCell({ targetX, targetY }, nil)
		refreshBuildPreview()
		local valid, reason = evaluateCell(towerId, targetX, targetY)
		local decision = BuildIntent.decide({
			touch = InputController.isTouchDevice(),
			guided = guided ~= nil,
			sameCell = sameCell,
			valid = valid,
		})
		if decision == "blocked" then
			-- explica e não gasta nada; o fantasma fica na célula para o jogador ver o porquê
			Actions.toast(L(reason or "build.invalidCell"), "error")
		elseif decision == "place" then
			GameFlow.placeTower(towerId, targetX, targetY)
		else
			currentTransform:zoomToCellIfSmall(targetX, targetY)
		end
		return
	end
	if x == nil or y == nil then
		if currentTransform:isInsideWindow(screen) then
			Actions.selectTower(nil)
			Actions.selectEnemy(nil)
		end
		return
	end
	-- O sprite tem apoio em (0,5; 0,82): o corpo do bicho fica na célula de cima da base.
	-- Sem olhar a célula de baixo, clicar na raposa não selecionava nada.
	local tower = towerAt(x, y) or towerAt(x, y + 1)
	if tower then
		Actions.selectTower(tower.id)
		AudioController.play("ui_click")
		return
	end
	local px, py = currentTransform:screenToLogical(screen)
	-- mesma correção para inimigos: o ponto clicado é o corpo, a posição lógica são os pés
	local enemyId = currentRenderer:nearestEnemy(px, py + 0.3, 0.8)
	if enemyId then
		Actions.selectEnemy(enemyId)
		return
	end
	Actions.selectTower(nil)
	Actions.selectEnemy(nil)
end

local function onHover(screen: Vector2?)
	local towerId = Atoms.buildTowerId()
	local currentTransform = transform
	if not towerId or not screen or not currentTransform or InputController.isTouchDevice() then
		return
	end
	if guidedCellFor(towerId) or isOverChrome(screen) then
		return
	end
	local x, y = currentTransform:screenToCell(screen)
	if x ~= nil and y ~= nil then
		local cell = Atoms.buildCell()
		if not cell or cell[1] ~= x or cell[2] ~= y then
			Actions.setBuildCell({ x, y }, nil)
			refreshBuildPreview()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Eventos de partida
-- ---------------------------------------------------------------------------

local lastBossBannerAt = 0

local function handleEvents(events: { Types.NetEvent })
	local currentRenderer = renderer
	-- a recompensa da onda chega num evento e o fim da onda em outro, na mesma leva: o aviso
	-- junta os dois em uma linha só
	local income: number? = nil
	for _, event in ipairs(events) do
		if event.kind == "waveIncome" then
			income = event.amount
		end
	end
	for _, event in ipairs(events) do
		if event.kind == "waveStart" then
			AudioController.play("wave_start")
			Actions.setBossBanner(nil)
			Actions.announce(L("hud.waveIncoming", { wave = event.wave or 0 }), nil, "warn")
			if currentRenderer then
				currentRenderer:flashSpawn()
			end
		elseif event.kind == "waveEnd" then
			AudioController.play("wave_end")
			Actions.announce(
				L("hud.waveCleared", { wave = event.wave or 0 }),
				if income then L("hud.waveIncome", { amount = income }) else nil,
				"good"
			)
			if currentRenderer then
				currentRenderer:celebrateWaveEnd()
			end
		elseif event.kind == "bossSpawn" and event.enemyDefId then
			Actions.setBossBanner(L("hud.bossIncoming", { name = L("enemy." .. event.enemyDefId) }))
			AudioController.play("boss_spawn", true)
			lastBossBannerAt = os.clock()
			Juice.shakeBoard(0.9)
		elseif event.kind == "bossTelegraph" then
			AudioController.play("boss_telegraph", true)
		elseif event.kind == "bossAbility" then
			AudioController.play("boss_ability", true)
			Juice.shakeBoard(0.7)
			task.delay(2, function()
				if os.clock() - lastBossBannerAt >= 2 then
					Actions.setBossBanner(nil)
				end
			end)
		elseif event.kind == "leak" then
			AudioController.play("base_hit")
			-- vazamento é o único momento em que a apresentação "machuca": tremor e clarão
			Juice.shakeBoard(1)
			Juice.damageFlash()
		elseif event.kind == "pulse" then
			AudioController.play("base_pulse", true)
			Juice.shakeBoard(0.5)
		elseif event.kind == "towerPlaced" and event.userId == localUserId then
			AudioController.play("ui_confirm")
		elseif event.kind == "speedChanged" and event.reason == "overload" then
			Actions.toast(L("hud.speedOverload"), "error")
		elseif event.kind == "circuitChanged" and event.circuitId and event.towerId then
			local tower = Atoms.towers()[event.towerId :: number]
			if tower and tower.o == localUserId then
				Actions.toast(L("circuit." .. (event.circuitId :: string)) .. " ✓", "success")
			end
		elseif event.kind == "towerSold" and Atoms.selectedTowerId() == event.towerId then
			Actions.selectTower(nil)
		end
	end
	local _ = currentRenderer
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

local function applySettings(settings: Types.ProfileSettings)
	local currentRenderer = renderer
	if not currentRenderer then
		return
	end
	currentRenderer.reducedMotion = settings.reducedMotion
	currentRenderer.reducedParticles = settings.reducedParticles
	currentRenderer.damageNumbers = settings.damageNumbers
	currentRenderer:setCircuitPattern(settings.circuitPattern)
end

-- Chamado pelo App a cada montagem da interface: o tabuleiro muda de lugar, não de estado.
function BoardPresenter.attach(area: Frame)
	boardArea = area
	local existing = transform
	if existing then
		existing.viewport.Parent = area
		return
	end
	local currentTransform = BoardTransform.new(area)
	transform = currentTransform
	local currentRenderer = BoardRenderer.new(currentTransform)
	renderer = currentRenderer
	-- o tremor sacode o palco (a grade), não a janela: a janela é o recorte da tela inteira
	Juice.setBoard(currentTransform.stage)
	applySettings(SettingsController.get())

	InputController.init(currentTransform, {
		onTap = onTap,
		onHover = onHover,
		onPickSlot = function(slot)
			local ids = Atoms.loadout()
			local id = ids[slot]
			if not id then
				return
			end
			if Atoms.buildTowerId() == id then
				Actions.exitBuild()
			else
				Actions.enterBuild(id)
			end
		end,
		onCancel = function()
			if Atoms.buildTowerId() then
				Actions.exitBuild()
			else
				Actions.selectTower(nil)
				Actions.selectEnemy(nil)
			end
		end,
		onUpgradeKey = function()
			local selected = Atoms.selectedTowerId()
			if not selected then
				return
			end
			local tower = Atoms.towers()[selected]
			if tower and tower.o == localUserId then
				local nexts = Catalog.TRANSITIONS[tower.st] or {}
				if #nexts == 1 then
					GameFlow.upgradeTower(tower.id, nexts[1])
				end
			end
		end,
	})
	inputReady = true

	-- Remontagem no meio de uma partida: redesenha o mapa e aplica o último estado conhecido,
	-- sem esperar o próximo quadro completo do servidor.
	local view = MatchController.current()
	if view then
		currentRenderer:setMap(view.snapshot.mapId)
		currentRenderer:applyFrame(view, {})
		currentRenderer:setSelected(Atoms.selectedTowerId())
		refreshBuildPreview()
		InputController.setEnabled(true)
	end
end

function BoardPresenter.init()
	MatchController.on("start", function(view: MatchController.MatchView?)
		local currentRenderer = renderer
		if not view or not currentRenderer then
			return
		end
		local snapshot = view.snapshot
		currentRenderer:setMap(snapshot.mapId)
		currentRenderer:setSelected(nil)
		currentRenderer:setBuildPreview(nil)
		applySettings(SettingsController.get())
		InputController.setEnabled(true)
		AudioController.music("music_" .. snapshot.mapId)
		local transformNow = transform
		if transformNow then
			transformNow:reset(false)
		end
		currentRenderer:applyFrame(view, {})
	end)

	MatchController.on("frame", function(view: MatchController.MatchView, events: { Types.NetEvent })
		local currentRenderer = renderer
		if not currentRenderer then
			return
		end
		currentRenderer:applyFrame(view, events)
		handleEvents(events)
		if Atoms.buildTowerId() then
			refreshBuildPreview()
		end
		Atoms.zoomed(if transform then (transform :: BoardTransform.BoardTransform):isZoomed() else false)
	end)

	MatchController.on("left", function()
		InputController.setEnabled(false)
		AudioController.music("music_menu")
	end)

	SettingsController.onChanged(applySettings)

	-- Tutorial: as etapas de ação já abrem o posicionamento na torre certa, com a célula marcada.
	Bridge.watchAtom(Atoms.tutorialStep, function(step: number?)
		local snapshot = Atoms.snapshot()
		if not snapshot or snapshot.mode ~= "tutorial" or not step then
			return
		end
		local guidedTower = if step == 1 then "dardo" elseif step == 3 then "goma" else nil
		if not guidedTower then
			return
		end
		if Atoms.buildTowerId() ~= guidedTower then
			Actions.enterBuild(guidedTower)
		end
		local guided = Balance.tutorial.guidedCells[guidedTower]
		if guided then
			Actions.setBuildCell({ guided[1], guided[2] }, nil)
		end
		refreshBuildPreview()
	end)

	-- seleção e modo de construção são estado da interface: o tabuleiro só reage
	Bridge.watchAtom(Atoms.selectedTowerId, function(id: number?)
		local currentRenderer = renderer
		if currentRenderer then
			currentRenderer:setSelected(id)
		end
	end)
	Bridge.watchAtom(Atoms.buildTowerId, function()
		refreshBuildPreview()
	end)

	RunService.RenderStepped:Connect(function(deltaTime: number)
		local currentRenderer = renderer
		if currentRenderer and Atoms.snapshot() then
			currentRenderer:update(deltaTime)
		end
	end)
end

-- "Ver tudo": volta o tabuleiro para o enquadramento completo.
function BoardPresenter.resetZoom()
	local currentTransform = transform
	if currentTransform then
		currentTransform:reset(true)
		Atoms.zoomed(false)
	end
end

function BoardPresenter.isReady(): boolean
	return inputReady
end

return BoardPresenter
