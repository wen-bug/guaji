class_name CharacterController
extends CharacterBody2D

enum CharacterState { IDLE, ROAMING, TALKING, PAUSED, EXPEDITION_RUNNING }

const BASELINE_Y := 170.0
const HOME_LEFT := 48.0
const HOME_RIGHT := 676.0
const HOME_X := 86.0
const WORLD_LEFT := 28.0
const WORLD_RIGHT := 930.0
const GRAVITY := 900.0
const TALK_LINES := [
	"今天也要稳稳修行。",
	"家里真清静。",
	"等一个新任务。",
	"先散散步。",
]

var speed := 140.0
var target_position := Vector2.ZERO
var moving := false
var state := CharacterState.IDLE
var idle_timer := 0.0
var talk_timer := 0.0
var vertical_velocity := 0.0
var rng := RandomNumberGenerator.new()
var sprite: AnimatedSprite2D
var talk_label: Label


func setup() -> void:
	_bind_scene_nodes()
	rng.randomize()
	position = Vector2(HOME_X, BASELINE_Y)
	target_position = position
	vertical_velocity = 0.0
	_set_state(CharacterState.IDLE)
	_reset_idle_timer()


func is_on_ground() -> bool:
	return is_equal_approx(position.y, BASELINE_Y) and is_equal_approx(vertical_velocity, 0.0)


func set_idle_roam() -> void:
	if _is_busy_with_home_idle():
		return

	if position.x < HOME_LEFT or position.x > HOME_RIGHT:
		_walk_to(Vector2(HOME_X, BASELINE_Y), CharacterState.ROAMING)
	else:
		_set_state(CharacterState.IDLE)
		if idle_timer <= 0.0:
			_reset_idle_timer()


func enter_expedition_run(run_position: Vector2) -> void:
	_bind_scene_nodes()
	moving = false
	target_position = run_position
	position = run_position
	vertical_velocity = 0.0
	if talk_label != null:
		talk_label.visible = false
	if sprite != null:
		sprite.flip_h = false
	_set_state(CharacterState.EXPEDITION_RUNNING)


func exit_expedition_run() -> void:
	_bind_scene_nodes()
	moving = false
	position = Vector2(HOME_X, BASELINE_Y)
	target_position = position
	vertical_velocity = 0.0
	if talk_label != null:
		talk_label.visible = false
	_set_state(CharacterState.IDLE)
	_reset_idle_timer()


func _ready() -> void:
	_bind_scene_nodes()


func _process(delta: float) -> void:
	if moving:
		_update_movement(delta)
	else:
		match state:
			CharacterState.EXPEDITION_RUNNING:
				_play_animation("run")
			CharacterState.IDLE:
				idle_timer -= delta
				if idle_timer <= 0.0:
					_choose_home_idle_action()
			CharacterState.TALKING:
				talk_timer -= delta
				if talk_timer <= 0.0:
					talk_label.visible = false
					_set_state(CharacterState.IDLE)
					_reset_idle_timer()
	_apply_gravity(delta)


func _update_movement(delta: float) -> void:
	var distance := speed * delta
	position.x = move_toward(position.x, target_position.x, distance)
	if abs(position.x - target_position.x) <= 1.0:
		position.x = target_position.x
		moving = false
		if state == CharacterState.ROAMING:
			_set_state(CharacterState.IDLE)
			_reset_idle_timer()


func _apply_gravity(delta: float) -> void:
	if position.y < BASELINE_Y or vertical_velocity > 0.0:
		vertical_velocity += GRAVITY * delta
		position.y = minf(BASELINE_Y, position.y + vertical_velocity * delta)
		if is_equal_approx(position.y, BASELINE_Y):
			position.y = BASELINE_Y
			vertical_velocity = 0.0
	elif position.y > BASELINE_Y:
		position.y = BASELINE_Y
		vertical_velocity = 0.0


func _choose_home_idle_action() -> void:
	if rng.randf() < 0.42:
		_start_talking()
	else:
		var next_x := rng.randf_range(HOME_LEFT, HOME_RIGHT)
		_walk_to(Vector2(next_x, BASELINE_Y), CharacterState.ROAMING)


func _start_talking() -> void:
	talk_label.text = TALK_LINES[rng.randi_range(0, TALK_LINES.size() - 1)]
	talk_label.visible = true
	talk_timer = rng.randf_range(1.6, 2.8)
	_set_state(CharacterState.TALKING)


func _walk_to(target: Vector2, next_state: CharacterState) -> void:
	target_position = Vector2(clamp(target.x, WORLD_LEFT, WORLD_RIGHT), BASELINE_Y)
	if abs(position.x - target_position.x) <= 1.0:
		moving = false
		_set_state(CharacterState.IDLE)
		_reset_idle_timer()
		return

	moving = true
	talk_label.visible = false
	_face_target()
	_set_state(next_state)


func _face_target() -> void:
	if sprite == null:
		return
	sprite.flip_h = target_position.x < position.x


func _set_state(next_state: CharacterState) -> void:
	if state == next_state and sprite != null and sprite.is_playing():
		return

	state = next_state
	match state:
		CharacterState.ROAMING, CharacterState.EXPEDITION_RUNNING:
			_play_animation("run")
		_:
			_play_animation("idle")


func _play_animation(animation_name: StringName) -> void:
	if sprite == null:
		return
	if sprite.animation != animation_name:
		sprite.animation = animation_name
	sprite.play()


func _reset_idle_timer() -> void:
	idle_timer = rng.randf_range(0.8, 1.8)


func _is_busy_with_home_idle() -> bool:
	return state == CharacterState.ROAMING or state == CharacterState.TALKING or state == CharacterState.EXPEDITION_RUNNING


func _bind_scene_nodes() -> void:
	if sprite == null:
		sprite = $Sprite
	if talk_label == null:
		talk_label = $TalkLabel
