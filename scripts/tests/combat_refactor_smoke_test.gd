extends Node

const PARTY_SIZE := 4
const STEP := 1.0 / 60.0
const MAX_FRAMES := 1800
const RESULT_PATH := "res://.funplay/combat_smoke_result.txt"

var failures: Array[String] = []


func _ready() -> void:
	_write_result("COMBAT_REFACTOR_SMOKE_STARTED")
	await _run()


func _run() -> void:
	var world := Node2D.new()
	add_child(world)
	_test_legacy_migration()
	_test_recruit_skills_and_basic_attacks()
	_test_roster_and_innate_traits()
	_test_gameplay_baseline()
	_test_enemy_rank_progression()
	_test_equipment_enhancement_rules()
	_test_rich_text_descriptions()
	_test_save_fallback()
	_test_visual_contracts(world)
	var game_state := GameState.new()
	game_state.companions.clear()
	game_state.party_order.clear()
	for index in range(PARTY_SIZE):
		var member := _test_member(game_state, index)
		game_state.companions.append(member)
		game_state.party_order.append(str(member.get("id", "")))
	game_state._ensure_party_state()

	var actor_scene := load("res://scripts/actors/actor.tscn") as PackedScene
	var views: Dictionary = {}
	for index in range(PARTY_SIZE):
		var member: Dictionary = game_state.party_members()[index]
		var actor := actor_scene.instantiate() as ActorController
		world.add_child(actor)
		actor.configure_member(member, index)
		views[str(member.get("id", ""))] = actor
	_test_talk_bubbles(views)

	var combat_scene := load("res://scripts/game/combat/combat_controller.tscn") as PackedScene
	var combat := combat_scene.instantiate() as CombatController
	world.add_child(combat)
	combat.set_party_views(views)
	_test_defeat_and_cooldowns(world, combat_scene, actor_scene)
	combat.begin_encounter(game_state, null, "forest_wolf", 1)
	_expect(combat.active, "战斗应成功开始")
	_expect(combat.party_combatants.size() == PARTY_SIZE, "应按编队创建四名战斗成员")
	for combatant in combat.party_combatants:
		combatant["move_speed"] = 400.0
	combat.enemy["move_speed"] = 400.0
	var starting_enemy_hp := int(combat.enemy.get("hp", 0))
	var saw_return := false
	var saw_ranged_attack := false
	var saw_enemy_phase := false
	var first_round_order: Array[String] = []
	var expected_order: Array[String] = ["test_member_0", "test_member_1", "test_member_2", "test_member_3"]
	for _frame in range(MAX_FRAMES):
		combat.tick(STEP, game_state)
		var active_party_count := 0
		for combatant in combat.party_combatants:
			var state := str(combatant.get("state", ""))
			var member_id := str(combatant.get("member_id", ""))
			if state in [CombatController.STATE_APPROACH, CombatController.STATE_ATTACK, CombatController.STATE_RETURN]:
				active_party_count += 1
				_expect(member_id == combat._current_party_member_id(), "只有当前顺序成员可以执行战斗动画")
			if state == CombatController.STATE_ATTACK and str(combatant.get("pending_action", {}).get("attack_mode", "")) == DataTables.ATTACK_MODE_RANGED:
				saw_ranged_attack = true
			if state == CombatController.STATE_APPROACH and combat._round_number == 1 and not first_round_order.has(member_id):
				if not first_round_order.is_empty():
					var previous_id := first_round_order[first_round_order.size() - 1]
					var previous_index := combat._combatant_index(previous_id)
					_expect(str(combat.party_combatants[previous_index].get("state", "")) == CombatController.STATE_RECOVERY, "前一名成员归位后才能轮到下一名")
				first_round_order.append(member_id)
			if state == CombatController.STATE_RETURN:
				saw_return = true
		_expect(active_party_count <= 1, "回合制中不能有多名队员同时执行动画")
		if combat._turn_phase == CombatController.PHASE_ENEMY:
			saw_enemy_phase = true
			_expect(first_round_order == expected_order, "敌人行动前玩家队伍必须按 party_order 全部执行")
		await get_tree().physics_frame
		if combat.is_finished():
			break

	_expect(int(combat.enemy.get("hp", starting_enemy_hp)) < starting_enemy_hp, "普攻有效帧碰撞应造成伤害")
	_expect(saw_ranged_attack, "远程角色应执行火球术普通攻击")
	_expect(saw_return, "攻击结束后应进入 RETURN 阶段")
	_expect(first_round_order == expected_order, "第一轮玩家行动顺序应与 party_order 一致")
	_expect(saw_enemy_phase, "全体玩家完成后敌人才应获得回合")
	_expect(combat.is_finished(), "战斗应在限制帧数内结束")
	_expect(combat.combat_result() == CombatController.RESULT_VICTORY, "敌人死亡后战斗结果应为 victory")
	_expect(game_state.expedition_level() >= 1 and int(game_state.account_progression.get("expedition_exp", 0)) > 0, "死亡动画结束后账号应获得历练经验")
	for member in game_state.party_members():
		_expect(int(member.get("stats", {}).get("exp", 0)) > 0, "每名参战成员都应获得经验")

	if failures.is_empty():
		_write_result("COMBAT_REFACTOR_SMOKE_OK")
		print("COMBAT_REFACTOR_SMOKE_OK")
		get_tree().quit(0)
	else:
		_write_result("COMBAT_REFACTOR_SMOKE_FAILED\n%s" % "\n".join(failures))
		for message in failures:
			push_error(message)
		get_tree().quit(1)


