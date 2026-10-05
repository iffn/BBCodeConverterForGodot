class_name BBCodeUtility
extends RefCounted

## Utility class providing stateless BBCode string manipulation and tag logic.


## Toggles a tag on a raw text string given a selection range.
## Returns a Dictionary with keys: "new_text", "selection_start", "selection_end".
static func toggle_tag(
	full_text: String,
	has_selection: bool,
	sel_start: int,
	selected_text: String,
	encase: String
) -> Dictionary:
	var open_tag: String = "[" + encase + "]"
	var close_tag: String = "[/" + encase + "]"

	if not has_selection:
		return _toggle_tag_at_caret(full_text, sel_start, encase, open_tag, close_tag)

	var sel_end: int = sel_start + selected_text.length()

	# Case 1: Selection starts and ends with the exact tag pair -> strip edge tags
	if (
		selected_text.begins_with(open_tag)
		and selected_text.ends_with(close_tag)
		and selected_text.length() >= open_tag.length() + close_tag.length()
	):
		return _strip_edge_tags(full_text, sel_start, selected_text, open_tag, close_tag)

	# Case 2: Tags sit immediately adjacent to selection bounds -> strip adjacent tags
	var has_open_before: bool = (
		sel_start >= open_tag.length()
		and full_text.substr(sel_start - open_tag.length(), open_tag.length()) == open_tag
	)
	var has_close_after: bool = (
		sel_end + close_tag.length() <= full_text.length()
		and full_text.substr(sel_end, close_tag.length()) == close_tag
	)
	if has_open_before and has_close_after:
		return _strip_adjacent_tags(full_text, sel_start, sel_end, selected_text, open_tag, close_tag)

	# Case 3: Matching tag pair exists INSIDE selection -> strip inner tags & wrap whole selection
	if selected_text.contains(open_tag) and selected_text.contains(close_tag):
		return _strip_inner_and_wrap(full_text, sel_start, selected_text, encase, open_tag, close_tag)

	# Case 4: Selection is enclosed by or outside active tags -> invert or wrap
	return _close_and_reopen_around(full_text, sel_start, selected_text, encase, open_tag, close_tag)


## Wraps or unwraps selected line ranges in [ul] list tags.
## Returns a Dictionary with keys: "new_text", "selection_start", "selection_end".
static func add_list_layer(
	full_text: String,
	has_selection: bool,
	sel_start: int,
	sel_end: int
) -> Dictionary:
	var open_tag: String = "[ul]"
	var close_tag: String = "[/ul]"

	if not has_selection:
		var line_start: int = full_text.rfind("\n", max(0, sel_start - 1))
		line_start = 0 if line_start == -1 else line_start + 1
		var line_end: int = full_text.find("\n", sel_start)
		line_end = full_text.length() if line_end == -1 else line_end
		sel_start = line_start
		sel_end = line_end
	else:
		var line_start: int = full_text.rfind("\n", max(0, sel_start - 1))
		sel_start = 0 if line_start == -1 else line_start + 1

		var line_end: int = full_text.find("\n", sel_end)
		sel_end = full_text.length() if line_end == -1 else line_end

	# Check if already wrapped in [ul] adjacent to expanding line bounds
	var has_open_before: bool = (
		sel_start >= open_tag.length() + 1
		and full_text.substr(sel_start - open_tag.length() - 1, open_tag.length() + 1) == open_tag + "\n"
	)
	var has_close_after: bool = (
		sel_end + close_tag.length() + 1 <= full_text.length()
		and full_text.substr(sel_end, close_tag.length() + 1) == "\n" + close_tag
	)

	if has_open_before and has_close_after:
		var new_text: String = full_text.erase(sel_end, close_tag.length() + 1)
		new_text = new_text.erase(sel_start - open_tag.length() - 1, open_tag.length() + 1)
		var new_start: int = sel_start - open_tag.length() - 1
		return {
			"new_text": new_text,
			"selection_start": new_start,
			"selection_end": new_start + (sel_end - sel_start)
		}

	# Insert list wrapper around target range
	var result: String = full_text.insert(sel_end, "\n" + close_tag)
	result = result.insert(sel_start, open_tag + "\n")
	var new_sel_start: int = sel_start + open_tag.length() + 1

	return {
		"new_text": result,
		"selection_start": new_sel_start,
		"selection_end": new_sel_start + (sel_end - sel_start)
	}


