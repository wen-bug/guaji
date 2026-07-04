class_name BaseEnemy
extends Node2D

const DEFAULT_HP_BAR_WIDTH := 48.0
const DEFAULT_ATTACK_LUNGE := 10.0
const CombatActorStatusScript = preload("res://scripts/game/combat/combat_actor_status.gd")

var enemy_data: Dictionary = {}
var _combat_position := Vector2.ZERO
var _visual_node: Node2D = null
var _hp_fill: ColorRect = null
var _hurt_overlay: ColorRect = null
var _feedback_tween: Tween = null
var combat_status: CombatActorStatus


func _ready() -> void:
	_bind_nodes()
	_update_hp_bar()


func setup(data: Dictionary) -> void:
	enemy_data = data.duplicate(true)
	visible = true
	_bind_nodes()
	ensure_combat_status().bind_enemy(enemy_data, self)
	_update_hp_bar()


func sync_data(data: Dictionary) -> void:
	enemy_data = data.duplicate(true)
	_update_hp_bar()


func runtime_data() -> Dictionary:
	return enemy_data.duplicate(true)


func template_id() -> String:
	return str(enemy_data.get("id", ""))


func set_combat_position(value: Vector2) -> void:
	_combat_position = value
	position = value


func combat_position() -> Vector2:
	return _combat_position


func set_hit_points(current_hp: int, max_hp: int) -> void:
	enemy_data["hp"] = current_hp
	enemy_data["max_hp"] = max_hp
	_update_hp_bar()


func select_action(game_state) -> Dictionary:
	if enemy_data.is_empty():
		return {}
	var element_id := ""
	if game_state != null and game_state.rng.randf() < float(enemy_data.get("element_attack_ratio", 0.0)):
		element_id = str(enemy_data.get("element", ""))
	return {
		"kind": "basic_attack",
		"base_damage": int(enemy_data.get("attack", 1)),
		"element": element_id,
	}


func play_attack_feedback() -> void:
	_bind_nodes()
	var target_node: Node2D = _feedback_target()
	if target_node == null:
		return
	_reset_feedback_tween()
	var origin: Vector2 = target_node.position
	var direction: float = -1.0 if _combat_position.x >= 0.0 else 1.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(target_node, "position", origin + Vector2(DEFAULT_ATTACK_LUNGE * direction, 0.0), 0.08)
	_feedback_tween.tween_property(target_node, "position", origin, 0.12)


func play_hurt_feedback() -> void:
	_bind_nodes()
	var target_node: Node2D = _feedback_target()
	if target_node == null:
		return
	_reset_feedback_tween()
	var target_item: CanvasItem = target_node as CanvasItem
	var origin: Vector2 = target_node.position
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(target_node, "position", origin + Vector2(5.0, 0.0), 0.05)
	_feedback_tween.tween_property(target_node, "position", origin - Vector2(4.0, 0.0), 0.1).set_delay(0.05)
	_feedback_tween.tween_property(target_node, "position", origin, 0.06).set_delay(0.15)
	if target_item != null:
		_feedback_tween.tween_property(target_item, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.05)
		_feedback_tween.tween_property(target_item, "modulate", Color.WHITE, 0.16).set_delay(0.05)
	if _hurt_overlay != null:
		_hurt_overlay.visible = true
		_hurt_overlay.modulate.a = 0.7
		_feedback_tween.tween_property(_hurt_overlay, "modulate:a", 0.0, 0.18)
		_feedback_tween.tween_callback(_hide_hurt_overlay).set_delay(0.19)


func ensure_combat_status() -> CombatActorStatus:
	if combat_status != null:
		return combat_status
	combat_status = get_node_or_null("CombatActorStatus") as CombatActorStatus
	if combat_status == null:
		combat_status = CombatActorStatusScript.new()
		combat_status.name = "CombatActorStatus"
		add_child(combat_status)
	combat_status.visual_owner = self
	return combat_status


func _bind_nodes() -> void:
	if _visual_node == null:
		_visual_node = get_node_or_null("Visual") as Node2D
	if _hp_fill == null:
		_hp_fill = get_node_or_null("HPBack/HPFill") as ColorRect
	if _hurt_overlay == null:
		_hurt_overlay = get_node_or_null("HurtOverlay") as ColorRect


func _feedback_target() -> Node2D:
	if _visual_node != null:
		return _visual_node
	return self


func _update_hp_bar() -> void:
	if _hp_fill == null or enemy_data.is_empty():
		return
	var current_hp: float = float(enemy_data.get("hp", 0))
	var max_hp: float = max(1.0, float(enemy_data.get("max_hp", 1)))
	var ratio: float = clamp(current_hp / max_hp, 0.0, 1.0)
	_hp_fill.size.x = DEFAULT_HP_BAR_WIDTH * ratio


func _reset_feedback_tween() -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
		_feedback_tween = null
	var target_node: Node2D = _feedback_target()
	if target_node != null:
		target_node.position = _visual_node.position if _visual_node != null else _combat_position
		var target_item: CanvasItem = target_node as CanvasItem
		if target_item != null:
			target_item.modulate = Color.WHITE


func _hide_hurt_overlay() -> void:
	if _hurt_overlay != null:
		_hurt_overlay.visible = false
