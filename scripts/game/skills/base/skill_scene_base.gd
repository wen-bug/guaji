class_name SkillSceneBase
extends Node2D

signal finished(result: Dictionary)
signal combat_events_emitted(events: Array)
signal impact_resolved(impact_id: StringName, result: Dictionary)

const CombatSkillExecutorScript = preload("res://scripts/game/combat/combat_skill_executor.gd")
const STATUS_ANIMATION_NAMES: Array[StringName] = [
	&"apply", &"refresh", &"stack", &"loop", &"tick", &"absorb", &"break", &"remove",
]

@export_group("技能资源")
## 此场景对应的技能定义；正式技能必须绑定，未绑定的场景会被视为模板并忽略。
@export var skill_resource: SkillDef

@export_group("表现定位")
## auto 根据目标范围定位；也可强制挂到施法者或首个预选目标。
@export_enum("auto", "caster", "primary_target") var anchor_role := "auto"
## 场景根节点相对战斗角色效果锚点的像素偏移。
@export var effect_offset := Vector2.ZERO

var last_result: Dictionary = {}
var context: SkillCastContext

var _animation_player: AnimationPlayer
var _skill_executor = CombatSkillExecutorScript.new()
var _cast_active := false
var _cast_finished := false
var _impact_applied := false
var _resolved_impact_ids: Dictionary = {}


func _ready() -> void:
	_bind_scene_nodes()


func start_cast(cast_context: SkillCastContext) -> void:
	context = cast_context
	_cast_active = true
	_cast_finished = false
	_impact_applied = false
	_resolved_impact_ids.clear()
	last_result = _empty_result(false)
	if context == null or context.caster == null:
		_abort_cast("技能施法上下文无效")
		return
	_bind_resolvers()
	_bind_scene_nodes()
	var errors := contract_errors()
	if not errors.is_empty():
		_abort_cast("；".join(errors))
		return
	global_position = _anchor_position() + effect_offset
	global_position.x += effect_offset.x * float(context.facing_direction - 1)
	scale.x = absf(scale.x) * float(context.facing_direction)
	_animation_player.play(&"cast")


func open_hitbox(impact_id: StringName = &"impact") -> void:
	# Legacy API 2 compatibility: logical targeting no longer uses physical windows.
	if str(impact_id).strip_edges().is_empty():
		return


func close_hitbox() -> void:
	# Legacy API 2 compatibility: intentionally no-op.
	pass


func impact(impact_id: StringName = &"") -> void:
	if not _cast_active or context == null or context.caster == null:
		return
	var resolved_impact_id := impact_id
	if str(resolved_impact_id).is_empty():
		resolved_impact_id = &"impact"
	if _resolved_impact_ids.has(str(resolved_impact_id)):
		push_error("技能场景重复结算 impact [%s:%s]" % [_skill_id(), resolved_impact_id])
		return
	if not _required_impact_ids().has(str(resolved_impact_id)):
		_abort_cast("impact(%s) 没有对应效果" % resolved_impact_id)
		return
	_impact_applied = true
	_resolved_impact_ids[str(resolved_impact_id)] = true
	var impact_result: Dictionary = _skill_executor.execute_impact(
		context.caster,
		_targets_for_impact(),
		context.skill_data,
		resolved_impact_id,
		context.effect_resolver,
		context.rng
	)
	_merge_impact_result(impact_result)
	last_result["cast_succeeded"] = true
	impact_resolved.emit(resolved_impact_id, impact_result.duplicate(true))
	var events: Array = impact_result.get("events", [])
	if not events.is_empty():
		combat_events_emitted.emit(events.duplicate(true))


func finish_cast() -> void:
	if _cast_finished:
		return
	if _cast_active:
		var missing_impacts: Array[String] = []
		for required_id in _required_impact_ids():
			if not _resolved_impact_ids.has(required_id):
				missing_impacts.append(required_id)
		if not missing_impacts.is_empty():
			_abort_cast("finish_cast() 前缺少 impact: %s" % ", ".join(missing_impacts))
			return
	_cast_finished = true
	_cast_active = false
	finished.emit(last_result.duplicate(true))


