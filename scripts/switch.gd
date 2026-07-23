class_name Switch
extends Node2D
## Two-state lever. Flipped by nearby player interact or by a projectile hit.
## Wire targets in the inspector (NodePaths to Toggleable / any set_activated node).


signal toggled(is_on: bool)

@export var starts_on := false
@export var one_shot := false
@export var targets: Array[NodePath] = []

var is_on := false

var _locked := false

@onready var _lever_arm: Node2D = $LeverArm


func _ready() -> void:
    is_on = starts_on
    _update_visual()
    _apply_to_targets()


## Flip the switch. Safe to call from interact, arrows, or other gameplay.
func activate() -> void:
    if _locked:
        return
    is_on = not is_on
    if one_shot:
        _locked = true
    toggled.emit(is_on)
    _update_visual()
    _apply_to_targets()


func _apply_to_targets() -> void:
    for path in targets:
        var node := get_node_or_null(path)
        if node and node.has_method("set_activated"):
            node.set_activated(is_on)


func _update_visual() -> void:
    if _lever_arm:
        _lever_arm.rotation_degrees = 35.0 if is_on else -35.0


func _on_hit_area_body_entered(body: Node2D) -> void:
    if body.is_in_group("projectile"):
        activate()


func _on_hit_area_area_entered(area: Area2D) -> void:
    if area.is_in_group("projectile"):
        activate()
