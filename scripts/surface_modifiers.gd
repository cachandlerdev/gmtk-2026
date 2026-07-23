class_name SurfaceModifiers
extends RefCounted
## Movement modifiers from the floor under a CharacterBody2D.
## Shared by player, pushables, and future NPCs.


var speed_factor := 1.0
var acceleration_factor := 1.0
var friction_factor := 1.0
var blocks_jump := false


## Read modifiers from whatever the body is standing on after move_and_slide().
static func from_floor(body: CharacterBody2D) -> SurfaceModifiers:
	var mods := SurfaceModifiers.new()
	if body == null or not body.is_on_floor():
		return mods
	var floor_body := get_floor_collider(body)
	if floor_body == null:
		return mods
	if floor_body.has_method("get_surface_modifiers"):
		return floor_body.get_surface_modifiers()
	return mods


## First slide collision whose normal points up (walkable floor).
static func get_floor_collider(body: CharacterBody2D) -> Object:
	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		if collision.get_normal().dot(Vector2.UP) > 0.7:
			return collision.get_collider()
	return null
