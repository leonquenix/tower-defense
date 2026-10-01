--!strict
-- Tela de entrada, montada sobre a ilustração de marca: o fundo é desenhado pela camada de
-- cenário (UI/App), e aqui ficam só o logotipo, a pilha de botões e as duas fichas de canto.
--
-- Tudo vem dos átomos: saldo de botões, equipe salva e estado do perfil. Nenhum texto fixo em
-- português mora aqui — as frases saem de Config/Localization. Se o logotipo ainda não estiver
-- publicado (Config/Brand), a tela desenha o título em texto, sem erro e sem buraco.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Brand = require(ReplicatedStorage.Shared.Config.Brand)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

local COLUMN_WIDTH = 560
local LOGO_WIDTH = 430

-- Marca: a arte quando existe, o título escrito quando não existe.
local function brandMark(scope: Kit.Scope, compact: Kit.Used<boolean>): GuiObject
	local logo = Brand.logo
	if logo and logo.image then
		return scope:New("ImageLabel")({
			Name = "Logo",
			BackgroundTransparency = 1,
			Image = logo.image :: string,
			ScaleType = Enum.ScaleType.Fit,
			Size = scope:Computed(function(use)
				local width = if Kit.read(use, compact) then LOGO_WIDTH * 0.78 else LOGO_WIDTH
				return UDim2.fromOffset(width, width / logo.aspect)
			end),
			LayoutOrder = 1,
			ZIndex = 3,
		})
	end
	return Kit.title(scope, {
		Name = "Title",
		Text = string.upper(L("app.title")),
		TextSize = 60,
		TextColor3 = Theme.colors.cream,
		Size = UDim2.new(1, 0, 0, 72),
		LayoutOrder = 1,
		ZIndex = 3,
	})
end

