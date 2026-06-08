extends SceneTree

const GameStateScript = preload("res://scripts/game/game_state.gd")
const SaveManagerScript = preload("res://scripts/game/save_manager.gd")
const HomeMapScript = preload("res://scripts/map/home_map.gd")
const HomeMapScene = preload("res://scripts/map/home.tscn")
const BattleMapScene = preload("res://scripts/map/battle_map.tscn")
const HudScene = preload("res://scripts/ui/hud.tscn")
const CharacterScene = preload("res://scripts/character/character_controller.tscn")
const MeScene = preload("res://scripts/character/me.tscn")
const MainScene = preload("res://main.tscn")

var failures := 0


func _init() -> void:
	_run()
	quit(1 if failures > 0 else 0)


func _run() -> void:
	_test_initial_progression_stats()
	_test_level_cap_and_breakthrough_item()
	_test_root_bone_breakthrough()
	_test_root_bone_activity_bonuses()
	_test_alchemy_recipes_and_duration_buffs()
	_test_alchemy_recipe_materials_and_batch_crafting()
	_test_save_manager_and_game_state_roundtrip()
	_test_home_action_opens_farm_panel()
	_test_main_scene_opens_farm_hud()
	_test_progress_state_save_and_alerts()
	_test_farm_seeds_and_level_yield()
	_test_farm_slots_growth_claim_and_speed_buff()
	_test_queue_modules_removed()
	_test_home_map_node_mapping_and_farm_slots()
	_test_battle_map_expedition_spawns_monsters()
	_test_main_scene_enters_expedition_before_combat()
	_test_hud_uses_scene_nodes()
	_test_character_gravity()
	_test_me_scene_uses_character_body()
	_test_character_reference_chain_uses_me_scene()
	_test_equipment_slots_strengthening_and_affixes()
	_test_equipment_attribute_tiers_stones_and_refine()
	_test_equipment_equip_requirements()
	_test_enemy_templates()
	_test_element_and_physical_reduction()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)


func _control_tree_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text
	elif node is Button:
		text += (node as Button).text
	for child in node.get_children():
		text += "\n%s" % _control_tree_text(child)
	return text


func _test_initial_progression_stats() -> void:
	var game_state = GameStateScript.new()
	_check(game_state.stats.has("root_bone"), "initial stats include root bone")
	_check(game_state.stats.has("level_cap"), "initial stats include level cap")
	_check(game_state.stats.has("stage"), "initial stats include stage")
	_check(game_state.stats.get("level_cap", 0) == 10, "initial level cap is 10")
	_check(game_state.stats.get("stage", 0) == 1, "initial stage is 1")


func _test_level_cap_and_breakthrough_item() -> void:
	var game_state = GameStateScript.new()
	game_state.stats["level"] = 10
	game_state.stats["level_cap"] = 10
	game_state.stats["stage"] = 1
	game_state.stats["root_bone"] = 1
	game_state.add_exp(game_state.stats["next_exp"])
	_check(game_state.stats["level"] == 10, "level does not exceed cap before breakthrough")
	_check(game_state.add_inventory_item("breakthrough_pill", 1, false), "breakthrough item can be added")
	_check(game_state.use_inventory_item("breakthrough_pill"), "breakthrough item can unlock cap")
	_check(game_state.stats["level_cap"] == 20, "breakthrough item raises level cap")
	_check(game_state.stats["stage"] == 2, "breakthrough item raises stage")


func _test_root_bone_breakthrough() -> void:
	var game_state = GameStateScript.new()
	game_state.stats["level"] = 10
	game_state.stats["level_cap"] = 10
	game_state.stats["stage"] = 1
	game_state.stats["root_bone"] = 11
	_check(game_state.try_breakthrough(), "root bone above level unlocks cap")
	_check(game_state.stats["level_cap"] == 20, "root bone breakthrough raises level cap")


func _test_root_bone_activity_bonuses() -> void:
	var game_state = GameStateScript.new()
	game_state.stats["root_bone"] = 10
	_check(game_state.cultivation_gain(3) == 7, "root bone increases cultivation gain")
	_check(game_state.craft_bonus() == 2, "root bone increases crafting stats")
	_check(is_equal_approx(game_state.alchemy_extra_chance(), 0.15), "root bone controls alchemy extra chance")


func _test_alchemy_recipes_and_duration_buffs() -> void:
	var game_state = GameStateScript.new()
	_check(DataTables.ITEM_TYPE_ALCHEMY_RECIPE == "alchemy_recipe", "alchemy recipe item type exists")
	_check(game_state.inventory_item_count("recipe_pill") == 1, "initial inventory has base alchemy recipe")
	_check(not game_state.is_inventory_item_direct_usable("recipe_pill"), "recipe is not directly usable from inventory double click")
	_check(game_state.use_inventory_item("recipe_pill"), "recipe item can be learned")
	_check(game_state.known_alchemy_recipes.has("pill"), "learned recipe is tracked")
	_check(game_state.inventory_item_count("recipe_pill") == 0, "recipe item is consumed")
	_check(game_state.add_inventory_item("might_pill", 1, false), "duration pill can be added")
	_check(game_state.is_inventory_item_direct_usable("might_pill"), "pill is directly usable from inventory double click")
	_check(game_state.use_inventory_item("might_pill"), "duration pill can be used")
	_check(game_state.active_buffs.size() == 1, "duration pill creates active buff")
	game_state.update_buffs(999.0)
	_check(game_state.active_buffs.is_empty(), "duration buff expires")


