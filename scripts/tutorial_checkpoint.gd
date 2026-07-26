extends Area2D
class_name TutorialCheckpoint

@export_multiline var objective_text: String = ""
@export_multiline var toast_message: String = ""

signal reached(checkpoint: TutorialCheckpoint)

var _triggered := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	body_entered.connect(_on_body_entered)
	# Player may already be inside at spawn — catch that next physics frame.
	call_deferred("_check_initial_overlap")


func _check_initial_overlap() -> void:
	if _triggered:
		return
	for body in get_overlapping_bodies():
		_try_trigger(body)


func _on_body_entered(body: Node2D) -> void:
	_try_trigger(body)


func _try_trigger(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	reached.emit(self)
	_apply()
	# Stop listening so walking back through doesn't re-fire.
	set_deferred("monitoring", false)


func _apply() -> void:
	if objective_text != "":
		var tracker := Hud.get_node_or_null("HUD/ObjectiveTracker")
		if tracker and tracker.has_method("set_objective"):
			tracker.set_objective(objective_text)
	if toast_message != "":
		MessageFeed.show_message(toast_message)
