--!strict
-- Fim de partida: o que aconteceu, o que foi creditado e o que ficou pendente.
--
-- A recompensa nunca é "estimada" aqui: o texto reflete exatamente o status que o servidor
-- mandou (salva, pendente, duplicada, não registrada).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

local STATUS_TEXT: { [string]: string } = {
	saved = "result.rewardSaved",
	pending = "result.rewardPending",
	duplicate = "result.rewardAlreadySaved",
	unsaved = "result.rewardNotRecorded",
	unavailable = "result.rewardNotRecorded",
	ineligible = "result.noReward",
	none = "result.noReward",
}

-- Uma estrela do resultado. A escala vem de fora: o cartão entrega uma por vez, com mola, para
-- a conquista ter peso em vez de aparecer pronta.
local function starText(scope: Kit.Scope, result: Kit.Used<any>, index: number, scale: Kit.Used<number>): TextLabel
	local label = Kit.text(scope, {
		Name = "Star" .. index,
		Text = "★",
		Font = Theme.fonts.title,
		TextSize = 44,
		TextColor3 = scope:Computed(function(use)
			local payload = Kit.read(use, result)
			local earned = payload and payload.result and payload.result.starsEarned
			local got = typeof(earned) == "table" and earned[index] == true
			return if got then Theme.colors.gold else Theme.colors.sageDeep
		end),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(48, 48),
		LayoutOrder = index,
		ZIndex = 43,
	})
	local holder = scope:New("UIScale")({ Scale = scale })
	holder.Parent = label
	local rotation = scope:New("UIStroke")({
		Color = Theme.colors.goldDark,
		Thickness = scope:Computed(function(use)
			local payload = Kit.read(use, result)
			local earned = payload and payload.result and payload.result.starsEarned
			local got = typeof(earned) == "table" and earned[index] == true
			return if got then 2 else 0
		end),
	})
	rotation.Parent = label
	return label
end

