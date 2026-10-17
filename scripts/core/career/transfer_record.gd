class_name TransferRecord
extends RefCounted
## A move between clubs, kept in the career history (shown in news in M5).

var season_number: int = 0
var from_club: String = ""
var to_club: String = ""
## Release-clause fee paid by the new club; 0 for free moves and trials.
var fee: int = 0
var wage: int = 0


func to_dict() -> Dictionary:
	return {
		"season_number": season_number,
		"from_club": from_club,
		"to_club": to_club,
		"fee": fee,
		"wage": wage,
	}


static func validate_dict(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in ["season_number", "fee", "wage"]:
		if not DataChecks.is_number(data.get(key)):
			problems.append("transfer.%s must be a number" % key)
	for key: String in ["from_club", "to_club"]:
		if typeof(data.get(key)) != TYPE_STRING:
			problems.append("transfer.%s must be a string" % key)
	return problems


static func from_dict(data: Dictionary) -> TransferRecord:
	var record := TransferRecord.new()
	record.season_number = int(data["season_number"])
	record.from_club = data["from_club"]
	record.to_club = data["to_club"]
	record.fee = int(data["fee"])
	record.wage = int(data["wage"])
	return record
