@tool
## 道具静态资源。Inspector 中直接显示中文分类，悬停字段可查看中文用途说明。
class_name ItemDef
extends Resource

@export_category("道具资源配置（悬停字段查看说明）")
@export_group("基础信息｜ID、编号、类型、名称")
## 物品的稳定内容 ID；存档、配方和掉落表通过它引用物品。
@export var id := ""
## 物品编号；已发布编号只能追加，不能复用或修改。
@export var item_no := 0
## 物品分类 ID，例如 material、skill_book 或 pill。
@export_enum("skill_book", "equipment", "material", "crop", "pill", "alchemy_recipe", "blueprint") var type := "material"
## HUD 和物品详情中显示的中文名称。
@export var display_name := ""

@export_group("图标与说明｜贴图、路径、描述")
## Inspector 中直接拖入的图标，运行时优先于 icon_path。
@export var icon_texture: Texture2D
## 默认图标文件名，不包含扩展名。
@export var icon_name := ""
## 图标资源路径；icon_texture 为空时使用。
@export var icon_path := ""
## 物品详情中显示的说明文本。
@export_multiline var description := ""

@export_group("使用规则｜堆叠、使用范围、冷却")
## 是否允许同 ID 物品合并为一个堆叠。
@export var stackable := true
## 是否允许玩家主动使用该物品。
@export var usable := false
## 可使用场景范围；none 表示没有主动使用入口。
@export_enum("none", "home", "combat", "both") var use_context := "none"
## 物品获得时关联的五行或成长目标；无目标时填写 none。
@export_enum("none", "attack", "defense", "max_hp", "max_mp", "root_bone", "wood", "fire", "earth", "metal", "water") var gain_target := "none"
## 战斗自动使用后的个人冷却回合数。
@export_range(0, 99, 1) var combat_cooldown_turns := 0
## 多个道具共享冷却时使用的稳定分组 ID。
@export var shared_cooldown_group := ""
## AI 识别的行为分类；空值表示不可放入自动道具栏。
@export var ai_action_type := ""
## 按顺序结算的类型化 ItemEffectDef 子资源。
@export var effects: Array[Resource] = []
## 仅供旧 Mod API 2 输入使用；核心资源必须保持为空。
@export_storage var payload: Dictionary = {}


var use_scope: String:
	get:
		return use_context
	set(value):
		use_context = value


func setup(def_id: String, data: Dictionary) -> ItemDef:
	id = def_id
	item_no = int(data.get("item_no", 0))
	type = data.get("type", "material")
	display_name = data.get("name", data.get("display_name", def_id))
	icon_name = data.get("icon_name", def_id)
	icon_path = data.get("icon_path", "res://assets/items/%s.png" % icon_name)
	description = data.get("description", "")
	stackable = bool(data.get("stackable", true))
	usable = bool(data.get("usable", false))
	use_context = data.get("use_context", data.get("use_scope", "none"))
	gain_target = data.get("gain_target", "none")
	payload = data.get("payload", {}).duplicate(true)
	combat_cooldown_turns = int(data.get("combat_cooldown_turns", payload.get("cooldown", 0)))
	shared_cooldown_group = str(data.get("shared_cooldown_group", payload.get("cooldown_group", "")))
	ai_action_type = str(data.get("ai_action_type", ""))
	return self


func to_item_data() -> Dictionary:
	return {
		"item_no": item_no,
		"type": type,
		"name": display_name,
		"icon_name": icon_name,
		"icon_path": icon_path,
		"description": description,
		"stackable": stackable,
		"usable": usable,
		"use_scope": use_context,
		"use_context": use_context,
		"gain_target": gain_target,
		"combat_cooldown_turns": combat_cooldown_turns,
		"shared_cooldown_group": shared_cooldown_group,
		"ai_action_type": ai_action_type,
		"effects": _effect_dictionaries(),
		"payload": legacy_payload(),
	}


func _effect_dictionaries() -> Array:
	var result: Array = []
	for raw_effect in effects:
		if raw_effect != null and raw_effect.has_method("to_dictionary"):
			result.append(raw_effect.call("to_dictionary"))
	return result


func legacy_payload() -> Dictionary:
	if not payload.is_empty():
		return payload.duplicate(true)
	var result := {}
	for raw_effect in _effect_dictionaries():
		var effect: Dictionary = raw_effect
		match str(effect.get("kind", "")):
			"restore_resource":
				var resource_id := str(effect.get("stat", ""))
				if float(effect.get("ratio", 0.0)) > 0.0:
					result["%s_ratio" % resource_id] = float(effect.get("ratio", 0.0))
				elif int(effect.get("amount", 0)) > 0:
					result[resource_id] = int(effect.get("amount", 0))
			"temporary_modifier":
				result.merge({"effect_mode": "duration", "stat": effect.get("stat", ""), "amount": effect.get("value", 0.0), "duration": effect.get("duration_seconds", 0.0)}, true)
			"permanent_attribute":
				var permanent: Dictionary = result.get("permanent_attribute_enhance", {"tier_id": effect.get("tier_id", ""), "effects": []})
				var permanent_effect := {"stat": effect.get("stat", "")}
				if int(effect.get("amount", 0)) > 0:
					permanent_effect["amount"] = int(effect.get("amount", 0))
				permanent["effects"].append(permanent_effect)
				result["permanent_attribute_enhance"] = permanent
			"unlock_content":
				match str(effect.get("reference_kind", "")):
					"skill": result["skill_id"] = effect.get("reference_id", "")
					"alchemy_recipe": result["recipe_id"] = effect.get("reference_id", "")
					"equipment_template": result["equipment_template_id"] = effect.get("reference_id", "")
			"breakthrough": result["breakthrough"] = true
			"building_quality": result["permanent_building_quality"] = {"building_id": effect.get("reference_id", ""), "amount": effect.get("amount", 0)}
			"farm_seed": result.merge({"seed_yield": effect.get("amount", 0), "growth_seconds": effect.get("auxiliary_value", 0.0)}, true)
			"equipment_enhancement_material": result.merge({"stat": effect.get("stat", ""), "enhance_amount": effect.get("amount", 0), "stone_group": effect.get("group_id", "")}, true)
			"currency": result["%s_currency" % str(effect.get("group_id", ""))] = true
	if combat_cooldown_turns > 0:
		result["cooldown"] = combat_cooldown_turns
	if not shared_cooldown_group.is_empty():
		result["cooldown_group"] = shared_cooldown_group
	return result
