class_name CombatAI
extends RefCounted

const PLAYER_HP_HEAL_THRESHOLD := 0.35
const PLAYER_HP_DEFENSE_THRESHOLD := 0.60
const PLAYER_MP_RESOURCE_THRESHOLD := 0.25
const SHIELD_SAFE_RATIO := 0.20

const ACTION_SOURCE_SKILL := "skill"
const ACTION_SOURCE_PILL := "pill"
const ACTION_SOURCE_BASIC := "basic"
const ACTION_TYPE_HEAL := "heal"
const ACTION_TYPE_DEFENSE := "defense"
const ACTION_TYPE_BUFF := "buff"
const ACTION_TYPE_RESOURCE := "resource"
const ACTION_TYPE_DAMAGE := "damage"
const ACTION_TYPE_NORMAL_ATTACK := "normal_attack"
func select_player_action(game_state, player_range: float, distance_to_enemy: float, skill_cooldowns: Dictionary, _pill_cooldowns: Dictionary, _pill_group_cooldowns: Dictionary, member: Dictionary = {}, combat_context: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = member
	if actor.is_empty():
		return {}
	var member_id: String = str(actor.get("id", ""))
	var actor_stats: Dictionary = actor.get("stats", {})
	var hp_ratio: float = float(actor_stats.get("hp", 0)) / max(1.0, float(game_state.total_stat_for(member_id, "max_hp")))
	var mp_ratio: float = float(actor_stats.get("mp", 0)) / max(1.0, float(game_state.total_stat_for(member_id, "max_mp")))

	var heal_action := _best_context_action(ACTION_TYPE_HEAL, actor, skill_cooldowns, combat_context, hp_ratio, mp_ratio, distance_to_enemy, player_range)
	if not heal_action.is_empty():
		return heal_action

	var defense_action := _best_context_action(ACTION_TYPE_DEFENSE, actor, skill_cooldowns, combat_context, hp_ratio, mp_ratio, distance_to_enemy, player_range)
	if not defense_action.is_empty():
		return defense_action

	var buff_action := _best_context_action(ACTION_TYPE_BUFF, actor, skill_cooldowns, combat_context, hp_ratio, mp_ratio, distance_to_enemy, player_range)
	if not buff_action.is_empty():
		return buff_action

	var resource_action := _best_context_action(ACTION_TYPE_RESOURCE, actor, skill_cooldowns, combat_context, hp_ratio, mp_ratio, distance_to_enemy, player_range)
	if mp_ratio <= PLAYER_MP_RESOURCE_THRESHOLD and not resource_action.is_empty():
		return resource_action

	var damage_action := _best_context_action(ACTION_TYPE_DAMAGE, actor, skill_cooldowns, combat_context, hp_ratio, mp_ratio, distance_to_enemy, player_range)
	if not damage_action.is_empty():
		return damage_action

	var attack_mode: String = str(actor.get("attack_mode", DataTables.ATTACK_MODE_MELEE))
	var basic_attack: Dictionary = DataTables.create_basic_attack(attack_mode)
	var basic := {
		"source": ACTION_SOURCE_BASIC,
		"action_type": ACTION_TYPE_NORMAL_ATTACK,
		"id": str(basic_attack.get("id", "basic_attack")),
		"attack_mode": str(basic_attack.get("attack_mode", DataTables.ATTACK_MODE_MELEE)),
		"priority": 0,
		"range": max(player_range, float(basic_attack.get("basic_attack_range", 0.0))),
		"cooldown_group": "",
	}
	var opponents: Array = combat_context.get("opponents", [])
	if not opponents.is_empty() and opponents[0] is CombatActorStatus:
		basic["preferred_target_id"] = (opponents[0] as CombatActorStatus).actor_id
	return basic


func select_enemy_action(enemy_data: Dictionary, combat_context: Dictionary) -> Dictionary:
	var caster: CombatActorStatus = combat_context.get("caster") as CombatActorStatus
	if caster == null:
		return {}
	var snapshot := caster.combat_snapshot()
	var hp_ratio := float(snapshot.get("hp", 0)) / maxf(1.0, float(snapshot.get("max_hp", 1)))
	var candidates: Array[Dictionary] = []
	for slot in range(enemy_data.get("skills", []).size()):
		var skill := DataTables.create_skill(str(enemy_data.get("skills", [])[slot]))
		if skill.is_empty() or int(enemy_data.get("skill_cooldowns", {}).get(str(skill.get("id", "")), 0)) > 0:
			continue
		if not _skill_trigger_matches_context(skill, hp_ratio, 1.0, combat_context):
			continue
		var evaluated := _evaluate_skill(skill, combat_context, caster)
		if evaluated.is_empty():
			continue
		evaluated["slot"] = slot
		candidates.append(evaluated)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_survival := int(a.get("category_rank", 0))
		var b_survival := int(b.get("category_rank", 0))
		if a_survival != b_survival: return a_survival > b_survival
		var ap := int(a.get("priority", 0)); var bp := int(b.get("priority", 0))
		return ap > bp if ap != bp else int(a.get("slot", 0)) < int(b.get("slot", 0))
	)
	return candidates[0]


