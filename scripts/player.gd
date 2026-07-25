extends CharacterBody2D

signal health_changed(current_hearts: int, max_hearts: int)
signal died
signal arrow_inventory_changed
signal key_count_changed(count: int)

@export_group("Movement")
## Controls movement speed
@export var SPEED: float = 300
## Controls jump strength. The smaller the number, the higher the player jumps.
@export var JUMP_VELOCITY: float = -550.0
## Custom gravity multiplier to improve player movement
@export var GRAVITY_FACTOR: float = 2
## How much faster the player moves while dashing. Separate for air or else op.
@export var GROUND_DASH_FACTOR: float = 2.5
@export var AIR_DASH_FACTOR: float = 2.0
## The impact of inertia. The higher this value, the more control the player has
@export var INERTIA_FACTOR: float = 2000
## How much faster the player moves while performing a melee attack.
@export var MELEE_THRUST_VELOCITY: float = 1.15
## How much the player gets launched vertically performing a melee attack.
@export var MELEE_JUMP_AMOUNT: float = 3500
## How fast the player dives downwards for a dive attack
@export var DIVE_FACTOR: float = 8
## How many air jumps the player gets
@export var MAX_NUM_OF_AIR_JUMPS: int = 1
## How much gravity gets applied while hover aiming.
@export var HOVER_AIM_GRAVITY_FACTOR: float = 0.25

@export_group("Combat")
## How long knockback lasts when taking damage
@export var KNOCKBACK_DURATION: float = 0.15
## How much damage melee does
@export var MELEE_DAMAGE: int = 2
## How much damage dive attacks do
@export var DIVE_MELEE_DAMAGE: int = 4
## How much gravity gets applied while hovering before a dive
@export var DIVE_HOVER_GRAVITY_FACTOR: float = 0.3
## How long you can't move after diving
@export var DIVE_COOLDOWN: float = 1
## How much of an effect knockback has
@export var KNOCKBACK_FACTOR: float = 1


@export_group("Arrows")
@export var starting_basic_arrows: int = 5
@export var starting_piercing_arrows: int = 3
@export var starting_bouncing_arrows: int = 3

# credit to https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html
@export_group("Screen Shake")
@export var MELEE_ATTACK_SCREEN_SHAKE: float = 0.1
@export var DIVE_ATTACK_SCREEN_SHAKE: float = 0.3
@export var DASH_SCREEN_SHAKE: float = 0.2

## How quickly shaking stops [0, 1]
@export var shake_decay: float = 0.8
## Maximum horizontal/vertical shake in pixels
@export var max_shake_offset = Vector2(100, 75)
## Maximum screenshake rotation in radians (use sparingly)
@export var max_roll = 0.1

# Current camera shake strength
var _screen_shake_amount: float = 0.0
# Exponent used for the shake strength. Use [2, 3]
var _shake_power: float = 2

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
@onready var dive_update_timer = $Timers/DiveUpdateTimer
@onready var dive_hover_timer = $Timers/DiveHoverTimer

@onready var collision = $CollisionShape2D
@onready var camera = $Camera2D

@onready var left_wall_ray_cast = $LeftWallRayCast
@onready var right_wall_ray_cast = $RightWallRayCast
@onready var left_attack_ray_cast = $LeftAttackRayCast # melee
@onready var right_attack_ray_cast = $RightAttackRayCast # melee
@onready var dive_collider = $DiveCollider

@onready var interact_range: Area2D = $InteractRange
@onready var hearts_hud = $HeartsHUD
@onready var arrows_hud = $ArrowsHUD
@onready var keys_hud = $KeysHUD
@onready var bow = $Bow

enum {Idle, Jump, WallJump, Melee, Dash, DiveStart, DiveEnd, AimBowDown, AimBowSide, AimBowUp}

# Helps us keep track of the animation state
var _anim_state = Idle

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
var _is_dive_attacking: bool = false
var _is_dive_hovering: bool = false
var _on_dive_cooldown: bool = false

# Needed to prevent aiming direction from forcibly moving the character
var _player_wants_to_move: bool = false
var _is_aiming: bool = false
# A threshold value used for the difference between the mouse and the player 
# position to see if we're aiming sideways
var _aim_side_threshold: float = 100
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
## How many keys the player is currently holding. Uncapped; each unlock consumes one.
var key_count: int = 0


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
	if keys_hud != null and keys_hud.has_method("setup"):
		keys_hud.setup(self)
	key_count_changed.emit(key_count)
	# Bow updates first so hover can read the current draw state this frame.
	bow.process_physics_priority = -100
	if not bow.arrow_fired.is_connected(_on_bow_arrow_fired):
		bow.arrow_fired.connect(_on_bow_arrow_fired)
	
	animated_sprite.play("idle")
	_anim_state = Idle


