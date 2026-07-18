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
const ITEM_ID_SKILL_BOOK_THUNDER := "skill_book_thunder"
const ITEM_ID_SKILL_BOOK_POISON := "skill_book_poison"
const ITEM_ID_SKILL_BOOK_HEAL := "skill_book_heal"
const ITEM_ID_SKILL_BOOK_ATTACK_UP := "skill_book_attack_up"
const ITEM_ID_SKILL_BOOK_SPIRIT_SHIELD := "skill_book_spirit_shield"

const ATTACK_MODE_MELEE := "melee"
const ATTACK_MODE_RANGED := "ranged"
const ATTACK_MODES := [ATTACK_MODE_MELEE, ATTACK_MODE_RANGED]
const RANGED_BASIC_ATTACK_ID := "fireball"

const SKILL_TARGET_SELF := "self"
const SKILL_TARGET_SINGLE_ALLY := "single_ally"
const SKILL_TARGET_ALL_ALLIES := "all_allies"
const SKILL_TARGET_SINGLE_ENEMY := "single_enemy"
const SKILL_TARGET_ALL_ENEMIES := "all_enemies"
const SKILL_TARGET_SCOPES := [
	SKILL_TARGET_SELF,
	SKILL_TARGET_SINGLE_ALLY,
	SKILL_TARGET_ALL_ALLIES,
	SKILL_TARGET_SINGLE_ENEMY,
	SKILL_TARGET_ALL_ENEMIES,
]
const SKILL_TARGET_MODE_SINGLE := "single"
const SKILL_TARGET_MODE_AOE := "aoe"
const SKILL_BUFF_EFFECT_KINDS := ["hot", "shield", "buff_stat"]
const SKILL_DEBUFF_EFFECT_KINDS := ["dot", "debuff_stat"]

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

const INNATE_TRAIT_RARITY_NAMES := {
	"common": "普通",
	"rare": "优秀",
	"exceptional": "异禀",
}

