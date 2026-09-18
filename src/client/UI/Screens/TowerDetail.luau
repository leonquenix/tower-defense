--!strict
-- 07_torre e 32_desbloqueio: entender a função antes de gastar botões.
--
-- Contrato:
--  * custo de desbloqueio (botões) fica separado do custo de construção (sucata) — sem troca implícita;
--  * Desbloquear abre a confirmação 32 com preço, saldo atual e saldo projetado;
--  * possuída oferece Equipar, Aparência/Domínio e Experimentar no treino;
--  * atributos vêm do catálogo, com unidade e função; as especializações são comparação, não upgrade;
--  * saldo insuficiente informa "Faltam N botões" e nunca abre loja de Robux;
--  * já possuída é sucesso idempotente, sem novo débito.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Responsive = require(script.Parent.Parent.Parent.View.Responsive)
local Ui = require(script.Parent.Parent.Parent.View.Ui)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Chrome = require(script.Parent.Chrome)
local Modal = require(script.Parent.Parent.Modal)
local Store = require(script.Parent.Parent.Store)

local TowerDetail = {}
TowerDetail.__index = TowerDetail

local L = Localization.get

export type Callbacks = {
	onBack: () -> (),
	onEquip: (towerId: string) -> (),
	onCosmetics: (towerId: string) -> (),
	onTraining: (towerId: string) -> (),
	onUnlocked: (towerId: string) -> (),
}

export type TowerDetail = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		content: ScrollingFrame,
		footer: Frame,
		buttons: { Components.Button },
		towerId: string,
	},
	TowerDetail
))

-- Linhas de atributo com unidade e função, sempre a partir do catálogo real.
local function statLines(def: Types.TowerDef, stats: Types.TowerStateStats): { string }
	local lines: { string } = {}
	if def.damageType ~= "none" then
		table.insert(lines, L("detail.damage", { value = Ui.formatDecimal(stats.damage, 1) }))
		table.insert(lines, L("detail.interval", { value = Ui.formatDecimal(stats.interval, 2) }))
	end
	table.insert(lines, L("detail.range", { value = Ui.formatDecimal(stats.range, 1) }))
	if stats.haste then
		-- Maestro mostra bônus de cadência, não DPS zero
		table.insert(lines, L("detail.haste", { value = math.floor(stats.haste * 100 + 0.5) }))
	end
	if stats.slow and stats.slowDuration then
		table.insert(
			lines,
			L(
				"detail.slow",
				{ value = math.floor(stats.slow * 100 + 0.5), duration = Ui.formatDecimal(stats.slowDuration, 1) }
			)
		)
	end
	if stats.splash then
		table.insert(lines, L("detail.splash", { value = Ui.formatDecimal(stats.splash, 1) }))
	end
	if stats.chains then
		table.insert(lines, L("detail.chains", { value = stats.chains }))
	end
	if stats.armorIgnore then
		table.insert(lines, L("detail.armorIgnore", { value = math.floor(stats.armorIgnore * 100 + 0.5) }))
	end
	if stats.bossBonus then
		table.insert(lines, L("detail.bossBonus", { value = math.floor(stats.bossBonus * 100 + 0.5) }))
	end
	if stats.mark and stats.markDuration then
		table.insert(
			lines,
			L(
				"detail.mark",
				{ value = math.floor(stats.mark * 100 + 0.5), duration = Ui.formatDecimal(stats.markDuration, 1) }
			)
		)
	end
	return lines
end

