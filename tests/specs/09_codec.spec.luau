local Codec = load("Shared/Net/Codec")
local Enums = load("Shared/Net/Enums")

local function sampleSnapshot()
	return {
		matchId = "m-1",
		mode = "normal",
		mapId = "jardim",
		difficulty = "desafio",
		phase = "Wave",
		waveIndex = 7,
		totalWaves = 20,
		baseHP = 83.5,
		simTime = 121.25,
		speedMultiplier = 2,
		phaseEndsAt = math.huge,
		pulseReadyAt = 140.5,
		revision = 991,
		enemies = {
			{
				id = 12,
				d = "latinha",
				b = false,
				hp = 40,
				mhp = 60,
				s = 13.5,
				v = 1.5,
				sl = 0.25,
				mk = 0,
				sm = false,
				tg = false,
				tga = nil,
				ab = 0,
				ar = 2,
				er = 0,
			},
			{
				id = 13,
				d = "rei_ferrugem",
				b = true,
				hp = 900,
				mhp = 1200,
				s = 4,
				v = 0.75,
				sl = 0,
				mk = 1.2,
				sm = false,
				tg = true,
				tga = 125.5,
				ab = 3,
				ar = 7,
				er = 0.25,
			},
		},
		towers = {
			{
				id = 3,
				o = 1234567890,
				d = "voltz",
				st = "L3A",
				x = 5,
				y = 6,
				tm = "strongest",
				inv = 1250,
				cp = 4,
				ci = "ritmo_eletrico",
				du = 0,
			},
		},
		participants = {
			{ userId = 1234567890, name = "Ana", connected = true, ready = false, speedVote = 2, color = 1 },
		},
		wallet = 725,
		limits = { perPlayer = 12, placedByMe = 3 },
		result = nil,
		full = true,
		nextWavePreview = { { enemy = "fiapo", count = 8 }, { enemy = "casulo", count = 2 } },
		trainingUnlockAll = false,
		tutorialStep = nil,
	}
end

describe("Codec / snapshot", function()
	it("ida e volta preserva os campos usados pelo cliente", function()
		local original = sampleSnapshot()
		local back = Codec.decodeSnapshot(Codec.encodeSnapshot(original))
		expect(back.matchId).toBe(original.matchId)
		expect(back.mode).toBe("normal")
		expect(back.mapId).toBe("jardim")
		expect(back.difficulty).toBe("desafio")
		expect(back.phase).toBe("Wave")
		expect(back.waveIndex).toBe(7)
		expect(back.speedMultiplier).toBe(2)
		expect(back.wallet).toBe(725)
		expect(back.limits.perPlayer).toBe(12)
		expect(back.limits.placedByMe).toBe(3)
		expect(#back.enemies).toBe(2)
		expect(back.enemies[1].d).toBe("latinha")
		expect(back.enemies[2].d).toBe("rei_ferrugem")
		expect(back.enemies[2].b).toBe(true)
		expect(back.enemies[2].tga).toBe(125.5)
		expect(back.enemies[1].tga).toBe(nil)
		expect(back.towers[1].d).toBe("voltz")
		expect(back.towers[1].st).toBe("L3A")
		expect(back.towers[1].tm).toBe("strongest")
		expect(back.towers[1].ci).toBe("ritmo_eletrico")
		expect(back.towers[1].o).toBe(1234567890)
		expect(back.participants[1].name).toBe("Ana")
		expect(back.nextWavePreview[2].enemy).toBe("casulo")
		expect(back.trainingUnlockAll).toBe(false)
		expect(back.tutorialStep).toBe(nil)
	end)

	it("prazo sem fim volta como math.huge (float não guarda infinito útil)", function()
		local back = Codec.decodeSnapshot(Codec.encodeSnapshot(sampleSnapshot()))
		expect(back.phaseEndsAt).toBe(math.huge)
		expect(back.pulseReadyAt).toBe(140.5)
	end)

	it("um id de inimigo desconhecido não derruba o cliente", function()
		local wire = Codec.encodeSnapshot(sampleSnapshot())
		wire.enemies[1].d = 250 -- versão nova do servidor
		local back = Codec.decodeSnapshot(wire)
		expect(back.enemies[1].d).toBe("fiapo")
	end)
end)

describe("Codec / eventos", function()
	it("ida e volta de um ataque com alvos", function()
		local event = {
			kind = "attack",
			simTime = 12.5,
			towerId = 3,
			attackSeq = 44,
			targets = {
				{ enemyId = 12, damage = 18.5, index = 1 },
				{ enemyId = 13, damage = 9, index = 2 },
			},
		}
		local back = Codec.decodeEvent(Codec.encodeEvent(event))
		expect(back.kind).toBe("attack")
		expect(back.towerId).toBe(3)
		expect(back.attackSeq).toBe(44)
		expect(#back.targets).toBe(2)
		expect(back.targets[2].damage).toBe(9)
		expect(back.entityId).toBe(nil)
		expect(back.cell).toBe(nil)
	end)

	it("célula, fase e circuito atravessam como ids", function()
		local event = {
			kind = "towerPlaced",
			simTime = 3,
			towerId = 9,
			userId = 1234567890,
			cell = { 4, 11 },
			amount = 250,
		}
		local wire = Codec.encodeEvent(event)
		expect(wire.cellX).toBe(4)
		expect(wire.cellY).toBe(11)
		local back = Codec.decodeEvent(wire)
		expect(back.cell[1]).toBe(4)
		expect(back.cell[2]).toBe(11)
		expect(back.userId).toBe(1234567890)
		expect(back.amount).toBe(250)
	end)

	it("evento fora da lista viaja pelo nome, sem virar 'unknown'", function()
		local wire = Codec.encodeEvent({ kind = "algoNovo", simTime = 1 })
		expect(wire.k).toBe(0)
		expect(wire.ks).toBe("algoNovo")
		expect(Codec.decodeEvent(wire).kind).toBe("algoNovo")
	end)
end)

describe("Enums / ids estáveis", function()
	it("todo inimigo e chefe do balanceamento tem id", function()
		expect(Enums.toId(Enums.enemy, "fiapo") > 0).toBeTruthy()
		expect(Enums.toId(Enums.enemy, "breu") > 0).toBeTruthy()
		expect(Enums.toId(Enums.enemy, "inexistente")).toBe(0)
	end)

	it("ids cabem em um byte (o fio usa uint8)", function()
		local sets = {
			Enums.enemy,
			Enums.tower,
			Enums.towerState,
			Enums.targetMode,
			Enums.difficulty,
			Enums.matchMode,
			Enums.map,
			Enums.circuit,
			Enums.phase,
			Enums.event,
			Enums.frame,
			Enums.lobby,
		}
		for _, enumSet in ipairs(sets) do
			expect(Enums.count(enumSet) <= 255).toBeTruthy()
		end
	end)
end)
