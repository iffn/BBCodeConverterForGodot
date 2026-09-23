class_name CaretAndSelectionOverlay
extends Control

signal selection_changed(start_index: int, end_index: int)
signal caret_moved(plain_index: int)

@export var visible_label: RichTextLabel
@export var hit_test_viewport: HitTestViewport

var text_buffer: TextBuffer

# Caret and Selection state (measured in plain-text index offsets)
var caret_index: int = 0:
	set(value):
		var clamped_val = clampi(value, 0, text_buffer.plain_text.length() if text_buffer else 0)
		if caret_index != clamped_val or cached_caret_pos == Vector2.ZERO:
			caret_index = clamped_val
			_update_caret_position()
			caret_moved.emit(caret_index)

var selection_start: int = -1
var selection_end: int = -1

var is_dragging: bool = false
var caret_visible: bool = true
var caret_timer: Timer

# Cache last known valid caret screen position for warm-start color searching
var last_known_caret_pos: Vector2 = Vector2.ZERO
# Stores the finalized calculated screen position for passive rendering in _draw()
var cached_caret_pos: Vector2 = Vector2.ZERO

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
	_update_caret_position()


func _gui_input(event: InputEvent) -> void:
	if not visible_label or not hit_test_viewport or not text_buffer:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				# Mouse click provides direct warm-start coordinate reference
				last_known_caret_pos = event.position
				var clicked_idx: int = hit_test_viewport.get_plain_index_at_position(event.position)
				
				if clicked_idx != -1:
					self.caret_index = clicked_idx
				else:
					self.caret_index = text_buffer.plain_text.length()
				
				selection_start = caret_index
				selection_end = caret_index
				is_dragging = true
				_reset_caret_blink()
			else:
				is_dragging = false

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
			if event.shift_pressed:
				if selection_start == -1:
					selection_start = caret_index
				self.caret_index = max(0, caret_index - 1)
				selection_end = caret_index
			else:
				self.caret_index = max(0, caret_index - 1)
				_clear_selection()
				
		KEY_RIGHT:
			if event.shift_pressed:
				if selection_start == -1:
					selection_start = caret_index
				self.caret_index = min(plain_len, caret_index + 1)
				selection_end = caret_index
			else:
				self.caret_index = min(plain_len, caret_index + 1)
				_clear_selection()
				
		KEY_BACKSPACE:
			if _has_selection():
				_delete_selection()
			elif caret_index > 0:
				text_buffer.delete_plain_range(caret_index - 1, caret_index)
				self.caret_index -= 1
				
		KEY_DELETE:
			if _has_selection():
				_delete_selection()
			elif caret_index < plain_len:
				text_buffer.delete_plain_range(caret_index, caret_index + 1)
				
		KEY_ENTER:
			if _has_selection():
				_delete_selection()
			text_buffer.insert_text_at_plain_index(caret_index, "\n")
			self.caret_index += 1
			
		_:
			if event.unicode > 31 and event.unicode != 127:
				var typed_char: String = String.chr(event.unicode)
				if _has_selection():
					_delete_selection()
				text_buffer.insert_text_at_plain_index(caret_index, typed_char)
				self.caret_index += typed_char.length()

	_reset_caret_blink()


func _draw() -> void:
	if not has_focus() or not text_buffer or not visible_label:
		return

	# Pure passive drawing using pre-calculated position
	if caret_visible and caret_index >= 0:
		var font_height: float = visible_label.get_theme_font_size("normal_font_size")
		if font_height <= 0:
			font_height = 16.0
		draw_line(cached_caret_pos, cached_caret_pos + Vector2(0, font_height), CARET_COLOR, CARET_WIDTH)


## Triggers caret position recalculation only when index or text changes
func _update_caret_position() -> void:
	cached_caret_pos = _get_caret_screen_position(caret_index)
	last_known_caret_pos = cached_caret_pos
	queue_redraw()