const INNATE_TRAIT_SLOT_NAMES := {
	"main": "主命格",
	"sub": "副命格",
	"flaw": "缺陷命格",
	"basic": "命格",
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
const EQUIPMENT_RARITY_WEIGHTS := {
	"t1": 55,
	"t2": 28,
	"t3": 12,
	"t4": 4,
	"t5": 1,
}
const EQUIPMENT_ENHANCE_LIMITS := {
	"t1": 5,
	"t2": 10,
	"t3": 20,
	"t4": 30,
	"t5": 40,
}
const EQUIPMENT_ENHANCE_BASE_COSTS := {
	"t1": 1,
	"t2": 2,
	"t3": 3,
	"t4": 5,
	"t5": 8,
}
const EQUIPMENT_ATTRIBUTE_POINT_BUDGETS := {
	"t1": 20,
	"t2": 50,
	"t3": 100,
	"t4": 180,
	"t5": 300,
}
const EQUIPMENT_NORMAL_ATTRIBUTE_STATS := ["attack", "defense", "max_hp", "max_mp", "root_bone"]
const EQUIPMENT_ELEMENT_ATTRIBUTE_STATS := ["element_wood", "element_fire", "element_earth", "element_metal", "element_water"]

const ENEMY_RANK_ORDER := ["t1", "t2", "t3", "t4", "t5"]
const ENEMY_RANK_DEFS := {
	"t1": {"name": "一阶", "min_level": 1, "max_level": 20, "skill_count": 0, "stat_multipliers": {"max_hp": 1.0, "attack": 1.0, "defense": 1.0}, "level_growth": {"max_hp": 4.0, "attack": 1.0, "defense": 0.33}, "element_attack_ratio": 0.15, "base_drop_chance": 0.55, "drop_categories": ["basic_material"], "drop_rarity_weights": {"t1": 90, "t2": 10, "t3": 0, "t4": 0, "t5": 0}},
	"t2": {"name": "二阶", "min_level": 21, "max_level": 40, "skill_count": 1, "stat_multipliers": {"max_hp": 1.35, "attack": 1.30, "defense": 1.25}, "level_growth": {"max_hp": 5.0, "attack": 1.2, "defense": 0.40}, "element_attack_ratio": 0.25, "base_drop_chance": 0.60, "drop_categories": ["basic_material", "attribute_crop"], "drop_rarity_weights": {"t1": 70, "t2": 25, "t3": 5, "t4": 0, "t5": 0}},
	"t3": {"name": "三阶", "min_level": 41, "max_level": 60, "skill_count": 2, "stat_multipliers": {"max_hp": 1.80, "attack": 1.65, "defense": 1.55}, "level_growth": {"max_hp": 6.0, "attack": 1.4, "defense": 0.50}, "element_attack_ratio": 0.35, "base_drop_chance": 0.65, "drop_categories": ["basic_material", "attribute_crop", "element_stone"], "drop_rarity_weights": {"t1": 55, "t2": 30, "t3": 12, "t4": 3, "t5": 0}},
	"t4": {"name": "四阶", "min_level": 61, "max_level": 80, "skill_count": 3, "stat_multipliers": {"max_hp": 2.35, "attack": 2.10, "defense": 1.95}, "level_growth": {"max_hp": 7.0, "attack": 1.7, "defense": 0.65}, "element_attack_ratio": 0.50, "base_drop_chance": 0.70, "drop_categories": ["basic_material", "attribute_crop", "element_stone", "production_material"], "drop_rarity_weights": {"t1": 40, "t2": 35, "t3": 18, "t4": 6, "t5": 1}},
	"t5": {"name": "五阶", "min_level": 81, "max_level": 0, "skill_count": 4, "stat_multipliers": {"max_hp": 3.00, "attack": 2.65, "defense": 2.45}, "level_growth": {"max_hp": 9.0, "attack": 2.0, "defense": 0.80}, "element_attack_ratio": 0.70, "base_drop_chance": 0.75, "drop_categories": ["basic_material", "attribute_crop", "element_stone", "production_material", "rare_material"], "drop_rarity_weights": {"t1": 25, "t2": 35, "t3": 25, "t4": 12, "t5": 3}},
}

const ENEMY_DROP_CATEGORY_ITEMS := {
	"basic_material": ["herb", "ore", "spirit_stone"],
	"attribute_crop": ["blade_grass", "ironroot", "blood_ginseng", "spirit_lotus", "bone_bamboo", "woodvine", "flame_flower", "earth_moss", "metal_reed", "water_orchid"],
	"element_stone": ["spirit_stone_wood", "spirit_stone_fire", "spirit_stone_earth", "spirit_stone_metal", "spirit_stone_water"],
	"production_material": ["farm_speed_talisman", "refine_talisman"],
	"rare_material": ["pill", "breakthrough_pill"],
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
	"skill_book_thunder": {"item_no": 1029, "name": "雷击术技能书", "description": "使用后令选中角色永久学会雷击术。", "type": ITEM_TYPE_SKILL_BOOK, "stackable": true, "usable": true, "payload": {"skill_id": "thunder", "obtain_source": "non_drop"}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "metal"},
	"skill_book_poison": {"item_no": 1030, "name": "蚀骨毒雾技能书", "description": "使用后令选中角色永久学会蚀骨毒雾。", "type": ITEM_TYPE_SKILL_BOOK, "stackable": true, "usable": true, "payload": {"skill_id": "poison", "obtain_source": "non_drop"}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "wood"},
	"skill_book_heal": {"item_no": 1031, "name": "回春术技能书", "description": "使用后令选中角色永久学会回春术。", "type": ITEM_TYPE_SKILL_BOOK, "stackable": true, "usable": true, "payload": {"skill_id": "heal", "obtain_source": "non_drop"}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "wood"},
	"skill_book_attack_up": {"item_no": 1032, "name": "燃锋诀技能书", "description": "使用后令选中角色永久学会燃锋诀。", "type": ITEM_TYPE_SKILL_BOOK, "stackable": true, "usable": true, "payload": {"skill_id": "attack_up", "obtain_source": "non_drop"}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "fire"},
	"skill_book_spirit_shield": {"item_no": 1033, "name": "玄甲术技能书", "description": "使用后令选中角色永久学会玄甲术。", "type": ITEM_TYPE_SKILL_BOOK, "stackable": true, "usable": true, "payload": {"skill_id": "spirit_shield", "obtain_source": "non_drop"}, "use_scope": ITEM_USE_SCOPE_HOME, "gain_target": "earth"},
}

const SKILL_DEFS := {
	"heal": {"id": "heal", "name": "回春术", "type": "heal", "target_scope": SKILL_TARGET_SELF, "element": "wood", "mp_cost": 6, "cooldown": 5, "damage_multiplier": 0.0, "heal_multiplier": 1.0, "release_distance": 96.0, "priority": 90, "trigger": ["hp_below_35"], "combat_buffs": [], "effects": [], "scene_path": "res://scripts/game/skills/heal/heal_skill.tscn"},
	"thunder": {"id": "thunder", "name": "雷击术", "type": "damage", "target_scope": SKILL_TARGET_SINGLE_ENEMY, "element": "metal", "mp_cost": 12, "cooldown": 5, "damage_multiplier": 1.75, "release_distance": 140.0, "priority": 60, "trigger": ["always"], "combat_buffs": [], "effects": [], "scene_path": "res://scripts/game/skills/damage/thunder_skill.tscn"},
	"poison": {"id": "poison", "name": "蚀骨毒雾", "type": "damage", "target_scope": SKILL_TARGET_ALL_ENEMIES, "element": "wood", "mp_cost": 8, "cooldown": 4, "damage_multiplier": 0.9, "release_distance": 120.0, "priority": 55, "trigger": ["always"], "combat_buffs": [], "effects": [{"kind": "dot", "trigger": "on_hit", "target": "target", "element": "wood", "amount": 2, "duration_turns": 3}], "scene_path": "res://scripts/game/skills/damage/poison_skill.tscn"},
	"attack_up": {"id": "attack_up", "name": "燃锋诀", "type": "buff", "target_scope": SKILL_TARGET_SELF, "element": "fire", "mp_cost": 5, "cooldown": 6, "damage_multiplier": 0.0, "release_distance": 0.0, "priority": 70, "trigger": ["always"], "combat_buffs": [], "effects": [{"kind": "buff_stat", "target": "self", "stat": "attack", "amount": 2, "duration_turns": 3}], "scene_path": "res://scripts/game/skills/buff/attack_up_skill.tscn"},
	"spirit_shield": {"id": "spirit_shield", "name": "玄甲术", "type": "defense", "target_scope": SKILL_TARGET_SELF, "element": "earth", "mp_cost": 7, "cooldown": 6, "damage_multiplier": 0.0, "release_distance": 0.0, "priority": 80, "trigger": ["hp_below_60"], "combat_buffs": [], "effects": [{"kind": "shield", "target": "self", "amount": 10, "duration_turns": 3}], "scene_path": "res://scripts/game/skills/buff/spirit_shield_skill.tscn"},
	"wolf_bite": {"id": "wolf_bite", "name": "撕咬", "type": "damage", "target_scope": SKILL_TARGET_SINGLE_ENEMY, "element": "wood", "enemy_only": true, "mp_cost": 0, "cooldown": 2, "damage_multiplier": 1.25, "release_distance": 0.0, "priority": 40, "trigger": ["always"], "weight": 1, "combat_buffs": [], "effects": [], "scene_path": "res://scripts/game/skills/damage/direct_damage_skill.tscn"},
	"wolf_bleed": {"id": "wolf_bleed", "name": "裂伤", "type": "damage", "target_scope": SKILL_TARGET_SINGLE_ENEMY, "element": "wood", "enemy_only": true, "mp_cost": 0, "cooldown": 3, "damage_multiplier": 1.0, "release_distance": 0.0, "priority": 55, "trigger": ["always"], "weight": 1, "combat_buffs": [], "effects": [{"kind": "dot", "trigger": "on_hit", "target": "target", "element": "wood", "amount": 2, "duration": 2}], "scene_path": "res://scripts/game/skills/damage/direct_damage_skill.tscn"},
	"wolf_howl": {"id": "wolf_howl", "name": "狼嚎", "type": "damage", "target_scope": SKILL_TARGET_ALL_ENEMIES, "element": "wood", "enemy_only": true, "mp_cost": 0, "cooldown": 4, "damage_multiplier": 1.1, "release_distance": 0.0, "priority": 65, "trigger": ["hp_below_50"], "weight": 1, "combat_buffs": [], "effects": [{"kind": "buff_stat", "trigger": "after_damage", "target": "self", "stat": "attack", "amount": 2, "duration": 2}], "scene_path": "res://scripts/game/skills/damage/direct_damage_skill.tscn"},
	"wolf_pounce": {"id": "wolf_pounce", "name": "扑杀", "type": "damage", "target_scope": SKILL_TARGET_SINGLE_ENEMY, "element": "wood", "enemy_only": true, "mp_cost": 0, "cooldown": 5, "damage_multiplier": 1.8, "release_distance": 0.0, "priority": 80, "trigger": ["target_hp_below_35"], "weight": 1, "combat_buffs": [], "effects": [], "scene_path": "res://scripts/game/skills/damage/direct_damage_skill.tscn"},
}

const BASIC_ATTACK_DEFS := {
	ATTACK_MODE_MELEE: {"id": "basic_attack", "name": "普通攻击", "attack_mode": ATTACK_MODE_MELEE, "target_scope": SKILL_TARGET_SINGLE_ENEMY, "element": "", "mp_cost": 0, "cooldown": 0.0, "release_distance": 0.0, "scene_path": "res://scripts/game/skills/damage/basic_attack.tscn"},
	ATTACK_MODE_RANGED: {"id": RANGED_BASIC_ATTACK_ID, "name": "火球术", "attack_mode": ATTACK_MODE_RANGED, "target_scope": SKILL_TARGET_SINGLE_ENEMY, "element": "fire", "mp_cost": 0, "cooldown": 0.0, "release_distance": 120.0, "scene_path": "res://scripts/game/skills/damage/basic_attack.tscn"},
}

const ALCHEMY_RECIPE_DEFS := {
	"pill": {"result_item_id": "pill", "materials": [{"item_id": "herb", "amount": 2}]},
}

const EQUIPMENT_DEFS := {
	"weapon": {"slot": "weapon", "name": "武器"},
	"helmet": {"slot": "helmet", "name": "头盔"},
	"armor": {"slot": "armor", "name": "护甲"},
	"leggings": {"slot": "leggings", "name": "胫甲"},
	"gloves": {"slot": "gloves", "name": "护手"},
	"accessory": {"slot": "accessory", "name": "饰品"},
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
	"training_dummy": {"id": "training_dummy", "visual_id": "training_dummy", "name": "木桩", "level_offset": 0, "max_hp": 40, "attack": 3, "defense": 0, "move_speed": 48.0, "player_move_speed": 96.0, "attack_range": 72.0, "player_attack_range": 96.0, "spawn_delay": 0.4, "turn_wait": 1.8, "element": "wood", "weak_element": "fire", "element_attack_ratio": 0.0, "skills": [], "drop_profile": {"base_chance": 0.0, "items": []}, "equipment_drop_chance": 0.0, "exp": 6, "use_drop": false, "is_training_dummy": true},
	"forest_wolf": {"id": "forest_wolf", "visual_id": "forest_wolf", "name": "林狼", "level_offset": 0, "max_hp": 32, "attack": 6, "defense": 1, "move_speed": 120.0, "player_move_speed": 120.0, "attack_range": 88.0, "player_attack_range": 96.0, "spawn_delay": 0.6, "turn_wait": 1.4, "element": "wood", "element_power": 3, "weak_element": "fire", "element_attack_ratio": 0.05, "skills": ["wolf_bite", "wolf_bleed", "wolf_howl", "wolf_pounce"], "drop_profile": {"base_chance": 0.55}, "drops": {"herb": {"chance": 0.55, "min": 1, "max": 2}, "ore": {"chance": 0.30, "min": 1, "max": 1}, "spirit_stone": {"chance": 0.10, "min": 1, "max": 1}}, "equipment_drop_chance": 0.05, "exp": 10, "use_drop": true, "is_training_dummy": false},
}

const ENEMY_SCENE_PATHS := {
	"training_dummy": "res://scripts/game/enemies/training_dummy/enemy.tscn",
	"forest_wolf": "res://scripts/game/enemies/forest_wolf/enemy.tscn",
}

const DEFAULT_ENEMY_ID := "training_dummy"


static func _mod_content():
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var api := tree.root.get_node_or_null("ModAPI")
	return api.content if api != null else null


static func content_definition(kind: String, content_id: String, fallback: Dictionary = {}) -> Dictionary:
	var registry = _mod_content()
	if registry != null and registry.has(kind, content_id):
		return registry.definition(kind, content_id)
	return fallback.duplicate(true)


static func content_definitions(kind: String, fallback: Dictionary = {}) -> Dictionary:
	var registry = _mod_content()
	return registry.all(kind) if registry != null else fallback.duplicate(true)


static func content_ids(kind: String, fallback: Dictionary = {}) -> Array[String]:
	var registry = _mod_content()
	if registry != null:
		return registry.ids(kind)
	var result: Array[String] = []
	for content_id in fallback.keys():
		result.append(str(content_id))
	result.sort()
	return result


static func content_has(kind: String, content_id: String, fallback: Dictionary = {}) -> bool:
	var registry = _mod_content()
	return registry.has(kind, content_id) if registry != null else fallback.has(content_id)


static func item_definition(item_id: String) -> Dictionary:
	return content_definition("item", item_id, ITEM_DEFS.get(item_id, {}))


static func item_drop_rarity(item_id: String) -> String:
	var definition: Dictionary = item_definition(item_id)
	if definition.has("drop_rarity"):
		return str(definition.get("drop_rarity", "t1"))
	if item_id in ["herb", "ore", "spirit_stone"]:
		return "t1"
	if item_id.begins_with("spirit_stone_") or item_id in ["blade_grass", "ironroot", "blood_ginseng", "spirit_lotus", "bone_bamboo", "woodvine", "flame_flower", "earth_moss", "metal_reed", "water_orchid"]:
		return "t2"
	if item_id in ["farm_speed_talisman", "refine_talisman"]:
		return "t3"
	if item_id in ["pill", "breakthrough_pill"]:
		return "t4"
	return "t1"


static func item_no(item_id: String) -> int:
	return int(item_definition(item_id).get("item_no", 0))


static func item_id_from_no(no: int) -> String:
	for item_id in content_ids("item", ITEM_DEFS):
		if int(item_definition(item_id).get("item_no", 0)) == no:
			return str(item_id)
	return ""


static func item_icon_name(item_id: String) -> String:
	var definition: Dictionary = item_definition(item_id)
	return str(definition.get("icon_name", item_id))


static func item_icon_path(item_id: String) -> String:
	var definition: Dictionary = item_definition(item_id)
	if definition.has("icon_path"):
		return str(definition.get("icon_path", ""))
	var icon_name: String = item_icon_name(item_id)
	if icon_name.is_empty():
		return ""
	return "%s/%s.png" % [ITEM_ICON_ROOT, icon_name]


static func equipment_icon_name(template_id: String) -> String:
	var definition: Dictionary = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {}))
	return str(definition.get("icon_name", template_id))


