class_name GameState
extends RefCounted

signal changed
signal log_added(message: String)

const FARM_SLOT_COUNT = 5
const FARM_STATUS_EMPTY = "empty"
const FARM_STATUS_GROWING = "growing"
const FARM_STATUS_READY = "ready"
const PARTY_MAX_SIZE = 4
const ROSTER_MAX_SIZE = 8
const RECRUIT_RESOURCE_ID = "spirit_stone"
const RECRUIT_COST_SPIRIT_STONE = 1
const TEST_INVENTORY_ITEM_MIN_COUNT = 1
const TEST_INVENTORY_SETTING := "game/development/seed_test_inventory"
const LEVEL_ATTRIBUTE_POINTS = 5
const SAVE_SCHEMA_VERSION = 13
const BUILDING_RECRUIT = "recruit"
const BUILDING_FORGE = "forge"
const BUILDING_ALCHEMY = "alchemy"
const BUILDING_FARM = "farm"
const PRODUCTION_BUILDING_IDS = [BUILDING_FARM, BUILDING_FORGE, BUILDING_ALCHEMY]
const REMOVED_PRODUCTION_TRAIT_IDS = ["craft_hand", "craft_touch", "pill_heart", "pill_sense", "field_sense"]
const RECRUIT_NAME_PARTS = ["青岚", "赤霄", "玄石", "白羽", "沧流", "云舟", "明河", "素问", "照夜", "归尘"]
const RANDOM_POINT_TARGETS = ["attack", "defense", "root_bone", "max_hp", "max_mp", "element_wood", "element_fire", "element_earth", "element_metal", "element_water"]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var account_progression: Dictionary = {
	"expedition_level": 1,
	"expedition_exp": 0,
	"next_expedition_exp": 40,
}
var selected_expedition_map_id := "verdant_forest"
var task_exp: Dictionary = {
	"recruit": 0,
	"farm": 0,
	"forge": 0,
	"alchemy": 0,
	"fight": 0,
}
var inventory: Array = []
var inventory_service: InventoryService
var known_alchemy_recipes: Array = []
var companions: Array = []
var party_order: Array = []
var reserve_order: Array = []
var recruit_candidates: Array = []
var party_service: PartyService
var active_buffs: Array = []
var farm_slots: Array = []
var farm_speed_buffs: Array = []
var progress_states: Dictionary = {
	"alchemy": {"status": "not_started", "title": "Alchemy", "detail": "未开始", "completed": false, "claimable": false},
	"forge": {"status": "not_started", "title": "Forge", "detail": "未开始", "completed": false, "claimable": false},
	"farm": {"status": "not_started", "title": "Farm", "detail": "未开始", "completed": false, "claimable": false},
}
var building_levels: Dictionary = {
	"recruit": 1,
	"forge": 1,
	"alchemy": 1,
	"farm": 1,
}
var permanent_building_bonuses: Dictionary = {
	"farm": {"output_quality": 0},
	"forge": {"output_quality": 0},
	"alchemy": {"output_quality": 0},
}
var orphaned_mod_data: Dictionary = {
	"inventory": [],
	"recipes": [],
	"skills": [],
	"traits": [],
	"production_jobs": [],
}


func _init() -> void:
	inventory_service = InventoryService.new(self)
	party_service = PartyService.new(self)
	rng.randomize()
	_ensure_building_state()
	_ensure_account_progression()
	_ensure_permanent_building_bonuses()
	_ensure_farm_slots()
	_ensure_party_state()
	add_inventory_item(RECRUIT_RESOURCE_ID, 1, false)
	add_inventory_item("herb", 1, false)
	add_inventory_item("recipe_pill", 1, false)
	_grant_missing_starter_skill_books()
	_seed_test_inventory_if_enabled()
	generate_recruit_candidates(false)


func _seed_test_inventory_if_enabled() -> void:
	if not bool(ProjectSettings.get_setting(TEST_INVENTORY_SETTING, false)):
		return
	_add_test_inventory_items()


func _add_test_inventory_items() -> void:
	var item_ids: Array = DataTables.content_ids("item", DataTables.ITEM_DEFS)
	item_ids.sort()
	for item_id in item_ids:
		var current_count: int = inventory_item_count(str(item_id))
		if current_count < TEST_INVENTORY_ITEM_MIN_COUNT:
			add_inventory_item(str(item_id), TEST_INVENTORY_ITEM_MIN_COUNT - current_count, false)
	var template_ids: Array = DataTables.content_ids("equipment", DataTables.EQUIPMENT_DEFS)
	template_ids.sort()
	for template_id in template_ids:
		if _has_inventory_equipment_template(str(template_id)):
			continue
		var equipment: Dictionary = DataTables.create_equipment_from_template(str(template_id), 1, rng, 0, "", "t1", "debug")
		if not equipment.is_empty():
			inventory.append(equipment)


func _has_inventory_equipment_template(template_id: String) -> bool:
	for item in inventory:
		if not (item is Dictionary):
			continue
		if str(item.get("type", "")) == DataTables.ITEM_TYPE_EQUIPMENT and str(item.get("item_id", "")) == template_id:
			return true
	return false


func to_save_data() -> Dictionary:
	var result := {
		"schema_version": SAVE_SCHEMA_VERSION,
		"rng": _rng_save_data(),
		"account_progression": account_progression.duplicate(true),
		"selected_expedition_map_id": selected_expedition_map_id,
		"task_exp": task_exp.duplicate(true),
		"inventory": inventory.duplicate(true),
		"known_alchemy_recipes": known_alchemy_recipes.duplicate(),
		"companions": _companions_save_data(),
		"party_order": party_order.duplicate(),
		"reserve_order": reserve_order.duplicate(),
		"recruit_candidates": recruit_candidates.duplicate(true),
		"active_buffs": active_buffs.duplicate(true),
		"farm_slots": farm_slots.duplicate(true),
		"farm_speed_buffs": farm_speed_buffs.duplicate(true),
		"progress_states": progress_states.duplicate(true),
		"building_levels": building_levels.duplicate(true),
		"permanent_building_bonuses": permanent_building_bonuses.duplicate(true),
		"orphaned_mod_data": orphaned_mod_data.duplicate(true),
	}
	var api = _mod_api()
	if api != null:
		api.emit_event(&"before_save", {
			"schema_version": SAVE_SCHEMA_VERSION,
			"party_member_ids": party_order.duplicate(),
		})
		result.merge(api.export_save_data(), true)
	return result


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	var loaded_schema_version: int = int(data.get("schema_version", 1))
	var legacy_production_jobs: Dictionary = data.get("production_jobs", {}).duplicate(true) if data.get("production_jobs", {}) is Dictionary else {}
	orphaned_mod_data = data.get("orphaned_mod_data", orphaned_mod_data).duplicate(true)
	_ensure_orphan_shape()
	var api = _mod_api()
	if api != null:
		api.import_save_data(data)
	_load_rng_state(data.get("rng", {}))
	if data.has("account_progression"):
		_load_dictionary_values(account_progression, data.get("account_progression", {}))
	selected_expedition_map_id = str(data.get("selected_expedition_map_id", selected_expedition_map_id))
	if selected_expedition_map_id.is_empty():
		selected_expedition_map_id = "verdant_forest"
	_load_dictionary_values(task_exp, data.get("task_exp", {}))
	if data.has("inventory"):
		inventory = _duplicate_array(data.get("inventory", []))
	if data.has("known_alchemy_recipes"):
		known_alchemy_recipes.clear()
		for recipe_id in data.get("known_alchemy_recipes", []):
			known_alchemy_recipes.append(str(recipe_id))
	if data.has("companions"):
		companions.assign(_duplicate_array(data.get("companions", [])))
	_resolve_member_skill_references()
	if data.has("party_order"):
		party_order.clear()
		for member_id in data.get("party_order", []):
			party_order.append(str(member_id))
	reserve_order.clear()
	if data.has("reserve_order"):
		for member_id in data.get("reserve_order", []):
			reserve_order.append(str(member_id))
	if data.has("recruit_candidates"):
		recruit_candidates.assign(_duplicate_array(data.get("recruit_candidates", [])))
	if data.has("active_buffs"):
		active_buffs = _duplicate_array(data.get("active_buffs", []))
	if data.has("farm_slots"):
		farm_slots.assign(_duplicate_array(data.get("farm_slots", [])))
	if data.has("farm_speed_buffs"):
		farm_speed_buffs.assign(_duplicate_array(data.get("farm_speed_buffs", [])))
	if data.has("building_levels"):
		_load_dictionary_values(building_levels, data.get("building_levels", {}))
	if data.has("permanent_building_bonuses"):
		_load_dictionary_values(permanent_building_bonuses, data.get("permanent_building_bonuses", {}))
	_ensure_building_state()
	if loaded_schema_version < 5:
		account_progression = {
			"expedition_level": 1,
			"expedition_exp": maxi(0, int(task_exp.get("fight", 0))),
			"next_expedition_exp": 40,
		}
	_ensure_account_progression()
	_ensure_permanent_building_bonuses()
	_ensure_farm_slots()
	_restore_available_mod_content()
	_resolve_member_skill_references()
	_quarantine_unknown_mod_content()
	_sanitize_loaded_inventory()
	if loaded_schema_version < 12:
		_migrate_removed_production_traits()
		_settle_legacy_production_jobs(legacy_production_jobs)
	if loaded_schema_version < 6:
		_migrate_equipment_attribute_model()
	if loaded_schema_version < 7:
		_migrate_equipment_refine_model()
	if loaded_schema_version < 9:
		_grant_missing_starter_skill_books()
	_seed_test_inventory_if_enabled()
	_sanitize_active_buffs()
	_sanitize_farm_speed_buffs()
	_ensure_party_state()
	if loaded_schema_version < 3 and party_member_count() <= 0 and recruit_stone_count() <= 0:
		add_inventory_item(RECRUIT_RESOURCE_ID, 1, false)
	_ensure_recruit_candidate_growth()
	_migrate_free_points_to_auto_growth()
	if recruit_candidates.is_empty():
		generate_recruit_candidates(false)
	_load_progress_states(data.get("progress_states", {}))
	clear_progress_state(BUILDING_FORGE)
	clear_progress_state(BUILDING_ALCHEMY)
	_clamp_runtime_stats()
	_refresh_farm_progress_state()
	changed.emit()


