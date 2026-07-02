class_name CombatController
extends Node2D

signal log_added(message: String)
signal damage_popup_requested(amount: int, world_position: Vector2, target_key: String, damage_type: String, is_heal: bool)
signal player_attack_started(action_type: String)
signal player_hit_received(amount: int, damage_type: String)
signal enemy_hit_received(amount: int, damage_type: String)
signal enemy_attack_started(enemy_id: String)

const PLAYER_TURN_WAIT := 1.1
const ENEMY_TURN_WAIT := 1.4
const DEFAULT_ATTACK_RANGE := 96.0
const DEFAULT_ENEMY_ATTACK_RANGE := 88.0
const DEFAULT_MOVE_STEP := 120.0
const DEFAULT_RETREAT_DISTANCE := 72.0
const DEFAULT_ENEMY_SPAWN_DELAY := 0.8
const DEFAULT_ENEMY_POSITION := Vector2(866, 126)

const ACTION_SOURCE_SKILL := "skill"
const ACTION_SOURCE_PILL := "pill"
const ACTION_SOURCE_BASIC := "basic"
const ACTION_TYPE_NORMAL_ATTACK := "normal_attack"

enum PlayerCombatState { RUNNING, APPROACHING, READY, ACTING, RECOVERING, VICTORY, DEFEATED, LEAVING }
enum EnemyCombatState { SPAWNING, WAITING, APPROACHING, ACTING, RECOVERING, DEAD }

var active := false
var finished := false
var enemy := {}
var player_state := PlayerCombatState.RUNNING
var enemy_state := EnemyCombatState.WAITING
var player_cooldown := 0.0
var enemy_cooldown := 0.0
var skill_cooldowns := {}
var pill_cooldowns := {}
var pill_group_cooldowns := {}
var combat_buffs := []
var party_combatants: Array[Dictionary] = []
var player_action_resolving := false
var enemy_position := DEFAULT_ENEMY_POSITION
var current_enemy_node: BaseEnemy = null
var animation_player: AnimationPlayer
var skill_resolver := SkillResolver.new()
var combat_ai := CombatAI.new()
var pending_action := {}
var pending_game_state: GameState = null
var animation_action: Dictionary = {}
var animation_game_state: GameState = null
var animation_hit_applied := false
var battle_map: Node2D = null
var player_range := DEFAULT_ATTACK_RANGE
var enemy_range := DEFAULT_ENEMY_ATTACK_RANGE
var player_move_speed := DEFAULT_MOVE_STEP
var player_retreat_distance := DEFAULT_RETREAT_DISTANCE
var enemy_move_speed := DEFAULT_MOVE_STEP
var _player_position := Vector2.ZERO
var _home_position := Vector2.ZERO


func _ready() -> void:
	_bind_scene_nodes()
	_update_enemy_visual()


func begin_encounter(game_state: GameState, map_node: Node2D = null, enemy_id: String = "") -> void:
	_bind_scene_nodes()
	battle_map = map_node if map_node != null else battle_map
	if battle_map == null:
		battle_map = get_parent() as Node2D
	_set_combat_positions()
	enemy_position = DEFAULT_ENEMY_POSITION
	enemy = DataTables.create_enemy(game_state.stats["level"], game_state.rng, enemy_id)
	_spawn_enemy_node(str(enemy.get("id", DataTables.DEFAULT_ENEMY_ID)))
	_setup_party_combatants(game_state)
	active = true
	finished = false
	player_state = PlayerCombatState.APPROACHING
	enemy_state = EnemyCombatState.SPAWNING
	player_cooldown = 0.0
	enemy_cooldown = float(enemy.get("spawn_delay", DEFAULT_ENEMY_SPAWN_DELAY))
	player_action_resolving = false
	pending_action.clear()
	pending_game_state = null
	skill_cooldowns.clear()
	pill_cooldowns.clear()
	pill_group_cooldowns.clear()
	combat_buffs.clear()
	player_range = float(enemy.get("player_attack_range", DEFAULT_ATTACK_RANGE))
	enemy_range = float(enemy.get("attack_range", DEFAULT_ENEMY_ATTACK_RANGE))
	player_move_speed = float(enemy.get("player_move_speed", DEFAULT_MOVE_STEP))
	enemy_move_speed = float(enemy.get("move_speed", DEFAULT_MOVE_STEP))
	log_added.emit("遭遇%s，弱%s" % [enemy["name"], DataTables.element_name(enemy["weak_element"])] )
	_update_enemy_visual()


