extends Node

const ValidatorScript = preload("res://scripts/modding/internal/mod_schema_validator.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_definitions_and_recipes()
	_check_default_gain_and_targeting()
	_check_resource_sync_and_multi_effect()
	_check_shared_limit_and_persistence()
	_check_invalid_payloads_are_atomic()
	_check_mod_validation_and_description()
	if failures.is_empty():
		print("PERMANENT_ATTRIBUTE_ENHANCE_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _fresh_state(member_count: int = 1) -> GameState:
	var state := GameState.new()
	state.inventory.clear()
	state.companions.clear()
	state.party_order.clear()
	state.reserve_order.clear()
	state.recruit_candidates.clear()
	state.known_alchemy_recipes.clear()
	state.rng.seed = 173
	for index in range(member_count):
		var member: Dictionary = state.party_service.create_recruit_candidate(index, {})
		member["kind"] = "companion"
		state.companions.append(member)
		state.party_order.append(str(member.get("id", "")))
	return state


func _check_definitions_and_recipes() -> void:
	var specs := {
		"t1_attack_enhance_pill": [1051, "attack", "blade_grass", "spirit_stone", 6],
		"t1_defense_enhance_pill": [1052, "defense", "ironroot", "spirit_stone", 6],
		"t1_max_hp_enhance_pill": [1053, "max_hp", "blood_ginseng", "spirit_stone", 6],
		"t1_max_mp_enhance_pill": [1054, "max_mp", "spirit_lotus", "spirit_stone", 6],
		"t1_root_bone_enhance_pill": [1055, "root_bone", "bone_bamboo", "spirit_stone", 6],
		"t1_wood_enhance_pill": [1056, "element_wood", "woodvine", "spirit_stone_wood", 7],
		"t1_fire_enhance_pill": [1057, "element_fire", "flame_flower", "spirit_stone_fire", 7],
		"t1_earth_enhance_pill": [1058, "element_earth", "earth_moss", "spirit_stone_earth", 7],
		"t1_metal_enhance_pill": [1059, "element_metal", "metal_reed", "spirit_stone_metal", 7],
		"t1_water_enhance_pill": [1060, "element_water", "water_orchid", "spirit_stone_water", 7],
	}
	var item_nos: Dictionary = {}
	for item_id in specs:
		var spec: Array = specs[item_id]
		var definition := DataTables.item_definition(item_id)
		_expect_equal("item number " + item_id, int(definition.get("item_no", 0)), int(spec[0]))
		_expect_true("unique item number " + item_id, not item_nos.has(spec[0]))
		item_nos[spec[0]] = true
		_expect_equal("item type " + item_id, str(definition.get("type", "")), DataTables.ITEM_TYPE_PILL)
		_expect_true("item usable " + item_id, bool(definition.get("usable", false)))
		var enhance_data: Dictionary = definition.get("payload", {}).get("permanent_attribute_enhance", {})
		_expect_equal("item tier " + item_id, str(enhance_data.get("tier_id", "")), "t1")
		var effects: Array = enhance_data.get("effects", [])
		_expect_equal("single effect " + item_id, effects.size(), 1)
		_expect_equal("effect stat " + item_id, str(effects[0].get("stat", "")), str(spec[1]))
		_expect_true("default amount omitted " + item_id, not effects[0].has("amount"))
		_expect_true("resource exists " + item_id, ResourceLoader.exists(DataTables.item_resource_path(item_id)))
		var recipe := DataTables.alchemy_recipe_def(item_id)
		_expect_equal("recipe result " + item_id, str(recipe.get("result_item_id", "")), item_id)
		_expect_equal("recipe level " + item_id, int(recipe.get("unlock_building_level", 0)), int(spec[4]))
		var materials: Array = recipe.get("materials", [])
		_expect_true("recipe crop " + item_id, _material_has(materials, str(spec[2]), 3))
		_expect_true("recipe herb " + item_id, _material_has(materials, "herb", 8))
		_expect_true("recipe stone " + item_id, _material_has(materials, str(spec[3]), 2))

	var state := _fresh_state()
	state.building_levels["alchemy"] = 5
	state._ensure_building_unlocked_recipes()
	_expect_true("tier one stat recipe locked at level five", not state.known_alchemy_recipes.has("t1_attack_enhance_pill"))
	state.building_levels["alchemy"] = 6
	state._ensure_building_unlocked_recipes()
	_expect_true("stat recipe unlocks at level six", state.known_alchemy_recipes.has("t1_attack_enhance_pill"))
	_expect_true("element recipe remains locked at level six", not state.known_alchemy_recipes.has("t1_fire_enhance_pill"))
	state.add_inventory_item("blade_grass", 3, false)
	state.add_inventory_item("herb", 8, false)
	state.add_inventory_item("spirit_stone", 2, false)
	_expect_true("stat enhance pill crafts", state.craft_alchemy_recipe("t1_attack_enhance_pill", 1))
	_expect_equal("craft spends crop", state.inventory_item_count("blade_grass"), 0)
	_expect_equal("craft spends herb", state.inventory_item_count("herb"), 0)
	_expect_equal("craft spends stones", state.inventory_item_count("spirit_stone"), 0)
	_expect_equal("permanent pill ignores level-six multiplier", state.inventory_item_count("t1_attack_enhance_pill"), 1)
	state.building_levels["alchemy"] = 7
	state._ensure_building_unlocked_recipes()
	_expect_true("element recipe unlocks at level seven", state.known_alchemy_recipes.has("t1_fire_enhance_pill"))


func _check_default_gain_and_targeting() -> void:
	var state := _fresh_state(2)
	var member: Dictionary = state.companions[0]
	var other: Dictionary = state.companions[1]
	var member_id := str(member.get("id", ""))
	var before := int(member.get("stats", {}).get("attack", 0))
	var other_before := int(other.get("stats", {}).get("attack", 0))
	state.add_inventory_item("t1_attack_enhance_pill", 1, false)
	_expect_true("default gain pill succeeds", state.use_inventory_item_for_member("t1_attack_enhance_pill", member_id))
	_expect_equal("default amount is one", int(member.get("stats", {}).get("attack", 0)), before + 1)
	_expect_equal("other member unchanged", int(other.get("stats", {}).get("attack", 0)), other_before)
	_expect_equal("tier use recorded", state.permanent_attribute_enhance_tier_uses_for(member_id, "t1"), 1)
	_expect_equal("item use recorded", state.permanent_attribute_enhance_item_uses_for(member_id, "t1_attack_enhance_pill"), 1)
	_expect_equal("successful pill consumed", state.inventory_item_count("t1_attack_enhance_pill"), 0)


func _check_resource_sync_and_multi_effect() -> void:
	var state := _fresh_state()
	var member: Dictionary = state.companions[0]
	var member_id := str(member.get("id", ""))
	var stats: Dictionary = member.get("stats", {})
	stats["hp"] = 10
	stats["mp"] = 5
	var old_max_hp := int(stats.get("max_hp", 0))
	var old_max_mp := int(stats.get("max_mp", 0))
	state.add_inventory_item("t1_max_hp_enhance_pill", 1, false)
	state.add_inventory_item("t1_max_mp_enhance_pill", 1, false)
	_expect_true("max hp pill succeeds", state.use_inventory_item_for_member("t1_max_hp_enhance_pill", member_id))
	_expect_true("max mp pill succeeds", state.use_inventory_item_for_member("t1_max_mp_enhance_pill", member_id))
	_expect_equal("max hp increases", int(stats.get("max_hp", 0)), old_max_hp + 1)
	_expect_equal("current hp follows max hp", int(stats.get("hp", 0)), 11)
	_expect_equal("max mp increases", int(stats.get("max_mp", 0)), old_max_mp + 1)
	_expect_equal("current mp follows max mp", int(stats.get("mp", 0)), 6)

	var attack_before := int(stats.get("attack", 0))
	var fire_before := int(member.get("elements", {}).get("fire", 0))
	var multi_item := {
		"instance_id": "test_multi",
		"item_id": "test_multi",
		"name": "Multi",
		"type": DataTables.ITEM_TYPE_PILL,
		"stackable": true,
		"count": 1,
		"payload": {"permanent_attribute_enhance": {
			"tier_id": "t1",
			"effects": [{"stat": "attack", "amount": 2}, {"stat": "element_fire", "amount": 3}],
		}},
	}
	state.inventory.append(multi_item)
	_expect_true("multi effect pill succeeds", state._use_permanent_attribute_item_for_member(multi_item, member_id))
	_expect_equal("multi effect attack", int(stats.get("attack", 0)), attack_before + 2)
	_expect_equal("multi effect element", int(member.get("elements", {}).get("fire", 0)), fire_before + 3)
	_expect_equal("multi pill counts once", state.permanent_attribute_enhance_item_uses_for(member_id, "test_multi"), 1)
	_expect_equal("all successful pills share tier count", state.permanent_attribute_enhance_tier_uses_for(member_id, "t1"), 3)


func _check_shared_limit_and_persistence() -> void:
	var state := _fresh_state()
	var member: Dictionary = state.companions[0]
	var member_id := str(member.get("id", ""))
	member["enhance_pill_uses_by_tier"] = {"t1": 99}
	member["enhance_pill_uses_by_item"] = {}
	state.add_inventory_item("t1_attack_enhance_pill", 1, false)
	state.add_inventory_item("t1_defense_enhance_pill", 1, false)
	_expect_true("one hundredth pill succeeds", state.use_inventory_item_for_member("t1_attack_enhance_pill", member_id))
	var defense_before := int(member.get("stats", {}).get("defense", 0))
	_expect_true("one hundred first pill rejected", not state.use_inventory_item_for_member("t1_defense_enhance_pill", member_id))
	_expect_equal("limit failure leaves stat", int(member.get("stats", {}).get("defense", 0)), defense_before)
	_expect_equal("limit failure leaves item", state.inventory_item_count("t1_defense_enhance_pill"), 1)
	_expect_equal("shared tier capped", state.permanent_attribute_enhance_tier_uses_for(member_id, "t1"), 100)
	_expect_equal("successful item count separate", state.permanent_attribute_enhance_item_uses_for(member_id, "t1_attack_enhance_pill"), 1)
	_expect_equal("failed item count absent", state.permanent_attribute_enhance_item_uses_for(member_id, "t1_defense_enhance_pill"), 0)

	var saved := state.to_save_data()
	_expect_equal("save schema sixteen", int(saved.get("schema_version", 0)), 16)
	var loaded := GameState.new()
	loaded.load_save_data(saved)
	_expect_equal("tier count persists", loaded.permanent_attribute_enhance_tier_uses_for(member_id, "t1"), 100)
	_expect_equal("item count persists", loaded.permanent_attribute_enhance_item_uses_for(member_id, "t1_attack_enhance_pill"), 1)

	var legacy := GameState.new()
	legacy.load_save_data({
		"schema_version": 14,
		"companions": [{"id": "legacy", "name": "Legacy", "stats": {}, "elements": {}, "equipped": {}, "skills": []}],
		"party_order": ["legacy"],
		"recruit_candidates": [],
	})
	var legacy_member := legacy.member_by_id("legacy")
	_expect_true("legacy tier counts initialized", legacy_member.get("enhance_pill_uses_by_tier", null) is Dictionary)
	_expect_true("legacy item counts initialized", legacy_member.get("enhance_pill_uses_by_item", null) is Dictionary)


func _check_invalid_payloads_are_atomic() -> void:
	var state := _fresh_state()
	var member: Dictionary = state.companions[0]
	var member_id := str(member.get("id", ""))
	var invalid_data := [
		{"tier_id": "t2", "effects": [{"stat": "attack"}]},
		{"tier_id": "t1", "effects": []},
		{"tier_id": "t1", "effects": [{"stat": "unknown"}]},
		{"tier_id": "t1", "effects": [{"stat": "attack"}, {"stat": "attack"}]},
		{"tier_id": "t1", "effects": [{"stat": "attack", "amount": 0}]},
		{"tier_id": "t1", "effects": [{"stat": "attack", "amount": 1.5}]},
		{"tier_id": "t1", "effects": ["attack"]},
	]
	for index in range(invalid_data.size()):
		var item_id := "invalid_%d" % index
		var item := {
			"instance_id": item_id,
			"item_id": item_id,
			"name": item_id,
			"type": DataTables.ITEM_TYPE_PILL,
			"stackable": true,
			"count": 1,
			"payload": {"permanent_attribute_enhance": invalid_data[index]},
		}
		state.inventory.append(item)
		var attack_before := int(member.get("stats", {}).get("attack", 0))
		var uses_before := state.permanent_attribute_enhance_tier_uses_for(member_id, "t1")
		_expect_true("invalid payload rejected %d" % index, not state._use_permanent_attribute_item_for_member(item, member_id))
		_expect_equal("invalid payload keeps item %d" % index, state.inventory_item_count(item_id), 1)
		_expect_equal("invalid payload keeps stat %d" % index, int(member.get("stats", {}).get("attack", 0)), attack_before)
		_expect_equal("invalid payload keeps uses %d" % index, state.permanent_attribute_enhance_tier_uses_for(member_id, "t1"), uses_before)
	_expect_true("missing member rejected", not state._use_permanent_attribute_item_for_member(DataTables.create_stack_item("t1_attack_enhance_pill", 1), "missing"))


func _check_mod_validation_and_description() -> void:
	var validator = ValidatorScript.new()
	var good := {
		"name": "Good",
		"type": "pill",
		"payload": {"permanent_attribute_enhance": {
			"tier_id": "t1",
			"effects": [{"stat": "attack"}, {"stat": "element_water", "amount": 2}],
		}},
	}
	_expect_true("valid mod payload accepted", validator.validate_definition("item", "good", good).is_empty())
	var bad := good.duplicate(true)
	bad["payload"]["permanent_attribute_enhance"]["effects"] = [{"stat": "attack"}, {"stat": "attack"}]
	_expect_true("duplicate mod stat rejected", not validator.validate_definition("item", "bad", bad).is_empty())
	bad = good.duplicate(true)
	bad["payload"]["permanent_attribute_enhance"]["effects"] = [{"stat": "attack", "amount": 0}]
	_expect_true("invalid mod amount rejected", not validator.validate_definition("item", "bad_amount", bad).is_empty())

	var state := _fresh_state()
	var member_id := str(state.companions[0].get("id", ""))
	var item := DataTables.create_stack_item("t1_attack_enhance_pill", 1)
	var description := RichTextDescriptionRenderer.plain_text(RichTextDescriptionRenderer.build_item_segments(item, state, member_id))
	_expect_true("description includes permanent effect", description.contains("永久强化"))
	_expect_true("description includes default amount", description.contains("+1"))
	_expect_true("description includes tier usage", description.contains("0/100"))


func _material_has(materials: Array, item_id: String, amount: int) -> bool:
	for material in materials:
		if str(material.get("item_id", "")) == item_id and int(material.get("amount", 0)) == amount:
			return true
	return false


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
