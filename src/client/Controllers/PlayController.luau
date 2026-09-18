--!strict
-- Orquestra a tela de combate: tabuleiro, HUD, entrada, modo de construção, seleção e comandos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Shared.Types)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Grid = require(ReplicatedStorage.Shared.Math.Grid)
local Simulation = require(ReplicatedStorage.Shared.Sim.Simulation)
local Circuits = require(ReplicatedStorage.Shared.Rules.Circuits)
local Ui = require(script.Parent.Parent.View.Ui)
local Theme = require(script.Parent.Parent.View.Theme)
local Modal = require(script.Parent.Parent.UI.Modal)
local Store = require(script.Parent.Parent.UI.Store)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local BoardTransform = require(script.Parent.Parent.View.BoardTransform)
local BoardRenderer = require(script.Parent.Parent.View.BoardRenderer)
local Hud = require(script.Parent.Parent.View.Hud)
local MatchController = require(script.Parent.MatchController)
local InputController = require(script.Parent.InputController)
local Responsive = require(script.Parent.Parent.View.Responsive)
local SettingsController = require(script.Parent.SettingsController)
local AudioController = require(script.Parent.AudioController)

local PlayController = {}

local L = Localization.get

local root: Frame
local hud: Hud.Hud
local transform: BoardTransform.BoardTransform
local renderer: BoardRenderer.Renderer
local active = false
local buildTowerId: string? = nil
local buildCell: Types.Cell? = nil
local selectedTowerId: number? = nil
local onLeftCallback: (() -> ())? = nil
local onResultCallback: ((any) -> ())? = nil
local pendingCommand = false
local pulseModal: Modal.Controls? = nil
local leaveModal: Modal.Controls? = nil
local currentLoadout: { string } = {}
local hudCallbacks: Hud.Callbacks
local lastBossBannerAt = 0

local function toastError(code: string?)
	Toasts.error(code)
	AudioController.play("ui_error")
end

-- Enquanto a reconciliação está em andamento, novas mutações ficam bloqueadas (guia, tela 26).
local function canMutate(): boolean
	if Store.canMutate() then
		return true
	end
	Toasts.show(L("connection.blocked"), "error", "connection:blocked")
	return false
end

-- ---------------------------------------------------------------------------
-- Construção
-- ---------------------------------------------------------------------------

local function validCells(): { Types.Cell }
	local view = MatchController.current()
	if not view then
		return {}
	end
	local map = Catalog.getMap(view.snapshot.mapId)
	if not map then
		return {}
	end
	local path = Simulation.getPath(view.snapshot.mapId)
	local blocked = Simulation.getBlocked(view.snapshot.mapId)
	local cells = {}
	for x = 0, Grid.COLUMNS - 1 do
		for y = 0, Grid.ROWS - 1 do
			if
				not path.cellSet[Grid.cellKey(x, y)]
				and not blocked[Grid.cellKey(x, y)]
				and not MatchController.towerAt(x, y)
			then
				table.insert(cells, { x, y })
			end
		end
	end
	return cells
end

