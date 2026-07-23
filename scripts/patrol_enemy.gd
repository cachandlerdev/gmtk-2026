class_name PatrolEnemy
extends EnemyBase
## Walks back and forth, turning around at walls and before platform edges.


@export var speed: float = 90.0


func _behaviour(_delta: float) -> void:
	# Turn at a wall, or before walking off the edge of the platform.
	if is_on_floor() and (is_on_wall() or not has_ground_ahead()):
		set_facing(-facing)
	velocity.x = facing * speed
