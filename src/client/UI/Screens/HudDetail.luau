--!strict
-- Painel de detalhe do combate: a torre selecionada (atributos, melhoria, alvo, venda) ou o
-- inimigo selecionado (vida, proteções, estado).
--
-- Os números vêm do catálogo e do snapshot; nenhuma conta de dano acontece aqui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children
local peek = Fusion.peek

local L = Localization.get

export type Props = { localUserId: number }

local function decimal(value: number, places: number?): string
	local text = string.format("%." .. tostring(places or 1) .. "f", value)
	text = text:gsub("%.?0+$", "")
	return (text:gsub("%.", ","))
end

local function statLines(def: Types.TowerDef, stats: Types.TowerStateStats): { string }
	local lines: { string } = {}
	if def.damageType ~= "none" then
		table.insert(lines, L("detail.damage", { value = decimal(stats.damage, 1) }))
		table.insert(lines, L("detail.interval", { value = decimal(stats.interval, 2) }))
	end
	table.insert(lines, L("detail.range", { value = decimal(stats.range, 1) }))
	if stats.haste then
		table.insert(lines, L("detail.haste", { value = math.floor(stats.haste * 100 + 0.5) }))
	end
	if stats.slow and stats.slowDuration then
		table.insert(
			lines,
			L("detail.slow", {
				value = math.floor(stats.slow * 100 + 0.5),
				duration = decimal(stats.slowDuration, 1),
			})
		)
	end
	if stats.splash then
		table.insert(lines, L("detail.splash", { value = decimal(stats.splash, 1) }))
	end
	if stats.chains then
		table.insert(lines, L("detail.chains", { value = stats.chains }))
	end
	if stats.armorIgnore then
		table.insert(lines, L("detail.armorIgnore", { value = math.floor(stats.armorIgnore * 100 + 0.5) }))
	end
	if stats.bossBonus then
		table.insert(lines, L("detail.bossBonus", { value = math.floor(stats.bossBonus * 100 + 0.5) }))
	end
	if stats.mark then
		table.insert(
			lines,
			L("detail.mark", {
				value = math.floor(stats.mark * 100 + 0.5),
				duration = decimal(stats.markDuration or 0, 1),
			})
		)
	end
	return lines
end