func _test_alchemy_recipe_materials_and_batch_crafting() -> void:
	var life_materials: Array = DataTables.alchemy_recipe_materials("life_boost_pill")
	_check(_recipe_material_amount(life_materials, "blood_ginseng") == 2, "life boost pill uses blood ginseng")
	_check(_recipe_material_amount(life_materials, "herb") == 1, "life boost pill uses documented herb")
	var root_materials: Array = DataTables.alchemy_recipe_materials("root_bone_pill")
	_check(_recipe_material_amount(root_materials, "monster_core") == 1, "root bone pill uses documented monster core")
	var wood_materials: Array = DataTables.alchemy_recipe_materials("wood_pill")
	_check(_recipe_material_amount(wood_materials, "herb") == 1, "wood pill uses documented herb")
	var metal_materials: Array = DataTables.alchemy_recipe_materials("metal_pill")
	_check(_recipe_material_amount(metal_materials, "ore") == 1, "metal pill uses documented ore")

	var game_state = GameStateScript.new()
	game_state.inventory.clear()
	game_state.known_alchemy_recipes.clear()
	game_state.known_alchemy_recipes.append("attack_pill")
	game_state.add_inventory_item("blade_grass", 6, false)
	game_state.add_inventory_item("rice", 3, false)
	game_state.add_inventory_item("stat_stone_attack_t1", 2, false)
	_check(game_state.alchemy_max_craft_count("attack_pill") == 2, "max craft count is limited by rarest material")
	_check(game_state.craft_alchemy_recipe("attack_pill", 2), "batch alchemy craft succeeds with enough materials")
	_check(game_state.inventory_item_count("blade_grass") == 2, "batch alchemy consumes crop materials")
	_check(game_state.inventory_item_count("rice") == 1, "batch alchemy consumes helper materials")
	_check(game_state.inventory_item_count("stat_stone_attack_t1") == 0, "batch alchemy consumes stone materials")
	_check(game_state.inventory_item_count("attack_pill") >= 2, "batch alchemy adds crafted pills")

	var pill_count := game_state.inventory_item_count("attack_pill")
	_check(not game_state.craft_alchemy_recipe("attack_pill", 1), "alchemy crafting fails when materials are short")
	_check(game_state.inventory_item_count("attack_pill") == pill_count, "failed alchemy crafting does not add pills")
	_check(not game_state.craft_alchemy_recipe("attack_pill", 0), "alchemy crafting rejects zero count")
	var unlearned_state = GameStateScript.new()
	unlearned_state.inventory.clear()
	unlearned_state.add_inventory_item("blade_grass", 2, false)
	unlearned_state.add_inventory_item("rice", 1, false)
	unlearned_state.add_inventory_item("stat_stone_attack_t1", 1, false)
	_check(not unlearned_state.craft_alchemy_recipe("attack_pill", 1), "alchemy crafting rejects unlearned recipes")


func _test_home_action_opens_farm_panel() -> void:
	var hud = HudScene.instantiate()
	get_root().add_child(hud)
	hud.refresh(GameStateScript.new())
	hud.show_home_action_panel(GameDefs.TaskType.FARM)
	var farm_panel := hud.get_node("Root/FarmPanel") as Control
	_check(farm_panel.visible, "farm action opens hud panel")
	hud.queue_free()

func _test_main_scene_opens_farm_hud() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	main.home_map = main.get_node("Home")
	main.hud = main.get_node("Hud")
	var hud = main.get_node("Hud") as CanvasLayer
	var farm_panel := hud.get_node("Root/FarmPanel") as Control
	main._on_home_node_selected("farmland")
	_check(farm_panel.visible, "main scene opens farm hud when farmland is selected")
	main.queue_free()

func _test_progress_state_save_and_alerts() -> void:
	var game_state = GameStateScript.new()
	game_state.set_progress_state("alchemy", "claimable", "Pill ready")
	var saved := game_state.to_save_data()
	var restored = GameStateScript.new()
	restored.load_save_data(saved)
	_check(restored.progress_state("alchemy").get("claimable", false), "progress state restores claimable flag")

	var home_map = HomeMapScene.instantiate()
	get_root().add_child(home_map)
	home_map.setup_home_map()
	home_map.update_progress_alerts(restored)
	var forge_alert := home_map.get_node_or_null("forge/AlertLabel") as Label
	_check(forge_alert == null or not forge_alert.visible, "forge alert stays hidden without completion")
	home_map.update_progress_alerts(game_state)
	var alchemy_alert := home_map.get_node_or_null("alchemy/AlertLabel") as Label
	_check(alchemy_alert != null and alchemy_alert.visible, "claimable progress shows alert above building")
	game_state.clear_progress_state("alchemy")
	home_map.update_progress_alerts(game_state)
	_check(not alchemy_alert.visible, "clearing progress hides alert")
	home_map.queue_free()

func _test_save_manager_and_game_state_roundtrip() -> void:
	var game_state = GameStateScript.new()
	game_state.inventory.clear()
	game_state.stats["level"] = 7
	game_state.elements["fire"] = 9
	game_state.task_exp["alchemy"] = 12
	game_state.known_alchemy_recipes.append("attack_pill")
	game_state.add_inventory_item("blade_grass", 3, false)
	game_state.active_buffs.append({"stat": "attack", "amount": 2, "remaining": 30.0})

	var path := "user://test_save_manager.cfg"
	var manager = SaveManagerScript.new(path)
	var save_data := {
		"game_state": game_state.to_save_data(),
		"hud": {"panel_positions": {"AlchemyPanel": {"x": 123.0, "y": 45.0}}},
		"config": {"viewport_size": {"width": 960, "height": 480}},
	}
	_check(manager.save_data(save_data), "save manager writes save file")
	var loaded: Dictionary = manager.load_data()
	_check(loaded.get("version", 0) == SaveManagerScript.SAVE_VERSION, "save manager stores save version")
	_check(loaded.get("hud", {}).get("panel_positions", {}).get("AlchemyPanel", {}).get("x", 0.0) == 123.0, "save manager roundtrips hud panel position")

	var restored_state = GameStateScript.new()
	restored_state.load_save_data(loaded.get("game_state", {}))
	_check(restored_state.stats["level"] == 7, "game state save restores stats")
	_check(restored_state.elements["fire"] == 9, "game state save restores elements")
	_check(restored_state.task_exp["alchemy"] == 12, "game state save restores task experience")
	_check(restored_state.inventory_item_count("blade_grass") == 3, "game state save restores inventory")
	_check(restored_state.known_alchemy_recipes.has("attack_pill"), "game state save restores learned recipes")
	_check(restored_state.active_buffs.size() == 1, "game state save restores active buffs")


func _test_farm_seeds_and_level_yield() -> void:
	var game_state = GameStateScript.new()
	_check(game_state.stats.has("farm_level"), "farm level exists")
	game_state.stats["farm_level"] = 3
	var result: Dictionary = game_state.consume_seed_for_farm()
	_check(result.get("item_id", "") == "herb", "farm consumes first crop as seed")
	_check(int(result.get("amount", 0)) == 5, "farm level increases seed yield")
	_check(game_state.inventory_item_count("herb") == 3, "seed is consumed before harvest reward")
	_check(game_state.inventory_item_count("herb") == 3, "farm harvest waits in plot before entering backpack")
	game_state.add_task_experience(GameDefs.TaskType.FARM, 25)
	_check(game_state.stats["farm_level"] > 3, "farm proficiency can raise farm level")


