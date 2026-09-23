class_name CaretAndSelectionOverlay
extends Control

signal selection_changed(start_index: int, end_index: int)
signal caret_moved(plain_index: int)

@export var visible_label: RichTextLabel
@export var hit_test_viewport: HitTestViewport

var text_buffer: TextBuffer

# Caret and Selection state (measured in plain-text index offsets)
var caret_index: int = 0
var selection_start: int = -1
var selection_end: int = -1

var is_dragging: bool = false
var caret_visible: bool = true
var caret_timer: Timer

const CARET_WIDTH: float = 2.0
const CARET_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)


func _ready() -> void:
	focus_mode = FOCUS_ALL
	mouse_default_cursor_shape = CURSOR_IBEAM
	
	# Setup caret blinking timer
	caret_timer = Timer.new()
	caret_timer.wait_time = 0.53
	caret_timer.autostart = true
	caret_timer.timeout.connect(_on_caret_timer_timeout)
	add_child(caret_timer)


func setup(buffer: TextBuffer) -> void:
	text_buffer = buffer
	text_buffer.text_changed.connect(_on_text_changed)


func _gui_input(event: InputEvent) -> void:
	if not visible_label or not hit_test_viewport or not text_buffer:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				var clicked_idx: int = hit_test_viewport.get_plain_index_at_position(event.position)
				
				if clicked_idx != -1:
					caret_index = clicked_idx
				else:
					caret_index = text_buffer.plain_text.length()
				
				selection_start = caret_index
				selection_end = caret_index
				is_dragging = true
				_reset_caret_blink()
				queue_redraw()
			else:
				is_dragging = false

	elif event is InputEventMouseMotion and is_dragging:
		var hovered_idx: int = hit_test_viewport.get_plain_index_at_position(event.position)
		if hovered_idx != -1:
			caret_index = hovered_idx
			selection_end = caret_index
			_reset_caret_blink()
			queue_redraw()

	elif event is InputEventKey and event.pressed:
		_handle_keyboard_input(event)


func _handle_keyboard_input(event: InputEventKey) -> void:
	var plain_len: int = text_buffer.plain_text.length()
	
	match event.keycode:
		KEY_LEFT:
			if event.shift_pressed:
				if selection_start == -1:
					selection_start = caret_index
				caret_index = max(0, caret_index - 1)
				selection_end = caret_index
			else:
				caret_index = max(0, caret_index - 1)
				_clear_selection()
				
		KEY_RIGHT:
			if event.shift_pressed:
				if selection_start == -1:
					selection_start = caret_index
				caret_index = min(plain_len, caret_index + 1)
				selection_end = caret_index
			else:
				caret_index = min(plain_len, caret_index + 1)
				_clear_selection()
				
		KEY_BACKSPACE:
			if _has_selection():
				_delete_selection()
			elif caret_index > 0:
				text_buffer.delete_plain_range(caret_index - 1, caret_index)
				caret_index -= 1
				
		KEY_DELETE:
			if _has_selection():
				_delete_selection()
			elif caret_index < plain_len:
				text_buffer.delete_plain_range(caret_index, caret_index + 1)
				
		KEY_ENTER:
			if _has_selection():
				_delete_selection()
			text_buffer.insert_text_at_plain_index(caret_index, "\n")
			caret_index += 1
			
		_:
			# Handle printable unicode character typing
			if event.unicode > 31 and event.unicode != 127:
				var typed_char: String = String.chr(event.unicode)
				if _has_selection():
					_delete_selection()
				text_buffer.insert_text_at_plain_index(caret_index, typed_char)
				caret_index += typed_char.length()

	_reset_caret_blink()
	queue_redraw()


func _draw() -> void:
	if not has_focus() or not text_buffer or not visible_label:
		return

	# Draw caret at current plain-text index position
	if caret_visible and caret_index >= 0:
		var caret_pos: Vector2 = _get_caret_screen_position(caret_index)
		var font_height: float = visible_label.get_theme_font_size("normal_font_size")
		draw_line(caret_pos, caret_pos + Vector2(0, font_height), CARET_COLOR, CARET_WIDTH)


