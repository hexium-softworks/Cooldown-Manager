--!strict
--[=[
	Owns all cooldowns for a single owner.

	@class CooldownTracker
]=]

local require = require(script.Parent.loader).load(script)

local ClockUtils = require("CooldownManagerClock")
local Constants = require("CooldownManagerConstants")
local Cooldown = require("Cooldown")
local KeyUtils = require("CooldownManagerKeyUtils")
local Maid = require("Maid")
local Signal = require("Signal")

type Cooldown = Cooldown.Cooldown
type Clock = ClockUtils.Clock

export type Scheduler = {
	Delay: (self: Scheduler, delaySeconds: number, callback: () -> ()) -> thread?,
	Cancel: ((self: Scheduler, handle: thread?) -> ())?,
}

local TaskScheduler = {}
TaskScheduler.__index = TaskScheduler

function TaskScheduler.new(): Scheduler
	return setmetatable({}, TaskScheduler) :: any
end

function TaskScheduler:Delay(delaySeconds: number, callback: () -> ()): thread?
	if delaySeconds <= 0 then
		task.defer(callback)
		return nil
	end

	return task.delay(delaySeconds, callback)
end

function TaskScheduler:Cancel(handle: thread?)
	if handle ~= nil then
		task.cancel(handle)
	end
end

local CooldownTracker = {}
CooldownTracker.ClassName = "CooldownTracker"
CooldownTracker.__index = CooldownTracker

export type CooldownTracker = typeof(setmetatable(
	{} :: {
		_owner: any,
		_service: any?,
		_clock: Clock,
		_scheduler: Scheduler,
		_maid: Maid.Maid,
		_cooldowns: { [string]: Cooldown },
		_tasks: { [string]: thread? },
		_revision: number,
		_destroyed: boolean,
		Changed: Signal.Signal<string, Cooldown?>,
	},
	{} :: typeof({ __index = CooldownTracker })
))

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function assertValidDuration(duration: any, allowZero: boolean): number
	if not isFiniteNumber(duration) then
		error("Cooldown duration must be a finite number", 3)
	end

	if duration < 0 then
		error("Cooldown duration cannot be negative", 3)
	end

	if duration == 0 and not allowZero then
		error("Cooldown duration must be greater than zero", 3)
	end

	return duration
end

function CooldownTracker.new(owner: any, service: any?, clock: Clock?, scheduler: Scheduler?): CooldownTracker
	local self = setmetatable({
		_owner = owner,
		_service = service,
		_clock = clock or ClockUtils.newDefaultClock(),
		_scheduler = scheduler or TaskScheduler.new(),
		_maid = Maid.new(),
		_cooldowns = {},
		_tasks = {},
		_revision = 0,
		_destroyed = false,
		Changed = Signal.new(),
	}, CooldownTracker)

	return self :: any
end

function CooldownTracker:GetOwner(): any
	return self._owner
end

function CooldownTracker:IsDestroyed(): boolean
	return self._destroyed
end

function CooldownTracker:_assertAlive()
	if self._destroyed then
		error("Cannot mutate a destroyed CooldownTracker", 3)
	end
end

function CooldownTracker:_nextRevision(): number
	self._revision += 1
	return self._revision
end

function CooldownTracker:_cancelScheduled(key: string)
	local handle = self._tasks[key]
	if handle ~= nil and self._scheduler.Cancel then
		self._scheduler:Cancel(handle)
	end
	self._tasks[key] = nil
end

function CooldownTracker:_schedule(cooldown: Cooldown)
	local key = cooldown:GetKey()
	self:_cancelScheduled(key)

	local revision = cooldown:GetRevision()
	local delaySeconds = cooldown:GetRemaining()

	self._tasks[key] = self._scheduler:Delay(delaySeconds, function()
		self:_completeCooldown(key, revision)
	end)
end

function CooldownTracker:_notifyStarted(key: string, cooldown: Cooldown, isUpdate: boolean)
	self.Changed:Fire(key, cooldown)

	if self._service and cooldown:ShouldReplicate() then
		self._service:_replicateCooldown(self._owner, key, cooldown, isUpdate)
	end
end

