extends Control
## Store: one-time cosmetic and convenience purchases, behind the parental
## gate, plus Restore purchases. Purchases never change how the game plays.

const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const LOCKER_SCENE := "res://scenes/main/locker_screen.tscn"
const NOTE := (
	"Everything here is cosmetic or a convenience. Nothing makes your player better:"
	+ " ratings, key moments and careers work the same for everyone."
)

var _products: VBoxContainer = VBoxContainer.new()
var _message: Label = UiParts.label("")

@onready var _layout: VBoxContainer = %Layout


func _ready() -> void:
	_layout.add_child(UiParts.label(NOTE))
	if not Store.adapter.label().is_empty():
		_layout.add_child(UiParts.label(Store.adapter.label(), 22))
	_products.add_theme_constant_override("separation", 20)
	_layout.add_child(_products)
	_layout.add_child(UiParts.button("Restore purchases", restore))
	_message.add_theme_color_override("font_color", Preferences.color("highlight"))
	_layout.add_child(_message)
	_layout.add_child(UiParts.button("Locker", _open.bind(LOCKER_SCENE)))
	_layout.add_child(UiParts.button("Back", _open.bind(MENU_SCENE)))
	refresh()


func refresh() -> void:
	UiParts.clear(_products)
	for product: StoreCatalog.Product in Store.catalog.products:
		_products.add_child(UiParts.label("%s\n%s" % [product.name, product.description]))
		var owned := Store.entitlements.owns_product(product.id)
		var buy := UiParts.button("Owned" if owned else "Buy", buy_with_gate.bind(product.id))
		buy.disabled = owned or not Store.is_available()
		_products.add_child(buy)
	if not Store.is_available():
		_message.text = "Purchases are not available in this build."


## Shows the parental gate, then buys `product_id`.
func buy_with_gate(product_id: String) -> void:
	if not await ParentalGateDialog.ask(self, "Purchases need a grown-up."):
		_message.text = "No purchase made."
		return
	_message.text = await Store.purchase(product_id)
	refresh()


func restore() -> void:
	_message.text = "Restoring…"
	_message.text = await Store.restore()
	refresh()


func _open(scene: String) -> void:
	get_tree().change_scene_to_file(scene)
