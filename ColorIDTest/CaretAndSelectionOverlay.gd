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

var selection_start: int = -1:
	set(value):
		if selection_start != value:
			selection_start = value
			selection_changed.emit(selection_start, selection_end)
			queue_redraw()

var selection_end: int = -1:
	set(value):
		if selection_end != value:
			selection_end = value
			selection_changed.emit(selection_start, selection_end)
			queue_redraw()

var is_dragging: bool = false
var caret_visible: bool = true
var caret_timer: Timer

var last_known_caret_pos: Vector2 = Vector2.ZERO
var cached_caret_pos: Vector2 = Vector2.ZERO
var cached_caret_height: float = -1.0 # Tracks dynamic line height at caret
var preferred_x: float = -1.0

const CARET_WIDTH: float = 2.0
const CARET_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const SELECTION_COLOR: Color = Color(0.2, 0.5, 0.9, 0.4)


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
			preferred_x = event.position.x
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
		preferred_x = event.position.x
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
			preferred_x = -1.0
			if event.shift_pressed and selection_start == -1:
				selection_start = caret_index
			self.caret_index = max(0, caret_index - 1)
			if event.shift_pressed:
				selection_end = caret_index
			else:
				_clear_selection()

		KEY_RIGHT:
			preferred_x = -1.0
			if event.shift_pressed and selection_start == -1:
				selection_start = caret_index
			self.caret_index = min(plain_len, caret_index + 1)
			if event.shift_pressed:
				selection_end = caret_index
			else:
				_clear_selection()

		KEY_UP:
			_move_caret_vertically(-1, event.shift_pressed)

		KEY_DOWN:
			_move_caret_vertically(1, event.shift_pressed)

		KEY_BACKSPACE:
			preferred_x = -1.0
			if _has_selection():
				_delete_selection()
			elif caret_index > 0:
				var target_idx: int = caret_index - 1
				text_buffer.delete_plain_range(target_idx, caret_index)
				self.caret_index = target_idx

		KEY_DELETE:
			preferred_x = -1.0
			if _has_selection():
				_delete_selection()
			elif caret_index < plain_len:
				text_buffer.delete_plain_range(caret_index, caret_index + 1)

		KEY_ENTER:
			preferred_x = -1.0
			if _has_selection():
				_delete_selection()
			var target_idx: int = caret_index
			text_buffer.insert_text_at_plain_index(target_idx, "\n")
			self.caret_index = target_idx + 1

		_:
			if event.unicode > 31 and event.unicode != 127:
				preferred_x = -1.0
				var typed_char: String = String.chr(event.unicode)
				if _has_selection():
					_delete_selection()
				var target_idx: int = caret_index
				text_buffer.insert_text_at_plain_index(target_idx, typed_char)
				self.caret_index = target_idx + typed_char.length()

	_reset_caret_blink()


func _move_caret_vertically(line_direction: int, shift_pressed: bool) -> void:
	if not text_buffer or text_buffer.plain_text.length() == 0:
		return

	if preferred_x < 0.0:
		preferred_x = cached_caret_pos.x

	var current_line: int = _get_line_count(caret_index)
	var target_line: int = current_line + line_direction

	if target_line < 0 or target_line > text_buffer.plain_text.count("\n"):
		return

	if shift_pressed and selection_start == -1:
		selection_start = caret_index

	var target_line_start: int = _get_line_index_by_count(target_line)
	var target_line_end: int = text_buffer.plain_text.find("\n", target_line_start)
	if target_line_end == -1:
		target_line_end = text_buffer.plain_text.length()

	var best_idx: int = target_line_start
	var closest_dist: float = INF

	for i in range(target_line_start, target_line_end + 1):
		var pos: Vector2 = _get_caret_screen_position(i)
		var dist: float = abs(pos.x - preferred_x)
		if dist < closest_dist:
			closest_dist = dist
			best_idx = i

	var saved_preferred_x: float = preferred_x
	self.caret_index = best_idx
	preferred_x = saved_preferred_x

	if shift_pressed:
		selection_end = caret_index
	else:
		_clear_selection()


func _get_line_index_by_count(line_target: int) -> int:
	if line_target <= 0:
		return 0
	var count: int = 0
	var idx: int = 0
	while idx < text_buffer.plain_text.length():
		if text_buffer.plain_text[idx] == "\n":
			count += 1
			if count == line_target:
				return idx + 1
		idx += 1
	return text_buffer.plain_text.length()


func _draw() -> void:
	if not has_focus() or not text_buffer or not visible_label:
		return

	if _has_selection():
		_draw_selection_rects()

	if caret_visible and caret_index >= 0:
		var draw_h: float = cached_caret_height if cached_caret_height > 0.0 else _get_font_height()
		draw_line(cached_caret_pos, cached_caret_pos + Vector2(0, draw_h), CARET_COLOR, CARET_WIDTH)