return function(scope: Kit.Scope, props: Props): Frame
	local towers = Bridge.use(scope, Atoms.towers)
	local snapshot = Bridge.use(scope, Atoms.snapshot)
	local selectedTowerId = Bridge.use(scope, Atoms.selectedTowerId)
	local selectedEnemyId = Bridge.use(scope, Atoms.selectedEnemyId)

	local tower = scope:Computed(function(use): Types.TowerSnapshot?
		local id = Kit.read(use, selectedTowerId)
		if not id then
			return nil
		end
		return Kit.read(use, towers)[id]
	end)
	local enemy = scope:Computed(function(use): Types.EnemySnapshot?
		local id = Kit.read(use, selectedEnemyId)
		local current = Kit.read(use, snapshot)
		if not id or not current then
			return nil
		end
		for _, entry in ipairs(current.enemies) do
			if entry.id == id then
				return entry
			end
		end
		return nil
	end)
	local visible = scope:Computed(function(use)
		return Kit.read(use, tower) ~= nil or Kit.read(use, enemy) ~= nil
	end)
	local mine = scope:Computed(function(use)
		local current = use(tower)
		return current ~= nil and current.o == props.localUserId
	end)

	local title = scope:Computed(function(use)
		local current = Kit.read(use, tower)
		if current then
			local def = Catalog.getTower(current.d)
			return if def then def.name .. " · " .. current.st else current.d
		end
		local target = Kit.read(use, enemy)
		if target then
			return L("enemy." .. target.d)
		end
		return ""
	end)

	local lines = scope:Computed(function(use): { string }
		local current = Kit.read(use, tower)
		if current then
			local def = Catalog.getTower(current.d)
			local stats = Catalog.getStateStats(current.d, current.st)
			local out: { string } = {}
			if def and stats then
				out = statLines(def, stats)
			end
			if current.ci then
				table.insert(out, L("detail.circuit") .. ": " .. L("circuit." .. current.ci))
			end
			if not (current.o == props.localUserId) then
				table.insert(out, L("detail.notYours"))
			end
			return out
		end
		local target = Kit.read(use, enemy)
		if target then
			local out: { string } = {
				math.floor(target.hp + 0.5) .. " / " .. math.floor(target.mhp + 0.5),
			}
			if target.ar > 0 then
				table.insert(out, L("hud.armorPhysical", { value = math.floor(target.ar * 100 + 0.5) }))
			end
			if target.er > 0 then
				table.insert(out, L("hud.armorEnergy", { value = math.floor(target.er * 100 + 0.5) }))
			end
			if target.sl > 0 then
				table.insert(
					out,
					L("detail.slow", {
						value = math.floor(target.sl * 100 + 0.5),
						duration = "—",
					})
				)
			end
			if Localization.has("enemy.trait." .. target.d) then
				table.insert(out, L("enemy.trait." .. target.d))
			end
			return out
		end
		return {}
	end)

	local nextStates = scope:Computed(function(use): { string }
		local current = Kit.read(use, tower)
		if not current or not Kit.read(use, mine) then
			return {}
		end
		local transitions: { string } = (Catalog.TRANSITIONS[current.st] :: any) or {}
		return transitions
	end)

	return Kit.panel(scope, {
		name = "Detail",
		blocking = true,
		visible = visible,
		size = UDim2.new(1, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = 2,
		padding = 16,
		zIndex = 18,
		layout = Kit.list(scope, { Padding = UDim.new(0, 8) }),
		-- o "fechar" fica fora da fila do layout, no canto do painel
		overlay = Kit.children(Kit.button(scope, {
			name = "Close",
			text = "✕",
			kind = "ghost",
			size = UDim2.fromOffset(40, 40),
			position = UDim2.new(1, -10, 0, 8),
			anchorPoint = Vector2.new(1, 0),
			zIndex = 21,
			onActivate = function()
				Actions.selectTower(nil)
				Actions.selectEnemy(nil)
			end,
		})),
		children = Kit.children(
			Kit.title(scope, {
				Text = title,
				TextSize = 22,
				Size = UDim2.new(1, -40, 0, 26),
				LayoutOrder = 1,
				ZIndex = 19,
			}),
			scope:New("Frame")({
				Name = "Stats",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				ZIndex = 19,
				[Children] = Kit.children(
					Kit.list(scope, { Padding = UDim.new(0, 3) }),
					scope:ForValues(lines, function(_, innerScope: Kit.Scope, line: string)
						return Kit.text(innerScope, {
							Text = line,
							TextSize = 14,
							TextColor3 = Theme.colors.muted,
							Size = UDim2.new(1, 0, 0, 18),
							ZIndex = 19,
						})
					end)
				),
			}),
			-- Melhorias: uma por caminho disponível, sempre com o custo no rótulo.
			scope:New("Frame")({
				Name = "Upgrades",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				ZIndex = 19,
				[Children] = Kit.children(
					Kit.list(scope, { Padding = UDim.new(0, 6) }),
					scope:ForValues(nextStates, function(_, innerScope: Kit.Scope, nextState: string)
						local cost = innerScope:Computed(function(use)
							local current = Kit.read(use, tower)
							if not current then
								return 0
							end
							local stats = Catalog.getStateStats(current.d, nextState)
							return if stats then stats.cost else 0
						end)
						return Kit.button(innerScope, {
							name = "Upgrade_" .. nextState,
							text = innerScope:Computed(function(use)
								return L("detail.upgrade", { cost = use(cost) })
							end),
							sub = nextState,
							kind = "primary",
							size = UDim2.new(1, 0, 0, 48),
							zIndex = 20,
							disabled = innerScope:Computed(function(use)
								local current = Kit.read(use, snapshot)
								local price = Kit.read(use, cost)
								if not current then
									return true
								end
								return current.mode ~= "training" and current.wallet < price
							end),
							onActivate = function()
								local current: Types.TowerSnapshot? = peek(tower)
								if current then
									GameFlow.upgradeTower(current.id, nextState)
								end
							end,
						})
					end)
				),
			}),
			-- Alvo: quatro modos, o atual fica marcado.
			scope:New("Frame")({
				Name = "Targets",
				BackgroundTransparency = 1,
				Visible = mine,
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 4,
				ZIndex = 19,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 4),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Kit.button(scope, {
						name = "TargetCycle",
						text = scope:Computed(function(use)
							local current = use(tower)
							return L("detail.target", {
								mode = L("target." .. (if current then current.tm else "first")),
							})
						end),
						kind = "secondary",
						icon = "ui_target",
						size = UDim2.new(1, 0, 0, 40),
						zIndex = 20,
						onActivate = function()
							local current: Types.TowerSnapshot? = peek(tower)
							if not current then
								return
							end
							local modes = Catalog.TARGET_MODES
							local index = table.find(modes, current.tm :: any) or 1
							local nextMode = modes[(index % #modes) + 1]
							GameFlow.setTarget(current.id, nextMode)
						end,
					})
				),
			}),
			Kit.button(scope, {
				name = "Sell",
				text = scope:Computed(function(use)
					local current: Types.TowerSnapshot? = Kit.read(use, tower)
					local refund = if current then math.floor(current.inv * 0.7 + 0.5) else 0
					return L("detail.sell", { refund = refund })
				end),
				kind = "danger",
				icon = "ui_sell",
				visible = mine,
				size = UDim2.new(1, 0, 0, 44),
				layoutOrder = 5,
				zIndex = 20,
				onActivate = function()
					local current: Types.TowerSnapshot? = peek(tower)
					if not current then
						return
					end
					local def = Catalog.getTower(current.d)
					local refund = math.floor(current.inv * 0.7 + 0.5)
					local selected = current :: Types.TowerSnapshot
					Actions.openModal({
						title = L("detail.sellTitle", { tower = if def then def.name else selected.d }),
						body = L("detail.sellConfirm", {
							tower = if def then def.name else selected.d,
							refund = refund,
						}),
						confirmText = L("detail.sellAction", { refund = refund }),
						danger = true,
						onConfirm = function()
							Actions.closeModal()
							GameFlow.sellTower(selected.id)
						end,
					})
				end,
			})
		),
	})
end
