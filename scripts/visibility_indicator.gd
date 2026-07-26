extends Control
## The stealth "eye" on the HUD. Its openness tracks the strongest guard
## detection: fully closed while unseen, opening as a guard's detection meter
## fills, fully open once a guard is alerted.

var _game_states_not_to_show = [GameMode.Victory, GameMode.Defeat, GameMode.MainMenu]

@onready var animation_player = $AnimationPlayer
@onready var visibility_indicator = $VisibilityIndicator


func _ready() -> void:
	# Drive the frame manually rather than autoplaying the open/close animation.
	visibility_indicator.stop()
	
	visibility_indicator.animation = &"close_eye"
	animation_player.play("fade_in")


func _process(_delta: float) -> void:
	visible = GameMode.get_state() not in _game_states_not_to_show
	if not visible:
		return
	# Frame 0 = open eye (fully detected); last frame = closed (unseen).
	var last = visibility_indicator.sprite_frames.get_frame_count(&"close_eye") - 1
	visibility_indicator.frame = int(round((1.0 - GameMode.get_detection_level()) * last))
