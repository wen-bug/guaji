extends Node

const ACTIVE_SKILLS := {
	"attack_up": "res://scripts/game/skills/buff/attack_up_skill.tscn",
	"spirit_shield": "res://scripts/game/skills/buff/spirit_shield_skill.tscn",
	"poison": "res://scripts/game/skills/damage/poison_skill.tscn",
	"thunder": "res://scripts/game/skills/damage/thunder_skill.tscn",
	"heal": "res://scripts/game/skills/heal/heal_skill.tscn",
	"water_cold_talisman": "res://scripts/game/skills/damage/water_cold_talisman_skill.tscn",
	"wolf_bite": "res://scripts/game/skills/damage/wolf_bite_skill.tscn",
	"wolf_bleed": "res://scripts/game/skills/damage/wolf_bleed_skill.tscn",
	"wolf_howl": "res://scripts/game/skills/damage/wolf_howl_skill.tscn",
	"wolf_pounce": "res://scripts/game/skills/damage/wolf_pounce_skill.tscn",
}
const GROUP_SKILLS := ["poison", "wolf_howl"]
const EMPTY_MATERIAL_SKILLS := [
	"water_cold_talisman", "wolf_bite", "wolf_bleed", "wolf_howl", "wolf_pounce",
]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	SkillPresentation.set_mode(SkillPresentation.MODE_MATERIAL)
	_check_active_skill_contracts()
	await _check_mode_switch_visibility()
	await _check_material_and_hitbox_results_match()
	await _check_miss_has_no_fallback()
	await _check_self_overlap()
	await _check_group_candidate_filtering()
	await _check_hidden_status_visual()
	SkillPresentation.set_mode(SkillPresentation.MODE_MATERIAL)
	if failures.is_empty():
		print("SKILL_PRESENTATION_MODE_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_active_skill_contracts() -> void:
	for skill_id in ACTIVE_SKILLS:
		var scene := load(ACTIVE_SKILLS[skill_id]) as PackedScene
		var skill := scene.instantiate() as SkillSceneBase if scene != null else null
		if skill == null:
			failures.append("技能场景无法实例化: %s" % skill_id)
			continue
		var errors := skill.contract_errors()
		_expect_true("%s contract" % skill_id, errors.is_empty(), "；".join(errors))
		var hitboxes: Array[Node] = []
		_find_named_nodes(skill, &"SkillHitbox", hitboxes)
		_expect_equal("%s unique SkillHitbox" % skill_id, hitboxes.size(), 1)
		if hitboxes.size() == 1:
			var shapes := _collision_shapes(hitboxes[0])
			_expect_equal("%s collision shape count" % skill_id, shapes.size(), 1)
			if shapes.size() == 1 and shapes[0].shape is RectangleShape2D:
				var expected := Vector2(480, 96) if GROUP_SKILLS.has(skill_id) else Vector2(72, 96)
				_expect_equal("%s hitbox size" % skill_id, (shapes[0].shape as RectangleShape2D).size, expected)
		var player := skill.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if player != null:
			_expect_equal("%s animation process" % skill_id, player.callback_mode_process, AnimationPlayer.ANIMATION_PROCESS_PHYSICS)
			var methods := _root_method_sequence(player.get_animation(&"cast"))
			_expect_equal("%s collision timeline" % skill_id, methods, [&"open_hitbox", &"impact", &"close_hitbox", &"finish_cast"])
		var visual := skill.get_node_or_null("EffectSprite") as AnimatedSprite2D
		_expect_true("%s material visual group" % skill_id, visual != null and visual.is_in_group("skill_material_visual"))
		if EMPTY_MATERIAL_SKILLS.has(skill_id) and visual != null:
			_expect_true("%s material intentionally empty" % skill_id, visual.sprite_frames == null)
		skill.free()


func _check_mode_switch_visibility() -> void:
	var skill := _instantiate_skill("thunder")
	add_child(skill)
	await get_tree().process_frame
	var visual := skill.get_node("EffectSprite") as CanvasItem
	var drawer := skill.get_node("SkillHitboxDebugDrawer") as Node2D
	var original_layer := visual.visibility_layer
	_expect_true("material layer visible", original_layer != 0)
	_expect_true("drawer hidden outside window", not drawer.visible)
	SkillPresentation.set_mode(SkillPresentation.MODE_HITBOX)
	_expect_equal("material hidden immediately", visual.visibility_layer, 0)
	_expect_true("drawer remains hidden outside window", not drawer.visible)
	var cast := _make_manual_cast(skill, "switch_target", Vector2.ZERO, false)
	skill.start_cast(cast.context)
	await get_tree().physics_frame
	(skill.get_node("AnimationPlayer") as AnimationPlayer).stop()
	_expect_true("drawer visible during window", drawer.visible)
	SkillPresentation.set_mode(SkillPresentation.MODE_MATERIAL)
	_expect_equal("material restored during cast", visual.visibility_layer, original_layer)
	_expect_true("drawer hidden after live switch", not drawer.visible)
	SkillPresentation.set_mode(SkillPresentation.MODE_HITBOX)
	_expect_true("drawer restored after live switch", drawer.visible)
	skill.close_hitbox()
	_expect_true("drawer hidden after close", not drawer.visible)
	skill.queue_free()
	_cleanup_cast(cast)
	await get_tree().process_frame


func _check_material_and_hitbox_results_match() -> void:
	var material := await _run_thunder_cast(SkillPresentation.MODE_MATERIAL, false)
	var hitbox := await _run_thunder_cast(SkillPresentation.MODE_HITBOX, false)
	for key in ["damage", "heal", "target_ids", "applied_effects", "cast_succeeded"]:
		_expect_equal("mode parity %s" % key, hitbox.get(key), material.get(key))


func _check_miss_has_no_fallback() -> void:
	var result := await _run_thunder_cast(SkillPresentation.MODE_HITBOX, true)
	_expect_equal("miss damage", int(result.get("damage", -1)), 0)
	_expect_true("miss target list empty", result.get("target_ids", []).is_empty())
	_expect_true("miss cast still succeeds", bool(result.get("cast_succeeded", false)))


func _check_self_overlap() -> void:
	SkillPresentation.set_mode(SkillPresentation.MODE_HITBOX)
	var skill := _instantiate_skill("heal")
	add_child(skill)
	var cast := _make_manual_cast(skill, "self", Vector2(80, 80), true, 30, 100)
	var completion := {"finished": false, "result": {}}
	skill.finished.connect(func(value: Dictionary):
		completion.finished = true
		completion.result = value
	)
	skill.start_cast(cast.context)
	await _wait_for_cast(func(): return completion.finished)
	var result: Dictionary = completion.result
	_expect_true("self cast finished", completion.finished)
	_expect_true("self overlap heals", int(result.get("heal", 0)) > 0)
	_expect_equal("self overlap target", result.get("target_ids", []), ["self"])
	skill.queue_free()
	_cleanup_cast(cast)
	await get_tree().process_frame


func _check_group_candidate_filtering() -> void:
	SkillPresentation.set_mode(SkillPresentation.MODE_HITBOX)
	var skill := _instantiate_skill("poison")
	add_child(skill)
	var caster := _make_actor("group_caster", Vector2.ZERO, CombatHurtbox.TEAM_ENEMY)
	var first := _make_actor("first", Vector2(0, 0), CombatHurtbox.TEAM_PARTY)
	var outside := _make_actor("outside", Vector2(300, 0), CombatHurtbox.TEAM_PARTY)
	var unlisted := _make_actor("unlisted", Vector2(40, 0), CombatHurtbox.TEAM_PARTY)
	var definition := skill.skill_resource.to_dictionary()
	var context := SkillCastContext.create(caster.status, [first.status], [first.status, outside.status], definition, CombatEffectResolver.new())
	var completion := {"finished": false, "result": {}}
	skill.finished.connect(func(value: Dictionary):
		completion.finished = true
		completion.result = value
	)
	skill.start_cast(context)
	await _wait_for_cast(func(): return completion.finished)
	var result: Dictionary = completion.result
	_expect_true("group cast finished", completion.finished)
	_expect_equal("group physical and candidate filter", result.get("target_ids", []), ["first"])
	for actor in [caster, first, outside, unlisted]:
		_cleanup_actor(actor)
	skill.queue_free()
	await get_tree().process_frame


func _check_hidden_status_visual() -> void:
	var scene := load("res://scripts/game/skills/status/visuals/poison.tscn") as PackedScene
	var visual := scene.instantiate() as StatusVisualBase
	add_child(visual)
	await get_tree().process_frame
	SkillPresentation.set_mode(SkillPresentation.MODE_HITBOX)
	var completion := {"finished": false}
	visual.event_animation_finished.connect(func(): completion.finished = true)
	var duration := visual.play_event({"type": "status_added"})
	await get_tree().process_frame
	_expect_equal("hidden status event duration", duration, 0.0)
	_expect_true("hidden status visual invisible", not visual.visible)
	_expect_true("hidden status event completes", completion.finished)
	visual.set_loop_active(true)
	_expect_true("hidden status loop does not process", not visual.is_processing())
	SkillPresentation.set_mode(SkillPresentation.MODE_MATERIAL)
	_expect_true("status loop restored", visual.visible)
	visual.queue_free()
	await get_tree().process_frame


func _run_thunder_cast(mode: StringName, move_target_out: bool) -> Dictionary:
	SkillPresentation.set_mode(mode)
	var skill := _instantiate_skill("thunder")
	add_child(skill)
	var cast := _make_manual_cast(skill, "target", Vector2(120, 100), false)
	var completion := {"finished": false, "result": {}}
	skill.finished.connect(func(value: Dictionary):
		completion.finished = true
		completion.result = value
	)
	skill.start_cast(cast.context)
	if move_target_out:
		cast.target_visual.global_position += Vector2(500, 0)
	await _wait_for_cast(func(): return completion.finished)
	_expect_true("thunder cast finished in %s" % mode, completion.finished)
	skill.queue_free()
	_cleanup_cast(cast)
	await get_tree().process_frame
	return completion.result


func _make_manual_cast(
	skill: SkillSceneBase,
	target_id: String,
	position: Vector2,
	self_target: bool,
	hp: int = 100,
	max_hp: int = 100
) -> Dictionary:
	var caster := _make_actor("caster" if not self_target else target_id, position, CombatHurtbox.TEAM_ENEMY, hp, max_hp)
	var target := caster if self_target else _make_actor(target_id, position, CombatHurtbox.TEAM_PARTY, hp, max_hp)
	var definition := skill.skill_resource.to_dictionary()
	var context := SkillCastContext.create(caster.status, [target.status], [target.status], definition, CombatEffectResolver.new())
	return {
		"context": context,
		"caster": caster,
		"target": target,
		"target_visual": target.visual,
	}


func _make_actor(actor_id: String, position: Vector2, hurtbox_team: String, hp: int = 100, max_hp: int = 100) -> Dictionary:
	var visual := Node2D.new()
	visual.name = "%sVisual" % actor_id
	visual.global_position = position
	add_child(visual)
	var hurtbox := CombatHurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.configure_identity(actor_id, hurtbox_team)
	visual.add_child(hurtbox)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(64, 88)
	shape.shape = rectangle
	hurtbox.add_child(shape)
	var status := CombatActorStatus.new()
	status.actor_id = actor_id
	status.actor_name = actor_id
	status.actor_kind = CombatActorStatus.KIND_ENEMY
	status.data = {"id": actor_id, "hp": hp, "max_hp": max_hp, "attack": 12, "defense": 0, "elements": {}}
	status.visual_owner = visual
	add_child(status)
	return {"visual": visual, "hurtbox": hurtbox, "status": status}


func _cleanup_cast(cast: Dictionary) -> void:
	_cleanup_actor(cast.caster)
	if cast.target != cast.caster:
		_cleanup_actor(cast.target)


func _cleanup_actor(actor: Dictionary) -> void:
	if actor.status != null and is_instance_valid(actor.status):
		actor.status.queue_free()
	if actor.visual != null and is_instance_valid(actor.visual):
		actor.visual.queue_free()


func _wait_for_cast(done: Callable) -> void:
	for _frame in range(120):
		if bool(done.call()):
			return
		await get_tree().physics_frame


func _instantiate_skill(skill_id: String) -> SkillSceneBase:
	return (load(ACTIVE_SKILLS[skill_id]) as PackedScene).instantiate() as SkillSceneBase


func _find_named_nodes(node: Node, target_name: StringName, result: Array[Node]) -> void:
	for child in node.get_children():
		if child.name == target_name:
			result.append(child)
		_find_named_nodes(child, target_name, result)


func _collision_shapes(node: Node) -> Array[CollisionShape2D]:
	var result: Array[CollisionShape2D] = []
	for child in node.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			result.append(child as CollisionShape2D)
		result.append_array(_collision_shapes(child))
	return result


func _root_method_sequence(animation: Animation) -> Array[StringName]:
	var calls: Array[Dictionary] = []
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_METHOD or str(animation.track_get_path(track_index)) not in ["", "."]:
			continue
		for key_index in range(animation.track_get_key_count(track_index)):
			var key: Dictionary = animation.track_get_key_value(track_index, key_index)
			calls.append({"time": animation.track_get_key_time(track_index, key_index), "method": StringName(key.get("method", ""))})
	calls.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.time) < float(b.time))
	var result: Array[StringName] = []
	for method_call in calls:
		result.append(method_call.method)
	return result


func _expect_true(label: String, condition: bool, detail: String = "") -> void:
	if not condition:
		failures.append("%s: expected true%s" % [label, " (%s)" % detail if not detail.is_empty() else ""])


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
