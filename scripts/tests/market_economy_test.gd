extends Node

const TEST_NOW := 2000000000

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_market_data()
	_check_offer_and_commission_generation()
	_check_free_and_paid_refresh()
	_check_purchase_atomicity()
	_check_recycling_atomicity()
	_check_commission_atomicity()
	_check_save_and_migration()
	_check_economy_guards()
	if failures.is_empty():
		print("MARKET_ECONOMY_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _fresh_state(now_unix: int = TEST_NOW) -> GameState:
	var state := GameState.new()
	state.inventory.clear()
	state.companions.clear()
	state.party_order.clear()
	state.reserve_order.clear()
	state.recruit_candidates.clear()
	state.known_alchemy_recipes.clear()
	state.market_state = {
		"next_free_refresh_unix": now_unix + DataTables.MARKET_REFRESH_SECONDS,
		"paid_refresh_count": 0,
		"market_rng_state": {},
		"offers": [],
		"commissions": [],
	}
	state.market_service.market_rng.seed = 731927
	state.market_service._save_rng_state()
	state.market_service.ensure_state(now_unix)
	return state


func _check_market_data() -> void:
	var token := DataTables.item_definition(DataTables.ITEM_ID_MARKET_TOKEN)
	_expect_equal("market token item number", int(token.get("item_no", 0)), 1061)
	_expect_equal("market token type", str(token.get("type", "")), DataTables.ITEM_TYPE_MATERIAL)
	_expect_true("market token is stackable", bool(token.get("stackable", false)))
	_expect_true("market token is not usable", not bool(token.get("usable", true)))
	_expect_true("market token resource exists", ResourceLoader.exists(DataTables.item_resource_path(DataTables.ITEM_ID_MARKET_TOKEN)))
	_expect_true("market token cannot be recycled", not DataTables.MARKET_RECYCLE_DEFS.has(DataTables.ITEM_ID_MARKET_TOKEN))
	var state := _fresh_state()
	_expect_equal("market data validates", state.market_validation_errors(), [])
	_expect_equal("offer category count", DataTables.MARKET_GOODS_POOLS.size(), 5)
	var weight_total := 0
	for pool in DataTables.MARKET_GOODS_POOLS.values():
		weight_total += int(pool.get("weight", 0))
	_expect_equal("offer category weights total", weight_total, 100)


func _check_offer_and_commission_generation() -> void:
	var state := _fresh_state()
	var offers := state.market_offers(TEST_NOW)
	_expect_equal("six offers generated", offers.size(), DataTables.MARKET_OFFER_COUNT)
	var offer_ids := {}
	for offer in offers:
		var item_id := str(offer.get("item_id", ""))
		_expect_true("offer id is unique " + item_id, not offer_ids.has(item_id))
		offer_ids[item_id] = true
		_expect_true("offer item exists " + item_id, not DataTables.item_definition(item_id).is_empty())
		_expect_true("offer amount positive " + item_id, int(offer.get("amount", 0)) > 0)
		_expect_true("offer price positive " + item_id, int(offer.get("price", 0)) > 0)
	var commissions := state.market_commissions(TEST_NOW)
	_expect_equal("three commissions generated", commissions.size(), 3)
	var commission_ids := {}
	for index in range(commissions.size()):
		var commission: Dictionary = commissions[index]
		_expect_equal("commission reward %d" % index, int(commission.get("reward", 0)), int(DataTables.MARKET_COMMISSION_REWARDS[index]))
		var base_value := 0
		for requirement in commission.get("requirements", []):
			var item_id := str(requirement.get("item_id", ""))
			_expect_true("commission ids do not repeat " + item_id, not commission_ids.has(item_id))
			commission_ids[item_id] = true
			_expect_true("commission excludes rare items " + item_id, DataTables.MARKET_COMMISSION_ITEM_IDS.has(item_id))
			var recycle: Dictionary = DataTables.MARKET_RECYCLE_DEFS.get(item_id, {})
			base_value += int(requirement.get("amount", 0)) / int(recycle.get("amount", 1)) * int(recycle.get("tokens", 0))
		_expect_equal("commission base value %d" % index, base_value, int(DataTables.MARKET_COMMISSION_VALUES[index]))
	var skill_entry: Dictionary = DataTables.MARKET_GOODS_POOLS["rare"]["entries"][0]
	_expect_true("skill book gated below expedition six", not state.market_service._goods_entry_available(skill_entry))
	state.account_progression["expedition_level"] = 6
	var member := state.party_service.create_recruit_candidate(0, {})
	member["kind"] = "companion"
	state.companions.append(member)
	state.party_order.append(str(member.get("id", "")))
	_expect_true("needed skill book enters pool at expedition six", state.market_service._goods_entry_available(skill_entry))
	var enhance_entry: Dictionary = DataTables.MARKET_GOODS_POOLS["rare"]["entries"][6]
	state.building_levels["alchemy"] = 5
	_expect_true("permanent pill gated below alchemy six", not state.market_service._goods_entry_available(enhance_entry))
	state.building_levels["alchemy"] = 6
	_expect_true("permanent pill enters pool at alchemy six", state.market_service._goods_entry_available(enhance_entry))
	member["enhance_pill_uses_by_tier"] = {"t1": 100}
	_expect_true("permanent pills leave pool when roster is capped", not state.market_service._goods_entry_available(enhance_entry))


func _check_free_and_paid_refresh() -> void:
	var state := _fresh_state(TEST_NOW)
	state.market_state["paid_refresh_count"] = 3
	state.market_state["next_free_refresh_unix"] = TEST_NOW + 10
	_expect_true("free refresh triggers at deadline", state.market_service.refresh_if_due(TEST_NOW + 10))
	_expect_equal("free refresh resets paid count", int(state.market_state.get("paid_refresh_count", -1)), 0)
	_expect_equal("free refresh schedules one latest cycle", int(state.market_state.get("next_free_refresh_unix", 0)), TEST_NOW + 10 + DataTables.MARKET_REFRESH_SECONDS)
	_expect_equal("free refresh still has six offers", state.market_offers(TEST_NOW + 10).size(), 6)
	_expect_equal("free refresh still has three commissions", state.market_commissions(TEST_NOW + 10).size(), 3)
	state.market_state["next_free_refresh_unix"] = TEST_NOW + DataTables.MARKET_REFRESH_SECONDS + 1
	state.market_service.ensure_state(TEST_NOW)
	_expect_equal("clock rollback is clamped", int(state.market_state.get("next_free_refresh_unix", 0)), TEST_NOW + DataTables.MARKET_REFRESH_SECONDS)

	var live_now := int(Time.get_unix_time_from_system())
	state = _fresh_state(live_now)
	state.add_inventory_item(DataTables.ITEM_ID_MARKET_TOKEN, 60, false)
	var commissions_before: Array = state.market_commissions(live_now)
	var deadline_before := int(state.market_state.get("next_free_refresh_unix", 0))
	var expected_costs := [2, 4, 8, 16, 16]
	for index in range(expected_costs.size()):
		_expect_equal("paid refresh cost %d" % index, state.market_manual_refresh_cost(), expected_costs[index])
		var tokens_before := state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN)
		_expect_true("paid refresh succeeds %d" % index, state.refresh_market())
		_expect_equal("paid refresh deducts exact cost %d" % index, state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN), tokens_before - expected_costs[index])
		_expect_equal("paid refresh keeps commissions %d" % index, state.market_state.get("commissions", []), commissions_before)
		_expect_equal("paid refresh keeps free deadline %d" % index, int(state.market_state.get("next_free_refresh_unix", 0)), deadline_before)
	var offers_before: Array = state.market_state.get("offers", []).duplicate(true)
	var paid_count_before := int(state.market_state.get("paid_refresh_count", 0))
	state._remove_inventory_count(DataTables.ITEM_ID_MARKET_TOKEN, state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN))
	_expect_true("paid refresh rejects insufficient tokens", not state.refresh_market())
	_expect_equal("failed refresh keeps offers", state.market_state.get("offers", []), offers_before)
	_expect_equal("failed refresh keeps paid count", int(state.market_state.get("paid_refresh_count", 0)), paid_count_before)


