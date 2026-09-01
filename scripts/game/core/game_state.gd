class_name GameState
extends RefCounted

const MarketServiceScript = preload("res://scripts/game/core/market_service.gd")

signal changed
signal log_added(message: String)

const FARM_SLOT_COUNT = 5
const FARM_STATUS_EMPTY = "empty"
const FARM_STATUS_GROWING = "growing"
const FARM_STATUS_READY = "ready"
const PARTY_MAX_SIZE = 4
const ROSTER_MAX_SIZE = 8
const MAX_MEMBER_SKILL_SLOTS := 4
const RECRUIT_RESOURCE_ID = "spirit_stone"
const RECRUIT_COST_SPIRIT_STONE = 1
const TEST_INVENTORY_ITEM_MIN_COUNT = 1
const TEST_INVENTORY_SETTING := "game/development/seed_test_inventory"
const LEVEL_ATTRIBUTE_POINTS = 5
const SAVE_SCHEMA_VERSION = 23
const BUILDING_RECRUIT = "recruit"
const BUILDING_FORGE = "forge"
const BUILDING_ALCHEMY = "alchemy"
const BUILDING_FARM = "farm"
const PRODUCTION_BUILDING_IDS = [BUILDING_FARM, BUILDING_FORGE, BUILDING_ALCHEMY]
const REMOVED_PRODUCTION_TRAIT_IDS = ["craft_hand", "craft_touch", "pill_heart", "pill_sense", "field_sense"]
const RECRUIT_NAME_PARTS = ["青岚", "赤霄", "玄石", "白羽", "沧流", "云舟", "明河", "素问", "照夜", "归尘"]
const RANDOM_POINT_TARGETS = ["attack", "defense", "root_bone", "max_hp", "max_mp", "element_wood", "element_fire", "element_earth", "element_metal", "element_water"]
const SCHEMA_19_CORE_WEAPON_IDS := [
	"weapon_metal_sword",
	"weapon_wood_staff",
	"weapon_earth_gauntlet",
	"weapon_water_brush",
	"weapon_fire_orb",
]
const SCHEMA_19_WEAPON_ENHANCEMENT_TARGETS := {
	"weapon_wood_staff": "max_hp",
	"weapon_earth_gauntlet": "defense",
	"weapon_water_brush": "max_mp",
}

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
var market_service
var companions: Array = []
var party_order: Array = []
var reserve_order: Array = []
var recruit_candidates: Array = []
var party_service: PartyService
var active_item_buffs: Array = []
var auto_use_item_ids: Array[String] = ["", "", "", ""]
var farm_slots: Array = []
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
var reward_progress: Dictionary = {
	"valid_victories": 0,
	"manual_fragment_progress": 0,
	"blueprint_pity": 0,
	"unlocked_blueprints": [],
}
var permanent_building_bonuses: Dictionary = {
	"farm": {"output_quality": 0},
	"forge": {"output_quality": 0},
	"alchemy": {"output_quality": 0},
}
var market_state: Dictionary = {
	"next_free_refresh_unix": 0,
	"paid_refresh_count": 0,
	"market_rng_state": {},
	"offers": [],
	"commissions": [],
}
func _init() -> void:
	inventory_service = InventoryService.new(self)
	market_service = MarketServiceScript.new(self)
	party_service = PartyService.new(self)
	rng.randomize()
	_ensure_building_state()
	_ensure_reward_progress()
	_ensure_account_progression()
	_ensure_permanent_building_bonuses()
	_ensure_farm_slots()
	_ensure_party_state()
	add_inventory_item(RECRUIT_RESOURCE_ID, 1, false)
	add_inventory_item("herb", 1, false)
	_grant_missing_starter_skill_books()
	_seed_test_inventory_if_enabled()
	generate_recruit_candidates(false)
	market_service.ensure_state()


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
		"companions": _companions_save_data(),
		"party_order": party_order.duplicate(),
		"reserve_order": reserve_order.duplicate(),
		"recruit_candidates": recruit_candidates.duplicate(true),
		"active_item_buffs": active_item_buffs.duplicate(true),
		"auto_use_item_ids": auto_use_item_ids.duplicate(),
		"farm_slots": farm_slots.duplicate(true),
		"progress_states": progress_states.duplicate(true),
		"building_levels": building_levels.duplicate(true),
		"reward_progress": reward_progress.duplicate(true),
		"permanent_building_bonuses": permanent_building_bonuses.duplicate(true),
		"market_state": market_state.duplicate(true),
	}
	return result


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	var loaded_schema_version: int = int(data.get("schema_version", 1))
	var legacy_production_jobs: Dictionary = data.get("production_jobs", {}).duplicate(true) if data.get("production_jobs", {}) is Dictionary else {}
	_load_rng_state(data.get("rng", {}))
	if data.has("account_progression"):
		_load_dictionary_values(account_progression, data.get("account_progression", {}))
	selected_expedition_map_id = str(data.get("selected_expedition_map_id", selected_expedition_map_id))
	if selected_expedition_map_id.is_empty():
		selected_expedition_map_id = "verdant_forest"
	_load_dictionary_values(task_exp, data.get("task_exp", {}))
	if data.has("inventory"):
		inventory = _duplicate_array(data.get("inventory", []))
	if loaded_schema_version < 18:
		_migrate_schema_18_equipment_inventory()
	if loaded_schema_version < 19:
		_migrate_schema_19_equipment_enhancements()
	if loaded_schema_version < 20:
		_migrate_schema_20_equipment_templates()
	if loaded_schema_version < 21:
		_migrate_schema_21_equipment_values()
	if data.has("market_state") and data.get("market_state") is Dictionary:
		market_state = data.get("market_state", {}).duplicate(true)
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
	if data.has("active_item_buffs"):
		active_item_buffs = _duplicate_array(data.get("active_item_buffs", []))
	if data.has("auto_use_item_ids"):
		set_auto_use_item_ids(data.get("auto_use_item_ids", []), false)
	if data.has("farm_slots"):
		farm_slots.assign(_duplicate_array(data.get("farm_slots", [])))
	if loaded_schema_version < 22:
		_migrate_schema_22_item_buffs(data)
	if data.has("building_levels"):
		_load_dictionary_values(building_levels, data.get("building_levels", {}))
	if data.has("reward_progress"):
		_load_dictionary_values(reward_progress, data.get("reward_progress", {}))
	_ensure_reward_progress()
	if loaded_schema_version < 18:
		reward_progress["blueprint_pity"] = 0
		reward_progress["unlocked_blueprints"] = []
	if data.has("permanent_building_bonuses"):
		_load_dictionary_values(permanent_building_bonuses, data.get("permanent_building_bonuses", {}))
	_ensure_building_state()
	if loaded_schema_version < 23:
		_migrate_schema_23_alchemy(data)
	if loaded_schema_version < 5:
		account_progression = {
			"expedition_level": 1,
			"expedition_exp": maxi(0, int(task_exp.get("fight", 0))),
			"next_expedition_exp": 40,
		}
	_ensure_account_progression()
	_ensure_permanent_building_bonuses()
	_ensure_farm_slots()
	_resolve_member_skill_references()
	_filter_unknown_content()
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
	_sanitize_active_item_buffs()
	_ensure_party_state()
	if loaded_schema_version < 17:
		_migrate_schema_17_affinity_growth()
	if loaded_schema_version < 3 and party_member_count() <= 0 and recruit_stone_count() <= 0:
		add_inventory_item(RECRUIT_RESOURCE_ID, 1, false)
	_ensure_recruit_candidate_growth()
	if loaded_schema_version < 14:
		_migrate_schema_14_progression()
	_migrate_free_points_to_auto_growth()
	if recruit_candidates.is_empty():
		generate_recruit_candidates(false)
	_load_progress_states(data.get("progress_states", {}))
	clear_progress_state(BUILDING_FORGE)
	clear_progress_state(BUILDING_ALCHEMY)
	_clamp_runtime_stats()
	_refresh_farm_progress_state()
	market_service.ensure_state()
	# Current and Schema 21 saves must not advance gameplay RNG during deterministic load cleanup.
	if loaded_schema_version >= 21:
		_load_rng_state(data.get("rng", {}))
	changed.emit()


func _inventory_content_available(item: Dictionary) -> bool:
	var item_id := str(item.get("item_id", ""))
	if str(item.get("type", "")) == DataTables.ITEM_TYPE_EQUIPMENT:
		return DataTables.content_has("equipment", item_id, DataTables.EQUIPMENT_DEFS)
	return DataTables.content_has("item", item_id, DataTables.ITEM_DEFS)


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