func _mod_api():
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("ModAPI") if tree != null else null


func _ensure_orphan_shape() -> void:
	for key in ["inventory", "recipes", "skills", "traits", "production_jobs"]:
		if not (orphaned_mod_data.get(key, null) is Array):
			orphaned_mod_data[key] = []


func _inventory_content_available(item: Dictionary) -> bool:
	var item_id := str(item.get("item_id", ""))
	if str(item.get("type", "")) == DataTables.ITEM_TYPE_EQUIPMENT:
		return DataTables.content_has("equipment", item_id, DataTables.EQUIPMENT_DEFS)
	return DataTables.content_has("item", item_id, DataTables.ITEM_DEFS)


func _restore_available_mod_content() -> void:
	_ensure_orphan_shape()
	var remaining_inventory: Array = []
	for item in orphaned_mod_data["inventory"]:
		if not (item is Dictionary) or not _inventory_content_available(item):
			remaining_inventory.append(item)
			continue
		var instance_id := str(item.get("instance_id", ""))
		if inventory_item_by_instance(instance_id).is_empty():
			inventory.append(item.duplicate(true))
			var owner_id := str(item.get("equipped_by", ""))
			var slot := str(item.get("equipped_slot", ""))
			var owner := member_by_id(owner_id)
			if not owner.is_empty() and not slot.is_empty():
				owner.get("equipped", {})[slot] = instance_id
	orphaned_mod_data["inventory"] = remaining_inventory
	var remaining_recipes: Array = []
	for recipe_id in orphaned_mod_data["recipes"]:
		if DataTables.content_has("recipe", str(recipe_id), DataTables.ALCHEMY_RECIPE_DEFS):
			if not known_alchemy_recipes.has(str(recipe_id)):
				known_alchemy_recipes.append(str(recipe_id))
		else:
			remaining_recipes.append(recipe_id)
	orphaned_mod_data["recipes"] = remaining_recipes
	for category in ["skills", "traits"]:
		var remaining: Array = []
		var kind := "skill" if category == "skills" else "trait"
		for record in orphaned_mod_data[category]:
			if not (record is Dictionary) or not DataTables.content_has(kind, str(record.get("content_id", ""))):
				remaining.append(record)
				continue
			var member := member_by_id(str(record.get("member_id", "")))
			if member.is_empty():
				remaining.append(record)
				continue
			var field := "skills" if category == "skills" else "innate_traits"
			var values: Array = member.get(field, [])
			values.append(record.get("value", {}).duplicate(true))
			member[field] = values
		orphaned_mod_data[category] = remaining
	var pending_jobs: Dictionary = {}
	var remaining_jobs: Array = []
	for job in orphaned_mod_data["production_jobs"]:
		if not (job is Dictionary):
			continue
		var building_id := str(job.get("building_id", ""))
		if building_id == BUILDING_ALCHEMY and DataTables.item_definition(str(job.get("result_item_id", ""))).is_empty():
			remaining_jobs.append(job)
			continue
		pending_jobs[building_id] = job.duplicate(true)
	orphaned_mod_data["production_jobs"] = remaining_jobs
	_settle_legacy_production_jobs(pending_jobs)


func _migrate_removed_production_traits() -> void:
	for collection in [companions, recruit_candidates]:
		for member in collection:
			if not (member is Dictionary):
				continue
			var kept_traits: Array = []
			for raw_trait in member.get("innate_traits", []):
				var trait_id := str(raw_trait.get("id", "")) if raw_trait is Dictionary else str(raw_trait)
				if not REMOVED_PRODUCTION_TRAIT_IDS.has(trait_id):
					kept_traits.append(raw_trait)
			member["innate_traits"] = kept_traits
	var kept_orphans: Array = []
	for record in orphaned_mod_data.get("traits", []):
		if not (record is Dictionary) or not REMOVED_PRODUCTION_TRAIT_IDS.has(str(record.get("content_id", ""))):
			kept_orphans.append(record)
	orphaned_mod_data["traits"] = kept_orphans


func _settle_legacy_production_jobs(jobs: Dictionary) -> void:
	for building_id in [BUILDING_FORGE, BUILDING_ALCHEMY]:
		var raw_job = jobs.get(building_id, {})
		if not (raw_job is Dictionary):
			continue
		var job: Dictionary = raw_job
		if not ["running", "claimable"].has(str(job.get("status", "idle"))):
			continue
		if building_id == BUILDING_FORGE:
			_settle_legacy_forge_job(job)
		else:
			_settle_legacy_alchemy_job(job)


func _settle_legacy_forge_job(job: Dictionary) -> void:
	var template_ids: Array = DataTables.content_ids("equipment", DataTables.EQUIPMENT_DEFS)
	if template_ids.is_empty():
		orphaned_mod_data["production_jobs"].append(job.duplicate(true))
		return
	var names: Array[String] = []
	for _index in range(maxi(1, int(job.get("output_count", 1)))):
		var rarity := DataTables.random_equipment_rarity(rng)
		if rng.randf() < clampf(float(job.get("rarity_upgrade_chance", 0.0)), 0.0, 0.95):
			rarity = DataTables.upgrade_equipment_rarity(rarity, 1)
		var template_id := str(template_ids[rng.randi_range(0, template_ids.size() - 1)])
		var equipment := DataTables.create_equipment_from_template(
			template_id,
			maxi(1, int(job.get("member_level", expedition_level()))),
			rng,
			maxi(0, int(job.get("craft_bonus", 0))),
			"",
			rarity,
			"non_drop"
		)
		if not equipment.is_empty():
			add_equipment(equipment)
			names.append(str(equipment.get("name", "装备")))
	add_task_experience(GameDefs.TaskType.FORGE, 5)
	log_added.emit("旧炼器任务已结算：%s" % "、".join(names))


func _settle_legacy_alchemy_job(job: Dictionary) -> void:
	var result_item_id := str(job.get("result_item_id", ""))
	if result_item_id.is_empty() or DataTables.item_definition(result_item_id).is_empty():
		orphaned_mod_data["production_jobs"].append(job.duplicate(true))
		return
	var amount := maxi(1, int(job.get("amount", 1)))
	var result_count := amount * maxi(1, int(job.get("output_multiplier", 1)))
	for _index in range(amount):
		if rng.randf() < clampf(float(job.get("extra_chance", 0.0)), 0.0, 0.95):
			result_count += 1
	result_count += maxi(0, int(job.get("flat_output_bonus", 0))) * amount
	add_inventory_item(result_item_id, result_count, false)
	add_task_experience(GameDefs.TaskType.ALCHEMY, 5)
	log_added.emit("旧炼丹任务已结算：%s x%d" % [DataTables.resource_name(result_item_id), result_count])


func _quarantine_unknown_mod_content() -> void:
	_ensure_orphan_shape()
	var kept_inventory: Array = []
	for item in inventory:
		if item is Dictionary and not _inventory_content_available(item):
			orphaned_mod_data["inventory"].append(item.duplicate(true))
		else:
			kept_inventory.append(item)
	inventory = kept_inventory
	var kept_recipes: Array = []
	for recipe_id in known_alchemy_recipes:
		if DataTables.content_has("recipe", str(recipe_id), DataTables.ALCHEMY_RECIPE_DEFS):
			kept_recipes.append(recipe_id)
		else:
			orphaned_mod_data["recipes"].append(recipe_id)
	known_alchemy_recipes = kept_recipes
	for member in companions:
		if not (member is Dictionary):
			continue
		for field in ["innate_traits"]:
			var kind := "trait"
			var category := "traits"
			var kept: Array = []
			for value in member.get(field, []):
				var content_id := str(value.get("id", "")) if value is Dictionary else str(value)
				if DataTables.content_has(kind, content_id):
					kept.append(value)
				else:
					orphaned_mod_data[category].append({
						"member_id": str(member.get("id", "")),
						"content_id": content_id,
						"value": value.duplicate(true) if value is Dictionary or value is Array else value,
					})
			member[field] = kept


