extends Area2D
## Level exit zone. Every level has one. It stays inert until the level's
## objective (the Count) is dead — which flips GameMode into the Escape state —
## after which the player reaching this zone completes the level and opens the
## next-level menu (via LevelManager.complete_level).
##
## Polls overlaps each physics frame rather than relying on body_entered alone,
## so it also fires if the player is already standing in the zone the moment the
## escape phase begins.

var _triggered: bool = false


func _ready() -> void:
	add_to_group("exit")


func _physics_process(_delta: float) -> void:
	if _triggered:
		return
	# Only usable during the escape phase (i.e. once the objective is dead).
	if GameMode.get_state() != GameMode.Escape:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_triggered = true
			LevelManager.complete_level()
			return
