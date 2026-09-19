--!strict
-- Fila de avisos curtos (no máximo três, 2,5 s cada). Nunca bloqueia nem rouba foco.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local ACCENT: { [string]: Color3 } = {
	info = Theme.colors.cyan,
	success = Theme.colors.teal,
	error = Theme.colors.danger,
}

local ICON: { [string]: string } = {
	info = "ui_check",
	success = "ui_check",
	error = "ui_error",
}

return function(scope: Kit.Scope): Frame
	local toasts = Bridge.use(scope, Atoms.toasts)

	return scope:New("Frame")({
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 360, 1, -120),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		Active = false,
		ZIndex = 50,
		[Children] = Kit.children(
			Kit.list(scope, {
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			scope:ForValues(toasts, function(_, innerScope: Kit.Scope, toast: Atoms.Toast)
				local accent = ACCENT[toast.kind] or Theme.colors.cyan
				local iconChild = Kit.icon(innerScope, ICON[toast.kind] or "ui_check", 20, {
					LayoutOrder = 1,
					ImageColor3 = accent,
					ZIndex = 52,
				})
				local children: { any } = {
					Kit.list(innerScope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Kit.text(innerScope, {
						Text = toast.text,
						TextSize = 15,
						Font = Theme.fonts.bodyMedium,
						TextColor3 = Theme.colors.cream,
						Size = UDim2.new(0, 260, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = 2,
						ZIndex = 52,
					}),
				}
				if iconChild then
					table.insert(children, iconChild)
				end
				return Kit.panel(innerScope, {
					name = "Toast" .. tostring(toast.id),
					size = UDim2.new(0, 320, 0, 0),
					automaticSize = Enum.AutomaticSize.Y,
					color = Theme.colors.ink,
					strokeColor = accent,
					radius = Kit.radius.chip,
					padding = 12,
					paddingVertical = 10,
					gloss = false,
					zIndex = 51,
					children = children,
				})
			end)
		),
	})
end