func select_auto_item_action(game_state, pill_cooldowns: Dictionary, pill_group_cooldowns: Dictionary, member: Dictionary = {}) -> Dictionary:
	if member.is_empty():
		return {}
	var member_id := str(member.get("id", ""))
	var stats: Dictionary = member.get("stats", {})
	var hp_ratio := float(stats.get("hp", 0)) / maxf(1.0, float(game_state.total_stat_for(member_id, "max_hp")))
	var mp_ratio := float(stats.get("mp", 0)) / maxf(1.0, float(game_state.total_stat_for(member_id, "max_mp")))
	for raw_item_id in game_state.auto_use_item_ids:
		var item_id := str(raw_item_id)
		if item_id.is_empty() or game_state.inventory_item_count(item_id) <= 0:
			continue
		var item: Dictionary = game_state.inventory_item_by_instance(item_id)
		var action_type := str(item.get("ai_action_type", ""))
		if action_type.is_empty():
			action_type = _pill_action_type(item.get("payload", {}))
		if not _pill_trigger_matches(action_type, hp_ratio, mp_ratio):
			continue
		var action := _pill_action_from_item(item, action_type)
		if action.is_empty() or not _item_has_benefit(game_state, item, member, hp_ratio, mp_ratio):
			continue
		var group_id := str(action.get("cooldown_group", ""))
		if float(pill_cooldowns.get(item_id, 0.0)) > 0.0:
			continue
		if not group_id.is_empty() and float(pill_group_cooldowns.get(group_id, 0.0)) > 0.0:
			continue
		return action
	return {}


func _find_best_available_action(_game_state, action_type: String, hp_ratio: float, mp_ratio: float, skill_cooldowns: Dictionary, _pill_cooldowns: Dictionary, _pill_group_cooldowns: Dictionary, player_range: float, distance_to_enemy: float, member: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = member
	if actor.is_empty():
		return {}
	var actor_stats: Dictionary = actor.get("stats", {})
	var candidates: Array[Dictionary] = []
	for skill in actor.get("skills", []):
		if bool(skill.get("disabled", false)):
			continue
		if str(skill.get("type", "")) != action_type:
			continue
		if not _skill_trigger_matches(skill, hp_ratio, mp_ratio, distance_to_enemy, player_range):
			continue
		if float(skill_cooldowns.get(str(skill.get("id", "")), 0.0)) > 0.0:
			continue
		if int(actor_stats.get("mp", 0)) < int(skill.get("mp_cost", 0)):
			continue
		candidates.append({
			"source": ACTION_SOURCE_SKILL,
			"action_type": action_type,
			"id": str(skill.get("id", "")),
			"priority": int(skill.get("priority", 0)),
			"cooldown_group": str(skill.get("cooldown_group", action_type)),
		})

	if candidates.is_empty():
		return {}
	# Slot order decides: skills are collected in member slot order, so the first
	# candidate is the front-most usable skill of this action type.
	return candidates[0]


func _best_context_action(action_type: String, actor: Dictionary, skill_cooldowns: Dictionary, context: Dictionary, hp_ratio: float, mp_ratio: float, distance_to_enemy: float, player_range: float) -> Dictionary:
	var caster: CombatActorStatus = context.get("caster") as CombatActorStatus
	var candidates: Array[Dictionary] = []
	for slot in range(actor.get("skills", []).size()):
		var skill: Dictionary = actor.get("skills", [])[slot]
		if bool(skill.get("disabled", false)) or str(skill.get("type", "")) != action_type:
			continue
		if float(skill_cooldowns.get(str(skill.get("id", "")), 0.0)) > 0.0:
			continue
		if int(actor.get("stats", {}).get("mp", 0)) < int(skill.get("mp_cost", 0)):
			continue
		if not _skill_trigger_matches_context(skill, hp_ratio, mp_ratio, context):
			continue
		if context.is_empty():
			if _skill_trigger_matches(skill, hp_ratio, mp_ratio, distance_to_enemy, player_range):
				return _action_from_skill(skill, action_type)
			continue
		var evaluated := _evaluate_skill(skill, context, caster)
		if evaluated.is_empty():
			continue
		evaluated["slot"] = slot
		candidates.append(evaluated)
	if candidates.is_empty():
		return {}
	if action_type == ACTION_TYPE_DAMAGE:
		return candidates[0]
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		var av := int(a.get("benefit", 0)); var bv := int(b.get("benefit", 0))
		return av > bv if av != bv else int(a.get("slot", 0)) < int(b.get("slot", 0))
	)
	return candidates[0]


