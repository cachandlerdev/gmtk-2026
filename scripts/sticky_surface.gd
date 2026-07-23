class_name StickySurface
extends StaticBody2D
## Viscous ground: slows movement and prevents jumping while standing on it.


@export var speed_factor := 0.35
@export var friction_factor := 2.5


func get_surface_modifiers() -> SurfaceModifiers:
	var mods := SurfaceModifiers.new()
	mods.speed_factor = speed_factor
	mods.friction_factor = friction_factor
	mods.blocks_jump = true
	return mods
