class_name ActorState
extends RefCounted


func can_enter(_actor: Node, _payload: Dictionary = {}) -> bool:
	return true


func enter(_actor: Node, _payload: Dictionary = {}) -> void:
	pass


func update(_actor: Node, _delta: float):
	return null


func handle_event(_actor: Node, _event_id: StringName, _payload: Dictionary = {}):
	return null


func exit(_actor: Node) -> void:
	pass
