--!strict
--[=[
	@class InputServiceConfigUtils.spec
]=]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local InputServiceConfigUtils = require("InputServiceConfigUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function getBoolInputActionType(): any
	local ok, value = pcall(function()
		return Enum.InputActionType.Bool
	end)

	if ok then
		return value
	end

	return nil
end

describe("InputServiceConfigUtils", function()
	it("accepts a valid context config", function()
		expect(function()
			InputServiceConfigUtils.validateContextConfig({
				Name = "PlayContext",
				Enabled = true,
				Priority = 2000,
				Sink = true,
				Actions = {
					{
						Name = "Sprint",
						Bindings = {
							{
								Name = "Keyboard",
								KeyCode = Enum.KeyCode.LeftShift,
							},
						},
					},
				},
			})
		end).never.toThrow()
	end)

	if getBoolInputActionType() ~= nil then
		it("accepts InputActionType enum values", function()
			expect(function()
				InputServiceConfigUtils.validateActionConfig({
					Name = "Sprint",
					Type = getBoolInputActionType(),
				})
			end).never.toThrow()
		end)
	end

	it("rejects unknown fields", function()
		expect(function()
			InputServiceConfigUtils.validateContextConfig({
				Name = "PlayContext",
				RemoteEventName = "Nope",
			})
		end).toThrow()
	end)

	it("rejects unsafe names", function()
		expect(function()
			InputServiceConfigUtils.validateActionConfig({
				Name = "Bad/Action",
			})
		end).toThrow()
	end)

	it("rejects mismatched enum types", function()
		expect(function()
			InputServiceConfigUtils.validateActionConfig({
				Name = "Sprint",
				Type = Enum.KeyCode.E,
			})
		end).toThrow()
	end)
end)
