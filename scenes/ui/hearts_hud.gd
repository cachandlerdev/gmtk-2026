extends CanvasLayer

@export var full_heart: Texture2D
@export var empty_heart: Texture2D
@export var heart_size: Vector2 = Vector2(32, 32)

@onready var _row: HBoxContainer = $Margin/Hearts

var _hearts: Array[TextureRect] = []


func _ready() -> void:
	var player := get_parent()
	if player != null and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)


## Clears and rebuilds the row to match `max_hearts`.
func setup(max_hearts: int) -> void:
	_clear_hearts()
	for i in max_hearts:
		var heart := _make_heart()
		_row.add_child(heart)
		_hearts.append(heart)
	_on_health_changed(max_hearts, max_hearts)


func _clear_hearts() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_hearts.clear()


func _make_heart() -> TextureRect:
	var heart := TextureRect.new()
	heart.custom_minimum_size = heart_size
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.texture = full_heart
	return heart


func _on_health_changed(current_hearts: int, _max_hearts: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = full_heart if i < current_hearts else empty_heart
