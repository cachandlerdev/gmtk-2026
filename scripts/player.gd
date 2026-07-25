extends CharacterBody2D

signal health_changed(current_hearts: int, max_hearts: int)
signal died
signal arrow_inventory_changed

@export_group("Movement")
## Controls movement speed
@export var SPEED: float = 500.0
## Controls jump strength. The smaller the number, the higher the player jumps.
@export var JUMP_VELOCITY: float = -650.0
## Custom gravity multiplier to improve player movement
@export var GRAVITY_FACTOR: float = 2
## How much faster the player moves while dashing. Separate for air or else op.
@export var GROUND_DASH_FACTOR: float = 2.5
@export var AIR_DASH_FACTOR: float = 2.0
## The impact of inertia. The higher this value, the more control the player has
@export var INERTIA_FACTOR: float = 2000
## How much faster the player moves while performing a melee attack.
@export var MELEE_THRUST_VELOCITY: float = 1.2
## How much the player gets launched vertically performing a melee attack.
@export var MELEE_JUMP_AMOUNT: float = 3500
## How many air jumps the player gets
@export var MAX_NUM_OF_AIR_JUMPS: int = 1
## How much gravity gets applied while hover aiming.
@export var HOVER_AIM_GRAVITY_FACTOR: float = 0.25

@export_group("Combat")
## How long knockback lasts when taking damage
@export var KNOCKBACK_DURATION: float = 0.15
## How much damage melee does
@export var MELEE_DAMAGE: int = 2
## How much of an effect knockback has
@export var KNOCKBACK_FACTOR: float = 0.1

@export_group("Arrows")
@export var starting_basic_arrows: int = 5
@export var starting_piercing_arrows: int = 3
@export var starting_bouncing_arrows: int = 3

# if needed. Coyote time not implemented right now
const COYOTE_FRAMES: int = 6
const MAX_HEARTS: int = 3
const LOW_HEALTH_THRESHOLD: int = 1

## World Y past which the player is considered out of bounds (falling).
@export var fall_death_y: float = 500.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var temp_sprite = $TempSprite

@onready var dash_duration_timer = $Timers/DashDurationTimer
@onready var dash_cooldown_timer = $Timers/DashCooldownTimer
@onready var melee_duration_timer = $Timers/MeleeDurationTimer
@onready var melee_cooldown_timer = $Timers/MeleeCooldownTimer
@onready var wall_jump_timer = $Timers/WallJumpTimer
@onready var hover_aim_duration_timer = $Timers/HoverAimDurationTimer
@onready var hover_aim_cooldown_timer = $Timers/HoverAimCooldownTimer
@onready var invulnerability_timer = $Timers/InvulnerabilityTimer

@onready var left_wall_ray_cast = $LeftWallRayCast
@onready var right_wall_ray_cast = $RightWallRayCast
@onready var left_attack_ray_cast = $LeftAttackRayCast # melee
@onready var right_attack_ray_cast = $RightAttackRayCast # melee

@onready var interact_range: Area2D = $InteractRange
@onready var hearts_hud = $HeartsHUD
@onready var arrows_hud = $ArrowsHUD
@onready var bow = $Bow

# Controls whether the character can dash again
var _is_dashing: bool = false
var _can_dash: bool = true

# Keeps track of the jump count for double jumps
var _num_of_jumps: int = MAX_NUM_OF_AIR_JUMPS

# The direction the player is currently moving in
var _direction: float = 1.0
# Keeps track of the looking direction. always 1 or -1, never 0
var _looking_direction: float = 1.0

# Used to temporarily disable directional movement when wall jumping
var _is_wall_jumping: bool = false

# Handles melee attacks
var _is_melee_attacking: bool = false
var _can_melee_attack: bool = true

# Needed to prevent aiming direction from forcibly moving the character
var _player_wants_to_move: bool = false
var _is_aiming: bool = false
# Handles temporary hovering while aiming to shot
var _is_hover_aiming: bool = false
var _can_hover_aim: bool = true

# Floor surface modifiers (sticky / sliding), refreshed after move_and_slide
var _surface_mods: SurfaceModifiers = SurfaceModifiers.new()

var _hearts: int = MAX_HEARTS
var _is_dead: bool = false

# Tracks knockback effects
var _is_knocked_back: bool = false

var arrow_inventory: ArrowInventory = ArrowInventory.new()


