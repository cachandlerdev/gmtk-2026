class_name Shieldbearer
extends EnemyBase
## Patrols back and forth behind a raised shield. When its vision cone spots the
## player it turns to face them and advances, keeping the shield between itself
## and the player.
##
## Damage is gated by hit direction: shots into the shielded front are blocked
## (and bounced back like off a wall). Land a hit by getting behind it (dash
## past), ricocheting a shot in from the rear, or arcing a plunging shot over
## the top of the shield. Arrows never pierce through a shieldbearer.


@export var patrol_speed: float = 55.0
@export var chase_speed: float = 95.0
## Speed a blocked arrow keeps when it bounces off the shield.
@export var block_bounce: float = 0.7


func _behaviour(_delta: float) -> void:
	# is_alerted is driven by the base's VisionCone perception.
	if is_alerted:
		chase_step(chase_speed)
	else:
		patrol_step(patrol_speed)


## The shield blocks shots into its front. A hit lands from behind, or from a
## steeply descending arrow that clears the top of the shield.
func _can_be_hit(source: Node = null) -> bool:
	if source == null:
		return true

	var body := source as CharacterBody2D
	var v := body.velocity if body != null else Vector2.ZERO

	# A steeply descending arrow drops over the top of the shield.
	if v.y > absf(v.x) and v.y > 1.0:
		return true

	# Otherwise blocked when the shot is on the shielded (front) side. Uses
	# position, not velocity, so a shot stays blocked even as we bounce it.
	var n2d := source as Node2D
	if n2d != null:
		return signf(n2d.global_position.x - global_position.x) != float(facing)
	return true


## Shielded enemies always stop the arrow; full-draw pierce does not apply.
func _can_be_pierced(_source: Node = null) -> bool:
	return false


## Bounce a blocked arrow back off the shield, with a metallic glint.
func _on_hit_blocked(source: Node = null) -> void:
	var body := source as CharacterBody2D
	if body != null:
		# Reflect off the shield's outward-facing normal.
		body.velocity = body.velocity.bounce(Vector2(facing, 0.0)) * block_bounce
	if _visual != null:
		_visual.modulate = Color(1.4, 1.4, 1.6)
		create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.12)
