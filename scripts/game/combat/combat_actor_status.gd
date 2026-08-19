class_name CombatActorStatus
extends Node

signal combat_popup_requested(amount: int, world_position: Vector2, target_key: String, damage_type: String, is_heal: bool)
signal hit_received(amount: int, damage_type: String)
signal defeated(actor_id: String)
signal status_changed(event: Dictionary)
signal combat_events_emitted(events: Array)

const KIND_MEMBER := "member"
const KIND_ENEMY := "enemy"
const CombatActorStateMachineScript = preload("res://scripts/game/combat/combat_actor_state_machine.gd")
const CombatEffectResolverScript = preload("res://scripts/game/combat/combat_effect_resolver.gd")

var actor_id: String = ""
var actor_name: String = ""
var actor_kind: String = KIND_MEMBER
var game_state = null
var member_id: String = ""
var data: Dictionary = {}
var combat_store: Dictionary = {}
var visual_owner: Node = null
var temp_stats: Dictionary = {}
var combat_buffs: Array = []
var combat_effects: Array = []
var skill_cooldowns: Dictionary = {}
var pending_skill: Dictionary = {}
var state_machine = CombatActorStateMachineScript.new()
var effect_resolver: CombatEffectResolver = CombatEffectResolverScript.new()
var popup_offset: Vector2 = Vector2(0, -24)
var turn_serial := 0
var turn_active := false
var _status_sequence := 0


func bind_member(owner_game_state, owner_member_id: String, owner_store: Dictionary = {}, owner_visual: Node = null) -> void:
	game_state = owner_game_state
	member_id = owner_member_id
	actor_kind = KIND_MEMBER
	actor_id = owner_member_id
	visual_owner = owner_visual
	combat_store = owner_store
	data = _member_data()
	actor_name = str(data.get("name", "成员"))
	_sync_runtime_arrays_from_store()
	_bind_presentation()


func bind_enemy(enemy_data: Dictionary, owner_visual: Node = null) -> void:
	game_state = null
	member_id = ""
	actor_kind = KIND_ENEMY
	data = enemy_data
	actor_id = str(data.get("combat_id", data.get("id", "enemy")))
	actor_name = str(data.get("name", "敌人"))
	visual_owner = owner_visual
	_sync_runtime_arrays_from_store()
	_bind_presentation()


func rebind_store(owner_store: Dictionary) -> void:
	combat_store = owner_store
	_sync_runtime_arrays_from_store()


func set_effect_resolver(resolver: CombatEffectResolver) -> void:
	if resolver != null:
		effect_resolver = resolver


func combat_snapshot() -> Dictionary:
	var stats: Dictionary = _stats()
	return {
		"id": actor_id,
		"name": actor_name,
		"kind": actor_kind,
		"hp": int(stats.get("hp", data.get("hp", 0))),
		"max_hp": total_stat("max_hp"),
		"mp": int(stats.get("mp", data.get("mp", 0))),
		"max_mp": total_stat("max_mp"),
		"attack": total_stat("attack"),
		"defense": total_stat("defense"),
		"elements": _elements().duplicate(true),
		"dominant_element": dominant_element(),
		"combat_affinity": combat_affinity(),
		"equipment_modifiers": equipment_combat_modifiers(),
		"combat_buffs": combat_buffs.duplicate(true),
		"combat_effects": combat_effects.duplicate(true),
		"temp_stats": temp_stats.duplicate(true),
		"position": combat_position(),
	}


func total_stat(stat_id: String) -> int:
	var value: int = 0
	if actor_kind == KIND_MEMBER and game_state != null:
		if stat_id == "attack":
			value = int(game_state.total_attack_for(member_id))
		elif stat_id == "defense":
			value = int(game_state.total_defense_for(member_id))
		else:
			value = int(game_state.total_stat_for(member_id, stat_id))
	else:
		value = int(data.get(stat_id, 0))
	value += int(temp_stats.get(stat_id, 0))
	value += _buff_stat_bonus(stat_id)
	return max(0, value)


func total_element(element_id: String) -> int:
	if actor_kind == KIND_MEMBER and game_state != null:
		return int(game_state.total_element_for(member_id, element_id))
	return int(data.get("elements", {}).get(element_id, data.get(element_id, 0)))


