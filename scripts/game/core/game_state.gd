class_name GameState
extends RefCounted

signal changed
signal log_added(message: String)

const FARM_SLOT_COUNT := 5
const FARM_STATUS_EMPTY := "empty"
const FARM_STATUS_GROWING := "growing"
const FARM_STATUS_READY := "ready"
const PLAYER_ID := "player"
const PARTY_MAX_SIZE := 4
const RECRUIT_COST_MATERIAL := 2
const LEVEL_ATTRIBUTE_POINTS := 5
const SAVE_SCHEMA_VERSION := 2
const RECRUIT_NAME_PARTS := ["青岚", "赤霄", "玄石", "白羽", "沧流", "云舟", "明河", "素问", "照夜", "归尘"]
const RANDOM_POINT_TARGETS := ["attack", "defense", "root_bone", "max_hp", "max_mp", "element_wood", "element_fire", "element_earth", "element_metal", "element_water"]

var rng := RandomNumberGenerator.new()
var stats := {
	"level": 1,
	"level_cap": 10,
	"stage": 1,
	"root_bone": 5,
	"farm_level": 1,
	"exp": 0,
	"next_exp": 40,
	"free_points": 0,
	"hp": 80,
	"max_hp": 80,
	"mp": 40,
	"max_mp": 40,
	"attack": 8,
	"defense": 2,
	"cultivation": 0,
	"next_cultivation": 30,
}
var elements := {
	"wood": 1,
	"fire": 1,
	"earth": 1,
	"metal": 1,
	"water": 1,
}
var task_exp := {
	"recruit": 0,
	"farm": 0,
	"forge": 0,
	"alchemy": 0,
	"fight": 0,
}
var inventory: Array = []
var inventory_service: InventoryService
var equipped := {
	"weapon": "",
	"helmet": "",
	"armor": "",
	"leggings": "",
	"gloves": "",
	"accessory_1": "",
	"accessory_2": "",
}
var skills := [DataTables.create_skill()]
var known_alchemy_recipes: Array[String] = []
var companions: Array[Dictionary] = []
var party_order: Array[String] = [PLAYER_ID]
var recruit_candidates: Array[Dictionary] = []
var party_service: PartyService
var active_buffs: Array = []
var farm_slots: Array[Dictionary] = []
var farm_speed_buffs: Array[Dictionary] = []
var progress_states := {
	"alchemy": {"status": "not_started", "title": "Alchemy", "detail": "未开始", "completed": false, "claimable": false},
	"forge": {"status": "not_started", "title": "Forge", "detail": "未开始", "completed": false, "claimable": false},
	"farm": {"status": "not_started", "title": "Farm", "detail": "未开始", "completed": false, "claimable": false},
}


func _init() -> void:
	inventory_service = InventoryService.new(self)
	party_service = PartyService.new(self)
	rng.randomize()
	_ensure_farm_slots()
	_ensure_party_state()
	add_inventory_item("herb", 4, false)
	add_inventory_item("ore", 4, false)
	add_inventory_item("stat_stone_attack_t1", 2, false)
	add_inventory_item("stat_stone_defense_t1", 2, false)
	add_inventory_item("spirit_stone_fire_t1", 2, false)
	add_inventory_item("spirit_stone_earth_t1", 2, false)
	add_inventory_item("farm_speed_talisman", 1, false)
	add_inventory_item("recipe_pill", 1, false)
	generate_recruit_candidates(false)


func to_save_data() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"rng": _rng_save_data(),
		"stats": stats.duplicate(true),
		"elements": elements.duplicate(true),
		"task_exp": task_exp.duplicate(true),
		"inventory": inventory.duplicate(true),
		"equipped": equipped.duplicate(true),
		"skills": skills.duplicate(true),
		"known_alchemy_recipes": known_alchemy_recipes.duplicate(),
		"companions": companions.duplicate(true),
		"party_order": party_order.duplicate(),
		"recruit_candidates": recruit_candidates.duplicate(true),
		"active_buffs": active_buffs.duplicate(true),
		"farm_slots": farm_slots.duplicate(true),
		"farm_speed_buffs": farm_speed_buffs.duplicate(true),
		"progress_states": progress_states.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	_load_rng_state(data.get("rng", {}))
	_load_dictionary_values(stats, data.get("stats", {}))
	_load_dictionary_values(elements, data.get("elements", {}))
	_load_dictionary_values(task_exp, data.get("task_exp", {}))
	if data.has("inventory"):
		inventory = _duplicate_array(data.get("inventory", []))
	_load_dictionary_values(equipped, data.get("equipped", {}))
	if data.has("skills"):
		skills = _duplicate_array(data.get("skills", skills))
	if data.has("known_alchemy_recipes"):
		known_alchemy_recipes.clear()
		for recipe_id in data.get("known_alchemy_recipes", []):
			known_alchemy_recipes.append(str(recipe_id))
	if data.has("companions"):
		companions.assign(_duplicate_array(data.get("companions", [])))
	if data.has("party_order"):
		party_order.clear()
		for member_id in data.get("party_order", [PLAYER_ID]):
			party_order.append(str(member_id))
	if data.has("recruit_candidates"):
		recruit_candidates.assign(_duplicate_array(data.get("recruit_candidates", [])))
	if data.has("active_buffs"):
		active_buffs = _duplicate_array(data.get("active_buffs", []))
	if data.has("farm_slots"):
		farm_slots.assign(_duplicate_array(data.get("farm_slots", [])))
	if data.has("farm_speed_buffs"):
		farm_speed_buffs.assign(_duplicate_array(data.get("farm_speed_buffs", [])))
	_ensure_farm_slots()
	_sanitize_loaded_inventory()
	_sanitize_active_buffs()
	_sanitize_farm_speed_buffs()
	_ensure_party_state()
	_ensure_recruit_candidate_growth()
	_migrate_free_points_to_auto_growth()
	if recruit_candidates.is_empty():
		generate_recruit_candidates(false)
	_load_progress_states(data.get("progress_states", {}))
	_clamp_runtime_stats()
	_refresh_farm_progress_state()
	changed.emit()


func _rng_save_data() -> Dictionary:
	return {
		"seed": int(rng.seed),
		"state": int(rng.state),
	}


func _load_rng_state(source) -> void:
	if not source is Dictionary:
		return
	if source.has("seed"):
		rng.seed = int(source.get("seed", rng.seed))
	if source.has("state"):
		rng.state = int(source.get("state", rng.state))


func _load_progress_states(source) -> void:
	if not source is Dictionary:
		return
	for key in progress_states.keys():
		var progress: Dictionary = progress_states[key]
		var loaded: Dictionary = source.get(key, {})
		progress["status"] = str(loaded.get("status", progress.get("status", "not_started")))
		progress["title"] = str(loaded.get("title", progress.get("title", key)))
		progress["detail"] = str(loaded.get("detail", progress.get("detail", "未开始")))
		progress["completed"] = bool(loaded.get("completed", progress.get("completed", false)))
		progress["claimable"] = bool(loaded.get("claimable", progress.get("claimable", false)))
		progress_states[key] = progress


func set_progress_state(progress_id: String, status: String, detail := "") -> void:
	if not progress_states.has(progress_id):
		return
	var progress: Dictionary = progress_states[progress_id]
	progress["status"] = status
	progress["detail"] = detail if not detail.is_empty() else str(progress.get("detail", ""))
	progress["completed"] = status == "completed" or status == "claimable"
	progress["claimable"] = status == "claimable"
	progress_states[progress_id] = progress
	changed.emit()


