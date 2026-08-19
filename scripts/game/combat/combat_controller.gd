class_name CombatController
extends Node2D

signal log_added(message: String)
signal damage_popup_requested(amount: int, world_position: Vector2, target_key: String, damage_type: String, is_heal: bool)

const STATE_READY := "READY"
const STATE_APPROACH := "APPROACH"
const STATE_ATTACK := "ATTACK"
const STATE_SKILL := "SKILL"
const STATE_RETURN := "RETURN"
const STATE_RECOVERY := "RECOVERY"
const STATE_DEFEATED := "DEFEATED"
const STATE_VICTORY := "VICTORY"
const PHASE_PARTY := "PARTY"
const PHASE_ENEMY := "ENEMY"
const RESULT_NONE := "none"
const RESULT_VICTORY := "victory"
const RESULT_DEFEAT := "defeat"

const ACTION_SOURCE_SKILL := "skill"
const ACTION_SOURCE_PILL := "pill"
const ACTION_SOURCE_BASIC := "basic"
const CombatSkillExecutorScript = preload("res://scripts/game/combat/combat_skill_executor.gd")
const DEFAULT_ENEMY_POSITION := Vector2(866, 170)
const DEFAULT_PARTY_POSITION := Vector2(736, 170)
const PARTY_FORMATION_SPACING := Vector2(-68, 0)
const POSITION_EPSILON := 2.0
const DEFAULT_MOVE_SPEED := 120.0
const MAX_ENEMY_COUNT := 8

var active := false
var finished := false
var enemy: Dictionary = {}
var enemy_group: Array = []
var enemy_group_index := 0
var party_combatants: Array = []
var party_actor_views: Dictionary = {}
var party_actor_statuses: Dictionary = {}
var current_enemy_node: BaseEnemy = null
var enemy_actor_status: CombatActorStatus = null
var battle_map: Node2D = null
var pending_game_state = null
var combat_ai := CombatAI.new()
var combat_effect_resolver := CombatEffectResolver.new()
var combat_skill_executor = CombatSkillExecutorScript.new()

var _next_action_id := 1
var _resolved_hits: Dictionary = {}
var _marker_reservations: Dictionary = {}
var _turn_phase := PHASE_PARTY
var _party_turn_index := 0
var _round_number := 1
var _enemy_state := STATE_READY
var _enemy_action_id := 0
var _enemy_target_id := ""
var _enemy_pending_action: Dictionary = {}
var _enemy_home_position := DEFAULT_ENEMY_POSITION
var _enemy_death_waiting := false
var _enemy_turn_started := false
var _rewards_granted := false
var _combat_result := RESULT_NONE
var _active_skill_scenes: Dictionary = {}
var _presentation_events: Array = []
var _presentation_timer := 0.0
var _presentation_waiters: Array[Callable] = []
var _presentation_active := false


func set_party_views(views: Dictionary) -> void:
	party_actor_views = views.duplicate()
	for member_id in party_actor_views.keys():
		var actor: Node = party_actor_views.get(member_id)
		if actor == null or not is_instance_valid(actor):
			continue
		var hit_callback := Callable(self, "_on_party_hit_candidate").bind(str(member_id))
		if actor.has_signal("hit_candidate") and not actor.is_connected("hit_candidate", hit_callback):
			actor.connect("hit_candidate", hit_callback)
		var finished_callback := Callable(self, "_on_party_attack_finished").bind(str(member_id))
		if actor.has_signal("attack_finished") and not actor.is_connected("attack_finished", finished_callback):
			actor.connect("attack_finished", finished_callback)


func begin_encounter(game_state, map_node: Node2D = null, enemy_selection = "", enemy_count_override: int = 0) -> void:
	clear()
	pending_game_state = game_state
	battle_map = map_node
	var members: Array = game_state.active_party_members()
	if members.is_empty():
		log_added.emit("需要先招募角色")
		return

	var base_position := DEFAULT_PARTY_POSITION
	if battle_map != null and battle_map.has_method("battle_player_position"):
		base_position = battle_map.call("battle_player_position")
	for index in range(members.size()):
		var member: Dictionary = members[index]
		var member_id: String = str(member.get("id", ""))
		var actor: Node = party_actor_views.get(member_id)
		if actor == null or not is_instance_valid(actor):
			push_warning("参战成员缺少 ActorController: %s" % member_id)
			continue
		var formation := base_position + PARTY_FORMATION_SPACING * float(index)
		actor.call("enter_combat", formation)
		actor.call("set_formation_position", formation)
		var combatant := {
			"member_id": member_id,
			"state": STATE_READY,
			"position": formation,
			"formation_position": formation,
			"move_speed": DEFAULT_MOVE_SPEED,
			"action_id": 0,
			"pending_action": {},
			"skill_cooldowns": {},
			"pill_cooldowns": {},
			"pill_group_cooldowns": {},
			"combat_buffs": [],
			"combat_effects": [],
			"turn_started": false,
		}
		party_combatants.append(combatant)
		var status: CombatActorStatus = actor.call("ensure_combat_status")
		status.set_effect_resolver(combat_effect_resolver)
		status.bind_member(game_state, member_id, combatant, actor)
		_connect_status(status)
		party_actor_statuses[member_id] = status

	if party_combatants.is_empty():
		log_added.emit("当前编队没有可用的战斗形象")
		return

	var enemy_count := clampi(enemy_count_override, 1, MAX_ENEMY_COUNT) if enemy_count_override > 0 else mini(MAX_ENEMY_COUNT, members.size() * 2)
	var encounter_enemy_ids := _normalized_encounter_enemy_ids(enemy_selection, enemy_count)
	if encounter_enemy_ids.is_empty():
		log_added.emit("遭遇配置没有可用敌人")
		return
	for index in range(encounter_enemy_ids.size()):
		var selected_enemy_id: String = encounter_enemy_ids[index]
		var generated_enemy: Dictionary = DataTables.create_enemy(game_state.expedition_level(), game_state.rng, selected_enemy_id)
		generated_enemy["combat_id"] = "enemy_%d" % (index + 1)
		enemy_group.append(generated_enemy)
	enemy_group_index = 0
	enemy = enemy_group[enemy_group_index]
	_spawn_enemy_node(str(enemy.get("id", "")))
	if current_enemy_node == null:
		return
	_enemy_home_position = DEFAULT_ENEMY_POSITION
	current_enemy_node.set_combat_position(_enemy_home_position)
	_turn_phase = PHASE_PARTY
	_party_turn_index = 0
	_round_number = 1
	_enemy_state = STATE_READY
	active = true
	finished = false
	_emit_mod_event(&"combat_started", {
		"enemy_id": str(enemy.get("id", "")),
		"enemy_ids": _enemy_group_ids(),
		"enemy_count": enemy_group.size(),
		"party_member_ids": party_combatants.map(func(value): return str(value.get("member_id", ""))),
	})
	log_added.emit("遭遇%s（共%d只），属性%s" % [enemy.get("name", "敌人"), enemy_group.size(), DataTables.combat_affinity_name(str(enemy.get("combat_affinity", "normal")))])


