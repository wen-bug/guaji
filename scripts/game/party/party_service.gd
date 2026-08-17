class_name PartyService
extends RefCounted

const PARTY_MAX_SIZE := 4
const ROSTER_MAX_SIZE := 8
const DEFAULT_VISUAL_ID := "actor_default"
const RECRUIT_RESOURCE_ID := "spirit_stone"
const RECRUIT_COST_SPIRIT_STONE := 1
const LEVEL_ATTRIBUTE_POINTS := 5
const RECRUIT_NAME_PARTS := ["青岚", "赤霄", "玄石", "白羽", "沧流", "云舟", "明河", "素问", "照夜", "归尘"]
const RANDOM_POINT_TARGETS := ["attack", "defense", "root_bone", "max_hp", "max_mp", "element_wood", "element_fire", "element_earth", "element_metal", "element_water"]

var game_state


func _init(owner) -> void:
	game_state = owner


func growth_summary_for(member_id: String) -> String:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return ""
	return growth_summary_for_member_data(member)


func party_members() -> Array:
	ensure_party_state()
	var result: Array = []
	for member_id in game_state.party_order:
		var member: Dictionary = member_by_id(str(member_id))
		if not member.is_empty():
			result.append(member)
	return result


func roster_members() -> Array:
	ensure_party_state()
	var result: Array = []
	var ordered_ids: Array = []
	ordered_ids.append_array(game_state.party_order)
	ordered_ids.append_array(game_state.reserve_order)
	for member_id in ordered_ids:
		var member: Dictionary = member_by_id(str(member_id))
		if not member.is_empty():
			result.append(member)
	return result


func active_party_members() -> Array:
	var result: Array = []
	for member in party_members():
		if int(member.get("stats", {}).get("hp", 0)) > 0:
			result.append(member)
	return result


func member_by_id(member_id: String) -> Dictionary:
	if member_id.is_empty():
		return {}
	for companion in game_state.companions:
		if str(companion.get("id", "")) == member_id:
			ensure_member_shape(companion)
			return companion
	return {}


func party_member_count() -> int:
	return party_members().size()


func roster_member_count() -> int:
	return game_state.companions.size()


func generate_recruit_candidates(should_emit_signal: bool = true) -> void:
	game_state.recruit_candidates.clear()
	var used_names: Dictionary = {}
	for companion in game_state.companions:
		used_names[str(companion.get("name", ""))] = true
	for index in range(3):
		var candidate: Dictionary = create_recruit_candidate(index, used_names)
		game_state.recruit_candidates.append(candidate)
		used_names[str(candidate.get("name", ""))] = true
	if should_emit_signal:
		game_state.changed.emit()


func recruit_candidate(candidate_id: String) -> bool:
	ensure_party_state()
	if game_state.companions.size() >= ROSTER_MAX_SIZE:
		game_state.log_added.emit("角色库已满，最多八人")
		return false
	var candidate: Dictionary = candidate_by_id(candidate_id)
	if candidate.is_empty():
		game_state.log_added.emit("候选人不存在")
		return false
	if recruit_stone_count() < recruit_cost():
		game_state.log_added.emit("灵石不足，招募需要 %d 个灵石" % recruit_cost())
		return false
	if not game_state.spend_resource(RECRUIT_RESOURCE_ID, recruit_cost()):
		game_state.log_added.emit("灵石不足，招募失败")
		return false
	var companion: Dictionary = candidate.duplicate(true)
	companion.erase("candidate_id")
	companion["kind"] = "companion"
	ensure_member_shape(companion)
	game_state.companions.append(companion)
	var mod_api = game_state._mod_api()
	if mod_api != null:
		mod_api.emit_event(&"member_created", {"member": companion.duplicate(true)})
	if game_state.party_order.size() < PARTY_MAX_SIZE:
		game_state.party_order.append(str(companion.get("id", "")))
	else:
		game_state.reserve_order.append(str(companion.get("id", "")))
	game_state.log_added.emit("招募%s入队" % str(companion.get("name", "队友")))
	generate_recruit_candidates(false)
	game_state.add_task_experience(GameDefs.TaskType.RECRUIT, 5)
	game_state.changed.emit()
	return true


