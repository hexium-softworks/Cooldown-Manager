--!strict
--[=[
	Shared public types for InputService.

	@class InputServiceTypes
]=]

local InputServiceTypes = {}

export type InputActionState = boolean | number | Vector2 | Vector3

export type InputBindingConfig = {
	Name: string,
	Type: Enum.InputBindingType?,
	KeyCode: Enum.KeyCode?,
	UIButton: GuiButton?,
	UIModifier: GuiButton?,
	PrimaryModifier: Enum.KeyCode?,
	SecondaryModifier: Enum.KeyCode?,
	DisplayName: string?,
	DisplayImage: any?,
	PressedThreshold: number?,
	ReleasedThreshold: number?,
	ResponseCurve: number?,
	Scale: number?,
	Vector2Scale: Vector2?,
	Vector3Scale: Vector3?,
	PointerIndex: number?,
	ClampMagnitudeToOne: boolean?,
	Up: Enum.KeyCode?,
	Down: Enum.KeyCode?,
	Left: Enum.KeyCode?,
	Right: Enum.KeyCode?,
	Forward: Enum.KeyCode?,
	Backward: Enum.KeyCode?,
}

export type InputActionConfig = {
	Name: string,
	DisplayName: string?,
	Enabled: boolean?,
	Type: Enum.InputActionType?,
	Bindings: { InputBindingConfig }?,
}

export type InputContextConfig = {
	Name: string,
	Enabled: boolean?,
	Priority: number?,
	Sink: boolean?,
	Actions: { InputActionConfig }?,
}

export type ActionSignalBundle = {
	Pressed: any,
	Released: any,
	StateChanged: any,
	EnabledChanged: any,
	PreferredBindingChanged: any,
	Destroy: (ActionSignalBundle) -> (),
}

return InputServiceTypes