func _normalized_encounter_enemy_ids(enemy_selection, legacy_enemy_count: int) -> Array[String]:
	var result: Array[String] = []
	if enemy_selection is Array or enemy_selection is PackedStringArray:
		for raw_id in enemy_selection:
			if result.size() >= MAX_ENEMY_COUNT:
				push_warning("遭遇敌人超过上限 %d，额外敌人已忽略" % MAX_ENEMY_COUNT)
				break
			var enemy_id := str(raw_id)
			if not DataTables.content_has("enemy", enemy_id, DataTables.ENEMY_TEMPLATES):
				push_warning("遭遇配置引用了无效敌人：%s" % enemy_id)
				continue
			result.append(enemy_id)
		return result
	var resolved_enemy_id := DataTables.resolve_enemy_id(str(enemy_selection))
	for _index in range(clampi(legacy_enemy_count, 1, MAX_ENEMY_COUNT)):
		result.append(resolved_enemy_id)
	return result


func _enemy_group_ids() -> Array[String]:
	var result: Array[String] = []
	for enemy_data in enemy_group:
		if enemy_data is Dictionary:
			result.append(str(enemy_data.get("id", "")))
	return result


func tick(delta: float, game_state) -> void:
	if not active or finished or _enemy_death_waiting:
		return
	pending_game_state = game_state
	if _presentation_active:
		_tick_presentation(delta)
		return
	if _turn_phase == PHASE_PARTY:
		_tick_current_party_turn(delta, game_state)
	else:
		_tick_enemy(delta)
	_check_combat_result()


func is_finished() -> bool:
	return finished


func combat_result() -> String:
	return _combat_result


func clear() -> void:
	for scene in _active_skill_scenes.values():
		if scene != null and is_instance_valid(scene):
			scene.queue_free()
	_active_skill_scenes.clear()
	_presentation_events.clear()
	_presentation_timer = 0.0
	_presentation_waiters.clear()
	_presentation_active = false
	for combatant in party_combatants:
		var actor := _party_actor(str(combatant.get("member_id", "")))
		if actor != null:
			actor.call("cancel_combat_action")
	if current_enemy_node != null and is_instance_valid(current_enemy_node):
		current_enemy_node.cancel_combat_action()
		current_enemy_node.queue_free()
	current_enemy_node = null
	enemy_actor_status = null
	party_actor_statuses.clear()
	party_combatants.clear()
	enemy_group.clear()
	enemy_group_index = 0
	_marker_reservations.clear()
	_resolved_hits.clear()
	enemy.clear()
	active = false
	finished = false
	_combat_result = RESULT_NONE
	_enemy_death_waiting = false
	_enemy_turn_started = false
	_rewards_granted = false
	_enemy_action_id = 0
	_enemy_target_id = ""
	_enemy_pending_action.clear()
	_turn_phase = PHASE_PARTY
	_party_turn_index = 0
	_round_number = 1
	pending_game_state = null


func combat_status() -> Dictionary:
	return {
		"active": active,
		"finished": finished,
		"result": _combat_result,
		"turn_phase": _turn_phase,
		"round": _round_number,
		"party_turn_index": _party_turn_index,
		"current_member_id": _current_party_member_id(),
		"enemy_state": _enemy_state,
		"party_combatants": party_combatants.duplicate(true),
		"enemy": enemy.duplicate(true),
		"enemy_count": enemy_group.size(),
		"enemy_index": enemy_group_index,
		"enemies": enemy_group.duplicate(true),
		"marker_reservations": _marker_reservations.duplicate(true),
	}


func _tick_current_party_turn(delta: float, game_state) -> void:
	if _party_turn_index < 0 or _party_turn_index >= party_combatants.size():
		_begin_enemy_phase()
		return
	_tick_party_combatant(_party_turn_index, delta, game_state)


func _tick_party_combatant(index: int, delta: float, game_state) -> void:
	var combatant: Dictionary = party_combatants[index]
	var member_id: String = str(combatant.get("member_id", ""))
	var member: Dictionary = game_state.member_by_id(member_id)
	var actor := _party_actor(member_id)
	if member.is_empty() or actor == null:
		_cancel_party_action(combatant, true)
		party_combatants[index] = combatant
		_advance_party_turn()
		return
	if int(member.get("stats", {}).get("hp", 0)) <= 0:
		_cancel_party_action(combatant, true)
		actor.call("play_death_feedback")
		party_combatants[index] = combatant
		_advance_party_turn()
		return

	if not bool(combatant.get("turn_started", false)):
		combatant["turn_started"] = true
		_advance_turn_cooldowns(combatant)
		var status: CombatActorStatus = party_actor_statuses.get(member_id)
		if status != null:
			var turn_events := status.tick_turn_start()
			if _queue_presentation(turn_events):
				party_combatants[index] = combatant
				return
		if not _member_alive(member_id):
			_cancel_party_action(combatant, true)
			actor.call("play_death_feedback")
			party_combatants[index] = combatant
			_advance_party_turn()
			return

	match str(combatant.get("state", STATE_READY)):
		STATE_READY:
			_begin_party_action(combatant, member, game_state)
		STATE_APPROACH:
			_tick_party_approach(combatant, actor, delta)
		STATE_ATTACK:
			pass
		STATE_SKILL:
			pass
		STATE_RETURN:
			_tick_party_return(combatant, actor, delta)
	party_combatants[index] = combatant


func _begin_party_action(combatant: Dictionary, member: Dictionary, game_state) -> void:
	if int(enemy.get("hp", 0)) <= 0:
		return
	var action: Dictionary = combat_ai.select_player_action(
		game_state,
		float(enemy.get("player_attack_range", 96.0)),
		_distance_to_enemy(combatant),
		combatant.get("skill_cooldowns", {}),
		combatant.get("pill_cooldowns", {}),
		combatant.get("pill_group_cooldowns", {}),
		member
	)
	if action.is_empty():
		_finish_party_turn(combatant)
		return
	if str(action.get("source", ACTION_SOURCE_BASIC)) != ACTION_SOURCE_BASIC:
		_resolve_instant_party_action(combatant, member, action, game_state)
		return
	var member_id: String = str(combatant.get("member_id", ""))
	var target_id: String = str(enemy.get("combat_id", "enemy_1"))
	var attack_mode: String = str(action.get("attack_mode", DataTables.ATTACK_MODE_MELEE))
	if attack_mode == DataTables.ATTACK_MODE_MELEE and not _reserve_marker(target_id, member_id):
		return
	var action_id := _allocate_action_id()
	combatant["action_id"] = action_id
	combatant["pending_action"] = action.duplicate(true)
	combatant["state"] = STATE_APPROACH
	_resolved_hits[action_id] = {}


