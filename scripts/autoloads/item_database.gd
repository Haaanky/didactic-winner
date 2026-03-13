extends Node

## Centralised item-definition database.
## All item properties live here; no magic strings or values scattered elsewhere.
## Access via the global autoload name: ItemDatabase.get_def("hand_axe")

# Item definition keys:
#   name          : String — display name
#   description   : String — one-line tooltip
#   weight        : float  — kg per unit
#   is_tool       : bool   — tools cannot be consumed
#   food_value    : float  — hunger restored on consumption (0.0 = not food)
#   warmth_value  : float  — warmth restored on consumption
#   craftable_at_campfire : bool — recipe requires a lit campfire nearby

const ITEMS: Dictionary = {
	"hand_axe": {
		"name": "Hand Axe",
		"description": "A crude stone axe. Chop trees with [E] to get logs.",
		"weight": 1.5,
		"is_tool": true,
		"food_value": 0.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
	"hunting_knife": {
		"name": "Hunting Knife",
		"description": "A flint-knapped knife. Required to harvest hunted animals.",
		"weight": 0.5,
		"is_tool": true,
		"food_value": 0.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
	"log": {
		"name": "Log",
		"description": "A section of birch or spruce. Used as fuel and in crafting.",
		"weight": 2.0,
		"is_tool": false,
		"food_value": 0.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
	"stone": {
		"name": "Stone",
		"description": "A rough chunk of granite. Needed for tool crafting.",
		"weight": 0.8,
		"is_tool": false,
		"food_value": 0.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
	"berries": {
		"name": "Wild Berries",
		"description": "Tart lingonberries. Restores a small amount of hunger.",
		"weight": 0.1,
		"is_tool": false,
		"food_value": 8.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
	"dried_berries": {
		"name": "Dried Berries",
		"description": "Preserved berries. Better hunger value than fresh ones.",
		"weight": 0.08,
		"is_tool": false,
		"food_value": 14.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": true,
	},
	"mushroom": {
		"name": "Forest Mushroom",
		"description": "A porcini mushroom. Decent food on its own.",
		"weight": 0.1,
		"is_tool": false,
		"food_value": 10.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
	"raw_fish": {
		"name": "Raw Fish",
		"description": "A freshly caught Arctic char. Cook it before eating.",
		"weight": 0.4,
		"is_tool": false,
		"food_value": 5.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
	"cooked_fish": {
		"name": "Cooked Fish",
		"description": "Char grilled over an open fire. Hearty and nourishing.",
		"weight": 0.35,
		"is_tool": false,
		"food_value": 28.0,
		"warmth_value": 4.0,
		"craftable_at_campfire": true,
	},
	"raw_meat": {
		"name": "Raw Meat",
		"description": "Fresh game. You really should cook this.",
		"weight": 0.6,
		"is_tool": false,
		"food_value": 5.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
	"cooked_meat": {
		"name": "Cooked Meat",
		"description": "Well-seasoned game cooked over the campfire.",
		"weight": 0.5,
		"is_tool": false,
		"food_value": 40.0,
		"warmth_value": 6.0,
		"craftable_at_campfire": true,
	},
	"dried_fish": {
		"name": "Dried Fish",
		"description": "Jerky-style fish. Lightweight survival rations.",
		"weight": 0.2,
		"is_tool": false,
		"food_value": 20.0,
		"warmth_value": 2.0,
		"craftable_at_campfire": true,
	},
	"rope": {
		"name": "Rope",
		"description": "Braided spruce root. Needed for some crafting recipes.",
		"weight": 0.3,
		"is_tool": false,
		"food_value": 0.0,
		"warmth_value": 0.0,
		"craftable_at_campfire": false,
	},
}

# Crafting recipes.
# Structure: { "output_id": { "quantity": int, "ingredients": { "item_id": count, ... }, "campfire": bool } }
const RECIPES: Dictionary = {
	"hand_axe": {
		"quantity": 1,
		"ingredients": {"log": 2, "stone": 3},
		"campfire": false,
	},
	"hunting_knife": {
		"quantity": 1,
		"ingredients": {"log": 1, "stone": 2},
		"campfire": false,
	},
	"rope": {
		"quantity": 1,
		"ingredients": {"log": 3},
		"campfire": false,
	},
	"cooked_fish": {
		"quantity": 1,
		"ingredients": {"raw_fish": 1},
		"campfire": true,
	},
	"cooked_meat": {
		"quantity": 1,
		"ingredients": {"raw_meat": 1},
		"campfire": true,
	},
	"dried_berries": {
		"quantity": 1,
		"ingredients": {"berries": 4},
		"campfire": true,
	},
	"dried_fish": {
		"quantity": 1,
		"ingredients": {"raw_fish": 2},
		"campfire": true,
	},
}


func get_def(item_id: String) -> Dictionary:
	if not ITEMS.has(item_id):
		push_warning("ItemDatabase: unknown item_id — %s" % item_id)
		return {}
	return ITEMS[item_id]


func get_display_name(item_id: String) -> String:
	return ITEMS.get(item_id, {}).get("name", item_id)


func get_food_value(item_id: String) -> float:
	return float(ITEMS.get(item_id, {}).get("food_value", 0.0))


func get_warmth_value(item_id: String) -> float:
	return float(ITEMS.get(item_id, {}).get("warmth_value", 0.0))


func get_weight(item_id: String) -> float:
	return float(ITEMS.get(item_id, {}).get("weight", 0.5))


func is_tool(item_id: String) -> bool:
	return bool(ITEMS.get(item_id, {}).get("is_tool", false))


func is_food(item_id: String) -> bool:
	return get_food_value(item_id) > 0.0


func get_recipe(output_id: String) -> Dictionary:
	if not RECIPES.has(output_id):
		return {}
	return RECIPES[output_id]


func get_all_craftable_ids() -> Array[String]:
	var result: Array[String] = []
	for key: String in RECIPES.keys():
		result.append(key)
	return result


func can_craft(output_id: String, inventory: InventoryComponent, at_campfire: bool) -> bool:
	var recipe: Dictionary = get_recipe(output_id)
	if recipe.is_empty():
		return false
	if recipe.get("campfire", false) and not at_campfire:
		return false
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for ing_id: String in ingredients.keys():
		var needed: int = int(ingredients[ing_id])
		if not inventory.has_item(ing_id, needed):
			return false
	return true


func craft(output_id: String, inventory: InventoryComponent, at_campfire: bool) -> bool:
	if not can_craft(output_id, inventory, at_campfire):
		return false
	var recipe: Dictionary = get_recipe(output_id)
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for ing_id: String in ingredients.keys():
		var count: int = int(ingredients[ing_id])
		inventory.remove_item(ing_id, count)
	var qty: int = int(recipe.get("quantity", 1))
	var weight: float = get_weight(output_id)
	inventory.add_item(output_id, qty, weight)
	EventBus.journal_entry_added.emit("Crafted: %s." % get_display_name(output_id))
	return true
