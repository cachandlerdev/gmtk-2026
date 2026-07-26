extends CanvasLayer

## Global pause menu, registered as an Autoload so it works in every scene.
## Its process_mode is ALWAYS (set in the scene) so it keeps running while the
## SceneTree is paused — otherwise it would freeze along with the gameplay and
## you could never un-pause.

@onready var restart_button: Button = $Center/Menu/RestartButton
@onready var main_menu_button: Button = $Center/Menu/MainMenuButton

var _prev_game_mode = GameMode.Stealth

func _ready() -> void:
	visible = false
	restart_button.pressed.connect(_restart)
	main_menu_button.pressed.connect(_quit)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# yeah I know it's not great that this is on tick but it was the easiest way
	if GameMode.get_state() == GameMode.Defeat and _prev_game_mode != GameMode.Defeat:
		visible = true
		$AnimationPlayer.play("fade_in")
	_prev_game_mode = GameMode.get_state()


func hide_menu() -> void:
	visible = false
	get_tree().reload_current_scene()
	GameMode.set_state(GameMode.Stealth)


func _restart() -> void:
	LevelManager.restart_level()


func _quit() -> void:
	LevelManager.go_to_main_menu()