func _tick_party_approach(combatant: Dictionary, actor: Node, delta: float) -> void:
	if current_enemy_node == null or int(enemy.get("hp", 0)) <= 0:
		combatant["state"] = STATE_RETURN
		return
	var action: Dictionary = combatant.get("pending_action", {})
	var attack_mode: String = str(action.get("attack_mode", DataTables.ATTACK_MODE_MELEE))
	var target_position := current_enemy_node.melee_approach_position()
	var reached := false
	if attack_mode == DataTables.ATTACK_MODE_RANGED:
		var basic_attack_range: float = float(action.get("range", enemy.get("player_attack_range", 96.0)))
		reached = _distance_to_enemy(combatant) <= basic_attack_range
		if not reached:
			target_position = _ranged_approach_position(combatant, basic_attack_range)
			reached = _move_actor_toward(combatant, actor, target_position, delta)
	else:
		reached = _move_actor_toward(combatant, actor, target_position, delta)
	if reached:
		combatant["state"] = STATE_ATTACK
		var visual_action: String = "ranged_attack" if attack_mode == DataTables.ATTACK_MODE_RANGED else "melee_attack"
		actor.call("play_combat_action", visual_action, int(combatant.get("action_id", 0)))


func _tick_party_return(combatant: Dictionary, actor: Node, delta: float) -> void:
	var formation: Vector2 = combatant.get("formation_position", Vector2.ZERO)
	if not _move_actor_toward(combatant, actor, formation, delta):
		return
	_release_markers_for(str(combatant.get("member_id", "")))
	_finish_party_turn(combatant)


func _finish_party_turn(combatant: Dictionary) -> void:
	var member_id: String = str(combatant.get("member_id", ""))
	var status: CombatActorStatus = party_actor_statuses.get(member_id)
	if status != null:
		var turn_events := status.tick_turn_end()
		if _queue_presentation(turn_events, Callable(self, "_complete_party_turn").bind(member_id)):
			return
	_complete_party_turn(member_id)


func _complete_party_turn(member_id: String) -> void:
	var index := _combatant_index(member_id)
	if index < 0:
		return
	var combatant: Dictionary = party_combatants[index]
	_resolved_hits.erase(int(combatant.get("action_id", 0)))
	combatant["action_id"] = 0
	combatant["pending_action"] = {}
	combatant["state"] = STATE_RECOVERY
	combatant["turn_started"] = false
	party_combatants[index] = combatant
	_advance_party_turn()


func _resolve_instant_party_action(combatant: Dictionary, member: Dictionary, action: Dictionary, game_state) -> void:
	var source := str(action.get("source", ""))
	if source == ACTION_SOURCE_SKILL:
		_resolve_party_skill(combatant, member, action, game_state)
		return
	elif source == ACTION_SOURCE_PILL:
		_resolve_party_pill(combatant, member, action, game_state)
	_finish_party_turn(combatant)


func _resolve_party_skill(combatant: Dictionary, member: Dictionary, action: Dictionary, game_state) -> void:
	var skill: Dictionary = DataTables.create_skill(str(action.get("id", "")))
	if skill.is_empty():
		return
	var member_id: String = str(member.get("id", ""))
	var caster: CombatActorStatus = party_actor_statuses.get(member_id)
	var targets: Array = _skill_targets(caster, skill)
	var scene := _create_skill_scene(skill)
	if scene == null:
		log_added.emit("%s释放%s失败" % [member.get("name", "成员"), skill.get("name", "技能")])
		_finish_party_turn(combatant)
		return
	var mp_cost := int(skill.get("mp_cost", 0))
	if caster == null or not caster.spend_mp(mp_cost):
		scene.queue_free()
		log_added.emit("%s法力不足" % member.get("name", "成员"))
		return
	var skill_id := str(skill.get("id", ""))
	combatant["pending_action"] = action.duplicate(true)
	combatant["state"] = STATE_SKILL
	_active_skill_scenes[member_id] = scene
	scene.combat_events_emitted.connect(_on_skill_combat_events)
	scene.finished.connect(_on_party_skill_finished.bind(member_id, skill_id), CONNECT_ONE_SHOT)
	log_added.emit("%s释放%s" % [member.get("name", "成员"), skill.get("name", "技能")])
	scene.start_cast(_skill_cast_context(caster, targets, skill, game_state.rng))


func _on_party_skill_finished(result: Dictionary, member_id: String, skill_id: String) -> void:
	var scene: SkillSceneBase = _active_skill_scenes.get(member_id) as SkillSceneBase
	_active_skill_scenes.erase(member_id)
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	var index := _combatant_index(member_id)
	if index < 0:
		return
	var combatant: Dictionary = party_combatants[index]
	var cooldowns: Dictionary = combatant.get("skill_cooldowns", {})
	var skill: Dictionary = DataTables.create_skill(skill_id)
	if bool(result.get("cast_succeeded", false)):
		cooldowns[skill_id] = _cooldown_turns(int(skill.get("cooldown", 0)), float(result.get("cooldown_multiplier", 1.0)))
	else:
		var caster: CombatActorStatus = party_actor_statuses.get(member_id)
		if caster != null:
			caster.refund_mp(int(skill.get("mp_cost", 0)))
		log_added.emit("%s配置无效，施法已中止" % skill.get("name", "技能"))
	combatant["skill_cooldowns"] = cooldowns
	party_combatants[index] = combatant
	if _wait_for_presentation(Callable(self, "_complete_party_skill_turn").bind(member_id)):
		return
	_complete_party_skill_turn(member_id)


func _complete_party_skill_turn(member_id: String) -> void:
	var index := _combatant_index(member_id)
	if index < 0:
		return
	var combatant: Dictionary = party_combatants[index]
	_check_combat_result()
	if not active or finished or _enemy_death_waiting:
		return
	if _turn_phase != PHASE_PARTY or _current_party_member_id() != member_id:
		return
	_finish_party_turn(combatant)
	party_combatants[index] = combatant


func _resolve_party_pill(combatant: Dictionary, member: Dictionary, action: Dictionary, game_state) -> void:
	var instance_id := str(action.get("id", ""))
	var item: Dictionary = game_state.inventory_item_by_instance(instance_id)
	if item.is_empty() or not game_state.use_inventory_item_for_member(instance_id, str(member.get("id", ""))):
		return
	var cooldowns: Dictionary = combatant.get("pill_cooldowns", {})
	cooldowns[str(item.get("item_id", ""))] = int(action.get("cooldown", 2))
	combatant["pill_cooldowns"] = cooldowns
	var group_id := str(action.get("cooldown_group", ""))
	if not group_id.is_empty():
		var groups: Dictionary = combatant.get("pill_group_cooldowns", {})
		groups[group_id] = int(action.get("cooldown", 2))
		combatant["pill_group_cooldowns"] = groups


