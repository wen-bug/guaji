extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_template_resources()
	_check_affix_limits()
	_check_enhance_refine_ascend_and_salvage()
	_check_schema_18_migration()
	if failures.is_empty():
		print("EQUIPMENT_PROGRESSION_V2_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_template_resources() -> void:
	var expected := {
		"weapon_metal_sword": [["attack", 30], ["element_metal", 12]],
		"weapon_wood_staff": [["attack", 30], ["element_wood", 12]],
		"weapon_earth_gauntlet": [["attack", 30], ["element_earth", 12]],
		"weapon_water_brush": [["attack", 30], ["element_water", 12]],
		"weapon_fire_orb": [["attack", 30], ["element_fire", 12]],
		"helmet": [["max_mp", 60]],
		"armor": [["defense", 30]],
		"leggings": [["max_hp", 120]],
		"gloves": [["root_bone", 30]],
		"accessory_wood": [["element_wood", 30]],
		"accessory_fire": [["element_fire", 30]],
		"accessory_earth": [["element_earth", 30]],
		"accessory_metal": [["element_metal", 30]],
		"accessory_water": [["element_water", 30]],
	}
	for template_id in expected:
		var resource := DataTables.equipment_resource(str(template_id))
		_expect_true("%s resource exists" % template_id, resource != null)
		var attributes := DataTables.equipment_tier_base_attributes(str(template_id), "t5")
		_expect_equal("%s t5 attribute count" % template_id, attributes.size(), expected[template_id].size())
		for index in range(expected[template_id].size()):
			_expect_equal("%s t5 stat %d" % [template_id, index], str(attributes[index].get("stat", "")), str(expected[template_id][index][0]))
			_expect_equal("%s t5 amount %d" % [template_id, index], int(attributes[index].get("amount", 0)), int(expected[template_id][index][1]))


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
	_expect_equal("enhancement unit applied", state._item_equipment_attribute_value(item, "element_metal"), 2)
	var old_affixes: Array = item.get("affixes", []).duplicate(true)
	_expect_true("single slot refine", state.refine_equipment_affix(str(item.get("instance_id", "")), 0))
	_expect_true("refined slot changes type", str(item.get("affixes", [])[0].get("id", "")) != str(old_affixes[0].get("id", "")))
	_expect_true("ascend t1 to t2", state.ascend_equipment(str(item.get("instance_id", ""))))
	_expect_equal("ascend changes rarity", str(item.get("rarity", "")), "t2")
	_expect_equal("ascend adds second affix", item.get("affixes", []).size(), 2)
	_expect_equal("ascend keeps enhancement", int(item.get("enhancement_allocations", {}).get("element_metal", 0)), 1)
	_expect_equal("ascend updates attack base", int(item.get("base_attributes", [])[0].get("amount", 0)), 5)

	var t5 := DataTables.create_equipment_from_template("helmet", 1, state.rng, 0, "", "t5", "test")
	state.add_equipment(t5)
	_expect_true("t5 cannot ascend", not state.ascend_equipment(str(t5.get("instance_id", ""))))
	var stones_before := state.inventory_item_count(DataTables.ITEM_ID_ENHANCEMENT_STONE)
	_expect_true("salvage unequipped item", state.salvage_equipment(str(item.get("instance_id", ""))))
	_expect_equal("t2 plus half enhancement salvage", state.inventory_item_count(DataTables.ITEM_ID_ENHANCEMENT_STONE), stones_before + 2)


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
	_expect_equal("legacy weapon template mapped", str(item.get("item_id", "")), "weapon_metal_sword")
	_expect_equal("legacy enhancement retained", int(item.get("enhance_count", 0)), 4)
	_expect_equal("legacy enhancement allocated first", int(item.get("enhancement_allocations", {}).get("attack", 0)), 4)
	_expect_equal("stable t3 affixes generated", item.get("affixes", []).size(), 3)
	_expect_equal("blueprints compensated", state.inventory_item_count(DataTables.ITEM_ID_ORE), 8)
	_expect_equal("blueprint pity removed", int(state.reward_progress.get("blueprint_pity", -1)), 0)
	_expect_equal("schema upgraded", int(state.to_save_data().get("schema_version", 0)), 18)


func _expect_true(label: String, value: bool) -> void:
	if not value:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
