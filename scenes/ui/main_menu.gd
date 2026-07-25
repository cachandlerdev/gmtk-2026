extends Control


func _ready() -> void:
	# Announce we're on the menu so global HUD bits (the stealth eye) hide and
	# the menu music plays. On boot nothing else sets this — GameMode defaults
	# to Stealth — so the menu has to do it itself.
	GameMode.set_state(GameMode.MainMenu)


func _on_start_game_pressed() -> void:
	LevelManager.start_game()


func _on_quit_game_pressed() -> void:
	get_tree().quit()