## Calculates caret position and prints diagnostic information
func _get_caret_screen_position(idx: int) -> Vector2:
	print("\n--- CARET POSITION SEARCH [New Index: %d] ---" % idx)

	if not visible_label or not text_buffer or not hit_test_viewport:
		print("  [ERROR] Missing editor dependencies!")
		return Vector2.ZERO

	var plain_len: int = text_buffer.plain_text.length()
	if plain_len == 0 or idx <= 0:
		print("  [INFO] At start of document (Index <= 0). Returning Vector2.ZERO")
		return Vector2.ZERO

	var img: Image = hit_test_viewport.get_texture().get_image()
	if not img:
		print("  [ERROR] Unable to fetch SubViewport image texture! Falling back to last_known_caret_pos: ", last_known_caret_pos)
		return last_known_caret_pos

	var font = visible_label.get_theme_font("normal_font")
	var font_size: int = visible_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 16

	var target_char_idx: int = idx - 1
	var target_char: String = text_buffer.plain_text[target_char_idx]

	var printable_char: String = target_char
	if target_char == "\n": printable_char = "\\n"
	elif target_char == "\t": printable_char = "\\t"
	elif target_char == " ": printable_char = "' '"

	print("  Target Char: '%s' | Char Idx: %d" % [printable_char, target_char_idx])

	# 1. Handle whitespace/newlines using font string measurement fallback
	if target_char == " " or target_char == "\t" or target_char == "\n":
		var line_start: int = text_buffer.plain_text.rfind("\n", target_char_idx)
		line_start = 0 if line_start == -1 else line_start + 1
		var line_text: String = text_buffer.plain_text.substr(line_start, idx - line_start)
		
		var line_count: int = text_buffer.plain_text.substr(0, idx).count("\n")
		var line_h: float = font.get_height(font_size) if font else font_size * 1.2
		var adv_x: float = font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font else 0.0
		
		var whitespace_pos = Vector2(adv_x, line_count * line_h)
		print("  [WHITESPACE DETECTED] Font estimated pos: ", whitespace_pos)
		return whitespace_pos

	# 2. Local Search Region setup
	if target_char_idx < text_buffer.plain_text_ids.size():
		var target_flat_id: int = text_buffer.plain_text_ids[target_char_idx]
		var target_color: Color = hit_test_viewport._flat_id_to_color(target_flat_id)

		print("  Target Flat ID: %d | Hex Color: #%s" % [target_flat_id, target_color.to_html(false)])
		print("  Warm-Start Ref Pos: ", last_known_caret_pos)

		var search_cx: int = int(last_known_caret_pos.x)
		var search_cy: int = int(last_known_caret_pos.y + (font_size * 0.5))

		# Constrain search radius to a single glyph region
		var radius_x: int = 25
		var radius_y: int = 12

		var min_x: int = clampi(search_cx - radius_x, 0, img.get_width() - 1)
		var max_x: int = clampi(search_cx + radius_x, 0, img.get_width() - 1)
		var min_y: int = clampi(search_cy - radius_y, 0, img.get_height() - 1)
		var max_y: int = clampi(search_cy + radius_y, 0, img.get_height() - 1)

		print("  Pixel Search Box: X[%d to %d], Y[%d to %d]" % [min_x, max_x, min_y, max_y])

		var rightmost_x: int = -1
		var matched_pixel_count: int = 0

		# Strict color matching (0.001 tolerance)
		for y in range(min_y, max_y + 1):
			for x in range(min_x, max_x + 1):
				var px_color: Color = img.get_pixel(x, y)
				if px_color.a > 0.1 and _colors_match(px_color, target_color, 0.001):
					matched_pixel_count += 1
					if x > rightmost_x:
						rightmost_x = x

		print("  Pixels Matched: %d" % matched_pixel_count)

		# Validate against matching dark background regions
		if rightmost_x != -1 and matched_pixel_count < 200:
			var line_count: int = text_buffer.plain_text.substr(0, idx).count("\n")
			var line_h: float = font.get_height(font_size) if font else font_size * 1.2
			var final_sampled_pos = Vector2(rightmost_x + 1.0, line_count * line_h)
			print("  [SUCCESS] Match found! Rightmost X: %d | Final Pos: %s" % [rightmost_x, final_sampled_pos])
			return final_sampled_pos
		else:
			print("  [FAIL] Target color invalid or pixel count abnormal (%d)!" % matched_pixel_count)

	# 3. Fallback calculation if sampling fails
	var line_start: int = text_buffer.plain_text.rfind("\n", target_char_idx)
	line_start = 0 if line_start == -1 else line_start + 1
	var line_text: String = text_buffer.plain_text.substr(line_start, idx - line_start)
	var fallback_x: float = font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font else 0.0
	var line_count: int = text_buffer.plain_text.substr(0, idx).count("\n")
	var line_h: float = font.get_height(font_size) if font else font_size * 1.2

	var fallback_pos = Vector2(fallback_x, line_count * line_h)
	print("  [FALLBACK] Using font string size estimate: ", fallback_pos)
	return fallback_pos


## Strict color comparison (0.001 tolerance) to prevent matching black/background pixels
func _colors_match(c1: Color, c2: Color, tol: float = 0.001) -> bool:
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
	self.caret_index = clampi(caret_index, 0, text_buffer.plain_text.length())
	_update_caret_position()
