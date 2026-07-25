extends Node


@export_group("Music")
# TODO: Change for multiple music tracks. Not the prettiest system but it'll work
# TODO: Add a filler clip
@export var main_menu_music_index: int = 0
@export var battle_music_index: int = 1
@export var near_death_music_index: int = 2
@export var victory_music_index: int = 3
@export var defeat_music_index: int = 4
@export var escape_music_index: int = 5
@export var exploration_music_index: int = 6 # outside, probably harp?
@export var stealth_music_index: int = 7
@export var alarm_raised_music_index: int = 8


enum {MainMenu, Battle, NearDeath, AlarmRaised, Escape, Victory, Defeat, Exploration, Stealth}
var _game_mode_state := Stealth
var _num_of_alert_guards: int = 0
## Strongest detection any guard currently has on the player, 0..1.
var _detection_level: float = 0.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Track the highest detection meter across all guards so the visibility eye can
# open gradually as the player is spotted.
func _process(_delta: float) -> void:
	var highest := 0.0
	for guard in get_tree().get_nodes_in_group("enemy"):
		if "detection" in guard:
			highest = maxf(highest, guard.detection)
	_detection_level = highest


func get_state():
	return _game_mode_state


## Updates the game state and handles things like music changes 
func set_state(new_state) -> void:
	# TODO: Make this more sophisticated for multiple music tracks. 
	# Not the prettiest system but it'll work for now
	var player = get_tree().get_first_node_in_group("player")

	var can_change: bool = false
	match new_state:
		Stealth:
			if _game_mode_state != AlarmRaised and _game_mode_state != Escape:
				MusicPlayer.get_stream_playback().switch_to_clip(stealth_music_index)
				can_change = true
		Exploration:
			if _game_mode_state != AlarmRaised and _game_mode_state != Escape:
				MusicPlayer.get_stream_playback().switch_to_clip(stealth_music_index)
				MusicPlayer.get_stream_playback().switch_to_clip(exploration_music_index)
				can_change = true
		Battle:
			if not player._is_dead and _game_mode_state != AlarmRaised and _game_mode_state != Escape:
				print("TODO: Battle stage")
				MusicPlayer.get_stream_playback().switch_to_clip(battle_music_index)
				can_change = true
		NearDeath:
			if not player._is_dead and _game_mode_state != AlarmRaised and _game_mode_state != Escape:
				print("TODO: Near Death stage")
				MusicPlayer.get_stream_playback().switch_to_clip(near_death_music_index)
				can_change = true
		AlarmRaised:
			if not player._is_dead:
				print("TODO: Alarm Raised stage")
				MusicPlayer.get_stream_playback().switch_to_clip(alarm_raised_music_index)
				can_change = true
		Escape:
			# We don't check AlarmRaised here so that if the count is killed 
			# after the alarm is raised, it updates to say that the count is dead.
			if not player._is_dead and _game_mode_state != Escape:
				print("TODO: Escape stage")
				MusicPlayer.get_stream_playback().switch_to_clip(escape_music_index)
				can_change = true
		Victory:
			print("TODO: Victory stage")
			MusicPlayer.get_stream_playback().switch_to_clip(victory_music_index)
			can_change = true
		Defeat:
			print("TODO: Defeat stage")
			_num_of_alert_guards = 0
			MusicPlayer.get_stream_playback().switch_to_clip(defeat_music_index)
			can_change = true
		MainMenu:
			print("TODO: Main Menu stage")
			MusicPlayer.get_stream_playback().switch_to_clip(main_menu_music_index)
			can_change = true

	if can_change:
		_game_mode_state = new_state


## Returns whether there are any guards that currently know where the player is.
func is_hidden() -> bool:
	return _num_of_alert_guards == 0


## The strongest detection any guard has on the player right now, 0..1. 0 = fully
## unseen, 1 = a guard is fully alerted. Drives the visibility eye's openness.
func get_detection_level() -> float:
	return _detection_level


## Used to let the player know that he's been discovered. Adds the guard to a 
## list of alert guards.
func add_watching_guard() -> void:
	_num_of_alert_guards += 1
	if _num_of_alert_guards == 1 and (_game_mode_state == Exploration or _game_mode_state == Stealth):
		set_state(Battle)


## Used when a guard gives up and loses the player. Removes the specified guard
## from the list of alert guards.
func remove_watching_guard() -> void:
	_num_of_alert_guards -= 1
	if _num_of_alert_guards == 0 and _game_mode_state == Battle:
		set_state(Stealth)
