class_name CountEnemy
extends EnemyBase


func _on_death() -> void:
	super()
	GameMode.set_state(GameMode.Escape)

