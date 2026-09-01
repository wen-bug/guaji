class_name CombatController
extends Node2D

signal log_added(message: String)
signal damage_popup_requested(amount: int, world_position: Vector2, target_key: String, damage_type: String, is_heal: bool)

const STATE_READY := "READY"
const STATE_APPROACH := "APPROACH"
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
const DEFAULT_ENEMY_POSITION := Vector2(866, 170)
const DEFAULT_PARTY_POSITION := Vector2(736, 170)
const PARTY_FORMATION_SPACING := Vector2(-68, 0)
const POSITION_EPSILON := 2.0
const DEFAULT_MOVE_SPEED := 120.0
const MAX_ENEMY_COUNT := 8
const MAX_CONCURRENT_ENEMIES := 4
const ENEMY_FORMATION_SPACING := Vector2(68, 0)
const VIEWPORT_SAFE_MARGIN := 48.0

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
var enemy_combatants: Array = []
var enemy_waiting_queue: Array = []
var battle_map: Node2D = null
var pending_game_state = null
var combat_ai := CombatAI.new()
var combat_effect_resolver := CombatEffectResolver.new()
var skill_scene_registry := SkillSceneRegistry.new()
var _skill_scene_registry_ready := false

var _turn_phase := PHASE_PARTY
var _party_turn_index := 0
var _round_number := 1
var _next_action_id := 1
var _enemy_state := STATE_READY
var _enemy_target_id := ""
var _enemy_pending_action: Dictionary = {}
var _enemy_home_position := DEFAULT_ENEMY_POSITION
var _enemy_death_waiting := false
var _enemy_turn_started := false
var _enemy_turn_order: Array[String] = []
var _enemy_turn_index := 0
var _rewards_granted := false
var _combat_result := RESULT_NONE
var _active_skill_scenes: Dictionary = {}
var _presentation_events: Array = []
var _presentation_timer := 0.0
var _presentation_waiters: Array[Callable] = []
var _presentation_active := false


func set_party_views(views: Dictionary) -> void:
	party_actor_views = views.duplicate()


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
			"auto_item_checked": false,
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
	# Reposition the party now that the simultaneous enemy count is known.
	base_position = _party_front_position(party_combatants.size(), mini(MAX_CONCURRENT_ENEMIES, enemy_group.size()))
	for index in range(party_combatants.size()):
		var formation: Vector2 = base_position + PARTY_FORMATION_SPACING * float(index)
		party_combatants[index]["position"] = formation
		party_combatants[index]["formation_position"] = formation
		var actor := _party_actor(str(party_combatants[index].get("member_id", "")))
		if actor != null:
			actor.call("enter_combat", formation)
			actor.call("set_formation_position", formation)
	for generated in enemy_group:
		enemy_waiting_queue.append(generated)
	_refill_enemy_slots()
	_sync_front_enemy_aliases()
	if enemy_combatants.is_empty():
		return
	_turn_phase = PHASE_PARTY
	_party_turn_index = 0
	_round_number = 1
	_enemy_state = STATE_READY
	active = true
	finished = false
	log_added.emit("遭遇%s（共%d只，%d只同场），属性%s" % [enemy.get("name", "敌人"), enemy_group.size(), enemy_combatants.size(), DataTables.combat_affinity_name(str(enemy.get("combat_affinity", "normal")))])


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
	if not active or finished:
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
	for enemy_combatant in enemy_combatants:
		var node: BaseEnemy = enemy_combatant.get("node") as BaseEnemy
		if node != null and is_instance_valid(node):
			node.cancel_combat_action()
			node.queue_free()
	current_enemy_node = null
	enemy_actor_status = null
	enemy_combatants.clear()
	enemy_waiting_queue.clear()
	party_actor_statuses.clear()
	party_combatants.clear()
	enemy_group.clear()
	enemy_group_index = 0
	enemy.clear()
	active = false
	finished = false
	_combat_result = RESULT_NONE
	_enemy_death_waiting = false
	_enemy_turn_started = false
	_enemy_turn_order.clear()
	_enemy_turn_index = 0
	_rewards_granted = false
	_next_action_id = 1
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
		"current_enemy_combat_id": str(enemy.get("combat_id", "")),
		"enemy_turn_index": _enemy_turn_index,
		"party_combatants": party_combatants.duplicate(true),
		"enemy": enemy.duplicate(true),
		"enemy_count": enemy_group.size(),
		"enemy_index": enemy_group_index,
		"enemies": enemy_group.duplicate(true),
		"active_enemies": _enemy_combatant_snapshots(),
		"waiting_enemies": enemy_waiting_queue.duplicate(true),
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
	_try_auto_item_for_turn(combatant, member, game_state)

	match str(combatant.get("state", STATE_READY)):
		STATE_READY:
			_begin_party_action(combatant, member, game_state)
		STATE_APPROACH:
			_tick_party_approach(combatant, actor, member, game_state, delta)
		STATE_SKILL:
			pass
		STATE_RETURN:
			_tick_party_return(combatant, actor, delta)
	party_combatants[index] = combatant


