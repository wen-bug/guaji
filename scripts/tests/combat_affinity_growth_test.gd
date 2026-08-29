extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_affinity_matrix()
	_check_direct_damage_sources()
	_check_dot_and_shield_order()
	_check_enemy_growth_profiles()
	_check_member_growth_and_migration()
	if failures.is_empty():
		print("COMBAT_AFFINITY_GROWTH_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_affinity_matrix() -> void:
	var expected_overcomes := {
		"metal": "wood",
		"wood": "earth",
		"earth": "water",
		"water": "fire",
		"fire": "metal",
	}
	for attacker in DataTables.COMBAT_AFFINITY_IDS:
		for target in DataTables.COMBAT_AFFINITY_IDS:
			var expected := DataTables.AFFINITY_RELATION_NEUTRAL
			if str(expected_overcomes.get(attacker, "")) == target:
				expected = DataTables.AFFINITY_RELATION_OVERCOME
			elif str(expected_overcomes.get(target, "")) == attacker:
				expected = DataTables.AFFINITY_RELATION_RESTRAINED
			_expect_equal("matrix %s -> %s" % [attacker, target], DataTables.combat_affinity_relation(str(attacker), str(target)), expected)


func _check_direct_damage_sources() -> void:
	var executor := CombatSkillExecutor.new()
	var resolver := CombatEffectResolver.new()
	var caster := _enemy_status("caster", "metal", 100, 0)
	var target := _enemy_status("target", "wood", 100, 2)
	var basic := DataTables.create_basic_attack(DataTables.ATTACK_MODE_MELEE, 10)
	var basic_result := executor.execute(caster, [target], basic, resolver)
	_expect_equal("basic attack uses caster affinity", int(basic_result.get("damage", 0)), 10)
	_expect_relation("basic attack relation", basic_result, DataTables.AFFINITY_RELATION_OVERCOME)

	target.data["hp"] = 100
	target.data["combat_affinity"] = "metal"
	target.data["weak_element"] = "fire"
	var fire_skill := _damage_skill("fire", 10)
	var fire_result := executor.execute(caster, [target], fire_skill, resolver)
	_expect_equal("skill uses explicit element and ignores weak_element", int(fire_result.get("damage", 0)), 10)
	_expect_relation("explicit skill relation", fire_result, DataTables.AFFINITY_RELATION_OVERCOME)

	target.data["hp"] = 100
	target.data["combat_affinity"] = "wood"
	var plain_result := executor.execute(caster, [target], _damage_skill("", 10), resolver)
	_expect_equal("elementless skill stays normal", int(plain_result.get("damage", 0)), 8)
	_expect_relation("elementless relation", plain_result, DataTables.AFFINITY_RELATION_NEUTRAL)

	target.data["hp"] = 100
	target.data["combat_affinity"] = "metal"
	caster.data["combat_affinity"] = "wood"
	var restrained_result := executor.execute(caster, [target], basic, resolver)
	_expect_equal("restrained direct damage", int(restrained_result.get("damage", 0)), 6)
	_expect_relation("restrained relation", restrained_result, DataTables.AFFINITY_RELATION_RESTRAINED)
	caster.free()
	target.free()


func _check_dot_and_shield_order() -> void:
	var target := _enemy_status("dot_target", "metal", 100, 0)
	target.add_status_effect({
		"status_id": "affinity_dot",
		"kind": "dot",
		"amount": 8,
		"value": 8,
		"damage_affinity": "fire",
		"duration_turns": 1,
	})
	var events := target.tick_turn_start()
	_expect_equal("dot applies affinity multiplier", int(target.data.get("hp", 0)), 90)
	var tick_event := _event_of_type(events, "status_tick")
	_expect_equal("dot relation metadata", str(tick_event.get("affinity_relation", "")), DataTables.AFFINITY_RELATION_OVERCOME)

	target.data["hp"] = 100
	target.combat_effects.clear()
	target.add_status_effect({"status_id": "shield", "kind": "shield", "amount": 3, "value": 3, "duration_turns": 2})
	var caster := _enemy_status("shield_caster", "fire", 100, 0)
	var result := CombatSkillExecutor.new().execute(caster, [target], _damage_skill("fire", 8), CombatEffectResolver.new())
	_expect_equal("affinity applies before shield", int(result.get("damage", 0)), 7)
	_expect_equal("shield absorbed after affinity", int(result.get("blocked_by_shield", 0)), 3)
	caster.free()
	target.free()


func _check_enemy_growth_profiles() -> void:
	for enemy_id in DataTables.ENEMY_TEMPLATES.keys():
		var enemy_resource := DataTables.enemy_resource(str(enemy_id))
		_expect_true("enemy resource exists %s" % enemy_id, enemy_resource != null)
		if enemy_resource != null:
			_expect_equal("enemy resource id %s" % enemy_id, str(enemy_resource.get("id")), str(enemy_id))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var normal := DataTables.create_enemy(11, rng, "forest_wolf")
	var elite := DataTables.create_enemy(11, rng, "blight_shaman")
	var boss := DataTables.create_enemy(11, rng, "abyssal_turtle")
	var dummy := DataTables.create_enemy(11, rng, "training_dummy")
	_expect_equal("normal growth budget", int(normal.get("attribute_point_budget", -1)), 40)
	_expect_equal("elite growth budget", int(elite.get("attribute_point_budget", -1)), 60)
	_expect_equal("boss growth budget", int(boss.get("attribute_point_budget", -1)), 75)
	_expect_equal("dummy growth budget", int(dummy.get("attribute_point_budget", -1)), 0)
	_expect_equal("boss affinity", str(boss.get("combat_affinity", "")), "water")
	_expect_equal("boss primary", str(boss.get("growth_primary_stat", "")), "max_hp")
	_expect_equal("boss secondary", boss.get("growth_secondary_stats", []), ["defense", "element_water"])
	_expect_equal("dummy affinity", str(dummy.get("combat_affinity", "")), "normal")
	for enemy in [normal, elite, boss]:
		var growth_stats: Array = [enemy.get("growth_primary_stat", "")]
		growth_stats.append_array(enemy.get("growth_secondary_stats", []))
		_expect_equal("enemy growth stats unique %s" % enemy.get("id", ""), _unique_count(growth_stats), 3)
		_expect_true("enemy affinity valid %s" % enemy.get("id", ""), DataTables.COMBAT_AFFINITY_IDS.has(enemy.get("combat_affinity", "")))


func _check_member_growth_and_migration() -> void:
	var state := GameState.new()
	state.rng.seed = 99
	var member := {
		"id": "weighted-member",
		"stats": state.party_service.base_member_stats(),
		"elements": state.party_service.base_member_elements(),
		"growth_primary_stat": "attack",
		"growth_secondary_stats": ["defense", "root_bone"],
		"growth_primary_stats": ["attack", "defense", "root_bone"],
	}
	var gains := state.party_service.apply_companion_attribute_points_to(member, 10000)
	var attack_points := int(gains.get("attack", 0))
	var defense_points := int(gains.get("defense", 0))
	var root_points := int(gains.get("root_bone", 0))
	_expect_true("primary weight near 52 percent", attack_points > 4900 and attack_points < 5500)
	_expect_true("first secondary weight near 17 percent", defense_points > 1400 and defense_points < 2000)
	_expect_true("second secondary weight near 17 percent", root_points > 1400 and root_points < 2000)

	var legacy := GameState.new()
	legacy.load_save_data({
		"schema_version": 16,
		"companions": [{
			"id": "legacy-affinity-member",
			"name": "旧角色",
			"stats": {"level": 5, "hp": 80, "max_hp": 80, "mp": 40, "max_mp": 40, "attack": 8, "defense": 2},
			"elements": {"wood": 3, "fire": 2, "earth": 1, "metal": 1, "water": 1},
			"equipped": {},
			"skills": [],
			"growth_primary_stats": ["attack", "defense", "element_fire"],
		}],
		"party_order": ["legacy-affinity-member"],
		"recruit_candidates": [],
	})
	var migrated: Dictionary = legacy.companions[0]
	var first_affinity := str(migrated.get("combat_affinity", ""))
	_expect_true("migrated affinity valid", DataTables.COMBAT_AFFINITY_IDS.has(first_affinity))
	_expect_equal("legacy primary migrated", str(migrated.get("growth_primary_stat", "")), "attack")
	_expect_equal("legacy secondary migrated", migrated.get("growth_secondary_stats", []), ["defense", "element_fire"])
	_expect_equal("migration preserves attack", int(migrated.get("stats", {}).get("attack", 0)), 8)
	_expect_equal("schema twenty-two saved", int(legacy.to_save_data().get("schema_version", 0)), 23)
	var repeated := legacy.party_service.stable_combat_affinity_for_id("legacy-affinity-member")
	_expect_equal("affinity migration deterministic", first_affinity, repeated)

	var repair_state := GameState.new()
	repair_state.rng.seed = 314159
	var rng_state_before := repair_state.rng.state
	var malformed_member := {
		"id": "malformed-growth-member",
		"growth_primary_stat": "invalid",
		"growth_secondary_stats": ["invalid", "attack"],
		"growth_primary_stats": ["invalid"],
	}
	repair_state.party_service.ensure_member_growth_shape(malformed_member)
	var repaired_growth: Array = malformed_member.get("growth_primary_stats", []).duplicate()
	_expect_equal("growth repair preserves save rng", repair_state.rng.state, rng_state_before)
	_expect_equal("growth repair creates three unique stats", repaired_growth.size(), 3)
	var repaired_growth_set := {}
	for stat_id in repaired_growth:
		repaired_growth_set[str(stat_id)] = true
	_expect_equal("growth repair stats are unique", repaired_growth_set.size(), 3)
	repair_state.party_service.ensure_member_growth_shape(malformed_member)
	_expect_equal("growth repair is stable", malformed_member.get("growth_primary_stats", []), repaired_growth)


func _enemy_status(actor_id: String, affinity: String, hp: int, defense: int) -> CombatActorStatus:
	var status := CombatActorStatus.new()
	status.bind_enemy({"id": actor_id, "name": actor_id, "hp": hp, "max_hp": hp, "defense": defense, "elements": {}, "combat_affinity": affinity})
	return status


func _damage_skill(element: String, amount: int) -> Dictionary:
	return {
		"id": "affinity_damage",
		"element": element,
		"effects": [{"effect_id": "impact", "kind": "damage", "target": "skill_targets", "base_amount": amount, "shieldable": true}],
	}


func _expect_relation(label: String, result: Dictionary, expected: String) -> void:
	var targets: Array = result.get("target_results", [])
	_expect_equal(label, str(targets[0].get("affinity_relation", "")) if not targets.is_empty() else "", expected)


func _event_of_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _unique_count(values: Array) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[str(value)] = true
	return unique.size()


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
