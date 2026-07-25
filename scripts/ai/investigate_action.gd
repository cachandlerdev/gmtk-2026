class_name InvestigateAction
extends ActionLeaf
## Holds the enemy in place, turned toward where it last saw the player, while
## its detection meter fills toward full alert or drains back to unaware.


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var enemy := actor as EnemyBase
	if enemy == null:
		return FAILURE
	enemy.investigate_step()
	return RUNNING