func _test_member(game_state: GameState, index: int) -> Dictionary:
	return {
		"id": "test_member_%d" % index,
		"name": "测试成员%d" % (index + 1),
		"kind": "companion",
		"visual_id": "actor_default",
		"stats": game_state._base_member_stats(),
		"elements": game_state._base_member_elements(),
		"equipped": game_state._base_equipped_slots(),
		"attack_mode": DataTables.ATTACK_MODE_RANGED if index == 0 else DataTables.ATTACK_MODE_MELEE,
		"skills": [],
		"innate_traits": [],
		"growth_primary_stats": ["attack", "defense", "max_hp"],
	}


func _test_recruit_skills_and_basic_attacks() -> void:
	var state := GameState.new()
	var candidate: Dictionary = state.party_service.create_recruit_candidate(0, {})
	_expect(candidate.get("skills", []).is_empty(), "新招募候选不应自带技能")
	_expect(str(candidate.get("attack_mode", "")) == DataTables.ATTACK_MODE_MELEE, "新招募候选默认使用近战普通攻击")

	var empty_member: Dictionary = candidate.duplicate(true)
	empty_member["skills"] = []
	state.party_service.ensure_member_shape(empty_member)
	_expect(empty_member.get("skills", []).is_empty(), "角色数据补全不应为空技能列表添加默认技能")

	var migrated_member: Dictionary = candidate.duplicate(true)
	migrated_member["skills"] = [
		{"id": DataTables.RANGED_BASIC_ATTACK_ID, "type": "damage"},
		DataTables.create_skill("heal"),
	]
	state.party_service.ensure_member_shape(migrated_member)
	_expect(migrated_member.get("skills", []).size() == 1 and str(migrated_member.get("skills", [])[0].get("id", "")) == "heal", "旧默认火球术应从角色技能中迁移移除")
	_expect(DataTables.create_skill(DataTables.RANGED_BASIC_ATTACK_ID).is_empty(), "火球术不应继续作为可学习技能")
	_expect(DataTables.item_definition("skill_fireball").is_empty(), "火球术残卷不应继续作为背包物品")

	var ranged_member: Dictionary = empty_member.duplicate(true)
	ranged_member["attack_mode"] = DataTables.ATTACK_MODE_RANGED
	var action := CombatAI.new().select_player_action(state, 96.0, 160.0, {}, {}, {}, ranged_member)
	_expect(str(action.get("source", "")) == CombatAI.ACTION_SOURCE_BASIC, "无技能远程角色应回退到普通攻击")
	_expect(str(action.get("id", "")) == DataTables.RANGED_BASIC_ATTACK_ID, "远程普通攻击应使用火球术定义")
	_expect(str(action.get("attack_mode", "")) == DataTables.ATTACK_MODE_RANGED and float(action.get("range", 0.0)) >= 120.0, "火球术普通攻击应保留远程射程")
	var fireball_attack: Dictionary = DataTables.create_basic_attack(DataTables.ATTACK_MODE_RANGED, 10)
	_expect(int(fireball_attack.get("mp_cost", -1)) == 0 and float(fireball_attack.get("cooldown", -1.0)) == 0.0, "火球术普通攻击不应消耗法力或进入技能冷却")

	var learner: Dictionary = empty_member.duplicate(true)
	learner.erase("candidate_id")
	learner["kind"] = "companion"
	state.companions.append(learner)
	state.party_order.append(str(learner.get("id", "")))
	var heal_book := {
		"instance_id": "test_skill_heal",
		"item_id": "test_skill_heal",
		"name": "回春术技能书",
		"type": DataTables.ITEM_TYPE_SKILL_BOOK,
		"count": 2,
		"stackable": true,
		"usable": true,
		"consumable": true,
		"payload": {"skill_id": "heal"},
	}
	var thunder_book := heal_book.duplicate(true)
	thunder_book["instance_id"] = "test_skill_thunder"
	thunder_book["item_id"] = "test_skill_thunder"
	thunder_book["name"] = "雷击术技能书"
	thunder_book["count"] = 1
	thunder_book["payload"] = {"skill_id": "thunder"}
	state.inventory.append(heal_book)
	state.inventory.append(thunder_book)
	var learner_id := str(learner.get("id", ""))
	_expect(state.use_inventory_item_for_member("test_skill_heal", learner_id), "首次使用技能书应成功学习技能")
	_expect(state.inventory_item_count("test_skill_heal") == 1, "成功学习后技能书应消耗1本")
	_expect(not state.use_inventory_item_for_member("test_skill_heal", learner_id), "重复技能书不应替换已学技能")
	_expect(state.inventory_item_count("test_skill_heal") == 1, "重复学习失败时不应消耗技能书")
	_expect(state.use_inventory_item_for_member("test_skill_thunder", learner_id), "不同技能书应追加新技能")
	var learned_skills: Array = state.member_by_id(learner_id).get("skills", [])
	_expect(learned_skills.size() == 2, "学习第二技能时不应替换第一技能")
	_expect(str(learned_skills[0].get("id", "")) == "heal" and str(learned_skills[1].get("id", "")) == "thunder", "人物技能应按学习顺序永久保留")
	for learned_skill in learned_skills:
		_expect(bool(learned_skill.get("locked", false)) and not bool(learned_skill.get("replaceable", true)), "人物已学技能应锁定且不可替换")


