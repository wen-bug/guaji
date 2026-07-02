extends SceneTree

const GameStateScript = preload("res://scripts/game/core/game_state.gd")
const CombatControllerScript = preload("res://scripts/game/combat/combat_controller.gd")

var failures: Array[String] = []


func _init() -> void:
	_run_all()
	if failures.is_empty():
		print("recruit_party_tests: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _run_all() -> void:
	_test_old_save_creates_player_party()
	_test_old_save_migrates_free_points()
	_test_save_roundtrip_preserves_runtime_state()
	_test_level_up_auto_assigns_player_points()
	_test_recruit_cost_and_party_limit()
	_test_recruit_candidate_shape()
	_test_companion_level_up_uses_primary_growth()
	_test_party_order()
	_test_equipment_single_owner()
	_test_party_combat_exp()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _attribute_point_total(member: Dictionary) -> int:
	var member_stats: Dictionary = member.get("stats", {})
	var member_elements: Dictionary = member.get("elements", {})
	var total := 0
	total += int(member_stats.get("attack", 0))
	total += int(member_stats.get("defense", 0))
	total += int(member_stats.get("root_bone", 0))
	total += int(int(member_stats.get("max_hp", 0)) / 4)
	total += int(int(member_stats.get("max_mp", 0)) / 2)
	total += int(member_elements.get("wood", 0))
	total += int(member_elements.get("fire", 0))
	total += int(member_elements.get("earth", 0))
	total += int(member_elements.get("metal", 0))
	total += int(member_elements.get("water", 0))
	return total


func _stat_value(member: Dictionary, stat_id: String) -> int:
	if stat_id == "max_hp":
		return int(int(member.get("stats", {}).get("max_hp", 0)) / 4)
	if stat_id == "max_mp":
		return int(int(member.get("stats", {}).get("max_mp", 0)) / 2)
	if stat_id.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
		return int(member.get("elements", {}).get(DataTables.element_id_from_attribute(stat_id), 0))
	return int(member.get("stats", {}).get(stat_id, 0))


func _primary_point_total(member: Dictionary, primary_stats: Array) -> int:
	var total := 0
	for stat_id in primary_stats:
		total += _stat_value(member, str(stat_id))
	return total


func _test_old_save_creates_player_party() -> void:
	var state = GameStateScript.new()
	state.load_save_data({
		"stats": {"level": 3, "attack": 12},
		"task_exp": {"meditate": 7},
	})
	_assert(state.party_order.size() == 1 and state.party_order[0] == GameState.PLAYER_ID, "old save should create player-only party")
	_assert(int(state.stats.get("level", 0)) == 3, "old save should keep player level")
	_assert(int(state.task_exp.get("recruit", 0)) == 7, "old meditate task exp should migrate to recruit")


func _test_old_save_migrates_free_points() -> void:
	var state = GameStateScript.new()
	var base_player_total := _attribute_point_total(state.player_member())
	var companion := {
		"id": "companion_old",
		"name": "旧友",
		"kind": "companion",
		"stats": {"free_points": GameState.LEVEL_ATTRIBUTE_POINTS},
		"growth_primary_stats": ["attack", "defense", "root_bone"],
	}
	var base_companion_total := _attribute_point_total({
		"stats": state._base_member_stats(),
		"elements": state._base_member_elements(),
	})
	state.load_save_data({
		"stats": {"free_points": GameState.LEVEL_ATTRIBUTE_POINTS},
		"companions": [companion],
		"party_order": [GameState.PLAYER_ID, "companion_old"],
	})
	var migrated_companion := state.member_by_id("companion_old")
	_assert(int(state.stats.get("free_points", 0)) == 0, "old player free points should migrate and clear")
	_assert(int(migrated_companion.get("stats", {}).get("free_points", 0)) == 0, "old companion free points should migrate and clear")
	_assert(_attribute_point_total(state.player_member()) == base_player_total + GameState.LEVEL_ATTRIBUTE_POINTS, "old player free points should become attributes")
	_assert(_attribute_point_total(migrated_companion) == base_companion_total + GameState.LEVEL_ATTRIBUTE_POINTS, "old companion free points should become attributes")


func _test_save_roundtrip_preserves_runtime_state() -> void:
	var state = GameStateScript.new()
	state.debug_add_item("ore", 20)
	state.generate_recruit_candidates(false)
	state.recruit_candidate(str(state.recruit_candidates[0].get("candidate_id", "")))
	state.active_buffs.append({"item_id": "pill", "name": "测试增益", "stat": "attack", "amount": 3, "remaining": 9.5})
	state.farm_speed_buffs.append({"item_id": "farm_speed_talisman", "multiplier": 2.0, "remaining_seconds": 12.0})
	var snapshot: Dictionary = state.to_save_data()
	var restored = GameStateScript.new()
	restored.load_save_data(snapshot)
	_assert(int(snapshot.get("schema_version", 0)) == GameState.SAVE_SCHEMA_VERSION, "save should include current schema version")
	_assert(restored.party_order == state.party_order, "save should preserve party order")
	_assert(restored.companions.size() == state.companions.size(), "save should preserve companions")
	_assert(restored.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL) == state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL), "save should preserve inventory totals")
	_assert(restored.active_buffs.size() == 1 and int(restored.active_buffs[0].get("amount", 0)) == 3, "save should preserve active buffs")
	_assert(restored.farm_speed_buffs.size() == 1 and int(restored.farm_speed_buffs[0].get("remaining_seconds", 0)) == 12, "save should preserve farm speed buffs")


