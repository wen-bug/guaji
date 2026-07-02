class_name PartyService
extends RefCounted

var game_state: GameState


func _init(owner: GameState) -> void:
	game_state = owner


func player_member() -> Dictionary:
	return {
		"id": GameState.PLAYER_ID,
		"name": "玩家",
		"kind": "player",
		"stats": game_state.stats,
		"elements": game_state.elements,
		"equipped": game_state.equipped,
		"skills": game_state.skills,
	}


func growth_summary_for(member_id: String) -> String:
	if member_id == GameState.PLAYER_ID or member_id.is_empty():
		return "全随机"
	var member: Dictionary = selected_party_member_or_player(member_id)
	return growth_summary_for_member_data(member)


func party_members() -> Array:
	ensure_party_state()
	var result: Array = []
	for member_id in game_state.party_order:
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
	if member_id == GameState.PLAYER_ID or member_id.is_empty():
		return player_member()
	for companion in game_state.companions:
		if str(companion.get("id", "")) == member_id:
			ensure_member_shape(companion)
			return companion
	return {}


func party_member_count() -> int:
	return party_members().size()


func selected_party_member_or_player(member_id: String) -> Dictionary:
	var member: Dictionary = member_by_id(member_id)
	if member.is_empty():
		return player_member()
	return member


func generate_recruit_candidates(should_emit_signal := true) -> void:
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
	if game_state.party_order.size() >= GameState.PARTY_MAX_SIZE:
		game_state.log_added.emit("队伍已满，最多四人")
		return false
	var candidate: Dictionary = candidate_by_id(candidate_id)
	if candidate.is_empty():
		game_state.log_added.emit("候选人不存在")
		return false
	if game_state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL) < GameState.RECRUIT_COST_MATERIAL:
		game_state.log_added.emit("材料不足，招募需要 %d 个任意材料" % GameState.RECRUIT_COST_MATERIAL)
		return false
	if not game_state.spend_inventory_type(DataTables.ITEM_TYPE_MATERIAL, GameState.RECRUIT_COST_MATERIAL):
		game_state.log_added.emit("材料不足，招募失败")
		return false
	var companion: Dictionary = candidate.duplicate(true)
	companion.erase("candidate_id")
	companion["kind"] = "companion"
	ensure_member_shape(companion)
	game_state.companions.append(companion)
	game_state.party_order.append(str(companion.get("id", "")))
	game_state.log_added.emit("招募%s入队" % str(companion.get("name", "队友")))
	generate_recruit_candidates(false)
	game_state.add_task_experience(GameDefs.TaskType.RECRUIT, 5)
	game_state.changed.emit()
	return true


func move_party_member(member_id: String, direction: int) -> bool:
	ensure_party_state()
	var index := game_state.party_order.find(member_id)
	if index < 0:
		return false
	var target := clampi(index + direction, 0, game_state.party_order.size() - 1)
	if target == index:
		return false
	var id := game_state.party_order[index]
	game_state.party_order.remove_at(index)
	game_state.party_order.insert(target, id)
	game_state.changed.emit()
	return true


func dismiss_companion(member_id: String) -> bool:
	if member_id == GameState.PLAYER_ID:
		game_state.log_added.emit("玩家不能离队")
		return false
	for index in range(game_state.companions.size()):
		var companion: Dictionary = game_state.companions[index]
		if str(companion.get("id", "")) != member_id:
			continue
		game_state._unequip_all_for_member(member_id)
		game_state.companions.remove_at(index)
		game_state.party_order.erase(member_id)
		game_state.log_added.emit("%s离开队伍" % str(companion.get("name", "队友")))
		ensure_party_state()
		game_state.changed.emit()
		return true
	return false


func can_recruit() -> bool:
	return game_state.party_order.size() < GameState.PARTY_MAX_SIZE and game_state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL) >= GameState.RECRUIT_COST_MATERIAL


func add_exp_for_member(member_id: String, amount: int) -> void:
	var member: Dictionary = selected_party_member_or_player(member_id)
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
		add_exp_for_member(str(member.get("id", GameState.PLAYER_ID)), amount)


