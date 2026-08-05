extends Node

const SkillValueResolverScript = preload("res://scripts/game/combat/skill_value_resolver.gd")
const ModSchemaValidatorScript = preload("res://scripts/modding/internal/mod_schema_validator.gd")
const CombatSkillExecutorScript = preload("res://scripts/game/combat/combat_skill_executor.gd")

class FakeGameState:
	extends RefCounted

	@warning_ignore("unused_signal")
	signal changed

	var member: Dictionary = {
		"id": "hero",
		"name": "测试角色",
		"stats": {"hp": 80, "max_hp": 80, "mp": 40, "max_mp": 40, "attack": 8, "defense": 2},
		"elements": {"wood": 1, "fire": 1, "earth": 1, "metal": 1, "water": 1},
	}

	func member_by_id(_member_id: String) -> Dictionary:
		return member

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

	func spend_mp_for(_member_id: String, amount: int) -> bool:
		var stats: Dictionary = member.get("stats", {})
		if int(stats.get("mp", 0)) < amount:
			return false
		stats["mp"] = int(stats.get("mp", 0)) - amount
		return true

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_player_scaling()
	_check_enemy_scaling()
	_check_fixed_effect_modes()
	_check_scene_integration()
	_check_legacy_compatibility()
	_check_schema_validation()
	if failures.is_empty():
		print("SKILL_ATTRIBUTE_SCALING_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_player_scaling() -> void:
	var game_state := FakeGameState.new()
	var caster := CombatActorStatus.new()
	caster.bind_member(game_state, "hero")
	_expect_equal("thunder level-one value", SkillValueResolverScript.damage_amount(DataTables.create_skill("thunder"), caster), 14)
	_expect_equal("heal level-one value", SkillValueResolverScript.heal_amount(DataTables.create_skill("heal"), caster), 8)
	game_state.member["elements"]["metal"] = 5
	_expect_equal("caster metal mutation", caster.total_element("metal"), 5)
	_expect_equal("thunder metal scaling", SkillValueResolverScript.damage_amount(DataTables.create_skill("thunder"), caster), 21)
	game_state.member["elements"]["fire"] = 4
	var attack_effect: Dictionary = DataTables.create_skill("attack_up").get("effects", [])[0]
	var scaled_attack := SkillValueResolverScript.scaled_effect(attack_effect, "fire", caster)
	_expect_equal("buff scaling", int(scaled_attack.get("amount", 0)), 4)
	caster.free()


func _check_enemy_scaling() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var enemy_data: Dictionary = DataTables.create_enemy(1, rng, "forest_wolf")
	var caster := CombatActorStatus.new()
	caster.bind_enemy(enemy_data)
	var expected_damage := {"wolf_bite": 7, "wolf_bleed": 6, "wolf_howl": 6, "wolf_pounce": 10}
	for skill_id in expected_damage:
		_expect_equal("enemy %s scaling" % skill_id, SkillValueResolverScript.damage_amount(DataTables.create_skill(skill_id), caster), expected_damage[skill_id])
	var bleed_effect: Dictionary = DataTables.create_skill("wolf_bleed").get("effects", [])[1]
	var scaled_bleed := SkillValueResolverScript.scaled_effect(bleed_effect, "wood", caster)
	_expect_equal("enemy dot scaling", int(scaled_bleed.get("amount", 0)), 2)
	caster.free()


func _check_fixed_effect_modes() -> void:
	var game_state := FakeGameState.new()
	game_state.member["elements"]["earth"] = 4
	var player := CombatActorStatus.new()
	player.bind_member(game_state, "hero")
	var enemy := CombatActorStatus.new()
	enemy.bind_enemy({
		"id": "enemy",
		"name": "敌人",
		"attack": 20,
		"elements": {"earth": 6},
	})
	for caster in [player, enemy]:
		var caster_label := "player" if caster == player else "enemy"
		_expect_equal("%s fixed damage" % caster_label, SkillValueResolverScript.damage_amount({"base_damage": 9, "damage_multiplier": 99.0}, caster), 9)
		_expect_equal("%s fixed heal zero" % caster_label, SkillValueResolverScript.heal_amount({"heal_amount": 0, "heal_multiplier": 99.0}, caster), 0)
		for effect in [
			{"kind": "dot", "amount": 3},
			{"kind": "shield", "amount": 7},
			{"kind": "buff_stat", "value": 2},
		]:
			var fixed := SkillValueResolverScript.scaled_effect(effect, "earth", caster)
			_expect_equal("%s fixed %s" % [caster_label, effect.get("kind", "effect")], int(fixed.get("amount", fixed.get("value", 0))), int(effect.get("amount", effect.get("value", 0))))
		var expected_bonus := 2 if caster == player else 3
		for effect in [
			{"kind": "dot", "amount": 3, "attribute_multiplier": 0.5},
			{"kind": "shield", "amount": 7, "attribute_multiplier": 0.5},
			{"kind": "buff_stat", "value": 2, "attribute_multiplier": 0.5},
		]:
			var scaled := SkillValueResolverScript.scaled_effect(effect, "earth", caster)
			var base_value := int(effect.get("amount", effect.get("value", 0)))
			_expect_equal("%s scaled %s" % [caster_label, effect.get("kind", "effect")], int(scaled.get("amount", 0)), base_value + expected_bonus)
	player.free()
	enemy.free()


func _check_scene_integration() -> void:
	var game_state := FakeGameState.new()
	game_state.member["elements"]["metal"] = 5
	var player := CombatActorStatus.new()
	player.bind_member(game_state, "hero")
	var target := CombatActorStatus.new()
	target.bind_enemy({"id": "target", "name": "目标", "hp": 100, "max_hp": 100, "defense": 0, "elements": {}, "weak_element": "water"})
	var executor = CombatSkillExecutorScript.new()
	var resolver := CombatEffectResolver.new()
	var random := RandomNumberGenerator.new()
	var damage_result := executor.execute(player, [target], DataTables.create_skill("thunder"), resolver, random)
	_expect_equal("direct damage executor scaling", int(damage_result.get("damage", 0)), 21)
	var fixed_damage := {
		"id": "fixed",
		"type": "damage",
		"element": "metal",
		"effects": [{"effect_id": "impact", "kind": "damage", "target": "skill_targets", "base_amount": 9}],
	}
	var fixed_result := executor.execute(player, [target], fixed_damage, resolver, random)
	_expect_equal("direct damage executor fixed value", int(fixed_result.get("damage", 0)), 9)

	game_state.member["stats"]["hp"] = 50
	var heal_result := executor.execute(player, [player], DataTables.create_skill("heal"), resolver, random)
	_expect_equal("heal executor scaling", int(heal_result.get("heal", 0)), 8)

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var wolf := CombatActorStatus.new()
	wolf.bind_enemy(DataTables.create_enemy(1, rng, "forest_wolf"))
	executor.execute(wolf, [player], DataTables.create_skill("wolf_bleed"), resolver, rng)
	var dot_amount := 0
	for effect in player.combat_effects:
		if effect is Dictionary and str(effect.get("kind", "")) == "dot":
			dot_amount = int(effect.get("value", effect.get("amount", 0)))
	_expect_equal("enemy dot scene scaling", dot_amount, 2)

	player.free()
	target.free()
	wolf.free()


func _check_legacy_compatibility() -> void:
	var game_state := FakeGameState.new()
	var caster := CombatActorStatus.new()
	caster.bind_member(game_state, "hero")
	_expect_equal("legacy damage multiplier", SkillValueResolverScript.damage_amount({"damage_multiplier": 1.5}, caster), 12)
	_expect_equal("fixed legacy damage", SkillValueResolverScript.damage_amount({"base_damage": 9}, caster), 9)
	_expect_equal("fixed damage zero", SkillValueResolverScript.damage_amount({"base_damage": 0, "damage_multiplier": 99.0}, caster), 0)
	_expect_equal("fixed heal", SkillValueResolverScript.heal_amount({"heal_amount": 7, "heal_multiplier": 99.0}, caster), 7)
	_expect_equal("fixed heal zero", SkillValueResolverScript.heal_amount({"heal_amount": 0, "heal_multiplier": 99.0}, caster), 0)
	_expect_equal("legacy heal multiplier", SkillValueResolverScript.heal_amount({"heal_multiplier": 1.5}, caster), 12)
	var fixed_result := SkillResolver.new().resolve_skill({"base_damage": 9, "damage_multiplier": 99.0}, game_state, {"member_id": "hero", "total_attack": 8})
	_expect_equal("legacy resolver fixed damage", int(fixed_result.get("damage", -1)), 9)
	var basic_attack := DataTables.create_basic_attack(DataTables.ATTACK_MODE_MELEE, 8)
	_expect_equal("basic attack unchanged", SkillValueResolverScript.damage_amount(basic_attack, caster), 8)
	var legacy_effect := {"kind": "shield", "amount": 6}
	_expect_equal("legacy effect unchanged", int(SkillValueResolverScript.scaled_effect(legacy_effect, "earth", caster).get("amount", 0)), 6)
	_expect_equal("fixed effect value unchanged", int(SkillValueResolverScript.scaled_effect({"kind": "buff_stat", "value": 4}, "fire", caster).get("value", 0)), 4)
	_expect_equal("probability never scales", int(SkillValueResolverScript.scaled_effect({"kind": "chance", "amount": 5, "attribute_multiplier": 3.0}, "fire", caster).get("amount", 0)), 5)
	caster.free()


func _check_schema_validation() -> void:
	var validator = ModSchemaValidatorScript.new()
	var invalid := {"name": "错误技能", "scene_path": "res://bad.tscn", "damage_attribute_multiplier": -0.5}
	var errors: Array[String] = validator.validate_definition("skill", "bad_skill", invalid)
	if errors.is_empty():
		failures.append("negative attribute multiplier passed schema validation")


func _expect_equal(label: String, actual: int, expected: int) -> void:
	if actual != expected:
		failures.append("%s: expected %d, got %d" % [label, expected, actual])
