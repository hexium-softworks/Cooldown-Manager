--!strict
--[=[
	Validation helpers for replicated cooldown keys.

	@class CooldownManagerKeyUtils
]=]

local require = require(script.Parent.loader).load(script)

local Constants = require("CooldownManagerConstants")

local CooldownManagerKeyUtils = {}

function CooldownManagerKeyUtils.getValidationError(key: any): string?
	if type(key) ~= "string" then
		return "Cooldown key must be a string"
	end

	if key == "" then
		return "Cooldown key cannot be empty"
	end

	if #key > Constants.MaxKeyLength then
		return string.format("Cooldown key cannot exceed %d characters", Constants.MaxKeyLength)
	end

	if string.sub(key, 1, #Constants.ReservedKeyPrefix) == Constants.ReservedKeyPrefix then
		return string.format("Cooldown key cannot start with reserved prefix %q", Constants.ReservedKeyPrefix)
	end

	if string.sub(key, 1, 1) == "." or string.sub(key, #key, #key) == "." then
		return "Cooldown key cannot start or end with a separator"
	end

	if string.find(key, "..", 1, true) ~= nil then
		return "Cooldown key cannot contain empty segments"
	end

	return nil
end

function CooldownManagerKeyUtils.assertValidKey(key: any): string
	local validationError = CooldownManagerKeyUtils.getValidationError(key)
	if validationError then
		error(validationError, 3)
	end

	return key
end

function CooldownManagerKeyUtils.isValidKey(key: any): boolean
	return CooldownManagerKeyUtils.getValidationError(key) == nil
end

return CooldownManagerKeyUtils
