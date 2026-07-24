class_name AttackAction
extends ActionLeaf
## Swings once at the player, then reports SUCCESS. The enemy's attack cooldown
## (checked by CanAttackCondition) paces how often this can run.


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var enemy := actor as EnemyBase
	if enemy == null:
		return FAILURE
	enemy.attack()
	return SUCCESS