func clear_progress_state(progress_id: String) -> void:
	if not progress_states.has(progress_id):
		return
	var progress: Dictionary = progress_states[progress_id]
	progress["status"] = "not_started"
	progress["detail"] = "未开始"
	progress["completed"] = false
	progress["claimable"] = false
	progress_states[progress_id] = progress
	changed.emit()


func progress_state(progress_id: String) -> Dictionary:
	return progress_states.get(progress_id, {}).duplicate(true)


func _load_dictionary_values(target: Dictionary, source) -> void:
	if not source is Dictionary:
		return
	for key in source.keys():
		target[key] = source[key]


func _duplicate_array(value) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


func _sanitize_loaded_inventory() -> void:
	for index in range(inventory.size() - 1, -1, -1):
		if not inventory[index] is Dictionary:
			inventory.remove_at(index)
			continue
		var item: Dictionary = inventory[index]
		var item_id := str(item.get("item_id", ""))
		var item_type := str(item.get("type", ""))
		if item_id.is_empty() or item_type.is_empty():
			inventory.remove_at(index)
			continue
		item["instance_id"] = str(item.get("instance_id", item_id))
		item["count"] = maxi(1, int(item.get("count", 1)))
		item["payload"] = item.get("payload", {}) if item.get("payload", {}) is Dictionary else {}
		if item_type == DataTables.ITEM_TYPE_EQUIPMENT:
			_sanitize_loaded_equipment(item)
		else:
			_sanitize_loaded_stack_item(item)
		inventory[index] = item


func _sanitize_loaded_stack_item(item: Dictionary) -> void:
	var item_id := str(item.get("item_id", ""))
	var definition := DataTables.item_definition(item_id)
	if definition.is_empty():
		return
	item["name"] = str(item.get("name", definition.get("name", item_id)))
	item["description"] = str(item.get("description", definition.get("description", "")))
	item["type"] = str(item.get("type", definition.get("type", "")))
	item["stackable"] = bool(item.get("stackable", definition.get("stackable", true)))
	item["usable"] = bool(item.get("usable", definition.get("usable", false)))
	item["gain_target"] = str(item.get("gain_target", definition.get("gain_target", "none")))
	item["obtain_source"] = str(item.get("obtain_source", "non_drop"))


func _sanitize_loaded_equipment(item: Dictionary) -> void:
	item["stackable"] = false
	item["usable"] = bool(item.get("usable", true))
	item["slot"] = str(item.get("slot", "weapon"))
	item["rarity"] = str(item.get("rarity", "t1"))
	item["equipment_level"] = maxi(1, int(item.get("equipment_level", 1)))
	item["base_attributes"] = _duplicate_array(item.get("base_attributes", []))
	item["enhanced_attributes"] = _duplicate_array(item.get("enhanced_attributes", []))
	item["refine_affixes"] = _duplicate_array(item.get("refine_affixes", []))
	item["affixes"] = _duplicate_array(item.get("affixes", []))
	item["enhance_count"] = maxi(0, int(item.get("enhance_count", 0)))
	item["refine_count"] = maxi(0, int(item.get("refine_count", 0)))
	item["equipped"] = bool(item.get("equipped", false))
	item["equipped_by"] = str(item.get("equipped_by", ""))
	item["equip_requirement"] = item.get("equip_requirement", {}) if item.get("equip_requirement", {}) is Dictionary else {}
	_update_equipment_compat_bonuses(item)


func _sanitize_active_buffs() -> void:
	for index in range(active_buffs.size() - 1, -1, -1):
		if not active_buffs[index] is Dictionary:
			active_buffs.remove_at(index)
			continue
		var buff: Dictionary = active_buffs[index]
		buff["item_id"] = str(buff.get("item_id", ""))
		buff["name"] = str(buff.get("name", DataTables.resource_name(str(buff.get("item_id", "")))))
		buff["stat"] = str(buff.get("stat", ""))
		buff["amount"] = int(buff.get("amount", 0))
		buff["remaining"] = float(buff.get("remaining", 0.0))
		if str(buff.get("item_id", "")).is_empty() or str(buff.get("stat", "")).is_empty() or float(buff.get("remaining", 0.0)) <= 0.0:
			active_buffs.remove_at(index)
			continue
		active_buffs[index] = buff


func _sanitize_farm_speed_buffs() -> void:
	for index in range(farm_speed_buffs.size() - 1, -1, -1):
		if not farm_speed_buffs[index] is Dictionary:
			farm_speed_buffs.remove_at(index)
			continue
		var buff: Dictionary = farm_speed_buffs[index]
		buff["item_id"] = str(buff.get("item_id", ""))
		buff["multiplier"] = max(1.0, float(buff.get("multiplier", 1.0)))
		buff["remaining_seconds"] = float(buff.get("remaining_seconds", 0.0))
		if str(buff.get("item_id", "")).is_empty() or float(buff.get("remaining_seconds", 0.0)) <= 0.0:
			farm_speed_buffs.remove_at(index)
			continue
		farm_speed_buffs[index] = buff


func player_member() -> Dictionary:
	return party_service.player_member()


func growth_summary_for(member_id: String) -> String:
	return party_service.growth_summary_for(member_id)


func party_members() -> Array:
	return party_service.party_members()


func active_party_members() -> Array:
	return party_service.active_party_members()


func member_by_id(member_id: String) -> Dictionary:
	return party_service.member_by_id(member_id)


func party_member_count() -> int:
	return party_service.party_member_count()


func selected_party_member_or_player(member_id: String) -> Dictionary:
	return party_service.selected_party_member_or_player(member_id)


func generate_recruit_candidates(should_emit_signal := true) -> void:
	party_service.generate_recruit_candidates(should_emit_signal)


func recruit_candidate(candidate_id: String) -> bool:
	return party_service.recruit_candidate(candidate_id)


func move_party_member(member_id: String, direction: int) -> bool:
	return party_service.move_party_member(member_id, direction)


func dismiss_companion(member_id: String) -> bool:
	return party_service.dismiss_companion(member_id)


func can_recruit() -> bool:
	return party_service.can_recruit()


func total_attack_for(member_id: String) -> int:
	var member := selected_party_member_or_player(member_id)
	return _total_attack_for_member(member)


func total_defense_for(member_id: String) -> int:
	var member := selected_party_member_or_player(member_id)
	return _total_defense_for_member(member)


func total_stat_for(member_id: String, stat_id: String) -> int:
	var member := selected_party_member_or_player(member_id)
	return _total_stat_for_member(member, stat_id)


func total_element_for(member_id: String, element_id: String) -> int:
	var member := selected_party_member_or_player(member_id)
	return _total_element_for_member(member, element_id)


func element_summary_for(member_id: String) -> String:
	var member := selected_party_member_or_player(member_id)
	return "木%d 火%d 土%d 金%d 水%d" % [
		_total_element_for_member(member, "wood"),
		_total_element_for_member(member, "fire"),
		_total_element_for_member(member, "earth"),
		_total_element_for_member(member, "metal"),
		_total_element_for_member(member, "water"),
	]


