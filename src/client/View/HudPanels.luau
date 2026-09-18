--!strict
-- Painéis contextuais do combate: barra de chefe (19/41), menu de alvo (45), popover de
-- velocidade (31/40), menu de Opções com grupo e saída (13/27) e aviso de conexão (26/42).
--
-- Todos são camadas locais acima do HUD: no máximo um painel contextual aberto por vez, nenhum
-- deles pausa o mundo e nenhum deixa o toque atravessar para o tabuleiro.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.UI.Components)
local Focus = require(script.Parent.Parent.UI.Focus)
local MatchController = require(script.Parent.Parent.Controllers.MatchController)
local Theme = require(script.Parent.Theme)

local HudPanels = {}

local L = Localization.get

-- ---------------------------------------------------------------------------
-- BossBar (19 e 41)
-- ---------------------------------------------------------------------------

export type BossBar = {
	frame: Frame,
	update: (self: BossBar, view: MatchController.MatchView, simTime: number) -> (),
	destroy: (self: BossBar) -> (),
}

function HudPanels.bossBar(parent: Instance, mobile: boolean): BossBar
	local frame = Components.panel(parent, "BossBar", {
		Size = if mobile then UDim2.new(0, 300, 0, 56) else UDim2.new(0, 420, 0, 66),
		Position = if mobile then UDim2.new(0.5, 0, 0, 40) else UDim2.new(0.5, 0, 0, 84),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.colors.surface,
		Visible = false,
		ZIndex = 6,
	}, { shadow = false })
	frame.Active = false -- informativo: não intercepta o toque do tabuleiro
	Components.padding(frame, 12, 8)

	local nameLabel = Components.label(frame, "Name", "", {
		Size = UDim2.new(1, -90, 0, 20),
		Font = Theme.fonts.bodyBold,
		TextSize = if mobile then 13 else Theme.sizes.body,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
	})
	local hpLabel = Components.label(frame, "Hp", "", {
		Size = UDim2.fromOffset(90, 20),
		Position = UDim2.new(1, -90, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.fonts.numbers,
		TextSize = if mobile then 12 else Theme.sizes.caption,
		TextWrapped = false,
		ZIndex = 7,
	})
	local bar = Components.progressBar(frame, "Bar", {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.fromOffset(0, 22),
		ZIndex = 7,
	}, Theme.colors.enemy)
	Components.stroke(bar.instance, Theme.colors.ink, 2)
	-- aviso e efeito ativo são estados sucessivos: ícone + texto + contagem, sem flash de tela
	local stateRow = Components.frame(frame, "State", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 36),
		BackgroundTransparency = 1,
		ZIndex = 7,
	})
	stateRow.Active = false
	Components.list(stateRow, Enum.FillDirection.Horizontal, 6)
	local iconHandle = Components.icon(stateRow, "ui_error", 16, { LayoutOrder = 1, ZIndex = 8 })
	local stateLabel = Components.label(stateRow, "Text", "", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = if mobile then 11 else Theme.sizes.caption,
		TextWrapped = false,
		Font = Theme.fonts.bodyMedium,
		LayoutOrder = 2,
		ZIndex = 8,
	})

	local self = {} :: BossBar
	self.frame = frame

	function self.update(_, view: MatchController.MatchView, simTime: number)
		-- só chefes realmente ativos; nunca três painéis comparativos
		local boss: MatchController.EnemyView? = nil
		for _, enemy in pairs(view.enemies) do
			if enemy.isBoss and not enemy.isSummon then
				boss = enemy
				break
			end
		end
		if not boss then
			frame.Visible = false
			return
		end
		local live = boss :: MatchController.EnemyView
		frame.Visible = true
		nameLabel.Text = L("enemy." .. live.defId)
		hpLabel.Text = string.format("%d / %d", math.max(math.floor(live.hp + 0.5), 0), live.maxHp)
		bar:setProgress(live.hp / math.max(live.maxHp, 1), false)
		local abilityKey = "boss." .. live.defId .. ".ability"
		if live.telegraphing then
			-- a contagem deriva de readyAt/telegraphAt em simTime do servidor, nunca de tween
			local remaining = if live.telegraphAt then math.max(0, math.ceil(live.telegraphAt - simTime)) else 0
			stateLabel.Text = L("boss.telegraphCountdown", {
				ability = if Localization.has(abilityKey) then L(abilityKey) else "",
				seconds = remaining,
			})
			stateLabel.TextColor3 = Theme.colors.danger
			if iconHandle then
				iconHandle:setColor(Theme.colors.danger)
			end
		elseif live.armorBonus > 0 then
			stateLabel.Text = L("boss.shieldActive", { value = math.floor(live.armor * 100 + 0.5) })
			stateLabel.TextColor3 = Theme.colors.goldDark
			if iconHandle then
				iconHandle:setColor(Theme.colors.goldDark)
			end
		else
			stateLabel.Text = if Localization.has(abilityKey) then L(abilityKey) else ""
			stateLabel.TextColor3 = Theme.colors.muted
			if iconHandle then
				iconHandle:setColor(Theme.colors.muted)
			end
		end
	end

	function self.destroy(_)
		frame:Destroy()
	end
	return self
