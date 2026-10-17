class_name EventText
extends RefCounted
## Turns the career's event log into the phone's News items, agent Messages and
## Kickfie posts, by filling templates from data/text_templates.json. Templates
## for the same variant are used in rotation (1st, 2nd, 3rd... occurrence), so
## stories do not repeat back to back; fan handles and likes come from Variety.
## The same career always reads the same.

const SALT_HANDLE := 24
const SALT_LIKES := 25
const POSTS_PER_EVENT := 2
const MILLION := 1000.0


class NewsItem:
	extends RefCounted
	var season_number: int = 0
	var headline: String = ""
	var body: String = ""


class KickfiePost:
	extends RefCounted
	var season_number: int = 0
	var handle: String = ""
	var text: String = ""
	var likes: int = 0


## Newest first.
static func news_feed(
	career: CareerState, world: ClubWorld, labels: GameLabels, templates: TextTemplates
) -> Array[NewsItem]:
	var items: Array[NewsItem] = []
	var turns := _occurrences(career, templates)
	for index: int in range(career.events.size() - 1, -1, -1):
		var event := career.events[index]
		var key := variant_key(event, templates)
		var options := templates.templates_for("news", key)
		var chosen: Dictionary = options[turns[index] % options.size()]
		var values := placeholders(event, career, world, labels)
		var item := NewsItem.new()
		item.season_number = event.season_number
		item.headline = str(chosen["headline"]).format(values)
		item.body = str(chosen["body"]).format(values)
		items.append(item)
	return items


## Agent texts about past events, newest first (not every event gets one).
static func agent_messages(
	career: CareerState, world: ClubWorld, labels: GameLabels, templates: TextTemplates
) -> Array[String]:
	var messages: Array[String] = []
	var turns := _occurrences(career, templates)
	for index: int in range(career.events.size() - 1, -1, -1):
		var event := career.events[index]
		var options := templates.templates_for("agent", variant_key(event, templates))
		if not options.is_empty():
			var text: String = options[turns[index] % options.size()]
			messages.append(text.format(placeholders(event, career, world, labels)))
	return messages


## Fan posts, newest first: up to POSTS_PER_EVENT different posts per event.
static func kickfie_feed(
	career: CareerState, world: ClubWorld, labels: GameLabels, templates: TextTemplates
) -> Array[KickfiePost]:
	var posts: Array[KickfiePost] = []
	var turns := _occurrences(career, templates)
	for index: int in range(career.events.size() - 1, -1, -1):
		var event := career.events[index]
		var options := templates.templates_for("kickfie", variant_key(event, templates))
		var values := placeholders(event, career, world, labels)
		var first := turns[index] * POSTS_PER_EVENT
		for offset: int in mini(POSTS_PER_EVENT, options.size()):
			var post := KickfiePost.new()
			post.season_number = event.season_number
			post.text = str(options[(first + offset) % options.size()]).format(values)
			var handle_index := _pick_index(
				templates.fan_handles.size(), event, index + offset, SALT_HANDLE
			)
			post.handle = templates.fan_handles[handle_index]
			post.likes = _likes(event, index + offset)
			posts.append(post)
	return posts


## "season_played.great", "retirement.inducted" or just the event type.
static func variant_key(event: CareerEvent, templates: TextTemplates) -> String:
	match event.type:
		CareerEvent.SEASON_PLAYED:
			var rating := float(event.values["rating"])
			if rating >= templates.great_rating:
				return "season_played.great"
			if rating < templates.poor_rating:
				return "season_played.poor"
			return "season_played.steady"
		CareerEvent.RETIREMENT:
			var inducted: bool = event.values["inducted"]
			return "retirement.inducted" if inducted else "retirement.not_inducted"
	return event.type


## Display values for every placeholder the event's templates may use.
static func placeholders(
	event: CareerEvent, career: CareerState, world: ClubWorld, labels: GameLabels
) -> Dictionary:
	var values := {
		"player": career.player.display_name,
		"position": labels.position_name(career.player.position),
		"age": str(event.age),
		"season": str(event.season_number),
	}
	for key: Variant in event.values:
		values[key] = _display(str(key), event.values[key], world)
	var club_id := str(event.values.get("club", event.values.get("to_club", "")))
	if world.has_club(club_id):
		values["league"] = world.league_of(club_id).name
		values["club_tag"] = world.club(club_id).name.replace(" ", "")
	return values


## 450 -> "450k credits", 1500 -> "1.5M credits" (money is stored in thousands).
static func money(thousands: float) -> String:
	if thousands >= MILLION:
		return "%.1fM credits" % (thousands / MILLION)
	return "%dk credits" % roundi(thousands)


static func _display(key: String, value: Variant, world: ClubWorld) -> String:
	if CareerEvent.CLUB_FIELDS.has(key):
		return world.club(str(value)).name if world.has_club(str(value)) else str(value)
	if key == "fee" or key == "wage":
		return money(float(value))
	if key == "rating":
		return "%.1f" % float(value)
	if DataChecks.is_number(value):
		return str(roundi(float(value)))
	return str(value)


## For each event, how many earlier events share its variant (0 for the first).
static func _occurrences(career: CareerState, templates: TextTemplates) -> Array[int]:
	var seen: Dictionary[String, int] = {}
	var turns: Array[int] = []
	for event: CareerEvent in career.events:
		var key := variant_key(event, templates)
		turns.append(seen.get(key, 0))
		seen[key] = turns[-1] + 1
	return turns


static func _pick_index(count: int, event: CareerEvent, index: int, salt: int) -> int:
	return int(Variety.unit(event.season_number, index, salt) * count)


## Better players get more likes (uses the overall the event reports, if any).
static func _likes(event: CareerEvent, index: int) -> int:
	var overall := float(event.values.get("overall_after", event.values.get("peak_overall", 50)))
	var base := 40.0 + overall * 6.0
	return roundi(base * (0.5 + Variety.unit(event.season_number, index, SALT_LIKES)))