func _check_purchase_atomicity() -> void:
	var now := int(Time.get_unix_time_from_system())
	var state := _fresh_state(now)
	var offer: Dictionary = state.market_offers(now)[0]
	var item_id := str(offer.get("item_id", ""))
	var amount := int(offer.get("amount", 0))
	var price := int(offer.get("price", 0))
	var item_before := state.inventory_item_count(item_id)
	_expect_true("purchase rejects insufficient tokens", not state.buy_market_offer(0))
	_expect_equal("failed purchase keeps item count", state.inventory_item_count(item_id), item_before)
	_expect_true("failed purchase keeps offer available", not bool(state.market_state["offers"][0].get("sold", false)))
	state.add_inventory_item(DataTables.ITEM_ID_MARKET_TOKEN, price, false)
	_expect_true("purchase succeeds", state.buy_market_offer(0))
	_expect_equal("purchase grants exact amount", state.inventory_item_count(item_id), item_before + amount)
	_expect_equal("purchase deducts exact price", state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN), 0)
	_expect_true("purchased offer is sold", bool(state.market_state["offers"][0].get("sold", false)))
	_expect_true("sold offer cannot be purchased twice", not state.buy_market_offer(0))
	_expect_equal("repeat purchase grants nothing", state.inventory_item_count(item_id), item_before + amount)