func _test_roster_and_innate_traits() -> void:
	var state := GameState.new()
	state.add_inventory_item("spirit_stone", PartyService.ROSTER_MAX_SIZE, false)
	for _index in range(PartyService.ROSTER_MAX_SIZE):
		var candidate_id := str(state.recruit_candidates[0].get("candidate_id", ""))
		_expect(state.recruit_candidate(candidate_id), "角色库未满时应允许招募")
	_expect(state.roster_member_count() == 8, "角色库上限应为8人")
	_expect(state.party_member_count() == 4, "出战队伍上限应保持4人")
	_expect(state.reserve_order.size() == 4, "第5至第8名角色应进入候补")
	_expect(not state.can_recruit(), "角色库达到8人后不应继续招募")
	var ninth_candidate_id := str(state.recruit_candidates[0].get("candidate_id", ""))
	_expect(not state.recruit_candidate(ninth_candidate_id), "第9名角色招募应被拒绝")

	var removed_active_id := str(state.party_order[0])
	var promoted_id := str(state.reserve_order[0])
	_expect(state.set_member_active(removed_active_id, false), "出战角色应能下阵")
	_expect(state.party_member_count() == 3 and state.reserve_order.has(removed_active_id), "下阵角色应进入候补")
	_expect(state.set_member_active(promoted_id, true), "候补角色应能上阵")
	_expect(state.party_member_count() == 4 and state.party_order.has(promoted_id), "上阵后出战人数应恢复为4")

	var released_equipment := DataTables.create_equipment_from_template("weapon", 1, state.rng, 0, "", "t1", "test")
	state.add_inventory_instance(released_equipment)
	var released_equipment_id := str(released_equipment.get("instance_id", ""))
	_expect(state.equip_item_for_member(released_equipment_id, removed_active_id), "放生测试角色应能穿戴装备")
	var stone_count_before_release := state.recruit_stone_count()
	_expect(state.release_companion(removed_active_id), "候补角色应能被放生")
	_expect(state.member_by_id(removed_active_id).is_empty(), "放生后角色数据应永久移除")
	var unequipped_item := state.inventory_item_by_instance(released_equipment_id)
	_expect(not bool(unequipped_item.get("equipped", true)) and str(unequipped_item.get("equipped_by", "")) == "", "放生后角色装备应解除归属")
	_expect(state.recruit_stone_count() == stone_count_before_release, "放生不应返还灵石")

	var restored := GameState.new()
	restored.load_save_data(state.to_save_data())
	_expect(restored.roster_member_count() == state.roster_member_count(), "存档应保留角色库人数")
	_expect(restored.party_order == state.party_order, "存档应保留出战顺序")
	_expect(restored.reserve_order == state.reserve_order, "存档应保留候补顺序")

	state.building_levels["recruit"] = 10
	for _index in range(24):
		var candidate := state.party_service.create_recruit_candidate(_index, {})
		var traits: Array = candidate.get("innate_traits", [])
		_expect(not traits.is_empty() and traits.size() <= DataTables.recruit_max_trait_count(10), "招募候选命格数量应在建筑上限内且至少有一个")
		for raw_trait in traits:
			_expect(raw_trait is Dictionary, "新候选命格应使用结构化数据")
			if raw_trait is Dictionary:
				_expect(["main", "sub"].has(str(raw_trait.get("slot", ""))), "候选命格槽位应有效")
				_expect(DataTables.INNATE_TRAIT_RARITY_NAMES.has(str(raw_trait.get("rarity", ""))), "候选命格品质应有效")
	_expect(DataTables.innate_trait_name("sharp_edge") == "锋芒", "旧字符串命格应继续解析名称")
	_expect(not DataTables.innate_trait_effect_summary("sharp_edge").is_empty(), "命格应提供实际效果说明")