func move_party_member(member_id: String, direction: int) -> bool:
	ensure_party_state()
	var index: int = game_state.party_order.find(member_id)
	if index < 0:
		return false
	var target: int = clampi(index + direction, 0, game_state.party_order.size() - 1)
	if target == index:
		return false
	var id: String = str(game_state.party_order[index])
	game_state.party_order.remove_at(index)
	game_state.party_order.insert(target, id)
	game_state.changed.emit()
	return true


func dismiss_companion(member_id: String) -> bool:
	return release_companion(member_id)


func release_companion(member_id: String) -> bool:
	for index in range(game_state.companions.size()):
		var companion: Dictionary = game_state.companions[index]
		if str(companion.get("id", "")) != member_id:
			continue
		game_state._unequip_all_for_member(member_id)
		game_state.companions.remove_at(index)
		game_state.party_order.erase(member_id)
		game_state.reserve_order.erase(member_id)
		game_state.log_added.emit("%s已放生" % str(companion.get("name", "队友")))
		ensure_party_state()
		game_state.changed.emit()
		return true
	return false


func set_member_active(member_id: String, active: bool) -> bool:
	ensure_party_state()
	var active_index: int = game_state.party_order.find(member_id)
	var reserve_index: int = game_state.reserve_order.find(member_id)
	if active:
		if active_index >= 0:
			return true
		if reserve_index < 0 or game_state.party_order.size() >= PARTY_MAX_SIZE:
			return false
		game_state.reserve_order.remove_at(reserve_index)
		game_state.party_order.append(member_id)
	else:
		if active_index < 0:
			return reserve_index >= 0
		game_state.party_order.remove_at(active_index)
		if not game_state.reserve_order.has(member_id):
			game_state.reserve_order.append(member_id)
	game_state.changed.emit()
	return true


func can_recruit() -> bool:
	return game_state.companions.size() < ROSTER_MAX_SIZE and recruit_stone_count() >= recruit_cost()


func recruit_resource_id() -> String:
	return RECRUIT_RESOURCE_ID


func recruit_cost() -> int:
	return RECRUIT_COST_SPIRIT_STONE


func recruit_stone_count() -> int:
	return game_state.inventory_item_count(RECRUIT_RESOURCE_ID)


func add_exp_for_member(member_id: String, amount: int) -> void:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return
	var member_stats: Dictionary = member.get("stats", {})
	member_stats["exp"] = int(member_stats.get("exp", 0)) + amount
	while int(member_stats.get("exp", 0)) >= int(member_stats.get("next_exp", 1)):
		if not ensure_level_cap_open_for_member(member):
			break
		member_stats["exp"] = int(member_stats.get("exp", 0)) - int(member_stats.get("next_exp", 1))
		member_stats["next_exp"] = int(int(member_stats.get("next_exp", 1)) * 1.35) + 20
		level_up_member(member)
	game_state.changed.emit()


func add_exp_to_party(amount: int) -> void:
	for member in party_members():
		add_exp_for_member(str(member.get("id", "")), amount)


