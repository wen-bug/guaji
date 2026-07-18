class_name CombatVisual
extends Node2D

signal hit_candidate(action_id: int, target_id: String)
signal attack_finished(action_id: int)
signal death_finished

const CombatHitboxScript = preload("res://scripts/actors/visuals/combat_hitbox.gd")
const CombatHurtboxScript = preload("res://scripts/actors/visuals/combat_hurtbox.gd")

const WALK_ANIMATIONS: Array[StringName] = [&"walk", &"run", &"idle"]
const RUN_ANIMATIONS: Array[StringName] = [&"run", &"walk", &"idle"]
const MELEE_ATTACK_ANIMATIONS: Array[StringName] = [&"melee_attack", &"attack"]
const RANGED_ATTACK_ANIMATIONS: Array[StringName] = [&"ranged_attack", &"attack", &"melee_attack"]

@export var placeholder_color := Color.WHITE
@export var attack_hit_start_frame := 3
@export var attack_hit_end_frame := 5

var actor_id := ""
var team := ""
var active_action_id := 0
var active_attack_animation: StringName = &""
var active_attack_uses_hitbox := false
var active_transient_animation: StringName = &""

var sprite: CanvasItem
var animated_sprite: AnimatedSprite2D
var animation_player: AnimationPlayer
var hurtbox: CombatHurtbox
var attack_hitbox: CombatHitbox
var melee_marker: Marker2D
var hit_socket: Marker2D
var effect_socket: Marker2D
var hp_fill: ColorRect
var _hurt_tween: Tween
var _death_tween: Tween
var _death_finished_emitted := false


func _ready() -> void:
	_bind_nodes()
	_ensure_runtime_contract()
	_bind_nodes()
	_connect_nodes()
	_apply_placeholder_color()
	close_attack_window()


func configure_identity(value_actor_id: String, value_team: String) -> void:
	_bind_nodes()
	_ensure_runtime_contract()
	_bind_nodes()
	_connect_nodes()
	actor_id = value_actor_id
	team = value_team
	if hurtbox != null:
		hurtbox.configure_identity(actor_id, team)
	if attack_hitbox != null:
		attack_hitbox.configure_identity(actor_id, team)
	close_attack_window()


func play_idle() -> void:
	active_transient_animation = &""
	_play_first_available([&"idle"], true)


func play_walk() -> void:
	active_transient_animation = &""
	_play_first_available(WALK_ANIMATIONS, true)


func play_run() -> void:
	active_transient_animation = &""
	_play_first_available(RUN_ANIMATIONS, true)


func play_attack(action_id: int) -> void:
	play_melee_attack(action_id)


func play_melee_attack(action_id: int) -> void:
	_play_attack(action_id, MELEE_ATTACK_ANIMATIONS, true)


func play_ranged_attack(action_id: int) -> void:
	_play_attack(action_id, RANGED_ATTACK_ANIMATIONS, false)


func _play_attack(action_id: int, animation_names: Array[StringName], uses_hitbox: bool) -> void:
	active_action_id = action_id
	active_attack_uses_hitbox = uses_hitbox
	close_attack_window()
	active_attack_animation = _play_first_available(animation_names, false)
	if active_attack_animation.is_empty():
		call_deferred("_finish_attack")


func play_hurt() -> void:
	_bind_nodes()
	if sprite == null:
		return
	if _hurt_tween != null:
		_hurt_tween.kill()
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(sprite, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.05)
	_hurt_tween.tween_property(sprite, "modulate", placeholder_color, 0.13)


func play_death() -> void:
	cancel_action()
	_death_finished_emitted = false
	if not _play_first_available([&"death"], false).is_empty():
		return
	if _death_tween != null:
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(self, "scale:y", 0.15, 0.35)
	_death_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	_death_tween.chain().tween_callback(_emit_death_finished)


func play_level_up() -> void:
	if active_action_id > 0:
		return
	active_transient_animation = _play_first_available([&"level_up"], false)
	if active_transient_animation.is_empty():
		play_idle()


func cancel_action() -> void:
	close_attack_window()
	active_action_id = 0
	active_attack_animation = &""
	active_attack_uses_hitbox = false
	active_transient_animation = &""
	if animation_player != null:
		animation_player.stop()
	if animated_sprite != null:
		animated_sprite.stop()


func melee_approach_position() -> Vector2:
	_bind_nodes()
	return melee_marker.global_position if melee_marker != null else global_position


func hit_position() -> Vector2:
	_bind_nodes()
	return hit_socket.global_position if hit_socket != null else global_position


func effect_position() -> Vector2:
	_bind_nodes()
	return effect_socket.global_position if effect_socket != null else hit_position()


func contract_error() -> String:
	_bind_nodes()
	_ensure_runtime_contract()
	_bind_nodes()
	if sprite == null:
		return "缺少 AnimatedSprite2D 或 Sprite2D"
	if animation_player == null:
		return "缺少 AnimationPlayer"
	if hurtbox == null or hurtbox.get_node_or_null("CollisionShape2D") == null:
		return "缺少 Hurtbox/CollisionShape2D"
	if attack_hitbox == null or attack_hitbox.get_node_or_null("CollisionShape2D") == null:
		return "缺少 AttackHitbox/CollisionShape2D"
	if melee_marker == null:
		return "缺少 Marker2D"
	if hit_socket == null:
		return "缺少 HitSocket"
	if effect_socket == null:
		return "缺少 EffectSocket"
	return ""