func _evaluate_skill(skill: Dictionary, context: Dictionary, caster: CombatActorStatus) -> Dictionary:
	var scope := DataTables.skill_target_scope(skill)
	var allies: Array = context.get("allies", [])
	var opponents: Array = context.get("opponents", [])
	var pool: Array = allies if scope in [DataTables.SKILL_TARGET_SELF, DataTables.SKILL_TARGET_SINGLE_ALLY, DataTables.SKILL_TARGET_ALL_ALLIES] else opponents
	if scope == DataTables.SKILL_TARGET_SELF:
		pool = [caster]
	if pool.is_empty():
		return {}
	var targets := _ai_targets(pool, skill, scope, caster)
	var skill_type := str(skill.get("type", ACTION_TYPE_DAMAGE))
	var benefit := 0
	var preferred: CombatActorStatus = null
	if skill_type == ACTION_TYPE_HEAL:
		for target in targets:
			var snapshot := (target as CombatActorStatus).combat_snapshot()
			var missing := maxi(0, int(snapshot.get("max_hp", 0)) - int(snapshot.get("hp", 0)))
			var ratio := float(snapshot.get("hp", 0)) / maxf(1.0, float(snapshot.get("max_hp", 1)))
			if ratio <= PLAYER_HP_HEAL_THRESHOLD and missing > 0:
				benefit += 100000 + missing
				if preferred == null: preferred = target
	elif skill_type == ACTION_TYPE_DEFENSE or _skill_has_status_kind(skill, "shield"):
		for target in targets:
			var snapshot := (target as CombatActorStatus).combat_snapshot()
			var ratio := float(snapshot.get("hp", 0)) / maxf(1.0, float(snapshot.get("max_hp", 1)))
			var shield := _total_shield(snapshot.get("combat_effects", []))
			var shield_need := shield < ceili(float(snapshot.get("max_hp", 1)) * SHIELD_SAFE_RATIO) or _skill_status_refresh_has_benefit(skill, target)
			if ratio <= PLAYER_HP_DEFENSE_THRESHOLD and shield_need:
				benefit += 100000 + maxi(0, ceili(float(snapshot.get("max_hp", 1)) * SHIELD_SAFE_RATIO) - shield)
				if preferred == null: preferred = target
	elif skill_type == ACTION_TYPE_BUFF and not _skill_has_direct_damage(skill):
		for target in targets:
			if _skill_status_refresh_has_benefit(skill, target):
				benefit += 1000
				if preferred == null: preferred = target
	else:
		benefit = 1
		preferred = targets[0] as CombatActorStatus
	if benefit <= 0:
		return {}
	var action := _action_from_skill(skill, skill_type)
	action["benefit"] = benefit
	action["category_rank"] = 3 if skill_type == ACTION_TYPE_HEAL else (2 if skill_type in [ACTION_TYPE_DEFENSE, ACTION_TYPE_BUFF] else 1)
	if preferred != null:
		action["preferred_target_id"] = preferred.actor_id
	return action


