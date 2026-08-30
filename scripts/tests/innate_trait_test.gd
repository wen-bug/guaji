extends Node

const PASS_TOKEN := "INNATE_TRAIT_PASS"
const ModSchemaValidatorScript = preload("res://scripts/modding/internal/mod_schema_validator.gd")
const RARITIES := ["common", "rare", "exceptional"]
const FORBIDDEN_BUILTIN_KINDS := [
	"growth_weight", "drop_chance_percent", "task_exp_percent", "leech_percent",
	"defense_ignore", "venom_poison", "skill_cooldown_percent",
]

var failures: Array[String] = []
var captured_logs: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_definitions_and_rarity_effects()
	_check_mod_trait_validation()
	_check_flat_stats_and_legacy_strings()
	_check_combat_modifiers_and_damage()
	_check_cooldown_turns()
	_check_breakthrough_does_not_awaken()
	_check_recruit_generation()
	_check_save_compatibility()
	if failures.is_empty():
		print(PASS_TOKEN)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _fresh_state(seed_value: int = 2026) -> GameState:
	var state := GameState.new()
	state.inventory.clear()
	state.companions.clear()
	state.party_order.clear()
	state.reserve_order.clear()
	state.recruit_candidates.clear()
	state.rng.seed = seed_value
	return state


func _trait_entry(trait_id: String, rarity: String = "common", slot: String = "main", awakened: bool = false) -> Dictionary:
	return {
		"id": trait_id,
		"name": str(DataTables.INNATE_TRAIT_DEFS.get(trait_id, {}).get("name", trait_id)),
		"slot": slot,
		"rarity": rarity,
		"level": 1,
		"awakened": awakened,
	}


func _make_member(state: GameState, member_id: String, traits: Array) -> Dictionary:
	var member := {
		"id": member_id,
		"name": member_id,
		"stats": state.party_service.base_member_stats(),
		"elements": state.party_service.base_member_elements(),
		"growth_primary_stat": "attack",
		"growth_secondary_stats": ["defense", "root_bone"],
		"growth_primary_stats": ["attack", "defense", "root_bone"],
		"innate_traits": traits,
	}
	state.companions.append(member)
	state.party_order.append(member_id)
	return member


func _member_status(state: GameState, member_id: String) -> CombatActorStatus:
	var status := CombatActorStatus.new()
	status.bind_member(state, member_id)
	return status


func _enemy_status(actor_id: String, affinity: String = "normal", hp: int = 1000) -> CombatActorStatus:
	var status := CombatActorStatus.new()
	status.bind_enemy({"id": actor_id, "name": actor_id, "hp": hp, "max_hp": hp, "defense": 0, "elements": {}, "combat_affinity": affinity})
	return status


func _damage_skill(element: String, amount: int) -> Dictionary:
	return {
		"id": "innate_test_damage",
		"type": "skill",
		"element": element,
		"effects": [{"effect_id": "impact", "kind": "damage", "target": "skill_targets", "base_amount": amount, "shieldable": true}],
	}


func _effect_amount(effects: Array, kind: String) -> float:
	var result := 0.0
	for raw_effect in effects:
		if raw_effect is Dictionary and str(raw_effect.get("kind", "")) == kind:
			result += float(raw_effect.get("amount", raw_effect.get("value", 0.0)))
	return result