func dominant_element_for(member_id: String) -> String:
	return _dominant_element_for_member(selected_party_member_or_player(member_id))


func element_damage_bonus_for(member_id: String, element_id: String) -> int:
	return int(total_element_for(member_id, element_id) * 0.5)


func reduce_physical_damage_for(member_id: String, amount: int) -> int:
	return max(1, amount - total_defense_for(member_id))


func reduce_element_damage_for(member_id: String, element_id: String, amount: int) -> int:
	return max(0, amount - int(total_element_for(member_id, element_id) * 0.35))


func take_damage_for(member_id: String, amount: int, element_id := "") -> int:
	var member := selected_party_member_or_player(member_id)
	var member_stats: Dictionary = member.get("stats", {})
	var final_amount := reduce_physical_damage_for(member_id, amount)
	if not element_id.is_empty():
		final_amount = reduce_element_damage_for(member_id, element_id, final_amount)
	member_stats["hp"] = max(0, int(member_stats.get("hp", 0)) - final_amount)
	changed.emit()
	return final_amount


func spend_mp_for(member_id: String, amount: int) -> bool:
	var member := selected_party_member_or_player(member_id)
	var member_stats: Dictionary = member.get("stats", {})
	if int(member_stats.get("mp", 0)) < amount:
		return false
	member_stats["mp"] = int(member_stats.get("mp", 0)) - amount
	changed.emit()
	return true


func heal_member(member_id: String, hp_amount: int, mp_amount: int) -> Dictionary:
	var member := selected_party_member_or_player(member_id)
	var member_stats: Dictionary = member.get("stats", {})
	var old_hp := int(member_stats.get("hp", 0))
	var old_mp := int(member_stats.get("mp", 0))
	member_stats["hp"] = min(_total_stat_for_member(member, "max_hp"), old_hp + hp_amount)
	member_stats["mp"] = min(_total_stat_for_member(member, "max_mp"), old_mp + mp_amount)
	changed.emit()
	return {"hp": int(member_stats.get("hp", 0)) - old_hp, "mp": int(member_stats.get("mp", 0)) - old_mp}


func allocate_attribute_point(_member_id: String, _target: String) -> bool:
	log_added.emit("手动加点已取消，升级时会自动分配属性")
	return false


func add_exp_for_member(member_id: String, amount: int) -> void:
	party_service.add_exp_for_member(member_id, amount)


func add_exp_to_party(amount: int) -> void:
	party_service.add_exp_to_party(amount)


func equipped_item_for(member_id: String, slot: String):
	var member := selected_party_member_or_player(member_id)
	var member_equipped: Dictionary = member.get("equipped", {})
	var instance_id: String = str(member_equipped.get(slot, ""))
	if instance_id.is_empty():
		return {}
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty():
		return {}
	return item


func equip_item_for_member(instance_id: String, member_id: String) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var member := selected_party_member_or_player(member_id)
	var slot: String = _equipment_slot_for_member(item, member)
	var member_equipped: Dictionary = member.get("equipped", {})
	var previous_id: String = str(member_equipped.get(slot, ""))
	if previous_id == instance_id:
		log_added.emit("%s已由%s装备" % [item.get("name", "装备"), member.get("name", "成员")])
		return true
	if not equipment_requirement_met_for(item, member_id, slot):
		var requirement_text := equipment_requirement_text_for(item, member_id)
		log_added.emit("%s穿戴需求不足：%s" % [item.get("name", "装备"), requirement_text])
		return false
	_unequip_if_needed(instance_id)
	if not previous_id.is_empty():
		_unequip_if_needed(previous_id)
	item["equipped"] = true
	item["equipped_by"] = str(member.get("id", PLAYER_ID))
	item["equipped_slot"] = slot
	member_equipped[slot] = instance_id
	log_added.emit("%s穿戴%s" % [member.get("name", "成员"), item.get("name", "装备")])
	changed.emit()
	return true


func equipment_requirement_met_for(item: Dictionary, member_id: String, target_slot := "") -> bool:
	var requirement: Dictionary = item.get("equip_requirement", {})
	if requirement.is_empty():
		return true
	return equipment_requirement_current_value_for(item, member_id, target_slot) >= int(requirement.get("min", 0))


func equipment_requirement_current_value_for(item: Dictionary, member_id: String, target_slot := "") -> int:
	var requirement: Dictionary = item.get("equip_requirement", {})
	var stat_id: String = str(requirement.get("stat", ""))
	if stat_id.is_empty():
		return 0
	var member := selected_party_member_or_player(member_id)
	var excluded_slot := str(target_slot)
	if excluded_slot.is_empty():
		excluded_slot = _equipment_slot_for_member(item, member)
	return _total_requirement_stat_excluding_slot_for(member, stat_id, excluded_slot)


func equipment_requirement_text_for(item: Dictionary, member_id: String) -> String:
	var requirement: Dictionary = item.get("equip_requirement", {})
	if requirement.is_empty():
		return ""
	var stat_id: String = str(requirement.get("stat", ""))
	var current := equipment_requirement_current_value_for(item, member_id)
	var needed := int(requirement.get("min", 0))
	var status: String = "已达标" if current >= needed else "未达标"
	return "%s %d / 当前 %d（%s）" % [DataTables.attribute_display_name(stat_id), needed, current, status]


func _ensure_party_state() -> void:
	party_service.ensure_party_state()


func _ensure_member_shape(member: Dictionary) -> void:
	party_service.ensure_member_shape(member)


func _base_member_stats() -> Dictionary:
	return party_service.base_member_stats()


func _base_member_elements() -> Dictionary:
	return party_service.base_member_elements()


func _base_equipped_slots() -> Dictionary:
	return party_service.base_equipped_slots()


func _companion_exists(member_id: String) -> bool:
	return party_service.companion_exists(member_id)


func _sync_equipped_ownership() -> void:
	party_service.sync_equipped_ownership()


func _sanitize_equipped_for_member(member_id: String, member_equipped: Dictionary) -> Dictionary:
	return party_service.sanitize_equipped_for_member(member_id, member_equipped)


func _create_recruit_candidate(index: int, used_names: Dictionary) -> Dictionary:
	return party_service.create_recruit_candidate(index, used_names)


func _random_recruit_name(used_names: Dictionary) -> String:
	return party_service.random_recruit_name(used_names)


func _candidate_by_id(candidate_id: String) -> Dictionary:
	return party_service.candidate_by_id(candidate_id)


func growth_summary_for_member_data(member: Dictionary) -> String:
	return party_service.growth_summary_for_member_data(member)


func _ensure_recruit_candidate_growth() -> void:
	party_service.ensure_recruit_candidate_growth()


func _migrate_free_points_to_auto_growth() -> void:
	party_service.migrate_free_points_to_auto_growth()


func _migrate_free_points_for_member(member: Dictionary) -> void:
	party_service.migrate_free_points_for_member(member)


func _apply_random_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	return party_service.apply_random_attribute_points_to(member, point_count)


func _apply_auto_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	return party_service.apply_auto_attribute_points_to(member, point_count)


func _apply_companion_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	return party_service.apply_companion_attribute_points_to(member, point_count)


func _random_growth_primary_stats() -> Array[String]:
	return party_service.random_growth_primary_stats()


func _normalized_growth_primary_stats(raw_value) -> Array[String]:
	return party_service.normalized_growth_primary_stats(raw_value)