func _process(delta: float) -> void:
	if _screen_shake_amount:
		_screen_shake_amount = max(_screen_shake_amount - shake_decay * delta, 0)
		_shake()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Take care of gravity
	if should_we_apply_gravity():
		if _is_hover_aiming or _is_dive_hovering:
			var actual_gravity_factor: float = DIVE_HOVER_GRAVITY_FACTOR if _is_dive_hovering else HOVER_AIM_GRAVITY_FACTOR
			# velocity.x += get_gravity().x * delta * actual_gravity_factor
			if velocity.y < 0:
				# Stops the player from flying super high if aiming right after jumping
				velocity.y = 0
			else:
				velocity.y = max(velocity.y + get_gravity().y * delta * actual_gravity_factor, velocity.y)
		else:
			var actual_dive_factor: float = 1
			if _is_dive_attacking:
				actual_dive_factor = DIVE_FACTOR
			velocity += get_gravity() * delta * GRAVITY_FACTOR * actual_dive_factor

	_update_player_direction()

	# Handle player inputs
	if Input.is_action_just_pressed("jump") and _num_of_jumps > 0 and not _surface_mods.blocks_jump:
		_jump()
	if Input.is_action_just_pressed("dash") and _can_dash:
		animated_sprite.play("dash")
		_anim_state = Dash
		_dash()
	if Input.is_action_just_pressed("melee") and _can_melee_attack:
		if is_on_floor():
			melee_attack()
		else:
			start_dive_attack()
	if Input.is_action_just_released("melee") and _is_dive_hovering:
		dive_downwards()
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

	_auto_loot_items()
	_sync_hover_aim_with_bow()
	_update_jump_count()
	_update_player_sprite()
	_update_player_movement(delta)
	_update_floor_surface_modifiers()
	_check_out_of_bounds()


## Add screen shake
func add_screen_shake(amount: float) -> void:
	_screen_shake_amount = min(_screen_shake_amount + amount, 1.0)


## Applies camera shake for this instant
func _shake() -> void:
	var amount = pow(_screen_shake_amount, _shake_power)
	camera.rotation = max_roll * amount * randf_range(-1, 1)
	camera.offset.x = max_shake_offset.x * amount * randf_range(-1, 1)
	camera.offset.y = max_shake_offset.y * amount * randf_range(-1, 1)


## Handles updating the player's direction. When aiming the bow, this follows
## the bow's facing (mouse or right stick). Otherwise we update it based on
## movement as long as the player isn't wall jumping or melee attacking.
func _update_player_direction() -> void:
	if _is_aiming:
		_player_wants_to_move = false
		_direction = float(bow.facing)
		_looking_direction = _direction
	elif not _is_wall_jumping or _is_melee_attacking or _is_dive_hovering or _is_dive_attacking:
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
	collision.disabled = true
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


## Pick up every lootable item in interact range (landed arrows, keys, ...).
func _auto_loot_items() -> void:
	for area in interact_range.get_overlapping_areas():
		var target := area.get_parent()
		if target != null and target.has_method("try_loot"):
			target.try_loot(self)


## Returns true if at least one arrow of this type was added.
func try_add_arrow(type: int, amount: int = 1) -> bool:
	return arrow_inventory.add(type, amount) > 0


## Add keys to the player's inventory.
func add_keys(amount: int = 1) -> void:
	if amount <= 0:
		return
	key_count += amount
	key_count_changed.emit(key_count)


## Spend keys if the player has enough. Returns true when consumed.
func try_consume_key(amount: int = 1) -> bool:
	if amount <= 0 or key_count < amount:
		return false
	key_count -= amount
	key_count_changed.emit(key_count)
	return true


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
	animated_sprite.play("melee_attack")
	_anim_state = Melee
	_is_melee_attacking = true
	_can_melee_attack = false
	melee_duration_timer.start()


## Fly downwards and attack. This starts the attack by hovering the player for a sec
func start_dive_attack() -> void:
	_is_dive_hovering = true
	_direction = 0
	animated_sprite.play("dive_start")
	_anim_state = DiveStart
	dive_hover_timer.start()


