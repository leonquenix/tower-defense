--!strict
-- Moldura compartilhada das telas de menu: fundo verde suave com decoração não interativa,
-- topo fixo com Voltar, título e saldo de botões, e corpo rolável.
--
-- O topo e o Voltar permanecem fixos; menus de dados viram listas roláveis (guia, prancha 35).
-- A decoração fica fora das áreas de toque.
local Localization = require(game:GetService("ReplicatedStorage").Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Responsive = require(script.Parent.Parent.Parent.View.Responsive)
local Components = require(script.Parent.Parent.Components)
local Store = require(script.Parent.Parent.Store)

local Chrome = {}

local L = Localization.get

export type Screen = {
	root: Frame,
	body: Frame,
	top: Frame,
	backButton: Components.Button?,
	titleLabel: TextLabel,
	balanceChip: Components.Chip,
	statusLabel: TextLabel,
	setTitle: (self: Screen, text: string, subtitle: string?) -> (),
	refreshBalance: (self: Screen) -> (),
	compactHeight: (self: Screen) -> number,
	show: (self: Screen) -> (),
	hide: (self: Screen) -> (),
	clearBody: (self: Screen) -> (),
	destroy: (self: Screen) -> (),
}

-- Círculos claros do fundo (prancha 02): puramente decorativos, Active=false.
local function decorate(root: Frame)
	local decor = Components.frame(root, "Decor", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
	})
	decor.Active = false
	local blobs = {
		{ UDim2.fromScale(0.86, -0.18), UDim2.fromOffset(420, 420) },
		{ UDim2.fromScale(-0.12, 0.62), UDim2.fromOffset(320, 320) },
		{ UDim2.fromScale(0.62, 0.78), UDim2.fromOffset(260, 260) },
	}
	for index, blob in ipairs(blobs) do
		local circle = Components.frame(decor, "Blob" .. index, {
			Position = blob[1],
			Size = blob[2],
			BackgroundColor3 = Theme.colors.sageDeep,
			BackgroundTransparency = 0.45,
			ZIndex = 0,
		})
		circle.Active = false
		Components.corner(circle, 999)
	end
end

export type Options = {
	name: string,
	title: string,
	subtitle: string?,
	showBack: boolean?,
	showBalance: boolean?,
	onBack: (() -> ())?,
	bodyPadding: number?,
}

function Chrome.new(parent: Instance, options: Options): Screen
	local compact = Responsive.isCompact()
	local root = Components.frame(parent, options.name, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.sage,
		Visible = false,
	})
	decorate(root)

	local topHeight = if compact then 52 else 68
	local top = Components.frame(root, "Top", {
		Size = UDim2.new(1, -32, 0, topHeight),
		Position = UDim2.new(0, 16, 0, 12),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})

	local left = 0
	local backButton: Components.Button? = nil
	if options.showBack ~= false and options.onBack then
		backButton = Components.button(top, {
			name = "Back",
			text = L("common.back"),
			kind = "secondary",
			icon = "ui_back",
			size = UDim2.fromOffset(if compact then 112 else 128, Theme.sizes.buttonTarget),
			position = UDim2.fromOffset(0, 4),
			textSize = Theme.sizes.body,
			textAlign = Enum.TextXAlignment.Left,
			onActivate = options.onBack,
		})
		left = if compact then 124 else 142
	end

	local titleLabel = Components.title(top, "Title", options.title, {
		Size = UDim2.new(1, -(left + 220), 0, if compact then 30 else 38),
		Position = UDim2.fromOffset(left, if compact then 2 else 4),
		TextSize = if compact then 22 else Theme.sizes.title,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	})
	local subtitleLabel = Components.caption(top, "Subtitle", options.subtitle or "", {
		Size = UDim2.new(1, -(left + 220), 0, 18),
		Position = UDim2.fromOffset(left, if compact then 30 else 40),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = (options.subtitle or "") ~= "",
		ZIndex = 4,
	})

	local balanceChip = Components.statChip(top, "Balance", L("common.buttons"), {
		Size = UDim2.fromOffset(10, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, 0, 0, 6),
		AnchorPoint = Vector2.new(1, 0),
		Visible = options.showBalance ~= false,
		ZIndex = 4,
	}, "ui_buttons")

	-- Aviso persistente de perfil não salvo: nunca some sozinho e não é toast.
	local statusLabel = Components.caption(root, "Status", "", {
		Size = UDim2.new(1, -32, 0, 18),
		Position = UDim2.new(0, 16, 0, topHeight + 14),
		TextColor3 = Theme.colors.danger,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		ZIndex = 4,
	})

	local body = Components.frame(root, "Body", {
		Size = UDim2.new(1, -32, 1, -(topHeight + 28)),
		Position = UDim2.new(0, 16, 0, topHeight + 20),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})

	local self = {} :: Screen
	self.root = root
	self.top = top
	self.body = body
	self.backButton = backButton
	self.titleLabel = titleLabel
	self.balanceChip = balanceChip
	self.statusLabel = statusLabel

	function self.setTitle(_, text: string, subtitle: string?)
		titleLabel.Text = text
		subtitleLabel.Text = subtitle or ""
		subtitleLabel.Visible = (subtitle or "") ~= ""
	end

	function self.refreshBalance(_)
		local profile = Store.profile()
		if profile then
			balanceChip:setValue(tostring(profile.buttons or 0))
			balanceChip.instance.Visible = options.showBalance ~= false
		else
			balanceChip.instance.Visible = false
		end
		local status = Store.get().profileStatus
		if profile and not Store.isPersistent() then
			statusLabel.Text = L("app.progressNotSaved")
			statusLabel.Visible = true
		elseif not profile and status ~= "loading" then
			statusLabel.Text = L("app.profileUnavailableShort")
			statusLabel.Visible = true
		else
			statusLabel.Visible = false
		end
	end

	function self.compactHeight(_): number
		return topHeight
	end

	function self.clearBody(_)
		for _, child in ipairs(body:GetChildren()) do
			child:Destroy()
		end
	end

	function self.show(_)
		root.Visible = true
		self:refreshBalance()
	end

	function self.hide(_)
		root.Visible = false
	end

	function self.destroy(_)
		if backButton then
			backButton:destroy()
		end
		root:Destroy()
	end

	return self
end

return Chrome
