--!strict
-- Tela de entrada. É a vitrine da direção de arte: marca grande à esquerda, pilha de botões
-- com chanfro e, à direita, o mascote sobre um disco de papel com o Farol de Pilha ao lado.
--
-- Tudo vem dos átomos: saldo de botões, equipe salva e estado do perfil. Nenhum texto fixo em
-- português mora aqui — as frases saem de Config/Localization.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
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

local function heroImage(): string?
	local entry = Assets.get(Assets.towerKey("dardo", "L0"))
	if not entry then
		return nil
	end
	return entry.portrait or entry.image
end

return function(scope: Kit.Scope, props: Props): Frame
	local profile_ = Bridge.use(scope, Atoms.profile)
	local buttons = Bridge.map(scope, Atoms.profile, function()
		return Selectors.buttons()
	end)
	local profileStatus = Bridge.use(scope, Atoms.profileStatus)
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
	-- Quem já concluiu (ou pulou) o tutorial não precisa vê-lo como chamada principal.
	local tutorialDone = scope:Computed(function(use)
		local profile = use(profile_)
		return profile ~= nil and profile.tutorialCompleted == true
	end)

	local left = scope:New("Frame")({
		Name = "Brand",
		BackgroundTransparency = 1,
		Size = scope:Computed(function(use)
			return if use(compact) then UDim2.new(0.62, 0, 1, -40) else UDim2.new(0.52, 0, 1, -64)
		end),
		Position = UDim2.fromOffset(40, 32),
		[Children] = Kit.children(
			Kit.list(scope, { Padding = UDim.new(0, 14) }),
			Kit.tag(scope, {
				text = string.upper(L("app.tagline")),
				color = Theme.colors.paper,
				textColor = Theme.colors.tealDark,
				frame = { LayoutOrder = 1, ZIndex = 3 },
			}),
			Kit.title(scope, {
				Name = "Title",
				Text = string.upper(L("app.title")),
				TextSize = scope:Computed(function(use)
					return if use(compact) then 44 else 64
				end),
				TextColor3 = Theme.colors.ink,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				ZIndex = 3,
			}),
			Kit.text(scope, {
				Name = "Subtitle",
				Text = L("app.subtitle"),
				TextSize = 18,
				TextColor3 = Theme.colors.tealDark,
				Font = Theme.fonts.bodyMedium,
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = 3,
				ZIndex = 3,
			}),
			-- Aviso de perfil indisponível: explica e oferece saída, sem bloquear a tela.
			Kit.panel(scope, {
				name = "ProfileWarning",
				visible = profileBroken,
				size = UDim2.new(1, -20, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
				color = Theme.colors.dangerSoft,
				strokeColor = Theme.colors.danger,
				radius = Kit.radius.chip,
				padding = 14,
				layoutOrder = 4,
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
			-- Botão principal: tutorial para quem está começando, "Jogar" para quem já passou.
			Kit.button(scope, {
				name = "Primary",
				text = scope:Computed(function(use)
					return if use(tutorialDone) then L("menu.play") else L("menu.tutorial")
				end),
				sub = scope:Computed(function(use)
					return if use(tutorialDone) then L("menu.playHint") else L("menu.startTutorialHint")
				end),
				kind = "primary",
				icon = "ui_play",
				size = UDim2.new(1, -20, 0, 76),
				layoutOrder = 5,
				zIndex = 3,
				onActivate = function()
					if Fusion.peek(tutorialDone) then
						Actions.navigate("maps")
					else
						GameFlow.startTutorial()
					end
				end,
			}),
			scope:New("Frame")({
				Name = "Row",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -20, 0, 60),
				LayoutOrder = 6,
				ZIndex = 3,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 12),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Kit.button(scope, {
						name = "Play",
						text = scope:Computed(function(use)
							return if use(tutorialDone) then L("menu.replayTutorial") else L("menu.play")
						end),
						sub = scope:Computed(function(use)
							return if use(tutorialDone) then "" else L("menu.playHint")
						end),
						kind = "cyan",
						size = UDim2.new(0.5, -6, 1, 0),
						layoutOrder = 1,
						zIndex = 4,
						onActivate = function()
							if Fusion.peek(tutorialDone) then
								GameFlow.startTutorial()
							else
								Actions.navigate("maps")
							end
						end,
					}),
					Kit.button(scope, {
						name = "Collection",
						text = L("menu.collection"),
						kind = "secondary",
						size = UDim2.new(0.5, -6, 1, 0),
						layoutOrder = 2,
						zIndex = 4,
						onActivate = function()
							Actions.navigate("collection")
						end,
					})
				),
			}),
			scope:New("Frame")({
				Name = "Row2",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -20, 0, 56),
				LayoutOrder = 7,
				ZIndex = 3,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 12),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Kit.button(scope, {
						name = "Training",
						text = L("menu.training"),
						kind = "quiet",
						size = UDim2.new(0.34, -8, 1, 0),
						layoutOrder = 1,
						zIndex = 4,
						onActivate = function()
							GameFlow.startTraining("jardim")
						end,
					}),
					Kit.button(scope, {
						name = "Shop",
						text = L("menu.shop"),
						kind = "quiet",
						size = UDim2.new(0.33, -8, 1, 0),
						layoutOrder = 2,
						zIndex = 4,
						onActivate = function()
							Actions.push("shop")
						end,
					}),
					Kit.button(scope, {
						name = "Settings",
						text = L("menu.settings"),
						kind = "quiet",
						icon = "ui_settings",
						size = UDim2.new(0.33, -8, 1, 0),
						layoutOrder = 3,
						zIndex = 4,
						onActivate = function()
							Actions.push("settings")
						end,
					})
				),
			})
		),
	})

	local heroArt = heroImage()
	local right = scope:New("Frame")({
		Name = "Hero",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.42, 0, 1, -80),
		Position = UDim2.new(1, -40, 0, 40),
		AnchorPoint = Vector2.new(1, 0),
		Visible = scope:Computed(function(use)
			return not use(compact)
		end),
		[Children] = Kit.children(
			-- disco de papel atrás do mascote (o contorno grosso é marca da direção de arte)
			scope:New("Frame")({
				Name = "Disc",
				BackgroundColor3 = Theme.colors.paper,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0.86, 0.86),
				Position = UDim2.fromScale(0.5, 0.44),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 2,
				[Children] = Kit.children(
					Kit.corner(scope, 9999),
					Kit.stroke(scope, Theme.colors.ink, 3),
					scope:New("UIAspectRatioConstraint")({ AspectRatio = 1 }),
					if heroArt
						then scope:New("ImageLabel")({
							Name = "Mascot",
							BackgroundTransparency = 1,
							Image = heroArt,
							ScaleType = Enum.ScaleType.Fit,
							Size = UDim2.fromScale(0.78, 0.78),
							Position = UDim2.fromScale(0.5, 0.52),
							AnchorPoint = Vector2.new(0.5, 0.5),
							ZIndex = 3,
						})
						else Kit.title(scope, {
							Text = "★",
							TextSize = 64,
							TextXAlignment = Enum.TextXAlignment.Center,
							Size = UDim2.fromScale(1, 1),
							ZIndex = 3,
						})
				),
			}),
			scope:New("ImageLabel")({
				Name = "Lighthouse",
				BackgroundTransparency = 1,
				Image = Assets.image("base_farol_pilha") or "",
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.26, 0.26),
				Position = UDim2.fromScale(0.88, 0.78),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 4,
			}),
			Kit.panel(scope, {
				name = "Team",
				size = UDim2.new(0, 0, 0, 44),
				automaticSize = Enum.AutomaticSize.X,
				position = UDim2.fromScale(0.5, 0.96),
				anchorPoint = Vector2.new(0.5, 1),
				color = Theme.colors.teal,
				radius = Kit.radius.pill,
				padding = 18,
				paddingVertical = 8,
				zIndex = 5,
				children = Kit.children(Kit.text(scope, {
					Name = "TeamText",
					Text = team,
					TextColor3 = Theme.colors.ink,
					Font = Theme.fonts.bodyBold,
					TextSize = 15,
					TextWrapped = false,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
					ZIndex = 6,
				})),
			})
		),
	})

	local balance = Kit.chip(scope, {
		name = "Buttons",
		icon = "ui_buttons",
		caption = L("common.buttons"),
		value = scope:Computed(function(use)
			return tostring(use(buttons))
		end),
		accent = Theme.colors.gold,
		width = UDim2.new(0, 0, 0, 52),
	})
	balance.Position = UDim2.new(1, -40, 0, 32)
	balance.AnchorPoint = Vector2.new(1, 0)

	return scope:New("Frame")({
		Name = "MainMenu",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.visible,
		[Children] = Kit.children(left, right, balance),
	})
end