func _test_gameplay_baseline() -> void:
	var setting_key := GameState.TEST_INVENTORY_SETTING
	var original_setting = ProjectSettings.get_setting(setting_key, false)
	ProjectSettings.set_setting(setting_key, false)
	var normal_state := GameState.new()
	_expect(normal_state.inventory_item_count("spirit_stone") == 1, "正式新档应只有一个招募灵石")
	_expect(normal_state.inventory_item_count("herb") == 1, "正式新档应只有一个草药种子")
	_expect(normal_state.inventory_item_count("recipe_pill") == 1, "正式新档应提供调息丹方")
	_expect(normal_state.inventory_item_count("ore") == 0, "正式新档不应直接提供矿石")
	_expect(normal_state.inventory_items_for_type(DataTables.ITEM_TYPE_EQUIPMENT).is_empty(), "正式新档不应注入测试装备")

	ProjectSettings.set_setting(setting_key, true)
	var debug_state := GameState.new()
	_expect(not debug_state.inventory_items_for_type(DataTables.ITEM_TYPE_EQUIPMENT).is_empty(), "开发开关应注入测试装备")
	_expect(debug_state.inventory_item_count("ore") >= 1, "开发开关应补齐测试物品")
	ProjectSettings.set_setting(setting_key, original_setting)

	_expect(DataTables.crop_growth_seconds("herb") == 600.0, "基础草药生长时间应为600秒")
	_expect(DataTables.forge_duration_seconds(1) == 900.0, "1级炼器时间应为900秒")
	_expect(DataTables.alchemy_duration_seconds(1, 1) == 600.0, "1级单份炼丹时间应为600秒")
	var wolf: Dictionary = DataTables.ENEMY_TEMPLATES.get("forest_wolf", {})
	_expect(float(wolf.get("equipment_drop_chance", -1.0)) == 0.05, "林狼装备掉落率应为5%")
	_expect(wolf.get("drops", {}).has("ore") and wolf.get("drops", {}).has("spirit_stone"), "林狼应提供矿石和灵石来源")

	var simulation_rng := RandomNumberGenerator.new()
	simulation_rng.seed = 424242
	var ore_count := 0
	var stone_count := 0
	for _encounter in range(60):
		if simulation_rng.randf() < float(wolf.get("drops", {}).get("ore", {}).get("chance", 0.0)):
			ore_count += 1
		if simulation_rng.randf() < float(wolf.get("drops", {}).get("spirit_stone", {}).get("chance", 0.0)):
			stone_count += 1
	_expect(ore_count >= 4, "固定种子首小时模拟应获得足够首次炼器的矿石")
	_expect(stone_count >= 1, "固定种子首小时模拟应获得至少一个建筑升级灵石")


func _test_enemy_rank_progression() -> void:
	_expect(CombatController.MAX_ENEMY_COUNT == 8, "敌人数量上限应为8")
	_expect(mini(CombatController.MAX_ENEMY_COUNT, 1 * 2) == 2, "单人遭遇应生成两只敌人")
	_expect(mini(CombatController.MAX_ENEMY_COUNT, PARTY_SIZE * 2) == 8, "四人遭遇应生成八只敌人")
	var boundaries := {1: "t1", 20: "t1", 21: "t2", 40: "t2", 41: "t3", 60: "t3", 61: "t4", 80: "t4", 81: "t5"}
	for level in boundaries.keys():
		_expect(DataTables.enemy_rank_for_level(int(level)) == str(boundaries[level]), "敌人阶级边界错误: %d" % int(level))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260712
	var previous: Dictionary = {}
	for level in [1, 5, 20, 21, 40, 41, 60, 61, 80, 81]:
		var enemy := DataTables.create_enemy(level, rng, "forest_wolf")
		_expect(enemy.get("elements", {}).has("wood"), "林狼应具有木行战斗属性")
		_expect(float(enemy.get("element_attack_ratio", 0.0)) >= 0.0 and float(enemy.get("element_attack_ratio", 0.0)) <= 1.0, "元素攻击概率必须有效")
		_expect(enemy.get("skills", []).size() == int(DataTables.ENEMY_RANK_DEFS[enemy.get("rank", "t1")].get("skill_count", 0)), "林狼技能数量应跟随阶级")
		if not previous.is_empty():
			_expect(int(enemy.get("max_hp", 0)) >= int(previous.get("max_hp", 0)), "敌人生命应随等级单调增长")
			_expect(int(enemy.get("attack", 0)) >= int(previous.get("attack", 0)), "敌人攻击应随等级单调增长")
			_expect(int(enemy.get("defense", 0)) >= int(previous.get("defense", 0)), "敌人防御应随等级单调增长")
		previous = enemy
	var top_profile := DataTables.rank_drop_profile("t5", {})
	_expect(top_profile.get("categories", []).has("rare_material"), "五阶掉落池应解锁稀有材料")
	_expect(DataTables.random_rarity_from_weights(rng, {"t1": 0, "t2": 0, "t3": 0, "t4": 0, "t5": 1}) == "t5", "固定稀有度权重应稳定抽中对应阶级")
	var controller := CombatController.new()
	controller.enemy = DataTables.create_enemy(20, rng, "forest_wolf")
	var rank_level := int(controller.enemy.get("rank_level", 1))
	var level_steps := mini(3, floori(float(rank_level - 1) / 5.0))
	_expect(level_steps == 3, "阶内掉落概率加成最多应为三个5%台阶")


