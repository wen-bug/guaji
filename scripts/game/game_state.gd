class_name GameState
extends RefCounted

signal changed
signal log_added(message: String)

var rng := RandomNumberGenerator.new()
var stats := {
	"level": 1,
	"level_cap": 10,
	"stage": 1,
	"root_bone": 5,
	"farm_level": 1,
	"exp": 0,
	"next_exp": 40,
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
	"meditate": 0,
	"farm": 0,
	"forge": 0,
	"alchemy": 0,
	"fight": 0,
}
var inventory: Array = []
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
var active_buffs: Array = []


func _init() -> void:
	rng.randomize()
	add_inventory_item("herb", 4, false)
	add_inventory_item("ore", 4, false)
	add_inventory_item("stat_stone_attack_t1", 2, false)
	add_inventory_item("stat_stone_defense_t1", 2, false)
	add_inventory_item("spirit_stone_fire_t1", 2, false)
	add_inventory_item("spirit_stone_earth_t1", 2, false)
	add_inventory_item("recipe_pill", 1, false)


func to_save_data() -> Dictionary:
	return {
		"stats": stats.duplicate(true),
		"elements": elements.duplicate(true),
		"task_exp": task_exp.duplicate(true),
		"inventory": inventory.duplicate(true),
		"equipped": equipped.duplicate(true),
		"skills": skills.duplicate(true),
		"known_alchemy_recipes": known_alchemy_recipes.duplicate(),
		"active_buffs": active_buffs.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	_load_dictionary_values(stats, data.get("stats", {}))
	_load_dictionary_values(elements, data.get("elements", {}))
	_load_dictionary_values(task_exp, data.get("task_exp", {}))
	inventory = _duplicate_array(data.get("inventory", []))
	_load_dictionary_values(equipped, data.get("equipped", {}))
	skills = _duplicate_array(data.get("skills", skills))
	known_alchemy_recipes.clear()
	for recipe_id in data.get("known_alchemy_recipes", []):
		known_alchemy_recipes.append(str(recipe_id))
	active_buffs = _duplicate_array(data.get("active_buffs", []))
	changed.emit()


func _load_dictionary_values(target: Dictionary, source) -> void:
	if not source is Dictionary:
		return
	for key in source.keys():
		target[key] = source[key]


func _duplicate_array(value) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


func total_attack() -> int:
	return int(stats["attack"] + int(element_power() * 0.15) + _stat_bonus("attack") + _equipment_attribute_bonus("attack"))


func total_defense() -> int:
	return int(stats["defense"] + _stat_bonus("defense") + _equipment_attribute_bonus("defense"))


func total_stat(stat_id: String) -> int:
	var value := int(stats.get(stat_id, 0)) + _stat_bonus(stat_id) + _equipment_attribute_bonus(stat_id)
	return value


func total_element(element_id: String) -> int:
	return int(elements.get(element_id, 0)) + _equipment_attribute_bonus("element_%s" % element_id)


func element_power() -> int:
	var value := 0
	for element_id in elements.keys():
		value += total_element(element_id)
	return value


func dominant_element() -> String:
	var best_id := "wood"
	var best_value := -1
	for element_id in elements.keys():
		var element_value := total_element(element_id)
		if element_value > best_value:
			best_id = element_id
			best_value = element_value
	return best_id


func cultivation_gain(base_amount: int) -> int:
	return base_amount + int(total_stat("root_bone") * 0.4)


func craft_bonus() -> int:
	return int(total_stat("root_bone") * 0.2)


func alchemy_extra_chance() -> float:
	return min(0.35, float(total_stat("root_bone")) * 0.015)


func element_damage_bonus(element_id: String) -> int:
	return int(total_element(element_id) * 0.5)


func reduce_element_damage(element_id: String, amount: int) -> int:
	return max(0, amount - int(total_element(element_id) * 0.35))


func reduce_physical_damage(amount: int) -> int:
	return max(1, amount - total_defense())


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
	var final_amount := reduce_physical_damage(amount)
	if not element_id.is_empty():
		final_amount = reduce_element_damage(element_id, final_amount)
	stats["hp"] = max(0, stats["hp"] - final_amount)
	changed.emit()


func add_exp(amount: int) -> void:
	stats["exp"] += amount
	while stats["exp"] >= stats["next_exp"]:
		if not _ensure_level_cap_open():
			break
		stats["exp"] -= stats["next_exp"]
		stats["next_exp"] = int(stats["next_exp"] * 1.35) + 20
		_level_up()
	changed.emit()


func add_cultivation(amount: int) -> void:
	var final_amount := cultivation_gain(amount)
	stats["cultivation"] += final_amount
	log_added.emit("Meditation cultivation +%d" % final_amount)
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
		log_added.emit("%s proficiency reached %d" % [DataTables.task_name(task_type), task_exp[key]])
	changed.emit()


func gain_resource(resource_id: String, amount: int) -> void:
	if add_inventory_item(resource_id, amount, false):
		log_added.emit("获得%s x%d" % [DataTables.resource_name(resource_id), amount])
		changed.emit()


func spend_resource(resource_id: String, amount: int) -> bool:
	if inventory_item_count(resource_id) < amount:
		return false
	_remove_inventory_count(resource_id, amount)
	changed.emit()
	return true


func spend_inventory_type(type_id: String, amount: int) -> bool:
	if inventory_total_for_type(type_id) < amount:
		return false

	var remaining := amount
	var index := 0
	while index < inventory.size() and remaining > 0:
		var item: Dictionary = inventory[index]
		if item.get("type", "") != type_id or not bool(item.get("stackable", false)):
			index += 1
			continue

		var spent: int = mini(int(item["count"]), remaining)
		item["count"] = int(item["count"]) - spent
		remaining -= spent
		if int(item["count"]) <= 0:
			inventory.remove_at(index)
		else:
			index += 1

	changed.emit()
	return true


func add_inventory_item(item_id: String, amount: int, should_emit_signal := true) -> bool:
	if amount <= 0:
		return false

	var definition := DataTables.item_definition(item_id)
	if definition.is_empty():
		return false

	var item: Dictionary = _find_stack_item(item_id)
	if item.is_empty():
		item = DataTables.create_stack_item(item_id, amount)
		inventory.append(item)
	else:
		item["count"] += amount

	if should_emit_signal:
		changed.emit()
	return true


func add_inventory_instance(item: Dictionary) -> void:
	if item.is_empty():
		return
	inventory.append(item)
	changed.emit()


func inventory_items_for_type(type_id: String) -> Array:
	var result := []
	for item in inventory:
		if item.get("type", "") == type_id and int(item.get("count", 0)) > 0:
			result.append(item)
	return result


func inventory_item_count(item_id: String) -> int:
	var item: Dictionary = _find_stack_item(item_id)
	if item.is_empty():
		return 0
	return int(item.get("count", 0))


func inventory_total_for_type(type_id: String) -> int:
	var total := 0
	for item in inventory:
		if item.get("type", "") == type_id:
			total += int(item.get("count", 0))
	return total


func inventory_item_by_instance(instance_id: String) -> Dictionary:
	for item in inventory:
		if item.get("instance_id", "") == instance_id:
			return item
	return {}


func equipped_item(slot: String):
	var instance_id: String = equipped.get(slot, "")
	if instance_id.is_empty():
		return {}
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty():
		return {}
	return item


func is_inventory_item_usable(instance_id: String) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty():
		return false
	return bool(item.get("usable", false))


func is_inventory_item_direct_usable(instance_id: String) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty():
		return false
	return item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT or item.get("type", "") == DataTables.ITEM_TYPE_PILL


func use_inventory_item(instance_id: String) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty():
		return false

	match item.get("type", ""):
		DataTables.ITEM_TYPE_EQUIPMENT:
			return _equip_item(item)
		DataTables.ITEM_TYPE_SKILL_BOOK:
			return _use_skill_book(item)
		DataTables.ITEM_TYPE_ALCHEMY_RECIPE:
			return _use_alchemy_recipe(item)
		DataTables.ITEM_TYPE_PILL:
			return _use_pill(item)
		_:
			log_added.emit("%s不能使用" % item.get("name", "物品"))
			return false


func drop_inventory_item(instance_id: String) -> bool:
	for index in range(inventory.size()):
		var item: Dictionary = inventory[index]
		if item.get("instance_id", "") != instance_id:
			continue

		if item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
			_unequip_if_needed(instance_id)
			log_added.emit("丢弃%s" % item["name"])
			inventory.remove_at(index)
		else:
			item["count"] = int(item["count"]) - 1
			log_added.emit("丢弃%s x1" % item["name"])
			if int(item["count"]) <= 0:
				inventory.remove_at(index)

		changed.emit()
		return true
	return false


func add_equipment(item: Dictionary) -> void:
	add_inventory_instance(item)
	log_added.emit("获得装备：%s" % item["name"])


func resource_summary() -> String:
	return "作物:%d 材料:%d 丹药:%d" % [
		inventory_total_for_type(DataTables.ITEM_TYPE_CROP),
		inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL),
		inventory_total_for_type(DataTables.ITEM_TYPE_PILL),
	]


