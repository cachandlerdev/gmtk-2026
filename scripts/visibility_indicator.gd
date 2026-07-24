extends AnimatedSprite2D

var was_hidden: bool = true
var _game_states_not_to_show = [GameMode.Victory, GameMode.Defeat, GameMode.MainMenu]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	visible = GameMode.get_state() not in _game_states_not_to_show

	# Not great on tick but it's fast
	if GameMode.is_hidden() and not was_hidden:
		play("close_eye")
	elif not GameMode.is_hidden() and was_hidden:
		play("close_eye", -1.0)

	was_hidden = GameMode.is_hidden()