func _test_equipment_enhancement_rules() -> void:
	var budgets := {"t1": 20, "t2": 50, "t3": 100, "t4": 180, "t5": 300}
	var attribute_rng := RandomNumberGenerator.new()
	attribute_rng.seed = 20260712
	var saw_normal := false
	var saw_element := false
	for rarity in budgets.keys():
		_expect(DataTables.equipment_attribute_point_budget(str(rarity)) == int(budgets[rarity]), "装备阶位属性点预算错误: %s" % str(rarity))
		for _index in range(40):
			var attributes := DataTables.generate_equipment_base_attributes(str(rarity), attribute_rng)
			_expect(attributes.size() >= 1 and attributes.size() <= 5, "装备随机属性数量应在1至5之间")
			var total := 0
			var unique_stat_ids: Dictionary = {}
			for attribute in attributes:
				var stat_id := str(attribute.get("stat", ""))
				_expect(not unique_stat_ids.has(stat_id), "装备随机属性不能重复")
				unique_stat_ids[stat_id] = true
				total += int(attribute.get("amount", 0))
				saw_normal = saw_normal or DataTables.EQUIPMENT_NORMAL_ATTRIBUTE_STATS.has(stat_id)
				saw_element = saw_element or DataTables.EQUIPMENT_ELEMENT_ATTRIBUTE_STATS.has(stat_id)
			_expect(total <= int(budgets[rarity]) and total > 0, "随机属性点总值应为预算平均分配后的有效值")
	_expect(saw_normal and saw_element, "随机属性应同时覆盖普通与五行属性池")
	var level_rng_a := RandomNumberGenerator.new()
	var level_rng_b := RandomNumberGenerator.new()
	level_rng_a.seed = 99
	level_rng_b.seed = 99
	var level_one := DataTables.create_equipment_from_template("weapon", 1, level_rng_a, 0, "", "t3", "debug")
	var level_ninety_nine := DataTables.create_equipment_from_template("weapon", 99, level_rng_b, 0, "", "t3", "debug")
	_expect(level_one.get("base_attributes", []) == level_ninety_nine.get("base_attributes", []), "同阶装备基础属性不应受装备等级影响")
	_expect(level_one.get("affixes", []).is_empty(), "新装备不应生成旧数值词条")
	_expect(DataTables.equipment_enhance_limit("t1") == 5 and DataTables.equipment_enhance_limit("t5") == 40, "装备强化上限应按阶位为5至40")
	_expect(DataTables.equipment_enhance_cost("t1", 5) == 1, "一阶+5强化消耗应为1")
	_expect(DataTables.equipment_enhance_cost("t3", 16) == 6, "三阶+16强化消耗应为6")
	_expect(DataTables.equipment_enhance_cost("t5", 40) == 15, "五阶+40强化消耗应为15")
	var state := GameState.new()
	state.inventory.clear()
	state.rng.seed = 20260712
	state.add_inventory_item(DataTables.ITEM_ID_SPIRIT_STONE, 100, false)
	var weapon := DataTables.create_equipment_from_template("weapon", 1, state.rng, 0, "", "t1", "debug")
	weapon["base_attributes"] = [{"stat": "attack", "amount": 20}]
	state.add_equipment(weapon)
	for _index in range(5):
		_expect(state.enhance_equipment(str(weapon.get("instance_id", ""))), "一阶武器应能强化至+5")
	var enhanced_weapon := state.inventory_item_by_instance(str(weapon.get("instance_id", "")))
	_expect(int(enhanced_weapon.get("enhance_count", 0)) == 5, "一阶武器强化次数应达到上限")
	_expect(state._sum_enhanced_attribute(enhanced_weapon, "attack") == 5, "单属性武器每次强化应直接增加1点攻击")
	_expect(not state.enhance_equipment(str(weapon.get("instance_id", ""))), "达到阶位上限后不应继续强化")
	var armor := DataTables.create_equipment_from_template("armor", 1, state.rng, 0, "", "t1", "debug")
	armor["base_attributes"] = [{"stat": "defense", "amount": 10}, {"stat": "max_hp", "amount": 10}]
	state.add_equipment(armor)
	_expect(state.enhance_equipment(str(armor.get("instance_id", ""))), "双属性装备应能强化")
	var enhanced_armor := state.inventory_item_by_instance(str(armor.get("instance_id", "")))
	var enhanced_stat := str(enhanced_armor.get("enhanced_attributes", [])[0].get("stat", ""))
	_expect(["defense", "max_hp"].has(enhanced_stat), "随机强化必须命中已有基础属性")
	state.add_inventory_item(DataTables.ITEM_ID_REFINE_TALISMAN, 10, false)
	var enhancement_level := int(enhanced_armor.get("enhance_count", 0))
	_expect(state.add_equipment_affix(str(armor.get("instance_id", ""))), "洗练应成功重洗随机属性")
	var refined_armor := state.inventory_item_by_instance(str(armor.get("instance_id", "")))
	_expect(int(refined_armor.get("enhance_count", 0)) == enhancement_level, "洗练后强化等级必须保持")
	_expect(refined_armor.get("enhanced_attributes", []).size() == enhancement_level, "洗练后强化点总数必须保持")
	_expect(refined_armor.get("refine_affixes", []).is_empty() and int(refined_armor.get("refine_count", 0)) == 1, "洗练不应生成旧百分比词条且应增加洗练次数")
	var refined_base_stats: Dictionary = {}
	for attribute in refined_armor.get("base_attributes", []):
		refined_base_stats[str(attribute.get("stat", ""))] = true
	for attribute in refined_armor.get("enhanced_attributes", []):
		_expect(refined_base_stats.has(str(attribute.get("stat", ""))), "洗练后的强化点必须重新分配到新属性")
	var migration_state := GameState.new()
	migration_state.load_save_data({
		"schema_version": 5,
		"inventory": [{
			"instance_id": "legacy_equipment",
			"item_id": "weapon",
			"type": DataTables.ITEM_TYPE_EQUIPMENT,
			"count": 1,
			"rarity": "t2",
			"equipment_level": 1,
			"base_attributes": [{"stat": "attack", "amount": 999}],
			"affixes": [{"stat": "defense", "amount": 999}],
			"enhanced_attributes": [{"stat": "attack", "amount": 5}],
			"refine_affixes": [{"stat": "attack", "percent": 0.1}],
			"enhance_count": 5,
			"refine_count": 1,
		}],
	})
	var migrated_item := migration_state.inventory_item_by_instance("legacy_equipment")
	_expect(int(migrated_item.get("attribute_generation_version", 0)) == 1, "旧装备应迁移到阶位点数属性模型")
	_expect(migrated_item.get("affixes", []).is_empty() and migrated_item.get("enhanced_attributes", []).is_empty() and migrated_item.get("refine_affixes", []).is_empty(), "旧装备迁移应清空数值词条、强化和洗练")
	_expect(int(migrated_item.get("enhance_count", -1)) == 0 and int(migrated_item.get("refine_count", -1)) == 0, "旧装备迁移应重置强化和洗练次数")