func _test_farm_slots_growth_claim_and_speed_buff() -> void:
	var game_state = GameStateScript.new()
	game_state.inventory.clear()
	game_state.add_inventory_item("herb", 2, false)
	game_state.add_inventory_item("farm_speed_talisman", 1, false)
	_check(game_state.farm_slots.size() == 5, "game state initializes five farm slots")
	_check(DataTables.crop_growth_seconds("herb") == 60.0, "basic herb has documented growth time")
	_check(DataTables.is_farm_speed_item("farm_speed_talisman"), "farm speed talisman is recognized")
	_check(game_state.plant_farm_slot(0, "herb"), "planting a farm slot succeeds")
	_check(game_state.inventory_item_count("herb") == 1, "planting consumes one seed")
	game_state.update_farm(30.0)
	_check(str(game_state.farm_slots[0].get("status", "")) == "growing", "crop remains growing before maturity")
	_check(game_state.inventory_item_count("herb") == 1, "growing crop output is not yet in backpack")
	_check(game_state.use_farm_speed_item("farm_speed_talisman"), "farm speed item can be consumed")
	_check(game_state.farm_speed_multiplier() == 2.0, "farm speed buff doubles growth speed")
	game_state.update_farm(15.0)
	_check(str(game_state.farm_slots[0].get("status", "")) == "ready", "speed buff advances crop to ready")
	_check(game_state.inventory_item_count("herb") == 1, "ready crop output stays in farm slot")
	_check(game_state.claim_farm_slot(0), "ready farm slot can be claimed")
	_check(game_state.inventory_item_count("herb") == 4, "claimed harvest enters backpack with seed yield")
	_check(str(game_state.farm_slots[0].get("status", "")) == "empty", "claimed farm slot becomes empty")
	var saved := game_state.to_save_data()
	var restored = GameStateScript.new()
	restored.load_save_data(saved)
	_check(restored.farm_slots.size() == 5, "farm slots roundtrip through save data")
	_check(restored.farm_speed_buffs.size() == 1, "farm speed buffs roundtrip through save data")


func _test_queue_modules_removed() -> void:
	var removed_game_scripts := ["task" + "_manager.gd", "zone" + "_manager.gd"]
	for script_name in removed_game_scripts:
		_check(not FileAccess.file_exists("res://scripts/game/%s" % script_name), "%s is removed" % script_name)
	_check(GameDefs.TaskType.FIGHT >= 0, "task type enum remains for direct HUD actions")


func _test_home_map_node_mapping_and_farm_slots() -> void:
	_check(HomeMapScript.task_type_for_node("meditate") == GameDefs.TaskType.MEDITATE, "home meditate node maps to meditate")
	_check(HomeMapScript.task_type_for_node("forge") == GameDefs.TaskType.FORGE, "home forge node maps to forge")
	_check(HomeMapScript.task_type_for_node("alchemy") == GameDefs.TaskType.ALCHEMY, "home alchemy node maps to alchemy")
	_check(HomeMapScript.task_type_for_node("farmland") == GameDefs.TaskType.FARM, "home farmland node maps to farm")
	_check(HomeMapScript.task_type_for_node("fight") == GameDefs.TaskType.FIGHT, "future fight node maps to fight panel")

	var home_map = HomeMapScene.instantiate()
	for action_name in ["meditate", "alchemy", "forge", "fight"]:
		var scene_action_node := home_map.get_node(action_name) as CanvasItem
		_check(scene_action_node.material is ShaderMaterial and (scene_action_node.material as ShaderMaterial).shader == HomeMapScript.OUTLINE_HIGHLIGHT_SHADER, "%s building has scene-bound outline shader material" % action_name)

	for action_name in ["meditate", "alchemy", "forge", "farmland", "fight"]:
		var scene_action_area := home_map.get_node("%s/Area2D" % action_name) as Area2D
		_check(scene_action_area.mouse_entered.is_connected(Callable(home_map, "_on_%s_area_mouse_entered" % action_name)), "%s Area2D scene mouse enter signal is connected" % action_name)
		_check(scene_action_area.mouse_exited.is_connected(Callable(home_map, "_on_%s_area_mouse_exited" % action_name)), "%s Area2D scene mouse exit signal is connected" % action_name)

	get_root().add_child(home_map)
	home_map.setup_home_map()
	var floor := home_map.get_node("floor") as CanvasItem
	_check(floor.z_index == 0, "home floor uses lowest z index")
	for action_name in ["meditate", "alchemy", "forge", "farmland", "fight"]:
		var z_action_node := home_map.get_node(action_name) as CanvasItem
		_check(z_action_node.z_index == 10, "%s building uses middle z index" % action_name)
	for action_name in ["meditate", "alchemy", "forge", "fight"]:
		var action_node := home_map.get_node(action_name) as CanvasItem
		var action_area := action_node.get_node("Area2D") as Area2D
		_check(action_area.visible, "%s Area2D is visible for mouse hover" % action_name)
		_check(action_area.input_pickable, "%s Area2D is input pickable" % action_name)
		_check(not action_area.mouse_entered.is_connected(Callable(home_map, "_on_action_area_mouse_entered").bind(action_name)), "%s Area2D does not rely on dynamic mouse enter connection" % action_name)
		_check(not action_area.mouse_exited.is_connected(Callable(home_map, "_on_action_area_mouse_exited").bind(action_name)), "%s Area2D does not rely on dynamic mouse exit connection" % action_name)
		_check(action_node.material is ShaderMaterial and (action_node.material as ShaderMaterial).shader == HomeMapScript.OUTLINE_HIGHLIGHT_SHADER, "%s building binds outline shader material" % action_name)

	var fight := home_map.get_node_or_null("fight") as CanvasItem
	_check(fight != null, "home fight building exists for fight action")
	_check(fight != null and fight.material is ShaderMaterial, "home fight building has outline shader material bound after setup")
	if fight != null:
		var fight_area := fight.get_node("Area2D") as Area2D
		fight_area.mouse_entered.emit()
		_check(fight.material.get_shader_parameter("outline_enabled") == true, "home fight building enables outline shader on mouse hover")
		fight_area.mouse_exited.emit()
		_check(fight.material.get_shader_parameter("outline_enabled") == false, "home fight building disables outline shader on mouse exit")

	var forge := home_map.get_node("forge") as CanvasItem
	_check(forge.material is ShaderMaterial, "home action node has outline shader material bound after setup")
	_check(forge.material.get_shader_parameter("outline_enabled") == false, "home action outline shader starts disabled")
	var forge_area := forge.get_node("Area2D") as Area2D
	forge_area.mouse_entered.emit()
	_check(forge.material.get_shader_parameter("outline_enabled") == true, "home action node enables outline shader on mouse hover")
	forge_area.mouse_exited.emit()
	_check(forge.material is ShaderMaterial and forge.material.get_shader_parameter("outline_enabled") == false, "home action node disables outline shader on mouse exit")
	var forge_original_scale: Vector2 = forge.scale
	var hover_motion := InputEventMouseMotion.new()
	forge_area.input_event.emit(null, hover_motion, 0)
	_check(forge.scale != forge_original_scale, "home action node highlights through mouse motion input event")
	_check(forge.z_index == 15, "home action hover stays between building and character z index")
	forge_area.mouse_exited.emit()
	var farmland := home_map.get_node("farmland") as CanvasItem
	_check(farmland.material is ShaderMaterial, "farmland has outline shader material bound after setup")
	var farmland_rect := home_map.get_node("farmland/ColorRect") as CanvasItem
	var crop_area := home_map.get_node("farmland/crop/Area2D") as Area2D
	crop_area.mouse_entered.emit()
	_check(farmland.material.get_shader_parameter("outline_enabled") == true, "crop hover enables outline shader on farmland action")
	_check(farmland_rect.material is ShaderMaterial, "farmland visual child also receives outline shader")
	crop_area.mouse_exited.emit()
	_check(home_map.farm_slot_count() == 5, "home map exposes five farm slots")
	home_map.show_farm_crops("herb", 8)
	_check(home_map.active_crop_count() == 5, "farm crop display is capped to five slots")
	home_map.show_farm_crops("rice", 2)
	_check(home_map.active_crop_count() == 2, "farm crop display refreshes to current amount")
	var first_crop := home_map.get_node_or_null("farmland/crop_1")
	_check(first_crop != null and first_crop.get_meta("crop_id") == "rice", "farm crop node stores displayed crop id")
	home_map.queue_free()


