--!strict
-- Tipos compartilhados de Quintal em Guarda.
-- Regras e simulação são puras: nenhum tipo aqui depende de instâncias Roblox.

export type TowerStateId = "L0" | "L1" | "L2" | "L3A" | "L3B"
export type TargetMode = "first" | "last" | "strongest" | "closest"
export type DamageType = "physical" | "energy" | "none"
export type Difficulty = "normal" | "desafio"
export type MatchMode = "normal" | "training"
export type Phase =
	"Lobby"
	| "Loading"
	| "Preparation"
	| "Wave"
	| "Intermission"
	| "Won"
	| "Lost"
	-- o Farol apagou, mas a partida pode ser retomada do início da onda (Retomada)
	| "RetryDecision"
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
	-- encomenda v2 (Escovinha, Lumi, Pula, Pião, Picolé, Fofo)
	shred: number?, -- armadura raspada (absoluta) por acerto
	shredDuration: number?,
	shredStacks: number?, -- acúmulo da mesma torre (Escova de Aço)
	burn: number?, -- queimadura em dano por segundo; enquanto dura, o alvo não recebe cura
	burnDuration: number?,
	focusRamp: number?, -- Holofote: bônus por acerto seguido no mesmo alvo
	focusMax: number?,
	burnSpread: number?, -- Enxame: vizinhos que também pegam fogo
	burnSpreadRadius: number?,
	push: number?, -- empurrão em células para trás no caminho
	grab: number?, -- Língua de Sogra: puxa o inimigo comum mais forte
	allTargets: number?, -- Pião: acerta todos no alcance (teto de alvos)
	freeze: number?, -- segundos de congelamento (chefe só fica lento)
	frozenBonus: number?, -- dano extra em quem está congelado por esta torre
	damageBoost: number?, -- Fofo: aura de dano
	baseHeal: number?, -- Coração Remendado: vida devolvida ao Farol por onda vencida
}

