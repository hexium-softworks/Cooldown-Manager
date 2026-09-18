# InputService

A game-agnostic Nevermore package for Roblox's Input Action System.

InputService creates and edits real `InputContext`, `InputAction`, and
`InputBinding` instances in `ReplicatedStorage.Inputs`. The server owns shared
defaults, clients listen to actions and make local presentation changes, and no
client input is treated as server authority by this package.

## Installation

```sh
pnpm add @hexium-softworks/inputservice
```

This package expects a Roblox runtime that can create `InputContext`,
`InputAction`, and `InputBinding` instances.

## Model

InputService mirrors Roblox's Input Action System hierarchy:

```txt
ReplicatedStorage
  Inputs
    PlayContext
      Sprint
        Keyboard
        Gamepad
      Jump
        Keyboard
    MenuContext
      Confirm
      Back
```

- `InputContext` groups actions and controls priority, sinking, and enablement.
- `InputAction` represents something the player can do, such as sprint, jump,
  confirm, or open inventory.
- `InputBinding` describes how an action is triggered, such as a key, UI button,
  directional set, pointer index, or scriptable binding.

Server code should create shared gameplay defaults. Client code should connect to
signals, enable or disable local presentation contexts, add local-only bindings,
and fire scriptable bindings for UI or custom local input.

## Server Usage

Register one context:

```lua
local InputService = require("InputService")

local inputService = serviceBag:GetService(InputService)

inputService:RegisterContext({
	Name = "PlayContext",
	Enabled = true,
	Priority = 2000,
	Sink = true,
	Actions = {
		{
			Name = "Sprint",
			DisplayName = "Sprint",
			Type = Enum.InputActionType.Bool,
			Bindings = {
				{
					Name = "Keyboard",
					KeyCode = Enum.KeyCode.LeftShift,
					DisplayName = "Left Shift",
				},
				{
					Name = "Gamepad",
					KeyCode = Enum.KeyCode.ButtonL3,
					DisplayName = "L3",
				},
			},
		},
	},
})
```

Register multiple contexts at startup:

```lua
inputService:RegisterContexts({
	{
		Name = "Gameplay",
		Enabled = true,
		Priority = 2000,
		Sink = false,
		Actions = {
			{
				Name = "Sprint",
				DisplayName = "Sprint",
				Type = Enum.InputActionType.Bool,
				Bindings = {
					{
						Name = "Keyboard",
						KeyCode = Enum.KeyCode.LeftShift,
					},
					{
						Name = "Gamepad",
						KeyCode = Enum.KeyCode.ButtonL3,
					},
				},
			},
			{
				Name = "Jump",
				DisplayName = "Jump",
				Type = Enum.InputActionType.Bool,
				Bindings = {
					{
						Name = "Keyboard",
						KeyCode = Enum.KeyCode.Space,
					},
					{
						Name = "Gamepad",
						KeyCode = Enum.KeyCode.ButtonA,
					},
				},
			},
			{
				Name = "Move",
				DisplayName = "Move",
				Type = Enum.InputActionType.Direction2D,
				Bindings = {
					{
						Name = "Wasd",
						Up = Enum.KeyCode.W,
						Down = Enum.KeyCode.S,
						Left = Enum.KeyCode.A,
						Right = Enum.KeyCode.D,
						Vector2Scale = Vector2.new(1, 1),
						ClampMagnitudeToOne = true,
					},
				},
			},
		},
	},
	{
		Name = "Menu",
		Enabled = false,
		Priority = 3000,
		Sink = true,
		Actions = {
			{
				Name = "Confirm",
				DisplayName = "Confirm",
				Type = Enum.InputActionType.Bool,
				Bindings = {
					{
						Name = "Keyboard",
						KeyCode = Enum.KeyCode.Return,
					},
					{
						Name = "Gamepad",
						KeyCode = Enum.KeyCode.ButtonA,
					},
				},
			},
			{
				Name = "Back",
				DisplayName = "Back",
				Type = Enum.InputActionType.Bool,
				Bindings = {
					{
						Name = "Keyboard",
						KeyCode = Enum.KeyCode.Escape,
					},
					{
						Name = "Gamepad",
						KeyCode = Enum.KeyCode.ButtonB,
					},
				},
			},
		},
	},
	{
		Name = "Vehicle",
		Enabled = false,
		Priority = 2500,
		Sink = true,
		Actions = {
			{
				Name = "Throttle",
				DisplayName = "Throttle",
				Type = Enum.InputActionType.Direction1D,
				Bindings = {
					{
						Name = "Keyboard",
						Up = Enum.KeyCode.W,
						Down = Enum.KeyCode.S,
						Scale = 1,
					},
				},
			},
		},
	},
})
```

