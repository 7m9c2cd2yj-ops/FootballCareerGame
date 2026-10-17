class_name AgeTable
extends RefCounted
## A table of age brackets from JSON rows like
## {"from_age": 8, "to_age": 12, "<value_key>": 4.0}. Rows must be sorted,
## contiguous and cover first_age..last_age exactly; lookups outside the
## range use the nearest bracket, so they never fail.

var _first_age: int = 0
var _last_age: int = 0
var _from: Array[int] = []
var _to: Array[int] = []
var _values: Array[float] = []


## Checks data[key]; appends readable problems.
static func validate(
	data: Dictionary,
	key: String,
	value_key: String,
	first_age: int,
	last_age: int,
	problems: Array[String]
) -> void:
	var raw_rows: Variant = data.get(key)
	if typeof(raw_rows) != TYPE_ARRAY:
		problems.append("%s must be an array" % key)
		return
	var rows: Array = raw_rows
	if rows.is_empty():
		problems.append("%s must not be empty" % key)
		return
	var next_age := first_age
	for row: Variant in rows:
		if typeof(row) != TYPE_DICTIONARY:
			problems.append("%s rows must be objects" % key)
			return
		var fields: Dictionary = row
		for field: String in ["from_age", "to_age", value_key]:
			if not DataChecks.require_number(fields, field, key + ".", problems):
				return
		if int(fields["from_age"]) != next_age or int(fields["to_age"]) < next_age:
			problems.append("%s has a gap or overlap at age %d" % [key, next_age])
			return
		next_age = int(fields["to_age"]) + 1
	if next_age != last_age + 1:
		problems.append("%s must end exactly at age %d" % [key, last_age])


## Builds a table from rows that passed `validate`.
static func from_rows(rows: Array, value_key: String) -> AgeTable:
	var table := AgeTable.new()
	for row: Dictionary in rows:
		table._from.append(int(row["from_age"]))
		table._to.append(int(row["to_age"]))
		table._values.append(float(row[value_key]))
	table._first_age = table._from[0]
	table._last_age = table._to[-1]
	return table


func value_at(age: int) -> float:
	var clamped := clampi(age, _first_age, _last_age)
	for i: int in _values.size():
		if clamped >= _from[i] and clamped <= _to[i]:
			return _values[i]
	return _values[-1]
