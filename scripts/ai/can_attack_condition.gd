class_name CanAttackCondition
extends ConditionLeaf
## SUCCESS when the player is within the enemy's attack range and its attack is
## off cooldown.


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var enemy := actor as EnemyBase
	if enemy == null:
		return FAILURE
	return SUCCESS if enemy.can_attack() else FAILURE