func _test_battle_map_expedition_spawns_monsters() -> void:
	var battle_map = BattleMapScene.instantiate()
	get_root().add_child(battle_map)
	_check(not battle_map.visible, "battle map starts hidden")

	var spawn_events := []
	battle_map.monster_spawn_requested.connect(func(): spawn_events.append(true))
	battle_map.enter_expedition()
	_check(battle_map.visible, "battle map shows when expedition starts")
	_check(battle_map.is_expedition_active(), "battle map tracks active expedition")
	_check(battle_map.next_spawn_time >= battle_map.spawn_interval_min, "spawn timer uses minimum interval")
	_check(battle_map.next_spawn_time <= battle_map.spawn_interval_max, "spawn timer uses maximum interval")

	var initial_ground_x: float = battle_map.ground_layer.position.x
	battle_map.advance(0.25)
	_check(battle_map.ground_layer.position.x != initial_ground_x, "battle map ground scrolls while running")

	battle_map.next_spawn_time = 0.01
	battle_map.spawn_timer = 0.0
	battle_map.advance(0.02)
	_check(spawn_events.size() == 1, "battle map requests monster after random wait")
	_check(battle_map.is_waiting_for_combat(), "battle map waits for combat after spawn request")

	battle_map.finish_combat()
	_check(not battle_map.is_waiting_for_combat(), "battle map resumes route after combat finishes")
	_check(battle_map.next_spawn_time >= battle_map.spawn_interval_min, "battle map schedules another random spawn after combat")
	spawn_events.clear()
	battle_map.advance(0.02)
	_check(spawn_events.is_empty(), "battle map does not immediately chain spawn after combat")
	battle_map.queue_free()


func _test_main_scene_enters_expedition_before_combat() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	var battle_map = main.get_node_or_null("BattleMap")
	var home = main.get_node_or_null("Home")
	var combat = main.get_node_or_null("CombatController")
	var character = main.get_node_or_null("CharacterController")
	_check(battle_map != null and not battle_map.visible, "main battle map starts hidden")

	main._on_home_action_requested(GameDefs.TaskType.FIGHT)
	_check(home != null and not home.visible, "starting fight hides home map")
	_check(battle_map != null and battle_map.visible, "starting fight opens expedition map")
	_check(combat != null and not combat.active, "expedition starts before first monster combat")
	_check(character != null and character.sprite.animation == &"run", "expedition uses character run animation")

	battle_map.next_spawn_time = 0.01
	battle_map.spawn_timer = 0.0
	battle_map.advance(0.02)
	_check(combat.active, "main starts combat when battle map requests a monster")

	combat.active = false
	combat.finished = true
	main._process(0.02)
	_check(battle_map.visible, "battle map remains visible after one combat")
	_check(home != null and not home.visible, "home stays hidden while expedition continues")
	_check(not battle_map.is_waiting_for_combat(), "battle map schedules next monster after combat result")
	_check(character.sprite.animation == &"run", "character keeps running after combat result")
	main.queue_free()