func ensure_party_state() -> void:
	if not game_state.stats.has("free_points"):
		game_state.stats["free_points"] = 0
	if game_state.task_exp.has("meditate"):
		game_state.task_exp["recruit"] = max(int(game_state.task_exp.get("recruit", 0)), int(game_state.task_exp.get("meditate", 0)))
	game_state.task_exp.erase("meditate")
	if not game_state.party_order.has(GameState.PLAYER_ID):
		game_state.party_order.insert(0, GameState.PLAYER_ID)
	for index in range(game_state.companions.size() - 1, -1, -1):
		var companion: Dictionary = game_state.companions[index]
		ensure_member_shape(companion)
		var companion_id := str(companion.get("id", ""))
		if companion_id.is_empty() or companion_id == GameState.PLAYER_ID:
			game_state.companions.remove_at(index)
			continue
		game_state.companions[index] = companion
	var filtered: Array[String] = []
	for raw_id in game_state.party_order:
		var member_id := str(raw_id)
		if filtered.has(member_id):
			continue
		if member_id == GameState.PLAYER_ID or companion_exists(member_id):
			filtered.append(member_id)
	game_state.party_order = filtered
	if not game_state.party_order.has(GameState.PLAYER_ID):
		game_state.party_order.insert(0, GameState.PLAYER_ID)
	while game_state.party_order.size() > GameState.PARTY_MAX_SIZE:
		game_state.party_order.remove_at(game_state.party_order.size() - 1)
	sync_equipped_ownership()


func ensure_member_shape(member: Dictionary) -> void:
	member["id"] = str(member.get("id", "companion_%d" % game_state.rng.randi()))
	member["name"] = str(member.get("name", "队友"))
	member["kind"] = str(member.get("kind", "companion"))
	var member_stats: Dictionary = member.get("stats", {})
	var defaults := base_member_stats()
	for key in defaults.keys():
		if not member_stats.has(key):
			member_stats[key] = defaults[key]
	member["stats"] = member_stats
	var member_elements: Dictionary = member.get("elements", {})
	var element_defaults := base_member_elements()
	for key in element_defaults.keys():
		if not member_elements.has(key):
			member_elements[key] = element_defaults[key]
	member["elements"] = member_elements
	var member_equipped: Dictionary = member.get("equipped", {})
	var equipped_defaults := base_equipped_slots()
	for key in equipped_defaults.keys():
		if not member_equipped.has(key):
			member_equipped[key] = equipped_defaults[key]
	member["equipped"] = member_equipped
	var member_skills: Array = member.get("skills", [])
	if member_skills.is_empty():
		member_skills.append(DataTables.create_skill())
	member["skills"] = member_skills
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
	game_state.equipped = sanitize_equipped_for_member(GameState.PLAYER_ID, game_state.equipped)
	for companion_index in range(game_state.companions.size()):
		var companion: Dictionary = game_state.companions[companion_index]
		companion["equipped"] = sanitize_equipped_for_member(str(companion.get("id", "")), companion.get("equipped", {}))
		game_state.companions[companion_index] = companion


func sanitize_equipped_for_member(member_id: String, member_equipped: Dictionary) -> Dictionary:
	var result := base_equipped_slots()
	for slot in result.keys():
		var instance_id := str(member_equipped.get(slot, ""))
		if instance_id.is_empty():
			continue
		var item := game_state.inventory_item_by_instance(instance_id)
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
	var target_level := maxi(1, int(game_state.stats.get("level", 1)))
	var candidate := {
		"id": "companion_%d_%d" % [Time.get_ticks_usec(), game_state.rng.randi()],
		"candidate_id": "candidate_%d_%d" % [index, game_state.rng.randi()],
		"name": random_recruit_name(used_names),
		"kind": "candidate",
		"stats": base_member_stats(),
		"elements": base_member_elements(),
		"equipped": base_equipped_slots(),
		"skills": [DataTables.create_skill()],
		"growth_primary_stats": random_growth_primary_stats(),
	}
	var candidate_stats: Dictionary = candidate["stats"]
	candidate_stats["level"] = target_level
	var point_count := maxi(0, (target_level - 1) * GameState.LEVEL_ATTRIBUTE_POINTS)
	apply_companion_attribute_points_to(candidate, point_count)
	candidate_stats["hp"] = candidate_stats["max_hp"]
	candidate_stats["mp"] = candidate_stats["max_mp"]
	return candidate


func random_recruit_name(used_names: Dictionary) -> String:
	for _attempt in range(16):
		var name := "%s" % GameState.RECRUIT_NAME_PARTS[game_state.rng.randi_range(0, GameState.RECRUIT_NAME_PARTS.size() - 1)]
		if not used_names.has(name):
			return name
	return "散修%d" % game_state.rng.randi_range(100, 999)


func candidate_by_id(candidate_id: String) -> Dictionary:
	for candidate in game_state.recruit_candidates:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return candidate
	return {}