func tick(delta: float, game_state: GameState) -> void:
	if not active or finished:
		return
	_tick_party_combatants(delta, game_state)
	_update_enemy_combat_state(delta, game_state)
	_check_combat_result(game_state)
	_update_enemy_visual()


func is_finished() -> bool:
	return finished


func clear() -> void:
	active = false
	finished = false
	enemy = {}
	player_state = PlayerCombatState.LEAVING
	enemy_state = EnemyCombatState.DEAD
	player_cooldown = 0.0
	enemy_cooldown = 0.0
	player_action_resolving = false
	pending_action.clear()
	pending_game_state = null
	animation_action.clear()
	animation_game_state = null
	animation_hit_applied = false
	combat_buffs.clear()
	party_combatants.clear()
	battle_map = null
	_clear_enemy_node()
	_update_enemy_visual()


func combat_status() -> Dictionary:
	return {
		"active": active,
		"finished": finished,
		"player_state": PlayerCombatState.keys()[player_state],
		"enemy_state": EnemyCombatState.keys()[enemy_state],
		"player_cooldown": player_cooldown,
		"enemy_cooldown": enemy_cooldown,
		"player_action_resolving": player_action_resolving,
		"skill_cooldowns": skill_cooldowns.duplicate(true),
		"pill_cooldowns": pill_cooldowns.duplicate(true),
		"pill_group_cooldowns": pill_group_cooldowns.duplicate(true),
		"pending_action": pending_action.duplicate(true),
		"combat_buffs": combat_buffs.duplicate(true),
		"party_combatants": party_combatants.duplicate(true),
		"player_position": _player_position,
		"enemy_position": enemy_position,
		"distance_to_enemy": _distance_to_enemy(),
	}


func combat_stat_bonus(stat_id: String) -> int:
	var value := 0
	for buff in combat_buffs:
		if str(buff.get("stat", "")) == stat_id:
			value += int(buff.get("amount", 0))
	return value


func _combat_total_attack(game_state: GameState) -> int:
	return int(game_state.total_attack()) + combat_stat_bonus("attack")


func _setup_party_combatants(game_state: GameState) -> void:
	party_combatants.clear()
	var members := game_state.party_members()
	for index in range(members.size()):
		var member: Dictionary = members[index]
		var member_id := str(member.get("id", GameState.PLAYER_ID))
		var position := _home_position - Vector2(float(index) * 42.0, 0.0)
		party_combatants.append({
			"member_id": member_id,
			"name": str(member.get("name", "成员")),
			"state": PlayerCombatState.APPROACHING,
			"cooldown": 0.0,
			"skill_cooldowns": {},
			"pill_cooldowns": {},
			"pill_group_cooldowns": {},
			"combat_buffs": [],
			"pending_action": {},
			"position": position,
			"home_position": position,
			"range": float(enemy.get("player_attack_range", DEFAULT_ATTACK_RANGE)),
			"move_speed": float(enemy.get("player_move_speed", DEFAULT_MOVE_STEP)),
		})
	if not party_combatants.is_empty():
		_player_position = party_combatants[0].get("position", _player_position)
		_update_player_state()


func _tick_party_combatants(delta: float, game_state: GameState) -> void:
	for index in range(party_combatants.size()):
		var combatant: Dictionary = party_combatants[index]
		var member_id := str(combatant.get("member_id", GameState.PLAYER_ID))
		var member := game_state.member_by_id(member_id)
		if member.is_empty() or int(member.get("stats", {}).get("hp", 0)) <= 0:
			combatant["state"] = PlayerCombatState.DEFEATED
			party_combatants[index] = combatant
			continue
		_tick_combatant_cooldowns(combatant, delta)
		if int(combatant.get("state", PlayerCombatState.READY)) == PlayerCombatState.RECOVERING:
			combatant["cooldown"] = max(0.0, float(combatant.get("cooldown", 0.0)) - delta)
			if float(combatant.get("cooldown", 0.0)) > 0.0:
				party_combatants[index] = combatant
				continue
		_resolve_combatant_action(index, delta, game_state, member)


func _tick_combatant_cooldowns(combatant: Dictionary, delta: float) -> void:
	for key in ["skill_cooldowns", "pill_cooldowns", "pill_group_cooldowns"]:
		var cooldowns: Dictionary = combatant.get(key, {})
		for id in cooldowns.keys():
			cooldowns[id] = max(0.0, float(cooldowns[id]) - delta)
		combatant[key] = cooldowns