func _begin_party_action(combatant: Dictionary, member: Dictionary, game_state) -> void:
	_sync_front_enemy_aliases()
	if enemy_actor_status == null or not enemy_actor_status.is_alive():
		return
	var context := _combat_ai_context(party_actor_statuses.get(str(member.get("id", ""))))
	var action: Dictionary = combat_ai.select_player_action(
		game_state,
		float(enemy.get("player_attack_range", 96.0)),
		_distance_to_enemy(combatant),
		combatant.get("skill_cooldowns", {}),
		combatant.get("pill_cooldowns", {}),
		combatant.get("pill_group_cooldowns", {}),
		member,
		context
	)
	if action.is_empty():
		_finish_party_turn(combatant)
		return
	_resolve_instant_party_action(combatant, member, action, game_state)


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
	combatant["action_id"] = 0
	combatant["pending_action"] = {}
	combatant["pending_skill"] = {}
	combatant["attack_mode"] = ""
	combatant["approach_target_id"] = ""
	combatant["state"] = STATE_RECOVERY
	combatant["turn_started"] = false
	combatant["auto_item_checked"] = false
	party_combatants[index] = combatant
	_advance_party_turn()


func _resolve_instant_party_action(combatant: Dictionary, member: Dictionary, action: Dictionary, game_state) -> void:
	var source := str(action.get("source", ""))
	if source == ACTION_SOURCE_SKILL:
		_resolve_party_skill(combatant, member, action, game_state)
		return
	_finish_party_turn(combatant)


func _resolve_party_skill(combatant: Dictionary, member: Dictionary, action: Dictionary, game_state) -> void:
	var member_id: String = str(member.get("id", ""))
	var caster: CombatActorStatus = party_actor_statuses.get(member_id)
	var skill: Dictionary = DataTables.create_default_attack_skill(caster.total_stat("attack")) if str(action.get("id", "")) == DataTables.DEFAULT_ATTACK_SKILL_ID and caster != null else DataTables.create_skill(str(action.get("id", "")))
	if skill.is_empty():
		return
	var preferred := _status_by_id(str(action.get("preferred_target_id", "")))
	var targets: Array = _skill_targets(caster, skill, preferred)
	var attack_mode := DataTables.skill_attack_mode(skill)
	var approach_target_id := ""
	if attack_mode == DataTables.ATTACK_MODE_MELEE and not targets.is_empty():
		var primary := targets[0] as CombatActorStatus
		if primary != null and _enemy_node(primary.actor_id) != null:
			approach_target_id = primary.actor_id
	combatant["pending_action"] = action.duplicate(true)
	combatant["pending_skill"] = skill
	combatant["attack_mode"] = attack_mode
	if not approach_target_id.is_empty():
		combatant["approach_target_id"] = approach_target_id
		combatant["state"] = STATE_APPROACH
		return
	combatant["approach_target_id"] = ""
	_start_party_skill_cast(combatant, member, targets, game_state)


func _tick_party_approach(combatant: Dictionary, actor: Node, member: Dictionary, game_state, delta: float) -> void:
	var target_id := str(combatant.get("approach_target_id", ""))
	var target_node := _enemy_node(target_id)
	var target_status := _enemy_status(target_id)
	if target_node == null or target_status == null or not target_status.is_alive():
		# 近战接近过程中目标死亡：取消施法，直接回位结算回合。
		combatant["pending_skill"] = {}
		combatant["attack_mode"] = DataTables.ATTACK_MODE_RANGED
		combatant["state"] = STATE_RETURN
		return
	if _move_actor_toward(combatant, actor, target_node.melee_approach_position(), delta):
		var skill: Dictionary = combatant.get("pending_skill", {})
		var preferred := _status_by_id(target_id)
		_start_party_skill_cast(combatant, member, _skill_targets(party_actor_statuses.get(str(member.get("id", ""))), skill, preferred), game_state)


func _tick_party_return(combatant: Dictionary, actor: Node, delta: float) -> void:
	var formation: Vector2 = combatant.get("formation_position", Vector2.ZERO)
	if not _move_actor_toward(combatant, actor, formation, delta):
		return
	_finish_party_turn(combatant)


