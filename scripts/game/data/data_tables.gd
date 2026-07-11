class_name DataTables
extends Node

const ITEM_USE_SCOPE_HOME := "home"
const ITEM_USE_SCOPE_COMBAT := "combat"
const ITEM_USE_SCOPE_NONE := "none"

const ITEM_TYPE_SKILL_BOOK := "skill_book"
const ITEM_TYPE_EQUIPMENT := "equipment"
const ITEM_TYPE_MATERIAL := "material"
const ITEM_TYPE_CROP := "crop"
const ITEM_TYPE_PILL := "pill"
const ITEM_TYPE_ALCHEMY_RECIPE := "alchemy_recipe"

const ITEM_ICON_ROOT := "res://assets/items"
const EQUIPMENT_ICON_ROOT := "res://assets/equipment"
const ITEM_RESOURCE_ROOT := "res://resources/items"
const EQUIPMENT_RESOURCE_ROOT := "res://resources/equipment"
const SKILL_RESOURCE_ROOT := "res://resources/skills"

const ITEM_ID_HERB := "herb"
const ITEM_ID_BLADE_GRASS := "blade_grass"
const ITEM_ID_IRONROOT := "ironroot"
const ITEM_ID_BLOOD_GINSENG := "blood_ginseng"
const ITEM_ID_SPIRIT_LOTUS := "spirit_lotus"
const ITEM_ID_BONE_BAMBOO := "bone_bamboo"
const ITEM_ID_WOODVINE := "woodvine"
const ITEM_ID_FLAME_FLOWER := "flame_flower"
const ITEM_ID_EARTH_MOSS := "earth_moss"
const ITEM_ID_METAL_REED := "metal_reed"
const ITEM_ID_WATER_ORCHID := "water_orchid"
const ITEM_ID_ORE := "ore"
const ITEM_ID_SPIRIT_STONE := "spirit_stone"
const ITEM_ID_FARM_SPEED_TALISMAN := "farm_speed_talisman"
const ITEM_ID_SPIRIT_STONE_FIRE := "spirit_stone_fire"
const ITEM_ID_SPIRIT_STONE_EARTH := "spirit_stone_earth"
const ITEM_ID_SPIRIT_STONE_WOOD := "spirit_stone_wood"
const ITEM_ID_SPIRIT_STONE_METAL := "spirit_stone_metal"
const ITEM_ID_SPIRIT_STONE_WATER := "spirit_stone_water"
const ITEM_ID_REFINE_TALISMAN := "refine_talisman"
const ITEM_ID_RECIPE_PILL := "recipe_pill"
const ITEM_ID_PILL := "pill"
const ITEM_ID_BREAKTHROUGH_PILL := "breakthrough_pill"

const ATTACK_MODE_MELEE := "melee"
const ATTACK_MODE_RANGED := "ranged"
const ATTACK_MODES := [ATTACK_MODE_MELEE, ATTACK_MODE_RANGED]
const RANGED_BASIC_ATTACK_ID := "fireball"

const ITEM_GAIN_TARGET_ORDER := ["attack", "defense", "max_hp", "max_mp", "root_bone", "wood", "fire", "earth", "metal", "water"]
const ITEM_GAIN_TARGET_LABELS := {
	"attack": "攻击",
	"defense": "防御",
	"max_hp": "气血",
	"max_mp": "法力",
	"root_bone": "根骨",
	"wood": "木",
	"fire": "火",
	"earth": "土",
	"metal": "金",
	"water": "水",
}

const ELEMENT_IDS := ["wood", "fire", "earth", "metal", "water"]
const ELEMENT_NAMES := {
	"wood": "木",
	"fire": "火",
	"earth": "土",
	"metal": "金",
	"water": "水",
}
const ELEMENT_ATTRIBUTE_PREFIX := "element_"

const OBTAIN_SOURCE_NAMES := {
	"drop": "掉落",
	"non_drop": "非掉落",
	"debug": "调试",
}

const TASK_ZONE_NAMES := {
	GameDefs.TaskType.RECRUIT: "招募",
	GameDefs.TaskType.FARM: "种田",
	GameDefs.TaskType.FORGE: "炼器",
	GameDefs.TaskType.ALCHEMY: "炼丹",
	GameDefs.TaskType.FIGHT: "战斗",
}
const TASK_ZONE_IDS := {
	GameDefs.TaskType.RECRUIT: "recruit",
	GameDefs.TaskType.FARM: "farm",
	GameDefs.TaskType.FORGE: "forge",
	GameDefs.TaskType.ALCHEMY: "alchemy",
	GameDefs.TaskType.FIGHT: "fight",
}

