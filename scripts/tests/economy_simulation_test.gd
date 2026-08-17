extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_simulate_first_hour()
	_simulate_levels_1_to_46()
	_check_weighted_salvage()
	_check_breakthrough_reachability()
	if failures.is_empty():
		print("ECONOMY_SIMULATION_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _simulate_first_hour() -> void:
	var state := GameState.new()
	state.inventory.clear()
	state.rng.seed = 20260817
	var controller := CombatController.new()
	controller.enemy = DataTables.create_enemy(1, state.rng, "forest_wolf")
	for _fight in range(120):
		controller._resolve_drops(state)
	var herb := state.inventory_item_count("herb")
	var ore := state.inventory_item_count("ore")
	var spirit := state.inventory_item_count("spirit_stone")
	var crop := state.inventory_item_count("woodvine")
	var stone := state.inventory_item_count("spirit_stone_wood")
	_expect_true("first hour herb remains primary", herb >= 70 and herb <= 130)
	_expect_true("first hour ore remains available", ore >= 20 and ore <= 52)
	_expect_true("first hour spirit stones remain scarce", spirit >= 4 and spirit <= 22)
	_expect_true("element crop does not replace basics", crop >= 10 and crop <= 38)
	_expect_true("element stones remain supplementary", stone >= 2 and stone <= 18)


func _simulate_levels_1_to_46() -> void:
	var state := GameState.new()
	var previous_cap := 0
	for level in range(1, 47):
		state.account_progression["expedition_level"] = level
		var cap := state.building_level_cap()
		_expect_true("building cap monotonic at %d" % level, cap >= previous_cap)
		_expect_true("building cap bounded at %d" % level, cap >= 1 and cap <= 10)
		previous_cap = cap
	for building_level in range(1, 11):
		var requirement := state.building_level_requirement(building_level)
		state.account_progression["expedition_level"] = requirement
		_expect_true("building level %d opens on requirement" % building_level, state.building_level_cap() >= building_level)
	_expect_equal("level 46 reaches building ten", previous_cap, 10)


func _check_weighted_salvage() -> void:
	var expected := 0.0
	var total_weight := 0.0
	for rarity in DataTables.EQUIPMENT_RARITY_ORDER:
		var weight := float(DataTables.EQUIPMENT_RARITY_WEIGHTS.get(rarity, 0))
		expected += weight * float(DataTables.equipment_salvage_ore(str(rarity)))
		total_weight += weight
	expected /= maxf(1.0, total_weight)
	_expect_true("weighted salvage stays below forge cost", expected < 4.0)


func _check_breakthrough_reachability() -> void:
	var state := GameState.new()
	state.account_progression["expedition_level"] = 6
	state.building_levels["alchemy"] = 2
	state._ensure_building_unlocked_recipes()
	_expect_true("breakthrough recipe reachable by expedition six", state.known_alchemy_recipes.has("breakthrough_pill"))
	var recipe := DataTables.alchemy_recipe_def("breakthrough_pill")
	_expect_equal("breakthrough uses one base pill", int(recipe.get("materials", [])[0].get("amount", 0)), 1)
	_expect_equal("breakthrough uses eight herb", int(recipe.get("materials", [])[1].get("amount", 0)), 8)


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