function CooldownTracker:_notifyRemoved(key: string, cooldown: Cooldown)
	self.Changed:Fire(key, nil)

	if self._service and cooldown:ShouldReplicate() then
		self._service:_removeReplicatedCooldown(self._owner, key)
	end
end

function CooldownTracker:_completeCooldown(key: string, revision: number): boolean
	local cooldown = self._cooldowns[key]
	if not cooldown or cooldown:GetRevision() ~= revision then
		return false
	end

	self._tasks[key] = nil
	self._cooldowns[key] = nil

	local completed = cooldown:_complete(revision)
	self:_notifyRemoved(key, cooldown)
	cooldown:Destroy()

	return completed
end

function CooldownTracker:_startInternal(key: string, duration: number, options: any?, policy: string): (boolean, Cooldown)
	self:_assertAlive()
	KeyUtils.assertValidKey(key)
	assertValidDuration(duration, true)
	if
		policy ~= Constants.CooldownPolicy.Reject
		and policy ~= Constants.CooldownPolicy.Restart
		and policy ~= Constants.CooldownPolicy.KeepLonger
		and policy ~= Constants.CooldownPolicy.Extend
	then
		error("Invalid cooldown policy", 3)
	end

	options = options or {}

	local now = self._clock:Now()
	local existing = self._cooldowns[key]

	if existing and existing:GetRemaining() <= 0 then
		self:_completeCooldown(key, existing:GetRevision())
		existing = nil
	end

	if existing then
		if policy == Constants.CooldownPolicy.Reject then
			return false, existing
		elseif policy == Constants.CooldownPolicy.KeepLonger then
			if existing:GetRemaining() >= duration then
				return true, existing
			end
		elseif policy == Constants.CooldownPolicy.Extend then
			return true, self:_extendInternal(key, duration)
		end
	end

	local revision = self:_nextRevision()
	local endTime = now + duration
	local metadata = options.Metadata
	local cooldown = existing
	local isUpdate = existing ~= nil
	local wasReplicated = cooldown ~= nil and cooldown:ShouldReplicate()
	local shouldReplicate = if options.Replicate ~= nil then options.Replicate == true else wasReplicated

	if cooldown then
		cooldown:_update(now, endTime, revision, metadata, shouldReplicate)
	else
		cooldown = Cooldown.new(self, self._owner, key, now, endTime, revision, metadata, shouldReplicate, self._clock)
		self._cooldowns[key] = cooldown
	end

	self:_notifyStarted(key, cooldown, isUpdate)
	if wasReplicated and not shouldReplicate and self._service then
		self._service:_removeReplicatedCooldown(self._owner, key)
	end

	if duration <= 0 then
		self:_completeCooldown(key, revision)
	else
		self:_schedule(cooldown)
	end

	return true, cooldown
end

function CooldownTracker:_extendInternal(key: string, duration: number): Cooldown
	assertValidDuration(duration, false)

	local existing = self._cooldowns[key]
	if not existing or existing:GetRemaining() <= 0 then
		error("Cannot extend an absent or completed cooldown", 3)
	end

	local revision = self:_nextRevision()
	local startTime = existing:GetStartTime()
	local endTime = existing:GetEndTime() + duration
	existing:_update(startTime, endTime, revision, existing:GetMetadata(), existing:ShouldReplicate())
	self:_notifyStarted(key, existing, true)
	self:_schedule(existing)

	return existing
end

function CooldownTracker:IsReady(key: string): boolean
	KeyUtils.assertValidKey(key)
	local cooldown = self._cooldowns[key]
	return cooldown == nil or cooldown:GetRemaining() <= 0
end

function CooldownTracker:GetRemaining(key: string): number
	KeyUtils.assertValidKey(key)
	local cooldown = self._cooldowns[key]
	if not cooldown then
		return 0
	end

	return cooldown:GetRemaining()
end

function CooldownTracker:GetCooldown(key: string): Cooldown?
	KeyUtils.assertValidKey(key)
	local cooldown = self._cooldowns[key]
	if cooldown and cooldown:GetRemaining() <= 0 then
		self:_completeCooldown(key, cooldown:GetRevision())
		return nil
	end

	return cooldown
