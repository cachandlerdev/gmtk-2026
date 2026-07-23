class_name Toggleable
extends Node2D
## Base for level objects with two states (door, bridge, spikes, etc.).
## Switches call set_activated(is_on).


@export var starts_activated := false

var is_activated := false


func _ready() -> void:
    set_activated(starts_activated)


## Apply the on/off state. Override in subclasses.
func set_activated(active: bool) -> void:
    is_activated = active
    _on_activation_changed(active)


func _on_activation_changed(_active: bool) -> void:
    pass
