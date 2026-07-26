@tool
class_name Door
extends Toggleable
## Blocks the player when closed. Opens either with a key (interact) or via a
## linked switch — pick one with open_mode (never both).
##
## Place the node at the hinge (right edge of the doorway). Flip scale.x to
## hinge from the left instead. Activated = open.


enum OpenMode {
	KEY,    ## Player spends a key on interact. Ignores switches.
	SWITCH, ## Linked switches call set_activated. No key interact.
}

## Sheet layout: frame 0 = closed (edge-on), frame 1 = open (face / doorway).
const FRAME_CLOSED := 0
const FRAME_OPEN := 1

@export var open_mode: OpenMode = OpenMode.KEY:
	set(value):
		open_mode = value
		if is_node_ready():
			_sync_interact_area()

@onready var _collision: CollisionShape2D = $Body/CollisionShape2D
@onready var _sprite: Sprite2D = $Visual
@onready var _interact_collision: CollisionShape2D = $InteractArea/CollisionShape2D

var _initialized := false


func _ready() -> void:
	super._ready()
	_initialized = true
	_sync_interact_area()


## Player interact: unlock with a key (KEY mode), or hint about the switch (SWITCH mode).
func activate() -> void:
	if is_activated:
		return
	if open_mode == OpenMode.SWITCH:
		MessageFeed.show_message("This door opens with a nearby switch.")
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("try_consume_key"):
		return
	if not player.try_consume_key():
		MessageFeed.show_message("You need a key to open this door.")
		return
	# Bypass the switch-only guard in set_activated.
	_force_set_activated(true)


## Switches call this. Key-mode doors ignore it after the initial setup.
func set_activated(active: bool) -> void:
	if open_mode == OpenMode.KEY and _initialized and not Engine.is_editor_hint():
		return
	_force_set_activated(active)


func _force_set_activated(active: bool) -> void:
	is_activated = active
	_on_activation_changed(active)


func _on_activation_changed(active: bool) -> void:
	# Active = open. Inactive = closed.
	if _sprite:
		_sprite.frame = FRAME_OPEN if active else FRAME_CLOSED
	if _collision:
		_collision.set_deferred("disabled", active)
	_sync_interact_area()


func _sync_interact_area() -> void:
	if _interact_collision == null:
		return
	# Interact while closed (key unlock or switch hint); disable once open.
	_interact_collision.set_deferred("disabled", is_activated)