func dominant_element() -> String:
	if actor_kind == KIND_MEMBER and game_state != null:
		return game_state.dominant_element_for(member_id)
	var best_id: String = ""
	var best_value: int = -1
	for element_id in DataTables.ELEMENT_IDS:
		var value: int = total_element(str(element_id))
		if value > best_value:
			best_value = value
			best_id = str(element_id)
	return best_id


func combat_affinity() -> String:
	if actor_kind == KIND_MEMBER and game_state != null and game_state.has_method("combat_affinity_for"):
		return DataTables.normalize_combat_affinity(str(game_state.combat_affinity_for(member_id)))
	return DataTables.normalize_combat_affinity(str(data.get("combat_affinity", DataTables.COMBAT_AFFINITY_NORMAL)))


func equipment_combat_modifiers() -> Dictionary:
	if actor_kind == KIND_MEMBER and game_state != null and game_state.has_method("equipment_combat_modifiers_for"):
		return game_state.equipment_combat_modifiers_for(member_id)
	return {
		"direct_damage_percent": 0.0,
		"critical_chance": 0.0,
		"critical_multiplier": 1.5,
		"leech_percent": 0.0,
		"defense_ignore": 0,
		"direct_damage_reduction": 0.0,
		"direct_heal_percent": 0.0,
	}


func add_buff(buff: Dictionary) -> void:
	if buff.is_empty():
		return
	var normalized: Dictionary = buff.duplicate(true)
	var source_skill_id: String = str(normalized.get("source_skill_id", ""))
	for effect in effect_resolver.legacy_buffs_to_effects([normalized], source_skill_id):
		add_status_effect(effect)


func add_status_effect(effect: Dictionary) -> Dictionary:
	if effect.is_empty():
		return {}
	var next_effect := effect.duplicate(true)
	_status_sequence += 1
	next_effect["first_turn_serial"] = turn_serial + 1
	next_effect["application_order"] = _status_sequence
	var store: Dictionary = _runtime_effect_store()
	var event := effect_resolver.add_status_effect(store, next_effect)
	_apply_runtime_effect_store(store)
	_write_runtime_arrays_to_store()
	if not event.is_empty():
		event["actor_id"] = actor_id
		status_changed.emit(event.duplicate(true))
		combat_events_emitted.emit([event.duplicate(true)])
	return event


func resolve_status_trigger(trigger: String, context: Dictionary, rng: RandomNumberGenerator, owner_role: String = "attacker") -> Dictionary:
	var store: Dictionary = _runtime_effect_store()
	effect_resolver.resolve_status_trigger(trigger, store, context, rng, owner_role)
	_apply_runtime_effect_store(store)
	_write_runtime_arrays_to_store()
	return context


func apply_shields(incoming_damage: int, context: Dictionary) -> int:
	var store: Dictionary = _runtime_effect_store()
	var remaining: int = effect_resolver.apply_shields(store, incoming_damage, context)
	_apply_runtime_effect_store(store)
	_write_runtime_arrays_to_store()
	for event in context.get("events", []):
		if not (event is Dictionary):
			continue
		var event_type := str(event.get("type", ""))
		if event_type == "shield_absorbed" or event_type.begins_with("status_"):
			status_changed.emit(event.duplicate(true))
	return remaining


func tick_turn_start() -> Array:
	turn_serial += 1
	turn_active = true
	var events: Array = []
	for effect in combat_effects:
		if not (effect is Dictionary):
			continue
		var amount: int = int(effect.get("value", effect.get("amount", 0))) * maxi(1, int(effect.get("stacks", 1)))
		if amount <= 0:
			continue
		if int(effect.get("first_turn_serial", 1)) > turn_serial:
			continue
		match str(effect.get("kind", "")):
			"dot":
				var damage_affinity := DataTables.normalize_combat_affinity(str(effect.get("damage_affinity", DataTables.COMBAT_AFFINITY_NORMAL)))
				var affinity_relation := DataTables.combat_affinity_relation(damage_affinity, combat_affinity())
				var final_amount := DataTables.apply_combat_affinity_multiplier(amount, affinity_relation)
				events.append({"type": "status_tick", "actor_id": actor_id, "status": effect.duplicate(true), "amount": final_amount, "base_amount": amount, "damage_affinity": damage_affinity, "affinity_relation": affinity_relation})
				var damage_event := apply_damage(final_amount, str(effect.get("damage_type", "dot")), {
					"source": "dot",
					"status_id": str(effect.get("status_id", "")),
					"damage_affinity": damage_affinity,
					"target_affinity": combat_affinity(),
					"affinity_relation": affinity_relation,
				})
				var followup_events: Array = damage_event.get("followup_events", [])
				damage_event.erase("followup_events")
				events.append(damage_event)
				events.append_array(followup_events)
			"hot":
				events.append({"type": "status_tick", "actor_id": actor_id, "status": effect.duplicate(true), "amount": amount})
				events.append(apply_heal(amount))
	if not events.is_empty():
		combat_events_emitted.emit(events.duplicate(true))
	return events