end

function CooldownTracker:TryStart(key: string, duration: number, options: any?): (boolean, Cooldown)
	local policy = (options and options.Policy) or Constants.CooldownPolicy.Reject
	return self:_startInternal(key, duration, options, policy)
end

function CooldownTracker:Start(key: string, duration: number, options: any?): Cooldown
	local success, cooldown = self:TryStart(key, duration, options)
	if not success then
		error(string.format("Cooldown %q is already active", key), 2)
	end
	return cooldown
end

function CooldownTracker:Cancel(key: string): boolean
	self:_assertAlive()
	KeyUtils.assertValidKey(key)
	local cooldown = self._cooldowns[key]
	if not cooldown then
		return false
	end

	self:_cancelScheduled(key)
	self._cooldowns[key] = nil

	local cancelled = cooldown:_cancel()
	self:_notifyRemoved(key, cooldown)
	cooldown:Destroy()

	return cancelled
end

function CooldownTracker:Extend(key: string, duration: number): boolean
	self:_assertAlive()
	KeyUtils.assertValidKey(key)

	local cooldown = self._cooldowns[key]
	if not cooldown or cooldown:GetRemaining() <= 0 then
		return false
	end

	self:_extendInternal(key, duration)
	return true
end

function CooldownTracker:Reduce(key: string, duration: number): boolean
	self:_assertAlive()
	KeyUtils.assertValidKey(key)
	assertValidDuration(duration, false)

	local cooldown = self._cooldowns[key]
	if not cooldown or cooldown:GetRemaining() <= 0 then
		return false
	end

	local revision = self:_nextRevision()
	local startTime = cooldown:GetStartTime()
	local endTime = math.max(self._clock:Now(), cooldown:GetEndTime() - duration)
	cooldown:_update(startTime, endTime, revision, cooldown:GetMetadata(), cooldown:ShouldReplicate())
	self:_notifyStarted(key, cooldown, true)

	if cooldown:GetRemaining() <= 0 then
		self:_completeCooldown(key, revision)
	else
		self:_schedule(cooldown)
	end

	return true
end

function CooldownTracker:Clear()
	if self._destroyed then
		return
	end

	local keys = {}
	local hadReplicatedCooldown = false
	for key in self._cooldowns do
		local cooldown = self._cooldowns[key]
		if cooldown and cooldown:ShouldReplicate() then
			hadReplicatedCooldown = true
		end
		table.insert(keys, key)
	end

	for _, key in keys do
		self:Cancel(key)
	end

	if self._service and hadReplicatedCooldown then
		self._service:_trackerCleared(self._owner)
	end
end

function CooldownTracker:TryAcquire(request: any)
	self:_assertAlive()
	assert(type(request) == "table", "TryAcquire request must be a table")
	assert(type(request.Start) == "table", "TryAcquire request.Start must be a table")

	local requiredKeys = {}
	local seen = {}

	if request.Require then
		assert(type(request.Require) == "table", "TryAcquire request.Require must be a table")
		for _, key in request.Require do
			KeyUtils.assertValidKey(key)
			if not seen[key] then
				seen[key] = true
				table.insert(requiredKeys, key)
			end
		end
	end

	for key, duration in request.Start do
		KeyUtils.assertValidKey(key)
		assertValidDuration(duration, true)
		if not seen[key] then
			seen[key] = true
			table.insert(requiredKeys, key)
		end
	end

	for _, key in requiredKeys do
		if not self:IsReady(key) then
			return {
				Success = false,
				BlockedBy = key,
				Remaining = self:GetRemaining(key),
			}
		end
	end

	local started = {}
	for key, duration in request.Start do
		local options = request.Options and request.Options[key] or nil
		local success, cooldown = self:TryStart(key, duration, options)
		assert(success, "TryAcquire failed after readiness check")
		started[key] = cooldown
	end

	return {
		Success = true,
		Started = started,
	}
end

function CooldownTracker:Destroy()
	if self._destroyed then
		return
	end

	self:Clear()
	self._destroyed = true
	self.Changed:Destroy()
	self._maid:DoCleaning()
end

return CooldownTracker
