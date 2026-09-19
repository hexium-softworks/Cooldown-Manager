--!strict
--[=[
	Constants for AudioService.

	@class AudioServiceConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type AudioServiceConstants = {
	ROOT_FOLDER_NAME: string,
	ROOT_FOLDER_CLASS_NAME: string,
	CATEGORIES_FOLDER_NAME: string,
	ASSETS_FOLDER_NAME: string,
	EFFECTS_FOLDER_NAME: string,
	SOUND_SERVICE_FOLDER_NAME: string,
	PLAYBACK_FOLDER_NAME: string,
	VOICE_FOLDER_NAME: string,
	LISTENERS_FOLDER_NAME: string,
	TEMPORARY_FOLDER_NAME: string,
	MASTER_CATEGORY_NAME: string,
	DEFAULT_CATEGORY_VOLUME: number,
}

return Table.readonly({
	ROOT_FOLDER_NAME = "AudioService",
	ROOT_FOLDER_CLASS_NAME = "Folder",
	CATEGORIES_FOLDER_NAME = "Categories",
	ASSETS_FOLDER_NAME = "Assets",
	EFFECTS_FOLDER_NAME = "Effects",
	SOUND_SERVICE_FOLDER_NAME = "AudioService",
	PLAYBACK_FOLDER_NAME = "Playback",
	VOICE_FOLDER_NAME = "Voice",
	LISTENERS_FOLDER_NAME = "Listeners",
	TEMPORARY_FOLDER_NAME = "Temporary",
	MASTER_CATEGORY_NAME = "Master",
	DEFAULT_CATEGORY_VOLUME = 1,
} :: AudioServiceConstants)