func _filter_unknown_content() -> void:
	var kept_inventory: Array = []
	for item in inventory:
		if item is Dictionary and _inventory_content_available(item):
			kept_inventory.append(item)
	inventory = kept_inventory
	for collection in [companions, recruit_candidates]:
		for member in collection:
			if not (member is Dictionary):
				continue
			var kept_traits: Array = []
			for value in member.get("innate_traits", []):
				var content_id := str(value.get("id", "")) if value is Dictionary else str(value)
				if DataTables.content_has("trait", content_id):
					kept_traits.append(value)
			member["innate_traits"] = kept_traits


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
	for collection in [companions, recruit_candidates]:
		for member in collection:
			if not (member is Dictionary):
				continue
			var resolved: Array = []
			for value in member.get("skills", []):
				var skill_reference := _skill_reference(value)
				var skill_id := str(skill_reference.get("id", ""))
				if skill_id.is_empty():
					continue
				if not DataTables.content_has("skill", skill_id, DataTables.SKILL_DEFS):
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


func building_level_cap() -> int:
	return mini(10, 1 + floori(float(expedition_level() - 1) / 5.0))


func building_level_requirement(level: int) -> int:
	return 1 + maxi(0, level - 1) * 5


func next_building_level_requirement(building_id: String) -> int:
	var next_level: int = building_level(building_id) + 1
	if next_level > DataTables.building_max_level(building_id):
		return 0
	return building_level_requirement(next_level)


func building_upgrade_cost(building_id: String) -> Dictionary:
	var level: int = building_level(building_id)
	if level >= DataTables.building_max_level(building_id) or level >= building_level_cap():
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
	if current_level >= building_level_cap():
		log_added.emit("%s升级至 %d 级需要历练等级 %d" % [DataTables.building_name(building_id), current_level + 1, next_building_level_requirement(building_id)])
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
	item["name"] = str(definition.get("name", item_id))
	item["description"] = str(definition.get("description", ""))
	item["type"] = str(definition.get("type", ""))
	item["stackable"] = bool(definition.get("stackable", true))
	item["usable"] = bool(definition.get("usable", false))
	item["use_context"] = str(definition.get("use_context", definition.get("use_scope", "none")))
	item["gain_target"] = str(definition.get("gain_target", "none"))
	item["effects"] = definition.get("effects", []).duplicate(true)
	item["combat_cooldown_turns"] = int(definition.get("combat_cooldown_turns", 0))
	item["shared_cooldown_group"] = str(definition.get("shared_cooldown_group", ""))
	item["ai_action_type"] = str(definition.get("ai_action_type", ""))
	item["combat_target_mode"] = str(definition.get("combat_target_mode", DataTables.ITEM_COMBAT_TARGET_SINGLE))
	item["payload"] = definition.get("payload", {}).duplicate(true)
	item["obtain_source"] = str(item.get("obtain_source", "non_drop"))
	item["item_no"] = DataTables.item_no(item_id)
	item["icon_name"] = DataTables.item_icon_name(item_id)
	item["icon_path"] = DataTables.item_icon_path(item_id)
	item["resource_path"] = DataTables.item_resource_path(item_id)


func _sanitize_loaded_equipment(item: Dictionary) -> void:
	var item_id: String = str(item.get("item_id", ""))
	if DataTables.LEGACY_EQUIPMENT_VARIANT_ALIASES.has(item_id):
		_migrate_schema_20_equipment_item(item)
		item_id = str(item.get("item_id", item_id))
	item["item_id"] = item_id
	item["stackable"] = false
	item["usable"] = bool(item.get("usable", true))
	var definition: Dictionary = DataTables.content_definition("equipment", item_id, DataTables.EQUIPMENT_DEFS.get(item_id, {}))
	item["slot"] = str(definition.get("slot", item.get("slot", "weapon")))
	item["rarity"] = str(item.get("rarity", "t1"))
	item["equipment_level"] = maxi(1, int(item.get("equipment_level", 1)))
	item["equip_requirement"] = {}
	var variants := DataTables.equipment_attribute_variants(item_id)
	var variant_id := str(item.get("equipment_variant_id", ""))
	if not variants.is_empty() and not variants.has(variant_id):
		var variant_ids: Array = variants.keys()
		variant_ids.sort()
		variant_id = str(variant_ids[0])
	item["equipment_variant_id"] = variant_id
	var variant := DataTables.equipment_variant_definition(item_id, variant_id)
	var base_name := str(item.get("equipment_base_name", variant.get("name", definition.get("name", item_id))))
	item["equipment_base_name"] = base_name
	item["icon_name"] = str(item.get("icon_name", DataTables.equipment_icon_name(item_id, variant_id)))
	item["icon_path"] = str(item.get("icon_path", DataTables.equipment_icon_path(item_id, variant_id)))
	item["resource_path"] = DataTables.equipment_resource_path(item_id, variant_id)
	var rolled_attribute_stats: Array = item.get("rolled_attribute_stats", []).duplicate() if item.get("rolled_attribute_stats", []) is Array else []
	item["rolled_attribute_stats"] = rolled_attribute_stats
	if not _valid_equipment_base_attributes(item.get("base_attributes", [])):
		item["base_attributes"] = DataTables.build_equipment_base_attributes(item_id, str(item["rarity"]), variant_id, rolled_attribute_stats)
	item["attribute_generation_version"] = DataTables.EQUIPMENT_ATTRIBUTE_GENERATION_VERSION
	item["description_effects"] = _duplicate_array(item.get("description_effects", DataTables.equipment_template_description_effects(item_id, variant_id)))
	var allocations: Dictionary = item.get("enhancement_allocations", {}) if item.get("enhancement_allocations", {}) is Dictionary else {}
	if allocations.is_empty() and int(item.get("enhance_count", 0)) > 0 and not item["base_attributes"].is_empty():
		allocations[str(item["base_attributes"][0].get("stat", "attack"))] = int(item.get("enhance_count", 0))
	item["enhancement_allocations"] = allocations
	_sync_enhanced_attributes(item)
	item["refine_affixes"] = _duplicate_array(item.get("refine_affixes", []))
	var affixes := _duplicate_array(item.get("affixes", []))
	var affix_limit := DataTables.equipment_affix_count(str(item["rarity"]), item_id, variant_id)
	if affixes.is_empty():
		affixes = DataTables.generate_stable_equipment_affixes(str(item["rarity"]), str(item.get("instance_id", item_id)), item_id, variant_id)
	if affixes.size() > affix_limit:
		affixes.resize(affix_limit)
	item["affixes"] = affixes
	item["enhance_count"] = maxi(0, int(item.get("enhance_count", 0)))
	item["refine_count"] = maxi(0, int(item.get("refine_count", 0)))
	item["equipped"] = bool(item.get("equipped", false))
	item["equipped_by"] = str(item.get("equipped_by", ""))
	if str(item.get("equipped_by", "")) == "player":
		item["equipped"] = false
		item["equipped_by"] = ""
		item.erase("equipped_slot")
	_update_equipment_compat_bonuses(item)
	var rarity_name := DataTables.equipment_rarity_name(str(item["rarity"]))
	item["name"] = "%s·%s" % [rarity_name, base_name]
	item["description"] = "%s等级装备" % rarity_name


func _valid_equipment_base_attributes(value) -> bool:
	if not (value is Array) or value.is_empty():
		return false
	var seen: Dictionary = {}
	for raw_attribute in value:
		if not (raw_attribute is Dictionary):
			return false
		var stat_id := str(raw_attribute.get("stat", ""))
		if stat_id.is_empty() or seen.has(stat_id) or int(raw_attribute.get("amount", 0)) < 0:
			return false
		seen[stat_id] = true
	return true


func _migrate_schema_18_equipment_inventory() -> void:
	var blueprint_compensation := 0
	var kept: Array = []
	for raw_item in inventory:
		if not (raw_item is Dictionary):
			kept.append(raw_item)
			continue
		var item: Dictionary = raw_item
		var item_id := str(item.get("item_id", ""))
		if item_id.begins_with("blueprint_"):
			blueprint_compensation += maxi(1, int(item.get("count", 1))) * 4
			continue
		if item_id == "weapon":
			item["item_id"] = "weapon_metal_sword"
		elif item_id == "accessory":
			item["item_id"] = "accessory_wood"
		kept.append(item)
	inventory = kept
	if blueprint_compensation > 0:
		add_inventory_item(DataTables.ITEM_ID_ORE, blueprint_compensation, false)
		reward_progress["blueprint_pity"] = 0
		reward_progress["unlocked_blueprints"] = []
		log_added.emit("旧装备图纸已移除，补偿矿石 x%d" % blueprint_compensation)


func _migrate_schema_19_equipment_enhancements() -> void:
	for raw_item in inventory:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var item_id := str(item.get("item_id", ""))
		if not SCHEMA_19_CORE_WEAPON_IDS.has(item_id):
			continue
		var allocations: Dictionary = item.get("enhancement_allocations", {}).duplicate(true) if item.get("enhancement_allocations", {}) is Dictionary else {}
		if allocations.is_empty() and int(item.get("enhance_count", 0)) > 0:
			allocations["attack"] = maxi(0, int(item.get("enhance_count", 0)))
		var attack_points := maxi(0, int(allocations.get("attack", 0)))
		if SCHEMA_19_WEAPON_ENHANCEMENT_TARGETS.has(item_id):
			var target_stat := str(SCHEMA_19_WEAPON_ENHANCEMENT_TARGETS[item_id])
			if attack_points > 0:
				allocations[target_stat] = maxi(0, int(allocations.get(target_stat, 0))) + attack_points
			allocations.erase("attack")
		item["enhancement_allocations"] = allocations


