extends CanvasLayer
## Shows how many keys the player is holding.


@export var key_texture: Texture2D
@export var icon_size: Vector2 = Vector2(28, 28)

@onready var _icon: TextureRect = $Margin/Row/Icon
@onready var _count: Label = $Margin/Row/Count


func _ready() -> void:
	if key_texture != null:
		_icon.texture = key_texture
	_icon.custom_minimum_size = icon_size
	_set_count(0)


func setup(player: Node) -> void:
	if player == null:
		return
	if player.has_signal("key_count_changed"):
		if not player.key_count_changed.is_connected(_on_key_count_changed):
			player.key_count_changed.connect(_on_key_count_changed)
	if "key_count" in player:
		_set_count(player.key_count)


func _on_key_count_changed(count: int) -> void:
	_set_count(count)


func _set_count(count: int) -> void:
	_count.text = str(count)
	visible = count > 0
