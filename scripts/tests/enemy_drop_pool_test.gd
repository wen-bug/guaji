extends Node

const NORMAL_ENEMIES := ["forest_wolf", "venom_spider", "ember_gnome", "stone_lizard", "iron_lancer", "tide_fish"]
const ELITE_ENEMIES := ["blight_shaman", "stone_overlord"]
const BOSS_ENEMIES := ["abyssal_turtle"]
const NORMAL_ITEMS := ["herb", "ore", "spirit_stone", "blade_grass", "ironroot", "blood_ginseng", "spirit_lotus", "bone_bamboo", "woodvine", "flame_flower", "earth_moss", "metal_reed", "water_orchid"]
const ELITE_ITEMS := ["spirit_stone_wood", "spirit_stone_fire", "spirit_stone_earth", "spirit_stone_metal", "spirit_stone_water", "farm_speed_talisman", "refine_talisman"]
const BOSS_ITEMS := ["pill", "breakthrough_pill"]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_profile_data()
	_check_enemy_bindings()
	_check_rank_profile_deduplication()
	_check_normal_runtime()
	_check_elite_runtime()
	_check_boss_runtime()
	_check_overlapping_sources()
	if failures.is_empty():
		print("ENEMY_DROP_POOL_TEST_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _fresh_state(seed_value: int) -> GameState:
	var state := GameState.new()
	state.inventory.clear()
	state.companions.clear()
	state.party_order.clear()
	state.reserve_order.clear()
	state.recruit_candidates.clear()
	state.rng.seed = seed_value
	return state


func _check_profile_data() -> void:
	_expect_true("class drop profile validation", DataTables.enemy_class_drop_profile_errors().is_empty())
	var expected_by_class := {
		DataTables.ENEMY_CLASS_NORMAL: NORMAL_ITEMS,
		DataTables.ENEMY_CLASS_ELITE: ELITE_ITEMS,
		DataTables.ENEMY_CLASS_BOSS: BOSS_ITEMS,
	}
	var assigned: Dictionary = {}
	for enemy_class in expected_by_class:
		var profile: Dictionary = DataTables.enemy_class_drop_profile(str(enemy_class))
		var ids := _entry_ids(profile)
		var expected: Array = expected_by_class[enemy_class]
		_expect_equal("%s pool size" % enemy_class, ids.size(), expected.size())
		for item_id in expected:
			_expect_true("%s contains %s" % [enemy_class, item_id], ids.has(item_id))
			_expect_true("%s item exists" % item_id, not DataTables.item_definition(str(item_id)).is_empty())
		for item_id in ids:
			_expect_true("%s appears in only one class pool" % item_id, not assigned.has(item_id))
			assigned[item_id] = enemy_class
		for entry_value in profile.get("entries", []):
			var entry: Dictionary = entry_value
			_expect_equal("%s amount" % entry.get("item_id", ""), int(entry.get("amount", 0)), 1)
	var normal_profile := DataTables.enemy_class_drop_profile(DataTables.ENEMY_CLASS_NORMAL)
	var normal_chances := {"herb": 0.55, "ore": 0.30, "spirit_stone": 0.10}
	for item_id in NORMAL_ITEMS:
		var expected_chance: float = float(normal_chances.get(item_id, 0.02))
		_expect_approx("%s normal chance" % item_id, _entry_number(normal_profile, str(item_id), "chance"), expected_chance)
	var elite_profile := DataTables.enemy_class_drop_profile(DataTables.ENEMY_CLASS_ELITE)
	for item_id in ELITE_ITEMS:
		var expected_chance := 0.05 if ["farm_speed_talisman", "refine_talisman"].has(item_id) else 0.10
		_expect_approx("%s elite chance" % item_id, _entry_number(elite_profile, str(item_id), "chance"), expected_chance)
	var boss_profile := DataTables.enemy_class_drop_profile(DataTables.ENEMY_CLASS_BOSS)
	_expect_equal("boss mode", str(boss_profile.get("mode", "")), "weighted_one")
	for item_id in BOSS_ITEMS:
		_expect_approx("%s boss weight" % item_id, _entry_number(boss_profile, str(item_id), "weight"), 1.0)


func _check_enemy_bindings() -> void:
	var state := _fresh_state(101)
	var equipment_chances := {
		DataTables.ENEMY_CLASS_NORMAL: 0.05,
		DataTables.ENEMY_CLASS_ELITE: 0.12,
		DataTables.ENEMY_CLASS_BOSS: 0.25,
	}
	var enemies_by_class := {
		DataTables.ENEMY_CLASS_NORMAL: NORMAL_ENEMIES,
		DataTables.ENEMY_CLASS_ELITE: ELITE_ENEMIES,
		DataTables.ENEMY_CLASS_BOSS: BOSS_ENEMIES,
	}
	for enemy_class in enemies_by_class:
		for enemy_id in enemies_by_class[enemy_class]:
			var generated := DataTables.create_enemy(1, state.rng, str(enemy_id))
			_expect_equal("%s class" % enemy_id, str(generated.get("enemy_class", "")), str(enemy_class))
			_expect_equal("%s starts at t1" % enemy_id, str(generated.get("rank", "")), "t1")
			_expect_true("%s class pool enabled" % enemy_id, bool(generated.get("use_class_drop_pool", false)))
			_expect_true("%s rank pool disabled" % enemy_id, not bool(generated.get("use_rank_drop_pool", true)))
			_expect_true("%s explicit drops cleared" % enemy_id, generated.get("drops", {}).is_empty())
			_expect_equal("%s receives full class pool" % enemy_id, _entry_ids(generated.get("class_drop_profile", {})).size(), _entry_ids(DataTables.enemy_class_drop_profile(str(enemy_class))).size())
			_expect_approx("%s equipment chance" % enemy_id, float(generated.get("equipment_drop_chance", 0.0)), float(equipment_chances[enemy_class]))
	var dummy := DataTables.create_enemy(1, state.rng, "training_dummy")
	_expect_true("training dummy class pool disabled", not bool(dummy.get("use_class_drop_pool", false)))
	_expect_true("training dummy has no drops", not bool(dummy.get("use_drop", true)))


func _check_rank_profile_deduplication() -> void:
	var profile := DataTables.rank_drop_profile("t1", {"categories": ["basic_material", "basic_material"]})
	var ids: Array = profile.get("items", [])
	_expect_equal("duplicated category expands to unique items", ids.size(), 3)
	_expect_true("deduplicated rank pool has herb", ids.has("herb"))
	_expect_true("deduplicated rank pool has ore", ids.has("ore"))
	_expect_true("deduplicated rank pool has spirit stone", ids.has("spirit_stone"))


func _check_normal_runtime() -> void:
	var state := _fresh_state(20260818)
	var controller := CombatController.new()
	controller.enemy = DataTables.create_enemy(1, state.rng, "forest_wolf")
	var saw_multiple_different_items := false
	for _fight in range(400):
		var before := _counts_for(state, NORMAL_ITEMS)
		controller._resolve_drops(state)
		var changed := 0
		for item_id in NORMAL_ITEMS:
			var delta := state.inventory_item_count(str(item_id)) - int(before.get(item_id, 0))
			_expect_true("normal single-kill amount for %s" % item_id, delta >= 0 and delta <= 1)
			if delta == 1:
				changed += 1
		if changed > 1:
			saw_multiple_different_items = true
	_expect_true("normal independent checks can award multiple different items", saw_multiple_different_items)
	_expect_true("normal pool produces drops", _pool_total(state, NORMAL_ITEMS) > 0)
	_expect_equal("normal enemies do not drop elite items", _pool_total(state, ELITE_ITEMS), 0)
	_expect_equal("normal enemies do not drop boss items", _pool_total(state, BOSS_ITEMS), 0)


func _check_elite_runtime() -> void:
	var state := _fresh_state(20260819)
	var controller := CombatController.new()
	controller.enemy = DataTables.create_enemy(1, state.rng, "blight_shaman")
	for _fight in range(300):
		controller._resolve_drops(state)
	_expect_true("elite pool produces drops", _pool_total(state, ELITE_ITEMS) > 0)
	_expect_equal("elite enemies do not drop normal items", _pool_total(state, NORMAL_ITEMS), 0)
	_expect_equal("elite enemies do not drop boss items", _pool_total(state, BOSS_ITEMS), 0)


func _check_boss_runtime() -> void:
	var state := _fresh_state(20260820)
	var controller := CombatController.new()
	controller.enemy = DataTables.create_enemy(1, state.rng, "abyssal_turtle")
	for fight in range(200):
		var before := _pool_total(state, BOSS_ITEMS)
		controller._resolve_drops(state)
		_expect_equal("boss kill %d awards exactly one class item" % fight, _pool_total(state, BOSS_ITEMS) - before, 1)
	_expect_true("boss can drop pill", state.inventory_item_count("pill") > 0)
	_expect_true("boss can drop breakthrough pill", state.inventory_item_count("breakthrough_pill") > 0)
	_expect_equal("boss does not drop normal items", _pool_total(state, NORMAL_ITEMS), 0)
	_expect_equal("boss does not drop elite items", _pool_total(state, ELITE_ITEMS), 0)


func _check_overlapping_sources() -> void:
	var state := _fresh_state(303)
	var controller := CombatController.new()
	controller.enemy = {
		"use_drop": true,
		"drops": {"herb": {"chance": 1.0, "min": 1, "max": 1}},
		"use_class_drop_pool": true,
		"class_drop_profile": {"mode": "independent", "entries": [{"item_id": "herb", "chance": 1.0, "amount": 1}]},
		"use_rank_drop_pool": true,
		"drop_profile": {"base_chance": 1.0, "items": ["herb"], "rarity_weights": {"t1": 100}},
		"rank_level": 1,
	}
	controller._resolve_drops(state)
	_expect_equal("explicit class and rank overlap awards once", state.inventory_item_count("herb"), 1)


func _entry_ids(profile: Dictionary) -> Array:
	var ids: Array = []
	for entry_value in profile.get("entries", []):
		if entry_value is Dictionary:
			ids.append(str(entry_value.get("item_id", "")))
	return ids


func _entry_number(profile: Dictionary, item_id: String, key: String) -> float:
	for entry_value in profile.get("entries", []):
		if entry_value is Dictionary and str(entry_value.get("item_id", "")) == item_id:
			return float(entry_value.get(key, 0.0))
	return -1.0


func _counts_for(state: GameState, item_ids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for item_id in item_ids:
		counts[item_id] = state.inventory_item_count(str(item_id))
	return counts


func _pool_total(state: GameState, item_ids: Array) -> int:
	var total := 0
	for item_id in item_ids:
		total += state.inventory_item_count(str(item_id))
	return total


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_approx(label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
