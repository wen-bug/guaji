class_name InventoryService
extends RefCounted

var game_state


func _init(owner) -> void:
	game_state = owner


func spend_resource(resource_id: String, amount: int) -> bool:
	if inventory_item_count(resource_id) < amount:
		return false
	remove_inventory_count(resource_id, amount)
	game_state.changed.emit()
	return true


func spend_inventory_type(type_id: String, amount: int) -> bool:
	if inventory_total_for_type(type_id) < amount:
		return false

	var remaining: int = amount
	var index: int = 0
	while index < game_state.inventory.size() and remaining > 0:
		var item: Dictionary = game_state.inventory[index]
		if item.get("type", "") != type_id or not bool(item.get("stackable", false)):
			index += 1
			continue

		var spent: int = mini(int(item["count"]), remaining)
		item["count"] = int(item["count"]) - spent
		remaining -= spent
		if int(item["count"]) <= 0:
			game_state.inventory.remove_at(index)
		else:
			index += 1

	game_state.changed.emit()
	return true


func add_inventory_item(item_id: String, amount: int, should_emit_signal: bool = true) -> bool:
	if amount <= 0:
		return false

	var definition: Dictionary = DataTables.item_definition(item_id)
	if definition.is_empty():
		return false

	var item: Dictionary = find_stack_item(item_id)
	if item.is_empty():
		item = DataTables.create_stack_item(item_id, amount)
		game_state.inventory.append(item)
	else:
		item["count"] += amount

	if should_emit_signal:
		game_state.changed.emit()
	return true


func add_inventory_instance(item: Dictionary) -> void:
	if item.is_empty():
		return
	game_state.inventory.append(item)
	game_state.changed.emit()


func inventory_items_for_type(type_id: String) -> Array:
	var result: Array = []
	for item in game_state.inventory:
		if item.get("type", "") == type_id and int(item.get("count", 0)) > 0:
			result.append(item)
	return result


func inventory_item_count(item_id: String) -> int:
	var item: Dictionary = find_stack_item(item_id)
	if item.is_empty():
		return 0
	return int(item.get("count", 0))


func inventory_total_for_type(type_id: String) -> int:
	var total: int = 0
	for item in game_state.inventory:
		if item.get("type", "") == type_id:
			total += int(item.get("count", 0))
	return total


func inventory_item_by_instance(instance_id: String) -> Dictionary:
	for item in game_state.inventory:
		if item.get("instance_id", "") == instance_id:
			return item
	return {}


func is_inventory_item_usable(instance_id: String) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty():
		return false
	return DataTables.item_use_scope(str(item.get("item_id", ""))) == DataTables.ITEM_USE_SCOPE_HOME


func is_inventory_item_direct_usable(instance_id: String) -> bool:
	return is_inventory_item_usable(instance_id)


func use_inventory_item(instance_id: String) -> bool:
	return use_inventory_item_for_member(instance_id, game_state.default_party_member_id())


func use_inventory_item_for_member(instance_id: String, member_id: String) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty():
		return false

	if item.get("payload", {}).has("permanent_building_quality") or DataTables.is_farm_speed_item(str(item.get("item_id", ""))):
		return game_state._use_home_item(item)

	match item.get("type", ""):
		DataTables.ITEM_TYPE_EQUIPMENT:
			return game_state.equip_item_for_member(instance_id, member_id)
		DataTables.ITEM_TYPE_SKILL_BOOK:
			return game_state._use_skill_book(item, member_id)
		DataTables.ITEM_TYPE_ALCHEMY_RECIPE:
			return game_state._use_alchemy_recipe(item)
		DataTables.ITEM_TYPE_BLUEPRINT:
			return game_state.use_equipment_blueprint(item)
		DataTables.ITEM_TYPE_PILL:
			return game_state._use_pill_for_member(item, member_id)
		_:
			game_state.log_added.emit("%s不能使用" % item.get("name", "物品"))
			return false


func drop_inventory_item(instance_id: String) -> bool:
	for index in range(game_state.inventory.size()):
		var item: Dictionary = game_state.inventory[index]
		if item.get("instance_id", "") != instance_id:
			continue

		if item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
			game_state._unequip_if_needed(instance_id)
			game_state.log_added.emit("丢弃%s" % item["name"])
			game_state.inventory.remove_at(index)
		else:
			item["count"] = int(item["count"]) - 1
			game_state.log_added.emit("丢弃%s x1" % item["name"])
			if int(item["count"]) <= 0:
				game_state.inventory.remove_at(index)

		game_state.changed.emit()
		return true
	return false


func resource_summary() -> String:
	return "作物:%d 材料:%d 丹药:%d" % [
		inventory_total_for_type(DataTables.ITEM_TYPE_CROP),
		inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL),
		inventory_total_for_type(DataTables.ITEM_TYPE_PILL),
	]


func find_stack_item(item_id: String) -> Dictionary:
	for item in game_state.inventory:
		if item.get("item_id", "") == item_id and bool(item.get("stackable", false)):
			return item
	return {}


func remove_inventory_count(item_id: String, amount: int) -> void:
	for index in range(game_state.inventory.size()):
		var item: Dictionary = game_state.inventory[index]
		if item.get("item_id", "") != item_id:
			continue
		item["count"] = int(item["count"]) - amount
		if int(item["count"]) <= 0:
			game_state.inventory.remove_at(index)
		return