func _check_definitions_and_rarity_effects() -> void:
	_expect_equal("trait definition count", DataTables.INNATE_TRAIT_DEFS.size(), 22)
	_expect_equal("unified main pool count", DataTables.MAIN_TRAIT_IDS.size(), 15)
	_expect_equal("sub pool count", DataTables.SUB_TRAIT_IDS.size(), 2)
	_expect_equal("flaw pool count", DataTables.FLAW_TRAIT_IDS.size(), 5)
	var seen_ids := {}
	for trait_id in DataTables.MAIN_TRAIT_IDS + DataTables.SUB_TRAIT_IDS + DataTables.FLAW_TRAIT_IDS:
		seen_ids[str(trait_id)] = true
	_expect_equal("all definitions are pooled", seen_ids.size(), 22)
	for trait_id in DataTables.INNATE_TRAIT_DEFS:
		var definition: Dictionary = DataTables.INNATE_TRAIT_DEFS[trait_id]
		_expect_true("trait has name %s" % trait_id, not str(definition.get("name", "")).is_empty())
		var effects_by_rarity = definition.get("effects_by_rarity", {})
		_expect_true("trait has rarity map %s" % trait_id, effects_by_rarity is Dictionary)
		if not (effects_by_rarity is Dictionary):
			continue
		for rarity in RARITIES:
			var effects = effects_by_rarity.get(rarity, [])
			_expect_true("trait rarity has effects %s/%s" % [trait_id, rarity], effects is Array and not effects.is_empty())
			if not (effects is Array):
				continue
			for raw_effect in effects:
				if not (raw_effect is Dictionary):
					failures.append("trait effect must be dictionary %s/%s" % [trait_id, rarity])
					continue
				var kind := str(raw_effect.get("kind", ""))
				_expect_true("builtin kind is simple %s/%s/%s" % [trait_id, rarity, kind], not FORBIDDEN_BUILTIN_KINDS.has(kind))
	var inline := {"id": "missing_trait", "rarity": "rare", "effects": [{"kind": "direct_damage_percent", "amount": 0.03}], "awakened": true, "awakened_effects": [{"kind": "direct_damage_percent", "amount": 0.99}]}
	_expect_equal("inline effects fallback", _effect_amount(DataTables.innate_trait_effects(inline), "direct_damage_percent"), 0.03)


func _check_mod_trait_validation() -> void:
	var validator = ModSchemaValidatorScript.new()
	var valid := {
		"name": "三档冷却",
		"effects_by_rarity": {
			"common": [{"kind": "skill_cooldown_turns", "amount": -1}],
			"rare": [{"kind": "skill_cooldown_turns", "amount": -1}],
			"exceptional": [{"kind": "skill_cooldown_turns", "amount": -2}],
		},
	}
	_expect_true("rarity trait validates", validator.validate_definition("trait", "rarity_trait", valid).is_empty())
	var invalid := valid.duplicate(true)
	invalid["effects_by_rarity"]["common"][0]["amount"] = -1.5
	_expect_true("fractional cooldown rejected", not validator.validate_definition("trait", "bad_cooldown", invalid).is_empty())


func _check_flat_stats_and_legacy_strings() -> void:
	var state := _fresh_state()
	var common := _make_member(state, "robust-common", [_trait_entry("robust_body", "common")])
	var rare := _make_member(state, "robust-rare", [_trait_entry("robust_body", "rare")])
	var exceptional := _make_member(state, "robust-exceptional", [_trait_entry("robust_body", "exceptional")])
	_expect_equal("common robust hp", state.total_stat_for(common["id"], "max_hp"), 100)
	_expect_equal("rare robust hp", state.total_stat_for(rare["id"], "max_hp"), 104)
	_expect_equal("exceptional robust hp", state.total_stat_for(exceptional["id"], "max_hp"), 108)
	var legacy := _make_member(state, "robust-legacy", ["robust_body"])
	_expect_equal("legacy string defaults common", state.total_stat_for(legacy["id"], "max_hp"), 100)


