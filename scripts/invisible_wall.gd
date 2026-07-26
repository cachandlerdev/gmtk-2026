@tool
extends StaticBody2D
## Invisible solid barrier on the character_barrier layer. Blocks the player
## and enemies only — projectiles pass through. Place and resize the
## CollisionShape2D in a level. Drawn faintly in the editor; invisible at runtime.


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or cs.shape == null or not cs.visible or cs.disabled:
		return
	var rect_shape := cs.shape as RectangleShape2D
	if rect_shape == null:
		return
	var size := rect_shape.size
	var rect := Rect2(cs.position - size * 0.5, size)
	draw_rect(rect, Color(0.3, 0.75, 1.0, 0.2))
	draw_rect(rect, Color(0.3, 0.75, 1.0, 0.7), false, 1.0)