func _resolve_combatant_action(index: int, delta: float, game_state: GameState, member: Dictionary) -> void:
	var combatant: Dictionary = party_combatants[index]
	var member_id := str(combatant.get("member_id", GameState.PLAYER_ID))
	var action: Dictionary = combat_ai.select_player_action(
		game_state,
		float(combatant.get("range", DEFAULT_ATTACK_RANGE)),
		_distance_to_enemy_for(combatant),
		combatant.get("skill_cooldowns", {}),
		combatant.get("pill_cooldowns", {}),
		combatant.get("pill_group_cooldowns", {}),
		member
	)
	if action.is_empty():
		party_combatants[index] = combatant
		return
	var required_distance: float = combat_ai.preferred_player_release_distance(action, float(combatant.get("range", DEFAULT_ATTACK_RANGE)))
	if _distance_to_enemy_for(combatant) > required_distance:
		combatant["state"] = PlayerCombatState.APPROACHING
		_move_combatant_toward_enemy(combatant, delta)
		party_combatants[index] = combatant
		return
	combatant["state"] = PlayerCombatState.ACTING
	player_attack_started.emit(str(action.get("action_type", "")))
	_apply_combatant_action_hit(game_state, member, combatant, action)
	_finish_combatant_turn(combatant, action)
	party_combatants[index] = combatant


func _apply_combatant_action_hit(game_state: GameState, member: Dictionary, combatant: Dictionary, action: Dictionary) -> void:
	if str(action.get("source", "")) == ACTION_SOURCE_SKILL:
		_resolve_combatant_skill_action(game_state, member, combatant, action)
	elif str(action.get("source", "")) == ACTION_SOURCE_PILL:
		_resolve_combatant_pill_action(game_state, member, combatant, action)
	else:
		_resolve_combatant_basic_attack(game_state, member, combatant)


func _resolve_combatant_basic_attack(game_state: GameState, member: Dictionary, combatant: Dictionary) -> void:
	var member_id := str(member.get("id", GameState.PLAYER_ID))
	var damage: int = _member_damage(game_state, member_id, _combatant_total_attack(game_state, combatant))
	_damage_enemy(damage, "physical")
	log_added.emit("%s普通攻击命中%s，造成%d点伤害" % [member.get("name", "成员"), enemy.get("name", "敌人"), damage])


func _resolve_combatant_skill_action(game_state: GameState, member: Dictionary, combatant: Dictionary, action: Dictionary) -> void:
	var skill: Dictionary = DataTables.create_skill(str(action.get("id", "")))
	var member_id := str(member.get("id", GameState.PLAYER_ID))
	var result: Dictionary = skill_resolver.resolve_skill(skill, game_state, {"total_attack": _combatant_total_attack(game_state, combatant), "member_id": member_id})
	if not bool(result.get("success", false)):
		log_added.emit("%s%s" % [member.get("name", "成员"), str(result.get("message", "释放失败"))])
		return
	var skill_id: String = str(result.get("skill_id", skill.get("id", "")))
	var cooldowns: Dictionary = combatant.get("skill_cooldowns", {})
	cooldowns[skill_id] = float(result.get("cooldown", 0.0))
	combatant["skill_cooldowns"] = cooldowns
	_apply_skill_combat_buffs_to_combatant(combatant, result.get("combat_buffs", []), skill_id)
	var raw_damage: int = int(result.get("damage", 0))
	if raw_damage > 0:
		var element_id: String = str(result.get("element", ""))
		var final_damage := _member_damage(game_state, member_id, raw_damage, element_id)
		_damage_enemy(final_damage, _damage_type_from_element(element_id))
	log_added.emit("%s%s" % [member.get("name", "成员"), str(result.get("message", "释放失败"))])


