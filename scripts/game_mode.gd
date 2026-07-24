extends Node


var _num_of_alert_guards: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	print(_num_of_alert_guards)
	pass


## Returns whether there are any guards that currently know where the player is.
func is_hidden() -> bool:
	return _num_of_alert_guards == 0


## Used to let the player know that he's been discovered. Adds the guard to a 
## list of alert guards.
func add_watching_guard() -> void:
	_num_of_alert_guards += 1


## Used when a guard gives up and loses the player. Removes the specified guard
## from the list of alert guards.
func remove_watching_guard() -> void:
	_num_of_alert_guards -= 1
