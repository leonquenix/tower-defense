--!strict
-- Definição do comando (replicada ao cliente pelo Cmdr).
return {
	Name = "forceWin",
	Aliases = { "win" },
	Description = "Encerra a partida como vitória, com o número de estrelas pedido.",
	Group = "Teste",
	Args = {
		{
			Type = "integer",
			Name = "stars",
			Description = "Quantas estrelas gravar (0 a 3). Sem valor, grava três.",
			Optional = true,
		},
	},
}
