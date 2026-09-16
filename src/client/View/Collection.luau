--!strict
-- Coleção: seis personagens, compra por botões, equipe (até quatro), domínio e especializações.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Collection = {}
Collection.__index = Collection

local L = Localization.get

export type Callbacks = {
	onBack: () -> (),
	onBuy: (towerId: string) -> (),
	onSetLoadout: (towerIds: { string }) -> (),
}

export type Collection = typeof(setmetatable(
	{} :: {
		root: Frame,
		grid: ScrollingFrame,
		header: TextLabel,
		callbacks: Callbacks,
		refreshHeader: () -> (),
		refit: () -> (),
		profile: { [string]: any }?,
	},
	Collection
))

function Collection.new(parent: GuiObject, callbacks: Callbacks): Collection
	local root = Ui.frame(
		parent,
		"Collection",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.paper, Visible = false }
	)
	local self = setmetatable({ root = root, callbacks = callbacks, profile = nil }, Collection) :: any
	local top = Ui.frame(
		root,
		"Top",
		{ Size = UDim2.new(1, -32, 0, 56), Position = UDim2.new(0, 16, 0, 12), BackgroundTransparency = 1 }
	)
	local back = Ui.button(top, "Back", "← " .. L("common.back"), "secondary", { Size = UDim2.new(0, 140, 0, 48) })
	back:onClick(callbacks.onBack)
	local title = Ui.title(
		top,
		"Title",
		L("collection.title"),
		{ Size = UDim2.new(0, 300, 1, 0), Position = UDim2.new(0, 156, 0, 0), TextSize = 30 }
	)
	self.header = Ui.label(top, "Buttons", "", {
		Size = UDim2.new(0, 300, 1, 0),
		Position = UDim2.new(1, -300, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.fonts.numbers,
		TextSize = 24,
		TextColor3 = Theme.colors.goldDark,
	})
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, -32, 1, -90)
	grid.Position = UDim2.new(0, 16, 0, 78)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 6
	grid.Parent = root
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 300, 0, 300)
	layout.FillDirectionMaxCells = 0
	layout.CellPadding = UDim2.new(0, 12, 0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	self.grid = grid
	-- colunas adaptativas: cada carta ocupa 1/n da largura, com mínimo de ~300 px
	local function fit()
		local width = grid.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local cols = math.max(1, math.floor((width + 12) / 312))
		layout.CellSize = UDim2.new(1 / cols, -12, 0, 300)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	self.refit = fit
	self.refreshHeader = function()
		title.Text = L("collection.title")
		back:setText("← " .. L("common.back"))
	end
	return self
end

local function masteryText(profile: { [string]: any }?, towerId: string): string
	local points = 0
	if profile and profile.masteryByTower and profile.masteryByTower[towerId] then
		points = profile.masteryByTower[towerId].points or 0
	end
	local nextMilestone: number? = nil
	for _, m in ipairs(Balance.rewards.masteryMilestones) do
		if points < m then
			nextMilestone = m
			break
		end
	end
	local text = L("collection.mastery", { points = points })
	if nextMilestone then
		text ..= "  ·  " .. L("collection.nextMilestone", { points = nextMilestone })
	end
	return text
end

function Collection.render(self: Collection)
	self.refreshHeader()
	local profile = self.profile
	self.header.Text = if profile
		then Ui.formatNumber(profile.buttons) .. " " .. L("common.buttons")
		else L("app.loading")
	for _, c in ipairs(self.grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local owned: { string } = if profile then profile.ownedTowerIds else Catalog.starterTowerIds()
	local loadout: { string } = if profile then profile.loadout else Catalog.starterTowerIds()
	for i, def in ipairs(Balance.towers) do
		local card = Ui.panel(self.grid, "Card_" .. def.id, { LayoutOrder = i, BackgroundColor3 = Theme.colors.cream })
		Ui.padding(card, 12)
		local isOwned = table.find(owned, def.id) ~= nil
		local isEquipped = table.find(loadout, def.id) ~= nil
		local entry = Assets.get(Assets.towerKey(def.id, "L0"))
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = if entry and (entry.portrait or entry.image) then (entry.portrait or entry.image) :: string else ""
		img.ScaleType = Enum.ScaleType.Fit
		img.Size = UDim2.new(0, 96, 0, 96)
		img.Position = UDim2.new(0, 0, 0, 0)
		img.ImageColor3 = if isOwned then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
		img.Parent = card
		Ui.title(
			card,
			"Name",
			def.name,
			{ Size = UDim2.new(1, -106, 0, 30), Position = UDim2.new(0, 106, 0, 0), TextSize = 24 }
		)
		Ui.label(card, "Role", def.role, {
			Size = UDim2.new(1, -106, 0, 20),
			Position = UDim2.new(0, 106, 0, 32),
			TextColor3 = Theme.colors.muted,
			TextSize = 14,
		})
		local l0 = def.states.L0
		Ui.label(
			card,
			"Stats",
			(if def.damageType ~= "none" then L("detail.damage", { value = l0.damage }) .. " · " else "")
				.. L("detail.range", { value = Ui.formatDecimal(l0.range, 1) })
				.. "\n"
				.. L("build.confirm", { cost = l0.cost }),
			{ Size = UDim2.new(1, -106, 0, 40), Position = UDim2.new(0, 106, 0, 54), TextSize = 13 }
		)
		-- especializações
		local specRow = Ui.frame(
			card,
			"Specs",
			{ Size = UDim2.new(1, 0, 0, 64), Position = UDim2.new(0, 0, 0, 104), BackgroundTransparency = 1 }
		)
		Ui.list(specRow, Enum.FillDirection.Horizontal, 8)
		for si, state in ipairs({ "L3A", "L3B" }) do
			local specEntry = Assets.get(Assets.towerKey(def.id, state))
			local holder = Ui.frame(
				specRow,
				state,
				{ Size = UDim2.new(0.5, -4, 1, 0), BackgroundTransparency = 1, LayoutOrder = si }
			)
			local simg = Instance.new("ImageLabel")
			simg.BackgroundTransparency = 1
			simg.Image = if specEntry and (specEntry.portrait or specEntry.image)
				then (specEntry.portrait or specEntry.image) :: string
				else ""
			simg.ScaleType = Enum.ScaleType.Fit
			simg.Size = UDim2.new(0, 56, 0, 56)
			simg.Parent = holder
			Ui.label(holder, "N", def.branchNames[si], {
				Size = UDim2.new(1, -60, 1, 0),
				Position = UDim2.new(0, 60, 0, 0),
				TextSize = 13,
				Font = Theme.fonts.bodyBold,
			})
		end
		Ui.label(card, "Mastery", masteryText(profile, def.id), {
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.new(0, 0, 0, 176),
			TextSize = 12,
			TextColor3 = Theme.colors.muted,
		})
		local action: Ui.Button
		if not isOwned then
			action = Ui.button(
				card,
				"Buy",
				L("collection.buy", { cost = def.unlock }),
				"primary",
				{ Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -48) }
			)
			local buttons = if profile then profile.buttons else 0
			if buttons < def.unlock then
				action:setEnabled(false, L("collection.notEnough", { missing = def.unlock - buttons }))
			end
			if not profile then
				action:setEnabled(false, L("app.loading"))
			end
			action:onClick(function()
				self.callbacks.onBuy(def.id)
			end)
		elseif isEquipped then
			action = Ui.button(
				card,
				"Unequip",
				"✓ " .. L("collection.equipped"),
				"secondary",
				{ Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -48) }
			)
			action:setText("✓ " .. L("collection.equipped"), L("collection.unequip"))
			action:onClick(function()
				local newLoadout = {}
				for _, id in ipairs(loadout) do
					if id ~= def.id then
						table.insert(newLoadout, id)
					end
				end
				self.callbacks.onSetLoadout(newLoadout)
			end)
		else
			action = Ui.button(
				card,
				"Equip",
				L("collection.equip"),
				"primary",
				{ Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -48) }
			)
			if #loadout >= Balance.loadoutSlots then
				action:setEnabled(false, L("collection.teamFull"))
			end
			action:onClick(function()
				local newLoadout = table.clone(loadout)
				table.insert(newLoadout, def.id)
				self.callbacks.onSetLoadout(newLoadout)
			end)
		end
	end
end

function Collection.setProfile(self: Collection, profile: { [string]: any }?)
	self.profile = profile
	if self.root.Visible then
		Collection.render(self)
	end
end

function Collection.show(self: Collection)
	self.root.Visible = true
	Collection.render(self)
end

function Collection.hide(self: Collection)
	self.root.Visible = false
end

return Collection
