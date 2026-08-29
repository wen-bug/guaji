class_name SkillSceneBase
extends Node2D

signal finished(result: Dictionary)
signal combat_events_emitted(events: Array)
signal impact_resolved(impact_id: StringName, result: Dictionary)

const CombatSkillExecutorScript = preload("res://scripts/game/combat/combat_skill_executor.gd")
const SkillHitboxDebugDrawerScript = preload("res://scripts/game/skills/base/skill_hitbox_debug_drawer.gd")
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
var _skill_hitbox: Area2D
var _skill_executor = CombatSkillExecutorScript.new()
var _hit_actor_ids: Dictionary = {}
var _candidate_by_id: Dictionary = {}
var _cast_active := false
var _cast_finished := false
var _impact_applied := false
var _resolved_impact_ids: Dictionary = {}
var _current_impact_id := StringName()
var _hitbox_window_open := false
var _hitbox_drawer: Node2D
var _material_visuals: Array[CanvasItem] = []


func _ready() -> void:
	_bind_scene_nodes()
	_bind_presentation_mode()
	_sync_presentation_mode()


func start_cast(cast_context: SkillCastContext) -> void:
	context = cast_context
	_cast_active = true
	_cast_finished = false
	_impact_applied = false
	_resolved_impact_ids.clear()
	_current_impact_id = StringName()
	_hitbox_window_open = false
	_hit_actor_ids.clear()
	_candidate_by_id.clear()
	last_result = _empty_result(false)
	if context == null or context.caster == null:
		_abort_cast("技能施法上下文无效")
		return
	for candidate in context.ordered_candidates:
		if candidate is CombatActorStatus:
			_candidate_by_id[(candidate as CombatActorStatus).actor_id] = candidate
	_bind_resolvers()
	_bind_scene_nodes()
	var errors := contract_errors()
	if not errors.is_empty():
		_abort_cast("；".join(errors))
		return
	global_position = _anchor_position() + effect_offset
	_configure_projectile_paths()
	_sync_presentation_mode()
	_animation_player.play(&"cast")


func open_hitbox(impact_id: StringName = &"impact") -> void:
	if not _cast_active or _skill_hitbox == null:
		return
	if _hitbox_window_open:
		_abort_cast("open_hitbox() 不能嵌套开启碰撞窗口")
		return
	if str(impact_id).strip_edges().is_empty():
		_abort_cast("open_hitbox() 的 impact_id 不能为空")
		return
	_hit_actor_ids.clear()
	_current_impact_id = impact_id
	_hitbox_window_open = true
	_skill_hitbox.monitoring = true
	_sync_presentation_mode()
	call_deferred("_collect_overlaps")


func close_hitbox() -> void:
	if _skill_hitbox != null:
		_skill_hitbox.set_deferred("monitoring", false)
	_hitbox_window_open = false
	_current_impact_id = StringName()
	_sync_presentation_mode()


