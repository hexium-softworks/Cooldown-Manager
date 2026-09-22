--!strict
--[=[
	Server-authoritative cooldown registry.

	@class CooldownManagerService
]=]

local Players = game:GetService("Players")

local require = require(script.Parent.loader).load(script)

local ClockUtils = require("CooldownManagerClock")
local CooldownTracker = require("CooldownTracker")
local Log = require("Log")
local Maid = require("Maid")
local ReplicationService = require("ReplicationService")
local ReplicationUtils = require("CooldownManagerReplicationUtils")

local CooldownManagerService = {}
CooldownManagerService.ServiceName = "CooldownManagerService"

local ServiceLog = Log.new({
	name = "CooldownManagerService",
	defaultContext = {
		Package = "CooldownManager",
		Service = "CooldownManagerService",
	},
})

local function isInstance(value: any): boolean
	return typeof(value) == "Instance"
end

local function isPlayer(value: any): boolean
	return isInstance(value) and value:IsA("Player")
end

function CooldownManagerService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._clock = ClockUtils.newDefaultClock()
	self._replicationService = self._serviceBag:GetService(ReplicationService)
	self._weakTrackers = setmetatable({}, { __mode = "k" })
	self._stringTrackers = {}
	self._trackerMaids = setmetatable({}, { __mode = "k" })
	self._replicatedStates = setmetatable({}, { __mode = "k" })
	self._warnedUnsupportedReplicationOwners = setmetatable({}, { __mode = "k" })

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:DestroyTracker(player)
	end))
end

function CooldownManagerService:Start() end

function CooldownManagerService:SetClock(clock)
	assert(type(clock) == "table" and type(clock.Now) == "function", "Clock must expose Now(self)")
	self._clock = clock
end

function CooldownManagerService:_getTrackerMap(owner: any)
	if type(owner) == "string" then
		return self._stringTrackers
	end

	return self._weakTrackers
end

function CooldownManagerService:_validateOwner(owner: any)
	if owner == nil then
		error("Cooldown owner cannot be nil", 3)
	end

	if isInstance(owner) and owner.Parent == nil and not owner:IsA("Player") then
		error("Cooldown owner Instance must not be destroyed", 3)
	end
end

function CooldownManagerService:_bindOwnerCleanup(owner: any)
	if type(owner) == "string" then
		return
	end

	local maid = Maid.new()
	self._trackerMaids[owner] = maid

	if isInstance(owner) then
		maid:GiveTask(owner.Destroying:Connect(function()
			self:DestroyTracker(owner)
		end))
	end
end

function CooldownManagerService:GetTracker(owner: any)
	self:_validateOwner(owner)

	local map = self:_getTrackerMap(owner)
	local tracker = map[owner]
	if tracker and not tracker:IsDestroyed() then
		return tracker
	end

	tracker = CooldownTracker.new(owner, self, self._clock)
	map[owner] = tracker
	self:_bindOwnerCleanup(owner)

	return tracker
end

function CooldownManagerService:FindTracker(owner: any)
	if owner == nil then
		return nil
	end

	local map = self:_getTrackerMap(owner)
	local tracker = map[owner]
	if tracker and not tracker:IsDestroyed() then
		return tracker
	end

	return nil
end

function CooldownManagerService:_destroyReplicatedState(owner: any)
	local state = self._replicatedStates[owner]
	if not state then
		return
	end

	self._replicatedStates[owner] = nil
	state:Destroy()
end

function CooldownManagerService:DestroyTracker(owner: any): boolean
	local tracker = self:FindTracker(owner)
	if not tracker then
		return false
	end

	local map = self:_getTrackerMap(owner)
	map[owner] = nil

	local trackerMaid = self._trackerMaids[owner]
	if trackerMaid then
		self._trackerMaids[owner] = nil
		trackerMaid:DoCleaning()
	end

	tracker:Destroy()
	self:_destroyReplicatedState(owner)
	return true
end

function CooldownManagerService:Clear(owner: any)
	local tracker = self:FindTracker(owner)
	if tracker then
		tracker:Clear()
	end
end