func _tick_enemy(delta: float) -> void:
	if current_enemy_node == null or enemy_actor_status == null or int(enemy.get("hp", 0)) <= 0:
		return
	match _enemy_state:
		STATE_READY:
			_begin_enemy_action()
		STATE_APPROACH:
			_tick_enemy_approach(delta)
		STATE_ATTACK:
			pass
		STATE_SKILL:
			pass
		STATE_RETURN:
			_tick_enemy_return(delta)


func _begin_enemy_action() -> void:
	if not _enemy_turn_started:
		_enemy_turn_started = true
		var turn_events := enemy_actor_status.tick_turn_start()
		if _queue_presentation(turn_events):
			return
	if not enemy_actor_status.is_alive():
		_check_combat_result()
		return
	var target_id := _first_alive_party_member_id()
	if target_id.is_empty():
		_check_combat_result()
		return
	if not _reserve_marker(target_id, str(enemy.get("combat_id", "enemy_1"))):
		return
	var enemy_cooldowns: Dictionary = enemy.get("skill_cooldowns", {})
	for skill_id in enemy_cooldowns.keys():
		enemy_cooldowns[skill_id] = maxi(0, int(enemy_cooldowns[skill_id]) - 1)
	enemy["skill_cooldowns"] = enemy_cooldowns
	_enemy_target_id = target_id
	var target_status: CombatActorStatus = party_actor_statuses.get(target_id)
	_enemy_pending_action = current_enemy_node.select_action(pending_game_state, target_status)
	_enemy_action_id = _allocate_action_id()
	_resolved_hits[_enemy_action_id] = {}
	_enemy_state = STATE_APPROACH


func _tick_enemy_approach(delta: float) -> void:
	var target := _party_actor(_enemy_target_id)
	if target == null or not _member_alive(_enemy_target_id):
		_enemy_state = STATE_RETURN
		return
	var target_position: Vector2 = target.call("melee_approach_position")
	if _move_enemy_toward(target_position, delta):
		if _enemy_action_is_skill():
			_start_enemy_skill()
		else:
			_enemy_state = STATE_ATTACK
			current_enemy_node.play_attack_feedback(_enemy_action_id)


func _tick_enemy_return(delta: float) -> void:
	if not _move_enemy_toward(_enemy_home_position, delta):
		return
	_release_markers_for(str(enemy.get("combat_id", "enemy_1")))
	_resolved_hits.erase(_enemy_action_id)
	_enemy_action_id = 0
	_enemy_target_id = ""
	var turn_events := enemy_actor_status.tick_turn_end()
	if _queue_presentation(turn_events, Callable(self, "_complete_enemy_return")):
		return
	_complete_enemy_return()


func _complete_enemy_return() -> void:
	_enemy_turn_started = false
	_begin_next_round()


func _on_party_hit_candidate(action_id: int, target_id: String, member_id: String) -> void:
	if not active or _enemy_death_waiting or _turn_phase != PHASE_PARTY or member_id != _current_party_member_id():
		return
	var index := _combatant_index(member_id)
	if index < 0:
		return
	var combatant: Dictionary = party_combatants[index]
	if str(combatant.get("state", "")) != STATE_ATTACK or int(combatant.get("action_id", 0)) != action_id:
		return
	if target_id != str(enemy.get("combat_id", "enemy_1")) or not _claim_hit(action_id, target_id):
		return
	var caster: CombatActorStatus = party_actor_statuses.get(member_id)
	if caster == null or enemy_actor_status == null:
		return
	_resolve_party_basic_attack(combatant, caster)


func _on_party_attack_finished(action_id: int, member_id: String) -> void:
	if _turn_phase != PHASE_PARTY or member_id != _current_party_member_id():
		return
	var index := _combatant_index(member_id)
	if index < 0:
		return
	var combatant: Dictionary = party_combatants[index]
	if int(combatant.get("action_id", 0)) != action_id:
		return
	var action: Dictionary = combatant.get("pending_action", {})
	if str(action.get("attack_mode", DataTables.ATTACK_MODE_MELEE)) == DataTables.ATTACK_MODE_RANGED:
		var target_id: String = str(enemy.get("combat_id", "enemy_1"))
		if _claim_hit(action_id, target_id):
			var caster: CombatActorStatus = party_actor_statuses.get(member_id)
			if caster != null and enemy_actor_status != null:
				_resolve_party_basic_attack(combatant, caster)
	combatant["state"] = STATE_RETURN
	party_combatants[index] = combatant


func _on_enemy_hit_candidate(action_id: int, target_id: String) -> void:
	if not active or _turn_phase != PHASE_ENEMY or _enemy_state != STATE_ATTACK or action_id != _enemy_action_id or not _claim_hit(action_id, target_id):
		return
	var target: CombatActorStatus = party_actor_statuses.get(target_id)
	if target == null or not target.is_alive():
		return
	var action := _enemy_pending_action
	var skill: Dictionary = _basic_attack_skill(int(action.get("base_damage", enemy.get("attack", 1))))
	var targets := _skill_targets(enemy_actor_status, skill, target)
	var result := combat_skill_executor.execute(enemy_actor_status, targets, skill, combat_effect_resolver, pending_game_state.rng)
	log_added.emit("%s攻击%s，造成%d点伤害%s" % [enemy.get("name", "敌人"), target.actor_name, int(result.get("damage", 0)), _affinity_result_suffix(result)])
	_check_combat_result()


func _on_enemy_attack_finished(action_id: int) -> void:
	if _turn_phase == PHASE_ENEMY and action_id == _enemy_action_id:
		_enemy_state = STATE_RETURN


func _on_actor_defeated(actor_id: String) -> void:
	if actor_id == str(enemy.get("combat_id", "enemy_1")):
		_start_enemy_death()
		return
	var index := _combatant_index(actor_id)
	if index < 0:
		return
	var combatant: Dictionary = party_combatants[index]
	_cancel_party_action(combatant, true)
	party_combatants[index] = combatant
	var actor := _party_actor(actor_id)
	if actor != null:
		actor.call("play_death_feedback")
	if _enemy_target_id == actor_id:
		current_enemy_node.cancel_combat_action()
		_enemy_state = STATE_RETURN


func _start_enemy_death() -> void:
	if _enemy_death_waiting:
		return
	_enemy_death_waiting = true
	for index in range(party_combatants.size()):
		var combatant: Dictionary = party_combatants[index]
		if str(combatant.get("state", "")) != STATE_DEFEATED:
			var actor := _party_actor(str(combatant.get("member_id", "")))
			if actor != null:
				actor.call("cancel_combat_action")
			combatant["state"] = STATE_RECOVERY
		party_combatants[index] = combatant
	_marker_reservations.clear()
	if current_enemy_node != null:
		current_enemy_node.cancel_combat_action()
		current_enemy_node.play_death_feedback()
	else:
		_on_enemy_death_finished()


