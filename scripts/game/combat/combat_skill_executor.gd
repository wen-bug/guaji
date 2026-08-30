class_name CombatSkillExecutor
extends RefCounted

const SkillValueResolverScript = preload("res://scripts/game/combat/skill_value_resolver.gd")


func execute_impact(
	caster: CombatActorStatus,
	impact_targets: Array,
	skill: Dictionary,
	impact_id: StringName,
	effect_resolver: CombatEffectResolver,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var impact_skill := skill.duplicate(true)
	var impact_effects: Array = []
	for raw_effect in skill.get("effects", []):
		if raw_effect is Dictionary and str(raw_effect.get("impact_id", "impact")) == str(impact_id):
			impact_effects.append(raw_effect.duplicate(true))
	impact_skill["effects"] = impact_effects
	var result := execute(caster, impact_targets, impact_skill, effect_resolver, rng)
	result["impact_id"] = str(impact_id)
	return result


func execute(
	caster: CombatActorStatus,
	skill_targets: Array,
	skill: Dictionary,
	effect_resolver: CombatEffectResolver,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var result := {
		"skill_id": str(skill.get("id", "")),
		"events": [],
		"damage": 0,
		"heal": 0,
		"blocked_by_shield": 0,
		"cooldown_multiplier": 1.0,
		"applied_effects": [],
		"target_ids": [],
		"target_results": [],
	}
	if caster == null:
		return result
	var hit_targets: Array = []
	for raw_effect in skill.get("effects", []):
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect.duplicate(true)
		match str(effect.get("kind", "")):
			"damage":
				_apply_damage_effect(caster, _effect_targets(effect, caster, skill_targets, hit_targets), skill, effect, effect_resolver, rng, hit_targets, result)
			"heal":
				_apply_heal_effect(caster, _effect_targets(effect, caster, skill_targets, hit_targets), skill, effect, result)
			"status":
				if not bool(effect.get("requires_hit", false)) or not hit_targets.is_empty():
					_apply_status_effect(caster, _effect_targets(effect, caster, skill_targets, hit_targets), skill, effect, result)
			"cooldown":
				result["cooldown_multiplier"] = float(result.get("cooldown_multiplier", 1.0)) * maxf(0.0, float(effect.get("multiplier", 1.0)))
			_:
				_apply_custom_effect(caster, skill_targets, skill, effect, rng, result)
	if not result.get("target_ids", []).is_empty():
		result["target_id"] = str(result.get("target_ids", [""])[0])
	return result


func _apply_damage_effect(
	caster: CombatActorStatus,
	targets: Array,
	skill: Dictionary,
	effect: Dictionary,
	effect_resolver: CombatEffectResolver,
	rng: RandomNumberGenerator,
	hit_targets: Array,
	result: Dictionary
) -> void:
	var damage_affinity := _damage_affinity(skill, effect, caster)
	var scaling_element := "" if damage_affinity == DataTables.COMBAT_AFFINITY_NORMAL else damage_affinity
	if str(skill.get("type", "")) != "normal_attack":
		scaling_element = str(effect.get("element", ""))
		if scaling_element.is_empty():
			scaling_element = str(skill.get("element", ""))
	var raw_damage := SkillValueResolverScript.effect_amount(effect, scaling_element, caster)
	var attacker_modifiers := caster.equipment_combat_modifiers()
	raw_damage = maxi(1, roundi(float(raw_damage) * (1.0 + float(attacker_modifiers.get("direct_damage_percent", 0.0)))))
	if str(skill.get("type", "")) == "normal_attack":
		raw_damage = maxi(1, roundi(float(raw_damage) * (1.0 + float(attacker_modifiers.get("normal_attack_percent", 0.0)))))
	var is_critical := rng != null and rng.randf() < float(attacker_modifiers.get("critical_chance", 0.0))
	if is_critical:
		raw_damage = maxi(1, roundi(float(raw_damage) * float(attacker_modifiers.get("critical_multiplier", 1.5))))
	for candidate in targets:
		if not (candidate is CombatActorStatus):
			continue
		var target := candidate as CombatActorStatus
		if not target.is_alive():
			continue
		var context := effect_resolver.create_hit_result(caster.actor_id, target.actor_id, "skill", str(skill.get("id", ""))) if effect_resolver != null else {}
		context["events"] = []
		context["blocked_by_shield"] = 0
		var affinity_relation := DataTables.combat_affinity_relation(damage_affinity, target.combat_affinity())
		var defense_ignore := int(effect.get("defense_ignore", 0)) + int(attacker_modifiers.get("defense_ignore", 0))
		var weakness_multiplier := 1.0 + (float(attacker_modifiers.get("weakness_damage_percent", 0.0)) if affinity_relation == "overcome" else 0.0)
		var final_damage := maxi(1, roundi(float(_final_damage(raw_damage, affinity_relation, defense_ignore, target)) * weakness_multiplier))
		var target_modifiers := target.equipment_combat_modifiers()
		var target_reduction := float(target_modifiers.get("direct_damage_reduction", 0.0))
		final_damage = maxi(1, roundi(float(final_damage) * (1.0 - target_reduction)))
		# 命格受伤修正：按伤害类型分拆，负值为减伤、正值为易伤（缺陷命格），DOT 不经过此乘区。
		var damage_type := _damage_type(damage_affinity)
		var taken_key := "physical_damage_taken_percent" if damage_type == "physical" else "element_damage_taken_percent"
		var taken_percent := float(target_modifiers.get(taken_key, 0.0))
		if taken_percent != 0.0:
			final_damage = maxi(1, roundi(float(final_damage) * (1.0 + taken_percent)))
		if bool(effect.get("shieldable", true)) and final_damage > 0:
			final_damage = target.apply_shields(final_damage, context)
		var damage_result := target.apply_damage(final_damage, damage_type, {
			"skill_id": str(skill.get("id", "")),
			"effect_id": str(effect.get("effect_id", "")),
			"caster_id": caster.actor_id,
			"raw_damage": raw_damage,
			"damage_affinity": damage_affinity,
			"target_affinity": target.combat_affinity(),
			"affinity_relation": affinity_relation,
			"critical": is_critical,
		})
		var followup_events: Array = damage_result.get("followup_events", [])
		damage_result.erase("followup_events")
		_append_events(result, context.get("events", []))
		_append_event(result, damage_result)
		_append_events(result, followup_events)
		var dealt := int(damage_result.get("amount", 0))
		if dealt > 0:
			hit_targets.append(target)
		var leech_ratio := clampf(float(effect.get("leech_ratio", 0.0)) + float(attacker_modifiers.get("leech_percent", 0.0)), 0.0, 1.0)
		if dealt > 0 and leech_ratio > 0.0:
			var heal_result := caster.apply_heal(floori(float(dealt) * leech_ratio))
			_append_event(result, heal_result)
			result["heal"] = int(result.get("heal", 0)) + int(heal_result.get("amount", 0))
		result["damage"] = int(result.get("damage", 0)) + dealt
		result["blocked_by_shield"] = int(result.get("blocked_by_shield", 0)) + int(context.get("blocked_by_shield", 0))
		_record_target(result, target.actor_id, {"damage": dealt, "blocked_by_shield": int(context.get("blocked_by_shield", 0)), "damage_affinity": damage_affinity, "target_affinity": target.combat_affinity(), "affinity_relation": affinity_relation, "critical": is_critical})
		if is_critical:
			result["critical"] = true


func _apply_heal_effect(caster: CombatActorStatus, targets: Array, skill: Dictionary, effect: Dictionary, result: Dictionary) -> void:
	var amount := SkillValueResolverScript.effect_amount(effect, str(skill.get("element", "")), caster)
	amount = maxi(1, roundi(float(amount) * (1.0 + float(caster.equipment_combat_modifiers().get("direct_heal_percent", 0.0)))))
	for candidate in targets:
		if not (candidate is CombatActorStatus):
			continue
		var target := candidate as CombatActorStatus
		if not target.is_alive():
			continue
		var heal_result := target.apply_heal(amount)
		_append_event(result, heal_result)
		result["heal"] = int(result.get("heal", 0)) + int(heal_result.get("amount", 0))
		_record_target(result, target.actor_id, {"heal": int(heal_result.get("amount", 0))})


func _apply_status_effect(caster: CombatActorStatus, targets: Array, skill: Dictionary, effect: Dictionary, result: Dictionary) -> void:
	var status := effect.duplicate(true)
	status["kind"] = str(effect.get("status_kind", ""))
	status["amount"] = SkillValueResolverScript.effect_amount(effect, str(skill.get("element", "")), caster)
	status["value"] = status["amount"]
	status["element"] = str(effect.get("element", skill.get("element", "")))
	status["damage_affinity"] = _damage_affinity(skill, effect, caster)
	status["source_actor_id"] = caster.actor_id
	status["source_skill_id"] = str(skill.get("id", ""))
	status.erase("status_kind")
	status.erase("base_amount")
	status.erase("attribute_multiplier")
	for candidate in targets:
		if not (candidate is CombatActorStatus):
			continue
		var target := candidate as CombatActorStatus
		if not target.is_alive():
			continue
		var status_event := target.add_status_effect(status)
		if not status_event.is_empty():
			_append_event(result, status_event)
			var applied: Array = result.get("applied_effects", [])
			applied.append(status_event.get("status", {}).duplicate(true))
			result["applied_effects"] = applied
		_record_target(result, target.actor_id, {"status_id": str(status.get("status_id", ""))})


func _apply_custom_effect(caster: CombatActorStatus, targets: Array, skill: Dictionary, effect: Dictionary, rng: RandomNumberGenerator, result: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var api := tree.root.get_node_or_null("ModAPI") if tree != null else null
	var handler: Callable = api.effect_handler(str(effect.get("kind", ""))) if api != null else Callable()
	if not handler.is_valid():
		return
	var custom_result = handler.call(effect.duplicate(true), {
		"caster": caster,
		"targets": targets.duplicate(),
		"skill": skill.duplicate(true),
		"rng": rng,
	})
	if not (custom_result is Dictionary):
		return
	_append_events(result, custom_result.get("events", []))
	if custom_result.has("cooldown_multiplier"):
		result["cooldown_multiplier"] = float(result.get("cooldown_multiplier", 1.0)) * maxf(0.0, float(custom_result.get("cooldown_multiplier", 1.0)))


func _effect_targets(effect: Dictionary, caster: CombatActorStatus, skill_targets: Array, hit_targets: Array) -> Array:
	match str(effect.get("target", "skill_targets")):
		"caster":
			return [caster]
		"primary_target":
			return [skill_targets[0]] if not skill_targets.is_empty() else []
		"hit_targets":
			return hit_targets.duplicate()
		_:
			return skill_targets.duplicate()


func _final_damage(raw_damage: int, affinity_relation: String, defense_ignore: int, target: CombatActorStatus) -> int:
	var defense: int = maxi(0, target.total_stat("defense") - defense_ignore)
	var damage: int = maxi(1, raw_damage - defense)
	return DataTables.apply_combat_affinity_multiplier(damage, affinity_relation)


func _damage_type(damage_affinity: String) -> String:
	return "physical" if damage_affinity == DataTables.COMBAT_AFFINITY_NORMAL else "element_%s" % damage_affinity


func _damage_affinity(skill: Dictionary, effect: Dictionary, caster: CombatActorStatus) -> String:
	if str(skill.get("type", "")) == "normal_attack":
		return caster.combat_affinity()
	var element_id := str(effect.get("element", ""))
	if element_id.is_empty():
		element_id = str(skill.get("element", ""))
	return DataTables.normalize_combat_affinity(element_id)


func _append_event(result: Dictionary, event: Dictionary) -> void:
	var events: Array = result.get("events", [])
	events.append(event.duplicate(true))
	result["events"] = events


func _append_events(result: Dictionary, values: Array) -> void:
	for value in values:
		if value is Dictionary:
			_append_event(result, value)


func _record_target(result: Dictionary, actor_id: String, values: Dictionary) -> void:
	var ids: Array = result.get("target_ids", [])
	if not ids.has(actor_id):
		ids.append(actor_id)
	result["target_ids"] = ids
	var entries: Array = result.get("target_results", [])
	for index in range(entries.size()):
		if str(entries[index].get("target_id", "")) == actor_id:
			entries[index].merge(values, true)
			result["target_results"] = entries
			return
	var entry := {"target_id": actor_id}
	entry.merge(values, true)
	entries.append(entry)
	result["target_results"] = entries
