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
	area_entered.connect(_on_area_entered)


func configure_identity(value_owner_id: String, value_team: String) -> void:
	owner_id = value_owner_id
	team = value_team
	collision_layer = 0
	collision_mask = ENEMY_HURTBOX_LAYER if team == TEAM_PARTY else PARTY_HURTBOX_LAYER


func open_window(value_action_id: int) -> void:
	action_id = value_action_id
	_hit_targets.clear()
	monitoring = true
	call_deferred("_collect_overlaps")


func close_window() -> void:
	set_deferred("monitoring", false)
	action_id = 0
	_hit_targets.clear()


func _collect_overlaps() -> void:
	if not monitoring or action_id <= 0:
		return
	for area in get_overlapping_areas():
		_try_emit_hit(area)


func _on_area_entered(area: Area2D) -> void:
	_try_emit_hit(area)


func _try_emit_hit(area: Area2D) -> void:
	if not monitoring or action_id <= 0 or not (area is CombatHurtbox):
		return
	var hurtbox := area as CombatHurtbox
	if hurtbox.actor_id.is_empty() or hurtbox.team == team or _hit_targets.has(hurtbox.actor_id):
		return
	_hit_targets[hurtbox.actor_id] = true
	hit_candidate.emit(action_id, hurtbox.actor_id)
