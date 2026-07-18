extends Node2D

const GAME_STATE_SCRIPT_PATH := "res://scripts/game/core/game_state.gd"
const SAVE_MANAGER_SCRIPT_PATH := "res://scripts/game/core/save_manager.gd"
const ACTOR_SCENE_PATH := "res://scripts/actors/actor.tscn"
const WINDOW_SIZE := Vector2i(960, 480)
const SCENE_VIEWPORT_SIZE := Vector2(960, 480)
const EXPEDITION_RUN_POSITION := Vector2(180, 170)
const COMBAT_START_POSITION := Vector2(736, 170)

var game_state
var save_manager
var save_timer: Timer
var party_actors_container: Node2D
var party_actors: Dictionary = {}
var _party_signature := ""
var combat
var hud
var home_map
var battle_map
var expedition_active := false
var scene_transition_active := false
var _exit_save_completed := false


func _ready() -> void:
	_setup_runtime_services()
	_setup_window()
	_load_saved_data()
	_setup_save_timer()

	_bind_scene_nodes()
	_apply_scene_viewport_size()
	_sync_party_actors(true)

	_connect_scene_signals()
	hud.load_hud_save_data(_loaded_hud_data())
	if home_map != null:
		home_map.update_progress_alerts(game_state)
	hud.push_log("家园已启动")
	var mod_api := get_node_or_null("/root/ModAPI")
	if mod_api != null:
		mod_api.notify_game_ready(game_state)


func _on_home_node_selected(node_name: String) -> void:
	_bind_scene_nodes()
	var task_type: int = home_map.task_type_for_node(node_name)
	if task_type == GameDefs.TaskType.RECRUIT \
		or task_type == GameDefs.TaskType.FARM \
		or task_type == GameDefs.TaskType.FORGE \
		or task_type == GameDefs.TaskType.ALCHEMY \
		or task_type == GameDefs.TaskType.FIGHT:
		hud.show_home_action_panel(task_type)
		hud.refresh(game_state)


func _on_home_action_requested(task_type: int) -> void:
	_bind_scene_nodes()
	if task_type == GameDefs.TaskType.RECRUIT:
		game_state.generate_recruit_candidates()
		hud.show_home_action_panel(task_type)
	elif task_type == GameDefs.TaskType.FARM:
		hud.show_home_action_panel(task_type)
	elif task_type == GameDefs.TaskType.FORGE:
		if not game_state.has_party_member():
			_push_log("需要先招募角色")
			return
		var forge_member_id: String = str(game_state.party_members()[0].get("id", ""))
		game_state.craft_equipment_for_member(forge_member_id)
	elif task_type == GameDefs.TaskType.ALCHEMY:
		if not game_state.has_party_member():
			_push_log("需要先招募角色")
			return
		var pill_id: String = game_state.random_known_alchemy_recipe()
		if pill_id.is_empty():
			hud.push_log("没有已学丹方")
			return
		var alchemy_member_id: String = str(game_state.party_members()[0].get("id", ""))
		game_state.craft_alchemy_recipe(pill_id, 1, alchemy_member_id)
	elif task_type == GameDefs.TaskType.FIGHT:
		if not game_state.has_party_member():
			_push_log("需要先招募角色")
			return
		if hud != null:
			hud.hide_home_ui()
		_start_enter_expedition_transition()


func _process(delta: float) -> void:
	_bind_scene_nodes()
	game_state.update_buffs(delta)
	game_state.update_home_production(delta)
	game_state.update_farm(delta)
	if combat.active:
		combat.tick(delta, game_state)
	_sync_party_actors()
	if combat.is_finished() and not scene_transition_active:
		_finish_current_combat()
	elif not expedition_active:
		for actor in party_actors.values():
			actor.set_idle_roam()
	hud.refresh(game_state)
	if home_map != null:
		home_map.show_farm_slots(game_state.farm_slots)
		home_map.update_progress_alerts(game_state)


func _enter_expedition() -> void:
	_bind_scene_nodes()
	_apply_scene_viewport_size()
	_connect_scene_signals()
	if expedition_active:
		_push_log("已经在历练中，等待下一次遇怪")
		return
	if not game_state.has_party_member():
		_push_log("需要先招募角色")
		return
	expedition_active = true
	_sync_party_actors()
	if home_map != null:
		home_map.visible = false
	if battle_map != null:
		battle_map.enter_expedition()
	_set_party_expedition_run()
	if hud != null:
		hud.set_expedition_controls_visible(true)
	_push_log("进入历练地图，开始寻找怪物")


func _start_enter_expedition_transition() -> void:
	if scene_transition_active:
		return
	_bind_scene_nodes()
	if expedition_active:
		_enter_expedition()
		return
	scene_transition_active = true
	if hud != null:
		hud.play_scene_transition("进入历练...")
		await hud.scene_transition_midpoint
		_enter_expedition()
		await hud.scene_transition_finished
	else:
		_enter_expedition()
	scene_transition_active = false


func _on_expedition_exit_requested() -> void:
	if scene_transition_active:
		return
	_start_exit_expedition_transition()


