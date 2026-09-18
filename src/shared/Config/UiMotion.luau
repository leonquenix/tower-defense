--!strict
-- ARQUIVO GERADO por tools/import_ui_tokens.py a partir de
-- UI_Quintal_em_Guarda_v1/dados/animacoes.json (sha256 191147ab4b94019de36c37cd5277dfd77deee3141c16383cf51484a70853d34d)
-- Não edite à mão: altere o JSON e rode a ferramenta.
-- duration em segundos; style/direction nomeiam Enum.EasingStyle/Enum.EasingDirection.
-- normal e reduced descrevem o efeito esperado (o código lê as duas variantes).

export type Recipe = {
	duration: number,
	style: string,
	direction: string,
	normal: string,
	reduced: string,
}

local UiMotion: { [string]: Recipe } = {
	balance = {
		direction = "Out",
		duration = 0.2,
		normal = "número visual do saldo anterior ao confirmado",
		reduced = "Valor final imediato",
		style = "Linear",
	},
	boss_warning = {
		direction = "Out",
		duration = 2,
		normal = "ícone + texto regressivo pelo servidor",
		reduced = "Ícone estático + texto",
		style = "Linear",
	},
	build = {
		direction = "Out",
		duration = 0.18,
		normal = "sprite escala 0,90 → 1 sem deslocar célula",
		reduced = "Escala 1 imediata",
		style = "Back",
	},
	cooldown = {
		direction = "Out",
		duration = 0,
		normal = "preenchimento calculado por readyAt − simTime",
		reduced = "Mesmo preenchimento, sem pulso",
		style = "Linear",
	},
	hover_focus = {
		direction = "Out",
		duration = 0.1,
		normal = "escala 1 → 1,03; contorno de foco 3 px",
		reduced = "Somente contorno",
		style = "Quad",
	},
	modal_enter = {
		direction = "Out",
		duration = 0.18,
		normal = "scrim alpha 0 → 0,45; painel 0,96 → 1",
		reduced = "Alpha em 80 ms",
		style = "Quad",
	},
	panel_enter = {
		direction = "Out",
		duration = 0.18,
		normal = "alpha 0 → 1; deslocamento vertical 12 → 0 px",
		reduced = "Somente alpha em 80 ms",
		style = "Quad",
	},
	panel_exit = {
		direction = "In",
		duration = 0.12,
		normal = "alpha 1 → 0; remover após término",
		reduced = "Alpha em 80 ms",
		style = "Quad",
	},
	press = {
		direction = "Out",
		duration = 0.08,
		normal = "escala 1 → 0,97; retorno em 100 ms",
		reduced = "Somente mudança de preenchimento",
		style = "Quad",
	},
	result = {
		direction = "Out",
		duration = 0.24,
		normal = "painel entra; até 12 partículas por 450 ms",
		reduced = "Painel sem partículas",
		style = "Quad",
	},
	toast = {
		direction = "Out",
		duration = 0.16,
		normal = "alpha e deslocamento 8 px; sucesso permanece 2,5 s",
		reduced = "Alpha em 80 ms",
		style = "Quad",
	},
	upgrade = {
		direction = "Out",
		duration = 0.35,
		normal = "borda dourada e troca de sprite aos 175 ms",
		reduced = "Troca imediata e rótulo",
		style = "Quad",
	},
}

return UiMotion
