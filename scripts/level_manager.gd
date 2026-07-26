extends Node
## Central owner of level order and every scene transition. The main menu, the
## per-level win hook, and the death/pause menus all route through here instead
## of each calling change_scene_to_file with a hardcoded path.
##
## Registered as an Autoload (see project.godot). Persists across scenes, so it
## remembers which level in `levels` we are on.

## Ordered list of playable level scenes.
## DESIGNERS: append your level's scene path here. A level is "complete" when its
## objective (the Count, in group "objective") is killed — see level.gd — so a
## level needs a Count to be finishable for now.
@export var levels: Array[String] = [
	"res://scenes/levels/level_1_courtyard.tscn",
	"res://scenes/levels/level_2_gallery.tscn",
	"res://scenes/levels/level_3_throne.tscn",
]

const MAIN_MENU := "res://scenes/levels/main_menu_level.tscn"
const VICTORY_SCREEN := "res://scenes/ui/victory_menu.tscn"

## Index into `levels` of the level currently being played.
var _index: int = 0


## Begin a fresh run from the first level. Called by the main menu's Start button.
func start_game() -> void:
	_index = 0
	_load_level(_index)


## Called by a level when its win condition is met (first pass: the Count dies).
## Shows the level-complete menu, or the final victory screen if this was the
## last level in the list.
func complete_level() -> void:
	GameMode.set_state(GameMode.Victory)
	if _index >= levels.size() - 1:
		# Final level cleared — roll the victory screen straight away.
		_go_to(VICTORY_SCREEN)
	else:
		# Freeze the level and let the player choose to advance.
		await get_tree().create_timer(2.5).timeout
		get_tree().paused = true
		LevelCompleteMenu.show_menu()


## Advance to the next level (from the level-complete menu).
func next_level() -> void:
	_index += 1
	if _index >= levels.size():
		_go_to(VICTORY_SCREEN)
	else:
		_load_level(_index)


## Reload the level currently being played (from the level-complete or death menu).
func restart_level() -> void:
	_load_level(_index)


## Return to the main menu.
func go_to_main_menu() -> void:
	_go_to(MAIN_MENU)
	GameMode.set_state(GameMode.MainMenu)


## Load the level at `i`, dropping into stealth mode.
func _load_level(i: int) -> void:
	_clear_overlays()
	get_tree().change_scene_to_file(levels[i])
	GameMode.set_state(GameMode.Stealth)


## Transition to an arbitrary scene (menus, victory screen).
func _go_to(path: String) -> void:
	_clear_overlays()
	get_tree().change_scene_to_file(path)


## Un-pause and hide any overlay menus before a transition, so nothing lingers
## on top of the newly loaded scene.
func _clear_overlays() -> void:
	get_tree().paused = false
	LevelCompleteMenu.hide_menu()
	DeathMenu.hide_menu()
	if SettingsMenu.visible:
		SettingsMenu.visible = false
	if PauseMenu.visible:
		PauseMenu.visible = false
