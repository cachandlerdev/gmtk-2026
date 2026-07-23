class_name Bridge
extends Toggleable
## Platform that appears when activated. Hidden / non-colliding when off.


@onready var _collision: CollisionShape2D = $Body/CollisionShape2D
@onready var _visual: Polygon2D = $Body/Visual


func _on_activation_changed(active: bool) -> void:
    _collision.set_deferred("disabled", not active)
    _visual.visible = active