func _start_party_skill_cast(combatant: Dictionary, member: Dictionary, targets: Array, game_state) -> void:
	var member_id: String = str(member.get("id", ""))
	var caster: CombatActorStatus = party_actor_statuses.get(member_id)
	var skill: Dictionary = combatant.get("pending_skill", {})
	if skill.is_empty():
		_finish_party_turn(combatant)
		return
	var scene := _create_skill_scene(skill)
	if scene == null:
		log_added.emit("%s释放%s失败" % [member.get("name", "成员"), skill.get("name", "技能")])
		combatant["attack_mode"] = DataTables.ATTACK_MODE_RANGED
		combatant["state"] = STATE_RETURN
		return
	var mp_cost := int(skill.get("mp_cost", 0))
	if caster == null or not caster.spend_mp(mp_cost):
		scene.queue_free()
		log_added.emit("%s法力不足" % member.get("name", "成员"))
		combatant["attack_mode"] = DataTables.ATTACK_MODE_RANGED
		combatant["state"] = STATE_RETURN
		return
	var skill_id := str(skill.get("id", ""))
	combatant["state"] = STATE_SKILL
	_active_skill_scenes[member_id] = scene
	scene.combat_events_emitted.connect(_on_skill_combat_events)
	scene.finished.connect(_on_party_skill_finished.bind(member_id, skill_id), CONNECT_ONE_SHOT)
	var actor := _party_actor(member_id)
	if actor != null:
		actor.call("play_combat_action", str(combatant.get("attack_mode", DataTables.ATTACK_MODE_RANGED)) + "_attack", _allocate_action_id())
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
		var cooldown_multiplier := float(result.get("cooldown_multiplier", 1.0))
		var cooldown_adjustment := 0
		var caster_status: CombatActorStatus = party_actor_statuses.get(member_id)
		if caster_status != null:
			var modifiers := caster_status.equipment_combat_modifiers()
			cooldown_multiplier *= 1.0 + float(modifiers.get("skill_cooldown_percent", 0.0))
			cooldown_adjustment = int(modifiers.get("skill_cooldown_turns", 0))
		cooldowns[skill_id] = _cooldown_turns(int(skill.get("cooldown", 0)), cooldown_multiplier, cooldown_adjustment)
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
	if not active or finished:
		return
	if _turn_phase != PHASE_PARTY or _current_party_member_id() != member_id:
		return
	if str(combatant.get("attack_mode", "")) == DataTables.ATTACK_MODE_MELEE and _member_alive(member_id):
		combatant["attack_mode"] = DataTables.ATTACK_MODE_RANGED
		combatant["state"] = STATE_RETURN
		party_combatants[index] = combatant
		return
	combatant["attack_mode"] = ""
	_finish_party_turn(combatant)
	party_combatants[index] = combatant


func _resolve_party_pill(combatant: Dictionary, member: Dictionary, action: Dictionary, game_state) -> bool:
	var instance_id := str(action.get("id", ""))
	var item: Dictionary = game_state.inventory_item_by_instance(instance_id)
	if item.is_empty() or not game_state.use_combat_inventory_item(instance_id, str(member.get("id", "")), _alive_party_member_ids()):
		return false
	var cooldowns: Dictionary = combatant.get("pill_cooldowns", {})
	cooldowns[str(item.get("item_id", ""))] = int(action.get("cooldown", 2))
	combatant["pill_cooldowns"] = cooldowns
	var group_id := str(action.get("cooldown_group", ""))
	if not group_id.is_empty():
		var groups: Dictionary = combatant.get("pill_group_cooldowns", {})
		groups[group_id] = int(action.get("cooldown", 2))
		combatant["pill_group_cooldowns"] = groups
	return true


func _try_auto_item_for_turn(combatant: Dictionary, member: Dictionary, game_state) -> bool:
	if bool(combatant.get("auto_item_checked", false)):
		return false
	combatant["auto_item_checked"] = true
	var item_action := combat_ai.select_auto_item_action(
		game_state,
		combatant.get("pill_cooldowns", {}),
		combatant.get("pill_group_cooldowns", {}),
		member
	)
	if item_action.is_empty():
		return false
	return _resolve_party_pill(combatant, member, item_action, game_state)


func _alive_party_member_ids() -> Array[String]:
	var result: Array[String] = []
	for combatant in party_combatants:
		var member_id := str(combatant.get("member_id", ""))
		if _member_alive(member_id):
			result.append(member_id)
	return result


