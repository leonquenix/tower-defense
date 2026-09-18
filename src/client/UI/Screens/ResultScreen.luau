--!strict
-- 23_vitoria, 24_derrota, 25_recompensa_pendente e 44_resultados_estados.
--
-- Contrato:
--  * Won/Lost vêm só do servidor; RewardPending impede apresentar o saldo como salvo;
--  * "Salvo" só aparece depois da confirmação durável (status "saved");
--  * enquanto não salvo, a tela mostra a variante 25 com "Verificar novamente" e espera progressiva;
--  * reconciliar preserva o matchId e não duplica saldo (mesmo requestId, servidor deduplica);
--  * um destaque por vez, com fila finita que se esvazia ao sair do resultado;
--  * derrota tem tom acolhedor: sem culpa, sem ranking de dano e sem oferta paga para continuar;
--  * Revanche marca prontidão e não bloqueia Voltar ao menu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Ui = require(script.Parent.Parent.Parent.View.Ui)
local Accessibility = require(script.Parent.Parent.Accessibility)
local Anim = require(script.Parent.Parent.Anim)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local MatchController = require(script.Parent.Parent.Parent.Controllers.MatchController)
local Store = require(script.Parent.Parent.Store)

local ResultScreen = {}
ResultScreen.__index = ResultScreen

local L = Localization.get

-- Espera progressiva da reconciliação automática (evita spam manual e rajada de pedidos).
local RECHECK_BACKOFF = { 3, 6, 12, 24, 45 }

export type Callbacks = {
	onRematch: (ready: boolean) -> (),
	onMenu: () -> (),
	onOpenCollection: () -> (),
	onOpenMaps: () -> (),
	onOpenMastery: (towerId: string) -> (),
}

type Highlight = { key: string, text: string, actionText: string?, action: (() -> ())? }

export type ResultScreen = typeof(setmetatable(
	{} :: {
		root: Frame,
		box: Frame,
		callbacks: Callbacks,
		content: ScrollingFrame,
		footer: Frame,
		buttons: { Components.Button },
		highlightFrame: Frame,
		payload: { [string]: any }?,
		rematchReady: boolean,
		rematchButton: Components.Button?,
		recheckButton: Components.Button?,
		highlights: { Highlight },
		highlightIndex: number,
		recheckStep: number,
		recheckToken: number,
		shownKeys: { [string]: boolean },
	},
	ResultScreen
))

