--!strict
-- Definição do comando (replicada ao cliente pelo Cmdr). Só descreve nome, grupo e argumentos:
-- quem executa é o par `setCoinsServer`, que nunca sai do servidor.
return {
	Name = "setCoins",
	Aliases = { "setScrap", "coins" },
	Description = "Define a sucata do jogador na partida em andamento.",
	Group = "Teste",
	Args = {
		{
			Type = "integer",
			Name = "amount",
			Description = "Quanta sucata o jogador passa a ter.",
		},
	},
}
