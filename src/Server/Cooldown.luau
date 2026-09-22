--!strict
--[=[
	Server-side cooldown object.

	@class Cooldown
]=]

local require = require(script.Parent.loader).load(script)

local ClockUtils = require("CooldownManagerClock")
local Signal = require("Signal")

local Cooldown = {}
Cooldown.ClassName = "Cooldown"
Cooldown.__index = Cooldown

export type Cooldown = typeof(setmetatable(
	{} :: {
		_tracker: any,
		_owner: any,
		_key: string,
		_startTime: number,
		_endTime: number,
		_duration: number,
		_revision: number,
		_metadata: { [string]: any }?,
		_shouldReplicate: boolean,
		_completed: boolean,
		_cancelled: boolean,
		_destroyed: boolean,
		_clock: ClockUtils.Clock,
		Completed: Signal.Signal<Cooldown>,
		Cancelled: Signal.Signal<Cooldown>,
	},
	{} :: typeof({ __index = Cooldown })
))

function Cooldown.new(
	tracker: any,
	owner: any,
	key: string,
	startTime: number,
	endTime: number,
	revision: number,
	metadata: { [string]: any }?,
	shouldReplicate: boolean,
	clock: ClockUtils.Clock
): Cooldown
	local self = setmetatable({
		_tracker = tracker,
		_owner = owner,
		_key = key,
		_startTime = startTime,
		_endTime = endTime,
		_duration = math.max(0, endTime - startTime),
		_revision = revision,
		_metadata = metadata,
		_shouldReplicate = shouldReplicate,
		_completed = false,
		_cancelled = false,
		_destroyed = false,
		_clock = clock,
		Completed = Signal.new(),
		Cancelled = Signal.new(),
	}, Cooldown)

	return self :: any
end

function Cooldown:GetKey(): string
	return self._key
end

function Cooldown:GetOwner(): any
	return self._owner
end

function Cooldown:GetStartTime(): number
	return self._startTime
end

function Cooldown:GetEndTime(): number
	return self._endTime
end

function Cooldown:GetDuration(): number
	return self._duration
end

function Cooldown:GetRevision(): number
	return self._revision
end

function Cooldown:GetMetadata(): { [string]: any }?
	return self._metadata
end

function Cooldown:ShouldReplicate(): boolean
	return self._shouldReplicate
end

function Cooldown:GetElapsed(): number
	return ClockUtils.getElapsed(self._startTime, self._clock:Now())
end

function Cooldown:GetRemaining(): number
	return ClockUtils.getRemaining(self._endTime, self._clock:Now())
end

function Cooldown:GetProgress(): number
	return ClockUtils.getProgress(self._startTime, self._endTime, self._clock:Now())
end

function Cooldown:IsActive(): boolean
	return not self._destroyed and not self._completed and not self._cancelled and self:GetRemaining() > 0
end

function Cooldown:IsComplete(): boolean
	return self._completed or (not self._cancelled and self:GetRemaining() <= 0)
end

function Cooldown:ToSnapshot()
	return {
		Key = self._key,
		StartTime = self._startTime,
		EndTime = self._endTime,
		Duration = self._duration,
		Revision = self._revision,
		Metadata = self._metadata,
	}
end

function Cooldown:_update(startTime: number, endTime: number, revision: number, metadata: { [string]: any }?, shouldReplicate: boolean)
	self._startTime = startTime
	self._endTime = endTime
	self._duration = math.max(0, endTime - startTime)
	self._revision = revision
	self._metadata = metadata
	self._shouldReplicate = shouldReplicate
	self._completed = false
	self._cancelled = false
	self._destroyed = false
end

function Cooldown:_complete(revision: number): boolean
	if self._destroyed or self._cancelled or self._completed or self._revision ~= revision then
		return false
	end

	self._completed = true
	self.Completed:Fire(self)
	return true
end

function Cooldown:_cancel(): boolean
	if self._destroyed or self._cancelled or self._completed then
		return false
	end

	self._cancelled = true
	self.Cancelled:Fire(self)
	return true
end

function Cooldown:Cancel(): boolean
	return self._tracker:Cancel(self._key)
end

function Cooldown:Extend(duration: number): boolean
	return self._tracker:Extend(self._key, duration)
end

function Cooldown:Reduce(duration: number): boolean
	return self._tracker:Reduce(self._key, duration)
end

function Cooldown:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self.Completed:Destroy()
	self.Cancelled:Destroy()
end

return Cooldown