func _companions_save_data() -> Array:
	var result: Array = companions.duplicate(true)
	for member in result:
		if not (member is Dictionary):
			continue
		var references: Array = []
		for value in member.get("skills", []):
			var skill_reference := _skill_reference(value)
			if not skill_reference.is_empty():
				references.append(skill_reference)
		member["skills"] = references
	return result


func _resolve_member_skill_references() -> void:
	for member in companions:
		if not (member is Dictionary):
			continue
		var resolved: Array = []
		for value in member.get("skills", []):
			var skill_reference := _skill_reference(value)
			var skill_id := str(skill_reference.get("id", ""))
			if skill_id.is_empty():
				continue
			if not DataTables.content_has("skill", skill_id, DataTables.SKILL_DEFS):
				skill_reference["disabled"] = true
				resolved.append(skill_reference)
				continue
			var skill := DataTables.create_skill(skill_id, str(skill_reference.get("obtain_source", "non_drop")))
			skill["disabled"] = false
			resolved.append(skill)
		member["skills"] = resolved


func _skill_reference(value) -> Dictionary:
	var skill_id := str(value.get("id", "")) if value is Dictionary else str(value)
	if skill_id.is_empty():
		return {}
	return {
		"id": skill_id,
		"obtain_source": str(value.get("obtain_source", "non_drop")) if value is Dictionary else "non_drop",
		"disabled": bool(value.get("disabled", false)) if value is Dictionary else false,
	}


func _grant_missing_starter_skill_books() -> void:
	var starter_books := {
		DataTables.ITEM_ID_SKILL_BOOK_THUNDER: "thunder",
		DataTables.ITEM_ID_SKILL_BOOK_POISON: "poison",
		DataTables.ITEM_ID_SKILL_BOOK_HEAL: "heal",
		DataTables.ITEM_ID_SKILL_BOOK_ATTACK_UP: "attack_up",
		DataTables.ITEM_ID_SKILL_BOOK_SPIRIT_SHIELD: "spirit_shield",
	}
	for book_id in starter_books:
		var skill_id: String = str(starter_books[book_id])
		if _party_knows_skill(skill_id) or inventory_item_count(str(book_id)) > 0:
			continue
		add_inventory_item(str(book_id), 1, false)


func _party_knows_skill(skill_id: String) -> bool:
	for member in companions:
		if not (member is Dictionary):
			continue
		for skill in member.get("skills", []):
			if skill is Dictionary and str(skill.get("id", "")) == skill_id:
				return true
	return false


func _rng_save_data() -> Dictionary:
	return {
		"seed": int(rng.seed),
		"state": int(rng.state),
	}


func _load_rng_state(source) -> void:
	if not (source is Dictionary):
		return
	if source.has("seed"):
		rng.seed = int(source.get("seed", rng.seed))
	if source.has("state"):
		rng.state = int(source.get("state", rng.state))


func _load_progress_states(source) -> void:
	if not (source is Dictionary):
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


func set_progress_state(progress_id: String, status: String, detail: String = "") -> void:
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
	var progress: Dictionary = progress_states.get(progress_id, {})
	return progress.duplicate(true)


func building_level(building_id: String) -> int:
	if not building_levels.has(building_id):
		return 1
	return clampi(int(building_levels.get(building_id, 1)), 1, DataTables.building_max_level(building_id))


func building_upgrade_cost(building_id: String) -> Dictionary:
	var level: int = building_level(building_id)
	if level >= DataTables.building_max_level(building_id):
		return {}
	return DataTables.building_upgrade_cost(building_id, level)


func can_upgrade_building(building_id: String) -> bool:
	var cost: Dictionary = building_upgrade_cost(building_id)
	if cost.is_empty():
		return false
	return inventory_item_count(str(cost.get("item_id", ""))) >= int(cost.get("amount", 0))


