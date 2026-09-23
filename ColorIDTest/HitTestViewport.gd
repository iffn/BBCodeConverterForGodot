class_name HitTestViewport
extends SubViewport

@export var visible_label: RichTextLabel
@export var hidden_label: RichTextLabel

var text_buffer: TextBuffer


func _ready() -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func setup(buffer: TextBuffer) -> void:
	if text_buffer and text_buffer.text_changed.is_connected(_on_text_changed):
		text_buffer.text_changed.disconnect(_on_text_changed)

	text_buffer = buffer

	if text_buffer:
		text_buffer.text_changed.connect(_on_text_changed)

	sync_label_properties()
	update_hidden_text(text_buffer)


func _on_text_changed() -> void:
	update_hidden_text(text_buffer)


func sync_label_properties() -> void:
	if not visible_label or not hidden_label:
		return

	size = Vector2i(visible_label.size)
	hidden_label.size = visible_label.size
	hidden_label.position = Vector2.ZERO
	hidden_label.autowrap_mode = visible_label.autowrap_mode
	hidden_label.bbcode_enabled = true

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


func sync_scroll(scroll_value: int) -> void:
	if not hidden_label:
		return

	var v_bar = hidden_label.get_v_scroll_bar()
	if v_bar:
		v_bar.value = scroll_value


func update_hidden_text(buffer: TextBuffer) -> void:
	if not hidden_label or not buffer:
		return

	var raw_bbcode: String = buffer.raw_text
	var result_bbcode: String = ""
	var plain_char_counter: int = 0
	var in_tag: bool = false

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

		if plain_char_counter < buffer.plain_text_ids.size():
			var char_color: Color = ColorIDMapper.get_color_from_index(buffer, plain_char_counter)
			var hex_color: String = ColorIDMapper.to_bbcode_color(char_color)

			if ch == "\n":
				result_bbcode += "\n"
			else:
				result_bbcode += "[color=" + hex_color + "][bgcolor=" + hex_color + "]" + ch + "[/bgcolor][/color]"

			plain_char_counter += 1
		else:
			result_bbcode += ch

		i += 1

	hidden_label.text = result_bbcode


## Decodes mouse position in viewport to corresponding plain text character index
func get_plain_index_at_position(pos: Vector2) -> int:
	var tex: ViewportTexture = get_texture()
	if not tex or not text_buffer:
		return -1

	var img: Image = tex.get_image()
	if not img:
		return -1

	var img_size: Vector2i = img.get_size()
	var px: int = clampi(int(pos.x), 0, img_size.x - 1)
	var py: int = clampi(int(pos.y), 0, img_size.y - 1)

	var sampled_color: Color = img.get_pixel(px, py)
	return ColorIDMapper.get_index_from_color(text_buffer, sampled_color)
