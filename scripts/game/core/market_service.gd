class_name MarketService
extends RefCounted

const MAX_COMMISSION_REQUIREMENTS := 2

var game_state
var market_rng := RandomNumberGenerator.new()


func _init(owner) -> void:
	game_state = owner


func ensure_state(now_unix: int = -1) -> bool:
	var now := _resolved_now(now_unix)
	if not (game_state.market_state is Dictionary):
		game_state.market_state = {}
	var state: Dictionary = game_state.market_state
	var changed_state := false
	if not (state.get("market_rng_state", null) is Dictionary) or state.get("market_rng_state", {}).is_empty():
		_seed_market_rng()
		_save_rng_state()
		changed_state = true
	else:
		_load_rng_state()
	if not (state.get("offers", null) is Array):
		state["offers"] = []
		changed_state = true
	if not (state.get("commissions", null) is Array):
		state["commissions"] = []
		changed_state = true
	state["paid_refresh_count"] = maxi(0, int(state.get("paid_refresh_count", 0)))
	var next_refresh := int(state.get("next_free_refresh_unix", 0))
	if next_refresh <= 0 or next_refresh > now + DataTables.MARKET_REFRESH_SECONDS:
		state["next_free_refresh_unix"] = now + DataTables.MARKET_REFRESH_SECONDS
		next_refresh = int(state["next_free_refresh_unix"])
		changed_state = true
	if state["offers"].is_empty() or not _valid_saved_offers(state["offers"]):
		state["offers"] = _generate_offers()
		changed_state = true
	if state["commissions"].is_empty() or not _valid_saved_commissions(state["commissions"]):
		state["commissions"] = _generate_commissions()
		changed_state = true
	if now >= next_refresh:
		_free_refresh(now)
		changed_state = true
	return changed_state


func refresh_if_due(now_unix: int = -1) -> bool:
	var now := _resolved_now(now_unix)
	var changed_state := ensure_state(now)
	if now < int(game_state.market_state.get("next_free_refresh_unix", now + DataTables.MARKET_REFRESH_SECONDS)):
		return changed_state
	_free_refresh(now)
	game_state.changed.emit()
	return true


func manual_refresh_cost() -> int:
	ensure_state()
	var count := maxi(0, int(game_state.market_state.get("paid_refresh_count", 0)))
	var index := mini(count, DataTables.MARKET_MANUAL_REFRESH_COSTS.size() - 1)
	return int(DataTables.MARKET_MANUAL_REFRESH_COSTS[index])


func seconds_until_refresh(now_unix: int = -1) -> int:
	var now := _resolved_now(now_unix)
	ensure_state(now)
	return maxi(0, int(game_state.market_state.get("next_free_refresh_unix", now)) - now)


func offers(now_unix: int = -1) -> Array:
	refresh_if_due(now_unix)
	return game_state.market_state.get("offers", []).duplicate(true)


func commissions(now_unix: int = -1) -> Array:
	refresh_if_due(now_unix)
	return game_state.market_state.get("commissions", []).duplicate(true)


func recyclable_item_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_item_id in DataTables.MARKET_RECYCLE_DEFS.keys():
		var item_id := str(raw_item_id)
		if item_id != DataTables.ITEM_ID_MARKET_TOKEN and game_state.inventory_item_count(item_id) >= int(DataTables.MARKET_RECYCLE_DEFS[item_id].get("amount", 1)):
			result.append(item_id)
	result.sort_custom(func(a: String, b: String): return DataTables.item_no(a) < DataTables.item_no(b))
	return result


func recycle_definition(item_id: String) -> Dictionary:
	return DataTables.MARKET_RECYCLE_DEFS.get(item_id, {}).duplicate(true)


func recycle_preview(item_id: String, amount: int) -> int:
	var definition: Dictionary = DataTables.MARKET_RECYCLE_DEFS.get(item_id, {})
	var batch_amount := int(definition.get("amount", 0))
	var token_amount := int(definition.get("tokens", 0))
	if batch_amount <= 0 or token_amount <= 0 or amount < batch_amount or amount % batch_amount != 0:
		return 0
	return floori(float(amount) / float(batch_amount)) * token_amount


