extends Node2D

## Standalone combat workbench. It intentionally owns an in-memory GameState
## and never calls SaveManager or the production main scene.

const GAME_STATE_SCRIPT := preload("res://scripts/game/core/game_state.gd")
const ACTOR_SCENE := preload("res://scripts/actors/actor.tscn")
const COMBAT_SCENE := preload("res://scripts/game/combat/combat_controller.tscn")

const VIEWPORT_SIZE := Vector2(960, 480)
const MAX_MEMBERS := 4
const MAX_SKILLS := 4
const MAX_ENEMIES := 8
const EQUIPMENT_SLOTS := ["weapon", "helmet", "armor", "leggings", "gloves", "accessory"]
const EQUIPMENT_SLOT_NAMES := {
	"weapon": "武器", "helmet": "头盔", "armor": "护甲", "leggings": "胫甲",
	"gloves": "护手", "accessory": "饰品",
}

var game_state
var combat: CombatController
var party_actors: Node2D
var actor_views: Dictionary = {}
var members: Array[Dictionary] = []
var member_equipment: Array[Dictionary] = []
var member_skill_ids: Array[Array] = []
var member_enabled: Array[bool] = []
var enemy_id := "training_dummy"
var enemy_count := 1
var battle_started := false

var member_list: VBoxContainer
var battle_status_label: Label
var enemy_option: OptionButton
var enemy_count_spin: SpinBox
var add_member_button: Button
var start_button: Button
var reset_button: Button


func _ready() -> void:
	_build_runtime_nodes()
	_build_ui()
	reset_configuration()


func _process(delta: float) -> void:
	if combat != null and combat.active:
		combat.tick(delta, game_state)
		if combat.is_finished():
			battle_started = false
	_update_status()


## Public sandbox API for MCP game_eval and UI controls.
func reset_configuration() -> void:
	reset_battle()
	game_state = GAME_STATE_SCRIPT.new()
	members.clear()
	member_equipment.clear()
	member_skill_ids.clear()
	member_enabled.clear()
	_refresh_member_list()
	_update_status("配置已清空：请添加角色并选择技能/装备")


func add_test_member() -> bool:
	if members.size() >= MAX_MEMBERS:
		return false
	var candidate: Dictionary = game_state.party_service.create_recruit_candidate(members.size(), {})
	candidate["kind"] = "companion"
	candidate["id"] = "sandbox_member_%d" % (members.size() + 1)
	candidate["name"] = "测试角色 %d" % (members.size() + 1)
	game_state.party_service.ensure_member_shape(candidate)
	members.append(candidate)
	member_equipment.append({})
	member_skill_ids.append([])
	member_enabled.append(true)
	_refresh_member_list()
	return true


func remove_test_member(index: int) -> bool:
	if index < 0 or index >= members.size():
		return false
	members.remove_at(index)
	member_equipment.remove_at(index)
	member_skill_ids.remove_at(index)
	member_enabled.remove_at(index)
	_refresh_member_list()
	return true


func set_member_equipment(index: int, slot: String, template_id: String, rarity: String = "t1") -> bool:
	if index < 0 or index >= members.size() or not EQUIPMENT_SLOTS.has(slot):
		return false
	if not DataTables.content_has("equipment", template_id, DataTables.EQUIPMENT_DEFS):
		return false
	if not DataTables.EQUIPMENT_RARITY_ORDER.has(rarity):
		rarity = "t1"
	var resolved_slot := "accessory_1" if slot == "accessory" else slot
	member_equipment[index][resolved_slot] = {
		"template_id": template_id,
		"rarity": rarity,
	}
	_refresh_member_list()
	return true


func set_member_skills(index: int, skill_ids: Array) -> bool:
	if index < 0 or index >= members.size():
		return false
	var resolved: Array = []
	for raw_id in skill_ids:
		if resolved.size() >= MAX_SKILLS:
			break
		var skill_id := str(raw_id)
		if not DataTables.content_has("skill", skill_id, DataTables.SKILL_DEFS):
			return false
		var skill := DataTables.create_skill(skill_id, "debug")
		if skill.is_empty():
			return false
		resolved.append(skill)
	members[index]["skills"] = resolved
	member_skill_ids[index] = resolved.map(func(value): return str(value.get("id", "")))
	_refresh_member_list()
	return true


func set_member_enabled(index: int, enabled: bool) -> bool:
	if index < 0 or index >= members.size():
		return false
	member_enabled[index] = enabled
	_refresh_member_list()
	return true


func set_enemy(selected_id: String, count: int) -> bool:
	if not DataTables.content_has("enemy", selected_id, DataTables.ENEMY_TEMPLATES):
		return false
	enemy_id = selected_id
	enemy_count = clampi(count, 1, MAX_ENEMIES)
	if enemy_option != null:
		for i in range(enemy_option.item_count):
			if str(enemy_option.get_item_metadata(i)) == enemy_id:
				enemy_option.select(i)
				break
		if enemy_count_spin != null:
			enemy_count_spin.value = enemy_count
	_update_status()
	return true


