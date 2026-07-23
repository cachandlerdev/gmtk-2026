extends CharacterBody2D

## A projectile arrow. Flies with an initial velocity, arcs under gravity,
## rotates to face its travel direction, and ricochets off the world a few
## times before coming to rest.

@export var fall_gravity: float = 980.0
@export var lifetime: float = 6.0
@export var bounciness: float = 0.7          # fraction of speed kept per bounce
@export var max_bounces: int = 3             # stick after this many ricochets
@export var min_bounce_speed: float = 120.0  # below this after a bounce, stop

var _bounces: int = 0
var _stopped: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Switches, enemies, and similar listen for this group on body/area enter.
	add_to_group("projectile")
	# Failsafe cleanup for arrows that never come to rest on screen.
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if _stopped:
		return

	velocity.y += fall_gravity * delta

	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_ricochet(collision.get_normal())

	if not _stopped:
		rotation = velocity.angle()

func _ricochet(normal: Vector2) -> void:
	velocity = velocity.bounce(normal) * bounciness
	_bounces += 1
	if _bounces >= max_bounces or velocity.length() < min_bounce_speed:
		_stop()

func _stop() -> void:
	_stopped = true
	velocity = Vector2.ZERO
	# Once at rest the arrow is inert: turn its collider off so it no longer
	# registers as a projectile against enemies, switches, or anything else.
	_collision.set_deferred("disabled", true)