func _resolve_combatant_pill_action(game_state: GameState, member: Dictionary, combatant: Dictionary, action: Dictionary) -> void:
	var member_id := str(member.get("id", GameState.PLAYER_ID))
	var item: Dictionary = game_state.inventory_item_by_instance(str(action.get("id", "")))
	if item.is_empty():
		log_added.emit("丹药不存在")
		return
	var old_hp: int = int(member.get("stats", {}).get("hp", 0))
	if not game_state.use_inventory_item_for_member(str(item.get("instance_id", "")), member_id):
		log_added.emit("%s丹药使用失败" % member.get("name", "成员"))
		return
	var healed: int = int(member.get("stats", {}).get("hp", 0)) - old_hp
	if healed > 0:
		damage_popup_requested.emit(healed, combatant.get("position", _player_position), member_id, "heal", true)
	var item_id := str(item.get("item_id", ""))
	var cooldowns: Dictionary = combatant.get("pill_cooldowns", {})
	cooldowns[item_id] = float(action.get("cooldown", 1.5))
	combatant["pill_cooldowns"] = cooldowns


func _finish_combatant_turn(combatant: Dictionary, action: Dictionary) -> void:
	_update_combatant_buff_turns(combatant)
	combatant["cooldown"] = PLAYER_TURN_WAIT
	if str(action.get("source", "")) == ACTION_SOURCE_PILL:
		combatant["cooldown"] = max(float(combatant.get("cooldown", 0.0)), 1.5)
	combatant["state"] = PlayerCombatState.RECOVERING


func _combatant_total_attack(game_state: GameState, combatant: Dictionary) -> int:
	return int(game_state.total_attack_for(str(combatant.get("member_id", GameState.PLAYER_ID)))) + _combatant_stat_bonus(combatant, "attack")


func _combatant_stat_bonus(combatant: Dictionary, stat_id: String) -> int:
	var value := 0
	for buff in combatant.get("combat_buffs", []):
		if str(buff.get("stat", "")) == stat_id:
			value += int(buff.get("amount", 0))
	return value


func _member_damage(game_state: GameState, member_id: String, base_damage: int, attack_element: String = "") -> int:
	var damage: int = max(1, int(base_damage - enemy["defense"]))
	var element_id: String = attack_element
	if element_id.is_empty():
		element_id = game_state.dominant_element_for(member_id)
	damage += game_state.element_damage_bonus_for(member_id, element_id)
	if element_id == enemy["weak_element"]:
		damage += max(1, int(base_damage * 0.25)) + game_state.total_element_for(member_id, element_id)
	return damage


func _player_damage(game_state: GameState, base_damage: int, attack_element: String = "") -> int:
	var damage: int = max(1, int(base_damage - enemy["defense"]))
	var element_id: String = attack_element
	if element_id.is_empty():
		element_id = game_state.dominant_element()
	damage += game_state.element_damage_bonus(element_id)
	if element_id == enemy["weak_element"]:
		damage += max(1, int(base_damage * 0.25)) + game_state.elements.get(element_id, 0)
	return damage


func _tick_skill_cooldowns(delta: float) -> void:
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = max(0.0, float(skill_cooldowns[skill_id]) - delta)
	for item_id in pill_cooldowns.keys():
		pill_cooldowns[item_id] = max(0.0, float(pill_cooldowns[item_id]) - delta)
	for group_id in pill_group_cooldowns.keys():
		pill_group_cooldowns[group_id] = max(0.0, float(pill_group_cooldowns[group_id]) - delta)


func _update_player_combat_state(delta: float, game_state: GameState) -> void:
	if player_state == PlayerCombatState.ACTING:
		return
	if player_state == PlayerCombatState.RECOVERING:
		player_cooldown = max(0.0, player_cooldown - delta)
		if player_cooldown > 0.0:
			return
	player_state = PlayerCombatState.READY
	_resolve_player_action(delta, game_state)


func _update_enemy_combat_state(delta: float, game_state: GameState) -> void:
	if enemy_state == EnemyCombatState.DEAD:
		return
	if enemy_state == EnemyCombatState.SPAWNING or enemy_state == EnemyCombatState.RECOVERING:
		enemy_cooldown = max(0.0, enemy_cooldown - delta)
		if enemy_cooldown > 0.0:
			return
	var target := _front_alive_combatant(game_state)
	if target.is_empty():
		return
	if _distance_between(target.get("position", _player_position), enemy_position) > enemy_range:
		enemy_state = EnemyCombatState.APPROACHING
		_move_enemy_toward_combatant(target, delta)
		return
	enemy_state = EnemyCombatState.WAITING
	_run_enemy_turn(game_state)


func _check_combat_result(game_state: GameState) -> void:
	if enemy.is_empty():
		return
	if int(enemy.get("hp", 0)) <= 0:
		_finish_victory(game_state)
		return
	if _alive_combatants(game_state).is_empty():
		_finish_defeat(game_state)


