class_name CombatEffectResolver
extends RefCounted

const TRIGGERS := [
	"attack_start",
	"before_hit",
	"on_hit",
	"after_damage",
	"on_kill",
	"on_damaged",
	"turn_start",
	"turn_end",
]
const STATUS_KINDS := ["dot", "hot", "shield", "buff_stat", "debuff_stat"]
const COMBAT_KINDS := [
	"damage_percent",
	"damage_flat",
	"defense_ignore",
	"element_attach",
	"dot",
	"hot",
	"shield",
	"heal",
	"leech",
	"buff_stat",
	"debuff_stat",
	"cooldown_percent",
]


func create_hit_result(attacker_id: String, defender_id: String, source: String, skill_id: String = "") -> Dictionary:
	return {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"source": source,
		"skill_id": skill_id,
		"base_damage": 0,
		"final_damage": 0,
		"element": "",
		"damage_type": "physical",
		"is_hit": true,
		"is_critical": false,
		"is_kill": false,
		"applied_effects": [],
		"blocked_by_shield": 0,
		"healed": 0,
	}


func normalize_effects(raw_effects) -> Array:
	var result: Array = []
	if not (raw_effects is Array):
		return result
	for raw_effect in raw_effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect.duplicate(true)
		var kind: String = str(effect.get("kind", ""))
		var trigger: String = str(effect.get("trigger", ""))
		if kind.is_empty() or not COMBAT_KINDS.has(kind):
			continue
		if not trigger.is_empty() and not TRIGGERS.has(trigger):
			continue
		if not effect.has("target"):
			effect["target"] = _default_target_for_kind(kind)
		if not effect.has("value") and effect.has("amount"):
			effect["value"] = effect.get("amount", 0)
		result.append(effect)
	return result


func legacy_buffs_to_effects(buff_defs: Array, source_skill_id: String = "") -> Array:
	var result: Array = []
	for buff_def in buff_defs:
		if not (buff_def is Dictionary):
			continue
		var stat_id: String = str(buff_def.get("stat", ""))
		if stat_id.is_empty():
			continue
		result.append({
			"trigger": "attack_start",
			"kind": "buff_stat",
			"target": "self",
			"stat": stat_id,
			"value": int(buff_def.get("amount", 0)),
			"duration_turns": int(buff_def.get("turns", buff_def.get("remaining_turns", 1))),
			"source_skill_id": source_skill_id,
		})
	return result


func resolve_trigger(trigger: String, effects: Array, context: Dictionary, rng: RandomNumberGenerator, owner_role: String = "attacker") -> Dictionary:
	if not TRIGGERS.has(trigger):
		return context
	var normalized: Array = normalize_effects(effects)
	for effect in normalized:
		if str(effect.get("trigger", "")) != trigger:
			continue
		if not _chance_passed(effect, rng):
			continue
		_apply_effect(effect, trigger, context, owner_role)
	return context


func add_status_effect(target: Dictionary, effect: Dictionary) -> Dictionary:
	var status: Dictionary = _status_from_effect(effect)
	if status.is_empty():
		return {}
	var effects: Array = target.get("combat_effects", [])
	var stack_key: String = str(status.get("stack_key", ""))
	if not stack_key.is_empty():
		for index in range(effects.size()):
			var existing: Dictionary = effects[index]
			if str(existing.get("stack_key", "")) != stack_key:
				continue
			var max_stacks: int = maxi(1, int(status.get("max_stacks", existing.get("max_stacks", 1))))
			existing["stacks"] = mini(max_stacks, int(existing.get("stacks", 1)) + 1)
			existing["remaining_turns"] = max(int(existing.get("remaining_turns", 0)), int(status.get("remaining_turns", 0)))
			if existing.has("amount") and status.has("amount"):
				existing["amount"] = max(int(existing.get("amount", 0)), int(status.get("amount", 0)))
			effects[index] = existing
			target["combat_effects"] = effects
			return existing
	effects.append(status)
	target["combat_effects"] = effects
	return status