func recycle_item(item_id: String, amount: int, confirmed_valuable: bool = false) -> bool:
	ensure_state()
	var definition: Dictionary = DataTables.MARKET_RECYCLE_DEFS.get(item_id, {})
	if definition.is_empty() or item_id == DataTables.ITEM_ID_MARKET_TOKEN:
		game_state.log_added.emit("该物品不能在坊市回收")
		return false
	if bool(definition.get("valuable", false)) and not confirmed_valuable:
		game_state.log_added.emit("贵重物品回收需要确认")
		return false
	var token_amount := recycle_preview(item_id, amount)
	if token_amount <= 0:
		game_state.log_added.emit("回收数量必须是完整批次")
		return false
	if game_state.inventory_item_count(item_id) < amount:
		game_state.log_added.emit("%s数量不足" % DataTables.resource_name(item_id))
		return false
	game_state._remove_inventory_count(item_id, amount)
	game_state.add_inventory_item(DataTables.ITEM_ID_MARKET_TOKEN, token_amount, false)
	game_state.log_added.emit("回收%s x%d，获得坊市令 x%d" % [DataTables.resource_name(item_id), amount, token_amount])
	game_state.changed.emit()
	return true


func buy_offer(slot_index: int) -> bool:
	refresh_if_due()
	var offers_data: Array = game_state.market_state.get("offers", [])
	if slot_index < 0 or slot_index >= offers_data.size():
		return false
	var offer = offers_data[slot_index]
	if not (offer is Dictionary) or bool(offer.get("sold", false)):
		game_state.log_added.emit("该商品已经售罄")
		return false
	var item_id := str(offer.get("item_id", ""))
	var amount := int(offer.get("amount", 0))
	var price := int(offer.get("price", 0))
	if DataTables.item_definition(item_id).is_empty() or amount <= 0 or price <= 0:
		return false
	if game_state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN) < price:
		game_state.log_added.emit("坊市令不足")
		return false
	game_state._remove_inventory_count(DataTables.ITEM_ID_MARKET_TOKEN, price)
	if not game_state.add_inventory_item(item_id, amount, false):
		game_state.add_inventory_item(DataTables.ITEM_ID_MARKET_TOKEN, price, false)
		return false
	offer["sold"] = true
	offers_data[slot_index] = offer
	game_state.market_state["offers"] = offers_data
	game_state.log_added.emit("坊市购得%s x%d" % [DataTables.resource_name(item_id), amount])
	game_state.changed.emit()
	return true


func paid_refresh() -> bool:
	ensure_state()
	var cost := manual_refresh_cost()
	if game_state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN) < cost:
		game_state.log_added.emit("刷新坊市需要坊市令 x%d" % cost)
		return false
	var generated := _generate_offers()
	if generated.size() != DataTables.MARKET_OFFER_COUNT:
		game_state.log_added.emit("坊市商品配置不足，刷新失败")
		return false
	game_state._remove_inventory_count(DataTables.ITEM_ID_MARKET_TOKEN, cost)
	game_state.market_state["offers"] = generated
	game_state.market_state["paid_refresh_count"] = int(game_state.market_state.get("paid_refresh_count", 0)) + 1
	game_state.log_added.emit("消耗坊市令 x%d 刷新货架" % cost)
	game_state.changed.emit()
	return true


