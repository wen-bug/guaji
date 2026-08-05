extends Node

const ACTOR_SCENE := preload("res://scripts/actors/actor_controller.tscn")
const BATTLE_MAP_SCENE := preload("res://scripts/map/battle_map.tscn")
const MapEncounterProfileScript = preload("res://scripts/map/encounters/map_encounter_profile.gd")
const MapEncounterVariantScript = preload("res://scripts/map/encounters/map_encounter_variant.gd")
const MapEnemyClassPoolScript = preload("res://scripts/map/encounters/map_enemy_class_pool.gd")

class FakeGameState:
	extends RefCounted

	var rng := RandomNumberGenerator.new()
	var expedition_exp := 0
	var member_exp := 0
	var resources: Dictionary = {}
	var equipment_count := 0
	var member: Dictionary = {
		"id": "hero",
		"name": "测试角色",
		"visual_id": "actor_default",
		"stats": {"hp": 80, "max_hp": 80, "mp": 40, "max_mp": 40, "attack": 8, "defense": 2},
		"elements": {"wood": 1, "fire": 1, "earth": 1, "metal": 1, "water": 1},
	}

	func _init() -> void:
		rng.seed = 17

	func active_party_members() -> Array:
		return [member]

	func member_by_id(_member_id: String) -> Dictionary:
		return member

	func expedition_level() -> int:
		return 1

	func total_attack_for(_member_id: String) -> int:
		return int(member.get("stats", {}).get("attack", 0))

	func total_defense_for(_member_id: String) -> int:
		return int(member.get("stats", {}).get("defense", 0))

	func total_stat_for(_member_id: String, stat_id: String) -> int:
		return int(member.get("stats", {}).get(stat_id, 0))

	func total_element_for(_member_id: String, element_id: String) -> int:
		return int(member.get("elements", {}).get(element_id, 0))

	func dominant_element_for(_member_id: String) -> String:
		return "wood"

	func add_expedition_exp(amount: int) -> void:
		expedition_exp += amount

	func add_exp_for_member(_member_id: String, amount: int) -> void:
		member_exp += amount

	func gain_resource(item_id: String, amount: int) -> void:
		resources[item_id] = int(resources.get(item_id, 0)) + amount

	func add_equipment(_item: Dictionary) -> void:
		equipment_count += 1

	func craft_bonus() -> int:
		return 0