func _growth_summary_for_member(member: Dictionary) -> String:
	return party_service.growth_summary_for_member_data(member)


func _attribute_list_text(stat_ids: Array[String]) -> String:
	return party_service.attribute_list_text(stat_ids)


func _apply_attribute_point_to(member: Dictionary, target: String, gains: Dictionary) -> void:
	party_service.apply_attribute_point_to(member, target, gains)


func _total_attack_for_member(member: Dictionary) -> int:
	return int(_total_stat_for_member(member, "attack") + int(_element_power_for_member(member) * 0.15))


func _total_defense_for_member(member: Dictionary) -> int:
	return _total_stat_for_member(member, "defense")


func _total_stat_for_member(member: Dictionary, stat_id: String) -> int:
	var member_stats: Dictionary = member.get("stats", {})
	return int(member_stats.get(stat_id, 0)) + _stat_bonus_for_member(member, stat_id) + _equipment_attribute_bonus_for_member(member, stat_id)


func _total_element_for_member(member: Dictionary, element_id: String) -> int:
	var member_elements: Dictionary = member.get("elements", {})
	return int(member_elements.get(element_id, 0)) + _equipment_attribute_bonus_for_member(member, "element_%s" % element_id)


func _element_power_for_member(member: Dictionary) -> int:
	var value := 0
	for element_id in DataTables.ELEMENT_IDS:
		value += _total_element_for_member(member, str(element_id))
	return value


func _dominant_element_for_member(member: Dictionary) -> String:
	var best_id := "wood"
	var best_value := -1
	for element_id in DataTables.ELEMENT_IDS:
		var element_value := _total_element_for_member(member, str(element_id))
		if element_value > best_value:
			best_id = str(element_id)
			best_value = element_value
	return best_id


func _stat_bonus_for_member(member: Dictionary, stat_id: String) -> int:
	var value := 0
	if str(member.get("id", "")) == PLAYER_ID:
		for buff in active_buffs:
			if buff.get("stat", "") == stat_id:
				value += int(buff.get("amount", 0))
	for item in _equipped_items_for_member(member):
		value += _item_affix_bonus(item, stat_id)
	return value


func _equipment_attribute_bonus_for_member(member: Dictionary, stat_id: String) -> int:
	var value := 0
	for item in _equipped_items_for_member(member):
		value += _item_equipment_attribute_value(item, stat_id)
	return value


func _equipped_items_for_member(member: Dictionary) -> Array:
	var items: Array = []
	var member_equipped: Dictionary = member.get("equipped", {})
	for slot in member_equipped.keys():
		var item: Dictionary = inventory_item_by_instance(str(member_equipped.get(slot, "")))
		if not item.is_empty():
			items.append(item)
	return items


func _equipment_slot_for_member(item: Dictionary, member: Dictionary) -> String:
	var slot: String = str(item.get("slot", ""))
	if slot != "accessory":
		return slot
	var member_equipped: Dictionary = member.get("equipped", {})
	if str(member_equipped.get("accessory_1", "")).is_empty():
		return "accessory_1"
	if str(member_equipped.get("accessory_2", "")).is_empty():
		return "accessory_2"
	return "accessory_1"


func _total_requirement_stat_excluding_slot_for(member: Dictionary, stat_id: String, excluded_slot: String) -> int:
	if stat_id.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
		var element_id: String = DataTables.element_id_from_attribute(stat_id)
		return int(member.get("elements", {}).get(element_id, 0)) + _equipment_attribute_bonus_excluding_slot_for(member, stat_id, excluded_slot)
	return int(member.get("stats", {}).get(stat_id, 0)) + _stat_bonus_for_member(member, stat_id) + _equipment_attribute_bonus_excluding_slot_for(member, stat_id, excluded_slot)


func _equipment_attribute_bonus_excluding_slot_for(member: Dictionary, stat_id: String, excluded_slot: String) -> int:
	var value := 0
	var member_equipped: Dictionary = member.get("equipped", {})
	for slot in member_equipped.keys():
		if str(slot) == excluded_slot:
			continue
		var item: Dictionary = inventory_item_by_instance(str(member_equipped.get(slot, "")))
		if item.is_empty():
			continue
		value += _item_equipment_attribute_value(item, stat_id)
	return value


func _unequip_all_for_member(member_id: String) -> void:
	var member := member_by_id(member_id)
	if member.is_empty():
		return
	var member_equipped: Dictionary = member.get("equipped", {})
	for slot in member_equipped.keys():
		var instance_id := str(member_equipped.get(slot, ""))
		if not instance_id.is_empty():
			_unequip_if_needed(instance_id)


func _clamp_member_runtime_stats(member: Dictionary) -> void:
	party_service.clamp_member_runtime_stats(member)


func total_attack() -> int:
	return total_attack_for(PLAYER_ID)


func total_defense() -> int:
	return total_defense_for(PLAYER_ID)


func total_stat(stat_id: String) -> int:
	return total_stat_for(PLAYER_ID, stat_id)


func total_element(element_id: String) -> int:
	return total_element_for(PLAYER_ID, element_id)


func element_power() -> int:
	var value := 0
	for element_id in elements.keys():
		value += total_element(element_id)
	return value


func dominant_element() -> String:
	return dominant_element_for(PLAYER_ID)


func cultivation_gain(base_amount: int) -> int:
	return base_amount + int(total_stat("root_bone") * 0.4)


func craft_bonus() -> int:
	return int(total_stat("root_bone") * 0.2)


func alchemy_extra_chance() -> float:
	return min(0.35, float(total_stat("root_bone")) * 0.015)


func element_damage_bonus(element_id: String) -> int:
	return element_damage_bonus_for(PLAYER_ID, element_id)


func reduce_element_damage(element_id: String, amount: int) -> int:
	return reduce_element_damage_for(PLAYER_ID, element_id, amount)


func reduce_physical_damage(amount: int) -> int:
	return reduce_physical_damage_for(PLAYER_ID, amount)


func physical_resistance() -> int:
	return total_defense()


func element_resistance(element_id: String) -> int:
	return int(total_element(element_id) * 0.35)


func heal(hp_amount: int, mp_amount: int) -> void:
	stats["hp"] = min(total_stat("max_hp"), stats["hp"] + hp_amount)
	stats["mp"] = min(total_stat("max_mp"), stats["mp"] + mp_amount)
	changed.emit()


func spend_mp(amount: int) -> bool:
	if stats["mp"] < amount:
		return false
	stats["mp"] -= amount
	changed.emit()
	return true


func take_damage(amount: int, element_id := "") -> void:
	take_damage_for(PLAYER_ID, amount, element_id)


func add_exp(amount: int) -> void:
	add_exp_for_member(PLAYER_ID, amount)


func add_cultivation(amount: int) -> void:
	var final_amount := cultivation_gain(amount)
	stats["cultivation"] += final_amount
	log_added.emit("修为 +%d" % final_amount)
	while stats["cultivation"] >= stats["next_cultivation"]:
		if not _ensure_level_cap_open():
			break
		stats["cultivation"] -= stats["next_cultivation"]
		stats["next_cultivation"] = int(stats["next_cultivation"] * 1.35) + 15
		_level_up()
	changed.emit()