func _resolve_player_action(delta: float, game_state: GameState) -> void:
	var action: Dictionary = combat_ai.select_player_action(game_state, player_range, _distance_to_enemy(), skill_cooldowns, pill_cooldowns, pill_group_cooldowns)
	if action.is_empty():
		return
	pending_action = action.duplicate(true)
	var required_distance: float = combat_ai.preferred_player_release_distance(action, player_range)
	if _distance_to_enemy() > required_distance:
		player_state = PlayerCombatState.APPROACHING
		_move_toward_enemy(delta)
		return
	player_state = PlayerCombatState.ACTING
	_execute_pending_action(game_state)


func _execute_pending_action(game_state: GameState) -> void:
	if pending_action.is_empty() or pending_game_state != null and pending_game_state != game_state:
		pending_game_state = game_state
	var action: Dictionary = pending_action.duplicate(true)
	pending_action.clear()
	if action.is_empty():
		return
	var animation_name: String = _animation_name_for_action(action)
	player_attack_started.emit(str(action.get("action_type", "")))
	if not animation_name.is_empty() and animation_player != null and animation_player.has_animation(animation_name):
		animation_action = action.duplicate(true)
		animation_game_state = game_state
		animation_hit_applied = false
		animation_player.play(animation_name)
		return
	_apply_action_hit(game_state, action)
	_finish_player_turn(action)


func apply_queued_animation_hit() -> void:
	if animation_hit_applied or animation_action.is_empty() or animation_game_state == null:
		return
	animation_hit_applied = true
	_apply_action_hit(animation_game_state, animation_action)


func _on_action_animation_finished(_animation_name: StringName) -> void:
	if animation_action.is_empty():
		return
	if not animation_hit_applied:
		apply_queued_animation_hit()
	var action: Dictionary = animation_action.duplicate(true)
	animation_action.clear()
	animation_game_state = null
	animation_hit_applied = false
	_finish_player_turn(action)


func trigger_animation_hit() -> void:
	apply_queued_animation_hit()


func _apply_action_hit(game_state: GameState, action: Dictionary) -> void:
	if str(action.get("source", "")) == ACTION_SOURCE_SKILL:
		_resolve_skill_action(game_state, action)
	elif str(action.get("source", "")) == ACTION_SOURCE_PILL:
		_resolve_pill_action(game_state, action)
	else:
		_resolve_basic_attack(game_state)


func _animation_name_for_action(action: Dictionary) -> String:
	match str(action.get("source", "")):
		ACTION_SOURCE_SKILL:
			return "skill_cast"
		ACTION_SOURCE_BASIC:
			return "normal_attack"
		_:
			return ""


func _resolve_basic_attack(game_state: GameState) -> void:
	var damage: int = _player_damage(game_state, _combat_total_attack(game_state))
	_damage_enemy(damage, "physical")
	log_added.emit("普通攻击命中%s，造成%d点伤害" % [enemy.get("name", "敌人"), damage])


func _resolve_skill_action(game_state: GameState, action: Dictionary) -> void:
	var skill: Dictionary = DataTables.create_skill(str(action.get("id", "")))
	var result: Dictionary = skill_resolver.resolve_skill(skill, game_state, {"total_attack": _combat_total_attack(game_state)})
	if not bool(result.get("success", false)):
		log_added.emit(str(result.get("message", "释放失败")))
		return
	var skill_id: String = str(result.get("skill_id", skill.get("id", "")))
	skill_cooldowns[skill_id] = float(result.get("cooldown", 0.0))
	_apply_skill_combat_buffs_from_defs(result.get("combat_buffs", []), skill_id)
	var raw_damage: int = int(result.get("damage", 0))
	if raw_damage > 0:
		var element_id: String = str(result.get("element", ""))
		var final_damage := _player_damage(game_state, raw_damage, element_id)
		_damage_enemy(final_damage, _damage_type_from_element(element_id))
	log_added.emit(str(result.get("message", "释放失败")))


func _resolve_pill_action(game_state: GameState, action: Dictionary) -> void:
	var item: Dictionary = game_state.inventory_item_by_instance(str(action.get("id", "")))
	if item.is_empty():
		log_added.emit("丹药不存在")
		return
	var old_hp: int = int(game_state.stats.get("hp", 0))
	if not game_state.use_inventory_item(str(item.get("instance_id", ""))):
		log_added.emit("丹药使用失败")
		return
	var healed: int = int(game_state.stats.get("hp", 0)) - old_hp
	if healed > 0:
		damage_popup_requested.emit(healed, _player_position, "player", "heal", true)
	log_added.emit("使用%s" % item.get("name", "丹药"))


