class_name Club
extends RefCounted
## A fictional club: its league, strength, budget tier, crest and stated needs.

const SHAPES: Array[String] = ["shield", "circle", "hexagon", "diamond"]
const PATTERNS: Array[String] = ["plain", "stripes", "halves", "band", "chevron"]

var id: String = ""
var name: String = ""
var league_id: String = ""
## 1..99, comparable with player overall ratings.
var strength: float = 0.0
## Key into career_rules.json "budgets".
var budget: String = ""
## Minimum trial score to join this club's youth team at the trial age.
var youth_intake_min: float = 0.0
var crest_shape: String = "shield"
var crest_pattern: String = "plain"
var crest_primary: Color = Color.WHITE
var crest_secondary: Color = Color.BLACK
var needs: Array[ClubNeed] = []


## Up to three capital letters from the name, for the crest ("Mistral City" -> "MC").
func initials() -> String:
	var letters := ""
	for word: String in name.split(" ", false):
		letters += word.substr(0, 1).to_upper()
	return letters.substr(0, 3)


static func from_dict(data: Dictionary) -> Club:
	var club := Club.new()
	club.id = data["id"]
	club.name = data["name"]
	club.league_id = data["league"]
	club.strength = float(data["strength"])
	club.budget = data["budget"]
	club.youth_intake_min = float(data["youth_intake_min"])
	var crest: Dictionary = data["crest"]
	club.crest_shape = crest["shape"]
	club.crest_pattern = crest["pattern"]
	club.crest_primary = Color.html(crest["primary"])
	club.crest_secondary = Color.html(crest["secondary"])
	for need: Dictionary in data["needs"]:
		club.needs.append(ClubNeed.from_dict(need))
	return club
