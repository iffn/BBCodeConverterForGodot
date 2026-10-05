class_name CaretAndSelectionOverlay
extends Control

signal selection_changed(start_index: int, end_index: int)
signal caret_moved(plain_index: int)

@export var visible_label: RichTextLabel
@export var hit_test_viewport: HitTestViewport

var text_buffer: TextBuffer

var caret_index: int = 0:
	set(value):
		var max_len: int = text_buffer.plain_text.length() if text_buffer else 0
		var clamped_val: int = clampi(value, 0, max_len)
		if caret_index != clamped_val or cached_caret_pos == Vector2.ZERO:
			caret_index = clamped_val
			_update_caret_position()
			caret_moved.emit(caret_index)

var selection_start: int = -1
var selection_end: int = -1
var is_dragging: bool = false
var caret_visible: bool = true
var caret_timer: Timer

var last_known_caret_pos: Vector2 = Vector2.ZERO
var cached_caret_pos: Vector2 = Vector2.ZERO

const CARET_WIDTH: float = 2.0
const CARET_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)


func _ready() -> void:
	focus_mode = FOCUS_ALL
	mouse_default_cursor_shape = CURSOR_IBEAM

	caret_timer = Timer.new()
	caret_timer.wait_time = 0.53
	caret_timer.autostart = true
	caret_timer.timeout.connect(_on_caret_timer_timeout)
	add_child(caret_timer)


func setup(buffer: TextBuffer) -> void:
	if text_buffer and text_buffer.text_changed.is_connected(_on_text_changed):
		text_buffer.text_changed.disconnect(_on_text_changed)

	text_buffer = buffer
	if text_buffer:
		text_buffer.text_changed.connect(_on_text_changed)

	_update_caret_position()


func _gui_input(event: InputEvent) -> void:
	if not visible_label or not hit_test_viewport or not text_buffer:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			last_known_caret_pos = event.position
			var clicked_idx: int = hit_test_viewport.get_plain_index_at_position(event.position)
			self.caret_index = clicked_idx if clicked_idx != -1 else text_buffer.plain_text.length()
			selection_start = caret_index
			selection_end = caret_index
			is_dragging = true
		else:
			is_dragging = false
		_reset_caret_blink()

	elif event is InputEventMouseMotion and is_dragging:
		last_known_caret_pos = event.position
		var hovered_idx: int = hit_test_viewport.get_plain_index_at_position(event.position)
		if hovered_idx != -1:
			self.caret_index = hovered_idx
			selection_end = caret_index
			_reset_caret_blink()

	elif event is InputEventKey and event.pressed:
		_handle_keyboard_input(event)


func _handle_keyboard_input(event: InputEventKey) -> void:
	var plain_len: int = text_buffer.plain_text.length()

	match event.keycode:
		KEY_LEFT:
			if event.shift_pressed and selection_start == -1:
				selection_start = caret_index
			self.caret_index = max(0, caret_index - 1)
			if event.shift_pressed:
				selection_end = caret_index
			else:
				_clear_selection()

		KEY_RIGHT:
			if event.shift_pressed and selection_start == -1:
				selection_start = caret_index
			self.caret_index = min(plain_len, caret_index + 1)
			if event.shift_pressed:
				selection_end = caret_index
			else:
				_clear_selection()

		KEY_BACKSPACE:
			if _has_selection():
				_delete_selection()
			elif caret_index > 0:
				var target_idx: int = caret_index - 1
				text_buffer.delete_plain_range(target_idx, caret_index)
				self.caret_index = target_idx

		KEY_DELETE:
			if _has_selection():
				_delete_selection()
			elif caret_index < plain_len:
				text_buffer.delete_plain_range(caret_index, caret_index + 1)

		KEY_ENTER:
			if _has_selection():
				_delete_selection()
			var target_idx: int = caret_index
			text_buffer.insert_text_at_plain_index(target_idx, "\n")
			self.caret_index = target_idx + 1

		_:
			if event.unicode > 31 and event.unicode != 127:
				var typed_char: String = String.chr(event.unicode)
				if _has_selection():
					_delete_selection()
				var target_idx: int = caret_index
				text_buffer.insert_text_at_plain_index(target_idx, typed_char)
				self.caret_index = target_idx + typed_char.length()

	_reset_caret_blink()


func _draw() -> void:
	if not has_focus() or not text_buffer or not visible_label:
		return

	if caret_visible and caret_index >= 0:
		var font_height: float = _get_font_height()
		draw_line(cached_caret_pos, cached_caret_pos + Vector2(0, font_height), CARET_COLOR, CARET_WIDTH)