static func equipment_icon_path(template_id: String) -> String:
	var definition: Dictionary = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {}))
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
	return str(item_definition(item_id).get("name", item_id))


static func item_display_description(item_id: String) -> String:
	var resource: Resource = item_resource(item_id)
	var description: String = _resource_string(resource, "description", "")
	if not description.is_empty():
		return description
	return str(item_definition(item_id).get("description", ""))


static func equipment_template_description(template_id: String) -> String:
	var resource: Resource = equipment_resource(template_id)
	var description: String = _resource_string(resource, "description", "")
	if not description.is_empty():
		return description
	return str(content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {})).get("description", ""))


static func equipment_template_description_effects(template_id: String) -> Array:
	var resource: Resource = equipment_resource(template_id)
	if resource != null:
		var resource_effects = resource.get("description_effects")
		if resource_effects is Array and not resource_effects.is_empty():
			return resource_effects.duplicate(true)
	var table_effects = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {})).get("description_effects", [])
	return table_effects.duplicate(true) if table_effects is Array else []


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
		"consumable": bool(definition.get("consumable", definition.get("type", "") == ITEM_TYPE_SKILL_BOOK)),
		"payload": definition.get("payload", {}).duplicate(true),
		"obtain_source": "non_drop",
		"gain_target": definition.get("gain_target", "none"),
		"item_no": item_no(item_id),
		"icon_name": item_icon_name(item_id),
		"icon_path": item_icon_path(item_id),
		"resource_path": item_resource_path(item_id),
	}