Update inputs later without rebuilding the whole tree:

```lua
inputService:ConfigureAction("Gameplay", {
	Name = "Interact",
	DisplayName = "Interact",
	Type = Enum.InputActionType.Bool,
	Bindings = {
		{
			Name = "Keyboard",
			KeyCode = Enum.KeyCode.E,
		},
	},
})

inputService:ConfigureBinding("Gameplay", "Jump", {
	Name = "Keyboard",
	KeyCode = Enum.KeyCode.Space,
	DisplayName = "Space",
})
```

Switch active modes by toggling contexts:

```lua
local function setMenuOpen(isOpen)
	inputService:SetContextEnabled("Gameplay", not isOpen)
	inputService:SetContextEnabled("Menu", isOpen)
end

local function setInVehicle(isInVehicle)
	inputService:SetContextEnabled("Vehicle", isInVehicle)
end
```

Remove objects when a feature is unloaded:

```lua
inputService:RemoveBinding("Gameplay", "Jump", "Keyboard")
inputService:RemoveAction("Gameplay", "Interact")
inputService:RemoveContext("Vehicle")
```

## Client Usage

Read shared contexts and bind to action signals:

```lua
local InputServiceClient = require("InputServiceClient")

local inputServiceClient = serviceBag:GetService(InputServiceClient)

inputServiceClient:WaitForContext("Gameplay", 10)

local sprintPressed = inputServiceClient:BindPressed("Gameplay", "Sprint", function()
	print("Sprint pressed")
end)

local sprintReleased = inputServiceClient:BindReleased("Gameplay", "Sprint", function()
	print("Sprint released")
end)

local moveChanged = inputServiceClient:BindStateChanged("Gameplay", "Move", function(value)
	print("Move changed", value)
end)
```

`BindPressed`, `BindReleased`, and `BindStateChanged` return connections. Store
and disconnect them with your maid/janitor/cleanup pattern:

```lua
maid:GiveTask(sprintPressed)
maid:GiveTask(sprintReleased)
maid:GiveTask(moveChanged)
```

You can also access the full signal bundle:

```lua
local signals = inputServiceClient:GetActionSignals("Gameplay", "Jump")

maid:GiveTask(signals.EnabledChanged:Connect(function(enabled)
	print("Jump enabled:", enabled)
end))

maid:GiveTask(signals.PreferredBindingChanged:Connect(function(binding)
	print("Preferred jump binding:", binding)
end))
```

Toggle local action state:

```lua
inputServiceClient:SetActionEnabled("Gameplay", "Sprint", false)
inputServiceClient:SetContextEnabled("Menu", true)
```

## Local Contexts And UI Bindings

Clients can define local-only contexts. These are useful for UI, tutorials,
debug tools, accessibility overlays, and rebinding screens. They do not send any
claims or config changes to the server through this package.

```lua
local closeButton = playerGui.Inventory.CloseButton

inputServiceClient:DefineLocalContext({
	Name = "InventoryUi",
	Enabled = false,
	Priority = 4000,
	Sink = true,
	Actions = {
		{
			Name = "Close",
			DisplayName = "Close",
			Type = Enum.InputActionType.Bool,
			Bindings = {
				{
					Name = "Keyboard",
					KeyCode = Enum.KeyCode.Escape,
				},
				{
					Name = "Button",
					UIButton = closeButton,
					DisplayName = "Close",
				},
			},
		},
	},
})

inputServiceClient:BindPressed("InventoryUi", "Close", function()
	inputServiceClient:SetContextEnabled("InventoryUi", false)
end)
```

Configure a local binding at runtime:

```lua
inputServiceClient:ConfigureBinding("InventoryUi", "Close", {
	Name = "Gamepad",
	KeyCode = Enum.KeyCode.ButtonB,
	DisplayName = "Back",
})
```

Fire a binding from custom client code when the underlying `InputBinding` type in
your Roblox runtime supports `:Fire()`:

