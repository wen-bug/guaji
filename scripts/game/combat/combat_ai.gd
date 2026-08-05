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
		"range": max(player_range, float(basic_attack.get("release_distance", 0.0))),
		"cooldown_group": "",
	}


func preferred_player_release_distance(action: Dictionary, player_range: float) -> float:
	if action.is_empty():
		return player_range
	if str(action.get("source", "")) == ACTION_SOURCE_SKILL:
		var skill: Dictionary = DataTables.create_skill(str(action.get("id", "")))
		return _skill_release_distance(skill, player_range)
	return max(player_range, float(action.get("range", player_range)))


func _find_best_available_action(game_state, action_type: String, hp_ratio: float, mp_ratio: float, skill_cooldowns: Dictionary, pill_cooldowns: Dictionary, pill_group_cooldowns: Dictionary, player_range: float, distance_to_enemy: float, member: Dictionary = {}) -> Dictionary:
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
			"range": float(skill.get("release_distance", player_range)),
			"cooldown_group": str(skill.get("cooldown_group", action_type)),
		})

	for raw_item in game_state.inventory_items_for_type(DataTables.ITEM_TYPE_PILL):
		var item: Dictionary = raw_item
		var pill_action: Dictionary = _pill_action_from_item(item, action_type)
		if pill_action.is_empty():
			continue
		var item_id: String = str(item.get("item_id", ""))
		var group_id: String = str(pill_action.get("cooldown_group", ""))
		if float(pill_cooldowns.get(item_id, 0.0)) > 0.0:
			continue
		if not group_id.is_empty() and float(pill_group_cooldowns.get(group_id, 0.0)) > 0.0:
			continue
		candidates.append(pill_action)

	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	return candidates[0]


func _pill_action_from_item(item: Dictionary, requested_type: String) -> Dictionary:
	var payload: Dictionary = item.get("payload", {})
	var action_type: String = _pill_action_type(payload)
	if action_type != requested_type:
		return {}
	var cooldown_group: String = "%s_pill" % action_type
	return {
		"source": ACTION_SOURCE_PILL,
		"action_type": action_type,
		"id": str(item.get("instance_id", "")),
		"item_id": str(item.get("item_id", "")),
		"priority": _pill_priority(action_type),
		"range": 0.0,
		"cooldown_group": cooldown_group,
		"cooldown": 2,
	}


func _pill_action_type(payload: Dictionary) -> String:
	if int(payload.get("hp", 0)) > 0:
		return ACTION_TYPE_HEAL
	if int(payload.get("mp", 0)) > 0:
		return ACTION_TYPE_RESOURCE
	if str(payload.get("stat", "")) == "defense":
		return ACTION_TYPE_DEFENSE
	if str(payload.get("stat", "")) == "attack":
		return ACTION_TYPE_DAMAGE
	return ""


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


func _skill_trigger_matches(skill: Dictionary, hp_ratio: float, mp_ratio: float, distance_to_enemy: float, player_range: float) -> bool:
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
				if distance_to_enemy <= player_range:
					return true
	return false


func _skill_release_distance(skill: Dictionary, player_range: float) -> float:
	return max(player_range, float(skill.get("release_distance", player_range)))