func element_summary() -> String:
	return "木%d 火%d 土%d 金%d 水%d" % [
		elements["wood"],
		elements["fire"],
		elements["earth"],
		elements["metal"],
		elements["water"],
	]


func task_exp_for(task_type: int) -> int:
	return task_exp.get(DataTables.task_zone_id(task_type), 0)


func _find_stack_item(item_id: String):
	for item in inventory:
		if item.get("item_id", "") == item_id and bool(item.get("stackable", false)):
			return item
	return {}


func _remove_inventory_count(item_id: String, amount: int) -> void:
	for index in range(inventory.size()):
		var item: Dictionary = inventory[index]
		if item.get("item_id", "") != item_id:
			continue
		item["count"] = int(item["count"]) - amount
		if int(item["count"]) <= 0:
			inventory.remove_at(index)
		return


func can_equip_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var slot: String = _equipment_slot_for_item(item)
	return equipment_requirement_met(item, slot)


func equipment_requirement_met(item: Dictionary, target_slot := "") -> bool:
	var requirement: Dictionary = item.get("equip_requirement", {})
	if requirement.is_empty():
		return true
	return equipment_requirement_current_value(item, target_slot) >= int(requirement.get("min", 0))


func equipment_requirement_current_value(item: Dictionary, target_slot := "") -> int:
	var requirement: Dictionary = item.get("equip_requirement", {})
	var stat_id: String = requirement.get("stat", "")
	if stat_id.is_empty():
		return 0
	var excluded_slot := str(target_slot)
	if excluded_slot.is_empty():
		excluded_slot = _equipment_slot_for_item(item)
	return _total_requirement_stat_excluding_slot(stat_id, excluded_slot)


