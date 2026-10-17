extends Control
## Locker: equip boots, a celebration and a kit colour. Shown in key moments
## only; they never change a result.

const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const STORE_SCENE := "res://scenes/main/store_screen.tscn"
const SWATCH_BORDER := Color(0.85, 0.85, 0.85)
const KIND_NAMES: Dictionary[String, String] = {
	StoreCatalog.BOOTS: "Boots",
	StoreCatalog.CELEBRATIONS: "Celebration",
	StoreCatalog.KITS: "Kit colour",
}

var _items: VBoxContainer = VBoxContainer.new()

@onready var _layout: VBoxContainer = %Layout


func _ready() -> void:
	_layout.add_child(UiParts.label("Cosmetics only: what you wear never changes a result."))
	_items.add_theme_constant_override("separation", 12)
	_layout.add_child(_items)
	_layout.add_child(UiParts.button("Store", _open.bind(STORE_SCENE)))
	_layout.add_child(UiParts.button("Back", _open.bind(MENU_SCENE)))
	refresh()


func refresh() -> void:
	UiParts.clear(_items)
	for kind: String in StoreCatalog.KINDS:
		_items.add_child(UiParts.label(KIND_NAMES[kind], 34))
		var equipped := str(Store.equipped(kind)["id"])
		for item: Dictionary in Store.catalog.items[kind]:
			_items.add_child(_item_button(item, item["id"] == equipped))


func equip(item_id: String) -> void:
	Store.equip(item_id)
	refresh()


func _item_button(item: Dictionary, is_equipped: bool) -> Button:
	var item_id := str(item["id"])
	var owned := Store.entitlements.owns_item(item_id, Store.catalog)
	var text := str(item["name"])
	if is_equipped:
		text = "✓ %s (equipped)" % text
	elif not owned:
		text = "%s · in the store" % text
	var button := UiParts.button(text, equip.bind(item_id))
	button.disabled = is_equipped or not owned
	if item.has("color"):
		button.icon = _swatch(str(item["color"]))
	return button


## A small bordered colour square; the "palette" kit shows the palette's player colour.
func _swatch(color_text: String) -> Texture2D:
	var color := Preferences.color("player_kit")
	if color_text != StoreCatalog.PALETTE_COLOR:
		color = Color.html(color_text)
	var image := Image.create_empty(40, 40, false, Image.FORMAT_RGBA8)
	image.fill(SWATCH_BORDER)
	image.fill_rect(Rect2i(3, 3, 34, 34), color)
	return ImageTexture.create_from_image(image)


func _open(scene: String) -> void:
	get_tree().change_scene_to_file(scene)
