extends CanvasLayer
## Shown when a level's win condition is met (first pass: the Count is dead).
## Freezes the level and lets the player advance, retry, or bail to the menu.
##
## Registered as an Autoload so it persists across scenes, mirroring DeathMenu.
## The LevelManager pauses the tree before showing this; our process_mode is
## ALWAYS (set in the scene) so the buttons keep working while paused.

@onready var next_button: Button = $Center/Menu/NextButton
@onready var restart_button: Button = $Center/Menu/RestartButton
@onready var main_menu_button: Button = $Center/Menu/MainMenuButton


func _ready() -> void:
	visible = false
	next_button.pressed.connect(_on_next)
	restart_button.pressed.connect(_on_restart)
	main_menu_button.pressed.connect(_on_main_menu)


func show_menu() -> void:
	visible = true
	$AnimationPlayer.play("fade_in")


func hide_menu() -> void:
	visible = false


func _on_next() -> void:
	LevelManager.next_level()


func _on_restart() -> void:
	LevelManager.restart_level()


func _on_main_menu() -> void:
	LevelManager.go_to_main_menu()
