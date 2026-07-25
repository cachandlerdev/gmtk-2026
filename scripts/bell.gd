class_name Bell
extends Node2D
## Two-state lever. Flipped by nearby player interact or by a projectile hit.
## Wire targets in the inspector (NodePaths to Toggleable / any set_activated node).


signal toggled(is_on: bool)

@export var starts_on := false
@export var one_shot := false
@export var targets: Array[NodePath] = []

var is_on := false

var _locked := false

@onready var _sprite: Sprite2D = $Visual


func _ready() -> void:
	is_on = starts_on
	_update_visual()
	_apply_to_targets()


## Flip the switch. Call from interact, arrows, or other gameplay elements.
func activate() -> void:
	if _locked:
		return
	is_on = not is_on
	if one_shot:
		_locked = true
	print("rang bell")
	toggled.emit(is_on)
	_update_visual()
	_apply_to_targets()
	GameMode.set_state(GameMode.AlarmRaised)


func _apply_to_targets() -> void:
	for path in targets:
		var node := get_node_or_null(path)
		if node and node.has_method("set_activated"):
			node.set_activated(is_on)


func _update_visual() -> void:
	if _sprite:
		_sprite.frame = 1 if is_on else 0


func _on_interact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body is WatchmanEnemy and body.is_alerted:
		activate()
