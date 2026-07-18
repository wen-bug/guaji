class_name ModEventBus
extends RefCounted

const EVENT_GAME_READY := &"game_ready"
const EVENT_SAVE_LOADED := &"save_loaded"
const EVENT_BEFORE_SAVE := &"before_save"
const EVENT_MEMBER_CREATED := &"member_created"
const EVENT_COMBAT_STARTED := &"combat_started"
const EVENT_COMBAT_FINISHED := &"combat_finished"

const SUPPORTED_EVENTS: Array[StringName] = [
	EVENT_GAME_READY,
	EVENT_SAVE_LOADED,
	EVENT_BEFORE_SAVE,
	EVENT_MEMBER_CREATED,
	EVENT_COMBAT_STARTED,
	EVENT_COMBAT_FINISHED,
]

var _listeners: Dictionary = {}


func subscribe(event_id: StringName, callback: Callable) -> bool:
	if not SUPPORTED_EVENTS.has(event_id) or not callback.is_valid():
		return false
	if not _listeners.has(event_id):
		_listeners[event_id] = []
	var callbacks: Array = _listeners[event_id]
	if not callbacks.has(callback):
		callbacks.append(callback)
	return true


func unsubscribe(event_id: StringName, callback: Callable) -> void:
	if not _listeners.has(event_id):
		return
	(_listeners[event_id] as Array).erase(callback)


func emit_event(event_id: StringName, payload: Dictionary = {}) -> void:
	if not SUPPORTED_EVENTS.has(event_id):
		return
	for callback in (_listeners.get(event_id, []) as Array).duplicate():
		if callback is Callable and callback.is_valid():
			callback.call(payload.duplicate(true))