func _test_level_up_auto_assigns_player_points() -> void:
	var state = GameStateScript.new()
	var total_before := _attribute_point_total(state.player_member())
	state.add_exp(int(state.stats.get("next_exp", 40)))
	_assert(int(state.stats.get("level", 0)) == 2, "level up should increase player level")
	_assert(int(state.stats.get("free_points", 0)) == 0, "level up should not leave manual attribute points")
	_assert(_attribute_point_total(state.player_member()) == total_before + GameState.LEVEL_ATTRIBUTE_POINTS, "level up should auto assign player points")
	_assert(not state.allocate_attribute_point(GameState.PLAYER_ID, "attack"), "manual allocation should be retired")


func _test_recruit_cost_and_party_limit() -> void:
	var state = GameStateScript.new()
	state.debug_add_item("ore", 20)
	for _index in range(3):
		state.generate_recruit_candidates(false)
		var candidate_id := str(state.recruit_candidates[0].get("candidate_id", ""))
		var material_before := state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL)
		_assert(state.recruit_candidate(candidate_id), "recruit should succeed with material and room")
		_assert(state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL) == material_before - GameState.RECRUIT_COST_MATERIAL, "recruit should spend material")
	state.generate_recruit_candidates(false)
	_assert(not state.recruit_candidate(str(state.recruit_candidates[0].get("candidate_id", ""))), "recruit should fail when party is full")
	_assert(state.party_member_count() == GameState.PARTY_MAX_SIZE, "party should cap at four")


func _test_recruit_candidate_shape() -> void:
	var state = GameStateScript.new()
	state.stats["level"] = 4
	state.generate_recruit_candidates(false)
	var candidate: Dictionary = state.recruit_candidates[0]
	_assert(int(candidate.get("stats", {}).get("level", 0)) == 4, "candidate should match player level")
	_assert(candidate.get("stats", {}).has("attack"), "candidate should have stats")
	_assert(candidate.get("elements", {}).has("wood"), "candidate should have elements")
	_assert(candidate.get("equipped", {}).has("weapon"), "candidate should have equipment slots")
	_assert(not candidate.get("skills", []).is_empty(), "candidate should have default skill")
	var primary_stats: Array = candidate.get("growth_primary_stats", [])
	_assert(primary_stats.size() == 3, "candidate should have three primary growth stats")
	for stat_id in primary_stats:
		_assert(GameState.RANDOM_POINT_TARGETS.has(str(stat_id)), "candidate primary stat should be valid")
	if primary_stats.size() == 3:
		_assert(primary_stats[0] != primary_stats[1] and primary_stats[0] != primary_stats[2] and primary_stats[1] != primary_stats[2], "candidate primary stats should be unique")