func ensure_party_state() -> void:
	if game_state.task_exp.has("meditate"):
		game_state.task_exp["recruit"] = max(int(game_state.task_exp.get("recruit", 0)), int(game_state.task_exp.get("meditate", 0)))
	game_state.task_exp.erase("meditate")
	for index in range(game_state.companions.size() - 1, -1, -1):
		var companion: Dictionary = game_state.companions[index]
		ensure_member_shape(companion)
		var companion_id: String = str(companion.get("id", ""))
		if companion_id.is_empty():
			game_state.companions.remove_at(index)
			continue
		game_state.companions[index] = companion
	var filtered: Array[String] = []
	for raw_id in game_state.party_order:
		var member_id: String = str(raw_id)
		if filtered.has(member_id):
			continue
		if companion_exists(member_id):
			filtered.append(member_id)
	game_state.party_order = filtered
	while game_state.party_order.size() > PARTY_MAX_SIZE:
		var overflow_id := str(game_state.party_order.pop_back())
		if not game_state.reserve_order.has(overflow_id):
			game_state.reserve_order.append(overflow_id)
	var reserve_filtered: Array[String] = []
	for raw_id in game_state.reserve_order:
		var reserve_id := str(raw_id)
		if reserve_filtered.has(reserve_id) or filtered.has(reserve_id):
			continue
		if companion_exists(reserve_id):
			reserve_filtered.append(reserve_id)
	for companion in game_state.companions:
		var companion_id := str(companion.get("id", ""))
		if not filtered.has(companion_id) and not reserve_filtered.has(companion_id):
			reserve_filtered.append(companion_id)
	game_state.reserve_order = reserve_filtered
	sync_equipped_ownership()


func ensure_member_shape(member: Dictionary) -> void:
	member["id"] = str(member.get("id", "companion_%d" % game_state.rng.randi()))
	member["name"] = str(member.get("name", "队友"))
	member["kind"] = str(member.get("kind", "companion"))
	member["visual_id"] = str(member.get("visual_id", DEFAULT_VISUAL_ID))
	if str(member.get("visual_id", "")).is_empty():
		member["visual_id"] = DEFAULT_VISUAL_ID
	var member_stats: Dictionary = member.get("stats", {})
	var defaults: Dictionary = base_member_stats()
	for key in defaults.keys():
		if not member_stats.has(key):
			member_stats[key] = defaults[key]
	member["stats"] = member_stats
	var member_elements: Dictionary = member.get("elements", {})
	var element_defaults: Dictionary = base_member_elements()
	for key in element_defaults.keys():
		if not member_elements.has(key):
			member_elements[key] = element_defaults[key]
	member["elements"] = member_elements
	var member_equipped: Dictionary = member.get("equipped", {})
	var equipped_defaults: Dictionary = base_equipped_slots()
	for key in equipped_defaults.keys():
		if not member_equipped.has(key):
			member_equipped[key] = equipped_defaults[key]
	member["equipped"] = member_equipped
	var attack_mode: String = str(member.get("attack_mode", DataTables.ATTACK_MODE_MELEE))
	member["attack_mode"] = attack_mode if DataTables.ATTACK_MODES.has(attack_mode) else DataTables.ATTACK_MODE_MELEE
	var member_skills: Array = member.get("skills", []) if member.get("skills", []) is Array else []
	member_skills = member_skills.filter(func(skill):
		return skill is Dictionary and str(skill.get("id", "")) != DataTables.RANGED_BASIC_ATTACK_ID
	)
	for skill in member_skills:
		skill["locked"] = true
		skill["replaceable"] = false
	member["skills"] = member_skills
	member["innate_traits"] = member.get("innate_traits", []) if member.get("innate_traits", []) is Array else []
	member["growth_primary_stats"] = normalized_growth_primary_stats(member.get("growth_primary_stats", []))
	clamp_member_runtime_stats(member)


func base_member_stats() -> Dictionary:
	return {
		"level": 1,
		"level_cap": 10,
		"stage": 1,
		"root_bone": 5,
		"exp": 0,
		"next_exp": 40,
		"free_points": 0,
		"hp": 80,
		"max_hp": 80,
		"mp": 40,
		"max_mp": 40,
		"attack": 8,
		"defense": 2,
	}


func next_exp_for_level(level: int) -> int:
	var next_exp := 40
	for _level in range(1, maxi(1, level)):
		next_exp = int(next_exp * 1.35) + 20
	return next_exp


func base_member_elements() -> Dictionary:
	return {
		"wood": 1,
		"fire": 1,
		"earth": 1,
		"metal": 1,
		"water": 1,
	}


func base_equipped_slots() -> Dictionary:
	return {
		"weapon": "",
		"helmet": "",
		"armor": "",
		"leggings": "",
		"gloves": "",
		"accessory_1": "",
		"accessory_2": "",
	}


