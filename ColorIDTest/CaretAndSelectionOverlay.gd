class_name CaretAndSelectionOverlay
extends Control

@export var visible_label: RichTextLabel
@export var mask_label: RichTextLabel
@export var hit_test_viewport: HitTestViewport

var text_buffer: TextBuffer

# Caret and Selection state
var caret_index: int = 0
var selection_anchor: int = -1
var preferred_x: float = -1.0

var _is_dragging: bool = false


func _ready() -> void:
	focus_mode = FOCUS_ALL


func setup(buffer: TextBuffer) -> void:
	text_buffer = buffer
	_update_mask_text()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			var idx: int = hit_test_viewport.get_plain_index_at_position(event.position)
			if idx != -1:
				preferred_x = event.position.x
				set_caret_index(idx)
				if event.shift_pressed and selection_anchor == -1:
					selection_anchor = caret_index
				elif not event.shift_pressed:
					selection_anchor = -1
				_is_dragging = true
		else:
			_is_dragging = false
			_update_mask_text()

	elif event is InputEventMouseMotion and _is_dragging:
		var idx: int = hit_test_viewport.get_plain_index_at_position(event.position)
		if idx != -1:
			if selection_anchor == -1:
				selection_anchor = caret_index
			set_caret_index(idx)

	elif event is InputEventKey and event.pressed:
		_handle_navigation_keys(event)


func _handle_navigation_keys(event: InputEventKey) -> void:
	# Horizontal Navigation (Left / Right)
	if event.keycode == KEY_LEFT:
		_handle_selection_anchor(event.shift_pressed)
		set_caret_index(max(0, caret_index - 1))
		_reset_preferred_x()
		accept_event()

	elif event.keycode == KEY_RIGHT:
		_handle_selection_anchor(event.shift_pressed)
		set_caret_index(min(text_buffer.plain_text.length(), caret_index + 1))
		_reset_preferred_x()
		accept_event()

	# Vertical Navigation (Up / Down)
	elif event.keycode == KEY_UP:
		_handle_selection_anchor(event.shift_pressed)
		_move_caret_vertical(-1)
		accept_event()

	elif event.keycode == KEY_DOWN:
		_handle_selection_anchor(event.shift_pressed)
		_move_caret_vertical(1)
		accept_event()


func _move_caret_vertical(direction: int) -> void:
	if not hit_test_viewport or not text_buffer:
		return

	var current_info: Dictionary = hit_test_viewport.get_caret_position_from_index(caret_index)
	var current_pos: Vector2 = current_info.position
	var line_height: float = current_info.height

	if preferred_x < 0.0:
		preferred_x = current_pos.x

	var target_y: float = current_pos.y + (line_height * 0.5) + (line_height * direction)
	var sample_pos := Vector2(preferred_x, target_y)

	var target_idx: int = hit_test_viewport.get_plain_index_at_position(sample_pos)
	if target_idx != -1:
		caret_index = target_idx
		_update_mask_text()


func _handle_selection_anchor(shift_pressed: bool) -> void:
	if shift_pressed and selection_anchor == -1:
		selection_anchor = caret_index
	elif not shift_pressed:
		selection_anchor = -1


func _reset_preferred_x() -> void:
	preferred_x = -1.0


func set_caret_index(idx: int) -> void:
	caret_index = clampi(idx, 0, text_buffer.plain_text.length() if text_buffer else 0)
	_update_mask_text()


func get_selection_range() -> Vector2i:
	if selection_anchor == -1 or selection_anchor == caret_index:
		return Vector2i(caret_index, caret_index)
	return Vector2i(min(selection_anchor, caret_index), max(selection_anchor, caret_index))


func has_selection() -> bool:
	var sel := get_selection_range()
	return sel.x != sel.y


func clear_selection() -> void:
	selection_anchor = -1
	_update_mask_text()


func _update_mask_text() -> void:
	if not mask_label or not text_buffer:
		return

	var full_text: String = text_buffer.plain_text
	var sel_range: Vector2i = get_selection_range()
	var start_idx: int = sel_range.x
	var end_idx: int = sel_range.y

	var max_active_index: int = max(end_idx, caret_index)
	var active_text: String = full_text.substr(0, max_active_index)

	var bbcode: String = ""
	var caret_at_start: bool = (selection_anchor != -1 and caret_index < selection_anchor)

	if not has_selection():
		var pre_caret: String = active_text.substr(0, caret_index)
		if not pre_caret.is_empty():
			bbcode += "[color=#000000][bgcolor=#000000]%s[/bgcolor][/color]" % pre_caret

		if has_focus():
			bbcode += "[color=#FFFFFF][bgcolor=#000000]|[/bgcolor][/color]"

	elif caret_at_start:
		var pre_caret: String = active_text.substr(0, start_idx)
		if not pre_caret.is_empty():
			bbcode += "[color=#000000][bgcolor=#000000]%s[/bgcolor][/color]" % pre_caret

		if has_focus():
			bbcode += "[color=#FFFFFF][bgcolor=#000000]|[/bgcolor][/color]"

		var selected_text: String = active_text.substr(start_idx, end_idx - start_idx)
		if not selected_text.is_empty():
			bbcode += "[color=#0000FF][bgcolor=#0000FF]%s[/bgcolor][/color]" % selected_text

	else:
		var pre_sel: String = active_text.substr(0, start_idx)
		if not pre_sel.is_empty():
			bbcode += "[color=#000000][bgcolor=#000000]%s[/bgcolor][/color]" % pre_sel

		var selected_text: String = active_text.substr(start_idx, end_idx - start_idx)
		if not selected_text.is_empty():
			bbcode += "[color=#0000FF][bgcolor=#0000FF]%s[/bgcolor][/color]" % selected_text

		if has_focus():
			bbcode += "[color=#FFFFFF][bgcolor=#000000]|[/bgcolor][/color]"

	mask_label.text = bbcode
