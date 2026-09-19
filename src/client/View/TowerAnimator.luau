--!strict
-- Movimentos procedurais das torres (animation_plan.json): repouso, ataque/apoio, construção e melhoria.
-- Atua só na imagem filha do contêiner lógico; a célula e a seleção não se movem.
-- Tempo em segundos de simulação (o chamador avança dt x velocidade). Nunca decide dano.
local TowerAnimator = {}
TowerAnimator.__index = TowerAnimator

export type IdleSpec = { period: number, scaleY: { number }, scaleX: { number }, rotation: { number } }
export type ActionSpec = {
	kind: string,
	duration: number,
	recoilPx: number,
	scaleYMin: number,
	scaleUniformMax: number,
	minPulseInterval: number?,
}

-- Espelho tipado de animation_plan.json (os valores de origem são a especificação; manter sincronizado)
local PLAN: { [string]: { idle: IdleSpec, action: ActionSpec } } = {
	dardo = {
		idle = { period = 1.6, scaleY = { 1, 1.015 }, scaleX = { 1, 1 }, rotation = { 0, 0 } },
		action = { kind = "attack", duration = 0.22, recoilPx = 3, scaleYMin = 1, scaleUniformMax = 1 },
	},
	pipoca = {
		idle = { period = 2, scaleY = { 1, 1.015 }, scaleX = { 1, 1 }, rotation = { 0, 0 } },
		action = { kind = "attack", duration = 0.3, recoilPx = 0, scaleYMin = 0.94, scaleUniformMax = 1 },
	},
	lupa = {
		idle = { period = 2.4, scaleY = { 1, 1.008 }, scaleX = { 1, 1 }, rotation = { 0, 0 } },
		action = { kind = "attack", duration = 0.24, recoilPx = 2, scaleYMin = 1, scaleUniformMax = 1 },
	},
	goma = {
		idle = { period = 1.8, scaleY = { 0.98, 1 }, scaleX = { 1, 1.02 }, rotation = { 0, 0 } },
		action = { kind = "attack", duration = 0.28, recoilPx = 0, scaleYMin = 0.95, scaleUniformMax = 1 },
	},
	voltz = {
		idle = { period = 1.2, scaleY = { 1, 1.025 }, scaleX = { 1, 1 }, rotation = { 0, 0 } },
		action = { kind = "attack", duration = 0.2, recoilPx = 0, scaleYMin = 0.92, scaleUniformMax = 1 },
	},
	maestro = {
		idle = { period = 1.4, scaleY = { 1, 1 }, scaleX = { 1, 1 }, rotation = { -1, 1 } },
		action = {
			kind = "support",
			duration = 0.3,
			recoilPx = 0,
			scaleYMin = 1,
			scaleUniformMax = 1.03,
			minPulseInterval = 1,
		},
	},
}

TowerAnimator.BUILD_DURATION = 0.18
TowerAnimator.UPGRADE_DURATION = 0.35

export type Animator = typeof(setmetatable(
	{} :: {
		image: ImageLabel,
		-- Quadro do sprite em pixels. É o que permite virar a torre para o outro lado sem
		-- segundo arquivo: um ImageRect de largura negativa espelha a textura no próprio eixo
		-- (ImageRectOffset = {w, 0}, ImageRectSize = {-w, h}). Girar não serve: deixaria a
		-- torre de ponta-cabeça.
		frameWidth: number,
		frameHeight: number,
		defId: string,
		plan: { idle: IdleSpec, action: ActionSpec },
		time: number,
		idlePhase: number,
		action: {
			kind: string,
			startedAt: number,
			duration: number,
			seq: number?,
			pendingImage: string?,
			swapped: boolean,
		}?,
		lastSeq: number,
		lastPulseAt: number,
		facing: number, -- 1 direita, -1 esquerda (recuo do disparo)
		anchorY: number,
	},
	TowerAnimator
))

function TowerAnimator.new(
	image: ImageLabel,
	defId: string,
	anchorY: number,
	frameWidth: number?,
	frameHeight: number?
): Animator
	local plan = PLAN[defId] or PLAN.dardo
	local self = setmetatable({
		image = image,
		frameWidth = frameWidth or 128,
		frameHeight = frameHeight or 128,
		defId = defId,
		plan = plan,
		time = 0,
		idlePhase = math.random() * plan.idle.period,
		action = nil,
		lastSeq = 0,
		lastPulseAt = -math.huge,
		facing = 1,
		anchorY = anchorY,
	}, TowerAnimator)
	return self
end

-- Vira a torre para o lado do alvo espelhando a textura no próprio eixo: com largura negativa
-- no ImageRect o Roblox desenha a imagem invertida na horizontal, sem sprite extra e sem girar.
local function applyFacing(self: Animator)
	if self.facing < 0 then
		self.image.ImageRectOffset = Vector2.new(self.frameWidth, 0)
		self.image.ImageRectSize = Vector2.new(-self.frameWidth, self.frameHeight)
	else
		self.image.ImageRectOffset = Vector2.zero
		self.image.ImageRectSize = Vector2.zero -- imagem inteira
	end
end