func _update_caret_position() -> void:
	cached_caret_pos = _get_caret_screen_position(caret_index)
	last_known_caret_pos = cached_caret_pos
	queue_redraw()


func _get_caret_screen_position(idx: int) -> Vector2:
	if not visible_label or not text_buffer or not hit_test_viewport:
		return Vector2.ZERO

	if text_buffer.plain_text.length() == 0 or idx <= 0:
		return Vector2.ZERO

	var font = visible_label.get_theme_font("normal_font")
	var font_size: int = visible_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 16

	var target_char_idx: int = idx - 1
	var target_char: String = text_buffer.plain_text[target_char_idx]

	# Only skip unrendered whitespace like tabs and newlines
	if target_char in ["\t", "\n"]:
		# print("[Caret Search] Skipping unrendered whitespace char '%s' at idx %d" % [target_char, idx])
		return _calculate_font_fallback_pos(idx, font, font_size)

	var tex: Texture2D = hit_test_viewport.get_texture()
	if not tex:
		# print("[Caret Search] HitTestViewport texture is null.")
		return _calculate_font_fallback_pos(idx, font, font_size)

	var img: Image = tex.get_image()
	if img and target_char_idx < text_buffer.plain_text_ids.size():
		var target_color: Color = ColorIDMapper.get_color_from_index(text_buffer, target_char_idx)
		var estimated_pos: Vector2 = _calculate_font_fallback_pos(idx, font, font_size)

		var found_pos: Vector2 = _find_target_color_radially(img, estimated_pos, target_color)
		if found_pos != Vector2.INF:
			# print("[Caret Search] Match found at idx %d (%s) -> Pos: %s" % [idx, target_char, found_pos])
			return found_pos

	# print("[Caret Search] Search missed at idx %d (%s) -> Using fallback pos." % [idx, target_char])
	return _calculate_font_fallback_pos(idx, font, font_size)


## Scans outward step-by-step from start_pos until the target color is matched
func _find_target_color_radially(img: Image, start_pos: Vector2, target_color: Color) -> Vector2:
	var width: int = img.get_width()
	var height: int = img.get_height()
	var start_x: int = clampi(int(start_pos.x), 0, width - 1)
	var start_y: int = clampi(int(start_pos.y), 0, height - 1)

	var max_radius: int = 150 # Maximum horizontal/vertical distance to search
	
	for r in range(0, max_radius):
		for y_offset in range(-8, 9): # Vertical jitter allowance
			var test_y: int = start_y + y_offset
			if test_y < 0 or test_y >= height:
				continue

			for dir in [1, -1]:
				var test_x: int = start_x + (r * dir)
				if test_x < 0 or test_x >= width:
					continue

				var px: Color = img.get_pixel(test_x, test_y)
				if px.a > 0.1 and _colors_match(px, target_color):
					# Find the right edge of this glyph segment
					var rightmost_x: int = test_x
					while rightmost_x + 1 < width:
						var next_px: Color = img.get_pixel(rightmost_x + 1, test_y)
						if next_px.a > 0.1 and _colors_match(next_px, target_color):
							rightmost_x += 1
						else:
							break
					
					var line_h: float = _get_font_height()
					return Vector2(rightmost_x + 1.0, _get_line_count(caret_index) * line_h)

	return Vector2.INF


func _colors_match(c1: Color, c2: Color, tol: float = 0.001) -> bool:
	return abs(c1.r - c2.r) < tol and abs(c1.g - c2.g) < tol and abs(c1.b - c2.b) < tol


func _calculate_font_fallback_pos(idx: int, font: Font, font_size: int) -> Vector2:
	var target_char_idx: int = idx - 1
	var line_start: int = _get_line_start(target_char_idx)
	var line_text: String = text_buffer.plain_text.substr(line_start, idx - line_start)
	var adv_x: float = font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font else 0.0
	return Vector2(adv_x, _get_line_count(idx) * _get_font_height())


func _get_line_start(char_idx: int) -> int:
	var start: int = text_buffer.plain_text.rfind("\n", char_idx)
	return 0 if start == -1 else start + 1


func _get_line_count(idx: int) -> int:
	return text_buffer.plain_text.substr(0, idx).count("\n")


func _get_font_height() -> float:
	var font = visible_label.get_theme_font("normal_font")
	var font_size: int = visible_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 16
	return font.get_height(font_size) if font else font_size * 1.2


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
	self.caret_index = start
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
	var max_len: int = text_buffer.plain_text.length() if text_buffer else 0
	caret_index = clampi(caret_index, 0, max_len)
	_deferred_update_caret_position.call_deferred()


func _deferred_update_caret_position() -> void:
	await RenderingServer.frame_post_draw
	_update_caret_position()
