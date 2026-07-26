class_name KeyPickup
extends PickupBase
## World key the player can walk over to collect. Place in levels or drop from enemies.


@export var amount: int = 1


## Add keys to the player and despawn. Returns true when looted.
func try_loot(player: Node) -> bool:
	if player == null or amount <= 0:
		return false
	if not player.has_method("add_keys"):
		return false
	var n := amount
	amount = 0
	player.add_keys(n)
	queue_free()
	return true
