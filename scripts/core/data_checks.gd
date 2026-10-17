class_name DataChecks
extends RefCounted
## Shared helpers for validating JSON data files with readable messages.


static func is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


## Appends "<prefix><key> must be a number" and returns false if data[key] is not numeric.
static func require_number(
	data: Dictionary, key: String, prefix: String, problems: Array[String]
) -> bool:
	if not is_number(data.get(key)):
		problems.append("%s%s must be a number" % [prefix, key])
		return false
	return true


## `schema` maps section name -> Array of keys that must be numbers in that section.
static func require_number_sections(
	data: Dictionary, schema: Dictionary, problems: Array[String]
) -> void:
	for section: String in schema:
		if typeof(data.get(section)) != TYPE_DICTIONARY:
			problems.append("%s must be an object" % section)
			continue
		var values: Dictionary = data[section]
		for key: String in schema[section]:
			require_number(values, key, section + ".", problems)