func growth_summary_for_member_data(member: Dictionary) -> String:
	if str(member.get("id", "")) == GameState.PLAYER_ID:
		return "全随机"
	var primary_stats := normalized_growth_primary_stats(member.get("growth_primary_stats", []))
	member["growth_primary_stats"] = primary_stats
	return "主属性 %s" % attribute_list_text(primary_stats)


func ensure_recruit_candidate_growth() -> void:
	for index in range(game_state.recruit_candidates.size()):
		var candidate: Dictionary = game_state.recruit_candidates[index]
		ensure_member_shape(candidate)
		game_state.recruit_candidates[index] = candidate


func migrate_free_points_to_auto_growth() -> void:
	migrate_free_points_for_member(player_member())
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
	var free_points := maxi(0, int(member_stats.get("free_points", 0)))
	if free_points <= 0:
		member_stats["free_points"] = 0
		return
	apply_auto_attribute_points_to(member, free_points)
	member_stats["free_points"] = 0


func apply_random_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	var gains: Dictionary = {}
	for _index in range(point_count):
		var target := str(GameState.RANDOM_POINT_TARGETS[game_state.rng.randi_range(0, GameState.RANDOM_POINT_TARGETS.size() - 1)])
		apply_attribute_point_to(member, target, gains)
	return gains


func apply_auto_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	if str(member.get("id", "")) == GameState.PLAYER_ID:
		return apply_random_attribute_points_to(member, point_count)
	return apply_companion_attribute_points_to(member, point_count)


func apply_companion_attribute_points_to(member: Dictionary, point_count: int) -> Dictionary:
	var gains: Dictionary = {}
	var primary_stats := normalized_growth_primary_stats(member.get("growth_primary_stats", []))
	member["growth_primary_stats"] = primary_stats
	var primary_count := int(floor(float(maxi(0, point_count)) * 0.8))
	for _index in range(primary_count):
		var target := str(primary_stats[game_state.rng.randi_range(0, primary_stats.size() - 1)])
		apply_attribute_point_to(member, target, gains)
	for _index in range(maxi(0, point_count - primary_count)):
		var target := str(GameState.RANDOM_POINT_TARGETS[game_state.rng.randi_range(0, GameState.RANDOM_POINT_TARGETS.size() - 1)])
		apply_attribute_point_to(member, target, gains)
	return gains


func random_growth_primary_stats() -> Array[String]:
	var pool: Array[String] = []
	for target in GameState.RANDOM_POINT_TARGETS:
		pool.append(str(target))
	var result: Array[String] = []
	while result.size() < 3 and not pool.is_empty():
		var index := game_state.rng.randi_range(0, pool.size() - 1)
		result.append(str(pool[index]))
		pool.remove_at(index)
	return result


func normalized_growth_primary_stats(raw_value) -> Array[String]:
	var result: Array[String] = []
	if raw_value is Array:
		for target in raw_value:
			var stat_id := str(target)
			if GameState.RANDOM_POINT_TARGETS.has(stat_id) and not result.has(stat_id):
				result.append(stat_id)
			if result.size() >= 3:
				break
	while result.size() < 3:
		var candidate := str(GameState.RANDOM_POINT_TARGETS[game_state.rng.randi_range(0, GameState.RANDOM_POINT_TARGETS.size() - 1)])
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
		var element_id := DataTables.element_id_from_attribute(target)
		member_elements[element_id] = int(member_elements.get(element_id, 0)) + 1
		gains[target] = int(gains.get(target, 0)) + 1
	else:
		member_stats[target] = int(member_stats.get(target, 0)) + 1
		gains[target] = int(gains.get(target, 0)) + 1


func grant_auto_level_points_for_member(member: Dictionary) -> void:
	var member_stats: Dictionary = member.get("stats", {})
	var gains := apply_auto_attribute_points_to(member, GameState.LEVEL_ATTRIBUTE_POINTS)
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
	if try_breakthrough_for_member(member):
		return true
	game_state.log_added.emit("%s已达到等级上限 %d；请使用突破丹或提升根骨" % [member.get("name", "成员"), int(member_stats.get("level_cap", 10))])
	return false


func try_breakthrough_for_member(member: Dictionary) -> bool:
	var member_stats: Dictionary = member.get("stats", {})
	if int(member_stats.get("level", 1)) < int(member_stats.get("level_cap", 10)):
		return false
	if int(member_stats.get("root_bone", 0)) <= int(member_stats.get("level", 1)):
		return false
	unlock_next_stage_for_member(member)
	game_state.log_added.emit("%s根骨突破至阶段 %d" % [member.get("name", "成员"), int(member_stats.get("stage", 1))])
	game_state.changed.emit()
	return true


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
