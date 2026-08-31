extends Node

const CORE_AOE_SKILLS := [
	"earth_ji_furrow_shelter", "earth_spirit_armor", "fire_blazing_mark",
	"fire_ding_cinder_storm", "fire_ding_smolder_seal", "fire_heavenly_flame",
	"metal_ten_thousand_blades", "metal_xin_needle_storm", "poison",
	"water_binding_array", "water_gui_dew_mercy", "water_gui_eroding_rain",
	"water_returning_tide", "wolf_howl", "wood_breath_array",
	"wood_corroding_vine", "wood_yi_creeping_thicket", "wood_yi_strangling_root",
]

var failures: Array[String] = []


func _ready() -> void:
	_check_aoe_data()
	_check_aoe_slices()
	_check_aoe_anchors()
	_check_enemy_skill_loadouts()
	_check_ai_thresholds()
	if failures.is_empty():
		print("COMBAT_AI_AOE_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_aoe_data() -> void:
	for skill_id in CORE_AOE_SKILLS:
		var skill := DataTables.create_skill(skill_id)
		_expect(skill.get("target_count", 0) == 3, "%s target_count must be 3" % skill_id)
		_expect(skill.get("target_tendency", "") == "front", "%s tendency must be front" % skill_id)
	var legacy := {"type": "damage", "target_scope": "all_enemies"}
	_expect(DataTables.skill_target_count(legacy, 4) == 4, "legacy AOE must retain all-target behavior")
	var native := SkillDef.new()
	_expect(native.target_count == 2 and native.target_tendency == "front", "native AOE defaults changed")


func _check_aoe_slices() -> void:
	var ai := CombatAI.new()
	var targets: Array = []
	for index in range(4):
		var status := CombatActorStatus.new()
		status.bind_enemy({"combat_id": "enemy_%d" % (index + 1), "name": "Target", "hp": 10, "max_hp": 10})
		targets.append(status)
	var skill := {"type": "damage", "target_scope": "all_enemies", "target_count": 3, "target_tendency": "back"}
	_expect(_ids(ai._ai_targets(targets, skill, "all_enemies", null)) == ["enemy_2", "enemy_3", "enemy_4"], "back 3 target slice is incorrect")
	skill["target_count"] = 2
	_expect(_ids(ai._ai_targets(targets, skill, "all_enemies", null)) == ["enemy_3", "enemy_4"], "back 2 target slice is incorrect")
	skill["target_tendency"] = "front"
	_expect(_ids(ai._ai_targets(targets, skill, "all_enemies", null)) == ["enemy_1", "enemy_2"], "front target slice is incorrect")


func _check_aoe_anchors() -> void:
	var controller := CombatController.new()
	var caster := CombatActorStatus.new()
	caster.bind_enemy({"combat_id": "caster", "name": "Caster", "hp": 10, "max_hp": 10})
	var first := CombatActorStatus.new()
	first.bind_enemy({"combat_id": "first", "name": "First", "hp": 10, "max_hp": 10})
	var second := CombatActorStatus.new()
	second.bind_enemy({"combat_id": "second", "name": "Second", "hp": 10, "max_hp": 10})
	var heal_context := controller._skill_cast_context(caster, [first, second], DataTables.create_skill("water_gui_dew_mercy"), RandomNumberGenerator.new())
	_expect(heal_context.anchor_target == caster, "friendly AOE must anchor its animation to the caster")
	var debuff_context := controller._skill_cast_context(caster, [first, second], DataTables.create_skill("water_binding_array"), RandomNumberGenerator.new())
	_expect(debuff_context.anchor_target == first, "enemy debuff AOE must anchor to the finite-range start target")
	controller.free()


func _check_enemy_skill_loadouts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for enemy_id in DataTables.ENEMY_TEMPLATES:
		var expected: Array = DataTables.core_enemy_definition(enemy_id).get("skills", [])
		var generated: Array = DataTables.create_enemy(1, rng, enemy_id).get("skills", [])
		_expect(generated == expected, "%s must keep its fixed skill loadout at every rank" % enemy_id)


func _check_ai_thresholds() -> void:
	var ai := CombatAI.new()
	var caster := CombatActorStatus.new()
	caster.bind_enemy({"combat_id": "caster", "name": "Caster", "hp": 100, "max_hp": 100, "mp": 40, "max_mp": 40})
	var ally := CombatActorStatus.new()
	ally.bind_enemy({"combat_id": "ally", "name": "Ally", "hp": 35, "max_hp": 100, "mp": 40, "max_mp": 40})
	var context := {"caster": caster, "allies": [caster, ally], "opponents": []}
	var heal := ai._evaluate_skill(DataTables.create_skill("water_gui_dew_mercy"), context, caster)
	_expect(str(heal.get("preferred_target_id", "")) == "ally", "heal threshold must select the lowest-HP ally")
	ally.bind_enemy({"combat_id": "ally", "name": "Ally", "hp": 60, "max_hp": 100, "mp": 40, "max_mp": 40})
	var defense := ai._evaluate_skill(DataTables.create_skill("earth_ji_garden_ward"), context, caster)
	_expect(str(defense.get("preferred_target_id", "")) == "ally", "defense threshold must include 60 percent HP")
	ally.bind_enemy({"combat_id": "ally", "name": "Ally", "hp": 61, "max_hp": 100, "mp": 40, "max_mp": 40})
	_expect(ai._evaluate_skill(DataTables.create_skill("earth_ji_garden_ward"), context, caster).is_empty(), "defense must skip targets above 60 percent HP")


func _ids(targets: Array) -> Array[String]:
	var result: Array[String] = []
	for target in targets:
		result.append((target as CombatActorStatus).actor_id)
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
