class_name ArrowPickup
extends PickupBase
## World arrow ammo the player can walk over to collect. Place in levels or drop from enemies.
## Change `arrow_type` in the inspector (or use a typed preset scene) for each ammo kind.


@export var arrow_type: Arrow.Type = Arrow.Type.BASIC:
	set(value):
		arrow_type = value
		_update_visual()

@export var amount: int = 1

@export_group("Sprites")
@export var basic_texture: Texture2D
@export var piercing_texture: Texture2D
@export var bouncing_texture: Texture2D
@export var fire_texture: Texture2D
@export var ice_texture: Texture2D

@onready var _sprite: Sprite2D = $Visual


func _ready() -> void:
	super._ready()
	_update_visual()


## Add arrows to the player and despawn. Stays if that inventory slot is full.
func try_loot(player: Node) -> bool:
	if player == null or amount <= 0:
		return false
	if not player.has_method("try_add_arrow"):
		return false
	if not player.try_add_arrow(arrow_type, amount):
		return false
	GameMode.play_sound("arrow_collect", global_position)
	queue_free()
	return true


func _update_visual() -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Visual") as Sprite2D
	if _sprite == null:
		return
	var texture := _texture_for(arrow_type)
	if texture != null:
		_sprite.texture = texture


func _texture_for(type: Arrow.Type) -> Texture2D:
	match type:
		Arrow.Type.BASIC:
			return basic_texture
		Arrow.Type.PIERCING:
			return piercing_texture
		Arrow.Type.BOUNCING:
			return bouncing_texture
		Arrow.Type.FIRE:
			return fire_texture
		Arrow.Type.ICE:
			return ice_texture
	return basic_texture
