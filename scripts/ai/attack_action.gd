class_name AttackAction
extends ActionLeaf
## Runs a melee swing: a brief wind-up pause (the player's chance to strike or
## dodge first), then the blow. RUNNING during the wind-up, SUCCESS once it
## resolves; the attack cooldown then paces the next one.


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var enemy := actor as EnemyBase
	if enemy == null:
		return FAILURE
	if enemy.attack_step(enemy.get_physics_process_delta_time()):
		return RUNNING
	return SUCCESS


## If the branch switches away mid-swing (lost the player, etc.), abandon the
## wind-up cleanly instead of leaving the enemy stuck.
func interrupt(actor: Node, blackboard: Blackboard) -> void:
	var enemy := actor as EnemyBase
	if enemy != null:
		enemy.cancel_attack()
	super(actor, blackboard)
