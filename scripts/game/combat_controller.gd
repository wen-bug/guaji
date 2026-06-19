class_name CombatController
extends Node2D

signal log_added(message: String)
signal damage_feedback(payload: Dictionary)

const PLAYER_MODE_AUTO := "auto"
const PLAYER_MODE_MANUAL := "manual"
const PLAYER_ACTION_ATTACK := "attack"
const PLAYER_ACTION_DEFEND := "defend"
const PLAYER_ACTION_SKILL := "skill"
const PLAYER_TURN_WAIT := 1.1
const ENEMY_TURN_WAIT := 1.4
const DEFEND_DAMAGE_MULTIPLIER := 0.5
const SkillResolverScript = preload("res://scripts/game/skill_resolver.gd")

var active := false
var finished := false
var enemy := {}
var attack_timer := 0.0
var enemy_timer := 0.0
var skill_cooldowns := {}
var combat_buffs := []
var player_mode := PLAYER_MODE_AUTO
var pending_player_mode := ""
var player_turn_ready := false
var player_action_resolving := false
var defending := false
var enemy_position := Vector2(866, 126)
var enemy_visual: Node2D
var hp_fill: ColorRect
var animation_player: AnimationPlayer
var skill_resolver := SkillResolverScript.new()
var pending_player_action := {}
var pending_game_state = null


func _ready() -> void:
	_bind_scene_nodes()
	_update_enemy_visual()


func begin_encounter(game_state) -> void:
	_bind_scene_nodes()
	enemy = DataTables.create_enemy(game_state.stats["level"], game_state.rng)
	active = true
	finished = false
	attack_timer = 0.0
	enemy_timer = 0.8
	player_mode = PLAYER_MODE_AUTO
	pending_player_mode = ""
	player_turn_ready = false
	player_action_resolving = false
	defending = false
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

	if attack_timer <= 0.0 and not player_action_resolving:
		if player_mode == PLAYER_MODE_AUTO:
			_run_auto_player_turn(game_state)
		else:
			player_turn_ready = true

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
	pending_player_mode = ""
	player_turn_ready = false
	player_action_resolving = false
	defending = false
	pending_player_action.clear()
	pending_game_state = null
	combat_buffs.clear()
	_update_enemy_visual()


func request_toggle_player_mode() -> void:
	if not active or finished:
		return
	var target_mode := PLAYER_MODE_MANUAL if player_mode == PLAYER_MODE_AUTO else PLAYER_MODE_AUTO
	if player_action_resolving:
		pending_player_mode = target_mode
		return
	_set_player_mode(target_mode)


func request_player_action(action_id: String, skill_id: String, game_state) -> bool:
	if not can_use_player_action(action_id, skill_id, game_state):
		return false
	_start_player_action(action_id, skill_id, game_state)
	return true


func can_use_player_action(action_id: String, skill_id: String, game_state) -> bool:
	if not active or finished or player_mode != PLAYER_MODE_MANUAL or not player_turn_ready or player_action_resolving:
		return false
	if action_id == PLAYER_ACTION_ATTACK or action_id == PLAYER_ACTION_DEFEND:
		return true
	if action_id != PLAYER_ACTION_SKILL:
		return false
	var skill := _find_skill(skill_id, game_state.skills)
	if skill.is_empty():
		return false
	if float(skill_cooldowns.get(skill_id, 0.0)) > 0.0:
		return false
	return int(game_state.stats.get("mp", 0)) >= int(skill["mp_cost"])


