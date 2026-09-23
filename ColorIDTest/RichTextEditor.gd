class_name RichTextEditor
extends Control

@export var visible_label: RichTextLabel
@export var hit_test_viewport: HitTestViewport
@export var overlay: CaretAndSelectionOverlay

var text_buffer: TextBuffer


func _ready() -> void:
	# Initialize data buffer
	text_buffer = TextBuffer.new("[b]Hello[/b] World! Welcome to the [color=#ff0000]BBCode[/color] WYSIWYG editor.")
	
	# Connect and setup sub-components
	if hit_test_viewport:
		hit_test_viewport.setup(text_buffer)
		
	if overlay:
		overlay.visible_label = visible_label
		overlay.hit_test_viewport = hit_test_viewport
		overlay.setup(text_buffer)
		
	if visible_label:
		visible_label.bbcode_enabled = true
		_update_visible_label()
		
		# Connect vertical scrollbar signal for viewport synchronization
		var v_bar = visible_label.get_v_scroll_bar()
		if v_bar:
			v_bar.value_changed.connect(_on_scroll_changed)
			
	text_buffer.text_changed.connect(_on_buffer_text_changed)


## Public API: Sets new raw BBCode string
func set_bbcode(bbcode: String) -> void:
	text_buffer.set_raw_text(bbcode)


## Public API: Returns the underlying raw BBCode string
func get_bbcode() -> String:
	return text_buffer.raw_text


## Public API: Applies a BBCode tag over the active selection range (e.g. "b", "i", "color=#00ff00")
func apply_tag_to_selection(tag: String) -> void:
	if not overlay or not overlay._has_selection():
		return
		
	var start_plain: int = min(overlay.selection_start, overlay.selection_end)
	var end_plain: int = max(overlay.selection_start, overlay.selection_end)
	
	var start_raw: int = text_buffer.plain_to_raw_map[start_plain]
	var end_raw: int = 0
	if end_plain == text_buffer.plain_text.length():
		end_raw = text_buffer.raw_text.length()
	else:
		end_raw = text_buffer.plain_to_raw_map[end_plain]
		
	# Extract base tag name for closing tag (e.g., "color=#ff0000" -> "color")
	var tag_name: String = tag.split("=")[0]
	var open_tag: String = "[" + tag + "]"
	var close_tag: String = "[/" + tag_name + "]"
	
	# Insert closing tag first, then opening tag to preserve relative offsets
	text_buffer.raw_text = text_buffer.raw_text.insert(end_raw, close_tag)
	text_buffer.raw_text = text_buffer.raw_text.insert(start_raw, open_tag)
	
	text_buffer.rebuild_id_mappings()


func _on_buffer_text_changed() -> void:
	_update_visible_label()


func _update_visible_label() -> void:
	if visible_label:
		visible_label.text = text_buffer.raw_text


func _on_scroll_changed(_value: float) -> void:
	if not visible_label or not hit_test_viewport:
		return
		
	var v_val: int = 0
	var v_bar = visible_label.get_v_scroll_bar()
	
	if v_bar:
		v_val = int(v_bar.value)
		
	hit_test_viewport.sync_scroll(v_val)
