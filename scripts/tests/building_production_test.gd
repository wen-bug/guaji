extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_character_free_production()
	_check_permanent_quality_items()
	_check_legacy_migration()
	_check_unresolved_legacy_job()
	if failures.is_empty():
		print("BUILDING_PRODUCTION_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _fresh_state() -> GameState:
	var state := GameState.new()
	state.inventory.clear()
	state.companions.clear()
	state.party_order.clear()
	state.reserve_order.clear()
	state.recruit_candidates.clear()
	state.known_alchemy_recipes.clear()
	state.rng.seed = 17
	return state


func _check_character_free_production() -> void:
	var state := _fresh_state()
	state.add_inventory_item("herb", 10, false)
	state.add_inventory_item("ore", 8, false)
	state.known_alchemy_recipes.append("pill")
	state.account_progression["expedition_level"] = 17

	_expect_true("farm plants without characters", state.plant_farm_slot(0, "herb"))
	var slot: Dictionary = state.farm_slots[0]
	_expect_equal("farm remains timed", str(slot.get("status", "")), GameState.FARM_STATUS_GROWING)
	_expect_true("farm has no worker id", not slot.has("worker_id"))
	_expect_equal("farm level-one yield", int(slot.get("harvest_amount", 0)), DataTables.crop_seed_yield("herb"))
	state.update_farm(float(slot.get("growth_seconds", 0.0)))
	_expect_equal("farm reaches ready", str(state.farm_slots[0].get("status", "")), GameState.FARM_STATUS_READY)
	_expect_true("farm claim succeeds", state.claim_farm_slot(0))

	var equipment_before := state.inventory_total_for_type(DataTables.ITEM_TYPE_EQUIPMENT)
	_expect_true("forge works without characters", state.craft_equipment())
	_expect_equal("forge spends fixed ore", state.inventory_item_count("ore"), 4)
	_expect_equal("forge outputs immediately", state.inventory_total_for_type(DataTables.ITEM_TYPE_EQUIPMENT), equipment_before + 1)
	var forged_level := 0
	for item in state.inventory_items_for_type(DataTables.ITEM_TYPE_EQUIPMENT):
		forged_level = int(item.get("equipment_level", 0))
	_expect_equal("forge tier requirement is decoupled from expedition", forged_level, 1)

	var pills_before := state.inventory_item_count("pill")
	var herbs_before := state.inventory_item_count("herb")
	_expect_true("alchemy works without characters", state.craft_alchemy_recipe("pill", 2))
	_expect_equal("alchemy spends fixed materials", state.inventory_item_count("herb"), herbs_before - 4)
	_expect_true("alchemy outputs immediately", state.inventory_item_count("pill") >= pills_before + 2)
	_expect_equal("forge proficiency granted", state.task_exp_for(GameDefs.TaskType.FORGE), 5)
	_expect_equal("alchemy proficiency granted", state.task_exp_for(GameDefs.TaskType.ALCHEMY), 5)


func _check_permanent_quality_items() -> void:
	var state := _fresh_state()
	var quality_item := {
		"instance_id": "quality-valid",
		"item_id": "quality-valid",
		"name": "测试品质道具",
		"type": DataTables.ITEM_TYPE_MATERIAL,
		"stackable": true,
		"count": 2,
		"payload": {"permanent_building_quality": {"building_id": "forge", "amount": 2}},
	}
	state.inventory.append(quality_item)
	_expect_true("quality payload is usable", state.use_inventory_item("quality-valid"))
	_expect_equal("quality item consumed once", state.inventory_item_count("quality-valid"), 1)
	_expect_equal("quality persists on building", state.building_output_quality("forge"), 2)
	_expect_approx("quality adds five percent per point", state.forge_rarity_upgrade_chance(), 0.1)
	state.permanent_building_bonuses["forge"]["output_quality"] = 100
	_expect_approx("forge chance clamps at ninety-five percent", state.forge_rarity_upgrade_chance(), 0.95)
	_expect_equal("quality included in save", int(state.to_save_data().get("permanent_building_bonuses", {}).get("forge", {}).get("output_quality", 0)), 100)

	var invalid_item := quality_item.duplicate(true)
	invalid_item["instance_id"] = "quality-invalid"
	invalid_item["item_id"] = "quality-invalid"
	invalid_item["count"] = 1
	invalid_item["payload"]["permanent_building_quality"]["building_id"] = "recruit"
	state.inventory.append(invalid_item)
	_expect_true("invalid quality payload rejected", not state.use_inventory_item("quality-invalid"))
	_expect_equal("invalid quality item not consumed", state.inventory_item_count("quality-invalid"), 1)


func _check_legacy_migration() -> void:
	var state := _fresh_state()
	var farm_slot := {
		"status": "growing",
		"crop_id": "herb",
		"worker_id": "old-worker",
		"worker_name": "旧角色",
		"elapsed_seconds": 123.0,
		"growth_seconds": 600.0,
		"harvest_amount": 9,
	}
	state.load_save_data({
		"schema_version": 11,
		"inventory": [],
		"companions": [{"id": "old-worker", "innate_traits": ["craft_touch", "good_root"], "skills": [], "stats": {}}],
		"recruit_candidates": [{"id": "candidate", "innate_traits": [{"id": "pill_sense"}]}],
		"farm_slots": [farm_slot],
		"production_jobs": {
			"forge": {"building_id": "forge", "status": "running", "member_level": 12, "craft_bonus": 3, "output_count": 1, "rarity_upgrade_chance": 0.0},
			"alchemy": {"building_id": "alchemy", "status": "claimable", "result_item_id": "pill", "amount": 2, "output_multiplier": 1, "extra_chance": 0.0},
		},
	})
	_expect_equal("legacy companion trait removed", state.companions[0].get("innate_traits", []), ["good_root"])
	_expect_equal("legacy candidate trait removed", state.recruit_candidates[0].get("innate_traits", []).size(), 0)
	_expect_equal("legacy farm elapsed preserved", float(state.farm_slots[0].get("elapsed_seconds", 0.0)), 123.0)
	_expect_equal("legacy farm harvest preserved", int(state.farm_slots[0].get("harvest_amount", 0)), 9)
	_expect_true("legacy farm worker removed", not state.farm_slots[0].has("worker_id"))
	_expect_equal("legacy forge settled", state.inventory_total_for_type(DataTables.ITEM_TYPE_EQUIPMENT), 1)
	_expect_equal("legacy alchemy settled", state.inventory_item_count("pill"), 2)
	_expect_true("new saves omit production jobs", not state.to_save_data().has("production_jobs"))


func _check_unresolved_legacy_job() -> void:
	var state := _fresh_state()
	state.load_save_data({
		"schema_version": 11,
		"inventory": [],
		"production_jobs": {
			"alchemy": {"building_id": "alchemy", "status": "running", "result_item_id": "missing.mod.pill", "amount": 1},
		},
	})
	_expect_equal("missing mod job quarantined", state.orphaned_mod_data.get("production_jobs", []).size(), 1)


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_approx(label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
