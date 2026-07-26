class_name Shieldbearer
extends EnemyBase
## A guard that fights behind a raised shield. Its movement (patrol until it
## spots the player, then chase) comes from its BeehaveTree child; this script
## only handles the shield.
##
## Damage is gated by hit direction: shots into the shielded front are blocked
## (and bounced back like off a wall). Land a hit by getting behind it (dash
## past), ricocheting a shot in from the rear, or arcing a plunging shot over
## the top of the shield. A full-draw piercing arrow can punch through the
## shield (dealing damage), but that spends its entire pierce budget so the
## arrow stops there. Other arrows never pierce the shield.


## Speed a blocked arrow keeps when it bounces off the shield.
@export var block_bounce: float = 0.7


## The shield blocks shots into its front. A hit lands from behind, or from a
## steeply descending arrow that clears the top of the shield. Full-draw
## piercing arrows ignore the front block.
func _can_be_hit(source: Node = null) -> bool:
	if source == null:
		return true
	if _is_full_draw_piercing(source):
		return true

	var body := source as CharacterBody2D
	var v := body.velocity if body != null else Vector2.ZERO

	# A steeply descending arrow drops over the top of the shield.
	if v.y > absf(v.x) and v.y > 1.0:
		return true

	# Block shots traveling into the shielded front. Use velocity
	# so fast arrows that tunnel past center still count as front hits.
	if not is_zero_approx(v.x) and signf(v.x) == float(-facing):
		return false
	return true


## Shield hits always stop the arrow. A full-draw piercing shot can still
## damage through the front via _can_be_hit, but that exhausts all pierces.
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
	GameMode.play_sound("shield_block", global_position)


func _is_full_draw_piercing(source: Node) -> bool:
	var arrow := source as Arrow
	return arrow != null and arrow.arrow_type == Arrow.Type.PIERCING and arrow.full_draw
