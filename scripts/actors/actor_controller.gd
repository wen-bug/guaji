class_name ActorController
extends CharacterBody2D

signal hit_candidate(action_id: int, target_id: String)
signal attack_finished(action_id: int)
signal death_finished(actor_id: String)

enum ActorMode {
	IDLE,
	ROAMING,
	TALKING,
	PAUSED,
	EXPEDITION_RUNNING,
	COMBAT_READY,
	COMBAT_MOVING,
	COMBAT_ACTING,
	DEAD,
}

const CombatActorStatusScript = preload("res://scripts/game/combat/combat_actor_status.gd")
const DEFAULT_VISUAL_ID := "actor_default"
const PARTY_VISUAL_ROOT := "res://scripts/actors/visuals/party"
const BASELINE_Y := 170.0
const HOME_X := 86.0
const HOME_SPACING := 72.0
const HOME_ROAM_RADIUS := 46.0
const WORLD_LEFT := 28.0
const WORLD_RIGHT := 930.0
const TALK_BUBBLE_Y := -112.0
const TALK_BUBBLE_LANE_OFFSET := 50.0
static var active_talker: Node = null

var member_id := ""
var member_data: Dictionary = {}
var visual_id := DEFAULT_VISUAL_ID
var party_index := 0
var speed := 140.0
var target_position := Vector2.ZERO
var home_anchor := Vector2(HOME_X, BASELINE_Y)
var formation_position := Vector2.ZERO
var moving := false
var state := ActorMode.IDLE
var idle_timer := 0.0
var talk_timer := 0.0
var combat_motion_timer := 0.0
var rng := RandomNumberGenerator.new()
var visual_root: Node2D
var talk_bubble: Control
var talk_label: Label
var talk_tween: Tween
var combat_visual: CombatVisual
var combat_status: CombatActorStatus


func _ready() -> void:
	_bind_scene_nodes()
	rng.randomize()


func configure_member(member: Dictionary, index: int) -> void:
	_bind_scene_nodes()
	member_data = member.duplicate(true)
	member_id = str(member.get("id", ""))
	visual_id = str(member.get("visual_id", DEFAULT_VISUAL_ID))
	if visual_id.is_empty():
		visual_id = DEFAULT_VISUAL_ID
	party_index = index
	home_anchor = Vector2(HOME_X + HOME_SPACING * float(index), BASELINE_Y)
	_update_talk_bubble_lane()
	_load_combat_visual()
	ensure_combat_status().visual_owner = self


func setup() -> void:
	enter_home(home_anchor)


func enter_home(anchor: Vector2 = home_anchor) -> void:
	_bind_scene_nodes()
	home_anchor = anchor
	moving = false
	position = home_anchor
	target_position = position
	combat_motion_timer = 0.0
	_hide_talk_bubble(true)
	_set_state(ActorMode.IDLE)
	_reset_idle_timer()


func set_idle_roam() -> void:
	if state != ActorMode.IDLE:
		return
	idle_timer -= get_process_delta_time()
	if idle_timer <= 0.0:
		_choose_home_idle_action()


func enter_expedition_run(run_position: Vector2) -> void:
	moving = false
	position = run_position
	target_position = position
	_hide_talk_bubble(true)
	_set_state(ActorMode.EXPEDITION_RUNNING)


func enter_combat(combat_start_position: Vector2) -> void:
	moving = false
	formation_position = combat_start_position
	position = combat_start_position
	target_position = position
	combat_motion_timer = 0.0
	_hide_talk_bubble(true)
	_set_state(ActorMode.COMBAT_READY)


func set_combat_position(value: Vector2) -> void:
	var changed := position.distance_squared_to(value) > 0.25
	position = value
	target_position = value
	if changed and state != ActorMode.COMBAT_ACTING and state != ActorMode.DEAD:
		combat_motion_timer = 0.08
		_set_state(ActorMode.COMBAT_MOVING)


func set_formation_position(value: Vector2) -> void:
	formation_position = value


func exit_expedition_run() -> void:
	enter_home(home_anchor)


func combat_position() -> Vector2:
	return global_position


func melee_approach_position() -> Vector2:
	return combat_visual.melee_approach_position() if combat_visual != null else global_position


func hit_position() -> Vector2:
	return combat_visual.hit_position() if combat_visual != null else global_position


func effect_position() -> Vector2:
	return combat_visual.effect_position() if combat_visual != null else global_position


func bind_combat_status_presentation(status: CombatActorStatus) -> void:
	if combat_visual != null:
		combat_visual.bind_combat_status(status)


func present_combat_event(event: Dictionary) -> float:
	return combat_visual.present_combat_event(event) if combat_visual != null else 0.0


func play_combat_action(action_type: String, action_id: int = 0) -> void:
	if state == ActorMode.DEAD or combat_visual == null:
		return
	combat_motion_timer = 0.0
	_set_state(ActorMode.COMBAT_ACTING, false)
	if action_type in ["ranged", "ranged_attack"]:
		combat_visual.play_ranged_attack(action_id)
	else:
		combat_visual.play_melee_attack(action_id)