static func create_skill(skill_id: String, obtain_source: String = "non_drop") -> Dictionary:
	var definition: Dictionary = content_definition("skill", skill_id, SKILL_DEFS.get(skill_id, {}))
	if definition.is_empty():
		return {}
	var skill: Dictionary = normalize_skill_definition(definition)
	skill["obtain_source"] = obtain_source
	if not bool(skill.get("enemy_only", false)):
		skill["locked"] = true
		skill["replaceable"] = false
	return skill


static func create_basic_attack(attack_mode: String, base_damage: int = 0) -> Dictionary:
	var resolved_mode: String = attack_mode if ATTACK_MODES.has(attack_mode) else ATTACK_MODE_MELEE
	var attack: Dictionary = normalize_skill_definition(content_definition("basic_attack", resolved_mode, BASIC_ATTACK_DEFS[resolved_mode]))
	attack["type"] = "normal_attack"
	attack["base_damage"] = maxi(0, base_damage)
	attack["damage_marker"] = "impact"
	return attack


static func normalize_skill_definition(definition: Dictionary) -> Dictionary:
	var skill: Dictionary = definition.duplicate(true)
	var scope: String = str(skill.get("target_scope", ""))
	if not SKILL_TARGET_SCOPES.has(scope):
		scope = _default_skill_target_scope(str(skill.get("type", "")))
	skill["target_scope"] = scope
	skill["target_mode"] = SKILL_TARGET_MODE_AOE if scope in [SKILL_TARGET_ALL_ALLIES, SKILL_TARGET_ALL_ENEMIES] else SKILL_TARGET_MODE_SINGLE
	skill["is_aoe"] = skill["target_mode"] == SKILL_TARGET_MODE_AOE
	var tags: Array[String] = _skill_effect_tags(skill)
	skill["effect_tags"] = tags
	skill["has_buff"] = tags.has("buff")
	skill["has_debuff"] = tags.has("debuff")
	return skill