func _check_recycling_atomicity() -> void:
	var state := _fresh_state()
	state.add_inventory_item("t1_attack_enhance_pill", 2, false)
	_expect_true("valuable recycle requires confirmation", not state.recycle_market_item("t1_attack_enhance_pill", 2))
	_expect_equal("unconfirmed valuable item remains", state.inventory_item_count("t1_attack_enhance_pill"), 2)
	_expect_equal("unconfirmed recycle grants no token", state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN), 0)
	_expect_true("confirmed valuable recycle succeeds", state.recycle_market_item("t1_attack_enhance_pill", 2, true))
	_expect_equal("valuable recycle consumes full batch", state.inventory_item_count("t1_attack_enhance_pill"), 0)
	_expect_equal("valuable recycle grants token", state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN), 1)
	state.add_inventory_item("herb", 19, false)
	_expect_true("partial recycle batch rejected", not state.recycle_market_item("herb", 9))
	_expect_equal("failed partial recycle keeps herbs", state.inventory_item_count("herb"), 19)
	_expect_true("full recycle batch succeeds", state.recycle_market_item("herb", 10))
	_expect_equal("full recycle consumes ten herbs", state.inventory_item_count("herb"), 9)
	_expect_equal("full recycle adds one token", state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN), 2)
	_expect_true("market token cannot recycle", not state.recycle_market_item(DataTables.ITEM_ID_MARKET_TOKEN, 1))
	state.add_inventory_item("ore", 3, false)
	_expect_true("resource summary excludes token from materials", state.resource_summary().contains("材料:3"))
	_expect_true("resource summary shows token separately", state.resource_summary().contains("坊市令:2"))


func _check_commission_atomicity() -> void:
	var now := int(Time.get_unix_time_from_system())
	var state := _fresh_state(now)
	var commission: Dictionary = state.market_commissions(now)[0]
	var reward := int(commission.get("reward", 0))
	var before: Array = state.market_state.get("commissions", []).duplicate(true)
	_expect_true("commission rejects missing items", not state.complete_market_commission(0))
	_expect_equal("failed commission keeps state", state.market_state.get("commissions", []), before)
	_expect_equal("failed commission grants no token", state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN), 0)
	for requirement in commission.get("requirements", []):
		state.add_inventory_item(str(requirement.get("item_id", "")), int(requirement.get("amount", 0)), false)
	_expect_true("commission succeeds with all items", state.complete_market_commission(0))
	_expect_equal("commission grants exact reward", state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN), reward)
	_expect_true("commission marked completed", bool(state.market_state["commissions"][0].get("completed", false)))
	_expect_true("commission cannot complete twice", not state.complete_market_commission(0))
	_expect_equal("repeat commission grants nothing", state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN), reward)


func _check_save_and_migration() -> void:
	var now := int(Time.get_unix_time_from_system())
	var state := _fresh_state(now)
	state.market_state["paid_refresh_count"] = 2
	state.market_state["offers"][0]["sold"] = true
	var saved := state.to_save_data()
	_expect_equal("save schema eighteen", int(saved.get("schema_version", 0)), 18)
	var expected_market: Dictionary = saved.get("market_state", {}).duplicate(true)
	var loaded := GameState.new()
	loaded.load_save_data(saved)
	_expect_equal("market state persists", loaded.market_state, expected_market)
	var legacy := GameState.new()
	legacy.load_save_data({"schema_version": 15, "inventory": [], "companions": [], "party_order": [], "recruit_candidates": []})
	_expect_equal("schema fifteen gains six offers", legacy.market_offers().size(), 6)
	_expect_equal("schema fifteen gains commissions", legacy.market_commissions().size(), 3)
	_expect_equal("schema fifteen saves as eighteen", int(legacy.to_save_data().get("schema_version", 0)), 18)


func _check_economy_guards() -> void:
	var state := _fresh_state()
	state.building_levels["forge"] = 6
	state.add_inventory_item("ore", 4, false)
	_expect_true("forge succeeds", state.craft_equipment())
	var crafted: Array = state.inventory_items_for_type(DataTables.ITEM_TYPE_EQUIPMENT)
	_expect_equal("level-six forge creates two items", crafted.size(), 2)
	for equipment in crafted.duplicate():
		_expect_equal("forged item records source", str(equipment.get("obtain_source", "")), "crafted")
		_expect_true("crafted item salvages", state.salvage_equipment(str(equipment.get("instance_id", ""))))
	_expect_equal("crafted salvage does not return ore", state.inventory_item_count("ore"), 0)
	_expect_equal("crafted salvage returns enhancement stones", state.inventory_item_count(DataTables.ITEM_ID_ENHANCEMENT_STONE), 2)

	state = _fresh_state()
	state.building_levels["alchemy"] = 7
	state.known_alchemy_recipes.append("t1_attack_enhance_pill")
	state.add_inventory_item("blade_grass", 3, false)
	state.add_inventory_item("herb", 8, false)
	state.add_inventory_item("spirit_stone", 2, false)
	var recipe := DataTables.alchemy_recipe_def("t1_attack_enhance_pill")
	_expect_true("permanent recipe disables multiplier", not bool(recipe.get("allow_output_multiplier", true)))
	_expect_true("permanent recipe disables bonus", not bool(recipe.get("allow_bonus_output", true)))
	_expect_true("permanent pill craft succeeds", state.craft_alchemy_recipe("t1_attack_enhance_pill", 1))
	_expect_equal("permanent pill output stays one", state.inventory_item_count("t1_attack_enhance_pill"), 1)


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