func _tick_enemy(delta: float) -> void:
	if not _has_current_enemy_turn() and not _select_current_enemy_turn():
		_begin_next_round()
		return
	match _enemy_state:
		STATE_READY:
			_begin_enemy_action()
		STATE_APPROACH:
			_tick_enemy_approach(delta)
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
	var enemy_cooldowns: Dictionary = enemy.get("skill_cooldowns", {})
	for skill_id in enemy_cooldowns.keys():
		enemy_cooldowns[skill_id] = maxi(0, int(enemy_cooldowns[skill_id]) - 1)
	enemy["skill_cooldowns"] = enemy_cooldowns
	_enemy_target_id = target_id
	var target_status: CombatActorStatus = party_actor_statuses.get(target_id)
	_enemy_pending_action = current_enemy_node.select_action_with_context(pending_game_state, _combat_ai_context(enemy_actor_status)) if current_enemy_node.has_method("select_action_with_context") else current_enemy_node.select_action(pending_game_state, target_status)
	var preferred_id := str(_enemy_pending_action.get("preferred_target_id", target_id))
	if _member_alive(preferred_id):
		target_id = preferred_id
	_enemy_target_id = target_id
	if DataTables.skill_is_melee(_enemy_pending_action) and _party_actor(target_id) != null:
		_enemy_state = STATE_APPROACH
		return
	_start_enemy_skill()


func _tick_enemy_approach(delta: float) -> void:
	var target := _party_actor(_enemy_target_id)
	if target == null or not _member_alive(_enemy_target_id):
		_enemy_state = STATE_RETURN
		return
	if _move_enemy_toward(target.call("melee_approach_position"), delta):
		_start_enemy_skill()


func _tick_enemy_return(delta: float) -> void:
	if not _move_enemy_toward(_enemy_home_position, delta):
		return
	_enemy_target_id = ""
	var turn_events := enemy_actor_status.tick_turn_end()
	if _queue_presentation(turn_events, Callable(self, "_complete_enemy_return")):
		return
	_complete_enemy_return()


func _complete_enemy_return() -> void:
	_enemy_turn_started = false
	_store_current_enemy_runtime()
	_enemy_turn_index += 1
	_enemy_state = STATE_READY
	_enemy_target_id = ""
	_enemy_pending_action.clear()
	if not _select_current_enemy_turn():
		_begin_next_round()


func _on_actor_defeated(actor_id: String) -> void:
	if _enemy_combatant_index(actor_id) >= 0:
		_start_enemy_death(actor_id)
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


func _start_enemy_death(actor_id: String = "") -> void:
	var index := _enemy_combatant_index(actor_id if not actor_id.is_empty() else str(enemy.get("combat_id", "")))
	if index < 0:
		return
	var enemy_combatant: Dictionary = enemy_combatants[index]
	if bool(enemy_combatant.get("death_waiting", false)) or bool(enemy_combatant.get("rewarded", false)):
		return
	enemy_combatant["death_waiting"] = true
	enemy_combatants[index] = enemy_combatant
	var node: BaseEnemy = enemy_combatant.get("node") as BaseEnemy
	if node != null:
		node.cancel_combat_action()
		node.play_death_feedback()
	else:
		_on_enemy_death_finished(str(enemy_combatant.get("combat_id", "")))


func _on_enemy_death_finished(actor_id: String = "") -> void:
	var index := _enemy_combatant_index(actor_id if not actor_id.is_empty() else str(enemy.get("combat_id", "")))
	if index < 0:
		return
	var defeated: Dictionary = enemy_combatants[index]
	if not bool(defeated.get("rewarded", false)):
		enemy = defeated.get("data", {})
		_rewards_granted = false
		_grant_victory_rewards()
		defeated["rewarded"] = true
	var node: BaseEnemy = defeated.get("node") as BaseEnemy
	if node != null and is_instance_valid(node):
		node.queue_free()
	enemy_combatants.remove_at(index)
	_refill_enemy_slots()
	_layout_enemy_slots()
	_sync_front_enemy_aliases()
	if not enemy_combatants.is_empty() or not enemy_waiting_queue.is_empty():
		_check_combat_result()
		return
	var reward_eligible := true
	for defeated_enemy in enemy_group:
		if bool(defeated_enemy.get("is_training_dummy", false)):
			reward_eligible = false
			break
	if pending_game_state.has_method("register_full_encounter_victory"):
		pending_game_state.call("register_full_encounter_victory", reward_eligible)
	_combat_result = RESULT_VICTORY
	active = false
	finished = true
	for combatant in party_combatants:
		if str(combatant.get("state", "")) != STATE_DEFEATED:
			combatant["state"] = STATE_VICTORY


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
	# 保留旧存档命格的掉落加成兼容路径。
	if bool(enemy.get("use_drop", true)) and pending_game_state.rng.randf() < clampf(float(enemy.get("equipment_drop_chance", 0.0)) * _drop_chance_multiplier(pending_game_state), 0.0, 1.0):
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


func _drop_chance_multiplier(game_state) -> float:
	# 命格掉落加成乘数；GameState 未提供 helper 时退回 1.0（兼容宿主注入的自定义状态对象）。
	if game_state != null and game_state.has_method("party_drop_chance_multiplier"):
		return maxf(0.0, float(game_state.party_drop_chance_multiplier()))
	return 1.0


