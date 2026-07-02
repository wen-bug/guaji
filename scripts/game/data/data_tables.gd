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

const SPIRIT_STONE_QUALITY_ORDER := ["t1", "t2", "t3", "t4", "t5"]

const ITEM_DEFS := {
	"herb": {"name": "草药", "description": "通用炼丹材料，也可作为种子。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 3, "growth_seconds": 60.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"rice": {"name": "灵米", "description": "基础作物与辅料。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 2, "growth_seconds": 90.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"mushroom": {"name": "灵菇", "description": "基础作物与辅料。", "type": ITEM_TYPE_CROP, "stackable": true, "usable": false, "payload": {"seed_yield": 1, "growth_seconds": 120.0}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"ore": {"name": "矿石", "description": "通用炼器与招募材料。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"farm_speed_talisman": {"name": "丰收符", "description": "提升农田生长速度一段时间。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": true, "payload": {"farm_speed": true}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
	"stat_stone_attack_t1": {"name": "攻击灵石·一阶", "description": "可用于强化攻击属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "attack", "quality": "t1", "enhance_amount": 1, "stone_group": "stat"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "attack"},
	"stat_stone_defense_t1": {"name": "防御灵石·一阶", "description": "可用于强化防御属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "defense", "quality": "t1", "enhance_amount": 1, "stone_group": "stat"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "defense"},
	"spirit_stone_fire_t1": {"name": "火灵石·一阶", "description": "可用于强化火行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_fire", "quality": "t1", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "fire"},
	"spirit_stone_earth_t1": {"name": "土灵石·一阶", "description": "可用于强化土行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_earth", "quality": "t1", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "earth"},
	"spirit_stone_wood_t1": {"name": "木灵石·一阶", "description": "可用于强化木行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_wood", "quality": "t1", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "wood"},
	"spirit_stone_metal_t1": {"name": "金灵石·一阶", "description": "可用于强化金行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_metal", "quality": "t1", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "metal"},
	"spirit_stone_water_t1": {"name": "水灵石·一阶", "description": "可用于强化水行属性。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {"stat": "element_water", "quality": "t1", "enhance_amount": 1, "stone_group": "element"}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "water"},
	"refine_talisman": {"name": "洗练符", "description": "用于装备洗练。", "type": ITEM_TYPE_MATERIAL, "stackable": true, "usable": false, "payload": {}, "use_scope": ITEM_USE_SCOPE_NONE, "gain_target": "none"},
	"recipe_pill": {"name": "调息丹方", "description": "学习后可炼制调息丹。", "type": ITEM_TYPE_ALCHEMY_RECIPE, "stackable": true, "usable": true, "payload": {"recipe_id": "pill"}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
	"pill": {"name": "调息丹", "description": "恢复生命和法力。", "type": ITEM_TYPE_PILL, "stackable": true, "usable": true, "payload": {"hp": 18, "mp": 12}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
	"breakthrough_pill": {"name": "破境丹", "description": "达到等级上限时可突破。", "type": ITEM_TYPE_PILL, "stackable": true, "usable": true, "payload": {"breakthrough": true}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
	"skill_fireball": {"name": "火球术残卷", "description": "学习后获得火球术。", "type": ITEM_TYPE_SKILL_BOOK, "stackable": true, "usable": true, "payload": {"skill_id": "fireball"}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "none"},
}

const SKILL_DEFS := {
	"fireball": {"id": "fireball", "name": "火球术", "type": "damage", "element": "fire", "mp_cost": 8, "cooldown": 3.0, "damage_multiplier": 1.35, "release_distance": 120.0, "priority": 50, "trigger": ["always"], "combat_buffs": []},
	"heal": {"id": "heal", "name": "回春术", "type": "heal", "element": "wood", "mp_cost": 6, "cooldown": 5.0, "damage_multiplier": 0.0, "release_distance": 96.0, "priority": 90, "trigger": ["hp_below_35"], "combat_buffs": []},
	"thunder": {"id": "thunder", "name": "雷击术", "type": "damage", "element": "metal", "mp_cost": 12, "cooldown": 5.0, "damage_multiplier": 1.75, "release_distance": 140.0, "priority": 60, "trigger": ["always"], "combat_buffs": []},
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

const ENEMY_TEMPLATES := {
	"training_dummy": {"id": "training_dummy", "name": "木桩", "level_offset": 0, "max_hp": 40, "attack": 3, "defense": 0, "move_speed": 48.0, "player_move_speed": 96.0, "attack_range": 72.0, "player_attack_range": 96.0, "spawn_delay": 0.4, "turn_wait": 1.8, "element": "wood", "weak_element": "fire", "element_attack_ratio": 0.0, "drops": {}, "exp": 6, "use_drop": false, "is_training_dummy": true},
	"forest_wolf": {"id": "forest_wolf", "name": "林狼", "level_offset": 0, "max_hp": 32, "attack": 6, "defense": 1, "move_speed": 120.0, "player_move_speed": 120.0, "attack_range": 88.0, "player_attack_range": 96.0, "spawn_delay": 0.6, "turn_wait": 1.4, "element": "wood", "weak_element": "fire", "element_attack_ratio": 0.2, "drops": {"herb": {"chance": 0.55, "min": 1, "max": 2}}, "exp": 10, "use_drop": true, "is_training_dummy": false},
}

const ENEMY_SCENE_PATHS := {
	"training_dummy": "res://scripts/game/enemies/training_dummy/enemy.tscn",
	"forest_wolf": "res://scripts/game/enemies/forest_wolf/enemy.tscn",
}

const DEFAULT_ENEMY_ID := "training_dummy"


static func item_definition(item_id: String) -> Dictionary:
	return ITEM_DEFS.get(item_id, {}).duplicate(true)


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
	}


static func create_skill(skill_id: String = "fireball", obtain_source: String = "non_drop") -> Dictionary:
	var definition: Dictionary = SKILL_DEFS.get(skill_id, {})
	if definition.is_empty():
		return {}
	var skill: Dictionary = definition.duplicate(true)
	skill["obtain_source"] = obtain_source
	return skill


static func create_enemy(level: int, rng: RandomNumberGenerator, enemy_id: String = DEFAULT_ENEMY_ID) -> Dictionary:
	var resolved_enemy_id: String = resolve_enemy_id(enemy_id)
	var template: Dictionary = ENEMY_TEMPLATES.get(resolved_enemy_id, ENEMY_TEMPLATES[DEFAULT_ENEMY_ID]).duplicate(true)
	var enemy_level: int = maxi(1, level + int(template.get("level_offset", 0)))
	var max_hp: int = int(template.get("max_hp", 1)) + enemy_level * 4
	var attack: int = int(template.get("attack", 1)) + enemy_level * 1
	var defense: int = int(template.get("defense", 0)) + enemy_level / 3
	return {
		"id": str(template.get("id", resolved_enemy_id)),
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
	return create_equipment_from_template(template_id, level, rng, craft_bonus, "", "t1", obtain_source)


static func create_equipment_from_template(template_id: String, level: int, rng: RandomNumberGenerator, craft_bonus: int = 0, _name_prefix: String = "", rarity: String = "t1", obtain_source: String = "non_drop") -> Dictionary:
	var template: Dictionary = EQUIPMENT_DEFS.get(template_id, {})
	if template.is_empty():
		return {}
	var rarity_index := maxi(0, EQUIPMENT_RARITY_ORDER.find(rarity))
	if rarity_index < 0:
		rarity_index = 0
	var rarity_name: String = str(EQUIPMENT_RARITY_NAMES.get(rarity, "一阶"))
	var slot := str(template.get("slot", template_id))
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
		"name": "%s·%s" % [rarity_name, slot_name(slot)],
		"description": "%s等级装备" % rarity_name,
		"type": ITEM_TYPE_EQUIPMENT,
		"count": 1,
		"stackable": false,
		"usable": true,
		"payload": {},
		"obtain_source": obtain_source,
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


static func element_name(element_id: String) -> String:
	return ELEMENT_NAMES.get(element_id, element_id)


static func resource_name(resource_id: String) -> String:
	var item: Dictionary = ITEM_DEFS.get(resource_id, {})
	if not item.is_empty():
		return str(item.get("name", resource_id))
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


static func element_id_from_attribute(stat_id: String) -> String:
	if stat_id.begins_with(ELEMENT_ATTRIBUTE_PREFIX):
		return stat_id.trim_prefix(ELEMENT_ATTRIBUTE_PREFIX)
	return ""


static func is_farm_seed(item_id: String) -> bool:
	return ITEM_DEFS.has(item_id) and item_id in ["herb", "rice", "mushroom"]


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


static func enhance_stone_item_id(stat_id: String, quality: String) -> String:
	if stat_id.begins_with(ELEMENT_ATTRIBUTE_PREFIX):
		return "spirit_stone_%s_%s" % [element_id_from_attribute(stat_id), quality]
	return "stat_stone_%s_%s" % [stat_id, quality]


static func spirit_stone_enhance_amount(quality: String) -> int:
	match quality:
		"t1":
			return 1
		"t2":
			return 2
		"t3":
			return 4
		"t4":
			return 7
		"t5":
			return 11
		_:
			return 1


static func alchemy_recipe_def(recipe_id: String) -> Dictionary:
	return {"result_item_id": recipe_id, "materials": []}


static func alchemy_recipe_materials(_recipe_id: String) -> Array:
	return []