func _ai_targets(pool: Array, skill: Dictionary, scope: String, caster: CombatActorStatus) -> Array:
	if scope == DataTables.SKILL_TARGET_SELF:
		return [caster]
	if scope in [DataTables.SKILL_TARGET_SINGLE_ALLY, DataTables.SKILL_TARGET_SINGLE_ENEMY]:
		if scope == DataTables.SKILL_TARGET_SINGLE_ALLY:
			var sorted := pool.duplicate()
			sorted.sort_custom(func(a: CombatActorStatus, b: CombatActorStatus): return _hp_ratio(a) < _hp_ratio(b))
			return [sorted[0]]
		return [pool[0]]
	var count := DataTables.skill_target_count(skill, pool.size())
	var start := pool.size() - count if DataTables.skill_target_tendency(skill) == DataTables.SKILL_TARGET_TENDENCY_BACK else 0
	return pool.slice(start, start + count)


func _action_from_skill(skill: Dictionary, action_type: String) -> Dictionary:
	return {"source": ACTION_SOURCE_SKILL, "action_type": action_type, "id": str(skill.get("id", "")), "priority": int(skill.get("priority", 0)), "cooldown_group": str(skill.get("cooldown_group", action_type))}


func _hp_ratio(status: CombatActorStatus) -> float:
	var snapshot := status.combat_snapshot()
	return float(snapshot.get("hp", 0)) / maxf(1.0, float(snapshot.get("max_hp", 1)))


func _total_shield(effects: Array) -> int:
	var result := 0
	for effect in effects:
		if effect is Dictionary and str(effect.get("kind", "")) == "shield":
			result += maxi(0, int(effect.get("amount", effect.get("value", 0))))
	return result


func _skill_status_refresh_has_benefit(skill: Dictionary, target: CombatActorStatus) -> bool:
	var active := target.active_statuses()
	var has_status := false
	for raw_effect in skill.get("effects", []):
		if not (raw_effect is Dictionary) or str(raw_effect.get("kind", "")) != "status":
			continue
		has_status = true
		var status_id := str(raw_effect.get("status_id", ""))
		var existing: Dictionary = {}
		for status in active:
			if status is Dictionary and str(status.get("status_id", "")) == status_id:
				existing = status
				break
		if existing.is_empty():
			return true
		if str(raw_effect.get("stack_mode", "refresh")) == "stack" and int(existing.get("stacks", 1)) < int(raw_effect.get("max_stacks", 1)):
			return true
		if int(existing.get("remaining_turns", 99)) <= 1:
			return true
		if str(raw_effect.get("status_kind", "")) == "shield":
			var fresh_amount := SkillValueResolver.effect_amount(raw_effect, str(skill.get("element", "")), target)
			if int(existing.get("amount", 0)) * 2 < fresh_amount:
				return true
	return not has_status


func _skill_has_direct_damage(skill: Dictionary) -> bool:
	for effect in skill.get("effects", []):
		if effect is Dictionary and str(effect.get("kind", "")) == "damage": return true
	return false


func _skill_has_status_kind(skill: Dictionary, kind: String) -> bool:
	for effect in skill.get("effects", []):
		if effect is Dictionary and str(effect.get("status_kind", "")) == kind: return true
	return false


func _skill_trigger_matches_context(skill: Dictionary, caster_hp: float, mp_ratio: float, context: Dictionary) -> bool:
	var triggers: Array = skill.get("trigger", ["always"])
	if triggers.is_empty() or triggers.has("always"):
		return true
	var allies: Array = context.get("allies", [])
	var opponents: Array = context.get("opponents", [])
	for trigger in triggers:
		match str(trigger):
			"hp_below_35":
				if allies.any(func(status): return status is CombatActorStatus and _hp_ratio(status) <= PLAYER_HP_HEAL_THRESHOLD): return true
			"hp_below_60":
				if allies.any(func(status): return status is CombatActorStatus and _hp_ratio(status) <= PLAYER_HP_DEFENSE_THRESHOLD): return true
			"hp_below_50":
				if caster_hp <= 0.5: return true
			"target_hp_below_35":
				if not opponents.is_empty() and _hp_ratio(opponents[0]) <= PLAYER_HP_HEAL_THRESHOLD: return true
			"mp_below_25":
				if mp_ratio <= PLAYER_MP_RESOURCE_THRESHOLD: return true
			"enemy_in_range":
				return true
	return false


