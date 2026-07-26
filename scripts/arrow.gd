class_name Arrow
extends CharacterBody2D

## A projectile arrow. Flies with an initial velocity, arcs under gravity,
## rotates to face its travel direction, and ricochets off the world a few
## times before coming to rest. Once stopped it can be looted by walking over it.
##
## Types set pierce / bounce presets via apply_type(). Full draw still grants
## +1 pierce and +1 bounce on top of the type base. Exhausting pierces drops
## the arrow so it falls to the floor instead of freezing at the hit point.

enum Type { BASIC, PIERCING, BOUNCING, FIRE, ICE }

## Art points toward the top-left; offset so the tip follows velocity. +- 135 degrees
const SPRITE_ANGLE_OFFSET := 3.0 * PI / 4.0

@export var fall_gravity: float = 980.0
@export var lifetime: float = 6.0
@export var bounciness: float = 0.7          # fraction of speed kept per bounce
@export var max_bounces: int = 2             # stick after this many ricochets
@export var min_bounce_speed: float = 120.0  # below this after a bounce, stop
## Velocity kept when an arrow drops after its last enemy hit.
@export var drop_speed: float = 0.25
@export var despawn_rate: float = 0.05
# 30% of the time, arrows will despawn after hitting the ground

@export_group("Sprites")
@export var basic_texture: Texture2D
@export var piercing_texture: Texture2D
@export var bouncing_texture: Texture2D
@export var fire_texture: Texture2D
@export var ice_texture: Texture2D

@export_group("Impact Patches")
@export var ice_patch_scene: PackedScene

## Extra enemies this arrow can pass through after the first hit. Set by Bow.
var pierces_remaining: int = 0
## Which inventory slot this arrow returns to when looted.
var arrow_type: Type = Type.BASIC
## True when released at full charge. Used for shield-pierce and similar gates.
var full_draw: bool = false

var _bounces: int = 0
var _stopped: bool = false
## True after the last enemy hit: no longer a projectile, just falling.
var _dropping: bool = false
## Set when the arrow lands so the in-flight failsafe no longer despawns it.
var _cancel_lifetime: bool = false
## Bumped when lifetime is restarted so stale timers don't despawn the arrow
var _lifetime_generation: int = 0
var _spawned_impact: bool = false

var _can_be_picked_up: bool = true

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Visual
@onready var _interact_collision: CollisionShape2D = $InteractArea/CollisionShape2D


func _ready() -> void:
	# Switches, enemies, and similar listen for this group on body/area enter.
	add_to_group("projectile")
	_interact_collision.disabled = true
	_start_lifetime_timer()


## Apply type presets and the charge-based pierce bonus. Call after the arrow
## is in the tree (bow does this right after add_child).
func apply_type(type: Type, charge_ratio: float = 0.0) -> void:
	arrow_type = type
	full_draw = is_equal_approx(charge_ratio, 1.0)
	match type:
		Type.BASIC:
			lifetime = 6.0
			bounciness = 0.7
			max_bounces = 2
			min_bounce_speed = 120.0
			pierces_remaining = 1 if full_draw else 0
			despawn_rate = 0.05
			_set_texture(basic_texture)
		Type.PIERCING:
			lifetime = 6.0
			bounciness = 0.7
			max_bounces = 2
			min_bounce_speed = 120.0
			pierces_remaining = 2 if full_draw else 1
			despawn_rate = 0.02
			_set_texture(piercing_texture)
		Type.BOUNCING:
			lifetime = 10.0
			bounciness = 0.85
			max_bounces = 5
			min_bounce_speed = 80.0
			despawn_rate = 0.01
			pierces_remaining = 1 if full_draw else 0
			_set_texture(bouncing_texture)
		Type.FIRE:
			lifetime = 6.0
			bounciness = 0.0
			max_bounces = 1
			min_bounce_speed = 9999.0
			despawn_rate = 0.03
			pierces_remaining = 1 if full_draw else 0
			_set_texture(fire_texture)
		Type.ICE:
			lifetime = 6.0
			bounciness = 0.0
			max_bounces = 1
			min_bounce_speed = 9999.0
			despawn_rate = 0.03
			pierces_remaining = 1 if full_draw else 0
			_set_texture(ice_texture)
	# Full draw: one extra ricochet on top of the type base.
	if full_draw:
		max_bounces += 1

	_start_lifetime_timer()
	# Point the arrow in the direction of travel
	if velocity.length_squared() > 0.0:
		_face_velocity()


func _set_texture(texture: Texture2D) -> void:
	if _sprite != null and texture != null:
		_sprite.texture = texture