```lua
inputServiceClient:ConfigureAction("InventoryUi", {
	Name = "Close",
	Type = Enum.InputActionType.Bool,
	Bindings = {
		{
			Name = "Script",
			Type = Enum.InputBindingType.Scriptable,
		},
	},
})

inputServiceClient:FireBinding("InventoryUi", "Close", "Script", true)
inputServiceClient:FireBinding("InventoryUi", "Close", "Script", false)
```

## Blend And Nevermore UI Patterns

InputService does not depend on Blend, Rx, Binder, or BaseObject, but it fits
well with those Nevermore patterns:

- Use a service to define the shared input tree and expose game-specific state.
- Use `BaseObject` or a pane/controller object to own UI and input connections.
- Use `Maid` for every connection, mounted Blend tree, and temporary tool input.
- Use `Blend.State` for the current list of visible input hints.
- Use `PreferredBindingChanged` to update labels when the player's device changes.
- Use a short-lived maid for tool-specific actions so unequipping the tool removes
  its input context and hint rows at the same time.

The pattern is to keep actions in the input tree, then render a separate list of
human-readable rows. General actions, such as `F` to interact, stay in the list
all the time. Tool actions are pushed while the tool is equipped and cleaned up
when it is unequipped.

```lua
local Blend = require("Blend")
local Maid = require("Maid")

local InputHintPane = {}
InputHintPane.ClassName = "InputHintPane"
InputHintPane.__index = InputHintPane

function InputHintPane.new(inputServiceClient, playerGui)
	local self = setmetatable({}, InputHintPane)

	self._maid = Maid.new()
	self._inputServiceClient = inputServiceClient
	self._rows = Blend.State({})

	self._maid:GiveTask(self:_render(playerGui):Subscribe())
	self:_setAlwaysAvailableRows()

	return self
end

function InputHintPane:_render(playerGui)
	return Blend.New "ScreenGui" {
		Name = "InputHints",
		Parent = playerGui,
		ResetOnSpawn = false,

		Blend.New "Frame" {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.98, 0.96),
			Size = UDim2.fromOffset(280, 160),
			BackgroundTransparency = 1,

			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},

			Blend.ComputedPairs(self._rows, function(_, row)
				return Blend.New "TextLabel" {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 0.25,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = string.format("[%s] %s", row.BindingText, row.DisplayName),
					LayoutOrder = row.LayoutOrder,
				}
			end),
		},
	}
end

function InputHintPane:_setRows(rows)
	self._rows.Value = rows
end

function InputHintPane:_setAlwaysAvailableRows()
	self:_setRows({
		{
			ContextName = "Gameplay",
			ActionName = "Interact",
			DisplayName = "Interact",
			BindingText = "F",
			LayoutOrder = 100,
		},
		{
			ContextName = "Gameplay",
			ActionName = "Sprint",
			DisplayName = "Sprint",
			BindingText = "LeftShift",
			LayoutOrder = 110,
		},
	})
end

function InputHintPane:Destroy()
	self._maid:DoCleaning()
end

return InputHintPane
```

For real UI, avoid hard-coding binding text forever. Start with a fallback, then
listen to each action's `PreferredBindingChanged` signal and rewrite that row
when Roblox chooses a better keyboard, gamepad, or touch binding for the player.

```lua
local function getBindingText(binding)
	if not binding then
		return "?"
	end

	if binding.DisplayName ~= "" then
		return binding.DisplayName
	end

	if binding.KeyCode ~= Enum.KeyCode.Unknown then
		return binding.KeyCode.Name
	end

	if binding.UIButton then
		return binding.UIButton.Name
	end

	return binding.Name
end

function InputHintPane:_watchPreferredBinding(row)
	local signals = self._inputServiceClient:GetActionSignals(row.ContextName, row.ActionName)

	local function update(binding)
		local nextRows = table.clone(self._rows.Value)

		for index, existing in nextRows do
			if existing.ContextName == row.ContextName and existing.ActionName == row.ActionName then
				local nextRow = table.clone(existing)
				nextRow.BindingText = getBindingText(binding)
				nextRows[index] = nextRow
				break
			end
		end

		self._rows.Value = nextRows
	end

	local action = self._inputServiceClient:GetAction(row.ContextName, row.ActionName)
	if action then
		update(action.PreferredBinding)
	end

	return signals.PreferredBindingChanged:Connect(update)
end
```

Tool-specific input works best as a lifetime-scoped layer. When the user equips a
tool, define or enable a local context for the tool, add its rows to the hint
list, and store all of that work in a tool maid. When the tool is unequipped, the
maid cleans the UI rows and disables or removes the tool context.

