class_name EnemyBase
extends CharacterBody2D
## Base for all enemies. Handles gravity, health, taking hits from the player's
## projectiles, optional contact damage to the player, a hurt flash, facing +
## visual mirroring, and a ledge probe.
##
## Movement/attacks come from a BeehaveTree child when present (ticked manually
## below); subclasses may still override _behaviour() as a fallback, and
## _can_be_hit() / _can_be_pierced() for shields and armor.
## Expected (optional) child nodes:
##   Visual      (Node2D)     — mirrored on facing, flashed on hit
##   LedgeRay    (RayCast2D)  — used by has_ground_ahead()
##   Hitbox      (Area2D)     — wire its body_entered to _on_hitbox_body_entered
##   VisionCone  (VisionCone) — drives is_alerted
##   BeehaveTree (BeehaveTree)— drives behaviour; set to MANUAL process thread


## Graduated awareness of the player: UNAWARE → SUSPICIOUS (detection meter
## filling) → ALERTED (full chase). Drives the behaviour tree.
enum Awareness { UNAWARE, SUSPICIOUS, ALERTED }

@export var max_health: int = 2
@export var gravity_factor: float = 1.0
## If true, merely touching the player damages them. Off by default so the
## telegraphed attack is the real threat; enable per-enemy for spiked/hazard types.
@export var contact_damage: bool = false
## How long the enemy stays fully alerted after losing sight of the player
## before its detection meter starts to drain.
@export var alert_linger: float = 1.5
## Detection meter fill rate per second at point-blank; scales down with range.
@export var detection_fill_rate: float = 3.0
## Detection meter drain rate per second while the player is out of sight.
@export var detection_decay_rate: float = 0.7
## Speeds used by the patrol_step / chase_step helpers the behaviour tree drives.
@export var patrol_speed: float = 115.0
@export var chase_speed: float = 185.0
## Horizontal speed of the brief backward knockback applied when the enemy is hit.
@export var knockback_speed: float = 150.0
## How long that knockback lasts, in seconds.
@export var knockback_time: float = 0.14

@export_group("Attack")
## Horizontal reach (in pixels) at which the enemy stops to swing.
@export var attack_range: float = 44
## Pause before the blow lands — the player's window to strike (or dodge) first.
@export var attack_windup: float = 0.35
## Delay before the enemy may swing again.
@export var attack_cooldown: float = 1.0
## How long the enemy stands still recovering after a swing lands, before it
## resumes chasing/patrolling.
@export var attack_recovery: float = 0.35

@export_group("Loot")
## Scenes to spawn at this enemy's position on death (e.g. key pickups). Assign per-instance in the editor.
@export var loot_drops: Array[PackedScene] = []

var facing: int = 1          ## 1 = right, -1 = left
## Current awareness state (see the Awareness enum).
var awareness: Awareness = Awareness.UNAWARE
## Detection meter, 0..1. Fills while the player is seen, drains otherwise; hits
## 1.0 to become ALERTED.
var detection: float = 0.0
## True only while fully ALERTED. Kept for the tree and GameMode watching count.
var is_alerted: bool = false
## Where the player was last seen — used while investigating.
var last_seen_pos: Vector2 = Vector2.ZERO
var _health: int
var _alert_hold: float = 0.0
var _attack_cooldown_left: float = 0.0
var _attacking: bool = false
var _windup_left: float = 0.0
var _knockback_left: float = 0.0
## Keeps the attack animation on screen briefly through the strike (the attack
## state itself ends the instant the blow lands).
var _anim_lock_left: float = 0.0
## Counts down a stand-still recovery pause after a swing lands.
var _recover_left: float = 0.0

@onready var _visual: Node2D = get_node_or_null("Visual")
@onready var _ledge_ray: RayCast2D = get_node_or_null("LedgeRay")
@onready var _vision: VisionCone = get_node_or_null("VisionCone")
@onready var _tree: BeehaveTree = _find_behaviour_tree()
@onready var _hitbox: Area2D = $Hitbox


func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	_align_ledge_ray()
	_ready_enemy()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_factor * delta
	_update_perception(delta)
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	if _knockback_left > 0.0:
		# Staggered: skip behaviour and let the knockback velocity carry it.
		_knockback_left -= delta
	elif _recover_left > 0.0:
		# Recovery pause after a swing — hold position before resuming behaviour.
		_recover_left -= delta
		velocity.x = 0.0
	elif _tree != null:
		# A BeehaveTree child drives behaviour. It is set to MANUAL so we tick it
		# here — after perception, before move_and_slide.
		_tree.tick()
	else:
		_behaviour(delta)

	move_and_slide()
	_update_animation(delta)


