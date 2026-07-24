class_name PatrolEnemy
extends EnemyBase
## Walks back and forth, turning at walls and platform edges. If it has a
## VisionCone child and spots the player, it chases them until it loses sight.


@export var speed: float = 90.0
@export var chase_speed: float = 130.0


func _behaviour(_delta: float) -> void:
	if is_alerted:
		chase_step(chase_speed)
	else:
		patrol_step(speed)


func _on_death_despawn_timer_timeout() -> void:
	pass # Replace with function body.
