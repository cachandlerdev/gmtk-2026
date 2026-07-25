extends Node2D
## Base script for a playable level. Handles standard per-level setup and wires
## the win condition to the LevelManager. First pass: the level is complete when
## the assassination target (the Count, in group "objective") is killed.
##
## Attach this to a level's root Node2D, or extend it (see enemy_test_level.gd).

func _ready() -> void:
	GameMode.set_state(GameMode.Stealth)
	_connect_objective()


## Find the level's objective and route its defeat to the LevelManager. Children
## are ready before the level root, so the Count is already in its group here.
func _connect_objective() -> void:
	var objective := get_tree().get_first_node_in_group("objective")
	if objective and objective.has_signal("defeated"):
		objective.defeated.connect(_on_objective_defeated)


func _on_objective_defeated() -> void:
	LevelManager.complete_level()
