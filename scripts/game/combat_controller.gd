class_name CombatController
extends Node2D

signal log_added(message: String)

const PLAYER_ACTION_ATTACK := "attack"
const PLAYER_ACTION_SKILL := "skill"
const PLAYER_TURN_WAIT := 1.1
const ENEMY_TURN_WAIT := 1.4
const DEFAULT_ATTACK_RANGE := 96.0
const DEFAULT_ENEMY_ATTACK_RANGE := 88.0
const DEFAULT_MOVE_STEP := 120.0
const DEFAULT_RETREAT_DISTANCE := 72.0
const SkillResolverScript = preload("res://scripts/game/skill_resolver.gd")

var active := false
var finished := false
var enemy := {}
var attack_timer := 0.0
var enemy_timer := 0.0
var skill_cooldowns := {}
var combat_buffs := []
var player_action_resolving := false
var enemy_position := Vector2(866, 126)
var enemy_visual: Node2D
var hp_fill: ColorRect
var animation_player: AnimationPlayer
var skill_resolver := SkillResolverScript.new()
var pending_player_action := {}
var pending_game_state = null
var battle_map: Node2D = null
var player_range := DEFAULT_ATTACK_RANGE
var enemy_range := DEFAULT_ENEMY_ATTACK_RANGE
var player_move_speed := DEFAULT_MOVE_STEP
var player_retreat_distance := DEFAULT_RETREAT_DISTANCE
var _player_position := Vector2.ZERO
var _home_position := Vector2.ZERO
var _player_action_step := 0.0


func _ready() -> void:
	_bind_scene_nodes()
	_update_enemy_visual()


func begin_encounter(game_state, map_node: Node2D = null) -> void:
	_bind_scene_nodes()
	battle_map = map_node if map_node != null else battle_map
	if battle_map == null:
		battle_map = get_parent() as Node2D
	_set_combat_positions()
	enemy = DataTables.create_enemy(game_state.stats["level"], game_state.rng)
	active = true
	finished = false
	attack_timer = 0.0
	enemy_timer = 0.8
	player_action_resolving = false
	pending_player_action.clear()
	pending_game_state = null
	skill_cooldowns.clear()
	combat_buffs.clear()
	log_added.emit("遭遇%s，弱%s" % [enemy["name"], DataTables.element_name(enemy["weak_element"])])
	_update_enemy_visual()


func tick(delta: float, game_state) -> void:
	if not active or finished:
		return

	attack_timer -= delta
	enemy_timer -= delta
	_tick_skill_cooldowns(delta)
	_update_player_movement(delta)

	if attack_timer <= 0.0 and not player_action_resolving:
		_run_auto_player_turn(game_state)

	if enemy["hp"] <= 0:
		_finish_victory(game_state)
		return

	if enemy_timer <= 0.0:
		_run_enemy_turn(game_state)
		if game_state.stats["hp"] <= 0:
			_finish_defeat(game_state)

	_update_enemy_visual()


func is_finished() -> bool:
	return finished


func clear() -> void:
	active = false
	finished = false
	enemy = {}
	player_action_resolving = false
	pending_player_action.clear()
	pending_game_state = null
	combat_buffs.clear()
	battle_map = null
	_update_enemy_visual()


