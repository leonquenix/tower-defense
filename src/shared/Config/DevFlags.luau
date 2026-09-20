--!strict
-- Chaves de desenvolvimento. Não é dado gerado nem balanceamento: é interruptor de teste,
-- escrito à mão e lido por cliente e servidor no mesmo lugar para os dois nunca discordarem.
--
-- ANTES DE PUBLICAR: tudo aqui volta para false. O que estiver ligado muda regra de jogo.
local DevFlags = {
	-- Libera todos os mapas e dificuldades, sem depender de vitória anterior nem do tutorial.
	-- Ligado em 2026-09-19 a pedido do responsável, para jogar livremente entre os cenários
	-- enquanto a arte dos mapas é refeita.
	unlockAllMaps = true,

	-- Mostra o guia da primeira fase toda vez, ignorando o `campaignIntroSeen` do perfil.
	-- Serve para conferir o guia sem apagar o perfil; em produção fica false.
	alwaysShowIntro = false,

	-- Publica o console de teste (Cmdr, tecla F2) com os comandos de `src/server/Console`.
	-- Quem pode usá-lo ainda é decidido por `MatchService.isDevAllowed` (Studio ou lista).
	testConsole = true,
}

return DevFlags
