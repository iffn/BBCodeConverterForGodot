class_name RichTextEditor
extends Control

@export var visible_label: RichTextLabel
@export var hit_test_viewport: HitTestViewport
@export var overlay: CaretAndSelectionOverlay
@export var scroll_bar: VScrollBar

var text_buffer: TextBuffer


func _ready() -> void:
	text_buffer = TextBuffer.new()

	if hit_test_viewport:
		hit_test_viewport.setup(text_buffer)

	if overlay:
		overlay.setup(text_buffer)

	if scroll_bar:
		scroll_bar.value_changed.connect(_on_scroll_changed)

	if visible_label:
		text_buffer.set_raw_text(visible_label.text)

	text_buffer.text_changed.connect(_on_buffer_text_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or not overlay:
		return

	var key_event := event as InputEventKey
	var ctrl: bool = key_event.ctrl_pressed or key_event.meta_pressed

	# 1. Formatting Hotkeys
	if ctrl:
		match key_event.keycode:
			KEY_B:
				apply_tag_to_selection("b")
				get_viewport().set_input_as_handled()
				return
			KEY_I:
				apply_tag_to_selection("i")
				get_viewport().set_input_as_handled()
				return
			KEY_U:
				apply_tag_to_selection("u")
				get_viewport().set_input_as_handled()
				return
			KEY_S:
				apply_tag_to_selection("s")
				get_viewport().set_input_as_handled()
				return
			KEY_L:
				add_list_layer()
				get_viewport().set_input_as_handled()
				return

	# 2. Backspace & Delete
	if key_event.keycode == KEY_BACKSPACE:
		_handle_backspace()
		get_viewport().set_input_as_handled()
		return
	elif key_event.keycode == KEY_DELETE:
		_handle_delete()
		get_viewport().set_input_as_handled()
		return

	# 3. Enter / Return Key
	elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_handle_text_input("\n")
		get_viewport().set_input_as_handled()
		return

	# 4. Printable Character Input
	if key_event.unicode > 31 and not ctrl:
		_handle_text_input(String.chr(key_event.unicode))
		get_viewport().set_input_as_handled()


func _handle_text_input(text_to_insert: String) -> void:
	var sel: Vector2i = overlay.get_selection_range()
	var insert_idx: int = overlay.caret_index

	if sel.x != sel.y:
		text_buffer.delete_plain_range(sel.x, sel.y)
		insert_idx = sel.x
		overlay.clear_selection()

	text_buffer.insert_text_at_plain_index(insert_idx, text_to_insert)
	overlay.set_caret_index(insert_idx + text_to_insert.length())


func _handle_backspace() -> void:
	var sel: Vector2i = overlay.get_selection_range()

	if sel.x != sel.y:
		text_buffer.delete_plain_range(sel.x, sel.y)
		overlay.set_caret_index(sel.x)
		overlay.clear_selection()
	elif overlay.caret_index > 0:
		var target_idx: int = overlay.caret_index - 1
		text_buffer.delete_plain_range(target_idx, overlay.caret_index)
		overlay.set_caret_index(target_idx)


func _handle_delete() -> void:
	var sel: Vector2i = overlay.get_selection_range()

	if sel.x != sel.y:
		text_buffer.delete_plain_range(sel.x, sel.y)
		overlay.set_caret_index(sel.x)
		overlay.clear_selection()
	elif overlay.caret_index < text_buffer.plain_text.length():
		text_buffer.delete_plain_range(overlay.caret_index, overlay.caret_index + 1)


func apply_tag_to_selection(tag_name: String) -> void:
	if not overlay or not text_buffer:
		return

	var sel: Vector2i = overlay.get_selection_range()
	var new_sel: Vector2i = text_buffer.toggle_tag_on_range(sel.x, sel.y, tag_name)

	_apply_new_selection(new_sel)


func add_list_layer() -> void:
	if not overlay or not text_buffer:
		return

	var sel: Vector2i = overlay.get_selection_range()
	var new_sel: Vector2i = text_buffer.add_list_layer(sel.x, sel.y)

	_apply_new_selection(new_sel)


func toggle_bold() -> void:
	apply_tag_to_selection("b")


func toggle_italic() -> void:
	apply_tag_to_selection("i")


func toggle_underlined() -> void:
	apply_tag_to_selection("u")


func toggle_strikethrough() -> void:
	apply_tag_to_selection("s")


func toggle_center() -> void:
	apply_tag_to_selection("center")


func toggle_left() -> void:
	apply_tag_to_selection("left")


func toggle_right() -> void:
	apply_tag_to_selection("right")


func toggle_fill() -> void:
	apply_tag_to_selection("fill")


func get_active_formatting() -> Array[String]:
	if not overlay or not text_buffer:
		return []
	return text_buffer.get_active_tags_at_index(overlay.caret_index)


func _apply_new_selection(new_sel: Vector2i) -> void:
	if new_sel.x == new_sel.y:
		overlay.clear_selection()
		overlay.set_caret_index(new_sel.x)
	else:
		overlay.selection_anchor = new_sel.x
		overlay.set_caret_index(new_sel.y)


func _on_buffer_text_changed() -> void:
	if visible_label:
		visible_label.text = text_buffer.raw_text

	if overlay:
		overlay.queue_redraw()


func _on_scroll_changed(value: float) -> void:
	var int_val: int = int(value)
	if visible_label:
		visible_label.scroll_to_line(int_val)
	if hit_test_viewport:
		hit_test_viewport.sync_scroll(int_val)
