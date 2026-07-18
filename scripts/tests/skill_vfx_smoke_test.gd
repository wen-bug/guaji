extends Node

const RESULT_PATH := "res://.funplay/skill_vfx_smoke_result.txt"
const SKILL_IDS := ["thunder", "poison", "heal", "attack_up", "spirit_shield"]
const BOOK_IDS := [
	"skill_book_thunder",
	"skill_book_poison",
	"skill_book_heal",
	"skill_book_attack_up",
	"skill_book_spirit_shield",
]

var failures: Array[String] = []
var resolver := CombatEffectResolver.new()
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	_write_result("SKILL_VFX_SMOKE_STARTED")
	await _run()


func _run() -> void:
	var setting_key := GameState.TEST_INVENTORY_SETTING
	var original_setting = ProjectSettings.get_setting(setting_key, false)
	ProjectSettings.set_setting(setting_key, false)
	rng.seed = 20260716

	var state := GameState.new()
	_test_definitions_and_starter_books(state)
	var member_id := _recruit_and_learn_all(state)
	if not member_id.is_empty():
		_test_ai_selection(state, member_id)
		_test_skill_effects(state, member_id)
		_test_controller_timing()

	ProjectSettings.set_setting(setting_key, original_setting)
	if failures.is_empty():
		_write_result("SKILL_VFX_SMOKE_OK")
		print("SKILL_VFX_SMOKE_OK")
		get_tree().quit(0)
	else:
		_write_result("SKILL_VFX_SMOKE_FAILED\n%s" % "\n".join(failures))
		for message in failures:
			push_error(message)
		get_tree().quit(1)


func _test_definitions_and_starter_books(state: GameState) -> void:
	var item_numbers: Dictionary = {}
	var expected_modes := {
		"thunder": DataTables.SKILL_TARGET_MODE_SINGLE,
		"poison": DataTables.SKILL_TARGET_MODE_AOE,
		"heal": DataTables.SKILL_TARGET_MODE_SINGLE,
		"attack_up": DataTables.SKILL_TARGET_MODE_SINGLE,
		"spirit_shield": DataTables.SKILL_TARGET_MODE_SINGLE,
	}
	for index in range(SKILL_IDS.size()):
		var skill_id: String = SKILL_IDS[index]
		var book_id: String = BOOK_IDS[index]
		var skill: Dictionary = DataTables.create_skill(skill_id)
		var book: Dictionary = DataTables.item_definition(book_id)
		_expect(not skill.is_empty(), "技能定义应存在: %s" % skill_id)
		_expect(str(skill.get("target_mode", "")) == str(expected_modes.get(skill_id, "")), "技能应声明正确的单体/AOE分类: %s" % skill_id)
		_expect(not skill.get("effect_tags", []).is_empty(), "技能应声明至少一种效果分类: %s" % skill_id)
		_expect(not book.is_empty(), "技能书定义应存在: %s" % book_id)
		_expect(str(book.get("payload", {}).get("skill_id", "")) == skill_id, "技能书载荷应指向对应技能: %s" % book_id)
		var item_no := int(book.get("item_no", 0))
		_expect(item_no >= 1029 and item_no <= 1033 and not item_numbers.has(item_no), "技能书编号应在 1029-1033 内且唯一: %s" % book_id)
		item_numbers[item_no] = true
		var skill_resource: Resource = load(DataTables.skill_resource_path(skill_id))
		var item_resource := DataTables.item_resource(book_id)
		_expect(skill_resource != null and skill_resource.get("icon_texture") != null, "技能图标应可加载: %s" % skill_id)
		_expect(item_resource != null and item_resource.get("icon_texture") != null, "技能书图标应可加载: %s" % book_id)
		_expect(state.inventory_item_count(book_id) == 1, "正式新档应赠送一本技能书: %s" % book_id)
	_expect(not DataTables.skill_has_buff(DataTables.create_skill("thunder")), "纯伤害技能不应误判为增益")
	_expect(not DataTables.skill_has_debuff(DataTables.create_skill("thunder")), "纯伤害技能不应误判为减益")
	_expect(not DataTables.skill_is_aoe(DataTables.create_skill("thunder")), "雷击术应识别为单体技能")
	_expect(DataTables.skill_is_aoe(DataTables.create_skill("poison")), "毒雾应识别为AOE技能")
	_expect(DataTables.skill_has_debuff(DataTables.create_skill("poison")), "毒雾应识别为附带减益")
	_expect(DataTables.skill_has_buff(DataTables.create_skill("attack_up")), "燃锋诀应识别为附带增益")
	_expect(DataTables.skill_has_buff(DataTables.create_skill("spirit_shield")), "玄甲术应识别为附带增益")

	var save_data := state.to_save_data()
	save_data["schema_version"] = 8
	var saved_inventory: Array = save_data.get("inventory", [])
	save_data["inventory"] = saved_inventory.filter(func(item):
		return item is Dictionary and not BOOK_IDS.has(str(item.get("item_id", "")))
	)
	var restored := GameState.new()
	restored.load_save_data(save_data)
	for book_id in BOOK_IDS:
		_expect(restored.inventory_item_count(book_id) == 1, "旧存档应补发缺失技能书: %s" % book_id)
	var migrated_again := GameState.new()
	migrated_again.load_save_data(restored.to_save_data())
	for book_id in BOOK_IDS:
		_expect(migrated_again.inventory_item_count(book_id) == 1, "技能书迁移不应重复发放: %s" % book_id)

	var battle_map := BattleMap.new()
	add_child(battle_map)
	var spawn_count := [0]
	battle_map.monster_spawn_requested.connect(func(): spawn_count[0] += 1)
	battle_map.enter_expedition()
	battle_map.advance(0.99)
	_expect(spawn_count[0] == 0, "首只敌人不应早于配置延迟出现")
	battle_map.advance(0.01)
	_expect(spawn_count[0] == 1, "进入历练一秒后应请求生成首只敌人")
	battle_map.finish_combat()
	_expect(battle_map.next_spawn_time >= 3.0 and battle_map.next_spawn_time <= 5.0, "后续遭遇间隔应为 3-5 秒")
	battle_map.queue_free()


