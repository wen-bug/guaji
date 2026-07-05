class_name SkillSceneBase
extends Node2D

signal finished(result: Dictionary)

var caster: CombatActorStatus = null
var targets: Array = []
var skill_data: Dictionary = {}
var last_result: Dictionary = {}
var effect_resolver: CombatEffectResolver = null
var rng: RandomNumberGenerator = null


func setup(skill_caster: CombatActorStatus, skill_targets: Array, data: Dictionary, resolver: CombatEffectResolver = null, random_source: RandomNumberGenerator = null) -> void:
	caster = skill_caster
	targets = skill_targets
	skill_data = data.duplicate(true)
	last_result = {"events": [], "skill_id": str(skill_data.get("id", ""))}
	effect_resolver = resolver
	rng = random_source
	if caster != null and effect_resolver != null:
		caster.set_effect_resolver(effect_resolver)
	for target in targets:
		if target is CombatActorStatus and effect_resolver != null:
			(target as CombatActorStatus).set_effect_resolver(effect_resolver)


func start_cast() -> Dictionary:
	apply_marker(str(skill_data.get("start_marker", "impact")))
	finish_cast()
	return last_result


func apply_marker(_marker: String) -> void:
	pass


func finish_cast() -> void:
	finished.emit(last_result)


func primary_target() -> CombatActorStatus:
	if targets.is_empty():
		return null
	return targets[0]


func add_event(event: Dictionary) -> void:
	var events: Array = last_result.get("events", [])
	events.append(event)
	last_result["events"] = events


func attack_context(target: CombatActorStatus, base_damage: int, element_id: String) -> Dictionary:
	var hit_result: Dictionary = {}
	if effect_resolver != null:
		hit_result = effect_resolver.create_hit_result(caster.actor_id, target.actor_id, str(skill_data.get("type", "skill")), str(skill_data.get("id", "")))
	hit_result["base_damage"] = base_damage
	hit_result["element"] = element_id
	return {
		"hit_result": hit_result,
		"attacker_status": caster,
		"defender_status": target,
		"attacker_id": caster.actor_id,
		"defender_id": target.actor_id,
		"attacker_kind": caster.actor_kind,
		"defender_kind": target.actor_kind,
		"damage": maxi(0, base_damage),
		"base_damage": maxi(0, base_damage),
		"element": element_id,
		"defense_ignore": 0,
		"final_damage": 0,
		"blocked_by_shield": 0,
		"cooldown_multiplier": 1.0,
		"events": [],
		"applied_effects": [],
		"dealt_to_attacker": 0,
		"dealt_to_defender": 0,
		"healed": 0,
	}


func attack_effects() -> Array:
	var effects: Array = []
	effects.append_array(skill_data.get("effects", []))
	effects.append_array(skill_data.get("caster_static_effects", []))
	return effects


func defender_effects() -> Array:
	return skill_data.get("target_static_effects", [])


func resolve_static_trigger(trigger: String, context: Dictionary, effects: Array, owner_role: String) -> void:
	if effect_resolver == null:
		return
	effect_resolver.resolve_trigger(trigger, effects, context, rng, owner_role)


func resolve_actor_status_trigger(actor: CombatActorStatus, trigger: String, context: Dictionary, owner_role: String) -> void:
	if actor == null:
		return
	actor.resolve_status_trigger(trigger, context, rng, owner_role)


func apply_effect_events(context: Dictionary) -> void:
	var events: Array = context.get("events", [])
	context["events"] = []
	for event in events:
		if not (event is Dictionary):
			continue
		var actor: CombatActorStatus = _actor_for_role(context, str(event.get("target_role", "defender")))
		if actor == null:
			continue
		match str(event.get("kind", "")):
			"status":
				var effect_data = event.get("effect", {})
				if effect_data is Dictionary:
					actor.add_status_effect(effect_data)
			"damage":
				var effect_data: Dictionary = event.get("effect", {})
				var result: Dictionary = actor.apply_damage(int(event.get("amount", 0)), damage_type_from_element(str(effect_data.get("element", ""))), {"effect": effect_data.duplicate(true)})
				_add_context_damage(context, actor, int(result.get("amount", 0)))
				add_event(result)
			"heal":
				var result: Dictionary = actor.apply_heal(int(event.get("amount", 0)))
				context["healed"] = int(context.get("healed", 0)) + int(result.get("amount", 0))
				add_event(result)


func _actor_for_role(context: Dictionary, role: String) -> CombatActorStatus:
	match role:
		"attacker":
			return context.get("attacker_status", caster) as CombatActorStatus
		"defender":
			return context.get("defender_status", primary_target()) as CombatActorStatus
		"party_front":
			return primary_target()
		"party_all":
			return primary_target()
		_:
			return context.get("defender_status", primary_target()) as CombatActorStatus


func _add_context_damage(context: Dictionary, actor: CombatActorStatus, amount: int) -> void:
	if amount <= 0:
		return
	var key: String = "dealt_to_attacker" if actor == context.get("attacker_status", null) else "dealt_to_defender"
	context[key] = int(context.get(key, 0)) + amount


func damage_type_from_element(element_id: String) -> String:
	if element_id.is_empty():
		return "physical"
	return "element_%s" % element_id
