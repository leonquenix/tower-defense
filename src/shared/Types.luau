--!strict
-- Tipos compartilhados de Quintal em Guarda.
-- Regras e simulação são puras: nenhum tipo aqui depende de instâncias Roblox.

export type TowerStateId = "L0" | "L1" | "L2" | "L3A" | "L3B"
export type TargetMode = "first" | "last" | "strongest" | "closest"
export type DamageType = "physical" | "energy" | "none"
export type Difficulty = "normal" | "desafio"
export type MatchMode = "normal" | "tutorial" | "training"
export type Phase =
	"Lobby"
	| "Loading"
	| "Preparation"
	| "Wave"
	| "Intermission"
	| "Won"
	| "Lost"
	| "RewardPending"
	| "Closed"
	| "Abandoned"

export type Cell = { number } -- {x, y}

-- ---------------------------------------------------------------------------
-- Dados de catálogo (gerados a partir de dados/balanceamento_v1.json)
-- ---------------------------------------------------------------------------

export type TowerStateStats = {
	cost: number,
	damage: number,
	interval: number,
	range: number,
	splash: number?,
	maxTargets: number?,
	armorIgnore: number?,
	bossBonus: number?,
	mark: number?,
	markDuration: number?,
	slow: number?,
	slowDuration: number?,
	chains: number?,
	chainRadius: number?,
	chainFalloff: number?,
	haste: number?,
}

export type TowerDef = {
	id: string,
	name: string,
	role: string,
	starter: boolean,
	unlock: number,
	damageType: DamageType,
	target: string,
	perPlayerLimit: number,
	states: { [string]: TowerStateStats },
	branchNames: { string },
}

export type EnemyDef = {
	id: string,
	name: string,
	hp: number,
	speed: number,
	bounty: number,
	leak: number,
	armor: number,
	energyResistance: number?,
	healPulse: number?,
	healRadius: number?,
	healInterval: number?,
	splitOnDeath: number?,
}

export type BossDef = {
	id: string,
	name: string,
	hp: number,
	speed: number,
	armor: number,
	leak: number,
	bounty: number,
	mechanic: string,
	period: number,
	telegraph: number,
	duration: number?,
	radius: number?,
	attackSlow: number?,
	extraArmor: number?,
	summonType: string?,
	summonCount: number?,
}

export type WaveGroup = { enemy: string, count: number }

export type WaveDef = {
	wave: number,
	groups: { WaveGroup },
	spawnInterval: number,
	groupGap: number,
	bossAfterGroups: boolean,
	income: number,
}

export type MapDef = {
	id: string,
	name: string,
	unlock: string,
	hpMultiplier: number,
	path: { Cell },
	blocked: { Cell },
	boss: string,
}

export type DifficultyDef = { hp: number, speed: number, winButtons: number }

export type CircuitDef = {
	id: string,
	pair: { string },
	effect: string,
	value: number,
	cap: number?,
}

export type PulseDef = {
	damage: number,
	damageType: DamageType,
	slow: number,
	slowDuration: number,
	cooldown: number,
	startsCharged: boolean,
	scaleDamageWithCoop: boolean,
}

export type EffectsDef = {
	slowCap: number,
	bossSlowStrength: number,
	physicalArmorCap: number,
	hasteStacking: string,
	slowStacking: string,
	markStacking: string,
}

export type RewardsDef = {
	tutorialButtons: number,
	lossButtonsPerWave: number,
	lossButtonsCap: number,
	masteryWin: number,
	masteryLoss: number,
	masteryLossMinWaves: number,
	masteryMinPlacedSeconds: number,
	masteryMilestones: { number },
}

export type TutorialDef = {
	startingCash: number,
	waves: { { WaveGroup } },
	guidedCells: { [string]: Cell },
}

export type ShopDef = {
	enabledByDefault: boolean,
	founderPassId: number?,
	proposedRobuxPrice: number,
}

export type GridDef = {
	columns: number,
	rows: number,
	cellUnits: number,
	virtualWidth: number,
	virtualHeight: number,
}

export type BalanceData = {
	version: string,
	status: string,
	checksum: string,
	grid: GridDef,
	baseHP: number,
	startingCash: number,
	tickRate: number,
	snapshotRate: number,
	towers: { TowerDef },
	enemies: { EnemyDef },
	bosses: { BossDef },
	waves: { WaveDef },
	difficulties: { [string]: DifficultyDef },
	circuits: { CircuitDef },
	pulse: PulseDef,
	effects: EffectsDef,
	rewards: RewardsDef,
	tutorial: TutorialDef,
	shop: ShopDef,
	partyMax: number,
	serverMaxPlayers: number,
	loadoutSlots: number,
	playerTowerLimitsByPartySize: { number },
	coopAdditionalHPPerPlayer: number,
	preparationSeconds: number,
	intermissionSeconds: number,
	sellRefund: number,
}