func _test_rich_text_descriptions() -> void:
	var state := GameState.new()
	state.companions.clear()
	state.party_order.clear()
	var member := _test_member(state, 30)
	member.get("elements", {})["fire"] = 32
	state.companions.append(member)
	state.party_order.append(str(member.get("id", "")))
	state._ensure_party_state()
	var item := {
		"item_id": "weapon",
		"name": "测试赤焰剑",
		"description": "用于验证语义富文本。",
		"type": DataTables.ITEM_TYPE_EQUIPMENT,
		"rarity": "t3",
		"base_attributes": [{"stat": "attack", "amount": 12}],
		"enhanced_attributes": [{"stat": "attack", "amount": 2}],
		"affixes": [{"stat": "element_fire", "amount": 4}],
		"refine_affixes": [{"stat": "attack", "percent": 0.12}],
		"description_effects": [{
			"kind": "element_damage_formula",
			"element": "fire",
			"stat": "element_fire",
			"multiplier": 0.75,
			"rounding": "floor",
		}],
	}
	var segments: Array = RichTextDescriptionRenderer.build_item_segments(item, state, str(member.get("id", "")))
	var text: String = RichTextDescriptionRenderer.plain_text(segments)
	_expect(text.contains("造成 火属性伤害（火属性 32 × 0.75 = 24）"), "元素公式描述应显示实时属性、倍率和结果")
	var saw_fire_role := false
	var saw_multiplier_role := false
	var saw_result_role := false
	for segment in segments:
		var role: String = str(segment.get("role", ""))
		saw_fire_role = saw_fire_role or role == "element_fire"
		saw_multiplier_role = saw_multiplier_role or role == RichTextDescriptionRenderer.ROLE_MULTIPLIER
		saw_result_role = saw_result_role or role == RichTextDescriptionRenderer.ROLE_RESULT
	_expect(saw_fire_role and saw_multiplier_role and saw_result_role, "公式描述应包含元素、倍率和结果语义颜色")
	var label := RichTextLabel.new()
	RichTextDescriptionRenderer.render_item(label, item, state, str(member.get("id", "")))
	_expect(label.get_total_character_count() > 0, "RichTextLabel应接收渲染后的描述")
	label.free()
	var generated := DataTables.create_equipment_from_template("weapon", 1, state.rng)
	_expect(generated.has("description_effects"), "新装备实例应始终携带description_effects字段")


