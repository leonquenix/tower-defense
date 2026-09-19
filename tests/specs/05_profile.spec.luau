local ProfileSchema = load("Shared/Profile/ProfileSchema")
local Localization = load("Shared/Config/Localization")
local DevFlags = load("Shared/Config/DevFlags")
local Balance = load("Shared/Config/Balance")

describe("ProfileSchema", function()
	it("perfil padrão possui as três torres iniciais equipadas", function()
		local p = ProfileSchema.default(1000)
		expect(p.ownedTowerIds).toEqual({ "dardo", "pipoca", "goma" })
		expect(p.loadout).toEqual({ "dardo", "pipoca", "goma" })
		expect(p.buttons).toBe(0)
		expect(ProfileSchema.validate(p)).toBe(true)
	end)
	it("P07: migração de perfil antigo é idempotente", function()
		local v1 = {
			schemaVersion = 1,
			buttons = 300,
			ownedTowerIds = { "dardo", "pipoca", "goma", "lupa" },
			loadout = { "dardo" },
			cosmeticsOwned = {},
			cosmeticLoadout = {},
			masteryByTower = { dardo = { points = 12, milestones = {} } },
			mapUnlocks = { ["jardim:normal"] = true },
			tutorialRewardClaimed = true,
			settings = { musicVolume = 0.2 },
			lifetimeStats = {
				matches = 3,
				wins = 1,
				losses = 2,
				wavesCleared = 30,
				enemiesDefeated = 100,
				towersPlaced = 20,
			},
			recentMatchRewards = { m1 = 900 },
			createdAt = 1,
			updatedAt = 2,
		}
		local once, changed = ProfileSchema.migrate(v1, 1000)
		expect(changed).toBe(true)
		expect(once.schemaVersion).toBe(ProfileSchema.CURRENT_VERSION)
		expect(once.tutorialCompleted).toBe(true)
		expect(once.pendingResults).toEqual({})
		expect(once.lifetimeStats.buttonsEarned).toBe(0)
		expect(once.settings.sfxVolume).toBe(0.8)
		expect(once.settings.musicVolume).toBe(0.2)
		expect(once.buttons).toBe(300)
		local twice, changed2 = ProfileSchema.migrate(once, 2000)
		expect(changed2).toBe(false)
		expect(twice.buttons).toBe(300)
		expect(ProfileSchema.validate(twice)).toBe(true)
	end)
	it("perfil de versão futura não é tocado", function()
		local future = { schemaVersion = 99 }
		local p = ProfileSchema.migrate(future, 1)
		expect(p).toBeNil()
	end)
	it("P05: repetir o mesmo matchId não paga duas vezes", function()
		local p = ProfileSchema.default(0)
		local input = {
			matchId = "m-1",
			buttons = 120,
			masteryByTower = { dardo = 10 },
			outcome = "won",
			mode = "normal",
			mapId = "jardim",
			difficulty = "normal",
			wavesCompleted = 20,
			createdAt = 100,
			now = 200,
		}
		local r1 = ProfileSchema.applyMatchResult(p, input)
		expect(r1.applied).toBe(true)
		expect(p.buttons).toBe(120)
		expect(p.masteryByTower.dardo.points).toBe(10)
		expect(p.campaign["1"]).toBe(nil) -- sem levelId, nada de estrela
		local r2 = ProfileSchema.applyMatchResult(p, input)
		expect(r2.applied).toBe(false)
		expect(r2.reason).toBe("duplicate")
		expect(p.buttons).toBe(120)
	end)
	it("resultado mais antigo que 30 dias não é reprocessado", function()
		local p = ProfileSchema.default(0)
		local r = ProfileSchema.applyMatchResult(p, {
			matchId = "old",
			buttons = 120,
			masteryByTower = {},
			outcome = "won",
			mode = "normal",
			mapId = "jardim",
			difficulty = "normal",
			wavesCompleted = 20,
			createdAt = 0,
			now = 31 * 24 * 3600,
		})
		expect(r.applied).toBe(false)
		expect(r.reason).toBe("expired")
	end)
	it("ledger cheio preserva proteção e recusa aplicar", function()
		local p = ProfileSchema.default(0)
		for i = 1, 1024 do
			p.recentMatchRewards["m" .. i] = 1000
		end
		local r = ProfileSchema.applyMatchResult(p, {
			matchId = "novo",
			buttons = 120,
			masteryByTower = {},
			outcome = "won",
			mode = "normal",
			mapId = "jardim",
			difficulty = "normal",
			wavesCompleted = 20,
			createdAt = 1000,
			now = 1000,
		})
		expect(r.applied).toBe(false)
		expect(r.reason).toBe("ledger_full")
		expect(p.buttons).toBe(0)
	end)
	it("P06: estrelas de uma fase são guardadas e pagas uma vez", function()
		local p = ProfileSchema.default(0)
		local input = {
			matchId = "m-fase-1",
			buttons = 120,
			masteryByTower = {},
			outcome = "won",
			mode = "normal",
			mapId = "jardim",
			difficulty = "normal",
			wavesCompleted = 3,
			levelId = "1",
			stars = 2,
			createdAt = 10,
			now = 20,
		}
		local first = ProfileSchema.applyMatchResult(p, input)
		expect(first.applied).toBe(true)
		expect(first.newStars).toBe(2)
		expect(first.unlockedLevelId).toBe("2")
		expect(p.campaign["1"]).toBe(2)
		expect(p.buttons).toBe(120 + 2 * Balance.campaign.buttonsPerStar)
		-- repetir a mesma partida não paga de novo
		expect(ProfileSchema.applyMatchResult(p, input).applied).toBe(false)
		-- voltar com resultado pior mantém o melhor
		local worse = table.clone(input)
		worse.matchId = "m-fase-1b"
		worse.stars = 1
		local second = ProfileSchema.applyMatchResult(p, worse)
		expect(second.applied).toBe(true)
		expect(second.newStars).toBe(0)
		expect(p.campaign["1"]).toBe(2)
		-- melhorar paga só a diferença
		local better = table.clone(input)
		better.matchId = "m-fase-1c"
		better.stars = 3
		local third = ProfileSchema.applyMatchResult(p, better)
		expect(third.newStars).toBe(1)
		expect(p.campaign["1"]).toBe(3)
	end)
	it("marcos de domínio são registrados uma vez", function()
		local p = ProfileSchema.default(0)
		local r = ProfileSchema.applyMatchResult(p, {
			matchId = "a",
			buttons = 0,
			masteryByTower = { goma = 35 },
			outcome = "won",
			mode = "normal",
			mapId = "jardim",
			difficulty = "normal",
			wavesCompleted = 20,
			createdAt = 0,
			now = 0,
		})
		expect(r.newMilestones.goma).toEqual({ 30 })
		local r2 = ProfileSchema.applyMatchResult(p, {
			matchId = "b",
			buttons = 0,
			masteryByTower = { goma = 70 },
			outcome = "won",
			mode = "normal",
			mapId = "jardim",
			difficulty = "normal",
			wavesCompleted = 20,
			createdAt = 0,
			now = 0,
		})
		expect(r2.newMilestones.goma).toEqual({ 100 })
		expect(p.masteryByTower.goma.milestones).toEqual({ 30, 100 })
	end)
	it("compra de torre exige botões e não repete", function()
		local p = ProfileSchema.default(0)
		local ok, err = ProfileSchema.buyTower(p, "lupa", 1)
		expect(ok).toBe(false)
		expect(err).toBe("INSUFFICIENT_FUNDS")
		p.buttons = 240
		expect(ProfileSchema.buyTower(p, "lupa", 1)).toBe(true)
		expect(p.buttons).toBe(0)
		expect(p.loadout[4]).toBe("lupa")
		expect(ProfileSchema.buyTower(p, "lupa", 1)).toBe(false)
	end)
	it("loadout aceita até quatro torres distintas possuídas", function()
		local p = ProfileSchema.default(0)
		expect(ProfileSchema.setLoadout(p, { "dardo", "dardo" }, 1)).toBe(false)
		expect(ProfileSchema.setLoadout(p, { "voltz" }, 1)).toBe(false)
		expect(ProfileSchema.setLoadout(p, { "goma", "dardo" }, 1)).toBe(true)
		expect(p.loadout).toEqual({ "goma", "dardo" })
		expect(ProfileSchema.setLoadout(p, { "dardo", "pipoca", "goma", "dardo", "pipoca" }, 1)).toBe(false)
	end)
	it("desbloqueio segue a campanha: uma estrela abre a fase seguinte", function()
		local p = ProfileSchema.default(0)
		local levels = Balance.campaign.levels
		expect(ProfileSchema.campaignUnlocked(p, levels[1].id)).toBe(true)
		expect(ProfileSchema.campaignUnlocked(p, levels[2].id)).toBe(false)
		ProfileSchema.applyLevelResult(p, levels[1].id, 1)
		expect(ProfileSchema.campaignUnlocked(p, levels[2].id)).toBe(true)
		expect(ProfileSchema.campaignUnlocked(p, levels[3].id)).toBe(false)
		expect(ProfileSchema.campaignUnlocked(p, "fase-que-nao-existe")).toBe(false)
	end)
	it("interruptor de desenvolvimento abre tudo", function()
		local p = ProfileSchema.default(0)
		local last = Balance.campaign.levels[#Balance.campaign.levels]
		local expected = DevFlags.unlockAllMaps or ProfileSchema.campaignUnlocked(p, last.id)
		expect(ProfileSchema.isLevelUnlocked(p, last.id)).toBe(expected)
	end)
	it("sanitiza configurações", function()
		local s = ProfileSchema.sanitizeSettings(
			{ musicVolume = 5, locale = "xx", circuitPattern = "dashed", reducedMotion = true },
			ProfileSchema.defaultSettings()
		)
		expect(s.musicVolume).toBe(1)
		expect(s.locale).toBe("pt-br")
		expect(s.circuitPattern).toBe("dashed")
		expect(s.reducedMotion).toBe(true)
	end)
end)

describe("Localization", function()
	it("inglês cobre todas as chaves do português", function()
		expect(Localization.missingKeys("en")).toEqual({})
	end)
	it("substitui parâmetros", function()
		expect(Localization.get("build.noFunds", { missing = 120 })).toBe("Faltam 120 sucatas")
		Localization.setLocale("en")
		expect(Localization.get("build.noFunds", { missing = 120 })).toBe("120 scrap missing")
		Localization.setLocale("pt-br")
	end)
end)