func contract_errors() -> Array[String]:
	_bind_scene_nodes()
	var errors: Array[String] = []
	if skill_resource == null:
		errors.append("根节点未绑定 skill_resource")
		return errors
	if not accepts_skill_type(skill_resource.type):
		errors.append("技能类型 %s 与根脚本 %s 不匹配" % [skill_resource.type, get_script().resource_path.get_file()])
	if _animation_player == null:
		errors.append("缺少名为 AnimationPlayer 的节点")
		return errors
	if not _animation_player.has_animation(&"RESET"):
		errors.append("AnimationPlayer 缺少 RESET 动画")
	if not _animation_player.has_animation(&"cast"):
		errors.append("AnimationPlayer 缺少 cast 动画")
		return errors
	var animation := _animation_player.get_animation(&"cast")
	for status_animation in STATUS_ANIMATION_NAMES:
		if _animation_player.has_animation(status_animation):
			errors.append("释放场景不能包含持续状态动画 %s" % status_animation)
	if _contains_status_visual(self):
		errors.append("释放场景不能挂载 StatusVisualBase")
	if animation.loop_mode != Animation.LOOP_NONE:
		errors.append("cast 动画不能循环")
	if _animation_player.callback_mode_method != AnimationPlayer.ANIMATION_METHOD_CALL_IMMEDIATE:
		errors.append("AnimationPlayer 方法回调模式必须为 Immediate")
	var calls := _animation_method_calls(animation)
	var root_calls: Array[Dictionary] = []
	for method_call in calls:
		if str(method_call.get("target_path", "")) in ["", "."]:
			root_calls.append(method_call)
	var methods: Array[StringName] = []
	for method_call in root_calls:
		methods.append(StringName(method_call.get("method", "")))
	if not methods.has(&"impact"):
		errors.append("cast 方法轨道缺少 impact()")
	if not methods.has(&"finish_cast"):
		errors.append("cast 方法轨道缺少 finish_cast()")
	var declared_impacts := _declared_animation_impacts(root_calls, errors)
	for required_id in _required_impact_ids():
		if not declared_impacts.has(required_id):
			errors.append("效果 impact_id %s 没有对应的 impact() 关键帧" % required_id)
	return errors


func accepts_skill_type(_skill_type: String) -> bool:
	return true


func primary_target() -> CombatActorStatus:
	if context != null and context.anchor_target != null:
		return context.anchor_target
	if context == null or context.selected_targets.is_empty():
		return null
	return context.selected_targets[0] as CombatActorStatus


func _bind_scene_nodes() -> void:
	_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _animation_player != null and not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)


func _bind_resolvers() -> void:
	if context.caster != null and context.effect_resolver != null:
		context.caster.set_effect_resolver(context.effect_resolver)
	for candidate in context.ordered_candidates:
		if candidate is CombatActorStatus and context.effect_resolver != null:
			(candidate as CombatActorStatus).set_effect_resolver(context.effect_resolver)


func _targets_for_impact() -> Array:
	var result: Array = []
	var candidates := context.selected_targets if context != null else []
	if candidates.is_empty() and context != null:
		candidates = context.ordered_candidates
	for candidate in candidates:
		if candidate is CombatActorStatus and (candidate as CombatActorStatus).is_alive():
			result.append(candidate)
	return result


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"cast" and _cast_active and not _cast_finished:
		_abort_cast("cast 动画结束前未调用 finish_cast()")


func _abort_cast(reason: String) -> void:
	if _cast_finished:
		return
	push_error("技能场景配置错误 [%s]: %s" % [_skill_id(), reason])
	if not _impact_applied:
		last_result = _empty_result(false)
	else:
		last_result["cast_succeeded"] = true
		last_result["partial_cast"] = true
	last_result["error"] = reason
	_cast_finished = true
	_cast_active = false
	finished.emit(last_result.duplicate(true))


func _empty_result(succeeded: bool) -> Dictionary:
	return {
		"skill_id": _skill_id(),
		"events": [],
		"damage": 0,
		"heal": 0,
		"blocked_by_shield": 0,
		"cooldown_multiplier": 1.0,
		"applied_effects": [],
		"target_ids": [],
		"target_results": [],
		"cast_succeeded": succeeded,
	}


func _required_impact_ids() -> Array[String]:
	var result: Array[String] = []
	var effects: Array = context.skill_data.get("effects", []) if context != null else skill_resource.effects if skill_resource != null else []
	for raw_effect in effects:
		var impact_id := "impact"
		if raw_effect is Dictionary:
			impact_id = str(raw_effect.get("impact_id", "impact"))
		elif raw_effect is SkillEffectDef:
			impact_id = str((raw_effect as SkillEffectDef).impact_id)
		if not impact_id.is_empty() and not result.has(impact_id):
			result.append(impact_id)
	return result