return function(scope: Kit.Scope, props: Props): Frame
	local buttons = Bridge.map(scope, Atoms.profile, function()
		return Selectors.buttons()
	end)
	local profileStatus = Bridge.use(scope, Atoms.profileStatus)
	local profileState = Bridge.use(scope, Atoms.profile)
	local compact = Bridge.use(scope, Atoms.compact)
	local team = Bridge.map(scope, Atoms.profile, function(): string
		local names: { string } = {}
		for _, towerId in ipairs(Selectors.loadout()) do
			local def = Catalog.getTower(towerId)
			if def then
				table.insert(names, def.name)
			end
		end
		if #names == 0 then
			return L("menu.teamEmpty")
		end
		return L("menu.teamReady", { team = table.concat(names, " · ") })
	end)
	local profileBroken = scope:Computed(function(use)
		local status = use(profileStatus)
		return status ~= "ready" and status ~= "volatile"
	end)
	local column = scope:New("Frame")({
		Name = "Brand",
		BackgroundTransparency = 1,
		Size = scope:Computed(function(use)
			local width = if Kit.read(use, compact) then COLUMN_WIDTH * 0.82 else COLUMN_WIDTH
			return UDim2.new(0, width, 1, -72)
		end),
		Position = UDim2.fromOffset(48, 40),
		[Children] = Kit.children(
			Kit.list(scope, { Padding = UDim.new(0, 12) }),
			brandMark(scope, compact),
			Kit.text(scope, {
				Name = "Subtitle",
				Text = "— " .. L("app.subtitle") .. " —",
				TextSize = 20,
				TextColor3 = Theme.colors.cream,
				Font = Theme.fonts.bodyBold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(0, LOGO_WIDTH, 0, 28),
				LayoutOrder = 2,
				ZIndex = 3,
			}),
			-- Aviso de perfil indisponível: explica e oferece saída, sem bloquear a tela.
			Kit.panel(scope, {
				name = "ProfileWarning",
				visible = profileBroken,
				size = UDim2.new(1, 0, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
				color = Theme.colors.dangerSoft,
				strokeColor = Theme.colors.danger,
				radius = Kit.radius.chip,
				padding = 14,
				layoutOrder = 3,
				gloss = false,
				layout = Kit.list(scope, { Padding = UDim.new(0, 8) }),
				children = Kit.children(
					Kit.text(scope, {
						Text = L("app.profileUnavailable"),
						TextColor3 = Theme.colors.danger,
						TextSize = 14,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = 1,
						ZIndex = 4,
					}),
					Kit.button(scope, {
						name = "Retry",
						text = L("common.retry"),
						kind = "danger",
						size = UDim2.new(0, 200, 0, 44),
						layoutOrder = 2,
						zIndex = 4,
						onActivate = GameFlow.retryProfile,
					})
				),
			}),
			-- Chamada principal: larga, dourada, com o subtítulo por baixo do rótulo.
			Kit.button(scope, {
				name = "Primary",
				text = L("menu.campaign"),
				sub = L("menu.campaignHint"),
				kind = "primary",
				icon = "ui_play",
				textSize = 26,
				size = UDim2.new(1, 0, 0, 84),
				layoutOrder = 4,
				zIndex = 3,
				onActivate = function()
					Actions.navigate("campaign")
				end,
			}),
			scope:New("Frame")({
				Name = "Row",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 68),
				LayoutOrder = 5,
				ZIndex = 3,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 12),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Kit.button(scope, {
						name = "Collection",
						text = L("menu.collection"),
						sub = L("menu.collectionHint"),
						kind = "cyan",
						size = UDim2.new(0.5, -6, 1, 0),
						layoutOrder = 1,
						zIndex = 4,
						onActivate = function()
							Actions.navigate("collection")
						end,
					}),
					Kit.button(scope, {
						name = "Training",
						text = L("menu.training"),
						sub = L("menu.trainingHint"),
						kind = "secondary",
						size = UDim2.new(0.5, -6, 1, 0),
						layoutOrder = 2,
						zIndex = 4,
						onActivate = function()
							GameFlow.startTraining("jardim")
						end,
					})
				),
			}),
			scope:New("Frame")({
				Name = "Row2",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 64),
				LayoutOrder = 6,
				ZIndex = 3,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 12),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Kit.button(scope, {
						name = "Shop",
						text = L("menu.shop"),
						sub = L("menu.shopHint"),
						kind = "dark",
						textSize = 17,
						size = UDim2.new(0.5, -6, 1, 0),
						layoutOrder = 1,
						zIndex = 4,
						onActivate = function()
							Actions.push("shop")
						end,
					}),
					Kit.button(scope, {
						name = "Settings",
						text = L("menu.settings"),
						sub = L("menu.settingsHint"),
						kind = "dark",
						icon = "ui_settings",
						textSize = 17,
						size = UDim2.new(0.5, -6, 1, 0),
						layoutOrder = 2,
						zIndex = 4,
						onActivate = function()
							Actions.push("settings")
						end,
					})
				),
			})
		),
	})

	-- Fichas de canto: nível da conta (com a barra dentro do nível) e saldo de botões.
	local levelChip = Kit.chip(scope, {
		name = "Level",
		icon = "ui_upgrade",
		caption = scope:Computed(function(use)
			local _ = use(profileState)
			local profile = Atoms.profile()
			if profile and profile.levelMaxed then
				return L("level.max")
			end
			return L("level.xp", {
				into = if profile then (profile.levelInto or 0) else 0,
				needed = if profile then (profile.levelNeeded or 0) else 0,
			})
		end),
		value = scope:Computed(function(use)
			local _ = use(profileState)
			return L("level.label", { level = Selectors.level() })
		end),
		accent = Theme.colors.cyan,
		progress = scope:Computed(function(use)
			local _ = use(profileState)
			return Selectors.levelProgress()
		end),
		width = UDim2.new(0, 0, 0, 56),
		layoutOrder = 1,
	})
	local balance = Kit.chip(scope, {
		name = "Buttons",
		icon = "ui_buttons",
		caption = L("common.buttons"),
		value = scope:Computed(function(use)
			return tostring(use(buttons))
		end),
		accent = Theme.colors.gold,
		width = UDim2.new(0, 0, 0, 56),
		layoutOrder = 2,
	})
	local corner = scope:New("Frame")({
		Name = "Corner",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -40, 0, 32),
		AnchorPoint = Vector2.new(1, 0),
		[Children] = Kit.children(
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 10),
			}),
			levelChip,
			balance
		),
	})

	-- Painel "Hoje": recompensa diária, presentes da sessão e as fichas guardadas. É o motivo de
	-- abrir o jogo amanhã e de ficar mais um pouco hoje; o servidor confere tudo no resgate.
	local clock = scope:Value(os.clock())
	local ticker = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - Fusion.peek(clock) >= 1 then
			clock:set(now)
		end
	end)
	table.insert(scope, ticker)
	local daily = scope:Computed(function(use): { [string]: any }
		local _ = use(profileState)
		local profile = Atoms.profile()
		return if profile and profile.daily then profile.daily else { available = false, dayIndex = 1 }
	end)
	local gift = scope:Computed(function(use): Selectors.GiftState?
		local _ = use(profileState)
		return Selectors.nextGift(use(clock))
	end)
	local function clockText(seconds: number): string
		local total = math.max(math.ceil(seconds), 0)
		return string.format("%d:%02d", total // 60, total % 60)
	end
	local rowText = function(props: { name: string, text: Kit.Used<string>, order: number }): TextLabel
		return Kit.text(scope, {
			Name = props.name,
			Text = props.text,
			Font = Theme.fonts.bodyBold,
			TextSize = 15,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = props.order,
			ZIndex = 6,
		})
	end
	local today = Kit.panel(scope, {
		name = "Today",
		size = UDim2.new(0, 300, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		position = UDim2.new(1, -40, 0, 104),
		anchorPoint = Vector2.new(1, 0),
		color = Theme.colors.paper,
		radius = Kit.radius.chip,
		padding = 14,
		paddingVertical = 12,
		zIndex = 5,
		visible = scope:Computed(function(use)
			return not use(profileBroken)
		end),
		layout = Kit.list(scope, { Padding = UDim.new(0, 8) }),
		children = Kit.children(
			Kit.title(scope, {
				Text = L("menu.today"),
				TextSize = 20,
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = 1,
				ZIndex = 6,
			}),
			rowText({
				name = "DailyText",
				order = 2,
				text = scope:Computed(function(use)
					local state = use(daily)
					return L("daily.title") .. " · " .. L("daily.day", { day = state.dayIndex or 1 })
				end),
			}),
			Kit.button(scope, {
				name = "Daily",
				text = scope:Computed(function(use)
					return if use(daily).available then L("daily.claim") else L("daily.claimed")
				end),
				sub = scope:Computed(function(use)
					local state = use(daily)
					local bundle = Balance.retention.dailyRewards[state.dayIndex or 1]
					return if state.available then Selectors.rewardText(bundle) else ""
				end),
				kind = scope:Computed(function(use)
					return if use(daily).available then "primary" else "quiet"
				end),
				disabled = scope:Computed(function(use)
					return not use(daily).available
				end),
				size = UDim2.new(1, 0, 0, 52),
				layoutOrder = 3,
				zIndex = 6,
				onActivate = GameFlow.claimDaily,
			}),
			rowText({ name = "GiftText", order = 4, text = L("gifts.title") }),
			Kit.button(scope, {
				name = "Gift",
				text = scope:Computed(function(use): string
					local state = use(gift)
					if not state then
						return L("gifts.done")
					end
					return if state.ready
						then L("gifts.open")
						else L("gifts.next", { time = clockText(state.secondsLeft) })
				end),
				sub = scope:Computed(function(use)
					local state = use(gift)
					if not state then
						return ""
					end
					local def = Balance.retention.sessionGifts[state.index]
					return Selectors.rewardText(def)
				end),
				kind = scope:Computed(function(use)
					local state = use(gift)
					return if state and state.ready then "primary" else "quiet"
				end),
				disabled = scope:Computed(function(use)
					local state = use(gift)
					return not (state and state.ready)
				end),
				size = UDim2.new(1, 0, 0, 52),
				layoutOrder = 5,
				zIndex = 6,
				onActivate = function()
					local state = Fusion.peek(gift)
					if state and state.ready then
						GameFlow.claimGift(state.index)
					end
				end,
			}),
			Kit.caption(scope, {
				Name = "Inventory",
				Text = scope:Computed(function(use)
					local _ = use(profileState)
					return L("inventory.summary", {
						retry = Selectors.itemCount("retry"),
						support = Selectors.itemCount("support"),
					})
				end),
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 6,
				ZIndex = 6,
			})
		),
	})

	-- Equipe salva no canto inferior direito: texto e os retratos das torres equipadas.
	local teamIcons = scope:ForValues(
		Bridge.map(scope, Atoms.profile, function()
			return Selectors.loadout()
		end),
		function(_, innerScope: Kit.Scope, towerId: string)
			local entry = Assets.get(Assets.towerKey(towerId, "L0"))
			return innerScope:New("ImageLabel")({
				Name = "Tower_" .. towerId,
				BackgroundTransparency = 1,
				Image = if entry then (entry.portrait or entry.image or "") else "",
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(34, 34),
				ZIndex = 6,
			})
		end
	)

	local teamPill = Kit.panel(scope, {
		name = "Team",
		size = UDim2.new(0, 0, 0, 52),
		automaticSize = Enum.AutomaticSize.X,
		position = UDim2.new(1, -40, 1, -32),
		anchorPoint = Vector2.new(1, 1),
		color = Theme.colors.paper,
		radius = Kit.radius.chip,
		padding = 16,
		paddingVertical = 8,
		zIndex = 5,
		layout = Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		children = Kit.children(
			Kit.text(scope, {
				Name = "TeamText",
				Text = team,
				TextColor3 = Theme.colors.ink,
				Font = Theme.fonts.bodyBold,
				TextSize = 15,
				TextWrapped = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = 1,
				ZIndex = 6,
			}),
			scope:New("Frame")({
				Name = "Icons",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 0, 34),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 2,
				ZIndex = 6,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 6),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					teamIcons
				),
			})
		),
	})

	return scope:New("Frame")({
		Name = "MainMenu",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.visible,
		[Children] = Kit.children(column, corner, today, teamPill),
	})
end