func _ready() -> void:
	# Add the player to the player group
	add_to_group("player")
	_hearts = MAX_HEARTS
	hearts_hud.setup(MAX_HEARTS)
	health_changed.emit(_hearts, MAX_HEARTS)
	_is_dead = false

	arrow_inventory.add(Arrow.Type.BASIC, starting_basic_arrows)
	arrow_inventory.add(Arrow.Type.PIERCING, starting_piercing_arrows)
	arrow_inventory.add(Arrow.Type.BOUNCING, starting_bouncing_arrows)
	arrow_inventory.changed.connect(_on_arrow_inventory_changed)
	bow.inventory = arrow_inventory
	if arrows_hud != null and arrows_hud.has_method("setup"):
		arrows_hud.setup(arrow_inventory)
	arrow_inventory_changed.emit()
	# Bow updates first so hover can read the current draw state this frame.
	bow.process_physics_priority = -100
	if not bow.arrow_fired.is_connected(_on_bow_arrow_fired):
		bow.arrow_fired.connect(_on_bow_arrow_fired)


func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Take care of gravity
	if should_we_apply_gravity():
		if _is_hover_aiming:
			# Soft hover: kill upward momentum, fall much slower than normal.
			if velocity.y < 0.0:
				velocity.y = 0.0
			velocity.y += get_gravity().y * delta * HOVER_AIM_GRAVITY_FACTOR
			velocity.x += get_gravity().x * delta * HOVER_AIM_GRAVITY_FACTOR
		else:
			velocity += get_gravity() * delta * GRAVITY_FACTOR

	_update_player_direction()

	# Handle player inputs
	if Input.is_action_just_pressed("jump") and _num_of_jumps > 0 and not _surface_mods.blocks_jump:
		_jump()
	if Input.is_action_just_pressed("dash") and _can_dash:
		_dash()
	if Input.is_action_just_pressed("melee") and _can_melee_attack:
		melee_attack()
	if Input.is_action_just_pressed("aim") or Input.is_action_just_pressed("shoot"):
		aim()
	if Input.is_action_just_released("aim") or Input.is_action_just_released("shoot"):
		stop_aiming()
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("cycle_arrow_next"):
		cycle_arrow_next()
	if Input.is_action_just_pressed("cycle_arrow_prev"):
		cycle_arrow_prev()

	_auto_loot_arrows()
	_sync_hover_aim_with_bow()
	_update_jump_count()
	_update_player_sprite()
	_update_player_movement(delta)
	_update_floor_surface_modifiers()
	_check_out_of_bounds()


## Handles updating the player's direction. When aiming the bow, this is
## controlled by the mouse. Otherwise we update it based on the movement
## direction as long as the player isn't wall jumping or melee attacking.
func _update_player_direction() -> void:
	if _is_aiming:
		_player_wants_to_move = false
		# Must use world space. Viewport mouse coords break once the camera moves.
		var mouse_location := get_global_mouse_position()
		var player_location := global_position
		if player_location.x < mouse_location.x: # aiming right
			_direction = 1.0
			_looking_direction = 1.0
		elif player_location.x > mouse_location.x: #aiming left
			_direction = -1.0
			_looking_direction = -1.0
	elif not _is_wall_jumping or _is_melee_attacking:
		# Get the input direction and handle the movement/deceleration.
		_direction = Input.get_axis("move_left", "move_right")
		if _direction != 0:
			_player_wants_to_move = true
			_looking_direction = _direction
		


## Damageable interface used by spikes, enemies, and projectiles.
func take_hit(source: Node = null) -> void:
	if _is_dead or not invulnerability_timer.is_stopped():
		return

	_hearts = maxi(_hearts - 1, 0)
	var source_name: String = str(source.name) if source else "unknown"
	print("Player hit by %s — hearts left: %d" % [source_name, _hearts])

	health_changed.emit(_hearts, MAX_HEARTS)
	_flash_hurt()
	invulnerability_timer.start()

	if _hearts <= 0:
		die()
	elif _hearts <= LOW_HEALTH_THRESHOLD:
		GameMode.set_state(GameMode.NearDeath)
	
	_is_knocked_back = true
	await get_tree().create_timer(KNOCKBACK_DURATION).timeout
	_is_knocked_back = false


func get_hearts() -> int:
	return _hearts


func get_max_hearts() -> int:
	return MAX_HEARTS


## Instant death (out of bounds, hazards that should kill outright, etc.).
func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit()
	set_physics_process(false)
	GameMode.set_state(GameMode.Defeat)


func _check_out_of_bounds() -> void:
	if global_position.y > fall_death_y:
		die()


func _flash_hurt() -> void:
	var original_modulate: Color = temp_sprite.modulate #store the original state
	temp_sprite.modulate = Color(1.0, 0.35, 0.35) #set the sprite color to reddish
	var tween := create_tween() #create a tween to animate the color back to the original state
	tween.tween_property(temp_sprite, "modulate", original_modulate, 0.2) #animate the color back to the original state