func _test_hud_uses_scene_nodes() -> void:
	var hud = HudScene.instantiate()
	get_root().add_child(hud)
	var root := hud.get_node("Root") as Control
	_check(root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "hud root ignores background mouse events for home hover")
	_check(hud.get_node_or_null("Root/MenuButton") != null, "hud main menu button is a scene node")
	var menu_panel := hud.get_node_or_null("Root/MenuPanel")
	_check(menu_panel != null and menu_panel.visible == false, "hud secondary menu starts hidden")
	var character_info_button := hud.get_node_or_null("Root/MenuPanel/MenuLayout/CharacterInfoButton") as Button
	var inventory_button := hud.get_node_or_null("Root/MenuPanel/MenuLayout/InventoryButton") as Button
	_check(character_info_button != null and character_info_button.text == "信息", "secondary menu exposes info button")
	_check(inventory_button != null and inventory_button.text == "背包", "secondary menu exposes inventory button")
	var attribute_grid := hud.get_node_or_null("Root/CharacterInfoPanel/PanelLayout/AttributeGrid") as GridContainer
	var equipment_grid := hud.get_node_or_null("Root/CharacterInfoPanel/PanelLayout/EquipmentGrid") as GridContainer
	var skill_grid := hud.get_node_or_null("Root/CharacterInfoPanel/PanelLayout/SkillGrid") as GridContainer
	_check(attribute_grid != null, "character info panel exposes attribute grid")
	_check(equipment_grid != null, "character info panel exposes equipment grid")
	_check(skill_grid != null, "character info panel exposes skill grid")
	_check(hud.get_node_or_null("Root/CharacterInfoPanel/PanelLayout/StatusLabel") == null, "character info panel no longer uses status label")
	var inventory_grid := hud.get_node_or_null("Root/InventoryPanel/InventoryLayout/InventoryGrid") as GridContainer
	_check(inventory_grid != null, "inventory panel exposes a grid UI")
	_check(hud.get_node_or_null("Root/InventoryPanel/InventoryLayout/InventoryItemDetailPanel") != null, "inventory panel exposes hover detail UI")
	_check(hud.get_node_or_null("Root/FarmPanel/PanelLayout/SeedSlotButton") != null, "farm panel exposes seed selector")
	_check(hud.get_node_or_null("Root/FarmPanel/PanelLayout/FarmSlotList") != null, "farm panel exposes farm slot list")
	_check(hud.get_node_or_null("Root/FarmPanel/PanelLayout/SpeedItemSlotButton") != null, "farm panel exposes speed item selector")
	_check(hud.get_node_or_null("Root/FarmPanel/PanelLayout/ActionRow/PlantButton") != null, "farm panel exposes plant button")
	_check(hud.get_node_or_null("Root/FarmPanel/PanelLayout/ActionRow/ClaimButton") != null, "farm panel exposes claim button")
	_check(hud.get_node_or_null("Root/FarmPanel/PanelLayout/ActionRow/ClaimAllButton") != null, "farm panel exposes claim all button")
	_check(hud.get_node_or_null("Root/ForgePanel/PanelLayout/ExecuteButton") != null, "forge panel is a separate UI")
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/RecipeSlotButton") != null, "alchemy panel exposes recipe slot")
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/RecipePickerPanel") != null, "alchemy panel exposes embedded recipe picker")
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/RecipePickerPanel/RecipeList") != null, "alchemy panel exposes recipe list")
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/MaterialGrid") != null, "alchemy panel exposes material grid")
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/CraftCountSpinBox") != null, "alchemy panel exposes craft count spin box")
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/CraftButton") != null, "alchemy panel exposes craft button")
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/MaxCountLabel") != null, "alchemy panel exposes max count label")
	_check(hud.get_node_or_null("Root/MeditatePanel/PanelLayout/ExecuteButton") != null, "meditate panel is a separate UI")
	_check(hud.get_node_or_null("Root/FightPanel/PanelLayout/ExecuteButton") != null, "fight panel is a separate UI for future building")
	_check(hud.get_node_or_null("Root/MenuPanel/MenuLayout/ButtonRow") == null, "secondary menu does not contain task action buttons")
	_check(hud.get_node_or_null("Root/MenuPanel/MenuLayout/InventorySection") == null, "secondary menu does not embed inventory UI directly")
	_check(hud.get_node_or_null("Root/InventoryPanel/InventoryLayout/InventoryList") == null, "inventory panel no longer uses item list as main UI")
	_check(hud.get_node_or_null("Root/MenuPanel/MenuLayout/PersonalInfo") == null, "secondary menu does not embed character info directly")
	_check(hud.get_node_or_null("Root/TopPanel") == null, "hud no longer exposes top panel actions on main screen")
	_check(hud.get_node_or_null("Root/HomeActionPanel") == null, "generic home action panel is replaced by action-specific panels")
	var game_state = GameStateScript.new()
	game_state.add_inventory_item("might_pill", 1, false)
	var info_weapon := DataTables.create_equipment_from_template("weapon", 1, RandomNumberGenerator.new(), 0, "neutral", "t1")
	info_weapon["equip_requirement"] = {}
	game_state.add_equipment(info_weapon)
	game_state.use_inventory_item(info_weapon["instance_id"])
	hud.refresh(game_state)
	_check(attribute_grid.get_child_count() >= 18, "character attributes refresh into grid rows")
	_check(_control_tree_text(attribute_grid).contains("HP") and _control_tree_text(attribute_grid).contains("攻击"), "attribute grid shows core stats")
	_check(equipment_grid.get_child_count() == 7, "equipment grid creates fixed equipment slots")
	var weapon_slot := equipment_grid.get_child(0) as Control
	_check(weapon_slot != null and weapon_slot.get_node_or_null("SlotLayout/IconPlaceholder") != null, "equipment slot reserves icon placeholder")
	_check(_control_tree_text(weapon_slot).contains(info_weapon["name"]), "equipment slot shows equipped item name")
	_check(_control_tree_text(equipment_grid).contains("未装备"), "empty equipment slots show unequipped state")
	_check(skill_grid.get_child_count() >= 1, "skill grid creates learned skill slots")
	var first_skill_slot := skill_grid.get_child(0) as Control
	_check(first_skill_slot != null and first_skill_slot.get_node_or_null("SlotLayout/IconPlaceholder") != null, "skill slot reserves icon placeholder")
	_check(_control_tree_text(skill_grid).contains("灵火术"), "skill grid shows learned skill name")
	var character_info_panel := hud.get_node("Root/CharacterInfoPanel") as Control
	var inventory_panel := hud.get_node("Root/InventoryPanel") as Control
	menu_panel.visible = true
	character_info_button.pressed.emit()
	_check(character_info_panel.visible and not inventory_panel.visible and not menu_panel.visible, "info button opens character info panel")
	menu_panel.visible = true
	inventory_button.pressed.emit()
	hud._set_inventory_category(DataTables.ITEM_TYPE_PILL)
	_check(inventory_panel.visible and not character_info_panel.visible and not menu_panel.visible, "inventory button opens inventory panel")
	_check(inventory_grid.get_child_count() == 25, "inventory grid creates twenty five slots")
	var first_slot := inventory_grid.get_child(0) as Button
	_check(first_slot != null and first_slot.get_node_or_null("SlotLayout/IconPlaceholder") != null, "inventory slot reserves icon placeholder")
	hud._on_inventory_slot_mouse_entered(0)
	var detail_panel := hud.get_node("Root/InventoryPanel/InventoryLayout/InventoryItemDetailPanel") as Control
	var detail_label := hud.get_node("Root/InventoryPanel/InventoryLayout/InventoryItemDetailPanel/DetailLabel") as Label
	_check(detail_panel.visible and detail_label.text.length() > 0, "hovering inventory item shows detail panel")
	var pill_count_before := game_state.inventory_item_count("might_pill")
	hud._on_inventory_slot_pressed(0)
	hud._on_inventory_slot_pressed(0)
	_check(game_state.inventory_item_count("might_pill") < pill_count_before, "double clicking pill slot directly uses pill")
	game_state.add_inventory_item("recipe_attack_pill", 1, false)
	hud._set_inventory_category(DataTables.ITEM_TYPE_ALCHEMY_RECIPE)
	hud._on_inventory_slot_pressed(0)
	hud._on_inventory_slot_pressed(0)
	_check(game_state.inventory_item_count("recipe_attack_pill") == 1 and not game_state.known_alchemy_recipes.has("attack_pill"), "double clicking recipe slot does not directly learn recipe")

	var farm_panel := hud.get_node("Root/FarmPanel") as Control
	var forge_panel := hud.get_node("Root/ForgePanel") as Control
	_check(hud.get_node_or_null("Root/FarmPanel/PanelLayout/ProgressLabel") != null, "farm panel includes progress label")
	_check(hud.get_node_or_null("Root/ForgePanel/PanelLayout/ProgressLabel") != null, "forge panel includes progress label")
	hud.load_hud_save_data({"panel_positions": {"FarmPanel": {"x": 111.0, "y": 77.0}}})
	hud.show_home_action_panel(GameDefs.TaskType.FARM)
	_check(farm_panel.visible and not forge_panel.visible, "opening a home action shows only its matching panel")
	_check(farm_panel.position == Vector2(111.0, 77.0), "home action panel opens at saved position")
	hud.load_hud_save_data({"panel_positions": {"InventoryPanel": {"x": 5000.0, "y": 5000.0}}})
	hud._open_inventory_panel()
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 480))
	)
	_check(inventory_panel.position.x + inventory_panel.size.x <= viewport_size.x, "saved hud x position is clamped inside viewport")
	_check(inventory_panel.position.y + inventory_panel.size.y <= viewport_size.y, "saved hud y position is clamped inside viewport")
	inventory_panel.position = Vector2(144.0, 88.0)
	var hud_save: Dictionary = hud.to_hud_save_data()
	_check(hud_save.get("panel_positions", {}).get("InventoryPanel", {}).get("x", 0.0) == 144.0, "hud save data stores dragged panel x position")

	game_state.inventory.clear()
	game_state.known_alchemy_recipes.append("attack_pill")
	game_state.add_inventory_item("blade_grass", 4, false)
	game_state.add_inventory_item("rice", 2, false)
	game_state.add_inventory_item("stat_stone_attack_t1", 2, false)
	hud.refresh(game_state)
	hud.show_home_action_panel(GameDefs.TaskType.ALCHEMY)
	var recipe_slot := hud.get_node("Root/AlchemyPanel/PanelLayout/RecipeSlotButton") as Button
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/ProgressLabel") != null, "alchemy panel includes progress label")
	var recipe_picker := hud.get_node("Root/AlchemyPanel/PanelLayout/RecipePickerPanel") as Control
	var recipe_list := hud.get_node("Root/AlchemyPanel/PanelLayout/RecipePickerPanel/RecipeList") as ItemList
	var material_grid := hud.get_node("Root/AlchemyPanel/PanelLayout/MaterialGrid") as GridContainer
	var craft_count := hud.get_node("Root/AlchemyPanel/PanelLayout/CraftCountSpinBox") as SpinBox
	var craft_button := hud.get_node("Root/AlchemyPanel/PanelLayout/CraftButton") as Button
	recipe_slot.pressed.emit()
	_check(recipe_picker.visible and recipe_list.item_count == 1, "recipe slot opens embedded recipe list")
	_check(str(recipe_list.get_item_metadata(0)) == "attack_pill", "alchemy recipe list uses learned recipes instead of backpack recipes")
	recipe_list.select(0)
	hud._on_alchemy_recipe_selected(0)
	_check(not recipe_picker.visible and recipe_slot.text == "破军丹", "selecting a recipe updates slot label")
	_check(material_grid.get_child_count() == 3, "selecting a recipe refreshes material slots")
	var first_count := material_grid.get_child(0).get_node("SlotLayout/CountLabel") as Label
	_check(first_count.text == "4/2", "material slot shows current and required count")
	_check(int(craft_count.max_value) == 2 and int(craft_count.value) == 2, "craft count defaults to max craftable amount")
	_check(not craft_button.disabled, "craft button is enabled when materials are enough")
	craft_button.pressed.emit()
	_check(game_state.inventory_item_count("attack_pill") >= 2, "craft button batch crafts selected recipe")
	hud.queue_free()