func _migrate_schema_20_equipment_templates() -> void:
	for raw_item in inventory:
		if raw_item is Dictionary:
			_migrate_schema_20_equipment_item(raw_item)


func _migrate_schema_20_equipment_item(item: Dictionary) -> void:
	if str(item.get("type", "")) != DataTables.ITEM_TYPE_EQUIPMENT:
		return
	var old_id := str(item.get("item_id", ""))
	if not DataTables.LEGACY_EQUIPMENT_VARIANT_ALIASES.has(old_id):
		if DataTables.EQUIPMENT_DEFS.has(old_id) and not item.has("rolled_attribute_stats"):
			item["rolled_attribute_stats"] = []
		return
	var alias: Dictionary = DataTables.LEGACY_EQUIPMENT_VARIANT_ALIASES[old_id]
	var template_id := str(alias.get("template_id", old_id))
	var variant_id := str(alias.get("variant_id", ""))
	var rarity := str(item.get("rarity", "t1"))
	if not _valid_equipment_base_attributes(item.get("base_attributes", [])):
		item["base_attributes"] = DataTables.equipment_tier_base_attributes(template_id, rarity, variant_id)
	var variant := DataTables.equipment_variant_definition(template_id, variant_id)
	item["item_id"] = template_id
	item["equipment_variant_id"] = variant_id
	item["equipment_base_name"] = str(variant.get("name", item.get("equipment_base_name", old_id)))
	item["icon_name"] = str(variant.get("icon_name", item.get("icon_name", DataTables.equipment_icon_name(template_id))))
	item["icon_path"] = str(variant.get("icon_path", item.get("icon_path", DataTables.equipment_icon_path(template_id))))
	item["resource_path"] = DataTables.equipment_resource_path(template_id)
	item["rolled_attribute_stats"] = []
	item["attribute_generation_version"] = 3


func _migrate_schema_21_equipment_values() -> void:
	for raw_item in inventory:
		if raw_item is Dictionary:
			_migrate_schema_21_equipment_item(raw_item)


func _migrate_schema_21_equipment_item(item: Dictionary) -> void:
	if str(item.get("type", "")) != DataTables.ITEM_TYPE_EQUIPMENT:
		return
	var existing_rolls: Array = item.get("rolled_attribute_stats", []).duplicate() if item.get("rolled_attribute_stats", []) is Array else []
	if DataTables.LEGACY_EQUIPMENT_VARIANT_ALIASES.has(str(item.get("item_id", ""))):
		_migrate_schema_20_equipment_item(item)
		if not existing_rolls.is_empty():
			item["rolled_attribute_stats"] = existing_rolls
	var template_id := str(item.get("item_id", ""))
	if not DataTables.EQUIPMENT_DEFS.has(template_id):
		return
	var rarity := str(item.get("rarity", "t1"))
	var variants := DataTables.equipment_attribute_variants(template_id)
	var variant_id := str(item.get("equipment_variant_id", ""))
	if not variants.is_empty() and not variants.has(variant_id):
		var variant_ids: Array = variants.keys()
		variant_ids.sort()
		variant_id = str(variant_ids[0])
	item["equipment_variant_id"] = variant_id
	var fixed_attributes := DataTables.equipment_tier_base_attributes(template_id, rarity, variant_id)
	var excluded_stats: Dictionary = {}
	for attribute in fixed_attributes:
		if attribute is Dictionary:
			excluded_stats[str(attribute.get("stat", ""))] = true
	var random_pool := DataTables.equipment_random_attribute_pool(template_id, variant_id)
	var target_count := DataTables.equipment_random_attribute_count(template_id, rarity, variant_id)
	var rolled_stats: Array[String] = []
	var raw_rolls = item.get("rolled_attribute_stats", [])
	if raw_rolls is Array:
		for raw_stat in raw_rolls:
			var stat_id := str(raw_stat)
			if rolled_stats.size() >= target_count:
				break
			if random_pool.has(stat_id) and not excluded_stats.has(stat_id) and not rolled_stats.has(stat_id):
				rolled_stats.append(stat_id)
	item["rolled_attribute_stats"] = rolled_stats
	item["base_attributes"] = DataTables.build_equipment_base_attributes(template_id, rarity, variant_id, rolled_stats)
	item["attribute_generation_version"] = DataTables.EQUIPMENT_ATTRIBUTE_GENERATION_VERSION


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


func _migrate_schema_22_item_buffs(data: Dictionary) -> void:
	active_item_buffs.clear()
	for raw_buff in data.get("active_buffs", []):
		if not (raw_buff is Dictionary):
			continue
		var old: Dictionary = raw_buff
		active_item_buffs.append({
			"buff_id": "%s_member" % str(old.get("item_id", "legacy")),
			"source_item_id": str(old.get("item_id", "")),
			"target": "member",
			"member_id": str(old.get("member_id", "")),
			"stat": str(old.get("stat", "")),
			"operation": "flat",
			"value": float(old.get("amount", 0.0)),
			"stacks": 1,
			"remaining_seconds": float(old.get("remaining_seconds", old.get("remaining", 0.0))),
		})
	for raw_buff in data.get("farm_speed_buffs", []):
		if not (raw_buff is Dictionary):
			continue
		var old: Dictionary = raw_buff
		active_item_buffs.append({
			"buff_id": "farm_speed",
			"source_item_id": str(old.get("item_id", "farm_speed_talisman")),
			"target": "home_global",
			"member_id": "",
			"stat": "farm_speed",
			"operation": "percent",
			"value": max(0.0, float(old.get("multiplier", 1.0)) - 1.0),
			"stacks": 1,
			"remaining_seconds": float(old.get("remaining_seconds", 0.0)),
		})
	auto_use_item_ids.assign(["", "", "", ""])


func _sanitize_active_item_buffs() -> void:
	for index in range(active_item_buffs.size() - 1, -1, -1):
		if not (active_item_buffs[index] is Dictionary):
			active_item_buffs.remove_at(index)
			continue
		var buff: Dictionary = active_item_buffs[index]
		buff["buff_id"] = str(buff.get("buff_id", ""))
		buff["source_item_id"] = str(buff.get("source_item_id", buff.get("item_id", "")))
		buff["target"] = str(buff.get("target", "member"))
		buff["member_id"] = str(buff.get("member_id", ""))
		buff["stat"] = str(buff.get("stat", ""))
		buff["operation"] = str(buff.get("operation", "flat"))
		buff["value"] = float(buff.get("value", buff.get("amount", 0.0)))
		buff["stacks"] = maxi(1, int(buff.get("stacks", 1)))
		buff["remaining_seconds"] = float(buff.get("remaining_seconds", buff.get("remaining", 0.0)))
		var invalid_member := str(buff["target"]) == "member" and member_by_id(str(buff["member_id"])).is_empty()
		if str(buff["buff_id"]).is_empty() or str(buff["stat"]).is_empty() or (float(buff["remaining_seconds"]) <= 0.0 and float(buff["remaining_seconds"]) != -1.0) or invalid_member:
			active_item_buffs.remove_at(index)
			continue
		active_item_buffs[index] = buff


func set_auto_use_item_ids(values, emit_change: bool = true) -> void:
	var normalized: Array[String] = ["", "", "", ""]
	var seen := {}
	if values is Array:
		for index in range(mini(4, values.size())):
			var item_id := str(values[index])
			var definition := DataTables.item_definition(item_id)
			if item_id.is_empty() or seen.has(item_id) or str(definition.get("ai_action_type", "")).is_empty() or not ["combat", "both"].has(str(definition.get("use_context", definition.get("use_scope", "none")))):
				continue
			normalized[index] = item_id
			seen[item_id] = true
	auto_use_item_ids.assign(normalized)
	if emit_change:
		changed.emit()


func set_auto_use_item_slot(slot_index: int, item_id: String) -> bool:
	if slot_index < 0 or slot_index >= 4:
		return false
	var next := auto_use_item_ids.duplicate()
	next[slot_index] = item_id
	set_auto_use_item_ids(next)
	return str(auto_use_item_ids[slot_index]) == item_id


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


func combat_affinity_for(member_id: String) -> String:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return DataTables.COMBAT_AFFINITY_NORMAL
	return DataTables.normalize_combat_affinity(str(member.get("combat_affinity", DataTables.COMBAT_AFFINITY_NORMAL)))


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
	var base_value := float(int(member_stats.get(stat_id, 0)) + _stat_bonus_for_member(member, stat_id) + _equipment_attribute_bonus_for_member(member, stat_id))
	base_value *= 1.0 + _trait_stat_percent_bonus_for_member(member, stat_id)
	return _apply_item_buff_modifiers(base_value, stat_id, "member", str(member.get("id", "")))


