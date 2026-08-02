class_name DirectDamageSkill
extends SkillSceneBase


func apply_marker(marker: String) -> void:
	var expected_marker: String = str(skill_data.get("damage_marker", skill_data.get("apply_marker", "impact")))
	if marker != expected_marker:
		return
	if caster == null:
		return
	_apply_skill_buffs()
	var raw_damage: int = _raw_damage()
	if raw_damage <= 0:
		return
	last_result["damage"] = 0
	last_result["blocked_by_shield"] = 0
	last_result["healed"] = 0
	last_result["applied_effects"] = []
	last_result["cooldown_multiplier"] = 1.0
	last_result["target_ids"] = []
	last_result["target_results"] = []
	for candidate in targets:
		if not (candidate is CombatActorStatus):
			continue
		var target := candidate as CombatActorStatus
		if not target.is_alive():
			continue
		var target_result := _apply_damage_to_target(target, raw_damage)
		var target_ids: Array = last_result.get("target_ids", [])
		target_ids.append(target.actor_id)
		last_result["target_ids"] = target_ids
		var target_results: Array = last_result.get("target_results", [])
		target_results.append(target_result)
		last_result["target_results"] = target_results
		last_result["damage"] = int(last_result.get("damage", 0)) + int(target_result.get("damage", 0))
		last_result["blocked_by_shield"] = int(last_result.get("blocked_by_shield", 0)) + int(target_result.get("blocked_by_shield", 0))
		last_result["healed"] = int(last_result.get("healed", 0)) + int(target_result.get("healed", 0))
		last_result["cooldown_multiplier"] = minf(float(last_result.get("cooldown_multiplier", 1.0)), float(target_result.get("cooldown_multiplier", 1.0)))
		var applied_effects: Array = last_result.get("applied_effects", [])
		applied_effects.append_array(target_result.get("applied_effects", []))
		last_result["applied_effects"] = applied_effects
	if not last_result.get("target_ids", []).is_empty():
		last_result["target_id"] = str(last_result.get("target_ids", [""])[0])


func _apply_damage_to_target(target: CombatActorStatus, raw_damage: int) -> Dictionary:
	var element_id: String = str(skill_data.get("element", ""))
	if element_id.is_empty():
		element_id = caster.dominant_element()
	var context: Dictionary = attack_context(target, raw_damage, element_id)
	var effects: Array = attack_effects()
	resolve_static_trigger("attack_start", context, effects, "attacker")
	resolve_actor_status_trigger(caster, "attack_start", context, "attacker")
	apply_effect_events(context)
	resolve_static_trigger("before_hit", context, effects, "attacker")
	resolve_actor_status_trigger(caster, "before_hit", context, "attacker")
	apply_effect_events(context)
	element_id = str(context.get("element", element_id))
	var amount: int = _final_damage(context, target)
	if amount > 0 and effect_resolver != null:
		amount = target.apply_shields(amount, context)
	context["final_damage"] = amount
	if amount > 0:
		resolve_static_trigger("on_hit", context, effects, "attacker")
		resolve_actor_status_trigger(caster, "on_hit", context, "attacker")
	var result: Dictionary = target.apply_damage(amount, damage_type_from_element(element_id), {
		"skill_id": str(skill_data.get("id", "")),
		"caster_id": caster.actor_id,
		"raw_damage": raw_damage,
	})
	_add_context_damage(context, target, int(result.get("amount", 0)))
	add_event(result)
	if amount > 0:
		apply_effect_events(context)
	if amount > 0 or int(context.get("blocked_by_shield", 0)) > 0:
		resolve_static_trigger("on_damaged", context, defender_effects(), "defender")
		resolve_actor_status_trigger(target, "on_damaged", context, "defender")
		resolve_static_trigger("after_damage", context, effects, "attacker")
		resolve_actor_status_trigger(caster, "after_damage", context, "attacker")
		resolve_static_trigger("after_damage", context, defender_effects(), "defender")
		resolve_actor_status_trigger(target, "after_damage", context, "defender")
		apply_effect_events(context)
	if bool(result.get("is_dead", false)):
		resolve_static_trigger("on_kill", context, effects, "attacker")
		resolve_actor_status_trigger(caster, "on_kill", context, "attacker")
		apply_effect_events(context)
	return {
		"target_id": target.actor_id,
		"damage": int(result.get("amount", 0)),
		"blocked_by_shield": int(context.get("blocked_by_shield", 0)),
		"healed": int(context.get("healed", 0)),
		"applied_effects": context.get("applied_effects", []).duplicate(true),
		"cooldown_multiplier": float(context.get("cooldown_multiplier", 1.0)),
	}


func _apply_skill_buffs() -> void:
	for buff in skill_data.get("combat_buffs", []):
		if buff is Dictionary:
			var next_buff: Dictionary = scaled_skill_effect(buff)
			next_buff["source_skill_id"] = str(skill_data.get("id", ""))
			caster.add_buff(next_buff)


func _raw_damage() -> int:
	return skill_damage_amount()


func _final_damage(context: Dictionary, target: CombatActorStatus) -> int:
	var raw_damage: int = int(context.get("damage", 0))
	var element_id: String = str(context.get("element", ""))
	var defense: int = max(0, target.total_stat("defense") - int(context.get("defense_ignore", 0)))
	var damage: int = max(1, raw_damage - defense)
	var uses_legacy_element_bonus := str(skill_data.get("type", "")) == "normal_attack" or (not skill_data.has("base_damage") and not skill_data.has("damage_attribute_multiplier"))
	if caster.actor_kind == CombatActorStatus.KIND_MEMBER and uses_legacy_element_bonus:
		damage += int(caster.total_element(element_id) * 0.5)
	if target.actor_kind == CombatActorStatus.KIND_ENEMY:
		if element_id == str(target.data.get("weak_element", "")):
			damage += max(1, int(raw_damage * 0.25)) + caster.total_element(element_id)
	else:
		if not element_id.is_empty():
			damage = max(0, damage - int(target.total_element(element_id) * 0.35))
	return damage