func _exit_tree() -> void:
	if is_alerted:
		GameMode.remove_watching_guard()


func _find_behaviour_tree() -> BeehaveTree:
	for child in get_children():
		if child is BeehaveTree:
			return child
	return null


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

## Return false if arrows should never pass through this enemy (e.g. shields).
func _can_be_pierced(_source: Node = null) -> bool:
	return true

## Called when a hit is ignored by _can_be_hit() (spark, clang, ...).
func _on_hit_blocked(_source: Node = null) -> void:
	pass

## Called just before the enemy is freed.
func _on_death() -> void:
	if is_alerted:
		is_alerted = false
		GameMode.remove_watching_guard()


## Instant death (out of bounds, etc.). 
func die() -> void:
	_on_death()
	_spawn_loot()
	queue_free()


## Instantiate editor-assigned loot scenes at this enemy's feet.
func _spawn_loot() -> void:
	if loot_drops.is_empty():
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	for scene in loot_drops:
		if scene == null:
			continue
		var drop: Node = scene.instantiate()
		parent.add_child(drop)
		if drop is Node2D:
			(drop as Node2D).global_position = global_position


# --- Damage ---------------------------------------------------------------

## Damageable interface. `source` is the projectile/attacker; may be null.
func take_hit(source: Node = null, damage: int = 1) -> void:
	if not _can_be_hit(source):
		_on_hit_blocked(source)
		return
	cancel_attack()          # a hit staggers the enemy, cancelling any wind-up
	_apply_knockback(source)
	_health -= damage
	_flash()
	if _health <= 0:
		die()


## Contact/hit area handler. Wire each enemy scene's Hitbox.body_entered here.
func _on_hitbox_body_entered(body: Node2D) -> void:
	# TODO: This only works when the player first enters the collision box, so 
	# if he sits in the box, he only takes damage once
	if body.is_in_group("player"):
		if contact_damage and body.has_method("take_hit"):
			body.take_hit(self)
	elif body.is_in_group("projectile"):
		# Shield/armor blocks must not consume arrow pierce budget.
		if not _can_be_hit(body):
			_on_hit_blocked(body)
			return
		if body.has_method("try_hit_enemy") and not body.try_hit_enemy(self, _can_be_pierced(body)):
			return
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


## True if a vision cone is present and currently has a clear view of a living
## player.
func can_see_player() -> bool:
	if _vision == null or not _vision.can_see_player:
		return false
	var player := get_player()
	return player != null and not player._is_dead


## Ramp the detection meter up while the player is visible (faster up close) and
## drain it once out of sight, then recompute the awareness state. No-op without
## a VisionCone.
func _update_perception(delta: float) -> void:
	if _vision == null:
		return
	if can_see_player():
		last_seen_pos = get_player().global_position
		detection = minf(1.0, detection + detection_fill_rate * _proximity_factor() * delta)
		_alert_hold = alert_linger
	elif awareness == Awareness.ALERTED and _alert_hold > 0.0:
		_alert_hold -= delta                 # hold full alert briefly after losing sight
	else:
		detection = maxf(0.0, detection - detection_decay_rate * delta)
	_apply_awareness()


## How strongly the player registers: 1.0 at point-blank, down to a floor at the
## edge of the vision cone.
func _proximity_factor() -> float:
	var player := get_player()
	if player == null or _vision == null:
		return 1.0
	var t := clampf(global_position.distance_to(player.global_position) / _vision.view_distance, 0.0, 1.0)
	return lerpf(1.0, 0.35, t)


## Recompute awareness from the detection meter, firing edge hooks. Keeps the
## GameMode watching-guard count tied to full alert.
func _apply_awareness() -> void:
	var next := Awareness.UNAWARE
	if detection >= 1.0:
		next = Awareness.ALERTED
	elif detection > 0.0:
		next = Awareness.SUSPICIOUS
	if next != awareness:
		if next == Awareness.ALERTED:
			GameMode.add_watching_guard()
		elif awareness == Awareness.ALERTED:
			GameMode.remove_watching_guard()
		awareness = next
	is_alerted = awareness == Awareness.ALERTED


## Walk forward at `speed`, turning around at walls and platform edges.
func patrol_step(speed: float) -> void:
	if is_on_floor() and (is_on_wall() or not has_ground_ahead()):
		set_facing(-facing)
	velocity.x = facing * speed


## Suspicious behaviour: hold position and turn to look toward where the player
## was last seen while the detection meter fills (or drains back down).
func investigate_step() -> void:
	velocity.x = 0.0
	if last_seen_pos != Vector2.ZERO:
		set_facing(1 if last_seen_pos.x >= global_position.x else -1)