static func skill_target_scope(skill: Dictionary) -> String:
	return str(normalize_skill_definition(skill).get("target_scope", SKILL_TARGET_SINGLE_ENEMY))


static func skill_target_mode(skill: Dictionary) -> String:
	return str(normalize_skill_definition(skill).get("target_mode", SKILL_TARGET_MODE_SINGLE))


static func skill_is_aoe(skill: Dictionary) -> bool:
	return bool(normalize_skill_definition(skill).get("is_aoe", false))


static func skill_effect_tags(skill: Dictionary) -> Array:
	return normalize_skill_definition(skill).get("effect_tags", []).duplicate()


static func skill_has_buff(skill: Dictionary) -> bool:
	return bool(normalize_skill_definition(skill).get("has_buff", false))


static func skill_has_debuff(skill: Dictionary) -> bool:
	return bool(normalize_skill_definition(skill).get("has_debuff", false))


static func skill_target_mode_name(mode: String) -> String:
	return "AOE" if mode == SKILL_TARGET_MODE_AOE else "单体"


static func skill_effect_tag_name(tag: String) -> String:
	return {
		"damage": "伤害",
		"heal": "治疗",
		"buff": "增益",
		"debuff": "减益",
		"shield": "护盾",
		"dot": "持续伤害",
		"hot": "持续治疗",
	}.get(tag, tag)


static func _default_skill_target_scope(skill_type: String) -> String:
	if skill_type in ["heal", "defense", "resource", "buff"]:
		return SKILL_TARGET_SELF
	return SKILL_TARGET_SINGLE_ENEMY