-- ---------------------------------------------------------------------------
-- Estado de simulação
-- ---------------------------------------------------------------------------

export type TimedEffect = {
	strength: number,
	expiresAt: number,
	sourceTowerId: number,
}

export type Enemy = {
	id: number,
	defId: string,
	isBoss: boolean,
	isSummon: boolean, -- criado por Casulo ou Breu: bounty 0
	hp: number,
	maxHp: number,
	s: number, -- distância escalar percorrida no caminho
	baseSpeed: number,
	armor: number,
	energyResistance: number,
	bounty: number,
	leak: number,
	alive: boolean,
	spawnedAt: number,
	slows: { TimedEffect },
	marks: { TimedEffect },
	-- Remendo
	lastHealAt: number,
	-- chefes
	bossArmorBonus: number,
	bossArmorUntil: number,
	bossNextTelegraphAt: number,
	bossTelegraphing: boolean,
	bossResolveAt: number,
	bossTargetCell: Cell?,
}

export type Tower = {
	id: number,
	ownerUserId: number,
	defId: string,
	state: TowerStateId,
	x: number,
	y: number,
	cooldown: number,
	targetMode: TargetMode,
	invested: number,
	placedAt: number,
	circuitPartnerId: number?,
	circuitId: string?,
	dustUntil: number,
	attackSeq: number,
	activeSeconds: number, -- tempo colocada (para domínio)
}

export type WaveRuntime = {
	groupIndex: number, -- grupo em andamento (1-based); 0 = não iniciado
	spawnedInGroup: number,
	nextSpawnAt: number,
	allGroupsSpawned: boolean,
	bossScheduledAt: number?,
	bossSpawned: boolean,
	waveStartedAt: number,
}

export type PlayerMatchStats = {
	damage: number,
	slowSeconds: number,
	supportBonusDamage: number,
	towersPlaced: number,
	commandsIssued: number,
}

export type Participant = {
	userId: number,
	connected: boolean, -- conexão real (informativo)
	active: boolean, -- conta para unanimidade de Pronto e 2x (falso após 30 s ausente)
	ready: boolean,
	speedVote: number,
	disconnectedAt: number?, -- relógio real, mantido pelo servidor
	loadout: { string },
	displayName: string,
}

export type MatchConfig = {
	matchId: string,
	configVersion: string,
	mode: MatchMode,
	mapId: string,
	difficulty: Difficulty,
	participants: { Participant }, -- congelados na largada
	seed: number,
	speedMultiplier: number?,
	trainingUnlockAll: boolean?,
}

export type MatchResult = {
	outcome: "won" | "lost" | "abandoned",
	wavesCompleted: number,
	buttonsPerPlayer: number,
	eligibleUserIds: { number },
	masteryByUser: { [number]: { [string]: number } },
	statsByUser: { [number]: PlayerMatchStats },
	durationSim: number,
}

export type MatchState = {
	matchId: string,
	configVersion: string,
	mode: MatchMode,
	mapId: string,
	difficulty: Difficulty,
	seed: number,
	participants: { Participant },
	participantOrder: { number }, -- UserIds crescentes
	phase: Phase,
	waveIndex: number, -- onda atual (1-based); 0 antes da primeira
	totalWaves: number,
	baseHP: number,
	simTime: number,
	speedMultiplier: number,
	phaseEndsAt: number, -- fim de preparação/intervalo em simTime
	enemies: { [number]: Enemy },
	enemyOrder: { number }, -- IDs vivos em ordem de criação
	towers: { [number]: Tower },
	towerOrder: { number },
	cellOccupancy: { [number]: number }, -- chave x*100+y -> towerId
	wallets: { [number]: number },
	nextEntityId: number,
	waveRuntime: WaveRuntime,
	pulseReadyAt: number,
	bountyCursor: number, -- índice em participantOrder para o resto
	stats: { [number]: PlayerMatchStats },
	commonHpFactor: number,
	bossHpFactor: number,
	coopFactor: number,
	pathLength: number,
	revision: number,
	result: MatchResult?,
	trainingUnlockAll: boolean,
	firstShotAt: number?,
	activeSecondsByUserTower: { [number]: { [string]: number } },
	trainingQueue: { TrainingSpawn },
	tutorialWaves: { { WaveGroup } }?,
	lastSupportPulseAt: { [number]: number },
}

export type TrainingSpawn = { defId: string, at: number }

-- ---------------------------------------------------------------------------
-- Eventos emitidos pela simulação (apresentação e telemetria)
-- ---------------------------------------------------------------------------

export type AttackTarget = { enemyId: number, damage: number, index: number }