end

-- ---------------------------------------------------------------------------
-- Menu de alvo (45): quatro opções, fecha ao escolher ou ao tocar fora
-- ---------------------------------------------------------------------------

export type TargetMenu = {
	open: (self: TargetMenu, anchor: GuiObject, current: string, onSelect: (mode: string) -> ()) -> (),
	close: (self: TargetMenu) -> (),
	isOpen: (self: TargetMenu) -> boolean,
}

function HudPanels.targetMenu(parent: Instance): TargetMenu
	local scrim = Components.frame(parent, "TargetScrim", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 14,
	})
	scrim.Active = true -- tocar fora fecha, e o toque não atravessa para o tabuleiro
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Outside"
	closeButton.Text = ""
	closeButton.BackgroundTransparency = 1
	closeButton.Size = UDim2.fromScale(1, 1)
	closeButton.AutoButtonColor = false
	closeButton.Selectable = false
	closeButton.ZIndex = 14
	closeButton.Parent = scrim

	local panel = Components.panel(scrim, "Panel", {
		Size = UDim2.fromOffset(260, 4 * (Theme.sizes.buttonTarget + 6) + 16),
		ZIndex = 15,
	}, { shadow = false })
	Components.padding(panel, 8, 8)
	Components.list(panel, Enum.FillDirection.Vertical, 6)

	local buttons: { Components.Button } = {}
	local scope = "targetMenu"
	local isOpen = false
	local self = {} :: TargetMenu

	function self.close(_)
		if not isOpen then
			return
		end
		isOpen = false
		scrim.Visible = false
		for _, button in ipairs(buttons) do
			button:destroy()
		end
		table.clear(buttons)
		Focus.popScope(scope)
	end

	function self.isOpen(_): boolean
		return isOpen
	end

	function self.open(_, anchor: GuiObject, current: string, onSelect: (mode: string) -> ())
		self:close()
		isOpen = true
		scrim.Visible = true
		-- posiciona junto do botão que abriu, sem sair da tela
		local anchorPosition = anchor.AbsolutePosition
		local parentPosition = (parent :: GuiObject).AbsolutePosition
		local parentSize = (parent :: GuiObject).AbsoluteSize
		local x = math.clamp(anchorPosition.X - parentPosition.X, 8, math.max(parentSize.X - 268, 8))
		local y = math.clamp(anchorPosition.Y - parentPosition.Y - panel.AbsoluteSize.Y - 8, 8, parentSize.Y - 8)
		panel.Position = UDim2.fromOffset(x, y)
		Focus.pushScope(scope, if anchor:IsA("GuiButton") then anchor else nil, function()
			self:close()
		end)
		for index, mode in ipairs(Catalog.TARGET_MODES) do
			local button = Components.button(panel, {
				name = mode,
				text = L("target." .. mode),
				kind = "secondary",
				size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
				layoutOrder = index,
				textAlign = Enum.TextXAlignment.Left,
				zIndex = 16,
				focusScope = scope,
				onActivate = function()
					-- selecionar o modo atual é idempotente: fecha sem mandar comando
					if mode ~= current then
						onSelect(mode)
					end
					self:close()
				end,
			})
			button:setSelected(mode == current)
			table.insert(buttons, button)
		end
		if #buttons > 0 then
			Focus.set(buttons[1].instance)
		end
	end

	closeButton.Activated:Connect(function()
		self:close()
	end)
	return self
