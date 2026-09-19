--!strict
--[=[
	Validation helpers for AudioService configs.

	@class AudioServiceConfigUtils
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local AudioServiceConstants = require("AudioServiceConstants")

local AudioServiceConfigUtils = {}

type FieldMap = { [string]: string }

local NAME_MAX_LENGTH = 100

local CATEGORY_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Volume = "number",
})

local EFFECT_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	ClassName = "string",
	Properties = "table",
	Bypass = "boolean",
})

local EFFECT_PRESET_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Effects = "table",
})

local ASSET_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Asset = "any",
	AudioContent = "any",
	Category = "string",
	Volume = "number",
	Looping = "boolean",
	PlaybackSpeed = "number",
	Effects = "table",
	EffectPresets = "table",
})

local PLAYBACK_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	AssetName = "string",
	Asset = "any",
	AudioContent = "any",
	Category = "string",
	Volume = "number",
	Looping = "boolean",
	PlaybackSpeed = "number",
	AutoPlay = "boolean",
	Effects = "table",
	EffectPresets = "table",
	Parent = "Instance",
	Emitter = "AudioEmitter",
})

local EMITTER_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Properties = "table",
	DistanceAttenuation = "table",
	AngleAttenuation = "table",
})

local LISTENER_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Parent = "Instance",
	Properties = "table",
	DistanceAttenuation = "table",
	AngleAttenuation = "table",
})

local VOICE_INPUT_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Player = "Player",
	Volume = "number",
	Muted = "boolean",
	AccessType = "AccessModifierType",
	UserIdAccessList = "table",
})

local VOICE_ROUTE_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Input = "AudioDeviceInput",
	Output = "AudioDeviceOutput",
	Target = "Instance",
	Category = "string",
	Volume = "number",
	Effects = "table",
	EffectPresets = "table",
})

local SUPPORTED_EFFECT_CLASSES = Table.readonly({
	AudioChorus = true,
	AudioCompressor = true,
	AudioDistortion = true,
	AudioEcho = true,
	AudioEqualizer = true,
	AudioFader = true,
	AudioFilter = true,
	AudioFlanger = true,
	AudioGate = true,
	AudioLimiter = true,
	AudioPitchShifter = true,
	AudioReverb = true,
	AudioTremolo = true,
})

