extends CanvasLayer

## Global pause menu, registered as an Autoload so it works in every scene.
## Its process_mode is ALWAYS (set in the scene) so it keeps running while the
## SceneTree is paused — otherwise it would freeze along with the gameplay and
## you could never un-pause.

@onready var restart_button: Button = $Center/Menu/RestartButton
@onready var main_menu_button: Button = $Center/Menu/MainMenuButton

@export var main_menu_path: String = "res://scenes/levels/main_menu_level.tscn"

func _ready() -> void:
	visible = false
	restart_button.pressed.connect(_restart)
	main_menu_button.pressed.connect(_quit)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# yeah I know it's not great that this is on tick but it was the easiest way
	if GameMode.get_state() == GameMode.Defeat:
		visible = true


func _restart() -> void:
	visible = false
	get_tree().reload_current_scene()
	GameMode.set_state(GameMode.Stealth)
	var player = get_tree().get_first_node_in_group("player")

func _quit() -> void:
	# Un-pause first so the tree is in a clean state, then exit.
	# Swap this for get_tree().change_scene_to_file(...) once a main menu exists.
	visible = false
	get_tree().change_scene_to_file(main_menu_path)
	GameMode.set_state(GameMode.MainMenu)