func _total_element_for_member(member: Dictionary, element_id: String) -> int:
	var member_elements: Dictionary = member.get("elements", {})
	var stat_id := "element_%s" % element_id
	var base_value := float(int(member_elements.get(element_id, 0)) + _trait_element_flat_bonus_for_member(member, element_id) + _equipment_attribute_bonus_for_member(member, stat_id))
	base_value *= 1.0 + _trait_element_percent_bonus_for_member(member, element_id)
	return _apply_item_buff_modifiers(base_value, stat_id, "member", str(member.get("id", "")))


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
	value += _trait_stat_flat_bonus_for_member(member, stat_id)
	for item in _equipped_items_for_member(member):
		value += _item_affix_bonus(item, stat_id)
	return value


func _apply_item_buff_modifiers(base_value: float, stat_id: String, target: String, member_id: String = "") -> int:
	return _apply_item_buff_modifiers_for_targets(base_value, stat_id, [target], member_id)


func _apply_item_buff_modifiers_for_targets(base_value: float, stat_id: String, targets: Array, member_id: String = "") -> int:
	var flat := 0.0
	var percent := 0.0
	for raw_buff in active_item_buffs:
		if not (raw_buff is Dictionary):
			continue
		var buff: Dictionary = raw_buff
		var buff_target := str(buff.get("target", ""))
		if not targets.has(buff_target) or str(buff.get("stat", "")) != stat_id:
			continue
		if buff_target == "member" and str(buff.get("member_id", "")) != member_id:
			continue
		var amount := float(buff.get("value", 0.0)) * maxi(1, int(buff.get("stacks", 1)))
		if str(buff.get("operation", "flat")) == "percent":
			percent += amount
		else:
			flat += amount
	return maxi(0, roundi((base_value + flat) * (1.0 + percent)))


func combat_total_stat_for(member_id: String, stat_id: String) -> int:
	var member := member_by_id(member_id)
	if member.is_empty():
		return 0
	var member_stats: Dictionary = member.get("stats", {})
	var base_value := float(int(member_stats.get(stat_id, 0)) + _stat_bonus_for_member(member, stat_id) + _equipment_attribute_bonus_for_member(member, stat_id))
	base_value *= 1.0 + _trait_stat_percent_bonus_for_member(member, stat_id)
	var value := _apply_item_buff_modifiers_for_targets(base_value, stat_id, ["member", "combat_global"], member_id)
	if stat_id == "attack":
		var total_element_power := 0
		for element_id in DataTables.ELEMENT_IDS:
			total_element_power += combat_total_element_for(member_id, str(element_id))
		value += int(float(total_element_power) * 0.15)
	return value


func combat_total_element_for(member_id: String, element_id: String) -> int:
	var member := member_by_id(member_id)
	if member.is_empty():
		return 0
	var stat_id := "element_%s" % element_id
	var member_elements: Dictionary = member.get("elements", {})
	var base_value := float(int(member_elements.get(element_id, 0)) + _trait_element_flat_bonus_for_member(member, element_id) + _equipment_attribute_bonus_for_member(member, stat_id))
	base_value *= 1.0 + _trait_element_percent_bonus_for_member(member, element_id)
	return _apply_item_buff_modifiers_for_targets(base_value, stat_id, ["member", "combat_global"], member_id)


func combat_global_modified_value(stat_id: String, base_value: int) -> int:
	return _apply_item_buff_modifiers(float(base_value), stat_id, "combat_global")


func item_buff_active(buff_id: String, target: String, member_id: String = "") -> bool:
	for raw_buff in active_item_buffs:
		if raw_buff is Dictionary and str(raw_buff.get("buff_id", "")) == buff_id and str(raw_buff.get("target", "")) == target and (target != "member" or str(raw_buff.get("member_id", "")) == member_id):
			return true
	return false


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


func craft_equipment_from_template(template_id: String) -> bool:
	if not DataTables.content_has("equipment", template_id, DataTables.EQUIPMENT_DEFS):
		log_added.emit("装备模板不存在")
		return false
	var cost := forge_material_cost()
	if not spend_resource(DataTables.ITEM_ID_ORE, cost):
		log_added.emit("矿石不足，定向打造需要 %d 个矿石" % cost)
		return false
	var output_count: int = 2 if building_level(BUILDING_FORGE) >= 6 else 1
	var names: Array[String] = []
	for _index in range(output_count):
		var rarity: String = DataTables.random_equipment_rarity(rng)
		if rng.randf() < forge_rarity_upgrade_chance():
			rarity = DataTables.upgrade_equipment_rarity(rarity, 1)
		var equipment := DataTables.create_equipment_from_template(template_id, 1, rng, 0, "", rarity, "crafted")
		if equipment.is_empty():
			add_inventory_item(DataTables.ITEM_ID_ORE, cost, false)
			return false
		add_equipment(equipment)
		names.append(str(equipment.get("name", "装备")))
	add_task_experience(GameDefs.TaskType.FORGE, 5)
	log_added.emit("定向打造完成：%s" % "、".join(names))
	changed.emit()
	return true


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
			1,
			rng,
			0,
			"",
			rarity,
			"crafted"
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
	# 保留 task_exp_percent 作为旧存档兼容字段；内置命格不再使用。
	var bonus := 0.0
	for member_id in party_order:
		var member := member_by_id(str(member_id))
		if member.is_empty():
			continue
		bonus += _innate_trait_modifier_for_member(member, "task_exp_percent")
	amount = maxi(1, roundi(float(amount) * (1.0 + bonus)))
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


func market_offers(now_unix: int = -1) -> Array:
	return market_service.offers(now_unix)


func market_commissions(now_unix: int = -1) -> Array:
	return market_service.commissions(now_unix)


func market_seconds_until_refresh(now_unix: int = -1) -> int:
	return market_service.seconds_until_refresh(now_unix)


func market_manual_refresh_cost() -> int:
	return market_service.manual_refresh_cost()


func refresh_market() -> bool:
	return market_service.paid_refresh()


func buy_market_offer(slot_index: int) -> bool:
	return market_service.buy_offer(slot_index)


func complete_market_commission(commission_index: int) -> bool:
	return market_service.complete_commission(commission_index)


func market_recyclable_item_ids() -> Array[String]:
	return market_service.recyclable_item_ids()


func market_recycle_definition(item_id: String) -> Dictionary:
	return market_service.recycle_definition(item_id)


func market_recycle_preview(item_id: String, amount: int) -> int:
	return market_service.recycle_preview(item_id, amount)


func recycle_market_item(item_id: String, amount: int, confirmed_valuable: bool = false) -> bool:
	return market_service.recycle_item(item_id, amount, confirmed_valuable)


func market_validation_errors() -> Array[String]:
	return market_service.validation_errors()


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


func _use_skill_book(item: Dictionary, member_id: String = "", replace_index: int = -1) -> bool:
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
	if member_skills.size() >= MAX_MEMBER_SKILL_SLOTS:
		# Slots full: learn in place only when the caller chose a skill to replace.
		if replace_index < 0 or replace_index >= member_skills.size():
			log_added.emit("技能槽已满，请选择要替换的技能")
			return false
		member_skills[replace_index] = skill
		_remove_inventory_count(item["item_id"], 1)
		log_added.emit("学会%s并替换槽位%d" % [skill["name"], replace_index + 1])
		changed.emit()
		return true
	member_skills.append(skill)
	member["skills"] = member_skills
	_remove_inventory_count(item["item_id"], 1)
	log_added.emit("学会%s" % skill["name"])
	changed.emit()
	return true


func member_skill_slots_full(member_id: String = "") -> bool:
	if member_id.is_empty():
		member_id = default_party_member_id()
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return false
	return member.get("skills", []).size() >= MAX_MEMBER_SKILL_SLOTS


func use_skill_book_replacing(instance_id: String, member_id: String, replace_index: int) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty():
		return false
	return _use_skill_book(item, member_id, replace_index)


func reorder_member_skill(member_id: String, index_a: int, index_b: int) -> bool:
	if member_id.is_empty():
		member_id = default_party_member_id()
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return false
	var member_skills: Array = member.get("skills", [])
	if index_a == index_b:
		return false
	if index_a < 0 or index_a >= member_skills.size():
		return false
	if index_b < 0 or index_b >= member_skills.size():
		return false
	var swapped = member_skills[index_a]
	member_skills[index_a] = member_skills[index_b]
	member_skills[index_b] = swapped
	member["skills"] = member_skills
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


func permanent_attribute_enhance_tier_uses_for(member_id: String, tier_id: String) -> int:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	var uses = member.get("enhance_pill_uses_by_tier", {})
	return maxi(0, int(uses.get(tier_id, 0))) if uses is Dictionary else 0


func permanent_attribute_enhance_item_uses_for(member_id: String, item_id: String) -> int:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return 0
	var uses = member.get("enhance_pill_uses_by_item", {})
	return maxi(0, int(uses.get(item_id, 0))) if uses is Dictionary else 0


