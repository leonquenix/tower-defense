local Actions = load("Client/State/Actions")
local Atoms = load("Client/State/Atoms")
local Selectors = load("Client/State/Selectors")
local Protocol = load("Shared/Net/Protocol")
local Localization = load("Shared/Config/Localization")

local function newInvite(id, expiresAt)
	return {
		inviteId = id,
		partyId = "p1",
		fromUserId = 10,
		fromName = "Ana",
		mapId = "jardim",
		difficulty = "normal",
		expiresAt = expiresAt,
		state = "pending",
	}
end

describe("Estado / convites", function()
	it("um convite vencido deixa de ser aceitável e some depois da carência", function()
		Atoms.clear()
		Actions.addInvite(newInvite("i1", 100))
		expect(#Atoms.invites()).toBe(1)
		expect(Atoms.invites()[1].state).toBe("pending")
		-- antes do prazo, nada muda
		Actions.expireInvites(99)
		expect(Atoms.invites()[1].state).toBe("pending")
		-- no prazo, vira expirado (o cartão explica em vez de sumir na cara do jogador)
		Actions.expireInvites(100)
		expect(Atoms.invites()[1].state).toBe("expired")
		-- passada a carência, sai da lista
		Actions.expireInvites(104)
		expect(#Atoms.invites()).toBe(0)
	end)

	it("não duplica o mesmo inviteId", function()
		Atoms.clear()
		Actions.addInvite(newInvite("i2", 100))
		Actions.addInvite(newInvite("i2", 100))
		expect(#Atoms.invites()).toBe(1)
	end)

	it("responder remove o convite da lista", function()
		Atoms.clear()
		Actions.addInvite(newInvite("i3", 100))
		Actions.removeInvite("i3")
		expect(#Atoms.invites()).toBe(0)
	end)

	it("cooldown por destinatário é de 5 s e não repete automaticamente", function()
		Atoms.clear()
		Actions.markInviteSent(42, "sent", 1000)
		expect(Selectors.inviteCooldownLeft(42, 1000) > 0).toBeTruthy()
		expect(Selectors.inviteCooldownLeft(42, 1000) <= 5).toBeTruthy()
		expect(Selectors.inviteCooldownLeft(42, 1006)).toBe(0)
		expect(Selectors.inviteCooldownLeft(43, 1000)).toBe(0)
	end)

	it("átomo troca a lista inteira: quem já leu não vê mudança por baixo", function()
		Atoms.clear()
		Actions.addInvite(newInvite("i4", 100))
		local before = Atoms.invites()
		Actions.setInviteState("i4", "accepted")
		expect(before[1].state).toBe("pending")
		expect(Atoms.invites()[1].state).toBe("accepted")
	end)
end)

describe("Estado / conexão", function()
	it("2 s sem atualização é sinal instável e 5 s bloqueia mutações", function()
		Atoms.clear()
		local base = 1000
		Actions.noteFrame(base)
		expect(Actions.updateConnection(base)).toBe("ok")
		expect(Selectors.canMutate()).toBeTruthy()

		expect(Actions.updateConnection(base + 2.5)).toBe("unstable")
		-- sinal instável ainda permite agir: o tabuleiro não é apagado no primeiro atraso
		expect(Selectors.canMutate()).toBeTruthy()

		expect(Actions.updateConnection(base + 6)).toBe("reconciling")
		expect(Selectors.canMutate()).toBe(false)
	end)

	it("um frame novo devolve o estado para ok", function()
		Atoms.clear()
		Actions.setConnection("reconciling")
		Actions.noteFrame(2000)
		expect(Atoms.connection()).toBe("ok")
	end)
end)

describe("Estado / avisos curtos", function()
	it("a fila guarda no máximo três avisos", function()
		Atoms.clear()
		for index = 1, 5 do
			Actions.toast("aviso " .. index, "info", 1000)
		end
		expect(#Atoms.toasts()).toBe(3)
		expect(Atoms.toasts()[3].text).toBe("aviso 5")
	end)

	it("o mesmo texto não entra duas vezes em menos de um segundo", function()
		Atoms.clear()
		Actions.toast("repetido", "info", 1000)
		Actions.toast("repetido", "info", 1000.4)
		expect(#Atoms.toasts()).toBe(1)
	end)

	it("avisos vencidos saem da fila", function()
		Atoms.clear()
		Actions.toast("some", "info", 1000)
		expect(Actions.expireToasts(1000 + Actions.TOAST_SECONDS + 0.1)).toBe(true)
		expect(#Atoms.toasts()).toBe(0)
	end)
end)

describe("Estado / navegação", function()
	it("push guarda a origem e back volta para ela", function()
		Atoms.clear()
		Actions.navigate("menu")
		Actions.push("settings", { inMatch = false })
		expect(Atoms.route()).toBe("settings")
		expect(Actions.back()).toBe(true)
		expect(Atoms.route()).toBe("menu")
		-- sem origem guardada, back não inventa uma
		expect(Actions.back()).toBe(false)
	end)

	it("navigate limpa a pilha: a tela lateral não vira origem", function()
		Atoms.clear()
		Actions.push("collection")
		Actions.navigate("maps")
		expect(Actions.back()).toBe(false)
		expect(Atoms.route()).toBe("maps")
	end)
end)

describe("Estado / resultado pendente", function()
	it("guarda e limpa o resultado pendente sem apagar o matchId", function()
		Atoms.clear()
		Actions.setPendingResult({ matchId = "m1", status = "pending", buttons = 120 })
		expect(Atoms.pendingResult().matchId).toBe("m1")
		Actions.setPendingResult(nil)
		expect(Atoms.pendingResult()).toBeNil()
	end)
end)

describe("Protocol / RespondInvite", function()
	local function env(action, payload)
		return {
			protocolVersion = 1,
			sessionSequence = 1,
			requestId = "r1",
			action = action,
			payload = payload,
		}
	end

	it("aceita inviteId e accept bem formados", function()
		local ok, err = Protocol.validateEnvelope(env("RespondInvite", { inviteId = "abc123", accept = true }))
		expect(ok).toBeTruthy()
		expect(err).toBeNil()
	end)

	it("recusa resposta sem token ou com campo extra", function()
		expect(select(2, Protocol.validateEnvelope(env("RespondInvite", { accept = true })))).toBe("BAD_REQUEST")
		expect(
			select(2, Protocol.validateEnvelope(env("RespondInvite", { inviteId = "a", accept = true, partyId = "p" })))
		).toBe("BAD_REQUEST")
		expect(select(2, Protocol.validateEnvelope(env("RespondInvite", { inviteId = "a", accept = 1 })))).toBe(
			"BAD_REQUEST"
		)
	end)

	it("convite gasta o balde persistente, não o de combate", function()
		expect(Protocol.PERSISTENT_ACTIONS.RespondInvite).toBe(true)
		expect(Protocol.PERSISTENT_ACTIONS.InviteToParty).toBe(true)
		expect(Protocol.COMBAT_ACTIONS.RespondInvite).toBeNil()
	end)
end)

describe("Localização / textos da interface", function()
	it("nenhum texto entregue mostra o marcador de preço", function()
		for _, locale in ipairs(Localization.locales()) do
			Localization.setLocale(locale)
			-- o preço só aparece depois de vir da plataforma
			expect(Localization.get("shop.buy", { price = "199" }):find("{pre") == nil).toBeTruthy()
			expect(Localization.get("shop.priceIs", { price = "199" }):find("{") == nil).toBeTruthy()
		end
		Localization.setLocale("pt-br")
	end)

	it("todo código de erro do protocolo tem texto próprio", function()
		for _, code in pairs(Protocol.ERROR) do
			expect(Localization.has("error." .. code)).toBeTruthy()
		end
		-- código desconhecido cai no texto de reserva
		expect(Localization.has("error.UNKNOWN")).toBeTruthy()
	end)

	it("motivos de bloqueio de construção existem nos dois idiomas", function()
		for _, key in ipairs({ "build.onPath", "build.occupied", "build.limit", "build.noFunds", "build.invalidCell" }) do
			expect(Localization.has(key)).toBeTruthy()
		end
		expect(#Localization.missingKeys("en")).toBe(0)
	end)
end)