func add_task_experience(task_type: int, amount: int) -> void:
	var key := DataTables.task_zone_id(task_type)
	task_exp[key] = task_exp.get(key, 0) + amount
	if key == "farm":
		_update_farm_level()
	if task_exp[key] % 10 == 0:
		log_added.emit("%s熟练度达到 %d" % [DataTables.task_name(task_type), task_exp[key]])
	changed.emit()


func gain_resource(resource_id: String, amount: int) -> void:
	if add_inventory_item(resource_id, amount, false):
		log_added.emit("获得%s x%d" % [DataTables.resource_name(resource_id), amount])
		changed.emit()


func debug_add_item(item_id: String, amount: int) -> bool:
	amount = clampi(amount, 1, 999)
	if DataTables.item_definition(item_id).is_empty():
		log_added.emit("调试添加失败：未知物品 %s" % item_id)
		return false
	if not add_inventory_item(item_id, amount, false):
		log_added.emit("调试添加失败：%s" % item_id)
		return false
	log_added.emit("调试添加：%s x%d" % [DataTables.resource_name(item_id), amount])
	changed.emit()
	return true


func debug_add_equipment(template_id: String, level: int, rarity: String) -> bool:
	if not DataTables.EQUIPMENT_DEFS.has(template_id):
		log_added.emit("调试生成装备失败：未知模板 %s" % template_id)
		return false
	if not DataTables.EQUIPMENT_RARITY_ORDER.has(rarity):
		log_added.emit("调试生成装备失败：未知稀有度 %s" % rarity)
		return false
	var equipment := DataTables.create_equipment_from_template(template_id, maxi(1, level), rng, craft_bonus(), "", rarity, "debug")
	if equipment.is_empty():
		log_added.emit("调试生成装备失败")
		return false
	add_inventory_instance(equipment)
	log_added.emit("调试生成装备：%s" % equipment.get("name", "装备"))
	return true


func debug_set_stat(stat_id: String, value: int) -> bool:
	if stats.has(stat_id):
		stats[stat_id] = _debug_clamped_stat_value(stat_id, value)
	elif elements.has(stat_id):
		elements[stat_id] = maxi(0, value)
	else:
		log_added.emit("调试设置失败：未知属性 %s" % stat_id)
		return false
	_clamp_runtime_stats()
	log_added.emit("调试设置：%s = %d" % [DataTables.attribute_display_name(stat_id), _debug_stat_value(stat_id)])
	changed.emit()
	return true


func spend_resource(resource_id: String, amount: int) -> bool:
	return inventory_service.spend_resource(resource_id, amount)


func spend_inventory_type(type_id: String, amount: int) -> bool:
	return inventory_service.spend_inventory_type(type_id, amount)


func add_inventory_item(item_id: String, amount: int, should_emit_signal := true) -> bool:
	return inventory_service.add_inventory_item(item_id, amount, should_emit_signal)


func add_inventory_instance(item: Dictionary) -> void:
	inventory_service.add_inventory_instance(item)


func inventory_items_for_type(type_id: String) -> Array:
	return inventory_service.inventory_items_for_type(type_id)


func inventory_item_count(item_id: String) -> int:
	return inventory_service.inventory_item_count(item_id)


func inventory_total_for_type(type_id: String) -> int:
	return inventory_service.inventory_total_for_type(type_id)


func inventory_item_by_instance(instance_id: String) -> Dictionary:
	return inventory_service.inventory_item_by_instance(instance_id)


func equipped_item(slot: String):
	var instance_id: String = equipped.get(slot, "")
	if instance_id.is_empty():
		return {}
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty():
		return {}
	return item


func is_inventory_item_usable(instance_id: String) -> bool:
	return inventory_service.is_inventory_item_usable(instance_id)


func is_inventory_item_direct_usable(instance_id: String) -> bool:
	return inventory_service.is_inventory_item_direct_usable(instance_id)


func use_inventory_item(instance_id: String) -> bool:
	return inventory_service.use_inventory_item(instance_id)


func use_inventory_item_for_member(instance_id: String, member_id: String) -> bool:
	return inventory_service.use_inventory_item_for_member(instance_id, member_id)


func _use_home_item(item: Dictionary) -> bool:
	if DataTables.is_farm_speed_item(str(item.get("item_id", ""))):
		return use_farm_speed_item(str(item.get("item_id", "")))
	return false


func drop_inventory_item(instance_id: String) -> bool:
	return inventory_service.drop_inventory_item(instance_id)


func add_equipment(item: Dictionary) -> void:
	add_inventory_instance(item)
	log_added.emit("获得装备：%s" % item["name"])


func resource_summary() -> String:
	return inventory_service.resource_summary()


func element_summary() -> String:
	return "木%d 火%d 土%d 金%d 水%d" % [
		elements["wood"],
		elements["fire"],
		elements["earth"],
		elements["metal"],
		elements["water"],
	]


func _debug_clamped_stat_value(stat_id: String, value: int) -> int:
	var min_one_stats := ["level", "level_cap", "stage", "farm_level", "next_exp", "next_cultivation", "max_hp", "max_mp"]
	if min_one_stats.has(stat_id):
		return maxi(1, value)
	return maxi(0, value)


func _debug_stat_value(stat_id: String) -> int:
	if stats.has(stat_id):
		return int(stats.get(stat_id, 0))
	if elements.has(stat_id):
		return int(elements.get(stat_id, 0))
	return 0


func _clamp_runtime_stats() -> void:
	stats["level"] = maxi(1, int(stats.get("level", 1)))
	stats["level_cap"] = maxi(1, int(stats.get("level_cap", 1)))
	stats["stage"] = maxi(1, int(stats.get("stage", 1)))
	stats["farm_level"] = maxi(1, int(stats.get("farm_level", 1)))
	stats["next_exp"] = maxi(1, int(stats.get("next_exp", 1)))
	stats["next_cultivation"] = maxi(1, int(stats.get("next_cultivation", 1)))
	stats["free_points"] = maxi(0, int(stats.get("free_points", 0)))
	stats["max_hp"] = maxi(1, int(stats.get("max_hp", 1)))
	stats["max_mp"] = maxi(1, int(stats.get("max_mp", 1)))
	stats["hp"] = clampi(int(stats.get("hp", 0)), 0, total_stat("max_hp"))
	stats["mp"] = clampi(int(stats.get("mp", 0)), 0, total_stat("max_mp"))


func task_exp_for(task_type: int) -> int:
	return task_exp.get(DataTables.task_zone_id(task_type), 0)


func _find_stack_item(item_id: String) -> Dictionary:
	return inventory_service.find_stack_item(item_id)


func _remove_inventory_count(item_id: String, amount: int) -> void:
	inventory_service.remove_inventory_count(item_id, amount)


func can_equip_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var slot: String = _equipment_slot_for_member(item, player_member())
	return equipment_requirement_met_for(item, PLAYER_ID, slot)


func equipment_requirement_met(item: Dictionary, target_slot := "") -> bool:
	return equipment_requirement_met_for(item, PLAYER_ID, target_slot)


func equipment_requirement_current_value(item: Dictionary, target_slot := "") -> int:
	return equipment_requirement_current_value_for(item, PLAYER_ID, target_slot)


func equipment_requirement_text(item: Dictionary) -> String:
	return equipment_requirement_text_for(item, PLAYER_ID)


func _equip_item(item: Dictionary) -> bool:
	return equip_item_for_member(str(item.get("instance_id", "")), PLAYER_ID)