func _recruit_and_learn_all(state: GameState) -> String:
	var candidate_id := str(state.recruit_candidates[0].get("candidate_id", ""))
	_expect(state.recruit_candidate(candidate_id), "技能测试应能招募首名角色")
	var member_id := state.default_party_member_id()
	_expect(not member_id.is_empty(), "招募后应存在默认出战角色")
	if member_id.is_empty():
		return ""
	for book_id in BOOK_IDS:
		_expect(state.use_inventory_item_for_member(book_id, member_id), "首次技能书应学习成功: %s" % book_id)
		_expect(state.inventory_item_count(book_id) == 0, "学习后应消耗技能书: %s" % book_id)
	var member: Dictionary = state.member_by_id(member_id)
	_expect(member.get("skills", []).size() == SKILL_IDS.size(), "角色应永久保留五个测试技能")
	state.add_inventory_item(BOOK_IDS[0], 1, false)
	_expect(not state.use_inventory_item_for_member(BOOK_IDS[0], member_id), "重复技能书不应再次学习")
	_expect(state.inventory_item_count(BOOK_IDS[0]) == 1, "重复学习失败不应消耗技能书")
	return member_id


func _test_ai_selection(state: GameState, member_id: String) -> void:
	var ai := CombatAI.new()
	var member: Dictionary = state.member_by_id(member_id)
	var stats: Dictionary = member.get("stats", {})
	stats["mp"] = stats.get("max_mp", 40)
	stats["hp"] = stats.get("max_hp", 80)
	var action := ai.select_player_action(state, 96.0, 80.0, {}, {}, {}, member)
	_expect(str(action.get("id", "")) == "attack_up", "健康状态应优先施放燃锋诀")
	action = ai.select_player_action(state, 96.0, 80.0, {"attack_up": 1}, {}, {}, member)
	_expect(str(action.get("id", "")) == "thunder", "增益冷却时应优先选择雷击术")
	action = ai.select_player_action(state, 96.0, 80.0, {"attack_up": 1, "thunder": 1}, {}, {}, member)
	_expect(str(action.get("id", "")) == "poison", "雷击冷却时应选择蚀骨毒雾")
	stats["hp"] = 40
	action = ai.select_player_action(state, 96.0, 80.0, {}, {}, {}, member)
	_expect(str(action.get("id", "")) == "spirit_shield", "气血低于六成应优先施放玄甲术")
	stats["hp"] = 20
	action = ai.select_player_action(state, 96.0, 80.0, {}, {}, {}, member)
	_expect(str(action.get("id", "")) == "heal", "气血低于三成半应优先施放回春术")
	stats["hp"] = stats.get("max_hp", 80)


