extends Node2D

const GameStateScript = preload("res://scripts/game/core/game_state.gd")
const SaveManagerScript = preload("res://scripts/game/core/save_manager.gd")
const WINDOW_SIZE := Vector2i(960, 480)
const SCENE_VIEWPORT_SIZE := Vector2(960, 480)

var game_state = GameStateScript.new()
var save_manager = SaveManagerScript.new()
var save_timer: Timer
var character
var combat
var hud
var home_map
var battle_map
var expedition_active := false
var scene_transition_active := false


func _ready() -> void:
	_setup_window()
	_load_saved_data()
	_setup_save_timer()

	_bind_scene_nodes()
	_apply_scene_viewport_size()
	character.setup()

	_connect_scene_signals()
	hud.load_hud_save_data(_loaded_hud_data())
	if home_map != null:
		home_map.update_progress_alerts(game_state)
	hud.push_log("家园已启动")


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
		if game_state.spend_inventory_type(DataTables.ITEM_TYPE_MATERIAL, 2):
			game_state.add_equipment(DataTables.create_equipment(game_state.stats["level"], game_state.rng, game_state.craft_bonus(), "non_drop"))
			game_state.add_exp(4)
			game_state.add_task_experience(task_type, 5)
		else:
			hud.push_log("材料不足，炼器失败")
	elif task_type == GameDefs.TaskType.ALCHEMY:
		var pill_id: String = game_state.random_known_alchemy_recipe()
		if pill_id.is_empty():
			hud.push_log("没有已学丹方")
			return
		if game_state.spend_inventory_type(DataTables.ITEM_TYPE_CROP, 2):
			game_state.gain_resource(pill_id, 1)
			if game_state.rng.randf() < game_state.alchemy_extra_chance():
				game_state.gain_resource(pill_id, 1)
			game_state.add_exp(4)
			game_state.add_task_experience(task_type, 5)
		else:
			hud.push_log("作物不足，炼丹失败")
	elif task_type == GameDefs.TaskType.FIGHT:
		if hud != null:
			hud.hide_home_ui()
		_start_enter_expedition_transition()


func _process(delta: float) -> void:
	_bind_scene_nodes()
	game_state.update_buffs(delta)
	game_state.update_farm(delta)
	if combat.active:
		combat.tick(delta, game_state)
	if combat.is_finished():
		_finish_current_combat()
	elif not expedition_active:
		character.set_idle_roam()
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
	expedition_active = true
	if home_map != null:
		home_map.visible = false
	if battle_map != null:
		battle_map.enter_expedition()
	if character != null:
		character.enter_expedition_run(Vector2(180, 170))
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
	if character != null:
		character.exit_expedition_run()
	if hud != null:
		hud.set_expedition_controls_visible(false)
		hud.refresh(game_state)
	_push_log("返回家园")


func _on_monster_spawn_requested() -> void:
	_bind_scene_nodes()
	if not expedition_active or combat.active:
		return
	if battle_map != null:
		battle_map.set_combat_mode(true)
	combat.begin_encounter(game_state, battle_map)


func _finish_current_combat() -> void:
	_bind_scene_nodes()
	game_state.add_task_experience(GameDefs.TaskType.FIGHT, 8)
	combat.clear()
	if battle_map != null and expedition_active:
		battle_map.finish_combat()
	if character != null and expedition_active:
		character.enter_expedition_run(Vector2(180, 170))


func _on_damage_popup_requested(amount: int, world_position: Vector2, target_key: String, damage_type: String, is_heal: bool) -> void:
	if hud != null and hud.has_method("show_damage_popup"):
		hud.show_damage_popup(amount, world_position, target_key, damage_type, is_heal)


func _bind_scene_nodes() -> void:
	if home_map == null:
		home_map = get_node_or_null("Home")
	if battle_map == null:
		battle_map = get_node_or_null("BattleMap")
	if character == null:
		character = get_node_or_null("CharacterController")
	if combat == null:
		combat = get_node_or_null("CombatController")
	if hud == null:
		hud = get_node_or_null("Hud")


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
		if character != null:
			var player_hit_callback := Callable(character, "play_hurt_feedback")
			if not combat.player_hit_received.is_connected(player_hit_callback):
				combat.player_hit_received.connect(player_hit_callback)
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
	var hud_data := {}
	if hud != null:
		hud_data = hud.to_hud_save_data()
	save_manager.save_data({
		"game_state": game_state.to_save_data(),
		"hud": hud_data,
		"config": {"viewport_size": {"width": WINDOW_SIZE.x, "height": WINDOW_SIZE.y}},
	})