func _start_exit_expedition_transition() -> void:
	if scene_transition_active:
		return
	_bind_scene_nodes()
	if not expedition_active:
		return
	scene_transition_active = true
	if combat != null:
		combat.clear()
	if hud != null:
		hud.play_scene_transition("返回家园...")
		await hud.scene_transition_midpoint
		_exit_expedition()
		await hud.scene_transition_finished
	else:
		_exit_expedition()
	scene_transition_active = false


func _exit_expedition() -> void:
	_bind_scene_nodes()
	_apply_scene_viewport_size()
	expedition_active = false
	if combat != null:
		combat.clear()
	if battle_map != null:
		battle_map.exit_expedition()
	if home_map != null:
		home_map.visible = true
		home_map.show_farm_slots(game_state.farm_slots)
		home_map.update_progress_alerts(game_state)
	_set_party_home()
	_sync_party_actors()
	if hud != null:
		hud.set_expedition_controls_visible(false)
		hud.refresh(game_state)
	_push_log("返回家园")


func _on_monster_spawn_requested() -> void:
	_bind_scene_nodes()
	if not expedition_active or combat.active:
		return
	if not game_state.has_party_member():
		_push_log("需要先招募角色")
		_start_exit_expedition_transition()
		return
	if battle_map != null:
		battle_map.set_combat_mode(true)
		battle_map.set_player_combat_position(COMBAT_START_POSITION)
	combat.set_party_views(party_actors)
	combat.begin_encounter(game_state, battle_map)


func _finish_current_combat() -> void:
	_bind_scene_nodes()
	var result: String = combat.combat_result()
	combat.clear()
	if result == CombatController.RESULT_DEFEAT:
		game_state.recover_party_after_defeat(0.5)
		_push_log("队伍全灭，恢复半数生命与法力后返回家园")
		_queue_save_data()
		_start_exit_expedition_transition()
		return
	if result != CombatController.RESULT_VICTORY:
		return
	game_state.add_task_experience(GameDefs.TaskType.FIGHT, 8)
	if battle_map != null and expedition_active:
		battle_map.finish_combat()
	if expedition_active:
		_set_party_expedition_run()


func _on_damage_popup_requested(amount: int, world_position: Vector2, target_key: String, damage_type: String, is_heal: bool) -> void:
	if hud != null and hud.has_method("show_damage_popup"):
		hud.show_damage_popup(amount, world_position, target_key, damage_type, is_heal)


func _bind_scene_nodes() -> void:
	if home_map == null:
		home_map = get_node_or_null("Home")
	if battle_map == null:
		battle_map = get_node_or_null("BattleMap")
	if party_actors_container == null:
		party_actors_container = get_node_or_null("PartyActors") as Node2D
	if combat == null:
		combat = get_node_or_null("CombatController")
	if hud == null:
		hud = get_node_or_null("Hud")


func _sync_party_actors(force: bool = false) -> void:
	if party_actors_container == null or game_state == null:
		return
	var members: Array = game_state.party_members()
	var signature_parts: Array[String] = []
	for member in members:
		signature_parts.append("%s:%s" % [member.get("id", ""), member.get("visual_id", "actor_default")])
	var signature := "|".join(signature_parts)
	if not force and signature == _party_signature:
		return
	_party_signature = signature
	var wanted: Dictionary = {}
	for member in members:
		wanted[str(member.get("id", ""))] = true
	for member_id in party_actors.keys().duplicate():
		if wanted.has(member_id):
			continue
		var removed_actor: Node = party_actors.get(member_id)
		party_actors.erase(member_id)
		if removed_actor != null and is_instance_valid(removed_actor):
			removed_actor.queue_free()
	var actor_scene := load(ACTOR_SCENE_PATH) as PackedScene
	if actor_scene == null:
		push_error("角色模板加载失败: %s" % ACTOR_SCENE_PATH)
		return
	for index in range(members.size()):
		var member: Dictionary = members[index]
		var member_id := str(member.get("id", ""))
		var actor: ActorController = party_actors.get(member_id)
		if actor == null or not is_instance_valid(actor):
			actor = actor_scene.instantiate() as ActorController
			if actor == null:
				continue
			party_actors_container.add_child(actor)
			party_actors[member_id] = actor
		actor.configure_member(member, index)
		if expedition_active:
			actor.enter_expedition_run(_expedition_position_for(index))
		else:
			actor.setup()
	if combat != null:
		combat.set_party_views(party_actors)


func _set_party_home() -> void:
	var members: Array = game_state.party_members()
	for index in range(members.size()):
		var actor: ActorController = party_actors.get(str(members[index].get("id", "")))
		if actor != null:
			actor.exit_expedition_run()


func _set_party_expedition_run() -> void:
	var members: Array = game_state.party_members()
	for index in range(members.size()):
		var actor: ActorController = party_actors.get(str(members[index].get("id", "")))
		if actor != null:
			actor.enter_expedition_run(_expedition_position_for(index))


