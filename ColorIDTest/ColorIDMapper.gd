class_name ColorIDMapper
extends RefCounted

const MAX_SECTORS: int = 256
const MAX_BASES: int = 256
const MAX_EXTENSIONS: int = 256

# Capacity per sector chunk (256 characters per sector)
const SECTOR_CHUNK_SIZE: int = 256

# Legacy compatibility constants
const BASE_CHARS_PER_SECTOR: int = 256
const EXT_CHARS_PER_SECTOR: int = 256
const MAX_TOTAL_CHARS: int = 16777216 # 256 * 256 * 256


## INTERFACE 1: Pass a character index, get the encoded Color
static func get_color_from_index(buffer: TextBuffer, plain_index: int) -> Color:
	if not buffer or plain_index < 0 or plain_index >= buffer.plain_text_ids.size():
		return Color(0, 0, 0, 0)

	var flat_id: int = buffer.plain_text_ids[plain_index]
	var vec_id: Vector3i = from_flat_id(flat_id)
	return encode_sector_id(vec_id.x, vec_id.y, vec_id.z)


## INTERFACE 2: Pass a sampled Color, get the character index
static func get_index_from_color(buffer: TextBuffer, color: Color) -> int:
	if not buffer or color.a < 0.1 or (color.r == 0 and color.g == 0 and color.b == 0):
		return -1

	var vec_id: Vector3i = decode_color(color)
	var flat_id: int = to_flat_id(vec_id)
	return buffer.get_plain_index_from_flat_id(flat_id)


# --- LOW-LEVEL CONVERSIONS ---

static func from_flat_id(flat_id: int) -> Vector3i:
	if flat_id < 0:
		return Vector3i(-1, -1, -1)
		
	var ext: int = flat_id % MAX_EXTENSIONS
	var temp: int = flat_id / MAX_EXTENSIONS
	var base: int = temp % MAX_BASES
	var sector: int = temp / MAX_BASES
	
	return Vector3i(sector, base, ext)


static func to_flat_id(vec_id: Vector3i) -> int:
	if vec_id.x < 0 or vec_id.y < 0 or vec_id.z < 0:
		return -1
	return (vec_id.x * MAX_BASES + vec_id.y) * MAX_EXTENSIONS + vec_id.z


static func encode_sector_id(sector: int, base: int, extension: int) -> Color:
	var r: float = float(clampi(sector, 0, MAX_SECTORS - 1)) / 255.0
	var g: float = float(clampi(base, 0, MAX_BASES - 1)) / 255.0
	var b: float = float(clampi(extension, 0, MAX_EXTENSIONS - 1)) / 255.0
	return Color(r, g, b, 1.0)


static func decode_color(color: Color) -> Vector3i:
	var sector: int = roundi(color.r * 255.0)
	var base: int = roundi(color.g * 255.0)
	var extension: int = roundi(color.b * 255.0)
	return Vector3i(sector, base, extension)


static func to_bbcode_color(color: Color) -> String:
	return "#" + color.to_html(false)