end

-- ---------------------------------------------------------------------------
-- Popover de velocidade (31 e 40): votos, retorno a 1x e quem falta
-- ---------------------------------------------------------------------------

export type SpeedPopover = {
	toggle: (
		self: SpeedPopover,
		anchor: GuiObject,
		view: MatchController.MatchView,
		onVote: (value: number) -> ()
	) -> (),
	close: (self: SpeedPopover) -> (),
	isOpen: (self: SpeedPopover) -> boolean,
}

function HudPanels.speedPopover(parent: Instance): SpeedPopover
	local scrim = Components.frame(parent, "SpeedScrim", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 14,
	})
	scrim.Active = true
	local outside = Instance.new("TextButton")
	outside.Name = "Outside"
	outside.Text = ""
	outside.BackgroundTransparency = 1
	outside.Size = UDim2.fromScale(1, 1)
	outside.AutoButtonColor = false
	outside.Selectable = false
	outside.ZIndex = 14
	outside.Parent = scrim

	local panel = Components.panel(scrim, "Panel", {
		Size = UDim2.fromOffset(300, 190),
		ZIndex = 15,
	}, { shadow = false })
	Components.padding(panel, 12, 10)

	local votesLabel = Components.label(panel, "Votes", "", {
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.fonts.bodyBold,
		ZIndex = 16,
	})
	local missingLabel = Components.caption(panel, "Missing", "", {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 26),
		ZIndex = 16,
	})

	local buttons: { Components.Button } = {}
	local scope = "speedPopover"
	local isOpen = false
	local self = {} :: SpeedPopover

	function self.close(_)
		if not isOpen then
			return
		end
		isOpen = false
		scrim.Visible = false
		for _, button in ipairs(buttons) do
			button:destroy()
		end
		table.clear(buttons)
		Focus.popScope(scope)
	end

	function self.isOpen(_): boolean
		return isOpen
	end

	function self.toggle(_, anchor: GuiObject, view: MatchController.MatchView, onVote: (value: number) -> ())
		if isOpen then
			self:close()
			return
		end
		isOpen = true
		scrim.Visible = true
		local snapshot = view.snapshot
		local votes, active = 0, 0
		local missing: { string } = {}
		local myVote = 1
		for _, participant in ipairs(snapshot.participants) do
			if participant.connected then
				active += 1
				if participant.speedVote == 2 then
					votes += 1
				else
					table.insert(missing, participant.name)
				end
			end
			if participant.userId == MatchController.localUserId then
				myVote = participant.speedVote
			end
		end
		votesLabel.Text = L("speed.votes", { votes = votes, total = active })
		-- 2x depende de unanimidade; qualquer participante volta para 1x sem votação
		missingLabel.Text = if snapshot.speedMultiplier == 2
			then L("speed.active")
			elseif #missing > 0 then L("speed.missing", { names = table.concat(missing, ", ") })
			else L("speed.ready")

		local anchorPosition = anchor.AbsolutePosition
		local parentPosition = (parent :: GuiObject).AbsolutePosition
		local parentSize = (parent :: GuiObject).AbsoluteSize
		local x = math.clamp(anchorPosition.X - parentPosition.X - 60, 8, math.max(parentSize.X - 308, 8))
		local y = math.clamp(anchorPosition.Y - parentPosition.Y - 198, 8, parentSize.Y - 8)
		panel.Position = UDim2.fromOffset(x, y)
		Focus.pushScope(scope, if anchor:IsA("GuiButton") then anchor else nil, function()
			self:close()
		end)

		local voteButton = Components.button(panel, {
			name = "Vote2x",
			text = if myVote == 2 then L("speed.cancelVote") else L("speed.vote2x"),
			kind = "primary",
			size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget * 2 + 8)),
			zIndex = 16,
			focusScope = scope,
			onActivate = function()
				onVote(if myVote == 2 then 1 else 2)
				self:close()
			end,
		})
		voteButton:setSelected(myVote == 2)
		table.insert(buttons, voteButton)
		local backButton = Components.button(panel, {
			name = "Back1x",
			text = L("speed.back1x"),
			kind = "secondary",
			size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			position = UDim2.new(0, 0, 1, -Theme.sizes.buttonTarget),
			zIndex = 16,
			focusScope = scope,
			onActivate = function()
				onVote(1)
				self:close()
			end,
		})
		if snapshot.speedMultiplier == 1 and myVote == 1 then
			backButton:setAvailable(false, L("speed.already1x"))
		end
		table.insert(buttons, backButton)
		Focus.set(voteButton.instance)
	end

	outside.Activated:Connect(function()
		self:close()
	end)
	return self
