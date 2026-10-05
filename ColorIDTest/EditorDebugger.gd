class_name EditorDebugger
extends Control

@export var editor: RichTextEditor
@export var editor_panel: Control
@export var debug_panel: Control
@export var debug_texture_rect: TextureRect
@export var info_label: Label
@export var raw_output: LineEdit

func _process(_delta: float) -> void:
	if not editor or not editor.hit_test_viewport or not editor.text_buffer:
		return

	var viewport = editor.hit_test_viewport
	var buffer = editor.text_buffer
	var overlay = editor.overlay

	# 1. Update live texture preview
	var viewport_tex = viewport.get_texture()
	if debug_texture_rect and viewport_tex:
		debug_texture_rect.texture = viewport_tex

	# 2. Calculate mouse offset relative to the Editor Panel
	var local_mouse: Vector2 = Vector2(-1, -1)
	var img_pixel_pos: Vector2i = Vector2i(-1, -1)
	var img: Image = viewport_tex.get_image() if viewport_tex else null

	var ref_panel: Control = editor_panel if editor_panel else editor

	if ref_panel:
		local_mouse = ref_panel.get_local_mouse_position()

		if img and ref_panel.size.x > 0 and ref_panel.size.y > 0:
			var scale_x: float = float(img.get_width()) / ref_panel.size.x
			var scale_y: float = float(img.get_height()) / ref_panel.size.y
			img_pixel_pos = Vector2i(local_mouse * Vector2(scale_x, scale_y))

	var sampled_color := Color.BLACK
	var decoded_id := Vector3i(-1, -1, -1)
	var flat_id: int = -1
	var plain_idx: int = -1
	var hovered_char: String = "N/A"

	# Sample using image-space coordinates via ColorIDMapper
	if img and img_pixel_pos.x >= 0 and img_pixel_pos.y >= 0 and img_pixel_pos.x < img.get_width() and img_pixel_pos.y < img.get_height():
		sampled_color = img.get_pixel(img_pixel_pos.x, img_pixel_pos.y)

		if sampled_color.a >= 0.1:
			decoded_id = ColorIDMapper.decode_color(sampled_color)
			flat_id = ColorIDMapper.to_flat_id(decoded_id)
			plain_idx = ColorIDMapper.get_index_from_color(buffer, sampled_color)

			if plain_idx >= 0 and plain_idx < buffer.plain_text.length():
				var raw_char: String = buffer.plain_text[plain_idx]
				match raw_char:
					"\n":
						hovered_char = "\\n"
					"\t":
						hovered_char = "\\t"
					" ":
						hovered_char = "' '"
					_:
						hovered_char = raw_char

	# 3. Get Caret Debug Info
	var caret_idx = overlay.caret_index
	var target_flat_id: int = -1
	var target_color_hex: String = "N/A"

	if caret_idx > 0 and caret_idx - 1 < buffer.plain_text_ids.size():
		var target_idx: int = caret_idx - 1
		target_flat_id = buffer.plain_text_ids[target_idx]
		var target_color: Color = ColorIDMapper.get_color_from_index(buffer, target_idx)
		target_color_hex = ColorIDMapper.to_bbcode_color(target_color)

	# Safely resolve next char when text is empty or caret is at the end
	var next_char: String = "N/A"
	if caret_idx >= 0 and caret_idx < buffer.plain_text.length():
		next_char = buffer.plain_text[caret_idx]

	# 4. Format stats text
	var debug_info: String = ""
	debug_info += "=== MOUSE SAMPLING ===\n"
	debug_info += "Editor Panel Offset: %s\n" % str(Vector2i(local_mouse))
	debug_info += "Image Pixel Pos: %s\n" % str(img_pixel_pos)
	debug_info += "Sampled Color (Hex): #%s\n" % sampled_color.to_html(false)
	debug_info += "Decoded (Sec, Base, Ext): %s\n" % str(decoded_id)
	debug_info += "Flat ID: %d | Plain Index: %d\n" % [flat_id, plain_idx]
	debug_info += "Hovered Char: %s\n\n" % hovered_char

	debug_info += "=== CARET STATE ===\n"
	debug_info += "Caret Plain Index: %d\n" % caret_idx
	debug_info += "Target Char Flat ID: %d\n" % target_flat_id
	debug_info += "Target Color (Hex): %s\n" % target_color_hex
	debug_info += "Next char : %s\n" % next_char
	debug_info += "\n"

	debug_info += "=== TEXT BUFFER ===\n"
	debug_info += "Plain Text Length: %d\n" % buffer.plain_text.length()
	debug_info += "Raw Text Length: %d" % buffer.raw_text.length()

	if info_label:
		info_label.text = debug_info

	queue_redraw()
	
	raw_output.text = buffer.raw_text


func _draw() -> void:
	if not debug_texture_rect:
		return
	
	var mouse_pos_editor = editor_panel.get_local_mouse_position()
	var offset = debug_panel.global_position - editor_panel.global_position
	
	var draw_pos: Vector2 = mouse_pos_editor + offset

	var gap: float = 2.0
	var line_length: float = 8.0
	var line_width: float = 2.0
	var crosshair_color: Color = Color.RED

	# Left line
	draw_line(draw_pos - Vector2(gap + line_length, 0), draw_pos - Vector2(gap, 0), crosshair_color, line_width)
	# Right line
	draw_line(draw_pos + Vector2(gap, 0), draw_pos + Vector2(gap + line_length, 0), crosshair_color, line_width)
	# Top line
	draw_line(draw_pos - Vector2(0, gap + line_length), draw_pos - Vector2(0, gap), crosshair_color, line_width)
	# Bottom line
	draw_line(draw_pos + Vector2(0, gap), draw_pos + Vector2(0, gap + line_length), crosshair_color, line_width)
