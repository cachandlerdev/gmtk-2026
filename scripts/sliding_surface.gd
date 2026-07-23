class_name SlidingSurface
extends StaticBody2D
## Icy ground: weak steering and low friction so characters keep sliding.


@export var speed_factor := 1.0
@export var acceleration_factor := 0.12
@export var friction_factor := 0.08


func get_surface_modifiers() -> SurfaceModifiers:
	var mods := SurfaceModifiers.new()
	mods.speed_factor = speed_factor
	mods.acceleration_factor = acceleration_factor
	mods.friction_factor = friction_factor
	return mods
