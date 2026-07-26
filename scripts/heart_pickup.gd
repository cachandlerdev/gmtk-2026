class_name HeartPickup
extends PickupBase
## World heart the player can walk over to restore health. Place in levels or drop from enemies.


@export var amount: int = 1


## Heal the player and despawn. Returns true when looted.
func try_loot(player: Node) -> bool:
	if player == null or amount <= 0:
		return false
	if not player.has_method("try_heal"):
		return false
	if not player.try_heal(amount):
		MessageFeed.show_message("Health is full.")
		return false
	GameMode.play_sound("heart_pickup", global_position)
	queue_free()
	return true