## Checks whether index character position falls inside an unclosed tag.
## Ignores escaped brackets (\x5b and \x5d).
static func within_tag(index: int, text: String, element: String) -> bool:
	var open_tag: String = "[" + element + "]"
	var close_tag: String = "[/" + element + "]"

	var i: int = index - 1
	while i >= 0:
		if text[i] == "]" and (i == 0 or text[i - 1] != "\\"):
			var close_start: int = i - close_tag.length() + 1
			if close_start >= 0 and text.substr(close_start, close_tag.length()) == close_tag:
				return false

			var open_start: int = i - open_tag.length() + 1
			if open_start >= 0 and text.substr(open_start, open_tag.length()) == open_tag:
				return true
		i -= 1

	return false


static func _toggle_tag_at_caret(
	full_text: String,
	caret_pos: int,
	encase: String,
	open_tag: String,
	close_tag: String
) -> Dictionary:
	var is_within: bool = within_tag(caret_pos, full_text, encase)
	var insert_text: String = close_tag + open_tag if is_within else open_tag + close_tag
	var new_text: String = full_text.insert(caret_pos, insert_text)
	var first_tag: String = close_tag if is_within else open_tag
	var caret: int = caret_pos + first_tag.length()

	return {
		"new_text": new_text,
		"selection_start": caret,
		"selection_end": caret
	}


static func _strip_edge_tags(
	full_text: String,
	sel_start: int,
	selected_text: String,
	open_tag: String,
	close_tag: String
) -> Dictionary:
	var stripped: String = selected_text.substr(
		open_tag.length(),
		selected_text.length() - open_tag.length() - close_tag.length()
	)
	var new_text: String = full_text.erase(sel_start, selected_text.length()).insert(sel_start, stripped)

	return {
		"new_text": new_text,
		"selection_start": sel_start,
		"selection_end": sel_start + stripped.length()
	}


static func _strip_adjacent_tags(
	full_text: String,
	sel_start: int,
	sel_end: int,
	selected_text: String,
	open_tag: String,
	close_tag: String
) -> Dictionary:
	var new_text: String = full_text.erase(sel_end, close_tag.length()).erase(sel_start - open_tag.length(), open_tag.length())
	var new_start: int = sel_start - open_tag.length()

	return {
		"new_text": new_text,
		"selection_start": new_start,
		"selection_end": new_start + selected_text.length()
	}


static func _strip_inner_and_wrap(
	full_text: String,
	sel_start: int,
	selected_text: String,
	_encase: String,
	open_tag: String,
	close_tag: String
) -> Dictionary:
	var inner_stripped: String = selected_text.replace(open_tag, "").replace(close_tag, "")
	var wrapped: String = open_tag + inner_stripped + close_tag
	var new_text: String = full_text.erase(sel_start, selected_text.length()).insert(sel_start, wrapped)
	var inner_start: int = sel_start + open_tag.length()

	return {
		"new_text": new_text,
		"selection_start": inner_start,
		"selection_end": inner_start + inner_stripped.length()
	}


static func _close_and_reopen_around(
	full_text: String,
	sel_start: int,
	selected_text: String,
	encase: String,
	open_tag: String,
	close_tag: String
) -> Dictionary:
	var is_inside: bool = within_tag(sel_start, full_text, encase)
	var modified_text: String = (
		close_tag + selected_text + open_tag
		if is_inside
		else open_tag + selected_text + close_tag
	)
	var new_text: String = full_text.erase(sel_start, selected_text.length()).insert(sel_start, modified_text)
	var lead_tag: String = close_tag if is_inside else open_tag
	var final_start: int = sel_start + lead_tag.length()

	return {
		"new_text": new_text,
		"selection_start": final_start,
		"selection_end": final_start + selected_text.length()
	}
