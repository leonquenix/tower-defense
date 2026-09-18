--!strict
-- Movimentos procedurais dos 8 inimigos e 3 chefes sobre uma única pose estática.
-- Espelho tipado de Assets_Inimigos_Bosses_v1/enemy_visuals.json (campo motion) com as amplitudes
-- do GUIA_MONSTROS_E_BOSSES (páginas 4 a 14). As poses NÃO são atlas: não há recorte de quadros.
--
-- Atua só na ImageLabel filha do contêiner lógico; a posição no caminho vem do servidor e não é
-- alterada aqui. Tempo em segundos de simulação (o chamador multiplica dt pela velocidade da
-- partida, então 1x e 2x usam o mesmo relógio lógico). Nunca decide dano, cura ou recompensa.
--
-- Prioridade de apresentação (guia, página 16): remoção > habilidade > impacto > movimento > repouso.
local EnemyAnimator = {}
EnemyAnimator.__index = EnemyAnimator

export type MotionSpec = {
	kind: string, -- hop | run | squash | stomp | float | sway
	period: number, -- segundos de simulação
	offsetPx: number, -- deslocamento vertical máximo em um quadro de referência de 128 px
	rotation: number, -- graus máximos
	scaleY: { number },
	scaleX: { number },
}

-- period/offset/rotation/scaleY vêm de enemy_visuals.json; scaleX segue o guia (só Bolota alarga).
local MOTION: { [string]: MotionSpec } = {
	fiapo = { kind = "hop", period = 0.6, offsetPx = 2, rotation = 0, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } },
	corrisco = { kind = "run", period = 0.35, offsetPx = 1.5, rotation = 1, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } },
	bolota = {
		kind = "squash",
		period = 1.2,
		offsetPx = 1,
		rotation = 0,
		scaleY = { 0.97, 1.01 },
		scaleX = { 1, 1.015 },
	},
	latinha = { kind = "stomp", period = 0.85, offsetPx = 1, rotation = 0, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } },
	nevoa = { kind = "float", period = 1.4, offsetPx = 2, rotation = 0, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } },
	remendo = { kind = "sway", period = 1.1, offsetPx = 1, rotation = 1, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } },
	casulo = { kind = "sway", period = 1.25, offsetPx = 1, rotation = 1, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } },
	brutamontes = {
		kind = "stomp",
		period = 1.3,
		offsetPx = 1.5,
		rotation = 0,
		scaleY = { 1, 1.01 },
		scaleX = { 1, 1 },
	},
	aspirador = { kind = "sway", period = 1.8, offsetPx = 0.7, rotation = 1, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } },
	rei_ferrugem = {
		kind = "stomp",
		period = 1.6,
		offsetPx = 0.8,
		rotation = 0,
		scaleY = { 1, 1.01 },
		scaleX = { 1, 1 },
	},
	breu = { kind = "sway", period = 2, offsetPx = 1, rotation = 1, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } },
}

local DEFAULT: MotionSpec =
	{ kind = "sway", period = 1.2, offsetPx = 1, rotation = 0, scaleY = { 1, 1.01 }, scaleX = { 1, 1 } }

EnemyAnimator.HIT_DURATION = 0.12 -- escurecimento curto no impacto
EnemyAnimator.SHAKE_DURATION = 0.12 -- tremor lateral do Casulo ao morrer
EnemyAnimator.TELEGRAPH_DURATION = 0.25 -- compressão do Aspirador ao iniciar o aviso
EnemyAnimator.ABILITY_DURATION = 0.2 -- estufar do Rei Ferrugem ao ativar a armadura
EnemyAnimator.SPAWN_DURATION = 0.18 -- entrada dos Corriscos invocados por Breu
EnemyAnimator.HIT_COLOR = Color3.fromRGB(150, 150, 160)

type Action = { kind: string, startedAt: number, duration: number }

export type Animator = typeof(setmetatable(
	{} :: {
		image: ImageLabel,
		entityId: string,
		spec: MotionSpec,
		time: number,
		phase: number,
		action: Action?,
		anchorY: number,
		visualScale: number, -- 0.7 nos filhos do Casulo
		baseColor: Color3,
	},
	EnemyAnimator
))

-- Fase determinística por entidade: dois Fiapos vizinhos não pulsam em uníssono,
-- e o mesmo id sempre recebe a mesma fase (sem aleatoriedade por frame).
local function phaseFor(entityKey: number, period: number): number
	return (entityKey * 0.6180339887) % 1 * period
end

function EnemyAnimator.new(
	image: ImageLabel,
	entityId: string,
	entityKey: number,
	anchorY: number,
	visualScale: number
): Animator
	local spec = MOTION[entityId] or DEFAULT
	return setmetatable({
		image = image,
		entityId = entityId,
		spec = spec,
		time = 0,
		phase = phaseFor(entityKey, spec.period),
		action = nil,
		anchorY = anchorY,
		visualScale = visualScale,
		baseColor = Color3.new(1, 1, 1),
	}, EnemyAnimator)
end

