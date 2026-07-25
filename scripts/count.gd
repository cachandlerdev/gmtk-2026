class_name Count
extends EnemyBase
## The Count — the assassination target and final boss of an area.
##
## For now it is just a tough melee guard using the shared guard brain; the real
## multi-phase boss fight (special moves, calling guards, phase changes by
## health) will hang off the hooks here later.

## Emitted when the Count is killed — hook this for area-completion / victory.
signal defeated


## Register as the level's objective so level.gd can find us and wire `defeated`
## to level completion.
func _ready_enemy() -> void:
	add_to_group("objective")


func _on_death() -> void:
	# Keep the base's alert/GameMode cleanup, then announce the kill.
	super._on_death()
	defeated.emit()
	GameMode.set_state(GameMode.Escape)