func _on_enemy_death_finished() -> void:
	if not _enemy_death_waiting:
		return
	_grant_victory_rewards()
	if enemy_group_index + 1 < enemy_group.size():
		_advance_enemy_group()
		return
	var reward_eligible := true
	for defeated_enemy in enemy_group:
		if bool(defeated_enemy.get("is_training_dummy", false)):
			reward_eligible = false
			break
	if pending_game_state.has_method("register_full_encounter_victory"):
		pending_game_state.call("register_full_encounter_victory", reward_eligible)
	_combat_result = RESULT_VICTORY
	_emit_mod_event(&"combat_finished", {
		"result": RESULT_VICTORY,
		"enemy_id": str(enemy.get("id", "")),
		"enemy_ids": _enemy_group_ids(),
	})
	_enemy_death_waiting = false
	active = false
	finished = true
	for combatant in party_combatants:
		if str(combatant.get("state", "")) != STATE_DEFEATED:
			combatant["state"] = STATE_VICTORY


func _advance_enemy_group() -> void:
	if current_enemy_node != null and is_instance_valid(current_enemy_node):
		current_enemy_node.queue_free()
	current_enemy_node = null
	enemy_actor_status = null
	enemy_group_index += 1
	enemy = enemy_group[enemy_group_index]
	_spawn_enemy_node(str(enemy.get("id", DataTables.DEFAULT_ENEMY_ID)))
	if current_enemy_node == null:
		_combat_result = RESULT_DEFEAT
		_emit_mod_event(&"combat_finished", {
			"result": RESULT_DEFEAT,
			"enemy_id": str(enemy.get("id", "")),
			"enemy_ids": _enemy_group_ids(),
		})
		active = false
		finished = true
		_enemy_death_waiting = false
		return
	current_enemy_node.set_combat_position(_enemy_home_position)
	_turn_phase = PHASE_PARTY
	_party_turn_index = 0
	_round_number = 1
	_enemy_state = STATE_READY
	_enemy_action_id = 0
	_enemy_target_id = ""
	_enemy_pending_action.clear()
	_enemy_turn_started = false
	_enemy_death_waiting = false
	_rewards_granted = false
	log_added.emit("下一只%s进入战斗，属性%s（剩余 %d）" % [enemy.get("name", "敌人"), DataTables.combat_affinity_name(str(enemy.get("combat_affinity", "normal"))), enemy_group.size() - enemy_group_index])


func _grant_victory_rewards() -> void:
	if _rewards_granted or pending_game_state == null:
		return
	_rewards_granted = true
	var exp_amount := int(enemy.get("exp", 0))
	pending_game_state.add_expedition_exp(exp_amount)
	for combatant in party_combatants:
		pending_game_state.add_exp_for_member(str(combatant.get("member_id", "")), exp_amount)
	_resolve_drops(pending_game_state)
	if str(enemy.get("enemy_class", enemy.get("encounter_class", "normal"))) == DataTables.ENEMY_CLASS_BOSS:
		var boss_tier := DataTables.EQUIPMENT_RARITY_ORDER.find(str(enemy.get("rank", "t1"))) + 1
		pending_game_state.add_inventory_item(DataTables.ITEM_ID_ASCENSION_STONE, maxi(1, boss_tier), false)
		log_added.emit("Boss掉落升阶石 x%d" % maxi(1, boss_tier))
	if bool(enemy.get("use_drop", true)) and pending_game_state.rng.randf() < float(enemy.get("equipment_drop_chance", 0.0)):
		var rarity_weights: Dictionary = enemy.get("drop_profile", {}).get("rarity_weights", {})
		pending_game_state.add_equipment(DataTables.create_equipment(int(enemy.get("level", pending_game_state.expedition_level())), pending_game_state.rng, pending_game_state.craft_bonus(), "drop", rarity_weights))
	log_added.emit("击败%s，账号历练 +%d" % [enemy.get("name", "敌人"), exp_amount])


func _resolve_drops(game_state) -> void:
	if not bool(enemy.get("use_drop", true)):
		return
	var awarded_item_ids: Dictionary = {}
	_resolve_explicit_drops(game_state, awarded_item_ids)
	if bool(enemy.get("use_class_drop_pool", false)):
		_resolve_class_drops(game_state, awarded_item_ids)
	if bool(enemy.get("use_rank_drop_pool", true)):
		_resolve_rank_drop(game_state, awarded_item_ids)


func _resolve_explicit_drops(game_state, awarded_item_ids: Dictionary) -> void:
	var explicit_drops = enemy.get("drops", {})
	if not (explicit_drops is Dictionary):
		return
	for item_id in explicit_drops.keys():
		var drop_def: Dictionary = explicit_drops.get(item_id, {})
		if game_state.rng.randf() > clampf(float(drop_def.get("chance", 0.0)), 0.0, 1.0):
			continue
		var low := maxi(1, int(drop_def.get("min", 1)))
		var high := maxi(low, int(drop_def.get("max", low)))
		_award_unique_drop(game_state, awarded_item_ids, str(item_id), game_state.rng.randi_range(low, high))


func _resolve_class_drops(game_state, awarded_item_ids: Dictionary) -> void:
	var profile = enemy.get("class_drop_profile", {})
	if not (profile is Dictionary):
		return
	var entries = profile.get("entries", [])
	if not (entries is Array) or entries.is_empty():
		return
	match str(profile.get("mode", "")):
		"independent":
			for entry_value in entries:
				if not (entry_value is Dictionary):
					continue
				var entry: Dictionary = entry_value
				if game_state.rng.randf() > clampf(float(entry.get("chance", 0.0)), 0.0, 1.0):
					continue
				_award_unique_drop(game_state, awarded_item_ids, str(entry.get("item_id", "")), int(entry.get("amount", 1)))
		"weighted_one":
			_resolve_weighted_class_drop(game_state, awarded_item_ids, entries)


func _resolve_weighted_class_drop(game_state, awarded_item_ids: Dictionary, entries: Array) -> void:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var item_id := str(entry.get("item_id", ""))
		var weight := float(entry.get("weight", 0.0))
		if item_id.is_empty() or weight <= 0.0 or DataTables.item_definition(item_id).is_empty():
			continue
		candidates.append(entry)
		total_weight += weight
	if candidates.is_empty() or total_weight <= 0.0:
		return
	var roll: float = float(game_state.rng.randf()) * total_weight
	var cursor := 0.0
	for index in range(candidates.size()):
		var entry: Dictionary = candidates[index]
		cursor += float(entry.get("weight", 0.0))
		if roll < cursor or index == candidates.size() - 1:
			_award_unique_drop(game_state, awarded_item_ids, str(entry.get("item_id", "")), int(entry.get("amount", 1)))
			return


