extends CanvasLayer
## Controls overlay, registered as an Autoload so both the main menu and the
## pause menu can reach it. process_mode is ALWAYS (set in the scene) so it
## keeps running while the tree is paused.

@onready var back_button: Button = $Center/Menu/BackButton

## When true, closing controls re-shows the pause menu instead of just hiding.
var _opened_from_pause: bool = false
var _previous_focus: Control


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open(from_pause: bool = false) -> void:
	_opened_from_pause = from_pause
	_previous_focus = get_viewport().gui_get_focus_owner()
	visible = true
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	if _opened_from_pause:
		_opened_from_pause = false
		PauseMenu.show_from_settings()
	if is_instance_valid(_previous_focus):
		_previous_focus.call_deferred("grab_focus")
