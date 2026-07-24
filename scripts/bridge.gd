@tool
class_name Bridge
extends Toggleable
## Drawbridge built from left / middle / right 16x16 AtlasTextures.
## Place the node at the hinge. Length is controlled by tile_count.
## Activated = lowered. Deactivated = raised (open_angle_degrees).
## Flip scale.x to hinge from the opposite side.


const TILE_SIZE := 16

@export_range(1, 64, 1) var tile_count := 4:
	set(value):
		tile_count = maxi(1, value)
		if is_inside_tree():
			_rebuild()

@export var left_tile: Texture2D = preload("res://assets/sprites/drawbridge_left.tres"):
	set(value):
		left_tile = value
		if is_inside_tree():
			_rebuild()

@export var middle_tile: Texture2D = preload("res://assets/sprites/drawbridge_middle.tres"):
	set(value):
		middle_tile = value
		if is_inside_tree():
			_rebuild()

@export var right_tile: Texture2D = preload("res://assets/sprites/drawbridge_right.tres"):
	set(value):
		right_tile = value
		if is_inside_tree():
			_rebuild()

@export var animation_duration := 0.55
@export var open_angle_degrees := -90.0

var _tween: Tween
var _initialized := false

@onready var _body: AnimatableBody2D = $Body
@onready var _collision: CollisionShape2D = $Body/CollisionShape2D
@onready var _visuals: Node2D = $Body/Visuals


func _ready() -> void:
	_rebuild()
	super._ready()
	_initialized = true


func _on_activation_changed(active: bool) -> void:
	var target := 0.0 if active else deg_to_rad(open_angle_degrees)
	# Ensure the bridge is at the correct position when the game starts and in editor
	if not _initialized or Engine.is_editor_hint():
		_body.rotation = target
		return

	# cancel any existing animation
	if _tween:
		_tween.kill()
	# create a new tween
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# tween the bridge to the target rotation
	_tween.tween_property(_body, "rotation", target, animation_duration)


# Rebuild the bridge visuals and collisions. Needed because the tile count and textures can change.
func _rebuild() -> void:
	if _visuals == null or _collision == null:
		return
	if left_tile == null or middle_tile == null or right_tile == null:
		return

	var total_width := float(TILE_SIZE * tile_count)

	while _visuals.get_child_count() > 0:
		var child := _visuals.get_child(0)
		_visuals.remove_child(child)
		child.free()

	for i in tile_count:
		var sprite := Sprite2D.new()
		sprite.texture = _tile_for_index(i)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.position = Vector2(TILE_SIZE * i, -TILE_SIZE * 0.5)
		_visuals.add_child(sprite)

	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision.shape = shape
	shape.size = Vector2(total_width, TILE_SIZE)
	_collision.position = Vector2(total_width * 0.5, 0.0)


func _tile_for_index(index: int) -> Texture2D:
	if tile_count == 1 or index == 0:
		return left_tile
	if index == tile_count - 1:
		return right_tile
	return middle_tile