func _test_companion_level_up_uses_primary_growth() -> void:
	var state = GameStateScript.new()
	state.debug_add_item("ore", 20)
	state.generate_recruit_candidates(false)
	state.recruit_candidate(str(state.recruit_candidates[0].get("candidate_id", "")))
	var companion_id := str(state.party_order[1])
	var companion := state.member_by_id(companion_id)
	var primary_stats := ["attack", "defense", "root_bone"]
	companion["growth_primary_stats"] = primary_stats
	var total_before := _attribute_point_total(companion)
	var primary_before := _primary_point_total(companion, primary_stats)
	state.add_exp_for_member(companion_id, int(companion.get("stats", {}).get("next_exp", 40)))
	companion = state.member_by_id(companion_id)
	_assert(int(companion.get("stats", {}).get("level", 0)) == 2, "companion level up should increase level")
	_assert(int(companion.get("stats", {}).get("free_points", 0)) == 0, "companion level up should not leave manual points")
	_assert(_attribute_point_total(companion) == total_before + GameState.LEVEL_ATTRIBUTE_POINTS, "companion level up should auto assign points")
	_assert(_primary_point_total(companion, primary_stats) >= primary_before + 4, "companion level up should put at least four points into primary stats")


func _test_party_order() -> void:
	var state = GameStateScript.new()
	state.debug_add_item("ore", 20)
	state.generate_recruit_candidates(false)
	state.recruit_candidate(str(state.recruit_candidates[0].get("candidate_id", "")))
	var companion_id := str(state.party_order[1])
	_assert(state.move_party_member(companion_id, -1), "companion should move up")
	_assert(state.party_order[0] == companion_id, "party order should update")
	_assert(state.party_order.has(GameState.PLAYER_ID), "player should stay in party")


func _test_equipment_single_owner() -> void:
	var state = GameStateScript.new()
	state.debug_add_item("ore", 20)
	state.generate_recruit_candidates(false)
	state.recruit_candidate(str(state.recruit_candidates[0].get("candidate_id", "")))
	var companion_id := str(state.party_order[1])
	var equipment := DataTables.create_equipment_from_template("weapon", 1, state.rng, 0, "", "t1", "debug")
	state.add_inventory_instance(equipment)
	var instance_id := str(equipment.get("instance_id", ""))
	_assert(state.equip_item_for_member(instance_id, GameState.PLAYER_ID), "player should equip weapon")
	_assert(state.equip_item_for_member(instance_id, companion_id), "companion should take weapon")
	_assert(str(state.equipped.get("weapon", "")) == "", "equipment should leave previous player slot")
	_assert(str(state.member_by_id(companion_id).get("equipped", {}).get("weapon", "")) == instance_id, "equipment should belong to companion")


func _test_party_combat_exp() -> void:
	var state = GameStateScript.new()
	state.debug_add_item("ore", 20)
	state.generate_recruit_candidates(false)
	state.recruit_candidate(str(state.recruit_candidates[0].get("candidate_id", "")))
	var controller = CombatControllerScript.new()
	controller.begin_encounter(state, null, "training_dummy")
	for _index in range(240):
		controller.tick(0.2, state)
		if controller.is_finished():
			break
	_assert(controller.is_finished(), "training dummy combat should finish")
	for member in state.party_members():
		_assert(int(member.get("stats", {}).get("exp", 0)) > 0, "each party member should gain exp")