func _use_permanent_attribute_item_for_member(item: Dictionary, member_id: String) -> bool:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		log_added.emit("需要先招募角色")
		return false
	var item_id := str(item.get("item_id", ""))
	var enhance_data = item.get("payload", {}).get("permanent_attribute_enhance", {})
	if item_id.is_empty() or not (enhance_data is Dictionary):
		log_added.emit("永久强化道具配置无效")
		return false
	var tier_id := str(enhance_data.get("tier_id", ""))
	var tier_limit := DataTables.permanent_attribute_enhance_tier_limit(tier_id)
	if tier_limit <= 0:
		log_added.emit("永久强化道具阶级无效")
		return false
	var tier_uses := permanent_attribute_enhance_tier_uses_for(member_id, tier_id)
	if tier_uses >= tier_limit:
		log_added.emit("%s强化丹使用次数已达到上限 %d" % [DataTables.permanent_attribute_enhance_tier_name(tier_id), tier_limit])
		return false
	var raw_effects = enhance_data.get("effects", [])
	if not (raw_effects is Array) or raw_effects.is_empty():
		log_added.emit("永久强化道具效果无效")
		return false
	var effects: Array = []
	var seen_stats: Dictionary = {}
	for raw_effect in raw_effects:
		if not (raw_effect is Dictionary):
			log_added.emit("永久强化道具效果无效")
			return false
		var stat_id := str(raw_effect.get("stat", ""))
		var raw_amount = raw_effect.get("amount", 1)
		if not DataTables.PERMANENT_ATTRIBUTE_ENHANCE_STATS.has(stat_id) or seen_stats.has(stat_id):
			log_added.emit("永久强化道具属性无效")
			return false
		if typeof(raw_amount) != TYPE_INT or int(raw_amount) <= 0:
			log_added.emit("永久强化道具数值无效")
			return false
		seen_stats[stat_id] = true
		effects.append({"stat": stat_id, "amount": int(raw_amount)})

	var member_stats: Dictionary = member.get("stats", {})
	var member_elements: Dictionary = member.get("elements", {})
	var gains: Dictionary = {}
	for effect in effects:
		var stat_id := str(effect.get("stat", ""))
		var amount := int(effect.get("amount", 1))
		if stat_id.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
			var element_id := DataTables.element_id_from_attribute(stat_id)
			member_elements[element_id] = int(member_elements.get(element_id, 0)) + amount
		else:
			member_stats[stat_id] = int(member_stats.get(stat_id, 0)) + amount
			if stat_id == "max_hp":
				member_stats["hp"] = mini(_total_stat_for_member(member, "max_hp"), int(member_stats.get("hp", 0)) + amount)
			elif stat_id == "max_mp":
				member_stats["mp"] = mini(_total_stat_for_member(member, "max_mp"), int(member_stats.get("mp", 0)) + amount)
		gains[stat_id] = amount

	var uses_by_tier: Dictionary = member.get("enhance_pill_uses_by_tier", {})
	var uses_by_item: Dictionary = member.get("enhance_pill_uses_by_item", {})
	uses_by_tier[tier_id] = tier_uses + 1
	uses_by_item[item_id] = maxi(0, int(uses_by_item.get(item_id, 0))) + 1
	member["enhance_pill_uses_by_tier"] = uses_by_tier
	member["enhance_pill_uses_by_item"] = uses_by_item
	_remove_inventory_count(item_id, 1)
	log_added.emit("%s使用%s，永久强化%s；%s剩余 %d 次" % [
		member.get("name", "成员"),
		item.get("name", "强化丹"),
		_attribute_gains_text(gains),
		DataTables.permanent_attribute_enhance_tier_name(tier_id),
		tier_limit - tier_uses - 1,
	])
	changed.emit()
	return true


func _use_pill(item: Dictionary) -> bool:
	return _use_pill_for_member(item, default_party_member_id())


func _use_typed_item_for_member(item: Dictionary, member_id: String) -> bool:
	var effects: Array = item.get("effects", [])
	if effects.is_empty():
		return false
	var first_effect: Dictionary = effects[0] if effects[0] is Dictionary else {}
	var first_kind := str(first_effect.get("kind", ""))
	match first_kind:
		"permanent_attribute":
			return _use_permanent_attribute_item_for_member(item, member_id)
		"breakthrough":
			return _use_breakthrough_item(item, member_id)
		"unlock_content":
			var reference_kind := str(first_effect.get("reference_kind", ""))
			if reference_kind == "skill": return _use_skill_book(item, member_id)
			if reference_kind == "equipment_template": return use_equipment_blueprint(item)
		"building_quality":
			return apply_permanent_building_quality(item)
	var member := member_by_id(member_id)
	var hp_amount := 0
	var mp_amount := 0
	var has_restore := false
	var has_modifier := false
	for raw_effect in effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect
		match str(effect.get("kind", "")):
			"restore_resource":
				if member.is_empty(): return false
				has_restore = true
				var stat := str(effect.get("stat", ""))
				var maximum := total_stat_for(member_id, "max_hp" if stat == "hp" else "max_mp")
				var resolved := int(effect.get("amount", 0)) + ceili(float(maximum) * clampf(float(effect.get("ratio", 0.0)), 0.0, 1.0))
				if stat == "hp": hp_amount += resolved
				elif stat == "mp": mp_amount += resolved
			"temporary_modifier":
				has_modifier = _apply_item_modifier_effect(str(item.get("item_id", "")), effect, member_id) or has_modifier
	if has_restore:
		var restored := heal_member(member_id, hp_amount, mp_amount)
		if int(restored.get("hp", 0)) <= 0 and int(restored.get("mp", 0)) <= 0 and not has_modifier:
			log_added.emit("目标当前无法从该道具获益")
			return false
	if not has_restore and not has_modifier:
		return false
	_remove_inventory_count(str(item.get("item_id", "")), 1)
	log_added.emit("使用%s" % str(item.get("name", "道具")))
	changed.emit()
	return true


func use_combat_inventory_item(instance_id: String, current_member_id: String, alive_member_ids: Array[String]) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty() or not [DataTables.ITEM_USE_SCOPE_COMBAT, DataTables.ITEM_USE_SCOPE_BOTH].has(str(item.get("use_context", "none"))):
		return false
	var effects: Array = item.get("effects", [])
	if effects.is_empty():
		return false
	var target_mode := str(item.get("combat_target_mode", DataTables.ITEM_COMBAT_TARGET_SINGLE))
	if not [DataTables.ITEM_COMBAT_TARGET_SINGLE, DataTables.ITEM_COMBAT_TARGET_AOE].has(target_mode):
		return false
	for raw_effect in effects:
		if raw_effect is Dictionary and target_mode == DataTables.ITEM_COMBAT_TARGET_SINGLE and str(raw_effect.get("target", "member")) == "combat_global":
			return false
	var target_ids: Array[String] = [current_member_id]
	if target_mode == DataTables.ITEM_COMBAT_TARGET_AOE:
		target_ids.clear()
		for member_id in alive_member_ids:
			var member := member_by_id(member_id)
			if not member_id.is_empty() and not target_ids.has(member_id) and not member.is_empty() and int(member.get("stats", {}).get("hp", 0)) > 0:
				target_ids.append(member_id)
	else:
		var current_member := member_by_id(current_member_id)
		if current_member.is_empty() or int(current_member.get("stats", {}).get("hp", 0)) <= 0:
			target_ids.clear()
	if target_ids.is_empty():
		return false
	var benefited := false
	for raw_effect in effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect
		match str(effect.get("kind", "")):
			"restore_resource":
				for member_id in target_ids:
					var stat := str(effect.get("stat", ""))
					var maximum := total_stat_for(member_id, "max_hp" if stat == "hp" else "max_mp")
					var amount := int(effect.get("amount", 0)) + ceili(float(maximum) * clampf(float(effect.get("ratio", 0.0)), 0.0, 1.0))
					var restored := heal_member(member_id, amount if stat == "hp" else 0, amount if stat == "mp" else 0)
					benefited = int(restored.get("hp", 0)) > 0 or int(restored.get("mp", 0)) > 0 or benefited
			"temporary_modifier":
				if str(effect.get("target", "member")) == "member":
					for member_id in target_ids:
						benefited = _apply_item_modifier_effect(str(item.get("item_id", "")), effect, member_id) or benefited
				else:
					benefited = _apply_item_modifier_effect(str(item.get("item_id", "")), effect, current_member_id) or benefited
	if not benefited:
		log_added.emit("目标当前无法从该道具获益")
		return false
	_remove_inventory_count(str(item.get("item_id", "")), 1)
	log_added.emit("使用%s（%s）" % [str(item.get("name", "道具")), DataTables.item_combat_target_mode_label(str(item.get("combat_target_mode", "single")))])
	changed.emit()
	return true


