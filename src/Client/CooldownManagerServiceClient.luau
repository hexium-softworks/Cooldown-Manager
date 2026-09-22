--!strict
--[=[
	Read-only client cooldown cache.

	@class CooldownManagerServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ClockUtils = require("CooldownManagerClock")
local Constants = require("CooldownManagerConstants")
local KeyUtils = require("CooldownManagerKeyUtils")
local Maid = require("Maid")
local Signal = require("Signal")

local CooldownManagerServiceClient = {}
CooldownManagerServiceClient.ServiceName = "CooldownManagerServiceClient"

local function makeSubscription(cleanup: () -> ())
	local subscription = {}
	local disconnected = false

	function subscription:Disconnect()
		if disconnected then
			return
		end
		disconnected = true
		cleanup()
	end

	subscription.Destroy = subscription.Disconnect

	return subscription
end

local function copySnapshot(snapshot)
	if snapshot == nil then
		return nil
	end

	return {
		Key = snapshot.Key,
		StartTime = snapshot.StartTime,
		EndTime = snapshot.EndTime,
		Duration = snapshot.Duration,
		Revision = snapshot.Revision,
		Metadata = snapshot.Metadata,
	}
end

function CooldownManagerServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._clock = ClockUtils.newDefaultClock()
	self._cooldowns = {}
	self._signalsByKey = {}
	self._allChanged = Signal.new()
end

function CooldownManagerServiceClient:Start() end

function CooldownManagerServiceClient:SetClock(clock)
	assert(type(clock) == "table" and type(clock.Now) == "function", "Clock must expose Now(self)")
	self._clock = clock
end

function CooldownManagerServiceClient:_getSignal(key: string)
	local signal = self._signalsByKey[key]
	if not signal then
		signal = Signal.new()
		self._signalsByKey[key] = signal
	end
	return signal
end

function CooldownManagerServiceClient:_emit(key: string)
	local snapshot = copySnapshot(self._cooldowns[key])
	self:_getSignal(key):Fire(snapshot)
	self._allChanged:Fire(key, snapshot)
end

function CooldownManagerServiceClient:_ApplyCooldown(snapshot)
	KeyUtils.assertValidKey(snapshot and snapshot.Key)
	assert(type(snapshot.StartTime) == "number", "Cooldown snapshot StartTime must be a number")
	assert(type(snapshot.EndTime) == "number", "Cooldown snapshot EndTime must be a number")
	assert(type(snapshot.Duration) == "number", "Cooldown snapshot Duration must be a number")

	self._cooldowns[snapshot.Key] = copySnapshot(snapshot)
	self:_emit(snapshot.Key)
end

function CooldownManagerServiceClient:_RemoveCooldown(key: string)
	KeyUtils.assertValidKey(key)
	self._cooldowns[key] = nil
	self:_emit(key)
end

function CooldownManagerServiceClient:_ClearCooldowns()
	local keys = {}
	for key in self._cooldowns do
		table.insert(keys, key)
	end

	table.clear(self._cooldowns)

	for _, key in keys do
		self:_emit(key)
	end
end

function CooldownManagerServiceClient:GetCooldown(key: string)
	KeyUtils.assertValidKey(key)
	local snapshot = self._cooldowns[key]
	if not snapshot then
		return nil
	end

	if self:GetRemaining(key) <= 0 then
		self._cooldowns[key] = nil
		self:_emit(key)
		return nil
	end

	return copySnapshot(snapshot)
end

function CooldownManagerServiceClient:IsReady(key: string): boolean
	return self:GetRemaining(key) <= 0
end

function CooldownManagerServiceClient:GetRemaining(key: string): number
	KeyUtils.assertValidKey(key)
	local snapshot = self._cooldowns[key]
	if not snapshot then
		return 0
	end

	return ClockUtils.getRemaining(snapshot.EndTime, self._clock:Now())
end

function CooldownManagerServiceClient:GetProgress(key: string): number
	KeyUtils.assertValidKey(key)
	local snapshot = self._cooldowns[key]
	if not snapshot then
		return 1
	end

	return ClockUtils.getProgress(snapshot.StartTime, snapshot.EndTime, self._clock:Now())
end

function CooldownManagerServiceClient:ObserveCooldown(key: string, callback: (any?) -> ())
	KeyUtils.assertValidKey(key)
	assert(type(callback) == "function", "ObserveCooldown requires a callback")

	callback(self:GetCooldown(key))
	local connection = self:_getSignal(key):Connect(function(snapshot)
		callback(copySnapshot(snapshot))
	end)

	return connection
end

function CooldownManagerServiceClient:ObserveReady(key: string, callback: (boolean) -> ())
	KeyUtils.assertValidKey(key)
	assert(type(callback) == "function", "ObserveReady requires a callback")

	local maid = Maid.new()
	local alive = true
	local currentThread: thread? = nil
	local lastValue: boolean? = nil

	local function cancelCurrentThread()
		if currentThread then
			task.cancel(currentThread)
			currentThread = nil
		end
	end

	local function emit()
		if not alive then
			return
		end

		currentThread = nil

		local isReady = self:IsReady(key)
		if lastValue ~= isReady then
			lastValue = isReady
			callback(isReady)
		end

		local snapshot = self:GetCooldown(key)
		if snapshot then
			local delaySeconds = math.max(0, snapshot.EndTime - self._clock:Now())
			currentThread = task.delay(delaySeconds, emit)
		end
	end

	maid:GiveTask(self:_getSignal(key):Connect(function()
		cancelCurrentThread()
		emit()
	end))

	emit()

	return makeSubscription(function()
		alive = false
		cancelCurrentThread()
		maid:DoCleaning()
	end)
end

function CooldownManagerServiceClient:_observeSampled(key: string, rate: number, read: () -> number, callback: (number) -> ())
	local maid = Maid.new()
	local alive = true
	local currentThread: thread? = nil
	local samplePeriod = 1 / math.max(1, rate)

	local function cancelCurrentThread()
		if currentThread then
			task.cancel(currentThread)
			currentThread = nil
		end
	end

	local function emit()
		if not alive then
			return
		end

		currentThread = nil
		callback(read())

		if self:GetCooldown(key) ~= nil then
			currentThread = task.delay(samplePeriod, emit)
		end
	end

	maid:GiveTask(self:_getSignal(key):Connect(function()
		cancelCurrentThread()
		emit()
	end))
	emit()

	return makeSubscription(function()
		alive = false
		cancelCurrentThread()
		maid:DoCleaning()
	end)
end

function CooldownManagerServiceClient:ObserveRemaining(key: string, optionsOrCallback: any?, maybeCallback: ((number) -> ())?)
	KeyUtils.assertValidKey(key)

	local options = {}
	local callback = maybeCallback
	if type(optionsOrCallback) == "function" then
		callback = optionsOrCallback
	else
		options = optionsOrCallback or {}
	end

	assert(type(callback) == "function", "ObserveRemaining requires a callback")

	return self:_observeSampled(key, options.Rate or Constants.DefaultRemainingRate, function()
		return self:GetRemaining(key)
	end, callback :: any)
end

function CooldownManagerServiceClient:ObserveProgress(key: string, optionsOrCallback: any?, maybeCallback: ((number) -> ())?)
	KeyUtils.assertValidKey(key)

	local options = {}
	local callback = maybeCallback
	if type(optionsOrCallback) == "function" then
		callback = optionsOrCallback
	else
		options = optionsOrCallback or {}
	end

	assert(type(callback) == "function", "ObserveProgress requires a callback")

	return self:_observeSampled(key, options.Rate or Constants.DefaultProgressRate, function()
		return self:GetProgress(key)
	end, callback :: any)
end

function CooldownManagerServiceClient:ObserveAll(callback: (string, any?) -> ())
	assert(type(callback) == "function", "ObserveAll requires a callback")

	for key in self._cooldowns do
		callback(key, self:GetCooldown(key))
	end

	return self._allChanged:Connect(function(key, snapshot)
		callback(key, copySnapshot(snapshot))
	end)
end

function CooldownManagerServiceClient:Destroy()
	self._maid:DoCleaning()
	self._allChanged:Destroy()

	for _, signal in self._signalsByKey do
		signal:Destroy()
	end

	table.clear(self._signalsByKey)
	table.clear(self._cooldowns)
end

return CooldownManagerServiceClient
