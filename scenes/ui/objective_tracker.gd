extends PanelContainer
## Top-right objective panel. Body text tracks GameMode state; size hugs content.


const MARGIN := 16.0

@onready var _body: RichTextLabel = $Margin/VBox/Body

var _last_text := ""
var _override_text := ""
var _use_override := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	$AnimationPlayer.play("fade_in")


func set_objective(text: String) -> void:
	_use_override = true
	_override_text = text


## Resume following GameMode-derived text.
func clear_objective() -> void:
	_use_override = false
	_override_text = ""


func _process(_delta: float) -> void:
	var next := ""
	var show := true
	var state = GameMode.get_state()
	match state:
		GameMode.MainMenu, GameMode.Victory, GameMode.Defeat:
			show = false
			_use_override = false
			_override_text = ""
		GameMode.AlarmRaised:
			next = "The alarm has been raised. Escape!"
		GameMode.Escape:
			next = "The count is down. Escape!"
		_:
			if _use_override:
				next = _override_text
			else:
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
