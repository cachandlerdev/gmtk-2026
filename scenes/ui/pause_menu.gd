extends CanvasLayer

## Global pause menu, registered as an Autoload so it works in every scene.
## Its process_mode is ALWAYS (set in the scene) so it keeps running while the
## SceneTree is paused — otherwise it would freeze along with the gameplay and
## you could never un-pause.

@onready var resume_button: Button = $Center/Menu/ResumeButton
@onready var quit_button: Button = $Center/Menu/QuitButton

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_resume)
	quit_button.pressed.connect(_quit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	if get_tree().paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	get_tree().paused = true
	visible = true

func _resume() -> void:
	get_tree().paused = false
	visible = false

func _quit() -> void:
	# Un-pause first so the tree is in a clean state, then head to the main menu.
	get_tree().paused = false
	visible = false
	LevelManager.go_to_main_menu()