func apply_shields(target: Dictionary, incoming_damage: int, context: Dictionary) -> int:
	var remaining: int = maxi(0, incoming_damage)
	if remaining <= 0:
		return 0
	var effects: Array = target.get("combat_effects", [])
	for index in range(effects.size()):
		if remaining <= 0:
			break
		var effect: Dictionary = effects[index]
		if str(effect.get("kind", "")) != "shield":
			continue
		var shield_amount: int = int(effect.get("amount", effect.get("value", 0)))
		if shield_amount <= 0:
			continue
		var blocked: int = mini(shield_amount, remaining)
		shield_amount -= blocked
		remaining -= blocked
		context["blocked_by_shield"] = int(context.get("blocked_by_shield", 0)) + blocked
		effect["amount"] = shield_amount
		effect["value"] = shield_amount
		effects[index] = effect
	var write_index: int = 0
	while write_index < effects.size():
		var shield: Dictionary = effects[write_index]
		if str(shield.get("kind", "")) == "shield" and int(shield.get("amount", shield.get("value", 0))) <= 0:
			effects.remove_at(write_index)
		else:
			write_index += 1
	target["combat_effects"] = effects
	return remaining


func tick_turn_start(target: Dictionary) -> Array:
	var events: Array = []
	for effect in target.get("combat_effects", []):
		if not (effect is Dictionary):
			continue
		var stacks: int = maxi(1, int(effect.get("stacks", 1)))
		var amount: int = int(effect.get("value", effect.get("amount", 0))) * stacks
		match str(effect.get("kind", "")):
			"dot":
				if amount > 0:
					events.append({"kind": "damage", "amount": amount, "damage_type": "dot", "source_effect": effect.duplicate(true)})
			"hot":
				if amount > 0:
					events.append({"kind": "heal", "amount": amount, "damage_type": "heal", "source_effect": effect.duplicate(true)})
	return events


func tick_turn_end(target: Dictionary) -> Array:
	var expired: Array = []
	var effects: Array = target.get("combat_effects", [])
	var index: int = 0
	while index < effects.size():
		var effect: Dictionary = effects[index]
		if bool(effect.get("fresh", false)):
			effect.erase("fresh")
			effects[index] = effect
			index += 1
			continue
		if not effect.has("remaining_turns"):
			index += 1
			continue
		effect["remaining_turns"] = int(effect.get("remaining_turns", 0)) - 1
		if int(effect.get("remaining_turns", 0)) <= 0:
			expired.append(effect.duplicate(true))
			effects.remove_at(index)
		else:
			effects[index] = effect
			index += 1
	target["combat_effects"] = effects
	return expired


func stat_bonus_from_effects(effects: Array, stat_id: String) -> int:
	var value: int = 0
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var kind: String = str(effect.get("kind", ""))
		if kind != "buff_stat" and kind != "debuff_stat":
			continue
		if str(effect.get("stat", "")) != stat_id:
			continue
		var stacks: int = maxi(1, int(effect.get("stacks", 1)))
		var amount: int = int(effect.get("value", effect.get("amount", 0))) * stacks
		if kind == "debuff_stat":
			amount = -abs(amount)
		value += amount
	return value