func _resolve_explicit_drops(game_state, awarded_item_ids: Dictionary) -> void:
	var explicit_drops = enemy.get("drops", {})
	if not (explicit_drops is Dictionary):
		return
	var multiplier := _drop_chance_multiplier(game_state)
	for item_id in explicit_drops.keys():
		var drop_def: Dictionary = explicit_drops.get(item_id, {})
		if game_state.rng.randf() > clampf(float(drop_def.get("chance", 0.0)) * multiplier, 0.0, 1.0):
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
	var multiplier := _drop_chance_multiplier(game_state)
	match str(profile.get("mode", "")):
		"independent":
			for entry_value in entries:
				if not (entry_value is Dictionary):
					continue
				var entry: Dictionary = entry_value
				if game_state.rng.randf() > clampf(float(entry.get("chance", 0.0)) * multiplier, 0.0, 1.0):
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
	var chance := clampf((float(profile.get("base_chance", 0.0)) + 0.05 * float(level_steps)) * _drop_chance_multiplier(game_state), 0.0, 1.0)
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
	for enemy_combatant in enemy_combatants.duplicate():
		var status: CombatActorStatus = enemy_combatant.get("status") as CombatActorStatus
		if status != null and not status.is_alive():
			_start_enemy_death(str(enemy_combatant.get("combat_id", "")))
	if enemy_combatants.is_empty() and enemy_waiting_queue.is_empty():
		return
	if _first_alive_party_member_id().is_empty():
		for combatant in enemy_combatants:
			var node: BaseEnemy = combatant.get("node") as BaseEnemy
			if node != null and is_instance_valid(node):
				node.cancel_combat_action()
		active = false
		finished = true
		_combat_result = RESULT_DEFEAT
		log_added.emit("队伍全灭")


func _spawn_enemy_node(_enemy_id: String) -> void:
	var data := enemy
	var combatant := _spawn_enemy_combatant(data, enemy_combatants.size())
	if not combatant.is_empty():
		enemy_combatants.append(combatant)
		_sync_front_enemy_aliases()


func _spawn_enemy_combatant(data: Dictionary, slot_index: int) -> Dictionary:
	var enemy_id := str(data.get("id", ""))
	var scene_path := DataTables.enemy_scene_path(enemy_id)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("敌人模板加载失败: %s" % scene_path)
		return {}
	var node := packed.instantiate() as BaseEnemy
	if node == null:
		push_error("敌人模板根节点必须继承 BaseEnemy: %s" % scene_path)
		return {}
	add_child(node)
	node.setup(data)
	var combat_id := str(data.get("combat_id", "enemy"))
	node.death_finished.connect(_on_enemy_death_finished.bind(combat_id), CONNECT_ONE_SHOT)
	var status := node.ensure_combat_status()
	status.set_effect_resolver(combat_effect_resolver)
	status.bind_enemy(data, node)
	_connect_status(status)
	var formation := _enemy_slot_position(slot_index)
	node.set_combat_position(formation)
	return {
		"combat_id": combat_id,
		"data": data,
		"node": node,
		"status": status,
		"slot_index": slot_index,
		"formation_position": formation,
		"position": formation,
		"state": STATE_READY,
		"action_id": 0,
		"target_id": "",
		"pending_action": {},
		"turn_started": false,
		"death_waiting": false,
		"rewarded": false,
	}


func _refill_enemy_slots() -> void:
	while enemy_combatants.size() < MAX_CONCURRENT_ENEMIES and not enemy_waiting_queue.is_empty():
		var data: Dictionary = enemy_waiting_queue.pop_front()
		var combatant := _spawn_enemy_combatant(data, enemy_combatants.size())
		if not combatant.is_empty():
			enemy_combatants.append(combatant)
	_layout_enemy_slots()


func _layout_enemy_slots() -> void:
	for index in range(enemy_combatants.size()):
		var formation := _enemy_slot_position(index)
		enemy_combatants[index]["slot_index"] = index
		enemy_combatants[index]["formation_position"] = formation
		enemy_combatants[index]["position"] = formation
		var node: BaseEnemy = enemy_combatants[index].get("node") as BaseEnemy
		if node != null:
			node.set_combat_position(formation)


func _party_front_position(_party_count: int, enemy_count: int) -> Vector2:
	var enemy_back_x := 866.0 + ENEMY_FORMATION_SPACING.x * float(maxi(0, enemy_count - 1))
	var shift := maxf(0.0, enemy_back_x - (960.0 - VIEWPORT_SAFE_MARGIN))
	return DEFAULT_PARTY_POSITION - Vector2(shift, 0)