func combat_status() -> Dictionary:
	return {
		"active": active,
		"finished": finished,
		"player_action_resolving": player_action_resolving,
		"skill_cooldowns": skill_cooldowns.duplicate(true),
		"combat_buffs": combat_buffs.duplicate(true),
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


func _combat_total_attack(game_state) -> int:
	return game_state.total_attack() + combat_stat_bonus("attack")


func _player_damage(game_state, base_damage: int, attack_element := "") -> int:
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


func _run_auto_player_turn(game_state) -> void:
	var skill := _first_available_skill(game_state)
	if not skill.is_empty() and _distance_to_enemy() > _skill_release_distance(skill):
		_move_toward_enemy()
		return
	if skill.is_empty() or _distance_to_enemy() > _skill_release_distance(skill):
		if _distance_to_enemy() > player_range:
			_move_toward_enemy()
			return
		_start_player_action(PLAYER_ACTION_ATTACK, "", game_state)
	else:
		_start_player_action(PLAYER_ACTION_SKILL, str(skill.get("id", "")), game_state)


func _start_player_action(action_id: String, skill_id: String, game_state) -> void:
	player_action_resolving = true
	pending_game_state = game_state
	pending_player_action = {
		"action_id": action_id,
		"skill_id": skill_id,
	}
	_play_player_action_animation(action_id)


func _play_player_action_animation(action_id: String) -> void:
	_bind_scene_nodes()
	var animation_name := "skill_cast" if action_id == PLAYER_ACTION_SKILL else "normal_attack"
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
	else:
		call_deferred("_complete_pending_player_action")


func _on_action_animation_finished(_animation_name: StringName) -> void:
	_complete_pending_player_action()


func _complete_pending_player_action() -> void:
	if pending_player_action.is_empty() or pending_game_state == null:
		return
	var game_state = pending_game_state
	var action_id := str(pending_player_action.get("action_id", ""))
	var skill_id := str(pending_player_action.get("skill_id", ""))
	pending_player_action.clear()
	pending_game_state = null

	if action_id == PLAYER_ACTION_ATTACK:
		_resolve_normal_attack(game_state)
	elif action_id == PLAYER_ACTION_SKILL:
		_resolve_skill_action(game_state, _find_skill(skill_id, game_state.skills))

	_finish_player_turn()
	if active and not enemy.is_empty() and enemy["hp"] <= 0:
		_finish_victory(game_state)


func _resolve_normal_attack(game_state) -> void:
	var damage := _player_damage(game_state, _combat_total_attack(game_state))
	_damage_enemy(damage)
	log_added.emit("普通攻击命中%s，造成%d点伤害" % [enemy.get("name", "敌人"), damage])


func _resolve_skill_action(game_state, skill: Dictionary) -> void:
	var result: Dictionary = skill_resolver.resolve_skill(skill, game_state, {"total_attack": _combat_total_attack(game_state)})
	if not bool(result.get("success", false)):
		log_added.emit(str(result.get("message", "释放失败")))
		return
	var skill_id := str(result.get("skill_id", skill.get("id", "")))
	skill_cooldowns[skill_id] = float(result.get("cooldown", 0.0))
	_apply_skill_combat_buffs_from_defs(result.get("combat_buffs", []), skill_id)
	var final_damage := 0
	var raw_damage := int(result.get("damage", 0))
	if raw_damage > 0:
		final_damage = _player_damage(game_state, raw_damage, str(result.get("element", "")))
		_damage_enemy(final_damage)
	log_added.emit(str(result.get("message", "释放失败")))


func _first_available_skill(game_state) -> Dictionary:
	if game_state.skills.is_empty():
		return {}
	for skill in game_state.skills:
		var skill_id: String = skill["id"]
		if float(skill_cooldowns.get(skill_id, 0.0)) > 0.0:
			continue
		if int(game_state.stats.get("mp", 0)) < int(skill["mp_cost"]):
			continue
		return skill
	return {}


func _finish_player_turn() -> void:
	_update_combat_buff_turns()
	attack_timer = PLAYER_TURN_WAIT
	player_action_resolving = false


func _run_enemy_turn(game_state) -> void:
	enemy_timer = ENEMY_TURN_WAIT
	var damage_to_player: int = int(enemy["attack"])
	damage_to_player = max(1, damage_to_player - combat_stat_bonus("defense"))
	var element_id := ""
	if game_state.rng.randf() < float(enemy.get("element_attack_ratio", 0.0)):
		element_id = enemy.get("element", "")
	game_state.take_damage(damage_to_player, element_id)
	if _distance_to_enemy() > enemy_range:
		_move_away_from_enemy()


func _apply_skill_combat_buffs_from_defs(buff_defs: Array, source_skill_id: String) -> void:
	for buff_def in buff_defs:
		var stat_id := str(buff_def.get("stat", ""))
		if stat_id.is_empty():
			continue
		combat_buffs.append({
			"stat": stat_id,
			"amount": int(buff_def.get("amount", 0)),
			"remaining_turns": int(buff_def.get("turns", 1)),
			"source_skill_id": source_skill_id,
			"fresh": true,
		})


func _update_combat_buff_turns() -> void:
	var index := 0
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


func _find_skill(skill_id: String, skills: Array) -> Dictionary:
	for skill in skills:
		if str(skill.get("id", "")) == skill_id:
			return skill
	return {}


func _damage_enemy(amount: int) -> void:
	enemy["hp"] = max(0, enemy["hp"] - amount)
	_update_enemy_visual()


func _finish_victory(game_state) -> void:
	finished = true
	active = false
	combat_buffs.clear()
	game_state.add_exp(enemy["exp"])
	_resolve_drops(game_state)
	if game_state.rng.randf() > 0.65:
		game_state.add_equipment(DataTables.create_equipment(int(enemy.get("level", game_state.stats["level"])), game_state.rng, game_state.craft_bonus(), "drop"))
	log_added.emit("击败%s" % enemy["name"])
	_update_enemy_visual()


func _resolve_drops(game_state) -> void:
	var drops: Dictionary = enemy.get("drops", {})
	for item_id in drops.keys():
		var drop_def: Dictionary = drops[item_id]
		if game_state.rng.randf() > float(drop_def.get("chance", 1.0)):
			continue
		var min_amount := int(drop_def.get("min", 1))
		var max_amount := int(drop_def.get("max", min_amount))
		game_state.gain_resource(item_id, game_state.rng.randi_range(min_amount, max_amount))


func _finish_defeat(game_state) -> void:
	finished = true
	active = false
	combat_buffs.clear()
	game_state.stats["hp"] = 1
	game_state.stats["mp"] = 0
	log_added.emit("战斗失败，需要打坐恢复")
	_update_enemy_visual()


func _bind_scene_nodes() -> void:
	if enemy_visual == null:
		enemy_visual = $EnemyVisual
	if hp_fill == null:
		hp_fill = $EnemyVisual/HPBack/HPFill
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player != null:
			var callback := Callable(self, "_on_action_animation_finished")
			if not animation_player.animation_finished.is_connected(callback):
				animation_player.animation_finished.connect(callback)


func _update_enemy_visual() -> void:
	_bind_scene_nodes()
	var should_show := active and not enemy.is_empty()
	enemy_visual.visible = should_show
	if not should_show:
		return
	enemy_visual.position = enemy_position
	var ratio: float = clamp(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)
	hp_fill.size.x = 48.0 * ratio


func _set_combat_positions() -> void:
	var map_node := battle_map if battle_map != null else get_parent()
	if map_node != null and map_node.has_method("battle_player_position"):
		_player_position = map_node.call("battle_player_position")
		_home_position = _player_position
	return
	_player_position = Vector2(736, 170)
	_home_position = Vector2(736, 170)


func _distance_to_enemy() -> float:
	return abs(_player_position.x - enemy_position.x)


func _skill_release_distance(skill: Dictionary) -> float:
	return max(player_range, float(skill.get("release_distance", player_range)))


func _move_toward_enemy() -> void:
	if _player_position.x < enemy_position.x:
		_player_position.x = minf(enemy_position.x, _player_position.x + player_move_speed * 0.016)
	else:
		_player_position.x = maxf(enemy_position.x, _player_position.x - player_move_speed * 0.016)
	_update_player_state()


func _move_away_from_enemy() -> void:
	var target_x := _home_position.x
	if _player_position.x < target_x:
		_player_position.x = minf(target_x, _player_position.x + player_move_speed * 0.016)
	else:
		_player_position.x = maxf(target_x, _player_position.x - player_move_speed * 0.016)
	_update_player_state()


func _update_player_movement(delta: float) -> void:
	if not active or finished:
		return
	if _distance_to_enemy() > player_range and not player_action_resolving:
		_move_toward_enemy()
	elif _distance_to_enemy() <= player_range and not player_action_resolving:
		_player_action_step = max(0.0, _player_action_step - delta)
	_update_player_state()


func _update_player_state() -> void:
	if battle_map != null and battle_map.has_method("set_player_combat_position"):
		battle_map.call("set_player_combat_position", _player_position)