func _apply_item_modifier_effect(item_id: String, effect: Dictionary, member_id: String) -> bool:
	var target := str(effect.get("target", "member"))
	if target == "member" and member_by_id(member_id).is_empty():
		return false
	var buff_id := str(effect.get("buff_id", "%s_%s" % [item_id, effect.get("effect_id", "buff")]))
	var duration := -1.0 if str(effect.get("duration_mode", "timed")) == "permanent" else float(effect.get("duration_seconds", 0.0))
	if duration == 0.0:
		return false
	var existing: Dictionary = {}
	for raw_buff in active_item_buffs:
		if raw_buff is Dictionary and str(raw_buff.get("buff_id", "")) == buff_id and str(raw_buff.get("target", "")) == target and (target != "member" or str(raw_buff.get("member_id", "")) == member_id):
			existing = raw_buff
			break
	var next := {
		"buff_id": buff_id,
		"source_item_id": item_id,
		"target": target,
		"member_id": member_id if target == "member" else "",
		"stat": str(effect.get("stat", "")),
		"operation": str(effect.get("operation", "flat")),
		"value": float(effect.get("value", 0.0)),
		"stacks": 1,
		"remaining_seconds": duration,
	}
	if existing.is_empty():
		active_item_buffs.append(next)
		return true
	match str(effect.get("stack_mode", "refresh")):
		"replace": existing.merge(next, true)
		"refresh":
			existing.merge(next, true)
		"extend":
			if float(existing.get("remaining_seconds", -1.0)) >= 0.0: existing["remaining_seconds"] = float(existing.get("remaining_seconds", 0.0)) + maxf(0.0, duration)
		"stack":
			var previous_stacks := maxi(1, int(existing.get("stacks", 1)))
			existing.merge(next, true)
			existing["stacks"] = mini(maxi(1, int(effect.get("max_stacks", 1))), previous_stacks + 1)
	return true


func _use_pill_for_member(item: Dictionary, member_id: String) -> bool:
	if item.get("effects", []) is Array and not item.get("effects", []).is_empty():
		return _use_typed_item_for_member(item, member_id)
	var payload: Dictionary = item.get("payload", {})
	if bool(payload.get("breakthrough", false)):
		return _use_breakthrough_item(item, member_id)
	if payload.get("effect_mode", "instant") == "duration":
		var duration: float = float(payload.get("duration", 0.0))
		_apply_item_modifier_effect(str(item["item_id"]), {
			"effect_id": "legacy_buff", "kind": "temporary_modifier", "target": "member",
			"stat": str(payload.get("stat", "")), "operation": "flat", "value": float(payload.get("amount", 0)),
			"buff_id": "%s_member" % str(item["item_id"]), "duration_mode": "timed", "duration_seconds": duration,
			"stack_mode": "extend", "max_stacks": 1,
		}, member_id)
		_remove_inventory_count(item["item_id"], 1)
		log_added.emit("使用%s，增益生效" % item["name"])
		changed.emit()
		return true

	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		log_added.emit("需要先招募角色")
		return false
	var max_hp: int = _total_stat_for_member(member, "max_hp")
	var max_mp: int = _total_stat_for_member(member, "max_mp")
	var hp_amount: int = int(payload.get("hp", 0)) + ceili(float(max_hp) * clampf(float(payload.get("hp_ratio", 0.0)), 0.0, 1.0))
	var mp_amount: int = int(payload.get("mp", 0)) + ceili(float(max_mp) * clampf(float(payload.get("mp_ratio", 0.0)), 0.0, 1.0))
	var member_stats: Dictionary = member.get("stats", {})
	var old_hp: int = int(member_stats.get("hp", 0))
	var old_mp: int = int(member_stats.get("mp", 0))

	member_stats["hp"] = min(max_hp, old_hp + hp_amount)
	member_stats["mp"] = min(max_mp, old_mp + mp_amount)
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
	if active_item_buffs.is_empty():
		return
	var index: int = 0
	var expired := false
	while index < active_item_buffs.size():
		var buff: Dictionary = active_item_buffs[index]
		if float(buff.get("remaining_seconds", 0.0)) < 0.0:
			index += 1
			continue
		buff["remaining_seconds"] = float(buff.get("remaining_seconds", 0.0)) - delta
		if float(buff["remaining_seconds"]) <= 0.0:
			active_item_buffs.remove_at(index)
			expired = true
		else:
			active_item_buffs[index] = buff
			index += 1
	if expired:
		_clamp_runtime_stats()
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
	for buff in active_item_buffs:
		if str(buff.get("source_item_id", "")) == item_id and str(buff.get("member_id", "")) == member_id:
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
	var item := inventory_service.find_stack_item(item_id)
	return not item.is_empty() and _use_typed_item_for_member(item, default_party_member_id())


func farm_speed_multiplier() -> float:
	var flat := 0.0
	var percent := 0.0
	for buff in active_item_buffs:
		if str(buff.get("target", "")) != "home_global" or str(buff.get("stat", "")) != "farm_speed":
			continue
		var amount := float(buff.get("value", 0.0)) * maxi(1, int(buff.get("stacks", 1)))
		if str(buff.get("operation", "flat")) == "percent": percent += amount
		else: flat += amount
	return maxf(0.0, (1.0 + flat) * (1.0 + percent))


func farm_speed_remaining_seconds() -> float:
	var remaining: float = 0.0
	for buff in active_item_buffs:
		if str(buff.get("target", "")) == "home_global" and str(buff.get("stat", "")) == "farm_speed":
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


func _innate_trait_modifier_for_member(member: Dictionary, kind: String) -> float:
	var value := 0.0
	for effect in _innate_trait_effects_for_member(member):
		if not (effect is Dictionary):
			continue
		if str(effect.get("kind", "")) != kind:
			continue
		value += float(effect.get("amount", effect.get("value", 0.0)))
	return value


func _trait_stat_percent_bonus_for_member(member: Dictionary, stat_id: String) -> float:
	var value := 0.0
	for effect in _innate_trait_effects_for_member(member):
		if not (effect is Dictionary):
			continue
		if str(effect.get("kind", "")) != "stat_percent":
			continue
		if str(effect.get("stat", "")) != stat_id:
			continue
		value += float(effect.get("amount", effect.get("value", 0.0)))
	return value


func _trait_element_percent_bonus_for_member(member: Dictionary, element_id: String) -> float:
	var value := 0.0
	var stat_id := "element_%s" % element_id
	for effect in _innate_trait_effects_for_member(member):
		if not (effect is Dictionary):
			continue
		var kind: String = str(effect.get("kind", ""))
		if kind == "element_percent" and str(effect.get("element", "")) == element_id:
			value += float(effect.get("amount", effect.get("value", 0.0)))
		elif kind == "stat_percent" and str(effect.get("stat", "")) == stat_id:
			value += float(effect.get("amount", effect.get("value", 0.0)))
	return value


func _innate_trait_effects_for_member(member: Dictionary) -> Array:
	var effects: Array = []
	var source = member.get("innate_traits", [])
	if not (source is Array):
		return effects
	for raw_trait in source:
		_append_effects_from_value(effects, DataTables.innate_trait_effects(raw_trait))
	return effects


func innate_trait_effects_of_kind(member_id: String, kind: String) -> Array:
	# 返回成员命格中指定 kind 的原始效果字典，供兼容内容消费。
	var matched: Array = []
	var member := member_by_id(member_id)
	if member.is_empty():
		return matched
	for effect in _innate_trait_effects_for_member(member):
		if effect is Dictionary and str(effect.get("kind", "")) == kind:
			matched.append((effect as Dictionary).duplicate(true))
	return matched


func party_drop_chance_multiplier() -> float:
	# 保留 drop_chance_percent 作为旧存档兼容字段；内置命格不再使用。
	var bonus := 0.0
	for member_id in party_order:
		var member := member_by_id(str(member_id))
		if member.is_empty():
			continue
		bonus += _innate_trait_modifier_for_member(member, "drop_chance_percent")
	return 1.0 + maxf(0.0, bonus)


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


func _refresh_farm_progress_state() -> void:
	var ready_count: int = ready_farm_slot_count()
	if ready_count > 0:
		set_progress_state("farm", "claimable", "%d 块农田可收取" % ready_count)
	elif active_farm_slot_count() > 0:
		set_progress_state("farm", "growing", "%d 块农田生长中" % active_farm_slot_count())
	else:
		clear_progress_state("farm")


func random_unlocked_alchemy_recipe() -> String:
	var recipe_ids: Array[String] = unlocked_alchemy_recipes()
	if recipe_ids.is_empty():
		return ""
	return recipe_ids[rng.randi_range(0, recipe_ids.size() - 1)]


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
	if not unlocked_alchemy_recipes().has(recipe_id):
		log_added.emit("炼丹建筑等级不足")
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
	var allow_output_multiplier: bool = bool(recipe.get("allow_output_multiplier", true))
	var allow_bonus_output: bool = bool(recipe.get("allow_bonus_output", true))
	var result_count: int = amount * (2 if level >= 6 and allow_output_multiplier else 1)
	var extra_chance := clampf(0.02 * float(level - 1), 0.0, 0.95)
	if allow_bonus_output:
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


