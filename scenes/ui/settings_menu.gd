extends CanvasLayer
## Settings overlay, registered as an Autoload so both the main menu and the
## pause menu can reach it. process_mode is ALWAYS (set in the scene) so it
## keeps running while the tree is paused.

@onready var music_slider: HSlider = $Center/Menu/MusicRow/Slider
@onready var sfx_slider: HSlider = $Center/Menu/SfxRow/Slider
@onready var mouse_slider: HSlider = $Center/Menu/MouseRow/Slider
@onready var controller_slider: HSlider = $Center/Menu/ControllerRow/Slider
@onready var music_value: Label = $Center/Menu/MusicRow/Value
@onready var sfx_value: Label = $Center/Menu/SfxRow/Value
@onready var mouse_value: Label = $Center/Menu/MouseRow/Value
@onready var controller_value: Label = $Center/Menu/ControllerRow/Value
@onready var back_button: Button = $Center/Menu/BackButton

## When true, closing settings re-shows the pause menu instead of just hiding.
var _opened_from_pause: bool = false
var _syncing: bool = false
var _previous_focus: Control


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mouse_slider.value_changed.connect(_on_mouse_changed)
	controller_slider.value_changed.connect(_on_controller_changed)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open(from_pause: bool = false) -> void:
	_opened_from_pause = from_pause
	_previous_focus = get_viewport().gui_get_focus_owner()
	_sync_from_settings()
	visible = true
	music_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	Settings.save_settings()
	visible = false
	if _opened_from_pause:
		_opened_from_pause = false
		PauseMenu.show_from_settings()
	if is_instance_valid(_previous_focus):
		_previous_focus.call_deferred("grab_focus")


func _sync_from_settings() -> void:
	_syncing = true
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	mouse_slider.value = Settings.mouse_sensitivity
	controller_slider.value = Settings.controller_aim_sensitivity
	_update_labels()
	_syncing = false


func _update_labels() -> void:
	music_value.text = _pct(Settings.music_volume)
	sfx_value.text = _pct(Settings.sfx_volume)
	mouse_value.text = "%.2fx" % Settings.mouse_sensitivity
	controller_value.text = "%.2fx" % Settings.controller_aim_sensitivity


func _pct(linear: float) -> String:
	return "%d%%" % int(round(linear * 100.0))


func _on_music_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_music_volume(value)
	_update_labels()


func _on_sfx_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_sfx_volume(value)
	_update_labels()


func _on_mouse_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_mouse_sensitivity(value)
	_update_labels()


func _on_controller_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_controller_aim_sensitivity(value)
	_update_labels()