static func _skill_effect_tags(skill: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var skill_type: String = str(skill.get("type", ""))
	if skill_type in ["damage", "normal_attack"] or float(skill.get("damage_multiplier", 0.0)) > 0.0 or int(skill.get("base_damage", 0)) > 0:
		tags.append("damage")
	if skill_type == "heal" or float(skill.get("heal_multiplier", 0.0)) > 0.0 or int(skill.get("heal_amount", 0)) > 0:
		tags.append("heal")
	var effects: Array = skill.get("effects", []) if skill.get("effects", []) is Array else []
	for raw_effect in effects:
		if not (raw_effect is Dictionary):
			continue
		var kind: String = str(raw_effect.get("kind", ""))
		if SKILL_BUFF_EFFECT_KINDS.has(kind) and not tags.has("buff"):
			tags.append("buff")
		if SKILL_DEBUFF_EFFECT_KINDS.has(kind) and not tags.has("debuff"):
			tags.append("debuff")
		if kind in ["shield", "dot", "hot"] and not tags.has(kind):
			tags.append(kind)
	if not skill.get("combat_buffs", []).is_empty() and not tags.has("buff"):
		tags.append("buff")
	return tags


static func create_enemy(level: int, rng: RandomNumberGenerator, enemy_id: String = DEFAULT_ENEMY_ID) -> Dictionary:
	var resolved_enemy_id: String = resolve_enemy_id(enemy_id)
	var template: Dictionary = content_definition("enemy", resolved_enemy_id, ENEMY_TEMPLATES.get(resolved_enemy_id, ENEMY_TEMPLATES[DEFAULT_ENEMY_ID]))
	var enemy_level: int = maxi(1, level + int(template.get("level_offset", 0)))
	var rank_id := enemy_rank_for_level(enemy_level)
	var rank: Dictionary = content_definition("enemy_rank", rank_id, ENEMY_RANK_DEFS[rank_id])
	var rank_level: int = enemy_rank_level(enemy_level)
	var multipliers: Dictionary = rank.get("stat_multipliers", {})
	var growth: Dictionary = rank.get("level_growth", {})
	var max_hp: int = _enemy_scaled_stat(int(template.get("max_hp", 1)), enemy_level, multipliers, growth, "max_hp")
	var attack: int = _enemy_scaled_stat(int(template.get("attack", 1)), enemy_level, multipliers, growth, "attack")
	var defense: int = _enemy_scaled_stat(int(template.get("defense", 0)), enemy_level, multipliers, growth, "defense")
	var element_id := str(template.get("element", ""))
	var element_power := maxi(0, int(template.get("element_power", 0)) + rank_level / 5)
	var skills: Array = template.get("skills", []).duplicate(true) if template.get("skills", []) is Array else []
	var skill_limit := int(rank.get("skill_count", 0))
	while skills.size() > skill_limit:
		skills.pop_back()
	var drop_profile: Dictionary = rank_drop_profile(rank_id, template.get("drop_profile", {}))
	var element_ratio := 0.0 if bool(template.get("is_training_dummy", false)) else float(rank.get("element_attack_ratio", 0.0)) + float(template.get("element_attack_ratio", 0.0))
	return {
		"id": str(template.get("id", resolved_enemy_id)),
		"visual_id": str(template.get("visual_id", "enemy_default")),
		"name": str(template.get("name", "敌人")),
		"level": enemy_level,
		"hp": max_hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"rank": rank_id,
		"rank_name": str(rank.get("name", rank_id)),
		"rank_level": rank_level,
		"move_speed": float(template.get("move_speed", 120.0)),
		"player_move_speed": float(template.get("player_move_speed", 120.0)),
		"attack_range": float(template.get("attack_range", 88.0)),
		"player_attack_range": float(template.get("player_attack_range", 96.0)),
		"spawn_delay": float(template.get("spawn_delay", 0.6)),
		"turn_wait": float(template.get("turn_wait", 1.4)),
		"element": element_id,
		"elements": {element_id: element_power} if not element_id.is_empty() else {},
		"weak_element": str(template.get("weak_element", "fire")),
		"element_attack_ratio": clampf(element_ratio, 0.0, 1.0),
		"skills": skills,
		"skill_cooldowns": {},
		"drop_profile": drop_profile,
		"drops": template.get("drops", {}).duplicate(true),
		"effects": template.get("effects", []).duplicate(true),
		"combat_effects": [],
		"turn_start_processed": false,
		"exp": int(template.get("exp", 5)) + enemy_level * 2,
		"use_drop": bool(template.get("use_drop", true)),
		"is_training_dummy": bool(template.get("is_training_dummy", false)),
}


static func enemy_rank_for_level(level: int) -> String:
	var resolved_level := maxi(1, level)
	for rank_id in ENEMY_RANK_ORDER:
		var definition: Dictionary = content_definition("enemy_rank", str(rank_id), ENEMY_RANK_DEFS[rank_id])
		if resolved_level >= int(definition.get("min_level", 1)) and (int(definition.get("max_level", 0)) <= 0 or resolved_level <= int(definition.get("max_level", 0))):
			return rank_id
	return "t5"


static func enemy_rank_level(level: int) -> int:
	return ((maxi(1, level) - 1) % 20) + 1


static func _enemy_scaled_stat(base_value: int, level: int, multipliers: Dictionary, growth: Dictionary, stat_id: String) -> int:
	var value := (float(base_value) + float(level) * float(growth.get(stat_id, 0.0))) * float(multipliers.get(stat_id, 1.0))
	return maxi(1 if stat_id != "defense" else 0, int(floor(value)))


static func rank_drop_profile(rank_id: String, override_data) -> Dictionary:
	var rank: Dictionary = content_definition("enemy_rank", rank_id, ENEMY_RANK_DEFS.get(rank_id, ENEMY_RANK_DEFS["t1"]))
	var profile := {
		"categories": rank.get("drop_categories", []).duplicate(true),
		"rarity_weights": rank.get("drop_rarity_weights", {}).duplicate(true),
		"base_chance": float(rank.get("base_drop_chance", 0.0)),
		"items": [],
	}
	if override_data is Dictionary:
		for key in ["categories", "rarity_weights", "items"]:
			if override_data.has(key):
				profile[key] = override_data[key].duplicate(true) if override_data[key] is Array or override_data[key] is Dictionary else override_data[key]
		if override_data.has("base_chance"):
			profile["base_chance"] = clampf(float(override_data.get("base_chance", profile["base_chance"])), 0.0, 1.0)
	if profile["items"].is_empty():
		for category in profile["categories"]:
			var drop_table := content_definition("drop_table", "enemy_drop_categories", {"categories": ENEMY_DROP_CATEGORY_ITEMS})
			for item_id in drop_table.get("categories", {}).get(str(category), []):
				if content_has("item", str(item_id), ITEM_DEFS):
					profile["items"].append(item_id)
	return profile


static func resolve_enemy_id(enemy_id: String) -> String:
	if enemy_id.is_empty() or not content_has("enemy", enemy_id, ENEMY_TEMPLATES):
		return DEFAULT_ENEMY_ID
	return enemy_id


static func enemy_scene_path(enemy_id: String) -> String:
	var resolved_enemy_id: String = resolve_enemy_id(enemy_id)
	var definition := content_definition("enemy", resolved_enemy_id, ENEMY_TEMPLATES.get(resolved_enemy_id, {}))
	var registered_path := str(definition.get("scene_path", ""))
	if not registered_path.is_empty():
		return registered_path
	return str(ENEMY_SCENE_PATHS.get(resolved_enemy_id, ENEMY_SCENE_PATHS[DEFAULT_ENEMY_ID]))


static func create_equipment(level: int, rng: RandomNumberGenerator, craft_bonus: int = 0, obtain_source: String = "non_drop", rarity_weights: Dictionary = {}) -> Dictionary:
	var template_ids := content_ids("equipment", EQUIPMENT_DEFS)
	var template_id: String = str(template_ids[rng.randi_range(0, template_ids.size() - 1)])
	var rarity := random_equipment_rarity(rng) if rarity_weights.is_empty() else random_rarity_from_weights(rng, rarity_weights)
	return create_equipment_from_template(template_id, level, rng, craft_bonus, "", rarity, obtain_source)


static func create_equipment_from_template(template_id: String, level: int, rng: RandomNumberGenerator, craft_bonus: int = 0, _name_prefix: String = "", rarity: String = "t1", obtain_source: String = "non_drop") -> Dictionary:
	var template: Dictionary = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {}))
	if template.is_empty():
		return {}
	var rarity_index := maxi(0, EQUIPMENT_RARITY_ORDER.find(rarity))
	if rarity_index < 0:
		rarity_index = 0
	var rarity_name: String = str(EQUIPMENT_RARITY_NAMES.get(rarity, "一阶"))
	var slot := str(template.get("slot", template_id))
	var equipment_name: String = str(template.get("name", slot_name(slot)))
	var equipment_level := maxi(1, level)
	var base_attributes := generate_equipment_base_attributes(rarity, rng)
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
		"attribute_generation_version": 1,
		"description_effects": equipment_template_description_effects(template_id),
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
		"affixes": [],
	}