func _equipment_slot_for_item(item: Dictionary) -> String:
	return _equipment_slot_for_member(item, player_member())


func _unequip_if_needed(instance_id: String) -> void:
	for slot in equipped.keys():
		if equipped[slot] == instance_id:
			equipped[slot] = ""
	for companion in companions:
		var companion_equipped: Dictionary = companion.get("equipped", {})
		for slot in companion_equipped.keys():
			if companion_equipped[slot] == instance_id:
				companion_equipped[slot] = ""
	var item := inventory_item_by_instance(instance_id)
	if not item.is_empty():
		item["equipped"] = false
		item.erase("equipped_by")
		item.erase("equipped_slot")


func _use_skill_book(item: Dictionary) -> bool:
	var skill_id: String = item.get("payload", {}).get("skill_id", "")
	if skill_id.is_empty():
		return false

	if _knows_skill(skill_id):
		log_added.emit("已经学会%s" % DataTables.create_skill(skill_id)["name"])
		return false

	var skill := DataTables.create_skill(skill_id, str(item.get("payload", {}).get("obtain_source", "non_drop")))
	skills.append(skill)
	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("学会%s" % skill["name"])
	changed.emit()
	return true


func _knows_skill(skill_id: String) -> bool:
	for skill in skills:
		if skill.get("id", "") == skill_id:
			return true
	return false


func _use_alchemy_recipe(item: Dictionary) -> bool:
	var recipe_id: String = item.get("payload", {}).get("recipe_id", "")
	if recipe_id.is_empty():
		return false
	if known_alchemy_recipes.has(recipe_id):
		log_added.emit("已学会该丹方")
		return false
	known_alchemy_recipes.append(recipe_id)
	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("学会丹方：%s" % DataTables.resource_name(recipe_id))
	changed.emit()
	return true


func _use_pill(item: Dictionary) -> bool:
	return _use_pill_for_member(item, PLAYER_ID)


func _use_pill_for_member(item: Dictionary, member_id: String) -> bool:
	var payload: Dictionary = item.get("payload", {})
	if bool(payload.get("breakthrough", false)):
		return _use_breakthrough_item(item)
	if payload.get("effect_mode", "instant") == "duration":
		var duration := float(payload.get("duration", 0.0))
		var existing_buff := _active_buff_for_item(str(item["item_id"]))
		if existing_buff.is_empty():
			active_buffs.append({
				"item_id": item["item_id"],
				"name": item["name"],
				"stat": payload.get("stat", ""),
				"amount": int(payload.get("amount", 0)),
				"remaining": duration,
			})
		else:
			existing_buff["remaining"] = float(existing_buff.get("remaining", 0.0)) + duration
		_remove_inventory_count(item["item_id"], 1)
		log_added.emit("使用%s，增益生效" % item["name"])
		changed.emit()
		return true

	var hp_amount: int = int(payload.get("hp", 0))
	var mp_amount: int = int(payload.get("mp", 0))
	var member := selected_party_member_or_player(member_id)
	var member_stats: Dictionary = member.get("stats", {})
	var old_hp: int = int(member_stats.get("hp", 0))
	var old_mp: int = int(member_stats.get("mp", 0))

	member_stats["hp"] = min(_total_stat_for_member(member, "max_hp"), old_hp + hp_amount)
	member_stats["mp"] = min(_total_stat_for_member(member, "max_mp"), old_mp + mp_amount)
	if int(member_stats.get("hp", 0)) == old_hp and int(member_stats.get("mp", 0)) == old_mp:
		log_added.emit("气血和法力已满")
		return false

	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("%s使用%s" % [member.get("name", "成员"), item["name"]])
	changed.emit()
	return true


func _use_breakthrough_item(item: Dictionary) -> bool:
	if stats["level"] < stats["level_cap"]:
		log_added.emit("尚未达到当前阶段等级上限")
		return false

	_unlock_next_stage()
	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("使用%s，突破至阶段 %d" % [item["name"], stats["stage"]])
	changed.emit()
	return true


func update_buffs(delta: float) -> void:
	if active_buffs.is_empty():
		return
	var index := 0
	while index < active_buffs.size():
		var buff: Dictionary = active_buffs[index]
		buff["remaining"] = float(buff.get("remaining", 0.0)) - delta
		if float(buff["remaining"]) <= 0.0:
			active_buffs.remove_at(index)
		else:
			index += 1
	changed.emit()


func consume_seed_for_farm() -> Dictionary:
	var slot_index := first_empty_farm_slot_index()
	if slot_index < 0:
		log_added.emit("农田已满")
		return {}
	for item in inventory:
		var item_id := str(item.get("item_id", ""))
		if DataTables.is_farm_seed(item_id) and plant_farm_slot(slot_index, item_id):
			var slot: Dictionary = farm_slots[slot_index]
			return {"item_id": item_id, "amount": int(slot.get("harvest_amount", 0)), "slot_index": slot_index}
	return {}


func first_empty_farm_slot_index() -> int:
	_ensure_farm_slots()
	for index in range(farm_slots.size()):
		if str(farm_slots[index].get("status", FARM_STATUS_EMPTY)) == FARM_STATUS_EMPTY:
			return index
	return -1


func plant_farm_slot(slot_index: int, crop_id: String) -> bool:
	_ensure_farm_slots()
	if slot_index < 0 or slot_index >= farm_slots.size():
		return false
	if str(farm_slots[slot_index].get("status", FARM_STATUS_EMPTY)) != FARM_STATUS_EMPTY:
		log_added.emit("农田槽位已有作物")
		return false
	if not DataTables.is_farm_seed(crop_id):
		log_added.emit("该物品不能种植")
		return false
	if not spend_resource(crop_id, 1):
		log_added.emit("种子不足")
		return false
	var harvest_amount := DataTables.crop_seed_yield(crop_id) + int(stats.get("farm_level", 1)) - 1
	farm_slots[slot_index] = {
		"status": FARM_STATUS_GROWING,
		"crop_id": crop_id,
		"elapsed_seconds": 0.0,
		"growth_seconds": DataTables.crop_growth_seconds(crop_id),
		"harvest_amount": max(1, harvest_amount),
	}
	set_progress_state("farm", "growing", "%s 生长中" % DataTables.resource_name(crop_id))
	log_added.emit("种下%s" % DataTables.resource_name(crop_id))
	changed.emit()
	return true


func _active_buff_for_item(item_id: String) -> Dictionary:
	for buff in active_buffs:
		if str(buff.get("item_id", "")) == item_id:
			return buff
	return {}


func update_farm(delta: float) -> void:
	_ensure_farm_slots()
	var changed_farm := false
	var multiplier := farm_speed_multiplier()
	for index in range(farm_slots.size()):
		var slot: Dictionary = farm_slots[index]
		if str(slot.get("status", FARM_STATUS_EMPTY)) != FARM_STATUS_GROWING:
			continue
		slot["elapsed_seconds"] = min(float(slot.get("growth_seconds", 0.0)), float(slot.get("elapsed_seconds", 0.0)) + delta * multiplier)
		if float(slot.get("elapsed_seconds", 0.0)) >= float(slot.get("growth_seconds", 0.0)):
			slot["status"] = FARM_STATUS_READY
			log_added.emit("%s成熟了" % DataTables.resource_name(str(slot.get("crop_id", ""))))
		farm_slots[index] = slot
		changed_farm = true
	changed_farm = _update_farm_speed_buffs(delta) or changed_farm
	if changed_farm:
		_refresh_farm_progress_state()
		changed.emit()