func companion_exists(member_id: String) -> bool:
	for companion in game_state.companions:
		if str(companion.get("id", "")) == member_id:
			return true
	return false


func sync_equipped_ownership() -> void:
	for companion_index in range(game_state.companions.size()):
		var companion: Dictionary = game_state.companions[companion_index]
		companion["equipped"] = sanitize_equipped_for_member(str(companion.get("id", "")), companion.get("equipped", {}))
		game_state.companions[companion_index] = companion


func sanitize_equipped_for_member(member_id: String, member_equipped: Dictionary) -> Dictionary:
	var result: Dictionary = base_equipped_slots()
	for slot in result.keys():
		var instance_id: String = str(member_equipped.get(slot, ""))
		if instance_id.is_empty():
			continue
		var item: Dictionary = game_state.inventory_item_by_instance(instance_id)
		if item.is_empty():
			continue
		var fallback_owner: String = member_id if bool(item.get("equipped", false)) else ""
		var owner: String = str(item.get("equipped_by", fallback_owner))
		if owner != member_id:
			continue
		result[slot] = instance_id
		item["equipped"] = true
		item["equipped_by"] = member_id
		item["equipped_slot"] = slot
	return result


func create_recruit_candidate(index: int, used_names: Dictionary) -> Dictionary:
	var target_level: int = clampi(game_state.building_level("recruit"), 1, 10)
	var candidate: Dictionary = {
		"id": "companion_%d_%d" % [Time.get_ticks_usec(), game_state.rng.randi()],
		"candidate_id": "candidate_%d_%d" % [index, game_state.rng.randi()],
		"name": random_recruit_name(used_names),
		"kind": "candidate",
		"visual_id": DEFAULT_VISUAL_ID,
		"stats": base_member_stats(),
		"elements": base_member_elements(),
		"equipped": base_equipped_slots(),
		"attack_mode": DataTables.ATTACK_MODE_MELEE,
		"skills": [],
		"innate_traits": random_basic_recruit_traits(),
		"growth_primary_stats": random_growth_primary_stats(),
	}
	var candidate_stats: Dictionary = candidate["stats"]
	candidate_stats["level"] = target_level
	candidate_stats["stage"] = 1 + floori(float(target_level - 1) / 10.0)
	candidate_stats["level_cap"] = int(candidate_stats["stage"]) * 10
	candidate_stats["next_exp"] = next_exp_for_level(target_level)
	var point_count: int = maxi(0, (target_level - 1) * LEVEL_ATTRIBUTE_POINTS)
	apply_companion_attribute_points_to(candidate, point_count)
	candidate_stats["hp"] = candidate_stats["max_hp"]
	candidate_stats["mp"] = candidate_stats["max_mp"]
	return candidate


func random_basic_recruit_traits() -> Array:
	var recruit_level: int = 1
	if game_state != null and game_state.has_method("building_level"):
		recruit_level = int(game_state.call("building_level", "recruit"))
	var max_count: int = DataTables.recruit_max_trait_count(recruit_level)
	var trait_count: int = 1
	var rarity := DataTables.random_innate_trait_rarity(game_state.rng)
	if max_count >= 2 and rarity != "common":
		trait_count = 2
	trait_count = mini(trait_count, max_count)
	var pool: Array = DataTables.BASIC_RECRUIT_TRAIT_IDS.duplicate()
	var traits: Array = []
	while traits.size() < trait_count and not pool.is_empty():
		var index: int = game_state.rng.randi_range(0, pool.size() - 1)
		var trait_id: String = str(pool[index])
		pool.remove_at(index)
		var definition: Dictionary = DataTables.content_definition("trait", trait_id, DataTables.INNATE_TRAIT_DEFS.get(trait_id, {}))
		traits.append({
			"id": trait_id,
			"name": str(definition.get("name", trait_id)),
			"slot": "main" if traits.is_empty() else "sub",
			"rarity": rarity,
			"level": 1,
			"awakened": false,
		})
	return traits