return function(scope: Kit.Scope, props: Props): Frame
	local result = Bridge.use(scope, Atoms.matchResult)
	local snapshot = Bridge.use(scope, Atoms.snapshot)

	local outcomeText = scope:Computed(function(use)
		local payload = use(result)
		if not payload then
			return ""
		end
		local outcome = payload.result and payload.result.outcome
		if outcome == "won" then
			return L("result.won")
		elseif outcome == "lost" then
			return L("result.lost")
		end
		return L("result.abandoned")
	end)

	-- O total de ondas não vem no resultado (que é o registro durável); ele é do snapshot da
	-- partida, que continua em memória enquanto esta tela está aberta.
	local summaryText = scope:Computed(function(use)
		local payload = Kit.read(use, result)
		local current = Kit.read(use, snapshot)
		if not payload or not payload.result then
			return ""
		end
		local total = if current then current.totalWaves else (payload.result.wavesCompleted or 0)
		return L("result.waves", { waves = payload.result.wavesCompleted or 0, total = total })
	end)

	local rewardText = scope:Computed(function(use)
		local payload = use(result)
		if not payload then
			return ""
		end
		if payload.status == "saving" then
			return L("result.rewardSaving")
		end
		local outcome = payload.outcome
		if not outcome then
			return L("result.noReward")
		end
		local key = STATUS_TEXT[tostring(outcome.status)] or "result.noReward"
		if outcome.status == "saved" or outcome.status == "duplicate" then
			return L("result.reward", { buttons = outcome.buttons or 0 }) .. " · " .. L(key)
		end
		return L(key)
	end)

	local pendingHelp = scope:Computed(function(use)
		local payload = use(result)
		local outcome = payload and payload.outcome
		if not outcome then
			return ""
		end
		if outcome.status == "pending" then
			return L("result.pendingExplain")
		elseif outcome.status == "unsaved" or outcome.status == "unavailable" then
			return L("result.notRecordedExplain")
		end
		return ""
	end)

	local masteryLines = scope:Computed(function(use): { string }
		local payload = use(result)
		local outcome = payload and payload.outcome
		local lines: { string } = {}
		if outcome and typeof(outcome.mastery) == "table" then
			for towerId, points in pairs(outcome.mastery) do
				local def = Catalog.getTower(towerId)
				table.insert(lines, L("result.mastery", { points = points, tower = if def then def.name else towerId }))
			end
		end
		table.sort(lines)
		if #lines == 0 then
			table.insert(lines, L("result.noMastery"))
		end
		return lines
	end)

	-- Entrada do cartão e das estrelas: o resultado chega com um salto, e cada estrela entra
	-- depois da outra. `seq` avança sozinho quando um resultado novo aparece.
	local cardScale = scope:Value(0.8)
	local starScales = { scope:Value(0), scope:Value(0), scope:Value(0) }
	local cardSpring = scope:Spring(cardScale, 16, 0.55)
	local starSprings = {
		scope:Spring(starScales[1], 22, 0.35),
		scope:Spring(starScales[2], 22, 0.35),
		scope:Spring(starScales[3], 22, 0.35),
	}
	local playedFor: string? = nil
	local function playEntrance(payload: any)
		local matchId = payload and payload.result and tostring(payload.result.matchId or payload.status)
		local key = tostring(matchId) .. tostring(payload and payload.status)
		if key == playedFor then
			return
		end
		playedFor = key
		cardScale:set(0.8)
		for _, value in ipairs(starScales) do
			value:set(0)
		end
		task.defer(function()
			cardScale:set(1)
		end)
		local earned = payload and payload.result and payload.result.starsEarned
		if typeof(earned) ~= "table" then
			return
		end
		for index = 1, 3 do
			task.delay(0.35 + index * 0.3, function()
				-- estrela não conquistada entra menor e apagada: a diferença tem de saltar aos olhos
				starScales[index]:set(if earned[index] == true then 1 else 0.7)
			end)
		end
	end
	Bridge.watchAtom(Atoms.matchResult, function(payload: any)
		if payload then
			playEntrance(payload)
		else
			playedFor = nil
		end
	end)

	local contributionText = scope:Computed(function(use)
		local payload = use(result)
		local stats = payload and payload.stats
		local mine = stats and stats[tostring(Players.LocalPlayer.UserId)] or nil
		if not mine then
			mine = stats and stats[Players.LocalPlayer.UserId] or nil
		end
		if not mine then
			return ""
		end
		return L("result.damage", { value = math.floor((mine.damage or 0) + 0.5) })
			.. " · "
			.. L("result.slow", { value = math.floor((mine.slowSeconds or 0) + 0.5) })
			.. " · "
			.. L("result.support", { value = math.floor((mine.supportBonusDamage or 0) + 0.5) })
	end)

	return scope:New("Frame")({
		Name = "ResultScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.visible,
		[Children] = Kit.children(Kit.panel(scope, {
			name = "Card",
			scale = cardSpring,
			size = UDim2.new(0, 560, 0, 0),
			automaticSize = Enum.AutomaticSize.Y,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			padding = 26,
			zIndex = 41,
			layout = Kit.list(scope, { Padding = UDim.new(0, 12) }),
			children = Kit.children(
				Kit.title(scope, {
					Text = outcomeText,
					TextSize = 34,
					Size = UDim2.new(1, 0, 0, 40),
					LayoutOrder = 1,
					ZIndex = 42,
				}),
				Kit.caption(scope, {
					Text = summaryText,
					Size = UDim2.new(1, 0, 0, 20),
					LayoutOrder = 2,
					ZIndex = 42,
				}),
				-- Estrelas da fase: as três, cheias as conquistadas nesta partida.
				scope:New("Frame")({
					Name = "Stars",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 52),
					Visible = scope:Computed(function(use)
						local payload = use(result)
						return payload ~= nil and payload.result ~= nil and payload.result.levelId ~= nil
					end),
					LayoutOrder = 3,
					ZIndex = 42,
					[Children] = Kit.children(
						Kit.list(scope, {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 10),
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						starText(scope, result, 1, starSprings[1]),
						starText(scope, result, 2, starSprings[2]),
						starText(scope, result, 3, starSprings[3])
					),
				}),
				Kit.panel(scope, {
					name = "Reward",
					size = UDim2.new(1, 0, 0, 0),
					automaticSize = Enum.AutomaticSize.Y,
					color = Theme.colors.cream,
					padding = 14,
					layoutOrder = 4,
					shadow = false,
					zIndex = 42,
					layout = Kit.list(scope, { Padding = UDim.new(0, 6) }),
					children = Kit.children(
						Kit.text(scope, {
							Text = rewardText,
							Font = Theme.fonts.bodyBold,
							Size = UDim2.new(1, 0, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							LayoutOrder = 1,
							ZIndex = 43,
						}),
						Kit.caption(scope, {
							Text = pendingHelp,
							Visible = scope:Computed(function(use)
								return use(pendingHelp) ~= ""
							end),
							Size = UDim2.new(1, 0, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							LayoutOrder = 2,
							ZIndex = 43,
						}),
						Kit.button(scope, {
							name = "Recheck",
							text = L("result.recheck"),
							kind = "quiet",
							visible = scope:Computed(function(use)
								return use(pendingHelp) ~= ""
							end),
							size = UDim2.new(0, 220, 0, 44),
							layoutOrder = 3,
							zIndex = 43,
							onActivate = GameFlow.claimPending,
						})
					),
				}),
				scope:New("Frame")({
					Name = "Mastery",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 4,
					ZIndex = 42,
					[Children] = Kit.children(
						Kit.list(scope, { Padding = UDim.new(0, 4) }),
						scope:ForValues(masteryLines, function(_, innerScope: Kit.Scope, line: string)
							return Kit.caption(innerScope, {
								Text = line,
								Size = UDim2.new(1, 0, 0, 18),
								ZIndex = 43,
							})
						end)
					),
				}),
				Kit.caption(scope, {
					Name = "Contribution",
					Text = scope:Computed(function(use)
						return L("result.contribution") .. ": " .. use(contributionText)
					end),
					Visible = scope:Computed(function(use)
						return use(contributionText) ~= ""
					end),
					Size = UDim2.new(1, 0, 0, 18),
					LayoutOrder = 5,
					ZIndex = 42,
				}),
				scope:New("Frame")({
					Name = "Actions",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 56),
					LayoutOrder = 6,
					ZIndex = 42,
					[Children] = Kit.children(
						Kit.list(scope, {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 10),
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Kit.button(scope, {
							name = "Menu",
							text = L("result.menu"),
							kind = "secondary",
							size = UDim2.fromOffset(200, 52),
							layoutOrder = 1,
							zIndex = 43,
							onActivate = function()
								Atoms.matchResult(nil)
								GameFlow.leaveMatch()
							end,
						}),
						Kit.button(scope, {
							name = "Rematch",
							text = L("result.rematch"),
							kind = "primary",
							icon = "ui_play",
							size = UDim2.fromOffset(240, 52),
							layoutOrder = 2,
							zIndex = 43,
							onActivate = function()
								GameFlow.rematch(true)
								Actions.toast(L("result.rematch"), "info")
							end,
						})
					),
				})
			),
		})),
	})
end