-- Reaproveitamento no pool: zera tempo, ação e transformações.
function EnemyAnimator.reset(self: Animator, entityId: string, entityKey: number, anchorY: number, visualScale: number)
	self.entityId = entityId
	self.spec = MOTION[entityId] or DEFAULT
	self.time = 0
	self.phase = phaseFor(entityKey, self.spec.period)
	self.action = nil
	self.anchorY = anchorY
	self.visualScale = visualScale
	EnemyAnimator.restore(self)
end

-- Deslocamentos são frações do quadro (offset de UDim é inteiro e truncaria um salto de 0,7 px
-- num sprite de 44 px). offsetPx/dxPx estão na referência de 128 px do guia: 2 px = 1,5625%.
local REFERENCE_FRAME = 128

local function applyTransform(self: Animator, sx: number, sy: number, offsetPx: number, rotation: number, dxPx: number)
	local s = self.visualScale
	self.image.Size = UDim2.fromScale(sx * s, sy * s)
	self.image.Position = UDim2.fromScale(0.5 + dxPx / REFERENCE_FRAME, self.anchorY + offsetPx / REFERENCE_FRAME)
	self.image.Rotation = rotation
end

function EnemyAnimator.restore(self: Animator)
	applyTransform(self, 1, 1, 0, 0, 0)
	self.image.ImageColor3 = self.baseColor
end

function EnemyAnimator.playHit(self: Animator)
	local current = self.action
	if current and (current.kind == "shake" or current.kind == "telegraph" or current.kind == "ability") then
		return -- habilidade e remoção têm prioridade sobre o impacto
	end
	self.action = { kind = "hit", startedAt = self.time, duration = EnemyAnimator.HIT_DURATION }
end

-- Casulo: tremor lateral curto depois da morte confirmada (os filhos já existem no servidor).
function EnemyAnimator.playDeathShake(self: Animator)
	self.action = { kind = "shake", startedAt = self.time, duration = EnemyAnimator.SHAKE_DURATION }
end

-- Aviso de chefe: compressão discreta; a contagem e o círculo ficam em elementos separados.
function EnemyAnimator.playTelegraph(self: Animator)
	self.action = { kind = "telegraph", startedAt = self.time, duration = EnemyAnimator.TELEGRAPH_DURATION }
end

function EnemyAnimator.playAbility(self: Animator)
	self.action = { kind = "ability", startedAt = self.time, duration = EnemyAnimator.ABILITY_DURATION }
end

-- Entrada dos invocados de Breu: escala 0,85 -> 1. Cosmético: a entidade já age no servidor.
function EnemyAnimator.playSpawnIn(self: Animator)
	self.action = { kind = "spawn", startedAt = self.time, duration = EnemyAnimator.SPAWN_DURATION }
end

function EnemyAnimator.update(self: Animator, simDt: number, reducedMotion: boolean)
	self.time += simDt
	local action = self.action
	if action then
		local t = (self.time - action.startedAt) / action.duration
		if t >= 1 then
			self.action = nil
			EnemyAnimator.restore(self)
		else
			if action.kind == "hit" then
				-- escurecimento curto: legível mesmo com movimento reduzido
				local k = 1 - t
				self.image.ImageColor3 = self.baseColor:Lerp(EnemyAnimator.HIT_COLOR, k)
				if reducedMotion then
					applyTransform(self, 1, 1, 0, 0, 0)
				end
				-- o ciclo de movimento continua por baixo do escurecimento
			elseif action.kind == "shake" then
				local dx = if reducedMotion then 0 else math.sin(t * math.pi * 6) * 2
				applyTransform(self, 1, 1, 0, 0, dx)
				return
			elseif action.kind == "telegraph" then
				local k = math.sin(t * math.pi)
				applyTransform(self, 1, 1 - 0.03 * (if reducedMotion then 0 else k), 0, 0, 0)
				return
			elseif action.kind == "ability" then
				local k = math.sin(t * math.pi)
				local s = 1 + 0.02 * (if reducedMotion then 0 else k)
				applyTransform(self, s, s, 0, 0, 0)
				return
			elseif action.kind == "spawn" then
				local s = if reducedMotion then 1 else 0.85 + 0.15 * t
				applyTransform(self, s, s, 0, 0, 0)
				return
			end
		end
	end
	if reducedMotion then
		-- movimento reduzido: sem ciclos decorativos; posição lógica e estado continuam legíveis
		applyTransform(self, 1, 1, 0, 0, 0)
		return
	end
	local spec = self.spec
	local cycle = (self.time + self.phase) / spec.period * math.pi * 2
	local wave = math.sin(cycle)
	local k = (wave + 1) / 2
	local sy = spec.scaleY[1] + (spec.scaleY[2] - spec.scaleY[1]) * k
	local sx = spec.scaleX[1] + (spec.scaleX[2] - spec.scaleX[1]) * (1 - k)
	local rot = spec.rotation * wave
	local offset: number
	if spec.kind == "hop" or spec.kind == "run" or spec.kind == "stomp" then
		-- salto/passada: só para cima, apoio volta ao chão a cada ciclo
		offset = -math.abs(wave) * spec.offsetPx
	else
		-- flutuação e balanço: oscilação suave em torno do apoio
		offset = -wave * spec.offsetPx
	end
	applyTransform(self, sx, sy, offset, rot, 0)
end

function EnemyAnimator.spec(entityId: string): MotionSpec?
	return MOTION[entityId]
end

return EnemyAnimator