func _creates_impact_surface() -> bool:
	return arrow_type == Type.FIRE or arrow_type == Type.ICE


func _start_lifetime_timer() -> void:
	_lifetime_generation += 1
	var generation := _lifetime_generation
	get_tree().create_timer(lifetime).timeout.connect(
		func() -> void: _on_lifetime_expired(generation)
	)


func _physics_process(delta: float) -> void:
	if _stopped:
		return

	velocity.y += fall_gravity * delta

	var collision := move_and_collide(velocity * delta)
	if collision != null:
		if _creates_impact_surface():
			GameMode.play_sound("arrow_hit", global_position)
			_spawn_impact_surface(collision)
			_stop()
		elif _dropping:
			# Stick on first contact with the world after dropping.
			GameMode.play_sound("arrow_hit", global_position)
			_stop()
		elif _is_tip_collision(collision):
			var break_roll: float = randf()
			if break_roll < despawn_rate:
				GameMode.play_sound("arrow_break", global_position)
				var time_before_despawn = 1
				_can_be_picked_up = false
				$Visual.modulate = Color(0.1, 0.1, 0.1, 1)
				await get_tree().create_timer(time_before_despawn).timeout
				queue_free()
			else:
				_ricochet(collision.get_normal())
		else:
			# Butt/side scrape: deflect without spending a bounce charge.
			velocity = velocity.bounce(collision.get_normal()) * bounciness
			if velocity.length() < min_bounce_speed:
				GameMode.play_sound("arrow_hit", global_position)
				_stop()

	if not _stopped:
		_face_velocity()


## Body faces flight so the collider tip leads; art offset stays on the sprite.
func _face_velocity() -> void:
	rotation = velocity.angle()
	if _sprite != null:
		_sprite.rotation = SPRITE_ANGLE_OFFSET


## True when the contact is on the forward (tip) half of the arrow.
func _is_tip_collision(collision: KinematicCollision2D) -> bool:
	if velocity.length_squared() < 1.0:
		return true
	var forward := velocity.normalized()
	var hit_offset := collision.get_position() - global_position
	return hit_offset.dot(forward) > 0.0 # If the hit offset is in the direction of travel, it's a tip collision


## Called by enemies before applying damage. Returns false if this arrow is
## already spent and should not hurt the caller. Consumes a pierce or drops.
## `allow_pierce` is false for shielded enemies that arrows cannot pass through.
func try_hit_enemy(_enemy: Node = null, allow_pierce: bool = true) -> bool:
	if _stopped or _dropping:
		return false
	if allow_pierce and pierces_remaining > 0:
		pierces_remaining -= 1
		GameMode.play_sound("arrow_hit_flesh")
		return true
	_drop()
	GameMode.play_sound("arrow_hit_flesh")

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
		GameMode.play_sound("arrow_hit", global_position)
		_stop()
	else:
		GameMode.play_sound("arrow_bounce", global_position)

# WIP
func _spawn_impact_surface(collision: KinematicCollision2D) -> void:
	if _spawned_impact:
		return
	var scene: PackedScene = null
	match arrow_type:
		Type.ICE:
			scene = ice_patch_scene
	if scene == null:
		return

	_spawned_impact = true
	var patch: Node2D = scene.instantiate()
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(patch)

	var normal := collision.get_normal()
	var point := collision.get_position()
	# Origin is the contact surface. Sink 1px along the normal so pixel art
	# sits flush instead of leaving a hairline gap.
	patch.global_position = (point - normal).snapped(Vector2.ONE)
	patch.rotation = normal.angle() + PI * 0.5


func _stop() -> void:
	_stopped = true
	_cancel_lifetime = true # Prevent the arrow from being despawned by the lifetime timer
	velocity = Vector2.ZERO
	# Once at rest the arrow is inert: turn its collider off so it no longer
	# registers as a projectile against enemies, switches, or anything else.
	_collision.set_deferred("disabled", true)
	# Become interactable so the player can pick this arrow back up.
	_interact_collision.set_deferred("disabled", false)


# Despawn the arrow if the lifetime timer expires (for arrows that never hit anything - out of bounds)
func _on_lifetime_expired(generation: int) -> void:
	if generation != _lifetime_generation:
		return
	if not _cancel_lifetime and not _stopped:
		queue_free()


## Return this arrow to inventory if there is space. Returns true when looted.
func try_loot(player: Node) -> bool:
	if not _stopped or player == null or not _can_be_picked_up:
		return false
	if not player.has_method("try_add_arrow"):
		return false
	if not player.try_add_arrow(arrow_type):
		return false
	GameMode.play_sound("arrow_collect", global_position)
	queue_free()
	return true