local function validateName(value: any, path: string): ()
	assert(typeof(value) == "string", string.format("%s.Name must be a string", path))
	assert(#value > 0, string.format("%s.Name must not be empty", path))
	assert(#value <= NAME_MAX_LENGTH, string.format("%s.Name must be %d characters or fewer", path, NAME_MAX_LENGTH))
	assert(not string.find(value, "[%c/]"), string.format("%s.Name contains unsupported characters", path))
end

local function validateEnumItem(value: any, enumType: any, fieldName: string): ()
	assert(typeof(value) == "EnumItem", string.format("%s must be an EnumItem", fieldName))
	assert(value.EnumType == enumType, string.format("%s must be a member of %s", fieldName, tostring(enumType)))
end

local function validateField(value: any, expectedType: string, fieldName: string): ()
	if expectedType == "any" then
		return
	elseif expectedType == "AccessModifierType" then
		validateEnumItem(value, Enum.AccessModifierType, fieldName)
	elseif expectedType == "Instance" then
		assert(typeof(value) == "Instance", string.format("%s must be an Instance", fieldName))
	elseif expectedType == "Player" then
		assert(typeof(value) == "Instance" and value:IsA("Player"), string.format("%s must be a Player", fieldName))
	elseif expectedType == "AudioEmitter" then
		assert(typeof(value) == "Instance" and value:IsA("AudioEmitter"), string.format("%s must be an AudioEmitter", fieldName))
	elseif expectedType == "AudioDeviceInput" then
		assert(
			typeof(value) == "Instance" and value:IsA("AudioDeviceInput"),
			string.format("%s must be an AudioDeviceInput", fieldName)
		)
	elseif expectedType == "AudioDeviceOutput" then
		assert(
			typeof(value) == "Instance" and value:IsA("AudioDeviceOutput"),
			string.format("%s must be an AudioDeviceOutput", fieldName)
		)
	else
		assert(typeof(value) == expectedType, string.format("%s must be %s", fieldName, expectedType))
	end
end

local function validateKnownFields(config: { [any]: any }, allowedFields: FieldMap, path: string): ()
	for key, value in config do
		assert(typeof(key) == "string", string.format("%s contains a non-string key", path))

		local expectedType = allowedFields[key]
		assert(expectedType ~= nil, string.format("%s.%s is not a supported config field", path, key))

		if value ~= nil then
			validateField(value, expectedType, string.format("%s.%s", path, key))
		end
	end
end

local function validateArray(value: any, path: string): ()
	assert(typeof(value) == "table", string.format("%s must be a table", path))
	for index in value do
		assert(typeof(index) == "number", string.format("%s must be an array", path))
	end
end

local function validatePropertyMap(value: any, path: string): ()
	assert(typeof(value) == "table", string.format("%s must be a table", path))
	for key in value do
		assert(typeof(key) == "string", string.format("%s must contain string property names", path))
	end
end

function AudioServiceConfigUtils.clampVolume(volume: number?): number
	if volume == nil then
		return AudioServiceConstants.DEFAULT_CATEGORY_VOLUME
	end

	assert(typeof(volume) == "number", "Volume must be a number")
	assert(volume == volume, "Volume must not be NaN")
	return math.clamp(volume, 0, 1)
end

function AudioServiceConfigUtils.isSupportedEffectClass(className: string): boolean
	return SUPPORTED_EFFECT_CLASSES[className] == true
end

function AudioServiceConfigUtils.validateCategoryConfig(config: any, path: string?): ()
	local categoryPath = path or "Category"
	assert(typeof(config) == "table", string.format("%s must be a table", categoryPath))
	validateKnownFields(config, CATEGORY_FIELDS, categoryPath)
	validateName(config.Name, categoryPath)

	if config.Volume ~= nil then
		AudioServiceConfigUtils.clampVolume(config.Volume)
	end
end

function AudioServiceConfigUtils.validateEffectConfig(config: any, path: string?): ()
	local effectPath = path or "Effect"
	assert(typeof(config) == "table", string.format("%s must be a table", effectPath))
	validateKnownFields(config, EFFECT_FIELDS, effectPath)
	validateName(config.Name, effectPath)

	assert(
		AudioServiceConfigUtils.isSupportedEffectClass(config.ClassName),
		string.format("%s.ClassName %q is not a supported audio effect", effectPath, tostring(config.ClassName))
	)

	if config.Properties ~= nil then
		validatePropertyMap(config.Properties, string.format("%s.Properties", effectPath))
	end
end

function AudioServiceConfigUtils.validateEffectPresetConfig(config: any, path: string?): ()
	local presetPath = path or "EffectPreset"
	assert(typeof(config) == "table", string.format("%s must be a table", presetPath))
	validateKnownFields(config, EFFECT_PRESET_FIELDS, presetPath)
	validateName(config.Name, presetPath)
	validateArray(config.Effects, string.format("%s.Effects", presetPath))

	for index, effectConfig in config.Effects do
		AudioServiceConfigUtils.validateEffectConfig(effectConfig, string.format("%s.Effects[%d]", presetPath, index))
	end
end

function AudioServiceConfigUtils.validateAssetConfig(config: any, path: string?): ()
	local assetPath = path or "Asset"
	assert(typeof(config) == "table", string.format("%s must be a table", assetPath))
	validateKnownFields(config, ASSET_FIELDS, assetPath)
	validateName(config.Name, assetPath)
	assert(config.Asset ~= nil or config.AudioContent ~= nil, string.format("%s.Asset or AudioContent is required", assetPath))

	if config.Volume ~= nil then
		AudioServiceConfigUtils.clampVolume(config.Volume)
	end

	if config.Effects ~= nil then
		validateArray(config.Effects, string.format("%s.Effects", assetPath))
		for index, effectConfig in config.Effects do
			AudioServiceConfigUtils.validateEffectConfig(effectConfig, string.format("%s.Effects[%d]", assetPath, index))
		end
	end

	if config.EffectPresets ~= nil then
		validateArray(config.EffectPresets, string.format("%s.EffectPresets", assetPath))
	end
end

function AudioServiceConfigUtils.validatePlaybackConfig(config: any, path: string?): ()
	local playbackPath = path or "Playback"
	assert(typeof(config) == "table", string.format("%s must be a table", playbackPath))
	validateKnownFields(config, PLAYBACK_FIELDS, playbackPath)
	assert(
		config.AssetName ~= nil or config.Asset ~= nil or config.AudioContent ~= nil,
		string.format("%s.AssetName, Asset, or AudioContent is required", playbackPath)
	)

	if config.Volume ~= nil then
		AudioServiceConfigUtils.clampVolume(config.Volume)
	end

	if config.Effects ~= nil then
		validateArray(config.Effects, string.format("%s.Effects", playbackPath))
		for index, effectConfig in config.Effects do
			AudioServiceConfigUtils.validateEffectConfig(effectConfig, string.format("%s.Effects[%d]", playbackPath, index))
		end
	end

	if config.EffectPresets ~= nil then
		validateArray(config.EffectPresets, string.format("%s.EffectPresets", playbackPath))
	end
end

function AudioServiceConfigUtils.validateEmitterConfig(config: any, path: string?): ()
	local emitterPath = path or "Emitter"
	assert(typeof(config) == "table", string.format("%s must be a table", emitterPath))
	validateKnownFields(config, EMITTER_FIELDS, emitterPath)

	if config.Name ~= nil then
		validateName(config.Name, emitterPath)
	end

	if config.Properties ~= nil then
		validatePropertyMap(config.Properties, string.format("%s.Properties", emitterPath))
	end
end

function AudioServiceConfigUtils.validateListenerConfig(config: any, path: string?): ()
	local listenerPath = path or "Listener"
	assert(typeof(config) == "table", string.format("%s must be a table", listenerPath))
	validateKnownFields(config, LISTENER_FIELDS, listenerPath)

	if config.Name ~= nil then
		validateName(config.Name, listenerPath)
	end

	if config.Properties ~= nil then
		validatePropertyMap(config.Properties, string.format("%s.Properties", listenerPath))
	end
end

function AudioServiceConfigUtils.validateVoiceInputConfig(config: any, path: string?): ()
	local voicePath = path or "VoiceInput"
	assert(typeof(config) == "table", string.format("%s must be a table", voicePath))
	validateKnownFields(config, VOICE_INPUT_FIELDS, voicePath)

	if config.Name ~= nil then
		validateName(config.Name, voicePath)
	end

	if config.Volume ~= nil then
		AudioServiceConfigUtils.clampVolume(config.Volume)
	end
end

function AudioServiceConfigUtils.validateVoiceRouteConfig(config: any, path: string?): ()
	local routePath = path or "VoiceRoute"
	assert(typeof(config) == "table", string.format("%s must be a table", routePath))
	validateKnownFields(config, VOICE_ROUTE_FIELDS, routePath)

	if config.Name ~= nil then
		validateName(config.Name, routePath)
	end

	if config.Volume ~= nil then
		AudioServiceConfigUtils.clampVolume(config.Volume)
	end

	if config.Effects ~= nil then
		validateArray(config.Effects, string.format("%s.Effects", routePath))
		for index, effectConfig in config.Effects do
			AudioServiceConfigUtils.validateEffectConfig(effectConfig, string.format("%s.Effects[%d]", routePath, index))
		end
	end
end

function AudioServiceConfigUtils.assertCanCreateAudioClass(className: string): ()
	local ok, instance = pcall(Instance.new, className, nil)
	if ok and typeof(instance) == "Instance" then
		instance:Destroy()
		return
	end

	error(
		string.format(
			"%s is not available in this Roblox runtime. Run in an engine with the modern Audio API enabled.",
			className
		),
		2
	)
end

return AudioServiceConfigUtils
