class_name RichTextDescriptionRenderer
extends RefCounted

const ROLE_PRIMARY := "primary"
const ROLE_SECONDARY := "secondary"
const ROLE_VALUE := "value"
const ROLE_MULTIPLIER := "multiplier"
const ROLE_RESULT := "result"
const ROLE_POSITIVE := "positive"
const ROLE_WARNING := "warning"
const ROLE_ERROR := "error"

const TEXT_COLORS := {
	ROLE_PRIMARY: Color("#F1E7D2"),
	ROLE_SECONDARY: Color("#B8B0A2"),
	ROLE_VALUE: Color("#7DD3FC"),
	ROLE_MULTIPLIER: Color("#F2C14E"),
	ROLE_RESULT: Color("#86D98B"),
	ROLE_POSITIVE: Color("#86D98B"),
	ROLE_WARNING: Color("#F2C14E"),
	ROLE_ERROR: Color("#FF6B6B"),
}

const ELEMENT_COLORS := {
	"wood": Color("#72C98A"),
	"fire": Color("#FF7868"),
	"earth": Color("#D7AA5B"),
	"metal": Color("#D7DEE8"),
	"water": Color("#66B8E8"),
}

const RARITY_COLORS := {
	"t1": Color("#C7C2BA"),
	"t2": Color("#86D98B"),
	"t3": Color("#7DD3FC"),
	"t4": Color("#C69AF4"),
	"t5": Color("#FFD36A"),
}


static func render_item(label: RichTextLabel, item: Dictionary, game_state = null, member_id: String = "") -> void:
	label.clear()
	for segment in build_item_segments(item, game_state, member_id):
		if bool(segment.get("newline", false)):
			label.newline()
			continue
		label.push_color(color_for_role(str(segment.get("role", ROLE_PRIMARY))))
		label.add_text(str(segment.get("text", "")))
		label.pop()


static func build_item_segments(item: Dictionary, game_state = null, member_id: String = "") -> Array:
	var segments: Array = []
	var description: String = DataTables.inventory_display_description(item)
	if not description.is_empty():
		_append_text(segments, description, ROLE_PRIMARY)

	if str(item.get("type", "")) == DataTables.ITEM_TYPE_EQUIPMENT:
		_append_attribute_group(segments, "基础属性", item.get("base_attributes", []), false)
		_append_attribute_group(segments, "强化分配", item.get("enhanced_attributes", []), false)
		_append_equipment_affixes(segments, item.get("affixes", []))
		var effects = item.get("description_effects", DataTables.equipment_template_description_effects(str(item.get("item_id", ""))))
		if effects is Array:
			for effect in effects:
				if effect is Dictionary:
					_append_description_effect(segments, effect, game_state, member_id)
	elif str(item.get("type", "")) == DataTables.ITEM_TYPE_PILL:
		var payload: Dictionary = item.get("payload", {})
		var enhance_data = payload.get("permanent_attribute_enhance", {})
		if enhance_data is Dictionary and enhance_data.get("effects", []) is Array:
			var display_effects: Array = []
			for raw_effect in enhance_data.get("effects", []):
				if raw_effect is Dictionary:
					var effect: Dictionary = raw_effect.duplicate(true)
					effect["amount"] = int(effect.get("amount", 1))
					display_effects.append(effect)
			_append_attribute_group(segments, "永久强化", display_effects, false)
			var tier_id := str(enhance_data.get("tier_id", ""))
			var tier_limit := DataTables.permanent_attribute_enhance_tier_limit(tier_id)
			if game_state != null and not member_id.is_empty() and tier_limit > 0:
				_append_line_start(segments)
				_append_text(segments, "%s用量：" % DataTables.permanent_attribute_enhance_tier_name(tier_id), ROLE_SECONDARY)
				_append_text(segments, "%d/%d" % [game_state.permanent_attribute_enhance_tier_uses_for(member_id, tier_id), tier_limit], ROLE_MULTIPLIER)
		elif str(payload.get("effect_mode", "instant")) == "duration":
			_append_line_start(segments)
			_append_text(segments, "持续：", ROLE_SECONDARY)
			_append_text(segments, "%d 秒" % int(payload.get("duration", 0)), ROLE_MULTIPLIER)
	return segments


static func _append_equipment_affixes(segments: Array, affixes) -> void:
	if not (affixes is Array) or affixes.is_empty():
		return
	_append_line_start(segments)
	_append_text(segments, "随机词条：", ROLE_SECONDARY)
	for index in range(mini(3, affixes.size())):
		if index > 0:
			_append_text(segments, " / ", ROLE_SECONDARY)
		if affixes[index] is Dictionary:
			_append_text(segments, DataTables.equipment_affix_text(affixes[index]), ROLE_POSITIVE)


