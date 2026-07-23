class_name Pushable
extends CharacterBody2D
## Box the player can shove horizontally. Stand on it for extra jump height,
## or push it to open / close pathways.


const GRAVITY_FACTOR := 2.0

@export var max_push_speed := 180.0
@export var friction := 1400.0

var _pushed_this_frame := false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta * GRAVITY_FACTOR
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if not _pushed_this_frame:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	_pushed_this_frame = false

	move_and_slide()


## Called by the player when walking into this box from the side.
func apply_push(direction: float) -> void:
	velocity.x = direction * max_push_speed
	_pushed_this_frame = true
