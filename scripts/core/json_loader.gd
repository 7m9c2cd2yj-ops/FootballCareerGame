class_name JsonLoader
extends RefCounted
## Reads JSON data files (clubs, balance tables, templates) into dictionaries.
## Pure logic: no scene-tree access, safe to call from headless tests.


## Outcome of a load. On failure `data` is empty and `error` describes why.
class LoadResult:
	extends RefCounted
	var data: Dictionary = {}
	var error: String = ""

	func is_ok() -> bool:
		return error.is_empty()


## Loads `path` and requires the top-level JSON value to be an object.
static func load_dictionary(path: String) -> LoadResult:
	if not FileAccess.file_exists(path):
		var missing := LoadResult.new()
		missing.error = "File not found: %s" % path
		return missing
	return parse_dictionary(FileAccess.get_file_as_string(path), path)


## Parses `text`; `source` is only used to make error messages traceable.
static func parse_dictionary(text: String, source: String) -> LoadResult:
	var result := LoadResult.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		# get_error_line() is 0-based; report 1-based lines like text editors do.
		var line := json.get_error_line() + 1
		result.error = "%s: line %d: %s" % [source, line, json.get_error_message()]
	elif typeof(json.data) != TYPE_DICTIONARY:
		result.error = "%s: top-level JSON value must be an object" % source
	else:
		result.data = json.data
	return result
