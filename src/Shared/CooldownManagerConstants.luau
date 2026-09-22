--!strict
--[=[
	Constants and public enum values for CooldownManager.

	@class CooldownManagerConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local CooldownPolicy = Table.readonly({
	Reject = "Reject",
	Restart = "Restart",
	KeepLonger = "KeepLonger",
	Extend = "Extend",
})

local constants = {
	CooldownPolicy = CooldownPolicy,

	MaxKeyLength = 128,
	ReservedKeyPrefix = "__",

	DefaultRemainingRate = 10,
	DefaultProgressRate = 30,
}

return Table.readonly(constants)