func start_battle() -> bool:
	var enabled_count := 0
	for enabled in member_enabled:
		if enabled:
			enabled_count += 1
	if enabled_count == 0 or combat == null:
		return false
	reset_battle()
	game_state.companions.clear()
	game_state.party_order.clear()
	for index in range(members.size()):
		if not member_enabled[index]:
			continue
		var member: Dictionary = members[index]
		game_state.companions.append(member.duplicate(true))
		game_state.party_order.append(str(member.get("id", "")))
	game_state.party_service.ensure_party_state()
	for index in range(member_equipment.size()):
		var member_id := str(members[index].get("id", ""))
		for slot in member_equipment[index].keys():
			var config: Dictionary = member_equipment[index][slot]
			var item := DataTables.create_equipment_from_template(str(config.get("template_id", "")), 1, game_state.rng, 0, "", str(config.get("rarity", "t1")), "debug")
			if item.is_empty():
				continue
			game_state.add_inventory_instance(item)
			game_state.equip_item_for_member(str(item.get("instance_id", "")), member_id)
	actor_views.clear()
	for index in range(members.size()):
		if not member_enabled[index]:
			continue
		var member: Dictionary = game_state.member_by_id(str(members[index].get("id", "")))
		var actor := ACTOR_SCENE.instantiate() as ActorController
		party_actors.add_child(actor)
		actor.configure_member(member, index)
		actor_views[str(member.get("id", ""))] = actor
	combat.set_party_views(actor_views)
	var ids: Array[String] = []
	for _i in range(enemy_count):
		ids.append(enemy_id)
	combat.begin_encounter(game_state, null, ids, enemy_count)
	battle_started = combat.active
	_update_status()
	return battle_started


func reset_battle() -> void:
	if combat != null:
		combat.clear()
	if party_actors != null:
		for child in party_actors.get_children():
			child.free()
	actor_views.clear()
	battle_started = false
	_update_status()


func debug_snapshot() -> Dictionary:
	var member_snapshot: Array = []
	for i in range(members.size()):
		var member: Dictionary = members[i]
		member_snapshot.append({
			"index": i,
			"id": str(member.get("id", "")),
			"name": str(member.get("name", "")),
			"enabled": member_enabled[i],
			"skills": member_skill_ids[i].duplicate(),
			"equipment": member_equipment[i].duplicate(true),
		})
	return {
		"members": member_snapshot,
		"enemy_id": enemy_id,
		"enemy_count": enemy_count,
		"battle_started": battle_started,
		"combat": combat.combat_status() if combat != null else {},
	}


func _build_runtime_nodes() -> void:
	party_actors = Node2D.new()
	party_actors.name = "PartyActors"
	add_child(party_actors)
	combat = COMBAT_SCENE.instantiate() as CombatController
	combat.name = "CombatController"
	add_child(combat)
	combat.log_added.connect(func(message: String): _update_status(message))


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugCanvas"
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)
	var background := ColorRect.new()
	background.color = Color(0.063, 0.098, 0.137, 0.88)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var battle_panel := ColorRect.new()
	battle_panel.position = Vector2(410, 0)
	battle_panel.size = Vector2(550, 480)
	battle_panel.color = Color(0.094, 0.153, 0.204, 0.72)
	root.add_child(battle_panel)
	var title := Label.new()
	title.text = "战斗测试沙盒"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "临时 GameState · 不写入正式存档 · MCP 可调试"
	subtitle.position = Vector2(20, 44)
	subtitle.modulate = Color("9fb3c8")
	root.add_child(subtitle)
	member_list = VBoxContainer.new()
	member_list.position = Vector2(20, 82)
	member_list.size = Vector2(370, 270)
	member_list.clip_contents = true
	member_list.add_theme_constant_override("separation", 6)
	root.add_child(member_list)
	add_member_button = Button.new()
	add_member_button.text = "+ 添加测试角色"
	add_member_button.position = Vector2(20, 360)
	add_member_button.size = Vector2(170, 32)
	add_member_button.pressed.connect(add_test_member)
	root.add_child(add_member_button)
	reset_button = Button.new()
	reset_button.text = "重置战斗"
	reset_button.position = Vector2(200, 360)
	reset_button.size = Vector2(100, 32)
	reset_button.pressed.connect(reset_battle)
	root.add_child(reset_button)
	start_button = Button.new()
	start_button.text = "开始战斗"
	start_button.position = Vector2(305, 360)
	start_button.size = Vector2(85, 32)
	start_button.pressed.connect(start_battle)
	root.add_child(start_button)
	var enemy_title := Label.new()
	enemy_title.text = "敌人配置"
	enemy_title.position = Vector2(20, 405)
	root.add_child(enemy_title)
	enemy_option = OptionButton.new()
	enemy_option.position = Vector2(105, 401)
	enemy_option.size = Vector2(180, 32)
	root.add_child(enemy_option)
	for id in DataTables.ENEMY_TEMPLATES.keys():
		var data: Dictionary = DataTables.ENEMY_TEMPLATES[id]
		enemy_option.add_item("%s (%s)" % [data.get("name", id), id])
		enemy_option.set_item_metadata(enemy_option.item_count - 1, str(id))
	enemy_option.item_selected.connect(func(index: int): enemy_id = str(enemy_option.get_item_metadata(index)); _update_status())
	var count_label := Label.new()
	count_label.text = "数量"
	count_label.position = Vector2(292, 408)
	root.add_child(count_label)
	enemy_count_spin = SpinBox.new()
	enemy_count_spin.position = Vector2(332, 401)
	enemy_count_spin.size = Vector2(72, 32)
	enemy_count_spin.min_value = 1
	enemy_count_spin.max_value = MAX_ENEMIES
	enemy_count_spin.step = 1
	enemy_count_spin.value = enemy_count
	enemy_count_spin.value_changed.connect(func(value: float): enemy_count = clampi(int(value), 1, MAX_ENEMIES); _update_status())
	root.add_child(enemy_count_spin)
	battle_status_label = Label.new()
	battle_status_label.position = Vector2(430, 18)
	battle_status_label.size = Vector2(510, 64)
	battle_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_status_label.modulate = Color("d7e3ef")
	root.add_child(battle_status_label)
	var hint := Label.new()
	hint.text = "战斗状态 / 当前回合"
	hint.position = Vector2(430, 92)
	hint.modulate = Color("9fb3c8")
	root.add_child(hint)


