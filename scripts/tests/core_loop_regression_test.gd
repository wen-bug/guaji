extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_building_level_cap()
	_check_drop_layers()
	_check_stage_2_progression()
	_check_stage_3_equipment_loop()
	_check_stage_4_skills_and_pills()
	_check_stage_5_enemies()
	if failures.is_empty():
		print("CORE_LOOP_STAGE_5_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _fresh_state() -> GameState:
	var state := GameState.new()
	state.inventory.clear()
	state.companions.clear()
	state.party_order.clear()
	state.reserve_order.clear()
	state.recruit_candidates.clear()
	state.known_alchemy_recipes.clear()
	state.rng.seed = 173
	return state


func _check_building_level_cap() -> void:
	var state := _fresh_state()
	_expect_equal("level 1 building cap", state.building_level_cap(), 1)
	_expect_equal("level 2 building requirement", state.building_level_requirement(2), 6)
	state.add_inventory_item("ore", 100, false)
	_expect_true("building blocked at expedition 1", not state.upgrade_building("forge"))
	_expect_equal("blocked upgrade spends no ore", state.inventory_item_count("ore"), 100)
	state.account_progression["expedition_level"] = 6
	_expect_equal("level 6 building cap", state.building_level_cap(), 2)
	_expect_true("building upgrade opens at expedition 6", state.upgrade_building("forge"))
	state.building_levels["forge"] = 7
	state.account_progression["expedition_level"] = 11
	_expect_equal("grandfathered building remains above cap", state.building_level("forge"), 7)
	_expect_true("grandfathered building cannot advance", not state.upgrade_building("forge"))
	_expect_equal("level 46 building cap", _building_cap_at(state, 46), 10)


func _building_cap_at(state: GameState, expedition_level: int) -> int:
	state.account_progression["expedition_level"] = expedition_level
	return state.building_level_cap()


func _check_drop_layers() -> void:
	var state := _fresh_state()
	var controller := CombatController.new()
	controller.enemy = DataTables.create_enemy(1, state.rng, "forest_wolf")
	_expect_true("forest wolf class pool enabled", bool(controller.enemy.get("use_class_drop_pool", false)))
	_expect_true("forest wolf rank pool disabled", not bool(controller.enemy.get("use_rank_drop_pool", true)))
	_expect_approx("forest wolf equipment rate", float(controller.enemy.get("equipment_drop_chance", 0.0)), 0.05)
	controller.enemy["class_drop_profile"] = {
		"mode": "independent",
		"entries": [{"item_id": "herb", "chance": 1.0, "amount": 1}],
	}
	controller.enemy["drop_profile"] = {
		"base_chance": 1.0,
		"items": ["herb"],
		"rarity_weights": {"t1": 100},
	}
	controller.enemy["drops"] = {"herb": {"chance": 1.0, "min": 1, "max": 1}}
	controller.enemy["use_rank_drop_pool"] = true
	controller._resolve_drops(state)
	_expect_equal("overlapping drop sources award item once", state.inventory_item_count("herb"), 1)


func _check_stage_2_progression() -> void:
	var state := _fresh_state()
	state.building_levels["recruit"] = 7
	state.account_progression["expedition_level"] = 46
	state.generate_recruit_candidates(false)
	var candidate: Dictionary = state.recruit_candidates[0]
	var candidate_stats: Dictionary = candidate.get("stats", {})
	_expect_equal("candidate level follows recruit building", int(candidate_stats.get("level", 0)), 7)
	_expect_equal("candidate stage initialized", int(candidate_stats.get("stage", 0)), 1)
	_expect_equal("candidate cap initialized", int(candidate_stats.get("level_cap", 0)), 10)
	_expect_equal("candidate next exp initialized", int(candidate_stats.get("next_exp", 0)), state.party_service.next_exp_for_level(7))

	candidate["kind"] = "companion"
	state.companions.append(candidate)
	state.party_order.append(str(candidate.get("id", "")))
	candidate_stats["level"] = 10
	candidate_stats["level_cap"] = 10
	candidate_stats["stage"] = 1
	candidate_stats["root_bone"] = 999
	candidate_stats["exp"] = 0
	candidate_stats["next_exp"] = state.party_service.next_exp_for_level(10)
	state.add_exp_for_member(str(candidate.get("id", "")), int(candidate_stats["next_exp"]))
	_expect_equal("root bone cannot break through", int(candidate_stats.get("level_cap", 0)), 10)
	_expect_equal("member remains at cap without pill", int(candidate_stats.get("level", 0)), 10)
	state.add_inventory_item("breakthrough_pill", 1, false)
	var pill_instance_id := ""
	for item in state.inventory:
		if str(item.get("item_id", "")) == "breakthrough_pill":
			pill_instance_id = str(item.get("instance_id", ""))
	_expect_true("breakthrough pill can be used", state.use_inventory_item_for_member(pill_instance_id, str(candidate.get("id", ""))))
	_expect_equal("pill raises level cap", int(candidate_stats.get("level_cap", 0)), 20)
	_expect_equal("pill raises stage", int(candidate_stats.get("stage", 0)), 2)

	var equipment := DataTables.create_equipment_from_template("weapon_metal_sword", 99, state.rng, 0, "", "t5", "test")
	_expect_equal("new equipment ignores expedition level", int(equipment.get("equipment_level", 0)), 1)
	_expect_true("tier five has no equip requirement", equipment.get("equip_requirement", {}).is_empty())

	var migrated := _fresh_state()
	migrated.load_save_data({
		"schema_version": 13,
		"inventory": [{
			"instance_id": "legacy-weapon",
			"item_id": "weapon",
			"type": DataTables.ITEM_TYPE_EQUIPMENT,
			"rarity": "t4",
			"equipment_level": 46,
			"equip_requirement": {"stat": "level", "min": 184},
			"base_attributes": [{"stat": "attack", "amount": 9}],
			"enhance_count": 3,
			"refine_affixes": [{"stat": "defense", "amount": 2}],
			"equipped": false,
		}],
		"companions": [{
			"id": "legacy-member",
			"name": "旧角色",
			"stats": {"level": 16, "level_cap": 99, "stage": 9, "exp": 50, "next_exp": 100},
			"elements": {},
			"equipped": {},
			"skills": [],
		}],
		"party_order": ["legacy-member"],
		"recruit_candidates": [],
		"building_levels": {"recruit": 1, "forge": 1, "alchemy": 1, "farm": 1},
	})
	var migrated_stats: Dictionary = migrated.companions[0].get("stats", {})
	_expect_equal("schema 14 recalculates stage", int(migrated_stats.get("stage", 0)), 2)
	_expect_equal("schema 14 recalculates cap", int(migrated_stats.get("level_cap", 0)), 20)
	_expect_equal("schema 14 keeps exp progress ratio", int(migrated_stats.get("exp", 0)), floori(float(migrated.party_service.next_exp_for_level(16)) * 0.5))
	var migrated_equipment: Dictionary = migrated.inventory_items_for_type(DataTables.ITEM_TYPE_EQUIPMENT)[0]
	_expect_true("schema 18 removes equip requirement", migrated_equipment.get("equip_requirement", {}).is_empty())
	_expect_equal("schema 14 preserves enhancement", int(migrated_equipment.get("enhance_count", 0)), 3)
	_expect_equal("schema 14 preserves refinement", migrated_equipment.get("refine_affixes", []).size(), 1)
	_expect_equal("new save schema", int(migrated.to_save_data().get("schema_version", 0)), 22)


func _check_stage_3_equipment_loop() -> void:
	var state := _fresh_state()
	var reward: Dictionary = state.register_full_encounter_victory(true)
	_expect_equal("victory no longer awards blueprint", str(reward.get("blueprint_item_id", "")), "")
	var template_id := "weapon"
	_expect_true("all templates can be targeted", state.unlocked_blueprint_templates().has(template_id))

	state.add_inventory_item("ore", 4, false)
	var equipment_before := state.inventory_total_for_type(DataTables.ITEM_TYPE_EQUIPMENT)
	_expect_true("unlocked template can be targeted", state.craft_equipment_from_template(template_id))
	_expect_equal("targeted forge uses four ore", state.inventory_item_count("ore"), 0)
	_expect_equal("targeted forge creates equipment", state.inventory_total_for_type(DataTables.ITEM_TYPE_EQUIPMENT), equipment_before + 1)

	var salvaged := DataTables.create_equipment_from_template("weapon_metal_sword", 1, state.rng, 0, "", "t5", "test")
	state.add_equipment(salvaged)
	var stones_before := state.inventory_item_count(DataTables.ITEM_ID_ENHANCEMENT_STONE)
	_expect_true("unequipped item can be salvaged", state.salvage_equipment(str(salvaged.get("instance_id", ""))))
	_expect_equal("tier five salvage returns five stones", state.inventory_item_count(DataTables.ITEM_ID_ENHANCEMENT_STONE), stones_before + 5)

	var protected := DataTables.create_equipment_from_template("helmet", 1, state.rng, 0, "", "t2", "test")
	protected["equipped"] = true
	protected["equipped_by"] = "member"
	state.add_equipment(protected)
	_expect_true("equipped item cannot be salvaged", not state.salvage_equipment(str(protected.get("instance_id", ""))))
	_expect_true("protected equipment remains", not state.inventory_item_by_instance(str(protected.get("instance_id", ""))).is_empty())

	_expect_equal("reward progress is saved", int(state.to_save_data().get("reward_progress", {}).get("valid_victories", 0)), 1)


func _check_stage_4_skills_and_pills() -> void:
	var state := _fresh_state()
	for _index in range(5):
		state.register_full_encounter_victory(true)
	_expect_equal("five valid victories grant one fragment", state.inventory_item_count("manual_fragment"), 1)
	_expect_equal("fragment progress resets after five", int(state.reward_progress.get("manual_fragment_progress", -1)), 0)
	var victories_before := int(state.reward_progress.get("valid_victories", 0))
	state.register_full_encounter_victory(false)
	_expect_equal("training victory does not advance rewards", int(state.reward_progress.get("valid_victories", 0)), victories_before)

	for skill_id in DataTables.SKILL_DEFS.keys():
		var skill: Dictionary = DataTables.create_skill(str(skill_id))
		_expect_true("skill target mode is valid: %s" % skill_id, ["single", "aoe"].has(str(skill.get("target_mode", ""))))
		_expect_true("skill has no release distance: %s" % skill_id, not skill.has("release_distance"))
	var cold := DataTables.create_skill("water_cold_talisman")
	_expect_equal("cold talisman target mode", str(cold.get("target_mode", "")), "single")
	_expect_equal("cold talisman mp", int(cold.get("mp_cost", 0)), 6)
	_expect_equal("cold talisman cooldown", int(cold.get("cooldown", 0)), 3)
	_expect_equal("cold talisman priority", int(cold.get("priority", 0)), 45)

	state.add_inventory_item("manual_fragment", 3, false)
	state.add_inventory_item("spirit_stone_water", 1, false)
	_expect_true("cold talisman exchange succeeds", state.exchange_skill_manual("water_cold_talisman"))
	_expect_equal("exchange spends fragments", state.inventory_item_count("manual_fragment"), 1)
	_expect_equal("exchange grants book", state.inventory_item_count("skill_book_water_cold_talisman"), 1)

	state.add_inventory_item("spirit_stone", 3, false)
	state.building_levels["forge"] = 2
	_expect_true("stone conversion locked before forge three", not state.convert_spirit_stones("fire"))
	state.building_levels["forge"] = 3
	_expect_true("stone conversion opens at forge three", state.convert_spirit_stones("fire"))
	_expect_equal("stone conversion output", state.inventory_item_count("spirit_stone_fire"), 1)

	var new_state := GameState.new()
	_expect_true("new state automatically knows basic pill", new_state.known_alchemy_recipes.has("pill"))
	_expect_equal("new state has no legacy recipe item", new_state.inventory_item_count("recipe_pill"), 0)
	state.building_levels["alchemy"] = 5
	state._ensure_building_unlocked_recipes()
	for recipe_id in ["breakthrough_pill", "life_pill", "spirit_pill", "attack_pill", "defense_pill", "wood_pill", "fire_pill", "earth_pill", "metal_pill", "water_pill"]:
		_expect_true("alchemy recipe unlocked: %s" % recipe_id, state.known_alchemy_recipes.has(recipe_id))

	var member: Dictionary = state.party_service.create_recruit_candidate(0, {})
	member["kind"] = "companion"
	state.companions.append(member)
	state.party_order.append(str(member.get("id", "")))
	var stats: Dictionary = member.get("stats", {})
	stats["hp"] = 1
	stats["mp"] = 1
	state.add_inventory_item("pill", 1, false)
	_expect_true("ratio pill can be used", state.use_inventory_item_for_member("pill", str(member.get("id", ""))))
	_expect_equal("base pill restores fifteen percent hp", int(stats.get("hp", 0)), 1 + ceili(float(state.total_stat_for(str(member.get("id", "")), "max_hp")) * 0.15))
	_expect_equal("base pill restores fifteen percent mp", int(stats.get("mp", 0)), 1 + ceili(float(state.total_stat_for(str(member.get("id", "")), "max_mp")) * 0.15))

	var ai := CombatAI.new()
	var attack_item := DataTables.create_stack_item("attack_pill", 1)
	var defense_item := DataTables.create_stack_item("defense_pill", 1)
	_expect_equal("attack buff pill shared cooldown", str(ai._pill_action_from_item(attack_item, "damage").get("cooldown_group", "")), "buff_pill")
	_expect_equal("defense buff pill shared cooldown", str(ai._pill_action_from_item(defense_item, "defense").get("cooldown_group", "")), "buff_pill")


func _check_stage_5_enemies() -> void:
	var state := _fresh_state()
	var visuals := {
		"venom_spider": "spider",
		"ember_gnome": "gnome",
		"stone_lizard": "lizard",
		"stone_overlord": "minotaur",
		"iron_lancer": "lancer",
		"tide_fish": "paddle_fish",
		"blight_shaman": "shaman",
		"abyssal_turtle": "turtle",
	}
	for enemy_id in visuals.keys():
		var generated := DataTables.create_enemy(21, state.rng, str(enemy_id))
		_expect_equal("enemy visual binding: %s" % enemy_id, str(generated.get("visual_id", "")), str(visuals[enemy_id]))
		for skill_id in generated.get("skills", []):
			var skill := DataTables.create_skill(str(skill_id))
			_expect_true("enemy skill mode valid: %s" % skill_id, ["single", "aoe"].has(str(skill.get("target_mode", ""))))
			_expect_true("enemy skill has no distance: %s" % skill_id, not skill.has("release_distance"))
	var normal := DataTables.create_enemy(21, state.rng, "tide_fish")
	var elite := DataTables.create_enemy(21, state.rng, "stone_overlord")
	var boss := DataTables.create_enemy(21, state.rng, "abyssal_turtle")
	_expect_approx("normal equipment chance", float(normal.get("equipment_drop_chance", 0.0)), 0.05)
	_expect_approx("elite equipment chance", float(elite.get("equipment_drop_chance", 0.0)), 0.12)
	_expect_approx("boss equipment chance", float(boss.get("equipment_drop_chance", 0.0)), 0.25)
	_expect_equal("elite encounter class", str(elite.get("encounter_class", "")), "elite")
	_expect_equal("boss encounter class", str(boss.get("encounter_class", "")), "boss")
	_expect_true("class drop profiles validate", DataTables.enemy_class_drop_profile_errors().is_empty())
	_expect_true("normal class pool enabled", bool(normal.get("use_class_drop_pool", false)))
	_expect_true("elite class pool enabled", bool(elite.get("use_class_drop_pool", false)))
	_expect_true("boss class pool enabled", bool(boss.get("use_class_drop_pool", false)))
	_expect_true("normal rank pool disabled", not bool(normal.get("use_rank_drop_pool", true)))
	_expect_true("elite rank pool disabled", not bool(elite.get("use_rank_drop_pool", true)))
	_expect_true("boss rank pool disabled", not bool(boss.get("use_rank_drop_pool", true)))
	_expect_equal("normal drop entry count", normal.get("class_drop_profile", {}).get("entries", []).size(), 13)
	_expect_equal("elite drop entry count", elite.get("class_drop_profile", {}).get("entries", []).size(), 7)
	_expect_equal("boss drop entry count", boss.get("class_drop_profile", {}).get("entries", []).size(), 2)
	_expect_equal("boss drop mode", str(boss.get("class_drop_profile", {}).get("mode", "")), "weighted_one")
	_expect_true("core enemies have no explicit material drops", normal.get("drops", {}).is_empty() and elite.get("drops", {}).is_empty() and boss.get("drops", {}).is_empty())


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_approx(label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