function TowerDetail.new(parent: Instance, callbacks: Callbacks): TowerDetail
	local self = setmetatable({ callbacks = callbacks, buttons = {}, towerId = "dardo" }, TowerDetail) :: any
	self.chrome = Chrome.new(parent, {
		name = "TowerDetailScreen",
		title = L("detail.title"),
		onBack = callbacks.onBack,
	})
	local body = self.chrome.body
	self.content = Components.scroller(body, "Content", {
		Size = UDim2.new(1, 0, 1, -(Theme.sizes.buttonTarget + 16)),
		ZIndex = 2,
	})
	local layout = Components.list(self.content, Enum.FillDirection.Vertical, 12)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	self.footer = Components.frame(body, "Footer", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 8),
		Position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget + 8)),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	Components.list(self.footer, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	return self
end

-- Confirmação de desbloqueio (prancha 32): preço, saldo atual e saldo projetado.
function TowerDetail.confirmUnlock(self: TowerDetail, def: Types.TowerDef, opener: GuiButton?)
	local balance = Store.buttons()
	local projected = balance - def.unlock
	Modal.open(self.chrome.root, {
		title = L("unlock.title", { tower = def.name }),
		body = L("unlock.body", { tower = def.name, cost = def.unlock }),
		confirmText = L("unlock.confirm"),
		cancelText = L("common.cancel"),
		opener = opener,
		width = 520,
		build = function(content)
			Components.label(content, "Balance", L("unlock.balance", { current = balance }), {
				Size = UDim2.new(1, 0, 0, 22),
				LayoutOrder = 1,
				Font = Theme.fonts.bodyMedium,
				ZIndex = 5,
			})
			Components.label(content, "Projected", L("unlock.projected", { value = math.max(projected, 0) }), {
				Size = UDim2.new(1, 0, 0, 22),
				LayoutOrder = 2,
				Font = Theme.fonts.bodyBold,
				TextColor3 = if projected >= 0 then Theme.colors.tealDark else Theme.colors.danger,
				ZIndex = 5,
			})
			if projected < 0 then
				Components.label(content, "Missing", L("collection.notEnough", { missing = -projected }), {
					Size = UDim2.new(1, 0, 0, 22),
					LayoutOrder = 3,
					TextColor3 = Theme.colors.danger,
					ZIndex = 5,
				})
			end
		end,
		onConfirm = function(controls)
			if Store.buttons() < def.unlock then
				-- saldo pode ter mudado entre abrir e confirmar: mostra o valor atualizado
				controls:setError(L("collection.notEnough", { missing = def.unlock - Store.buttons() }))
				return
			end
			controls:setPending(true)
			local key = "profile:buy:" .. def.id
			local started = CommandAdapter.send(key, "BuyTower", { towerId = def.id }, {
				onStage = function(stage)
					if stage == "slow" then
						controls:setBody(L("common.stillWorking"))
					end
				end,
				onSuccess = function(response)
					if response.profile then
						Store.setProfile(response.profile)
					end
					controls:close()
					self.callbacks.onUnlocked(def.id)
					TowerDetail.render(self)
				end,
				onError = function(code)
					if code == "INSUFFICIENT_FUNDS" then
						controls:setError(L("collection.notEnough", { missing = def.unlock - Store.buttons() }))
					elseif Localization.has("error." .. code) then
						controls:setError(L("error." .. code))
					else
						controls:setError(L("error.UNKNOWN"))
					end
				end,
			})
			if not started then
				-- pedido já em voo: mantém o preço e bloqueia a repetição, sem novo requestId
				controls:setBody(L("common.confirming"))
			end
		end,
	})
end

function TowerDetail.setTower(self: TowerDetail, towerId: string)
	self.towerId = towerId
end

function TowerDetail.render(self: TowerDetail)
	self.chrome:refreshBalance()
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

	local def = Catalog.getTower(self.towerId)
	if not def then
		Components.emptyState(self.content, "Unknown", L("detail.unknownTower"), {
			Size = UDim2.new(1, 0, 0, 120),
			LayoutOrder = 1,
		})
		return
	end
	local profile = Store.profile()
	local owned = profile ~= nil and table.find(profile.ownedTowerIds or {}, def.id) ~= nil
	local equipped = profile ~= nil and table.find(profile.loadout or {}, def.id) ~= nil
	local compact = Responsive.isCompact()
	self.chrome:setTitle(def.name, def.role)

	-- retrato e resumo
	local header = Components.panel(self.content, "Header", {
		Size = UDim2.new(1, 0, 0, if compact then 150 else 190),
		LayoutOrder = 1,
		ZIndex = 3,
	}, { tape = true, shadow = false })
	Components.padding(header, 16, 14)
	local entry = Assets.get(Assets.towerKey(def.id, "L0"))
	local portrait = if entry then (entry.portrait or entry.image) else nil
	if portrait then
		local image = Instance.new("ImageLabel")
		image.Name = "Portrait"
		image.BackgroundTransparency = 1
		image.Image = portrait :: string
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromOffset(if compact then 110 else 150, if compact then 110 else 150)
		image.Active = false
		image.ZIndex = header.ZIndex + 1
		image.Parent = header
	end
	local infoLeft = if compact then 124 else 166
	local stats = def.states.L0
	local lines = statLines(def, stats)
	for index, line in ipairs(lines) do
		Components.label(header, "Stat" .. index, line, {
			Size = UDim2.new(1, -infoLeft, 0, 20),
			Position = UDim2.fromOffset(infoLeft, (index - 1) * 22),
			TextSize = Theme.sizes.body,
			Font = Theme.fonts.bodyMedium,
			ZIndex = header.ZIndex + 1,
		})
	end
	Components.caption(header, "Limit", L("detail.perPlayerLimit", { limit = def.perPlayerLimit }), {
		Size = UDim2.new(1, -infoLeft, 0, 18),
		Position = UDim2.fromOffset(infoLeft, #lines * 22 + 2),
		ZIndex = header.ZIndex + 1,
	})

	-- custos: botões (desbloqueio) e sucata (construção) em blocos distintos
	local costs = Components.frame(self.content, "Costs", {
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 3,
	})
	Components.list(costs, Enum.FillDirection.Horizontal, 12)
	local function costCard(name: string, captionText: string, value: string, iconKey: string, order: number)
		local card = Components.panel(costs, name, {
			Size = UDim2.new(0.5, -6, 1, 0),
			LayoutOrder = order,
			ZIndex = 4,
		}, { shadow = false })
		Components.padding(card, 14, 12)
		Components.caption(card, "Caption", captionText, {
			Size = UDim2.new(1, 0, 0, 18),
			ZIndex = 5,
		})
		local row = Components.frame(card, "Row", {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 22),
			BackgroundTransparency = 1,
			ZIndex = 5,
		})
		Components.list(row, Enum.FillDirection.Horizontal, 8)
		Components.icon(row, iconKey, 22, { LayoutOrder = 1, ZIndex = 6 })
		Components.label(row, "Value", value, {
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = Theme.sizes.numbers,
			Font = Theme.fonts.numbers,
			TextWrapped = false,
			LayoutOrder = 2,
			ZIndex = 6,
		})
	end
	costCard(
		"Unlock",
		L("detail.unlockCost"),
		if def.unlock > 0 then tostring(def.unlock) else L("detail.starter"),
		"ui_buttons",
		1
	)
	costCard("Build", L("detail.buildCost"), tostring(stats.cost), "ui_scrap", 2)

	-- especializações: comparação lado a lado, sem aplicar nada
	Components.label(self.content, "SpecTitle", Components.upper(L("collection.spec")), {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.caption,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.tealDark,
		LayoutOrder = 3,
		ZIndex = 3,
	})
	local specRow = Components.frame(self.content, "Specs", {
		-- folga para cinco linhas de atributo sem encostar no custo
		Size = UDim2.new(1, 0, 0, 178),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		ZIndex = 3,
	})
	Components.list(specRow, Enum.FillDirection.Horizontal, 12)
	for index, state in ipairs({ "L3A", "L3B" }) do
		local specStats = Catalog.getStateStats(def.id, state)
		local card = Components.panel(specRow, state, {
			Size = UDim2.new(0.5, -6, 1, 0),
			LayoutOrder = index,
			ZIndex = 4,
		}, { shadow = false })
		Components.padding(card, 14, 12)
		Components.label(card, "Name", def.branchNames[index], {
			Size = UDim2.new(1, -64, 0, 24),
			Font = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.bodyLarge,
			ZIndex = 5,
		})
		local specEntry = Assets.get(Assets.towerKey(def.id, state))
		local specPortrait = if specEntry then (specEntry.portrait or specEntry.image) else nil
		if specPortrait then
			local image = Instance.new("ImageLabel")
			image.Name = "Portrait"
			image.BackgroundTransparency = 1
			image.Image = specPortrait :: string
			image.ScaleType = Enum.ScaleType.Fit
			image.Size = UDim2.fromOffset(56, 56)
			image.Position = UDim2.new(1, -56, 0, 0)
			image.Active = false
			image.ZIndex = card.ZIndex + 1
			image.Parent = card
		end
		if specStats then
			for line, text in ipairs(statLines(def, specStats)) do
				Components.caption(card, "S" .. line, text, {
					Size = UDim2.new(1, 0, 0, 18),
					Position = UDim2.fromOffset(0, 26 + (line - 1) * 19),
					ZIndex = 5,
				})
			end
			Components.label(card, "Cost", L("detail.specCost", { cost = specStats.cost }), {
				Size = UDim2.new(1, 0, 0, 20),
				Position = UDim2.new(0, 0, 1, -20),
				TextSize = Theme.sizes.caption,
				Font = Theme.fonts.bodyBold,
				TextColor3 = Theme.colors.goldText,
				ZIndex = 5,
			})
		end
	end
	Components.caption(self.content, "SpecNote", L("detail.specNote"), {
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 5,
		ZIndex = 3,
	})

	-- domínio
	local points = 0
	if profile and profile.masteryByTower and profile.masteryByTower[def.id] then
		points = profile.masteryByTower[def.id].points or 0
	end
	local nextMilestone: number? = nil
	for _, milestone in ipairs(Balance.rewards.masteryMilestones) do
		if points < milestone then
			nextMilestone = milestone
			break
		end
	end
	local masteryPanel = Components.panel(self.content, "Mastery", {
		Size = UDim2.new(1, 0, 0, 78),
		LayoutOrder = 6,
		ZIndex = 3,
	}, { shadow = false })
	Components.padding(masteryPanel, 14, 12)
	Components.label(masteryPanel, "Title", L("collection.mastery", { points = points }), {
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.fonts.bodyBold,
		ZIndex = 4,
	})
	local bar = Components.progressBar(masteryPanel, "Bar", {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.fromOffset(0, 30),
		ZIndex = 4,
	}, Theme.colors.teal)
	bar:setProgress(if nextMilestone then points / nextMilestone else 1, false)
	Components.caption(
		masteryPanel,
		"Next",
		if nextMilestone then L("collection.nextMilestone", { points = nextMilestone }) else L("collection.masteryMax"),
		{
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 44),
			ZIndex = 4,
		}
	)

	-- ações
	local training = Components.button(self.footer, {
		name = "Training",
		text = L("detail.tryInTraining"),
		kind = "secondary",
		size = UDim2.fromOffset(if compact then 240 else 310, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		zIndex = 4,
		onActivate = function()
			self.callbacks.onTraining(def.id)
		end,
	})
	table.insert(self.buttons, training)

	if owned then
		local cosmetics = Components.button(self.footer, {
			name = "Cosmetics",
			text = L("detail.cosmetics"),
			kind = "secondary",
			size = UDim2.fromOffset(if compact then 220 else 260, Theme.sizes.buttonTarget),
			layoutOrder = 2,
			zIndex = 4,
			onActivate = function()
				self.callbacks.onCosmetics(def.id)
			end,
		})
		table.insert(self.buttons, cosmetics)
		local equip = Components.button(self.footer, {
			name = "Equip",
			text = if equipped then L("collection.equipped") else L("collection.equip"),
			kind = "primary",
			size = UDim2.fromOffset(if compact then 200 else 240, Theme.sizes.buttonTarget),
			layoutOrder = 3,
			zIndex = 4,
			onActivate = function()
				self.callbacks.onEquip(def.id)
			end,
		})
		equip:setSelected(equipped)
		if equipped then
			equip:setAvailable(false, L("detail.alreadyEquipped"))
		end
		table.insert(self.buttons, equip)
	else
		local unlock: Components.Button
		unlock = Components.button(self.footer, {
			name = "Unlock",
			text = L("detail.unlock", { cost = def.unlock }),
			kind = "primary",
			icon = "ui_lock",
			size = UDim2.fromOffset(if compact then 260 else 300, Theme.sizes.buttonTarget),
			layoutOrder = 3,
			zIndex = 4,
			onActivate = function()
				TowerDetail.confirmUnlock(self, def, unlock.instance)
			end,
		})
		local missing = def.unlock - Store.buttons()
		if not profile then
			unlock:setAvailable(false, L("app.profileUnavailableShort"))
		elseif missing > 0 then
			unlock:setAvailable(false, L("collection.notEnough", { missing = missing }))
		end
		table.insert(self.buttons, unlock)
	end
end

function TowerDetail.show(self: TowerDetail, params: { [string]: any })
	if params and params.towerId then
		self.towerId = params.towerId
	end
	self.chrome:show()
	TowerDetail.render(self)
end

function TowerDetail.hide(self: TowerDetail)
	self.chrome:hide()
end

return TowerDetail
