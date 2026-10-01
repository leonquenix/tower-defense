local Progression = load("Shared/Rules/Progression")
local ProfileSchema = load("Shared/Profile/ProfileSchema")
local Balance = load("Shared/Config/Balance")

local DAY = 86400

describe("Progression / XP e nível", function()
	it("curva: 120 + 45 x (n - 1) por nível", function()
		expect(Progression.xpToNext(1)).toBe(120)
		expect(Progression.xpToNext(2)).toBe(165)
		expect(Progression.xpForLevel(10)).toBe(2700)
		expect(Progression.levelOf(0)).toBe(1)
		expect(Progression.levelOf(119)).toBe(1)
		expect(Progression.levelOf(120)).toBe(2)
		expect(Progression.levelOf(2700)).toBe(10)
		local info = Progression.levelInfo(130)
		expect(info.level).toBe(2)
		expect(info.into).toBe(10)
		expect(info.needed).toBe(165)
	end)
	it("teto de nível", function()
		local info = Progression.levelInfo(10 ^ 9)
		expect(info.level).toBe(Balance.progression.maxLevel)
		expect(info.maxed).toBe(true)
	end)
	it("XP da partida: ondas, vitória, dificuldade e grupo", function()
		-- fase 1 vencida sozinho: 12 x 3 + 60
		expect(Progression.matchXp("normal", "won", 3, "normal", 1)).toBe(96)
		expect(Progression.matchXp("normal", "lost", 5, "normal", 1)).toBe(60)
		expect(Progression.matchXp("normal", "won", 10, "desafio", 1)).toBe(math.floor(12 * 10 * 1.4 + 60 + 0.5))
		-- grupo de 4: +30 % no XP das ondas (teto)
		expect(Progression.matchXp("normal", "lost", 10, "normal", 4)).toBe(156)
		expect(Progression.matchXp("training", "won", 3, "normal", 1)).toBe(0)
		expect(Progression.matchXp("normal", "abandoned", 3, "normal", 1)).toBe(0)
	end)
end)