func _enemy_slot_position(index: int) -> Vector2:
	var active_capacity := mini(MAX_CONCURRENT_ENEMIES, maxi(1, enemy_group.size()))
	var enemy_back_x := DEFAULT_ENEMY_POSITION.x + ENEMY_FORMATION_SPACING.x * float(active_capacity - 1)
	var shift := maxf(0.0, enemy_back_x - (960.0 - VIEWPORT_SAFE_MARGIN))
	return DEFAULT_ENEMY_POSITION - Vector2(shift, 0) + ENEMY_FORMATION_SPACING * float(index)


func _sync_front_enemy_aliases() -> void:
	var combatant := _first_alive_enemy_combatant()
	if combatant.is_empty():
		enemy = {}
		current_enemy_node = null
		enemy_actor_status = null
		return
	enemy = combatant.get("data", {})
	current_enemy_node = combatant.get("node") as BaseEnemy
	enemy_actor_status = combatant.get("status") as CombatActorStatus
	_enemy_home_position = combatant.get("formation_position", DEFAULT_ENEMY_POSITION)


func _first_alive_enemy_combatant() -> Dictionary:
	for combatant in enemy_combatants:
		var status: CombatActorStatus = combatant.get("status") as CombatActorStatus
		if status != null and status.is_alive() and not bool(combatant.get("death_waiting", false)):
			return combatant
	return {}


func _enemy_combatant_index(combat_id: String) -> int:
	for index in range(enemy_combatants.size()):
		if str(enemy_combatants[index].get("combat_id", "")) == combat_id:
			return index
	return -1


func _enemy_status(combat_id: String) -> CombatActorStatus:
	var index := _enemy_combatant_index(combat_id)
	return enemy_combatants[index].get("status") as CombatActorStatus if index >= 0 else null


func _enemy_node(combat_id: String) -> BaseEnemy:
	var index := _enemy_combatant_index(combat_id)
	return enemy_combatants[index].get("node") as BaseEnemy if index >= 0 else null


func _status_by_id(actor_id: String) -> CombatActorStatus:
	var party_status: CombatActorStatus = party_actor_statuses.get(actor_id)
	return party_status if party_status != null else _enemy_status(actor_id)


func _enemy_combatant_snapshots() -> Array:
	var result: Array = []
	for combatant in enemy_combatants:
		var status: CombatActorStatus = combatant.get("status") as CombatActorStatus
		var snapshot := status.combat_snapshot() if status != null else {}
		snapshot["slot_index"] = int(combatant.get("slot_index", 0))
		snapshot["formation_position"] = combatant.get("formation_position", Vector2.ZERO)
		result.append(snapshot)
	return result


func _allocate_action_id() -> int:
	var action_id := _next_action_id
	_next_action_id += 1
	return action_id


func _connect_status(status: CombatActorStatus) -> void:
	if not status.combat_popup_requested.is_connected(_on_combat_popup_requested):
		status.combat_popup_requested.connect(_on_combat_popup_requested)
	if not status.defeated.is_connected(_on_actor_defeated):
		status.defeated.connect(_on_actor_defeated)


func _on_combat_popup_requested(amount: int, world_position: Vector2, target_key: String, damage_type: String, is_heal: bool) -> void:
	damage_popup_requested.emit(amount, world_position, target_key, damage_type, is_heal)


func _create_skill_scene(skill: Dictionary) -> SkillSceneBase:
	if skill.is_empty():
		return null
	if not _skill_scene_registry_ready:
		_skill_scene_registry_ready = true
		for registry_error in skill_scene_registry.scan_core():
			push_warning(registry_error)
	var packed: PackedScene = skill_scene_registry.packed_scene(str(skill.get("id", "")))
	if packed == null:
		push_warning("技能场景未注册: %s" % skill.get("id", ""))
		return null
	var scene := packed.instantiate() as SkillSceneBase
	if scene == null:
		return null
	add_child(scene)
	return scene


func _skill_cast_context(caster: CombatActorStatus, targets: Array, skill: Dictionary, rng: RandomNumberGenerator) -> SkillCastContext:
	var anchor: CombatActorStatus = targets[0] as CombatActorStatus if not targets.is_empty() else null
	var scope := DataTables.skill_target_scope(skill)
	# Friendly AOE reads as an aura from the caster. Enemy-facing damage and
	# debuffs keep the finite-range start target as their presentation anchor.
	if scope == DataTables.SKILL_TARGET_ALL_ALLIES:
		anchor = caster
	elif scope == DataTables.SKILL_TARGET_ALL_ENEMIES and not targets.is_empty():
		anchor = targets[0] as CombatActorStatus
	var direction := 1 if caster != null and caster.actor_kind == CombatActorStatus.KIND_MEMBER else -1
	return SkillCastContext.create(caster, targets, targets, skill, combat_effect_resolver, rng, anchor, direction)


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
	return _alive_enemy_statuses()


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
	if DataTables.skill_is_melee(skill):
		current_enemy_node.play_attack_feedback(_allocate_action_id())
	else:
		current_enemy_node.play_ranged_attack_feedback(_allocate_action_id())
	log_added.emit("%s释放%s" % [enemy.get("name", "敌人"), skill.get("name", "技能")])
	scene.start_cast(_skill_cast_context(enemy_actor_status, targets, skill, pending_game_state.rng))