func _finish_player_turn(action: Dictionary) -> void:
	_update_combat_buff_turns()
	player_cooldown = PLAYER_TURN_WAIT
	if str(action.get("source", "")) == ACTION_SOURCE_PILL:
		player_cooldown = max(player_cooldown, 1.5)
	player_state = PlayerCombatState.RECOVERING
	player_action_resolving = false
	pending_game_state = null


func _run_enemy_turn(game_state: GameState) -> void:
	if enemy.is_empty():
		return
	var target := _front_alive_combatant(game_state)
	if target.is_empty():
		return
	enemy_state = EnemyCombatState.ACTING
	enemy_attack_started.emit(str(enemy.get("id", "")))
	if current_enemy_node != null:
		current_enemy_node.play_attack_feedback()
	var enemy_action: Dictionary = _select_enemy_action(game_state)
	var element_id: String = str(enemy_action.get("element", ""))
	var target_id := str(target.get("member_id", GameState.PLAYER_ID))
	var raw_damage: int = max(1, int(enemy_action.get("base_damage", enemy.get("attack", 1))) - _combatant_stat_bonus(target, "defense"))
	var final_damage := game_state.take_damage_for(target_id, raw_damage, element_id)
	damage_popup_requested.emit(final_damage, target.get("position", _player_position), target_id, _damage_type_from_element(element_id), false)
	if target_id == GameState.PLAYER_ID:
		player_hit_received.emit(final_damage, _damage_type_from_element(element_id))
	enemy_cooldown = float(enemy.get("turn_wait", ENEMY_TURN_WAIT))
	enemy_state = EnemyCombatState.RECOVERING


func _apply_skill_combat_buffs_from_defs(buff_defs: Array, source_skill_id: String) -> void:
	for buff_def in buff_defs:
		var stat_id: String = str(buff_def.get("stat", ""))
		if stat_id.is_empty():
			continue
		combat_buffs.append({
			"stat": stat_id,
			"amount": int(buff_def.get("amount", 0)),
			"remaining_turns": int(buff_def.get("turns", 1)),
			"source_skill_id": source_skill_id,
			"fresh": true,
		})


func _apply_skill_combat_buffs_to_combatant(combatant: Dictionary, buff_defs: Array, source_skill_id: String) -> void:
	var buffs: Array = combatant.get("combat_buffs", [])
	for buff_def in buff_defs:
		var stat_id: String = str(buff_def.get("stat", ""))
		if stat_id.is_empty():
			continue
		buffs.append({
			"stat": stat_id,
			"amount": int(buff_def.get("amount", 0)),
			"remaining_turns": int(buff_def.get("turns", 1)),
			"source_skill_id": source_skill_id,
			"fresh": true,
		})
	combatant["combat_buffs"] = buffs


func _update_combat_buff_turns() -> void:
	var index: int = 0
	while index < combat_buffs.size():
		var buff: Dictionary = combat_buffs[index]
		if bool(buff.get("fresh", false)):
			buff.erase("fresh")
			combat_buffs[index] = buff
			index += 1
			continue
		buff["remaining_turns"] = int(buff.get("remaining_turns", 0)) - 1
		if int(buff.get("remaining_turns", 0)) <= 0:
			combat_buffs.remove_at(index)
		else:
			combat_buffs[index] = buff
			index += 1


func _update_combatant_buff_turns(combatant: Dictionary) -> void:
	var buffs: Array = combatant.get("combat_buffs", [])
	var index: int = 0
	while index < buffs.size():
		var buff: Dictionary = buffs[index]
		if bool(buff.get("fresh", false)):
			buff.erase("fresh")
			buffs[index] = buff
			index += 1
			continue
		buff["remaining_turns"] = int(buff.get("remaining_turns", 0)) - 1
		if int(buff.get("remaining_turns", 0)) <= 0:
			buffs.remove_at(index)
		else:
			buffs[index] = buff
			index += 1
	combatant["combat_buffs"] = buffs


func _find_skill(skill_id: String, skills: Array) -> Dictionary:
	for skill in skills:
		if str(skill.get("id", "")) == skill_id:
			return skill
	return {}