func _test_character_gravity() -> void:
	var character = CharacterScene.instantiate()
	get_root().add_child(character)
	character.setup()
	character.position.y = character.BASELINE_Y - 48.0
	character.vertical_velocity = 0.0
	character._process(0.1)
	_check(character.position.y > character.BASELINE_Y - 48.0, "gravity pulls character down")
	for _step in range(30):
		character._process(0.1)
	_check(is_equal_approx(character.position.y, character.BASELINE_Y), "gravity settles character on baseline")
	character.queue_free()


func _test_me_scene_uses_character_body() -> void:
	var me = MeScene.instantiate()
	get_root().add_child(me)
	_check(me is CharacterBody2D, "me scene root is CharacterBody2D")
	_check((me as CanvasItem).z_index == 20, "character uses highest z index")
	_check(me.get_node_or_null("Sprite") is AnimatedSprite2D, "me scene keeps animated sprite as child")
	_check(me.get_node_or_null("CollisionShape2D") is CollisionShape2D, "me scene has body collision shape")
	_check(me.get_node_or_null("Progress" + "Back") == null, "me scene no longer has progress UI")
	me.queue_free()


func _test_character_reference_chain_uses_me_scene() -> void:
	var character = CharacterScene.instantiate()
	_check(character is CharacterBody2D, "compat character scene root is CharacterBody2D")
	_check(character.get_node_or_null("Sprite") is AnimatedSprite2D, "compat character scene exposes sprite directly")
	character.queue_free()

	var main = MainScene.instantiate()
	var main_character = main.get_node_or_null("CharacterController")
	_check(main_character is CharacterBody2D, "main scene character node is CharacterBody2D")
	_check(main_character != null and main_character.scene_file_path == "res://scripts/character/me.tscn", "main scene references me scene directly")
	main.queue_free()


