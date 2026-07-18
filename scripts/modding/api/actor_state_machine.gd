extends RefCounted
class_name ActorStateMachine

var actor: Node = null
var state_id: String = ""
var state: ActorState = null
var factory_resolver: Callable


func setup(value_actor: Node, value_factory_resolver: Callable) -> void:
	actor = value_actor
	factory_resolver = value_factory_resolver


func transition(next_state_id: String, payload: Dictionary = {}) -> bool:
	if next_state_id.is_empty() or not factory_resolver.is_valid():
		return false
	var factory = factory_resolver.call(next_state_id)
	if not (factory is Callable) or not factory.is_valid():
		return false
	var next_state = factory.call()
	if not (next_state is ActorState) or not next_state.can_enter(actor, payload.duplicate(true)):
		return false
	if state != null:
		state.exit(actor)
	state_id = next_state_id
	state = next_state
	state.enter(actor, payload.duplicate(true))
	return true


func update(delta: float):
	if state == null:
		return null
	var requested = state.update(actor, delta)
	if requested is String and not str(requested).is_empty():
		return str(requested)
	return null


func handle_event(event_id: StringName, payload: Dictionary = {}):
	if state == null:
		return null
	var requested = state.handle_event(actor, event_id, payload.duplicate(true))
	if requested is String and not str(requested).is_empty():
		return str(requested)
	return null


func clear() -> void:
	if state != null:
		state.exit(actor)
	state = null
	state_id = ""
