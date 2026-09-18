--!strict
-- 01_entrada, 26_conexao e 42_recuperacao: entrada da experiência e recuperação de falhas.
--
-- Contrato:
--  * texto por etapa, nunca porcentagem inventada;
--  * depois de 10 s reais aparecem "Tentar novamente" e "Treino"; o tempo limite não cria perfil vazio;
--  * uma tentativa pendente por vez;
--  * perfil indisponível vira a variante 26 (mesma tela, outro conteúdo) — sem navegação duplicada;
--  * falha de imagem não bloqueia: o jogo segue com nome e silhueta local.
local Localization = require(game:GetService("ReplicatedStorage").Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Store = require(script.Parent.Parent.Store)

local Boot = {}
Boot.__index = Boot

local L = Localization.get

local RECOVERY_AFTER = 10 -- segundos reais até oferecer recuperação

export type Callbacks = {
	onTraining: () -> (),
	onSettings: () -> (),
}

export type Boot = typeof(setmetatable(
	{} :: {
		root: Frame,
		panel: Frame,
		stepLabel: TextLabel,
		detailLabel: TextLabel,
		retry: Components.Button,
		training: Components.Button,
		settings: Components.Button,
		callbacks: Callbacks,
		shownAt: number,
		steps: { string },
		recoveryVisible: boolean,
		ticker: thread?,
	},
	Boot
))

function Boot.new(parent: Instance, callbacks: Callbacks): Boot
	local root = Components.frame(parent, "Boot", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.sage,
		Visible = false,
	})
	local panel = Components.panel(root, "Panel", {
		Size = UDim2.new(0, 520, 0, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	}, { tape = true, shadow = false })
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(520, 460)
	maxSize.MinSize = Vector2.new(280, 0)
	maxSize.Parent = panel
	Components.padding(panel, 24, 22)
	local layout = Components.list(panel, Enum.FillDirection.Vertical, 12)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	Components.title(panel, "Title", L("app.title"), {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 34,
		LayoutOrder = 1,
		ZIndex = 3,
	})
	local stepLabel = Components.label(panel, "Step", L("boot.profile"), {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.fonts.bodyMedium,
		LayoutOrder = 2,
		ZIndex = 3,
	})
	local detailLabel = Components.caption(panel, "Detail", "", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		ZIndex = 3,
	})
	local actions = Components.frame(panel, "Actions", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		ZIndex = 3,
	})
	Components.list(actions, Enum.FillDirection.Horizontal, 10)

	local self = setmetatable({
		root = root,
		panel = panel,
		stepLabel = stepLabel,
		detailLabel = detailLabel,
		callbacks = callbacks,
		shownAt = os.clock(),
		steps = {},
		recoveryVisible = false,
		ticker = nil,
	}, Boot) :: any

	self.retry = Components.button(actions, {
		name = "Retry",
		text = L("common.retry"),
		kind = "primary",
		size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		zIndex = 4,
		visible = false,
		onActivate = function()
			Boot.requestRetry(self)
		end,
	})
	self.training = Components.button(actions, {
		name = "Training",
		text = L("boot.training"),
		kind = "secondary",
		size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
		layoutOrder = 2,
		zIndex = 4,
		visible = false,
		onActivate = callbacks.onTraining,
	})
	self.settings = Components.button(actions, {
		name = "Settings",
		text = L("menu.settings"),
		kind = "ghost",
		icon = "ui_settings",
		size = UDim2.fromOffset(190, Theme.sizes.buttonTarget),
		layoutOrder = 3,
		zIndex = 4,
		onActivate = callbacks.onSettings,
	})
	return self
end

-- Uma tentativa pendente por vez: o botão fica em "Confirmando" até a resposta.
function Boot.requestRetry(self: Boot)
	if CommandAdapter.isPending("boot:retry") then
		return
	end
	self.retry:setPending(true)
	CommandAdapter.send("boot:retry", "RetryProfile", {}, {
		onSuccess = function()
			self.retry:setPending(false)
			self.detailLabel.Text = L("boot.retrying")
		end,
		onError = function(code)
			self.retry:setPending(false)
			self.retry:showError(L("boot.retryFailed"))
			self.detailLabel.Text = if Localization.has("error." .. code)
				then L("error." .. code)
				else L("error.UNKNOWN")
		end,
	})
end

-- `steps` são etapas reais já resolvidas (perfil, mapa, elenco, chefe): sem porcentagem inventada.
function Boot.setSteps(self: Boot, steps: { string })
	self.steps = steps
	self.stepLabel.Text = if #steps == 0 then L("boot.profile") else steps[#steps]
end

function Boot.update(self: Boot)
	if not self.root.Visible then
		return
	end
	local status = Store.get().profileStatus
	local elapsed = os.clock() - self.shownAt
	local unavailable = status ~= "loading" and Store.profile() == nil

	if unavailable then
		-- variante 26: perfil indisponível com duas saídas claras e nenhum default persistido
		self.stepLabel.Text = L("app.profileUnavailable")
		self.detailLabel.Text = L("boot.noDefaults")
		self.retry.instance.Visible = true
		self.training.instance.Visible = true
		self.recoveryVisible = true
		return
	end

	if elapsed >= RECOVERY_AFTER and not self.recoveryVisible then
		-- 42: demora reconhecida, com recuperação e alternativa, sem declarar falha
		self.recoveryVisible = true
		self.retry.instance.Visible = true
		self.training.instance.Visible = true
		self.detailLabel.Text = L("boot.slow")
	end
	if not self.recoveryVisible then
		self.detailLabel.Text = L("boot.pleaseWait")
	end
end

function Boot.show(self: Boot)
	self.root.Visible = true
	self.shownAt = os.clock()
	self.recoveryVisible = false
	self.retry.instance.Visible = false
	self.training.instance.Visible = false
	self.retry:clearResult()
	Boot.update(self)
end

function Boot.hide(self: Boot)
	self.root.Visible = false
end

return Boot