function ResultScreen.new(parent: Instance, callbacks: Callbacks): ResultScreen
	local root = Components.frame(parent, "Result", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 10,
	})
	root.Active = true
	local box = Components.panel(root, "Box", {
		Size = UDim2.new(0.92, 0, 0.9, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 11,
	}, { tape = true, shadow = false })
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(660, 580)
	constraint.Parent = box
	Components.padding(box, 22, 20)

	local self = setmetatable({
		root = root,
		box = box,
		callbacks = callbacks,
		buttons = {},
		rematchReady = false,
		highlights = {},
		highlightIndex = 0,
		recheckStep = 0,
		recheckToken = 0,
		shownKeys = {},
	}, ResultScreen) :: any

	self.highlightFrame = Components.panel(box, "Highlight", {
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = Theme.colors.cream,
		Visible = false,
		ZIndex = 12,
	}, { shadow = false })
	Components.padding(self.highlightFrame, 14, 10)

	self.content = Components.scroller(box, "Content", {
		Size = UDim2.new(1, 0, 1, -(Theme.sizes.buttonTarget + 100)),
		Position = UDim2.fromOffset(0, 84),
		ZIndex = 12,
	})
	local layout = Components.list(self.content, Enum.FillDirection.Vertical, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	self.footer = Components.frame(box, "Footer", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 6),
		Position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget + 6)),
		BackgroundTransparency = 1,
		ZIndex = 12,
	})
	Components.list(self.footer, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	return self
end

-- ---------------------------------------------------------------------------
-- Destaques (44): um por vez, fila finita, sem repetir ao reprocessar o mesmo matchId
-- ---------------------------------------------------------------------------

local function queueHighlights(self: ResultScreen, payload: { [string]: any })
	table.clear(self.highlights)
	self.highlightIndex = 0
	local outcome = payload.outcome
	if not outcome then
		return
	end
	local matchId = tostring(payload.matchId or "")
	local function push(key: string, text: string, actionText: string?, action: (() -> ())?)
		local scoped = matchId .. "|" .. key
		if self.shownKeys[scoped] then
			return
		end
		self.shownKeys[scoped] = true
		table.insert(self.highlights, { key = key, text = text, actionText = actionText, action = action })
	end
	for _, key in ipairs(outcome.unlocked or {}) do
		local mapId, difficulty = tostring(key):match("^(%w+):(%w+)$")
		local map = if mapId then Catalog.getMap(mapId) else nil
		if map and difficulty then
			push(
				"unlock:" .. key,
				L("result.highlightUnlock", {
					map = map.name,
					difficulty = L("menu.difficulty." .. difficulty),
				}),
				L("result.seeMaps"),
				self.callbacks.onOpenMaps
			)
		end
	end
	for towerId, milestones in pairs(outcome.milestones or {}) do
		local def = Catalog.getTower(towerId)
		for _, milestone in ipairs(milestones) do
			push(
				"milestone:" .. towerId .. ":" .. tostring(milestone),
				L("result.highlightMilestone", {
					tower = if def then def.name else towerId,
					points = milestone,
				}),
				L("result.seeMastery"),
				function()
					self.callbacks.onOpenMastery(towerId)
				end
			)
		end
	end
	local view = MatchController.current()
	if view and view.snapshot.mode == "tutorial" and outcome.status == "saved" then
		push("tutorial", L("result.highlightTutorial"), L("result.seeCollection"), self.callbacks.onOpenCollection)
	end
end

local function showNextHighlight(self: ResultScreen)
	for _, child in ipairs(self.highlightFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.highlightIndex += 1
	local highlight = self.highlights[self.highlightIndex]
	if not highlight then
		self.highlightFrame.Visible = false
		self.content.Size = UDim2.new(1, 0, 1, -(Theme.sizes.buttonTarget + 100))
		self.content.Position = UDim2.fromOffset(0, 84)
		return
	end
	self.highlightFrame.Visible = true
	Components.label(self.highlightFrame, "Text", "★ " .. highlight.text, {
		Size = UDim2.new(1, -220, 1, 0),
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.tealDark,
		ZIndex = 13,
	})
	local button = Components.button(self.highlightFrame, {
		name = "Action",
		text = highlight.actionText or L("common.ok"),
		kind = "secondary",
		size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
		position = UDim2.new(1, -200, 0.5, -24),
		zIndex = 13,
		onActivate = function()
			if highlight.action then
				highlight.action()
			else
				showNextHighlight(self)
			end
		end,
	})
	table.insert(self.buttons, button)
end

-- ---------------------------------------------------------------------------
-- Reconciliação da recompensa pendente (25)
-- ---------------------------------------------------------------------------

function ResultScreen.recheck(self: ResultScreen, manual: boolean)
	local button = self.recheckButton
	if button then
		button:setPending(true)
	end
	-- ClaimPending reconcilia os resultados realmente registrados no servidor.
	-- O matchId é preservado: repetir não duplica saldo.
	CommandAdapter.send("result:claim", "ClaimPending", {}, {
		onSuccess = function(response)
			if button then
				button:setPending(false)
			end
			if response.profile then
				Store.setProfile(response.profile)
			end
			local payload = self.payload
			if payload and payload.outcome and response.profile then
				local stillPending = (response.profile.pendingResults or 0) > 0
				if not stillPending then
					payload.outcome.status = "saved"
					Store.setPendingResult(nil)
					if button then
						button:flashSuccess(L("result.rewardSaved"))
					end
				end
			end
			ResultScreen.render(self)
			ResultScreen.scheduleRecheck(self)
		end,
		onError = function(code)
			if button then
				button:setPending(false)
				button:showError(if Localization.has("error." .. code) then L("error." .. code) else L("common.retry"))
			end
			ResultScreen.scheduleRecheck(self)
		end,
	})
	if manual then
		self.recheckStep = 0 -- um pedido manual reinicia a espera progressiva
	end
end

function ResultScreen.scheduleRecheck(self: ResultScreen)
	local payload = self.payload
	if not payload or not payload.outcome or payload.outcome.status ~= "pending" then
		return
	end
	self.recheckStep = math.min(self.recheckStep + 1, #RECHECK_BACKOFF)
	local delay = RECHECK_BACKOFF[self.recheckStep]
	self.recheckToken += 1
	local token = self.recheckToken
	task.delay(delay, function()
		if token ~= self.recheckToken or not self.root.Visible then
			return
		end
		ResultScreen.recheck(self, false)
	end)
end

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------

local function rewardBlock(self: ResultScreen, payload: { [string]: any }, order: number)
	local outcome = payload.outcome
	local status = if outcome then tostring(outcome.status) else "none"
	local buttons = if outcome then (outcome.buttons or 0) else 0
	local panel = Components.panel(self.content, "Reward", {
		Size = UDim2.new(1, 0, 0, 92),
		LayoutOrder = order,
		ZIndex = 13,
	}, { shadow = false })
	Components.padding(panel, 16, 12)
	local row = Components.frame(panel, "Row", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		ZIndex = 14,
	})
	Components.list(row, Enum.FillDirection.Horizontal, 8)
	Components.icon(row, "ui_buttons", 24, { LayoutOrder = 1, ZIndex = 15 })
	Components.label(row, "Value", "+" .. Ui.formatNumber(buttons), {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 28,
		Font = Theme.fonts.numbers,
		TextColor3 = Theme.colors.goldText,
		TextWrapped = false,
		LayoutOrder = 2,
		ZIndex = 15,
	})
	local statusText: string
	local statusColor = Theme.colors.tealDark
	if status == "saved" then
		statusText = L("result.rewardSaved")
	elseif status == "duplicate" then
		statusText = L("result.rewardAlreadySaved")
	elseif status == "pending" then
		statusText = L("result.rewardPending")
		statusColor = Theme.colors.coral
	elseif status == "unsaved" then
		statusText = L("app.progressNotSaved")
		statusColor = Theme.colors.danger
	elseif status == "unavailable" then
		-- resultado NÃO registrado: não prometer recuperação futura
		statusText = L("result.rewardNotRecorded")
		statusColor = Theme.colors.danger
	else
		statusText = L("result.noReward")
		statusColor = Theme.colors.muted
	end
	Components.label(panel, "Status", statusText, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 38),
		Font = Theme.fonts.bodyMedium,
		TextColor3 = statusColor,
		ZIndex = 14,
	})
	if status == "pending" then
		Components.caption(panel, "Explain", L("result.pendingExplain"), {
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 60),
			ZIndex = 14,
		})
	elseif status == "unavailable" then
		Components.caption(panel, "Explain", L("result.notRecordedExplain"), {
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 60),
			ZIndex = 14,
		})
	end