func play_hurt_feedback() -> void:
	if combat_visual != null:
		combat_visual.play_hurt()


func play_level_up_feedback() -> void:
	if state != ActorMode.DEAD and combat_visual != null:
		combat_visual.play_level_up()


func play_death_feedback() -> void:
	if state == ActorMode.DEAD:
		return
	state = ActorMode.DEAD
	if combat_visual != null:
		combat_visual.play_death()


func cancel_combat_action() -> void:
	if combat_visual != null:
		combat_visual.cancel_action()
	if state != ActorMode.DEAD:
		_set_state(ActorMode.COMBAT_READY)


func ensure_combat_status() -> CombatActorStatus:
	if combat_status == null:
		combat_status = get_node_or_null("CombatActorStatus") as CombatActorStatus
	if combat_status == null:
		combat_status = CombatActorStatusScript.new()
		combat_status.name = "CombatActorStatus"
		add_child(combat_status)
	combat_status.visual_owner = self
	return combat_status


func _process(delta: float) -> void:
	if moving:
		_update_home_movement(delta)
		return
	match state:
		ActorMode.EXPEDITION_RUNNING:
			_play_visual_state(&"run")
		ActorMode.COMBAT_MOVING:
			combat_motion_timer = maxf(0.0, combat_motion_timer - delta)
			if combat_motion_timer <= 0.0:
				_set_state(ActorMode.COMBAT_READY)
		ActorMode.TALKING:
			talk_timer -= delta
			if talk_timer <= 0.0:
				_hide_talk_bubble()
				_set_state(ActorMode.IDLE)
				_reset_idle_timer()


func _choose_home_idle_action() -> void:
	if rng.randf() < 0.42 and _start_talking():
		return
	var left := maxf(WORLD_LEFT, home_anchor.x - HOME_ROAM_RADIUS)
	var right := minf(WORLD_RIGHT, home_anchor.x + HOME_ROAM_RADIUS)
	_walk_to(Vector2(rng.randf_range(left, right), BASELINE_Y))


func _start_talking() -> bool:
	if talk_bubble == null or talk_label == null:
		return false
	if active_talker != null and is_instance_valid(active_talker) and active_talker != self:
		return false
	active_talker = self
	var dialogue := _pick_dialogue()
	if dialogue.is_empty():
		return false
	talk_label.text = str(dialogue.get("text", ""))
	_show_talk_bubble()
	talk_timer = rng.randf_range(1.6, 2.8)
	_set_state(ActorMode.TALKING)
	return true


func _walk_to(target: Vector2) -> void:
	target_position = Vector2(clampf(target.x, WORLD_LEFT, WORLD_RIGHT), BASELINE_Y)
	moving = true
	_hide_talk_bubble(true)
	_face_target(target_position)
	_set_state(ActorMode.ROAMING)


func _update_home_movement(delta: float) -> void:
	position.x = move_toward(position.x, target_position.x, speed * delta)
	if absf(position.x - target_position.x) > 1.0:
		return
	position.x = target_position.x
	moving = false
	_set_state(ActorMode.IDLE)
	_reset_idle_timer()


func _face_target(target: Vector2) -> void:
	if combat_visual != null and combat_visual.animated_sprite != null:
		combat_visual.animated_sprite.flip_h = target.x < position.x


func _set_state(next_state: ActorMode, play_animation: bool = true) -> void:
	if state == next_state and play_animation:
		return
	state = next_state
	if not play_animation:
		return
	match state:
		ActorMode.ROAMING:
			_play_visual_state(&"walk")
		ActorMode.EXPEDITION_RUNNING, ActorMode.COMBAT_MOVING:
			_play_visual_state(&"run")
		ActorMode.DEAD:
			pass
		_:
			_play_visual_state(&"idle")


func _play_visual_state(animation_name: StringName) -> void:
	if combat_visual == null:
		return
	match animation_name:
		&"walk":
			combat_visual.play_walk()
		&"run":
			combat_visual.play_run()
		_:
			combat_visual.play_idle()


