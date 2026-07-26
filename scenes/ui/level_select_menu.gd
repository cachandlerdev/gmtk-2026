extends CanvasLayer
## Level-select overlay, registered as an Autoload so the main menu can open it.
## process_mode is ALWAYS (set in the scene) so it keeps running while the tree
## is paused. Buttons are rebuilt from LevelManager each time it opens.

@onready var level_list: VBoxContainer = $Center/Menu/LevelList
@onready var back_button: Button = $Center/Menu/BackButton

var _previous_focus: Control


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	_rebuild_buttons()
	visible = true
	var first := level_list.get_child(0) as Button
	if first:
		first.grab_focus()
	else:
		back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_previous_focus):
		_previous_focus.call_deferred("grab_focus")


func _rebuild_buttons() -> void:
	while level_list.get_child_count() > 0:
		level_list.get_child(0).free()

	for i in LevelManager.levels.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 44)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if i < LevelManager.level_names.size():
			button.text = LevelManager.level_names[i]
		else:
			button.text = "Level %d" % (i + 1)
		var index := i
		button.pressed.connect(func() -> void: _on_level_pressed(index))
		level_list.add_child(button)


func _on_level_pressed(index: int) -> void:
	visible = false
	LevelManager.start_at_level(index)
