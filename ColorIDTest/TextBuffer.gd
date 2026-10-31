class_name TextBuffer
extends RefCounted

## ============================================================================
## * Stores the current state of the text
## * Provides the text with and without formatting tags
## * Provides functions for text editing
## * Optimized for fast read, slow write
## ============================================================================

signal text_changed

# Raw text including invisible BBCode tags
var raw_text: String = ""

# Stripped plain text displayed on screen
var plain_text: String = ""

# Parallel array to plain_text: plain_text_ids[i] stores the flat integer ID for plain_text[i]
var plain_text_ids: Array[int] = []

# Map: flat_id -> plain_text_index
var flat_id_to_plain_index: Dictionary = {}

# Parallel mapping: plain_index -> raw_index
var plain_to_raw_map: Array[int] = []


func _init(initial_text: String = "") -> void:
	if not initial_text.is_empty():
		set_raw_text(initial_text)


## Sets new raw text and performs a full chunk allocation pass
func set_raw_text(new_raw: String) -> void:
	raw_text = new_raw
	rebuild_id_mappings()


## Re-indexes the text buffer using sector chunks
func rebuild_id_mappings() -> void:
	plain_text = ""
	plain_text_ids.clear()
	flat_id_to_plain_index.clear()
	plain_to_raw_map.clear()

	var in_tag: bool = false
	var raw_len: int = raw_text.length()
	var plain_idx: int = 0
	var i: int = 0

	while i < raw_len:
		var ch: String = raw_text[i]

		# Handle escaped brackets (e.g., \[ or \])
		if ch == "\\" and i + 1 < raw_len and raw_text[i + 1] in ["[", "]"]:
			if not in_tag:
				plain_text += raw_text[i + 1]
				_append_index_mapping(plain_idx, i + 1)
				plain_idx += 1
			i += 2
			continue

		if ch == "[":
			in_tag = true
			i += 1
			continue
		elif ch == "]":
			in_tag = false
			i += 1
			continue

		if not in_tag:
			plain_text += ch
			_append_index_mapping(plain_idx, i)
			plain_idx += 1

		i += 1

	text_changed.emit()


func _append_index_mapping(plain_idx: int, raw_idx: int) -> void:
	var flat_id: int = plain_idx

	plain_text_ids.append(flat_id)
	flat_id_to_plain_index[flat_id] = plain_idx
	plain_to_raw_map.append(raw_idx)


## Safely translates a plain-text index to its raw-text index counterpart
func plain_to_raw_index(plain_idx: int) -> int:
	if plain_idx <= 0:
		return 0
	if plain_idx >= plain_text.length():
		return raw_text.length()
	return plain_to_raw_map[plain_idx]


## Safely translates a raw-text index to a plain-text index
func raw_to_plain_index(raw_idx: int) -> int:
	if raw_idx <= 0:
		return 0
	for i in range(plain_to_raw_map.size()):
		if plain_to_raw_map[i] >= raw_idx:
			return i
	return plain_text.length()


## Inserts text at a specific plain-text index and updates chunk mappings
func insert_text_at_plain_index(plain_index: int, new_text: String) -> void:
	if plain_index < 0 or plain_index > plain_text.length():
		return

	var target_raw_index: int = plain_to_raw_index(plain_index)
	raw_text = raw_text.insert(target_raw_index, new_text)
	rebuild_id_mappings()


## Deletes a range of characters specified by plain-text indices
func delete_plain_range(start_plain: int, end_plain: int) -> void:
	if start_plain < 0 or end_plain > plain_text.length() or start_plain >= end_plain:
		return

	var start_raw: int = plain_to_raw_index(start_plain)
	var end_raw: int = plain_to_raw_index(end_plain)

	raw_text = raw_text.erase(start_raw, end_raw - start_raw)
	rebuild_id_mappings()


## Applies or removes a BBCode tag over a given plain-text index range.
## Returns a Vector2i containing the updated plain-text selection bounds (start, end).
func toggle_tag_on_range(start_plain: int, end_plain: int, tag: String) -> Vector2i:
	var start_raw: int = plain_to_raw_index(start_plain)
	var end_raw: int = plain_to_raw_index(end_plain)
	var has_selection: bool = start_plain != end_plain
	var selected_length: int = end_raw - start_raw

	var result: Dictionary = BBCodeUtility.toggle_tag(
		raw_text,
		has_selection,
		start_raw,
		selected_length,
		tag
	)

	raw_text = result["new_text"]
	rebuild_id_mappings()

	var new_start_plain: int = raw_to_plain_index(result["selection_start"])
	var new_end_plain: int = raw_to_plain_index(result["selection_end"])
	return Vector2i(new_start_plain, new_end_plain)


## Wraps or unwraps selected lines in [ul] tags.
## Returns a Vector2i containing the updated plain-text selection bounds (start, end).
func add_list_layer(start_plain: int, end_plain: int) -> Vector2i:
	var start_raw: int = plain_to_raw_index(start_plain)
	var end_raw: int = plain_to_raw_index(end_plain)
	var has_selection: bool = start_plain != end_plain

	var result: Dictionary = BBCodeUtility.add_list_layer(
		raw_text,
		has_selection,
		start_raw,
		end_raw
	)

	raw_text = result["new_text"]
	rebuild_id_mappings()

	var new_start_plain: int = raw_to_plain_index(result["selection_start"])
	var new_end_plain: int = raw_to_plain_index(result["selection_end"])
	return Vector2i(new_start_plain, new_end_plain)


## Returns a list of active BBCode tag names enclosing the specified plain-text index
func get_active_tags_at_index(plain_idx: int) -> Array[String]:
	var active_tags: Array[String] = []
	if plain_idx < 0 or plain_idx > plain_text.length():
		return active_tags

	var raw_idx: int = plain_to_raw_index(plain_idx)
	var tag_stack: Array[String] = []

	var regex := RegEx.new()
	regex.compile("\\[(/?)([a_zA-Z0-9_]+)(?:=[^\\]]+)?\\]")

	for result in regex.search_all(raw_text.substr(0, raw_idx)):
		var is_close: bool = result.get_string(1) == "/"
		var tag_name: String = result.get_string(2)

		if not is_close:
			tag_stack.append(tag_name)
		else:
			var last_idx: int = tag_stack.rfind(tag_name)
			if last_idx != -1:
				tag_stack.remove_at(last_idx)

	for tag_item in tag_stack:
		if not active_tags.has(tag_item):
			active_tags.append(tag_item)

	return active_tags


## Translates a flat character ID directly into its plain-text index
func get_plain_index_from_flat_id(flat_id: int) -> int:
	if flat_id_to_plain_index.has(flat_id):
		return flat_id_to_plain_index[flat_id]
	return -1