```lua
function InputHintPane:SetEquippedTool(tool)
	if self._toolMaid then
		self._toolMaid:DoCleaning()
	end

	self._toolMaid = Maid.new()
	self._maid._toolMaid = self._toolMaid

	if not tool then
		self:_setAlwaysAvailableRows()
		return
	end

	local contextName = "Tool:" .. tool.Name
	local toolRows = {
		{
			ContextName = contextName,
			ActionName = "Primary",
			DisplayName = tool.Name .. " Primary",
			BindingText = "MouseLeftButton",
			LayoutOrder = 200,
		},
		{
			ContextName = contextName,
			ActionName = "Reload",
			DisplayName = "Reload",
			BindingText = "R",
			LayoutOrder = 210,
		},
	}

	self._inputServiceClient:DefineLocalContext({
		Name = contextName,
		Enabled = true,
		Priority = 2600,
		Sink = false,
		Actions = {
			{
				Name = "Primary",
				DisplayName = tool.Name .. " Primary",
				Type = Enum.InputActionType.Bool,
				Bindings = {
					{
						Name = "Mouse",
						KeyCode = Enum.KeyCode.MouseLeftButton,
					},
				},
			},
			{
				Name = "Reload",
				DisplayName = "Reload",
				Type = Enum.InputActionType.Bool,
				Bindings = {
					{
						Name = "Keyboard",
						KeyCode = Enum.KeyCode.R,
					},
				},
			},
		},
	})

	local rows = table.clone(self._rows.Value)
	for _, row in toolRows do
		table.insert(rows, row)
		self._toolMaid:GiveTask(self:_watchPreferredBinding(row))
	end

	self:_setRows(rows)

	self._toolMaid:GiveTask(function()
		self._inputServiceClient:SetContextEnabled(contextName, false)
		self:_setAlwaysAvailableRows()
	end)
end
```

In a full Nevermore game, the tool layer usually comes from a service or Binder
instead of from the pane directly:

```lua
function ToolInputHintService:Start()
	local inputHintPane = InputHintPane.new(
		self._serviceBag:GetService(InputServiceClient),
		Players.LocalPlayer:WaitForChild("PlayerGui")
	)

	self._maid:GiveTask(inputHintPane)

	self._maid:GiveTask(self._equippedTool.Changed:Connect(function(tool)
		inputHintPane:SetEquippedTool(tool)
	end))
end
```

That keeps the responsibilities clean: `InputServiceClient` owns input instances,
the tool service decides which tool is active, and the Blend pane only renders
the current rows. The same shape works for ability bars, contextual prompts,
vehicle controls, build-mode hotkeys, and accessibility overlays.

## Config Reference

Every config requires a non-empty `Name` with no control characters or `/`.
Unknown fields are rejected so typos fail early.

Context fields:

| Field | Type | Notes |
| --- | --- | --- |
| `Name` | `string` | Required. Used as the `InputContext.Name`. |
| `Enabled` | `boolean?` | Sets whether the context is active. |
| `Priority` | `number?` | Higher-priority contexts can win over lower-priority contexts. |
| `Sink` | `boolean?` | Controls whether the context sinks input. |
| `Actions` | `{ InputActionConfig }?` | Actions to create or update under this context. |

Action fields:

| Field | Type | Notes |
| --- | --- | --- |
| `Name` | `string` | Required. Used as the `InputAction.Name`. |
| `DisplayName` | `string?` | Human-readable action name. |
| `Enabled` | `boolean?` | Sets whether the action is active. |
| `Type` | `Enum.InputActionType?` | The action value type, such as `Bool`, `Direction1D`, `Direction2D`, `Direction3D`, or `ViewportPosition`. |
| `Bindings` | `{ InputBindingConfig }?` | Bindings to create or update under this action. |

Binding fields:

