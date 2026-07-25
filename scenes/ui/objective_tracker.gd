extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	match GameMode.get_state():
		GameMode.MainMenu:
			text = ""
		GameMode.AlarmRaised: 
			text = "The alarm has been raised. Escape!"
		GameMode.Escape:
			text = "The count is down. Escape!"
		GameMode.Victory: 
			text = ""
		GameMode.Defeat:
			text = ""
		_:
			text = "Find the count."
	pass