func equipment_requirement_text(item: Dictionary) -> String:
	var requirement: Dictionary = item.get("equip_requirement", {})
	if requirement.is_empty():
		return ""
	var stat_id: String = requirement.get("stat", "")
	var current := equipment_requirement_current_value(item)
	var needed := int(requirement.get("min", 0))
	var status := "已达标" if current >= needed else "未达标"
	return "%s %d / 当前 %d（%s）" % [DataTables.attribute_display_name(stat_id), needed, current, status]


func _equip_item(item: Dictionary) -> bool:
	var slot: String = _equipment_slot_for_item(item)
	var previous_id: String = equipped.get(slot, "")
	if previous_id == item["instance_id"]:
		log_added.emit("%s already equipped" % item["name"])
		return true
	if not equipment_requirement_met(item, slot):
		var requirement_text := equipment_requirement_text(item)
		if requirement_text.is_empty():
			log_added.emit("%s cannot be equipped" % item["name"])
		else:
			log_added.emit("%s requirement not met: %s" % [item["name"], requirement_text])
		return false

	_unequip_if_needed(item["instance_id"])
	if not previous_id.is_empty():
		var previous := inventory_item_by_instance(previous_id)
		if not previous.is_empty():
			previous["equipped"] = false
			previous.erase("equipped_slot")

	item["equipped"] = true
	item["equipped_slot"] = slot
	equipped[slot] = item["instance_id"]
	log_added.emit("equipped %s" % item["name"])
	changed.emit()
	return true


func _equipment_slot_for_item(item: Dictionary) -> String:
	var slot: String = item.get("slot", "")
	if slot != "accessory":
		return slot
	if equipped.get("accessory_1", "").is_empty():
		return "accessory_1"
	if equipped.get("accessory_2", "").is_empty():
		return "accessory_2"
	return "accessory_1"


func _unequip_if_needed(instance_id: String) -> void:
	for slot in equipped.keys():
		if equipped[slot] == instance_id:
			equipped[slot] = ""
	var item := inventory_item_by_instance(instance_id)
	if not item.is_empty():
		item["equipped"] = false
		item.erase("equipped_slot")


func _use_skill_book(item: Dictionary) -> bool:
	var skill_id: String = item.get("payload", {}).get("skill_id", "")
	if skill_id.is_empty():
		return false

	if _knows_skill(skill_id):
		log_added.emit("已经学会%s" % DataTables.create_skill(skill_id)["name"])
		return false

	var skill := DataTables.create_skill(skill_id)
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
		log_added.emit("recipe already learned")
		return false
	known_alchemy_recipes.append(recipe_id)
	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("learned recipe: %s" % DataTables.resource_name(recipe_id))
	changed.emit()
	return true


