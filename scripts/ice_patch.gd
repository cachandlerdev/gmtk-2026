extends SlidingSurface
## Small temporary ice patch left by an ice arrow.


@export var lifetime: float = 8.0


func _ready() -> void:
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(queue_free)