static func equipment_attribute_point_budget(rarity: String) -> int:
	return int(EQUIPMENT_ATTRIBUTE_POINT_BUDGETS.get(rarity, EQUIPMENT_ATTRIBUTE_POINT_BUDGETS["t1"]))


static func generate_equipment_base_attributes(rarity: String, rng: RandomNumberGenerator) -> Array:
	var attribute_count := rng.randi_range(1, 5)
	var candidates: Array[String] = []
	var attributes: Array = []
	var amount := floori(float(equipment_attribute_point_budget(rarity)) / float(attribute_count))
	for _index in range(attribute_count):
		var pool: Array = EQUIPMENT_NORMAL_ATTRIBUTE_STATS if rng.randf() < 0.5 else EQUIPMENT_ELEMENT_ATTRIBUTE_STATS
		var available: Array[String] = []
		for stat_id in pool:
			if not candidates.has(stat_id):
				available.append(stat_id)
		if available.is_empty():
			for stat_id in EQUIPMENT_NORMAL_ATTRIBUTE_STATS + EQUIPMENT_ELEMENT_ATTRIBUTE_STATS:
				if not candidates.has(stat_id):
					available.append(stat_id)
		var stat_id: String = available[rng.randi_range(0, available.size() - 1)]
		candidates.append(stat_id)
		attributes.append({"stat": stat_id, "amount": amount})
	return attributes


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


