class_name CombatAI
extends RefCounted

const PLAYER_HP_HEAL_THRESHOLD := 0.35
const PLAYER_HP_DEFENSE_THRESHOLD := 0.60
const PLAYER_MP_RESOURCE_THRESHOLD := 0.25

const ACTION_SOURCE_SKILL := "skill"
const ACTION_SOURCE_PILL := "pill"
const ACTION_SOURCE_BASIC := "basic"
const ACTION_TYPE_HEAL := "heal"
const ACTION_TYPE_DEFENSE := "defense"
const ACTION_TYPE_BUFF := "buff"
const ACTION_TYPE_RESOURCE := "resource"
const ACTION_TYPE_DAMAGE := "damage"
const ACTION_TYPE_NORMAL_ATTACK := "normal_attack"
func select_player_action(game_state, player_range: float, distance_to_enemy: float, skill_cooldowns: Dictionary, pill_cooldowns: Dictionary, pill_group_cooldowns: Dictionary, member: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = member
	if actor.is_empty():
		return {}
	var member_id: String = str(actor.get("id", ""))
	var actor_stats: Dictionary = actor.get("stats", {})
	var hp_ratio: float = float(actor_stats.get("hp", 0)) / max(1.0, float(game_state.total_stat_for(member_id, "max_hp")))
	var mp_ratio: float = float(actor_stats.get("mp", 0)) / max(1.0, float(game_state.total_stat_for(member_id, "max_mp")))

	var heal_action: Dictionary = _find_best_available_action(game_state, ACTION_TYPE_HEAL, hp_ratio, mp_ratio, skill_cooldowns, pill_cooldowns, pill_group_cooldowns, player_range, distance_to_enemy, actor)
	if hp_ratio <= PLAYER_HP_HEAL_THRESHOLD and not heal_action.is_empty():
		return heal_action

	var defense_action: Dictionary = _find_best_available_action(game_state, ACTION_TYPE_DEFENSE, hp_ratio, mp_ratio, skill_cooldowns, pill_cooldowns, pill_group_cooldowns, player_range, distance_to_enemy, actor)
	if hp_ratio <= PLAYER_HP_DEFENSE_THRESHOLD and not defense_action.is_empty():
		return defense_action

	var buff_action: Dictionary = _find_best_available_action(game_state, ACTION_TYPE_BUFF, hp_ratio, mp_ratio, skill_cooldowns, pill_cooldowns, pill_group_cooldowns, player_range, distance_to_enemy, actor)
	if not buff_action.is_empty():
		return buff_action

	var resource_action: Dictionary = _find_best_available_action(game_state, ACTION_TYPE_RESOURCE, hp_ratio, mp_ratio, skill_cooldowns, pill_cooldowns, pill_group_cooldowns, player_range, distance_to_enemy, actor)
	if mp_ratio <= PLAYER_MP_RESOURCE_THRESHOLD and not resource_action.is_empty():
		return resource_action

	var damage_action: Dictionary = _find_best_available_action(game_state, ACTION_TYPE_DAMAGE, hp_ratio, mp_ratio, skill_cooldowns, pill_cooldowns, pill_group_cooldowns, player_range, distance_to_enemy, actor)
	if not damage_action.is_empty():
		return damage_action

	var attack_mode: String = str(actor.get("attack_mode", DataTables.ATTACK_MODE_MELEE))
	var basic_attack: Dictionary = DataTables.create_basic_attack(attack_mode)
	return {
		"source": ACTION_SOURCE_BASIC,
		"action_type": ACTION_TYPE_NORMAL_ATTACK,
		"id": str(basic_attack.get("id", "basic_attack")),
		"attack_mode": str(basic_attack.get("attack_mode", DataTables.ATTACK_MODE_MELEE)),
		"priority": 0,
		"range": max(player_range, float(basic_attack.get("basic_attack_range", 0.0))),
		"cooldown_group": "",
	}


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
