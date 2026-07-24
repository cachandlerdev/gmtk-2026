extends Node


@export_group("Music")
# TODO: Change for multiple music tracks. Not the prettiest system but it'll work
# TODO: Add a filler clip
@export var exploration_music_index: int = 0
@export var battle_music_index: int = 1
@export var near_death_music_index: int = 2
@export var victory_music_index: int = 3
@export var defeat_music_index: int = 4
@export var escape_music_index: int = 5
@export var main_menu_music_index: int = 6
@export var alarm_raised_music_index: int = 7


enum {Exploration, Battle, NearDeath, AlarmRaised, Escape, Victory, Defeat, MainMenu}
var _game_mode_state := Exploration


var _num_of_alert_guards: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	print(_num_of_alert_guards)
	pass


func get_state():
	return _game_mode_state


## Updates the game state and handles things like music changes 
func set_state(new_state) -> void:
	# TODO: Make this more sophisticated for multiple music tracks. 
	# Not the prettiest system but it'll work for now
	_game_mode_state = new_state
	match new_state:
		Exploration:
			MusicPlayer.get_stream_playback().switch_to_clip(exploration_music_index)
		Battle:
			print("TODO: Battle stage")
			MusicPlayer.get_stream_playback().switch_to_clip(battle_music_index)
		NearDeath:
			print("TODO: Near Death stage")
			MusicPlayer.get_stream_playback().switch_to_clip(near_death_music_index)
		AlarmRaised:
			print("TODO: Alarm Raised stage")
			MusicPlayer.get_stream_playback().switch_to_clip(alarm_raised_music_index)
		Escape:
			print("TODO: Escape stage")
			MusicPlayer.get_stream_playback().switch_to_clip(escape_music_index)
		Victory:
			print("TODO: Victory stage")
			MusicPlayer.get_stream_playback().switch_to_clip(victory_music_index)
		Defeat:
			print("TODO: Defeat stage")
			_num_of_alert_guards = 0
			MusicPlayer.get_stream_playback().switch_to_clip(defeat_music_index)
		MainMenu:
			print("TODO: Main Menu stage")
			MusicPlayer.get_stream_playback().switch_to_clip(main_menu_music_index)


## Returns whether there are any guards that currently know where the player is.
func is_hidden() -> bool:
	return _num_of_alert_guards == 0


## Used to let the player know that he's been discovered. Adds the guard to a 
## list of alert guards.
func add_watching_guard() -> void:
	_num_of_alert_guards += 1
	if _num_of_alert_guards == 1 and _game_mode_state == Exploration:
		set_state(Battle)


## Used when a guard gives up and loses the player. Removes the specified guard
## from the list of alert guards.
func remove_watching_guard() -> void:
	_num_of_alert_guards -= 1
	if _num_of_alert_guards == 0 and _game_mode_state == Battle:
		set_state(Exploration)
