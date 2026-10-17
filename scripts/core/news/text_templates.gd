class_name TextTemplates
extends RefCounted
## Validated view of data/text_templates.json: news, agent texts, Kickfie posts,
## live advice and preset fan handles. Templates may only use the placeholders
## their event (or advice) provides, and must pass ContentRules.

const DEFAULT_PATH := "res://data/text_templates.json"
## Placeholders every event template may use.
const COMMON: Array[String] = ["player", "position", "age", "season"]
## Extra placeholders for events that name a club.
const CLUB_EXTRAS: Array[String] = ["league", "club_tag"]
## Event types with mood variants instead of a single template list.
const VARIANTS: Dictionary = {
	CareerEvent.SEASON_PLAYED: ["great", "steady", "poor"],
	CareerEvent.RETIREMENT: ["inducted", "not_inducted"],
}
## Advice key -> placeholders it provides (on top of COMMON).
const ADVICE: Dictionary = {
	"fatigue_high": ["fatigue", "threshold"],
	"contract_final_year": ["club"],
	"contract_ended": [],
	"clubs_interested": ["count"],
	"trials_due": [],
	"retirement_option": [],
	"all_quiet": [],
}
const PLACEHOLDER_PATTERN := "\\{([a-z_]+)\\}"

var great_rating: float = 8.0
var poor_rating: float = 5.5
var fan_handles: Array[String] = []
## Section ("news"/"agent"/"kickfie") -> variant key -> list of templates.
var _sections: Dictionary[String, Dictionary] = {}
var _advice: Dictionary[String, Array] = {}


static func load_file(path: String, errors: Array[String]) -> TextTemplates:
	var loaded := JsonLoader.load_dictionary(path)
	if not loaded.is_ok():
		errors.append(loaded.error)
		return null
	var problems := validate(loaded.data)
	if not problems.is_empty():
		for problem: String in problems:
			errors.append("%s: %s" % [path, problem])
		return null
	return from_dictionary(loaded.data)


## Every variant key templates can be written for, e.g. "season_played.great".
static func variant_keys() -> Array[String]:
	var keys: Array[String] = []
	for type: String in CareerEvent.FIELDS:
		if VARIANTS.has(type):
			for variant: String in VARIANTS[type]:
				keys.append("%s.%s" % [type, variant])
		else:
			keys.append(type)
	return keys


## Placeholders allowed in templates for `variant_key`.
static func allowed_placeholders(variant_key: String) -> Array[String]:
	var type := variant_key.get_slice(".", 0)
	var allowed: Array[String] = COMMON.duplicate()
	for field: String in CareerEvent.FIELDS[type]:
		allowed.append(field)
	var fields: Array = CareerEvent.FIELDS[type]
	if fields.has("club") or fields.has("to_club"):
		allowed.append_array(CLUB_EXTRAS)
	return allowed


static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	DataChecks.require_number_sections(
		data, {"thresholds": ["great_rating", "poor_rating"]}, problems
	)
	_validate_handles(data.get("fan_handles"), problems)
	for section: String in ["news", "agent", "kickfie"]:
		if typeof(data.get(section)) != TYPE_DICTIONARY:
			problems.append("%s must be an object" % section)
			continue
		_validate_section(data[section], section, problems)
	if typeof(data.get("advice")) != TYPE_DICTIONARY:
		problems.append("advice must be an object")
	else:
		_validate_advice(data["advice"], problems)
	return problems


static func from_dictionary(data: Dictionary) -> TextTemplates:
	var templates := TextTemplates.new()
	templates.great_rating = float(data["thresholds"]["great_rating"])
	templates.poor_rating = float(data["thresholds"]["poor_rating"])
	templates.fan_handles.assign(data["fan_handles"])
	for section: String in ["news", "agent", "kickfie"]:
		templates._sections[section] = data[section]
	templates._advice.assign(data["advice"])
	return templates


## Templates in `section` for `variant_key`; empty if the section skips it.
func templates_for(section: String, variant_key: String) -> Array:
	return _sections[section].get(variant_key, [])


func advice_for(key: String) -> Array:
	return _advice.get(key, [])


static func _validate_handles(handles: Variant, problems: Array[String]) -> void:
	if not _is_filled_array(handles):
		problems.append("fan_handles must be a non-empty array")
		return
	for handle: Variant in handles:
		if typeof(handle) != TYPE_STRING or not str(handle).begins_with("@"):
			problems.append("fan handle %s must be a string starting with @" % str(handle))
		elif not ContentRules.problem_in(str(handle)).is_empty():
			problems.append("fan handle %s %s" % [handle, ContentRules.problem_in(str(handle))])


static func _validate_section(
	entries: Dictionary, section: String, problems: Array[String]
) -> void:
	var known := variant_keys()
	for key: String in entries:
		if not known.has(key):
			problems.append("%s.%s is not a known event or variant" % [section, key])
			continue
		if not _is_filled_array(entries[key]):
			problems.append("%s.%s must be a non-empty array" % [section, key])
			continue
		for template: Variant in entries[key]:
			for text: String in _texts_of(template, section, key, problems):
				_check_text(text, allowed_placeholders(key), "%s.%s" % [section, key], problems)
	if section == "news":
		for key: String in known:
			if not entries.has(key):
				problems.append("news is missing %s" % key)


## News templates are {headline, body}; the others are plain strings.
static func _texts_of(
	template: Variant, section: String, key: String, problems: Array[String]
) -> Array[String]:
	var texts: Array[String] = []
	if section != "news":
		if typeof(template) == TYPE_STRING:
			texts.append(template)
		else:
			problems.append("%s.%s entries must be strings" % [section, key])
		return texts
	if typeof(template) != TYPE_DICTIONARY:
		problems.append("news.%s entries must be objects" % key)
		return texts
	var item: Dictionary = template
	for part: String in ["headline", "body"]:
		if typeof(item.get(part)) == TYPE_STRING:
			texts.append(item[part])
		else:
			problems.append("news.%s needs a %s string" % [key, part])
	return texts


static func _validate_advice(entries: Dictionary, problems: Array[String]) -> void:
	for key: String in ADVICE:
		if not _is_filled_array(entries.get(key)):
			problems.append("advice.%s must be a non-empty array" % key)
			continue
		var allowed: Array[String] = COMMON.duplicate()
		for placeholder: String in ADVICE[key]:
			allowed.append(placeholder)
		for text: Variant in entries[key]:
			_check_text(str(text), allowed, "advice." + key, problems)


static func _is_filled_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var items: Array = value
	return not items.is_empty()


static func _check_text(
	text: String, allowed: Array[String], label: String, problems: Array[String]
) -> void:
	var content_problem := ContentRules.problem_in(text)
	if not content_problem.is_empty():
		problems.append("%s: '%s' %s" % [label, text, content_problem])
	var pattern := RegEx.create_from_string(PLACEHOLDER_PATTERN)
	for found: RegExMatch in pattern.search_all(text):
		if not allowed.has(found.get_string(1)):
			problems.append("%s: unknown placeholder {%s}" % [label, found.get_string(1)])