func _test_skill_effects(state: GameState, member_id: String) -> void:
	var member: Dictionary = state.member_by_id(member_id)
	var store := {"position": Vector2(100, 100), "combat_buffs": [], "combat_effects": [], "skill_cooldowns": {}}
	var caster := CombatActorStatus.new()
	add_child(caster)
	caster.bind_member(state, member_id, store)
	caster.set_effect_resolver(resolver)

	var enemy_data := DataTables.create_enemy(1, rng, "training_dummy")
	enemy_data["hp"] = 300
	enemy_data["max_hp"] = 300
	enemy_data["defense"] = 0
	enemy_data["combat_effects"] = []
	var target := CombatActorStatus.new()
	add_child(target)
	target.bind_enemy(enemy_data)
	target.set_effect_resolver(resolver)
	var second_enemy_data := DataTables.create_enemy(1, rng, "training_dummy")
	second_enemy_data["combat_id"] = "enemy_2"
	second_enemy_data["hp"] = 300
	second_enemy_data["max_hp"] = 300
	second_enemy_data["defense"] = 0
	second_enemy_data["combat_effects"] = []
	var second_target := CombatActorStatus.new()
	add_child(second_target)
	second_target.bind_enemy(second_enemy_data)
	second_target.set_effect_resolver(resolver)

	var thunder_hp := int(enemy_data.get("hp", 0))
	var thunder_result := _cast_skill("thunder", caster, [target])
	_expect(int(thunder_result.get("damage", 0)) > 0 and int(enemy_data.get("hp", 0)) < thunder_hp, "雷击术应在有效帧造成一次伤害")

	var second_poison_hp := int(second_enemy_data.get("hp", 0))
	var poison_result := _cast_skill("poison", caster, [target, second_target])
	_expect(int(poison_result.get("damage", 0)) > 0, "蚀骨毒雾应造成直接伤害")
	_expect(poison_result.get("target_results", []).size() == 2, "AOE技能应分别记录每个目标的结算结果")
	_expect(int(second_enemy_data.get("hp", 0)) < second_poison_hp, "AOE技能应伤害第二个目标")
	_expect(target.combat_effects.any(func(effect): return str(effect.get("kind", "")) == "dot"), "蚀骨毒雾应附加 DOT")
	_expect(second_target.combat_effects.any(func(effect): return str(effect.get("kind", "")) == "dot"), "AOE技能应向第二个目标附加 DOT")
	var hp_after_poison := int(enemy_data.get("hp", 0))
	for _turn in range(3):
		target.tick_turn_start()
		target.tick_turn_end()
	_expect(hp_after_poison - int(enemy_data.get("hp", 0)) == 6, "毒雾三回合应累计造成 6 点 DOT")
	_expect(not target.combat_effects.any(func(effect): return str(effect.get("kind", "")) == "dot"), "三次结算后 DOT 应移除")

	member.get("stats", {})["hp"] = 20
	var hp_before_heal := int(member.get("stats", {}).get("hp", 0))
	var heal_result := _cast_skill("heal", caster, [caster])
	_expect(int(heal_result.get("heal", 0)) > 0 and int(member.get("stats", {}).get("hp", 0)) > hp_before_heal, "回春术应恢复自身气血")

	var attack_before := caster.total_stat("attack")
	_cast_skill("attack_up", caster, [caster])
	_expect(caster.total_stat("attack") == attack_before + 2, "燃锋诀应提高 2 点攻击")
	caster.tick_turn_end()
	for _turn in range(2):
		caster.tick_turn_end()
		_expect(caster.total_stat("attack") == attack_before + 2, "燃锋诀应覆盖三个后续自身回合")
	caster.tick_turn_end()
	_expect(caster.total_stat("attack") == attack_before, "燃锋诀三回合后应移除")

	_cast_skill("spirit_shield", caster, [caster])
	var shield_context := {"blocked_by_shield": 0}
	var remaining := caster.apply_shields(13, shield_context)
	_expect(remaining == 3 and int(shield_context.get("blocked_by_shield", 0)) == 10, "玄甲术应吸收 10 点伤害")
	_expect(not caster.combat_effects.any(func(effect): return str(effect.get("kind", "")) == "shield"), "护盾耗尽后应移除")

	caster.queue_free()
	target.queue_free()
	second_target.queue_free()


