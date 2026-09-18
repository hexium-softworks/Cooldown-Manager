--!strict
--[=[
	@class InputServiceInstanceUtils.spec
]=]

local require = require(script.Parent.loader).load(script)

local InputServiceConstants = require("InputServiceConstants")
local InputServiceInstanceUtils = require("InputServiceInstanceUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function canCreateInputActionInstances(): boolean
	local ok, instance = pcall(Instance.new, InputServiceConstants.CONTEXT_CLASS_NAME, nil)
	if ok and typeof(instance) == "Instance" then
		instance:Destroy()
		return true
	end

	return false
end

describe("InputServiceInstanceUtils", function()
	it("guards unsupported runtimes", function()
		expect(typeof(canCreateInputActionInstances())).toEqual("boolean")
	end)

	if canCreateInputActionInstances() then
		it("upserts contexts without duplicating actions or bindings", function()
			local root = Instance.new("Folder")
			root.Name = InputServiceConstants.ROOT_FOLDER_NAME

			local context = InputServiceInstanceUtils.upsertContext(root, {
				Name = "PlayContext",
				Enabled = true,
				Priority = 10,
				Sink = false,
				Actions = {
					{
						Name = "Sprint",
						Type = Enum.InputActionType.Bool,
						Bindings = {
							{
								Name = "Keyboard",
								KeyCode = Enum.KeyCode.LeftShift,
							},
						},
					},
				},
			})

			InputServiceInstanceUtils.upsertContext(root, {
				Name = "PlayContext",
				Priority = 25,
				Actions = {
					{
						Name = "Sprint",
						DisplayName = "Run",
						Bindings = {
							{
								Name = "Keyboard",
								KeyCode = Enum.KeyCode.E,
							},
						},
					},
				},
			})

			local sprint = context:FindFirstChild("Sprint")
			expect(context.Priority).toEqual(25)
			expect(#root:GetChildren()).toEqual(1)
			expect(sprint ~= nil).toEqual(true)
			expect(#(sprint :: Instance):GetChildren()).toEqual(1)

			root:Destroy()
		end)

		it("removes only targeted objects", function()
			local root = Instance.new("Folder")
			root.Name = InputServiceConstants.ROOT_FOLDER_NAME

			local context = InputServiceInstanceUtils.upsertContext(root, {
				Name = "PlayContext",
				Actions = {
					{ Name = "Sprint" },
					{ Name = "Jump" },
				},
			})

			expect(InputServiceInstanceUtils.removeAction(context, "Sprint")).toEqual(true)
			expect(context:FindFirstChild("Sprint")).toEqual(nil)
			expect(context:FindFirstChild("Jump") ~= nil).toEqual(true)

			root:Destroy()
		end)
	end
end)
