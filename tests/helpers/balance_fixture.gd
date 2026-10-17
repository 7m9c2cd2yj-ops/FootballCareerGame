extends RefCounted
## Gives tests a fresh, mutable copy of the shipped balance data.


static func shipped_data() -> Dictionary:
	var loaded := JsonLoader.load_dictionary(Balance.DEFAULT_PATH)
	assert(loaded.is_ok(), loaded.error)
	return loaded.data.duplicate(true)


static func shipped() -> Balance:
	return Balance.from_dictionary(shipped_data())
