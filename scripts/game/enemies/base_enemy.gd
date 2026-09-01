class_name BaseEnemy
extends Node2D

signal hit_candidate(action_id: int, target_id: String)
signal attack_finished(action_id: int)
signal death_finished

const CombatActorStatusScript = preload("res://scripts/game/combat/combat_actor_status.gd")
const DEFAULT_VISUAL_ID := "enemy_default"
const ENEMY_VISUAL_ROOT := "res://scripts/actors/visuals/enemies"

var enemy_data: Dictionary = {}
var visual_id := DEFAULT_VISUAL_ID
var _combat_position := Vector2.ZERO
var visual_root: Node2D
var combat_visual: CombatVisual
var combat_status: CombatActorStatus
var _death_started := false
var _combat_ai := CombatAI.new()


func _ready() -> void:
	_bind_nodes()


func setup(data: Dictionary) -> void:
	enemy_data = data
	visual_id = str(enemy_data.get("visual_id", enemy_data.get("id", DEFAULT_VISUAL_ID)))
	if visual_id.is_empty():
		visual_id = DEFAULT_VISUAL_ID
	visible = true
	_death_started = false
	_bind_nodes()
	_load_combat_visual()
	ensure_combat_status().bind_enemy(enemy_data, self)
	_sync_visual_data()


func sync_data(data: Dictionary) -> void:
	enemy_data = data
	_sync_visual_data()


func runtime_data() -> Dictionary:
	return enemy_data.duplicate(true)


func template_id() -> String:
	return str(enemy_data.get("id", ""))


func set_combat_position(value: Vector2) -> void:
	_combat_position = value
	position = value


func combat_position() -> Vector2:
	return global_position


func melee_approach_position() -> Vector2:
	return combat_visual.melee_approach_position() if combat_visual != null else global_position


func hit_position() -> Vector2:
	return combat_visual.hit_position() if combat_visual != null else global_position


func effect_position() -> Vector2:
	return combat_visual.effect_position() if combat_visual != null else global_position


func bind_combat_status_presentation(status: CombatActorStatus) -> void:
	if combat_visual != null:
		combat_visual.bind_combat_status(status)


func present_combat_event(event: Dictionary) -> float:
	return combat_visual.present_combat_event(event) if combat_visual != null else 0.0


func select_action(_game_state, target_status = null) -> Dictionary:
	if enemy_data.is_empty():
		return {}
	var cooldowns: Dictionary = enemy_data.get("skill_cooldowns", {})
	var candidates: Array = []
	for skill_id in enemy_data.get("skills", []):
		var skill: Dictionary = DataTables.create_skill(str(skill_id))
		if skill.is_empty() or int(cooldowns.get(str(skill_id), 0)) > 0:
			continue
		if not _skill_triggered(skill, target_status):
			continue
		candidates.append(skill)
	if not candidates.is_empty():
		candidates.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
		var chosen: Dictionary = candidates[0]
		cooldowns[str(chosen.get("id", ""))] = maxi(0, int(chosen.get("cooldown", 0)))
		enemy_data["skill_cooldowns"] = cooldowns
		return chosen
	var attack := DataTables.create_default_attack_skill(int(enemy_data.get("attack", 1)))
	cooldowns[DataTables.DEFAULT_ATTACK_SKILL_ID] = int(attack.get("cooldown", 1))
	enemy_data["skill_cooldowns"] = cooldowns
	return attack


func select_action_with_context(_game_state, combat_context: Dictionary) -> Dictionary:
	if enemy_data.is_empty():
		return {}
	var chosen := _combat_ai.select_enemy_action(enemy_data, combat_context)
	if chosen.is_empty():
		var fallback := DataTables.create_default_attack_skill(int(enemy_data.get("attack", 1)))
		var fallback_cooldowns: Dictionary = enemy_data.get("skill_cooldowns", {})
		fallback_cooldowns[DataTables.DEFAULT_ATTACK_SKILL_ID] = int(fallback.get("cooldown", 1))
		enemy_data["skill_cooldowns"] = fallback_cooldowns
		return fallback
	var cooldowns: Dictionary = enemy_data.get("skill_cooldowns", {})
	var skill_id := str(chosen.get("id", ""))
	cooldowns[skill_id] = maxi(0, int(DataTables.create_skill(skill_id).get("cooldown", 0)))
	enemy_data["skill_cooldowns"] = cooldowns
	return DataTables.create_skill(skill_id).merged({"preferred_target_id": str(chosen.get("preferred_target_id", ""))}, true)


func _skill_triggered(skill: Dictionary, target_status) -> bool:
	var triggers: Array = skill.get("trigger", []) if skill.get("trigger", []) is Array else []
	if triggers.is_empty() or triggers.has("always"):
		return true
	var hp_ratio := float(enemy_data.get("hp", 0)) / maxf(1.0, float(enemy_data.get("max_hp", 1)))
	if triggers.has("hp_below_50") and hp_ratio <= 0.5:
		return true
	if triggers.has("hp_below_35") and hp_ratio <= 0.35:
		return true
	if triggers.has("target_hp_below_35") and target_status != null:
		var snapshot: Dictionary = target_status.combat_snapshot()
		if float(snapshot.get("hp", 0)) / maxf(1.0, float(snapshot.get("max_hp", 1))) <= 0.35:
			return true
	return false


