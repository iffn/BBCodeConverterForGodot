class_name HitTestViewport
extends SubViewport

@export var visible_label: RichTextLabel
@export var hidden_label: RichTextLabel

var text_buffer: TextBuffer


## Initializes the viewport with the text buffer and mirrors visible label settings
func setup(buffer: TextBuffer) -> void:
	text_buffer = buffer
	sync_label_properties()
	update_hidden_text(text_buffer)


## Synchronizes layout properties between the visible label and the hidden hit-test label
func sync_label_properties() -> void:
	if not visible_label or not hidden_label:
		return

	# Match viewport and hidden label size to visible label
	size = Vector2i(visible_label.size)
	hidden_label.size = visible_label.size
	hidden_label.position = Vector2.ZERO
	hidden_label.autowrap_mode = visible_label.autowrap_mode
	hidden_label.bbcode_enabled = true

	# Match font, theme, and font size overrides
	var font = visible_label.get_theme_font("normal_font")
	var font_size = visible_label.get_theme_font_size("normal_font_size")

	if font:
		hidden_label.add_theme_font_override("normal_font", font)
		hidden_label.add_theme_font_override("bold_font", font)
		hidden_label.add_theme_font_override("italics_font", font)
		hidden_label.add_theme_font_override("bold_italics_font", font)
		hidden_label.add_theme_font_override("mono_font", font)

	if font_size > 0:
		hidden_label.add_theme_font_size_override("normal_font_size", font_size)
		hidden_label.add_theme_font_size_override("bold_font_size", font_size)
		hidden_label.add_theme_font_size_override("italics_font_size", font_size)
		hidden_label.add_theme_font_size_override("bold_italics_font_size", font_size)
		hidden_label.add_theme_font_size_override("mono_font_size", font_size)


## Synchronizes scrolling from the main visible label to the offscreen hidden label
func sync_scroll(scroll_value: int) -> void:
	if not hidden_label:
		return

	var v_bar = hidden_label.get_v_scroll_bar()
	if v_bar:
		v_bar.value = scroll_value


## Re-renders the text buffer into color-encoded BBCode inside the hidden label
func update_hidden_text(buffer: TextBuffer) -> void:
	if not hidden_label or not buffer:
		return

	var raw_bbcode: String = buffer.raw_text
	var plain_ids: Array[int] = buffer.plain_text_ids

	var result_bbcode: String = ""
	var plain_char_counter: int = 0
	var in_tag: bool = false

	# Parse raw BBCode and replace printable characters with solid color blocks
	var i: int = 0
	while i < raw_bbcode.length():
		var ch: String = raw_bbcode[i]

		if ch == "[":
			in_tag = true
			result_bbcode += ch
			i += 1
			continue
		elif ch == "]":
			in_tag = false
			result_bbcode += ch
			i += 1
			continue

		if in_tag:
			result_bbcode += ch
			i += 1
			continue

		# Handles plain text characters
		if plain_char_counter < plain_ids.size():
			var flat_id: int = plain_ids[plain_char_counter]
			var char_color: Color = _flat_id_to_color(flat_id)
			var hex_color: String = ColorIDMapper.to_bbcode_color(char_color)

			if ch == "\n":
				result_bbcode += "\n"
			else:
				# Set BOTH text color and background color to the exact same ID
				result_bbcode += "[color=" + hex_color + "][bgcolor=" + hex_color + "]" + ch + "[/bgcolor][/color]"

			plain_char_counter += 1
		else:
			result_bbcode += ch

		i += 1

	hidden_label.text = result_bbcode


## Decodes mouse position in viewport to corresponding plain text character index
func get_plain_index_at_position(pos: Vector2) -> int:
	var tex: ViewportTexture = get_texture()
	if not tex:
		return -1

	var img: Image = tex.get_image()
	if not img:
		return -1

	var img_size: Vector2i = img.get_size()
	var px: int = clampi(int(pos.x), 0, img_size.x - 1)
	var py: int = clampi(int(pos.y), 0, img_size.y - 1)

	var sampled_color: Color = img.get_pixel(px, py)

	# Skip completely transparent or unpainted background pixels
	if sampled_color.a < 0.1:
		return -1

	var vec_id: Vector3i = ColorIDMapper.decode_color(sampled_color)
	var flat_id: int = ColorIDMapper.to_flat_id(vec_id)

	if text_buffer:
		return text_buffer.get_plain_index_from_flat_id(flat_id)

	return -1


func _flat_id_to_color(flat_id: int) -> Color:
	var vec_id: Vector3i = ColorIDMapper.from_flat_id(flat_id)
	return ColorIDMapper.encode_sector_id(vec_id.x, vec_id.y, vec_id.z)
