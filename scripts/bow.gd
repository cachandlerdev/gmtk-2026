extends Node2D
class_name Bow

signal arrow_fired(arrow: Node, charge_ratio: float)

@export var arrow_scene: PackedScene
@export var active: bool = true
@export var auto_facing: bool = true
# If this is true, we use the player's mouse for input.
@export var is_player: bool = false

@export_group("Power")
@export var min_arrow_speed: float = 400.0
@export var max_arrow_speed: float = 1200.0
@export var max_charge_time: float = 1.0

@export_group("Aim")
@export var aim_speed: float = 2.5          ## radians per second
@export var max_aim_angle: float = 85.0     ## degrees up/down from horizontal
@export var spawn_offset: float = 44.0      ## how far in front the arrow spawns
@export var COOLDOWN_TIME: float = 0.33

@export_group("Input Actions")
@export var shoot_action: StringName = &"shoot"
@export var aim_up_action: StringName = &"aim_up"
@export var aim_down_action: StringName = &"aim_down"
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"

## 1 = facing right, -1 = facing left. Set by the host when auto_facing is off.
var facing: int = 1

## Current charge as a 0..1 ratio; handy for HUDs.
var charge_ratio: float = 0.0

## Shared with the player. Null means unlimited ammo (e.g. enemy bows later).
var inventory: ArrowInventory

var _charging: bool = false
var _charge: float = 0.0
var _aim_angle: float = 0.0

var _can_shoot: bool = true

func is_charging() -> bool:
	return _charging


func is_at_full_draw() -> bool:
	return _charging and is_equal_approx(charge_ratio, 1.0)


func _physics_process(delta: float) -> void:
	if not active:
		return

	if auto_facing:
		# TODO: Figure out how this would work if we have an enemy archer
		var mouse_location := get_global_mouse_position()
		var player_location := global_position
		var x_diff: float = mouse_location.x - player_location.x
		facing = 1 if x_diff >= 0.0 else -1

	_handle_bow(delta)
	queue_redraw()

func _handle_bow(delta: float) -> void:
	if Input.is_action_just_pressed(shoot_action) and _can_shoot and _has_ammo():
		_charging = true
		_charge = 0.0
		charge_ratio = 0.0
		_aim_angle = 0.0

	if _charging:
		_charge = minf(_charge + delta, max_charge_time)

		var aim_input: float = 0.0
		var limit := deg_to_rad(max_aim_angle)
		if is_player:
			# Get angle between mouse cursor and the bow's location
			var mouse_location := get_global_mouse_position()
			var player_location := global_position
			var x_diff: float = abs(mouse_location.x - player_location.x)
			var y_diff: float = player_location.y - mouse_location.y
			aim_input = atan2(y_diff, x_diff)

			var new_aim_angle = lerp(_aim_angle, aim_input, aim_speed * delta)
			_aim_angle = clampf(new_aim_angle, -limit, limit)
		else:
			# TODO: Figure out how this will work if enemies are carrying bows
			aim_input = Input.get_axis(aim_down_action, aim_up_action)
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
	arrow.global_position = global_position + dir * spawn_offset
	arrow.rotation = dir.angle()
	arrow.velocity = dir * arrow_speed
	if arrow.has_method("apply_type"):
		arrow.apply_type(fired_type, ratio)

	arrow_fired.emit(arrow, ratio)
	# Fire cooldown
	_can_shoot = false
	await get_tree().create_timer(COOLDOWN_TIME).timeout
	_can_shoot = true

func _projectile_parent() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root

func _draw() -> void:
	if not _charging:
		return
	var dir := _aim_direction()
	var ratio := _charge / max_charge_time
	var length := lerpf(34.0, 96.0, ratio)
	var col := Color(1.0, 1.0, 1.0, 0.85).lerp(Color(1.0, 0.55, 0.2, 0.95), ratio)
	draw_line(Vector2.ZERO, dir * length, col, 3.0)
	draw_circle(dir * length, 4.0, col)
