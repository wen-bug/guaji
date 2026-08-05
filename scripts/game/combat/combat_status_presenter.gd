class_name CombatStatusPresenter
extends Node2D

const StatusVisualBaseScript = preload("res://scripts/game/skills/status/status_visual_base.gd")
const MAX_VISIBLE_ICONS := 4

var status_owner: CombatActorStatus
var effect_root: Node2D
var status_bar: HBoxContainer
var _visuals: Dictionary = {}
var _ordered_ids: Array[String] = []
var _rotation_elapsed := 0.0
var _rotation_index := 0
var _pending_loop_ids: Dictionary = {}


func setup(status_source: CombatActorStatus, socket: Node2D, bar_position: Vector2 = Vector2(-38, -64)) -> void:
	status_owner = status_source
	effect_root = socket
	if status_bar == null:
		status_bar = HBoxContainer.new()
		status_bar.name = "CombatStatusBar"
		status_bar.position = bar_position
		status_bar.add_theme_constant_override("separation", 2)
		add_child(status_bar)
	if status_owner != null and not status_owner.status_changed.is_connected(_on_status_changed):
		status_owner.status_changed.connect(_on_status_changed)
	sync_statuses(status_owner.active_statuses() if status_owner != null else [])
	set_process(true)


func sync_statuses(statuses: Array) -> void:
	var active_ids: Array[String] = []
	for raw_status in statuses:
		if not (raw_status is Dictionary):
			continue
		var status: Dictionary = raw_status
		var status_id := str(status.get("status_id", ""))
		if status_id.is_empty():
			continue
		active_ids.append(status_id)
		_ensure_visual(status)
	for status_id in _visuals.keys().duplicate():
		if not active_ids.has(str(status_id)):
			_remove_visual(str(status_id))
	_ordered_ids = active_ids
	_rotation_index = clampi(_rotation_index, 0, maxi(0, _ordered_ids.size() - 1))
	_refresh_icons(statuses)
	_refresh_loop_visibility()


func present_event(event: Dictionary) -> float:
	var status: Dictionary = event.get("status", {})
	var status_id := str(status.get("status_id", event.get("status_id", "")))
	if status_id.is_empty():
		return 0.0
	if not status.is_empty():
		_ensure_visual(status)
	var visual: Node = _visuals.get(status_id) as Node
	if visual == null:
		return 0.0
	var event_type := str(event.get("type", ""))
	if event_type == "status_added" and visual.has_signal("event_animation_finished"):
		var callback := Callable(self, "_activate_status_loop").bind(status_id)
		if not visual.is_connected("event_animation_finished", callback):
			visual.connect("event_animation_finished", callback, CONNECT_ONE_SHOT)
	var duration: float = float(visual.call("play_event", event))
	if event_type == "status_added" and not visual.has_signal("event_animation_finished"):
		get_tree().create_timer(duration).timeout.connect(_activate_status_loop.bind(status_id))
	if event_type == "status_removed":
		get_tree().create_timer(duration).timeout.connect(func(): _remove_visual(status_id))
	return duration


func _process(delta: float) -> void:
	if _ordered_ids.size() <= 1:
		return
	_rotation_elapsed += maxf(0.0, delta)
	var current: Node = _visuals.get(_ordered_ids[_rotation_index]) as Node
	var cycle: float = float(current.get("loop_cycle_seconds")) if current != null else 1.0
	if _rotation_elapsed < cycle:
		return
	_rotation_elapsed = 0.0
	_rotation_index = (_rotation_index + 1) % _ordered_ids.size()
	_refresh_loop_visibility()


func _on_status_changed(event: Dictionary) -> void:
	if status_owner == null:
		return
	var statuses := status_owner.active_statuses()
	var event_type := str(event.get("type", ""))
	if event_type == "status_removed":
		_refresh_icons(statuses)
		return
	if event_type == "shield_absorbed":
		var absorbed_id := str(event.get("status_id", ""))
		for status in statuses:
			if status is Dictionary and str(status.get("status_id", "")) == absorbed_id:
				var visual: Node = _visuals.get(absorbed_id) as Node
				if visual != null:
					visual.call("update_status", status)
				break
		_refresh_icons(statuses)
		return
	if event_type == "status_added":
		var added_status: Dictionary = event.get("status", {})
		var added_id := str(added_status.get("status_id", ""))
		if not added_id.is_empty():
			_pending_loop_ids[added_id] = true
	sync_statuses(statuses)


