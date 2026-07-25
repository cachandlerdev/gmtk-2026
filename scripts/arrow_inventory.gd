class_name ArrowInventory
extends RefCounted
## Amounts of each arrow type the player is carrying, plus the currently
## selected type for the bow.

signal changed

const MAX_PER_TYPE: int = 5

var selected: int = Arrow.Type.BASIC
var _amounts: Dictionary = {
	Arrow.Type.BASIC: 0,
	Arrow.Type.PIERCING: 0,
	Arrow.Type.BOUNCING: 0,
	Arrow.Type.FIRE: 0,
	Arrow.Type.ICE: 0,
}


static func max_per_type() -> int:
	return MAX_PER_TYPE


## Order arrows cycle through
static func type_order() -> Array:
	# FIRE / ICE temporarily disabled until I figure how to implement their surface effects
	return [
		Arrow.Type.BASIC,
		Arrow.Type.PIERCING,
		Arrow.Type.BOUNCING,
	]


func count(type: int) -> int:
	return int(_amounts.get(type, 0))


func selected_count() -> int:
	return count(selected)


func space_left(type: int) -> int:
	return maxi(MAX_PER_TYPE - count(type), 0)


func can_add(type: int, amount: int = 1) -> bool:
	return space_left(type) >= amount


func is_full(type: int) -> bool:
	return space_left(type) <= 0


func has_any() -> bool:
	for type in type_order():
		if count(type) > 0:
			return true
	return false


## Adds up to `amount` without exceeding MAX_PER_TYPE. Returns how many were added.
func add(type: int, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var added := mini(amount, space_left(type))
	if added <= 0:
		return 0
	_amounts[type] = count(type) + added
	changed.emit()
	return added


func try_consume(type: int = selected) -> bool:
	if count(type) <= 0:
		return false
	_amounts[type] = count(type) - 1
	if count(selected) <= 0:
		cycle_next()
	else:
		changed.emit()
	return true


## Cycle to the next type that still has ammo. If none do, selected is unchanged.
func cycle_next() -> void:
	var order := type_order()
	var start := order.find(selected)
	if start < 0:
		start = 0
	for i in range(1, order.size() + 1):
		var candidate: int = order[(start + i) % order.size()]
		if count(candidate) > 0:
			selected = candidate
			changed.emit()
			return
	changed.emit()


## Cycle to the previous type that still has ammo.
func cycle_prev() -> void:
	var order := type_order()
	var start := order.find(selected)
	if start < 0:
		start = 0
	for i in range(1, order.size() + 1):
		var candidate: int = order[posmod(start - i, order.size())]
		if count(candidate) > 0:
			selected = candidate
			changed.emit()
			return
	changed.emit()


static func type_name(type: int) -> String:
	match type:
		Arrow.Type.BASIC:
			return "Basic"
		Arrow.Type.PIERCING:
			return "Piercing"
		Arrow.Type.BOUNCING:
			return "Bouncing"
		Arrow.Type.FIRE:
			return "Fire"
		Arrow.Type.ICE:
			return "Ice"
	return "Unknown"
