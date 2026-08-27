extends Node

const ItemParser = preload("res://scripts/game/data/item_config_parser.gd")
const SkillParser = preload("res://scripts/game/data/skill_config_parser.gd")
const CombatAIScript = preload("res://scripts/game/combat/combat_ai.gd")
const ModSchemaValidatorScript = preload("res://scripts/modding/internal/mod_schema_validator.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_parsers()
	_check_mod_item_effect_compatibility()
	_check_typed_effects_and_targets()
	_check_combat_item_targeting()
	_check_buff_lifecycle_rules()
	_check_schema_22_migration()
	_check_auto_slots_and_ai()
	if failures.is_empty():
		print("CONTENT_CONFIG_ITEM_BUFF_PASS")
		get_tree().quit(0)
		return
	for failure in failures: push_error(failure)
	get_tree().quit(1)


func _fresh_state() -> GameState:
	var state := GameState.new()
	state.inventory.clear(); state.companions.clear(); state.party_order.clear(); state.reserve_order.clear(); state.recruit_candidates.clear()
	var member: Dictionary = state.party_service.create_recruit_candidate(0, {})
	member["kind"] = "companion"
	state.companions.append(member)
	state.party_order.append(str(member.get("id", "")))
	return state


func _check_parsers() -> void:
	_expect_equal("item count", ItemParser.item_ids().size(), 58)
	_expect_equal("active skill count", SkillParser.definitions().size(), 10)
	_expect_equal("basic attack count", SkillParser.basic_attack_definitions().size(), 2)
	_expect_true("item parser valid", ItemParser.validation_errors().is_empty(), str(ItemParser.validation_errors()))
	_expect_true("skill parser valid", SkillParser.validation_errors().is_empty(), str(SkillParser.validation_errors()))
	for item_id in ItemParser.item_ids():
		var resource := load(ItemParser.resource_path(item_id)) as ItemDef
		_expect_true("core payload empty %s" % item_id, resource != null and resource.payload.is_empty())
	var copied_item := ItemParser.definition("attack_pill")
	copied_item["name"] = "mutated"
	_expect_equal("item parser returns deep copy", str(ItemParser.definition("attack_pill").get("name", "")), "破军丹")
	var copied_skill := SkillParser.definition("poison")
	copied_skill["effects"][0]["base_amount"] = 999
	_expect_true("skill parser returns deep copy", int(SkillParser.definition("poison").get("effects", [])[0].get("base_amount", 0)) != 999)
	var invalid_item := ItemParser.definition("attack_pill")
	invalid_item["effects"][0]["duration_seconds"] = 0.0
	_expect_true("invalid timed item effect rejected", not ItemParser.validate_definition(invalid_item, "test://item").is_empty())
	var invalid_skill := SkillParser.definition("poison")
	invalid_skill["effects"][0]["effect_id"] = ""
	_expect_true("invalid skill effect rejected", not SkillParser.validate_definition(invalid_skill, "test://skill").is_empty())
	for item_id in ["pill", "life_pill", "spirit_pill"]:
		_expect_equal("single combat item %s" % item_id, ItemParser.definition(item_id).get("combat_target_mode", ""), "single")
	for item_id in ["attack_pill", "defense_pill", "wood_pill", "fire_pill", "earth_pill", "metal_pill", "water_pill"]:
		_expect_equal("aoe combat item %s" % item_id, ItemParser.definition(item_id).get("combat_target_mode", ""), "aoe")
	_expect_equal("single target label", DataTables.item_combat_target_mode_label("single"), "单人")
	_expect_equal("aoe target label", DataTables.item_combat_target_mode_label("aoe"), "群体")
	var serialized := ItemDef.new().setup("serialized_scope", {
		"name": "Serialized Scope",
		"combat_target_mode": "aoe",
	})
	_expect_equal("item target mode serializes", serialized.to_item_data().get("combat_target_mode", ""), "aoe")


func _check_mod_item_effect_compatibility() -> void:
	var validator = ModSchemaValidatorScript.new()
	var legacy := ItemParser.normalize_external_definition("legacy_buff", {
		"name": "Legacy Buff",
		"type": "pill",
		"payload": {"stat": "attack", "amount": 2, "duration": 15.0},
	})
	_expect_true("legacy mod payload adapts to effects", not legacy.get("effects", []).is_empty())
	_expect_equal("legacy combat buff infers aoe", legacy.get("combat_target_mode", ""), "aoe")
	_expect_true("adapted legacy mod item validates", validator.validate_definition("item", "legacy_buff", legacy).is_empty())
	var legacy_restore := ItemParser.normalize_external_definition("legacy_restore", {
		"name": "Legacy Restore",
		"type": "pill",
		"payload": {"hp_ratio": 0.2},
	})
	_expect_equal("legacy restore infers single", legacy_restore.get("combat_target_mode", ""), "single")
	_expect_true("legacy restore validates", validator.validate_definition("item", "legacy_restore", legacy_restore).is_empty())
	var standard := ItemParser.definition("attack_pill")
	_expect_true("standard mod effects validate", validator.validate_definition("item", "standard_buff", standard).is_empty())
	var invalid_scope := standard.duplicate(true)
	invalid_scope["combat_target_mode"] = "single"
	_expect_true("single combat global rejected by parser", not ItemParser.validate_definition(invalid_scope, "test://invalid_scope").is_empty())
	_expect_true("single combat global rejected by mod validator", not validator.validate_definition("item", "invalid_scope", invalid_scope).is_empty())
	standard["effects"][0]["duration_seconds"] = 0.0
	_expect_true("invalid standard mod effect rejected", not validator.validate_definition("item", "invalid_buff", standard).is_empty())


func _check_typed_effects_and_targets() -> void:
	var state := _fresh_state()
	var member_id := state.default_party_member_id()
	var base_attack := state.total_stat_for(member_id, "attack")
	state.add_inventory_item("attack_pill", 1, false)
	_expect_true("combat global item usable at home", state.use_inventory_item_for_member("attack_pill", member_id))
	_expect_equal("home aggregation excludes combat buff", state.total_stat_for(member_id, "attack"), base_attack)
	var actor := CombatActorStatus.new()
	add_child(actor)
	actor.bind_member(state, member_id)
	_expect_equal("combat aggregation includes global buff", actor.total_stat("attack"), base_attack + 3)
	actor.queue_free()
	state.add_inventory_item("farm_speed_talisman", 1, false)
	_expect_true("farm item usable", state.use_inventory_item("farm_speed_talisman"))
	_expect_float("farm speed percent", state.farm_speed_multiplier(), 1.5)
	_expect_true("farm duration", state.farm_speed_remaining_seconds() > 299.0)


func _check_combat_item_targeting() -> void:
	var state := _fresh_state()
	var actor: Dictionary = state.party_members()[0]
	var ally: Dictionary = state.party_service.create_recruit_candidate(1, {})
	var fallen: Dictionary = state.party_service.create_recruit_candidate(2, {})
	ally["kind"] = "companion"
	fallen["kind"] = "companion"
	state.companions.append(ally)
	state.companions.append(fallen)
	state.party_order.append(str(ally.get("id", "")))
	state.party_order.append(str(fallen.get("id", "")))
	var actor_id := str(actor.get("id", ""))
	var ally_id := str(ally.get("id", ""))
	var fallen_id := str(fallen.get("id", ""))
	var actor_max := state.total_stat_for(actor_id, "max_hp")
	var ally_max := state.total_stat_for(ally_id, "max_hp")
	actor["stats"]["hp"] = 1
	ally["stats"]["hp"] = 2
	fallen["stats"]["hp"] = 0
	var group_item := _combat_test_item("test_group_restore", "aoe", 2, [
		{"effect_id": "group_restore", "kind": "restore_resource", "target": "member", "stat": "hp", "amount": 0, "ratio": 0.25},
		_modifier("group_global", "defense", 2.0, 30.0, "refresh"),
	])
	group_item["effects"][1]["target"] = "combat_global"
	state.add_inventory_instance(group_item)
	_expect_true("group combat item applies", state.use_combat_inventory_item("test_group_restore", actor_id, [actor_id, ally_id, fallen_id]))
	_expect_equal("group actor restores by own maximum", int(actor["stats"].get("hp", 0)), mini(actor_max, 1 + ceili(actor_max * 0.25)))
	_expect_equal("group ally restores by own maximum", int(ally["stats"].get("hp", 0)), mini(ally_max, 2 + ceili(ally_max * 0.25)))
	_expect_equal("group item excludes fallen member", int(fallen["stats"].get("hp", 0)), 0)
	_expect_equal("group item consumes one", state.inventory_item_count("test_group_restore"), 1)
	_expect_equal("combat global effect applies once", _buff_count(state, "group_global"), 1)

	var home_state := _fresh_state()
	var selected: Dictionary = home_state.party_members()[0]
	var other: Dictionary = home_state.party_service.create_recruit_candidate(1, {})
	other["kind"] = "companion"
	home_state.companions.append(other)
	home_state.party_order.append(str(other.get("id", "")))
	var selected_id := str(selected.get("id", ""))
	selected["stats"]["hp"] = 1
	other["stats"]["hp"] = 2
	var other_hp := int(other["stats"].get("hp", 0))
	home_state.add_inventory_instance(_combat_test_item("test_home_group", "aoe", 1, [
		{"effect_id": "home_restore", "kind": "restore_resource", "target": "member", "stat": "hp", "amount": 5, "ratio": 0.0},
	]))
	_expect_true("home use of aoe item succeeds", home_state.use_inventory_item_for_member("test_home_group", selected_id))
	_expect_equal("home aoe item leaves other member unchanged", int(other["stats"].get("hp", 0)), other_hp)

	var no_benefit := _fresh_state()
	var full_member: Dictionary = no_benefit.party_members()[0]
	var full_id := str(full_member.get("id", ""))
	full_member["stats"]["hp"] = no_benefit.total_stat_for(full_id, "max_hp")
	no_benefit.add_inventory_instance(_combat_test_item("test_no_benefit", "aoe", 1, [
		{"effect_id": "no_benefit_restore", "kind": "restore_resource", "target": "member", "stat": "hp", "amount": 5, "ratio": 0.0},
	]))
	_expect_true("no benefit combat item rejected", not no_benefit.use_combat_inventory_item("test_no_benefit", full_id, [full_id]))
	_expect_equal("no benefit item not consumed", no_benefit.inventory_item_count("test_no_benefit"), 1)
	var invalid_item := _combat_test_item("test_invalid_scope", "single", 1, [
		_modifier("invalid_global", "attack", 1.0, 10.0, "refresh"),
	])
	invalid_item["effects"][0]["target"] = "combat_global"
	no_benefit.add_inventory_instance(invalid_item)
	_expect_true("invalid runtime scope rejected", not no_benefit.use_combat_inventory_item("test_invalid_scope", full_id, [full_id]))
	_expect_equal("invalid runtime scope not consumed", no_benefit.inventory_item_count("test_invalid_scope"), 1)


func _combat_test_item(item_id: String, target_mode: String, count: int, effects: Array) -> Dictionary:
	return {
		"instance_id": item_id,
		"item_id": item_id,
		"name": item_id,
		"type": DataTables.ITEM_TYPE_PILL,
		"count": count,
		"stackable": true,
		"usable": true,
		"use_context": DataTables.ITEM_USE_SCOPE_BOTH,
		"combat_target_mode": target_mode,
		"effects": effects.duplicate(true),
	}


func _check_buff_lifecycle_rules() -> void:
	var state := _fresh_state()
	var member: Dictionary = state.party_members()[0]
	var member_id := str(member.get("id", ""))
	var base_attack := state.total_stat_for(member_id, "attack")
	var stack_effect := _modifier("stacking", "attack", 2.0, 10.0, "stack", 3)
	state._apply_item_modifier_effect("test_stack", stack_effect, member_id)
	state._apply_item_modifier_effect("test_stack", stack_effect, member_id)
	state._apply_item_modifier_effect("test_stack", stack_effect, member_id)
	state._apply_item_modifier_effect("test_stack", stack_effect, member_id)
	_expect_equal("stack reaches configured cap", int(state.active_item_buffs[0].get("stacks", 0)), 3)
	_expect_equal("stacked flat modifier aggregates", state.total_stat_for(member_id, "attack"), base_attack + 6)

	var refresh_effect := _modifier("refreshing", "defense", 1.0, 10.0, "refresh")
	state._apply_item_modifier_effect("test_refresh", refresh_effect, member_id)
	state.update_buffs(4.0)
	state._apply_item_modifier_effect("test_refresh", refresh_effect, member_id)
	_expect_float("refresh resets duration", _buff_remaining(state, "refreshing"), 10.0)

	var extend_effect := _modifier("extending", "root_bone", 1.0, 10.0, "extend")
	state._apply_item_modifier_effect("test_extend", extend_effect, member_id)
	state._apply_item_modifier_effect("test_extend", extend_effect, member_id)
	_expect_float("extend adds duration", _buff_remaining(state, "extending"), 20.0)

	var replace_effect := _modifier("replacing", "attack", 1.0, 10.0, "replace")
	state._apply_item_modifier_effect("test_replace", replace_effect, member_id)
	replace_effect["value"] = 4.0
	replace_effect["duration_seconds"] = 25.0
	state._apply_item_modifier_effect("test_replace", replace_effect, member_id)
	_expect_float("replace changes value", _buff_value(state, "replacing"), 4.0)
	_expect_float("replace changes duration", _buff_remaining(state, "replacing"), 25.0)

	var permanent_effect := _modifier("permanent", "defense", 1.0, 1.0, "refresh")
	permanent_effect["duration_mode"] = "permanent"
	state._apply_item_modifier_effect("test_permanent", permanent_effect, member_id)
	state.update_buffs(1000.0)
	_expect_float("permanent buff does not tick", _buff_remaining(state, "permanent"), -1.0)

	var member_stats: Dictionary = member.get("stats", {})
	var base_max_hp := state.total_stat_for(member_id, "max_hp")
	var health_effect := _modifier("health_limit", "max_hp", 20.0, 1.0, "refresh")
	state._apply_item_modifier_effect("test_health", health_effect, member_id)
	member_stats["hp"] = base_max_hp + 20
	state.update_buffs(2.0)
	_expect_equal("expired max health buff clamps hp", int(member_stats.get("hp", 0)), base_max_hp)

	var combined_state := _fresh_state()
	var combined_member: Dictionary = combined_state.party_members()[0]
	var combined_member_id := str(combined_member.get("id", ""))
	var base_defense := combined_state.total_stat_for(combined_member_id, "defense")
	var member_flat := _modifier("member_flat", "defense", 2.0, 30.0, "refresh")
	var member_percent := _modifier("member_percent", "defense", 0.5, 30.0, "refresh")
	member_percent["operation"] = "percent"
	var combat_flat := _modifier("combat_flat", "defense", 3.0, 30.0, "refresh")
	combat_flat["target"] = "combat_global"
	var combat_percent := _modifier("combat_percent", "defense", 0.2, 30.0, "refresh")
	combat_percent["target"] = "combat_global"
	combat_percent["operation"] = "percent"
	combined_state._apply_item_modifier_effect("member_flat", member_flat, combined_member_id)
	combined_state._apply_item_modifier_effect("member_percent", member_percent, combined_member_id)
	combined_state._apply_item_modifier_effect("combat_flat", combat_flat, combined_member_id)
	combined_state._apply_item_modifier_effect("combat_percent", combat_percent, combined_member_id)
	var combined_actor := CombatActorStatus.new()
	add_child(combined_actor)
	combined_actor.bind_member(combined_state, combined_member_id)
	_expect_equal("member and combat modifiers share one formula", combined_actor.total_stat("defense"), roundi(float(base_defense + 5) * 1.7))
	combined_actor.queue_free()


func _modifier(buff_id: String, stat: String, value: float, duration: float, stack_mode: String, max_stacks: int = 1) -> Dictionary:
	return {
		"effect_id": buff_id,
		"kind": "temporary_modifier",
		"target": "member",
		"stat": stat,
		"operation": "flat",
		"value": value,
		"buff_id": buff_id,
		"duration_mode": "timed",
		"duration_seconds": duration,
		"stack_mode": stack_mode,
		"max_stacks": max_stacks,
	}


func _buff_remaining(state: GameState, buff_id: String) -> float:
	for raw_buff in state.active_item_buffs:
		if raw_buff is Dictionary and str(raw_buff.get("buff_id", "")) == buff_id:
			return float(raw_buff.get("remaining_seconds", 0.0))
	return 0.0


func _buff_value(state: GameState, buff_id: String) -> float:
	for raw_buff in state.active_item_buffs:
		if raw_buff is Dictionary and str(raw_buff.get("buff_id", "")) == buff_id:
			return float(raw_buff.get("value", 0.0))
	return 0.0


func _buff_count(state: GameState, buff_id: String) -> int:
	var count := 0
	for raw_buff in state.active_item_buffs:
		if raw_buff is Dictionary and str(raw_buff.get("buff_id", "")) == buff_id:
			count += 1
	return count


func _check_schema_22_migration() -> void:
	var source := _fresh_state()
	var member_id := source.default_party_member_id()
	source.add_inventory_item("attack_pill", 1, false)
	var data := source.to_save_data()
	data["schema_version"] = 21
	data.erase("active_item_buffs")
	data.erase("auto_use_item_ids")
	data["active_buffs"] = [{"item_id": "attack_pill", "stat": "attack", "amount": 3, "remaining": 41.0, "member_id": member_id}]
	data["farm_speed_buffs"] = [{"item_id": "farm_speed_talisman", "multiplier": 1.5, "remaining_seconds": 87.0}]
	for item in data.get("inventory", []):
		if item is Dictionary and str(item.get("item_id", "")) == "attack_pill":
			item.erase("combat_target_mode")
	var loaded := GameState.new()
	loaded.load_save_data(data)
	_expect_equal("schema 22 saved", int(loaded.to_save_data().get("schema_version", 0)), 22)
	_expect_equal("legacy buffs merged", loaded.active_item_buffs.size(), 2)
	_expect_equal("auto slots initialize empty", loaded.auto_use_item_ids, ["", "", "", ""])
	_expect_equal("loaded stack refreshes target mode", loaded.inventory_item_by_instance("attack_pill").get("combat_target_mode", ""), "aoe")
	_expect_float("legacy farm time preserved", loaded.farm_speed_remaining_seconds(), 87.0)


func _check_auto_slots_and_ai() -> void:
	var state := _fresh_state()
	var member: Dictionary = state.party_members()[0]
	var member_id := str(member.get("id", ""))
	state.set_auto_use_item_ids(["attack_pill", "attack_pill", "pill", "spirit_pill"])
	_expect_equal("duplicates rejected", state.auto_use_item_ids, ["attack_pill", "", "pill", "spirit_pill"])
	state.add_inventory_item("attack_pill", 2, false)
	member["skills"] = [DataTables.create_skill("thunder")]
	var ai = CombatAIScript.new()
	var item_action: Dictionary = ai.select_auto_item_action(state, {}, {}, member)
	_expect_equal("configured auto item selected", str(item_action.get("source", "")), "pill")
	_expect_equal("configured item id", str(item_action.get("item_id", "")), "attack_pill")
	var normal_action: Dictionary = ai.select_player_action(state, 80.0, 20.0, {}, {}, {}, member)
	_expect_true("normal action remains after auto item selection", str(normal_action.get("source", "")) in ["skill", "basic"])
	_expect_true("buff starts inactive", not state.item_buff_active("attack_pill_buff", "combat_global", member_id))
	var controller := CombatController.new()
	var combatant := {
		"member_id": member_id,
		"pill_cooldowns": {},
		"pill_group_cooldowns": {},
		"auto_item_checked": false,
	}
	controller.party_combatants = [combatant]
	var status := CombatActorStatus.new()
	add_child(status)
	status.bind_member(state, member_id)
	controller.party_actor_statuses[member_id] = status
	_expect_true("selected combat item applies", controller._try_auto_item_for_turn(combatant, member, state))
	_expect_equal("auto item records personal cooldown", int(combatant["pill_cooldowns"].get("attack_pill", 0)), 3)
	_expect_equal("auto item records shared cooldown", int(combatant["pill_group_cooldowns"].get("buff_pill", 0)), 3)
	_expect_true("second auto item attempt in turn is skipped", not controller._try_auto_item_for_turn(combatant, member, state))
	_expect_equal("only one auto item consumed per turn", state.inventory_item_count("attack_pill"), 1)
	status.queue_free()
	controller.free()

	var failed_state := _fresh_state()
	var failed_member: Dictionary = failed_state.party_members()[0]
	var failed_member_id := str(failed_member.get("id", ""))
	failed_state.set_auto_use_item_ids(["pill", "", "", ""])
	failed_state.add_inventory_item("pill", 1, false)
	failed_member["stats"]["hp"] = failed_state.total_stat_for(failed_member_id, "max_hp")
	failed_member["stats"]["mp"] = failed_state.total_stat_for(failed_member_id, "max_mp")
	var failed_combatant := {"pill_cooldowns": {}, "pill_group_cooldowns": {}, "auto_item_checked": false}
	var failed_controller := CombatController.new()
	_expect_true("no benefit auto item skipped", not failed_controller._try_auto_item_for_turn(failed_combatant, failed_member, failed_state))
	_expect_true("failed auto item marked checked", bool(failed_combatant.get("auto_item_checked", false)))
	_expect_true("failed auto item writes no personal cooldown", failed_combatant["pill_cooldowns"].is_empty())
	_expect_true("failed auto item writes no shared cooldown", failed_combatant["pill_group_cooldowns"].is_empty())
	_expect_equal("failed auto item not consumed", failed_state.inventory_item_count("pill"), 1)
	_expect_true("failed auto item does not retry", not failed_controller._try_auto_item_for_turn(failed_combatant, failed_member, failed_state))
	failed_controller.free()

	var empty_state := _fresh_state()
	var empty_member: Dictionary = empty_state.party_members()[0]
	empty_state.set_auto_use_item_ids(["pill", "", "", ""])
	var empty_combatant := {"pill_cooldowns": {}, "pill_group_cooldowns": {}, "auto_item_checked": false}
	var empty_controller := CombatController.new()
	_expect_true("out of stock auto item skipped", not empty_controller._try_auto_item_for_turn(empty_combatant, empty_member, empty_state))
	_expect_true("out of stock writes no cooldown", empty_combatant["pill_cooldowns"].is_empty() and empty_combatant["pill_group_cooldowns"].is_empty())
	empty_controller.free()
	var saved := state.to_save_data()
	var loaded := GameState.new()
	loaded.load_save_data(saved)
	_expect_equal("auto slots preserve order on load", loaded.auto_use_item_ids, ["attack_pill", "", "pill", "spirit_pill"])
	_expect_true("combat global buff survives load", loaded.item_buff_active("attack_pill_buff", "combat_global"))
	_expect_equal("item buff save load preserves rng", loaded.to_save_data().get("rng", {}), saved.get("rng", {}))


func _expect_true(label: String, value: bool, detail: String = "") -> void:
	if not value: failures.append("%s%s" % [label, ": %s" % detail if not detail.is_empty() else ""])


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected: failures.append("%s expected %s, got %s" % [label, expected, actual])


func _expect_float(label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected): failures.append("%s expected %.3f, got %.3f" % [label, expected, actual])