func _damage_enemy(amount: int, damage_type: String = "physical") -> void:
	var current_hp: int = int(enemy.get("hp", 0))
	enemy["hp"] = max(0, current_hp - amount)
	damage_popup_requested.emit(amount, enemy_position, "enemy", damage_type, false)
	enemy_hit_received.emit(amount, damage_type)
	_play_enemy_hurt_feedback()
	_update_enemy_visual()


func _damage_type_from_element(element_id: String) -> String:
	if element_id.is_empty():
		return "physical"
	return "element_%s" % element_id


func _finish_victory(game_state: GameState) -> void:
	finished = true
	active = false
	player_state = PlayerCombatState.VICTORY
	enemy_state = EnemyCombatState.DEAD
	combat_buffs.clear()
	for combatant in party_combatants:
		combatant["state"] = PlayerCombatState.VICTORY
	game_state.add_exp_to_party(enemy["exp"])
	_resolve_drops(game_state)
	if bool(enemy.get("use_drop", true)) and game_state.rng.randf() > 0.65:
		game_state.add_equipment(DataTables.create_equipment(int(enemy.get("level", game_state.stats["level"])), game_state.rng, game_state.craft_bonus(), "drop"))
	log_added.emit("击败%s" % enemy["name"])
	_update_enemy_visual()


func _resolve_drops(game_state: GameState) -> void:
	if not bool(enemy.get("use_drop", true)):
		return
	var drops: Dictionary = enemy.get("drops", {})
	for item_id in drops.keys():
		var drop_def: Dictionary = drops[item_id]
		if game_state.rng.randf() > float(drop_def.get("chance", 1.0)):
			continue
		var min_amount: int = int(drop_def.get("min", 1))
		var max_amount: int = int(drop_def.get("max", min_amount))
		game_state.gain_resource(item_id, game_state.rng.randi_range(min_amount, max_amount))


func _finish_defeat(game_state: GameState) -> void:
	finished = true
	active = false
	player_state = PlayerCombatState.DEFEATED
	combat_buffs.clear()
	for member in game_state.party_members():
		var member_stats: Dictionary = member.get("stats", {})
		member_stats["hp"] = 1
		member_stats["mp"] = 0
	for combatant in party_combatants:
		combatant["state"] = PlayerCombatState.DEFEATED
	log_added.emit("战斗失败，队伍需要恢复")
	_update_enemy_visual()


func _spawn_enemy_node(enemy_id: String) -> void:
	_clear_enemy_node()
	var scene_path: String = DataTables.enemy_scene_path(enemy_id)
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("敌人场景加载失败: %s" % scene_path)
		return
	var instance: Node = packed_scene.instantiate()
	var enemy_node: BaseEnemy = instance as BaseEnemy
	if enemy_node == null:
		instance.queue_free()
		push_warning("敌人场景缺少 BaseEnemy 接口: %s" % scene_path)
		return
	add_child(enemy_node)
	current_enemy_node = enemy_node
	current_enemy_node.setup(enemy)
	current_enemy_node.set_combat_position(enemy_position)


func _clear_enemy_node() -> void:
	if current_enemy_node != null:
		current_enemy_node.queue_free()
		current_enemy_node = null


func _select_enemy_action(game_state: GameState) -> Dictionary:
	if current_enemy_node != null:
		var node_action: Dictionary = current_enemy_node.select_action(game_state)
		if not node_action.is_empty():
			return node_action
	var element_id: String = ""
	if game_state != null and game_state.rng.randf() < float(enemy.get("element_attack_ratio", 0.0)):
		element_id = str(enemy.get("element", ""))
	return {
		"kind": "basic_attack",
		"base_damage": int(enemy.get("attack", 1)),
		"element": element_id,
	}


func _bind_scene_nodes() -> void:
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player != null:
			var callback: Callable = Callable(self, "_on_action_animation_finished")
			if not animation_player.animation_finished.is_connected(callback):
				animation_player.animation_finished.connect(callback)
			_ensure_animation_hit_tracks()


func _update_enemy_visual() -> void:
	_bind_scene_nodes()
	var should_show: bool = active and not enemy.is_empty()
	if current_enemy_node != null:
		current_enemy_node.visible = should_show
	if not should_show:
		return
	if current_enemy_node != null:
		current_enemy_node.set_combat_position(enemy_position)
		current_enemy_node.sync_data(enemy)


