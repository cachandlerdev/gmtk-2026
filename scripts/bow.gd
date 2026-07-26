extends Node2D
class_name Bow

signal arrow_fired(arrow: Node, charge_ratio: float)

@export var arrow_scene: PackedScene
@export var active: bool = true
@export var auto_facing: bool = true
# If this is true, we use the player's mouse/stick for input.
@export var is_player: bool = false

@export_group("Power")
@export var min_arrow_speed: float = 400.0
@export var max_arrow_speed: float = 1200.0
@export var max_charge_time: float = 1.0

@export_group("Aim")
@export var aim_speed: float = 2.5          ## radians per second
@export var max_aim_angle: float = 85.0     ## degrees up/down from horizontal
@export var spawn_offset: float = 44.0      ## how far in front the arrow spawns
## Pull the spawn back from a wall/door so the arrow collider starts outside it.
@export var spawn_clearance: float = 12.0
@export var COOLDOWN_TIME: float = 0.33
@export var aim_deadzone: float = 0.25      ## stick deflection required to aim / face

## World physics layer — walls, doors, tilemaps.
const WORLD_COLLISION_MASK := 1

@export_group("Input Actions")
@export var shoot_action: StringName = &"shoot"
@export var aim_up_action: StringName = &"aim_up"
@export var aim_down_action: StringName = &"aim_down"
@export var aim_left_action: StringName = &"aim_left"
@export var aim_right_action: StringName = &"aim_right"
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"

@export_group("Camera")
@export var BOW_RELEASE_SCREEN_SHAKE: float = 0.15

@export_group("Aim Indicator")
@export var aim_indicator_radius: float = 28.0
@export var aim_indicator_max_arc_degrees: float = 105.0
@export var aim_indicator_arc_width: float = 0.8
@export var aim_indicator_triangle_size: float = 7.0
@export var aim_indicator_color_min: Color = Color(0.65, 0.65, 0.65, 0.85)
@export var aim_indicator_color_max: Color = Color(0.9, 0.15, 0.15, 0.9)

## 1 = facing right, -1 = facing left. Set by the host when auto_facing is off.
var facing: int = 1

## Current charge as a 0..1 ratio; handy for HUDs.
var charge_ratio: float = 0.0

## Shared with the player. Null means unlimited ammo (e.g. enemy bows later).
var inventory: ArrowInventory

## True while mouse is the active aim device; false for stick/gamepad.
var using_mouse_aim: bool = true

var _charging: bool = false
var _charge: float = 0.0
var _aim_angle: float = 0.0

var _can_shoot: bool = true

func is_charging() -> bool:
	return _charging


func is_at_full_draw() -> bool:
	return _charging and is_equal_approx(charge_ratio, 1.0)


func _input(event: InputEvent) -> void:
	if not is_player:
		return
	if event is InputEventMouseMotion:
		using_mouse_aim = true
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_X or event.axis == JOY_AXIS_RIGHT_Y:
			if absf(event.axis_value) >= aim_deadzone:
				using_mouse_aim = false
	elif event is InputEventJoypadButton:
		using_mouse_aim = false


func _physics_process(delta: float) -> void:
	if not active:
		return

	if auto_facing:
		_update_facing()

	_handle_bow(delta)
	queue_redraw()


func _update_facing() -> void:
	if is_player and not using_mouse_aim:
		var stick := _get_aim_stick()
		if absf(stick.x) >= aim_deadzone:
			facing = 1 if stick.x > 0.0 else -1
		return

	var mouse_location := get_global_mouse_position()
	var x_diff: float = mouse_location.x - global_position.x
	facing = 1 if x_diff >= 0.0 else -1


func _get_aim_stick() -> Vector2:
	return Vector2(
		Input.get_axis(aim_left_action, aim_right_action),
		Input.get_axis(aim_down_action, aim_up_action)
	)


func _handle_bow(delta: float) -> void:
	if Input.is_action_just_pressed(shoot_action) and _can_shoot and _has_ammo():
		_charging = true
		_charge = 0.0
		charge_ratio = 0.0
		_aim_angle = 0.0

	if _charging:
		_charge = minf(_charge + delta, max_charge_time)

		var limit := deg_to_rad(max_aim_angle)
		if is_player and using_mouse_aim:
			# Absolute aim toward the mouse cursor.
			var mouse_location := get_global_mouse_position()
			var x_diff: float = absf(mouse_location.x - global_position.x)
			var y_diff: float = global_position.y - mouse_location.y
			var target := atan2(y_diff, x_diff)
			var mouse_speed := aim_speed * Settings.mouse_sensitivity
			_aim_angle = clampf(lerp(_aim_angle, target, mouse_speed * delta), -limit, limit)
		elif is_player:
			# Absolute aim from the right stick; hold last angle when stick is neutral.
			var stick := _get_aim_stick()
			if stick.length() >= aim_deadzone:
				if absf(stick.x) >= aim_deadzone:
					facing = 1 if stick.x > 0.0 else -1
				var target := atan2(stick.y, maxf(absf(stick.x), 0.001))
				var stick_speed := aim_speed * Settings.controller_aim_sensitivity
				_aim_angle = clampf(lerp(_aim_angle, target, stick_speed * delta), -limit, limit)
		else:
			# Incremental aim (keyboard / non-player).
			var aim_input := Input.get_axis(aim_down_action, aim_up_action)
			_aim_angle = clampf(_aim_angle + aim_input * aim_speed * delta, -limit, limit)

		charge_ratio = _charge / max_charge_time

	if Input.is_action_just_released(shoot_action) and _charging:
		_fire()
		_charging = false
		charge_ratio = 0.0