func enhance_equipment(instance_id: String, stat_id: String = "") -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var current_level := int(item.get("enhance_count", 0))
	var rarity := str(item.get("rarity", "t1"))
	var template_id := str(item.get("item_id", ""))
	var variant_id := str(item.get("equipment_variant_id", ""))
	var limit := DataTables.equipment_enhance_limit(rarity, template_id, variant_id)
	if current_level >= limit:
		log_added.emit("%s已达到强化上限 +%d" % [item.get("name", "装备"), limit])
		return false
	var next_level := current_level + 1
	var costs := DataTables.equipment_enhance_costs(rarity, next_level, template_id, variant_id)
	if costs.is_empty():
		log_added.emit("装备强化配置无效")
		return false
	var allowed_stats: Array[String] = []
	for attribute in item.get("base_attributes", []):
		var base_stat := str(attribute.get("stat", ""))
		if not base_stat.is_empty() and not allowed_stats.has(base_stat):
			allowed_stats.append(base_stat)
	if allowed_stats.is_empty():
		log_added.emit("装备没有可强化的基础属性")
		return false
	if stat_id.is_empty():
		stat_id = allowed_stats[0]
	if not allowed_stats.has(stat_id):
		log_added.emit("该装备不能强化%s" % DataTables.attribute_display_name(stat_id))
		return false
	for cost_item_id in costs:
		if inventory_item_count(str(cost_item_id)) < int(costs[cost_item_id]):
			log_added.emit("%s不足，强化需要 %d 个" % [DataTables.resource_name(str(cost_item_id)), int(costs[cost_item_id])])
			return false
	for cost_item_id in costs:
		spend_resource(str(cost_item_id), int(costs[cost_item_id]))
	var allocations: Dictionary = item.get("enhancement_allocations", {})
	allocations[stat_id] = maxi(0, int(allocations.get(stat_id, 0))) + 1
	item["enhancement_allocations"] = allocations
	item["enhance_count"] = next_level
	item["enhance_level"] = item["enhance_count"]
	_sync_enhanced_attributes(item)
	_update_equipment_compat_bonuses(item)
	set_progress_state("forge", "completed", "已强化%s至 +%d" % [item["name"], item["enhance_count"]])
	log_added.emit("强化%s至 +%d" % [item["name"], item["enhance_count"]])
	changed.emit()
	return true


func add_equipment_affix(instance_id: String) -> bool:
	return refine_equipment_affix(instance_id, 0)


func refine_equipment_affix(instance_id: String, affix_index: int) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty() or item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var affixes: Array = item.get("affixes", [])
	if affix_index < 0 or affix_index >= affixes.size() or affix_index >= 3:
		log_added.emit("请选择有效的词条槽")
		return false
	var cost: int = int(item.get("refine_count", 0)) + 1
	if not spend_resource("refine_talisman", cost):
		log_added.emit("洗练符不足")
		return false
	var old_affix: Dictionary = affixes[affix_index]
	var old_id := str(old_affix.get("id", old_affix.get("type", "")))
	var candidates: Array = DataTables.EQUIPMENT_AFFIX_DEFS.keys()
	candidates.erase(old_id)
	var new_id := str(candidates[rng.randi_range(0, candidates.size() - 1)])
	affixes[affix_index] = {"id": new_id, "value": DataTables.equipment_affix(new_id).get("value", 0)}
	item["affixes"] = affixes
	item["refine_count"] = int(item.get("refine_count", 0)) + 1
	_update_equipment_compat_bonuses(item)
	set_progress_state("forge", "completed", "已洗练%s的第%d条词条" % [item["name"], affix_index + 1])
	log_added.emit("洗练%s：%s" % [item["name"], DataTables.equipment_affix_text(affixes[affix_index])])
	changed.emit()
	return true


func equipment_ascension_cost(instance_id: String) -> Dictionary:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty() or str(item.get("type", "")) != DataTables.ITEM_TYPE_EQUIPMENT:
		return {}
	return DataTables.equipment_ascension_cost(str(item.get("rarity", "t1")), str(item.get("item_id", "")), str(item.get("equipment_variant_id", "")))


func ascend_equipment(instance_id: String) -> bool:
	var item := inventory_item_by_instance(instance_id)
	if item.is_empty() or str(item.get("type", "")) != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	var rarity := str(item.get("rarity", "t1"))
	var template_id := str(item.get("item_id", ""))
	var variant_id := str(item.get("equipment_variant_id", ""))
	var cost := DataTables.equipment_ascension_cost(rarity, template_id, variant_id)
	if cost.is_empty():
		log_added.emit("五阶装备不能继续升阶")
		return false
	for item_id in cost:
		if inventory_item_count(str(item_id)) < int(cost[item_id]):
			log_added.emit("%s不足，升阶需要 %d 个" % [DataTables.resource_name(str(item_id)), int(cost[item_id])])
			return false
	for item_id in cost:
		_remove_inventory_count(str(item_id), int(cost[item_id]))
	var next_rarity := DataTables.upgrade_equipment_rarity(rarity, 1)
	item["rarity"] = next_rarity
	var fixed_attributes := DataTables.equipment_tier_base_attributes(template_id, next_rarity, variant_id)
	var rolled_stats: Array = item.get("rolled_attribute_stats", []).duplicate() if item.get("rolled_attribute_stats", []) is Array else []
	if DataTables.equipment_random_attribute_count(template_id, next_rarity, variant_id) > 0:
		rolled_stats = DataTables.roll_equipment_attribute_stats(template_id, next_rarity, fixed_attributes, rolled_stats, rng, variant_id)
		item["rolled_attribute_stats"] = rolled_stats
		item["base_attributes"] = DataTables.build_equipment_base_attributes(template_id, next_rarity, variant_id, rolled_stats)
	else:
		item["base_attributes"] = fixed_attributes
	var affixes: Array = item.get("affixes", [])
	var target_count := DataTables.equipment_affix_count(next_rarity, template_id, variant_id)
	while affixes.size() < target_count:
		affixes.append(DataTables.generate_equipment_affixes("t1", rng, template_id, variant_id)[0])
	item["affixes"] = affixes
	item["equip_requirement"] = {}
	var rarity_name := DataTables.equipment_rarity_name(next_rarity)
	item["name"] = "%s·%s" % [rarity_name, str(item.get("equipment_base_name", "装备"))]
	item["description"] = "%s等级装备" % rarity_name
	_sync_enhanced_attributes(item)
	_update_equipment_compat_bonuses(item)
	set_progress_state("forge", "completed", "%s已升至%s" % [item["name"], rarity_name])
	log_added.emit("%s升阶成功" % item["name"])
	changed.emit()
	return true


func _equipped_items() -> Array:
	var member: Dictionary = member_by_id(default_party_member_id())
	return _equipped_items_for_member(member) if not member.is_empty() else []


func _stat_bonus(stat_id: String) -> int:
	var value: int = 0
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


func equipment_combat_modifiers_for(member_id: String) -> Dictionary:
	var result := {
		"direct_damage_percent": 0.0,
		"critical_chance": 0.0,
		"critical_multiplier": 1.5,
		"leech_percent": 0.0,
		"defense_ignore": 0,
		"direct_damage_reduction": 0.0,
		"direct_heal_percent": 0.0,
	}
	var member := member_by_id(member_id)
	if member.is_empty():
		return result
	for item in _equipped_items_for_member(member):
		for affix in item.get("affixes", []):
			if not (affix is Dictionary):
				continue
			var affix_id := str(affix.get("id", affix.get("type", "")))
			if not result.has(affix_id):
				continue
			var value = affix.get("value", DataTables.equipment_affix(affix_id).get("value", 0))
			if affix_id == "defense_ignore":
				result[affix_id] = int(result[affix_id]) + int(value)
			else:
				result[affix_id] = float(result[affix_id]) + float(value)
	# 命格战斗修正按出生品质读取，与装备词条同一套上限约束。
	result["direct_damage_percent"] = float(result["direct_damage_percent"]) + _innate_trait_modifier_for_member(member, "direct_damage_percent")
	result["leech_percent"] = float(result["leech_percent"]) + _innate_trait_modifier_for_member(member, "leech_percent")
	result["defense_ignore"] = int(result["defense_ignore"]) + int(_innate_trait_modifier_for_member(member, "defense_ignore"))
	# 命格专属修正：装备词条不存在这些 key，仅作为统一读取出口，不设上限。
	result["weakness_damage_percent"] = _innate_trait_modifier_for_member(member, "weakness_damage_percent")
	result["physical_damage_taken_percent"] = _innate_trait_modifier_for_member(member, "physical_damage_taken_percent")
	result["element_damage_taken_percent"] = _innate_trait_modifier_for_member(member, "element_damage_taken_percent")
	result["skill_cooldown_turns"] = int(_innate_trait_modifier_for_member(member, "skill_cooldown_turns"))
	# 仅兼容旧存档命格；内置命格不再使用百分比冷却。
	result["skill_cooldown_percent"] = _innate_trait_modifier_for_member(member, "skill_cooldown_percent")
	for capped_id in DataTables.EQUIPMENT_COMBAT_MODIFIER_CAPS:
		result[capped_id] = minf(float(result.get(capped_id, 0.0)), DataTables.equipment_combat_modifier_cap(str(capped_id)))
	return result


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