func _set_combat_positions() -> void:
	var map_node: Node = battle_map if battle_map != null else get_parent() as Node
	if map_node != null and map_node.has_method("battle_player_position"):
		_player_position = map_node.call("battle_player_position")
		_home_position = _player_position
	else:
		_player_position = Vector2(736, 170)
		_home_position = Vector2(736, 170)


func _distance_to_enemy() -> float:
	return abs(_player_position.x - enemy_position.x)


func _distance_to_enemy_for(combatant: Dictionary) -> float:
	return _distance_between(combatant.get("position", _player_position), enemy_position)


func _distance_between(a: Vector2, b: Vector2) -> float:
	return abs(a.x - b.x)


func _alive_combatants(game_state: GameState) -> Array:
	var result: Array = []
	for combatant in party_combatants:
		var member_id := str(combatant.get("member_id", GameState.PLAYER_ID))
		var member := game_state.member_by_id(member_id)
		if not member.is_empty() and int(member.get("stats", {}).get("hp", 0)) > 0:
			result.append(combatant)
	return result


func _front_alive_combatant(game_state: GameState) -> Dictionary:
	for combatant in party_combatants:
		var member_id := str(combatant.get("member_id", GameState.PLAYER_ID))
		var member := game_state.member_by_id(member_id)
		if not member.is_empty() and int(member.get("stats", {}).get("hp", 0)) > 0:
			return combatant
	return {}


func _move_toward_enemy(delta: float) -> void:
	var distance: float = player_move_speed * delta
	if _player_position.x < enemy_position.x:
		_player_position.x = minf(enemy_position.x, _player_position.x + distance)
	else:
		_player_position.x = maxf(enemy_position.x, _player_position.x - distance)
	_update_player_state()


func _move_combatant_toward_enemy(combatant: Dictionary, delta: float) -> void:
	var position: Vector2 = combatant.get("position", _player_position)
	var distance: float = float(combatant.get("move_speed", DEFAULT_MOVE_STEP)) * delta
	if position.x < enemy_position.x:
		position.x = minf(enemy_position.x, position.x + distance)
	else:
		position.x = maxf(enemy_position.x, position.x - distance)
	combatant["position"] = position
	if str(combatant.get("member_id", GameState.PLAYER_ID)) == GameState.PLAYER_ID:
		_player_position = position
		_update_player_state()


func _move_enemy_toward_player(delta: float) -> void:
	var distance: float = enemy_move_speed * delta
	if enemy_position.x < _player_position.x:
		enemy_position.x = minf(_player_position.x, enemy_position.x + distance)
	else:
		enemy_position.x = maxf(_player_position.x, enemy_position.x - distance)
	_update_enemy_visual()


func _move_enemy_toward_combatant(combatant: Dictionary, delta: float) -> void:
	var target_position: Vector2 = combatant.get("position", _player_position)
	var distance: float = enemy_move_speed * delta
	if enemy_position.x < target_position.x:
		enemy_position.x = minf(target_position.x, enemy_position.x + distance)
	else:
		enemy_position.x = maxf(target_position.x, enemy_position.x - distance)
	_update_enemy_visual()


func _update_player_state() -> void:
	if battle_map != null and battle_map.has_method("set_player_combat_position"):
		battle_map.call("set_player_combat_position", _player_position)


func _ensure_animation_hit_tracks() -> void:
	_ensure_animation_hit_track("normal_attack", 0.09)
	_ensure_animation_hit_track("skill_cast", 0.12)


func _ensure_animation_hit_track(animation_name: String, hit_time: float) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	var animation: Animation = animation_player.get_animation(animation_name)
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) == Animation.TYPE_METHOD and animation.track_get_path(track_index) == NodePath("."):
			for key_index in range(animation.track_get_key_count(track_index)):
				var key_value: Dictionary = animation.track_get_key_value(track_index, key_index)
				if str(key_value.get("method", "")) == "apply_queued_animation_hit":
					return
	var method_track: int = animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(method_track, NodePath("."))
	animation.track_insert_key(method_track, hit_time, {"method": "apply_queued_animation_hit", "args": []})


func _play_enemy_hurt_feedback() -> void:
	if current_enemy_node != null:
		current_enemy_node.play_hurt_feedback()
		return


func _force_player_hurt_feedback() -> void:
	player_hit_received.emit(0, "physical")
