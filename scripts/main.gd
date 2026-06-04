extends Node2D

const GameStateScript = preload("res://scripts/game/game_state.gd")
const SaveManagerScript = preload("res://scripts/game/save_manager.gd")
const WINDOW_SIZE := Vector2i(960, 480)

var game_state = GameStateScript.new()
var save_manager = SaveManagerScript.new()
var save_timer: Timer
var character
var combat
var hud
var home_map


func _ready() -> void:
	_setup_window()
	_load_saved_data()
	_setup_save_timer()

	home_map = $Home
	character = $CharacterController
	character.setup()

	combat = $CombatController
	hud = $Hud

	home_map.home_node_selected.connect(_on_home_node_selected)
	hud.home_action_requested.connect(_on_home_action_requested)
	hud.hud_save_requested.connect(_queue_save_data)
	combat.log_added.connect(hud.push_log)
	game_state.log_added.connect(hud.push_log)
	game_state.changed.connect(_queue_save_data)
	hud.load_hud_save_data(_loaded_hud_data())
	hud.push_log("家园已启动")


func _on_home_node_selected(node_name: String) -> void:
	var task_type: int = home_map.task_type_for_node(node_name)
	if task_type == GameDefs.TaskType.MEDITATE \
		or task_type == GameDefs.TaskType.FARM \
		or task_type == GameDefs.TaskType.FORGE \
		or task_type == GameDefs.TaskType.ALCHEMY \
		or task_type == GameDefs.TaskType.FIGHT:
		hud.show_home_action_panel(task_type)


func _on_home_action_requested(task_type: int) -> void:
	if task_type == GameDefs.TaskType.MEDITATE:
		game_state.heal(18, 14)
		game_state.add_cultivation(8 + game_state.stats["level"])
		game_state.add_task_experience(task_type, 5)
	elif task_type == GameDefs.TaskType.FARM:
		var harvest: Dictionary = game_state.consume_seed_for_farm()
		if harvest.is_empty():
			hud.push_log("没有可用种子")
			return
		game_state.gain_resource(harvest["item_id"], int(harvest["amount"]))
		if home_map != null:
			home_map.show_farm_crops(str(harvest["item_id"]), int(harvest["amount"]))
		game_state.add_exp(2)
		game_state.add_task_experience(task_type, 5)
	elif task_type == GameDefs.TaskType.FORGE:
		if game_state.spend_inventory_type(DataTables.ITEM_TYPE_MATERIAL, 2):
			game_state.add_equipment(DataTables.create_equipment(game_state.stats["level"], game_state.rng, game_state.craft_bonus()))
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
		combat.begin_encounter(game_state)


func _process(delta: float) -> void:
	game_state.update_buffs(delta)
	if combat.active:
		combat.tick(delta, game_state)
		if combat.is_finished():
			game_state.add_task_experience(GameDefs.TaskType.FIGHT, 8)
	else:
		character.set_idle_roam()
	hud.refresh(game_state)


func _setup_window() -> void:
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
