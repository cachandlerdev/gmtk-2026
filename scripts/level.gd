extends Node2D
## Base script for a playable level. Handles standard per-level setup and wires
## the objective to the escape phase.
##
## Flow: killing the assassination target (the Count, in group "objective")
## flips GameMode into the Escape state; the level is not complete until the
## player then reaches the Exit zone (see exit.gd), which calls
## LevelManager.complete_level().
##
## Attach this to a level's root Node2D, or extend it (see enemy_test_level.gd).

func _ready() -> void:
	GameMode.set_state(GameMode.Stealth)
	_connect_objective()


## Find the level's objective and route its defeat to the escape phase. Children
## are ready before the level root, so the Count is already in its group here.
func _connect_objective() -> void:
	var objective := get_tree().get_first_node_in_group("objective")
	if objective and objective.has_signal("defeated"):
		objective.defeated.connect(_on_objective_defeated)


## The target is dead — begin the escape. The Exit zone takes it from here.
func _on_objective_defeated() -> void:
	GameMode.set_state(GameMode.Escape)
