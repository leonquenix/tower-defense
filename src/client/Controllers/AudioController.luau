--!strict
-- Pontos de integração de áudio. Nenhum som licenciado foi incluído: os IDs ficam vazios e as chamadas
-- são silenciosas até que áudio próprio seja produzido e registrado (ver MANUAL_ACTIONS).
local SoundService = game:GetService("SoundService")

local SettingsController = require(script.Parent.SettingsController)

local AudioController = {}

-- Chave lógica -> ContentId. Preencher somente com áudio próprio/licenciado após upload real.
local SOUND_IDS: { [string]: string? } = {
	ui_click = nil,
	ui_confirm = nil,
	ui_error = nil,
	ui_open = nil,
	shot_dardo = nil,
	shot_pipoca = nil,
	shot_lupa = nil,
	shot_goma = nil,
	shot_voltz = nil,
	support_maestro = nil,
	impact_light = nil,
	impact_heavy = nil,
	impact_energy = nil,
	boss_telegraph = nil,
	boss_ability = nil,
	boss_spawn = nil,
	wave_start = nil,
	wave_end = nil,
	base_hit = nil,
	base_pulse = nil,
	result_win = nil,
	result_lose = nil,
	ui_upgrade = nil,
	unlock = nil,
	music_menu = nil,
	music_jardim = nil,
	music_oficina = nil,
	music_sotao = nil,
}

local MAX_VOICES = 16
local activeVoices = 0
local missingReported: { [string]: boolean } = {}
local musicSound: Sound? = nil
local currentMusic: string? = nil

function AudioController.play(key: string, priority: boolean?)
	local id = SOUND_IDS[key]
	if not id then
		if not missingReported[key] then
			missingReported[key] = true
		end
		return
	end
	if activeVoices >= MAX_VOICES and not priority then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = SettingsController.get().sfxVolume
	sound.Parent = SoundService
	activeVoices += 1
	sound.Ended:Once(function()
		activeVoices -= 1
		sound:Destroy()
	end)
	sound:Play()
end

function AudioController.music(key: string?)
	if currentMusic == key then
		return
	end
	currentMusic = key
	if musicSound then
		musicSound:Destroy()
		musicSound = nil
	end
	local id = if key then SOUND_IDS[key] else nil
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = SettingsController.get().musicVolume
	sound.Parent = SoundService
	sound:Play()
	musicSound = sound
end

function AudioController.missingKeys(): { string }
	local list = {}
	for key, id in pairs(SOUND_IDS) do
		if id == nil then
			table.insert(list, key)
		end
	end
	table.sort(list)
	return list
end

SettingsController.onChanged(function(settings)
	if musicSound then
		musicSound.Volume = settings.musicVolume
	end
end)

return AudioController
