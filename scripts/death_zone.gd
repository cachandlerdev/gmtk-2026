extends Area2D
## Kill volume for out-of-bounds / pits. Place and resize in a level;
## any body with die() (player, enemies, ...) that enters is killed instantly.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
