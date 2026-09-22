--!strict
--[=[
	Helpers for ReplicationService state ids and safe path segments.

	@class CooldownManagerReplicationUtils
]=]

local CooldownManagerReplicationUtils = {}

function CooldownManagerReplicationUtils.getPlayerStateId(userId: number): string
	return `Cooldowns:{userId}`
end

function CooldownManagerReplicationUtils.encodeKey(key: string): string
	local encoded = string.gsub(key, "%%", function()
		return "%25"
	end)

	encoded = string.gsub(encoded, "%.", function()
		return "%2E"
	end)

	return encoded
end

function CooldownManagerReplicationUtils.decodeKey(encodedKey: string): string
	local key = string.gsub(encodedKey, "%%2E", function()
		return "."
	end)

	key = string.gsub(key, "%%25", function()
		return "%"
	end)

	return key
end

return CooldownManagerReplicationUtils