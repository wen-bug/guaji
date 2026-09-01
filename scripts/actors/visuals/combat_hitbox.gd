class_name CombatHitbox
extends Area2D

signal hit_candidate(action_id: int, target_id: String)

const TEAM_PARTY := "party"
const PARTY_HURTBOX_LAYER := 2
const ENEMY_HURTBOX_LAYER := 4

var action_id := 0
var owner_id := ""
var team := ""
var _hit_targets: Dictionary = {}


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0


func configure_identity(value_owner_id: String, value_team: String) -> void:
	owner_id = value_owner_id
	team = value_team
	collision_layer = 0
	collision_mask = 0


func open_window(value_action_id: int) -> void:
	# Legacy compatibility only: combat targets are resolved by CombatController.
	action_id = value_action_id
	_hit_targets.clear()


func close_window() -> void:
	action_id = 0
	_hit_targets.clear()


func _collect_overlaps() -> void:
	pass


func _on_area_entered(_area: Area2D) -> void:
	pass


func _try_emit_hit(_area: Area2D) -> void:
	# Kept for old scenes that may still call the private compatibility path.
	pass
