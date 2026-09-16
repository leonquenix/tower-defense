--!strict
-- Configurações locais (espelho do perfil) com sinal de mudança.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local ProfileSchema = require(ReplicatedStorage.Shared.Profile.ProfileSchema)
local Ui = require(script.Parent.Parent.View.Ui)

local SettingsController = {}

local current: Types.ProfileSettings = ProfileSchema.defaultSettings()
local listeners: { (Types.ProfileSettings) -> () } = {}

local function emit()
	Ui.setReducedMotion(current.reducedMotion)
	Localization.setLocale(current.locale)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, current)
	end
end

function SettingsController.get(): Types.ProfileSettings
	return current
end

function SettingsController.apply(settings: { [string]: any })
	current = ProfileSchema.sanitizeSettings(settings, current)
	emit()
end

function SettingsController.set(key: string, value: any)
	local patch: { [string]: any } = {}
	patch[key] = value
	SettingsController.apply(patch)
end

function SettingsController.onChanged(fn: (Types.ProfileSettings) -> ())
	table.insert(listeners, fn)
end

function SettingsController.reducedMotion(): boolean
	return current.reducedMotion
end

emit()

return SettingsController