func _ensure_visual(status: Dictionary) -> void:
	var status_id := str(status.get("status_id", ""))
	var existing: Node = _visuals.get(status_id) as Node
	if existing != null:
		existing.call("update_status", status)
		return
	var visual: Node2D = null
	var scene_path := str(status.get("status_scene_path", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var packed := load(scene_path) as PackedScene
		visual = packed.instantiate() as Node2D if packed != null else null
	if visual == null:
		visual = StatusVisualBaseScript.new()
	effect_root.add_child(visual)
	if visual.has_method("contract_errors"):
		var errors: Array = visual.call("contract_errors")
		if not errors.is_empty():
			push_error("状态表现契约无效 [%s]: %s" % [status_id, "；".join(errors)])
			visual.queue_free()
			visual = StatusVisualBaseScript.new()
			effect_root.add_child(visual)
	visual.position = Vector2.ZERO
	visual.call("setup", status)
	_visuals[status_id] = visual
	if not _ordered_ids.has(status_id):
		_ordered_ids.append(status_id)


func _remove_visual(status_id: String) -> void:
	var visual: Node = _visuals.get(status_id) as Node
	_visuals.erase(status_id)
	_ordered_ids.erase(status_id)
	_pending_loop_ids.erase(status_id)
	_rotation_index = clampi(_rotation_index, 0, maxi(0, _ordered_ids.size() - 1))
	_rotation_elapsed = 0.0
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	_refresh_loop_visibility()


func _refresh_loop_visibility() -> void:
	for status_id in _visuals.keys():
		var visual: Node = _visuals.get(status_id) as Node
		if visual != null:
			var should_loop := not _ordered_ids.is_empty() and str(status_id) == _ordered_ids[_rotation_index] and not _pending_loop_ids.has(status_id)
			visual.call("set_loop_active", should_loop)


func _activate_status_loop(status_id: String) -> void:
	_pending_loop_ids.erase(status_id)
	_refresh_loop_visibility()


func _refresh_icons(statuses: Array) -> void:
	for child in status_bar.get_children():
		status_bar.remove_child(child)
		child.queue_free()
	var visible_count := mini(MAX_VISIBLE_ICONS, statuses.size())
	for index in range(visible_count):
		if statuses[index] is Dictionary:
			status_bar.add_child(_create_status_icon(statuses[index]))
	if statuses.size() > MAX_VISIBLE_ICONS:
		var overflow := Label.new()
		overflow.custom_minimum_size = Vector2(18, 18)
		overflow.text = "+%d" % (statuses.size() - MAX_VISIBLE_ICONS)
		overflow.add_theme_font_size_override("font_size", 9)
		status_bar.add_child(overflow)


func _create_status_icon(status: Dictionary) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(18, 18)
	root.tooltip_text = _status_tooltip(status)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = DataTables.skill_icon_texture(str(status.get("source_skill_id", status.get("status_id", ""))))
	root.add_child(icon)
	var turns := Label.new()
	turns.position = Vector2(10, -2)
	turns.size = Vector2(10, 10)
	turns.text = str(status.get("remaining_turns", ""))
	turns.add_theme_font_size_override("font_size", 8)
	turns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(turns)
	var value := Label.new()
	value.position = Vector2(-1, 9)
	value.size = Vector2(18, 10)
	value.text = str(status.get("amount", "")) if str(status.get("kind", "")) == "shield" else ("x%d" % int(status.get("stacks", 1)) if int(status.get("stacks", 1)) > 1 else "")
	value.add_theme_font_size_override("font_size", 7)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(value)
	return root


func _status_tooltip(status: Dictionary) -> String:
	var detail := "%s · 剩余 %d 回合" % [str(status.get("status_id", "状态")), int(status.get("remaining_turns", 0))]
	if str(status.get("kind", "")) == "shield":
		detail += " · 护盾 %d" % int(status.get("amount", 0))
	elif int(status.get("stacks", 1)) > 1:
		detail += " · %d 层" % int(status.get("stacks", 1))
	return detail
