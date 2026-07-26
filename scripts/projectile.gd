class_name Projectile
extends Area2D
## Simple hazard bolt. Moves in a fixed direction until it hits a body or times out.


@export var speed := 420.0
@export var lifetime := 4.0

var direction := Vector2.RIGHT

var _spent := false


func _ready() -> void:
	add_to_group("projectile")
	rotation = direction.angle()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	# Ignore the thrower that spawned it.
	if body.is_in_group("projectile_thrower"):
		return
	_spent = true
	if body.has_method("take_hit"):
		body.take_hit(self)
	GameMode.play_sound("arrow_hit", global_position)
	queue_free()
