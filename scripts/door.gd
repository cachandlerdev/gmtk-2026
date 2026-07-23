class_name Door
extends Toggleable
## Blocks the player when closed. Opens when a linked switch turns on.


@onready var _collision: CollisionShape2D = $Body/CollisionShape2D
@onready var _visual: Polygon2D = $Body/Visual


func _on_activation_changed(active: bool) -> void:
    # Active = open. Inactive = closed.
    _collision.set_deferred("disabled", active)
    _visual.modulate.a = 0.25 if active else 1.0
