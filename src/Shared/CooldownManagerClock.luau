--!strict
--[=[
	Clock helpers for cooldown timestamp calculations.

	@class CooldownManagerClock
]=]

local CooldownManagerClock = {}

export type Clock = {
	Now: (self: Clock) -> number,
}

local DefaultClock = {}
DefaultClock.__index = DefaultClock

function DefaultClock.new(): Clock
	return setmetatable({}, DefaultClock) :: any
end

function DefaultClock:Now(): number
	local ok, value = pcall(function()
		return workspace:GetServerTimeNow()
	end)

	if ok and type(value) == "number" then
		return value
	end

	return os.clock()
end

function CooldownManagerClock.newDefaultClock(): Clock
	return DefaultClock.new()
end

function CooldownManagerClock.getRemaining(endTime: number, now: number): number
	return math.max(0, endTime - now)
end

function CooldownManagerClock.getElapsed(startTime: number, now: number): number
	return math.max(0, now - startTime)
end

function CooldownManagerClock.getProgress(startTime: number, endTime: number, now: number): number
	local duration = endTime - startTime
	if duration <= 0 then
		return 1
	end

	return math.clamp((now - startTime) / duration, 0, 1)
end

return CooldownManagerClock