func _use_pill(item: Dictionary) -> bool:
	var payload: Dictionary = item.get("payload", {})
	if bool(payload.get("breakthrough", false)):
		return _use_breakthrough_item(item)
	if payload.get("effect_mode", "instant") == "duration":
		active_buffs.append({
			"item_id": item["item_id"],
			"name": item["name"],
			"stat": payload.get("stat", ""),
			"amount": int(payload.get("amount", 0)),
			"remaining": float(payload.get("duration", 0.0)),
		})
		_remove_inventory_count(item["item_id"], 1)
		log_added.emit("used %s, buff active" % item["name"])
		changed.emit()
		return true

	var hp_amount: int = int(payload.get("hp", 0))
	var mp_amount: int = int(payload.get("mp", 0))
	var old_hp: int = stats["hp"]
	var old_mp: int = stats["mp"]

	stats["hp"] = min(total_stat("max_hp"), stats["hp"] + hp_amount)
	stats["mp"] = min(total_stat("max_mp"), stats["mp"] + mp_amount)
	if stats["hp"] == old_hp and stats["mp"] == old_mp:
		log_added.emit("hp and mp are full")
		return false

	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("used %s" % item["name"])
	changed.emit()
	return true


func _use_breakthrough_item(item: Dictionary) -> bool:
	if stats["level"] < stats["level_cap"]:
		log_added.emit("Current stage cap not reached")
		return false

	_unlock_next_stage()
	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("Used %s, reached stage %d" % [item["name"], stats["stage"]])
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
	for item in inventory:
		if item.get("type", "") != DataTables.ITEM_TYPE_CROP:
			continue
		var seed_yield := int(item.get("payload", {}).get("seed_yield", 0))
		if seed_yield <= 0:
			continue
		var item_id: String = item["item_id"]
		_remove_inventory_count(item_id, 1)
		changed.emit()
		return {"item_id": item_id, "amount": seed_yield + int(stats.get("farm_level", 1)) - 1}
	return {}


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
		log_added.emit("missing matching spirit stone")
		return false
	if not spend_resource(stone["item_id"], cost):
		log_added.emit("not enough spirit stones")
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
	log_added.emit("enhanced %s to +%d" % [item["name"], item["enhance_count"]])
	changed.emit()
	return true


func add_equipment_affix(instance_id: String) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var cost := int(item.get("refine_count", 0)) + 1
	if not spend_resource("refine_talisman", cost):
		log_added.emit("not enough refine talisman")
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
	log_added.emit("refined %s" % item["name"])
	changed.emit()
	return true


func _equipped_items() -> Array:
	var items := []
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
		var element_id := DataTables.element_id_from_attribute(stat_id)
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
	var base_stats := []
	for attribute in item.get("base_attributes", []):
		var stat_id: String = attribute.get("stat", "")
		if not stat_id.is_empty() and not base_stats.has(stat_id):
			base_stats.append(stat_id)
	for quality in DataTables.SPIRIT_STONE_QUALITY_ORDER:
		for stat_id in base_stats:
			var item_id := DataTables.enhance_stone_item_id(stat_id, quality)
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
		log_added.emit("farm level %d" % stats["farm_level"])


func _apply_random_level_gain() -> void:
	var hp_gain := rng.randi_range(8, 20)
	var mp_gain := rng.randi_range(4, 12)
	var attack_gain := rng.randi_range(1, 3)
	var defense_gain := rng.randi_range(0, 2)
	var root_bone_gain := rng.randi_range(0, 1)

	stats["max_hp"] += hp_gain
	stats["max_mp"] += mp_gain
	stats["attack"] += attack_gain
	stats["defense"] += defense_gain
	stats["root_bone"] += root_bone_gain

	var element_id: String = DataTables.ELEMENT_IDS[rng.randi_range(0, DataTables.ELEMENT_IDS.size() - 1)]
	var element_gain := rng.randi_range(1, 3)
	elements[element_id] += element_gain

	log_added.emit("Level %d: HP+%d MP+%d ATK+%d DEF+%d Root+%d %s+%d" % [
		stats["level"],
		hp_gain,
		mp_gain,
		attack_gain,
		defense_gain,
		root_bone_gain,
		DataTables.element_name(element_id),
		element_gain,
	])


func try_breakthrough() -> bool:
	if stats["level"] < stats["level_cap"]:
		return false
	if stats["root_bone"] <= stats["level"]:
		return false
	_unlock_next_stage()
	log_added.emit("Root bone breakthrough to stage %d" % stats["stage"])
	changed.emit()
	return true


func _ensure_level_cap_open() -> bool:
	if stats["level"] < stats["level_cap"]:
		return true
	if try_breakthrough():
		return true
	log_added.emit("Reached level cap %d; use breakthrough pill or raise root bone" % stats["level_cap"])
	return false


func _unlock_next_stage() -> void:
	stats["stage"] += 1
	stats["level_cap"] += 10


func _level_up() -> void:
	stats["level"] += 1
	_apply_random_level_gain()
	stats["hp"] = stats["max_hp"]
	stats["mp"] = stats["max_mp"]
