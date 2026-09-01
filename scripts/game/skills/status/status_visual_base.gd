class_name StatusVisualBase
extends Node2D

signal event_animation_finished

@export var tint := Color.WHITE
@export var loop_cycle_seconds := 1.0

var status_data: Dictionary = {}
var _sprite: Sprite2D
var _animation_player: AnimationPlayer
var _event_tween: Tween
var _loop_elapsed := 0.0
var _loop_active := false

const ALLOWED_ANIMATIONS: Array[StringName] = [
	&"RESET", &"apply", &"refresh", &"stack", &"loop", &"tick", &"absorb", &"break", &"remove",
]


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _animation_player != null and not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)
	_sprite.modulate = tint
	set_process(false)


func setup(status: Dictionary) -> void:
	status_data = status.duplicate(true)
	if _sprite == null:
		_ready()
	var texture := DataTables.skill_icon_texture(str(status.get("source_skill_id", status.get("status_id", ""))))
	if texture != null:
		_sprite.texture = texture
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			_sprite.scale = Vector2(30.0 / texture_size.x, 30.0 / texture_size.y)
	_sprite.modulate = Color(tint.r, tint.g, tint.b, 0.72)


func update_status(status: Dictionary) -> void:
	status_data = status.duplicate(true)


func contract_errors() -> Array[String]:
	_bind_nodes()
	var errors: Array[String] = []
	if _sprite == null:
		errors.append("状态场景缺少名为 Sprite 的 Sprite2D")
	if _animation_player == null:
		return errors
	for library_name in _animation_player.get_animation_library_list():
		var library := _animation_player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			if not ALLOWED_ANIMATIONS.has(animation_name):
				errors.append("状态场景包含未知动画 %s" % animation_name)
			var animation := library.get_animation(animation_name)
			for track_index in range(animation.get_track_count()):
				if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
					errors.append("状态动画 %s 不能包含方法轨道" % animation_name)
					break
	if _has_animation(&"loop") and _animation_player.get_animation(&"loop").loop_mode == Animation.LOOP_NONE:
		errors.append("状态 loop 动画必须循环")
	return errors


func set_loop_active(active: bool) -> void:
	_loop_active = active
	visible = active
	_loop_elapsed = 0.0
	set_process(active and not _has_animation("loop"))
	if active:
		scale = Vector2.ONE
		modulate = Color.WHITE
		if _has_animation("loop"):
			_animation_player.play(&"loop")
	elif _animation_player != null and _animation_player.current_animation == "loop":
		_animation_player.stop()


func play_event(event_data: Variant) -> float:
	visible = true
	set_process(false)
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.kill()
	var event: Dictionary = event_data if event_data is Dictionary else {"type": str(event_data)}
	var animation_name := _event_animation_name(event)
	if _has_animation(animation_name):
		_animation_player.play(animation_name)
		return maxf(0.01, _animation_player.get_animation(animation_name).length)
	return _play_fallback_event(animation_name)


func _event_animation_name(event: Dictionary) -> StringName:
	var event_type := str(event.get("type", ""))
	match event_type:
		"status_added":
			return &"apply"
		"status_refreshed":
			return &"refresh" if _has_animation("refresh") else &"apply"
		"status_stacked":
			return &"stack" if _has_animation("stack") else &"apply"
		"status_tick":
			return &"tick"
		"shield_absorbed":
			return &"absorb"
		"status_removed":
			var status: Dictionary = event.get("status", status_data)
			if str(event.get("reason", "")) == "depleted" and str(status.get("kind", "")) == "shield":
				return &"break"
			return &"remove"
		_:
			return &"apply"


func _play_fallback_event(animation_name: StringName) -> float:
	var duration := 0.18
	_event_tween = create_tween()
	match animation_name:
		&"tick":
			_event_tween.tween_property(self, "scale", Vector2(1.25, 1.25), duration * 0.5)
			_event_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.5)
		&"absorb":
			_event_tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.4, 1.0), duration * 0.5)
			_event_tween.tween_property(self, "modulate", Color.WHITE, duration * 0.5)
		&"break", &"remove":
			duration = 0.22
			_event_tween.set_parallel(true)
			_event_tween.tween_property(self, "modulate:a", 0.0, duration)
			_event_tween.tween_property(self, "scale", Vector2(1.35, 1.35), duration)
		_:
			_event_tween.tween_property(self, "scale", Vector2(1.2, 1.2), duration * 0.5)
			_event_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.5)
	_event_tween.finished.connect(_on_fallback_event_finished)
	return duration


func _has_animation(animation_name: StringName) -> bool:
	return _animation_player != null and _animation_player.has_animation(animation_name)


func _bind_nodes() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"loop":
		return
	event_animation_finished.emit()
	_restore_loop()


func _on_fallback_event_finished() -> void:
	event_animation_finished.emit()
	_restore_loop()


func _restore_loop() -> void:
	if _loop_active:
		visible = true
		if _has_animation("loop"):
			_animation_player.play(&"loop")
		else:
			set_process(true)
	else:
		visible = false


func _process(delta: float) -> void:
	if not _loop_active:
		return
	_loop_elapsed = fmod(_loop_elapsed + delta, maxf(0.2, loop_cycle_seconds))
	var phase := _loop_elapsed / maxf(0.2, loop_cycle_seconds)
	var pulse := 1.0 + sin(phase * TAU) * 0.08
	scale = Vector2(pulse, pulse)
