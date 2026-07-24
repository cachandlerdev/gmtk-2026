class_name IsAlertedCondition
extends ConditionLeaf
## SUCCESS while the enemy is alerted — i.e. its VisionCone can see the player,
## or saw them within the last `alert_linger` seconds.


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var enemy := actor as EnemyBase
	if enemy == null:
		return FAILURE
	return SUCCESS if enemy.is_alerted else FAILURE