export type TowerDef = {
	id: string,
	name: string,
	role: string,
	starter: boolean,
	unlock: number, -- botões para antecipar a torre antes do nível
	unlockLevel: number, -- nível da conta que libera a torre de graça
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
	slowImmune: boolean?, -- Novelo: lentidão não pega (congelamento pega)
	dodgeInterval: number?, -- Traça: esquiva o primeiro acerto a cada N segundos
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
	targetCount: number?, -- Boneco de Poeira: torres congeladas pela rajada
	soakHeal: number?, -- Esponjão: fração do dano de energia absorvido que vira cura
	cloudLength: number?, -- Traça Rainha: trecho do caminho escondido (células)
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

-- Grupo extra que o mapa acrescenta à onda global a partir de fromWave:
-- count + floor(perWave x (onda - fromWave)) inimigos, depois dos grupos da tabela.
export type MapGroup = { enemy: string, fromWave: number, count: number, perWave: number }

export type MapDef = {
	id: string,
	name: string,
	unlock: string?,
	hpMultiplier: number,
	path: { Cell },
	blocked: { Cell },
	boss: string,
	mapGroups: { MapGroup },
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
	shredCap: number, -- teto da armadura raspada somada às fontes
	pushCooldown: number, -- segundos em que o inimigo empurrado não é empurrado de novo
	maxPushPerEnemy: number, -- teto do empurrão total na vida do inimigo (células)
	bossPushFactor: number, -- fração do empurrão que pega em chefe
	freezeImmunity: number, -- segundos sem novo congelamento depois de descongelar
	frozenBossSlow: number, -- lentidão aplicada ao chefe no lugar do congelamento
	damageBoostStacking: string,
	burnStacking: string,
	baseHealPerWaveCap: number, -- teto de vida que o Farol recupera por onda
}

export type RewardsDef = {
	-- a vitória paga winButtons da dificuldade proporcional às ondas: ondas / referência
	winButtonsReferenceWaves: number,
	lossButtonsPerWave: number,
	lossButtonsCap: number,
	masteryWin: number,
	masteryLoss: number,
	masteryLossMinWaves: number,
	masteryMinPlacedSeconds: number,
	masteryMilestones: { number },
}

-- Campanha: fases declaradas em dados. A primeira estrela é sempre vencer; as outras duas saem
-- dos objetivos, avaliados pelo servidor a partir das estatísticas da partida (Rules/Stars).
export type ObjectiveDef = {
	kind: string, -- noLeak | maxDamage | maxTowers | onlyTowers | rushAll | noSell | minCircuits
	value: number?,
	towers: { string }?,
}

export type LevelDef = {
	id: string,
	mapId: string,
	waves: number, -- quantas ondas da tabela global a fase usa
	hpScale: number,
	startingCash: number,
	objectives: { ObjectiveDef },
	-- chefe do mapa depois da última onda da fase, com a vida escalada por este fator
	bossHpScale: number?,
	-- entregue uma vez por conta, na primeira vitória da fase
	firstClearReward: RewardBundle?,
	-- só a primeira fase: as ondas esperam o jogador chamar, e o guia inicial aparece uma vez
	manualWaveStart: boolean?,
	intro: boolean?,
	introTower: string?,
	introCell: Cell?,
}

export type CampaignDef = {
	buttonsPerStar: number,
	note: string,
	levels: { LevelDef },
}

-- Estatísticas de uma partida de campanha (é o que decide as estrelas).
export type CampaignStats = {
	damageTaken: number,
	towersBuilt: number,
	towerIds: { [string]: boolean },
	wavesRushed: number,
	wavesTotal: number,
	towersSold: number,
	circuitsActive: number, -- circuitos ligados no fim da partida
}

-- Pacote de recompensa: botões e fichas. É o mesmo formato para nível, dia, presente e fase.
export type ItemId = "retry" | "support"
export type RewardBundle = { buttons: number?, retry: number?, support: number? }

export type ProductDef = {
	id: string,
	item: ItemId,
	quantity: number,
	productId: number?, -- nil até o produto existir no Creator Hub
	proposedRobux: number,
}

export type ShopDef = {
	enabledByDefault: boolean,
	founderPassId: number?,
	proposedRobuxPrice: number,
	products: { ProductDef },
	retry: {
		enabled: boolean,
		decisionSeconds: number, -- quanto a tela de derrota espera uma decisão
		promptGraceSeconds: number, -- prazo extra enquanto a compra do Roblox está aberta
		prepSeconds: number, -- preparação curta antes de repetir a onda
		buttonsPrice: number, -- Retomada também sai por botões
	},
	support: { enabled: boolean },
}

export type ProgressionDef = {
	xpPerWave: number,
	xpWinBonus: number,
	xpDifficulty: { [string]: number },
	xpPerExtraPlayer: number,
	xpGroupCap: number,
	levelBase: number,
	levelStep: number,
	maxLevel: number,
	levelButtons: number,
	levelRetryEvery: number,
}

export type SessionGiftDef = { minutes: number, buttons: number?, retry: number?, support: number? }

export type RetentionDef = {
	dailyRewards: { RewardBundle },
	sessionGifts: { SessionGiftDef },
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
	campaign: CampaignDef,
	shop: ShopDef,
	partyMax: number,
	serverMaxPlayers: number,
	loadoutSlots: number,
	playerTowerLimitsByPartySize: { number },
	coopAdditionalHPPerPlayer: number,
	preparationSeconds: number,
	intermissionSeconds: number,
	-- bônus por chamar a onda antes do cronômetro: sucatas por segundo poupado, com teto
	earlyWaveBonusPerSecond: number,
	earlyWaveBonusMax: number,
	sellRefund: number,
	progression: ProgressionDef,
	retention: RetentionDef,
}

-- ---------------------------------------------------------------------------
-- Estado de simulação
-- ---------------------------------------------------------------------------

export type TimedEffect = {
	strength: number,
	expiresAt: number,
	sourceTowerId: number,
}

-- Queimadura: dano por segundo creditado ao dono da torre que acendeu (mesmo se ela for vendida).
export type BurnEffect = {
	strength: number,
	expiresAt: number,
	sourceTowerId: number,
	ownerUserId: number,
}

-- Nuvem de pó da Traça Rainha: trecho do caminho onde as torres não miram.
export type PathCloud = { fromS: number, toS: number, expiresAt: number, bossId: number }

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
	bossTargetTowerIds: { number }?, -- torres marcadas no aviso (Boneco de Poeira, Meia)
	bossSoakUntil: number, -- Esponjão: até quando absorve energia
	-- efeitos da encomenda v2
	shreds: { TimedEffect }, -- armadura raspada (Escovinha)
	burns: { BurnEffect }, -- queimadura (Lumi): enquanto houver, nada cura este inimigo
	freezeUntil: number, -- congelado (Picolé): velocidade zero
	freezeBonus: number, -- dano extra enquanto congelado (Geladeira)
	freezeImmuneUntil: number, -- depois de descongelar, um tempo sem novo congelamento
	pushReadyAt: number, -- quando pode ser empurrado de novo
	pushedTotal: number, -- células já empurradas na vida (teto em effects.maxPushPerEnemy)
	dodgeReadyAt: number, -- Traça: quando a próxima esquiva está pronta
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
	-- desligada por chefe: "frost" (Boneco de Poeira) ou "wrap" (Meia). Não atira nem dá aura.
	disabledUntil: number,
	disabledReason: string?,
	-- Holofote: alvo atual e acertos seguidos nele
	focusTargetId: number?,
	focusStacks: number,
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
	-- campanha: a fase manda em ondas, vida, sucata inicial e ritmo das ondas
	levelId: string?,
	waves: number?,
	hpScale: number?,
	startingCash: number?,
	manualWaveStart: boolean?,
	bossHpScale: number?,
	-- monetização: Retomada na derrota e Reforço na preparação (fora do guia e do treino)
	retryAllowed: boolean?,
	supportAllowed: boolean?,
}

