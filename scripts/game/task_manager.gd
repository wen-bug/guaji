class_name TaskManager
extends RefCounted

signal queue_changed
signal current_changed(task: Dictionary)
signal log_added(message: String)

var game_state
var zones
var queue: Array = []
var current_task: Dictionary = {}
var paused := false


func _init(initial_state, zone_manager) -> void:
	game_state = initial_state
	zones = zone_manager


func add_task(task_type: int) -> void:
	log_added.emit("%s 请通过对应界面执行" % DataTables.task_name(task_type))


func clear_queue() -> void:
	queue.clear()
	current_task = {}
	queue_changed.emit()
	current_changed.emit(current_task)
	log_added.emit("任务队列已取消")


func remove_task(_task_id: int) -> void:
	queue_changed.emit()


func toggle_pause() -> void:
	paused = not paused
	log_added.emit("任务队列已取消")


func register_player_input() -> void:
	pass


func update(_delta: float, character, _combat) -> void:
	if character != null:
		character.set_idle_roam()


func queue_summary() -> Array:
	return []


func current_task_name() -> String:
	return "空闲"