const BUILDING_DEFS := {
	"recruit": {"name": "招募", "max_level": 10, "cost_item": "spirit_stone", "cost_offset": 0},
	"forge": {"name": "炼器", "max_level": 10, "cost_item": "ore", "cost_offset": 1},
	"alchemy": {"name": "炼丹", "max_level": 10, "cost_item": "herb", "cost_offset": 1},
	"farm": {"name": "农田", "max_level": 10, "cost_item": "herb", "cost_offset": 0},
}

const BASIC_RECRUIT_TRAIT_IDS := [
	"robust_body",
	"sharp_edge",
	"steady_guard",
	"full_vigor",
	"good_root",
	"field_sense",
	"craft_touch",
	"pill_sense",
]

const SLOT_NAMES := {
	"weapon": "武器",
	"helmet": "头盔",
	"armor": "护甲",
	"leggings": "胫甲",
	"gloves": "护手",
	"accessory": "饰品",
}

const EQUIPMENT_RARITY_ORDER := ["t1", "t2", "t3", "t4", "t5"]
const EQUIPMENT_RARITY_NAMES := {
	"t1": "一阶",
	"t2": "二阶",
	"t3": "三阶",
	"t4": "四阶",
	"t5": "五阶",
}
const EQUIPMENT_RARITY_WEIGHTS := {
	"t1": 55,
	"t2": 28,
	"t3": 12,
	"t4": 4,
	"t5": 1,
}