end

-- Dica ligada à causa observada; sem diagnóstico inventado e sem oferta paga.
local function lossHint(view: MatchController.MatchView?): string
	if not view then
		return L("result.hint.general")
	end
	local snapshot = view.snapshot
	local myTowers = MatchController.myTowerCount()
	if myTowers <= 2 then
		return L("result.hint.fewTowers")
	end
	local hasCircuit = false
	for _, tower in pairs(view.towers) do
		if tower.ci then
			hasCircuit = true
			break
		end
	end
	if not hasCircuit then
		return L("result.hint.noCircuit")
	end
	if snapshot.wallet >= 600 then
		return L("result.hint.savedScrap")
	end
	return L("result.hint.general")
end

function ResultScreen.render(self: ResultScreen)
	for _, button in ipairs(self.buttons) do
		button:destroy()
	end
	table.clear(self.buttons)
	for _, child in ipairs(self.content:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, child in ipairs(self.footer:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.rematchButton = nil
	self.recheckButton = nil

	local payload = self.payload
	if not payload then
		return
	end
	local view = MatchController.current()
	local result = payload.result :: Types.MatchResult?
	local outcome = payload.outcome
	local status = if outcome then tostring(outcome.status) else "none"
	local won = result ~= nil and result.outcome == "won"

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local titleKey = if won
		then "result.won"
		elseif result and result.outcome == "lost" then "result.lost"
		else "result.abandoned"
	Components.title(self.content, "Title", L(titleKey), {
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 32,
		TextColor3 = if won then Theme.colors.tealDark else Theme.colors.danger,
		LayoutOrder = nextOrder(),
		ZIndex = 13,
	})
	if result and view then
		local map = Catalog.getMap(view.snapshot.mapId)
		Components.label(
			self.content,
			"Summary",
			L("result.summary", {
				map = if map then map.name else view.snapshot.mapId,
				difficulty = L("menu.difficulty." .. view.snapshot.difficulty),
				waves = result.wavesCompleted,
				total = view.snapshot.totalWaves,
			}),
			{
				Size = UDim2.new(1, 0, 0, 24),
				Font = Theme.fonts.bodyMedium,
				LayoutOrder = nextOrder(),
				ZIndex = 13,
			}
		)
	end

	rewardBlock(self, payload, nextOrder())

	if not won and result and result.outcome == "lost" then
		local hint = Components.panel(self.content, "Hint", {
			Size = UDim2.new(1, 0, 0, 68),
			BackgroundColor3 = Theme.colors.cream,
			LayoutOrder = nextOrder(),
			ZIndex = 13,
		}, { shadow = false })
		Components.padding(hint, 14, 10)
		Components.label(hint, "Text", lossHint(view), {
			Size = UDim2.fromScale(1, 1),
			TextSize = Theme.sizes.body,
			ZIndex = 14,
		})
	end

	-- domínio ganho, só de torres elegíveis e com pontos reais
	if outcome and outcome.mastery then
		local lines = 0
		for towerId, points in pairs(outcome.mastery) do
			local def = Catalog.getTower(towerId)
			if def and points > 0 then
				lines += 1
				Components.label(
					self.content,
					"M_" .. towerId,
					L("result.mastery", { points = points, tower = def.name }),
					{
						Size = UDim2.new(1, 0, 0, 20),
						TextSize = Theme.sizes.caption,
						LayoutOrder = nextOrder(),
						ZIndex = 13,
					}
				)
			end
		end
		if lines == 0 and won then
			Components.caption(self.content, "NoMastery", L("result.noMastery"), {
				Size = UDim2.new(1, 0, 0, 20),
				LayoutOrder = nextOrder(),
				ZIndex = 13,
			})
		end
	end

	-- contribuição do grupo (sem ranking de dano na derrota: tom acolhedor)
	local stats = payload.stats
	if stats and view and #view.snapshot.participants > 1 and won then
		Components.label(self.content, "ContribTitle", Components.upper(L("result.contribution")), {
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = Theme.sizes.caption,
			Font = Theme.fonts.bodyBold,
			TextColor3 = Theme.colors.tealDark,
			LayoutOrder = nextOrder(),
			ZIndex = 13,
		})
		for _, participant in ipairs(view.snapshot.participants) do
			local entry = stats[participant.userId] or stats[tostring(participant.userId)]
			if entry then
				local owner = Theme.owners[participant.color] or Theme.owners[1]
				Components.label(
					self.content,
					"C_" .. participant.userId,
					string.format(
						"%s %s   %s · %s",
						owner.glyph,
						participant.name,
						L("result.damage", { value = Ui.formatNumber(entry.damage) }),
						L("result.support", { value = Ui.formatNumber(entry.supportBonusDamage) })
					),
					{
						Size = UDim2.new(1, 0, 0, 20),
						TextSize = Theme.sizes.caption,
						LayoutOrder = nextOrder(),
						ZIndex = 13,
					}
				)
			end
		end
	end

	-- rodapé
	local menu = Components.button(self.footer, {
		name = "Menu",
		text = L("result.menu"),
		kind = "secondary",
		size = UDim2.fromOffset(240, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		zIndex = 13,
		onActivate = self.callbacks.onMenu,
	})
	table.insert(self.buttons, menu)

	if status == "pending" or status == "unavailable" then
		local recheck = Components.button(self.footer, {
			name = "Recheck",
			text = L("result.recheck"),
			kind = "primary",
			size = UDim2.fromOffset(270, Theme.sizes.buttonTarget),
			layoutOrder = 2,
			zIndex = 13,
			onActivate = function()
				ResultScreen.recheck(self, true)
			end,
		})
		self.recheckButton = recheck
		table.insert(self.buttons, recheck)
		if status == "unavailable" then
			-- sem registro durável não há o que recuperar: o botão explica em vez de prometer
			recheck:setAvailable(true, L("result.recheckNoRecord"))
		end
	end

	local canRematch = view ~= nil and view.snapshot.mode ~= "tutorial" and status ~= "pending"
	if canRematch then
		local rematch = Components.button(self.footer, {
			name = "Rematch",
			text = if self.rematchReady then L("result.cancelRematch") else L("result.rematch"),
			kind = if self.rematchReady then "secondary" else "primary",
			size = UDim2.fromOffset(280, Theme.sizes.buttonTarget),
			layoutOrder = 3,
			zIndex = 13,
			onActivate = function()
				self.rematchReady = not self.rematchReady
				self.callbacks.onRematch(self.rematchReady)
				ResultScreen.render(self)
			end,
		})
		rematch:setSelected(self.rematchReady)
		self.rematchButton = rematch
		table.insert(self.buttons, rematch)
		local rematchState = if view then view.rematch else nil
		if rematchState and rematchState.total > 1 then
			rematch:setText(
				if self.rematchReady then L("result.cancelRematch") else L("result.rematch"),
				L("result.rematchWaiting", { ready = rematchState.ready, total = rematchState.total })
			)
		end
	end

	showNextHighlight(self)
end

function ResultScreen.setRematch(self: ResultScreen, ready: number, total: number)
	local button = self.rematchButton
	if button and total > 1 then
		button:setText(
			if self.rematchReady then L("result.cancelRematch") else L("result.rematch"),
			L("result.rematchWaiting", { ready = ready, total = total })
		)
	end
end

-- Celebração curta: até 12 partículas por 450 ms, desligada no movimento reduzido.
local function celebrate(self: ResultScreen)
	if Accessibility.reducedMotion() or Accessibility.get().reducedParticles then
		return
	end
	for index = 1, 12 do
		local dot = Components.frame(self.box, "Spark" .. index, {
			Size = UDim2.fromOffset(8, 8),
			Position = UDim2.fromScale(0.5, 0.35),
			BackgroundColor3 = if index % 2 == 0 then Theme.colors.gold else Theme.colors.teal,
			ZIndex = 20,
		})
		dot.Active = false
		Components.corner(dot, 999)
		local angle = (index / 12) * math.pi * 2
		Anim.play(dot, "result", {
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.34, 0.35 + math.sin(angle) * 0.26),
			BackgroundTransparency = 1,
		})
		task.delay(0.45, function()
			dot:Destroy()
		end)
	end
end

function ResultScreen.show(self: ResultScreen, payload: { [string]: any })
	local wasVisible = self.root.Visible
	self.payload = payload
	self.recheckStep = 0
	self.root.Visible = true
	local outcome = payload.outcome
	if outcome and outcome.status == "pending" then
		Store.setPendingResult({
			matchId = tostring(payload.matchId or ""),
			status = "pending",
			buttons = outcome.buttons,
		})
	end
	queueHighlights(self, payload)
	ResultScreen.render(self)
	if not wasVisible then
		if not Accessibility.reducedMotion() then
			local scale = self.box:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Parent = self.box
			scale.Scale = 0.96
			Anim.play(scale, "result", { Scale = 1 })
		end
		local result = payload.result :: Types.MatchResult?
		if result and result.outcome == "won" then
			celebrate(self)
		end
	end
	ResultScreen.scheduleRecheck(self)
end

function ResultScreen.hide(self: ResultScreen)
	self.recheckToken += 1
	self.root.Visible = false
	self.rematchReady = false
	self.rematchButton = nil
	self.recheckButton = nil
	self.payload = nil
	table.clear(self.highlights) -- a fila se esvazia ao sair do resultado
	self.highlightIndex = 0
end

function ResultScreen.isVisible(self: ResultScreen): boolean
	return self.root.Visible
end

return ResultScreen
