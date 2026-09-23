class_name TextBuffer
extends RefCounted

signal text_changed

# Raw text including invisible BBCode tags
var raw_text: String = ""

# Stripped plain text displayed on screen
var plain_text: String = ""

# Parallel array to plain_text: plain_text_ids[i] stores the flat integer ID for plain_text[i]
var plain_text_ids: Array[int] = []

# Map: flat_id -> raw_string_index (for quick lookup during hit testing)
var id_to_raw_index: Dictionary = {}

# Parallel mapping: plain_index -> raw_index
var plain_to_raw_map: Array[int] = []

# Sector management state
var active_sectors: Array[Dictionary] = [] # Array of sector tracking dicts
var current_sector_index: int = 0


func _init(initial_text: String = "") -> void:
	_reset_sector_pool()
	if not initial_text.is_empty():
		set_raw_text(initial_text)


## Resets and initializes the sector ID pool
func _reset_sector_pool() -> void:
	active_sectors.clear()
	current_sector_index = 0
	_allocate_new_sector()


func _allocate_new_sector() -> void:
	if active_sectors.size() >= ColorIDMapper.MAX_SECTORS:
		# Fallback: if all sectors are full, re-index the entire document
		rebuild_id_mappings()
		return

	active_sectors.append({
		"next_base_id": 0,
		"next_ext_id": 0,
		"is_ext_active": false
	})
	current_sector_index = active_sectors.size() - 1


## Allocates a new unique character ID tuple Vector3i(sector, base, ext)
func _allocate_char_id() -> Vector3i:
	var sec: Dictionary = active_sectors[current_sector_index]
	
	if not sec["is_ext_active"]:
		if sec["next_base_id"] < ColorIDMapper.BASE_CHARS_PER_SECTOR:
			var id := Vector3i(current_sector_index, sec["next_base_id"], 0)
			sec["next_base_id"] += 1
			return id
		else:
			# Base pool full; switch to extension pool for insertions in this sector
			sec["is_ext_active"] = true
			
	if sec["next_ext_id"] < ColorIDMapper.EXT_CHARS_PER_SECTOR:
		var id := Vector3i(current_sector_index, 0, sec["next_ext_id"])
		sec["next_ext_id"] += 1
		return id
	
	# Current sector is completely exhausted; allocate a new sector
	_allocate_new_sector()
	return _allocate_char_id()


## Sets new raw text and performs a full parse/re-indexing pass
func set_raw_text(new_raw: String) -> void:
	raw_text = new_raw
	rebuild_id_mappings()


## Re-indexes the raw text, builds plain text, and assigns fresh sector IDs
func rebuild_id_mappings() -> void:
	_reset_sector_pool()
	plain_text = ""
	plain_text_ids.clear()
	id_to_raw_index.clear()
	plain_to_raw_map.clear()
	
	var in_tag: bool = false
	var raw_len: int = raw_text.length()
	var plain_idx: int = 0
	
	for raw_idx in range(raw_len):
		var char: String = raw_text[raw_idx]
		
		if char == "[":
			in_tag = true
			continue
		elif char == "]":
			in_tag = false
			continue
			
		if not in_tag:
			plain_text += char
			var vec_id := _allocate_char_id()
			var flat_id := ColorIDMapper.to_flat_id(vec_id)
			
			plain_text_ids.append(flat_id)
			id_to_raw_index[flat_id] = raw_idx
			plain_to_raw_map.append(raw_idx)
			plain_idx += 1
			
	text_changed.emit()


## Inserts text at a specific plain-text index without re-indexing untouched characters
func insert_text_at_plain_index(plain_index: int, new_text: String) -> void:
	if plain_index < 0 or plain_index > plain_text.length():
		return
		
	var target_raw_index: int = 0
	if plain_index == plain_text.length():
		target_raw_index = raw_text.length()
	else:
		target_raw_index = plain_to_raw_map[plain_index]
		
	# Insert into raw string
	raw_text = raw_text.insert(target_raw_index, new_text)
	
	# Assign new sector IDs for inserted characters
	var inserted_ids: Array[int] = []
	for i in range(new_text.length()):
		var vec_id := _allocate_char_id()
		inserted_ids.append(ColorIDMapper.to_flat_id(vec_id))
		
	# Update plain text buffers locally
	plain_text = plain_text.insert(plain_index, new_text)
	
	for i in range(inserted_ids.size()):
		plain_text_ids.insert(plain_index + i, inserted_ids[i])
		
	# Re-sync mapping offsets
	_sync_raw_mapping_offsets()
	text_changed.emit()


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
		
	# Erase from raw text
	raw_text = raw_text.erase(start_raw, end_raw - start_raw)
	
	# Erase from plain text buffers
	plain_text = plain_text.erase(start_plain, end_plain - start_plain)
	
	for i in range(end_plain - 1, start_plain - 1, -1):
		var flat_id: int = plain_text_ids[i]
		id_to_raw_index.erase(flat_id)
		plain_text_ids.remove_at(i)
		
	_sync_raw_mapping_offsets()
	text_changed.emit()


## Re-synchronizes plain_to_raw_map and id_to_raw_index after insertions or deletions
func _sync_raw_mapping_offsets() -> void:
	plain_to_raw_map.clear()
	id_to_raw_index.clear()
	
	var in_tag: bool = false
	var plain_idx: int = 0
	var raw_len: int = raw_text.length()
	
	for raw_idx in range(raw_len):
		var char: String = raw_text[raw_idx]
		if char == "[":
			in_tag = true
			continue
		elif char == "]":
			in_tag = false
			continue
			
		if not in_tag:
			if plain_idx < plain_text_ids.size():
				var flat_id: int = plain_text_ids[plain_idx]
				id_to_raw_index[flat_id] = raw_idx
				plain_to_raw_map.append(raw_idx)
				plain_idx += 1


## Translates a flat character ID sampled from the SubViewport into a plain-text index
func get_plain_index_from_flat_id(flat_id: int) -> int:
	if flat_id < 0:
		return -1
	return plain_text_ids.find(flat_id)
