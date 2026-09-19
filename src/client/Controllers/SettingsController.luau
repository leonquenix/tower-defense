--!strict
-- Preferências locais (espelho do que está salvo no perfil), guardadas no átomo Atoms.settings.
--
-- Mudar aqui é imediato na tela; persistir é outra coisa (a tela de Configurações manda
-- SaveSettings). Assim, um servidor fora do ar não impede o jogador de baixar a música.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local ProfileSchema = require(ReplicatedStorage.Shared.Profile.ProfileSchema)
local Types = require(ReplicatedStorage.Shared.Types)
local Charm = require(ReplicatedStorage.Shared.Lib.Charm)
local Atoms = require(script.Parent.Parent.State.Atoms)
local Accessibility = require(script.Parent.Parent.UI.Accessibility)

local SettingsController = {}

local localeListeners: { (locale: string) -> () } = {}
local appliedLocale = ProfileSchema.defaultSettings().locale

Atoms.settings(ProfileSchema.defaultSettings())

function SettingsController.get(): Types.ProfileSettings
	return Atoms.settings() or ProfileSchema.defaultSettings()
end

-- Aplica um conjunto parcial de preferências já saneado pelo esquema compartilhado.
function SettingsController.apply(settings: { [string]: any })
	local next_ = ProfileSchema.sanitizeSettings(settings, SettingsController.get())
	Atoms.settings(next_)
	Accessibility.setGamePreferences(next_.reducedMotion, next_.reducedParticles)
	Localization.setLocale(next_.locale)
	if next_.locale ~= appliedLocale then
		appliedLocale = next_.locale
		for _, fn in ipairs(localeListeners) do
			task.spawn(fn, next_.locale)
		end
	end
end

function SettingsController.set(key: string, value: any)
	local patch: { [string]: any } = {}
	patch[key] = value
	SettingsController.apply(patch)
end

function SettingsController.onChanged(fn: (Types.ProfileSettings) -> ()): () -> ()
	return Charm.subscribe(Atoms.settings, function(value: Types.ProfileSettings?)
		if value then
			fn(value)
		end
	end)
end

-- Trocar o idioma reescreve texto já desenhado, então a árvore de interface é remontada.
function SettingsController.onLocaleChanged(fn: (locale: string) -> ())
	table.insert(localeListeners, fn)
end

function SettingsController.reducedMotion(): boolean
	return SettingsController.get().reducedMotion
end

return SettingsController
