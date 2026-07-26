extends CanvasLayer
## Bottom-center toast messages for player feedback (locked doors, hints, etc.).
## Call MessageFeed.show_message("You need a key") from anywhere.


@export var default_duration: float = 2.5
@export var fade_in_duration: float = 0.15
@export var fade_out_duration: float = 0.35
@export var max_queue: int = 4

@onready var _label: Label = $Margin/Panel/Label
@onready var _panel: PanelContainer = $Margin/Panel
@onready var _margin: MarginContainer = $Margin

var _queue: Array[Dictionary] = []
var _showing := false
var _tween: Tween


func _ready() -> void:
	layer = 50
	_panel.modulate.a = 0.0
	_margin.visible = false


## Show a message. Queues if one is already visible.
func show_message(text: String, duration: float = -1.0) -> void:
	if text.is_empty():
		return
	var hold := default_duration if duration < 0.0 else duration
	if _showing:
		if _queue.size() >= max_queue:
			_queue.pop_front()
		_queue.append({"text": text, "duration": hold})
		return
	_display(text, hold)


func clear() -> void:
	_queue.clear()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_showing = false
	_panel.modulate.a = 0.0
	_margin.visible = false


func _display(text: String, duration: float) -> void:
	_showing = true
	_label.text = text
	_margin.visible = true
	_panel.modulate.a = 0.0

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, fade_in_duration)
	_tween.tween_interval(duration)
	_tween.tween_property(_panel, "modulate:a", 0.0, fade_out_duration)
	_tween.finished.connect(_on_display_finished, CONNECT_ONE_SHOT)


func _on_display_finished() -> void:
	_showing = false
	if _queue.is_empty():
		_margin.visible = false
		return
	var next: Dictionary = _queue.pop_front()
	_display(next["text"], next["duration"])
