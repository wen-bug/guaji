extends Node

const CombatAIScript = preload("res://scripts/game/combat/combat_ai.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_ai_slot_order()
	_check_skill_book_append_and_full()
	_check_full_slot_replacement()
	_check_reorder()
	_check_save_round_trip()
	if failures.is_empty():
		print("MEMBER_SKILL_SLOTS_PASS")
		get_tree().quit(0)
		return
	for failure in failures: push_error(failure)
	get_tree().quit(1)


func _fresh_state() -> GameState:
	var state := GameState.new()
	state.inventory.clear(); state.companions.clear(); state.party_order.clear(); state.reserve_order.clear(); state.recruit_candidates.clear()
	var member: Dictionary = state.party_service.create_recruit_candidate(0, {})
	member["kind"] = "companion"
	state.companions.append(member)
	state.party_order.append(str(member.get("id", "")))
	return state


func _member_skill_ids(state: GameState) -> Array:
	var member: Dictionary = state.party_members()[0]
	var ids: Array = []
	for skill in member.get("skills", []):
		ids.append(str(skill.get("id", "")))
	return ids


func _check_ai_slot_order() -> void:
	var state := _fresh_state()
	var member: Dictionary = state.party_members()[0]
	var ai = CombatAIScript.new()
	member["skills"] = [DataTables.create_skill("poison"), DataTables.create_skill("thunder")]
	var action: Dictionary = ai.select_player_action(state, 140.0, 10.0, {}, {}, {}, member)
	_expect_equal("front damage slot wins (poison first)", str(action.get("id", "")), "poison")
	member["skills"] = [DataTables.create_skill("thunder"), DataTables.create_skill("poison")]
	action = ai.select_player_action(state, 140.0, 10.0, {}, {}, {}, member)
	_expect_equal("front damage slot wins (thunder first)", str(action.get("id", "")), "thunder")
	var cooldowns := {"poison": 2.0}
	member["skills"] = [DataTables.create_skill("poison"), DataTables.create_skill("thunder")]
	action = ai.select_player_action(state, 140.0, 10.0, cooldowns, {}, {}, member)
	_expect_equal("front slot on cooldown falls through to next", str(action.get("id", "")), "thunder")


func _check_skill_book_append_and_full() -> void:
	var state := _fresh_state()
	var member_id := str(state.party_members()[0].get("id", ""))
	_expect_true("slots not full at start", not state.member_skill_slots_full(member_id))
	for expected_count in range(1, GameState.MAX_MEMBER_SKILL_SLOTS + 1):
		var skill_id: String = ["heal", "thunder", "poison", "attack_up"][expected_count - 1]
		state.add_inventory_item("skill_book_%s" % skill_id, 1, false)
		var instance_id := str(state.inventory.back().get("instance_id", ""))
		_expect_true("book %d appends" % expected_count, state.use_inventory_item_for_member(instance_id, member_id))
		_expect_equal("slot count after book %d" % expected_count, state.party_members()[0].get("skills", []).size(), expected_count)
	_expect_true("slots full detected", state.member_skill_slots_full(member_id))
	_expect_equal("append order preserved", _member_skill_ids(state), ["heal", "thunder", "poison", "attack_up"])


func _check_full_slot_replacement() -> void:
	var state := _fresh_state()
	var member_id := str(state.party_members()[0].get("id", ""))
	for skill_id in ["heal", "thunder", "poison", "attack_up"]:
		state.add_inventory_item("skill_book_%s" % skill_id, 1, false)
		var instance_id := str(state.inventory.back().get("instance_id", ""))
		state.use_inventory_item_for_member(instance_id, member_id)
	state.add_inventory_item("skill_book_spirit_shield", 1, false)
	var book_instance := str(state.inventory.back().get("instance_id", ""))
	_expect_true("full slots without replace rejected", not state.use_inventory_item_for_member(book_instance, member_id))
	_expect_equal("rejected book not consumed", state.inventory_item_count("skill_book_spirit_shield"), 1)
	_expect_equal("skill count unchanged on rejection", _member_skill_ids(state), ["heal", "thunder", "poison", "attack_up"])
	_expect_true("replace at slot 3 succeeds", state.use_skill_book_replacing(book_instance, member_id, 2))
	_expect_equal("slot 3 replaced in place", _member_skill_ids(state), ["heal", "thunder", "spirit_shield", "attack_up"])
	_expect_equal("replacing book consumed", state.inventory_item_count("skill_book_spirit_shield"), 0)
	_expect_true("relearning known skill rejected", not state.use_skill_book_replacing(book_instance, member_id, 0))
	_expect_true("invalid replace index rejected", not state.use_skill_book_replacing("missing_instance", member_id, 1))


func _check_reorder() -> void:
	var state := _fresh_state()
	var member_id := str(state.party_members()[0].get("id", ""))
	for skill_id in ["heal", "thunder", "poison", "attack_up"]:
		state.add_inventory_item("skill_book_%s" % skill_id, 1, false)
		var instance_id := str(state.inventory.back().get("instance_id", ""))
		state.use_inventory_item_for_member(instance_id, member_id)
	_expect_true("reorder swaps slots", state.reorder_member_skill(member_id, 0, 3))
	_expect_equal("swap result", _member_skill_ids(state), ["attack_up", "thunder", "poison", "heal"])
	_expect_true("adjacent swap works", state.reorder_member_skill(member_id, 1, 2))
	_expect_equal("adjacent swap result", _member_skill_ids(state), ["attack_up", "poison", "thunder", "heal"])
	_expect_true("same index rejected", not state.reorder_member_skill(member_id, 2, 2))
	_expect_true("out of bounds rejected", not state.reorder_member_skill(member_id, -1, 2))
	_expect_true("over max rejected", not state.reorder_member_skill(member_id, 0, 4))
	_expect_equal("rejected swaps leave order intact", _member_skill_ids(state), ["attack_up", "poison", "thunder", "heal"])


func _check_save_round_trip() -> void:
	var state := _fresh_state()
	var member_id := str(state.party_members()[0].get("id", ""))
	for skill_id in ["heal", "thunder", "poison", "attack_up"]:
		state.add_inventory_item("skill_book_%s" % skill_id, 1, false)
		var instance_id := str(state.inventory.back().get("instance_id", ""))
		state.use_inventory_item_for_member(instance_id, member_id)
	state.reorder_member_skill(member_id, 0, 2)
	state.use_skill_book_replacing(_add_book(state, "skill_book_spirit_shield"), member_id, 1)
	_expect_equal("pre-save order", _member_skill_ids(state), ["poison", "spirit_shield", "heal", "attack_up"])
	var loaded := GameState.new()
	loaded.load_save_data(state.to_save_data())
	var loaded_member: Dictionary = loaded.member_by_id(member_id)
	var loaded_ids: Array = []
	for skill in loaded_member.get("skills", []):
		loaded_ids.append(str(skill.get("id", "")))
	_expect_equal("slot order survives save round trip", loaded_ids, ["poison", "spirit_shield", "heal", "attack_up"])


func _add_book(state: GameState, item_id: String) -> String:
	state.add_inventory_item(item_id, 1, false)
	return str(state.inventory.back().get("instance_id", ""))


func _expect_true(label: String, value: bool, detail: String = "") -> void:
	if not value: failures.append("%s%s" % [label, ": %s" % detail if not detail.is_empty() else ""])


func _expect_equal(label: String, value, expected) -> void:
	if str(value) != str(expected):
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(value)])
