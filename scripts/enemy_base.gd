class_name EnemyBase
extends CharacterBody2D
## Base for all enemies. Handles gravity, health, taking hits from the player's
## projectiles, optional contact damage to the player, a hurt flash, facing +
## visual mirroring, and a ledge probe.
##
## Subclasses implement _behaviour() to set horizontal velocity / attacks, and
## may override _can_be_hit() for shields/armor. Expected (optional) child nodes:
##   Visual   (Node2D)   — mirrored on facing, flashed on hit
##   LedgeRay (RayCast2D) — used by has_ground_ahead()
##   Hitbox   (Area2D)    — wire its body_entered to _on_hitbox_body_entered


@export var max_health: int = 1
@export var gravity_factor: float = 1.0
## If true, touching the player calls their take_hit().
@export var contact_damage: bool = true
## How long the enemy stays alerted after losing sight of the player. Only
## matters if the enemy has a VisionCone child.
@export var alert_linger: float = 1.5

var facing: int = 1          ## 1 = right, -1 = left
## True while a VisionCone child sees the player, or recently did (linger).
var is_alerted: bool = false
var _health: int
var _lost_time: float = 0.0

@onready var _visual: Node2D = get_node_or_null("Visual")
@onready var _ledge_ray: RayCast2D = get_node_or_null("LedgeRay")
@onready var _vision: VisionCone = get_node_or_null("VisionCone")


func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	_align_ledge_ray()
	_ready_enemy()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_factor * delta
	_update_perception(delta)
	_behaviour(delta)
	move_and_slide()


# --- Hooks for subclasses -------------------------------------------------

## Called once after the base is ready. Override for setup.
func _ready_enemy() -> void:
	pass

## Called every physics frame. Override to drive movement/attacks by setting
## `velocity`; gravity and move_and_slide are handled by the base.
func _behaviour(_delta: float) -> void:
	pass

## Return false to ignore an incoming hit (shields, armor thresholds, ...).
func _can_be_hit(_source: Node = null) -> bool:
	return true

## Called when a hit is ignored by _can_be_hit() (spark, clang, ...).
func _on_hit_blocked(_source: Node = null) -> void:
	pass

## Called just before the enemy is freed.
func _on_death() -> void:
	print("dead")
	if is_alerted:
		GameMode.remove_watching_guard()
	pass


# --- Damage ---------------------------------------------------------------

## Damageable interface. `source` is the projectile/attacker; may be null.
func take_hit(source: Node = null) -> void:
	if not _can_be_hit(source):
		_on_hit_blocked(source)
		return
	_health -= 1
	_flash()
	if _health <= 0:
		_on_death()
		queue_free()


## Contact/hit area handler. Wire each enemy scene's Hitbox.body_entered here.
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if contact_damage and body.has_method("take_hit"):
			body.take_hit(self)
	elif body.is_in_group("projectile"):
		take_hit(body)


# --- Helpers --------------------------------------------------------------

## Turn to face a horizontal direction (1 or -1), mirroring visuals + ledge ray.
func set_facing(dir: int) -> void:
	if dir == 0 or dir == facing:
		return
	facing = dir
	if _visual != null:
		_visual.scale.x = absf(_visual.scale.x) * facing
	_align_ledge_ray()


## True if there is ground ahead in the facing direction (or no ledge ray set).
func has_ground_ahead() -> bool:
	return _ledge_ray == null or _ledge_ray.is_colliding()


## The player node, or null.
func get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


## True if a vision cone is present and currently sees the player.
func can_see_player() -> bool:
	return _vision != null and _vision.can_see_player


## Update `is_alerted` from the vision cone, keeping it set for `alert_linger`
## seconds after the player slips out of sight. No-op without a VisionCone.
func _update_perception(delta: float) -> void:
	if _vision == null:
		return
	if _vision.can_see_player:
		if not is_alerted:
			GameMode.add_watching_guard()
		is_alerted = true
		_lost_time = 0.0
	elif is_alerted:
		_lost_time += delta
		if _lost_time >= alert_linger:
			if is_alerted:
				GameMode.remove_watching_guard()
			is_alerted = false


## Walk forward at `speed`, turning around at walls and platform edges.
func patrol_step(speed: float) -> void:
	if is_on_floor() and (is_on_wall() or not has_ground_ahead()):
		set_facing(-facing)
	velocity.x = facing * speed


## Face the player and advance at `speed`, stopping at walls and ledges.
func chase_step(speed: float) -> void:
	var player := get_player()
	if player != null:
		set_facing(1 if player.global_position.x >= global_position.x else -1)
	if has_ground_ahead() and not is_on_wall():
		velocity.x = facing * speed
	else:
		velocity.x = 0.0


func _align_ledge_ray() -> void:
	if _ledge_ray != null:
		_ledge_ray.position.x = absf(_ledge_ray.position.x) * facing


func _flash() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.15)