func impact(impact_id: StringName = &"") -> void:
	if not _cast_active or context == null or context.caster == null:
		return
	var resolved_impact_id := impact_id
	if str(resolved_impact_id).is_empty():
		resolved_impact_id = _current_impact_id if not str(_current_impact_id).is_empty() else &"impact"
	if _resolved_impact_ids.has(str(resolved_impact_id)):
		push_error("技能场景重复结算 impact [%s:%s]" % [_skill_id(), resolved_impact_id])
		return
	if _skill_hitbox != null:
		if not _hitbox_window_open:
			_abort_cast("碰撞技能的 impact(%s) 不在有效窗口内" % resolved_impact_id)
			return
		if _current_impact_id != resolved_impact_id:
			_abort_cast("impact(%s) 与当前碰撞窗口 %s 不一致" % [resolved_impact_id, _current_impact_id])
			return
		_collect_overlaps()
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
	if _cast_active and _hitbox_window_open:
		_abort_cast("finish_cast() 前必须关闭碰撞窗口")
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
	close_hitbox()
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
	var hitboxes: Array[Area2D] = []
	_find_skill_hitboxes(self, hitboxes)
	if hitboxes.size() > 1:
		errors.append("当前技能场景只能包含一个名为 SkillHitbox 的 Area2D")
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
	var declared_impacts := _declared_animation_impacts(root_calls, _skill_hitbox != null, errors)
	for required_id in _required_impact_ids():
		if not declared_impacts.has(required_id):
			errors.append("效果 impact_id %s 没有对应的 impact() 关键帧" % required_id)
	if _skill_hitbox != null:
		if not methods.has(&"open_hitbox") or not methods.has(&"close_hitbox"):
			errors.append("包含 SkillHitbox 时必须绑定 open_hitbox() 和 close_hitbox()")
		if _animation_player.callback_mode_process != AnimationPlayer.ANIMATION_PROCESS_PHYSICS:
			errors.append("包含 SkillHitbox 时 AnimationPlayer 处理模式必须为 Physics")
		if not _has_collision_shape(_skill_hitbox):
			errors.append("SkillHitbox 缺少手工创建的 CollisionShape2D")
		for shape_node in _collision_shapes(_skill_hitbox):
			if not _is_supported_debug_shape(shape_node.shape):
				errors.append("SkillHitbox 包含不支持可视化的形状 %s" % shape_node.shape.get_class())
	var projectile_paths: Array[SkillProjectilePath] = []
	_find_projectile_paths(self, projectile_paths)
	if not projectile_paths.is_empty():
		for projectile_path in projectile_paths:
			var projectile_hitboxes: Array[Area2D] = []
			_find_skill_hitboxes(projectile_path, projectile_hitboxes)
			if projectile_hitboxes.is_empty():
				errors.append("SkillProjectilePath 必须包含自己的 SkillHitbox")
		if not _animation_has_property(animation, &"flight_progress"):
			errors.append("弹道 cast 动画必须包含 flight_progress 属性轨道")
	return errors


func accepts_skill_type(_skill_type: String) -> bool:
	return true


func primary_target() -> CombatActorStatus:
	if context == null or context.selected_targets.is_empty():
		return null
	return context.selected_targets[0] as CombatActorStatus


func _bind_scene_nodes() -> void:
	_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	var hitboxes: Array[Area2D] = []
	_find_skill_hitboxes(self, hitboxes)
	_skill_hitbox = hitboxes[0] if not hitboxes.is_empty() else null
	if _animation_player != null and not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)
	if _skill_hitbox != null:
		_skill_hitbox.monitoring = false
		_skill_hitbox.monitorable = false
		_skill_hitbox.collision_layer = 0
		if not _skill_hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			_skill_hitbox.area_entered.connect(_on_hitbox_area_entered)
	_bind_material_visuals()
	_ensure_hitbox_drawer()


func _bind_presentation_mode() -> void:
	var settings := get_node_or_null("/root/SkillPresentation")
	if settings == null or not settings.has_signal("mode_changed"):
		return
	var callback := Callable(self, "_on_presentation_mode_changed")
	if not settings.is_connected("mode_changed", callback):
		settings.connect("mode_changed", callback)


func _bind_material_visuals() -> void:
	_material_visuals.clear()
	_find_material_visuals(self)
	var fallback := get_node_or_null("EffectSprite") as CanvasItem
	if fallback != null and not _material_visuals.has(fallback):
		_material_visuals.append(fallback)
	for visual in _material_visuals:
		if not visual.has_meta("skill_material_visibility_layer"):
			visual.set_meta("skill_material_visibility_layer", visual.visibility_layer)


