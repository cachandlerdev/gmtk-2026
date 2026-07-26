extends PanelContainer
## Top-right objective panel. Body text tracks GameMode state; size hugs content.


const MARGIN := 16.0

@onready var _body: Label = $Margin/VBox/Body

var _last_text := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END


func _process(_delta: float) -> void:
	var next := ""
	var show := true
	match GameMode.get_state():
		GameMode.MainMenu, GameMode.Victory, GameMode.Defeat:
			show = false
		GameMode.AlarmRaised:
			next = "The alarm has been raised. Escape!"
		GameMode.Escape:
			next = "The count is down. Escape!"
		_:
			next = "Find the count."

	visible = show
	if not show:
		return
	if next == _last_text:
		return
	_last_text = next
	_body.text = next
	_fit_to_content()


func _fit_to_content() -> void:
	reset_size()
	var min_size := get_combined_minimum_size()
	size = min_size
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_left = -MARGIN - min_size.x
	offset_bottom = MARGIN + min_size.y
