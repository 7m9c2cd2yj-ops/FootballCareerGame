class_name PhoneFeeds
extends RefCounted
## Builds the scrolling lists for the News, Messages and Kickfie phone apps
## from Session data. Display only.

const CARD_COLOR := Color(1, 1, 1, 0.08)
const AGENT_COLOR := Color(0.2, 0.65, 0.35, 0.35)
const SMALL_FONT := 22


static func build(app: String) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	match app:
		"news":
			_fill_news(list)
		"messages":
			_fill_messages(list)
		"kickfie":
			_fill_kickfie(list)
	if list.get_child_count() == 0:
		list.add_child(_text("Nothing here yet. Play a season!", SMALL_FONT))
	return scroll


static func _fill_news(list: VBoxContainer) -> void:
	for item: EventText.NewsItem in Session.news_feed():
		var lines: Array[Control] = [
			_text("Season %d" % item.season_number, SMALL_FONT),
			_text(item.headline, 30),
			_text(item.body, SMALL_FONT),
		]
		list.add_child(_card(lines, CARD_COLOR))


static func _fill_messages(list: VBoxContainer) -> void:
	for advice: String in Session.agent_advice():
		list.add_child(_card([_text("Agent · now", SMALL_FONT), _text(advice, 26)], AGENT_COLOR))
	for message: String in Session.agent_messages():
		list.add_child(_card([_text("Agent", SMALL_FONT), _text(message, 26)], CARD_COLOR))


static func _fill_kickfie(list: VBoxContainer) -> void:
	for post: EventText.KickfiePost in Session.kickfie_feed():
		var lines: Array[Control] = [
			_text(post.handle, SMALL_FONT),
			_text(post.text, 28),
			_text("♥ %d · season %d" % [post.likes, post.season_number], SMALL_FONT),
		]
		list.add_child(_card(lines, CARD_COLOR))


static func _card(lines: Array[Control], color: Color) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	for line: Control in lines:
		column.add_child(line)
	card.add_child(column)
	return card


static func _text(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
