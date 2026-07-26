extends Node
## Global player preferences: audio levels and aim sensitivity.
## Registered as an Autoload so values persist across scenes and apply on boot.

const CONFIG_PATH := "user://settings.cfg"

const DEFAULT_MUSIC_VOLUME := 0.75
const DEFAULT_SFX_VOLUME := 0.75
const DEFAULT_MOUSE_SENSITIVITY := 1.0
const DEFAULT_CONTROLLER_AIM_SENSITIVITY := 1.0

var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var controller_aim_sensitivity: float = DEFAULT_CONTROLLER_AIM_SENSITIVITY


func _ready() -> void:
	load_settings()
	apply()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.25, 3.0)
	save_settings()


func set_controller_aim_sensitivity(value: float) -> void:
	controller_aim_sensitivity = clampf(value, 0.25, 3.0)
	save_settings()


func apply() -> void:
	_apply_audio()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "controller_aim_sensitivity", controller_aim_sensitivity)
	config.save(CONFIG_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	music_volume = clampf(float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)), 0.25, 3.0)
	controller_aim_sensitivity = clampf(float(config.get_value("controls", "controller_aim_sensitivity", DEFAULT_CONTROLLER_AIM_SENSITIVITY)), 0.25, 3.0)


func _apply_audio() -> void:
	_set_bus_linear("Music", music_volume)
	_set_bus_linear("SFX", sfx_volume)


func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