func random_recruit_name(used_names: Dictionary) -> String:
	for _attempt in range(16):
		var name: String = "%s" % RECRUIT_NAME_PARTS[game_state.rng.randi_range(0, RECRUIT_NAME_PARTS.size() - 1)]
		if not used_names.has(name):
			return name
	return "散修%d" % game_state.rng.randi_range(100, 999)


func candidate_by_id(candidate_id: String) -> Dictionary:
	for candidate in game_state.recruit_candidates:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return candidate
	return {}


func growth_summary_for_member_data(member: Dictionary) -> String:
	var primary_stats: Array[String] = normalized_growth_primary_stats(member.get("growth_primary_stats", []))
	member["growth_primary_stats"] = primary_stats
	return "主属性 %s" % attribute_list_text(primary_stats)


func ensure_recruit_candidate_growth() -> void:
	for index in range(game_state.recruit_candidates.size()):
		var candidate: Dictionary = game_state.recruit_candidates[index]
		ensure_member_shape(candidate)
		game_state.recruit_candidates[index] = candidate


func migrate_free_points_to_auto_growth() -> void:
	for index in range(game_state.companions.size()):
		var companion: Dictionary = game_state.companions[index]
		migrate_free_points_for_member(companion)
		game_state.companions[index] = companion
	for index in range(game_state.recruit_candidates.size()):
		var candidate: Dictionary = game_state.recruit_candidates[index]
		migrate_free_points_for_member(candidate)
		game_state.recruit_candidates[index] = candidate


func migrate_free_points_for_member(member: Dictionary) -> void:
	var member_stats: Dictionary = member.get("stats", {})
	var free_points: int = maxi(0, int(member_stats.get("free_points", 0)))
	if free_points <= 0:
		member_stats["free_points"] = 0
		return
	apply_auto_attribute_points_to(member, free_points)
	member_stats["free_points"] = 0


func apply_random_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	var gains: Dictionary = {}
	for _index in range(point_count):
		var target: String = str(RANDOM_POINT_TARGETS[game_state.rng.randi_range(0, RANDOM_POINT_TARGETS.size() - 1)])
		apply_attribute_point_to(member, target, gains)
	return gains


func apply_auto_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	return apply_companion_attribute_points_to(member, point_count)


func apply_companion_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	var gains: Dictionary = {}
	var primary_stats: Array[String] = normalized_growth_primary_stats(member.get("growth_primary_stats", []))
	member["growth_primary_stats"] = primary_stats
	var primary_count: int = int(floor(float(maxi(0, point_count)) * 0.8))
	for _index in range(primary_count):
		var target: String = str(primary_stats[game_state.rng.randi_range(0, primary_stats.size() - 1)])
		apply_attribute_point_to(member, target, gains)
	for _index in range(maxi(0, point_count - primary_count)):
		var target: String = str(RANDOM_POINT_TARGETS[game_state.rng.randi_range(0, RANDOM_POINT_TARGETS.size() - 1)])
		apply_attribute_point_to(member, target, gains)
	return gains


func random_growth_primary_stats() -> Array[String]:
	var pool: Array[String] = []
	for target in RANDOM_POINT_TARGETS:
		pool.append(str(target))
	var result: Array[String] = []
	while result.size() < 3 and not pool.is_empty():
		var index: int = game_state.rng.randi_range(0, pool.size() - 1)
		result.append(str(pool[index]))
		pool.remove_at(index)
	return result


func normalized_growth_primary_stats(raw_value) -> Array[String]:
	var result: Array[String] = []
	if raw_value is Array:
		for target in raw_value:
			var stat_id: String = str(target)
			if RANDOM_POINT_TARGETS.has(stat_id) and not result.has(stat_id):
				result.append(stat_id)
			if result.size() >= 3:
				break
	while result.size() < 3:
		var candidate: String = str(RANDOM_POINT_TARGETS[game_state.rng.randi_range(0, RANDOM_POINT_TARGETS.size() - 1)])
		if not result.has(candidate):
			result.append(candidate)
	return result


