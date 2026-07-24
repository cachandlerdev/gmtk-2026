class_name PatrolAction
extends ActionLeaf
## Walks the enemy forward at its patrol speed, turning around at walls and
## before platform edges. Runs indefinitely, so it always reports RUNNING.


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var enemy := actor as EnemyBase
	if enemy == null:
		return FAILURE
	enemy.patrol_step(enemy.patrol_speed)
	return RUNNING