func play_idle() -> void:
	if combat_visual != null:
		combat_visual.play_idle()


func play_walk() -> void:
	if combat_visual != null:
		combat_visual.play_walk()


func play_run() -> void:
	if combat_visual != null:
		combat_visual.play_run()


func play_attack_feedback(action_id: int = 0) -> void:
	if combat_visual != null:
		combat_visual.play_melee_attack(action_id)


func play_ranged_attack_feedback(action_id: int = 0) -> void:
	if combat_visual != null:
		combat_visual.play_ranged_attack(action_id)


func play_hurt_feedback() -> void:
	if combat_visual != null:
		combat_visual.play_hurt()


func play_death_feedback() -> void:
	if _death_started:
		return
	_death_started = true
	if combat_visual != null:
		combat_visual.play_death()
	else:
		death_finished.emit()


func cancel_combat_action() -> void:
	if combat_visual != null:
		combat_visual.cancel_action()


func ensure_combat_status() -> CombatActorStatus:
	if combat_status == null:
		combat_status = get_node_or_null("CombatActorStatus") as CombatActorStatus
	if combat_status == null:
		combat_status = CombatActorStatusScript.new()
		combat_status.name = "CombatActorStatus"
		add_child(combat_status)
	combat_status.visual_owner = self
	return combat_status


func _load_combat_visual() -> void:
	if combat_visual != null:
		combat_visual.queue_free()
		combat_visual = null
	var scene_path := _appearance_scene_path(visual_id, "enemy", DEFAULT_VISUAL_ID)
	if not ResourceLoader.exists(scene_path):
		push_warning("敌人形象不存在，使用默认形象: %s" % scene_path)
		scene_path = _appearance_scene_path(DEFAULT_VISUAL_ID, "enemy", DEFAULT_VISUAL_ID)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("默认敌人形象加载失败: %s" % scene_path)
		return
	var instance := packed.instantiate()
	combat_visual = instance as CombatVisual
	if combat_visual == null:
		instance.queue_free()
		push_error("敌人形象根节点必须使用 CombatVisual: %s" % scene_path)
		return
	var contract_issue := combat_visual.contract_error()
	if not contract_issue.is_empty() and not scene_path.ends_with("/%s.tscn" % DEFAULT_VISUAL_ID):
		push_warning("敌人形象接口不完整（%s），使用默认形象: %s" % [contract_issue, scene_path])
		combat_visual.free()
		scene_path = _appearance_scene_path(DEFAULT_VISUAL_ID, "enemy", DEFAULT_VISUAL_ID)
		packed = load(scene_path) as PackedScene
		combat_visual = packed.instantiate() as CombatVisual if packed != null else null
	if combat_visual == null:
		push_error("默认敌人形象加载失败: %s" % scene_path)
		return
	contract_issue = combat_visual.contract_error()
	if not contract_issue.is_empty():
		combat_visual.free()
		combat_visual = null
		push_error("默认敌人形象接口不完整（%s）: %s" % [contract_issue, scene_path])
		return
	visual_root.add_child(combat_visual)
	combat_visual.configure_identity(str(enemy_data.get("combat_id", "enemy")), CombatHurtbox.TEAM_ENEMY)
	combat_visual.hit_candidate.connect(_on_visual_hit_candidate)
	combat_visual.attack_finished.connect(_on_visual_attack_finished)
	combat_visual.death_finished.connect(_on_visual_death_finished)
	combat_visual.play_idle()


func _sync_visual_data() -> void:
	if combat_visual != null and not enemy_data.is_empty():
		combat_visual.set_hit_points(int(enemy_data.get("hp", 0)), int(enemy_data.get("max_hp", 1)))


func _appearance_scene_path(requested_id: String, expected_kind: String, fallback_id: String) -> String:
	var definition := DataTables.content_definition("appearance", requested_id)
	if str(definition.get("kind", "")) == expected_kind:
		var registered_path := str(definition.get("scene_path", ""))
		if ResourceLoader.exists(registered_path):
			return registered_path
	var fallback := DataTables.content_definition("appearance", fallback_id)
	var fallback_path := str(fallback.get("scene_path", ""))
	if ResourceLoader.exists(fallback_path):
		return fallback_path
	return "%s/%s.tscn" % [ENEMY_VISUAL_ROOT, _safe_visual_id(fallback_id)]


func _safe_visual_id(value: String) -> String:
	var result := ""
	for character in value:
		if character.is_valid_identifier() or character == "_" or character.is_valid_int():
			result += character
	return result if not result.is_empty() else DEFAULT_VISUAL_ID


func _on_visual_hit_candidate(action_id: int, target_id: String) -> void:
	hit_candidate.emit(action_id, target_id)


func _on_visual_attack_finished(action_id: int) -> void:
	attack_finished.emit(action_id)


func _on_visual_death_finished() -> void:
	death_finished.emit()


func _bind_nodes() -> void:
	if visual_root == null:
		visual_root = get_node_or_null("VisualRoot") as Node2D
