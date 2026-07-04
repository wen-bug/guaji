class_name CombatActorStateMachine
extends RefCounted

const STATE_IDLE := "idle"
const STATE_APPROACH := "approach"
const STATE_READY := "ready"
const STATE_CASTING := "casting"
const STATE_RECOVERING := "recovering"
const STATE_HURT := "hurt"
const STATE_DEAD := "dead"

const VALID_STATES := [
	STATE_IDLE,
	STATE_APPROACH,
	STATE_READY,
	STATE_CASTING,
	STATE_RECOVERING,
	STATE_HURT,
	STATE_DEAD,
]

var state := STATE_IDLE
var cooldown := 0.0


func set_state(next_state: String) -> void:
	if not VALID_STATES.has(next_state):
		return
	state = next_state


func enter_recovering(duration: float) -> void:
	cooldown = max(0.0, duration)
	set_state(STATE_RECOVERING)


func tick(delta: float) -> void:
	if state != STATE_RECOVERING:
		return
	cooldown = max(0.0, cooldown - delta)
	if cooldown <= 0.0:
		set_state(STATE_READY)


func is_ready() -> bool:
	return state == STATE_READY or state == STATE_IDLE


func is_dead() -> bool:
	return state == STATE_DEAD
