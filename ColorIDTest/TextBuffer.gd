class_name TextBuffer
extends RefCounted

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


## Re-indexes the text buffer using 256-character sector chunks
func rebuild_id_mappings() -> void:
	plain_text = ""
	plain_text_ids.clear()
	flat_id_to_plain_index.clear()
	plain_to_raw_map.clear()
	
	var in_tag: bool = false
	var raw_len: int = raw_text.length()
	var plain_idx: int = 0
	
	for raw_idx in range(raw_len):
		var ch: String = raw_text[raw_idx]
		
		if ch == "[":
			in_tag = true
			continue
		elif ch == "]":
			in_tag = false
			continue
			
		if not in_tag:
			plain_text += ch
			
			# Sector = plain_idx / 256, Offset = plain_idx % 256
			var sector: int = plain_idx / ColorIDMapper.SECTOR_CHUNK_SIZE
			var offset: int = plain_idx % ColorIDMapper.SECTOR_CHUNK_SIZE
			
			var vec_id := Vector3i(sector, offset, 0)
			var flat_id := ColorIDMapper.to_flat_id(vec_id)
			
			plain_text_ids.append(flat_id)
			flat_id_to_plain_index[flat_id] = plain_idx
			plain_to_raw_map.append(raw_idx)
			plain_idx += 1
			
	text_changed.emit()


## Inserts text at a specific plain-text index and updates chunk mappings
func insert_text_at_plain_index(plain_index: int, new_text: String) -> void:
	if plain_index < 0 or plain_index > plain_text.length():
		return
		
	var target_raw_index: int = 0
	if plain_index == plain_text.length():
		target_raw_index = raw_text.length()
	else:
		target_raw_index = plain_to_raw_map[plain_index]
		
	raw_text = raw_text.insert(target_raw_index, new_text)
	rebuild_id_mappings()


## Deletes a range of characters specified by plain-text indices
func delete_plain_range(start_plain: int, end_plain: int) -> void:
	if start_plain < 0 or end_plain > plain_text.length() or start_plain >= end_plain:
		return
		
	var start_raw: int = plain_to_raw_map[start_plain]
	var end_raw: int = 0
	if end_plain == plain_text.length():
		end_raw = raw_text.length()
	else:
		end_raw = plain_to_raw_map[end_plain]
		
	raw_text = raw_text.erase(start_raw, end_raw - start_raw)
	rebuild_id_mappings()


## Translates a flat character ID directly into its plain-text index
func get_plain_index_from_flat_id(flat_id: int) -> int:
	if flat_id_to_plain_index.has(flat_id):
		return flat_id_to_plain_index[flat_id]
	return -1	