function CooldownManagerService:IsReady(owner: any, key: string): boolean
	return self:GetTracker(owner):IsReady(key)
end

function CooldownManagerService:GetRemaining(owner: any, key: string): number
	return self:GetTracker(owner):GetRemaining(key)
end

function CooldownManagerService:GetCooldown(owner: any, key: string)
	local tracker = self:FindTracker(owner)
	if not tracker then
		return nil
	end

	return tracker:GetCooldown(key)
end

function CooldownManagerService:TryStart(owner: any, key: string, duration: number, options: any?)
	return self:GetTracker(owner):TryStart(key, duration, options)
end

function CooldownManagerService:Start(owner: any, key: string, duration: number, options: any?)
	return self:GetTracker(owner):Start(key, duration, options)
end

function CooldownManagerService:Cancel(owner: any, key: string): boolean
	local tracker = self:FindTracker(owner)
	if not tracker then
		return false
	end

	return tracker:Cancel(key)
end

function CooldownManagerService:Extend(owner: any, key: string, duration: number): boolean
	local tracker = self:FindTracker(owner)
	if not tracker then
		return false
	end

	return tracker:Extend(key, duration)
end

function CooldownManagerService:Reduce(owner: any, key: string, duration: number): boolean
	local tracker = self:FindTracker(owner)
	if not tracker then
		return false
	end

	return tracker:Reduce(key, duration)
end

function CooldownManagerService:TryAcquire(owner: any, request: any)
	return self:GetTracker(owner):TryAcquire(request)
end

function CooldownManagerService:_getReplicatedState(owner: any)
	if not isPlayer(owner) then
		if not self._warnedUnsupportedReplicationOwners[owner] then
			self._warnedUnsupportedReplicationOwners[owner] = true
			ServiceLog.Warn("Cooldown replication is only supported for Player owners", {
				OwnerType = typeof(owner),
			})
		end
		return nil
	end

	local state = self._replicatedStates[owner]
	if state and not state:IsDestroyed() then
		return state
	end

	state = self._replicationService:CreateState({
		Id = ReplicationUtils.getPlayerStateId(owner.UserId),
		InitialState = {
			Cooldowns = {},
		},
		Audience = owner,
	})

	self._replicatedStates[owner] = state
	return state
end

function CooldownManagerService:_replicateCooldown(owner: any, key: string, cooldown, _isUpdate: boolean)
	local state = self:_getReplicatedState(owner)
	if not state then
		return
	end

	local success, err = pcall(function()
		state:Set({ "Cooldowns", ReplicationUtils.encodeKey(key) }, cooldown:ToSnapshot())
	end)

	if not success then
		ServiceLog.Warn("Failed to replicate cooldown", {
			Key = key,
			Error = tostring(err),
		})
	end
end

function CooldownManagerService:_removeReplicatedCooldown(owner: any, key: string)
	local state = self._replicatedStates[owner]
	if not state or state:IsDestroyed() then
		return
	end

	local success, err = pcall(function()
		state:Delete({ "Cooldowns", ReplicationUtils.encodeKey(key) })
	end)

	if not success then
		ServiceLog.Warn("Failed to remove replicated cooldown", {
			Key = key,
			Error = tostring(err),
		})
	end
end

function CooldownManagerService:_trackerCleared(owner: any)
	local state = self._replicatedStates[owner]
	if not state or state:IsDestroyed() then
		return
	end

	local success, err = pcall(function()
		state:Set("Cooldowns", {})
	end)

	if not success then
		ServiceLog.Warn("Failed to clear replicated cooldowns", {
			Error = tostring(err),
		})
	end
end

function CooldownManagerService:Destroy()
	local stringOwners = {}
	for owner in self._stringTrackers do
		table.insert(stringOwners, owner)
	end

	for _, owner in stringOwners do
		self:DestroyTracker(owner)
	end

	local weakOwners = {}
	for owner in self._weakTrackers do
		table.insert(weakOwners, owner)
	end

	for _, owner in weakOwners do
		self:DestroyTracker(owner)
	end

	self._maid:DoCleaning()
end

return CooldownManagerService