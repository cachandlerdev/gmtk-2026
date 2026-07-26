extends Control

@onready var start_button: Button = $"CenterContainer/VBoxContainer/Start Game"


func _ready() -> void:
	# Announce we're on the menu so global HUD bits (the stealth eye) hide and
	# the menu music plays. On boot nothing else sets this — GameMode defaults
	# to Stealth — so the menu has to do it itself.
	GameMode.set_state(GameMode.MainMenu)
	start_button.call_deferred("grab_focus")


func _on_start_game_pressed() -> void:
	LevelManager.start_game()


func _on_controls_pressed() -> void:
	ControlsMenu.open(false)


func _on_settings_pressed() -> void:
	SettingsMenu.open(false)


func _on_quit_game_pressed() -> void:
	get_tree().quit()