func claim_farm_slot(slot_index: int) -> bool:
	_ensure_farm_slots()
	if slot_index < 0 or slot_index >= farm_slots.size():
		return false
	var slot: Dictionary = farm_slots[slot_index]
	if str(slot.get("status", FARM_STATUS_EMPTY)) != FARM_STATUS_READY:
		return false
	var crop_id := str(slot.get("crop_id", ""))
	var amount := int(slot.get("harvest_amount", 0))
	if crop_id.is_empty() or amount <= 0:
		return false
	add_inventory_item(crop_id, amount, false)
	farm_slots[slot_index] = _empty_farm_slot()
	add_exp(2)
	add_task_experience(GameDefs.TaskType.FARM, 5)
	log_added.emit("收取%s x%d" % [DataTables.resource_name(crop_id), amount])
	_refresh_farm_progress_state()
	changed.emit()
	return true


func claim_all_farm_slots() -> int:
	var claimed := 0
	for index in range(FARM_SLOT_COUNT):
		if claim_farm_slot(index):
			claimed += 1
	return claimed


func use_farm_speed_item(item_id: String) -> bool:
	if not DataTables.is_farm_speed_item(item_id):
		return false
	if not spend_resource(item_id, 1):
		log_added.emit("农田加速道具不足")
		return false
	farm_speed_buffs.append({
		"item_id": item_id,
		"multiplier": DataTables.farm_speed_item_multiplier(item_id),
		"remaining_seconds": DataTables.farm_speed_item_duration(item_id),
	})
	log_added.emit("农田加速 x%.1f" % DataTables.farm_speed_item_multiplier(item_id))
	changed.emit()
	return true


func farm_speed_multiplier() -> float:
	var multiplier := 1.0
	for buff in farm_speed_buffs:
		if float(buff.get("remaining_seconds", 0.0)) > 0.0:
			multiplier = max(multiplier, float(buff.get("multiplier", 1.0)))
	return multiplier


func farm_speed_remaining_seconds() -> float:
	var remaining := 0.0
	for buff in farm_speed_buffs:
		remaining = max(remaining, float(buff.get("remaining_seconds", 0.0)))
	return remaining


func ready_farm_slot_count() -> int:
	var count := 0
	for slot in farm_slots:
		if str(slot.get("status", FARM_STATUS_EMPTY)) == FARM_STATUS_READY:
			count += 1
	return count


func active_farm_slot_count() -> int:
	var count := 0
	for slot in farm_slots:
		if str(slot.get("status", FARM_STATUS_EMPTY)) != FARM_STATUS_EMPTY:
			count += 1
	return count


func _ensure_farm_slots() -> void:
	while farm_slots.size() < FARM_SLOT_COUNT:
		farm_slots.append(_empty_farm_slot())
	while farm_slots.size() > FARM_SLOT_COUNT:
		farm_slots.remove_at(farm_slots.size() - 1)
	for index in range(farm_slots.size()):
		var slot: Dictionary = farm_slots[index] if farm_slots[index] is Dictionary else {}
		var status := str(slot.get("status", FARM_STATUS_EMPTY))
		if not [FARM_STATUS_EMPTY, FARM_STATUS_GROWING, FARM_STATUS_READY].has(status):
			status = FARM_STATUS_EMPTY
		if status == FARM_STATUS_EMPTY:
			farm_slots[index] = _empty_farm_slot()
		else:
			slot["status"] = status
			slot["crop_id"] = str(slot.get("crop_id", ""))
			slot["elapsed_seconds"] = float(slot.get("elapsed_seconds", 0.0))
			slot["growth_seconds"] = max(1.0, float(slot.get("growth_seconds", DataTables.crop_growth_seconds(str(slot.get("crop_id", ""))))))
			slot["harvest_amount"] = max(1, int(slot.get("harvest_amount", 1)))
			farm_slots[index] = slot


func _empty_farm_slot() -> Dictionary:
	return {"status": FARM_STATUS_EMPTY, "crop_id": "", "elapsed_seconds": 0.0, "growth_seconds": 0.0, "harvest_amount": 0}


func _update_farm_speed_buffs(delta: float) -> bool:
	var changed_buffs := false
	var index := 0
	while index < farm_speed_buffs.size():
		var buff: Dictionary = farm_speed_buffs[index]
		buff["remaining_seconds"] = float(buff.get("remaining_seconds", 0.0)) - delta
		if float(buff.get("remaining_seconds", 0.0)) <= 0.0:
			farm_speed_buffs.remove_at(index)
		else:
			farm_speed_buffs[index] = buff
			index += 1
		changed_buffs = true
	return changed_buffs


func _refresh_farm_progress_state() -> void:
	var ready_count := ready_farm_slot_count()
	if ready_count > 0:
		set_progress_state("farm", "claimable", "%d 块农田可收取" % ready_count)
	elif active_farm_slot_count() > 0:
		set_progress_state("farm", "growing", "%d 块农田生长中" % active_farm_slot_count())
	else:
		clear_progress_state("farm")


func random_known_alchemy_recipe() -> String:
	if known_alchemy_recipes.is_empty():
		return ""
	return known_alchemy_recipes[rng.randi_range(0, known_alchemy_recipes.size() - 1)]