export type MatchResult = {
	outcome: "won" | "lost" | "abandoned",
	wavesCompleted: number,
	levelId: string?,
	stars: number,
	starsEarned: { boolean }, -- vitória, objetivo 1, objetivo 2
	campaignStats: CampaignStats?,
	-- usou Retomada ou Reforço: vitória vale, estrelas de objetivo não
	assisted: boolean,
	buttonsPerPlayer: number,
	xpPerPlayer: number,
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
	levelId: string?,
	manualWaveStart: boolean,
	campaignStats: CampaignStats,
	lastSupportPulseAt: { [number]: number },
	bossHpScale: number?,
	-- Retomada: foto do início da onda atual. Fichas, uso e o sinal de ajuda ficam fora dela e
	-- nunca voltam no tempo.
	checkpoint: Checkpoint?,
	retryAllowed: boolean,
	retryUsed: boolean,
	lostAtWave: number, -- onda em que o Farol apagou (0 enquanto não apagou)
	supportAllowed: boolean,
	supportUsedBy: { [number]: boolean },
	assisted: boolean,
	-- nuvens de pó ativas (Traça Rainha)
	pathClouds: { PathCloud },
}

export type Checkpoint = {
	waveIndex: number,
	wallets: { [number]: number },
	towers: { [number]: Tower },
	towerOrder: { number },
	cellOccupancy: { [number]: number },
	pulseRemaining: number,
	bountyCursor: number,
	campaignStats: CampaignStats,
}

export type TrainingSpawn = { defId: string, at: number }

-- ---------------------------------------------------------------------------
-- Eventos emitidos pela simulação (apresentação e telemetria)
-- ---------------------------------------------------------------------------

-- flag: 0 acerto normal, 1 esquiva (Traça), 2 absorvido (Esponjão encharcado)
export type AttackTarget = { enemyId: number, damage: number, index: number, flag: number? }

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
	resolveAt: number?, -- prazo de simulação do aviso de chefe
	expiresAt: number?, -- fim do efeito já resolvido (poeira, armadura)
	entityIds: { number }?, -- alvos curados, invocados criados
	towerIds: { number }?, -- torres atingidas por poeira
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

export type Inventory = { retry: number, support: number }

export type Profile = {
	schemaVersion: number,
	buttons: number,
	-- conta: XP acumulado e o maior nível cujas recompensas já foram entregues
	xp: number,
	rewardedLevel: number,
	-- fichas guardadas (compradas ou ganhas); só o servidor mexe
	inventory: Inventory,
	-- recibos já entregues (PurchaseId -> unix time): a compra nunca é entregue duas vezes
	purchases: { [string]: number },
	-- recompensa diária: último dia UTC resgatado e posição na sequência de 7
	daily: { lastDay: number, streak: number },
	-- presentes de sessão resgatados hoje (índices em retention.sessionGifts)
	sessionGifts: { day: number, claimed: { number } },
	-- concessões únicas por conta (ex.: "firstClear:2")
	grants: { [string]: boolean },
	-- maior passo do funil de primeira sessão já registrado
	onboardingStep: number,
	ownedTowerIds: { string },
	loadout: { string },
	cosmeticsOwned: { string },
	cosmeticLoadout: { [string]: string },
	masteryByTower: { [string]: MasteryRecord },
	-- campanha: estrelas por fase (0..3). Fase sem entrada nunca foi vencida.
	campaign: { [string]: number },
	campaignIntroSeen: boolean,
	-- campos do tutorial antigo: mantidos porque existem em perfis salvos; nada os lê.
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
	xpPerPlayer: number?, -- ausente em registros anteriores à v4 do perfil
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
	tga: number?, -- simTime em que o aviso resolve (só enquanto tg)
	ab: number, -- bônus de armadura ativo do chefe (Rei Ferrugem)
	ar: number, -- armadura atual efetiva (base + bônus)
	er: number, -- resistência de energia atual
	fx: number, -- estados visíveis (Snapshot.FX: queimando, congelado, raspado, encharcado, escondido)
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
	dis: number, -- disabledUntil (Boneco de Poeira, Meia)
	dr: string?, -- motivo: "frost" | "wrap"
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
	levelId: string?,
	-- eco das estatísticas que valem estrela, para o HUD mostrar o progresso ao vivo
	damageTaken: number,
	towersBuilt: number,
	wavesRushed: number,
	-- monetização: o que o HUD e a tela de derrota podem oferecer agora
	retryAvailable: boolean, -- Farol apagou e a Retomada ainda não foi usada nesta partida
	lostAtWave: number,
	supportAvailable: boolean, -- o destinatário ainda pode usar o Reforço (preparação, sem uso)
	assisted: boolean,
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
	resolveAt: number?, -- prazo de simulação do aviso de chefe
	expiresAt: number?, -- fim do efeito já resolvido (poeira, armadura)
	entityIds: { number }?, -- alvos curados, invocados criados
	towerIds: { number }?, -- torres atingidas por poeira
}

return nil
