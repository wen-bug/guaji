extends Node

const STATUS_SKILLS := {
	"poison": "res://scripts/game/skills/status/visuals/poison.tscn",
	"wolf_bleed": "res://scripts/game/skills/status/visuals/bleed.tscn",
	"attack_up": "res://scripts/game/skills/status/visuals/attack_up.tscn",
	"wolf_howl": "res://scripts/game/skills/status/visuals/wolf_howl.tscn",
	"spirit_shield": "res://scripts/game/skills/status/visuals/spirit_shield.tscn",
}

var failures: Array[String] = []
var presentation_done_count := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_bound_status_scenes()
	_check_registry_contracts()
	await _check_presenter_reuses_visual()
	await _check_shield_absorb_then_break()
	await _check_multi_status_removal_rotation()
	_check_two_turn_status_lifecycle()
	_check_multi_impact_targets_and_timing()
	_check_projectile_arc()
	_check_streamed_presentation_barrier()
	if failures.is_empty():
		print("STATUS_SKILL_FRAMEWORK_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_bound_status_scenes() -> void:
	for skill_id in STATUS_SKILLS:
		var skill := load("res://resources/skills/%s.tres" % skill_id) as SkillDef
		if skill == null:
			failures.append("技能资源无法加载: %s" % skill_id)
			continue
		var found_status := false
		for raw_effect in skill.effects:
			var effect := raw_effect as SkillEffectDef
			if effect == null or effect.kind != "status":
				continue
			found_status = true
			if effect.status_visual_scene == null:
				failures.append("状态技能未绑定 PackedScene: %s" % skill_id)
				continue
			var dictionary := effect.to_dictionary()
			if str(dictionary.get("status_scene_path", "")) != str(STATUS_SKILLS[skill_id]):
				failures.append("状态场景路径转换错误: %s" % skill_id)
			var visual := effect.status_visual_scene.instantiate() as StatusVisualBase
			if visual == null:
				failures.append("状态场景根类型错误: %s" % skill_id)
				continue
			var errors := visual.contract_errors()
			if not errors.is_empty():
				failures.append("状态场景契约错误 %s: %s" % [skill_id, "；".join(errors)])
			visual.free()
		if not found_status:
			failures.append("技能缺少 status effect: %s" % skill_id)


func _check_registry_contracts() -> void:
	var registry := SkillSceneRegistry.new()
	var core_errors := registry.scan_core()
	if not core_errors.is_empty():
		failures.append("核心技能注册失败: %s" % "；".join(core_errors))
	var missing_skill := SkillDef.new()
	missing_skill.id = "missing_status_visual"
	var missing_effect := SkillEffectDef.new()
	missing_effect.kind = "status"
	missing_effect.status_id = "missing"
	missing_effect.status_kind = "dot"
	missing_skill.effects = [missing_effect]
	if registry.status_visual_errors(missing_skill).is_empty():
		failures.append("缺失 status_visual_scene 未被拒绝")
	missing_effect.status_visual_scene = load("res://scripts/game/skills/damage/thunder_skill.tscn") as PackedScene
	if registry.status_visual_errors(missing_skill).is_empty():
		failures.append("错误状态场景根类型未被拒绝")


func _check_presenter_reuses_visual() -> void:
	var status_owner := CombatActorStatus.new()
	status_owner.bind_enemy({"id": "target", "name": "目标", "hp": 50, "max_hp": 50, "defense": 0, "elements": {}})
	var socket := Node2D.new()
	add_child(socket)
	var presenter := CombatStatusPresenter.new()
	add_child(presenter)
	presenter.setup(status_owner, socket)
	var effect := {
		"status_id": "shared_poison",
		"kind": "dot",
		"amount": 1,
		"value": 1,
		"duration_turns": 2,
		"stack_mode": "refresh",
		"max_stacks": 3,
		"status_scene_path": STATUS_SKILLS["poison"],
		"source_skill_id": "poison",
	}
	var added := status_owner.add_status_effect(effect)
	presenter.present_event(added)
	if socket.get_child_count() != 1:
		failures.append("状态首次应用未创建唯一表现节点")
	if presenter.status_bar.get_child_count() != 1:
		failures.append("状态首次应用未创建唯一状态图标")
	var refreshed := status_owner.add_status_effect(effect)
	presenter.present_event(refreshed)
	if socket.get_child_count() != 1:
		failures.append("状态刷新重复创建表现节点")
	if presenter.status_bar.get_child_count() != 1:
		failures.append("状态刷新重复创建状态图标")
	effect["stack_mode"] = "stack"
	var stacked := status_owner.add_status_effect(effect)
	presenter.present_event(stacked)
	if socket.get_child_count() != 1:
		failures.append("状态叠层重复创建表现节点")
	if presenter.status_bar.get_child_count() != 1:
		failures.append("状态叠层重复创建状态图标")
	var cast_visual := Node2D.new()
	add_child(cast_visual)
	cast_visual.free()
	if socket.get_child_count() != 1:
		failures.append("释放场景销毁后状态表现未独立保留")
	var removed_events := status_owner.clear_status_effects("cleared")
	var duration := presenter.present_event(removed_events[0]) if not removed_events.is_empty() else 0.0
	await get_tree().create_timer(duration + 0.05).timeout
	await get_tree().process_frame
	if socket.get_child_count() != 0:
		failures.append("状态移除动画结束后表现节点未清理")
	presenter.queue_free()
	socket.queue_free()
	status_owner.free()


func _check_two_turn_status_lifecycle() -> void:
	var status_owner := CombatActorStatus.new()
	status_owner.bind_enemy({"id": "turn_target", "name": "回合目标", "hp": 20, "max_hp": 20, "defense": 0, "elements": {}})
	status_owner.add_status_effect({
		"status_id": "two_turn_dot",
		"kind": "dot",
		"amount": 1,
		"value": 1,
		"duration_turns": 2,
		"status_scene_path": STATUS_SKILLS["poison"],
	})
	var first_start := status_owner.tick_turn_start()
	if not _has_event(first_start, "status_tick"):
		failures.append("DOT 未在目标下一次回合开始跳动")
	if _has_event(status_owner.tick_turn_end(), "status_removed"):
		failures.append("两回合状态在第一回合提前移除")
	var second_start := status_owner.tick_turn_start()
	if not _has_event(second_start, "status_tick"):
		failures.append("DOT 未在目标第二次回合开始跳动")
	if not _has_event(status_owner.tick_turn_end(), "status_removed"):
		failures.append("两回合状态未在第二回合结束移除")
	status_owner.free()


func _check_multi_impact_targets_and_timing() -> void:
	var caster := CombatActorStatus.new()
	caster.bind_enemy({"id": "multi_caster", "name": "施法者", "hp": 50, "max_hp": 50, "attack": 0, "defense": 0, "elements": {}})
	var first_target := CombatActorStatus.new()
	first_target.bind_enemy({"id": "first_target", "name": "第一目标", "hp": 50, "max_hp": 50, "defense": 0, "elements": {}})
	var second_target := CombatActorStatus.new()
	second_target.bind_enemy({"id": "second_target", "name": "第二目标", "hp": 50, "max_hp": 50, "defense": 0, "elements": {}})
	var executor := CombatSkillExecutor.new()
	var resolver := CombatEffectResolver.new()
	var skill := {
		"id": "multi_impact_test",
		"element": "",
		"effects": [
			{"effect_id": "damage_1", "kind": "damage", "impact_id": "hit_1", "base_amount": 5, "shieldable": false},
			{"effect_id": "damage_2", "kind": "damage", "impact_id": "hit_2", "base_amount": 7, "shieldable": false},
			{
				"effect_id": "bleed", "kind": "status", "impact_id": "hit_2", "target": "skill_targets",
				"status_id": "multi_bleed", "status_kind": "dot", "base_amount": 2, "duration_turns": 2,
				"stack_mode": "refresh", "max_stacks": 1, "status_scene_path": STATUS_SKILLS["wolf_bleed"],
			},
		],
	}
	var first_result := executor.execute_impact(caster, [first_target], skill, &"hit_1", resolver)
	if int(first_target.data.get("hp", 0)) != 45 or int(second_target.data.get("hp", 0)) != 50:
		failures.append("第一段未只结算该窗口的实际目标")
	if not first_target.active_statuses().is_empty() or not second_target.active_statuses().is_empty():
		failures.append("第一段错误执行了第二段状态效果")
	var second_result := executor.execute_impact(caster, [second_target], skill, &"hit_2", resolver)
	if int(second_target.data.get("hp", 0)) != 43 or int(first_target.data.get("hp", 0)) != 45:
		failures.append("第二段未只结算该窗口的实际目标")
	if second_target.active_statuses().size() != 1 or not first_target.active_statuses().is_empty():
		failures.append("多段状态未绑定到第二段实际受击目标")
	if not _has_actor_event(second_result.get("events", []), "status_added", "second_target"):
		failures.append("状态事件缺少实际受击目标 actor_id")
	if _has_event(first_result.get("events", []), "status_added"):
		failures.append("状态在错误的 impact_id 提前生效")
	if int(second_target.data.get("hp", 0)) != 43:
		failures.append("DOT 在命中时错误地立即结算")
	second_target.tick_turn_start()
	if int(second_target.data.get("hp", 0)) != 41:
		failures.append("DOT 未在实际受击目标的下一回合开始结算")
	var repeated_target := CombatActorStatus.new()
	repeated_target.bind_enemy({"id": "repeated_target", "name": "重复目标", "hp": 50, "max_hp": 50, "defense": 0, "elements": {}})
	executor.execute_impact(caster, [repeated_target], skill, &"hit_1", resolver)
	executor.execute_impact(caster, [repeated_target], skill, &"hit_2", resolver)
	if int(repeated_target.data.get("hp", 0)) != 38:
		failures.append("同一目标无法在不同碰撞窗口承受多段伤害")
	caster.free()
	first_target.free()
	second_target.free()
	repeated_target.free()


func _check_projectile_arc() -> void:
	var projectile := SkillProjectilePath.new()
	projectile.arc_height = 40.0
	projectile.configure_path(Vector2(10, 20), Vector2(110, 20))
	if not projectile.expected_global_position(0.0).is_equal_approx(Vector2(10, 20)):
		failures.append("弹道起点未固定到施法者锚点")
	if not projectile.expected_global_position(1.0).is_equal_approx(Vector2(110, 20)):
		failures.append("弹道终点未固定到受击目标锚点")
	if not projectile.expected_global_position(0.5).is_equal_approx(Vector2(60, -20)):
		failures.append("弹道中点未按 arc_height 形成抛物线")
	projectile.free()


func _check_streamed_presentation_barrier() -> void:
	presentation_done_count = 0
	var controller := CombatController.new()
	add_child(controller)
	controller.call("_queue_presentation", [{"type": "status_added", "actor_id": "actual_target", "status": {"status_id": "streamed"}}])
	var waiting: bool = controller.call("_wait_for_presentation", Callable(self, "_mark_presentation_done"))
	if not waiting or presentation_done_count != 0:
		failures.append("技能结束未等待已流式入队的状态表现")
	controller.call("_start_next_presentation_event")
	if presentation_done_count != 1:
		failures.append("状态表现 FIFO 清空后未释放回合屏障")
	controller.queue_free()


func _mark_presentation_done() -> void:
	presentation_done_count += 1


func _check_shield_absorb_then_break() -> void:
	var status_owner := CombatActorStatus.new()
	status_owner.bind_enemy({"id": "shield_target", "name": "护盾目标", "hp": 20, "max_hp": 20, "defense": 0, "elements": {}})
	var socket := Node2D.new()
	add_child(socket)
	var presenter := CombatStatusPresenter.new()
	add_child(presenter)
	presenter.setup(status_owner, socket)
	var added := status_owner.add_status_effect({
		"status_id": "test_shield",
		"kind": "shield",
		"amount": 5,
		"value": 5,
		"duration_turns": 2,
		"status_scene_path": STATUS_SKILLS["spirit_shield"],
		"source_skill_id": "spirit_shield",
	})
	presenter.present_event(added)
	var context := {"events": []}
	var remaining := status_owner.apply_shields(8, context)
	if remaining != 3:
		failures.append("护盾耗尽后的穿透伤害错误")
	if socket.get_child_count() != 1:
		failures.append("护盾耗尽时在 absorb 播放前移除了表现节点")
	var events: Array = context.get("events", [])
	if events.size() != 2 or str(events[0].get("type", "")) != "shield_absorbed" or str(events[1].get("type", "")) != "status_removed":
		failures.append("护盾吸收与破裂事件顺序错误")
	else:
		var absorb_duration := presenter.present_event(events[0])
		if absorb_duration <= 0.0:
			failures.append("护盾耗尽时未播放 absorb 动画")
		await get_tree().create_timer(absorb_duration + 0.02).timeout
		var break_duration := presenter.present_event(events[1])
		if break_duration <= 0.0:
			failures.append("护盾耗尽时未播放 break 动画")
		await get_tree().create_timer(break_duration + 0.05).timeout
		await get_tree().process_frame
		if socket.get_child_count() != 0:
			failures.append("护盾破裂动画结束后未清理表现节点")
	presenter.queue_free()
	socket.queue_free()
	status_owner.free()


func _check_multi_status_removal_rotation() -> void:
	var status_owner := CombatActorStatus.new()
	status_owner.bind_enemy({"id": "multi_target", "name": "多状态目标", "hp": 20, "max_hp": 20, "defense": 0, "elements": {}})
	var socket := Node2D.new()
	add_child(socket)
	var presenter := CombatStatusPresenter.new()
	add_child(presenter)
	presenter.setup(status_owner, socket)
	for index in range(5):
		var added := status_owner.add_status_effect({
			"status_id": "multi_%d" % index,
			"kind": "dot",
			"amount": 1,
			"value": 1,
			"duration_turns": 2,
			"status_scene_path": STATUS_SKILLS["poison"],
			"source_skill_id": "poison",
		})
		presenter.present_event(added)
	presenter._rotation_index = 4
	for index in range(5):
		presenter.call("_remove_visual", "multi_%d" % index)
	await get_tree().process_frame
	if not presenter._ordered_ids.is_empty() or not presenter._visuals.is_empty():
		failures.append("多状态批量移除后仍有轮播状态残留")
	if socket.get_child_count() != 0:
		failures.append("多状态批量移除后仍有表现节点残留")
	presenter.queue_free()
	socket.queue_free()
	status_owner.free()


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return true
	return false


func _has_actor_event(events: Array, event_type: String, actor_id: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type and str(event.get("actor_id", "")) == actor_id:
			return true
	return false