func _expedition_position_for(index: int) -> Vector2:
	return EXPEDITION_RUN_POSITION + Vector2(-52.0 * float(index), 0.0)


func _apply_scene_viewport_size() -> void:
	if home_map != null and home_map.has_method("set_scene_viewport_size"):
		home_map.call("set_scene_viewport_size", SCENE_VIEWPORT_SIZE)
	if battle_map != null and battle_map.has_method("set_scene_viewport_size"):
		battle_map.call("set_scene_viewport_size", SCENE_VIEWPORT_SIZE)


func _push_log(message: String) -> void:
	if hud != null:
		hud.push_log(message)


func _connect_scene_signals() -> void:
	if home_map != null:
		var home_callback := Callable(self, "_on_home_node_selected")
		if not home_map.home_node_selected.is_connected(home_callback):
			home_map.home_node_selected.connect(home_callback)
	if battle_map != null:
		var spawn_callback := Callable(self, "_on_monster_spawn_requested")
		if not battle_map.monster_spawn_requested.is_connected(spawn_callback):
			battle_map.monster_spawn_requested.connect(spawn_callback)
	if hud != null:
		var action_callback := Callable(self, "_on_home_action_requested")
		if not hud.home_action_requested.is_connected(action_callback):
			hud.home_action_requested.connect(action_callback)
		var expedition_exit_callback := Callable(self, "_on_expedition_exit_requested")
		if not hud.expedition_exit_requested.is_connected(expedition_exit_callback):
			hud.expedition_exit_requested.connect(expedition_exit_callback)
		var save_callback := Callable(self, "_queue_save_data")
		if not hud.hud_save_requested.is_connected(save_callback):
			hud.hud_save_requested.connect(save_callback)
	if combat != null and hud != null:
		var combat_log_callback := Callable(hud, "push_log")
		if not combat.log_added.is_connected(combat_log_callback):
			combat.log_added.connect(combat_log_callback)
		var damage_popup_callback := Callable(self, "_on_damage_popup_requested")
		if not combat.damage_popup_requested.is_connected(damage_popup_callback):
			combat.damage_popup_requested.connect(damage_popup_callback)
	var game_log_callback := Callable(self, "_push_log")
	if not game_state.log_added.is_connected(game_log_callback):
		game_state.log_added.connect(game_log_callback)
	var changed_callback := Callable(self, "_queue_save_data")
	if not game_state.changed.is_connected(changed_callback):
		game_state.changed.connect(changed_callback)


func _setup_window() -> void:
	if Engine.is_editor_hint() or OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return

	get_viewport().transparent_bg = true

	if OS.get_name() == "Windows":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)

	DisplayServer.window_set_size(WINDOW_SIZE)
	_position_window_above_taskbar()
	call_deferred("_position_window_above_taskbar")
	get_tree().create_timer(0.1).timeout.connect(_position_window_above_taskbar)


func _position_window_above_taskbar() -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size == Vector2i.ZERO:
		window_size = WINDOW_SIZE

	var horizontal_offset: int = int(maxi(0, usable.size.x - window_size.x) / 2.0)
	var vertical_offset: int = maxi(0, usable.size.y - window_size.y)
	var x: int = usable.position.x + horizontal_offset
	var y: int = usable.position.y + vertical_offset
	DisplayServer.window_set_position(Vector2i(x, y))


func _setup_save_timer() -> void:
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.5
	save_timer.timeout.connect(_save_data)
	add_child(save_timer)


func _setup_runtime_services() -> void:
	if game_state == null:
		var game_state_script: Resource = load(GAME_STATE_SCRIPT_PATH)
		if game_state_script == null:
			push_error("GameState 脚本加载失败: %s" % GAME_STATE_SCRIPT_PATH)
			return
		game_state = game_state_script.new()
	if save_manager == null:
		var save_manager_script: Resource = load(SAVE_MANAGER_SCRIPT_PATH)
		if save_manager_script == null:
			push_error("SaveManager 脚本加载失败: %s" % SAVE_MANAGER_SCRIPT_PATH)
			return
		save_manager = save_manager_script.new()


func _load_saved_data() -> void:
	var data: Dictionary = save_manager.load_data()
	game_state.load_save_data(data.get("game_state", {}))


func _loaded_hud_data() -> Dictionary:
	return save_manager.load_data().get("hud", {})


func _queue_save_data() -> void:
	if save_timer == null:
		return
	if save_timer.is_stopped():
		save_timer.start()


func _save_data() -> void:
	if save_manager == null or game_state == null:
		return
	var hud_data: Dictionary = {}
	if hud != null:
		hud_data = hud.to_hud_save_data()
	save_manager.save_data({
		"game_state": game_state.to_save_data(),
		"hud": hud_data,
		"config": {"viewport_size": {"width": WINDOW_SIZE.x, "height": WINDOW_SIZE.y}},
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_before_exit()


func _exit_tree() -> void:
	_save_before_exit()


func _save_before_exit() -> void:
	if _exit_save_completed:
		return
	_exit_save_completed = true
	if save_timer != null:
		save_timer.stop()
	_save_data()
