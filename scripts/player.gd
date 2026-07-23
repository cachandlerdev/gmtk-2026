extends CharacterBody2D


# Controls movement speed
const SPEED = 500.0
const JUMP_VELOCITY = -650.0
# Custom gravity multiplier to improve player movement
const GRAVITY_FACTOR = 2 
# How much faster the player moves while dashing. Separate for air or else op.
const GROUND_DASH_FACTOR = 2.5
const AIR_DASH_FACTOR = 2.0
# The impact of inertia. The higher this value, the more control the player has
const INERTIA_FACTOR = 2000
# How much faster the player moves while performing a melee attack.
const MELEE_THRUST_VELOCITY = 2.3
# How many air jumps the player gets
const MAX_NUM_OF_AIR_JUMPS = 1

const COYOTE_FRAMES = 6

@onready var animated_sprite = $AnimatedSprite2D
@onready var temp_sprite = $TempSprite

@onready var dash_duration_timer = $Timers/DashDurationTimer
@onready var dash_cooldown_timer = $Timers/DashCooldownTimer
@onready var melee_duration_timer = $Timers/MeleeDurationTimer
@onready var melee_cooldown_timer = $Timers/MeleeCooldownTimer
@onready var wall_jump_timer = $Timers/WallJumpTimer
@onready var hover_aim_duration_timer = $Timers/HoverAimDurationTimer
@onready var hover_aim_cooldown_timer = $Timers/HoverAimCooldownTimer

@onready var left_ray_cast = $LeftRayCast
@onready var right_ray_cast = $RightRayCast
@onready var interact_range: Area2D = $InteractRange

# Controls whether the character can dash again
var _is_dashing = false
var _can_dash = true

# Keeps track of the jump count for double jumps
var _num_of_jumps = MAX_NUM_OF_AIR_JUMPS

# The direction the player is currently moving in
var _direction = 0

# Used to temporarily disable directional movement when wall jumping
var _is_wall_jumping = false

# Handles melee attacks
var _is_melee_attacking = false
var _can_melee_attack = true

# Handles temporary hovering while aiming to shot
var _is_hover_aiming = false
var _can_hover_aim = true

# Floor surface modifiers (sticky / sliding), refreshed after move_and_slide
var _surface_mods: SurfaceModifiers = SurfaceModifiers.new()

func _ready() -> void:
	# Add the player to the player group
	add_to_group("player")


func _physics_process(delta: float) -> void: 
	# Take care of gravity
	if should_we_apply_gravity():
		velocity += get_gravity() * delta * GRAVITY_FACTOR
	if _is_hover_aiming:
		velocity.x = 0
		velocity.y = 0

	# Get the input direction and handle the movement/deceleration.
	if not _is_wall_jumping or _is_melee_attacking:
		_direction = Input.get_axis("move_left", "move_right")

	# Handle player inputs
	if Input.is_action_just_pressed("jump") and _num_of_jumps > 0 and not _surface_mods.blocks_jump:
		_jump()
	if Input.is_action_just_pressed("dash") and _can_dash:
		_dash()
	if Input.is_action_just_pressed("melee") and _can_melee_attack:
		melee_attack()
	if Input.is_action_just_pressed("aim"):
		aim()
	if Input.is_action_just_released("aim"): 
		# this might be a release arrow? not sure
		stop_aiming()
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	
	_update_jump_count()
	_update_player_sprite()
	_update_player_movement(delta)
	_update_floor_surface_modifiers()



func take_hit(source: Node = null) -> void:
	var source_name: String = str(source.name) if source else "unknown"
	print("Player hit by %s — damage / death (health not implemented)" % source_name)


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


## Handles updating the player's jump count.
func _update_jump_count() -> void:
	# If you're next to a wall, you can always jump
	if left_ray_cast.is_colliding() or right_ray_cast.is_colliding():
		_num_of_jumps = max(_num_of_jumps, 1)

	# Handle the double jump count
	if is_on_floor():
		_num_of_jumps = MAX_NUM_OF_AIR_JUMPS


## A helper that says whether gravity should be applied
func should_we_apply_gravity() -> bool:
	return not is_on_floor() and not _is_dashing and not _is_hover_aiming


## Performs a melee attack and launches the player forward slightly
func melee_attack() -> void:
	print("melee attack")
	_is_melee_attacking = true
	_can_melee_attack = false
	melee_duration_timer.start()


## Handles aiming to shoot a bow/crossbow/etc. If the player is in the air,
## hover aiming can occur
func aim() -> void:
	print("aim")
	# TODO

	if not is_on_floor() and _can_hover_aim:
		_hover_aim()
		_can_hover_aim = false


## Handles releasing the aim button (right mouse). This probably fires the arrow
func stop_aiming() -> void:
	# TODO: Does this fire the arrow? Not sure b/c depends on bow logic
	if not is_on_floor() and _is_hover_aiming:
		_stop_hover_aim()


## Takes care of hover aiming. Temporarily removes the effects of gravity while
## aiming for a short time.
func _hover_aim() -> void:
	_is_hover_aiming = true
	hover_aim_duration_timer.start()


## Stops the hover aiming.
func _stop_hover_aim() -> void:
	_is_hover_aiming = false
	hover_aim_cooldown_timer.start()


## Handles jump related actions like regular jumps and wall jumps.
## This function assumes that the player can jump at this point in time.
func _jump() -> void:
	# We prioritize walljumps
	if left_ray_cast.is_colliding() and not is_on_floor():
		_direction = 1
		_is_wall_jumping = true
		wall_jump_timer.start()
		print("Wall jump from left to right")

		velocity.y = JUMP_VELOCITY
		velocity.x = JUMP_VELOCITY

	elif right_ray_cast.is_colliding() and not is_on_floor():
		_direction = -1
		_is_wall_jumping = true
		wall_jump_timer.start()
		print("Wall jump from right to left")

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
	var actual_dash_factor = 1.0
	if _is_dashing and not is_on_floor():
		actual_dash_factor = AIR_DASH_FACTOR
	elif _is_dashing:
		actual_dash_factor = GROUND_DASH_FACTOR
	
	var actual_melee_factor = 1.0
	if _is_melee_attacking:
		actual_melee_factor = MELEE_THRUST_VELOCITY
	
	var target_velocity = (
		_direction * SPEED * actual_dash_factor * actual_melee_factor * _surface_mods.speed_factor
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