## Start the actual dive attack
func dive_downwards() -> void:
	invulnerability_timer.start()
	animated_sprite.play("dive_end")
	_anim_state = DiveEnd
	_is_dive_attacking = true
	_can_melee_attack = false
	dive_update_timer.start()

## Handles aiming to shoot a bow/crossbow/etc. If the player is in the air,
## hover aiming can occur
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
		animated_sprite.play("wall_jump")
		_anim_state = WallJump

	elif right_wall_ray_cast.is_colliding() and not is_on_floor() and right_wall_ray_cast.get_collider() :
		_direction = -1
		_is_wall_jumping = true
		wall_jump_timer.start()

		velocity.y = JUMP_VELOCITY
		velocity.x = _direction * JUMP_VELOCITY
		animated_sprite.play("wall_jump")
		_anim_state = WallJump
	else:
		# Regular jump

		animated_sprite.play("jump")
		_anim_state = Jump
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
	
	if _is_aiming:
		# get mouse y relative to player y
		var mouse_location := get_global_mouse_position()
		var player_location := global_position
		var y_diff: float = player_location.y - mouse_location.y

		print("abs_start")
		print(y_diff)
		print(_aim_side_threshold)
		#if abs(y_diff < _aim_side_threshold):
		#	animated_sprite.play("aim_bow_side")
		#	_anim_state = AimBowSide
		#elif y_diff < 0:
		#	# Mouse above player
		#	animated_sprite.play("aim_bow_up")
		#	_anim_state = AimBowUp
		#else:
		#	animated_sprite.play("aim_bow_down")
		#	_anim_state = AimBowDown
	
	# rip, this is why I should have made a state enum instead of bool flags
	if (not _is_aiming and not _is_dashing and not _is_dead and 
		not _is_dive_attacking and not _is_dive_hovering and 
		not _is_melee_attacking) and not _anim_state == Idle:

		animated_sprite.play("idle")
		_anim_state = Idle



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
	if _on_dive_cooldown:
		velocity = Vector2(0, 0)
		return

	# Move and account for the dash
	var actual_direction = _direction
	if _is_knocked_back:
		actual_direction = _looking_direction
	elif _is_dashing or _is_melee_attacking or _is_dive_attacking:
		# Make the player move when either of these happen
		actual_direction = _looking_direction

	var actual_dash_factor = 1.0
	if _is_dashing and not is_on_floor():
		actual_dash_factor = AIR_DASH_FACTOR
	elif _is_dashing:
		actual_dash_factor = GROUND_DASH_FACTOR
	
	# When melee attacking, you should get launched forward.
	var actual_melee_factor = 1.0
	#if _is_melee_attacking or _is_dive_attacking:
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
	
	if _is_melee_attacking or _is_dive_attacking:
		velocity.y -= MELEE_JUMP_AMOUNT * delta
	
	if _is_dive_hovering or _is_dive_attacking:
		velocity.x = 0
	
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
		var push_collision := get_slide_collision(i)
		var collider := push_collision.get_collider()
		if collider == null or not collider.has_method("apply_push"):
			continue
		var normal := push_collision.get_normal()
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
	add_screen_shake(DASH_SCREEN_SHAKE)


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


## The melee attack has finished. When you dive attack, you hit enemies on both sides of you
func _on_melee_duration_timer_timeout() -> void:
	if _is_dive_attacking:
		var others = dive_collider.get_overlapping_bodies()
		for other in others:
			if other is EnemyBase:
				other.take_hit(self, DIVE_MELEE_DAMAGE)
		add_screen_shake(DIVE_ATTACK_SCREEN_SHAKE)
	else:
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
		add_screen_shake(MELEE_ATTACK_SCREEN_SHAKE)

	_is_melee_attacking = false
	_is_dive_attacking = false

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


## Reevaluates whether the player is still diving, or whether they've hit the 
## ground now
func _on_dive_update_timer_timeout() -> void:
	if is_on_floor():
		_on_melee_duration_timer_timeout()
		_on_dive_cooldown = true
		await get_tree().create_timer(DIVE_COOLDOWN).timeout
		_on_dive_cooldown = false
	else:
		dive_update_timer.start()


## You ran out of time to hover. Start diving
func _on_dive_hover_timer_timeout() -> void:
	_is_dive_hovering = false
	dive_downwards()