func _test_equipment_slots_strengthening_and_affixes() -> void:
	var game_state = GameStateScript.new()
	_check(game_state.equipped.has("helmet"), "helmet slot exists")
	_check(game_state.equipped.has("accessory_2"), "second accessory slot exists")
	_check(DataTables.EQUIPMENT_DEFS.has("gloves"), "expanded equipment templates exist")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var helmet := DataTables.create_equipment_from_template("helmet", 1, rng)
	game_state.add_equipment(helmet)
	_check(game_state.use_inventory_item(helmet["instance_id"]), "helmet can be equipped")
	_check(game_state.equipped["helmet"] == helmet["instance_id"], "helmet occupies helmet slot")
	var accessory_a := DataTables.create_equipment_from_template("accessory", 1, rng)
	var accessory_b := DataTables.create_equipment_from_template("accessory", 1, rng)
	game_state.add_equipment(accessory_a)
	game_state.add_equipment(accessory_b)
	game_state.use_inventory_item(accessory_a["instance_id"])
	game_state.use_inventory_item(accessory_b["instance_id"])
	_check(not game_state.equipped["accessory_1"].is_empty(), "first accessory slot can be filled")
	_check(not game_state.equipped["accessory_2"].is_empty(), "second accessory slot can be filled")
	var helmet_stat: String = helmet.get("base_attributes", [])[0].get("stat", "element_fire")
	game_state.add_inventory_item(DataTables.spirit_stone_item_id(helmet_stat, "t1"), 4, false)
	_check(game_state.enhance_equipment(helmet["instance_id"]), "equipment can be enhanced with materials")
	_check(helmet.get("enhance_count", 0) == 1, "enhance count increases")
	game_state.add_inventory_item("refine_talisman", 1, false)
	_check(game_state.add_equipment_affix(helmet["instance_id"]), "equipment can gain refine affix")
	_check(helmet.get("refine_affixes", []).size() == 1, "refine affix is stored on equipment")


func _test_equipment_attribute_tiers_stones_and_refine() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_check(DataTables.EQUIPMENT_ATTRIBUTE_DEFS.size() == 10, "equipment attribute template has ten stats")
	for element_id in DataTables.ELEMENT_IDS:
		for tier in DataTables.SPIRIT_STONE_QUALITY_ORDER:
			var item_id := DataTables.spirit_stone_item_id("element_%s" % element_id, tier)
			var stone := DataTables.create_stack_item(item_id, 1)
			_check(not stone.is_empty(), "%s can be dynamically created" % item_id)
	for stat_id in DataTables.STAT_STONE_IDS:
		for tier in DataTables.SPIRIT_STONE_QUALITY_ORDER:
			var item_id := DataTables.stat_stone_item_id(stat_id, tier)
			var stone := DataTables.create_stack_item(item_id, 1)
			_check(not stone.is_empty(), "%s can be dynamically created" % item_id)
	_check(DataTables.spirit_stone_enhance_amount("t1") == 1, "tier one spirit stone enhances by one")
	_check(DataTables.spirit_stone_enhance_amount("t2") == 2, "tier two spirit stone enhances by two")
	_check(DataTables.spirit_stone_enhance_amount("t3") == 4, "tier three spirit stone enhances by four")
	_check(DataTables.spirit_stone_enhance_amount("t4") == 7, "tier four spirit stone enhances by seven")
	_check(DataTables.spirit_stone_enhance_amount("t5") == 11, "tier five spirit stone enhances by eleven")
	_check(DataTables.stat_stone_enhance_amount("t5") == 11, "stat stones use the same five tier values")
	_check(DataTables.equipment_rarity_multiplier("t5") > DataTables.equipment_rarity_multiplier("t1"), "high tier equipment has stronger attribute multiplier")
	_check(DataTables.neutral_weapon_multiplier("t1") > DataTables.equipment_rarity_multiplier("t1"), "neutral weapons have stronger direct attack multiplier")
	var level_one := DataTables.create_equipment_from_template("weapon", 1, rng)
	var tier_two := DataTables.create_equipment_from_template("weapon", 3, rng, 0, "fire", "t2")
	var tier_four := DataTables.create_equipment_from_template("weapon", 9, rng, 0, "fire", "t4")
	_check(DataTables.EQUIPMENT_RARITY_DEFS.has(level_one.get("rarity", "")), "equipment rarity is one of five tiers")
	_check(level_one.get("name", "").contains("·"), "equipment name uses five element tier format")
	_check(level_one.get("name", "").contains(DataTables.slot_name("weapon")), "equipment name includes slot name")
	_check(level_one.get("base_attributes", []).size() == DataTables.equipment_attribute_count_for_rarity(level_one.get("rarity", "t1")), "equipment attribute count follows rarity")
	_check(tier_two.get("base_attributes", []).size() == 2, "tier two creates two base attributes")
	_check(tier_four.get("base_attributes", []).size() == 4, "tier four creates four base attributes")
	var seen := {}
	for attribute in tier_four.get("base_attributes", []):
		seen[attribute.get("stat", "")] = true
	_check(seen.size() == tier_four.get("base_attributes", []).size(), "base attributes are unique")
	_check(_attribute_amount(tier_four, "element_fire") > 0, "tier four elemental weapon includes forced element attribute")
	var neutral_weapon := DataTables.create_equipment_from_template("weapon", 1, rng, 0, "neutral", "t4")
	var fire_weapon := DataTables.create_equipment_from_template("weapon", 1, rng, 0, "fire", "t4")
	_check(neutral_weapon.get("element", "") == "neutral", "neutral weapon stores neutral element")
	_check(neutral_weapon.get("name", "").begins_with("无相·"), "neutral weapon uses no-element name")
	_check(neutral_weapon.get("base_attributes", []).size() == 4, "tier four neutral weapon has four attributes")
	_check(_attribute_amount(neutral_weapon, "attack") > 0, "neutral weapon has attack base attribute")
	_check(_attribute_amount(neutral_weapon, "element_fire") == 0, "neutral weapon does not force element base attribute")
	_check(_attribute_amount(neutral_weapon, "attack") > _attribute_amount(fire_weapon, "attack"), "neutral weapon has higher direct attack than elemental weapon")
	var low_level_rng := RandomNumberGenerator.new()
	low_level_rng.seed = 1001
	var high_level_rng := RandomNumberGenerator.new()
	high_level_rng.seed = 1001
	var low_level_weapon := DataTables.create_equipment_from_template("weapon", 1, low_level_rng, 0, "neutral", "t3")
	var high_level_weapon := DataTables.create_equipment_from_template("weapon", 10, high_level_rng, 0, "neutral", "t3")
	_check(_attribute_amount(high_level_weapon, "attack") > _attribute_amount(low_level_weapon, "attack"), "equipment level adds extra attribute points")
	_check(neutral_weapon.get("attack_bonus", 0) == _attribute_amount(neutral_weapon, "attack"), "attack bonus mirrors current base attack attribute")

	var game_state = GameStateScript.new()
	game_state.inventory.clear()
	var item := DataTables.create_equipment_from_template("weapon", 1, rng)
	item["base_attributes"] = [{"stat": "element_fire", "amount": 5}]
	item["attack_bonus"] = 0
	item["defense_bonus"] = 0
	game_state.add_equipment(item)
	game_state.use_inventory_item(item["instance_id"])
	var fire_before := game_state.total_element("fire")
	game_state.add_inventory_item("spirit_stone_water_t1", 3, false)
	_check(not game_state.enhance_equipment(item["instance_id"]), "enhance rejects stones for missing base attribute")
	game_state.add_inventory_item("spirit_stone_fire_t1", 3, false)
	_check(game_state.enhance_equipment(item["instance_id"]), "enhance consumes matching attribute stone")
	_check(item.get("enhance_count", 0) == 1, "enhance count is tracked")
	_check(game_state.inventory_item_count("spirit_stone_fire_t1") == 2, "first enhance consumes one stone")
	_check(game_state.total_element("fire") > fire_before, "enhanced element attribute contributes to total element")

	var neutral_state = GameStateScript.new()
	neutral_state.inventory.clear()
	neutral_state.add_equipment(neutral_weapon)
	neutral_state.use_inventory_item(neutral_weapon["instance_id"])
	var attack_before := neutral_state.total_attack()
	neutral_state.add_inventory_item("spirit_stone_fire_t1", 3, false)
	_check(not neutral_state.enhance_equipment(neutral_weapon["instance_id"]), "neutral weapon rejects missing element stone")
	neutral_state.add_inventory_item("stat_stone_attack_t1", 3, false)
	_check(neutral_state.enhance_equipment(neutral_weapon["instance_id"]), "neutral weapon enhances with attack stat stone")
	_check(neutral_state.total_attack() > attack_before, "stat stone enhancement contributes to direct attack")
	game_state.add_inventory_item("refine_talisman", 3, false)
	_check(game_state.add_equipment_affix(item["instance_id"]), "refine consumes talisman and adds percent affix")
	_check(item.get("refine_count", 0) == 1, "refine count is tracked")
	_check(game_state.inventory_item_count("refine_talisman") == 2, "first refine consumes one talisman")
	_check(item.get("refine_affixes", []).size() == 1, "refine affix is stored separately")