end

-- ---------------------------------------------------------------------------
-- Menu de Opções do combate (13 e 27): grupo em leitura, configurações e saída
-- ---------------------------------------------------------------------------

export type OptionsCallbacks = {
	onSettings: () -> (),
	onLeave: () -> (),
}

export type OptionsPanel = {
	toggle: (self: OptionsPanel, anchor: GuiObject, view: MatchController.MatchView) -> (),
	close: (self: OptionsPanel) -> (),
	isOpen: (self: OptionsPanel) -> boolean,
}

function HudPanels.optionsPanel(parent: Instance, callbacks: OptionsCallbacks): OptionsPanel
	local scrim = Components.frame(parent, "OptionsScrim", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 14,
	})
	scrim.Active = true
	local outside = Instance.new("TextButton")
	outside.Name = "Outside"
	outside.Text = ""
	outside.BackgroundTransparency = 1
	outside.Size = UDim2.fromScale(1, 1)
	outside.AutoButtonColor = false
	outside.Selectable = false
	outside.ZIndex = 14
	outside.Parent = scrim

	local panel = Components.panel(scrim, "Panel", {
		Size = UDim2.fromOffset(320, 330),
		Position = UDim2.new(1, -16, 0, 80),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 15,
	}, { tape = true, shadow = false })
	Components.padding(panel, 14, 12)

	Components.label(panel, "Title", string.upper(L("hud.options")), {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.caption,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.tealDark,
		ZIndex = 16,
	})
	-- grupo durante o combate é leitura: sem editar equipe e sem entrar em outra sala
	local members = Components.scroller(panel, "Members", {
		Size = UDim2.new(1, 0, 0, 150),
		Position = UDim2.fromOffset(0, 24),
		ZIndex = 16,
	})
	local membersLayout = Components.list(members, Enum.FillDirection.Vertical, 4)
	membersLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	Components.caption(panel, "ReadOnly", L("hud.groupReadOnly"), {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 178),
		ZIndex = 16,
	})

	local buttons: { Components.Button } = {}
	local scope = "optionsPanel"
	local isOpen = false
	local self = {} :: OptionsPanel

	function self.close(_)
		if not isOpen then
			return
		end
		isOpen = false
		scrim.Visible = false
		for _, button in ipairs(buttons) do
			button:destroy()
		end
		table.clear(buttons)
		Focus.popScope(scope)
	end

	function self.isOpen(_): boolean
		return isOpen
	end

	function self.toggle(_, anchor: GuiObject, view: MatchController.MatchView)
		if isOpen then
			self:close()
			return
		end
		isOpen = true
		scrim.Visible = true
		for _, child in ipairs(members:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for index, participant in ipairs(view.snapshot.participants) do
			local owner = Theme.owners[participant.color] or Theme.owners[1]
			Components.label(
				members,
				"P" .. participant.userId,
				string.format(
					"%s %s%s",
					owner.glyph,
					participant.name,
					if participant.connected then "" else "  ⌛ " .. L("hud.disconnected")
				),
				{
					Size = UDim2.new(1, 0, 0, 22),
					TextColor3 = if participant.connected then Theme.colors.ink else Theme.colors.muted,
					TextWrapped = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = index,
					ZIndex = 17,
				}
			)
		end
		Focus.pushScope(scope, if anchor:IsA("GuiButton") then anchor else nil, function()
			self:close()
		end)
		local settingsButton = Components.button(panel, {
			name = "Settings",
			text = L("menu.settings"),
			kind = "secondary",
			icon = "ui_settings",
			size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget * 2 + 8)),
			zIndex = 16,
			focusScope = scope,
			onActivate = function()
				self:close()
				callbacks.onSettings()
			end,
		})
		table.insert(buttons, settingsButton)
		local leaveButton = Components.button(panel, {
			name = "Leave",
			text = L("hud.leave"),
			kind = "danger",
			size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			position = UDim2.new(0, 0, 1, -Theme.sizes.buttonTarget),
			zIndex = 16,
			focusScope = scope,
			onActivate = function()
				self:close()
				callbacks.onLeave()
			end,
		})
		table.insert(buttons, leaveButton)
		Focus.set(settingsButton.instance)
	end

	outside.Activated:Connect(function()
		self:close()
	end)
	return self
