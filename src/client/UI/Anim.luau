--!strict
-- Animações de interface guiadas por Config/UiMotion (gerado de dados/animacoes.json).
--
-- Regras do guia aplicadas aqui:
--  * cada propriedade tem um controlador: criar um tween cancela o anterior daquela propriedade;
--  * movimento reduzido troca deslocamento/escala por preenchimento e fades de no máximo 80 ms;
--  * microinterações usam tempo real do cliente (cooldowns e avisos usam simTime, fora daqui).
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiMotion = require(ReplicatedStorage.Shared.Config.UiMotion)
local Accessibility = require(script.Parent.Accessibility)

local Anim = {}

Anim.REDUCED_FADE = 0.08 -- teto de 80 ms para fades no modo reduzido

-- Um tween ativo por (instância, propriedade). A tabela é fraca na chave para não segurar Instances.
type Controller = { [string]: Tween }
local controllers: { [Instance]: Controller } = setmetatable({}, { __mode = "k" }) :: any

local function recipe(id: string): UiMotion.Recipe
	local found = UiMotion[id]
	assert(found, `receita de animação desconhecida: {id}`)
	return found
end

local function infoOf(r: UiMotion.Recipe, duration: number?): TweenInfo
	return TweenInfo.new(
		duration or r.duration,
		(Enum.EasingStyle :: any)[r.style],
		(Enum.EasingDirection :: any)[r.direction]
	)
end

local function cancel(instance: Instance, property: string)
	local slot = controllers[instance]
	if not slot then
		return
	end
	local running = slot[property]
	if running then
		running:Cancel()
		slot[property] = nil
	end
end

-- Cancela tudo que estiver animando esta instância (usar ao remover o componente).
function Anim.cancelAll(instance: Instance)
	local slot = controllers[instance]
	if not slot then
		return
	end
	for property, tween in pairs(slot) do
		tween:Cancel()
		slot[property] = nil
	end
	controllers[instance] = nil
end

-- Aplica uma receita. `reducedProps` é o estado final imediato quando o movimento está reduzido;
-- quando ele é nil, o modo reduzido faz um fade curto das mesmas propriedades.
function Anim.play(
	instance: Instance,
	recipeId: string,
	props: { [string]: any },
	reducedProps: { [string]: any }?
): Tween?
	local r = recipe(recipeId)
	if Accessibility.reducedMotion() then
		local final = reducedProps or props
		for property, value in pairs(final) do
			cancel(instance, property);
			(instance :: any)[property] = value
		end
		return nil
	end
	local slot = controllers[instance]
	if not slot then
		slot = {}
		controllers[instance] = slot
	end
	for property in pairs(props) do
		cancel(instance, property)
	end
	local tween = TweenService:Create(instance, infoOf(r), props)
	for property in pairs(props) do
		slot[property] = tween
	end
	tween.Completed:Once(function()
		local currentSlot = controllers[instance]
		if not currentSlot then
			return
		end
		for property, running in pairs(currentSlot) do
			if running == tween then
				currentSlot[property] = nil
			end
		end
	end)
	tween:Play()
	return tween
end

-- Fade de transparência respeitando o teto do modo reduzido.
function Anim.fade(instance: Instance, property: string, target: number, recipeId: string): Tween?
	local r = recipe(recipeId)
	local duration = if Accessibility.reducedMotion() then Anim.REDUCED_FADE else r.duration
	cancel(instance, property)
	local slot = controllers[instance]
	if not slot then
		slot = {}
		controllers[instance] = slot
	end
	local tween = TweenService:Create(instance, infoOf(r, duration), { [property] = target })
	slot[property] = tween
	tween.Completed:Once(function()
		local currentSlot = controllers[instance]
		if currentSlot and currentSlot[property] == tween then
			currentSlot[property] = nil
		end
	end)
	tween:Play()
	return tween
end

-- Entrada de painel: alpha 0→1 com deslocamento de 12 px (só alpha no modo reduzido).
function Anim.panelEnter(frame: GuiObject, restingPosition: UDim2)
	frame.Position = restingPosition
	frame.Visible = true
	if Accessibility.reducedMotion() then
		Anim.fade(frame, "BackgroundTransparency", frame:GetAttribute("restTransparency") :: any or 0, "panel_enter")
		return
	end
	frame.Position = restingPosition + UDim2.fromOffset(0, 12)
	Anim.play(frame, "panel_enter", { Position = restingPosition })
end

-- Saída de painel: esconde ao terminar, a menos que algo reexiba o painel no meio do caminho.
function Anim.panelExit(frame: GuiObject, restingPosition: UDim2, onHidden: (() -> ())?)
	if not frame.Visible then
		if onHidden then
			onHidden()
		end
		return
	end
	local token = ((frame:GetAttribute("animToken") :: any) or 0) + 1
	frame:SetAttribute("animToken", token)
	local function finish()
		if frame:GetAttribute("animToken") ~= token then
			return
		end
		frame.Visible = false
		frame.Position = restingPosition
		if onHidden then
			onHidden()
		end
	end
	if Accessibility.reducedMotion() then
		finish()
		return
	end
	local tween = Anim.play(frame, "panel_exit", { Position = restingPosition + UDim2.fromOffset(0, 12) })
	if tween then
		tween.Completed:Once(finish)
	else
		finish()
	end
end

-- Escala de foco/pressionado em um UIScale dedicado (nunca dois UIScale no mesmo botão).
function Anim.scale(scaleObject: UIScale, target: number, recipeId: string)
	if Accessibility.reducedMotion() then
		cancel(scaleObject, "Scale")
		scaleObject.Scale = 1
		return
	end
	Anim.play(scaleObject, recipeId, { Scale = target })
end

-- Contagem visual de saldo (200 ms). A precisão lógica é imediata: isto é só apresentação.
function Anim.countTo(current: number, target: number, deltaTime: number): number
	if Accessibility.reducedMotion() then
		return target
	end
	local r = recipe("balance")
	if math.abs(target - current) < 1 then
		return target
	end
	local alpha = math.clamp(deltaTime / math.max(r.duration, 0.001), 0, 1)
	return current + (target - current) * alpha
end

return Anim
