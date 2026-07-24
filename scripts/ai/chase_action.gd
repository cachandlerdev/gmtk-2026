class_name ChaseAction
extends ActionLeaf
## Turns the enemy to face the player and advances at its chase speed, stopping
## at walls and ledges. Runs for as long as the enemy stays alerted.


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var enemy := actor as EnemyBase
	if enemy == null:
		return FAILURE
	enemy.chase_step(enemy.chase_speed)
	return RUNNING