end

-- ---------------------------------------------------------------------------
-- Aviso de conexão (26 e 42)
-- ---------------------------------------------------------------------------

export type ConnectionBanner = {
	setState: (self: ConnectionBanner, state: string) -> (),
}

function HudPanels.connectionBanner(parent: Instance): ConnectionBanner
	local frame = Components.panel(parent, "Connection", {
		Size = UDim2.fromOffset(10, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.colors.dangerSoft,
		Visible = false,
		ZIndex = 13,
	}, { radius = Theme.sizes.pillCorner, shadow = false, strokeColor = Theme.colors.danger })
	frame.Active = false
	Components.padding(frame, 14, 6)
	local label = Components.label(frame, "Text", "", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		TextColor3 = Theme.colors.danger,
		Font = Theme.fonts.bodyMedium,
		ZIndex = 14,
	})
	local self = {} :: ConnectionBanner
	function self.setState(_, state: string)
		if state == "ok" then
			frame.Visible = false
			return
		end
		frame.Visible = true
		-- o tabuleiro NÃO é apagado: o último estado continua, marcado como desatualizado
		label.Text = if state == "unstable" then L("connection.unstable") else L("connection.reconciling")
	end
	return self
end

-- ---------------------------------------------------------------------------
-- Comparação de especialização (17): dois caminhos, custo incremental e atributos
-- ---------------------------------------------------------------------------

-- Monta as linhas de comparação antes/depois de um estado para o modal de confirmação.
function HudPanels.compareStates(
	def: Types.TowerDef,
	from: Types.TowerStateStats,
	to: Types.TowerStateStats
): { string }
	local lines: { string } = {}
	local function compare(labelKey: string, before: number?, after: number?, suffix: string?)
		if before == nil or after == nil then
			return
		end
		local arrow = if after > before then "↑" elseif after < before then "↓" else "="
		table.insert(
			lines,
			string.format(
				"%s: %s → %s %s%s",
				L(labelKey),
				tostring(before),
				tostring(after),
				arrow,
				if suffix then " " .. suffix else ""
			)
		)
	end
	if def.damageType ~= "none" then
		compare("detail.statDamage", from.damage, to.damage)
		compare("detail.statInterval", from.interval, to.interval)
	end
	compare("detail.statRange", from.range, to.range)
	if from.slow or to.slow then
		compare("detail.statSlow", from.slow, to.slow)
	end
	if from.haste or to.haste then
		compare("detail.statHaste", from.haste, to.haste)
	end
	if from.splash or to.splash then
		compare("detail.statSplash", from.splash, to.splash)
	end
	if from.chains or to.chains then
		compare("detail.statChains", from.chains, to.chains)
	end
	return lines
end

-- Reembolso de venda a partir do investido confirmado pelo servidor.
function HudPanels.sellRefund(invested: number): number
	return math.floor(invested * Balance.sellRefund)
end

return HudPanels
