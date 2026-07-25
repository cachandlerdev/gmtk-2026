extends Control
## Final victory screen, shown by the LevelManager after the last level in its
## list is cleared. A full scene (not an overlay) reached via change_scene.

@onready var play_again_button: Button = $Center/Menu/PlayAgainButton
@onready var main_menu_button: Button = $Center/Menu/MainMenuButton


func _ready() -> void:
	play_again_button.pressed.connect(LevelManager.start_game)
	main_menu_button.pressed.connect(LevelManager.go_to_main_menu)
