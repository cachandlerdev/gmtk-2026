class_name Archer
extends EnemyBase
## A ranged guard. Patrols until its vision cone spots the player, then holds
## position, faces them, and looses arrows on the attack cooldown while it has
## line of sight. It does not chase or melee, so it is vulnerable up close.


@export var projectile_scene: PackedScene
@export var projectile_speed: float = 340.0
## Muzzle position relative to the archer; x is mirrored to the facing side.
@export var muzzle_offset: Vector2 = Vector2(12, -16)


## Called by ShootAction each frame the archer is alerted. Holds position, faces
## the player, and fires when the cooldown allows and it can actually see them.
func shoot_step() -> void:
	velocity.x = 0.0
	var player := get_player()
	if player == null:
		return
	set_facing(1 if player.global_position.x >= global_position.x else -1)
	if _attack_cooldown_left > 0.0 or not can_see_player():
		return
	_attack_cooldown_left = attack_cooldown
	_on_attack()
	_fire_at(player)


func _fire_at(player: Node2D) -> void:
	if projectile_scene == null:
		return
	var arrow := projectile_scene.instantiate()
	arrow.speed = projectile_speed
	var origin := global_position + Vector2(absf(muzzle_offset.x) * facing, muzzle_offset.y)
	# Aim at the player's body rather than their feet.
	arrow.direction = ((player.global_position + Vector2(0, -12)) - origin).normalized()

	# Spawn into the level and place it at the muzzle.
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	parent.add_child(arrow)
	arrow.global_position = origin