func _test_defeat_and_cooldowns(world: Node2D, combat_scene: PackedScene, actor_scene: PackedScene) -> void:
	var state := GameState.new()
	state.companions.clear()
	state.party_order.clear()
	var member := _test_member(state, 20)
	state.companions.append(member)
	state.party_order.append(str(member.get("id", "")))
	state._ensure_party_state()
	var actor := actor_scene.instantiate() as ActorController
	world.add_child(actor)
	actor.configure_member(member, 0)
	var defeat_combat := combat_scene.instantiate() as CombatController
	world.add_child(defeat_combat)
	defeat_combat.set_party_views({str(member.get("id", "")): actor})
	defeat_combat.begin_encounter(state, null, "forest_wolf", 1)
	member.get("stats", {})["hp"] = 0
	defeat_combat._check_combat_result()
	_expect(defeat_combat.is_finished(), "队伍全灭应立即结束战斗")
	_expect(defeat_combat.combat_result() == CombatController.RESULT_DEFEAT, "队伍全灭结果应为 defeat")
	_expect(int(state.account_progression.get("expedition_exp", 0)) == 0, "失败战斗不应结算账号经验")
	state.recover_party_after_defeat(0.5)
	var stats: Dictionary = member.get("stats", {})
	_expect(int(stats.get("hp", 0)) == ceili(float(state.total_stat_for(str(member.get("id", "")), "max_hp")) * 0.5), "战败后生命应恢复至总上限50%")
	_expect(int(stats.get("mp", 0)) == ceili(float(state.total_stat_for(str(member.get("id", "")), "max_mp")) * 0.5), "战败后法力应恢复至总上限50%")
	_expect(defeat_combat._cooldown_turns(5, 0.81) == 5, "冷却百分比修正应向上取整")
	var combatant := {"skill_cooldowns": {"heal": 5}, "pill_cooldowns": {}, "pill_group_cooldowns": {}}
	for expected in [4, 3, 2, 1, 0]:
		defeat_combat._advance_turn_cooldowns(combatant)
		_expect(int(combatant.get("skill_cooldowns", {}).get("heal", -1)) == expected, "技能冷却应按角色自身回合递减")
	defeat_combat.clear()
	_expect(defeat_combat.combat_result() == CombatController.RESULT_NONE, "clear应重置战斗结果")
	defeat_combat.queue_free()
	actor.queue_free()


func _test_save_fallback() -> void:
	var save_path := "user://guaji_smoke_save.cfg"
	var manager := SaveManager.new(save_path)
	_expect(manager.save_data({"game_state": {"schema_version": GameState.SAVE_SCHEMA_VERSION}}), "临时存档应写入成功")
	_expect(int(manager.load_data().get("version", 0)) == SaveManager.SAVE_VERSION, "存档应包含当前外层版本")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string("not a valid config file")
		file.close()
	_expect(manager.load_data().is_empty(), "损坏存档应回退为空数据")