## Calculates the exact caret screen position by snapping an initial estimate 
## to the matching character's color bounds in the SubViewport.
func _get_caret_screen_position(idx: int) -> Vector2:
	if not visible_label or not text_buffer or not hit_test_viewport:
		return Vector2.ZERO
		
	var plain_len: int = text_buffer.plain_text.length()
	if plain_len == 0 or idx <= 0:
		return Vector2.ZERO

	# 1. Target the character immediately preceding the caret
	var target_char_idx: int = idx - 1
	if target_char_idx >= text_buffer.plain_text_ids.size():
		return Vector2.ZERO
		
	var target_flat_id: int = text_buffer.plain_text_ids[target_char_idx]
	var target_color: Color = hit_test_viewport._flat_id_to_color(target_flat_id)

	# 2. Estimate initial (x, y) coordinate
	var font = visible_label.get_theme_font("normal_font")
	var font_size = visible_label.get_theme_font_size("normal_font_size")
	if not font:
		font_size = 16
	
	var line_start: int = text_buffer.plain_text.rfind("\n", target_char_idx)
	line_start = 0 if line_start == -1 else line_start + 1
	
	var line_text: String = text_buffer.plain_text.substr(line_start, target_char_idx - line_start + 1)
	var est_x: float = 0.0
	if font:
		est_x = font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	var line_count: int = text_buffer.plain_text.substr(0, idx).count("\n")
	var est_y: float = line_count * (font_size * 1.2) + (font_size * 0.5)

	# 3. Retrieve SubViewport image frame
	var img: Image = hit_test_viewport.get_texture().get_image()
	if not img:
		return Vector2(est_x, line_count * font_size * 1.2)

	var img_size: Vector2i = img.get_size()
	var center_x: int = clampi(int(est_x), 0, img_size.x - 1)
	var center_y: int = clampi(int(est_y), 0, img_size.y - 1)

	# 4. Search local pixel box around estimate (±25px X/Y) for exact color match
	var search_radius: int = 25
	var min_x: int = max(0, center_x - search_radius)
	var max_x: int = min(img_size.x - 1, center_x + search_radius)
	var min_y: int = max(0, center_y - search_radius)
	var max_y: int = min(img_size.y - 1, center_y + search_radius)

	var found_max_x: int = -1
	var found_min_y: int = 99999

	var color_tolerance: float = 0.02

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var sampled: Color = img.get_pixel(x, y)
			if sampled.is_equal_approx(target_color) or _colors_match(sampled, target_color, color_tolerance):
				if x > found_max_x:
					found_max_x = x
				if y < found_min_y:
					found_min_y = y

	# 5. If found, snap caret to rightmost pixel of character + 1px offset
	if found_max_x != -1:
		return Vector2(found_max_x + 1, found_min_y)

	# Fallback to estimate if character wasn't visible in search box
	return Vector2(est_x, line_count * (font_size * 1.2))


## Helper to compare sampled color channels within a tight tolerance
func _colors_match(c1: Color, c2: Color, tol: float) -> bool:
	return abs(c1.r - c2.r) < tol and abs(c1.g - c2.g) < tol and abs(c1.b - c2.b) < tol


func _has_selection() -> bool:
	return selection_start != -1 and selection_end != -1 and selection_start != selection_end


func _clear_selection() -> void:
	selection_start = -1
	selection_end = -1


func _delete_selection() -> void:
	if not _has_selection():
		return
	var start: int = min(selection_start, selection_end)
	var end: int = max(selection_start, selection_end)
	text_buffer.delete_plain_range(start, end)
	caret_index = start
	_clear_selection()


func _reset_caret_blink() -> void:
	caret_visible = true
	if caret_timer:
		caret_timer.start()


func _on_caret_timer_timeout() -> void:
	if has_focus():
		caret_visible = !caret_visible
		queue_redraw()


func _on_text_changed() -> void:
	caret_index = clampi(caret_index, 0, text_buffer.plain_text.length())
	queue_redraw()
