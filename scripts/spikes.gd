class_name Spikes
extends Toggleable
## Damages anything with take_hit() while extended. Toggleable so switches can retract them.


@onready var _hurt_area: Area2D = $HurtArea
@onready var _collision: CollisionShape2D = $HurtArea/CollisionShape2D
@onready var _visual: AnimatedSprite2D = $Visual


func _on_activation_changed(active: bool) -> void:
	# Active = spikes up.
	_collision.set_deferred("disabled", not active)
	_visual.visible = active
	_hurt_area.monitoring = active

	var flip = true
	while  true:
		await get_tree().create_timer(1).timeout
		if flip:
			_hurt_area.monitoring = active
			_visual.play("spikes_on")
		else:
			_hurt_area.monitoring = false
			_visual.play("spikes_off")
		flip = not flip


func _on_hurt_area_body_entered(body: Node2D) -> void:
	if not is_activated:
		return
	if body.has_method("take_hit"):
		body.take_hit(self)
