class_name DamagePopupManager
extends Control

@export var rise_distance := 40.0
@export var fade_time := 0.7
@export var font_size := 22
@export var damage_color := Color(1.0, 0.35, 0.25, 1.0)
@export var heal_color := Color(0.35, 1.0, 0.55, 1.0)
@export var shield_color := Color(0.45, 0.75, 1.0, 1.0)
@export var dodge_color := Color(0.85, 0.85, 0.85, 1.0)
@export var block_color := Color(0.96, 0.88, 0.45, 1.0)
@export var critical_color := Color(1.0, 0.9, 0.35, 1.0)
@export var dot_color := Color(1.0, 0.6, 0.3, 1.0)

var _popups: Array[Dictionary] = []
var _stack_counts: Dictionary = {}


func push_damage(amount: int, world_position: Vector2, target_key: String = "", damage_type: String = "physical") -> void:
	push_popup("-%d" % amount, world_position, _color_for_damage_type(damage_type), target_key, damage_type)


func push_heal(amount: int, world_position: Vector2, target_key: String = "") -> void:
	push_popup("+%d" % amount, world_position, heal_color, target_key, "heal")


func push_popup(text: String, world_position: Vector2, popup_color: Color, target_key: String = "", damage_type: String = "physical") -> void:
	if text.is_empty():
		return
	var style: Dictionary = _popup_style_for_damage_type(damage_type)
	if text.begins_with("-") and str(style.get("prefix", "")).is_empty() == false and str(style.get("prefix", "")) != "":
		text = "%s %s" % [str(style.get("prefix", "")), text]
	var stack_index: int = _next_stack_index(target_key)
	var label: Label = _create_label(text, popup_color)
	label.position = world_position + _stack_offset(stack_index)
	add_child(label)
	_popups.append({
		"label": label,
		"start": label.position,
		"elapsed": 0.0,
		"target_key": target_key,
		"stack_index": stack_index,
		"damage_type": damage_type,
	})


func clear_popups() -> void:
	for popup in _popups:
		var label: Label = popup.get("label")
		if label != null:
			label.queue_free()
	_popups.clear()
	_stack_counts.clear()


func _process(delta: float) -> void:
	if _popups.is_empty():
		return
	var index := 0
	while index < _popups.size():
		var popup: Dictionary = _popups[index]
		popup["elapsed"] = float(popup.get("elapsed", 0.0)) + delta
		var label: Label = popup.get("label")
		if label == null:
			_popups.remove_at(index)
			continue
		var elapsed: float = float(popup.get("elapsed", 0.0))
		var ratio: float = clamp(elapsed / fade_time, 0.0, 1.0)
		var damage_type: String = str(popup.get("damage_type", "physical"))
		label.position = popup.get("start", Vector2.ZERO) + Vector2(0.0, -rise_distance * ratio)
		label.modulate.a = 1.0 - ratio
		label.scale = _scale_for_damage_type(damage_type, ratio)
		if ratio >= 1.0:
			label.queue_free()
			_popups.remove_at(index)
		else:
			_popups[index] = popup
			index += 1
	if _popups.is_empty():
		_stack_counts.clear()


func _next_stack_index(target_key: String) -> int:
	if target_key.is_empty():
		return _popups.size() % 5
	var count: int = int(_stack_counts.get(target_key, 0))
	_stack_counts[target_key] = count + 1
	return count


func _stack_offset(stack_index: int) -> Vector2:
	var horizontal: float = float((stack_index % 5) - 2) * 14.0
	var vertical: float = -float(stack_index % 3) * 8.0
	return Vector2(horizontal, vertical)


func _popup_style_for_damage_type(damage_type: String) -> Dictionary:
	var style := {
		"color": damage_color,
		"scale": 1.0,
		"prefix": "",
	}
	match damage_type:
		"heal":
			style["color"] = heal_color
			style["prefix"] = "+"
		"shield":
			style["color"] = shield_color
			style["prefix"] = "护盾"
		"dodge":
			style["color"] = dodge_color
			style["prefix"] = "闪避"
		"block":
			style["color"] = block_color
			style["prefix"] = "格挡"
		"critical":
			style["color"] = critical_color
			style["scale"] = 1.18
		"dot":
			style["color"] = dot_color
			style["scale"] = 0.92
		_:
			if damage_type.begins_with("element_"):
				style["color"] = _element_color(damage_type.trim_prefix("element_"))
	return style


func _color_for_damage_type(damage_type: String) -> Color:
	return _popup_style_for_damage_type(damage_type).get("color", damage_color)


func _scale_for_damage_type(damage_type: String, ratio: float) -> Vector2:
	var style: Dictionary = _popup_style_for_damage_type(damage_type)
	var base_scale: float = float(style.get("scale", 1.0))
	if damage_type == "critical":
		base_scale += 0.04 * (1.0 - ratio)
	return Vector2.ONE * base_scale


func _element_color(element_id: String) -> Color:
	match element_id:
		"fire":
			return Color(1.0, 0.45, 0.25, 1.0)
		"water":
			return Color(0.35, 0.75, 1.0, 1.0)
		"wood":
			return Color(0.45, 1.0, 0.55, 1.0)
		"metal":
			return Color(0.95, 0.86, 0.45, 1.0)
		"earth":
			return Color(0.86, 0.68, 0.4, 1.0)
		_:
			return damage_color


func _create_label(text: String, popup_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.z_index = 1000
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", popup_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label
