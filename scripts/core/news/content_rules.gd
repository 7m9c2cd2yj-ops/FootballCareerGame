class_name ContentRules
extends RefCounted
## Checks for text and names shown to players (young audience, original world).
## Used when loading data and by tests; not exhaustive, a guard against slips.

## Real organisations and clubs our data must never name (lower case).
const REAL_NAMES: Array[String] = [
	"fifa",
	"uefa",
	"conmebol",
	"premier league",
	"la liga",
	"laliga",
	"serie a",
	"bundesliga",
	"ligue 1",
	"eredivisie",
	"champions league",
	"europa league",
	"world cup",
	"ballon",
	"real madrid",
	"barcelona",
	"atletico",
	"manchester",
	"liverpool",
	"chelsea",
	"arsenal",
	"tottenham",
	"bayern",
	"dortmund",
	"juventus",
	"inter milan",
	"ac milan",
	"napoli",
	"paris saint",
	"psg",
	"ajax",
	"benfica",
	"porto",
	"celtic",
	"rangers fc",
	"boca",
	"river plate",
	"santos",
	"flamengo",
	"galaxy",
	"albion",
	"hotspur",
	"olympique",
]
## Links must never reach players without a parental gate.
const LINK_MARKERS: Array[String] = ["http", "www.", ".com", ".net", ".org", "://"]


## Returns a problem description, or "" if `text` is fine.
static func problem_in(text: String) -> String:
	var lower := text.to_lower()
	for marker: String in LINK_MARKERS:
		if lower.contains(marker):
			return "contains a link marker '%s'" % marker
	for real: String in REAL_NAMES:
		if lower.contains(real):
			return "contains the real name '%s'" % real
	return ""
