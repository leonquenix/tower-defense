--!strict
-- Tela de resultado: ondas, recompensa e status de salvamento, domínio, contribuição, revanche e menu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local MatchController = require(script.Parent.Parent.Controllers.MatchController)
local Motion = require(script.Parent.Motion)

local Result = {}
Result.__index = Result

local L = Localization.get

export type Callbacks = { onRematch: (ready: boolean) -> (), onMenu: () -> () }

export type Result = typeof(setmetatable(
	{} :: {
		root: Frame,
		box: Frame,
		body: Frame,
		callbacks: Callbacks,
		rematchReady: boolean,
		rematchButton: Ui.Button?,
	},
	Result
))

function Result.new(parent: GuiObject, callbacks: Callbacks): Result
	local root = Ui.frame(parent, "Result", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 20,
	})
	root.Active = true
	local box = Ui.panel(root, "Box", {
		Size = UDim2.new(0, 620, 0, 520),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.cream,
		ZIndex = 21,
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(620, 560)
	constraint.Parent = box
	box.Size = UDim2.new(0.92, 0, 0.9, 0)
	Ui.padding(box, 20)
	local body = Ui.frame(box, "Body", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22 })
	local self = setmetatable(
		{ root = root, box = box, body = body, callbacks = callbacks, rematchReady = false, rematchButton = nil },
		Result
	) :: any
	return self
end

function Result.render(self: Result, payload: { [string]: any })
	for _, c in ipairs(self.body:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local view = MatchController.current()
	local result = payload.result :: Types.MatchResult?
	local outcome = payload.outcome
	local status = payload.status
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -60)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 22
	scroll.Parent = self.body
	Ui.list(scroll, Enum.FillDirection.Vertical, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local o = 0
	local function add(inst: GuiObject)
		o += 1
		inst.LayoutOrder = o
		inst.ZIndex = 23
		inst.Parent = scroll
	end
	local titleKey = if result and result.outcome == "won"
		then "result.won"
		elseif result and result.outcome == "lost" then "result.lost"
		else "result.abandoned"
	add(Ui.title(nil, "Title", L(titleKey), {
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 32,
		TextColor3 = if result and result.outcome == "won" then Theme.colors.tealDark else Theme.colors.danger,
	}))
	if result and view then
		add(
			Ui.label(
				nil,
				"Waves",
				L("result.waves", { waves = result.wavesCompleted, total = view.snapshot.totalWaves }),
				{ Size = UDim2.new(1, 0, 0, 24), TextSize = 18, Font = Theme.fonts.bodyMedium }
			)
		)
	end
	-- recompensa
	local rewardText: string
	if status == "saving" then
		rewardText = L("result.rewardSaving")
	elseif outcome then
		if outcome.status == "saved" then
			rewardText = L("result.reward", { buttons = outcome.buttons }) .. "  ·  " .. L("result.rewardSaved")
		elseif outcome.status == "pending" then
			rewardText = L("result.reward", { buttons = outcome.buttons }) .. "  ·  " .. L("result.rewardPending")
		elseif outcome.status == "unsaved" then
			rewardText = L("result.reward", { buttons = outcome.buttons }) .. "  ·  " .. L("app.progressNotSaved")
		elseif outcome.status == "duplicate" then
			rewardText = L("result.rewardSaved")
		elseif outcome.status == "none" or outcome.status == "ineligible" then
			rewardText = L("result.noReward")
		else
			rewardText = L("result.rewardPending")
		end
	else
		rewardText = L("result.noReward")
	end
	add(Ui.label(nil, "Reward", rewardText, {
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 16,
		TextColor3 = Theme.colors.goldDark,
		Font = Theme.fonts.bodyBold,
	}))
	if outcome and outcome.mastery then
		for towerId, points in pairs(outcome.mastery) do
			local def = Catalog.getTower(towerId)
			if def and points > 0 then
				add(
					Ui.label(
						nil,
						"M_" .. towerId,
						L("result.mastery", { points = points, tower = def.name }),
						{ Size = UDim2.new(1, 0, 0, 20), TextSize = 14 }
					)
				)
			end
		end
		for towerId, milestones in pairs(outcome.milestones or {}) do
			local def = Catalog.getTower(towerId)
			for _, m in ipairs(milestones) do
				add(
					Ui.label(
						nil,
						"Mi_" .. towerId .. m,
						"★ " .. L("result.milestone", { points = m, tower = if def then def.name else towerId }),
						{
							Size = UDim2.new(1, 0, 0, 20),
							TextSize = 14,
							TextColor3 = Theme.colors.tealDark,
							Font = Theme.fonts.bodyBold,
						}
					)
				)
			end
		end
		for _, key in ipairs(outcome.unlocked or {}) do
			local mapId, diff = key:match("^(%w+):(%w+)$")
			local map = if mapId then Catalog.getMap(mapId) else nil
			local what = if map then map.name .. " · " .. L("menu.difficulty." .. tostring(diff)) else key
			add(
				Ui.label(
					nil,
					"U_" .. key,
					"🔓 " .. L("result.unlocked", { what = what }),
					{ Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = Theme.colors.tealDark }
				)
			)
		end
	end
	-- contribuição
	local stats = payload.stats :: { [any]: Types.PlayerMatchStats }?
	if stats and view then
		add(Ui.label(nil, "ContribTitle", Ui.upper(L("result.contribution")), {
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 12,
			Font = Theme.fonts.bodyBold,
			TextColor3 = Theme.colors.tealDark,
		}))
		for _, p in ipairs(view.snapshot.participants) do
			local st = stats[p.userId] or stats[tostring(p.userId)]
			if st then
				local owner = Theme.owners[p.color] or Theme.owners[1]
				add(
					Ui.label(
						nil,
						"C_" .. p.userId,
						owner.glyph
							.. " "
							.. p.name
							.. "   "
							.. L("result.damage", { value = Ui.formatNumber(st.damage) })
							.. "  ·  "
							.. L("result.slow", { value = Ui.formatDecimal(st.slowSeconds, 0) })
							.. "  ·  "
							.. L("result.support", { value = Ui.formatNumber(st.supportBonusDamage) }),
						{
							Size = UDim2.new(1, 0, 0, 20),
							TextSize = 14,
							TextColor3 = owner.color == Theme.colors.gold and Theme.colors.goldDark or owner.color,
						}
					)
				)
			end
		end
	end
	-- botões
	local rowFrame = Ui.frame(
		self.body,
		"Row",
		{ Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 1, -52), BackgroundTransparency = 1, ZIndex = 23 }
	)
	Ui.list(rowFrame, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	local menuBtn = Ui.button(
		rowFrame,
		"Menu",
		L("result.menu"),
		"secondary",
		{ Size = UDim2.new(0, 190, 0, 50), ZIndex = 24, LayoutOrder = 1 }
	)
	menuBtn:onClick(self.callbacks.onMenu)
	local canRematch = view ~= nil and view.snapshot.mode ~= "tutorial"
	if canRematch then
		local rematch = Ui.button(
			rowFrame,
			"Rematch",
			L("result.rematch"),
			"primary",
			{ Size = UDim2.new(0, 220, 0, 50), ZIndex = 24, LayoutOrder = 2 }
		)
		self.rematchButton = rematch
		rematch:onClick(function()
			self.rematchReady = not self.rematchReady
			self.callbacks.onRematch(self.rematchReady)
			rematch:setKind(if self.rematchReady then "secondary" else "primary")
		end)
		Result.setRematch(
			self,
			if view and view.rematch then view.rematch.ready else 0,
			if view and view.rematch then view.rematch.total else 1
		)
	end
end

function Result.setRematch(self: Result, ready: number, total: number)
	local b = self.rematchButton
	if b and total > 1 then
		b:setText(L("result.rematch"), L("result.rematchWaiting", { ready = ready, total = total }))
	end
end

function Result.show(self: Result, payload: { [string]: any })
	local wasVisible = self.root.Visible
	self.root.Visible = true
	Result.render(self, payload)
	if not wasVisible then
		Motion.popIn(self.box)
	end
end

function Result.hide(self: Result)
	self.root.Visible = false
	self.rematchReady = false
	self.rematchButton = nil
end

return Result