func _test_controller_timing() -> void:
	var state := GameState.new()
	var candidate_id := str(state.recruit_candidates[0].get("candidate_id", ""))
	if not state.recruit_candidate(candidate_id):
		_expect(false, "回合时序测试应能招募角色")
		return
	var member_id := state.default_party_member_id()
	var member: Dictionary = state.member_by_id(member_id)
	member["skills"] = [DataTables.create_skill("attack_up")]
	member.get("stats", {})["mp"] = 40

	var actor_scene := load("res://scripts/actors/actor.tscn") as PackedScene
	var actor := actor_scene.instantiate() as ActorController
	add_child(actor)
	actor.configure_member(member, 0)
	var combat_scene := load("res://scripts/game/combat/combat_controller.tscn") as PackedScene
	var combat := combat_scene.instantiate() as CombatController
	add_child(combat)
	combat.set_party_views({member_id: actor})
	combat.begin_encounter(state, null, "training_dummy", 1)
	combat.tick(1.0 / 60.0, state)
	var combatant: Dictionary = combat.party_combatants[0]
	_expect(str(combatant.get("state", "")) == CombatController.STATE_SKILL, "技能开始后应进入 SKILL 状态")
	var skill_scene: SkillSceneBase = combat._active_skill_scenes.get(member_id) as SkillSceneBase
	_expect(skill_scene != null, "战斗控制器应保留正在播放的技能场景")
	if skill_scene != null:
		_expect(skill_scene.global_position.distance_to(actor.effect_position()) < 0.1, "增益特效应锚定施法者效果点")
		skill_scene._process(0.2)
		_expect(str(combat.party_combatants[0].get("state", "")) == CombatController.STATE_SKILL, "动画结束前不得推进回合")
		skill_scene._process(2.0)
		_expect(combat._turn_phase == CombatController.PHASE_ENEMY, "单人技能动画结束后应进入敌方回合")
		_expect(int(combat.party_combatants[0].get("skill_cooldowns", {}).get("attack_up", 0)) == 6, "技能完成后应写入六回合冷却")
	combat.clear()
	combat.queue_free()
	actor.queue_free()


func _cast_skill(skill_id: String, caster: CombatActorStatus, targets: Array) -> Dictionary:
	var skill: Dictionary = DataTables.create_skill(skill_id)
	var packed := ResourceLoader.load(str(skill.get("scene_path", "")), "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as PackedScene
	var scene := packed.instantiate() as SkillSceneBase if packed != null else null
	_expect(scene != null, "技能场景应可实例化: %s" % skill_id)
	if scene == null:
		return {}
	add_child(scene)
	var effect_node := scene.get_node_or_null("EffectSprite")
	var effect_sprite := effect_node as AnimatedSprite2D
	var effect_node_type := effect_node.get_class() if effect_node != null else "missing"
	_expect(effect_sprite != null, "技能特效应使用 AnimatedSprite2D: %s (scene=%s, node=%s)" % [skill_id, str(skill.get("scene_path", "")), effect_node_type])
	if effect_sprite != null:
		_expect(effect_sprite.sprite_frames.has_animation(&"cast"), "技能特效应提供 cast 动画: %s" % skill_id)
		_expect(effect_sprite.sprite_frames.get_frame_count(&"cast") == int(scene.frame_count), "技能特效帧数应与场景配置一致: %s" % skill_id)
	scene.setup(caster, targets, skill, resolver, rng)
	var finish_count := [0]
	scene.finished.connect(func(_result): finish_count[0] += 1)
	scene.start_cast()
	scene._process(5.0)
	scene._process(5.0)
	_expect(finish_count[0] == 1, "技能完成信号和有效帧只能触发一次: %s" % skill_id)
	var result: Dictionary = scene.last_result.duplicate(true)
	scene.queue_free()
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _write_result(text: String) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(RESULT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