func _resolve_rank_drop(game_state, awarded_item_ids: Dictionary) -> void:
	var profile: Dictionary = enemy.get("drop_profile", {})
	var items: Array = profile.get("items", []) if profile.get("items", []) is Array else []
	if items.is_empty():
		return
	var rank_level := int(enemy.get("rank_level", 1))
	var level_steps := mini(3, floori(float(rank_level - 1) / 5.0))
	var chance := clampf(float(profile.get("base_chance", 0.0)) + 0.05 * float(level_steps), 0.0, 1.0)
	if game_state.rng.randf() > chance:
		return
	var rarity := _roll_drop_rarity(profile.get("rarity_weights", {}), game_state.rng)
	var matching: Array = []
	for item_id in items:
		var resolved_id := str(item_id)
		if DataTables.item_definition(resolved_id).is_empty():
			continue
		if DataTables.item_drop_rarity(resolved_id) == rarity:
			matching.append(resolved_id)
	if matching.is_empty():
		for item_id in items:
			if not DataTables.item_definition(str(item_id)).is_empty():
				matching.append(str(item_id))
	if matching.is_empty():
		return
	var selected_id: String = str(matching[game_state.rng.randi_range(0, matching.size() - 1)])
	_award_unique_drop(game_state, awarded_item_ids, selected_id, 1)


func _award_unique_drop(game_state, awarded_item_ids: Dictionary, item_id: String, amount: int) -> bool:
	if item_id.is_empty() or amount <= 0 or awarded_item_ids.has(item_id):
		return false
	if DataTables.item_definition(item_id).is_empty():
		return false
	game_state.gain_resource(item_id, amount)
	awarded_item_ids[item_id] = true
	return true


func _roll_drop_rarity(weights, rng: RandomNumberGenerator) -> String:
	var total := 0
	if weights is Dictionary:
		for rarity in DataTables.EQUIPMENT_RARITY_ORDER:
			total += maxi(0, int(weights.get(rarity, 0)))
	if total <= 0:
		return "t1"
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for rarity in DataTables.EQUIPMENT_RARITY_ORDER:
		cursor += maxi(0, int(weights.get(rarity, 0)))
		if roll <= cursor:
			return str(rarity)
	return "t1"


func _check_combat_result() -> void:
	if int(enemy.get("hp", 0)) <= 0:
		_start_enemy_death()
		return
	if _first_alive_party_member_id().is_empty():
		if current_enemy_node != null:
			current_enemy_node.cancel_combat_action()
		active = false
		finished = true
		_combat_result = RESULT_DEFEAT
		_emit_mod_event(&"combat_finished", {
			"result": RESULT_DEFEAT,
			"enemy_id": str(enemy.get("id", "")),
			"enemy_ids": _enemy_group_ids(),
		})
		log_added.emit("队伍全灭")


func _spawn_enemy_node(enemy_id: String) -> void:
	var scene_path := DataTables.enemy_scene_path(enemy_id)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("敌人模板加载失败: %s" % scene_path)
		return
	current_enemy_node = packed.instantiate() as BaseEnemy
	if current_enemy_node == null:
		push_error("敌人模板根节点必须继承 BaseEnemy: %s" % scene_path)
		return
	add_child(current_enemy_node)
	current_enemy_node.setup(enemy)
	current_enemy_node.hit_candidate.connect(_on_enemy_hit_candidate)
	current_enemy_node.attack_finished.connect(_on_enemy_attack_finished)
	current_enemy_node.death_finished.connect(_on_enemy_death_finished)
	enemy_actor_status = current_enemy_node.ensure_combat_status()
	enemy_actor_status.set_effect_resolver(combat_effect_resolver)
	enemy_actor_status.bind_enemy(enemy, current_enemy_node)
	_connect_status(enemy_actor_status)


func _emit_mod_event(event_id: StringName, payload: Dictionary) -> void:
	var api := get_node_or_null("/root/ModAPI")
	if api != null:
		api.emit_event(event_id, payload)


func _connect_status(status: CombatActorStatus) -> void:
	if not status.combat_popup_requested.is_connected(_on_combat_popup_requested):
		status.combat_popup_requested.connect(_on_combat_popup_requested)
	if not status.defeated.is_connected(_on_actor_defeated):
		status.defeated.connect(_on_actor_defeated)


func _on_combat_popup_requested(amount: int, world_position: Vector2, target_key: String, damage_type: String, is_heal: bool) -> void:
	damage_popup_requested.emit(amount, world_position, target_key, damage_type, is_heal)


func _basic_attack_skill(base_damage: int) -> Dictionary:
	var attack: Dictionary = DataTables.create_basic_attack(DataTables.ATTACK_MODE_MELEE, base_damage)
	return attack


func _resolve_party_basic_attack(combatant: Dictionary, caster: CombatActorStatus) -> void:
	var action: Dictionary = combatant.get("pending_action", {})
	var attack_mode: String = str(action.get("attack_mode", DataTables.ATTACK_MODE_MELEE))
	var attack: Dictionary = DataTables.create_basic_attack(attack_mode, caster.total_stat("attack"))
	var result := combat_skill_executor.execute(caster, [enemy_actor_status], attack, combat_effect_resolver, pending_game_state.rng)
	log_added.emit("%s使用%s命中%s，造成%d点伤害%s" % [
		caster.actor_name,
		attack.get("name", "普通攻击"),
		enemy.get("name", "敌人"),
		int(result.get("damage", 0)),
		_affinity_result_suffix(result),
	])
	_check_combat_result()


func _create_skill_scene(skill: Dictionary) -> SkillSceneBase:
	if skill.is_empty():
		return null
	var api := get_node_or_null("/root/ModAPI")
	var packed: PackedScene = api.skill_scene(str(skill.get("id", ""))) if api != null else null
	if packed == null:
		push_warning("技能场景未注册: %s" % skill.get("id", ""))
		return null
	var scene := packed.instantiate() as SkillSceneBase
	if scene == null:
		return null
	add_child(scene)
	return scene


func _skill_cast_context(caster: CombatActorStatus, targets: Array, skill: Dictionary, rng: RandomNumberGenerator) -> SkillCastContext:
	return SkillCastContext.create(caster, targets, _skill_candidates(caster, skill), skill, combat_effect_resolver, rng)


func _skill_candidates(caster: CombatActorStatus, skill: Dictionary) -> Array:
	var scope := str(skill.get("target_scope", "single_enemy"))
	if scope == "self":
		return [caster]
	var targets_allies := scope in ["single_ally", "all_allies"]
	var caster_is_party := caster != null and caster.actor_kind == CombatActorStatus.KIND_MEMBER
	var wants_party := caster_is_party == targets_allies
	if wants_party:
		var result: Array = []
		for combatant in party_combatants:
			var status: CombatActorStatus = party_actor_statuses.get(str(combatant.get("member_id", "")))
			if status != null and status.is_alive():
				result.append(status)
		return result
	return [enemy_actor_status] if enemy_actor_status != null and enemy_actor_status.is_alive() else []


