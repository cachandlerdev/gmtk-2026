class_name ShootAction
extends ActionLeaf
## Holds the archer in place and fires at the player. RUNNING so the archer keeps
## facing and firing (paced by its attack cooldown) for as long as it's alerted.


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var archer := actor as Archer
	if archer == null:
		return FAILURE
	archer.shoot_step()
	return RUNNING