export type SimEvent = {
	kind: string,
	simTime: number,
	entityId: number?,
	towerId: number?,
	attackSeq: number?,
	targets: { AttackTarget }?,
	enemyDefId: string?,
	userId: number?,
	amount: number?,
	wave: number?,
	phase: Phase?,
	cell: Cell?,
	circuitId: string?,
	partnerId: number?,
	reason: string?,
	radius: number?,
	s: number?,
	code: string?,
	speed: number?,
}

-- ---------------------------------------------------------------------------
-- Comandos e respostas
-- ---------------------------------------------------------------------------

export type CommandResult = {
	ok: boolean,
	errorCode: string?,
	balance: number?,
	revision: number,
	entityId: number?,
	message: string?,
}

-- ---------------------------------------------------------------------------
-- Perfil persistente
-- ---------------------------------------------------------------------------

export type MasteryRecord = { points: number, milestones: { number } }

export type ProfileSettings = {
	musicVolume: number,
	sfxVolume: number,
	reducedMotion: boolean,
	reducedParticles: boolean,
	damageNumbers: boolean,
	circuitPattern: string,
	locale: string,
}

export type LifetimeStats = {
	matches: number,
	wins: number,
	losses: number,
	wavesCleared: number,
	enemiesDefeated: number,
	towersPlaced: number,
	buttonsEarned: number,
}

export type PendingResultRef = { matchId: string, createdAt: number }

export type Profile = {
	schemaVersion: number,
	buttons: number,
	ownedTowerIds: { string },
	loadout: { string },
	cosmeticsOwned: { string },
	cosmeticLoadout: { [string]: string },
	masteryByTower: { [string]: MasteryRecord },
	mapUnlocks: { [string]: boolean },
	tutorialRewardClaimed: boolean,
	tutorialCompleted: boolean,
	settings: ProfileSettings,
	lifetimeStats: LifetimeStats,
	recentMatchRewards: { [string]: number }, -- matchId -> unix time aplicado
	pendingResults: { PendingResultRef },
	sessionLock: SessionLock?,
	createdAt: number,
	updatedAt: number,
}

export type SessionLock = { jobId: string, token: string, expiresAt: number }

-- Registro durável de resultado de partida (ledger)
export type MatchResultRecord = {
	matchId: string,
	configVersion: string,
	outcome: string,
	mode: MatchMode,
	mapId: string,
	difficulty: Difficulty,
	wavesCompleted: number,
	buttonsPerPlayer: number,
	eligibleUserIds: { number },
	masteryByUser: { [string]: { [string]: number } },
	appliedUserIds: { number },
	createdAt: number,
	partySize: number,
}

-- ---------------------------------------------------------------------------
-- Replicação (servidor -> cliente)
-- ---------------------------------------------------------------------------

export type EnemySnapshot = {
	id: number,
	d: string, -- defId
	b: boolean, -- isBoss
	hp: number,
	mhp: number,
	s: number,
	v: number, -- velocidade efetiva (unidades/s sim)
	sl: number, -- slow ativo (0..0.5)
	mk: number, -- marca ativa
	sm: boolean, -- summon
	tg: boolean, -- boss telegraphing
}

export type TowerSnapshot = {
	id: number,
	o: number, -- ownerUserId
	d: string,
	st: string, -- state
	x: number,
	y: number,
	tm: string, -- targetMode
	inv: number,
	cp: number?, -- circuit partner id
	ci: string?, -- circuit id
	du: number, -- dustUntil
}

export type ParticipantSnapshot = {
	userId: number,
	name: string,
	connected: boolean,
	ready: boolean,
	speedVote: number,
	color: number, -- índice 1..4
}

export type MatchSnapshot = {
	matchId: string,
	mode: MatchMode,
	mapId: string,
	difficulty: Difficulty,
	phase: Phase,
	waveIndex: number,
	totalWaves: number,
	baseHP: number,
	simTime: number,
	speedMultiplier: number,
	phaseEndsAt: number,
	pulseReadyAt: number,
	revision: number,
	enemies: { EnemySnapshot },
	towers: { TowerSnapshot },
	participants: { ParticipantSnapshot },
	wallet: number,
	limits: { perPlayer: number, placedByMe: number },
	result: MatchResult?,
	full: boolean,
	nextWavePreview: { WaveGroup }?,
	trainingUnlockAll: boolean,
	tutorialStep: number?,
}

export type NetEvent = {
	kind: string,
	simTime: number,
	entityId: number?,
	towerId: number?,
	attackSeq: number?,
	targets: { AttackTarget }?,
	enemyDefId: string?,
	userId: number?,
	amount: number?,
	wave: number?,
	phase: Phase?,
	cell: Cell?,
	circuitId: string?,
	partnerId: number?,
	reason: string?,
	radius: number?,
	s: number?,
	code: string?,
	speed: number?,
}

return nil
