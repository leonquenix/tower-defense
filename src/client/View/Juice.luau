--!strict
-- "Suco" do combate: tremor, clarão, partículas, números que saltam e pulos de escala.
--
-- Nada aqui decide jogo. Todo efeito é disparado por um evento que o servidor já confirmou
-- (impacto, morte, vazamento) e pode ser desligado inteiro pelas preferências de conforto:
-- movimento reduzido tira deslocamento e tremor; partículas reduzidas tira os cacos.
--
-- Números e durações estão em Config/UiMotion (juice_*), gerado do pacote de UI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiMotion = require(ReplicatedStorage.Shared.Config.UiMotion)
local Theme = require(script.Parent.Theme)
local Accessibility = require(script.Parent.Parent.UI.Accessibility)

local Juice = {}

local board: GuiObject? = nil
local boardBase: UDim2? = nil
local shakeToken = 0

local function recipe(id: string): UiMotion.Recipe
	local found = UiMotion[id]
	assert(found, `receita de animação desconhecida: {id}`)
	return found
end

local function info(id: string, duration: number?): TweenInfo
	local r = recipe(id)
	return TweenInfo.new(
		duration or r.duration,
		(Enum.EasingStyle :: any)[r.style],
		(Enum.EasingDirection :: any)[r.direction]
	)
end

-- ---------------------------------------------------------------------------
-- Tabuleiro
-- ---------------------------------------------------------------------------

function Juice.setBoard(frame: GuiObject?)
	board = frame
	boardBase = if frame then frame.Position else nil
	shakeToken += 1
end

-- Tremor curto com amplitude decrescente. `intensity` 0..1 escala o deslocamento.
-- Com movimento reduzido, o tremor vira um piscar de borda (nada se move).
function Juice.shakeBoard(intensity: number)
	local frame = board
	local base = boardBase
	if not frame or not base then
		return
	end
	if Accessibility.reducedMotion() then
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			local original = stroke.Color
			stroke.Color = Theme.colors.danger
			task.delay(0.12, function()
				stroke.Color = original
			end)
		end
		return
	end
	shakeToken += 1
	local token = shakeToken
	local duration = recipe("juice_shake").duration
	local amplitude = 10 * math.clamp(intensity, 0, 1)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			if shakeToken ~= token or not frame.Parent then
				break
			end
			local decay = 1 - (elapsed / duration)
			local offsetX = (math.random() - 0.5) * 2 * amplitude * decay
			local offsetY = (math.random() - 0.5) * 2 * amplitude * decay
			frame.Position = base + UDim2.fromOffset(offsetX, offsetY)
			elapsed += task.wait(0.03)
		end
		if shakeToken == token then
			frame.Position = base
		end
	end)
end

-- Clarão vermelho sobre o tabuleiro quando o Farol leva dano.
function Juice.damageFlash()
	local frame = board
	if not frame then
		return
	end
	local flash = Instance.new("Frame")
	flash.Name = "DamageFlash"
	flash.BackgroundColor3 = Theme.colors.danger
	flash.BackgroundTransparency = 0.55
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 5000
	flash.Active = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = flash
	flash.Parent = frame
	local tween = TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		flash:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Efeitos pontuais
-- ---------------------------------------------------------------------------

export type BurstOptions = {
	count: number?,
	color: Color3?,
	spread: number?, -- deslocamento máximo em fração do pai
	size: number?, -- lado da partícula em fração do pai
	rise: number?,
}