func _find_material_visuals(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem and child.is_in_group("skill_material_visual"):
			_material_visuals.append(child as CanvasItem)
		_find_material_visuals(child)


func _ensure_hitbox_drawer() -> void:
	if _skill_hitbox == null or _hitbox_drawer != null:
		return
	_hitbox_drawer = SkillHitboxDebugDrawerScript.new()
	_hitbox_drawer.name = "SkillHitboxDebugDrawer"
	add_child(_hitbox_drawer)
	_hitbox_drawer.setup(_skill_hitbox, _targets_allies())


func _sync_presentation_mode() -> void:
	var hitbox_mode := _is_hitbox_mode()
	for visual in _material_visuals:
		if visual != null and is_instance_valid(visual):
			visual.visibility_layer = 0 if hitbox_mode else int(visual.get_meta("skill_material_visibility_layer", 1))
	if _hitbox_drawer != null:
		_hitbox_drawer.visible = hitbox_mode and _hitbox_window_open
		_hitbox_drawer.queue_redraw()


func _on_presentation_mode_changed(_mode: StringName) -> void:
	_sync_presentation_mode()


func _is_hitbox_mode() -> bool:
	var settings := get_node_or_null("/root/SkillPresentation")
	return settings != null and settings.has_method("is_hitbox_mode") and bool(settings.call("is_hitbox_mode"))


func _targets_allies() -> bool:
	if context != null:
		return str(context.skill_data.get("target_scope", "")) in ["self", "single_ally", "all_allies"]
	return skill_resource != null and skill_resource.target_scope in ["self", "single_ally", "all_allies"]


func _bind_resolvers() -> void:
	if context.caster != null and context.effect_resolver != null:
		context.caster.set_effect_resolver(context.effect_resolver)
	for candidate in context.ordered_candidates:
		if candidate is CombatActorStatus and context.effect_resolver != null:
			(candidate as CombatActorStatus).set_effect_resolver(context.effect_resolver)
	if _skill_hitbox == null:
		return
	var scope := str(context.skill_data.get("target_scope", "single_enemy"))
	var target_allies := scope in ["self", "single_ally", "all_allies"]
	var caster_is_party := context.caster.actor_kind == CombatActorStatus.KIND_MEMBER
	if target_allies:
		_skill_hitbox.collision_mask = CombatHurtbox.PARTY_LAYER if caster_is_party else CombatHurtbox.ENEMY_LAYER
	else:
		_skill_hitbox.collision_mask = CombatHurtbox.ENEMY_LAYER if caster_is_party else CombatHurtbox.PARTY_LAYER


func _targets_for_impact() -> Array:
	if _skill_hitbox == null:
		return context.selected_targets.duplicate()
	var result: Array = []
	for candidate in context.ordered_candidates:
		if candidate is CombatActorStatus and _hit_actor_ids.has((candidate as CombatActorStatus).actor_id):
			result.append(candidate)
	return result


func _collect_overlaps() -> void:
	if _skill_hitbox == null or not _skill_hitbox.monitoring:
		return
	for area in _skill_hitbox.get_overlapping_areas():
		_collect_hurtbox(area)


func _on_hitbox_area_entered(area: Area2D) -> void:
	_collect_hurtbox(area)


func _collect_hurtbox(area: Area2D) -> void:
	if not _cast_active or _skill_hitbox == null or not _skill_hitbox.monitoring or not (area is CombatHurtbox):
		return
	var actor_id := (area as CombatHurtbox).actor_id
	if _candidate_by_id.has(actor_id):
		_hit_actor_ids[actor_id] = true


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
	close_hitbox()
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


func _configure_projectile_paths() -> void:
	var projectile_paths: Array[SkillProjectilePath] = []
	_find_projectile_paths(self, projectile_paths)
	if projectile_paths.is_empty() or context == null or context.caster == null:
		return
	var target := primary_target()
	var start_position := _actor_anchor_position(context.caster, "effect_position")
	var end_position := _actor_anchor_position(target, "hit_position") if target != null else start_position
	for projectile_path in projectile_paths:
		projectile_path.configure_path(start_position, end_position)


func _actor_anchor_position(actor: CombatActorStatus, method_name: String) -> Vector2:
	if actor == null:
		return global_position
	if actor.visual_owner != null and actor.visual_owner.has_method(method_name):
		return actor.visual_owner.call(method_name)
	return actor.combat_position()


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


func _declared_animation_impacts(calls: Array[Dictionary], has_hitbox: bool, errors: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var active_window := ""
	var active_window_open_time := 0.0
	var finish_seen := false
	for method_call in calls:
		var method := str(method_call.get("method", ""))
		var args: Array = method_call.get("args", [])
		var call_time := float(method_call.get("time", 0.0))
		if finish_seen:
			errors.append("finish_cast() 后不能再绑定 %s()" % method)
		match method:
			"open_hitbox":
				if not has_hitbox:
					errors.append("没有 SkillHitbox 时不能绑定 open_hitbox()")
				if not active_window.is_empty():
					errors.append("碰撞窗口不能嵌套")
				active_window = str(args[0]) if not args.is_empty() else "impact"
				active_window_open_time = call_time
				if active_window.is_empty():
					errors.append("open_hitbox() 的 impact_id 不能为空")
			"impact":
				var impact_id := str(args[0]) if not args.is_empty() and not str(args[0]).is_empty() else active_window if not active_window.is_empty() else "impact"
				if has_hitbox and active_window.is_empty():
					errors.append("碰撞技能的 impact(%s) 必须位于 open/close 窗口内" % impact_id)
				if has_hitbox and not active_window.is_empty() and impact_id != active_window:
					errors.append("impact(%s) 与碰撞窗口 %s 不一致" % [impact_id, active_window])
				if has_hitbox and not active_window.is_empty() and call_time - active_window_open_time < 1.0 / float(Engine.physics_ticks_per_second):
					errors.append("碰撞窗口 %s 必须在 impact() 前至少开启一个物理帧" % active_window)
				if result.has(impact_id):
					errors.append("静态 impact_id %s 只能结算一次" % impact_id)
				else:
					result.append(impact_id)
			"close_hitbox":
				if has_hitbox and active_window.is_empty():
					errors.append("close_hitbox() 前没有开启碰撞窗口")
				active_window = ""
			"finish_cast":
				if finish_seen:
					errors.append("finish_cast() 只能绑定一次")
				if not active_window.is_empty():
					errors.append("finish_cast() 前必须关闭碰撞窗口")
				finish_seen = true
			_:
				errors.append("cast 方法轨道不允许调用 %s()" % method)
	if not active_window.is_empty():
		errors.append("cast 结束时碰撞窗口仍处于开启状态")
	return result


func _find_skill_hitboxes(node: Node, result: Array[Area2D]) -> void:
	for child in node.get_children():
		if child.name == &"SkillHitbox" and child is Area2D:
			result.append(child as Area2D)
		_find_skill_hitboxes(child, result)


func _find_projectile_paths(node: Node, result: Array[SkillProjectilePath]) -> void:
	for child in node.get_children():
		if child is SkillProjectilePath:
			result.append(child as SkillProjectilePath)
		_find_projectile_paths(child, result)


func _animation_has_property(animation: Animation, property_name: StringName) -> bool:
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_VALUE:
			continue
		var track_path: NodePath = animation.track_get_path(track_index)
		if track_path.get_subname_count() > 0 and track_path.get_subname(track_path.get_subname_count() - 1) == property_name:
			return true
	return false


func _has_collision_shape(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			return true
		if _has_collision_shape(child):
			return true
	return false


func _collision_shapes(node: Node) -> Array[CollisionShape2D]:
	var result: Array[CollisionShape2D] = []
	for child in node.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			result.append(child as CollisionShape2D)
		result.append_array(_collision_shapes(child))
	return result


func _is_supported_debug_shape(shape: Shape2D) -> bool:
	return shape is RectangleShape2D or shape is CircleShape2D or shape is CapsuleShape2D or shape is ConvexPolygonShape2D


func _contains_status_visual(node: Node) -> bool:
	for child in node.get_children():
		if child is StatusVisualBase or _contains_status_visual(child):
			return true
	return false
