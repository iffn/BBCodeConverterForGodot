class_name ColorIDMapper
extends RefCounted

# Dimensions for packing Vector3i (sector, base, extension) into a single integer flat ID
const MAX_SECTORS: int = 256
const MAX_BASES: int = 256
const MAX_EXTENSIONS: int = 256

# Capacity constants required by TextBuffer.gd
const BASE_CHARS_PER_SECTOR: int = 65536 # 256 * 256
const EXT_CHARS_PER_SECTOR: int = 65536  # 256 * 256
const MAX_TOTAL_CHARS: int = 16777216    # 256 * 256 * 256

## Converts a flat integer ID into a 3D Vector3i ID (sector, base, extension)
static func from_flat_id(flat_id: int) -> Vector3i:
	if flat_id < 0:
		return Vector3i(-1, -1, -1)
		
	var ext: int = flat_id % MAX_EXTENSIONS
	var temp: int = flat_id / MAX_EXTENSIONS
	var base: int = temp % MAX_BASES
	var sector: int = temp / MAX_BASES
	
	return Vector3i(sector, base, ext)


## Converts a 3D Vector3i ID into a unique flat integer ID
static func to_flat_id(vec_id: Vector3i) -> int:
	if vec_id.x < 0 or vec_id.y < 0 or vec_id.z < 0:
		return -1
	return (vec_id.x * MAX_BASES + vec_id.y) * MAX_EXTENSIONS + vec_id.z


## Encodes sector, base, and extension into a unique RGB Color
static func encode_sector_id(sector: int, base: int, extension: int) -> Color:
	var r: float = float(clampi(sector, 0, MAX_SECTORS - 1)) / 255.0
	var g: float = float(clampi(base, 0, MAX_BASES - 1)) / 255.0
	var b: float = float(clampi(extension, 0, MAX_EXTENSIONS - 1)) / 255.0
	return Color(r, g, b, 1.0)


## Decodes an RGB Color back into a 3D Vector3i ID
static func decode_color(color: Color) -> Vector3i:
	var sector: int = roundi(color.r * 255.0)
	var base: int = roundi(color.g * 255.0)
	var extension: int = roundi(color.b * 255.0)
	return Vector3i(sector, base, extension)


## Formats a Color into a 6-digit hex string (#RRGGBB) for BBCode
static func to_bbcode_color(color: Color) -> String:
	return "#" + color.to_html(false)