func _on_enemy_skill_finished(result: Dictionary, scene_key: String, skill_id: String) -> void:
	var scene: SkillSceneBase = _active_skill_scenes.get(scene_key) as SkillSceneBase
	_active_skill_scenes.erase(scene_key)
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	if not bool(result.get("cast_succeeded", false)):
		var enemy_index := _enemy_combatant_index(scene_key)
		if enemy_index >= 0:
			var enemy_data: Dictionary = enemy_combatants[enemy_index].get("data", {})
			var cooldowns: Dictionary = enemy_data.get("skill_cooldowns", {})
			cooldowns[skill_id] = 0
			enemy_data["skill_cooldowns"] = cooldowns
			enemy_combatants[enemy_index]["data"] = enemy_data
	if _wait_for_presentation(Callable(self, "_complete_enemy_skill")):
		return
	_complete_enemy_skill()


func _complete_enemy_skill() -> void:
	_check_combat_result()
	if active and not finished:
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
	var event_owner: Node = _enemy_node(actor_id)
	if event_owner == null:
		event_owner = _party_actor(actor_id)
	var duration := 0.08
	if event_owner != null and event_owner.has_method("present_combat_event"):
		duration = maxf(duration, float(event_owner.call("present_combat_event", event)))
	_presentation_timer = duration


func _skill_targets(caster: CombatActorStatus, skill: Dictionary, preferred_target: CombatActorStatus = null) -> Array:
	if caster == null:
		return []
	var allies: Array = _alive_party_statuses() if caster.actor_kind == CombatActorStatus.KIND_MEMBER else _alive_enemy_statuses()
	var opponents: Array = _alive_enemy_statuses() if caster.actor_kind == CombatActorStatus.KIND_MEMBER else _alive_party_statuses()
	allies = allies.filter(func(status): return status is CombatActorStatus and status.is_alive())
	opponents = opponents.filter(func(status): return status is CombatActorStatus and status.is_alive())
	match DataTables.skill_target_scope(skill):
		DataTables.SKILL_TARGET_SELF:
			return [caster]
		DataTables.SKILL_TARGET_SINGLE_ALLY:
			return [_preferred_target(preferred_target, allies, caster)]
		DataTables.SKILL_TARGET_ALL_ALLIES:
			return _limited_aoe_targets(allies, skill)
		DataTables.SKILL_TARGET_ALL_ENEMIES:
			return _limited_aoe_targets(opponents, skill)
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


func _alive_enemy_statuses() -> Array:
	var result: Array = []
	for combatant in enemy_combatants:
		var status: CombatActorStatus = combatant.get("status") as CombatActorStatus
		if status != null and status.is_alive() and not bool(combatant.get("death_waiting", false)):
			result.append(status)
	return result


func _limited_aoe_targets(candidates: Array, skill: Dictionary) -> Array:
	if candidates.is_empty():
		return []
	var count := DataTables.skill_target_count(skill, candidates.size())
	var start := candidates.size() - count if DataTables.skill_target_tendency(skill) == DataTables.SKILL_TARGET_TENDENCY_BACK else 0
	return candidates.slice(start, start + count)


func _move_actor_toward(combatant: Dictionary, actor: Node, target: Vector2, delta: float) -> bool:
	var current_position: Vector2 = combatant.get("position", actor.call("combat_position"))
	var speed := float(combatant.get("move_speed", DEFAULT_MOVE_SPEED))
	current_position = current_position.move_toward(target, speed * delta)
	combatant["position"] = current_position
	actor.call("set_combat_position", current_position)
	return current_position.distance_to(target) <= POSITION_EPSILON


func _move_enemy_toward(target: Vector2, delta: float) -> bool:
	if current_enemy_node == null:
		return false
	var current_position := current_enemy_node.combat_position()
	current_position = current_position.move_toward(target, float(enemy.get("move_speed", DEFAULT_MOVE_SPEED)) * delta)
	current_enemy_node.set_combat_position(current_position)
	current_enemy_node.play_run()
	return current_position.distance_to(target) <= POSITION_EPSILON