func set_hit_points(current_hp: int, max_hp: int) -> void:
	_bind_nodes()
	if hp_fill == null:
		return
	var width := float(hp_fill.get_meta("full_width", hp_fill.size.x))
	hp_fill.set_meta("full_width", width)
	hp_fill.size.x = width * clamp(float(current_hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)


func open_attack_window() -> void:
	if attack_hitbox != null and active_action_id > 0 and active_attack_uses_hitbox:
		attack_hitbox.open_window(active_action_id)


func close_attack_window() -> void:
	if attack_hitbox != null:
		attack_hitbox.close_window()


func _play_named_animation(animation_name: StringName, looped: bool) -> void:
	_bind_nodes()
	if animated_sprite != null and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.sprite_frames.set_animation_loop(animation_name, looped)
		animated_sprite.play(animation_name)
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)


func _play_first_available(animation_names: Array[StringName], looped: bool) -> StringName:
	_bind_nodes()
	for animation_name in animation_names:
		if _has_animation(animation_name):
			_play_named_animation(animation_name, looped)
			return animation_name
	return &""


func _has_animation(animation_name: StringName) -> bool:
	if animated_sprite != null and animated_sprite.sprite_frames.has_animation(animation_name):
		return true
	return animation_player != null and animation_player.has_animation(animation_name)


func _on_sprite_frame_changed() -> void:
	if animated_sprite == null or animated_sprite.animation != active_attack_animation or active_action_id <= 0:
		return
	if active_attack_uses_hitbox and animated_sprite.frame >= attack_hit_start_frame and animated_sprite.frame <= attack_hit_end_frame:
		open_attack_window()
	else:
		close_attack_window()


func _on_sprite_animation_finished() -> void:
	if animated_sprite == null:
		return
	var animation_name := animated_sprite.animation
	if animation_name == active_attack_animation and active_action_id > 0:
		_finish_attack()
	elif animation_name == &"death":
		_emit_death_finished()
	elif animation_name == active_transient_animation:
		active_transient_animation = &""
		play_idle()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == active_attack_animation and active_action_id > 0:
		_finish_attack()
	elif animation_name == &"death":
		_emit_death_finished()
	elif animation_name == active_transient_animation:
		active_transient_animation = &""
		play_idle()


func _finish_attack() -> void:
	if active_action_id <= 0:
		return
	var finished_action_id := active_action_id
	close_attack_window()
	active_action_id = 0
	active_attack_animation = &""
	active_attack_uses_hitbox = false
	attack_finished.emit(finished_action_id)


func _emit_death_finished() -> void:
	if _death_finished_emitted:
		return
	_death_finished_emitted = true
	death_finished.emit()


func _on_hit_candidate(action_id: int, target_id: String) -> void:
	hit_candidate.emit(action_id, target_id)


func _bind_nodes() -> void:
	if animated_sprite == null:
		animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if animated_sprite == null:
			animated_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		sprite = animated_sprite
		if sprite == null:
			sprite = get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null:
			sprite = get_node_or_null("Visual") as CanvasItem
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if hurtbox == null:
		hurtbox = get_node_or_null("Hurtbox") as CombatHurtbox
	if attack_hitbox == null:
		attack_hitbox = get_node_or_null("AttackHitbox") as CombatHitbox
	if melee_marker == null:
		melee_marker = get_node_or_null("Marker2D") as Marker2D
	if hit_socket == null:
		hit_socket = get_node_or_null("HitSocket") as Marker2D
	if effect_socket == null:
		effect_socket = get_node_or_null("EffectSocket") as Marker2D
	if hp_fill == null:
		hp_fill = get_node_or_null("HPBack/HPFill") as ColorRect


func _ensure_runtime_contract() -> void:
	if hurtbox == null:
		hurtbox = CombatHurtboxScript.new()
		hurtbox.name = "Hurtbox"
		add_child(hurtbox)
		var hurt_shape := CollisionShape2D.new()
		hurt_shape.name = "CollisionShape2D"
		var hurt_rectangle := RectangleShape2D.new()
		hurt_rectangle.size = Vector2(28.0, 38.0)
		hurt_shape.shape = hurt_rectangle
		hurtbox.add_child(hurt_shape)
	if attack_hitbox == null:
		attack_hitbox = CombatHitboxScript.new()
		attack_hitbox.name = "AttackHitbox"
		attack_hitbox.position = Vector2(22.0, 0.0)
		add_child(attack_hitbox)
		var attack_shape := CollisionShape2D.new()
		attack_shape.name = "CollisionShape2D"
		var attack_rectangle := RectangleShape2D.new()
		attack_rectangle.size = Vector2(28.0, 28.0)
		attack_shape.shape = attack_rectangle
		attack_hitbox.add_child(attack_shape)
	if melee_marker == null:
		melee_marker = Marker2D.new()
		melee_marker.name = "Marker2D"
		melee_marker.position = Vector2(22.0, 0.0)
		add_child(melee_marker)
	if hit_socket == null:
		hit_socket = Marker2D.new()
		hit_socket.name = "HitSocket"
		hit_socket.position = Vector2(0.0, -10.0)
		add_child(hit_socket)
	if effect_socket == null:
		effect_socket = Marker2D.new()
		effect_socket.name = "EffectSocket"
		effect_socket.position = Vector2(16.0, -14.0)
		add_child(effect_socket)
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)


func _connect_nodes() -> void:
	if animated_sprite != null:
		if not animated_sprite.frame_changed.is_connected(_on_sprite_frame_changed):
			animated_sprite.frame_changed.connect(_on_sprite_frame_changed)
		if not animated_sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			animated_sprite.animation_finished.connect(_on_sprite_animation_finished)
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	if attack_hitbox != null and not attack_hitbox.hit_candidate.is_connected(_on_hit_candidate):
		attack_hitbox.hit_candidate.connect(_on_hit_candidate)


func _apply_placeholder_color() -> void:
	if sprite != null:
		sprite.modulate = placeholder_color
