class_name VisionCone
extends Node2D
## Reusable line-of-sight perception. Sees the player when they are within
## view_distance, inside the field-of-view arc (centered on the owner's facing),
## and not occluded by the world. Drop it as a child of any node that has a
## `facing` property (e.g. an EnemyBase); it reads that facing automatically.
##
## Poll `can_see_player`, or connect the player_spotted / player_lost signals.

signal player_spotted(player: Node2D)
signal player_lost

@export var view_distance: float = 240.0
@export var fov_degrees: float = 100.0
## Where the "eyes" sit, relative to this node.
@export var eye_offset: Vector2 = Vector2(0, -16)
## Which physics layers block sight (walls). World = 1.
@export_flags_2d_physics var sight_blockers: int = 1
## Per-cone opt-out: if false, this cone never draws even when debug view is on.
@export var show_cone: bool = true

## Global debug toggle shared by every cone. Off by default so cones don't show
## in normal play; flip it with the "toggle_vision" action (F1).
static var globally_visible: bool = false

var facing: int = 1
var can_see_player: bool = false

var _player: Node2D = null
var _detection: float = 0.0   ## mirrored from the owner for the cone tint


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_vision"):
		globally_visible = not globally_visible
		# First cone to handle it flips the shared flag; stop here so the other
		# cones don't toggle it back.
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	# Follow the owner's facing if it exposes one.
	var owner_node := get_parent()
	if owner_node != null and "facing" in owner_node:
		facing = owner_node.facing
	if owner_node != null and "detection" in owner_node:
		_detection = owner_node.detection

	var seen := _check_visible()
	if seen and not can_see_player:
		can_see_player = true
		player_spotted.emit(_player)
	elif not seen and can_see_player:
		can_see_player = false
		player_lost.emit()

	if show_cone:
		queue_redraw()


func _check_visible() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	_player = player

	var eye := global_position + eye_offset
	var target := player.global_position + Vector2(0, -12)   # aim at body, not feet
	var to_player := target - eye
	var dist := to_player.length()
	if dist > view_distance or dist < 1.0:
		return false

	# Inside the field-of-view arc?
	var forward := Vector2(facing, 0)
	if absf(rad_to_deg(forward.angle_to(to_player))) > fov_degrees * 0.5:
		return false

	# Clear line of sight? Cast at the player; a wall hit first means occluded.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(eye, target, sight_blockers)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.get("collider")
	return collider == player or (collider is Node and collider.is_in_group("player"))


func _draw() -> void:
	if not (show_cone and globally_visible):
		return
	var half := deg_to_rad(fov_degrees * 0.5)
	var forward := 0.0 if facing >= 0 else PI
	var points := PackedVector2Array([eye_offset])
	var steps := 14
	for i in range(steps + 1):
		var a := forward - half + (2.0 * half) * (float(i) / float(steps))
		points.append(eye_offset + Vector2(cos(a), sin(a)) * view_distance)
	# Tint ramps with the owner's detection: calm yellow → alert red.
	var col := Color(1.0, 0.9, 0.3, 0.09).lerp(Color(1.0, 0.25, 0.18, 0.20), _detection)
	draw_colored_polygon(points, col)