func upgrade_building(building_id: String) -> bool:
	if not DataTables.BUILDING_DEFS.has(building_id):
		return false
	var current_level: int = building_level(building_id)
	var max_level: int = DataTables.building_max_level(building_id)
	if current_level >= max_level:
		log_added.emit("%s已满级" % DataTables.building_name(building_id))
		return false
	var cost: Dictionary = building_upgrade_cost(building_id)
	var item_id: String = str(cost.get("item_id", ""))
	var amount: int = int(cost.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return false
	if not spend_resource(item_id, amount):
		log_added.emit("%s不足，升级需要 %s x%d" % [DataTables.resource_name(item_id), DataTables.resource_name(item_id), amount])
		return false
	building_levels[building_id] = current_level + 1
	log_added.emit("%s等级提升至 %d" % [DataTables.building_name(building_id), int(building_levels[building_id])])
	changed.emit()
	return true


func _load_dictionary_values(target: Dictionary, source) -> void:
	if not (source is Dictionary):
		return
	for key in source.keys():
		target[key] = source[key]


func _duplicate_array(value) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


func _ensure_building_state() -> void:
	for building_id in DataTables.BUILDING_DEFS.keys():
		var level: int = int(building_levels.get(building_id, 1))
		building_levels[building_id] = clampi(level, 1, DataTables.building_max_level(str(building_id)))


func _ensure_account_progression() -> void:
	account_progression["expedition_level"] = maxi(1, int(account_progression.get("expedition_level", 1)))
	account_progression["expedition_exp"] = maxi(0, int(account_progression.get("expedition_exp", 0)))
	account_progression["next_expedition_exp"] = maxi(1, int(account_progression.get("next_expedition_exp", 40)))
	while int(account_progression["expedition_exp"]) >= int(account_progression["next_expedition_exp"]):
		account_progression["expedition_exp"] = int(account_progression["expedition_exp"]) - int(account_progression["next_expedition_exp"])
		account_progression["expedition_level"] = int(account_progression["expedition_level"]) + 1
		account_progression["next_expedition_exp"] = 40 + (int(account_progression["expedition_level"]) - 1) * 20


func expedition_level() -> int:
	return maxi(1, int(account_progression.get("expedition_level", 1)))


func set_selected_expedition_map_id(map_id: String) -> void:
	if map_id.is_empty() or selected_expedition_map_id == map_id:
		return
	selected_expedition_map_id = map_id
	changed.emit()


func add_expedition_exp(amount: int) -> void:
	if amount <= 0:
		return
	account_progression["expedition_exp"] = int(account_progression.get("expedition_exp", 0)) + amount
	var old_level := expedition_level()
	_ensure_account_progression()
	if expedition_level() > old_level:
		log_added.emit("历练等级提升至 %d" % expedition_level())
	changed.emit()


func recover_party_after_defeat(ratio: float = 0.5) -> void:
	var recovery_ratio: float = clampf(ratio, 0.0, 1.0)
	for member in party_members():
		var member_id: String = str(member.get("id", ""))
		var member_stats: Dictionary = member.get("stats", {})
		var max_hp: int = maxi(1, total_stat_for(member_id, "max_hp"))
		var max_mp: int = maxi(0, total_stat_for(member_id, "max_mp"))
		member_stats["hp"] = maxi(1, ceili(float(max_hp) * recovery_ratio))
		member_stats["mp"] = clampi(ceili(float(max_mp) * recovery_ratio), 0, max_mp)
	changed.emit()


func _ensure_permanent_building_bonuses() -> void:
	for building_id in PRODUCTION_BUILDING_IDS:
		var raw_bonus = permanent_building_bonuses.get(building_id, {})
		var bonus: Dictionary = raw_bonus if raw_bonus is Dictionary else {}
		bonus["output_quality"] = maxi(0, int(bonus.get("output_quality", 0)))
		permanent_building_bonuses[building_id] = bonus


func building_output_quality(building_id: String) -> int:
	if not PRODUCTION_BUILDING_IDS.has(building_id):
		return 0
	return maxi(0, int(permanent_building_bonuses.get(building_id, {}).get("output_quality", 0)))


func apply_permanent_building_quality(item: Dictionary) -> bool:
	var effect = item.get("payload", {}).get("permanent_building_quality", {})
	if not (effect is Dictionary):
		return false
	var building_id: String = str(effect.get("building_id", ""))
	var amount: int = int(effect.get("amount", 0))
	if not PRODUCTION_BUILDING_IDS.has(building_id) or amount <= 0:
		log_added.emit("建筑品质道具配置无效")
		return false
	_remove_inventory_count(str(item.get("item_id", "")), 1)
	var bonus: Dictionary = permanent_building_bonuses.get(building_id, {})
	bonus["output_quality"] = building_output_quality(building_id) + amount
	permanent_building_bonuses[building_id] = bonus
	log_added.emit("%s永久品质提升至 %d" % [DataTables.building_name(building_id), building_output_quality(building_id)])
	changed.emit()
	return true


func _format_duration(seconds: float) -> String:
	var total: int = maxi(0, int(ceil(seconds)))
	var minutes: int = int(float(total) / 60.0)
	var rest: int = total % 60
	return "%02d:%02d" % [minutes, rest]


func _sanitize_loaded_inventory() -> void:
	for index in range(inventory.size() - 1, -1, -1):
		if not (inventory[index] is Dictionary):
			inventory.remove_at(index)
			continue
		var item: Dictionary = inventory[index]
		var item_id: String = str(item.get("item_id", ""))
		var item_type: String = str(item.get("type", ""))
		if item_id.is_empty() or item_type.is_empty():
			inventory.remove_at(index)
			continue
		item["instance_id"] = str(item.get("instance_id", item_id))
		item["count"] = maxi(1, int(item.get("count", 1)))
		item["payload"] = item.get("payload", {}) if item.get("payload", {}) is Dictionary else {}
		if item_type == DataTables.ITEM_TYPE_EQUIPMENT:
			_sanitize_loaded_equipment(item)
		else:
			if DataTables.item_definition(item_id).is_empty():
				inventory.remove_at(index)
				continue
			_sanitize_loaded_stack_item(item)
		inventory[index] = item


func _sanitize_loaded_stack_item(item: Dictionary) -> void:
	var item_id: String = str(item.get("item_id", ""))
	var definition: Dictionary = DataTables.item_definition(item_id)
	if definition.is_empty():
		return
	item["name"] = str(item.get("name", definition.get("name", item_id)))
	item["description"] = str(item.get("description", definition.get("description", "")))
	item["type"] = str(item.get("type", definition.get("type", "")))
	item["stackable"] = bool(item.get("stackable", definition.get("stackable", true)))
	item["usable"] = bool(item.get("usable", definition.get("usable", false)))
	item["gain_target"] = str(item.get("gain_target", definition.get("gain_target", "none")))
	item["obtain_source"] = str(item.get("obtain_source", "non_drop"))
	item["item_no"] = int(item.get("item_no", DataTables.item_no(item_id)))
	item["icon_name"] = str(item.get("icon_name", DataTables.item_icon_name(item_id)))
	item["icon_path"] = str(item.get("icon_path", DataTables.item_icon_path(item_id)))
	item["resource_path"] = str(item.get("resource_path", DataTables.item_resource_path(item_id)))


func _sanitize_loaded_equipment(item: Dictionary) -> void:
	var item_id: String = str(item.get("item_id", ""))
	item["stackable"] = false
	item["usable"] = bool(item.get("usable", true))
	item["slot"] = str(item.get("slot", "weapon"))
	item["rarity"] = str(item.get("rarity", "t1"))
	item["equipment_level"] = maxi(1, int(item.get("equipment_level", 1)))
	item["icon_name"] = str(item.get("icon_name", DataTables.equipment_icon_name(item_id)))
	item["icon_path"] = str(item.get("icon_path", DataTables.equipment_icon_path(item_id)))
	item["resource_path"] = str(item.get("resource_path", DataTables.equipment_resource_path(item_id)))
	item["base_attributes"] = _duplicate_array(item.get("base_attributes", []))
	item["attribute_generation_version"] = maxi(0, int(item.get("attribute_generation_version", 0)))
	item["description_effects"] = _duplicate_array(item.get("description_effects", DataTables.equipment_template_description_effects(item_id)))
	item["enhanced_attributes"] = _duplicate_array(item.get("enhanced_attributes", []))
	item["refine_affixes"] = _duplicate_array(item.get("refine_affixes", []))
	item["affixes"] = _duplicate_array(item.get("affixes", []))
	item["enhance_count"] = maxi(0, int(item.get("enhance_count", 0)))
	item["refine_count"] = maxi(0, int(item.get("refine_count", 0)))
	item["equipped"] = bool(item.get("equipped", false))
	item["equipped_by"] = str(item.get("equipped_by", ""))
	if str(item.get("equipped_by", "")) == "player":
		item["equipped"] = false
		item["equipped_by"] = ""
		item.erase("equipped_slot")
	item["equip_requirement"] = item.get("equip_requirement", {}) if item.get("equip_requirement", {}) is Dictionary else {}
	_update_equipment_compat_bonuses(item)


func _migrate_equipment_attribute_model() -> void:
	for index in range(inventory.size()):
		var item: Dictionary = inventory[index]
		if str(item.get("type", "")) != DataTables.ITEM_TYPE_EQUIPMENT:
			continue
		item["base_attributes"] = DataTables.generate_equipment_base_attributes(str(item.get("rarity", "t1")), rng)
		item["attribute_generation_version"] = 1
		item["affixes"] = []
		item["enhanced_attributes"] = []
		item["refine_affixes"] = []
		item["enhance_count"] = 0
		item["enhance_level"] = 0
		item["refine_count"] = 0
		_update_equipment_compat_bonuses(item)
		inventory[index] = item


func _migrate_equipment_refine_model() -> void:
	for index in range(inventory.size()):
		var item: Dictionary = inventory[index]
		if str(item.get("type", "")) != DataTables.ITEM_TYPE_EQUIPMENT:
			continue
		item["refine_affixes"] = []
		inventory[index] = item


func _sanitize_active_buffs() -> void:
	for index in range(active_buffs.size() - 1, -1, -1):
		if not (active_buffs[index] is Dictionary):
			active_buffs.remove_at(index)
			continue
		var buff: Dictionary = active_buffs[index]
		buff["item_id"] = str(buff.get("item_id", ""))
		buff["name"] = str(buff.get("name", DataTables.resource_name(str(buff.get("item_id", "")))))
		buff["stat"] = str(buff.get("stat", ""))
		buff["amount"] = int(buff.get("amount", 0))
		buff["remaining"] = float(buff.get("remaining", 0.0))
		buff["member_id"] = str(buff.get("member_id", ""))
		if str(buff.get("item_id", "")).is_empty() or str(buff.get("stat", "")).is_empty() or float(buff.get("remaining", 0.0)) <= 0.0 or member_by_id(str(buff.get("member_id", ""))).is_empty():
			active_buffs.remove_at(index)
			continue
		active_buffs[index] = buff


func _sanitize_farm_speed_buffs() -> void:
	for index in range(farm_speed_buffs.size() - 1, -1, -1):
		if not (farm_speed_buffs[index] is Dictionary):
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


func growth_summary_for(member_id: String) -> String:
	return party_service.growth_summary_for(member_id)


func party_members() -> Array:
	return party_service.party_members()


func roster_members() -> Array:
	return party_service.roster_members()


func active_party_members() -> Array:
	return party_service.active_party_members()


func member_by_id(member_id: String) -> Dictionary:
	return party_service.member_by_id(member_id)


func party_member_count() -> int:
	return party_service.party_member_count()


func roster_member_count() -> int:
	return party_service.roster_member_count()


func generate_recruit_candidates(should_emit_signal: bool = true) -> void:
	party_service.generate_recruit_candidates(should_emit_signal)


func recruit_candidate(candidate_id: String) -> bool:
	return party_service.recruit_candidate(candidate_id)


func move_party_member(member_id: String, direction: int) -> bool:
	return party_service.move_party_member(member_id, direction)


func dismiss_companion(member_id: String) -> bool:
	return party_service.dismiss_companion(member_id)


func release_companion(member_id: String) -> bool:
	return party_service.release_companion(member_id)


func set_member_active(member_id: String, active: bool) -> bool:
	return party_service.set_member_active(member_id, active)


func is_member_active(member_id: String) -> bool:
	return party_order.has(member_id)


func can_recruit() -> bool:
	return party_service.can_recruit()


func recruit_resource_id() -> String:
	return party_service.recruit_resource_id()


func recruit_cost() -> int:
	return party_service.recruit_cost()


func recruit_stone_count() -> int:
	return party_service.recruit_stone_count()


func has_party_member() -> bool:
	return party_member_count() > 0


func default_party_member_id() -> String:
	var members: Array = party_members()
	if members.is_empty():
		return ""
	return str(members[0].get("id", ""))


func total_attack_for(member_id: String) -> int:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	return _total_attack_for_member(member)


func total_defense_for(member_id: String) -> int:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	return _total_defense_for_member(member)


func total_stat_for(member_id: String, stat_id: String) -> int:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	return _total_stat_for_member(member, stat_id)


func total_element_for(member_id: String, element_id: String) -> int:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	return _total_element_for_member(member, element_id)


func element_summary_for(member_id: String) -> String:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return "木0 火0 土0 金0 水0"
	return "木%d 火%d 土%d 金%d 水%d" % [
		_total_element_for_member(member, "wood"),
		_total_element_for_member(member, "fire"),
		_total_element_for_member(member, "earth"),
		_total_element_for_member(member, "metal"),
		_total_element_for_member(member, "water"),
	]


func dominant_element_for(member_id: String) -> String:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return ""
	return _dominant_element_for_member(member)


func element_damage_bonus_for(member_id: String, element_id: String) -> int:
	return int(total_element_for(member_id, element_id) * 0.5)


func reduce_physical_damage_for(member_id: String, amount: int) -> int:
	return int(max(1, amount - total_defense_for(member_id)))


func reduce_element_damage_for(member_id: String, element_id: String, amount: int) -> int:
	return int(max(0, amount - int(total_element_for(member_id, element_id) * 0.35)))


func take_damage_for(member_id: String, amount: int, element_id: String = "") -> int:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	var member_stats: Dictionary = member.get("stats", {})
	var final_amount: int = reduce_physical_damage_for(member_id, amount)
	if not element_id.is_empty():
		final_amount = reduce_element_damage_for(member_id, element_id, final_amount)
	member_stats["hp"] = max(0, int(member_stats.get("hp", 0)) - final_amount)
	changed.emit()
	return final_amount


func spend_mp_for(member_id: String, amount: int) -> bool:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return false
	var member_stats: Dictionary = member.get("stats", {})
	if int(member_stats.get("mp", 0)) < amount:
		return false
	member_stats["mp"] = int(member_stats.get("mp", 0)) - amount
	changed.emit()
	return true


func heal_member(member_id: String, hp_amount: int, mp_amount: int) -> Dictionary:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return {"hp": 0, "mp": 0}
	var member_stats: Dictionary = member.get("stats", {})
	var old_hp: int = int(member_stats.get("hp", 0))
	var old_mp: int = int(member_stats.get("mp", 0))
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
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return {}
	var member_equipped: Dictionary = member.get("equipped", {})
	var instance_id: String = str(member_equipped.get(slot, ""))
	if instance_id.is_empty():
		return {}
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty():
		return {}
	return item


func equip_item_for_member(instance_id: String, member_id: String) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		log_added.emit("需要先招募角色")
		return false
	var slot: String = _equipment_slot_for_member(item, member)
	var member_equipped: Dictionary = member.get("equipped", {})
	var previous_id: String = str(member_equipped.get(slot, ""))
	if previous_id == instance_id:
		log_added.emit("%s已由%s装备" % [item.get("name", "装备"), member.get("name", "成员")])
		return true
	if not equipment_requirement_met_for(item, member_id, slot):
		var requirement_text: String = equipment_requirement_text_for(item, member_id)
		log_added.emit("%s穿戴需求不足：%s" % [item.get("name", "装备"), requirement_text])
		return false
	_unequip_if_needed(instance_id)
	if not previous_id.is_empty():
		_unequip_if_needed(previous_id)
	item["equipped"] = true
	item["equipped_by"] = str(member.get("id", ""))
	item["equipped_slot"] = slot
	member_equipped[slot] = instance_id
	log_added.emit("%s穿戴%s" % [member.get("name", "成员"), item.get("name", "装备")])
	changed.emit()
	return true


func equipment_requirement_met_for(item: Dictionary, member_id: String, target_slot: String = "") -> bool:
	var requirement: Dictionary = item.get("equip_requirement", {})
	if requirement.is_empty():
		return true
	return equipment_requirement_current_value_for(item, member_id, target_slot) >= int(requirement.get("min", 0))


func equipment_requirement_current_value_for(item: Dictionary, member_id: String, target_slot: String = "") -> int:
	var requirement: Dictionary = item.get("equip_requirement", {})
	var stat_id: String = str(requirement.get("stat", ""))
	if stat_id.is_empty():
		return 0
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	var excluded_slot: String = str(target_slot)
	if excluded_slot.is_empty():
		excluded_slot = _equipment_slot_for_member(item, member)
	return _total_requirement_stat_excluding_slot_for(member, stat_id, excluded_slot)


func equipment_requirement_text_for(item: Dictionary, member_id: String) -> String:
	var requirement: Dictionary = item.get("equip_requirement", {})
	if requirement.is_empty():
		return ""
	var stat_id: String = str(requirement.get("stat", ""))
	var current: int = equipment_requirement_current_value_for(item, member_id)
	var needed: int = int(requirement.get("min", 0))
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


func _random_growth_primary_stats() -> Array:
	return party_service.random_growth_primary_stats()


func _normalized_growth_primary_stats(raw_value) -> Array:
	return party_service.normalized_growth_primary_stats(raw_value)


func _growth_summary_for_member(member: Dictionary) -> String:
	return party_service.growth_summary_for_member_data(member)


func _attribute_list_text(stat_ids: Array) -> String:
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
	return int(member_elements.get(element_id, 0)) + _trait_element_flat_bonus_for_member(member, element_id) + _equipment_attribute_bonus_for_member(member, "element_%s" % element_id)


func _element_power_for_member(member: Dictionary) -> int:
	var value: int = 0
	for element_id in DataTables.ELEMENT_IDS:
		value += _total_element_for_member(member, str(element_id))
	return value


func _dominant_element_for_member(member: Dictionary) -> String:
	var best_id: String = "wood"
	var best_value: int = -1
	for element_id in DataTables.ELEMENT_IDS:
		var element_value: int = _total_element_for_member(member, str(element_id))
		if element_value > best_value:
			best_id = str(element_id)
			best_value = element_value
	return best_id


func _stat_bonus_for_member(member: Dictionary, stat_id: String) -> int:
	var value: int = 0
	for buff in active_buffs:
		if str(buff.get("member_id", "")) == str(member.get("id", "")) and buff.get("stat", "") == stat_id:
			value += int(buff.get("amount", 0))
	value += _trait_stat_flat_bonus_for_member(member, stat_id)
	for item in _equipped_items_for_member(member):
		value += _item_affix_bonus(item, stat_id)
	return value


func _equipment_attribute_bonus_for_member(member: Dictionary, stat_id: String) -> int:
	var value: int = 0
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
	var value: int = 0
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
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return
	var member_equipped: Dictionary = member.get("equipped", {})
	for slot in member_equipped.keys():
		var instance_id: String = str(member_equipped.get(slot, ""))
		if not instance_id.is_empty():
			_unequip_if_needed(instance_id)


func _clamp_member_runtime_stats(member: Dictionary) -> void:
	party_service.clamp_member_runtime_stats(member)


func total_attack() -> int:
	return total_attack_for(default_party_member_id())


func total_defense() -> int:
	return total_defense_for(default_party_member_id())


func total_stat(stat_id: String) -> int:
	return total_stat_for(default_party_member_id(), stat_id)


func total_element(element_id: String) -> int:
	return total_element_for(default_party_member_id(), element_id)


func element_power() -> int:
	var value: int = 0
	for element_id in DataTables.ELEMENT_IDS:
		value += total_element(element_id)
	return value


func dominant_element() -> String:
	return dominant_element_for(default_party_member_id())


func cultivation_gain(base_amount: int) -> int:
	return base_amount + int(total_stat("root_bone") * 0.4)


func craft_bonus() -> int:
	return 0


func forge_material_cost() -> int:
	return 4


func can_craft_equipment() -> bool:
	return inventory_item_count(DataTables.ITEM_ID_ORE) >= forge_material_cost()


func forge_rarity_upgrade_chance() -> float:
	var level_chance := 0.03 * float(building_level(BUILDING_FORGE) - 1)
	var quality_chance := 0.05 * float(building_output_quality(BUILDING_FORGE))
	return clampf(level_chance + quality_chance, 0.0, 0.95)


func craft_equipment() -> bool:
	var cost := forge_material_cost()
	if not spend_resource(DataTables.ITEM_ID_ORE, cost):
		log_added.emit("矿石不足，炼器需要 %d 个矿石" % cost)
		return false
	var level: int = building_level(BUILDING_FORGE)
	var output_count: int = 2 if level >= 6 else 1
	var template_ids: Array = DataTables.content_ids("equipment", DataTables.EQUIPMENT_DEFS)
	if template_ids.is_empty():
		add_inventory_item(DataTables.ITEM_ID_ORE, cost, false)
		log_added.emit("没有可用的装备模板")
		changed.emit()
		return false
	var names: Array[String] = []
	for _index in range(output_count):
		var rarity: String = DataTables.random_equipment_rarity(rng)
		if rng.randf() < forge_rarity_upgrade_chance():
			rarity = DataTables.upgrade_equipment_rarity(rarity, 1)
		var equipment: Dictionary = DataTables.create_equipment_from_template(
			str(template_ids[rng.randi_range(0, template_ids.size() - 1)]),
			expedition_level(),
			rng,
			0,
			"",
			rarity,
			"non_drop"
		)
		add_equipment(equipment)
		names.append(str(equipment.get("name", "装备")))
	add_task_experience(GameDefs.TaskType.FORGE, 5)
	log_added.emit("炼器完成：%s" % "、".join(names))
	changed.emit()
	return true


func element_damage_bonus(element_id: String) -> int:
	return element_damage_bonus_for(default_party_member_id(), element_id)


func reduce_element_damage(element_id: String, amount: int) -> int:
	return reduce_element_damage_for(default_party_member_id(), element_id, amount)


func reduce_physical_damage(amount: int) -> int:
	return reduce_physical_damage_for(default_party_member_id(), amount)


func physical_resistance() -> int:
	return total_defense()


func element_resistance(element_id: String) -> int:
	return int(total_element(element_id) * 0.35)


func heal(hp_amount: int, mp_amount: int) -> void:
	heal_member(default_party_member_id(), hp_amount, mp_amount)


func spend_mp(amount: int) -> bool:
	return spend_mp_for(default_party_member_id(), amount)


func take_damage(amount: int, element_id: String = "") -> void:
	take_damage_for(default_party_member_id(), amount, element_id)


func add_exp(amount: int) -> void:
	add_exp_for_member(default_party_member_id(), amount)


func add_cultivation(amount: int) -> void:
	add_exp_for_member(default_party_member_id(), cultivation_gain(amount))


func add_task_experience(task_type: int, amount: int) -> void:
	var key: String = DataTables.task_zone_id(task_type)
	task_exp[key] = task_exp.get(key, 0) + amount
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
	if not DataTables.content_has("equipment", template_id, DataTables.EQUIPMENT_DEFS):
		log_added.emit("调试生成装备失败：未知模板 %s" % template_id)
		return false
	if not DataTables.EQUIPMENT_RARITY_ORDER.has(rarity):
		log_added.emit("调试生成装备失败：未知稀有度 %s" % rarity)
		return false
	var equipment: Dictionary = DataTables.create_equipment_from_template(template_id, maxi(1, level), rng, craft_bonus(), "", rarity, "debug")
	if equipment.is_empty():
		log_added.emit("调试生成装备失败")
		return false
	add_inventory_instance(equipment)
	log_added.emit("调试生成装备：%s" % equipment.get("name", "装备"))
	return true


func debug_set_stat(stat_id: String, value: int, member_id: String = "") -> bool:
	if member_id.is_empty():
		member_id = default_party_member_id()
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		log_added.emit("调试设置失败：当前没有编队角色")
		return false
	var member_stats: Dictionary = member.get("stats", {})
	var member_elements: Dictionary = member.get("elements", {})
	if member_stats.has(stat_id):
		member_stats[stat_id] = _debug_clamped_stat_value(stat_id, value)
	elif member_elements.has(stat_id):
		member_elements[stat_id] = maxi(0, value)
	else:
		log_added.emit("调试设置失败：未知属性 %s" % stat_id)
		return false
	_clamp_runtime_stats()
	log_added.emit("调试设置：%s = %d" % [DataTables.attribute_display_name(stat_id), _debug_stat_value(stat_id, member_id)])
	changed.emit()
	return true


func spend_resource(resource_id: String, amount: int) -> bool:
	return inventory_service.spend_resource(resource_id, amount)


func spend_inventory_type(type_id: String, amount: int) -> bool:
	return inventory_service.spend_inventory_type(type_id, amount)


func add_inventory_item(item_id: String, amount: int, should_emit_signal: bool = true) -> bool:
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
	return equipped_item_for(default_party_member_id(), slot)


func is_inventory_item_usable(instance_id: String) -> bool:
	return inventory_service.is_inventory_item_usable(instance_id)


func is_inventory_item_direct_usable(instance_id: String) -> bool:
	return inventory_service.is_inventory_item_direct_usable(instance_id)


func use_inventory_item(instance_id: String) -> bool:
	return inventory_service.use_inventory_item(instance_id)


func use_inventory_item_for_member(instance_id: String, member_id: String) -> bool:
	return inventory_service.use_inventory_item_for_member(instance_id, member_id)


func _use_home_item(item: Dictionary) -> bool:
	if item.get("payload", {}).has("permanent_building_quality"):
		return apply_permanent_building_quality(item)
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
	return element_summary_for(default_party_member_id())


func _debug_clamped_stat_value(stat_id: String, value: int) -> int:
	var min_one_stats: Array = ["level", "level_cap", "stage", "farm_level", "next_exp", "next_cultivation", "max_hp", "max_mp"]
	if min_one_stats.has(stat_id):
		return maxi(1, value)
	return maxi(0, value)


func _debug_stat_value(stat_id: String, member_id: String = "") -> int:
	if member_id.is_empty():
		member_id = default_party_member_id()
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	var member_stats: Dictionary = member.get("stats", {})
	var member_elements: Dictionary = member.get("elements", {})
	if member_stats.has(stat_id):
		return int(member_stats.get(stat_id, 0))
	if member_elements.has(stat_id):
		return int(member_elements.get(stat_id, 0))
	return 0


func _clamp_runtime_stats() -> void:
	_ensure_building_state()
	for member in companions:
		_clamp_member_runtime_stats(member)


func task_exp_for(task_type: int) -> int:
	return int(task_exp.get(DataTables.task_zone_id(task_type), 0))


func _find_stack_item(item_id: String) -> Dictionary:
	return inventory_service.find_stack_item(item_id)


func _remove_inventory_count(item_id: String, amount: int) -> void:
	inventory_service.remove_inventory_count(item_id, amount)


func can_equip_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var member: Dictionary = member_by_id(default_party_member_id())
	if member.is_empty():
		return false
	var slot: String = _equipment_slot_for_member(item, member)
	return equipment_requirement_met_for(item, str(member.get("id", "")), slot)


func equipment_requirement_met(item: Dictionary, target_slot: String = "") -> bool:
	return equipment_requirement_met_for(item, default_party_member_id(), target_slot)


func equipment_requirement_current_value(item: Dictionary, target_slot: String = "") -> int:
	return equipment_requirement_current_value_for(item, default_party_member_id(), target_slot)


func equipment_requirement_text(item: Dictionary) -> String:
	return equipment_requirement_text_for(item, default_party_member_id())


func _equip_item(item: Dictionary) -> bool:
	return equip_item_for_member(str(item.get("instance_id", "")), default_party_member_id())


func _equipment_slot_for_item(item: Dictionary) -> String:
	var member: Dictionary = member_by_id(default_party_member_id())
	if member.is_empty():
		return str(item.get("slot", "weapon"))
	return _equipment_slot_for_member(item, member)


func _unequip_if_needed(instance_id: String) -> void:
	for companion in companions:
		var companion_equipped: Dictionary = companion.get("equipped", {})
		for slot in companion_equipped.keys():
			if companion_equipped[slot] == instance_id:
				companion_equipped[slot] = ""
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if not item.is_empty():
		item["equipped"] = false
		item.erase("equipped_by")
		item.erase("equipped_slot")


func _use_skill_book(item: Dictionary, member_id: String = "") -> bool:
	if member_id.is_empty():
		member_id = default_party_member_id()
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		log_added.emit("需要先招募角色")
		return false
	var skill_id: String = item.get("payload", {}).get("skill_id", "")
	if skill_id.is_empty():
		return false

	if _knows_skill(skill_id, member_id):
		log_added.emit("已经学会%s" % DataTables.create_skill(skill_id)["name"])
		return false

	var skill: Dictionary = DataTables.create_skill(skill_id, str(item.get("payload", {}).get("obtain_source", "non_drop")))
	if skill.is_empty():
		log_added.emit("技能不存在，技能书未消耗")
		return false
	var member_skills: Array = member.get("skills", [])
	# Learned character skills are append-only: skill books never replace an existing skill.
	member_skills.append(skill)
	member["skills"] = member_skills
	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("学会%s" % skill["name"])
	changed.emit()
	return true


func _knows_skill(skill_id: String, member_id: String = "") -> bool:
	if member_id.is_empty():
		member_id = default_party_member_id()
	var member: Dictionary = member_by_id(member_id)
	for skill in member.get("skills", []):
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
	return _use_pill_for_member(item, default_party_member_id())


func _use_pill_for_member(item: Dictionary, member_id: String) -> bool:
	var payload: Dictionary = item.get("payload", {})
	if bool(payload.get("breakthrough", false)):
		return _use_breakthrough_item(item, member_id)
	if payload.get("effect_mode", "instant") == "duration":
		var duration: float = float(payload.get("duration", 0.0))
		var existing_buff: Dictionary = _active_buff_for_item(str(item["item_id"]), member_id)
		if existing_buff.is_empty():
			active_buffs.append({
				"item_id": item["item_id"],
				"name": item["name"],
				"stat": payload.get("stat", ""),
				"amount": int(payload.get("amount", 0)),
				"remaining": duration,
				"member_id": member_id,
			})
		else:
			existing_buff["remaining"] = float(existing_buff.get("remaining", 0.0)) + duration
		_remove_inventory_count(item["item_id"], 1)
		log_added.emit("使用%s，增益生效" % item["name"])
		changed.emit()
		return true

	var hp_amount: int = int(payload.get("hp", 0))
	var mp_amount: int = int(payload.get("mp", 0))
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		log_added.emit("需要先招募角色")
		return false
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


func _use_breakthrough_item(item: Dictionary, member_id: String) -> bool:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		log_added.emit("需要先招募角色")
		return false
	var member_stats: Dictionary = member.get("stats", {})
	if int(member_stats.get("level", 1)) < int(member_stats.get("level_cap", 10)):
		log_added.emit("尚未达到当前阶段等级上限")
		return false

	_unlock_next_stage_for_member(member)
	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("%s使用%s，突破至阶段 %d" % [str(member.get("name", "成员")), item["name"], int(member_stats.get("stage", 1))])
	changed.emit()
	return true


func update_buffs(delta: float) -> void:
	if active_buffs.is_empty():
		return
	var index: int = 0
	while index < active_buffs.size():
		var buff: Dictionary = active_buffs[index]
		buff["remaining"] = float(buff.get("remaining", 0.0)) - delta
		if float(buff["remaining"]) <= 0.0:
			active_buffs.remove_at(index)
		else:
			index += 1
	changed.emit()


func consume_seed_for_farm() -> Dictionary:
	var slot_index: int = first_empty_farm_slot_index()
	if slot_index < 0:
		log_added.emit("农田已满")
		return {}
	for item in inventory:
		var item_id: String = str(item.get("item_id", ""))
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
	var harvest_amount: int = farm_harvest_amount_for(crop_id, true)
	farm_slots[slot_index] = {
		"status": FARM_STATUS_GROWING,
		"crop_id": crop_id,
		"elapsed_seconds": 0.0,
		"growth_seconds": DataTables.crop_growth_seconds(crop_id) * DataTables.farm_growth_multiplier(building_level(BUILDING_FARM)),
		"harvest_amount": max(1, harvest_amount),
	}
	set_progress_state("farm", "growing", "种下%s" % DataTables.resource_name(crop_id))
	log_added.emit("种下%s，预计收成 x%d" % [DataTables.resource_name(crop_id), max(1, harvest_amount)])
	changed.emit()
	return true


func farm_harvest_amount_for(crop_id: String, roll_extra: bool = false) -> int:
	var farm_level: int = building_level(BUILDING_FARM)
	var amount: int = DataTables.crop_seed_yield(crop_id) + farm_level - 1
	var extra_chance: float = 0.02 * float(farm_level - 1)
	if roll_extra and extra_chance > 0.0 and rng.randf() < extra_chance:
		amount += 1
	return int(max(1, amount))

func _active_buff_for_item(item_id: String, member_id: String = "") -> Dictionary:
	for buff in active_buffs:
		if str(buff.get("item_id", "")) == item_id and str(buff.get("member_id", "")) == member_id:
			return buff
	return {}


func update_farm(delta: float) -> void:
	_ensure_farm_slots()
	var changed_farm: bool = false
	var multiplier: float = farm_speed_multiplier()
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
	var crop_id: String = str(slot.get("crop_id", ""))
	var amount: int = int(slot.get("harvest_amount", 0))
	if crop_id.is_empty() or amount <= 0:
		return false
	add_inventory_item(crop_id, amount, false)
	farm_slots[slot_index] = _empty_farm_slot()
	add_task_experience(GameDefs.TaskType.FARM, 5)
	log_added.emit("收取%s x%d" % [DataTables.resource_name(crop_id), amount])
	_refresh_farm_progress_state()
	changed.emit()
	return true


func claim_all_farm_slots() -> int:
	var claimed: int = 0
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
	var multiplier: float = 1.0
	for buff in farm_speed_buffs:
		if float(buff.get("remaining_seconds", 0.0)) > 0.0:
			multiplier = max(multiplier, float(buff.get("multiplier", 1.0)))
	return multiplier


func farm_speed_remaining_seconds() -> float:
	var remaining: float = 0.0
	for buff in farm_speed_buffs:
		remaining = max(remaining, float(buff.get("remaining_seconds", 0.0)))
	return remaining

func _trait_stat_flat_bonus_for_member(member: Dictionary, stat_id: String) -> int:
	var value: int = 0
	for effect in _innate_trait_effects_for_member(member):
		if not (effect is Dictionary):
			continue
		if str(effect.get("kind", "")) != "stat_flat":
			continue
		if str(effect.get("stat", "")) != stat_id:
			continue
		value += int(effect.get("amount", effect.get("value", 0)))
	return value


func _trait_element_flat_bonus_for_member(member: Dictionary, element_id: String) -> int:
	var value: int = 0
	for effect in _innate_trait_effects_for_member(member):
		if not (effect is Dictionary):
			continue
		var kind: String = str(effect.get("kind", ""))
		var stat_id: String = str(effect.get("stat", ""))
		if kind == "element_flat" and str(effect.get("element", "")) == element_id:
			value += int(effect.get("amount", effect.get("value", 0)))
		elif kind == "stat_flat" and stat_id == "element_%s" % element_id:
			value += int(effect.get("amount", effect.get("value", 0)))
	return value


func _innate_trait_effects_for_member(member: Dictionary) -> Array:
	var effects: Array = []
	var source: Variant = member.get("innate_traits", [])
	var raw_traits: Array = []
	if source is Array:
		raw_traits.assign(source)
	for raw_trait in raw_traits:
		if raw_trait is String:
			var trait_id: String = str(raw_trait)
			var definition = DataTables.content_definition("trait", trait_id, DataTables.INNATE_TRAIT_DEFS.get(trait_id, {}))
			if definition is Dictionary:
				_append_effects_from_value(effects, definition.get("effects", []))
		elif raw_trait is Dictionary:
			var trait_id: String = str(raw_trait.get("id", ""))
			if not trait_id.is_empty():
				var definition = DataTables.content_definition("trait", trait_id, DataTables.INNATE_TRAIT_DEFS.get(trait_id, {}))
				if definition is Dictionary:
					_append_effects_from_value(effects, definition.get("effects", []))
					if bool(raw_trait.get("awakened", false)):
						_append_effects_from_value(effects, definition.get("awakened_effects", []))
			_append_effects_from_value(effects, raw_trait.get("effects", []))
			if bool(raw_trait.get("awakened", false)):
				_append_effects_from_value(effects, raw_trait.get("awakened_effects", []))
	return effects


func _append_effects_from_value(effects: Array, value) -> void:
	if not (value is Array):
		return
	for effect in value:
		if effect is Dictionary:
			effects.append(effect)


func ready_farm_slot_count() -> int:
	var count: int = 0
	for slot in farm_slots:
		if str(slot.get("status", FARM_STATUS_EMPTY)) == FARM_STATUS_READY:
			count += 1
	return count


func active_farm_slot_count() -> int:
	var count: int = 0
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
		var status: String = str(slot.get("status", FARM_STATUS_EMPTY))
		if not [FARM_STATUS_EMPTY, FARM_STATUS_GROWING, FARM_STATUS_READY].has(status):
			status = FARM_STATUS_EMPTY
		if status == FARM_STATUS_EMPTY:
			farm_slots[index] = _empty_farm_slot()
		else:
			slot["status"] = status
			slot["crop_id"] = str(slot.get("crop_id", ""))
			slot.erase("worker_id")
			slot.erase("worker_name")
			slot["elapsed_seconds"] = float(slot.get("elapsed_seconds", 0.0))
			slot["growth_seconds"] = max(1.0, float(slot.get("growth_seconds", DataTables.crop_growth_seconds(str(slot.get("crop_id", ""))))))
			slot["harvest_amount"] = max(1, int(slot.get("harvest_amount", 1)))
			farm_slots[index] = slot


func _empty_farm_slot() -> Dictionary:
	return {"status": FARM_STATUS_EMPTY, "crop_id": "", "elapsed_seconds": 0.0, "growth_seconds": 0.0, "harvest_amount": 0}


func _update_farm_speed_buffs(delta: float) -> bool:
	var changed_buffs: bool = false
	var index: int = 0
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
	var ready_count: int = ready_farm_slot_count()
	if ready_count > 0:
		set_progress_state("farm", "claimable", "%d 块农田可收取" % ready_count)
	elif active_farm_slot_count() > 0:
		set_progress_state("farm", "growing", "%d 块农田生长中" % active_farm_slot_count())
	else:
		clear_progress_state("farm")


func random_known_alchemy_recipe() -> String:
	if known_alchemy_recipes.is_empty():
		return ""
	return str(known_alchemy_recipes[rng.randi_range(0, known_alchemy_recipes.size() - 1)])


func alchemy_max_craft_count(recipe_id: String) -> int:
	if recipe_id.is_empty():
		return 0

	var materials: Array = DataTables.alchemy_recipe_materials(recipe_id)
	if materials.is_empty():
		return 0

	var max_count: int = 1 << 30
	for material in materials:
		var item_id: String = material.get("item_id", "")
		var amount: int = int(material.get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			return 0
		max_count = min(max_count, int(floor(float(inventory_item_count(item_id)) / float(amount))))
	return max_count


func craft_alchemy_recipe(recipe_id: String, amount: int) -> bool:
	if recipe_id.is_empty() or amount < 1:
		log_added.emit("炼丹数量无效")
		return false
	if not known_alchemy_recipes.has(recipe_id):
		log_added.emit("尚未学习丹方")
		return false

	var recipe: Dictionary = DataTables.alchemy_recipe_def(recipe_id)
	var result_item_id: String = recipe.get("result_item_id", "")
	var materials: Array = recipe.get("materials", [])
	if result_item_id.is_empty() or materials.is_empty():
		log_added.emit("丹方无效")
		return false
	if alchemy_max_craft_count(recipe_id) < amount:
		log_added.emit("炼丹材料不足")
		return false

	for material in materials:
		var required: int = alchemy_material_cost(str(material.get("item_id", "")), int(material.get("amount", 0)), amount)
		_remove_inventory_count(str(material.get("item_id", "")), required)

	var level: int = building_level(BUILDING_ALCHEMY)
	var result_count: int = amount * (2 if level >= 6 else 1)
	var extra_chance := clampf(0.02 * float(level - 1), 0.0, 0.95)
	for _index in range(amount):
		if rng.randf() < extra_chance:
			result_count += 1
	add_inventory_item(result_item_id, result_count, false)
	add_task_experience(GameDefs.TaskType.ALCHEMY, 5)
	log_added.emit("炼丹完成：%s x%d" % [DataTables.resource_name(result_item_id), result_count])
	changed.emit()
	return true


func alchemy_material_cost(item_id: String, base_amount: int, craft_amount: int) -> int:
	if item_id.is_empty() or base_amount <= 0 or craft_amount <= 0:
		return 0
	return base_amount * craft_amount


func enhance_equipment(instance_id: String) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var current_level := int(item.get("enhance_count", 0))
	var rarity := str(item.get("rarity", "t1"))
	var limit := DataTables.equipment_enhance_limit(rarity)
	if current_level >= limit:
		log_added.emit("%s已达到强化上限 +%d" % [item.get("name", "装备"), limit])
		return false
	var next_level := current_level + 1
	var cost := DataTables.equipment_enhance_cost(rarity, next_level)
	var stone: Dictionary = _random_enhance_stone(item)
	if stone.is_empty():
		log_added.emit("装备没有可强化的基础属性")
		return false
	if not spend_resource(stone["item_id"], cost):
		log_added.emit("%s不足，强化需要 %d 个" % [DataTables.resource_name(str(stone["item_id"])), cost])
		return false
	var enhanced_attributes: Array = item.get("enhanced_attributes", [])
	enhanced_attributes.append({
		"stat": stone["stat"],
		"amount": 1,
		"quality": stone["quality"],
	})
	item["enhanced_attributes"] = enhanced_attributes
	item["enhance_count"] = next_level
	item["enhance_level"] = item["enhance_count"]
	_update_equipment_compat_bonuses(item)
	set_progress_state("forge", "completed", "已强化%s至 +%d" % [item["name"], item["enhance_count"]])
	log_added.emit("强化%s至 +%d" % [item["name"], item["enhance_count"]])
	return true


func add_equipment_affix(instance_id: String) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var cost: int = int(item.get("refine_count", 0)) + 1
	if not spend_resource("refine_talisman", cost):
		log_added.emit("洗练符不足")
		return false
	item["base_attributes"] = DataTables.generate_equipment_base_attributes(str(item.get("rarity", "t1")), rng)
	item["refine_affixes"] = []
	_reroll_enhanced_attributes(item)
	item["refine_count"] = int(item.get("refine_count", 0)) + 1
	_update_equipment_compat_bonuses(item)
	set_progress_state("forge", "completed", "已洗练%s的随机属性" % item["name"])
	log_added.emit("洗练%s，强化等级保持 +%d" % [item["name"], int(item.get("enhance_count", 0))])
	return true


func _equipped_items() -> Array:
	var member: Dictionary = member_by_id(default_party_member_id())
	return _equipped_items_for_member(member) if not member.is_empty() else []


func _stat_bonus(stat_id: String) -> int:
	var value: int = 0
	for buff in active_buffs:
		if buff.get("stat", "") == stat_id:
			value += int(buff.get("amount", 0))
	for item in _equipped_items():
		value += _item_affix_bonus(item, stat_id)
	return value


func _item_affix_bonus(item: Dictionary, stat_id: String) -> int:
	var value: int = 0
	for affix in item.get("affixes", []):
		if affix.get("stat", "") == stat_id:
			value += int(affix.get("amount", 0))
	return value


func _equipment_attribute_bonus(stat_id: String) -> int:
	var value: int = 0
	for item in _equipped_items():
		value += _item_equipment_attribute_value(item, stat_id)
	return value


func _total_requirement_stat_excluding_slot(stat_id: String, excluded_slot: String) -> int:
	var member: Dictionary = member_by_id(default_party_member_id())
	if member.is_empty():
		return 0
	return _total_requirement_stat_excluding_slot_for(member, stat_id, excluded_slot)


func _equipment_attribute_bonus_excluding_slot(stat_id: String, excluded_slot: String) -> int:
	var member: Dictionary = member_by_id(default_party_member_id())
	return _equipment_attribute_bonus_excluding_slot_for(member, stat_id, excluded_slot) if not member.is_empty() else 0


func _item_equipment_attribute_value(item: Dictionary, stat_id: String) -> int:
	var flat_value: int = 0
	for attribute in item.get("base_attributes", []):
		if attribute.get("stat", "") == stat_id:
			flat_value += int(attribute.get("amount", 0))
	for attribute in item.get("enhanced_attributes", []):
		if attribute.get("stat", "") == stat_id:
			flat_value += int(attribute.get("amount", 0))
	if flat_value == 0:
		return 0
	return flat_value


func _random_enhance_stone(item: Dictionary) -> Dictionary:
	var base_stats: Array = []
	for attribute in item.get("base_attributes", []):
		var stat_id: String = attribute.get("stat", "")
		if not stat_id.is_empty() and not base_stats.has(stat_id):
			base_stats.append(stat_id)
	var candidates: Array = []
	for stat_id in base_stats:
		var item_id: String = DataTables.enhance_stone_item_id(stat_id)
		if not item_id.is_empty():
			candidates.append({"item_id": item_id, "stat": stat_id, "quality": "base"})
	if not candidates.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	return {}


func _reroll_enhanced_attributes(item: Dictionary) -> void:
	var base_stats: Array[String] = []
	for attribute in item.get("base_attributes", []):
		var stat_id := str(attribute.get("stat", ""))
		if not stat_id.is_empty() and not base_stats.has(stat_id):
			base_stats.append(stat_id)
	var enhanced_attributes: Array = []
	for _index in range(int(item.get("enhance_count", 0))):
		if base_stats.is_empty():
			break
		enhanced_attributes.append({
			"stat": base_stats[rng.randi_range(0, base_stats.size() - 1)],
			"amount": 1,
			"quality": "base",
		})
	item["enhanced_attributes"] = enhanced_attributes


func _update_equipment_compat_bonuses(item: Dictionary) -> void:
	item["attack_bonus"] = _item_equipment_attribute_value(item, "attack")
	item["defense_bonus"] = _item_equipment_attribute_value(item, "defense")
	item["enhance_attack_bonus"] = _sum_enhanced_attribute(item, "attack")
	item["enhance_defense_bonus"] = _sum_enhanced_attribute(item, "defense")


func _sum_enhanced_attribute(item: Dictionary, stat_id: String) -> int:
	var value: int = 0
	for attribute in item.get("enhanced_attributes", []):
		if attribute.get("stat", "") == stat_id:
			value += int(attribute.get("amount", 0))
	return value


func _update_farm_level() -> void:
	pass


func _grant_auto_level_points_for_member(member: Dictionary) -> void:
	party_service.grant_auto_level_points_for_member(member)


func try_breakthrough() -> bool:
	return _try_breakthrough_for_member(member_by_id(default_party_member_id()))


func _ensure_level_cap_open() -> bool:
	return _ensure_level_cap_open_for_member(member_by_id(default_party_member_id()))


func _unlock_next_stage() -> void:
	_unlock_next_stage_for_member(member_by_id(default_party_member_id()))


func _level_up() -> void:
	_level_up_member(member_by_id(default_party_member_id()))


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
		return str(DataTables.element_name(DataTables.element_id_from_attribute(stat_id)))
	return str(DataTables.attribute_display_name(stat_id))


func _attribute_gains_text(gains: Dictionary) -> String:
	if gains.is_empty():
		return "无"
	var parts: Array = []
	for stat_id in RANDOM_POINT_TARGETS:
		if not gains.has(stat_id):
			continue
		parts.append("%s+%d" % [_attribute_log_name(str(stat_id)), int(gains.get(stat_id, 0))])
	return "、".join(parts)
