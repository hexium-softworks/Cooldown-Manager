--!strict
--[=[
	In-memory category volume registry.

	@class AudioCategoryRegistry
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Signal = require("Signal")

local AudioServiceConfigUtils = require("AudioServiceConfigUtils")
local AudioServiceConstants = require("AudioServiceConstants")
local AudioServiceTypes = require("AudioServiceTypes")

type CategoryConfig = AudioServiceTypes.CategoryConfig

local AudioCategoryRegistry = {}
AudioCategoryRegistry.ClassName = "AudioCategoryRegistry"
AudioCategoryRegistry.__index = AudioCategoryRegistry

export type AudioCategoryRegistry = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_volumes: { [string]: number },
		_signals: { [string]: any },
	},
	AudioCategoryRegistry
))

function AudioCategoryRegistry.new(): AudioCategoryRegistry
	local self: AudioCategoryRegistry = setmetatable({
		_maid = Maid.new(),
		_volumes = {},
		_signals = {},
	}, AudioCategoryRegistry)

	self:RegisterCategory({
		Name = AudioServiceConstants.MASTER_CATEGORY_NAME,
		Volume = AudioServiceConstants.DEFAULT_CATEGORY_VOLUME,
	})

	return self
end

function AudioCategoryRegistry.RegisterCategory(self: AudioCategoryRegistry, config: CategoryConfig): ()
	AudioServiceConfigUtils.validateCategoryConfig(config)

	local volume = AudioServiceConfigUtils.clampVolume(config.Volume)
	if self._volumes[config.Name] == nil then
		self._volumes[config.Name] = volume
	else
		self:SetVolume(config.Name, volume)
	end
end

function AudioCategoryRegistry.RegisterCategories(self: AudioCategoryRegistry, configs: { CategoryConfig }): ()
	assert(typeof(configs) == "table", "Categories must be a table")

	for _, config in configs do
		self:RegisterCategory(config)
	end
end

function AudioCategoryRegistry.GetVolume(self: AudioCategoryRegistry, categoryName: string): number
	assert(typeof(categoryName) == "string", "Category name must be a string")

	local volume = self._volumes[categoryName]
	if volume == nil then
		return AudioServiceConstants.DEFAULT_CATEGORY_VOLUME
	end

	return volume
end

function AudioCategoryRegistry.SetVolume(self: AudioCategoryRegistry, categoryName: string, volume: number): ()
	assert(typeof(categoryName) == "string", "Category name must be a string")

	local clampedVolume = AudioServiceConfigUtils.clampVolume(volume)
	local oldVolume = self._volumes[categoryName]
	self._volumes[categoryName] = clampedVolume

	if oldVolume ~= clampedVolume then
		self:GetVolumeChangedSignal(categoryName):Fire(clampedVolume)
	end
end

function AudioCategoryRegistry.GetVolumeChangedSignal(self: AudioCategoryRegistry, categoryName: string): any
	assert(typeof(categoryName) == "string", "Category name must be a string")

	local signal = self._signals[categoryName]
	if signal then
		return signal
	end

	signal = Signal.new()
	self._signals[categoryName] = signal
	self._maid:GiveTask(signal)
	return signal
end

function AudioCategoryRegistry.ObserveVolume(
	self: AudioCategoryRegistry,
	categoryName: string,
	callback: (number) -> ()
): any
	assert(typeof(callback) == "function", "Callback must be a function")

	callback(self:GetVolume(categoryName))
	return self:GetVolumeChangedSignal(categoryName):Connect(callback)
end

function AudioCategoryRegistry.Destroy(self: AudioCategoryRegistry): ()
	self._maid:DoCleaning()
	table.clear(self._volumes)
	table.clear(self._signals)
end

return AudioCategoryRegistry
