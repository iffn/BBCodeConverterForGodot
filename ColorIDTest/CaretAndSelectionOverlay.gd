class_name CaretAndSelectionOverlay
extends Control

@export var visible_label: RichTextLabel
@export var hit_test_viewport: HitTestViewport

var text_buffer: TextBuffer

# Caret and Selection state
var caret_index: int = 0
var selection_anchor: int = -1
var preferred_x: float = -1.0

# Caret visual parameters
var caret_color: Color = Color.WHITE
var caret_width: float = 2.0
var caret_visible: bool = true
var caret_timer: Timer

# Selection visual parameters
var selection_color: Color = Color(0.2, 0.4, 0.8, 0.4)

var _is_dragging: bool = false


func _ready() -> void:
	focus_mode = FOCUS_ALL
	caret_timer = Timer.new()
	caret_timer.wait_time = 0.5
	caret_timer.timeout.connect(_toggle_caret_visibility)
	add_child(caret_timer)
	caret_timer.start()


func setup(buffer: TextBuffer) -> void:
	text_buffer = buffer


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
			queue_redraw()

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
		caret_visible = true
		caret_timer.start()
		queue_redraw()


func _handle_selection_anchor(shift_pressed: bool) -> void:
	if shift_pressed and selection_anchor == -1:
		selection_anchor = caret_index
	elif not shift_pressed:
		selection_anchor = -1


func _reset_preferred_x() -> void:
	preferred_x = -1.0


func set_caret_index(idx: int) -> void:
	caret_index = clampi(idx, 0, text_buffer.plain_text.length() if text_buffer else 0)
	caret_visible = true
	caret_timer.start()
	queue_redraw()


func get_selection_range() -> Vector2i:
	if selection_anchor == -1 or selection_anchor == caret_index:
		return Vector2i(caret_index, caret_index)
	return Vector2i(min(selection_anchor, caret_index), max(selection_anchor, caret_index))


func has_selection() -> bool:
	var sel := get_selection_range()
	return sel.x != sel.y


func clear_selection() -> void:
	selection_anchor = -1
	queue_redraw()


func _draw() -> void:
	if not hit_test_viewport or not text_buffer:
		return

	# Draw Selection Rectangles
	var sel := get_selection_range()
	if sel.x != sel.y:
		for i in range(sel.x, sel.y):
			var bounds: Rect2 = hit_test_viewport.get_character_bounds(i)
			if bounds.size != Vector2.ZERO:
				draw_rect(bounds, selection_color, true)

	# Draw Caret Line
	if caret_visible and has_focus():
		var caret_info: Dictionary = hit_test_viewport.get_caret_position_from_index(caret_index, preferred_x)
		var pos: Vector2 = caret_info.position
		var height: float = caret_info.height
		draw_line(pos, pos + Vector2(0, height), caret_color, caret_width)


func _toggle_caret_visibility() -> void:
	caret_visible = !caret_visible
	queue_redraw()