static func plain_text(segments: Array) -> String:
	var result := ""
	for segment in segments:
		if bool(segment.get("newline", false)):
			result += "\n"
		else:
			result += str(segment.get("text", ""))
	return result


static func color_for_role(role: String) -> Color:
	if role.begins_with("element_"):
		return ELEMENT_COLORS.get(role.trim_prefix("element_"), TEXT_COLORS[ROLE_PRIMARY])
	return TEXT_COLORS.get(role, TEXT_COLORS[ROLE_PRIMARY])


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, TEXT_COLORS[ROLE_PRIMARY])


static func _append_attribute_group(segments: Array, title: String, attributes, percent: bool) -> void:
	if not (attributes is Array) or attributes.is_empty():
		return
	_append_line_start(segments)
	_append_text(segments, "%s：" % title, ROLE_SECONDARY)
	var first := true
	for raw_attribute in attributes:
		if not (raw_attribute is Dictionary):
			continue
		if not first:
			_append_text(segments, " / ", ROLE_SECONDARY)
		var stat_id: String = str(raw_attribute.get("stat", ""))
		var value_text: String
		if percent:
			value_text = "%s +%d%%" % [_stat_label(stat_id), roundi(float(raw_attribute.get("percent", 0.0)) * 100.0)]
		else:
			value_text = "%s +%d" % [_stat_label(stat_id), int(raw_attribute.get("amount", 0))]
		_append_text(segments, value_text, _role_for_stat(stat_id))
		first = false


static func _append_description_effect(segments: Array, effect: Dictionary, game_state, member_id: String) -> void:
	match str(effect.get("kind", "")):
		"element_damage_formula":
			_append_element_damage_formula(segments, effect, game_state, member_id)
		"text":
			var text: String = str(effect.get("text", ""))
			if not text.is_empty():
				_append_line_start(segments)
				_append_text(segments, text, str(effect.get("role", ROLE_PRIMARY)))


static func _append_element_damage_formula(segments: Array, effect: Dictionary, game_state, member_id: String) -> void:
	var element: String = str(effect.get("element", ""))
	var stat_id: String = str(effect.get("stat", "element_%s" % element))
	var multiplier: float = float(effect.get("multiplier", 1.0))
	var context := _context_stat(game_state, member_id, stat_id)
	var element_label: String = "%s属性" % DataTables.element_name(element)
	_append_line_start(segments)
	_append_text(segments, "造成 ", ROLE_PRIMARY)
	_append_text(segments, "%s伤害" % element_label, "element_%s" % element)
	_append_text(segments, "（", ROLE_PRIMARY)
	if bool(context.get("available", false)):
		var stat_value: int = int(context.get("value", 0))
		_append_text(segments, "%s %d" % [_stat_label(stat_id), stat_value], ROLE_VALUE)
		_append_text(segments, " × ", ROLE_PRIMARY)
		_append_text(segments, _format_decimal(multiplier), ROLE_MULTIPLIER)
		_append_text(segments, " = ", ROLE_PRIMARY)
		_append_text(segments, str(_round_formula(float(stat_value) * multiplier, str(effect.get("rounding", "floor")))), ROLE_RESULT)
	else:
		_append_text(segments, _stat_label(stat_id), ROLE_VALUE)
		_append_text(segments, " × ", ROLE_PRIMARY)
		_append_text(segments, _format_decimal(multiplier), ROLE_MULTIPLIER)
	_append_text(segments, "）", ROLE_PRIMARY)


static func _context_stat(game_state, member_id: String, stat_id: String) -> Dictionary:
	if game_state == null or member_id.is_empty() or game_state.member_by_id(member_id).is_empty():
		return {"available": false, "value": 0}
	if stat_id.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
		return {"available": true, "value": game_state.total_element_for(member_id, DataTables.element_id_from_attribute(stat_id))}
	return {"available": true, "value": game_state.total_stat_for(member_id, stat_id)}


static func _round_formula(value: float, mode: String) -> int:
	match mode:
		"ceil":
			return ceili(value)
		"round":
			return roundi(value)
		_:
			return floori(value)


static func _format_decimal(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0"):
		text = text.left(-1)
	if text.ends_with("."):
		text = text.left(-1)
	return text


static func _stat_label(stat_id: String) -> String:
	if stat_id.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
		return "%s属性" % DataTables.element_name(DataTables.element_id_from_attribute(stat_id))
	return DataTables.attribute_display_name(stat_id)


static func _role_for_stat(stat_id: String) -> String:
	if stat_id.begins_with(DataTables.ELEMENT_ATTRIBUTE_PREFIX):
		return "element_%s" % DataTables.element_id_from_attribute(stat_id)
	return ROLE_VALUE


static func _append_line_start(segments: Array) -> void:
	if not segments.is_empty():
		segments.append({"newline": true})


static func _append_text(segments: Array, text: String, role: String) -> void:
	if not text.is_empty():
		segments.append({"text": text, "role": role})
