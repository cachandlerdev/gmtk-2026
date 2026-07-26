class_name PickupBase
extends Node2D
## Shared world-pickup behavior. Bob the Visual sprite in place so interact
## collision stays put while the art gently floats.


@export var float_amplitude: float = 3.0
@export var float_speed: float = 2.5

var _float_phase: float = 0.0
var _visual_base_y: float = 0.0
var _visual: Node2D


func _ready() -> void:
	_visual = get_node_or_null("Visual")
	if _visual != null:
		_visual_base_y = _visual.position.y
	# Randomize to avoid perfectly synchronized bobbing on multiple pickups
	_float_phase = randf() * TAU


func _process(delta: float) -> void:
	if _visual == null:
		return
	_float_phase += delta * float_speed
	_visual.position.y = _visual_base_y + sin(_float_phase) * float_amplitude
