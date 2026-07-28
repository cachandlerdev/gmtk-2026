extends CanvasLayer

@export var basic_texture: Texture2D
@export var piercing_texture: Texture2D
@export var bouncing_texture: Texture2D
@export var lead_icon_size: Vector2 = Vector2(36, 36)
@export var icon_size: Vector2 = Vector2(22, 22)
@export var highlight_color: Color = Color(1, 0.85, 0.35, 1)

@onready var _types: VBoxContainer = $Margin/VBoxContainer/Types
@onready var text: Label = $Margin/VBoxContainer/Label

var _inventory: ArrowInventory
## Arrow.Type -> HBoxContainers holding that type's icons
var _rows: Dictionary = {}
## source Texture2D -> baked outlined ImageTexture (HUD-only copies)
var _outline_cache: Dictionary = {}


func _process(delta: float):
	text.text = _inventory.type_name(_inventory.selected) + " Arrow"


func setup(inventory: ArrowInventory) -> void:
	_inventory = inventory
	if not _inventory.changed.is_connected(_refresh):
		_inventory.changed.connect(_refresh)
	_build_rows()
	_refresh()
	$AnimationPlayer.play("fade_in")


func _build_rows() -> void:
	for child in _types.get_children():
		_types.remove_child(child)
		child.queue_free()
	_rows.clear()

	for type in ArrowInventory.type_order():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Keep every type row flush-left so they line up.
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 2)
		_types.add_child(row)
		_rows[type] = row


func _make_icon(texture: Texture2D, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = size
	icon.size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	return icon


## Keep the original arrow at intended size, the extra outline pixels overflow around it.
func _make_outlined_icon(source: Texture2D, size: Vector2) -> Control:
	var outlined := _outlined_texture_for(source)
	var source_size := source.get_size()
	var outlined_size := outlined.get_size()
	var scale_factor := minf(size.x / source_size.x, size.y / source_size.y)
	var draw_size := outlined_size * scale_factor

	var root := Control.new()
	root.custom_minimum_size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = false

	var icon := _make_icon(outlined, draw_size)
	icon.position = (size - draw_size) * 0.5
	root.add_child(icon)
	return root


## Creates a silhouette outline into a new texture (for HUD-only copies, so world arrows are not affected)
func _outlined_texture_for(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	# Return the cached texture if it exists, so we don't have to bake it again
	if _outline_cache.has(source):
		return _outline_cache[source]

	var source_image := source.get_image()
	if source_image == null:
		return source
	# Duplicate the image to avoid modifying the original
	source_image = source_image.duplicate()
	# RGBA8 is the only format that supports transparency
	if source_image.get_format() != Image.FORMAT_RGBA8:
		source_image.convert(Image.FORMAT_RGBA8)

	var source_width := source_image.get_width()
	var source_height := source_image.get_height()
	# Create a new image 2 pixels larger to serve as the outline and make it transparent
	var outlined_image := Image.create(source_width + 2, source_height + 2, false, Image.FORMAT_RGBA8)
	outlined_image.fill(Color(0, 0, 0, 0))

	# Offset directions
	var directions: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]
	
	# Paint the highlight color in the new image around every opaque pixel corresponding to the source image.
	for y in source_height:
		for x in source_width:
			if source_image.get_pixel(x, y).a < 0.1:
				continue
			for d in directions:
				outlined_image.set_pixel(x + 1 + d.x, y + 1 + d.y, highlight_color)
	# Paint the original art on top of the highlighted outline.
	for y in source_height:
		for x in source_width:
			var color := source_image.get_pixel(x, y)
			if color.a < 0.1:
				continue
			outlined_image.set_pixel(x + 1, y + 1, color)

	var baked := ImageTexture.create_from_image(outlined_image)
	# Cache it to use later
	_outline_cache[source] = baked
	return baked


func _texture_for(type: int) -> Texture2D:
	match type:
		Arrow.Type.BASIC:
			return basic_texture
		Arrow.Type.PIERCING:
			return piercing_texture
		Arrow.Type.BOUNCING:
			return bouncing_texture
	return basic_texture


func _refresh() -> void:
	if _inventory == null:
		return
	if _rows.is_empty():
		_build_rows()

	for type in ArrowInventory.type_order():
		var row: HBoxContainer = _rows[type]
		var amount: int = _inventory.count(type)
		var selected: bool = type == _inventory.selected
		var texture := _texture_for(type)

		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
		for i in amount:
			var is_lead: bool = i == 0
			var size: Vector2 = lead_icon_size if is_lead else icon_size
			if selected and is_lead:
				row.add_child(_make_outlined_icon(texture, size))
			else:
				row.add_child(_make_icon(texture, size))