static func random_innate_trait_rarity(rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(1, 100)
	if roll <= 70:
		return "common"
	if roll <= 95:
		return "rare"
	return "exceptional"


static func innate_trait_rarity_name(rarity: String) -> String:
	return str(INNATE_TRAIT_RARITY_NAMES.get(rarity, rarity))


static func innate_trait_slot_name(slot: String) -> String:
	return str(INNATE_TRAIT_SLOT_NAMES.get(slot, slot))


static func innate_trait_id(raw_trait) -> String:
	if raw_trait is Dictionary:
		return str(raw_trait.get("id", ""))
	return str(raw_trait)


static func innate_trait_name(raw_trait) -> String:
	var trait_id := innate_trait_id(raw_trait)
	var definition: Dictionary = content_definition("trait", trait_id, INNATE_TRAIT_DEFS.get(trait_id, {}))
	if raw_trait is Dictionary:
		return str(raw_trait.get("name", definition.get("name", trait_id)))
	return str(definition.get("name", trait_id))


static func innate_trait_rarity(raw_trait) -> String:
	return str(raw_trait.get("rarity", "common")) if raw_trait is Dictionary else "common"


static func innate_trait_slot(raw_trait) -> String:
	return str(raw_trait.get("slot", "main")) if raw_trait is Dictionary else "main"


static func innate_trait_description(raw_trait) -> String:
	var definition: Dictionary = content_definition("trait", innate_trait_id(raw_trait), INNATE_TRAIT_DEFS.get(innate_trait_id(raw_trait), {}))
	return str(definition.get("description", "暂无说明"))


static func innate_trait_effect_summary(raw_trait) -> String:
	var definition: Dictionary = content_definition("trait", innate_trait_id(raw_trait), INNATE_TRAIT_DEFS.get(innate_trait_id(raw_trait), {}))
	var effects: Array = []
	if definition.get("effects", []) is Array:
		effects.append_array(definition.get("effects", []))
	if raw_trait is Dictionary and raw_trait.get("effects", []) is Array:
		effects.append_array(raw_trait.get("effects", []))
	var parts: Array[String] = []
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var kind := str(effect.get("kind", ""))
		var amount := float(effect.get("value", effect.get("amount", 0.0)))
		match kind:
			"stat_flat":
				parts.append("%s %+d" % [attribute_display_name(str(effect.get("stat", ""))), int(amount)])
			"element_flat":
				parts.append("%s行 %+d" % [element_name(str(effect.get("element", ""))), int(amount)])
			"alchemy_extra_chance":
				parts.append("炼丹额外成丹概率 %+d%%" % int(round(amount * 100.0)))
			"craft_bonus_flat":
				parts.append("炼器加成 %+d" % int(amount))
			"farm_harvest_bonus_flat":
				parts.append("种田收成 %+d" % int(amount))
			"forge_rarity_upgrade_chance":
				parts.append("炼器升阶概率 %+d%%" % int(round(amount * 100.0)))
	return "；".join(parts) if not parts.is_empty() else "暂无直接效果"


static func innate_trait_compact_summary(raw_trait) -> String:
	return "%s·%s %s" % [
		innate_trait_rarity_name(innate_trait_rarity(raw_trait)),
		innate_trait_slot_name(innate_trait_slot(raw_trait)),
		innate_trait_name(raw_trait),
	]


static func forge_duration_seconds(level: int) -> float:
	return max(300.0, 900.0 - 60.0 * float(maxi(1, level) - 1))


static func alchemy_duration_seconds(level: int, amount: int) -> float:
	return max(180.0, 600.0 - 45.0 * float(maxi(1, level) - 1)) * float(maxi(1, amount))


static func farm_growth_multiplier(level: int) -> float:
	return max(0.55, 1.0 - 0.05 * float(maxi(1, level) - 1))


static func element_name(element_id: String) -> String:
	return ELEMENT_NAMES.get(element_id, element_id)


static func resource_name(resource_id: String) -> String:
	var item: Dictionary = item_definition(resource_id)
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
	return str(item_definition(item_id).get("use_scope", ITEM_USE_SCOPE_NONE))


static func item_use_scope_label(scope: String) -> String:
	match scope:
		ITEM_USE_SCOPE_HOME:
			return "家园"
		ITEM_USE_SCOPE_COMBAT:
			return "战斗"
		_:
			return "无"


static func item_gain_target(item_id: String) -> String:
	return str(item_definition(item_id).get("gain_target", "none"))


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
	return random_rarity_from_weights(rng, EQUIPMENT_RARITY_WEIGHTS)


static func random_rarity_from_weights(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total_weight := 0
	for rarity in EQUIPMENT_RARITY_ORDER:
		total_weight += maxi(0, int(weights.get(rarity, 0)))
	var roll := rng.randi_range(1, maxi(1, total_weight))
	var cursor := 0
	for rarity in EQUIPMENT_RARITY_ORDER:
		cursor += maxi(0, int(weights.get(rarity, 0)))
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
	var definition: Dictionary = item_definition(item_id)
	if str(definition.get("type", "")) != ITEM_TYPE_CROP:
		return false
	var payload: Dictionary = definition.get("payload", {})
	return payload.has("seed_yield")


static func is_farm_speed_item(item_id: String) -> bool:
	return item_id == "farm_speed_talisman"


static func crop_seed_yield(item_id: String) -> int:
	return int(item_definition(item_id).get("payload", {}).get("seed_yield", 1))


static func crop_growth_seconds(item_id: String) -> float:
	return float(item_definition(item_id).get("payload", {}).get("growth_seconds", 60.0))


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


static func equipment_enhance_limit(rarity: String) -> int:
	return int(EQUIPMENT_ENHANCE_LIMITS.get(rarity, EQUIPMENT_ENHANCE_LIMITS["t1"]))


static func equipment_enhance_cost(rarity: String, next_enhance_level: int) -> int:
	var level := clampi(next_enhance_level, 1, equipment_enhance_limit(rarity))
	var base_cost := int(EQUIPMENT_ENHANCE_BASE_COSTS.get(rarity, EQUIPMENT_ENHANCE_BASE_COSTS["t1"]))
	return base_cost + floori(float(level - 1) / 5.0)


static func alchemy_recipe_def(recipe_id: String) -> Dictionary:
	return content_definition("recipe", recipe_id, ALCHEMY_RECIPE_DEFS.get(recipe_id, {}))


static func alchemy_recipe_materials(recipe_id: String) -> Array:
	return content_definition("recipe", recipe_id, ALCHEMY_RECIPE_DEFS.get(recipe_id, {})).get("materials", []).duplicate(true)
