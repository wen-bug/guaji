class_name SkillSceneBase
extends Node2D

signal finished(result: Dictionary)

@export var frame_count := 0
@export var impact_frame := 0
@export var frames_per_second := 15.0
@export_enum("caster", "target") var anchor_role := "target"
@export var effect_offset := Vector2.ZERO

var caster: CombatActorStatus = null
var targets: Array = []
var skill_data: Dictionary = {}
var last_result: Dictionary = {}
var effect_resolver: CombatEffectResolver = null
var rng: RandomNumberGenerator = null
var _effect_sprite: AnimatedSprite2D = null
var _cast_active := false
var _cast_finished := false
var _marker_applied := false
var _current_frame := 0
var _frame_elapsed := 0.0


func _ready() -> void:
	_effect_sprite = get_node_or_null("EffectSprite") as AnimatedSprite2D
	set_process(false)


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


func start_cast() -> void:
	_cast_finished = false
	_marker_applied = false
	_current_frame = 0
	_frame_elapsed = 0.0
	if _effect_sprite == null:
		_effect_sprite = get_node_or_null("EffectSprite") as AnimatedSprite2D
	if _effect_sprite == null or _effect_sprite.sprite_frames == null or not _effect_sprite.sprite_frames.has_animation(&"cast") or frame_count <= 0:
		_apply_impact_marker()
		finish_cast()
		return
	_effect_sprite.animation = &"cast"
	_effect_sprite.stop()
	_effect_sprite.frame = 0
	_effect_sprite.visible = true
	global_position = _anchor_position() + effect_offset
	_cast_active = true
	set_process(true)
	if impact_frame <= 0:
		_apply_impact_marker()


func _process(delta: float) -> void:
	if not _cast_active:
		return
	var frame_duration := 1.0 / maxf(1.0, frames_per_second)
	_frame_elapsed += maxf(0.0, delta)
	while _frame_elapsed >= frame_duration and _cast_active:
		_frame_elapsed -= frame_duration
		if _current_frame >= frame_count - 1:
			finish_cast()
			return
		_current_frame += 1
		_effect_sprite.frame = _current_frame
		if _current_frame >= impact_frame:
			_apply_impact_marker()


func apply_marker(_marker: String) -> void:
	pass


func finish_cast() -> void:
	if _cast_finished:
		return
	_cast_finished = true
	_cast_active = false
	set_process(false)
	_apply_impact_marker()
	finished.emit(last_result.duplicate(true))


func _apply_impact_marker() -> void:
	if _marker_applied:
		return
	_marker_applied = true
	apply_marker(str(skill_data.get("start_marker", "impact")))


func _anchor_position() -> Vector2:
	var anchor: CombatActorStatus = caster if anchor_role == "caster" else primary_target()
	if anchor == null:
		return global_position
	if anchor.visual_owner != null and anchor.visual_owner.has_method("effect_position"):
		return anchor.visual_owner.call("effect_position")
	return anchor.combat_position()


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