func _load_combat_visual() -> void:
	_bind_scene_nodes()
	if combat_visual != null and combat_visual.get_meta("visual_id", "") == visual_id:
		combat_visual.configure_identity(member_id, CombatHurtbox.TEAM_PARTY)
		return
	if combat_visual != null:
		combat_visual.queue_free()
		combat_visual = null
	var scene_path := _appearance_scene_path(visual_id, "party", DEFAULT_VISUAL_ID)
	if not ResourceLoader.exists(scene_path):
		push_warning("角色形象不存在，使用默认形象: %s" % scene_path)
		scene_path = _appearance_scene_path(DEFAULT_VISUAL_ID, "party", DEFAULT_VISUAL_ID)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("默认角色形象加载失败: %s" % scene_path)
		return
	var instance := packed.instantiate()
	combat_visual = instance as CombatVisual
	if combat_visual == null:
		instance.queue_free()
		push_error("角色形象根节点必须使用 CombatVisual: %s" % scene_path)
		return
	var contract_issue := combat_visual.contract_error()
	if not contract_issue.is_empty() and not scene_path.ends_with("/%s.tscn" % DEFAULT_VISUAL_ID):
		push_warning("角色形象接口不完整（%s），使用默认形象: %s" % [contract_issue, scene_path])
		combat_visual.free()
		scene_path = "%s/%s.tscn" % [PARTY_VISUAL_ROOT, DEFAULT_VISUAL_ID]
		packed = load(scene_path) as PackedScene
		combat_visual = packed.instantiate() as CombatVisual if packed != null else null
	if combat_visual == null:
		push_error("默认角色形象加载失败: %s" % scene_path)
		return
	contract_issue = combat_visual.contract_error()
	if not contract_issue.is_empty():
		combat_visual.free()
		combat_visual = null
		push_error("默认角色形象接口不完整（%s）: %s" % [contract_issue, scene_path])
		return
	visual_root.add_child(combat_visual)
	combat_visual.set_meta("visual_id", visual_id)
	combat_visual.configure_identity(member_id, CombatHurtbox.TEAM_PARTY)
	combat_visual.hit_candidate.connect(_on_visual_hit_candidate)
	combat_visual.attack_finished.connect(_on_visual_attack_finished)
	combat_visual.death_finished.connect(_on_visual_death_finished)
	_play_visual_state(&"idle")


func _pick_dialogue() -> Dictionary:
	var lines := [
		"今天也要稳稳修行。",
		"家里真清静。",
		"等一个新任务。",
		"先散散步。",
	]
	return {"text": lines[rng.randi_range(0, lines.size() - 1)]}


func _appearance_scene_path(requested_id: String, expected_kind: String, fallback_id: String) -> String:
	var definition := DataTables.content_definition("appearance", requested_id)
	if str(definition.get("kind", "")) == expected_kind:
		var registered_path := str(definition.get("scene_path", ""))
		if ResourceLoader.exists(registered_path):
			return registered_path
	var fallback := DataTables.content_definition("appearance", fallback_id)
	var fallback_path := str(fallback.get("scene_path", ""))
	if ResourceLoader.exists(fallback_path):
		return fallback_path
	return "%s/%s.tscn" % [PARTY_VISUAL_ROOT, _safe_visual_id(fallback_id)]


func _safe_visual_id(value: String) -> String:
	var result := ""
	for character in value:
		if character.is_valid_identifier() or character == "_" or character.is_valid_int():
			result += character
	return result if not result.is_empty() else DEFAULT_VISUAL_ID


func _on_visual_hit_candidate(action_id: int, target_id: String) -> void:
	hit_candidate.emit(action_id, target_id)


func _on_visual_attack_finished(action_id: int) -> void:
	if state != ActorMode.DEAD:
		_set_state(ActorMode.COMBAT_READY)
	attack_finished.emit(action_id)


func _on_visual_death_finished() -> void:
	death_finished.emit(member_id)


func _reset_idle_timer() -> void:
	idle_timer = rng.randf_range(0.8, 1.8)


func _show_talk_bubble() -> void:
	if talk_bubble == null:
		return
	if talk_tween != null:
		talk_tween.kill()
	talk_bubble.visible = true
	talk_bubble.modulate.a = 0.0
	talk_bubble.scale = Vector2(0.92, 0.92)
	talk_tween = create_tween().set_parallel(true)
	talk_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	talk_tween.tween_property(talk_bubble, "modulate:a", 1.0, 0.14)
	talk_tween.tween_property(talk_bubble, "scale", Vector2.ONE, 0.16)


func _hide_talk_bubble(immediate: bool = false) -> void:
	if active_talker == self:
		active_talker = null
	if talk_bubble == null:
		return
	if talk_tween != null:
		talk_tween.kill()
		talk_tween = null
	if immediate or not talk_bubble.visible:
		talk_bubble.visible = false
		talk_bubble.modulate.a = 1.0
		talk_bubble.scale = Vector2.ONE
		return
	talk_tween = create_tween().set_parallel(true)
	talk_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	talk_tween.tween_property(talk_bubble, "modulate:a", 0.0, 0.1)
	talk_tween.tween_property(talk_bubble, "scale", Vector2(0.96, 0.96), 0.1)
	talk_tween.chain().tween_callback(func():
		if talk_bubble != null:
			talk_bubble.visible = false
			talk_bubble.modulate.a = 1.0
			talk_bubble.scale = Vector2.ONE
	)


func _update_talk_bubble_lane() -> void:
	if talk_bubble == null:
		return
	talk_bubble.position.y = TALK_BUBBLE_Y - TALK_BUBBLE_LANE_OFFSET * float(party_index % 2)


func _bind_scene_nodes() -> void:
	if visual_root == null:
		visual_root = get_node_or_null("VisualRoot") as Node2D
	if talk_bubble == null:
		talk_bubble = get_node_or_null("TalkBubble") as Control
	if talk_label == null:
		talk_label = get_node_or_null("TalkBubble/BubbleLabel") as Label
