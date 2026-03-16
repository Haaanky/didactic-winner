extends GutTest

## Tests for ItemDatabase autoload.

func test_get_def_hand_axe_returns_correct_name() -> void:
	var def: Dictionary = ItemDatabase.get_def("hand_axe")
	assert_eq(def.get("name"), "Hand Axe")


func test_get_def_unknown_item_returns_empty_dict() -> void:
	var def: Dictionary = ItemDatabase.get_def("nonexistent_item_xyz")
	assert_true(def.is_empty())


func test_get_display_name_returns_name_string() -> void:
	assert_eq(ItemDatabase.get_display_name("berries"), "Wild Berries")


func test_get_display_name_unknown_falls_back_to_id() -> void:
	assert_eq(ItemDatabase.get_display_name("unknown_xyz"), "unknown_xyz")


func test_is_food_returns_true_for_berries() -> void:
	assert_true(ItemDatabase.is_food("berries"))


func test_is_food_returns_false_for_hand_axe() -> void:
	assert_false(ItemDatabase.is_food("hand_axe"))


func test_is_tool_returns_true_for_hand_axe() -> void:
	assert_true(ItemDatabase.is_tool("hand_axe"))


func test_is_tool_returns_false_for_log() -> void:
	assert_false(ItemDatabase.is_tool("log"))


func test_get_food_value_berries_is_positive() -> void:
	assert_gt(ItemDatabase.get_food_value("berries"), 0.0)


func test_get_food_value_log_is_zero() -> void:
	assert_eq(ItemDatabase.get_food_value("log"), 0.0)


func test_get_warmth_value_cooked_fish_is_positive() -> void:
	assert_gt(ItemDatabase.get_warmth_value("cooked_fish"), 0.0)


func test_get_weight_log_is_positive() -> void:
	assert_gt(ItemDatabase.get_weight("log"), 0.0)


func test_get_recipe_hand_axe_requires_log_and_stone() -> void:
	var recipe: Dictionary = ItemDatabase.get_recipe("hand_axe")
	assert_false(recipe.is_empty())
	var ingredients: Dictionary = recipe.get("ingredients", {})
	assert_true(ingredients.has("log"))
	assert_true(ingredients.has("stone"))


func test_get_recipe_nonexistent_returns_empty() -> void:
	var recipe: Dictionary = ItemDatabase.get_recipe("nonexistent_xyz")
	assert_true(recipe.is_empty())


func test_get_recipe_cooked_fish_requires_campfire() -> void:
	var recipe: Dictionary = ItemDatabase.get_recipe("cooked_fish")
	assert_true(bool(recipe.get("campfire", false)))


func test_can_craft_hand_axe_with_enough_materials() -> void:
	var inv: InventoryComponent = InventoryComponent.new()
	add_child(inv)
	inv.add_item("log", 2, 2.0)
	inv.add_item("stone", 3, 0.8)
	assert_true(ItemDatabase.can_craft("hand_axe", inv, false))
	inv.queue_free()


func test_can_craft_hand_axe_fails_without_enough_materials() -> void:
	var inv: InventoryComponent = InventoryComponent.new()
	add_child(inv)
	inv.add_item("log", 1, 2.0)
	assert_false(ItemDatabase.can_craft("hand_axe", inv, false))
	inv.queue_free()


func test_can_craft_cooked_fish_fails_without_campfire() -> void:
	var inv: InventoryComponent = InventoryComponent.new()
	add_child(inv)
	inv.add_item("raw_fish", 1, 0.4)
	assert_false(ItemDatabase.can_craft("cooked_fish", inv, false))
	inv.queue_free()


func test_can_craft_cooked_fish_succeeds_at_campfire() -> void:
	var inv: InventoryComponent = InventoryComponent.new()
	add_child(inv)
	inv.add_item("raw_fish", 1, 0.4)
	assert_true(ItemDatabase.can_craft("cooked_fish", inv, true))
	inv.queue_free()


func test_craft_removes_ingredients_and_adds_output() -> void:
	var inv: InventoryComponent = InventoryComponent.new()
	add_child(inv)
	inv.add_item("log", 2, 2.0)
	inv.add_item("stone", 3, 0.8)
	var success: bool = ItemDatabase.craft("hand_axe", inv, false)
	assert_true(success)
	assert_true(inv.has_item("hand_axe"))
	assert_false(inv.has_item("log"))
	assert_false(inv.has_item("stone"))
	inv.queue_free()


func test_craft_fails_and_does_not_modify_inventory_when_missing_materials() -> void:
	var inv: InventoryComponent = InventoryComponent.new()
	add_child(inv)
	inv.add_item("log", 1, 2.0)
	var success: bool = ItemDatabase.craft("hand_axe", inv, false)
	assert_false(success)
	assert_false(inv.has_item("hand_axe"))
	assert_eq(inv.get_quantity("log"), 1)
	inv.queue_free()


func test_get_all_craftable_ids_is_not_empty() -> void:
	var ids: Array[String] = ItemDatabase.get_all_craftable_ids()
	assert_gt(ids.size(), 0)


func test_all_recipes_reference_known_item_ids() -> void:
	for output_id: String in ItemDatabase.RECIPES.keys():
		assert_true(ItemDatabase.ITEMS.has(output_id),
			"Recipe output '%s' not in ITEMS" % output_id)
		var recipe: Dictionary = ItemDatabase.RECIPES[output_id]
		var ingredients: Dictionary = recipe.get("ingredients", {})
		for ing_id: String in ingredients.keys():
			assert_true(ItemDatabase.ITEMS.has(ing_id),
				"Ingredient '%s' not in ITEMS (recipe: %s)" % [ing_id, output_id])
