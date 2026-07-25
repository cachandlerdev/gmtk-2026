class_name IsSuspiciousCondition
extends ConditionLeaf
## SUCCESS while the enemy is SUSPICIOUS — its detection meter is partway up but
## not yet full. (Below full-alert, above unaware.)


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var enemy := actor as EnemyBase
	if enemy == null:
		return FAILURE
	return SUCCESS if enemy.awareness == EnemyBase.Awareness.SUSPICIOUS else FAILURE