func complete_commission(commission_index: int) -> bool:
	refresh_if_due()
	var commission_data: Array = game_state.market_state.get("commissions", [])
	if commission_index < 0 or commission_index >= commission_data.size():
		return false
	var commission = commission_data[commission_index]
	if not (commission is Dictionary) or bool(commission.get("completed", false)):
		game_state.log_added.emit("该委托已经完成")
		return false
	var requirements: Array = commission.get("requirements", [])
	var reward := int(commission.get("reward", 0))
	if requirements.is_empty() or reward <= 0:
		return false
	for raw_requirement in requirements:
		if not (raw_requirement is Dictionary):
			return false
		var item_id := str(raw_requirement.get("item_id", ""))
		var amount := int(raw_requirement.get("amount", 0))
		if amount <= 0 or game_state.inventory_item_count(item_id) < amount:
			game_state.log_added.emit("委托材料不足")
			return false
	for raw_requirement in requirements:
		game_state._remove_inventory_count(str(raw_requirement.get("item_id", "")), int(raw_requirement.get("amount", 0)))
	game_state.add_inventory_item(DataTables.ITEM_ID_MARKET_TOKEN, reward, false)
	commission["completed"] = true
	commission_data[commission_index] = commission
	game_state.market_state["commissions"] = commission_data
	game_state.log_added.emit("完成坊市委托，获得坊市令 x%d" % reward)
	game_state.changed.emit()
	return true


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen_goods := {}
	var max_commission_reward_multiplier := 0.0
	for index in range(mini(DataTables.MARKET_COMMISSION_VALUES.size(), DataTables.MARKET_COMMISSION_REWARDS.size())):
		var commission_value := int(DataTables.MARKET_COMMISSION_VALUES[index])
		if commission_value > 0:
			max_commission_reward_multiplier = maxf(
				max_commission_reward_multiplier,
				float(DataTables.MARKET_COMMISSION_REWARDS[index]) / float(commission_value)
			)
	for raw_category in DataTables.MARKET_GOODS_POOLS.keys():
		var category := str(raw_category)
		var pool: Dictionary = DataTables.MARKET_GOODS_POOLS[category]
		if int(pool.get("weight", 0)) <= 0:
			errors.append("商品分类 %s 权重无效" % category)
		for raw_entry in pool.get("entries", []):
			if not (raw_entry is Dictionary):
				errors.append("商品分类 %s 存在无效条目" % category)
				continue
			var item_id := str(raw_entry.get("item_id", ""))
			var amount := int(raw_entry.get("amount", 0))
			var price := int(raw_entry.get("price", 0))
			if DataTables.item_definition(item_id).is_empty() or item_id == DataTables.ITEM_ID_MARKET_TOKEN:
				errors.append("商品 %s 引用无效" % item_id)
			if amount <= 0 or price <= 0:
				errors.append("商品 %s 数量或价格无效" % item_id)
			if seen_goods.has(item_id):
				errors.append("商品 %s 在多个池中重复" % item_id)
			seen_goods[item_id] = true
			if recycle_preview(item_id, amount) >= price:
				errors.append("商品 %s 可直接回收套利" % item_id)
			if DataTables.MARKET_COMMISSION_ITEM_IDS.has(item_id) and DataTables.MARKET_RECYCLE_DEFS.has(item_id):
				var recycle_rule: Dictionary = DataTables.MARKET_RECYCLE_DEFS[item_id]
				var batch_amount := int(recycle_rule.get("amount", 0))
				var batch_tokens := int(recycle_rule.get("tokens", 0))
				if batch_amount > 0 and batch_tokens > 0:
					var commission_return := float(amount * batch_tokens) / float(batch_amount) * max_commission_reward_multiplier
					if commission_return > float(price):
						errors.append("商品 %s 可通过委托套利" % item_id)
	for raw_item_id in DataTables.MARKET_RECYCLE_DEFS.keys():
		var item_id := str(raw_item_id)
		var definition: Dictionary = DataTables.MARKET_RECYCLE_DEFS[item_id]
		if item_id == DataTables.ITEM_ID_MARKET_TOKEN or DataTables.item_definition(item_id).is_empty():
			errors.append("回收物品 %s 引用无效" % item_id)
		if int(definition.get("amount", 0)) <= 0 or int(definition.get("tokens", 0)) <= 0:
			errors.append("回收物品 %s 比例无效" % item_id)
	for raw_item_id in DataTables.MARKET_COMMISSION_ITEM_IDS:
		if not DataTables.MARKET_RECYCLE_DEFS.has(str(raw_item_id)):
			errors.append("委托物品 %s 没有回收价值" % str(raw_item_id))
	return errors


func _free_refresh(now: int) -> void:
	game_state.market_state["offers"] = _generate_offers()
	game_state.market_state["commissions"] = _generate_commissions()
	game_state.market_state["paid_refresh_count"] = 0
	game_state.market_state["next_free_refresh_unix"] = now + DataTables.MARKET_REFRESH_SECONDS


func _generate_offers() -> Array:
	_load_rng_state()
	var generated: Array = []
	var awarded_item_ids := {}
	while generated.size() < DataTables.MARKET_OFFER_COUNT:
		var eligible_by_category := _eligible_goods_by_category(awarded_item_ids)
		if eligible_by_category.is_empty():
			break
		var category := _weighted_category(eligible_by_category)
		var candidates: Array = eligible_by_category.get(category, [])
		var entry: Dictionary = candidates[market_rng.randi_range(0, candidates.size() - 1)].duplicate(true)
		var item_id := str(entry.get("item_id", ""))
		awarded_item_ids[item_id] = true
		generated.append({"slot_index": generated.size(), "item_id": item_id, "amount": int(entry.get("amount", 1)), "price": int(entry.get("price", 1)), "category": category, "sold": false})
	_save_rng_state()
	return generated