describe("Progression / recompensas de nível", function()
	it("cada nível paga botões uma vez, múltiplos de 5 pagam Retomada e torres abrem", function()
		local p = ProfileSchema.default(0)
		local out = Progression.addXp(p, Progression.xpForLevel(6))
		expect(out.levelBefore).toBe(1)
		expect(out.levelAfter).toBe(6)
		expect(out.rewards.buttons).toBe(5 * Balance.progression.levelButtons)
		expect(out.rewards.retry).toBe(1)
		expect(p.inventory.retry).toBe(1)
		expect(p.rewardedLevel).toBe(6)
		expect(table.find(p.ownedTowerIds, "lupa")).toBeTruthy()
		expect(table.find(p.ownedTowerIds, "maestro")).toBeTruthy()
		expect(table.find(p.ownedTowerIds, "voltz")).toBeNil()
		-- quarta vaga da equipe recebe a primeira torre liberada
		expect(#p.loadout).toBe(Balance.loadoutSlots)
		-- XP extra sem subir de nível não paga de novo
		local again = Progression.addXp(p, 1)
		expect(again.rewards.buttons or 0).toBe(0)
		expect(#again.towersUnlocked).toBe(0)
	end)
	it("torre antecipada com botões não é entregue de novo pelo nível", function()
		local p = ProfileSchema.default(0)
		p.buttons = 1000
		expect(ProfileSchema.buyTower(p, "lupa", 0)).toBe(true)
		local out = Progression.addXp(p, Progression.xpForLevel(3))
		expect(table.find(out.towersUnlocked, "lupa")).toBeNil()
	end)
end)

describe("Progression / recompensa diária", function()
	it("sequência de 7 dias, um resgate por dia", function()
		local p = ProfileSchema.default(0)
		local day0 = 20000 * DAY + 100
		local ok, bundle, index = Progression.claimDaily(p, day0)
		expect(ok).toBe(true)
		expect(index).toBe(1)
		expect(bundle.buttons).toBe(Balance.retention.dailyRewards[1].buttons)
		expect((Progression.claimDaily(p, day0 + 60))).toBe(false)
		local ok2, _, index2 = Progression.claimDaily(p, day0 + DAY)
		expect(ok2).toBe(true)
		expect(index2).toBe(2)
	end)
	it("pular um dia volta para o dia 1; depois do 7 volta ao 1", function()
		local p = ProfileSchema.default(0)
		local day0 = 20000 * DAY
		Progression.claimDaily(p, day0)
		Progression.claimDaily(p, day0 + DAY)
		local _, _, index = Progression.claimDaily(p, day0 + 3 * DAY)
		expect(index).toBe(1)
		local q = ProfileSchema.default(0)
		local last = 0
		for d = 0, 7 do
			local _, _, i = Progression.claimDaily(q, day0 + d * DAY)
			last = i
		end
		expect(last).toBe(1)
		expect(q.inventory.retry).toBe(1)
		expect(q.inventory.support).toBe(1)
	end)
end)

describe("Progression / presentes de sessão", function()
	it("só depois do tempo, uma vez por dia", function()
		local p = ProfileSchema.default(0)
		local now = 20000 * DAY
		local gift = Balance.retention.sessionGifts[1]
		local ok, why = Progression.canClaimGift(p, 1, gift.minutes * 60 - 1, now)
		expect(ok).toBe(false)
		expect(why).toBe("early")
		expect((Progression.claimGift(p, 1, gift.minutes * 60, now))).toBe(true)
		expect((Progression.claimGift(p, 1, 9999, now + 10))).toBe(false)
		-- dia novo: o presente volta
		expect((Progression.claimGift(p, 1, gift.minutes * 60, now + DAY))).toBe(true)
		expect((Progression.claimGift(p, 99, 99999, now))).toBe(false)
	end)
end)

describe("Perfil v4 / fichas e compras", function()
	it("v3 -> v4: XP nasce do histórico, torres do nível abrem, mapUnlocks sai", function()
		local v3 = ProfileSchema.default(0)
		v3.schemaVersion = 3
		v3.xp = nil
		v3.rewardedLevel = nil
		v3.inventory = nil
		v3.purchases = nil
		v3.mapUnlocks = { ["jardim:normal"] = true }
		v3.lifetimeStats.wavesCleared = 40
		v3.lifetimeStats.wins = 5
		local p, changed = ProfileSchema.migrate(v3, 10)
		expect(changed).toBe(true)
		expect(p.schemaVersion).toBe(4)
		expect(p.xp).toBe(12 * 40 + 60 * 5)
		expect(p.rewardedLevel).toBe(Progression.levelOf(p.xp))
		expect(p.mapUnlocks).toBeNil()
		expect(p.inventory.retry).toBe(0)
		expect(table.find(p.ownedTowerIds, "lupa")).toBeTruthy()
		expect(ProfileSchema.validate(p)).toBe(true)
		local again, changed2 = ProfileSchema.migrate(p, 20)
		expect(changed2).toBe(false)
		expect(again.xp).toBe(p.xp)
	end)
	it("v3 -> v4 depois do Reconcile do ProfileStore (xp = 0 do modelo) ainda usa o histórico", function()
		local v3 = ProfileSchema.default(0)
		v3.schemaVersion = 3
		v3.lifetimeStats.wavesCleared = 20
		v3.lifetimeStats.wins = 2
		local p = ProfileSchema.migrate(v3, 10)
		expect(p.xp).toBe(12 * 20 + 60 * 2)
		expect(p.rewardedLevel).toBe(Progression.levelOf(p.xp))
	end)
	it("o mesmo recibo nunca entrega duas vezes", function()
		local p = ProfileSchema.default(0)
		local granted, dup = ProfileSchema.applyPurchase(p, "purchase-1", "retry", 3, 100)
		expect(granted).toBe(true)
		expect(dup).toBe(false)
		expect(p.inventory.retry).toBe(3)
		local granted2, dup2 = ProfileSchema.applyPurchase(p, "purchase-1", "retry", 3, 200)
		expect(granted2).toBe(false)
		expect(dup2).toBe(true)
		expect(p.inventory.retry).toBe(3)
	end)
	it("o registro de recibos tem teto e guarda os mais recentes", function()
		local p = ProfileSchema.default(0)
		for i = 1, ProfileSchema.PURCHASE_LEDGER_LIMIT + 5 do
			ProfileSchema.applyPurchase(p, "r" .. i, "support", 1, i)
		end
		local count = 0
		for _ in pairs(p.purchases) do
			count += 1
		end
		expect(count).toBe(ProfileSchema.PURCHASE_LEDGER_LIMIT)
		expect(p.purchases["r1"]).toBeNil()
		expect(p.purchases["r" .. (ProfileSchema.PURCHASE_LEDGER_LIMIT + 5)]).toBeTruthy()
	end)
	it("gastar ficha exige estoque; Retomada por botões", function()
		local p = ProfileSchema.default(0)
		expect(ProfileSchema.consumeItem(p, "retry")).toBe(false)
		p.buttons = Balance.shop.retry.buttonsPrice
		expect(ProfileSchema.buyItemWithButtons(p, "retry")).toBe(true)
		expect(p.buttons).toBe(0)
		expect(ProfileSchema.consumeItem(p, "retry")).toBe(true)
		expect(p.inventory.retry).toBe(0)
		expect(ProfileSchema.buyItemWithButtons(p, "retry")).toBe(false)
		expect(ProfileSchema.buyItemWithButtons(p, "support")).toBe(false)
	end)
	it("resultado soma XP, sobe nível e entrega o presente da primeira vitória uma vez", function()
		local p = ProfileSchema.default(0)
		local input = {
			matchId = "m-a",
			buttons = 30,
			xp = 200,
			masteryByTower = {},
			outcome = "won",
			mode = "normal",
			mapId = "jardim",
			difficulty = "normal",
			wavesCompleted = 5,
			levelId = "2",
			stars = 1,
			createdAt = 0,
			now = 10,
		}
		local out = ProfileSchema.applyMatchResult(p, input)
		expect(out.applied).toBe(true)
		expect(out.xp.levelAfter).toBe(2)
		expect(out.firstClear.retry).toBe(1)
		expect(p.inventory.retry).toBe(1)
		input.matchId = "m-b"
		local out2 = ProfileSchema.applyMatchResult(p, input)
		expect(out2.firstClear).toBeNil()
		expect(p.inventory.retry).toBe(1)
		expect(p.xp).toBe(400)
	end)
end)