func _distance_to_enemy_target(combatant: Dictionary, target_node: BaseEnemy) -> float:
	if target_node == null:
		return INF
	return Vector2(combatant.get("position", Vector2.ZERO)).distance_to(target_node.combat_position())


func _advance_turn_cooldowns(combatant: Dictionary) -> void:
	for key in ["skill_cooldowns", "pill_cooldowns", "pill_group_cooldowns"]:
		var values: Dictionary = combatant.get(key, {})
		for id in values.keys():
			values[id] = maxi(0, int(values[id]) - 1)
		combatant[key] = values


func _cooldown_turns(base_turns: int, multiplier: float = 1.0, turn_adjustment: int = 0) -> int:
	var scaled_turns := ceili(float(maxi(0, base_turns)) * maxf(0.0, multiplier))
	return maxi(0, scaled_turns + turn_adjustment)


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
	_enemy_turn_order.clear()
	for combatant in enemy_combatants:
		var status: CombatActorStatus = combatant.get("status") as CombatActorStatus
		if status != null and status.is_alive() and not bool(combatant.get("death_waiting", false)):
			_enemy_turn_order.append(str(combatant.get("combat_id", "")))
	_enemy_turn_index = 0
	_enemy_state = STATE_READY
	_enemy_target_id = ""
	_select_current_enemy_turn()


func _begin_next_round() -> void:
	_round_number += 1
	_turn_phase = PHASE_PARTY
	_party_turn_index = 0
	_enemy_turn_order.clear()
	_enemy_turn_index = 0
	for index in range(party_combatants.size()):
		var combatant: Dictionary = party_combatants[index]
		var member_id := str(combatant.get("member_id", ""))
		combatant["turn_started"] = false
		combatant["auto_item_checked"] = false
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


func _cancel_party_action(combatant: Dictionary, defeated: bool) -> void:
	var member_id := str(combatant.get("member_id", ""))
	var skill_scene: SkillSceneBase = _active_skill_scenes.get(member_id) as SkillSceneBase
	_active_skill_scenes.erase(member_id)
	if skill_scene != null and is_instance_valid(skill_scene):
		skill_scene.queue_free()
	var actor := _party_actor(member_id)
	if actor != null:
		actor.call("cancel_combat_action")
	combatant["action_id"] = 0
	combatant["pending_action"] = {}
	combatant["state"] = STATE_DEFEATED if defeated else STATE_RETURN


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


func _select_current_enemy_turn() -> bool:
	while _enemy_turn_index < _enemy_turn_order.size():
		var combat_id := str(_enemy_turn_order[_enemy_turn_index])
		var index := _enemy_combatant_index(combat_id)
		if index < 0:
			_enemy_turn_index += 1
			continue
		var combatant: Dictionary = enemy_combatants[index]
		var status: CombatActorStatus = combatant.get("status") as CombatActorStatus
		if status == null or not status.is_alive() or bool(combatant.get("death_waiting", false)):
			_enemy_turn_index += 1
			continue
		enemy = combatant.get("data", {})
		current_enemy_node = combatant.get("node") as BaseEnemy
		enemy_actor_status = status
		_enemy_home_position = combatant.get("formation_position", DEFAULT_ENEMY_POSITION)
		_enemy_state = str(combatant.get("state", STATE_READY))
		return current_enemy_node != null
	return false


func _has_current_enemy_turn() -> bool:
	if _turn_phase != PHASE_ENEMY or _enemy_turn_index < 0 or _enemy_turn_index >= _enemy_turn_order.size():
		return false
	var combat_id := str(_enemy_turn_order[_enemy_turn_index])
	if enemy_actor_status == null or enemy_actor_status.actor_id != combat_id:
		return false
	var index := _enemy_combatant_index(combat_id)
	if index < 0:
		return false
	var status: CombatActorStatus = enemy_combatants[index].get("status") as CombatActorStatus
	return status != null and status.is_alive() and not bool(enemy_combatants[index].get("death_waiting", false))


func _store_current_enemy_runtime() -> void:
	var index := _enemy_combatant_index(str(enemy.get("combat_id", "")))
	if index < 0:
		return
	enemy_combatants[index]["data"] = enemy
	enemy_combatants[index]["position"] = current_enemy_node.combat_position() if current_enemy_node != null else _enemy_home_position
	enemy_combatants[index]["state"] = STATE_READY


func _combat_ai_context(caster: CombatActorStatus) -> Dictionary:
	return {
		"caster": caster,
		"allies": _alive_party_statuses() if caster != null and caster.actor_kind == CombatActorStatus.KIND_MEMBER else _alive_enemy_statuses(),
		"opponents": _alive_enemy_statuses() if caster != null and caster.actor_kind == CombatActorStatus.KIND_MEMBER else _alive_party_statuses(),
	}