func _aim_direction() -> Vector2:
	var f := 1.0 if facing >= 0 else -1.0
	return Vector2(f, 0.0).rotated(-_aim_angle * f)

func _has_ammo() -> bool:
	if inventory == null:
		return true
	if inventory.selected_count() > 0:
		return true
	# Selected type empty — try another type the player still has.
	if inventory.has_any():
		inventory.cycle_next()
		return inventory.selected_count() > 0
	return false

func _fire() -> void:
	if arrow_scene == null:
		push_warning("Bow has no arrow_scene assigned.")
		return
	if not _has_ammo():
		return

	var ratio := _charge / max_charge_time
	var arrow_speed := lerpf(min_arrow_speed, max_arrow_speed, ratio)
	var dir := _aim_direction()
	var fired_type: Arrow.Type = Arrow.Type.BASIC
	if inventory != null:
		fired_type = inventory.selected
		if not inventory.try_consume(fired_type):
			return

	var arrow := arrow_scene.instantiate()
	_projectile_parent().add_child(arrow)
	arrow.global_position = _spawn_position(dir)
	arrow.rotation = dir.angle()
	arrow.velocity = dir * arrow_speed
	# Player shares the world physics layer; don't let the shot bounce off the firer.
	var firer := get_parent()
	if firer is PhysicsBody2D and arrow is PhysicsBody2D:
		arrow.add_collision_exception_with(firer)
	if arrow.has_method("apply_type"):
		arrow.apply_type(fired_type, ratio)
	
	if is_player:
		var player = get_tree().get_first_node_in_group("player")
		player.add_screen_shake(BOW_RELEASE_SCREEN_SHAKE)
	
	GameMode.play_sound("bow_release", global_position)

	arrow_fired.emit(arrow, ratio)
	# Fire cooldown
	_can_shoot = false
	await get_tree().create_timer(COOLDOWN_TIME).timeout
	_can_shoot = true


## Spawn ahead of the bow, but never past world geometry (walls / closed doors).
## Spawning inside a collider lets move_and_collide tunnel through it.
func _spawn_position(dir: Vector2) -> Vector2:
	var from := global_position
	var desired := from + dir * spawn_offset
	var space := get_world_2d().direct_space_state
	if space == null:
		return desired

	var query := PhysicsRayQueryParameters2D.create(from, desired)
	query.collision_mask = WORLD_COLLISION_MASK
	# Bow sits inside the firer's collider (player is on the world layer).
	var firer := get_parent()
	if firer is CollisionObject2D:
		query.exclude = [firer.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return desired

	var safe_dist := maxf(0.0, from.distance_to(hit.position) - spawn_clearance)
	return from + dir * safe_dist


func _projectile_parent() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root

func _draw() -> void:
	if not is_player or not _charging:
		return

	var aim_direction := _aim_direction()
	var pull_strength := charge_ratio
	var indicator_color := aim_indicator_color_min.lerp(aim_indicator_color_max, pull_strength)
	var aim_direction_angle := aim_direction.angle()
	var half_arc_radians := deg_to_rad(aim_indicator_max_arc_degrees * 0.5 * pull_strength)

	# Pull-strength arc, centered on the aim direction (0° → 120°).
	if half_arc_radians > 0.001:
		var arc_point_count := maxi(8, int(ceil(aim_indicator_max_arc_degrees * pull_strength / 3.0)))
		draw_arc(
			Vector2.ZERO,
			aim_indicator_radius,
			aim_direction_angle - half_arc_radians,
			aim_direction_angle + half_arc_radians,
			arc_point_count,
			indicator_color,
			aim_indicator_arc_width,
			true
		)

	# Aim triangle nested into the arc: base on the stroke, tip pointing out.
	var aim_perpendicular := Vector2(-aim_direction.y, aim_direction.x)
	var triangle_half_base := aim_indicator_triangle_size * 0.5
	var half_arc_width := aim_indicator_arc_width * 0.5
	var triangle_base_center := aim_direction * (aim_indicator_radius - half_arc_width)
	var triangle_tip := aim_direction * (aim_indicator_radius + half_arc_width + aim_indicator_triangle_size * 0.55)
	var triangle_base_left := triangle_base_center + aim_perpendicular * triangle_half_base
	var triangle_base_right := triangle_base_center - aim_perpendicular * triangle_half_base
	draw_colored_polygon(
		PackedVector2Array([triangle_tip, triangle_base_left, triangle_base_right]),
		indicator_color
	)