const ITEM_DEFS := {
	"herb": {"item_no": 1001, "name": "草药", "description": "通用炼丹材料，也可作为种子。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 3, "growth_seconds": 600.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"ore": {"item_no": 1004, "name": "矿石", "description": "通用炼器材料。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"spirit_stone": {"item_no": 1005, "name": "灵石", "description": "招募修士与强化普通属性所需的通用灵石。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"recruit_currency": true, "enhance_amount": 1, "stone_group": "stat"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"farm_speed_talisman": {"item_no": 1006, "name": "丰收符", "description": "提升农田生长速度一段时间。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": true, "payload": {"farm_speed": true}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
	"spirit_stone_fire": {"item_no": 1009, "name": "火灵石", "description": "可用于强化火行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_fire", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "fire"},
	"spirit_stone_earth": {"item_no": 1010, "name": "土灵石", "description": "可用于强化土行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_earth", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "earth"},
	"spirit_stone_wood": {"item_no": 1011, "name": "木灵石", "description": "可用于强化木行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_wood", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "wood"},
	"spirit_stone_metal": {"item_no": 1012, "name": "金灵石", "description": "可用于强化金行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_metal", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "metal"},
	"spirit_stone_water": {"item_no": 1013, "name": "水灵石", "description": "可用于强化水行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_water", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "water"},
	"refine_talisman": {"item_no": 1014, "name": "洗练符", "description": "用于装备洗练。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"recipe_pill": {"item_no": 1015, "name": "调息丹方", "description": "学习后可炼制调息丹。", "type": ITEM_TYPE_ALCHEMY_RECIPE, "stackable": true, "usable": true, "payload": {"recipe_id": "pill"}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
	"pill": {"item_no": 1016, "name": "调息丹", "description": "恢复生命和法力。", "type": ITEM_TYPE_PILL, "stackable": true, "usable": true, "payload": {"hp": 18, "mp": 12}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
	"breakthrough_pill": {"item_no": 1017, "name": "破境丹", "description": "达到等级上限时可突破。", "type": ITEM_TYPE_PILL, "stackable": true, "usable": true, "payload": {"breakthrough": true}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
	"blade_grass": {"item_no": 1019, "name": "刃纹草", "description": "蕴含锋锐气息的攻击属性作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 900.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "attack"},
	"ironroot": {"item_no": 1020, "name": "铁根藤", "description": "根须坚韧的防御属性作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 900.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "defense"},
	"blood_ginseng": {"item_no": 1021, "name": "血参", "description": "补益气血的生命属性作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 1200.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "max_hp"},
	"spirit_lotus": {"item_no": 1022, "name": "灵泉莲", "description": "滋养法力的灵力属性作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 1200.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "max_mp"},
	"bone_bamboo": {"item_no": 1023, "name": "玉骨竹", "description": "淬炼根骨的根骨属性作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 1800.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "root_bone"},
	"woodvine": {"item_no": 1024, "name": "青木藤", "description": "蕴含木行生机的五行作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 900.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "wood"},
	"flame_flower": {"item_no": 1025, "name": "赤焰花", "description": "蕴含火行炎力的五行作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 1050.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "fire"},
	"earth_moss": {"item_no": 1026, "name": "厚土苔", "description": "蕴含土行厚重的五行作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 1050.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "earth"},
	"metal_reed": {"item_no": 1027, "name": "玄金苇", "description": "蕴含金行肃杀的五行作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 1500.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "metal"},
	"water_orchid": {"item_no": 1028, "name": "玄水兰", "description": "蕴含水行润泽的五行作物。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 1200.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "water"},
}

const SKILL_DEFS := {
	"heal": {"id": "heal", "name": "回春术", "type": "heal", "element": "wood", "mp_cost": 6, "cooldown": 5, "damage_multiplier": 0.0, "heal_multiplier": 1.0, "release_distance": 96.0, "priority": 90, "trigger": ["hp_below_35"], "combat_buffs": [], "effects": [], "scene_path": "res://scripts/game/skills/heal/heal_skill.tscn"},
	"thunder": {"id": "thunder", "name": "雷击术", "type": "damage", "element": "metal", "mp_cost": 12, "cooldown": 5, "damage_multiplier": 1.75, "release_distance": 140.0, "priority": 60, "trigger": ["always"], "combat_buffs": [], "effects": [], "scene_path": "res://scripts/game/skills/damage/direct_damage_skill.tscn"},
}

const BASIC_ATTACK_DEFS := {
	ATTACK_MODE_MELEE: {"id": "basic_attack", "name": "普通攻击", "attack_mode": ATTACK_MODE_MELEE, "element": "", "mp_cost": 0, "cooldown": 0.0, "release_distance": 0.0, "scene_path": "res://scripts/game/skills/damage/basic_attack.tscn"},
	ATTACK_MODE_RANGED: {"id": RANGED_BASIC_ATTACK_ID, "name": "火球术", "attack_mode": ATTACK_MODE_RANGED, "element": "fire", "mp_cost": 0, "cooldown": 0.0, "release_distance": 120.0, "scene_path": "res://scripts/game/skills/damage/basic_attack.tscn"},
}

const ALCHEMY_RECIPE_DEFS := {
	"pill": {"result_item_id": "pill", "materials": [{"item_id": "herb", "amount": 2}]},
}

const EQUIPMENT_DEFS := {
	"weapon": {"slot": "weapon", "name": "武器", "base_attributes": [{"stat": "attack", "amount": 8}], "level_scale": 2.2},
	"helmet": {"slot": "helmet", "name": "头盔", "base_attributes": [{"stat": "defense", "amount": 5}, {"stat": "max_hp", "amount": 12}], "level_scale": 1.6},
	"armor": {"slot": "armor", "name": "护甲", "base_attributes": [{"stat": "defense", "amount": 7}, {"stat": "max_hp", "amount": 18}], "level_scale": 2.0},
	"leggings": {"slot": "leggings", "name": "胫甲", "base_attributes": [{"stat": "defense", "amount": 4}, {"stat": "max_hp", "amount": 10}], "level_scale": 1.5},
	"gloves": {"slot": "gloves", "name": "护手", "base_attributes": [{"stat": "attack", "amount": 4}, {"stat": "defense", "amount": 2}], "level_scale": 1.4},
	"accessory": {"slot": "accessory", "name": "饰品", "base_attributes": [{"stat": "root_bone", "amount": 2}], "level_scale": 1.0},
}

const EQUIPMENT_ATTRIBUTE_DEFS := [
	{"stat": "attack"},
	{"stat": "defense"},
	{"stat": "max_hp"},
	{"stat": "max_mp"},
	{"stat": "root_bone"},
	{"stat": "element_wood"},
	{"stat": "element_fire"},
	{"stat": "element_earth"},
	{"stat": "element_metal"},
	{"stat": "element_water"},
]

const INNATE_TRAIT_DEFS := {
	"robust_body": {
		"name": "健体",
		"description": "体魄稳健，气血更充足。",
		"effects": [
			{"kind": "stat_flat", "stat": "max_hp", "amount": 20},
		],
	},
	"sharp_edge": {
		"name": "锋芒",
		"description": "出手锐利，攻击小幅提高。",
		"effects": [
			{"kind": "stat_flat", "stat": "attack", "amount": 2},
		],
	},
	"steady_guard": {
		"name": "稳守",
		"description": "守势沉稳，防御小幅提高。",
		"effects": [
			{"kind": "stat_flat", "stat": "defense", "amount": 2},
		],
	},
	"full_vigor": {
		"name": "充沛",
		"description": "灵力充沛，法力上限提高。",
		"effects": [
			{"kind": "stat_flat", "stat": "max_mp", "amount": 12},
		],
	},
	"good_root": {
		"name": "良根",
		"description": "根骨良好，生产和成长潜力更高。",
		"effects": [
			{"kind": "stat_flat", "stat": "root_bone", "amount": 2},
		],
	},
	"craft_hand": {
		"name": "巧匠",
		"description": "炼器时更容易引出材料灵性。",
		"effects": [
			{"kind": "craft_bonus_flat", "task": "forge", "amount": 1},
			{"kind": "forge_rarity_upgrade_chance", "task": "forge", "value": 0.05},
		],
	},
	"craft_touch": {
		"name": "巧手",
		"description": "手上有准头，炼器属性入口略有提高。",
		"effects": [
			{"kind": "craft_bonus_flat", "task": "forge", "amount": 1},
		],
	},
	"pill_heart": {
		"name": "丹心",
		"description": "炼丹时更容易额外成丹。",
		"effects": [
			{"kind": "alchemy_extra_chance", "task": "alchemy", "value": 0.05},
		],
	},
	"pill_sense": {
		"name": "丹感",
		"description": "对火候有感，炼丹额外出丹概率提高。",
		"effects": [
			{"kind": "alchemy_extra_chance", "task": "alchemy", "value": 0.04},
		],
	},
	"field_sense": {
		"name": "识田",
		"description": "种田时略微提高收成。",
		"effects": [
			{"kind": "farm_harvest_bonus_flat", "task": "farm", "amount": 1},
		],
	},
}

const ENEMY_TEMPLATES := {
	"training_dummy": {"id": "training_dummy", "visual_id": "training_dummy", "name": "木桩", "level_offset": 0, "max_hp": 40, "attack": 3, "defense": 0, "move_speed": 48.0, "player_move_speed": 96.0, "attack_range": 72.0, "player_attack_range": 96.0, "spawn_delay": 0.4, "turn_wait": 1.8, "element": "wood", "weak_element": "fire", "element_attack_ratio": 0.0, "drops": {}, "equipment_drop_chance": 0.0, "exp": 6, "use_drop": false, "is_training_dummy": true},
	"forest_wolf": {"id": "forest_wolf", "visual_id": "forest_wolf", "name": "林狼", "level_offset": 0, "max_hp": 32, "attack": 6, "defense": 1, "move_speed": 120.0, "player_move_speed": 120.0, "attack_range": 88.0, "player_attack_range": 96.0, "spawn_delay": 0.6, "turn_wait": 1.4, "element": "wood", "weak_element": "fire", "element_attack_ratio": 0.2, "drops": {"herb": {"chance": 0.55, "min": 1, "max": 2}, "ore": {"chance": 0.30, "min": 1, "max": 1}, "spirit_stone": {"chance": 0.10, "min": 1, "max": 1}}, "equipment_drop_chance": 0.05, "exp": 10, "use_drop": true, "is_training_dummy": false},
}

const ENEMY_SCENE_PATHS := {
	"training_dummy": "res://scripts/game/enemies/training_dummy/enemy.tscn",
	"forest_wolf": "res://scripts/game/enemies/forest_wolf/enemy.tscn",
}

const DEFAULT_ENEMY_ID := "training_dummy"


static func item_definition(item_id: String) -> Dictionary:
	return ITEM_DEFS.get(item_id, {}).duplicate(true)


static func item_no(item_id: String) -> int:
	return int(ITEM_DEFS.get(item_id, {}).get("item_no", 0))


static func item_id_from_no(no: int) -> String:
	for item_id in ITEM_DEFS.keys():
		if int(ITEM_DEFS[item_id].get("item_no", 0)) == no:
			return str(item_id)
	return ""


static func item_icon_name(item_id: String) -> String:
	var definition: Dictionary = ITEM_DEFS.get(item_id, {})
	return str(definition.get("icon_name", item_id))


static func item_icon_path(item_id: String) -> String:
	var definition: Dictionary = ITEM_DEFS.get(item_id, {})
	if definition.has("icon_path"):
		return str(definition.get("icon_path", ""))
	var icon_name: String = item_icon_name(item_id)
	if icon_name.is_empty():
		return ""
	return "%s/%s.png" % [ITEM_ICON_ROOT, icon_name]


static func equipment_icon_name(template_id: String) -> String:
	var definition: Dictionary = EQUIPMENT_DEFS.get(template_id, {})
	return str(definition.get("icon_name", template_id))


static func equipment_icon_path(template_id: String) -> String:
	var definition: Dictionary = EQUIPMENT_DEFS.get(template_id, {})
	if definition.has("icon_path"):
		return str(definition.get("icon_path", ""))
	var icon_name: String = equipment_icon_name(template_id)
	if icon_name.is_empty():
		return ""
	return "%s/%s.png" % [EQUIPMENT_ICON_ROOT, icon_name]


static func item_resource_path(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	return "%s/%s.tres" % [ITEM_RESOURCE_ROOT, item_id]


static func equipment_resource_path(template_id: String) -> String:
	if template_id.is_empty():
		return ""
	return "%s/%s.tres" % [EQUIPMENT_RESOURCE_ROOT, template_id]


static func skill_resource_path(skill_id: String) -> String:
	if skill_id.is_empty():
		return ""
	return "%s/%s.tres" % [SKILL_RESOURCE_ROOT, skill_id]


static func item_resource(item_id: String) -> Resource:
	return _load_resource(item_resource_path(item_id))


static func equipment_resource(template_id: String) -> Resource:
	return _load_resource(equipment_resource_path(template_id))


static func item_icon_texture(item_id: String) -> Texture2D:
	return _icon_texture_from_resource(item_resource_path(item_id))


static func equipment_icon_texture(template_id: String) -> Texture2D:
	return _icon_texture_from_resource(equipment_resource_path(template_id))


static func skill_icon_texture(skill_id: String) -> Texture2D:
	return _icon_texture_from_resource(skill_resource_path(skill_id))


static func item_display_name(item_id: String) -> String:
	var resource: Resource = item_resource(item_id)
	var display_name: String = _resource_string(resource, "display_name", "")
	if not display_name.is_empty():
		return display_name
	return str(ITEM_DEFS.get(item_id, {}).get("name", item_id))


static func item_display_description(item_id: String) -> String:
	var resource: Resource = item_resource(item_id)
	var description: String = _resource_string(resource, "description", "")
	if not description.is_empty():
		return description
	return str(ITEM_DEFS.get(item_id, {}).get("description", ""))


static func equipment_template_description(template_id: String) -> String:
	var resource: Resource = equipment_resource(template_id)
	var description: String = _resource_string(resource, "description", "")
	if not description.is_empty():
		return description
	return str(EQUIPMENT_DEFS.get(template_id, {}).get("description", ""))


static func inventory_display_name(item: Dictionary) -> String:
	var item_id: String = str(item.get("item_id", ""))
	if str(item.get("type", "")) == ITEM_TYPE_EQUIPMENT:
		return str(item.get("name", item_id))
	return item_display_name(item_id)


static func inventory_display_description(item: Dictionary) -> String:
	var item_id: String = str(item.get("item_id", ""))
	if str(item.get("type", "")) == ITEM_TYPE_EQUIPMENT:
		var instance_description: String = str(item.get("description", ""))
		var template_description: String = equipment_template_description(item_id)
		if instance_description.is_empty():
			return template_description
		if template_description.is_empty() or template_description == instance_description:
			return instance_description
		return "%s  %s" % [instance_description, template_description]
	return item_display_description(item_id)


static func inventory_icon_texture(item: Dictionary) -> Texture2D:
	var item_id: String = str(item.get("item_id", ""))
	var item_type: String = str(item.get("type", ""))
	var default_resource_path: String = equipment_resource_path(item_id) if item_type == ITEM_TYPE_EQUIPMENT else item_resource_path(item_id)
	var resource_path: String = str(item.get("resource_path", default_resource_path))
	var resource: Resource = _load_resource(resource_path)
	var texture: Texture2D = _texture_from_resource(resource)
	if texture != null:
		return texture
	var default_icon_path: String = equipment_icon_path(item_id) if item_type == ITEM_TYPE_EQUIPMENT else item_icon_path(item_id)
	var icon_path: String = _resource_string(resource, "icon_path", "")
	if icon_path.is_empty():
		icon_path = str(item.get("icon_path", default_icon_path))
	return _texture_from_path(icon_path)


static func _icon_texture_from_resource(path: String) -> Texture2D:
	return _texture_from_resource(_load_resource(path))


static func _load_resource(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)


static func _texture_from_resource(resource: Resource) -> Texture2D:
	if resource == null:
		return null
	var texture = resource.get("icon_texture")
	if texture is Texture2D:
		return texture
	return null


static func _texture_from_path(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if resource is Texture2D:
		return resource
	return null


static func _resource_string(resource: Resource, property_name: String, fallback: String = "") -> String:
	if resource == null:
		return fallback
	var value = resource.get(property_name)
	if value == null:
		return fallback
	var text: String = str(value)
	return fallback if text.is_empty() else text


static func create_stack_item(item_id: String, amount: int) -> Dictionary:
	var definition := item_definition(item_id)
	if definition.is_empty():
		return {}
	return {
		"instance_id": item_id,
		"item_id": item_id,
		"name": definition.get("name", item_id),
		"description": definition.get("description", ""),
		"type": definition.get("type", ""),
		"count": amount,
		"stackable": bool(definition.get("stackable", true)),
		"usable": bool(definition.get("usable", false)),
		"payload": definition.get("payload", {}).duplicate(true),
		"obtain_source": "non_drop",
		"gain_target": definition.get("gain_target", "none"),
		"item_no": item_no(item_id),
		"icon_name": item_icon_name(item_id),
		"icon_path": item_icon_path(item_id),
		"resource_path": item_resource_path(item_id),
	}


static func create_skill(skill_id: String, obtain_source: String = "non_drop") -> Dictionary:
	var definition: Dictionary = SKILL_DEFS.get(skill_id, {})
	if definition.is_empty():
		return {}
	var skill: Dictionary = definition.duplicate(true)
	skill["obtain_source"] = obtain_source
	return skill


static func create_basic_attack(attack_mode: String, base_damage: int = 0) -> Dictionary:
	var resolved_mode: String = attack_mode if ATTACK_MODES.has(attack_mode) else ATTACK_MODE_MELEE
	var attack: Dictionary = BASIC_ATTACK_DEFS[resolved_mode].duplicate(true)
	attack["type"] = "normal_attack"
	attack["base_damage"] = maxi(0, base_damage)
	attack["damage_marker"] = "impact"
	return attack


static func create_enemy(level: int, rng: RandomNumberGenerator, enemy_id: String = DEFAULT_ENEMY_ID) -> Dictionary:
	var resolved_enemy_id: String = resolve_enemy_id(enemy_id)
	var template: Dictionary = ENEMY_TEMPLATES.get(resolved_enemy_id, ENEMY_TEMPLATES[DEFAULT_ENEMY_ID]).duplicate(true)
	var enemy_level: int = maxi(1, level + int(template.get("level_offset", 0)))
	var max_hp: int = int(template.get("max_hp", 1)) + enemy_level * 4
	var attack: int = int(template.get("attack", 1)) + enemy_level * 1
	var defense: int = int(template.get("defense", 0)) + enemy_level / 3
	return {
		"id": str(template.get("id", resolved_enemy_id)),
		"visual_id": str(template.get("visual_id", "enemy_default")),
		"name": str(template.get("name", "敌人")),
		"level": enemy_level,
		"hp": max_hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"move_speed": float(template.get("move_speed", 120.0)),
		"player_move_speed": float(template.get("player_move_speed", 120.0)),
		"attack_range": float(template.get("attack_range", 88.0)),
		"player_attack_range": float(template.get("player_attack_range", 96.0)),
		"spawn_delay": float(template.get("spawn_delay", 0.6)),
		"turn_wait": float(template.get("turn_wait", 1.4)),
		"element": str(template.get("element", "")),
		"weak_element": str(template.get("weak_element", "fire")),
		"element_attack_ratio": float(template.get("element_attack_ratio", 0.0)),
		"drops": template.get("drops", {}).duplicate(true),
		"effects": template.get("effects", []).duplicate(true),
		"combat_effects": [],
		"turn_start_processed": false,
		"exp": int(template.get("exp", 5)) + enemy_level * 2,
		"use_drop": bool(template.get("use_drop", true)),
		"is_training_dummy": bool(template.get("is_training_dummy", false)),
	}


static func resolve_enemy_id(enemy_id: String) -> String:
	if enemy_id.is_empty() or not ENEMY_TEMPLATES.has(enemy_id):
		return DEFAULT_ENEMY_ID
	return enemy_id


static func enemy_scene_path(enemy_id: String) -> String:
	var resolved_enemy_id: String = resolve_enemy_id(enemy_id)
	return str(ENEMY_SCENE_PATHS.get(resolved_enemy_id, ENEMY_SCENE_PATHS[DEFAULT_ENEMY_ID]))


static func create_equipment(level: int, rng: RandomNumberGenerator, craft_bonus: int = 0, obtain_source: String = "non_drop") -> Dictionary:
	var template_id: String = str(EQUIPMENT_DEFS.keys()[rng.randi_range(0, EQUIPMENT_DEFS.size() - 1)])
	return create_equipment_from_template(template_id, level, rng, craft_bonus, "", random_equipment_rarity(rng), obtain_source)


static func create_equipment_from_template(template_id: String, level: int, rng: RandomNumberGenerator, craft_bonus: int = 0, _name_prefix: String = "", rarity: String = "t1", obtain_source: String = "non_drop") -> Dictionary:
	var template: Dictionary = EQUIPMENT_DEFS.get(template_id, {})
	if template.is_empty():
		return {}
	var rarity_index := maxi(0, EQUIPMENT_RARITY_ORDER.find(rarity))
	if rarity_index < 0:
		rarity_index = 0
	var rarity_name: String = str(EQUIPMENT_RARITY_NAMES.get(rarity, "一阶"))
	var slot := str(template.get("slot", template_id))
	var equipment_name: String = str(template.get("name", slot_name(slot)))
	var equipment_level := maxi(1, level)
	var base_attributes: Array = []
	for attribute in template.get("base_attributes", []):
		base_attributes.append({
			"stat": attribute.get("stat", ""),
			"amount": max(1, int((int(attribute.get("amount", 1)) + equipment_level * float(template.get("level_scale", 1.0)) + craft_bonus) * (1.0 + rarity_index * 0.08))),
		})
	var affixes: Array = []
	for _index in range(rarity_index + 1):
		var affix_def: Dictionary = EQUIPMENT_ATTRIBUTE_DEFS[rng.randi_range(0, EQUIPMENT_ATTRIBUTE_DEFS.size() - 1)]
		affixes.append({
			"stat": affix_def.get("stat", ""),
			"amount": max(1, int(rng.randi_range(1, 4) + equipment_level * 0.3 + craft_bonus)),
		})
	return {
		"instance_id": "%s_%d_%d" % [template_id, Time.get_ticks_usec(), rng.randi()],
		"item_id": template_id,
		"name": "%s·%s" % [rarity_name, equipment_name],
		"description": "%s等级装备" % rarity_name,
		"type": ITEM_TYPE_EQUIPMENT,
		"count": 1,
		"stackable": false,
		"usable": true,
		"payload": {},
		"obtain_source": obtain_source,
		"icon_name": equipment_icon_name(template_id),
		"icon_path": equipment_icon_path(template_id),
		"resource_path": equipment_resource_path(template_id),
		"slot": slot,
		"rarity": rarity,
		"equipment_level": equipment_level,
		"base_attributes": base_attributes,
		"enhanced_attributes": [],
		"refine_affixes": [],
		"enhance_count": 0,
		"refine_count": 0,
		"equipped": false,
		"equipped_by": "",
		"attack_bonus": 0,
		"defense_bonus": 0,
		"enhance_attack_bonus": 0,
		"enhance_defense_bonus": 0,
		"equip_requirement": {"stat": "level", "min": maxi(1, equipment_level * (rarity_index + 1))},
		"affixes": affixes,
	}


static func task_zone_id(task_type: int) -> String:
	return TASK_ZONE_IDS.get(task_type, "")


static func task_name(task_type: int) -> String:
	return TASK_ZONE_NAMES.get(task_type, "任务")


static func building_name(building_id: String) -> String:
	return str(BUILDING_DEFS.get(building_id, {}).get("name", building_id))


static func building_max_level(building_id: String) -> int:
	return int(BUILDING_DEFS.get(building_id, {}).get("max_level", 10))


static func building_upgrade_cost(building_id: String, current_level: int) -> Dictionary:
	var definition: Dictionary = BUILDING_DEFS.get(building_id, {})
	if definition.is_empty():
		return {}
	var amount: int = maxi(1, current_level + int(definition.get("cost_offset", 0)))
	return {"item_id": str(definition.get("cost_item", "")), "amount": amount}


static func recruit_max_trait_count(level: int) -> int:
	if level >= 7:
		return 3
	if level >= 4:
		return 2
	return 1


static func forge_duration_seconds(level: int) -> float:
	return max(300.0, 900.0 - 60.0 * float(maxi(1, level) - 1))


static func alchemy_duration_seconds(level: int, amount: int) -> float:
	return max(180.0, 600.0 - 45.0 * float(maxi(1, level) - 1)) * float(maxi(1, amount))


static func farm_growth_multiplier(level: int) -> float:
	return max(0.55, 1.0 - 0.05 * float(maxi(1, level) - 1))


static func element_name(element_id: String) -> String:
	return ELEMENT_NAMES.get(element_id, element_id)


static func resource_name(resource_id: String) -> String:
	var item: Dictionary = ITEM_DEFS.get(resource_id, {})
	if not item.is_empty():
		return item_display_name(resource_id)
	return resource_id


static func item_type_name(type_id: String) -> String:
	match type_id:
		ITEM_TYPE_SKILL_BOOK:
			return "技能书"
		ITEM_TYPE_EQUIPMENT:
			return "装备"
		ITEM_TYPE_MATERIAL:
			return "材料"
		ITEM_TYPE_CROP:
			return "作物"
		ITEM_TYPE_PILL:
			return "丹药"
		ITEM_TYPE_ALCHEMY_RECIPE:
			return "图纸"
		_:
			return type_id


static func item_use_scope(item_id: String) -> String:
	return str(ITEM_DEFS.get(item_id, {}).get("use_scope", ITEM_USE_SCOPE_NONE))


static func item_use_scope_label(scope: String) -> String:
	match scope:
		ITEM_USE_SCOPE_HOME:
			return "家园"
		ITEM_USE_SCOPE_COMBAT:
			return "战斗"
		_:
			return "无"


static func item_gain_target(item_id: String) -> String:
	return str(ITEM_DEFS.get(item_id, {}).get("gain_target", "none"))


static func item_gain_target_label(target_id: String) -> String:
	return ITEM_GAIN_TARGET_LABELS.get(target_id, target_id)


static func item_gain_target_color(_target_id: String) -> Color:
	return Color(0.95, 0.82, 0.42, 1.0)


static func attribute_display_name(stat_id: String) -> String:
	if ITEM_GAIN_TARGET_LABELS.has(stat_id):
		return str(ITEM_GAIN_TARGET_LABELS[stat_id])
	if stat_id.begins_with(ELEMENT_ATTRIBUTE_PREFIX):
		return element_name(element_id_from_attribute(stat_id))
	return stat_id


static func obtain_source_name(source_id: String) -> String:
	return OBTAIN_SOURCE_NAMES.get(source_id, source_id)


static func slot_name(slot_id: String) -> String:
	return SLOT_NAMES.get(slot_id, slot_id)


static func equipment_rarity_name(rarity: String) -> String:
	return EQUIPMENT_RARITY_NAMES.get(rarity, rarity)


static func random_equipment_rarity(rng: RandomNumberGenerator) -> String:
	var total_weight := 0
	for rarity in EQUIPMENT_RARITY_ORDER:
		total_weight += int(EQUIPMENT_RARITY_WEIGHTS.get(rarity, 0))
	var roll := rng.randi_range(1, maxi(1, total_weight))
	var cursor := 0
	for rarity in EQUIPMENT_RARITY_ORDER:
		cursor += int(EQUIPMENT_RARITY_WEIGHTS.get(rarity, 0))
		if roll <= cursor:
			return str(rarity)
	return "t1"


static func upgrade_equipment_rarity(rarity: String, steps: int) -> String:
	var index := EQUIPMENT_RARITY_ORDER.find(rarity)
	if index < 0:
		index = 0
	index = clampi(index + steps, 0, EQUIPMENT_RARITY_ORDER.size() - 1)
	return str(EQUIPMENT_RARITY_ORDER[index])


static func element_id_from_attribute(stat_id: String) -> String:
	if stat_id.begins_with(ELEMENT_ATTRIBUTE_PREFIX):
		return stat_id.trim_prefix(ELEMENT_ATTRIBUTE_PREFIX)
	return ""


static func is_farm_seed(item_id: String) -> bool:
	var definition: Dictionary = ITEM_DEFS.get(item_id, {})
	if str(definition.get("type", "")) != ITEM_TYPE_CROP:
		return false
	var payload: Dictionary = definition.get("payload", {})
	return payload.has("seed_yield")


static func is_farm_speed_item(item_id: String) -> bool:
	return item_id == "farm_speed_talisman"


static func crop_seed_yield(item_id: String) -> int:
	return int(ITEM_DEFS.get(item_id, {}).get("payload", {}).get("seed_yield", 1))


static func crop_growth_seconds(item_id: String) -> float:
	return float(ITEM_DEFS.get(item_id, {}).get("payload", {}).get("growth_seconds", 60.0))


static func farm_speed_item_multiplier(_item_id: String) -> float:
	return 1.5


static func farm_speed_item_duration(_item_id: String) -> float:
	return 300.0


static func enhance_stone_item_id(stat_id: String) -> String:
	if stat_id.begins_with(ELEMENT_ATTRIBUTE_PREFIX):
		return "spirit_stone_%s" % element_id_from_attribute(stat_id)
	if ["attack", "defense", "max_hp", "max_mp", "root_bone"].has(stat_id):
		return ITEM_ID_SPIRIT_STONE
	return ""


static func spirit_stone_enhance_amount(_item_id: String = "") -> int:
	return 1


static func alchemy_recipe_def(recipe_id: String) -> Dictionary:
	return ALCHEMY_RECIPE_DEFS.get(recipe_id, {}).duplicate(true)


static func alchemy_recipe_materials(recipe_id: String) -> Array:
	return ALCHEMY_RECIPE_DEFS.get(recipe_id, {}).get("materials", []).duplicate(true)
