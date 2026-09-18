--!strict
--[=[
	Constants for the input action system wrapper.

	@class InputServiceConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type InputServiceConstants = {
	ROOT_FOLDER_NAME: string,
	ROOT_FOLDER_CLASS_NAME: string,
	CONTEXT_CLASS_NAME: string,
	ACTION_CLASS_NAME: string,
	BINDING_CLASS_NAME: string,
	DEFAULT_CONTEXT_PRIORITY: number,
}

return Table.readonly({
	ROOT_FOLDER_NAME = "Inputs",
	ROOT_FOLDER_CLASS_NAME = "Folder",
	CONTEXT_CLASS_NAME = "InputContext",
	ACTION_CLASS_NAME = "InputAction",
	BINDING_CLASS_NAME = "InputBinding",
	DEFAULT_CONTEXT_PRIORITY = 0,
} :: InputServiceConstants)