func _test_equipment_equip_requirements() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var fire_weapon := DataTables.create_equipment_from_template("weapon", 3, rng, 0, "fire", "t2")
	var requirement: Dictionary = fire_weapon.get("equip_requirement", {})
	_check(requirement.get("stat", "") == "element_fire", "elemental equipment requires matching element")
	_check(int(requirement.get("min", 0)) == 6, "equipment requirement scales by level and rarity tier")
	var weak_state = GameStateScript.new()
	weak_state.inventory.clear()
	weak_state.elements["fire"] = 1
	weak_state.add_equipment(fire_weapon)
	_check(not weak_state.use_inventory_item(fire_weapon["instance_id"]), "equipment cannot be equipped below requirement")
	_check(weak_state.equipped["weapon"].is_empty(), "failed requirement does not change equipped slot")

	var strong_state = GameStateScript.new()
	strong_state.inventory.clear()
	strong_state.elements["fire"] = 6
	strong_state.add_equipment(fire_weapon.duplicate(true))
	_check(strong_state.use_inventory_item(fire_weapon["instance_id"]), "equipment can be equipped when requirement is met")
	_check(strong_state.equipped["weapon"] == fire_weapon["instance_id"], "met requirement equips item")

	var neutral_weapon := DataTables.create_equipment_from_template("weapon", 4, rng, 0, "neutral", "t3")
	var neutral_requirement: Dictionary = neutral_weapon.get("equip_requirement", {})
	_check(neutral_requirement.get("stat", "") == "attack", "neutral weapon requires attack")
	var neutral_state = GameStateScript.new()
	neutral_state.inventory.clear()
	neutral_state.stats["attack"] = int(neutral_requirement.get("min", 0))
	neutral_state.add_equipment(neutral_weapon)
	_check(neutral_state.use_inventory_item(neutral_weapon["instance_id"]), "neutral weapon can be equipped with enough attack")

	var old_item := DataTables.create_equipment_from_template("helmet", 1, rng, 0, "earth", "t1")
	old_item.erase("equip_requirement")
	var legacy_state = GameStateScript.new()
	legacy_state.inventory.clear()
	legacy_state.add_equipment(old_item)
	_check(legacy_state.use_inventory_item(old_item["instance_id"]), "legacy equipment without requirement remains equipable")

	var current_weapon := DataTables.create_equipment_from_template("weapon", 1, rng, 0, "neutral", "t1")
	current_weapon["equip_requirement"] = {}
	current_weapon["base_attributes"] = [{"stat": "attack", "amount": 20}]
	current_weapon["attack_bonus"] = 20
	var replacement := DataTables.create_equipment_from_template("weapon", 5, rng, 0, "neutral", "t5")
	replacement["equip_requirement"] = {"stat": "attack", "min": 20}
	replacement["base_attributes"] = [{"stat": "attack", "amount": 1}]
	replacement["attack_bonus"] = 1
	var swap_state = GameStateScript.new()
	swap_state.inventory.clear()
	swap_state.stats["attack"] = 8
	swap_state.add_equipment(current_weapon)
	swap_state.add_equipment(replacement)
	_check(swap_state.use_inventory_item(current_weapon["instance_id"]), "setup equips current weapon")
	_check(not swap_state.use_inventory_item(replacement["instance_id"]), "replacement cannot rely on removed same-slot equipment")
	_check(swap_state.equipped["weapon"] == current_weapon["instance_id"], "failed replacement keeps current equipment")


func _attribute_amount(item: Dictionary, stat_id: String) -> int:
	var value := 0
	for attribute in item.get("base_attributes", []):
		if attribute.get("stat", "") == stat_id:
			value += int(attribute.get("amount", 0))
	return value


func _recipe_material_amount(materials: Array, item_id: String) -> int:
	for material in materials:
		if material.get("item_id", "") == item_id:
			return int(material.get("amount", 0))
	return 0


func _test_enemy_templates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var enemy := DataTables.create_enemy(5, rng)
	_check(enemy.has("template_id"), "enemy instances include template id")
	_check(enemy.has("element_attack_ratio"), "enemy instances include elemental attack ratio")
	_check(DataTables.ENEMY_TEMPLATES.size() >= 3, "enemy template table has multiple templates")


func _test_element_and_physical_reduction() -> void:
	var game_state = GameStateScript.new()
	game_state.stats["defense"] = 5
	game_state.elements["fire"] = 10
	_check(game_state.reduce_physical_damage(12) == 7, "defense reduces physical damage")
	_check(game_state.reduce_element_damage("fire", 12) == 9, "matching element reduces elemental damage")
	_check(game_state.element_damage_bonus("fire") == 5, "element value increases matching damage")