func _check_combat_modifiers_and_damage() -> void:
	var state := _fresh_state()
	var common := _make_member(state, "fire-common", [_trait_entry("fire_aspect", "common")])
	var rare := _make_member(state, "fire-rare", [_trait_entry("fire_aspect", "rare")])
	var exceptional := _make_member(state, "fire-exceptional", [_trait_entry("fire_aspect", "exceptional")])
	_expect_equal("common damage modifier", state.equipment_combat_modifiers_for(common["id"]).get("direct_damage_percent"), 0.05)
	_expect_equal("rare damage modifier", state.equipment_combat_modifiers_for(rare["id"]).get("direct_damage_percent"), 0.07)
	_expect_equal("exceptional damage modifier", state.equipment_combat_modifiers_for(exceptional["id"]).get("direct_damage_percent"), 0.10)
	var awakened := _make_member(state, "fire-old-awakened", [_trait_entry("fire_aspect", "rare", "main", true)])
	_expect_equal("old awakened flag ignored", state.equipment_combat_modifiers_for(awakened["id"]).get("direct_damage_percent"), 0.07)

	var executor := CombatSkillExecutor.new()
	var resolver := CombatEffectResolver.new()
	var caster := _member_status(state, exceptional["id"])
	var target := _enemy_status("damage-target")
	var result := executor.execute(caster, [target], _damage_skill("fire", 100), resolver)
	_expect_equal("exceptional direct damage applied", int(result.get("damage", 0)), 110)
	caster.free()
	target.free()

	var defense_state := _fresh_state()
	var defender := _make_member(defense_state, "earth-defender", [_trait_entry("earth_body", "exceptional")])
	var victim := _member_status(defense_state, defender["id"])
	victim.data["stats"]["defense"] = 0
	victim.data["stats"]["hp"] = 1000
	victim.data["stats"]["max_hp"] = 1000
	var enemy := _enemy_status("damage-source")
	var reduced := executor.execute(enemy, [victim], _damage_skill("", 100), resolver)
	_expect_equal("exceptional physical reduction applied", int(reduced.get("damage", 0)), 90)
	enemy.free()
	victim.free()


func _check_cooldown_turns() -> void:
	var state := _fresh_state()
	var common := _make_member(state, "cd-common", [_trait_entry("full_spirit_root", "common")])
	var rare := _make_member(state, "cd-rare", [_trait_entry("full_spirit_root", "rare")])
	var exceptional := _make_member(state, "cd-exceptional", [_trait_entry("full_spirit_root", "exceptional")])
	var common_modifiers := state.equipment_combat_modifiers_for(common["id"])
	_expect_equal("common cooldown turns", int(common_modifiers.get("skill_cooldown_turns", 0)), -1)
	_expect_equal("common cooldown damage drawback", common_modifiers.get("direct_damage_percent"), -0.06)
	_expect_equal("rare cooldown turns", int(state.equipment_combat_modifiers_for(rare["id"]).get("skill_cooldown_turns", 0)), -1)
	_expect_equal("exceptional cooldown turns", int(state.equipment_combat_modifiers_for(exceptional["id"]).get("skill_cooldown_turns", 0)), -2)
	var flaw := _make_member(state, "cd-flaw", [_trait_entry("heavy_body", "exceptional", "flaw")])
	var flaw_modifiers := state.equipment_combat_modifiers_for(flaw["id"])
	_expect_equal("flaw cooldown benefit", int(flaw_modifiers.get("skill_cooldown_turns", 0)), -2)
	_expect_equal("flaw damage drawback", flaw_modifiers.get("direct_damage_percent"), -0.06)
	var controller := CombatController.new()
	_expect_equal("common cooldown result", controller._cooldown_turns(8, 1.0, -1), 7)
	_expect_equal("rare cooldown result", controller._cooldown_turns(8, 1.0, -1), 7)
	_expect_equal("exceptional cooldown result", controller._cooldown_turns(8, 1.0, -2), 6)
	_expect_equal("cooldown clamped at zero", controller._cooldown_turns(1, 1.0, -2), 0)
	controller.free()


func _capture_log(message: String) -> void:
	captured_logs.append(message)