func _enemy_action_is_skill() -> bool:
	return not _enemy_pending_action.is_empty() and DataTables.content_has("skill", str(_enemy_pending_action.get("id", "")), DataTables.SKILL_DEFS)


func _start_enemy_skill() -> void:
	var skill := _enemy_pending_action
	var preferred: CombatActorStatus = party_actor_statuses.get(_enemy_target_id)
	var targets := _skill_targets(enemy_actor_status, skill, preferred)
	var scene := _create_skill_scene(skill)
	if scene == null:
		log_added.emit("%s释放%s失败" % [enemy.get("name", "敌人"), skill.get("name", "技能")])
		_enemy_state = STATE_RETURN
		return
	var scene_key := enemy_actor_status.actor_id
	_active_skill_scenes[scene_key] = scene
	_enemy_state = STATE_SKILL
	scene.combat_events_emitted.connect(_on_skill_combat_events)
	scene.finished.connect(_on_enemy_skill_finished.bind(scene_key, str(skill.get("id", ""))), CONNECT_ONE_SHOT)
	log_added.emit("%s释放%s" % [enemy.get("name", "敌人"), skill.get("name", "技能")])
	scene.start_cast(_skill_cast_context(enemy_actor_status, targets, skill, pending_game_state.rng))


func _on_enemy_skill_finished(result: Dictionary, scene_key: String, skill_id: String) -> void:
	var scene: SkillSceneBase = _active_skill_scenes.get(scene_key) as SkillSceneBase
	_active_skill_scenes.erase(scene_key)
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	if not bool(result.get("cast_succeeded", false)):
		var cooldowns: Dictionary = enemy.get("skill_cooldowns", {})
		cooldowns[skill_id] = 0
		enemy["skill_cooldowns"] = cooldowns
	if _wait_for_presentation(Callable(self, "_complete_enemy_skill")):
		return
	_complete_enemy_skill()


func _complete_enemy_skill() -> void:
	_check_combat_result()
	if active and not finished and not _enemy_death_waiting:
		_enemy_state = STATE_RETURN


func _on_skill_combat_events(events: Array) -> void:
	for event in events:
		if not (event is Dictionary) or str(event.get("type", "")) != "damage":
			continue
		var source: Dictionary = event.get("source", {})
		if str(source.get("source", "")) == "dot":
			continue
		var relation := str(source.get("affinity_relation", DataTables.AFFINITY_RELATION_NEUTRAL))
		if relation != DataTables.AFFINITY_RELATION_NEUTRAL:
			log_added.emit("%s受到%d点伤害%s" % [str(event.get("actor_name", "目标")), int(event.get("amount", 0)), _affinity_relation_suffix(relation)])
	_queue_presentation(events)


func _queue_presentation(events: Array, done: Callable = Callable()) -> bool:
	var queued := false
	for event in events:
		if not (event is Dictionary):
			continue
		if str(event.get("type", "")) == "status_tick" and str(event.get("affinity_relation", DataTables.AFFINITY_RELATION_NEUTRAL)) != DataTables.AFFINITY_RELATION_NEUTRAL:
			log_added.emit("持续伤害%d%s" % [int(event.get("amount", 0)), _affinity_relation_suffix(str(event.get("affinity_relation", "")))])
		if str(event.get("type", "")) in ["status_added", "status_refreshed", "status_stacked", "status_tick", "shield_absorbed", "status_removed"]:
			_presentation_events.append(event.duplicate(true))
			queued = true
	if done.is_valid() and (queued or _presentation_active):
		_presentation_waiters.append(done)
	if queued and not _presentation_active:
		_presentation_active = true
		_start_next_presentation_event()
	return queued or _presentation_active


func _affinity_result_suffix(result: Dictionary) -> String:
	var suffix := "（暴击）" if bool(result.get("critical", false)) else ""
	for target_result in result.get("target_results", []):
		if target_result is Dictionary:
			var relation := str(target_result.get("affinity_relation", DataTables.AFFINITY_RELATION_NEUTRAL))
			if relation != DataTables.AFFINITY_RELATION_NEUTRAL:
				suffix += _affinity_relation_suffix(relation)
				break
	return suffix


func _affinity_relation_suffix(relation: String) -> String:
	match relation:
		DataTables.AFFINITY_RELATION_OVERCOME:
			return "（克制）"
		DataTables.AFFINITY_RELATION_RESTRAINED:
			return "（被克）"
		_:
			return ""


func _wait_for_presentation(done: Callable) -> bool:
	if not _presentation_active and _presentation_events.is_empty():
		return false
	if done.is_valid():
		_presentation_waiters.append(done)
	return true


func _tick_presentation(delta: float) -> void:
	_presentation_timer = maxf(0.0, _presentation_timer - maxf(0.0, delta))
	if _presentation_timer <= 0.0:
		_start_next_presentation_event()


func _start_next_presentation_event() -> void:
	if _presentation_events.is_empty():
		_presentation_active = false
		var waiters := _presentation_waiters.duplicate()
		_presentation_waiters.clear()
		for done in waiters:
			if done.is_valid():
				done.call()
		return
	var event: Dictionary = _presentation_events.pop_front()
	var actor_id := str(event.get("actor_id", ""))
	var event_owner: Node = current_enemy_node if enemy_actor_status != null and actor_id == enemy_actor_status.actor_id else _party_actor(actor_id)
	var duration := 0.08
	if event_owner != null and event_owner.has_method("present_combat_event"):
		duration = maxf(duration, float(event_owner.call("present_combat_event", event)))
	_presentation_timer = duration


func _skill_targets(caster: CombatActorStatus, skill: Dictionary, preferred_target: CombatActorStatus = null) -> Array:
	if caster == null:
		return []
	var allies: Array = _alive_party_statuses() if caster.actor_kind == CombatActorStatus.KIND_MEMBER else [enemy_actor_status]
	var opponents: Array = [enemy_actor_status] if caster.actor_kind == CombatActorStatus.KIND_MEMBER else _alive_party_statuses()
	allies = allies.filter(func(status): return status is CombatActorStatus and status.is_alive())
	opponents = opponents.filter(func(status): return status is CombatActorStatus and status.is_alive())
	match DataTables.skill_target_scope(skill):
		DataTables.SKILL_TARGET_SELF:
			return [caster]
		DataTables.SKILL_TARGET_SINGLE_ALLY:
			return [_preferred_target(preferred_target, allies, caster)]
		DataTables.SKILL_TARGET_ALL_ALLIES:
			return allies
		DataTables.SKILL_TARGET_ALL_ENEMIES:
			return opponents
		_:
			var fallback = opponents[0] if not opponents.is_empty() else null
			return [_preferred_target(preferred_target, opponents, fallback)] if fallback != null else []