## Face the player and advance at `speed`, stopping at walls and ledges.
func chase_step(speed: float) -> void:
	var player := get_player()
	if player != null:
		set_facing(1 if player.global_position.x >= global_position.x else -1)
	if has_ground_ahead() and not is_on_wall():
		velocity.x = facing * speed
	else:
		velocity.x = 0.0


# --- Attack ---------------------------------------------------------------

## True if the enemy should swing: the player is within attack_range and the
## cooldown has elapsed. Stays true through a committed wind-up.
func can_attack() -> bool:
	if _attacking:
		return true
	if _attack_cooldown_left > 0.0:
		return false
	var player := get_player()
	if player == null:
		return false
	# Horizontal reach (see _strike) — the enemy pauses this far out to wind up.
	return absf(player.global_position.x - global_position.x) <= attack_range


## Drive one frame of an attack: pause (stationary) for attack_windup, then land
## the blow. Returns true while still winding up, false once the swing resolves.
## The wind-up is the player's window to hit first — a hit cancels it.
func attack_step(delta: float) -> bool:
	velocity.x = 0.0
	if not _attacking:
		_attacking = true
		_windup_left = attack_windup
		var player := get_player()
		if player != null:
			set_facing(1 if player.global_position.x >= global_position.x else -1)
		_on_attack_windup()
	_windup_left -= delta
	if _windup_left > 0.0:
		return true
	_attacking = false
	_attack_cooldown_left = attack_cooldown
	_anim_lock_left = 0.2   # hold the attack animation through the strike frame
	_recover_left = attack_recovery   # stand still briefly after the swing
	_strike()
	return false


## Abandon an in-progress wind-up (the branch switched, or the enemy was hit).
func cancel_attack() -> void:
	_attacking = false


## Land the blow if the player is still in range and in front — stepping away or
## getting behind during the wind-up dodges it.
func _strike() -> void:
	var player := get_player()
	if player == null:
		return
	var to_player := player.global_position - global_position
	# Horizontal reach — the enemy's body-centre origin sits above the player's
	# feet origin, so full distance would over-read.
	if absf(to_player.x) > attack_range:
		return
	if signf(to_player.x) == float(-facing):
		return
	_on_attack()
	if player.has_method("take_hit"):
		player.take_hit(self)


## Brief backward shove when the enemy is hit, pushing away from the hit source.
func _apply_knockback(source: Node) -> void:
	var dir := -float(facing)
	var body := source as CharacterBody2D
	if body != null and absf(body.velocity.x) > 1.0:
		dir = signf(body.velocity.x)                       # player's arrow
	elif source != null and "direction" in source:
		dir = signf(source.direction.x)                    # trap / enemy projectile
	elif source is Node2D:
		var dx := global_position.x - (source as Node2D).global_position.x
		if not is_zero_approx(dx):
			dir = signf(dx)
	if dir == 0.0:
		dir = -float(facing)
	velocity.x = dir * knockback_speed
	_knockback_left = knockback_time


## Wind-up telegraph hook — override for an animation. Defaults to a tint that
## fades as the strike approaches.
func _on_attack_windup() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1.7, 1.4, 0.5)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, attack_windup)


## Strike feedback hook — override for an animation. Defaults to a brief tint.
func _on_attack() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1.6, 0.5, 0.4)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.15)


## Pick the animation on the Visual when it is an AnimatedSprite2D: attack during
## a wind-up (held briefly through the strike), walk while moving on the ground,
## idle otherwise. Missing animations fall back to idle, so a single-frame enemy
## (the Count) just holds its one frame.
func _update_animation(delta: float) -> void:
	var spr := _visual as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return
	_anim_lock_left = maxf(0.0, _anim_lock_left - delta)
	var want := &"idle"
	if _attacking or _anim_lock_left > 0.0:
		want = &"attack"
	elif is_on_floor() and absf(velocity.x) > 5.0:
		want = &"walk"
	if not spr.sprite_frames.has_animation(want):
		want = &"idle"
	if not spr.sprite_frames.has_animation(want):
		return
	# Only (re)start on a change of animation. Looping clips (walk/idle) keep
	# playing; a one-shot attack plays through and holds its last (strike) frame
	# rather than restarting each frame while the attack state lingers.
	if spr.animation != want:
		spr.play(want)


func _align_ledge_ray() -> void:
	if _ledge_ray != null:
		_ledge_ray.position.x = absf(_ledge_ray.position.x) * facing


func _flash() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1.0, 0, 0)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.15)
