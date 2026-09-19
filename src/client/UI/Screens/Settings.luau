--!strict
-- Configurações: áudio, conforto, Circuitos e idioma. Cada mudança vale na hora e é enviada
-- para o perfil; se a gravação falhar, a preferência continua valendo nesta sessão.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Commands = require(script.Parent.Parent.Parent.Net.Commands)
local SettingsController = require(script.Parent.Parent.Parent.Controllers.SettingsController)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

local function persist()
	local current = SettingsController.get()
	Commands.send("profile:settings", "SaveSettings", {
		musicVolume = current.musicVolume,
		sfxVolume = current.sfxVolume,
		reducedMotion = current.reducedMotion,
		reducedParticles = current.reducedParticles,
		damageNumbers = current.damageNumbers,
		circuitPattern = current.circuitPattern,
		locale = current.locale,
	}, nil)
end

return function(scope: Kit.Scope, props: Props): Frame
	local settings = Bridge.use(scope, Atoms.settings)

	local function readSetting<T>(field: string, fallback: T): Fusion.Computed<T>
		return scope:Computed(function(use): T
			local current: Types.ProfileSettings? = Kit.read(use, settings)
			if not current then
				return fallback
			end
			return (current :: any)[field]
		end)
	end

	-- Uma linha de opção: rótulo à esquerda, controle à direita.
	local function row(order: number, label: string, control: GuiObject): Frame
		return scope:New("Frame")({
			Name = "Row" .. tostring(order),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = order,
			ZIndex = 4,
			[Children] = Kit.children(
				Kit.list(scope, {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Kit.text(scope, {
					Text = label,
					Font = Theme.fonts.bodyMedium,
					Size = UDim2.new(0, 260, 1, 0),
					LayoutOrder = 1,
					ZIndex = 5,
				}),
				control
			),
		})
	end

	local function toggle(order: number, label: string, field: string): Frame
		local value = readSetting(field, false)
		return row(
			order,
			label,
			Kit.button(scope, {
				name = field,
				text = scope:Computed(function(use)
					return if use(value) then L("common.on") else L("common.off")
				end),
				kind = "secondary",
				selected = value,
				size = UDim2.fromOffset(160, 46),
				layoutOrder = 2,
				zIndex = 5,
				onActivate = function()
					SettingsController.set(field, not Fusion.peek(value))
					persist()
				end,
			})
		)
	end

	local function volume(order: number, label: string, field: string): Frame
		local value = readSetting(field, 0.5)
		local control = scope:New("Frame")({
			Name = field,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 360, 1, 0),
			LayoutOrder = 2,
			ZIndex = 5,
			[Children] = Kit.children(
				Kit.list(scope, {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Kit.button(scope, {
					name = "Down",
					text = "−",
					kind = "quiet",
					icon = "ui_minus",
					size = UDim2.fromOffset(56, 46),
					layoutOrder = 1,
					zIndex = 6,
					onActivate = function()
						SettingsController.set(field, math.max(0, Fusion.peek(value) - 0.1))
						persist()
					end,
				}),
				scope:New("Frame")({
					Name = "Meter",
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 180, 1, 0),
					LayoutOrder = 2,
					ZIndex = 6,
					[Children] = Kit.children(Kit.bar(scope, {
						value = value,
						color = Theme.colors.cyan,
						height = 12,
						size = UDim2.new(1, 0, 0, 12),
					})),
				}),
				Kit.button(scope, {
					name = "Up",
					text = "+",
					kind = "quiet",
					icon = "ui_plus",
					size = UDim2.fromOffset(56, 46),
					layoutOrder = 3,
					zIndex = 6,
					onActivate = function()
						SettingsController.set(field, math.min(1, Fusion.peek(value) + 0.1))
						persist()
					end,
				})
			),
		})
		return row(order, label, control)
	end

	local function choice(order: number, label: string, field: string, options: { { id: string, text: string } }): Frame
		local value = readSetting(field, options[1].id)
		local buttons: { any } = {
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		}
		for index, option in ipairs(options) do
			table.insert(
				buttons,
				Kit.button(scope, {
					name = option.id,
					text = option.text,
					kind = "secondary",
					selected = scope:Computed(function(use)
						return use(value) == option.id
					end),
					size = UDim2.fromOffset(190, 46),
					layoutOrder = index,
					zIndex = 6,
					onActivate = function()
						SettingsController.set(field, option.id)
						persist()
					end,
				})
			)
		end
		return row(
			order,
			label,
			scope:New("Frame")({
				Name = field,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 400, 1, 0),
				LayoutOrder = 2,
				ZIndex = 5,
				[Children] = buttons,
			})
		)
	end

	local screen = Kit.screen(scope, {
		name = "SettingsScreen",
		title = L("settings.title"),
		visible = props.visible,
		scroll = true,
		onBack = function()
			if not Actions.back() then
				Actions.navigate("menu")
			end
		end,
		bodyLayout = Kit.list(scope, { Padding = UDim.new(0, 10) }),
		children = Kit.children(
			Kit.panel(scope, {
				name = "Audio",
				size = UDim2.new(1, -16, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
				padding = 18,
				layoutOrder = 1,
				zIndex = 3,
				layout = Kit.list(scope, { Padding = UDim.new(0, 6) }),
				children = Kit.children(
					Kit.title(scope, {
						Text = L("settings.audio"),
						TextSize = 20,
						Size = UDim2.new(1, 0, 0, 26),
						LayoutOrder = 1,
						ZIndex = 4,
					}),
					volume(2, L("settings.music"), "musicVolume"),
					volume(3, L("settings.sfx"), "sfxVolume"),
					Kit.caption(scope, {
						Text = L("settings.audioMissing"),
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = 4,
						ZIndex = 4,
					})
				),
			}),
			Kit.panel(scope, {
				name = "Comfort",
				size = UDim2.new(1, -16, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
				padding = 18,
				layoutOrder = 2,
				zIndex = 3,
				layout = Kit.list(scope, { Padding = UDim.new(0, 6) }),
				children = Kit.children(
					Kit.title(scope, {
						Text = L("settings.comfort"),
						TextSize = 20,
						Size = UDim2.new(1, 0, 0, 26),
						LayoutOrder = 1,
						ZIndex = 4,
					}),
					toggle(2, L("settings.reducedMotion"), "reducedMotion"),
					toggle(3, L("settings.reducedParticles"), "reducedParticles"),
					toggle(4, L("settings.damageNumbers"), "damageNumbers"),
					choice(5, L("settings.circuitPattern"), "circuitPattern", {
						{ id = "solid", text = L("settings.circuitPattern.solid") },
						{ id = "dashed", text = L("settings.circuitPattern.dashed") },
					})
				),
			}),
			Kit.panel(scope, {
				name = "Language",
				size = UDim2.new(1, -16, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
				padding = 18,
				layoutOrder = 3,
				zIndex = 3,
				layout = Kit.list(scope, { Padding = UDim.new(0, 6) }),
				children = Kit.children(
					Kit.title(scope, {
						Text = L("settings.language"),
						TextSize = 20,
						Size = UDim2.new(1, 0, 0, 26),
						LayoutOrder = 1,
						ZIndex = 4,
					}),
					choice(2, L("settings.locale"), "locale", {
						{ id = "ptbr", text = L("settings.locale.ptbr") },
						{ id = "en", text = L("settings.locale.en") },
					})
				),
			})
		),
	})
	return screen.instance
end