-- Troca a textura do estado (ao criar a torre e a cada melhoria), mantendo o lado atual.
function TowerAnimator.setImage(self: Animator, image: string, frameWidth: number?, frameHeight: number?)
	if frameWidth then
		self.frameWidth = frameWidth
	end
	if frameHeight then
		self.frameHeight = frameHeight
	end
	if image ~= "" and self.image.Image ~= image then
		self.image.Image = image
	end
	applyFacing(self)
end

local function applyTransform(self: Animator, sx: number, sy: number, offsetPx: number, rotation: number)
	self.image.Size = UDim2.fromScale(sx, sy)
	self.image.Position = UDim2.new(0.5, offsetPx, self.anchorY, 0)
	self.image.Rotation = rotation
end

function TowerAnimator.restore(self: Animator)
	applyTransform(self, 1, 1, 0, 0)
end

-- Ataque/apoio cosmético identificado por attackSeq (deduplicação; eventos obsoletos são ignorados)
function TowerAnimator.playAction(self: Animator, seq: number, targetDirectionX: number?)
	if seq <= self.lastSeq then
		return
	end
	self.lastSeq = seq
	local spec = self.plan.action
	if spec.minPulseInterval and self.time - self.lastPulseAt < spec.minPulseInterval then
		return
	end
	self.lastPulseAt = self.time
	if targetDirectionX then
		local facing = if targetDirectionX >= 0 then 1 else -1
		if facing ~= self.facing then
			self.facing = facing
			applyFacing(self)
		end
	end
	if self.action and (self.action.kind == "upgrade" or self.action.kind == "build") then
		return -- ação de maior prioridade em andamento
	end
	self.action = {
		kind = spec.kind,
		startedAt = self.time,
		duration = spec.duration,
		seq = seq,
		pendingImage = nil,
		swapped = false,
	}
end

function TowerAnimator.playBuild(self: Animator)
	self.action = {
		kind = "build",
		startedAt = self.time,
		duration = TowerAnimator.BUILD_DURATION,
		seq = nil,
		pendingImage = nil,
		swapped = false,
	}
end

-- Melhoria: cancela ação atual, troca a textura uma vez no meio da transição e preserva o apoio.
function TowerAnimator.playUpgrade(self: Animator, newImage: string, frameWidth: number?, frameHeight: number?)
	TowerAnimator.restore(self)
	if frameWidth then
		self.frameWidth = frameWidth
	end
	if frameHeight then
		self.frameHeight = frameHeight
	end
	self.action = {
		kind = "upgrade",
		startedAt = self.time,
		duration = TowerAnimator.UPGRADE_DURATION,
		seq = nil,
		pendingImage = newImage,
		swapped = false,
	}
end

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

function TowerAnimator.update(self: Animator, simDt: number, reducedMotion: boolean, displayPixels: number)
	self.time += simDt
	local action = self.action
	if action then
		local t = (self.time - action.startedAt) / action.duration
		if t >= 1 then
			if action.kind == "upgrade" and not action.swapped and action.pendingImage then
				self.image.Image = action.pendingImage
			end
			self.action = nil
			TowerAnimator.restore(self)
		else
			local spec = self.plan.action
			local pxScale = displayPixels / 128
			if action.kind == "attack" then
				if reducedMotion then
					TowerAnimator.restore(self)
				else
					-- antecipação curta e recuo, retorno suave
					local k = if t < 0.3 then t / 0.3 else 1 - (t - 0.3) / 0.7
					local sy = 1 - (1 - spec.scaleYMin) * k
					local recoil = -spec.recoilPx * pxScale * k * self.facing
					applyTransform(self, 1, sy, recoil, 0)
				end
			elseif action.kind == "support" then
				if reducedMotion then
					TowerAnimator.restore(self)
				else
					local k = math.sin(t * math.pi)
					local s = 1 + (spec.scaleUniformMax - 1) * k
					applyTransform(self, s, s, 0, 0)
				end
			elseif action.kind == "build" then
				local s = 0.85 + 0.15 * easeOut(t)
				applyTransform(self, s, s, 0, 0)
			elseif action.kind == "upgrade" then
				if t >= 0.5 and not action.swapped and action.pendingImage then
					self.image.Image = action.pendingImage
					action.swapped = true
				end
				local glow = math.sin(t * math.pi)
				local s = 1 + 0.06 * glow
				applyTransform(self, s, s, 0, 0)
			end
			return
		end
	end
	-- repouso: só quando não há ação de maior prioridade
	if reducedMotion then
		return
	end
	local idle = self.plan.idle
	local phase = (self.time + self.idlePhase) / idle.period * math.pi * 2
	local k = (math.sin(phase) + 1) / 2
	local sy = idle.scaleY[1] + (idle.scaleY[2] - idle.scaleY[1]) * k
	local sx = idle.scaleX[1] + (idle.scaleX[2] - idle.scaleX[1]) * k
	local rot = idle.rotation[1] + (idle.rotation[2] - idle.rotation[1]) * k
	applyTransform(self, sx, sy, 0, rot)
end

function TowerAnimator.destroy(self: Animator)
	self.action = nil
	TowerAnimator.restore(self)
end

function TowerAnimator.plan(defId: string): { idle: IdleSpec, action: ActionSpec }?
	return PLAN[defId]
end

return TowerAnimator