| Field | Type | Notes |
| --- | --- | --- |
| `Name` | `string` | Required. Used as the `InputBinding.Name`. |
| `Type` | `Enum.InputBindingType?` | Binding type for runtimes that require it. |
| `KeyCode` | `Enum.KeyCode?` | Keyboard, mouse, or gamepad key/button binding. |
| `UIButton` | `GuiButton?` | UI button binding. |
| `UIModifier` | `GuiButton?` | UI modifier button. |
| `PrimaryModifier` | `Enum.KeyCode?` | Primary keyboard/gamepad modifier. |
| `SecondaryModifier` | `Enum.KeyCode?` | Secondary keyboard/gamepad modifier. |
| `DisplayName` | `string?` | Human-readable binding name. |
| `DisplayImage` | `Content?` | Binding icon/image content. |
| `PressedThreshold` | `number?` | Pressed threshold. Must be greater than or equal to `ReleasedThreshold` when both are set. |
| `ReleasedThreshold` | `number?` | Released threshold. |
| `ResponseCurve` | `number?` | Response curve value. |
| `Scale` | `number?` | Scalar output scale. |
| `Vector2Scale` | `Vector2?` | Vector2 output scale. |
| `Vector3Scale` | `Vector3?` | Vector3 output scale. |
| `PointerIndex` | `number?` | Pointer index for pointer-style bindings. |
| `ClampMagnitudeToOne` | `boolean?` | Clamp vector magnitude to one. |
| `Up` | `Enum.KeyCode?` | Up or positive direction key. |
| `Down` | `Enum.KeyCode?` | Down or negative direction key. |
| `Left` | `Enum.KeyCode?` | Left direction key. |
| `Right` | `Enum.KeyCode?` | Right direction key. |
| `Forward` | `Enum.KeyCode?` | Forward direction key for 3D actions. |
| `Backward` | `Enum.KeyCode?` | Backward direction key for 3D actions. |

## API Reference

Server `InputService`:

| Method | Description |
| --- | --- |
| `GetRootFolder()` | Returns `ReplicatedStorage.Inputs`. |
| `RegisterContext(config)` | Creates or updates one shared context. |
| `RegisterContexts(configs)` | Creates or updates many shared contexts. |
| `GetContext(contextName)` | Returns an `InputContext?`. |
| `GetAction(contextName, actionName)` | Returns an `InputAction?`. |
| `GetBinding(contextName, actionName, bindingName)` | Returns an `InputBinding?`. |
| `ConfigureAction(contextName, actionConfig)` | Creates or updates one action under an existing context. |
| `ConfigureBinding(contextName, actionName, bindingConfig)` | Creates or updates one binding under an existing action. |
| `SetContextEnabled(contextName, enabled)` | Enables or disables a context. |
| `SetActionEnabled(contextName, actionName, enabled)` | Enables or disables an action. |
| `RemoveContext(contextName)` | Removes a context and returns whether one was removed. |
| `RemoveAction(contextName, actionName)` | Removes an action and returns whether one was removed. |
| `RemoveBinding(contextName, actionName, bindingName)` | Removes a binding and returns whether one was removed. |

Client `InputServiceClient`:

| Method | Description |
| --- | --- |
| `GetRootFolder()` | Returns or creates the local root folder. |
| `GetContext(contextName)` | Returns an `InputContext?`. |
| `WaitForContext(contextName, timeoutSeconds?)` | Waits for a shared context to replicate. |
| `DefineLocalContext(config)` | Creates or updates a local-only context. |
| `ConfigureAction(contextName, actionConfig)` | Creates or updates an action under an existing context. |
| `ConfigureBinding(contextName, actionName, bindingConfig)` | Creates or updates a binding under an existing action. |
| `GetAction(contextName, actionName)` | Returns an `InputAction?`. |
| `GetBinding(contextName, actionName, bindingName)` | Returns an `InputBinding?`. |
| `GetActionSignals(contextName, actionName)` | Returns cached pressed, released, state, enabled, and preferred-binding signals. |
| `BindPressed(contextName, actionName, callback)` | Connects to an action's pressed signal. |
| `BindReleased(contextName, actionName, callback)` | Connects to an action's released signal. |
| `BindStateChanged(contextName, actionName, callback)` | Connects to an action's state changed signal. |
| `SetContextEnabled(contextName, enabled)` | Enables or disables a context locally. |
| `SetActionEnabled(contextName, actionName, enabled)` | Enables or disables an action locally. |
| `FireBinding(contextName, actionName, bindingName, state)` | Fires a scriptable binding with `boolean`, `number`, `Vector2`, or `Vector3` state. |

## Security

- No remotes are created for input claims, rebinding, or context changes.
- Server APIs accept configs only from server code.
- Client-side input signals should be treated as intent only.
- Client-created contexts and bindings are local convenience only.
- Games must validate gameplay effects on the server.