local function evaluateCell(towerId: string, x: number, y: number): (boolean, string?, number?, string?)
	local view = MatchController.current()
	if not view then
		return false, "build.invalidCell", nil, nil
	end
	local snapshot = view.snapshot
	local def = Catalog.getTower(towerId)
	if not def then
		return false, "build.invalidCell", nil, nil
	end
	if not Grid.inBounds(x, y) then
		return false, "build.invalidCell", nil, nil
	end
	local path = Simulation.getPath(snapshot.mapId)
	if path.cellSet[Grid.cellKey(x, y)] then
		return false, "build.onPath", nil, nil
	end
	if Simulation.getBlocked(snapshot.mapId)[Grid.cellKey(x, y)] then
		return false, "build.blocked", nil, nil
	end
	if MatchController.towerAt(x, y) then
		return false, "build.occupied", nil, nil
	end
	if
		MatchController.myTowerCount() >= snapshot.limits.perPlayer
		or MatchController.myTowerCountOf(towerId) >= def.perPlayerLimit
	then
		return false, "build.limit", nil, nil
	end
	local cost = def.states.L0.cost
	if snapshot.mode ~= "training" and snapshot.wallet < cost then
		return false, "build.noFunds", nil, nil
	end
	-- prévia de Circuito com a mesma regra determinística do servidor
	local towers: { Types.Tower } = {}
	for id, t in pairs(view.towers) do
		table.insert(towers, {
			id = id,
			ownerUserId = t.o,
			defId = t.d,
			state = t.st :: any,
			x = t.x,
			y = t.y,
			cooldown = 0,
			targetMode = "first",
			invested = t.inv,
			placedAt = 0,
			circuitPartnerId = nil,
			circuitId = nil,
			dustUntil = 0,
			attackSeq = 0,
			activeSeconds = 0,
		})
	end
	local hypothetical: Types.Tower = {
		id = 2 ^ 40,
		ownerUserId = MatchController.localUserId,
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
	local circuitText: string? = nil
	if preview then
		local partner = view.towers[preview.partnerId]
		local partnerName = if partner then (Catalog.getTower(partner.d) :: Types.TowerDef).name else "?"
		circuitText = L("build.circuitPreview", { name = L("circuit." .. preview.circuitId), partner = partnerName })
	end
	return true, nil, preview and preview.partnerId or nil, circuitText
end

local function refreshBuildPreview()
	if not buildTowerId then
		renderer:setBuildPreview(nil)
		hud:setBuildMode(nil, nil, false, nil, nil, nil)
		return
	end
	local towerId = buildTowerId :: string
	local def = Catalog.getTower(towerId) :: Types.TowerDef
	local cells = validCells()
	if buildCell then
		local cell = buildCell :: Types.Cell
		local valid, reason, partnerId, circuitText = evaluateCell(towerId, cell[1], cell[2])
		renderer:setBuildPreview({
			towerId = towerId,
			x = cell[1],
			y = cell[2],
			valid = valid,
			reason = reason,
			partnerId = partnerId,
			circuitId = nil,
			validCells = cells,
		})
		hud:setBuildMode(towerId, cell, valid, reason, def.states.L0.cost, circuitText)
	else
		renderer:setBuildPreview({
			towerId = towerId,
			x = nil,
			y = nil,
			valid = false,
			reason = nil,
			partnerId = nil,
			circuitId = nil,
			validCells = cells,
		})
		hud:setBuildMode(towerId, nil, false, nil, def.states.L0.cost, nil)
	end
end

local function exitBuild()
	buildTowerId = nil
	buildCell = nil
	refreshBuildPreview()
end

local function enterBuild(towerId: string)
	local view = MatchController.current()
	if not view then
		return
	end
	if not table.find(view.snapshot.participants and PlayController.loadout() or {}, towerId) then
		return
	end
	selectedTowerId = nil
	renderer:setSelected(nil)
	hud:showTowerDetail(nil)
	buildTowerId = towerId
	buildCell = nil
	-- tutorial: célula guiada já sugerida
	if view.snapshot.mode == "tutorial" then
		local guided = Balance.tutorial.guidedCells[towerId]
		if
			guided
			and ((view.tutorialStep == 1 and towerId == "dardo") or (view.tutorialStep == 3 and towerId == "goma"))
		then
			buildCell = { guided[1], guided[2] }
		end
	end
	refreshBuildPreview()
	AudioController.play("ui_open")
end

local PENDING_TIMEOUT = 8

local function setPending(value: boolean)
	pendingCommand = value
	root:SetAttribute("pendingCommand", value)
end

local function confirmBuild()
	root:SetAttribute("confirmAttempt", ((root:GetAttribute("confirmAttempt") :: any) or 0) + 1)
	if not buildTowerId or not buildCell or pendingCommand then
		root:SetAttribute(
			"confirmSkipped",
			string.format(
				"tower=%s cell=%s pending=%s",
				tostring(buildTowerId),
				tostring(buildCell and (buildCell[1] .. "," .. buildCell[2])),
				tostring(pendingCommand)
			)
		)
		return
	end
	local towerId = buildTowerId :: string
	local cell = buildCell :: Types.Cell
	local valid = evaluateCell(towerId, cell[1], cell[2])
	if not valid then
		return
	end
	setPending(true)
	hud.buildConfirm:setEnabled(false, "…")
	local attempt = root:GetAttribute("confirmAttempt")
	-- rede lenta: libera o botão após o tempo limite (o servidor deduplica por célula ocupada)
	task.delay(PENDING_TIMEOUT, function()
		if pendingCommand and root:GetAttribute("confirmAttempt") == attempt then
			setPending(false)
			toastError("RATE_LIMIT")
			refreshBuildPreview()
		end
	end)
	MatchController.command("PlaceTower", { towerId = towerId, x = cell[1], y = cell[2] }, function(response)
		root:SetAttribute("lastPlaceResponse", tostring(response.ok) .. "/" .. tostring(response.errorCode))
		setPending(false)
		if response.ok then
			AudioController.play("ui_confirm")
			exitBuild()
			if transform:isZoomed() and Responsive.isCompact() then
				transform:reset(true)
			end
		else
			toastError(response.errorCode)
			if response.hint then
				Ui.toast(root, L(response.hint), false)
			end
			refreshBuildPreview()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Seleção
-- ---------------------------------------------------------------------------

local function selectTower(id: number?)
	selectedTowerId = id
	renderer:setSelected(id)
	hud:showTowerDetail(id)
	if id then
		AudioController.play("ui_click")
	end
end

-- No tutorial, a torre guiada fica travada na célula marcada
local function guidedCellFor(towerId: string): Types.Cell?
	local view = MatchController.current()
	if not view or view.snapshot.mode ~= "tutorial" then
		return nil
	end
	if (view.tutorialStep == 1 and towerId == "dardo") or (view.tutorialStep == 3 and towerId == "goma") then
		local guided = Balance.tutorial.guidedCells[towerId]
		return if guided then { guided[1], guided[2] } else nil
	end
	return nil
end

local function onTap(screen: Vector2)
	local view = MatchController.current()
	if not view then
		return
	end
	if hud:isPointOverChrome(screen) then
		return
	end
	local x, y = transform:screenToCell(screen)
	if buildTowerId then
		local guided = guidedCellFor(buildTowerId :: string)
		if guided then
			if x == guided[1] and y == guided[2] and not InputController.isTouchDevice() then
				confirmBuild()
			end
			return
		end
		if x ~= nil and y ~= nil then
			if buildCell and buildCell[1] == x and buildCell[2] == y and not InputController.isTouchDevice() then
				confirmBuild() -- segundo clique na mesma célula confirma no computador
			else
				buildCell = { x, y }
				refreshBuildPreview()
				transform:zoomToCellIfSmall(x, y)
			end
		end
		return
	end
	if x == nil or y == nil then
		if transform:isInsideWindow(screen) then
			selectTower(nil)
			hud:showEnemyDetail(nil)
		end
		return
	end
	local tower = MatchController.towerAt(x, y)
	if tower then
		selectTower(tower.id)
		return
	end
	local px, py = transform:screenToLogical(screen)
	local enemyId = renderer:nearestEnemy(px, py, 0.6)
	if enemyId then
		selectedTowerId = nil
		renderer:setSelected(nil)
		hud:showEnemyDetail(enemyId)
		return
	end
	selectTower(nil)
	hud:showEnemyDetail(nil)
end

local function onHover(screen: Vector2?)
	if not buildTowerId or not screen or InputController.isTouchDevice() then
		return
	end
	if guidedCellFor(buildTowerId :: string) or hud:isPointOverChrome(screen) then
		return
	end
	local x, y = transform:screenToCell(screen)
	if x ~= nil and y ~= nil then
		if not buildCell or buildCell[1] ~= x or buildCell[2] ~= y then
			buildCell = { x, y }
			refreshBuildPreview()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Eventos de partida
-- ---------------------------------------------------------------------------

function PlayController.loadout(): { string }
	local view = MatchController.current()
	if not view then
		return {}
	end
	-- a equipe do jogador é a lista de cartas do HUD (definida ao entrar)
	local ids = {}
	for id in pairs(hud.towerCards) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return hud.towerCards[a].instance.LayoutOrder < hud.towerCards[b].instance.LayoutOrder
	end)
	return ids
end

local function applySettings(settings: Types.ProfileSettings)
	renderer.reducedMotion = settings.reducedMotion
	renderer.reducedParticles = settings.reducedParticles
	renderer.damageNumbers = settings.damageNumbers
	renderer:setCircuitPattern(settings.circuitPattern)
end

local function handleEvents(view: MatchController.MatchView, events: { Types.NetEvent })
	for _, e in ipairs(events) do
		if e.kind == "waveStart" then
			AudioController.play("wave_start")
			hud:setBossBanner(nil)
		elseif e.kind == "bossSpawn" and e.enemyDefId then
			hud:setBossBanner(L("hud.bossIncoming", { name = L("enemy." .. e.enemyDefId) }))
			AudioController.play("boss_spawn", true)
			lastBossBannerAt = os.clock()
		elseif e.kind == "bossTelegraph" and e.enemyDefId then
			hud:setBossBanner(
				L(
					"boss.telegraph",
					{ name = L("enemy." .. e.enemyDefId), ability = L("boss." .. e.enemyDefId .. ".ability") }
				)
			)
			AudioController.play("boss_telegraph", true)
			lastBossBannerAt = os.clock()
		elseif e.kind == "bossAbility" then
			AudioController.play("boss_ability", true)
			task.delay(2, function()
				if os.clock() - lastBossBannerAt >= 2 then
					hud:setBossBanner(nil)
				end
			end)
		elseif e.kind == "leak" then
			AudioController.play("base_hit")
		elseif e.kind == "speedChanged" and e.reason == "overload" then
			Ui.toast(root, L("hud.speedOverload"), true)
		elseif e.kind == "pulse" then
			AudioController.play("base_pulse", true)
			hud:disarmPulse()
			-- aliado usou enquanto a confirmação estava aberta: fecha e informa quem usou
			if pulseModal then
				(pulseModal :: Modal.Controls):close()
				pulseModal = nil
				local who = if e.userId then MatchController.participantName(e.userId) else nil
				Toasts.show(
					if who then L("hud.pulseUsedBy", { name = who }) else L("hud.pulseUsed"),
					"info",
					"pulse:used"
				)
			end
		elseif e.kind == "circuitChanged" and e.circuitId and e.towerId then
			local t = view.towers[e.towerId :: number]
			if t and t.o == MatchController.localUserId then
				Ui.toast(root, L("circuit." .. (e.circuitId :: string)) .. " ✓")
			end
		elseif e.kind == "towerSold" and selectedTowerId == e.towerId then
			selectTower(nil)
		end
	end
end

local function onFrame(view: MatchController.MatchView, events: { Types.NetEvent })
	if not active then
		return
	end
	renderer:applyFrame(view, events)
	handleEvents(view, events)
	hud:update(view, view.snapshot.wallet, MatchController.myTowerCount(), Responsive.isCompact())
	if buildTowerId then
		refreshBuildPreview()
	end
	hud:setZoomVisible(transform:isZoomed())
end

local function onStart(view: MatchController.MatchView, extra: any)
	active = true
	root.Visible = true
	buildTowerId = nil
	buildCell = nil
	selectedTowerId = nil
	transform:reset(false)
	renderer:setMap(view.snapshot.mapId)
	local loadout: { string } = {}
	local myLoadout = PlayController.pendingLoadout
	if view.snapshot.trainingUnlockAll then
		for _, t in ipairs(Balance.towers) do
			table.insert(loadout, t.id)
		end
	elseif view.snapshot.mode == "tutorial" then
		loadout = Catalog.starterTowerIds()
	else
		loadout = myLoadout
	end
	currentLoadout = loadout
	hud:setLoadout(loadout)
	hud:showTowerDetail(nil)
	hud:setBossBanner(nil)
	hud:setTutorialStep(if view.snapshot.mode == "tutorial" then view.tutorialStep else nil, false)
	renderer:setSelected(nil)
	renderer:setBuildPreview(nil)
	applySettings(SettingsController.get())
	InputController.setEnabled(true)
	AudioController.music("music_" .. view.snapshot.mapId)
	renderer:applyFrame(view, {})
	hud:update(view, view.snapshot.wallet, MatchController.myTowerCount(), Responsive.isCompact())
	-- tutorial: as etapas guiadas já abrem o posicionamento na célula marcada
	if view.snapshot.mode == "tutorial" and (view.tutorialStep == 1 or view.tutorialStep == 3) then
		local guidedTower = if view.tutorialStep == 1 then "dardo" else "goma"
		task.defer(function()
			if active and buildTowerId == nil then
				enterBuild(guidedTower)
			end
		end)
	end
end

local function onLeft()
	active = false
	root.Visible = false
	InputController.setEnabled(false)
	exitBuild()
	renderer:setSelected(nil)
	AudioController.music("music_menu")
	if onLeftCallback then
		onLeftCallback()
	end
end

local function onTutorial(step: number, retry: boolean)
	hud:setTutorialStep(step, retry)
	if step == 1 or step == 3 then
		local towerId = if step == 1 then "dardo" else "goma"
		task.defer(function()
			if active and buildTowerId ~= towerId then
				enterBuild(towerId)
			end
		end)
	end
	if step == 6 then
		AudioController.play("result_win", true)
	end
end

-- ---------------------------------------------------------------------------
-- Inicialização
-- ---------------------------------------------------------------------------

PlayController.pendingLoadout = {} :: { string }

function PlayController.init(
	parent: GuiObject,
	callbacks: { onLeft: () -> (), onResult: (any) -> (), onOpenSettings: () -> () }
)
	onLeftCallback = callbacks.onLeft
	onResultCallback = callbacks.onResult
	root = Ui.frame(
		parent,
		"PlayScreen",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.backdrop, Visible = false }
	)
	local mobile = Responsive.isCompact()
	hudCallbacks = {
		onPickTower = function(towerId)
			if buildTowerId == towerId then
				exitBuild()
			else
				enterBuild(towerId)
			end
		end,
		onConfirmBuild = confirmBuild,
		onCancelBuild = exitBuild,
		onPulse = function()
			local view = MatchController.current()
			if not view or not canMutate() then
				return
			end
			if pulseModal then
				return -- uma confirmação por vez
			end
			local damage = math.floor(
				Balance.pulse.damage * (1 + Balance.coopAdditionalHPPerPlayer * (#view.snapshot.participants - 1)) + 0.5
			)
			pulseModal = Modal.open(root, {
				title = L("hud.pulse"),
				body = L("hud.pulseSummary", {
					damage = damage,
					slow = math.floor(Balance.pulse.slow * 100 + 0.5),
					duration = Ui.formatDecimal(Balance.pulse.slowDuration, 1),
					cooldown = Balance.pulse.cooldown,
				}),
				confirmText = L("hud.pulseUse"),
				opener = hud.pulseButton.instance,
				onConfirm = function(controls)
					controls:setPending(true)
					MatchController.command("CastPulse", {}, function(response)
						pulseModal = nil
						controls:close()
						if not response.ok then
							toastError(response.errorCode)
						end
					end)
				end,
				onCancel = function()
					pulseModal = nil
				end,
			})
		end,
		onSpeedVote = function(value: number)
			MatchController.command("VoteSpeed", { value = value }, function(response)
				if not response.ok then
					toastError(response.errorCode)
				end
			end)
		end,
		onReady = function()
			local view = MatchController.current()
			if not view then
				return
			end
			local ready = false
			for _, p in ipairs(view.snapshot.participants) do
				if p.userId == MatchController.localUserId then
					ready = p.ready
				end
			end
			MatchController.command("SetReady", { ready = not ready }, function(response)
				if not response.ok then
					toastError(response.errorCode)
				end
			end)
		end,
		onLeave = function()
			if leaveModal then
				return -- repetição bloqueada enquanto o pedido está pendente
			end
			leaveModal = Modal.open(root, {
				title = L("hud.leave"),
				body = L("hud.leaveConfirm"),
				confirmText = L("hud.leaveAction"),
				danger = true,
				opener = hud.optionsButton.instance,
				onConfirm = function(controls)
					controls:setPending(true)
					MatchController.command("LeaveMatch", {}, function()
						leaveModal = nil
						controls:close()
					end)
				end,
				onCancel = function()
					leaveModal = nil
				end,
			})
		end,
		onZoomReset = function()
			transform:reset(true)
		end,
		onUpgrade = function(entityId, nextState)
			MatchController.command("UpgradeTower", { entityId = entityId, nextState = nextState }, function(response)
				if response.ok then
					AudioController.play("ui_confirm")
					hud.detailDirty = true
				else
					toastError(response.errorCode)
				end
			end)
		end,
		onSell = function(entityId)
			MatchController.command("SellTower", { entityId = entityId }, function(response)
				if response.ok then
					selectTower(nil)
				else
					toastError(response.errorCode)
				end
			end)
		end,
		onTarget = function(entityId, mode)
			MatchController.command("SetTarget", { entityId = entityId, mode = mode }, function(response)
				if response.ok then
					hud.detailDirty = true
				else
					toastError(response.errorCode)
				end
			end)
		end,
		onCloseDetail = function()
			selectTower(nil)
			hud:showEnemyDetail(nil)
		end,
		onOpenSettings = callbacks.onOpenSettings,
		onTrainingSpawn = function(enemyId, count)
			MatchController.command("TrainingSpawn", { enemyId = enemyId, count = count }, function(response)
				if not response.ok then
					toastError(response.errorCode)
				end
			end)
		end,
		onTrainingClear = function()
			MatchController.command("TrainingClear", {}, nil)
		end,
		onToggleRanges = function(value)
			renderer:setShowRanges(value)
		end,
		onToggleCircuits = function(value)
			renderer:setShowCircuits(value)
		end,
		onTutorialNext = function()
			local view = MatchController.current()
			if view and view.tutorialStep >= 6 then
				MatchController.command("LeaveMatch", {}, nil)
			else
				hud:hideTutorial()
			end
		end,
		onTutorialSkip = function()
			Ui.confirm(
				root,
				L("tutorial.skip"),
				L("tutorial.skipConfirm"),
				L("tutorial.skip"),
				L("common.cancel"),
				true,
				function()
					MatchController.command("TutorialSkip", {}, nil)
				end
			)
		end,
	}
	hud = Hud.new(root, hudCallbacks, mobile)
	transform = BoardTransform.new(hud.boardArea)
	renderer = BoardRenderer.new(transform)
	InputController.init(transform, {
		onTap = onTap,
		onHover = onHover,
		onPickSlot = function(slot)
			local ids = PlayController.loadout()
			local id = ids[slot]
			if id and active then
				if buildTowerId == id then
					exitBuild()
				else
					enterBuild(id)
				end
			end
		end,
		onCancel = function()
			if buildTowerId then
				exitBuild()
			else
				selectTower(nil)
				hud:showEnemyDetail(nil)
			end
		end,
		onUpgradeKey = function()
			local view = MatchController.current()
			if not view or not selectedTowerId then
				return
			end
			local tower = view.towers[selectedTowerId :: number]
			if tower and tower.o == MatchController.localUserId then
				local nexts = Catalog.TRANSITIONS[tower.st] or {}
				if #nexts == 1 then
					MatchController.command(
						"UpgradeTower",
						{ entityId = tower.id, nextState = nexts[1] },
						function(response)
							if not response.ok then
								toastError(response.errorCode)
							end
						end
					)
				end
			end
		end,
	})
	SettingsController.onChanged(function(settings)
		if renderer then
			applySettings(settings)
		end
	end)
	MatchController.on("start", onStart)
	MatchController.on("frame", onFrame)
	MatchController.on("left", onLeft)
	MatchController.on("tutorial", onTutorial)
	MatchController.on("result", function(payload)
		if onResultCallback then
			onResultCallback(payload)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if active then
			renderer:update(dt)
		end
	end)
end

-- Reconstrói o HUD do zero (troca de modo de layout ou de idioma) preservando seleção e estado.
local function rebuildHud(mobile: boolean)
	local old = hud
	hud = Hud.new(root, hudCallbacks, mobile)
	transform.viewport.Parent = hud.boardArea
	hud:setLoadout(currentLoadout)
	old:destroy()
	local view = MatchController.current()
	if view and active then
		hud:setTutorialStep(if view.snapshot.mode == "tutorial" then view.tutorialStep else nil, false)
		hud:showTowerDetail(selectedTowerId)
		refreshBuildPreview()
		hud:update(view, view.snapshot.wallet, MatchController.myTowerCount(), mobile)
	end
end

-- Reconstrói o HUD quando o modo de layout muda (redimensionamento/rotação) e reajusta larguras
function PlayController.relayout()
	if not hud then
		return
	end
	local mobile = Responsive.isCompact()
	if hud.mobile == mobile then
		hud:refit()
		return
	end
	rebuildHud(mobile)
end

-- Trocar o idioma reescreve rótulos fixos do HUD (legendas, atalhos, painéis contextuais).
function PlayController.rebuildForLocale()
	if not hud then
		return
	end
	rebuildHud(Responsive.isCompact())
end

function PlayController.isActive(): boolean
	return active
end

return PlayController