func tick_turn_end() -> Array:
	var expired: Array = []
	_tick_duration_array(combat_buffs, expired)
	_tick_duration_array(combat_effects, expired)
	turn_active = false
	_write_runtime_arrays_to_store()
	var events: Array = []
	for effect in expired:
		var event := {"type": "status_removed", "reason": "expired", "actor_id": actor_id, "status": effect.duplicate(true)}
		events.append(event)
		status_changed.emit(event.duplicate(true))
	if not events.is_empty():
		combat_events_emitted.emit(events.duplicate(true))
	return events


func clear_status_effects(reason: String = "cleared") -> Array:
	var events: Array = []
	for effect in combat_effects:
		if effect is Dictionary:
			var event := {"type": "status_removed", "reason": reason, "actor_id": actor_id, "status": effect.duplicate(true)}
			events.append(event)
			status_changed.emit(event.duplicate(true))
	combat_effects.clear()
	combat_buffs.clear()
	_write_runtime_arrays_to_store()
	if not events.is_empty():
		combat_events_emitted.emit(events.duplicate(true))
	return events


func active_statuses() -> Array:
	return combat_effects.duplicate(true)


func spend_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if actor_kind != KIND_MEMBER or game_state == null:
		return true
	return game_state.spend_mp_for(member_id, amount)


func refund_mp(amount: int) -> void:
	if amount <= 0 or actor_kind != KIND_MEMBER or game_state == null:
		return
	game_state.heal_member(member_id, 0, amount)


func apply_damage(amount: int, damage_type: String = "physical", source: Dictionary = {}) -> Dictionary:
	var final_amount: int = max(0, amount)
	var stats: Dictionary = _stats()
	var old_hp: int = int(stats.get("hp", data.get("hp", 0)))
	var new_hp: int = max(0, old_hp - final_amount)
	_set_hp(new_hp)
	var result: Dictionary = {
		"type": "damage",
		"actor_id": actor_id,
		"actor_name": actor_name,
		"amount": final_amount,
		"damage_type": damage_type,
		"old_hp": old_hp,
		"new_hp": new_hp,
		"is_dead": new_hp <= 0,
		"source": source.duplicate(true),
	}
	if final_amount > 0:
		show_combat_popup(result)
		play_hit_reaction(result)
		hit_received.emit(final_amount, damage_type)
	var followup_events: Array = []
	if new_hp <= 0:
		state_machine.set_state(CombatActorStateMachineScript.STATE_DEAD)
		followup_events = clear_status_effects("death")
		defeated.emit(actor_id)
	if not followup_events.is_empty():
		result["followup_events"] = followup_events
	_sync_visual_data()
	return result


func apply_heal(amount: int) -> Dictionary:
	var final_amount: int = max(0, amount)
	var stats: Dictionary = _stats()
	var old_hp: int = int(stats.get("hp", data.get("hp", 0)))
	var new_hp: int = min(total_stat("max_hp"), old_hp + final_amount)
	_set_hp(new_hp)
	var healed: int = new_hp - old_hp
	var result: Dictionary = {
		"type": "heal",
		"actor_id": actor_id,
		"actor_name": actor_name,
		"amount": healed,
		"damage_type": "heal",
		"old_hp": old_hp,
		"new_hp": new_hp,
		"is_dead": false,
	}
	if healed > 0:
		show_combat_popup(result)
	_sync_visual_data()
	return result


func play_hit_reaction(_result: Dictionary) -> void:
	if visual_owner != null and visual_owner.has_method("play_hurt_feedback"):
		visual_owner.call("play_hurt_feedback")
		return
	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("play_hurt_feedback"):
		parent_node.call("play_hurt_feedback")


func show_combat_popup(result: Dictionary) -> void:
	var amount: int = int(result.get("amount", 0))
	if amount <= 0:
		return
	var damage_type: String = str(result.get("damage_type", "physical"))
	combat_popup_requested.emit(amount, combat_position() + popup_offset, actor_id, damage_type, damage_type == "heal")


