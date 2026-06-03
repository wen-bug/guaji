extends SceneTree

const GameStateScript = preload("res://scripts/game/game_state.gd")
const ZoneManagerScript = preload("res://scripts/game/zone_manager.gd")
const TaskManagerScript = preload("res://scripts/game/task_manager.gd")
const HomeMapScript = preload("res://scripts/map/home_map.gd")
const HomeMapScene = preload("res://scripts/map/home.tscn")
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
	_test_farm_seeds_and_level_yield()
	_test_home_actions_are_not_queue_tasks()
	_test_home_map_node_mapping_and_farm_slots()
	_test_hud_uses_scene_nodes()
	_test_character_gravity()
	_test_me_scene_uses_character_body()
	_test_character_reference_chain_uses_me_scene()
	_test_equipment_slots_strengthening_and_affixes()
	_test_equipment_attribute_tiers_stones_and_refine()
	_test_enemy_templates()
	_test_element_and_physical_reduction()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)


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
	_check(game_state.use_inventory_item("recipe_pill"), "recipe item can be learned")
	_check(game_state.known_alchemy_recipes.has("pill"), "learned recipe is tracked")
	_check(game_state.inventory_item_count("recipe_pill") == 0, "recipe item is consumed")
	_check(game_state.add_inventory_item("might_pill", 1, false), "duration pill can be added")
	_check(game_state.use_inventory_item("might_pill"), "duration pill can be used")
	_check(game_state.active_buffs.size() == 1, "duration pill creates active buff")
	game_state.update_buffs(999.0)
	_check(game_state.active_buffs.is_empty(), "duration buff expires")


func _test_farm_seeds_and_level_yield() -> void:
	var game_state = GameStateScript.new()
	_check(game_state.stats.has("farm_level"), "farm level exists")
	game_state.stats["farm_level"] = 3
	var result: Dictionary = game_state.consume_seed_for_farm()
	_check(result.get("item_id", "") == "herb", "farm consumes first crop as seed")
	_check(int(result.get("amount", 0)) == 5, "farm level increases seed yield")
	_check(game_state.inventory_item_count("herb") == 3, "seed is consumed before harvest reward")
	game_state.add_task_experience(GameDefs.TaskType.FARM, 25)
	_check(game_state.stats["farm_level"] > 3, "farm proficiency can raise farm level")


