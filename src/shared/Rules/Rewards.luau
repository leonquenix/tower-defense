--!strict
-- Recompensas: divisão de sucata, renda de onda, botões e domínio. Regras puras.
local Types = require(script.Parent.Parent.Types)

local Rewards = {}

export type BountySplit = { shares: { [number]: number }, cursor: number }

-- Divide `bounty` em partes iguais entre participantes (UserIds crescentes). O resto vai
-- um por vez a partir do cursor (índice 1-based em participantOrder), que avança.
function Rewards.splitBounty(bounty: number, participantOrder: { number }, cursor: number): BountySplit
	local n = #participantOrder
	local shares: { [number]: number } = {}
	if n == 0 or bounty <= 0 then
		return { shares = shares, cursor = cursor }
	end
	local base = math.floor(bounty / n)
	local remainder = bounty - base * n
	for _, userId in ipairs(participantOrder) do
		shares[userId] = base
	end
	local c = cursor
	if c < 1 or c > n then
		c = 1
	end
	for _ = 1, remainder do
		local userId = participantOrder[c]
		shares[userId] += 1
		c += 1
		if c > n then
			c = 1
		end
	end
	return { shares = shares, cursor = c }
end

function Rewards.waveIncome(wave: Types.WaveDef): number
	return wave.income
end

function Rewards.sellRefund(invested: number, refundRate: number): number
	return math.floor(invested * refundRate)
end

function Rewards.winButtons(difficulty: Types.DifficultyDef): number
	return difficulty.winButtons
end

function Rewards.lossButtons(wavesCompleted: number, rewards: Types.RewardsDef): number
	return math.min(rewards.lossButtonsPerWave * math.max(wavesCompleted, 0), rewards.lossButtonsCap)
end

function Rewards.buttonsForOutcome(
	mode: Types.MatchMode,
	outcome: string,
	wavesCompleted: number,
	difficulty: Types.DifficultyDef,
	rewards: Types.RewardsDef
): number
	if mode == "training" then
		return 0
	end
	if outcome == "won" then
		return Rewards.winButtons(difficulty)
	elseif outcome == "lost" then
		return Rewards.lossButtons(wavesCompleted, rewards)
	end
	return 0
end

-- Pontos de domínio para uma torre equipada. activeSeconds: tempo colocada/apoiando.
function Rewards.masteryPoints(
	mode: Types.MatchMode,
	outcome: string,
	wavesCompleted: number,
	activeSeconds: number,
	rewards: Types.RewardsDef
): number
	if mode ~= "normal" then
		return 0
	end
	if activeSeconds < rewards.masteryMinPlacedSeconds then
		return 0
	end
	if outcome == "won" then
		return rewards.masteryWin
	elseif outcome == "lost" and wavesCompleted >= rewards.masteryLossMinWaves then
		return rewards.masteryLoss
	end
	return 0
end

-- Marcos alcançados ao passar de `before` para `after` pontos.
function Rewards.newMilestones(before: number, after: number, milestones: { number }): { number }
	local reached = {}
	for _, m in ipairs(milestones) do
		if before < m and after >= m then
			table.insert(reached, m)
		end
	end
	return reached
end

return Rewards
