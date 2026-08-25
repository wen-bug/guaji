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


func _check_mod_item_effect_compatibility() -> void:
	var validator = ModSchemaValidatorScript.new()
	var legacy := ItemParser.normalize_external_definition("legacy_buff", {
		"name": "Legacy Buff",
		"type": "pill",
		"payload": {"stat": "attack", "amount": 2, "duration": 15.0},
	})
	_expect_true("legacy mod payload adapts to effects", not legacy.get("effects", []).is_empty())
	_expect_true("adapted legacy mod item validates", validator.validate_definition("item", "legacy_buff", legacy).is_empty())
	var standard := ItemParser.definition("attack_pill")
	_expect_true("standard mod effects validate", validator.validate_definition("item", "standard_buff", standard).is_empty())
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


func _check_schema_22_migration() -> void:
	var source := _fresh_state()
	var member_id := source.default_party_member_id()
	var data := source.to_save_data()
	data["schema_version"] = 21
	data.erase("active_item_buffs")
	data.erase("auto_use_item_ids")
	data["active_buffs"] = [{"item_id": "attack_pill", "stat": "attack", "amount": 3, "remaining": 41.0, "member_id": member_id}]
	data["farm_speed_buffs"] = [{"item_id": "farm_speed_talisman", "multiplier": 1.5, "remaining_seconds": 87.0}]
	var loaded := GameState.new()
	loaded.load_save_data(data)
	_expect_equal("schema 22 saved", int(loaded.to_save_data().get("schema_version", 0)), 22)
	_expect_equal("legacy buffs merged", loaded.active_item_buffs.size(), 2)
	_expect_equal("auto slots initialize empty", loaded.auto_use_item_ids, ["", "", "", ""])
	_expect_float("legacy farm time preserved", loaded.farm_speed_remaining_seconds(), 87.0)


func _check_auto_slots_and_ai() -> void:
	var state := _fresh_state()
	var member: Dictionary = state.party_members()[0]
	var member_id := str(member.get("id", ""))
	state.set_auto_use_item_ids(["attack_pill", "attack_pill", "pill", "spirit_pill"])
	_expect_equal("duplicates rejected", state.auto_use_item_ids, ["attack_pill", "", "pill", "spirit_pill"])
	state.add_inventory_item("attack_pill", 1, false)
	member["skills"] = [DataTables.create_skill("thunder")]
	var ai = CombatAIScript.new()
	var action: Dictionary = ai.select_player_action(state, 80.0, 20.0, {}, {}, {}, member)
	_expect_equal("configured item precedes skill", str(action.get("source", "")), "pill")
	_expect_equal("configured item id", str(action.get("item_id", "")), "attack_pill")
	_expect_true("buff starts inactive", not state.item_buff_active("attack_pill_buff", "combat_global", member_id))
	_expect_true("selected combat item applies", state.use_inventory_item_for_member("attack_pill", member_id))
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