func _test_legacy_migration() -> void:
	var legacy_state := GameState.new()
	var legacy_equipment := DataTables.create_equipment(1, legacy_state.rng)
	legacy_equipment["instance_id"] = "legacy_player_equipment"
	legacy_equipment["equipped"] = true
	legacy_equipment["equipped_by"] = "player"
	legacy_state.load_save_data({
		"schema_version": 4,
		"stats": {"level": 99, "attack": 999},
		"elements": {"fire": 999},
		"skills": [{"id": "legacy_player_skill"}],
		"innate_traits": [{"id": "legacy_player_trait"}],
		"task_exp": {"fight": 85},
		"inventory": [DataTables.create_stack_item("herb", 7), legacy_equipment],
		"companions": [{"id": "legacy_member", "name": "旧成员"}],
		"party_order": ["player", "legacy_member"],
		"building_levels": {"farm": 3},
		"production_jobs": {
			"forge": {"status": "running", "elapsed_seconds": 1.0, "duration_seconds": 20.0, "member_id": "player"},
		},
		"farm_slots": [{"status": "ready", "crop_id": "herb", "worker_id": "player", "harvest_amount": 2}],
	})
	var migrated := legacy_state.member_by_id("legacy_member")
	_expect(str(migrated.get("visual_id", "")) == "actor_default", "旧成员应补齐 actor_default visual_id")
	_expect(legacy_state.party_order == ["legacy_member"], "旧存档固定主角应从编队中移除")
	_expect(legacy_state.expedition_level() > 1, "旧战斗熟练度应迁移为账号历练经验")
	_expect(legacy_state.inventory_item_count("herb") >= 7, "旧存档普通背包资源应保留")
	_expect(legacy_state.building_level("farm") == 3, "旧存档建筑等级应保留")
	var migrated_equipment := legacy_state.inventory_item_by_instance("legacy_player_equipment")
	_expect(not bool(migrated_equipment.get("equipped", true)) and str(migrated_equipment.get("equipped_by", "")) == "", "旧主角装备应解除归属")
	_expect(str(legacy_state.production_job("forge").get("member_id", "invalid")) == "", "旧主角生产任务应清除角色归属")
	_expect(str(legacy_state.farm_slots[0].get("worker_id", "invalid")) == "", "旧主角农田任务应清除角色归属")
	var saved := legacy_state.to_save_data()
	for legacy_key in ["stats", "elements", "equipped", "skills", "innate_traits"]:
		_expect(not saved.has(legacy_key), "新存档不应保存全局主角字段 %s" % legacy_key)


func _test_visual_contracts(world: Node2D) -> void:
	for path in [
		"res://scripts/actors/visuals/party/actor_default.tscn",
		"res://scripts/actors/visuals/enemies/enemy_default.tscn",
		"res://scripts/actors/visuals/enemies/forest_wolf.tscn",
		"res://scripts/actors/visuals/enemies/training_dummy.tscn",
	]:
		var packed := load(path) as PackedScene
		var visual := packed.instantiate() as CombatVisual if packed != null else null
		_expect(visual != null, "形象场景根节点必须继承 CombatVisual: %s" % path)
		if visual == null:
			continue
		world.add_child(visual)
		_expect(visual.contract_error().is_empty(), "形象场景契约不完整: %s" % path)
		for method_name in [
			"play_idle",
			"play_walk",
			"play_run",
			"play_melee_attack",
			"play_ranged_attack",
			"play_death",
			"play_level_up",
		]:
			_expect(visual.has_method(method_name), "形象缺少动画接口 %s: %s" % [method_name, path])
		if path.ends_with("/party/actor_default.tscn"):
			var sprite := visual.get_node_or_null("Sprite") as AnimatedSprite2D
			var animation_player := visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
			_expect(sprite != null, "默认人物形象必须使用 AnimatedSprite2D")
			if sprite != null:
				for animation_name in [&"idle", &"walk", &"run", &"melee_attack", &"ranged_attack"]:
					_expect(sprite.sprite_frames.has_animation(animation_name), "默认人物形象缺少动画 %s" % animation_name)
			_expect(animation_player != null and animation_player.has_animation(&"death"), "默认人物形象缺少死亡动画")
			_expect(animation_player != null and animation_player.has_animation(&"level_up"), "默认人物形象缺少升级动画")
		visual.queue_free()
	var fallback_actor_scene := load("res://scripts/actors/actor.tscn") as PackedScene
	var fallback_actor := fallback_actor_scene.instantiate() as ActorController
	world.add_child(fallback_actor)
	var fallback_member := _test_member(GameState.new(), 99)
	fallback_member["visual_id"] = "missing_visual_for_test"
	fallback_actor.configure_member(fallback_member, 0)
	_expect(fallback_actor.combat_visual != null and fallback_actor.combat_visual.contract_error().is_empty(), "缺失人物形象应降级到 actor_default")
	fallback_actor.queue_free()


func _test_talk_bubbles(views: Dictionary) -> void:
	var first: ActorController = views.get("test_member_0")
	var second: ActorController = views.get("test_member_1")
	_expect(first != null and second != null, "对话框测试需要至少两名角色")
	if first == null or second == null:
		return
	_expect(first.talk_bubble.position.y != second.talk_bubble.position.y, "相邻角色对话框应使用不同高度")
	_expect(first._start_talking(), "第一名角色应能显示对话框")
	_expect(first.talk_bubble.visible and not first.talk_label.text.is_empty(), "对话框应显示有效文本")
	_expect(not second._start_talking(), "同一时刻只能有一名角色说话")
	first._hide_talk_bubble(true)
	_expect(second._start_talking(), "上一名角色结束后下一名应能说话")
	second._hide_talk_bubble(true)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _write_result(text: String) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(RESULT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