func _test_home_actions_are_not_queue_tasks() -> void:
	var game_state = GameStateScript.new()
	var zone_manager = ZoneManagerScript.new()
	var task_manager = TaskManagerScript.new(game_state, zone_manager)
	task_manager.add_task(GameDefs.TaskType.FARM)
	task_manager.add_task(GameDefs.TaskType.FORGE)
	task_manager.add_task(GameDefs.TaskType.ALCHEMY)
	task_manager.add_task(GameDefs.TaskType.MEDITATE)
	task_manager.add_task(GameDefs.TaskType.FIGHT)
	_check(task_manager.queue.is_empty(), "all actions are rejected by the canceled task queue")
	_check(task_manager.current_task.is_empty(), "task manager does not start queued work")


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
	_check(hud.get_node_or_null("Root/CharacterInfoPanel/PanelLayout/StatusLabel") != null, "character info panel is a separate UI")
	_check(hud.get_node_or_null("Root/InventoryPanel/InventoryLayout/InventoryList") != null, "inventory panel is a separate UI")
	_check(hud.get_node_or_null("Root/FarmPanel/PanelLayout/ExecuteButton") != null, "farm panel is a separate UI")
	_check(hud.get_node_or_null("Root/ForgePanel/PanelLayout/ExecuteButton") != null, "forge panel is a separate UI")
	_check(hud.get_node_or_null("Root/AlchemyPanel/PanelLayout/ExecuteButton") != null, "alchemy panel is a separate UI")
	_check(hud.get_node_or_null("Root/MeditatePanel/PanelLayout/ExecuteButton") != null, "meditate panel is a separate UI")
	_check(hud.get_node_or_null("Root/FightPanel/PanelLayout/ExecuteButton") != null, "fight panel is a separate UI for future building")
	_check(hud.get_node_or_null("Root/MenuPanel/MenuLayout/ButtonRow") == null, "secondary menu does not contain task action buttons")
	_check(hud.get_node_or_null("Root/MenuPanel/MenuLayout/InventorySection") == null, "secondary menu does not embed inventory UI directly")
	_check(hud.get_node_or_null("Root/MenuPanel/MenuLayout/PersonalInfo") == null, "secondary menu does not embed character info directly")
	_check(hud.get_node_or_null("Root/TopPanel") == null, "hud no longer exposes top panel actions on main screen")
	_check(hud.get_node_or_null("Root/HomeActionPanel") == null, "generic home action panel is replaced by action-specific panels")
	var character_info_panel := hud.get_node("Root/CharacterInfoPanel") as Control
	var inventory_panel := hud.get_node("Root/InventoryPanel") as Control
	menu_panel.visible = true
	character_info_button.pressed.emit()
	_check(character_info_panel.visible and not inventory_panel.visible and not menu_panel.visible, "info button opens character info panel")
	menu_panel.visible = true
	inventory_button.pressed.emit()
	_check(inventory_panel.visible and not character_info_panel.visible and not menu_panel.visible, "inventory button opens inventory panel")

	var farm_panel := hud.get_node("Root/FarmPanel") as Control
	var forge_panel := hud.get_node("Root/ForgePanel") as Control
	hud.show_home_action_panel(GameDefs.TaskType.FARM)
	_check(farm_panel.visible and not forge_panel.visible, "opening a home action shows only its matching panel")
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
	_check(DataTables.spirit_stone_enhance_amount("t1") == 1, "tier one spirit stone enhances by one")
	_check(DataTables.spirit_stone_enhance_amount("t2") == 2, "tier two spirit stone enhances by two")
	_check(DataTables.spirit_stone_enhance_amount("t3") == 4, "tier three spirit stone enhances by four")
	_check(DataTables.spirit_stone_enhance_amount("t4") == 7, "tier four spirit stone enhances by seven")
	_check(DataTables.spirit_stone_enhance_amount("t5") == 11, "tier five spirit stone enhances by eleven")
	_check(DataTables.equipment_rarity_multiplier("t5") > DataTables.equipment_rarity_multiplier("t1"), "high tier equipment has stronger attribute multiplier")
	var level_one := DataTables.create_equipment_from_template("weapon", 1, rng)
	var level_three := DataTables.create_equipment_from_template("weapon", 3, rng)
	var level_high := DataTables.create_equipment_from_template("weapon", 9, rng)
	_check(DataTables.EQUIPMENT_RARITY_DEFS.has(level_one.get("rarity", "")), "equipment rarity is one of five tiers")
	_check(level_one.get("name", "").contains("·"), "equipment name uses five element tier format")
	_check(level_one.get("name", "").contains(DataTables.slot_name("weapon")), "equipment name includes slot name")
	_check(level_one.get("base_attributes", []).size() == 1, "source level one creates one base attribute")
	_check(level_three.get("base_attributes", []).size() == 3, "source level three creates three base attributes")
	_check(level_high.get("base_attributes", []).size() >= 7 and level_high.get("base_attributes", []).size() <= 10, "high source level creates random upper attribute count")
	var seen := {}
	for attribute in level_high.get("base_attributes", []):
		seen[attribute.get("stat", "")] = true
	_check(seen.size() == level_high.get("base_attributes", []).size(), "base attributes are unique")

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
	game_state.add_inventory_item("refine_talisman", 3, false)
	_check(game_state.add_equipment_affix(item["instance_id"]), "refine consumes talisman and adds percent affix")
	_check(item.get("refine_count", 0) == 1, "refine count is tracked")
	_check(game_state.inventory_item_count("refine_talisman") == 2, "first refine consumes one talisman")
	_check(item.get("refine_affixes", []).size() == 1, "refine affix is stored separately")


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

