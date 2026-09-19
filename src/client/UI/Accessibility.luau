--!strict
-- Preferências de acessibilidade efetivas: combina o que o jogador pediu no Roblox
-- (GuiService.ReducedMotionEnabled / PreferredTextSize) com as opções do jogo.
-- Regra do guia: qualquer pedido de redução ativa o modo; mudanças são observadas.
local GuiService = game:GetService("GuiService")

local Accessibility = {}

export type State = {
	reducedMotion: boolean,
	reducedParticles: boolean,
	textScale: number, -- multiplicador aplicado a TextSize (1 = referência)
	largeText: boolean,
}

local gameReducedMotion = false
local gameReducedParticles = false
local current: State = { reducedMotion = false, reducedParticles = false, textScale = 1, largeText = false }
local listeners: { (State) -> () } = {}

-- Enum.PreferredTextSize existe em clientes recentes; a leitura é protegida para não quebrar
-- em ambientes de teste onde a propriedade ainda não está disponível.
local TEXT_SCALE: { [string]: number } = {
	Regular = 1,
	Medium = 1.12,
	Large = 1.25,
	Larger = 1.4,
	Largest = 1.55,
}

local function robloxReducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

local function robloxTextScale(): number
	local ok, value = pcall(function()
		return GuiService.PreferredTextSize
	end)
	if not ok or typeof(value) ~= "EnumItem" then
		return 1
	end
	return TEXT_SCALE[value.Name] or 1
end

-- Movimento reduzido tira deslocamento, tremor e escala — não tira a informação do combate.
-- Projétil, clarão de impacto e número de dano são o que conta o que está acontecendo no
-- tabuleiro; quem quiser menos enfeite ainda pode desligar partículas em Configurações.
local function recompute()
	local scale = robloxTextScale()
	local next_: State = {
		reducedMotion = gameReducedMotion or robloxReducedMotion(),
		reducedParticles = gameReducedParticles,
		textScale = scale,
		largeText = scale > 1.05,
	}
	local changed = next_.reducedMotion ~= current.reducedMotion
		or next_.reducedParticles ~= current.reducedParticles
		or math.abs(next_.textScale - current.textScale) > 0.001
	current = next_
	if changed then
		for _, fn in ipairs(listeners) do
			task.spawn(fn, current)
		end
	end
end

function Accessibility.get(): State
	return current
end

function Accessibility.reducedMotion(): boolean
	return current.reducedMotion
end

function Accessibility.textScale(): number
	return current.textScale
end

-- Tamanho de texto final: aplica a preferência do sistema sem deixar o rótulo menor que a referência.
function Accessibility.scaleText(size: number): number
	return math.floor(size * current.textScale + 0.5)
end

-- Chamado pelo SettingsController quando as opções do jogo mudam.
function Accessibility.setGamePreferences(reducedMotion: boolean, reducedParticles: boolean)
	gameReducedMotion = reducedMotion
	gameReducedParticles = reducedParticles
	recompute()
end

function Accessibility.onChange(fn: (State) -> ())
	table.insert(listeners, fn)
end

function Accessibility.init()
	recompute()
	for _, property in ipairs({ "ReducedMotionEnabled", "PreferredTextSize" }) do
		pcall(function()
			GuiService:GetPropertyChangedSignal(property):Connect(recompute)
		end)
	end
end

return Accessibility
