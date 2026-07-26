class_name InteractPrompt
extends Node2D
## Bobbing gloves icon shown above an interactable when the player is nearby.


const GLOVES_TEXTURE: Texture2D = preload("res://assets/sprites/gloves_16x16.png")
const FADE_DURATION: float = 0.15

@export var float_amplitude: float = 3.0
@export var float_speed: float = 2.5
@export var height_padding: float = 10.0

var _host: Node2D
var _base_offset: Vector2 = Vector2(0, -24)
var _float_phase: float = 0.0
var _sprite: Sprite2D
var _fade_tween: Tween
var _dismissing: bool = false


func _ready() -> void:
	top_level = true
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_float_phase = randf() * TAU
	modulate.a = 0.0

	_sprite = Sprite2D.new()
	_sprite.texture = GLOVES_TEXTURE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	add_child(_sprite)


func setup(host: Node2D) -> void:
	_host = host
	_base_offset = _compute_offset(host)
	_sync_position()
	_fade_to(1.0)


## Fade out, then free. Safe to call more than once.
func dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	_fade_to(0.0, true)


## Cancel a dismiss and fade back in (e.g. player re-entered range).
func appear() -> void:
	if not _dismissing and modulate.a >= 0.99:
		return
	_dismissing = false
	_fade_to(1.0)


func _process(delta: float) -> void:
	if not is_instance_valid(_host):
		queue_free()
		return
	_float_phase += delta * float_speed
	_sync_position()


func _fade_to(alpha: float, free_when_done: bool = false) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, FADE_DURATION)
	if free_when_done:
		_fade_tween.tween_callback(queue_free)


func _sync_position() -> void:
	var bob_y := sin(_float_phase) * float_amplitude
	global_position = _host.to_global(_base_offset + Vector2(0, bob_y))


func _compute_offset(host: Node2D) -> Vector2:
	var area := host.get_node_or_null("InteractArea") as Area2D
	if area != null:
		var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape != null:
			var top_local := _shape_top_local(shape_node)
			return top_local + Vector2(0, -height_padding)

	var visual := host.get_node_or_null("Visual") as Node2D
	if visual != null:
		return visual.position + Vector2(0, -height_padding - 16.0)

	return Vector2(0, -24)


func _shape_top_local(shape_node: CollisionShape2D) -> Vector2:
	var shape := shape_node.shape
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		return shape_node.position + Vector2(0, -rect.size.y * 0.5)
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return shape_node.position + Vector2(0, -circle.radius)
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return shape_node.position + Vector2(0, -capsule.height * 0.5 - capsule.radius)
	return shape_node.position
