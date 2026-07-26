class_name ProjectileThrower
extends Toggleable
## Periodically fires a projectile in a fixed direction while activated.


@export var projectile_scene: PackedScene
@export var fire_interval := 1.25
@export var fire_direction := Vector2.RIGHT

@onready var _timer: Timer = $FireTimer
@onready var _muzzle: Marker2D = $Muzzle
@onready var _visual: CanvasItem = $Body/Visual
@onready var _body: StaticBody2D = $Body


func _ready() -> void:
	add_to_group("projectile_thrower")
	_body.add_to_group("projectile_thrower")
	if projectile_scene == null:
		projectile_scene = preload("res://scenes/assets/enemy_arrow.tscn")
	_timer.wait_time = fire_interval
	super._ready()


func _on_activation_changed(active: bool) -> void:
	_visual.modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.45)
	if active:
		if _timer.is_stopped():
			_fire()
			_timer.start()
	else:
		_timer.stop()


func _fire() -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate()

	var direction := (to_global(fire_direction) - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	projectile.direction = direction
	var spawn_pos := _muzzle.global_position
	var parent := get_parent()
	if parent == null:
		parent = self
	# Deferred so the first shot from _ready doesn't hit a busy scene tree.
	parent.add_child.call_deferred(projectile)
	projectile.set_deferred("global_position", spawn_pos)


func _on_fire_timer_timeout() -> void:
	_fire()