func _eligible_goods_by_category(excluded: Dictionary) -> Dictionary:
	var result := {}
	for raw_category in DataTables.MARKET_GOODS_POOLS.keys():
		var category := str(raw_category)
		var pool: Dictionary = DataTables.MARKET_GOODS_POOLS[category]
		var entries: Array = []
		for raw_entry in pool.get("entries", []):
			if not (raw_entry is Dictionary):
				continue
			var entry: Dictionary = raw_entry
			var item_id := str(entry.get("item_id", ""))
			if not excluded.has(item_id) and _goods_entry_available(entry):
				entries.append(entry.duplicate(true))
		if not entries.is_empty():
			result[category] = entries
	return result


func _goods_entry_available(entry: Dictionary) -> bool:
	var item_id := str(entry.get("item_id", ""))
	if DataTables.item_definition(item_id).is_empty():
		return false
	if game_state.expedition_level() < int(entry.get("min_expedition_level", 1)) or game_state.building_level("alchemy") < int(entry.get("min_alchemy_level", 1)):
		return false
	var required_recipe := str(entry.get("recipe_id", ""))
	if not required_recipe.is_empty():
		var recipe := DataTables.alchemy_recipe_def(required_recipe)
		var unlock_level := maxi(1, int(recipe.get("unlock_building_level", 1)))
		if game_state.building_level("alchemy") < unlock_level:
			return false
	var definition := DataTables.item_definition(item_id)
	var type_id := str(definition.get("type", ""))
	if type_id == DataTables.ITEM_TYPE_ALCHEMY_RECIPE:
		# 核心已无图纸货物；Mod 丹药物品按其配方解锁等级判断是否仍值得购买
		var payload_recipe := str(definition.get("payload", {}).get("recipe_id", ""))
		var payload_def := DataTables.alchemy_recipe_def(payload_recipe)
		return game_state.building_level("alchemy") < maxi(1, int(payload_def.get("unlock_building_level", 1)))
	if type_id == DataTables.ITEM_TYPE_BLUEPRINT:
		return not game_state.unlocked_blueprint_templates().has(str(definition.get("payload", {}).get("equipment_template_id", "")))
	if type_id == DataTables.ITEM_TYPE_SKILL_BOOK:
		return _roster_needs_skill(str(definition.get("payload", {}).get("skill_id", "")))
	if definition.get("payload", {}).has("permanent_attribute_enhance"):
		return _roster_can_use_enhance_tier(str(definition.get("payload", {}).get("permanent_attribute_enhance", {}).get("tier_id", "")))
	return true


func _weighted_category(eligible_by_category: Dictionary) -> String:
	var total_weight := 0
	for category in eligible_by_category.keys():
		total_weight += int(DataTables.MARKET_GOODS_POOLS.get(str(category), {}).get("weight", 0))
	var roll := market_rng.randi_range(1, maxi(1, total_weight))
	var cumulative := 0
	var categories: Array = eligible_by_category.keys()
	categories.sort()
	for raw_category in categories:
		var category := str(raw_category)
		cumulative += int(DataTables.MARKET_GOODS_POOLS.get(category, {}).get("weight", 0))
		if roll <= cumulative:
			return category
	return str(categories[0])


func _generate_commissions() -> Array:
	_load_rng_state()
	var generated: Array = []
	var used_item_ids := {}
	for index in range(DataTables.MARKET_COMMISSION_VALUES.size()):
		var target_value := int(DataTables.MARKET_COMMISSION_VALUES[index])
		var parts: Array[int] = [target_value]
		if target_value >= 4:
			var first_part := floori(float(target_value) / 2.0)
			parts = [first_part, target_value - first_part]
		var requirements: Array = []
		for part_value in parts:
			var candidate := _commission_candidate_for_value(part_value, used_item_ids)
			if candidate.is_empty():
				continue
			used_item_ids[str(candidate.get("item_id", ""))] = true
			requirements.append(candidate)
		generated.append({"commission_index": index, "requirements": requirements, "reward": int(DataTables.MARKET_COMMISSION_REWARDS[index]), "completed": false})
	_save_rng_state()
	return generated