-- Leque de partículas a partir de um ponto (morte, impacto, construção).
function Juice.burst(parent: GuiObject, position: UDim2, options: BurstOptions?)
	if Accessibility.get().reducedParticles then
		return
	end
	local opts: BurstOptions = options or {}
	local count = opts.count or 6
	local spread = opts.spread or 0.05
	local size = opts.size or 0.012
	local rise = opts.rise or 0.04
	local duration = recipe("juice_burst").duration
	for index = 1, count do
		local particle = Instance.new("Frame")
		particle.Name = "Spark"
		particle.BackgroundColor3 = opts.color or Theme.colors.gold
		particle.BorderSizePixel = 0
		particle.AnchorPoint = Vector2.new(0.5, 0.5)
		particle.Position = position
		particle.Size = UDim2.fromScale(size, size * 1.6)
		particle.ZIndex = 3000
		particle.Active = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = particle
		particle.Parent = parent
		local angle = (index / count) * math.pi * 2 + math.random() * 0.4
		local distance = spread * (0.6 + math.random() * 0.6)
		local target = position + UDim2.fromScale(math.cos(angle) * distance, math.sin(angle) * distance * 0.7 - rise)
		local tween = TweenService:Create(
			particle,
			info("juice_burst"),
			{ Position = target, BackgroundTransparency = 1, Size = UDim2.fromScale(size * 0.4, size * 0.4) }
		)
		tween:Play()
		tween.Completed:Once(function()
			particle:Destroy()
		end)
	end
	local _ = duration
end

-- Anel de impacto que cresce e some.
function Juice.ring(parent: GuiObject, position: UDim2, fromScale: number, toScale: number, color: Color3)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = position
	ring.Size = UDim2.fromScale(fromScale, fromScale)
	ring.ZIndex = 2900
	ring.Active = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = ring
	ring.Parent = parent
	local grow = TweenService:Create(
		ring,
		TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(toScale, toScale) }
	)
	grow:Play()
	TweenService:Create(stroke, TweenInfo.new(0.32), { Transparency = 1 }):Play()
	grow.Completed:Once(function()
		ring:Destroy()
	end)
end

-- Clarão branco curto sobre um sprite atingido (sem deformar quando o movimento é reduzido).
function Juice.hitFlash(image: ImageLabel)
	local original = image.ImageColor3
	image.ImageColor3 = Color3.new(1, 1, 1)
	local tween = TweenService:Create(image, info("juice_hit"), { ImageColor3 = original })
	tween:Play()
end

-- Salto de escala (cartas, fichas, torre recém-construída).
function Juice.pop(target: GuiObject, from: number?)
	if Accessibility.reducedMotion() then
		return
	end
	local existing = target:FindFirstChildOfClass("UIScale")
	local uiScale: UIScale
	if existing then
		uiScale = existing
	else
		uiScale = Instance.new("UIScale")
		uiScale.Parent = target
	end
	uiScale.Scale = from or 0.86
	TweenService:Create(uiScale, info("juice_pop"), { Scale = 1 }):Play()
end

-- Número que sobe em arco e some (dano, cura, sucata ganha).
function Juice.floatText(parent: GuiObject, position: UDim2, text: string, color: Color3, big: boolean?)
	local label = Instance.new("TextLabel")
	label.Name = "Float"
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Theme.fonts.numbers
	label.TextSize = if big then 28 else 20
	label.TextColor3 = color
	label.TextStrokeColor3 = Theme.colors.inkDeep
	label.TextStrokeTransparency = 0.2
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = position
	label.Size = UDim2.fromScale(0.12, 0.06)
	label.TextScaled = true
	label.ZIndex = 3100
	label.Parent = parent

	local drift = (math.random() - 0.5) * 0.04
	local target = position + UDim2.fromScale(drift, -0.08)
	if Accessibility.reducedMotion() then
		task.delay(0.25, function()
			label:Destroy()
		end)
		return
	end
	local rise = TweenService:Create(label, info("juice_float"), { Position = target, TextTransparency = 1 })
	rise:Play()
	TweenService:Create(label, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.16, 0.08),
	}):Play()
	rise.Completed:Once(function()
		label:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Auxiliares puros (testáveis fora do Studio)
-- ---------------------------------------------------------------------------

-- Curva do arco usado pelos números de dano: sobe rápido e desacelera.
function Juice.arc(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return 1 - (1 - clamped) * (1 - clamped)
end

-- Amplitude do tremor no instante t (0..1). Decai linearmente até zero.
function Juice.shakeAmplitude(t: number, intensity: number): number
	local clamped = math.clamp(t, 0, 1)
	return math.max(0, (1 - clamped)) * 10 * math.clamp(intensity, 0, 1)
end

return Juice