func _preferred_target(preferred_target: CombatActorStatus, candidates: Array, fallback: CombatActorStatus) -> CombatActorStatus:
	if preferred_target != null and candidates.has(preferred_target) and preferred_target.is_alive():
		return preferred_target
	return fallback


func _alive_party_statuses() -> Array:
	var result: Array = []
	for combatant in party_combatants:
		var member_id: String = str(combatant.get("member_id", ""))
		var status: CombatActorStatus = party_actor_statuses.get(member_id)
		if status != null and status.is_alive():
			result.append(status)
	return result


func _move_actor_toward(combatant: Dictionary, actor: Node, target: Vector2, delta: float) -> bool:
	var current_position: Vector2 = combatant.get("position", actor.call("combat_position"))
	var speed := float(combatant.get("move_speed", DEFAULT_MOVE_SPEED))
	current_position = current_position.move_toward(target, speed * delta)
	combatant["position"] = current_position
	actor.call("set_combat_position", current_position)
	return current_position.distance_to(target) <= POSITION_EPSILON


func _ranged_approach_position(combatant: Dictionary, basic_attack_range: float) -> Vector2:
	var enemy_position: Vector2 = current_enemy_node.combat_position()
	var actor_position: Vector2 = combatant.get("position", Vector2.ZERO)
	var direction: Vector2 = actor_position.direction_to(enemy_position) * -1.0
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT
	return enemy_position + direction * max(0.0, basic_attack_range)


func _move_enemy_toward(target: Vector2, delta: float) -> bool:
	if current_enemy_node == null:
		return false
	var current_position := current_enemy_node.combat_position()
	current_position = current_position.move_toward(target, float(enemy.get("move_speed", DEFAULT_MOVE_SPEED)) * delta)
	current_enemy_node.set_combat_position(current_position)
	current_enemy_node.play_run()
	return current_position.distance_to(target) <= POSITION_EPSILON


func _advance_turn_cooldowns(combatant: Dictionary) -> void:
	for key in ["skill_cooldowns", "pill_cooldowns", "pill_group_cooldowns"]:
		var values: Dictionary = combatant.get(key, {})
		for id in values.keys():
			values[id] = maxi(0, int(values[id]) - 1)
		combatant[key] = values


func _cooldown_turns(base_turns: int, multiplier: float = 1.0) -> int:
	return maxi(0, ceili(float(maxi(0, base_turns)) * maxf(0.0, multiplier)))


func _advance_party_turn() -> void:
	_party_turn_index += 1
	while _party_turn_index < party_combatants.size():
		var combatant: Dictionary = party_combatants[_party_turn_index]
		var member_id := str(combatant.get("member_id", ""))
		if _member_alive(member_id):
			combatant["state"] = STATE_READY
			combatant["turn_started"] = false
			party_combatants[_party_turn_index] = combatant
			return
		combatant["state"] = STATE_DEFEATED
		combatant["turn_started"] = false
		party_combatants[_party_turn_index] = combatant
		_party_turn_index += 1
	_begin_enemy_phase()


func _begin_enemy_phase() -> void:
	_turn_phase = PHASE_ENEMY
	_enemy_state = STATE_READY
	_enemy_action_id = 0
	_enemy_target_id = ""


func _begin_next_round() -> void:
	_round_number += 1
	_turn_phase = PHASE_PARTY
	_party_turn_index = 0
	_marker_reservations.clear()
	for index in range(party_combatants.size()):
		var combatant: Dictionary = party_combatants[index]
		var member_id := str(combatant.get("member_id", ""))
		combatant["turn_started"] = false
		combatant["state"] = STATE_READY if _member_alive(member_id) else STATE_DEFEATED
		party_combatants[index] = combatant
	while _party_turn_index < party_combatants.size() and not _member_alive(str(party_combatants[_party_turn_index].get("member_id", ""))):
		_party_turn_index += 1
	if _party_turn_index >= party_combatants.size():
		_check_combat_result()


func _current_party_member_id() -> String:
	if _turn_phase != PHASE_PARTY or _party_turn_index < 0 or _party_turn_index >= party_combatants.size():
		return ""
	return str(party_combatants[_party_turn_index].get("member_id", ""))


func _reserve_marker(target_id: String, attacker_id: String) -> bool:
	var reservation_owner := str(_marker_reservations.get(target_id, ""))
	if not reservation_owner.is_empty() and reservation_owner != attacker_id:
		return false
	_marker_reservations[target_id] = attacker_id
	return true


func _release_markers_for(attacker_id: String) -> void:
	for target_id in _marker_reservations.keys().duplicate():
		if str(_marker_reservations.get(target_id, "")) == attacker_id:
			_marker_reservations.erase(target_id)


func _claim_hit(action_id: int, target_id: String) -> bool:
	var hits: Dictionary = _resolved_hits.get(action_id, {})
	if hits.has(target_id):
		return false
	hits[target_id] = true
	_resolved_hits[action_id] = hits
	return true


func _cancel_party_action(combatant: Dictionary, defeated: bool) -> void:
	var member_id := str(combatant.get("member_id", ""))
	var skill_scene: SkillSceneBase = _active_skill_scenes.get(member_id) as SkillSceneBase
	_active_skill_scenes.erase(member_id)
	if skill_scene != null and is_instance_valid(skill_scene):
		skill_scene.queue_free()
	var actor := _party_actor(member_id)
	if actor != null:
		actor.call("cancel_combat_action")
	_release_markers_for(member_id)
	_resolved_hits.erase(int(combatant.get("action_id", 0)))
	combatant["action_id"] = 0
	combatant["pending_action"] = {}
	combatant["state"] = STATE_DEFEATED if defeated else STATE_RETURN


func _allocate_action_id() -> int:
	var result := _next_action_id
	_next_action_id += 1
	if _next_action_id <= 0:
		_next_action_id = 1
	return result


func _combatant_index(member_id: String) -> int:
	for index in range(party_combatants.size()):
		if str(party_combatants[index].get("member_id", "")) == member_id:
			return index
	return -1


func _party_actor(member_id: String) -> Node:
	var actor: Node = party_actor_views.get(member_id)
	return actor if actor != null and is_instance_valid(actor) else null


func _member_alive(member_id: String) -> bool:
	var status: CombatActorStatus = party_actor_statuses.get(member_id)
	return status != null and status.is_alive()


func _first_alive_party_member_id() -> String:
	for combatant in party_combatants:
		var member_id := str(combatant.get("member_id", ""))
		if _member_alive(member_id):
			return member_id
	return ""


func _distance_to_enemy(combatant: Dictionary) -> float:
	if current_enemy_node == null:
		return INF
	var combatant_position: Vector2 = combatant.get("position", Vector2.ZERO)
	return combatant_position.distance_to(current_enemy_node.combat_position())