func _pill_action_from_item(item: Dictionary, requested_type: String) -> Dictionary:
	var payload: Dictionary = item.get("payload", {})
	var action_type: String = str(item.get("ai_action_type", ""))
	if action_type.is_empty():
		action_type = _pill_action_type(payload)
	if action_type != requested_type:
		return {}
	var cooldown_group: String = str(item.get("shared_cooldown_group", payload.get("cooldown_group", "%s_pill" % action_type)))
	return {
		"source": ACTION_SOURCE_PILL,
		"action_type": action_type,
		"id": str(item.get("instance_id", "")),
		"item_id": str(item.get("item_id", "")),
		"priority": _pill_priority(action_type),
		"range": 0.0,
		"cooldown_group": cooldown_group,
		"cooldown": maxi(1, int(item.get("combat_cooldown_turns", payload.get("cooldown", 2)))),
	}


func _item_has_benefit(game_state, item: Dictionary, member: Dictionary, hp_ratio: float, mp_ratio: float) -> bool:
	var member_id := str(member.get("id", ""))
	for raw_effect in item.get("effects", []):
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect
		match str(effect.get("kind", "")):
			"restore_resource":
				var stat := str(effect.get("stat", ""))
				if stat == "hp" and hp_ratio < 1.0: return true
				if stat == "mp" and mp_ratio < 1.0: return true
			"temporary_modifier":
				var target := str(effect.get("target", "member"))
				if not game_state.item_buff_active(str(effect.get("buff_id", "")), target, member_id): return true
	return item.get("effects", []).is_empty()


func _pill_action_type(payload: Dictionary) -> String:
	if int(payload.get("hp", 0)) > 0 or float(payload.get("hp_ratio", 0.0)) > 0.0:
		return ACTION_TYPE_HEAL
	if int(payload.get("mp", 0)) > 0 or float(payload.get("mp_ratio", 0.0)) > 0.0:
		return ACTION_TYPE_RESOURCE
	if str(payload.get("stat", "")) == "defense":
		return ACTION_TYPE_DEFENSE
	if str(payload.get("stat", "")) == "attack":
		return ACTION_TYPE_DAMAGE
	return ""


func _pill_trigger_matches(action_type: String, hp_ratio: float, mp_ratio: float) -> bool:
	match action_type:
		ACTION_TYPE_HEAL:
			return hp_ratio <= PLAYER_HP_HEAL_THRESHOLD
		ACTION_TYPE_DEFENSE:
			return hp_ratio <= PLAYER_HP_DEFENSE_THRESHOLD
		ACTION_TYPE_RESOURCE:
			return mp_ratio <= PLAYER_MP_RESOURCE_THRESHOLD
		ACTION_TYPE_BUFF, ACTION_TYPE_DAMAGE:
			return true
		_:
			return false


func _pill_priority(action_type: String) -> int:
	match action_type:
		ACTION_TYPE_HEAL:
			return 95
		ACTION_TYPE_DEFENSE:
			return 75
		ACTION_TYPE_RESOURCE:
			return 55
		ACTION_TYPE_DAMAGE:
			return 35
		_:
			return 0


func _skill_trigger_matches(skill: Dictionary, hp_ratio: float, mp_ratio: float, _distance_to_enemy: float, _player_range: float) -> bool:
	var triggers: Array = skill.get("trigger", ["always"])
	if triggers.is_empty():
		return true
	for trigger in triggers:
		match str(trigger):
			"always":
				return true
			"hp_below_35":
				if hp_ratio <= PLAYER_HP_HEAL_THRESHOLD:
					return true
			"hp_below_60":
				if hp_ratio <= PLAYER_HP_DEFENSE_THRESHOLD:
					return true
			"mp_below_25":
				if mp_ratio <= PLAYER_MP_RESOURCE_THRESHOLD:
					return true
			"enemy_in_range":
				return true
	return false
