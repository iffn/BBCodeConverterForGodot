class_name EditorDebugger
extends Control

@export var editor: RichTextEditor
@export var debug_texture_rect: TextureRect
@export var info_label: Label

var target_crosshair_pos: Vector2 = Vector2(-1, -1)
var sampled_crosshair_pos: Vector2 = Vector2(-1, -1)


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
		
	# 2. Sample pixel under local mouse cursor
	var mouse_pos = overlay.get_local_mouse_position()
	var img: Image = viewport_tex.get_image() if viewport_tex else null
	
	var sampled_color := Color.BLACK
	var decoded_id := Vector3i(-1, -1, -1)
	var flat_id: int = -1
	var plain_idx: int = -1
	var hovered_char: String = "N/A"
	
	if img and mouse_pos.x >= 0 and mouse_pos.y >= 0 and mouse_pos.x < img.get_width() and mouse_pos.y < img.get_height():
		sampled_color = img.get_pixel(int(mouse_pos.x), int(mouse_pos.y))
		
		# Only process valid non-transparent pixel samples
		if sampled_color.a >= 0.1:
			decoded_id = ColorIDMapper.decode_color(sampled_color)
			flat_id = ColorIDMapper.to_flat_id(decoded_id)
			plain_idx = buffer.get_plain_index_from_flat_id(flat_id)
			
			if plain_idx >= 0 and plain_idx < buffer.plain_text.length():
				var raw_char: String = buffer.plain_text[plain_idx]
				
				# Format special characters cleanly for the UI debug string
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
		target_flat_id = buffer.plain_text_ids[caret_idx - 1]
		var target_color = viewport._flat_id_to_color(target_flat_id)
		target_color_hex = ColorIDMapper.to_bbcode_color(target_color)

	# 4. Format stats text
	var debug_info: String = ""
	debug_info += "=== MOUSE SAMPLING ===\n"
	debug_info += "Mouse Pos: %s\n" % str(Vector2i(mouse_pos))
	debug_info += "Sampled Color (Hex): #%s\n" % sampled_color.to_html(false)
	debug_info += "Decoded (Sec, Base, Ext): %s\n" % str(decoded_id)
	debug_info += "Flat ID: %d | Plain Index: %d\n" % [flat_id, plain_idx]
	debug_info += "Hovered Char: %s\n\n" % hovered_char
	
	debug_info += "=== CARET STATE ===\n"
	debug_info += "Caret Plain Index: %d\n" % caret_idx
	debug_info += "Target Char Flat ID: %d\n" % target_flat_id
	debug_info += "Target Color (Hex): %s\n\n" % target_color_hex
	
	debug_info += "=== TEXT BUFFER ===\n"
	debug_info += "Plain Text Length: %d\n" % buffer.plain_text.length()
	debug_info += "Raw Text Length: %d" % buffer.raw_text.length()
	
	if info_label:
		info_label.text = debug_info

	queue_redraw()


func _draw() -> void:
	if not editor or not editor.overlay:
		return
		
	var mouse_pos = editor.overlay.get_local_mouse_position()
	
	# Draw crosshair over current mouse position on top of editor
	draw_line(mouse_pos - Vector2(10, 0), mouse_pos + Vector2(10, 0), Color.RED, 2.0)
	draw_line(mouse_pos - Vector2(0, 10), mouse_pos + Vector2(0, 10), Color.RED, 2.0)
