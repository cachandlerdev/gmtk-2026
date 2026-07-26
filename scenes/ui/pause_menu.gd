extends CanvasLayer

## Global pause menu, registered as an Autoload so it works in every scene.
## Its process_mode is ALWAYS (set in the scene) so it keeps running while the
## SceneTree is paused — otherwise it would freeze along with the gameplay and
## you could never un-pause.

@onready var resume_button: Button = $Center/Menu/ResumeButton
@onready var controls_button: Button = $Center/Menu/ControlsButton
@onready var settings_button: Button = $Center/Menu/SettingsButton
@onready var quit_button: Button = $Center/Menu/QuitButton

## B is both "menu back" and "dash". After closing with B, ignore dash until
## that button is released so the same press can't dash on unpause.
var _suppress_dash_until_release: bool = false

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_resume)
	controls_button.pressed.connect(_open_controls)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(_quit)

func _input(event: InputEvent) -> void:
	if SettingsMenu.visible or ControlsMenu.visible:
		return
	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_suppress_dash_until_release = true
		_resume()

func _process(_delta: float) -> void:
	if not _suppress_dash_until_release:
		return
	# Keep dash from re-latching while B is still held after closing the menu.
	Input.action_release("dash")
	if not Input.is_physical_key_pressed(KEY_ESCAPE) and not _is_cancel_button_held():
		_suppress_dash_until_release = false

func _is_cancel_button_held() -> bool:
	# Joypad B / East face button (JOY_BUTTON_B == 1), matching ui_cancel.
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_B):
			return true
	return false

## True while the close-menu B press is still held — player must not dash.
func should_suppress_dash() -> bool:
	return _suppress_dash_until_release

func _toggle() -> void:
	if get_tree().paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	get_tree().paused = true
	visible = true
	resume_button.grab_focus()

func _resume() -> void:
	get_tree().paused = false
	visible = false

func show_from_settings() -> void:
	visible = true
	resume_button.grab_focus()

func _open_controls() -> void:
	visible = false
	ControlsMenu.open(true)

func _open_settings() -> void:
	visible = false
	SettingsMenu.open(true)

func _quit() -> void:
	# Un-pause first so the tree is in a clean state, then head to the main menu.
	get_tree().paused = false
	visible = false
	LevelManager.go_to_main_menu()