func _commission_candidate_for_value(target_value: int, excluded: Dictionary) -> Dictionary:
	var candidates: Array[String] = []
	for raw_item_id in DataTables.MARKET_COMMISSION_ITEM_IDS:
		var candidate_item_id := str(raw_item_id)
		if excluded.has(candidate_item_id) or not _commission_item_available(candidate_item_id):
			continue
		var candidate_rule: Dictionary = DataTables.MARKET_RECYCLE_DEFS.get(candidate_item_id, {})
		var token_value := int(candidate_rule.get("tokens", 0))
		if token_value > 0 and target_value % token_value == 0:
			candidates.append(candidate_item_id)
	if candidates.is_empty():
		return {}
	var selected_item_id := candidates[market_rng.randi_range(0, candidates.size() - 1)]
	var selected_rule: Dictionary = DataTables.MARKET_RECYCLE_DEFS[selected_item_id]
	var units := floori(float(target_value) / float(int(selected_rule.get("tokens", 1))))
	return {"item_id": selected_item_id, "amount": int(selected_rule.get("amount", 1)) * units}


func _commission_item_available(item_id: String) -> bool:
	var item := DataTables.item_definition(item_id)
	if item.is_empty():
		return false
	if str(item.get("type", "")) == DataTables.ITEM_TYPE_PILL:
		for recipe_id in DataTables.ALCHEMY_RECIPE_DEFS.keys():
			var recipe := DataTables.alchemy_recipe_def(str(recipe_id))
			if str(recipe.get("result_item_id", "")) == item_id:
				return game_state.unlocked_alchemy_recipes().has(str(recipe_id))
	return true


func _roster_needs_skill(skill_id: String) -> bool:
	if skill_id.is_empty():
		return false
	for member in game_state.roster_members():
		if member is Dictionary and not game_state._knows_skill(skill_id, str(member.get("id", ""))):
			return true
	return false


func _roster_can_use_enhance_tier(tier_id: String) -> bool:
	var limit := DataTables.permanent_attribute_enhance_tier_limit(tier_id)
	if tier_id.is_empty() or limit <= 0:
		return false
	for member in game_state.roster_members():
		if member is Dictionary and int(member.get("enhance_pill_uses_by_tier", {}).get(tier_id, 0)) < limit:
			return true
	return false


func _valid_saved_offers(value: Array) -> bool:
	if value.size() != DataTables.MARKET_OFFER_COUNT:
		return false
	var seen := {}
	for raw_offer in value:
		if not (raw_offer is Dictionary):
			return false
		var item_id := str(raw_offer.get("item_id", ""))
		if seen.has(item_id) or DataTables.item_definition(item_id).is_empty() or int(raw_offer.get("amount", 0)) <= 0 or int(raw_offer.get("price", 0)) <= 0:
			return false
		seen[item_id] = true
	return true


func _valid_saved_commissions(value: Array) -> bool:
	if value.size() != DataTables.MARKET_COMMISSION_VALUES.size():
		return false
	var seen := {}
	for raw_commission in value:
		if not (raw_commission is Dictionary) or int(raw_commission.get("reward", 0)) <= 0:
			return false
		var requirements: Array = raw_commission.get("requirements", [])
		if requirements.is_empty() or requirements.size() > MAX_COMMISSION_REQUIREMENTS:
			return false
		for raw_requirement in requirements:
			if not (raw_requirement is Dictionary):
				return false
			var item_id := str(raw_requirement.get("item_id", ""))
			if seen.has(item_id) or not DataTables.MARKET_RECYCLE_DEFS.has(item_id) or int(raw_requirement.get("amount", 0)) <= 0:
				return false
			seen[item_id] = true
	return true


func _seed_market_rng() -> void:
	market_rng.seed = int(Time.get_unix_time_from_system() * 1000000.0) ^ int(Time.get_ticks_usec()) ^ int(game_state.get_instance_id())


func _load_rng_state() -> void:
	var saved = game_state.market_state.get("market_rng_state", {})
	if not (saved is Dictionary) or saved.is_empty():
		_seed_market_rng()
		return
	market_rng.seed = int(saved.get("seed", 1))
	market_rng.state = int(saved.get("state", market_rng.state))


func _save_rng_state() -> void:
	game_state.market_state["market_rng_state"] = {"seed": market_rng.seed, "state": market_rng.state}


func _resolved_now(now_unix: int) -> int:
	return now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