func combat_status() -> Dictionary:
	return {
		"active": active,
		"finished": finished,
		"player_mode": player_mode,
		"pending_player_mode": pending_player_mode,
		"player_turn_ready": player_turn_ready,
		"player_action_resolving": player_action_resolving,
		"skill_cooldowns": skill_cooldowns.duplicate(true),
		"combat_buffs": combat_buffs.duplicate(true),
		"defending": defending,
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
	if skill.is_empty():
		_start_player_action(PLAYER_ACTION_ATTACK, "", game_state)
	else:
		_start_player_action(PLAYER_ACTION_SKILL, str(skill.get("id", "")), game_state)



func _start_player_action(action_id: String, skill_id: String, game_state) -> void:
	player_action_resolving = true
	player_turn_ready = false
	pending_game_state = game_state
	pending_player_action = {
		"action_id": action_id,
		"skill_id": skill_id,
	}
	_play_player_action_animation(action_id)


func _play_player_action_animation(action_id: String) -> void:
	_bind_scene_nodes()
	var animation_name := "skill_cast" if action_id == PLAYER_ACTION_SKILL else "normal_attack"
	if action_id == PLAYER_ACTION_DEFEND:
		animation_name = "defend"
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
	elif action_id == PLAYER_ACTION_DEFEND:
		defending = true
		log_added.emit("????")
	elif action_id == PLAYER_ACTION_SKILL:
		_resolve_skill_action(game_state, _find_skill(skill_id, game_state.skills))

	_finish_player_turn()
	if active and not enemy.is_empty() and enemy["hp"] <= 0:
		_finish_victory(game_state)


func _resolve_normal_attack(game_state) -> void:
	var damage := _player_damage(game_state, _combat_total_attack(game_state))
	_damage_enemy(damage)
	_emit_damage_feedback({
		"action_id": PLAYER_ACTION_ATTACK,
		"skill_id": "",
		"skill_name": "",
		"damage": damage,
		"message": "????",
	})
	log_added.emit("????")


func _resolve_skill_action(game_state, skill: Dictionary) -> void:
	var result: Dictionary = skill_resolver.resolve_skill(skill, game_state, {"total_attack": _combat_total_attack(game_state)})
	if not bool(result.get("success", false)):
		log_added.emit(str(result.get("message", "????")))
		return
	var skill_id := str(result.get("skill_id", skill.get("id", "")))
	skill_cooldowns[skill_id] = float(result.get("cooldown", 0.0))
	_apply_skill_combat_buffs_from_defs(result.get("combat_buffs", []), skill_id)
	var final_damage := 0
	var raw_damage := int(result.get("damage", 0))
	if raw_damage > 0:
		final_damage = _player_damage(game_state, raw_damage, str(result.get("element", "")))
		_damage_enemy(final_damage)
	_emit_damage_feedback({
		"action_id": PLAYER_ACTION_SKILL,
		"skill_id": skill_id,
		"skill_name": str(result.get("skill_name", skill.get("name", ""))),
		"damage": final_damage,
		"message": str(result.get("message", "????")),
	})
	log_added.emit(str(result.get("message", "????")))


func _emit_damage_feedback(payload: Dictionary) -> void:
	damage_feedback.emit(payload.duplicate(true))


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
	if not pending_player_mode.is_empty():
		_set_player_mode(pending_player_mode)
		pending_player_mode = ""


func _set_player_mode(next_mode: String) -> void:
	if next_mode != PLAYER_MODE_AUTO and next_mode != PLAYER_MODE_MANUAL:
		return
	player_mode = next_mode
	pending_player_mode = ""
	player_turn_ready = false
	if player_mode == PLAYER_MODE_MANUAL:
		attack_timer = max(attack_timer, 0.05)
	log_added.emit("切换为%s模式" % ("自动" if player_mode == PLAYER_MODE_AUTO else "手动"))


func _run_enemy_turn(game_state) -> void:
	enemy_timer = ENEMY_TURN_WAIT
	var damage_to_player: int = int(enemy["attack"])
	if defending:
		damage_to_player = max(1, int(ceil(float(damage_to_player) * DEFEND_DAMAGE_MULTIPLIER)))
		defending = false
	damage_to_player = max(1, damage_to_player - combat_stat_bonus("defense"))
	var element_id := ""
	if game_state.rng.randf() < float(enemy.get("element_attack_ratio", 0.0)):
		element_id = enemy.get("element", "")
	game_state.take_damage(damage_to_player, element_id)


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
		game_state.add_equipment(DataTables.create_equipment(int(enemy.get("level", game_state.stats["level"])), game_state.rng, game_state.craft_bonus()))
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