func _check_breakthrough_does_not_awaken() -> void:
	var state := _fresh_state()
	state.log_added.connect(_capture_log)
	var member := _make_member(state, "breakthrough-member", [_trait_entry("fire_aspect", "exceptional")])
	var before: Array = member["innate_traits"].duplicate(true)
	captured_logs.clear()
	state.party_service.unlock_next_stage_for_member(member)
	_expect_equal("breakthrough stage", int(member.get("stats", {}).get("stage", 0)), 2)
	_expect_equal("breakthrough level cap", int(member.get("stats", {}).get("level_cap", 0)), 20)
	_expect_equal("breakthrough leaves traits unchanged", member["innate_traits"], before)
	var trait_log_seen := false
	for message in captured_logs:
		if "命格" in message or "觉醒" in message:
			trait_log_seen = true
	_expect_true("breakthrough has no trait log", not trait_log_seen)


func _check_recruit_generation() -> void:
	var state := _fresh_state(91)
	var main_ids := {}
	var rarity_seen := {}
	for _index in range(5000):
		var traits: Array = state.party_service.random_basic_recruit_traits()
		_expect_true("level one produces one trait", traits.size() == 1)
		if traits.is_empty():
			continue
		var main: Dictionary = traits[0]
		main_ids[str(main.get("id", ""))] = true
		rarity_seen[str(main.get("rarity", ""))] = true
	_expect_equal("all main ids can generate", main_ids.size(), 15)
	_expect_equal("all recruit rarities seen", rarity_seen.size(), 3)

	var level_four := _fresh_state(92)
	level_four.building_levels["recruit"] = 4
	var common_sub_seen := false
	for _index in range(1000):
		var traits: Array = level_four.party_service.random_basic_recruit_traits()
		if traits.size() != 2:
			failures.append("level four must produce main and sub")
			break
		var rarity := str((traits[0] as Dictionary).get("rarity", ""))
		_expect_equal("sub shares candidate rarity", str((traits[1] as Dictionary).get("rarity", "")), rarity)
		_expect_equal("second trait is sub", str((traits[1] as Dictionary).get("slot", "")), "sub")
		if rarity == "common":
			common_sub_seen = true
	_expect_true("common recruits receive sub traits", common_sub_seen)

	var level_seven := _fresh_state(93)
	level_seven.building_levels["recruit"] = 7
	var exceptional_count := 0
	var flaw_count := 0
	var invalid_flaw := false
	for _index in range(4000):
		var traits: Array = level_seven.party_service.random_basic_recruit_traits()
		if str((traits[0] as Dictionary).get("rarity", "")) != "exceptional":
			continue
		exceptional_count += 1
		var member_flaws := 0
		for raw_trait in traits:
			if raw_trait is Dictionary and str(raw_trait.get("slot", "")) == "flaw":
				member_flaws += 1
				if not DataTables.FLAW_TRAIT_IDS.has(str(raw_trait.get("id", ""))):
					invalid_flaw = true
		if member_flaws > 1:
			invalid_flaw = true
		flaw_count += member_flaws
	_expect_true("exceptional recruits sampled", exceptional_count > 100)
	if exceptional_count > 0:
		var flaw_rate := float(flaw_count) / float(exceptional_count)
		_expect_true("flaw rate near 35 percent", flaw_rate > 0.25 and flaw_rate < 0.45)
	_expect_true("flaw entries valid", not invalid_flaw)


func _check_save_compatibility() -> void:
	var state := _fresh_state()
	var member := _make_member(state, "save-member", [_trait_entry("fire_aspect", "rare", "main", true)])
	var saved := state.to_save_data()
	var reloaded := GameState.new()
	reloaded.load_save_data(saved)
	var loaded_member := reloaded.member_by_id(member["id"])
	_expect_true("saved member reloads", not loaded_member.is_empty())
	if loaded_member.is_empty():
		return
	var traits: Array = loaded_member.get("innate_traits", [])
	_expect_true("saved trait reloads", not traits.is_empty())
	if not traits.is_empty():
		_expect_equal("legacy awakened field preserved", bool((traits[0] as Dictionary).get("awakened", false)), true)
	_expect_equal("legacy awakened field has no effect", reloaded.equipment_combat_modifiers_for(member["id"]).get("direct_damage_percent"), 0.07)


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