func alchemy_max_craft_count(recipe_id: String) -> int:
	if recipe_id.is_empty():
		return 0

	var materials := DataTables.alchemy_recipe_materials(recipe_id)
	if materials.is_empty():
		return 0

	var max_count := 1 << 30
	for material in materials:
		var item_id: String = material.get("item_id", "")
		var amount := int(material.get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			return 0
		max_count = min(max_count, floori(float(inventory_item_count(item_id)) / float(amount)))
	return max_count


func craft_alchemy_recipe(recipe_id: String, amount: int) -> bool:
	if recipe_id.is_empty() or amount < 1:
		log_added.emit("炼丹数量无效")
		return false
	if not known_alchemy_recipes.has(recipe_id):
		log_added.emit("尚未学习丹方")
		return false

	var recipe := DataTables.alchemy_recipe_def(recipe_id)
	var result_item_id: String = recipe.get("result_item_id", "")
	var materials: Array = recipe.get("materials", [])
	if result_item_id.is_empty() or materials.is_empty():
		log_added.emit("丹方无效")
		return false
	if alchemy_max_craft_count(recipe_id) < amount:
		log_added.emit("炼丹材料不足")
		return false

	for material in materials:
		_remove_inventory_count(str(material.get("item_id", "")), int(material.get("amount", 0)) * amount)

	var result_count := amount
	for _index in range(amount):
		if rng.randf() < alchemy_extra_chance():
			result_count += 1
	add_inventory_item(result_item_id, result_count, false)
	log_added.emit("炼成%s x%d" % [DataTables.resource_name(result_item_id), result_count])
	changed.emit()
	return true


func enhance_equipment(instance_id: String) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var cost := int(item.get("enhance_count", 0)) + 1
	var stone := _find_enhance_stone(item, cost)
	if stone.is_empty():
		log_added.emit("缺少匹配的灵石")
		return false
	if not spend_resource(stone["item_id"], cost):
		log_added.emit("灵石不足")
		return false
	var enhanced_attributes: Array = item.get("enhanced_attributes", [])
	enhanced_attributes.append({
		"stat": stone["stat"],
		"amount": int(stone["amount"]),
		"quality": stone["quality"],
	})
	item["enhanced_attributes"] = enhanced_attributes
	item["enhance_count"] = int(item.get("enhance_count", 0)) + 1
	item["enhance_level"] = item["enhance_count"]
	_update_equipment_compat_bonuses(item)
	set_progress_state("forge", "completed", "已强化%s至 +%d" % [item["name"], item["enhance_count"]])
	log_added.emit("强化%s至 +%d" % [item["name"], item["enhance_count"]])
	return true


func add_equipment_affix(instance_id: String) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var cost := int(item.get("refine_count", 0)) + 1
	if not spend_resource("refine_talisman", cost):
		log_added.emit("洗练符不足")
		return false
	var attribute_def: Dictionary = DataTables.EQUIPMENT_ATTRIBUTE_DEFS[rng.randi_range(0, DataTables.EQUIPMENT_ATTRIBUTE_DEFS.size() - 1)]
	var refine_affixes: Array = item.get("refine_affixes", [])
	var percent := snappedf(rng.randf_range(0.05, 0.15), 0.01)
	refine_affixes.append({
		"stat": attribute_def["stat"],
		"percent": percent,
	})
	item["refine_affixes"] = refine_affixes
	item["refine_count"] = int(item.get("refine_count", 0)) + 1
	set_progress_state("forge", "completed", "已洗练%s" % item["name"])
	log_added.emit("洗练%s" % item["name"])
	return true


func _equipped_items() -> Array:
	var items: Array = []
	for slot in equipped.keys():
		var item: Dictionary = equipped_item(slot)
		if not item.is_empty():
			items.append(item)
	return items


func _stat_bonus(stat_id: String) -> int:
	var value := 0
	for buff in active_buffs:
		if buff.get("stat", "") == stat_id:
			value += int(buff.get("amount", 0))
	for item in _equipped_items():
		value += _item_affix_bonus(item, stat_id)
	return value


func _item_affix_bonus(item: Dictionary, stat_id: String) -> int:
	var value := 0
	for affix in item.get("affixes", []):
		if affix.get("stat", "") == stat_id:
			value += int(affix.get("amount", 0))
	return value


func _equipment_attribute_bonus(stat_id: String) -> int:
	var value := 0
	for item in _equipped_items():
		value += _item_equipment_attribute_value(item, stat_id)
	return value


func _total_requirement_stat_excluding_slot(stat_id: String, excluded_slot: String) -> int:
	if stat_id.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
		var element_id: String = DataTables.element_id_from_attribute(stat_id)
		return int(elements.get(element_id, 0)) + _equipment_attribute_bonus_excluding_slot(stat_id, excluded_slot)
	return int(stats.get(stat_id, 0)) + _stat_bonus(stat_id) + _equipment_attribute_bonus_excluding_slot(stat_id, excluded_slot)


func _equipment_attribute_bonus_excluding_slot(stat_id: String, excluded_slot: String) -> int:
	var value := 0
	for slot in equipped.keys():
		if slot == excluded_slot:
			continue
		var item: Dictionary = equipped_item(slot)
		if item.is_empty():
			continue
		value += _item_equipment_attribute_value(item, stat_id)
	return value


func _item_equipment_attribute_value(item: Dictionary, stat_id: String) -> int:
	var flat_value := 0
	for attribute in item.get("base_attributes", []):
		if attribute.get("stat", "") == stat_id:
			flat_value += int(attribute.get("amount", 0))
	for attribute in item.get("enhanced_attributes", []):
		if attribute.get("stat", "") == stat_id:
			flat_value += int(attribute.get("amount", 0))
	if flat_value == 0:
		return 0
	var percent_bonus := 0.0
	for affix in item.get("refine_affixes", []):
		if affix.get("stat", "") == stat_id:
			percent_bonus += float(affix.get("percent", 0.0))
	return int(floor(flat_value * (1.0 + percent_bonus)))


func _find_enhance_stone(item: Dictionary, cost: int) -> Dictionary:
	var base_stats: Array = []
	for attribute in item.get("base_attributes", []):
		var stat_id: String = attribute.get("stat", "")
		if not stat_id.is_empty() and not base_stats.has(stat_id):
			base_stats.append(stat_id)
	for quality in DataTables.SPIRIT_STONE_QUALITY_ORDER:
		for stat_id in base_stats:
			var item_id: String = DataTables.enhance_stone_item_id(stat_id, quality)
			if item_id.is_empty():
				continue
			if inventory_item_count(item_id) >= cost:
				return {
					"item_id": item_id,
					"stat": stat_id,
					"quality": quality,
					"amount": DataTables.spirit_stone_enhance_amount(quality),
				}
	return {}


func _update_equipment_compat_bonuses(item: Dictionary) -> void:
	item["attack_bonus"] = _item_equipment_attribute_value(item, "attack")
	item["defense_bonus"] = _item_equipment_attribute_value(item, "defense")
	item["enhance_attack_bonus"] = _sum_enhanced_attribute(item, "attack")
	item["enhance_defense_bonus"] = _sum_enhanced_attribute(item, "defense")


func _sum_enhanced_attribute(item: Dictionary, stat_id: String) -> int:
	var value := 0
	for attribute in item.get("enhanced_attributes", []):
		if attribute.get("stat", "") == stat_id:
			value += int(attribute.get("amount", 0))
	return value


func _update_farm_level() -> void:
	while task_exp.get("farm", 0) >= int(stats.get("farm_level", 1)) * 5:
		stats["farm_level"] += 1
		log_added.emit("农田等级提升至 %d" % stats["farm_level"])


func _grant_auto_level_points_for_member(member: Dictionary) -> void:
	party_service.grant_auto_level_points_for_member(member)


func try_breakthrough() -> bool:
	return _try_breakthrough_for_member(player_member())


func _ensure_level_cap_open() -> bool:
	return _ensure_level_cap_open_for_member(player_member())


func _unlock_next_stage() -> void:
	_unlock_next_stage_for_member(player_member())


func _level_up() -> void:
	_level_up_member(player_member())


func _level_up_member(member: Dictionary) -> void:
	party_service.level_up_member(member)


func _ensure_level_cap_open_for_member(member: Dictionary) -> bool:
	return party_service.ensure_level_cap_open_for_member(member)


func _try_breakthrough_for_member(member: Dictionary) -> bool:
	return party_service.try_breakthrough_for_member(member)


func _unlock_next_stage_for_member(member: Dictionary) -> void:
	party_service.unlock_next_stage_for_member(member)


func _attribute_log_name(stat_id: String) -> String:
	if stat_id.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
		return DataTables.element_name(DataTables.element_id_from_attribute(stat_id))
	return DataTables.attribute_display_name(stat_id)


func _attribute_gains_text(gains: Dictionary) -> String:
	if gains.is_empty():
		return "无"
	var parts: Array[String] = []
	for stat_id in RANDOM_POINT_TARGETS:
		if not gains.has(stat_id):
			continue
		parts.append("%s+%d" % [_attribute_log_name(str(stat_id)), int(gains.get(stat_id, 0))])
	return "、".join(parts)