func _sync_enhanced_attributes(item: Dictionary) -> void:
	var allocations: Dictionary = item.get("enhancement_allocations", {}) if item.get("enhancement_allocations", {}) is Dictionary else {}
	var enhanced_attributes: Array = []
	var total := 0
	for stat_id in allocations:
		var points := maxi(0, int(allocations[stat_id]))
		if points <= 0:
			continue
		total += points
		enhanced_attributes.append({
			"stat": str(stat_id),
			"amount": points * DataTables.equipment_attribute_unit_amount(str(stat_id), str(item.get("item_id", "")), str(item.get("equipment_variant_id", ""))),
			"quality": "allocated",
			"points": points,
		})
	item["enhancement_allocations"] = allocations
	item["enhanced_attributes"] = enhanced_attributes
	item["enhance_count"] = total
	item["enhance_level"] = total


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


func unlocked_alchemy_recipes() -> Array[String]:
	var alchemy_level: int = building_level(BUILDING_ALCHEMY)
	var recipe_ids: Array = DataTables.ALCHEMY_RECIPE_DEFS.keys()
	for registered_id in DataTables.content_ids("recipe", DataTables.ALCHEMY_RECIPE_DEFS):
		if not recipe_ids.has(registered_id):
			recipe_ids.append(registered_id)
	var unlocked: Array[String] = []
	for recipe_id in recipe_ids:
		var recipe: Dictionary = DataTables.alchemy_recipe_def(str(recipe_id))
		var unlock_level: int = maxi(1, int(recipe.get("unlock_building_level", 1)))
		if alchemy_level >= unlock_level:
			unlocked.append(str(recipe_id))
	return unlocked


func _migrate_schema_14_progression() -> void:
	for collection in [companions, recruit_candidates]:
		for member in collection:
			if not (member is Dictionary):
				continue
			var stats: Dictionary = member.get("stats", {})
			var level: int = maxi(1, int(stats.get("level", 1)))
			var old_next_exp: int = maxi(1, int(stats.get("next_exp", 40)))
			var old_exp: int = maxi(0, int(stats.get("exp", 0)))
			var new_next_exp: int = party_service.next_exp_for_level(level)
			stats["exp"] = floori(float(old_exp) / float(old_next_exp) * float(new_next_exp))
			stats["next_exp"] = new_next_exp
			stats["stage"] = 1 + floori(float(level - 1) / 10.0)
			stats["level_cap"] = int(stats["stage"]) * 10


func _migrate_schema_17_affinity_growth() -> void:
	for collection in [companions, recruit_candidates]:
		for member in collection:
			if not (member is Dictionary):
				continue
			member["combat_affinity"] = party_service.stable_combat_affinity_for_id(str(member.get("id", member.get("candidate_id", ""))))
			party_service.ensure_member_growth_shape(member)


func _ensure_reward_progress() -> void:
	reward_progress["valid_victories"] = maxi(0, int(reward_progress.get("valid_victories", 0)))
	reward_progress["manual_fragment_progress"] = maxi(0, int(reward_progress.get("manual_fragment_progress", 0)))
	reward_progress["blueprint_pity"] = 0
	reward_progress["unlocked_blueprints"] = []


func unlocked_blueprint_templates() -> Array:
	return DataTables.content_ids("equipment", DataTables.EQUIPMENT_DEFS)


func use_equipment_blueprint(_item: Dictionary) -> bool:
	log_added.emit("装备图纸已退出当前系统")
	return false


func register_full_encounter_victory(eligible: bool = true) -> Dictionary:
	var result := {"eligible": eligible, "blueprint_item_id": ""}
	if not eligible:
		return result
	_ensure_reward_progress()
	reward_progress["valid_victories"] = int(reward_progress.get("valid_victories", 0)) + 1
	reward_progress["manual_fragment_progress"] = int(reward_progress.get("manual_fragment_progress", 0)) + 1
	if int(reward_progress["manual_fragment_progress"]) >= 5:
		reward_progress["manual_fragment_progress"] = int(reward_progress["manual_fragment_progress"]) - 5
		add_inventory_item(DataTables.ITEM_ID_MANUAL_FRAGMENT, 1, false)
		result["manual_fragment_amount"] = 1
		log_added.emit("五次完整清场获得功法残页 x1")
	changed.emit()
	return result


func is_equipment_equipped(instance_id: String) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty():
		return false
	if bool(item.get("equipped", false)) or not str(item.get("equipped_by", "")).is_empty():
		return true
	for member in companions:
		if not (member is Dictionary):
			continue
		for equipped_id in member.get("equipped", {}).values():
			if str(equipped_id) == instance_id:
				return true
	return false


func salvage_equipment(instance_id: String) -> bool:
	var item: Dictionary = inventory_item_by_instance(instance_id)
	if item.is_empty() or str(item.get("type", "")) != DataTables.ITEM_TYPE_EQUIPMENT:
		return false
	if is_equipment_equipped(instance_id):
		log_added.emit("已装备物品不能分解")
		return false
	var tier := DataTables.EQUIPMENT_RARITY_ORDER.find(str(item.get("rarity", "t1"))) + 1
	var stone_amount := maxi(1, tier) + floori(float(int(item.get("enhance_count", 0))) / 2.0)
	for index in range(inventory.size()):
		if str(inventory[index].get("instance_id", "")) == instance_id:
			inventory.remove_at(index)
			add_inventory_item(DataTables.ITEM_ID_ENHANCEMENT_STONE, stone_amount, false)
			log_added.emit("分解%s，获得强化石 x%d" % [str(item.get("name", "装备")), stone_amount])
			changed.emit()
			return true
	return false


func _migrate_schema_23_alchemy(_data: Dictionary) -> void:
	# 丹方改为按炼丹建筑等级直接解锁，known_alchemy_recipes 字段自然丢弃。
	# 残留 recipe_pill（调息丹方图纸）库存按回收价值补偿灵石后移除。
	var legacy_count: int = inventory_item_count(DataTables.ITEM_ID_RECIPE_PILL)
	if legacy_count > 0:
		_remove_inventory_count(DataTables.ITEM_ID_RECIPE_PILL, legacy_count)
		add_inventory_item("spirit_stone", legacy_count * 2, false)
		log_added.emit("丹方已随炼丹建筑等级解锁，回收调息丹方图纸 x%d，补偿灵石 x%d" % [legacy_count, legacy_count * 2])


func exchange_skill_manual(skill_id: String) -> bool:
	var exchange: Dictionary = DataTables.SKILL_EXCHANGE_DEFS.get(skill_id, {})
	if exchange.is_empty():
		return false
	var fragment_cost: int = int(exchange.get("fragment_cost", 3))
	var stone_cost: int = int(exchange.get("stone_cost", 1))
	var stone_id: String = str(exchange.get("element_stone_id", ""))
	if inventory_item_count(DataTables.ITEM_ID_MANUAL_FRAGMENT) < fragment_cost or inventory_item_count(stone_id) < stone_cost:
		log_added.emit("兑换功法需要残页 x%d、%s x%d" % [fragment_cost, DataTables.resource_name(stone_id), stone_cost])
		return false
	_remove_inventory_count(DataTables.ITEM_ID_MANUAL_FRAGMENT, fragment_cost)
	_remove_inventory_count(stone_id, stone_cost)
	var book_item_id: String = str(exchange.get("book_item_id", ""))
	add_inventory_item(book_item_id, 1, false)
	log_added.emit("兑换%s" % DataTables.resource_name(book_item_id))
	changed.emit()
	return true


func convert_spirit_stones(element_id: String) -> bool:
	if building_level(BUILDING_FORGE) < 3:
		log_added.emit("炼器建筑 3 级开放五行灵石转换")
		return false
	var stone_ids := {
		"wood": DataTables.ITEM_ID_SPIRIT_STONE_WOOD,
		"fire": DataTables.ITEM_ID_SPIRIT_STONE_FIRE,
		"earth": DataTables.ITEM_ID_SPIRIT_STONE_EARTH,
		"metal": DataTables.ITEM_ID_SPIRIT_STONE_METAL,
		"water": DataTables.ITEM_ID_SPIRIT_STONE_WATER,
	}
	var result_id: String = str(stone_ids.get(element_id, ""))
	if result_id.is_empty() or inventory_item_count(DataTables.ITEM_ID_SPIRIT_STONE) < 3:
		return false
	_remove_inventory_count(DataTables.ITEM_ID_SPIRIT_STONE, 3)
	add_inventory_item(result_id, 1, false)
	log_added.emit("灵石 x3 转换为%s x1" % DataTables.resource_name(result_id))
	changed.emit()
	return true
