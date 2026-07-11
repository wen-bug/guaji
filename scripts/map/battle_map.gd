class_name BattleMap
extends Node2D

signal monster_spawn_requested

@export var spawn_interval_min := 30.0
@export var spawn_interval_max := 60.0

var scene_viewport_size := Vector2(960, 480)
var spawn_timer := 0.0
var next_spawn_time := 0.0
var player_combat_position := Vector2(736, 170)

var _expedition_active := false
var _waiting_for_combat := false
var _combat_mode := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	visible = false
	set_process(false)


func set_scene_viewport_size(viewport_size: Vector2) -> void:
	scene_viewport_size = viewport_size


func enter_expedition() -> void:
	_expedition_active = true
	_waiting_for_combat = false
	_combat_mode = false
	visible = true
	_reset_spawn_timer()
	set_process(true)


func exit_expedition() -> void:
	_expedition_active = false
	_waiting_for_combat = false
	_combat_mode = false
	visible = false
	set_process(false)


func set_combat_mode(enabled: bool) -> void:
	_combat_mode = enabled
	_waiting_for_combat = enabled


func finish_combat() -> void:
	_combat_mode = false
	_waiting_for_combat = false
	_reset_spawn_timer()


func is_expedition_active() -> bool:
	return _expedition_active


func is_waiting_for_combat() -> bool:
	return _waiting_for_combat


func battle_player_position() -> Vector2:
	return player_combat_position


func set_player_combat_position(position: Vector2) -> void:
	player_combat_position = position


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not _expedition_active:
		return
	if _combat_mode or _waiting_for_combat:
		return
	spawn_timer += delta
	if spawn_timer >= next_spawn_time:
		_waiting_for_combat = true
		monster_spawn_requested.emit()


func _reset_spawn_timer() -> void:
	spawn_timer = 0.0
	var low := minf(spawn_interval_min, spawn_interval_max)
	var high := maxf(spawn_interval_min, spawn_interval_max)
	next_spawn_time = _rng.randf_range(low, high)
