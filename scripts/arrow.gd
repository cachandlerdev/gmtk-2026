extends CharacterBody2D

## A projectile arrow. Flies with an initial velocity, arcs under gravity,
## rotates to face its travel direction, and ricochets off the world a few
## times before coming to rest.
##
## Enemy piercing is set by the bow on fire: partial draws stop on the first
## enemy; a full draw may pass through one enemy (pierces_remaining = 1).
## Exhausting pierces drops the arrow so it falls to the floor instead of
## freezing at the hit point.

@export var fall_gravity: float = 980.0
@export var lifetime: float = 6.0
@export var bounciness: float = 0.7          # fraction of speed kept per bounce
@export var max_bounces: int = 3             # stick after this many ricochets
@export var min_bounce_speed: float = 120.0  # below this after a bounce, stop
## Velocity kept when an arrow drops after its last enemy hit.
@export var drop_speed: float = 0.25

## Extra enemies this arrow can pass through after the first hit. Set by Bow.
var pierces_remaining: int = 0

var _bounces: int = 0
var _stopped: bool = false
## True after the last enemy hit: no longer a projectile, just falling.
var _dropping: bool = false

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
		if _dropping:
			# Stick on first contact with the world after dropping.
			_stop()
		else:
			_ricochet(collision.get_normal())

	if not _stopped:
		rotation = velocity.angle()

## Called by enemies before applying damage. Returns false if this arrow is
## already spent and should not hurt the caller. Consumes a pierce or drops.
## `allow_pierce` is false for shielded enemies that arrows cannot pass through.
func try_hit_enemy(_enemy: Node = null, allow_pierce: bool = true) -> bool:
	if _stopped or _dropping:
		return false
	if allow_pierce and pierces_remaining > 0:
		pierces_remaining -= 1
		return true
	_drop()
	return true

## Leave the projectile group and fall under gravity until hitting the floor.
func _drop() -> void:
	_dropping = true
	remove_from_group("projectile")
	velocity *= drop_speed

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