func _refresh_member_list() -> void:
	if member_list == null:
		return
	for child in member_list.get_children():
		child.queue_free()
	for index in range(members.size()):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(370, 54)
		row.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = "%d. %s" % [index + 1, members[index].get("name", "角色")]
		label.custom_minimum_size = Vector2(100, 30)
		row.add_child(label)
		var enabled := CheckButton.new()
		enabled.button_pressed = member_enabled[index]
		enabled.tooltip_text = "是否加入本场战斗"
		enabled.toggled.connect(func(value: bool): set_member_enabled(index, value))
		row.add_child(enabled)
		var skill_button := OptionButton.new()
		skill_button.text = "技能配置"
		skill_button.custom_minimum_size = Vector2(90, 30)
		for skill_id in DataTables.SKILL_DEFS.keys():
			var skill: Dictionary = DataTables.SKILL_DEFS[skill_id]
			skill_button.add_item(str(skill.get("name", skill_id)))
			skill_button.set_item_metadata(skill_button.item_count - 1, str(skill_id))
		skill_button.item_selected.connect(func(option_index: int):
			var selected := str(skill_button.get_item_metadata(option_index))
			var current: Array = member_skill_ids[index].duplicate()
			if not current.has(selected): current.append(selected)
			set_member_skills(index, current)
		)
		row.add_child(skill_button)
		var equip_button := OptionButton.new()
		equip_button.text = "装备"
		equip_button.custom_minimum_size = Vector2(74, 30)
		for template_id in DataTables.EQUIPMENT_DEFS.keys():
			equip_button.add_item(str(template_id))
			equip_button.set_item_metadata(equip_button.item_count - 1, str(template_id))
		equip_button.item_selected.connect(func(option_index: int):
			set_member_equipment(index, "weapon", str(equip_button.get_item_metadata(option_index)), "t1")
		)
		row.add_child(equip_button)
		var remove := Button.new()
		remove.text = "×"
		remove.tooltip_text = "移除角色"
		remove.custom_minimum_size = Vector2(24, 30)
		remove.pressed.connect(func(): remove_test_member(index))
		row.add_child(remove)
		member_list.add_child(row)
	if add_member_button != null:
		add_member_button.disabled = members.size() >= MAX_MEMBERS


func _update_status(message: String = "") -> void:
	if battle_status_label == null:
		return
	var status := "配置角色 %d/%d · 敌人 %s x%d" % [members.size(), MAX_MEMBERS, enemy_id, enemy_count]
	if combat != null and combat.active:
		var snapshot := combat.combat_status()
		status += "\n战斗中：第%d轮 · %s · 敌人序列 %d/%d" % [snapshot.get("round", 0), snapshot.get("turn_phase", ""), int(snapshot.get("enemy_index", 0)) + 1, snapshot.get("enemy_count", 0)]
	elif not message.is_empty():
		status += "\n" + message
	else:
		status += "\n等待开始"
	battle_status_label.text = status