func _draw_selection_rects() -> void:
	var tex: Texture2D = hit_test_viewport.get_texture()
	if not tex:
		return

	var img: Image = tex.get_image()
	if not img:
		return

	var start_idx: int = min(selection_start, selection_end)
	var end_idx: int = max(selection_start, selection_end)

	var line_rects: Array[Rect2] = []
	var current_rect: Rect2 = Rect2()
	var has_active_rect: bool = false

	for i in range(start_idx, end_idx):
		if i >= text_buffer.plain_text_ids.size():
			break

		var char_rect: Rect2 = _get_character_bounds(img, i)
		if char_rect.size == Vector2.ZERO:
			continue

		if not has_active_rect:
			current_rect = char_rect
			has_active_rect = true
		else:
			if abs(char_rect.position.y - current_rect.position.y) < 4.0:
				var combined_right: float = max(current_rect.end.x, char_rect.end.x)
				var combined_top: float = min(current_rect.position.y, char_rect.position.y)
				var combined_bottom: float = max(current_rect.end.y, char_rect.end.y)

				current_rect.position.y = combined_top
				current_rect.size.x = combined_right - current_rect.position.x
				current_rect.size.y = combined_bottom - combined_top
			else:
				line_rects.append(current_rect)
				current_rect = char_rect

	if has_active_rect:
		line_rects.append(current_rect)

	for rect in line_rects:
		draw_rect(rect, SELECTION_COLOR, true)


func _get_character_bounds(img: Image, char_idx: int) -> Rect2:
	var target_color: Color = ColorIDMapper.get_color_from_index(text_buffer, char_idx)
	var font = visible_label.get_theme_font("normal_font")
	var font_size: int = visible_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 16

	var estimated_pos: Vector2 = _calculate_font_fallback_pos(char_idx + 1, font, font_size)
	var width: int = img.get_width()
	var height: int = img.get_height()

	var start_x: int = clampi(int(estimated_pos.x), 0, width - 1)
	var start_y: int = clampi(int(estimated_pos.y), 0, height - 1)

	var min_x: int = width
	var max_x: int = -1
	var min_y: int = height
	var max_y: int = -1

	var found: bool = false
	var search_radius: int = 40

	for y in range(max(0, start_y - search_radius), min(height, start_y + search_radius)):
		for x in range(max(0, start_x - search_radius), min(width, start_x + search_radius)):
			var px: Color = img.get_pixel(x, y)
			if px.a > 0.1 and _colors_match(px, target_color):
				found = true
				min_x = min(min_x, x)
				max_x = max(max_x, x)
				min_y = min(min_y, y)
				max_y = max(max_y, y)

	if not found:
		return Rect2()

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))


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

	if target_char in ["\t", "\n"]:
		cached_caret_height = _get_font_height()
		return _calculate_font_fallback_pos(idx, font, font_size)

	var tex: Texture2D = hit_test_viewport.get_texture()
	if not tex:
		cached_caret_height = _get_font_height()
		return _calculate_font_fallback_pos(idx, font, font_size)

	var img: Image = tex.get_image()
	if img and target_char_idx < text_buffer.plain_text_ids.size():
		var target_color: Color = ColorIDMapper.get_color_from_index(text_buffer, target_char_idx)
		var estimated_pos: Vector2 = _calculate_font_fallback_pos(idx, font, font_size)

		if preferred_x >= 0.0:
			estimated_pos.x = preferred_x

		var found_pos: Vector2 = _find_target_color_radially(img, estimated_pos, target_color)
		if found_pos != Vector2.INF:
			return found_pos

	cached_caret_height = _get_font_height()
	return _calculate_font_fallback_pos(idx, font, font_size)


func _find_target_color_radially(img: Image, start_pos: Vector2, target_color: Color) -> Vector2:
	var width: int = img.get_width()
	var height: int = img.get_height()
	var start_x: int = clampi(int(start_pos.x), 0, width - 1)
	var start_y: int = clampi(int(start_pos.y), 0, height - 1)

	var max_radius: int = 200
	var gap_tolerance: int = 2

	for r in range(0, max_radius):
		for y_offset in range(-40, 41):
			var test_y: int = start_y + y_offset
			if test_y < 0 or test_y >= height:
				continue

			for dir in [1, -1]:
				var test_x: int = start_x + (r * dir)
				if test_x < 0 or test_x >= width:
					continue

				var px: Color = img.get_pixel(test_x, test_y)
				if px.a > 0.1 and _colors_match(px, target_color):
					var rightmost_x: int = test_x
					while rightmost_x + 1 < width:
						var next_px: Color = img.get_pixel(rightmost_x + 1, test_y)
						if next_px.a > 0.1 and _colors_match(next_px, target_color):
							rightmost_x += 1
						else:
							break

					var line_top_y: int = test_y
					var curr_y: int = test_y
					var gaps: int = 0

					while curr_y - 1 >= 0:
						var up_px: Color = img.get_pixel(test_x, curr_y - 1)
						if up_px.a > 0.1 and _colors_match(up_px, target_color):
							line_top_y = curr_y - 1
							gaps = 0
						else:
							gaps += 1
							if gaps > gap_tolerance:
								break
						curr_y -= 1

					var line_bottom_y: int = test_y
					curr_y = test_y
					gaps = 0

					while curr_y + 1 < height:
						var down_px: Color = img.get_pixel(test_x, curr_y + 1)
						if down_px.a > 0.1 and _colors_match(down_px, target_color):
							line_bottom_y = curr_y + 1
							gaps = 0
						else:
							gaps += 1
							if gaps > gap_tolerance:
								break
						curr_y += 1

					var default_h: float = _get_font_height()
					var measured_h: float = float(line_bottom_y - line_top_y + 1)

					cached_caret_height = max(default_h, measured_h)
					return Vector2(rightmost_x + 1.0, float(line_top_y))

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
