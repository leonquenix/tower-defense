--!strict
-- ARQUIVO GERADO por tools/import_brand_assets.py a partir de assets/export/brand_assets.json.
-- Arte de marca: logotipo e fundo das telas de menu. image == nil quando ainda não foi
-- publicado; nesse caso a tela desenha o próprio título e o cenário de reserva.

export type BrandAsset = {
	image: string?,
	width: number,
	height: number,
	aspect: number,
}

local Brand: { [string]: BrandAsset } = {
	logo = {
		aspect = 2.4755,
		height = 797,
		image = "rbxassetid://132723613362335",
		width = 1973,
	},
	menuBackground = {
		aspect = 1.7768,
		height = 941,
		image = "rbxassetid://131384553190382",
		width = 1672,
	},
}

return Brand
