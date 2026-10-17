extends GutTest
## Templates: validation, safe content, every event renders fully, determinism.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")
const NewsFixture := preload("res://tests/helpers/news_fixture.gd")

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules
var _labels: GameLabels
var _templates: TextTemplates
var _context: EventText.Context


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)
	_labels = NewsFixture.labels()
	_templates = NewsFixture.templates()
	_context = EventText.Context.create(_world, CareerFixture.cups(), _labels, _templates)


func _data() -> Dictionary:
	return JsonLoader.load_dictionary(TextTemplates.DEFAULT_PATH).data


func _career_with_every_event() -> CareerState:
	var career := CareerFixture.career_at("MID", 24, 70.0, "tidewell", _balance)
	career.events = NewsFixture.every_event("tidewell", "brackenford")
	return career


func _all_texts(career: CareerState) -> Array[String]:
	var texts: Array[String] = []
	for item: EventText.NewsItem in EventText.news_feed(career, _context):
		texts.append(item.headline)
		texts.append(item.body)
	texts.append_array(EventText.agent_messages(career, _context))
	for post: EventText.KickfiePost in EventText.kickfie_feed(career, _context):
		texts.append(post.handle + " " + post.text)
	return texts


func test_every_event_type_renders_without_leftover_placeholders() -> void:
	var texts := _all_texts(_career_with_every_event())
	assert_gt(texts.size(), 20)
	for text: String in texts:
		assert_false(text.contains("{") or text.contains("}"), text)


func test_names_and_money_are_shown_readably() -> void:
	var texts := "\n".join(_all_texts(_career_with_every_event()))
	assert_string_contains(texts, "Tidewell FC")
	assert_string_contains(texts, "2.5M credits")
	assert_false(texts.contains("tidewell"), "club ids never leak into text")


func test_rendering_is_deterministic() -> void:
	var career := _career_with_every_event()
	assert_eq(_all_texts(career), _all_texts(career))


func test_season_mood_follows_the_rating() -> void:
	var events := NewsFixture.every_event("tidewell", "brackenford")
	assert_eq(EventText.variant_key(events[0], _templates), "season_played.great")
	assert_eq(EventText.variant_key(events[1], _templates), "season_played.steady")
	assert_eq(EventText.variant_key(events[2], _templates), "season_played.poor")


func test_money_format() -> void:
	assert_eq(EventText.money(450), "450k credits")
	assert_eq(EventText.money(1500), "1.5M credits")


func test_unknown_placeholder_is_rejected() -> void:
	var data := _data()
	data["agent"]["milestone"] = ["Your fee is {fee}"]
	assert_string_contains("\n".join(TextTemplates.validate(data)), "{fee}")


func test_links_are_rejected() -> void:
	var data := _data()
	data["kickfie"]["injury"] = ["Get well soon! www.example.com"]
	assert_string_contains("\n".join(TextTemplates.validate(data)), "link")


func test_real_names_are_rejected() -> void:
	var data := _data()
	var handles: Array = data["fan_handles"]
	handles.append("@ManchesterFan")
	assert_string_contains("\n".join(TextTemplates.validate(data)), "real name")


func test_every_variant_needs_news() -> void:
	var data := _data()
	var news: Dictionary = data["news"]
	news.erase("renewal")
	assert_string_contains("\n".join(TextTemplates.validate(data)), "news is missing renewal")


func test_unknown_event_key_is_rejected() -> void:
	var data := _data()
	data["kickfie"]["dragon_attack"] = ["Run!"]
	assert_string_contains("\n".join(TextTemplates.validate(data)), "dragon_attack")


func test_content_rules() -> void:
	assert_eq(ContentRules.problem_in("Great goal!"), "")
	assert_ne(ContentRules.problem_in("See https://x.example"), "")
	assert_ne(ContentRules.problem_in("Off to Bayern"), "")


func test_every_transfer_story_mentions_the_fee() -> void:
	for template: Dictionary in _templates.templates_for("news", CareerEvent.TRANSFER):
		var text := str(template["headline"]) + str(template["body"])
		assert_string_contains(text, "{fee}")


func test_back_to_back_stories_of_the_same_kind_differ() -> void:
	var career := CareerFixture.career_at("MID", 24, 70.0, "tidewell", _balance)
	var values := {
		"club": "tidewell",
		"overall_before": 60,
		"overall_after": 63,
		"rating": 9.0,
		"moments_won": 0,
		"moments_played": 0
	}
	for season: int in range(1, 4):
		career.events.append(CareerEvent.create(CareerEvent.SEASON_PLAYED, season, 20, values))
	var news := EventText.news_feed(career, _context)
	assert_ne(news[0].headline, news[1].headline)
	assert_ne(news[1].headline, news[2].headline)
	var messages := EventText.agent_messages(career, _context)
	assert_ne(messages[0], messages[1])