func _merge_impact_result(impact_result: Dictionary) -> void:
	for key in ["damage", "heal", "blocked_by_shield"]:
		last_result[key] = int(last_result.get(key, 0)) + int(impact_result.get(key, 0))
	last_result["cooldown_multiplier"] = float(last_result.get("cooldown_multiplier", 1.0)) * float(impact_result.get("cooldown_multiplier", 1.0))
	for key in ["events", "applied_effects"]:
		var merged: Array = last_result.get(key, [])
		merged.append_array((impact_result.get(key, []) as Array).duplicate(true))
		last_result[key] = merged
	var target_ids: Array = last_result.get("target_ids", [])
	for actor_id in impact_result.get("target_ids", []):
		if not target_ids.has(actor_id):
			target_ids.append(actor_id)
	last_result["target_ids"] = target_ids
	var target_results: Array = last_result.get("target_results", [])
	for raw_entry in impact_result.get("target_results", []):
		if not (raw_entry is Dictionary):
			continue
		var incoming: Dictionary = raw_entry
		var actor_id := str(incoming.get("target_id", ""))
		var found := false
		for index in range(target_results.size()):
			if str(target_results[index].get("target_id", "")) != actor_id:
				continue
			for key in incoming:
				if key in ["damage", "heal", "blocked_by_shield"]:
					target_results[index][key] = int(target_results[index].get(key, 0)) + int(incoming.get(key, 0))
				elif key != "target_id":
					target_results[index][key] = incoming[key]
			found = true
			break
		if not found:
			target_results.append(incoming.duplicate(true))
	last_result["target_results"] = target_results
	if not target_ids.is_empty():
		last_result["target_id"] = str(target_ids[0])


func _skill_id() -> String:
	if context != null:
		return str(context.skill_data.get("id", ""))
	return skill_resource.id if skill_resource != null else ""


func _anchor_position() -> Vector2:
	var resolved_role := anchor_role
	if resolved_role == "auto":
		resolved_role = "caster" if str(context.skill_data.get("target_scope", "")) == "self" else "primary_target"
	var anchor: CombatActorStatus = context.caster if resolved_role == "caster" else primary_target()
	if anchor == null:
		return global_position
	if anchor.visual_owner != null and anchor.visual_owner.has_method("effect_position"):
		return anchor.visual_owner.call("effect_position")
	return anchor.combat_position()


func _animation_method_calls(animation: Animation) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var order := 0
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_METHOD:
			continue
		var target_path: NodePath = animation.track_get_path(track_index)
		for key_index in range(animation.track_get_key_count(track_index)):
			var key = animation.track_get_key_value(track_index, key_index)
			if key is Dictionary:
				result.append({
					"method": StringName(key.get("method", "")),
					"args": (key.get("args", []) as Array).duplicate(true),
					"time": animation.track_get_key_time(track_index, key_index),
					"order": order,
					"target_path": str(target_path),
				})
				order += 1
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.get("time", 0.0)), float(b.get("time", 0.0))):
			return int(a.get("order", 0)) < int(b.get("order", 0))
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	return result


func _declared_animation_impacts(calls: Array[Dictionary], errors: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var finish_seen := false
	for method_call in calls:
		var method := str(method_call.get("method", ""))
		var args: Array = method_call.get("args", [])
		if finish_seen:
			errors.append("finish_cast() 后不能再绑定 %s()" % method)
		match method:
			"open_hitbox":
				pass
			"impact":
				var impact_id := str(args[0]) if not args.is_empty() and not str(args[0]).is_empty() else "impact"
				if result.has(impact_id):
					errors.append("静态 impact_id %s 只能结算一次" % impact_id)
				else:
					result.append(impact_id)
			"close_hitbox":
				pass
			"finish_cast":
				if finish_seen:
					errors.append("finish_cast() 只能绑定一次")
				finish_seen = true
			_:
				errors.append("cast 方法轨道不允许调用 %s()" % method)
	return result


func _contains_status_visual(node: Node) -> bool:
	for child in node.get_children():
		if child is StatusVisualBase or _contains_status_visual(child):
			return true
	return false