func combat_position() -> Vector2:
	if not combat_store.is_empty() and combat_store.has("position"):
		return combat_store.get("position", Vector2.ZERO)
	if visual_owner != null:
		if visual_owner.has_method("combat_position"):
			return visual_owner.call("combat_position")
		if visual_owner is Node2D:
			return (visual_owner as Node2D).global_position
	if get_parent() is Node2D:
		return (get_parent() as Node2D).global_position
	return Vector2.ZERO


func is_alive() -> bool:
	return int(_stats().get("hp", data.get("hp", 0))) > 0


func _member_data() -> Dictionary:
	if game_state == null:
		return {}
	return game_state.member_by_id(member_id)


func _stats() -> Dictionary:
	if actor_kind == KIND_MEMBER:
		data = _member_data()
		return data.get("stats", {})
	return data


func _elements() -> Dictionary:
	if actor_kind == KIND_MEMBER:
		data = _member_data()
		return data.get("elements", {})
	return data.get("elements", {})


func _set_hp(value: int) -> void:
	if actor_kind == KIND_MEMBER:
		var member: Dictionary = _member_data()
		var stats: Dictionary = member.get("stats", {})
		stats["hp"] = value
		if game_state != null:
			game_state.changed.emit()
	else:
		data["hp"] = value


func _sync_runtime_arrays_from_store() -> void:
	if not combat_store.is_empty():
		combat_buffs = combat_store.get("combat_buffs", []).duplicate(true)
		combat_effects = combat_store.get("combat_effects", []).duplicate(true)
		skill_cooldowns = combat_store.get("skill_cooldowns", {}).duplicate(true)
		turn_serial = int(combat_store.get("turn_serial", 0))
		_status_sequence = int(combat_store.get("status_sequence", combat_effects.size()))
	elif actor_kind == KIND_ENEMY:
		combat_effects = data.get("combat_effects", []).duplicate(true)


func _write_runtime_arrays_to_store() -> void:
	if not combat_store.is_empty():
		combat_store["combat_buffs"] = combat_buffs
		combat_store["combat_effects"] = combat_effects
		combat_store["skill_cooldowns"] = skill_cooldowns
		combat_store["turn_serial"] = turn_serial
		combat_store["status_sequence"] = _status_sequence
	elif actor_kind == KIND_ENEMY:
		data["combat_effects"] = combat_effects


func _runtime_effect_store() -> Dictionary:
	return {"actor_id": actor_id, "combat_effects": combat_effects.duplicate(true)}


func _apply_runtime_effect_store(store: Dictionary) -> void:
	combat_effects = store.get("combat_effects", []).duplicate(true)


func _buff_stat_bonus(stat_id: String) -> int:
	var value: int = 0
	for buff in combat_buffs:
		if not (buff is Dictionary):
			continue
		if str(buff.get("stat", "")) == stat_id:
			value += int(buff.get("amount", buff.get("value", 0)))
	for effect in combat_effects:
		if not (effect is Dictionary):
			continue
		var kind: String = str(effect.get("kind", ""))
		if kind != "buff_stat" and kind != "debuff_stat":
			continue
		if str(effect.get("stat", "")) != stat_id:
			continue
		var amount: int = int(effect.get("value", effect.get("amount", 0))) * maxi(1, int(effect.get("stacks", 1)))
		if kind == "debuff_stat":
			value -= abs(amount)
		else:
			value += amount
	return value


func _tick_duration_array(values: Array, expired: Array) -> void:
	var index: int = 0
	while index < values.size():
		var item: Dictionary = values[index]
		if not item.has("remaining_turns"):
			index += 1
			continue
		if int(item.get("first_turn_serial", 1)) > turn_serial:
			index += 1
			continue
		item["remaining_turns"] = int(item.get("remaining_turns", 0)) - 1
		if int(item.get("remaining_turns", 0)) <= 0:
			expired.append(item.duplicate(true))
			values.remove_at(index)
		else:
			values[index] = item
			index += 1


func _sync_visual_data() -> void:
	if visual_owner != null and actor_kind == KIND_ENEMY and visual_owner.has_method("sync_data"):
		visual_owner.call("sync_data", data)


func _bind_presentation() -> void:
	if visual_owner != null and visual_owner.has_method("bind_combat_status_presentation"):
		visual_owner.call("bind_combat_status_presentation", self)
