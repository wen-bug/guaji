extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_template_resources()
	_check_random_attribute_generation()
	_check_generation_and_load_stability()
	_check_affix_limits()
	_check_enhance_refine_ascend_and_salvage()
	_check_enhancement_units_and_description()
	_check_random_attribute_enhancement()
	_check_schema_18_migration()
	_check_schema_19_migration()
	_check_schema_20_migration()
	if failures.is_empty():
		print("EQUIPMENT_PROGRESSION_V2_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_template_resources() -> void:
	var expected_variants := {
		"weapon_metal_sword": [["element_metal", [2, 5, 10, 18, 30]], ["attack", [1, 2, 4, 7, 12]]],
		"weapon_wood_staff": [["element_wood", [2, 5, 10, 18, 30]], ["max_hp", [4, 8, 16, 28, 48]]],
		"weapon_earth_gauntlet": [["element_earth", [2, 5, 10, 18, 30]], ["defense", [1, 2, 4, 7, 12]]],
		"weapon_water_brush": [["element_water", [2, 5, 10, 18, 30]], ["max_mp", [2, 4, 8, 14, 24]]],
		"weapon_fire_orb": [["element_fire", [2, 5, 10, 18, 30]], ["attack", [1, 2, 4, 7, 12]]],
		"accessory_wood": [["element_wood", [1, 3, 6, 12, 20]], ["max_hp", [4, 8, 16, 24, 40]]],
		"accessory_fire": [["element_fire", [1, 3, 6, 12, 20]], ["attack", [1, 2, 4, 6, 10]]],
		"accessory_earth": [["element_earth", [1, 3, 6, 12, 20]], ["defense", [1, 2, 4, 6, 10]]],
		"accessory_metal": [["element_metal", [1, 3, 6, 12, 20]], ["attack", [1, 2, 4, 6, 10]]],
		"accessory_water": [["element_water", [1, 3, 6, 12, 20]], ["max_mp", [2, 4, 8, 12, 20]]],
	}
	var core_ids: Array = DataTables.EQUIPMENT_DEFS.keys()
	core_ids.sort()
	_expect_equal("six core equipment templates", core_ids, ["accessory", "armor", "gloves", "helmet", "leggings", "weapon"])
	for template_id in core_ids:
		var resource := DataTables.equipment_resource(str(template_id))
		_expect_true("%s resource exists" % template_id, resource != null)
	var expected_fixed := {
		"helmet": [["max_mp", [2, 6, 12, 24, 40]], ["defense", [1, 2, 4, 6, 10]]],
		"armor": [["defense", [1, 3, 6, 12, 20]], ["max_hp", [4, 8, 16, 24, 40]]],
		"leggings": [["max_hp", [4, 12, 24, 48, 80]], ["defense", [1, 2, 4, 6, 10]]],
		"gloves": [["root_bone", [1, 3, 6, 12, 20]], ["attack", [1, 2, 4, 6, 10]]],
	}
	for template_id in expected_fixed:
		for rarity_index in range(DataTables.EQUIPMENT_RARITY_ORDER.size()):
			var rarity := str(DataTables.EQUIPMENT_RARITY_ORDER[rarity_index])
			var attributes := DataTables.equipment_tier_base_attributes(str(template_id), rarity)
			for attribute_index in range(expected_fixed[template_id].size()):
				var expected_attribute: Array = expected_fixed[template_id][attribute_index]
				var stat_id := str(attributes[attribute_index].get("stat", ""))
				_expect_equal("%s %s stat %d" % [template_id, rarity, attribute_index], stat_id, str(expected_attribute[0]))
				_expect_equal("%s %s amount %d" % [template_id, rarity, attribute_index], int(attributes[attribute_index].get("amount", 0)), int(expected_attribute[1][rarity_index]))
	for variant_id in expected_variants:
		var template_id := "weapon" if str(variant_id).begins_with("weapon_") else "accessory"
		_expect_true("variant registered %s" % variant_id, DataTables.equipment_attribute_variants(template_id).has(variant_id))
		for rarity_index in range(DataTables.EQUIPMENT_RARITY_ORDER.size()):
			var rarity := str(DataTables.EQUIPMENT_RARITY_ORDER[rarity_index])
			var attributes := DataTables.equipment_tier_base_attributes(template_id, rarity, str(variant_id))
			for attribute_index in range(2):
				var expected_attribute: Array = expected_variants[variant_id][attribute_index]
				_expect_equal("%s %s stat %d" % [variant_id, rarity, attribute_index], str(attributes[attribute_index].get("stat", "")), str(expected_attribute[0]))
				_expect_equal("%s %s amount %d" % [variant_id, rarity, attribute_index], int(attributes[attribute_index].get("amount", 0)), int(expected_attribute[1][rarity_index]))


func _check_random_attribute_generation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	for template_id in DataTables.EQUIPMENT_DEFS:
		for rarity_index in range(DataTables.EQUIPMENT_RARITY_ORDER.size()):
			var rarity := str(DataTables.EQUIPMENT_RARITY_ORDER[rarity_index])
			var item := DataTables.create_equipment_from_template(str(template_id), 1, rng, 0, "", rarity, "test")
			var rolled: Array = item.get("rolled_attribute_stats", [])
			var attributes: Array = item.get("base_attributes", [])
			_expect_equal("%s %s random count" % [template_id, rarity], rolled.size(), rarity_index + 1)
			_expect_equal("%s %s total attribute count" % [template_id, rarity], attributes.size(), rarity_index + 3)
			var seen: Dictionary = {}
			for attribute in attributes:
				var stat_id := str(attribute.get("stat", ""))
				_expect_true("%s %s unique %s" % [template_id, rarity, stat_id], not seen.has(stat_id))
				seen[stat_id] = true
			var random_points := 0
			for index in range(2, attributes.size()):
				var attribute: Dictionary = attributes[index]
				random_points += floori(float(attribute.get("amount", 0)) / float(DataTables.equipment_attribute_unit_amount(str(attribute.get("stat", "")))))
			_expect_equal("%s %s shared random budget" % [template_id, rarity], random_points, DataTables.equipment_random_attribute_budget(str(template_id), rarity))


func _check_generation_and_load_stability() -> void:
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 7721
	second_rng.seed = 7721
	var first := DataTables.create_equipment_from_template("weapon", 1, first_rng, 0, "", "t5", "test")
	var second := DataTables.create_equipment_from_template("weapon", 1, second_rng, 0, "", "t5", "test")
	_expect_equal("same rng repeats variant", first.get("equipment_variant_id", ""), second.get("equipment_variant_id", ""))
	_expect_equal("same rng repeats random stats", first.get("rolled_attribute_stats", []), second.get("rolled_attribute_stats", []))
	_expect_equal("same rng repeats base values", first.get("base_attributes", []), second.get("base_attributes", []))
	var state := GameState.new()
	state.inventory = [first]
	state.rng.seed = 991
	var saved := state.to_save_data()
	var loaded := GameState.new()
	loaded.load_save_data(saved)
	var restored := loaded.inventory_item_by_instance(str(first.get("instance_id", "")))
	_expect_equal("load keeps random stats", restored.get("rolled_attribute_stats", []), first.get("rolled_attribute_stats", []))
	_expect_equal("load keeps base values", restored.get("base_attributes", []), first.get("base_attributes", []))


func _check_affix_limits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260819
	var expected_counts := {"t1": 1, "t2": 2, "t3": 3, "t4": 3, "t5": 3}
	for rarity in expected_counts:
		var item := DataTables.create_equipment_from_template("weapon_metal_sword", 99, rng, 0, "", str(rarity), "test")
		_expect_equal("%s affix count" % rarity, item.get("affixes", []).size(), int(expected_counts[rarity]))
		_expect_true("%s max three affixes" % rarity, item.get("affixes", []).size() <= 3)
		_expect_true("%s no equip level requirement" % rarity, item.get("equip_requirement", {}).is_empty())


func _check_enhance_refine_ascend_and_salvage() -> void:
	var state := GameState.new()
	state.rng.seed = 77
	var item := DataTables.create_equipment_from_template("weapon_metal_sword", 1, state.rng, 0, "", "t1", "test")
	state.add_equipment(item)
	state.add_inventory_item(DataTables.ITEM_ID_ENHANCEMENT_STONE, 3, false)
	state.add_inventory_item(DataTables.ITEM_ID_ORE, 8, false)
	state.add_inventory_item(DataTables.ITEM_ID_ASCENSION_STONE, 2, false)
	state.add_inventory_item(DataTables.ITEM_ID_REFINE_TALISMAN, 1, false)
	_expect_true("enhance selected element", state.enhance_equipment(str(item.get("instance_id", "")), "element_metal"))
	_expect_equal("enhancement point saved", int(item.get("enhancement_allocations", {}).get("element_metal", 0)), 1)
	_expect_equal("enhancement unit applied", state._item_equipment_attribute_value(item, "element_metal"), 3)
	var old_affixes: Array = item.get("affixes", []).duplicate(true)
	_expect_true("single slot refine", state.refine_equipment_affix(str(item.get("instance_id", "")), 0))
	_expect_true("refined slot changes type", str(item.get("affixes", [])[0].get("id", "")) != str(old_affixes[0].get("id", "")))
	_expect_true("ascend t1 to t2", state.ascend_equipment(str(item.get("instance_id", ""))))
	_expect_equal("ascend changes rarity", str(item.get("rarity", "")), "t2")
	_expect_equal("ascend adds second affix", item.get("affixes", []).size(), 2)
	_expect_equal("ascend keeps enhancement", int(item.get("enhancement_allocations", {}).get("element_metal", 0)), 1)
	_expect_equal("ascend updates element base", int(item.get("base_attributes", [])[0].get("amount", 0)), 5)
	_expect_equal("ascend updates attack base", int(item.get("base_attributes", [])[1].get("amount", 0)), 2)
	_expect_equal("ascend adds one random stat", item.get("rolled_attribute_stats", []).size(), 2)
	_expect_equal("ascend has four base attributes", item.get("base_attributes", []).size(), 4)

	var t5 := DataTables.create_equipment_from_template("helmet", 1, state.rng, 0, "", "t5", "test")
	state.add_equipment(t5)
	_expect_true("t5 cannot ascend", not state.ascend_equipment(str(t5.get("instance_id", ""))))
	var stones_before := state.inventory_item_count(DataTables.ITEM_ID_ENHANCEMENT_STONE)
	_expect_true("salvage unequipped item", state.salvage_equipment(str(item.get("instance_id", ""))))
	_expect_equal("t2 plus half enhancement salvage", state.inventory_item_count(DataTables.ITEM_ID_ENHANCEMENT_STONE), stones_before + 2)


func _check_enhancement_units_and_description() -> void:
	var state := GameState.new()
	state.rng.seed = 91
	var wood := DataTables.create_equipment_from_template("weapon_wood_staff", 1, state.rng, 0, "", "t1", "test")
	var water := DataTables.create_equipment_from_template("weapon_water_brush", 1, state.rng, 0, "", "t1", "test")
	state.add_equipment(wood)
	state.add_equipment(water)
	state.add_inventory_item(DataTables.ITEM_ID_ENHANCEMENT_STONE, 2, false)
	_expect_true("wood secondary hp can be enhanced", state.enhance_equipment(str(wood.get("instance_id", "")), "max_hp"))
	_expect_true("water secondary mp can be enhanced", state.enhance_equipment(str(water.get("instance_id", "")), "max_mp"))
	_expect_equal("hp enhancement uses four-point unit", state._item_equipment_attribute_value(wood, "max_hp"), 8)
	_expect_equal("mp enhancement uses two-point unit", state._item_equipment_attribute_value(water, "max_mp"), 4)
	var description := RichTextDescriptionRenderer.plain_text(RichTextDescriptionRenderer.build_item_segments(wood))
	_expect_true("description shows wood base", description.contains("木属性 +2"))
	_expect_true("description shows hp base", description.contains("气血 +4"))


func _check_random_attribute_enhancement() -> void:
	var state := GameState.new()
	state.rng.seed = 608
	var item := DataTables.create_equipment_from_template("helmet", 1, state.rng, 0, "", "t1", "test")
	state.add_equipment(item)
	state.add_inventory_item(DataTables.ITEM_ID_ENHANCEMENT_STONE, 1, false)
	var random_stat := str(item.get("rolled_attribute_stats", [""])[0])
	var before := state._item_equipment_attribute_value(item, random_stat)
	_expect_true("random base attribute can be enhanced", state.enhance_equipment(str(item.get("instance_id", "")), random_stat))
	_expect_equal("random enhancement allocation saved", int(item.get("enhancement_allocations", {}).get(random_stat, 0)), 1)
	_expect_equal("random enhancement aggregates unit", state._item_equipment_attribute_value(item, random_stat), before + DataTables.equipment_attribute_unit_amount(random_stat))


func _check_schema_18_migration() -> void:
	var state := GameState.new()
	state.load_save_data({
		"schema_version": 17,
		"inventory": [
			{"instance_id": "legacy-weapon", "item_id": "weapon", "type": DataTables.ITEM_TYPE_EQUIPMENT, "rarity": "t3", "enhance_count": 4, "refine_count": 2},
			{"instance_id": "legacy-blueprint", "item_id": "blueprint_weapon", "type": DataTables.ITEM_TYPE_BLUEPRINT, "count": 2, "stackable": true},
		],
		"reward_progress": {"valid_victories": 0, "manual_fragment_progress": 0, "blueprint_pity": 9, "unlocked_blueprints": ["weapon"]},
		"companions": [],
		"party_order": [],
		"recruit_candidates": [],
	})
	var equipment: Array = state.inventory_items_for_type(DataTables.ITEM_TYPE_EQUIPMENT)
	_expect_equal("legacy equipment retained", equipment.size(), 1)
	var item: Dictionary = equipment[0]
	_expect_equal("legacy weapon template mapped", str(item.get("item_id", "")), "weapon")
	_expect_equal("legacy weapon variant retained", str(item.get("equipment_variant_id", "")), "weapon_metal_sword")
	_expect_equal("legacy enhancement retained", int(item.get("enhance_count", 0)), 4)
	_expect_equal("legacy enhancement allocated first", int(item.get("enhancement_allocations", {}).get("attack", 0)), 4)
	_expect_equal("stable t3 affixes generated", item.get("affixes", []).size(), 3)
	_expect_equal("blueprints compensated", state.inventory_item_count(DataTables.ITEM_ID_ORE), 8)
	_expect_equal("blueprint pity removed", int(state.reward_progress.get("blueprint_pity", -1)), 0)
	_expect_equal("schema upgraded", int(state.to_save_data().get("schema_version", 0)), 20)


func _check_schema_19_migration() -> void:
	var state := GameState.new()
	state.load_save_data({
		"schema_version": 18,
		"inventory": [
			{"instance_id": "wood-explicit", "item_id": "weapon_wood_staff", "type": DataTables.ITEM_TYPE_EQUIPMENT, "rarity": "t2", "enhance_count": 5, "enhancement_allocations": {"attack": 3, "max_hp": 2}, "affixes": []},
			{"instance_id": "earth-missing", "item_id": "weapon_earth_gauntlet", "type": DataTables.ITEM_TYPE_EQUIPMENT, "rarity": "t1", "enhance_count": 4, "affixes": [], "equipped": true, "equipped_by": "member"},
			{"instance_id": "water-explicit", "item_id": "weapon_water_brush", "type": DataTables.ITEM_TYPE_EQUIPMENT, "rarity": "t3", "enhance_count": 3, "enhancement_allocations": {"attack": 2, "element_water": 1}, "affixes": []},
		],
		"companions": [{"id": "member", "name": "迁移测试", "stats": {}, "elements": {}, "equipped": {"weapon": "earth-missing"}, "skills": []}],
		"party_order": ["member"],
		"recruit_candidates": [],
	})
	var wood := state.inventory_item_by_instance("wood-explicit")
	var earth := state.inventory_item_by_instance("earth-missing")
	var water := state.inventory_item_by_instance("water-explicit")
	_expect_equal("wood attack merges into hp", int(wood.get("enhancement_allocations", {}).get("max_hp", 0)), 5)
	_expect_true("wood hidden attack removed", not wood.get("enhancement_allocations", {}).has("attack"))
	_expect_equal("earth missing allocations reconstructed", int(earth.get("enhancement_allocations", {}).get("defense", 0)), 4)
	_expect_true("earth stays equipped", bool(earth.get("equipped", false)) and str(earth.get("equipped_by", "")) == "member")
	_expect_equal("water attack maps to mp", int(water.get("enhancement_allocations", {}).get("max_mp", 0)), 2)
	_expect_equal("water element allocation retained", int(water.get("enhancement_allocations", {}).get("element_water", 0)), 1)
	_expect_true("water hidden attack removed", not water.get("enhancement_allocations", {}).has("attack"))
	_expect_equal("schema nineteen saved as current", int(state.to_save_data().get("schema_version", 0)), 20)


func _check_schema_20_migration() -> void:
	var direct := GameState.new()
	direct.rng.seed = 2020
	direct.inventory = [{"instance_id": "rng-check", "item_id": "weapon_fire_orb", "type": DataTables.ITEM_TYPE_EQUIPMENT, "rarity": "t1", "base_attributes": [{"stat": "element_fire", "amount": 2}, {"stat": "attack", "amount": 1}]}]
	var rng_before: Dictionary = direct.to_save_data().get("rng", {})
	direct._migrate_schema_20_equipment_templates()
	_expect_equal("schema twenty migration keeps rng", direct.to_save_data().get("rng", {}), rng_before)
	var state := GameState.new()
	var preserved := [{"stat": "element_wood", "amount": 99}, {"stat": "max_hp", "amount": 44}]
	state.load_save_data({
		"schema_version": 19,
		"inventory": [
			{"instance_id": "wood-preserved", "item_id": "weapon_wood_staff", "type": DataTables.ITEM_TYPE_EQUIPMENT, "rarity": "t2", "base_attributes": preserved, "enhance_count": 2, "enhancement_allocations": {"max_hp": 2}, "affixes": [{"id": "leech_percent", "value": 0.02}]},
			{"instance_id": "water-restored", "item_id": "accessory_water", "type": DataTables.ITEM_TYPE_EQUIPMENT, "rarity": "t3", "affixes": []},
		],
		"companions": [],
		"party_order": [],
		"recruit_candidates": [],
	})
	var wood := state.inventory_item_by_instance("wood-preserved")
	var water := state.inventory_item_by_instance("water-restored")
	_expect_equal("schema twenty maps weapon id", str(wood.get("item_id", "")), "weapon")
	_expect_equal("schema twenty keeps weapon variant", str(wood.get("equipment_variant_id", "")), "weapon_wood_staff")
	_expect_equal("schema twenty keeps weapon variant icon", str(wood.get("icon_path", "")), "res://assets/equipment/weapon.png")
	_expect_equal("schema twenty preserves existing base", wood.get("base_attributes", []), preserved)
	_expect_equal("schema twenty does not add rolls", wood.get("rolled_attribute_stats", []), [])
	_expect_equal("schema twenty keeps enhancement", int(wood.get("enhancement_allocations", {}).get("max_hp", 0)), 2)
	_expect_equal("schema twenty maps accessory id", str(water.get("item_id", "")), "accessory")
	_expect_equal("schema twenty keeps accessory icon", str(water.get("icon_path", "")), "res://assets/equipment/accessory.png")
	_expect_equal("schema twenty restores missing base", water.get("base_attributes", []), DataTables.equipment_tier_base_attributes("accessory", "t3", "accessory_water"))
	_expect_equal("schema twenty saved", int(state.to_save_data().get("schema_version", 0)), 20)


func _expect_true(label: String, value: bool) -> void:
	if not value:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
