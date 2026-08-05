class_name BattleMap
extends Node2D

signal monster_spawn_requested

const ExpeditionMapDefinitionScript = preload("res://scripts/map/expedition_map_definition.gd")

@export var spawn_interval_min := 3.0
@export var spawn_interval_max := 5.0
@export var first_spawn_delay := 1.0
@export var map_definitions: Array[Resource] = []
@export var default_map_id := "verdant_forest"
## 旧场景兼容入口；配置 map_definitions 后由当前地图覆盖。
@export var encounter_profile: Resource

var scene_viewport_size := Vector2(960, 480)
var spawn_timer := 0.0
var next_spawn_time := 0.0
var player_combat_position := Vector2(736, 170)
var selected_map_id := ""

var _expedition_active := false
var _waiting_for_combat := false
var _combat_mode := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_select_initial_map()
	_apply_map_visuals()
	visible = false
	set_process(false)


func set_scene_viewport_size(viewport_size: Vector2) -> void:
	scene_viewport_size = viewport_size
	_apply_map_visuals()


func map_summaries(expedition_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for resource in map_definitions:
		var definition: Resource = _as_map_definition(resource)
		if definition != null:
			result.append(definition.call("summary", expedition_level))
	return result


func select_map(map_id: String, expedition_level: int) -> bool:
	var definition: Resource = map_definition(map_id)
	if definition == null or not bool(definition.call("is_unlocked", expedition_level)):
		return false
	selected_map_id = str(definition.get("map_id"))
	encounter_profile = definition.get("encounter_profile") as Resource
	_apply_map_visuals()
	return true


func map_definition(map_id: String) -> Resource:
	for resource in map_definitions:
		var definition: Resource = _as_map_definition(resource)
		if definition != null and str(definition.get("map_id")) == map_id:
			return definition
	return null


func current_map_definition() -> Resource:
	return map_definition(selected_map_id)


func current_map_name() -> String:
	var definition: Resource = current_map_definition()
	return str(definition.get("display_name")) if definition != null else "历练地图"


func enter_expedition() -> void:
	_expedition_active = true
	_waiting_for_combat = false
	_combat_mode = false
	visible = true
	_reset_spawn_timer(maxf(0.0, first_spawn_delay))
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


func set_player_combat_position(combat_position: Vector2) -> void:
	player_combat_position = combat_position


func roll_encounter(party_size: int, level: int, rng: RandomNumberGenerator) -> Array[String]:
	if encounter_profile == null:
		push_error("BattleMap 缺少 encounter_profile，无法生成遭遇")
		return []
	return encounter_profile.roll_enemy_ids(party_size, level, rng)


func _select_initial_map() -> void:
	if select_map(default_map_id, 1):
		return
	for resource in map_definitions:
		var definition: Resource = _as_map_definition(resource)
		if definition != null and bool(definition.call("is_unlocked", 1)):
			select_map(str(definition.get("map_id")), 1)
			return


func _as_map_definition(resource: Resource) -> Resource:
	if resource != null and resource.get_script() == ExpeditionMapDefinitionScript:
		return resource
	return null


func _apply_map_visuals() -> void:
	var background := get_node_or_null("Background") as ColorRect
	var ground := get_node_or_null("Ground") as ColorRect
	if background != null:
		background.position = Vector2.ZERO
		background.size = scene_viewport_size
	if ground != null:
		ground.position = Vector2(0.0, scene_viewport_size.y * 0.68)
		ground.size = Vector2(scene_viewport_size.x, scene_viewport_size.y * 0.32)
	var definition: Resource = current_map_definition()
	if definition == null:
		return
	if background != null:
		background.color = definition.get("background_color")
	if ground != null:
		ground.color = definition.get("ground_color")


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


func _reset_spawn_timer(delay_override: float = -1.0) -> void:
	spawn_timer = 0.0
	if delay_override >= 0.0:
		next_spawn_time = delay_override
		return
	var low := minf(spawn_interval_min, spawn_interval_max)
	var high := maxf(spawn_interval_min, spawn_interval_max)
	next_spawn_time = _rng.randf_range(low, high)