var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_default_map()
	_check_map_selection()
	_check_count_clamps()
	_check_seeded_weights()
	_check_fixed_and_fallback_variants()
	await _check_combat_controller_sequence()
	if failures.is_empty():
		print("MAP_ENCOUNTER_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_default_map() -> void:
	var map := BATTLE_MAP_SCENE.instantiate() as BattleMap
	for entry in [[1, 2], [2, 4], [4, 8], [9, 8]]:
		var rng := _seeded_rng(100 + int(entry[0]))
		var ids := map.roll_encounter(int(entry[0]), 1, rng)
		_expect_equal("default count for party %d" % int(entry[0]), ids.size(), int(entry[1]))
		for enemy_id in ids:
			_expect_string("default enemy", enemy_id, "forest_wolf")
	map.free()


func _check_map_selection() -> void:
	var map := BATTLE_MAP_SCENE.instantiate() as BattleMap
	var summaries := map.map_summaries(1)
	_expect_equal("configured map count", summaries.size(), 2)
	_expect_true("forest map selectable", map.select_map("verdant_forest", 1))
	_expect_string("forest map name", map.current_map_name(), "青木林")
	var forest_ids := map.roll_encounter(1, 1, _seeded_rng(9))
	_expect_array("forest encounter", forest_ids, ["forest_wolf", "forest_wolf"])
	_expect_true("training map selectable", map.select_map("training_ground", 1))
	_expect_string("training map name", map.current_map_name(), "试炼场")
	_expect_array("training encounter", map.roll_encounter(4, 1, _seeded_rng(9)), ["training_dummy"])
	_expect_true("unknown map rejected", not map.select_map("missing_map", 99))
	map.free()
	var saved_state := GameState.new()
	saved_state.set_selected_expedition_map_id("training_ground")
	var restored_state := GameState.new()
	restored_state.load_save_data(saved_state.to_save_data())
	_expect_string("selected map persists", restored_state.selected_expedition_map_id, "training_ground")


func _check_count_clamps() -> void:
	var profile := _random_profile("count_clamp", "forest_wolf", 3, 3, 5)
	_expect_equal("minimum count", profile.roll_enemy_ids(0, 1, _seeded_rng(1)).size(), 3)
	_expect_equal("maximum count", profile.roll_enemy_ids(9, 1, _seeded_rng(1)).size(), 5)


func _check_seeded_weights() -> void:
	var profile := MapEncounterProfileScript.new()
	profile.profile_id = "weighted_pools"
	profile.fallback_enemy_id = "forest_wolf"
	profile.enemies_per_party_member = 1
	profile.min_enemy_count = 1
	profile.max_enemy_count = 1
	var variant := MapEncounterVariantScript.new()
	variant.id = "weighted_classes"
	var wolf_pool := _pool("normal", 1.0, ["forest_wolf"])
	var dummy_pool := _pool("normal", 3.0, ["training_dummy"])
	variant.class_pools.append(wolf_pool)
	variant.class_pools.append(dummy_pool)
	profile.variants.append(variant)

	var first_rng := _seeded_rng(913)
	var second_rng := _seeded_rng(913)
	var first_sequence: Array[String] = []
	var second_sequence: Array[String] = []
	var dummy_count := 0
	for _index in range(400):
		var first := profile.roll_enemy_ids(1, 1, first_rng)
		var second := profile.roll_enemy_ids(1, 1, second_rng)
		first_sequence.append(first[0])
		second_sequence.append(second[0])
		if first[0] == "training_dummy":
			dummy_count += 1
	_expect_true("seeded pool rolls are deterministic", first_sequence == second_sequence)
	_expect_true("weighted pool favors weight 3", dummy_count >= 260 and dummy_count <= 340)

	var variant_profile := MapEncounterProfileScript.new()
	variant_profile.profile_id = "weighted_variants"
	variant_profile.fallback_enemy_id = "forest_wolf"
	var wolf_variant := _fixed_variant("wolf", 1.0, ["forest_wolf"])
	var dummy_variant := _fixed_variant("dummy", 3.0, ["training_dummy"])
	variant_profile.variants.append(wolf_variant)
	variant_profile.variants.append(dummy_variant)
	var variant_rng := _seeded_rng(221)
	dummy_count = 0
	for _index in range(400):
		if variant_profile.roll_enemy_ids(1, 1, variant_rng)[0] == "training_dummy":
			dummy_count += 1
	_expect_true("weighted variant favors weight 3", dummy_count >= 260 and dummy_count <= 340)


func _check_fixed_and_fallback_variants() -> void:
	var fixed_profile := MapEncounterProfileScript.new()
	fixed_profile.profile_id = "fixed_order"
	fixed_profile.fallback_enemy_id = "forest_wolf"
	fixed_profile.variants.append(_fixed_variant("mixed", 1.0, ["training_dummy", "forest_wolf", "training_dummy"]))
	_expect_array("fixed order", fixed_profile.roll_enemy_ids(8, 1, _seeded_rng(5)), ["training_dummy", "forest_wolf", "training_dummy"])

	var filtered_profile := MapEncounterProfileScript.new()
	filtered_profile.profile_id = "filtered_fixed"
	filtered_profile.fallback_enemy_id = "training_dummy"
	filtered_profile.variants.append(_fixed_variant("filtered", 1.0, ["missing_enemy", "forest_wolf"]))
	_expect_array("invalid fixed ids filtered", filtered_profile.roll_enemy_ids(1, 1, _seeded_rng(5)), ["forest_wolf"])

	var fallback_profile := MapEncounterProfileScript.new()
	fallback_profile.profile_id = "map_fallback"
	fallback_profile.fallback_enemy_id = "forest_wolf"
	fallback_profile.variants.append(_fixed_variant("invalid", 1.0, ["missing_enemy"]))
	_expect_array("map-specific fallback", fallback_profile.roll_enemy_ids(1, 1, _seeded_rng(5)), ["forest_wolf"])

	var class_profile := MapEncounterProfileScript.new()
	class_profile.profile_id = "class_filter"
	class_profile.fallback_enemy_id = "training_dummy"
	var class_variant := MapEncounterVariantScript.new()
	class_variant.class_pools.append(_pool("elite", 1.0, ["forest_wolf"]))
	class_profile.variants.append(class_variant)
	_expect_array("class mismatch rejected", class_profile.roll_enemy_ids(1, 1, _seeded_rng(5)), ["training_dummy"])


func _check_combat_controller_sequence() -> void:
	var game_state := FakeGameState.new()
	var actor := ACTOR_SCENE.instantiate() as ActorController
	add_child(actor)
	actor.configure_member(game_state.member, 0)
	var controller := CombatController.new()
	add_child(controller)
	controller.set_party_views({"hero": actor})
	controller.begin_encounter(game_state, null, ["training_dummy", "forest_wolf"])
	_expect_true("heterogeneous encounter starts", controller.active)
	_expect_array("heterogeneous ids retained", controller._enemy_group_ids(), ["training_dummy", "forest_wolf"])
	_expect_string("first enemy scene", controller.current_enemy_node.template_id(), "training_dummy")
	var expected_exp := int(controller.enemy_group[0].get("exp", 0)) + int(controller.enemy_group[1].get("exp", 0))

	controller._enemy_death_waiting = true
	controller._on_enemy_death_finished()
	_expect_equal("enemy group advances", controller.enemy_group_index, 1)
	_expect_string("second enemy scene", controller.current_enemy_node.template_id(), "forest_wolf")
	_expect_equal("first enemy reward", game_state.expedition_exp, int(controller.enemy_group[0].get("exp", 0)))

	controller._enemy_death_waiting = true
	controller._on_enemy_death_finished()
	_expect_true("heterogeneous encounter finishes", controller.finished and not controller.active)
	_expect_equal("all enemy rewards", game_state.expedition_exp, expected_exp)
	_expect_equal("member receives all rewards", game_state.member_exp, expected_exp)

	_expect_array("legacy string repeats", controller._normalized_encounter_enemy_ids("forest_wolf", 3), ["forest_wolf", "forest_wolf", "forest_wolf"])
	_expect_array("invalid array ids filtered", controller._normalized_encounter_enemy_ids(["missing_enemy", "forest_wolf"], 8), ["forest_wolf"])
	controller.clear()
	controller.queue_free()
	actor.queue_free()
	await get_tree().process_frame


func _random_profile(profile_id: String, enemy_id: String, per_member: int, minimum: int, maximum: int) -> Resource:
	var profile := MapEncounterProfileScript.new()
	profile.profile_id = profile_id
	profile.fallback_enemy_id = enemy_id
	profile.enemies_per_party_member = per_member
	profile.min_enemy_count = minimum
	profile.max_enemy_count = maximum
	var variant := MapEncounterVariantScript.new()
	variant.class_pools.append(_pool("normal", 1.0, [enemy_id]))
	profile.variants.append(variant)
	return profile


func _pool(encounter_class: String, weight: float, enemy_ids: Array[String]) -> Resource:
	var pool := MapEnemyClassPoolScript.new()
	pool.encounter_class = encounter_class
	pool.weight = weight
	pool.enemy_ids = enemy_ids
	return pool


func _fixed_variant(variant_id: String, weight: float, enemy_ids: Array[String]) -> Resource:
	var variant := MapEncounterVariantScript.new()
	variant.id = variant_id
	variant.weight = weight
	variant.fixed_enemy_ids = enemy_ids
	return variant


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _expect_equal(label: String, actual: int, expected: int) -> void:
	if actual != expected:
		failures.append("%s: expected %d, got %d" % [label, expected, actual])


func _expect_string(label: String, actual: String, expected: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_array(label: String, actual: Array[String], expected: Array[String]) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_true(label: String, value: bool) -> void:
	if not value:
		failures.append("%s: expected true" % label)