func attribute_list_text(stat_ids: Array[String]) -> String:
	var names: Array[String] = []
	for stat_id in stat_ids:
		names.append(game_state._attribute_log_name(str(stat_id)))
	return "/".join(names)


func apply_attribute_point_to(member: Dictionary, target: String, gains: Dictionary) -> void:
	var member_stats: Dictionary = member.get("stats", {})
	var member_elements: Dictionary = member.get("elements", {})
	if target == "max_hp":
		member_stats["max_hp"] = int(member_stats.get("max_hp", 0)) + 4
		gains[target] = int(gains.get(target, 0)) + 4
	elif target == "max_mp":
		member_stats["max_mp"] = int(member_stats.get("max_mp", 0)) + 2
		gains[target] = int(gains.get(target, 0)) + 2
	elif target.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
		var element_id: String = DataTables.element_id_from_attribute(target)
		member_elements[element_id] = int(member_elements.get(element_id, 0)) + 1
		gains[target] = int(gains.get(target, 0)) + 1
	else:
		member_stats[target] = int(member_stats.get(target, 0)) + 1
		gains[target] = int(gains.get(target, 0)) + 1


func grant_auto_level_points_for_member(member: Dictionary) -> void:
	var member_stats: Dictionary = member.get("stats", {})
	var gains: Dictionary = apply_auto_attribute_points_to(member, LEVEL_ATTRIBUTE_POINTS)
	member_stats["free_points"] = 0
	game_state.log_added.emit("%s等级 %d：自动加点 %s" % [
		str(member.get("name", "成员")),
		int(member_stats.get("level", 1)),
		game_state._attribute_gains_text(gains),
	])


func level_up_member(member: Dictionary) -> void:
	var member_stats: Dictionary = member.get("stats", {})
	member_stats["level"] = int(member_stats.get("level", 1)) + 1
	grant_auto_level_points_for_member(member)
	member_stats["hp"] = game_state._total_stat_for_member(member, "max_hp")
	member_stats["mp"] = game_state._total_stat_for_member(member, "max_mp")


func ensure_level_cap_open_for_member(member: Dictionary) -> bool:
	var member_stats: Dictionary = member.get("stats", {})
	if int(member_stats.get("level", 1)) < int(member_stats.get("level_cap", 10)):
		return true
	game_state.log_added.emit("%s已达到等级上限 %d；请使用破境丹" % [member.get("name", "成员"), int(member_stats.get("level_cap", 10))])
	return false


func try_breakthrough_for_member(_member: Dictionary) -> bool:
	return false


func unlock_next_stage_for_member(member: Dictionary) -> void:
	var member_stats: Dictionary = member.get("stats", {})
	member_stats["stage"] = int(member_stats.get("stage", 1)) + 1
	member_stats["level_cap"] = int(member_stats.get("level_cap", 10)) + 10


func clamp_member_runtime_stats(member: Dictionary) -> void:
	var member_stats: Dictionary = member.get("stats", {})
	member_stats["level"] = maxi(1, int(member_stats.get("level", 1)))
	member_stats["level_cap"] = maxi(1, int(member_stats.get("level_cap", 10)))
	member_stats["stage"] = maxi(1, int(member_stats.get("stage", 1)))
	member_stats["next_exp"] = maxi(1, int(member_stats.get("next_exp", 40)))
	member_stats["free_points"] = maxi(0, int(member_stats.get("free_points", 0)))
	member_stats["max_hp"] = maxi(1, int(member_stats.get("max_hp", 80)))
	member_stats["max_mp"] = maxi(1, int(member_stats.get("max_mp", 40)))
	member_stats["hp"] = clampi(int(member_stats.get("hp", 0)), 0, game_state._total_stat_for_member(member, "max_hp"))
	member_stats["mp"] = clampi(int(member_stats.get("mp", 0)), 0, game_state._total_stat_for_member(member, "max_mp"))
