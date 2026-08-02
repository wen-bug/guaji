class_name SkillValueResolver
extends RefCounted

const SCALABLE_EFFECT_KINDS := [
	"damage_flat",
	"defense_ignore",
	"dot",
	"hot",
	"shield",
	"heal",
	"buff_stat",
	"debuff_stat",
]


static func damage_amount(skill: Dictionary, caster) -> int:
	if skill.has("damage_attribute_multiplier"):
		return scaled_amount(
			int(skill.get("base_damage", 0)),
			float(skill.get("damage_attribute_multiplier", 0.0)),
			_resolved_element(str(skill.get("element", "")), caster),
			caster
		)
	if skill.has("base_damage"):
		return maxi(0, int(skill.get("base_damage", 0)))
	if caster == null:
		return 0
	return maxi(0, int(caster.total_stat("attack") * float(skill.get("damage_multiplier", 1.0))))


static func heal_amount(skill: Dictionary, caster) -> int:
	if skill.has("heal_attribute_multiplier"):
		return scaled_amount(
			int(skill.get("heal_amount", 0)),
			float(skill.get("heal_attribute_multiplier", 0.0)),
			_resolved_element(str(skill.get("element", "")), caster),
			caster
		)
	if skill.has("heal_amount"):
		return maxi(0, int(skill.get("heal_amount", 0)))
	if caster == null:
		return 0
	return max(1, int(caster.total_stat("attack") * float(skill.get("heal_multiplier", 1.0))))


static func scaled_effect(effect: Dictionary, skill_element: String, caster) -> Dictionary:
	var resolved: Dictionary = effect.duplicate(true)
	var kind: String = str(resolved.get("kind", ""))
	if not resolved.has("attribute_multiplier") or (not kind.is_empty() and not SCALABLE_EFFECT_KINDS.has(kind)):
		return resolved
	var base_amount: int = int(resolved.get("amount", resolved.get("value", 0)))
	var element_id: String = str(resolved.get("element", skill_element))
	element_id = _resolved_element(element_id, caster)
	var amount := scaled_amount(base_amount, float(resolved.get("attribute_multiplier", 0.0)), element_id, caster)
	resolved["amount"] = amount
	resolved["value"] = amount
	resolved["base_amount"] = base_amount
	resolved["scaling_element"] = element_id
	resolved.erase("attribute_multiplier")
	return resolved


static func scaled_amount(base_amount: int, attribute_multiplier: float, element_id: String, caster) -> int:
	var attribute_value := 0
	if caster != null and not element_id.is_empty():
		attribute_value = int(caster.total_element(element_id))
	return scaled_amount_from_attribute(base_amount, attribute_multiplier, attribute_value)


static func scaled_amount_from_attribute(base_amount: int, attribute_multiplier: float, attribute_value: int) -> int:
	return maxi(0, floori(float(base_amount) + float(maxi(0, attribute_value)) * attribute_multiplier))


static func _resolved_element(element_id: String, caster) -> String:
	if not element_id.is_empty() or caster == null:
		return element_id
	return str(caster.dominant_element())