## Activates the nearest interactable currently overlapping the player's interactablerange.
func _try_interact() -> void:
	var nearest_node: Node2D = null
	var nearest_distance_squared := INF
	for area in interact_range.get_overlapping_areas():
		var target := area.get_parent()
		if target == null or not target.has_method("activate"):
			continue
		# Get the nearest interactable to the player
		var distance_squared := global_position.distance_squared_to(target.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_node = target
	if nearest_node:
		nearest_node.activate()


## Pick up every landed arrow in interact range that still fits in inventory.
func _auto_loot_arrows() -> void:
	for area in interact_range.get_overlapping_areas():
		var target := area.get_parent()
		if target is Arrow:
			(target as Arrow).try_loot(self)


## Returns true if at least one arrow of this type was added.
func try_add_arrow(type: int, amount: int = 1) -> bool:
	return arrow_inventory.add(type, amount) > 0


## Return a looted arrow to inventory (clamped to the per-type cap).
func add_arrow(type: Arrow.Type, amount: int = 1) -> void:
	arrow_inventory.add(type, amount)


func cycle_arrow_next() -> void:
	arrow_inventory.cycle_next()


func cycle_arrow_prev() -> void:
	arrow_inventory.cycle_prev()


func _on_arrow_inventory_changed() -> void:
	arrow_inventory_changed.emit()


## Handles updating the player's jump count.
func _update_jump_count() -> void:
	# If you're next to a wall, you can always jump
	if left_wall_ray_cast.is_colliding() or right_wall_ray_cast.is_colliding():
		_num_of_jumps = max(_num_of_jumps, 1)

	# Handle the double jump count
	if is_on_floor():
		_num_of_jumps = MAX_NUM_OF_AIR_JUMPS


## A helper that says whether gravity should be applied
func should_we_apply_gravity() -> bool:
	return not is_on_floor() and not _is_dashing


## Performs a melee attack and launches the player forward slightly
func melee_attack() -> void:
	_is_melee_attacking = true
	_can_melee_attack = false
	melee_duration_timer.start()


## Handles aiming. Hover is synced from the bow draw
## state in `_sync_hover_aim_with_bow` so it works for both aim and shoot inputs.
func aim() -> void:
	if bow._can_shoot and arrow_inventory.has_any():
		_is_aiming = true


## Handles releasing the aim/shoot button.
func stop_aiming() -> void:
	_is_aiming = false
	if _is_hover_aiming:
		_stop_hover_aim()


## Reduced gravity while drawing in the air.
func _hover_aim() -> void:
	_is_hover_aiming = true
	if velocity.y < 0.0:
		velocity.y = 0.0
	# Normal end is full draw / release / fire. If nothing happens the hover aim will time out
	hover_aim_duration_timer.wait_time = bow.max_charge_time + 0.25
	hover_aim_duration_timer.start()


## Stops the hover aiming.
func _stop_hover_aim() -> void:
	if not _is_hover_aiming:
		return
	_is_hover_aiming = false
	if not hover_aim_duration_timer.is_stopped():
		hover_aim_duration_timer.stop()
	hover_aim_cooldown_timer.start()


## Hover while the bow is drawing in the air; stop on full draw, fire, or release.
func _sync_hover_aim_with_bow() -> void:
	var drawing: bool = bow.is_charging() and not bow.is_at_full_draw()
	if drawing and not is_on_floor():
		if not _is_hover_aiming and _can_hover_aim:
			_hover_aim()
			_can_hover_aim = false
	elif _is_hover_aiming:
		# Full draw, released, landed, or no longer charging.
		if is_on_floor() or not bow.is_charging() or bow.is_at_full_draw():
			_stop_hover_aim()


func _on_bow_arrow_fired(_arrow: Node, _charge_ratio: float) -> void:
	if _is_hover_aiming:
		_stop_hover_aim()


## Handles jump related actions like regular jumps and wall jumps.
## This function assumes that the player can jump at this point in time.
func _jump() -> void:
	# We prioritize walljumps
	if left_wall_ray_cast.is_colliding() and not is_on_floor():
		_direction = 1
		_is_wall_jumping = true
		wall_jump_timer.start()

		velocity.y = JUMP_VELOCITY
		velocity.x = JUMP_VELOCITY

	elif right_wall_ray_cast.is_colliding() and not is_on_floor():
		_direction = -1
		_is_wall_jumping = true
		wall_jump_timer.start()

		velocity.y = JUMP_VELOCITY
		velocity.x = _direction * JUMP_VELOCITY
	else:
		# Regular jump
		velocity.y = JUMP_VELOCITY
	_num_of_jumps -= 1


## Update the player sprite. Handles flipping and animations
func _update_player_sprite() -> void:
	# Flip sprite depending on direction
	if _direction > 0:
		temp_sprite.scale.x = 1
		animated_sprite.flip_h = false
	elif _direction < 0:
		temp_sprite.scale.x = -1
		animated_sprite.flip_h = true

	# Animations TODO for when we have the sprites
	#if is_on_floor():
	#	 if direction == 0:
	#		 animated_sprite.play("idle")
	#	 else:
	#		 animated_sprite.play("run")
	#else:
	#	 animated_sprite.play("jump")


## Updates the player's velocity and moves him
func _update_player_movement(delta: float) -> void:
	# Move and account for the dash
	var actual_direction = _direction
	if _is_dashing or _is_melee_attacking:
		# Make the player move when either of these happen
		actual_direction = _looking_direction

	var actual_dash_factor = 1.0
	if _is_dashing and not is_on_floor():
		actual_dash_factor = AIR_DASH_FACTOR
	elif _is_dashing:
		actual_dash_factor = GROUND_DASH_FACTOR
	
	# When melee attacking, you should get launched forward.
	var actual_melee_factor = 1.0
	if _is_melee_attacking:
		actual_melee_factor = MELEE_THRUST_VELOCITY
	
	var actual_knockback_factor = 1.0
	if _is_knocked_back:
		actual_knockback_factor = -1 * KNOCKBACK_FACTOR
	
	
	var target_velocity = 0
	if _player_wants_to_move or _is_melee_attacking or _is_dashing:
		target_velocity = (
			actual_direction * SPEED * actual_dash_factor * actual_melee_factor * _surface_mods.speed_factor * actual_knockback_factor
		)
	
	var use_inertia := (
		(not is_on_floor() and not (_is_wall_jumping or _is_dashing or _is_melee_attacking))
		or (is_on_floor() and _surface_mods.acceleration_factor < 1.0)
	)
	# Add inertia factor so you can't turn on a dime in the air
	if use_inertia:
		var accel := INERTIA_FACTOR * delta
		if is_on_floor():
			accel *= _surface_mods.acceleration_factor
		velocity.x = move_toward(velocity.x, target_velocity, accel)
	else:
		velocity.x = target_velocity
	
	if _is_melee_attacking:
		velocity.y -= MELEE_JUMP_AMOUNT * delta

	move_and_slide()
	_push_colliding_objects() # Maybe we make it so we need to press a button to push objects instead?


## Read sticky / sliding modifiers from the floor we are standing on.
func _update_floor_surface_modifiers() -> void:
	_surface_mods = SurfaceModifiers.from_floor(self)


## Shove any Pushable boxes the player is walking into from the side.
func _push_colliding_objects() -> void:
	if _direction == 0.0:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider == null or not collider.has_method("apply_push"):
			continue
		var normal := collision.get_normal()
		# Side contact only — ignore standing on top or hitting the underside.
		if absf(normal.y) > 0.3:
			continue
		# Must be moving into the object.
		if signf(_direction) != -signf(normal.x):
			continue
		collider.apply_push(_direction)


## Let the player dash forward
func _dash() -> void:
	_can_dash = false
	_is_dashing = true
	dash_duration_timer.start()


## Re-enables the dash when the cooldown is over
func _on_dash_cooldown_timer_timeout() -> void:
	_can_dash = true


## Turns off the dash speed boost after it runs out.
func _on_dash_duration_timer_timeout() -> void:
	_is_dashing = false
	dash_cooldown_timer.start()


## The player can now change directions again
func _on_wall_jump_timer_timeout() -> void:
	_is_wall_jumping = false


## The melee attack has finished
func _on_melee_duration_timer_timeout() -> void:
	_is_melee_attacking = false
	# Now is when it should hit the enemy
	if _looking_direction > 0 and right_attack_ray_cast.is_colliding():
		# probably cleaner with a signal but oh well
		var other = right_attack_ray_cast.get_collider()
		if other is EnemyBase:
			other.take_hit(self, MELEE_DAMAGE)
	elif _looking_direction < 0 and left_attack_ray_cast.is_colliding():
		# probably cleaner with a signal but oh well
		var other = left_attack_ray_cast.get_collider()
		if other is EnemyBase:
			other.take_hit(self, MELEE_DAMAGE)


	melee_cooldown_timer.start()


## The player can melee again
func _on_melee_cooldown_timer_timeout() -> void:
	_can_melee_attack = true


## The player ran out of hover time
func _on_hover_aim_duration_timer_timeout() -> void:
	_stop_hover_aim()


## The player can hover aim again
func _on_hover_aim_cooldown_timer_timeout() -> void:
	_can_hover_aim = true