func _apply_effect(effect: Dictionary, trigger: String, context: Dictionary, owner_role: String) -> void:
	var kind: String = str(effect.get("kind", ""))
	match kind:
		"damage_percent":
			if ["on_hit", "after_damage", "on_damaged", "on_kill"].has(trigger):
				_add_event(context, effect, owner_role, "damage", _percent_amount(int(context.get("final_damage", 0)), float(effect.get("value", 0.0))))
			else:
				context["damage"] = max(0, int(floor(float(context.get("damage", 0)) * (1.0 + float(effect.get("value", 0.0))))))
		"damage_flat":
			if ["on_hit", "after_damage", "on_damaged", "on_kill"].has(trigger):
				_add_event(context, effect, owner_role, "damage", int(effect.get("value", effect.get("amount", 0))))
			else:
				context["damage"] = max(0, int(context.get("damage", 0)) + int(effect.get("value", effect.get("amount", 0))))
		"defense_ignore":
			context["defense_ignore"] = int(context.get("defense_ignore", 0)) + int(effect.get("value", effect.get("amount", 0)))
		"element_attach":
			var element_id: String = str(effect.get("element", effect.get("value", "")))
			if not element_id.is_empty():
				context["element"] = element_id
		"cooldown_percent":
			context["cooldown_multiplier"] = float(context.get("cooldown_multiplier", 1.0)) * max(0.0, 1.0 - float(effect.get("value", 0.0)))
		"dot", "hot", "shield", "buff_stat", "debuff_stat":
			_add_event(context, effect, owner_role, "status", 0)
		"heal":
			_add_event(context, effect, owner_role, "heal", int(effect.get("value", effect.get("amount", 0))))
		"leech":
			var final_damage: int = int(context.get("final_damage", 0))
			if final_damage > 0:
				var amount: int = _percent_amount(final_damage, float(effect.get("value", effect.get("amount", 0.0))))
				_add_event(context, effect, "attacker", "heal", amount)
	if not kind.is_empty():
		var applied: Array = context.get("applied_effects", [])
		applied.append(effect.duplicate(true))
		context["applied_effects"] = applied


func _add_event(context: Dictionary, effect: Dictionary, owner_role: String, event_kind: String, amount: int) -> void:
	if event_kind != "status" and amount <= 0:
		return
	var events: Array = context.get("events", [])
	events.append({
		"kind": event_kind,
		"amount": amount,
		"target_role": _target_role(effect, owner_role),
		"effect": effect.duplicate(true),
	})
	context["events"] = events


func _target_role(effect: Dictionary, owner_role: String) -> String:
	var target: String = str(effect.get("target", "self"))
	match target:
		"self":
			return owner_role
		"enemy":
			return "defender" if owner_role == "attacker" else "attacker"
		"attacker":
			return "attacker"
		"defender":
			return "defender"
		"party_front":
			return "party_front"
		"party_all":
			return "party_all"
		_:
			return owner_role


func _status_from_effect(effect: Dictionary) -> Dictionary:
	var kind: String = str(effect.get("kind", ""))
	if not STATUS_KINDS.has(kind):
		return {}
	var status: Dictionary = effect.duplicate(true)
	status["kind"] = kind
	if kind == "dot" or kind == "hot":
		status["trigger"] = "turn_start"
	else:
		status.erase("trigger")
	status["value"] = int(status.get("value", status.get("amount", 0)))
	if kind == "shield":
		status["amount"] = int(status.get("amount", status.get("value", 0)))
	if kind == "debuff_stat":
		status["value"] = abs(int(status.get("value", status.get("amount", 0))))
	if status.has("duration_turns") and not status.has("remaining_turns"):
		status["remaining_turns"] = int(status.get("duration_turns", 1))
	if not status.has("remaining_turns") and kind != "shield":
		status["remaining_turns"] = 1
	if ["buff_stat", "debuff_stat", "shield"].has(kind):
		status["fresh"] = true
	if not status.has("stacks"):
		status["stacks"] = 1
	return status


func _chance_passed(effect: Dictionary, rng: RandomNumberGenerator) -> bool:
	if not effect.has("chance"):
		return true
	var chance: float = clamp(float(effect.get("chance", 1.0)), 0.0, 1.0)
	if chance >= 1.0:
		return true
	if rng == null:
		return chance > 0.0
	return rng.randf() <= chance


func _percent_amount(base_amount: int, value: float) -> int:
	if value > 0.0 and value <= 1.0:
		return int(floor(float(base_amount) * value))
	return int(value)


func _default_target_for_kind(kind: String) -> String:
	match kind:
		"dot", "debuff_stat":
			return "enemy"
		"heal", "hot", "shield", "buff_stat", "leech", "cooldown_percent":
			return "self"
		_:
			return "enemy"
