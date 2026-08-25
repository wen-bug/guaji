class_name DataTables
extends Node

const EquipmentConfigParserScript = preload("res://scripts/game/data/equipment_config_parser.gd")
const ItemConfigParserScript = preload("res://scripts/game/data/item_config_parser.gd")
const SkillConfigParserScript = preload("res://scripts/game/data/skill_config_parser.gd")

const ITEM_USE_SCOPE_HOME := "home"
const ITEM_USE_SCOPE_COMBAT := "combat"
const ITEM_USE_SCOPE_BOTH := "both"
const ITEM_USE_SCOPE_NONE := "none"

const ITEM_TYPE_SKILL_BOOK := "skill_book"
const ITEM_TYPE_EQUIPMENT := "equipment"
const ITEM_TYPE_MATERIAL := "material"
const ITEM_TYPE_CROP := "crop"
const ITEM_TYPE_PILL := "pill"
const ITEM_TYPE_ALCHEMY_RECIPE := "alchemy_recipe"
const ITEM_TYPE_BLUEPRINT := "blueprint"

const ITEM_ICON_ROOT := "res://assets/items"
const EQUIPMENT_ICON_ROOT := "res://assets/equipment"
const ITEM_RESOURCE_ROOT := "res://resources/items"
const EQUIPMENT_RESOURCE_ROOT := "res://resources/equipment"
const SKILL_RESOURCE_ROOT := "res://resources/skills"
const ENEMY_RESOURCE_ROOT := "res://resources/enemies"

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
const ITEM_ID_MANUAL_FRAGMENT := "manual_fragment"
const ITEM_ID_SKILL_BOOK_WATER_COLD_TALISMAN := "skill_book_water_cold_talisman"
const ITEM_ID_T1_ATTACK_ENHANCE_PILL := "t1_attack_enhance_pill"
const ITEM_ID_T1_DEFENSE_ENHANCE_PILL := "t1_defense_enhance_pill"
const ITEM_ID_T1_MAX_HP_ENHANCE_PILL := "t1_max_hp_enhance_pill"
const ITEM_ID_T1_MAX_MP_ENHANCE_PILL := "t1_max_mp_enhance_pill"
const ITEM_ID_T1_ROOT_BONE_ENHANCE_PILL := "t1_root_bone_enhance_pill"
const ITEM_ID_T1_WOOD_ENHANCE_PILL := "t1_wood_enhance_pill"
const ITEM_ID_T1_FIRE_ENHANCE_PILL := "t1_fire_enhance_pill"
const ITEM_ID_T1_EARTH_ENHANCE_PILL := "t1_earth_enhance_pill"
const ITEM_ID_T1_METAL_ENHANCE_PILL := "t1_metal_enhance_pill"
const ITEM_ID_T1_WATER_ENHANCE_PILL := "t1_water_enhance_pill"
const ITEM_ID_MARKET_TOKEN := "market_token"
const ITEM_ID_ENHANCEMENT_STONE := "enhancement_stone"
const ITEM_ID_ASCENSION_STONE := "ascension_stone"

const MARKET_REFRESH_SECONDS := 600
const MARKET_OFFER_COUNT := 6
const MARKET_MANUAL_REFRESH_COSTS := [2, 4, 8, 16]
const MARKET_COMMISSION_VALUES := [2, 4, 6]
const MARKET_COMMISSION_REWARDS := [3, 6, 9]

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

const PERMANENT_ATTRIBUTE_ENHANCE_STATS := [
	"attack", "defense", "max_hp", "max_mp", "root_bone",
	"element_wood", "element_fire", "element_earth", "element_metal", "element_water",
]
const PERMANENT_ATTRIBUTE_ENHANCE_TIER_LIMITS := {"t1": 100}
const PERMANENT_ATTRIBUTE_ENHANCE_TIER_NAMES := {"t1": "一阶"}

const ELEMENT_IDS := ["wood", "fire", "earth", "metal", "water"]
const ELEMENT_NAMES := {
	"wood": "木",
	"fire": "火",
	"earth": "土",
	"metal": "金",
	"water": "水",
}
const ELEMENT_ATTRIBUTE_PREFIX := "element_"
const COMBAT_AFFINITY_NORMAL := "normal"
const COMBAT_AFFINITY_IDS := [COMBAT_AFFINITY_NORMAL, "wood", "fire", "earth", "metal", "water"]
const COMBAT_AFFINITY_NAMES := {
	COMBAT_AFFINITY_NORMAL: "普通",
	"wood": "木",
	"fire": "火",
	"earth": "土",
	"metal": "金",
	"water": "水",
}
const COMBAT_AFFINITY_OVERCOMES := {
	"metal": "wood",
	"wood": "earth",
	"earth": "water",
	"water": "fire",
	"fire": "metal",
}
const AFFINITY_RELATION_OVERCOME := "overcome"
const AFFINITY_RELATION_RESTRAINED := "restrained"
const AFFINITY_RELATION_NEUTRAL := "neutral"

const OBTAIN_SOURCE_NAMES := {
	"drop": "掉落",
	"crafted": "打造",
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
const EQUIPMENT_EQUIP_LEVEL_REQUIREMENTS := {
	"t1": 1,
	"t2": 5,
	"t3": 10,
	"t4": 15,
	"t5": 20,
}
const EQUIPMENT_SALVAGE_ORE := {
	"t1": 1,
	"t2": 2,
	"t3": 4,
	"t4": 7,
	"t5": 12,
}
static var EQUIPMENT_RARITY_WEIGHTS: Dictionary = EquipmentConfigParserScript.default_rarity_weights()
const EQUIPMENT_AFFIX_DEFS := {
	"direct_damage_percent": {"name": "直接伤害", "value": 0.05, "format": "percent"},
	"critical_chance": {"name": "暴击率", "value": 0.03, "format": "percent"},
	"leech_percent": {"name": "吸血", "value": 0.02, "format": "percent"},
	"defense_ignore": {"name": "破防", "value": 3, "format": "flat"},
	"direct_damage_reduction": {"name": "直接减伤", "value": 0.02, "format": "percent"},
	"direct_heal_percent": {"name": "直接治疗", "value": 0.05, "format": "percent"},
}
const EQUIPMENT_COMBAT_MODIFIER_CAPS := {
	"critical_chance": 0.30,
	"leech_percent": 0.20,
	"direct_damage_reduction": 0.30,
	"direct_heal_percent": 0.50,
}
const EQUIPMENT_ATTRIBUTE_POINT_BUDGETS := {
	"t1": 20,
	"t2": 50,
	"t3": 100,
	"t4": 180,
	"t5": 300,
}
const EQUIPMENT_ATTRIBUTE_GENERATION_VERSION := 4
const EQUIPMENT_NORMAL_ATTRIBUTE_STATS := ["attack", "defense", "max_hp", "max_mp", "root_bone"]
const EQUIPMENT_ELEMENT_ATTRIBUTE_STATS := ["element_wood", "element_fire", "element_earth", "element_metal", "element_water"]
const EQUIPMENT_ALL_ATTRIBUTE_STATS := EQUIPMENT_NORMAL_ATTRIBUTE_STATS + EQUIPMENT_ELEMENT_ATTRIBUTE_STATS

const ENEMY_RANK_ORDER := ["t1", "t2", "t3", "t4", "t5"]
const ENEMY_CLASS_NORMAL := "normal"
const ENEMY_CLASS_ELITE := "elite"
const ENEMY_CLASS_BOSS := "boss"
const ENEMY_GROWTH_ATTRIBUTE_TARGETS := ["max_hp", "attack", "defense", "element_wood", "element_fire", "element_earth", "element_metal", "element_water"]
const ENEMY_CLASS_ATTRIBUTE_POINT_MULTIPLIERS := {
	ENEMY_CLASS_NORMAL: 0.8,
	ENEMY_CLASS_ELITE: 1.2,
	ENEMY_CLASS_BOSS: 0.0,
}
const ENEMY_CLASS_EQUIPMENT_CHANCES := {
	ENEMY_CLASS_NORMAL: 0.05,
	ENEMY_CLASS_ELITE: 0.12,
	ENEMY_CLASS_BOSS: 0.25,
}
const ENEMY_RANK_DEFS := {
	"t1": {"name": "一阶", "min_level": 1, "max_level": 20, "skill_count": 0, "stat_multipliers": {"max_hp": 1.0, "attack": 1.0, "defense": 1.0}, "level_growth": {"max_hp": 4.0, "attack": 1.0, "defense": 0.33}, "base_drop_chance": 0.55, "drop_categories": ["basic_material"], "drop_rarity_weights": {"t1": 90, "t2": 10, "t3": 0, "t4": 0, "t5": 0}},
	"t2": {"name": "二阶", "min_level": 21, "max_level": 40, "skill_count": 1, "stat_multipliers": {"max_hp": 1.35, "attack": 1.30, "defense": 1.25}, "level_growth": {"max_hp": 5.0, "attack": 1.2, "defense": 0.40}, "base_drop_chance": 0.60, "drop_categories": ["basic_material", "attribute_crop"], "drop_rarity_weights": {"t1": 70, "t2": 25, "t3": 5, "t4": 0, "t5": 0}},
	"t3": {"name": "三阶", "min_level": 41, "max_level": 60, "skill_count": 2, "stat_multipliers": {"max_hp": 1.80, "attack": 1.65, "defense": 1.55}, "level_growth": {"max_hp": 6.0, "attack": 1.4, "defense": 0.50}, "base_drop_chance": 0.65, "drop_categories": ["basic_material", "attribute_crop", "element_stone"], "drop_rarity_weights": {"t1": 55, "t2": 30, "t3": 12, "t4": 3, "t5": 0}},
	"t4": {"name": "四阶", "min_level": 61, "max_level": 80, "skill_count": 3, "stat_multipliers": {"max_hp": 2.35, "attack": 2.10, "defense": 1.95}, "level_growth": {"max_hp": 7.0, "attack": 1.7, "defense": 0.65}, "base_drop_chance": 0.70, "drop_categories": ["basic_material", "attribute_crop", "element_stone", "production_material"], "drop_rarity_weights": {"t1": 40, "t2": 35, "t3": 18, "t4": 6, "t5": 1}},
	"t5": {"name": "五阶", "min_level": 81, "max_level": 0, "skill_count": 4, "stat_multipliers": {"max_hp": 3.00, "attack": 2.65, "defense": 2.45}, "level_growth": {"max_hp": 9.0, "attack": 2.0, "defense": 0.80}, "base_drop_chance": 0.75, "drop_categories": ["basic_material", "attribute_crop", "element_stone", "production_material", "rare_material"], "drop_rarity_weights": {"t1": 25, "t2": 35, "t3": 25, "t4": 12, "t5": 3}},
}

const ENEMY_DROP_CATEGORY_ITEMS := {
	"basic_material": ["herb", "ore", "spirit_stone"],
	"attribute_crop": ["blade_grass", "ironroot", "blood_ginseng", "spirit_lotus", "bone_bamboo", "woodvine", "flame_flower", "earth_moss", "metal_reed", "water_orchid"],
	"element_stone": ["spirit_stone_wood", "spirit_stone_fire", "spirit_stone_earth", "spirit_stone_metal", "spirit_stone_water"],
	"production_material": ["farm_speed_talisman", "refine_talisman"],
	"rare_material": ["pill", "breakthrough_pill"],
}

const ENEMY_CLASS_DROP_PROFILES := {
	ENEMY_CLASS_NORMAL: {
		"mode": "independent",
		"entries": [
			{"item_id": "herb", "chance": 0.55, "amount": 1},
			{"item_id": "ore", "chance": 0.30, "amount": 1},
			{"item_id": "spirit_stone", "chance": 0.10, "amount": 1},
			{"item_id": "blade_grass", "chance": 0.02, "amount": 1},
			{"item_id": "ironroot", "chance": 0.02, "amount": 1},
			{"item_id": "blood_ginseng", "chance": 0.02, "amount": 1},
			{"item_id": "spirit_lotus", "chance": 0.02, "amount": 1},
			{"item_id": "bone_bamboo", "chance": 0.02, "amount": 1},
			{"item_id": "woodvine", "chance": 0.02, "amount": 1},
			{"item_id": "flame_flower", "chance": 0.02, "amount": 1},
			{"item_id": "earth_moss", "chance": 0.02, "amount": 1},
			{"item_id": "metal_reed", "chance": 0.02, "amount": 1},
			{"item_id": "water_orchid", "chance": 0.02, "amount": 1},
		],
	},
	ENEMY_CLASS_ELITE: {
		"mode": "independent",
		"entries": [
			{"item_id": "spirit_stone_wood", "chance": 0.10, "amount": 1},
			{"item_id": "spirit_stone_fire", "chance": 0.10, "amount": 1},
			{"item_id": "spirit_stone_earth", "chance": 0.10, "amount": 1},
			{"item_id": "spirit_stone_metal", "chance": 0.10, "amount": 1},
			{"item_id": "spirit_stone_water", "chance": 0.10, "amount": 1},
			{"item_id": "farm_speed_talisman", "chance": 0.05, "amount": 1},
			{"item_id": "refine_talisman", "chance": 0.05, "amount": 1},
		],
	},
	ENEMY_CLASS_BOSS: {
		"mode": "weighted_one",
		"entries": [
			{"item_id": "pill", "weight": 1, "amount": 1},
			{"item_id": "breakthrough_pill", "weight": 1, "amount": 1},
		],
	},
}

const MARKET_RECYCLE_DEFS := {
	"herb": {"amount": 10, "tokens": 1},
	"ore": {"amount": 8, "tokens": 1},
	"blade_grass": {"amount": 5, "tokens": 1},
	"ironroot": {"amount": 5, "tokens": 1},
	"blood_ginseng": {"amount": 5, "tokens": 1},
	"spirit_lotus": {"amount": 5, "tokens": 1},
	"bone_bamboo": {"amount": 5, "tokens": 1},
	"woodvine": {"amount": 5, "tokens": 1},
	"flame_flower": {"amount": 5, "tokens": 1},
	"earth_moss": {"amount": 5, "tokens": 1},
	"metal_reed": {"amount": 5, "tokens": 1},
	"water_orchid": {"amount": 5, "tokens": 1},
	"spirit_stone": {"amount": 3, "tokens": 1},
	"spirit_stone_wood": {"amount": 2, "tokens": 1},
	"spirit_stone_fire": {"amount": 2, "tokens": 1},
	"spirit_stone_earth": {"amount": 2, "tokens": 1},
	"spirit_stone_metal": {"amount": 2, "tokens": 1},
	"spirit_stone_water": {"amount": 2, "tokens": 1},
	"farm_speed_talisman": {"amount": 1, "tokens": 2},
	"refine_talisman": {"amount": 1, "tokens": 2},
	"manual_fragment": {"amount": 2, "tokens": 1},
	"pill": {"amount": 5, "tokens": 1},
	"life_pill": {"amount": 5, "tokens": 1},
	"spirit_pill": {"amount": 5, "tokens": 1},
	"attack_pill": {"amount": 5, "tokens": 1},
	"defense_pill": {"amount": 5, "tokens": 1},
	"wood_pill": {"amount": 5, "tokens": 1},
	"fire_pill": {"amount": 5, "tokens": 1},
	"earth_pill": {"amount": 5, "tokens": 1},
	"metal_pill": {"amount": 5, "tokens": 1},
	"water_pill": {"amount": 5, "tokens": 1},
	"breakthrough_pill": {"amount": 3, "tokens": 1},
	"recipe_pill": {"amount": 1, "tokens": 2, "valuable": true},
	"skill_book_thunder": {"amount": 1, "tokens": 2, "valuable": true},
	"skill_book_poison": {"amount": 1, "tokens": 2, "valuable": true},
	"skill_book_heal": {"amount": 1, "tokens": 2, "valuable": true},
	"skill_book_attack_up": {"amount": 1, "tokens": 2, "valuable": true},
	"skill_book_spirit_shield": {"amount": 1, "tokens": 2, "valuable": true},
	"skill_book_water_cold_talisman": {"amount": 1, "tokens": 2, "valuable": true},
	"t1_attack_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_defense_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_max_hp_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_max_mp_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_root_bone_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_wood_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_fire_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_earth_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_metal_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
	"t1_water_enhance_pill": {"amount": 2, "tokens": 1, "valuable": true},
}

const MARKET_GOODS_POOLS := {
	"basic": {"weight": 40, "entries": [
		{"item_id": "herb", "amount": 8, "price": 2},
		{"item_id": "ore", "amount": 6, "price": 2},
		{"item_id": "blade_grass", "amount": 4, "price": 2},
		{"item_id": "ironroot", "amount": 4, "price": 2},
		{"item_id": "blood_ginseng", "amount": 4, "price": 2},
		{"item_id": "spirit_lotus", "amount": 4, "price": 2},
		{"item_id": "bone_bamboo", "amount": 4, "price": 2},
		{"item_id": "woodvine", "amount": 4, "price": 2},
		{"item_id": "flame_flower", "amount": 4, "price": 2},
		{"item_id": "earth_moss", "amount": 4, "price": 2},
		{"item_id": "metal_reed", "amount": 4, "price": 2},
		{"item_id": "water_orchid", "amount": 4, "price": 2},
	]},
	"production": {"weight": 25, "entries": [
		{"item_id": "spirit_stone", "amount": 2, "price": 4},
		{"item_id": "spirit_stone_wood", "amount": 1, "price": 3},
		{"item_id": "spirit_stone_fire", "amount": 1, "price": 3},
		{"item_id": "spirit_stone_earth", "amount": 1, "price": 3},
		{"item_id": "spirit_stone_metal", "amount": 1, "price": 3},
		{"item_id": "spirit_stone_water", "amount": 1, "price": 3},
		{"item_id": "farm_speed_talisman", "amount": 1, "price": 6},
		{"item_id": "refine_talisman", "amount": 1, "price": 6},
		{"item_id": "manual_fragment", "amount": 1, "price": 4},
	]},
	"pill": {"weight": 20, "entries": [
		{"item_id": "pill", "amount": 1, "price": 4, "recipe_id": "pill"},
		{"item_id": "breakthrough_pill", "amount": 1, "price": 8, "recipe_id": "breakthrough_pill"},
		{"item_id": "life_pill", "amount": 1, "price": 4, "recipe_id": "life_pill"},
		{"item_id": "spirit_pill", "amount": 1, "price": 4, "recipe_id": "spirit_pill"},
		{"item_id": "attack_pill", "amount": 1, "price": 4, "recipe_id": "attack_pill"},
		{"item_id": "defense_pill", "amount": 1, "price": 4, "recipe_id": "defense_pill"},
		{"item_id": "wood_pill", "amount": 1, "price": 4, "recipe_id": "wood_pill"},
		{"item_id": "fire_pill", "amount": 1, "price": 4, "recipe_id": "fire_pill"},
		{"item_id": "earth_pill", "amount": 1, "price": 4, "recipe_id": "earth_pill"},
		{"item_id": "metal_pill", "amount": 1, "price": 4, "recipe_id": "metal_pill"},
		{"item_id": "water_pill", "amount": 1, "price": 4, "recipe_id": "water_pill"},
	]},
	"knowledge": {"weight": 10, "entries": [
		{"item_id": "recipe_pill", "amount": 1, "price": 16},
	]},
	"rare": {"weight": 5, "entries": [
		{"item_id": "skill_book_thunder", "amount": 1, "price": 32, "min_expedition_level": 6},
		{"item_id": "skill_book_poison", "amount": 1, "price": 32, "min_expedition_level": 6},
		{"item_id": "skill_book_heal", "amount": 1, "price": 32, "min_expedition_level": 6},
		{"item_id": "skill_book_attack_up", "amount": 1, "price": 32, "min_expedition_level": 6},
		{"item_id": "skill_book_spirit_shield", "amount": 1, "price": 32, "min_expedition_level": 6},
		{"item_id": "skill_book_water_cold_talisman", "amount": 1, "price": 32, "min_expedition_level": 6},
		{"item_id": "t1_attack_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 6},
		{"item_id": "t1_defense_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 6},
		{"item_id": "t1_max_hp_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 6},
		{"item_id": "t1_max_mp_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 6},
		{"item_id": "t1_root_bone_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 6},
		{"item_id": "t1_wood_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 7},
		{"item_id": "t1_fire_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 7},
		{"item_id": "t1_earth_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 7},
		{"item_id": "t1_metal_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 7},
		{"item_id": "t1_water_enhance_pill", "amount": 1, "price": 24, "min_alchemy_level": 7},
	]},
}

const MARKET_COMMISSION_ITEM_IDS := [
	"herb", "ore", "blade_grass", "ironroot", "blood_ginseng", "spirit_lotus", "bone_bamboo",
	"woodvine", "flame_flower", "earth_moss", "metal_reed", "water_orchid", "spirit_stone",
	"spirit_stone_wood", "spirit_stone_fire", "spirit_stone_earth", "spirit_stone_metal",
	"spirit_stone_water", "farm_speed_talisman", "refine_talisman", "manual_fragment", "pill",
	"life_pill", "spirit_pill", "attack_pill", "defense_pill", "wood_pill", "fire_pill",
	"earth_pill", "metal_pill", "water_pill", "breakthrough_pill",
]

static var ITEM_DEFS: Dictionary = ItemConfigParserScript.definitions()
static var SKILL_DEFS: Dictionary = SkillConfigParserScript.definitions()
static var BASIC_ATTACK_DEFS: Dictionary = SkillConfigParserScript.basic_attack_definitions()
static var SKILL_EXCHANGE_DEFS: Dictionary = SkillConfigParserScript.exchange_definitions()


static func reload_item_skill_configs() -> Array[String]:
	ItemConfigParserScript.clear_cache()
	SkillConfigParserScript.clear_cache()
	ITEM_DEFS = ItemConfigParserScript.definitions()
	SKILL_DEFS = SkillConfigParserScript.definitions()
	BASIC_ATTACK_DEFS = SkillConfigParserScript.basic_attack_definitions()
	SKILL_EXCHANGE_DEFS = SkillConfigParserScript.exchange_definitions()
	var errors: Array[String] = ItemConfigParserScript.validation_errors()
	errors.append_array(SkillConfigParserScript.validation_errors())
	return errors

const ALCHEMY_RECIPE_DEFS := {
	"pill": {"result_item_id": "pill", "unlock_building_level": 1, "materials": [{"item_id": "herb", "amount": 2}]},
	"breakthrough_pill": {"result_item_id": "breakthrough_pill", "unlock_building_level": 2, "materials": [{"item_id": "pill", "amount": 1}, {"item_id": "herb", "amount": 8}]},
	"life_pill": {"result_item_id": "life_pill", "unlock_building_level": 3, "materials": [{"item_id": "blood_ginseng", "amount": 2}, {"item_id": "herb", "amount": 4}]},
	"spirit_pill": {"result_item_id": "spirit_pill", "unlock_building_level": 3, "materials": [{"item_id": "spirit_lotus", "amount": 2}, {"item_id": "herb", "amount": 4}]},
	"attack_pill": {"result_item_id": "attack_pill", "unlock_building_level": 4, "materials": [{"item_id": "blade_grass", "amount": 2}, {"item_id": "herb", "amount": 5}]},
	"defense_pill": {"result_item_id": "defense_pill", "unlock_building_level": 4, "materials": [{"item_id": "ironroot", "amount": 2}, {"item_id": "herb", "amount": 5}]},
	"wood_pill": {"result_item_id": "wood_pill", "unlock_building_level": 5, "materials": [{"item_id": "woodvine", "amount": 2}, {"item_id": "herb", "amount": 6}]},
	"fire_pill": {"result_item_id": "fire_pill", "unlock_building_level": 5, "materials": [{"item_id": "flame_flower", "amount": 2}, {"item_id": "herb", "amount": 6}]},
	"earth_pill": {"result_item_id": "earth_pill", "unlock_building_level": 5, "materials": [{"item_id": "earth_moss", "amount": 2}, {"item_id": "herb", "amount": 6}]},
	"metal_pill": {"result_item_id": "metal_pill", "unlock_building_level": 5, "materials": [{"item_id": "metal_reed", "amount": 2}, {"item_id": "herb", "amount": 6}]},
	"water_pill": {"result_item_id": "water_pill", "unlock_building_level": 5, "materials": [{"item_id": "water_orchid", "amount": 2}, {"item_id": "herb", "amount": 6}]},
	"t1_attack_enhance_pill": {"result_item_id": "t1_attack_enhance_pill", "unlock_building_level": 6, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "blade_grass", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone", "amount": 2}]},
	"t1_defense_enhance_pill": {"result_item_id": "t1_defense_enhance_pill", "unlock_building_level": 6, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "ironroot", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone", "amount": 2}]},
	"t1_max_hp_enhance_pill": {"result_item_id": "t1_max_hp_enhance_pill", "unlock_building_level": 6, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "blood_ginseng", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone", "amount": 2}]},
	"t1_max_mp_enhance_pill": {"result_item_id": "t1_max_mp_enhance_pill", "unlock_building_level": 6, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "spirit_lotus", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone", "amount": 2}]},
	"t1_root_bone_enhance_pill": {"result_item_id": "t1_root_bone_enhance_pill", "unlock_building_level": 6, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "bone_bamboo", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone", "amount": 2}]},
	"t1_wood_enhance_pill": {"result_item_id": "t1_wood_enhance_pill", "unlock_building_level": 7, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "woodvine", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone_wood", "amount": 2}]},
	"t1_fire_enhance_pill": {"result_item_id": "t1_fire_enhance_pill", "unlock_building_level": 7, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "flame_flower", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone_fire", "amount": 2}]},
	"t1_earth_enhance_pill": {"result_item_id": "t1_earth_enhance_pill", "unlock_building_level": 7, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "earth_moss", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone_earth", "amount": 2}]},
	"t1_metal_enhance_pill": {"result_item_id": "t1_metal_enhance_pill", "unlock_building_level": 7, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "metal_reed", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone_metal", "amount": 2}]},
	"t1_water_enhance_pill": {"result_item_id": "t1_water_enhance_pill", "unlock_building_level": 7, "allow_output_multiplier": false, "allow_bonus_output": false, "materials": [{"item_id": "water_orchid", "amount": 3}, {"item_id": "herb", "amount": 8}, {"item_id": "spirit_stone_water", "amount": 2}]},
}

static var EQUIPMENT_DEFS: Dictionary = EquipmentConfigParserScript.template_definitions()
static var LEGACY_EQUIPMENT_VARIANT_ALIASES: Dictionary = EquipmentConfigParserScript.legacy_aliases()


static func reload_equipment_configs() -> Array[String]:
	EquipmentConfigParserScript.clear_cache()
	EQUIPMENT_RARITY_WEIGHTS = EquipmentConfigParserScript.default_rarity_weights()
	EQUIPMENT_DEFS = EquipmentConfigParserScript.template_definitions()
	LEGACY_EQUIPMENT_VARIANT_ALIASES = EquipmentConfigParserScript.legacy_aliases()
	return EquipmentConfigParserScript.validation_errors()


static func _is_indexed_core_equipment_reference(template_id: String) -> bool:
	var index := EquipmentConfigParserScript.index_data()
	var paths = index.get("equipment_paths", {})
	var aliases = index.get("aliases", {})
	return (
		EquipmentConfigParserScript.slot_ids().has(template_id)
		or (paths is Dictionary and paths.has(template_id))
		or (aliases is Dictionary and aliases.has(template_id))
	)

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
		"description": "根骨良好，成长潜力更高。",
		"effects": [
			{"kind": "stat_flat", "stat": "root_bone", "amount": 2},
		],
	},
}

const ENEMY_TEMPLATES := {
	"training_dummy": {"id": "training_dummy", "visual_id": "training_dummy", "name": "木桩", "encounter_class": "normal", "enemy_class": ENEMY_CLASS_NORMAL, "level_offset": 0, "max_hp": 40, "attack": 3, "defense": 0, "move_speed": 48.0, "player_move_speed": 96.0, "attack_range": 72.0, "player_attack_range": 96.0, "spawn_delay": 0.4, "turn_wait": 1.8, "element": "wood", "combat_affinity": "normal", "attribute_point_multiplier": 0.0, "growth_primary_stat": "max_hp", "growth_secondary_stats": ["attack", "defense"], "skills": [], "drop_profile": {"base_chance": 0.0, "items": []}, "equipment_drop_chance": 0.0, "exp": 6, "use_drop": false, "is_training_dummy": true},
	"forest_wolf": {"id": "forest_wolf", "visual_id": "forest_wolf", "name": "林狼", "encounter_class": "normal", "enemy_class": ENEMY_CLASS_NORMAL, "level_offset": 0, "max_hp": 32, "attack": 6, "defense": 1, "move_speed": 120.0, "player_move_speed": 120.0, "attack_range": 88.0, "player_attack_range": 96.0, "spawn_delay": 0.6, "turn_wait": 1.4, "element": "wood", "element_power": 3, "skills": ["wolf_bite", "wolf_bleed", "wolf_howl", "wolf_pounce"], "skill_unlock_rank": "t2", "use_class_drop_pool": true, "use_rank_drop_pool": false, "equipment_drop_chance": 0.05, "exp": 10, "use_drop": true, "is_training_dummy": false},
	"venom_spider": {"id": "venom_spider", "visual_id": "spider", "name": "毒纹蛛", "encounter_class": "normal", "enemy_class": ENEMY_CLASS_NORMAL, "max_hp": 26, "attack": 7, "defense": 1, "element": "wood", "element_power": 4, "skills": ["poison"], "skill_unlock_rank": "t2", "use_class_drop_pool": true, "use_rank_drop_pool": false, "exp": 11, "use_drop": true},
	"blight_shaman": {"id": "blight_shaman", "visual_id": "shaman", "name": "腐木巫祝", "encounter_class": "elite", "enemy_class": ENEMY_CLASS_ELITE, "reference_stat_multipliers": {"max_hp": 1.6, "attack": 1.35, "defense": 1.3}, "experience_multiplier": 1.8, "drop_chance_bonus": 0.15, "max_hp": 35, "attack": 8, "defense": 2, "element": "wood", "element_power": 6, "skills": ["poison", "heal"], "skill_unlock_rank": "t1", "use_class_drop_pool": true, "use_rank_drop_pool": false, "exp": 18, "use_drop": true},
	"ember_gnome": {"id": "ember_gnome", "visual_id": "gnome", "name": "灰烬地精", "encounter_class": "normal", "enemy_class": ENEMY_CLASS_NORMAL, "max_hp": 34, "attack": 9, "defense": 2, "element": "fire", "element_power": 5, "skills": ["attack_up"], "skill_unlock_rank": "t2", "use_class_drop_pool": true, "use_rank_drop_pool": false, "exp": 13, "use_drop": true},
	"stone_lizard": {"id": "stone_lizard", "visual_id": "lizard", "name": "岩甲蜥", "encounter_class": "normal", "enemy_class": ENEMY_CLASS_NORMAL, "max_hp": 44, "attack": 8, "defense": 4, "element": "earth", "element_power": 6, "skills": ["spirit_shield"], "skill_unlock_rank": "t2", "use_class_drop_pool": true, "use_rank_drop_pool": false, "exp": 15, "use_drop": true},
	"stone_overlord": {"id": "stone_overlord", "visual_id": "minotaur", "name": "镇岳兽王", "encounter_class": "elite", "enemy_class": ENEMY_CLASS_ELITE, "reference_stat_multipliers": {"max_hp": 1.6, "attack": 1.35, "defense": 1.3}, "experience_multiplier": 1.8, "drop_chance_bonus": 0.15, "max_hp": 52, "attack": 11, "defense": 5, "element": "earth", "element_power": 8, "skills": ["wolf_pounce", "wolf_howl"], "skill_unlock_rank": "t1", "use_class_drop_pool": true, "use_rank_drop_pool": false, "exp": 24, "use_drop": true},
	"iron_lancer": {"id": "iron_lancer", "visual_id": "lancer", "name": "玄锋枪卒", "encounter_class": "normal", "enemy_class": ENEMY_CLASS_NORMAL, "max_hp": 48, "attack": 12, "defense": 4, "element": "metal", "element_power": 8, "skills": ["thunder"], "skill_unlock_rank": "t2", "use_class_drop_pool": true, "use_rank_drop_pool": false, "exp": 18, "use_drop": true},
	"tide_fish": {"id": "tide_fish", "visual_id": "paddle_fish", "name": "潮鳍鱼妖", "encounter_class": "normal", "enemy_class": ENEMY_CLASS_NORMAL, "max_hp": 54, "attack": 13, "defense": 5, "element": "water", "element_power": 9, "skills": ["water_cold_talisman"], "skill_unlock_rank": "t2", "use_class_drop_pool": true, "use_rank_drop_pool": false, "exp": 20, "use_drop": true},
	"abyssal_turtle": {"id": "abyssal_turtle", "visual_id": "turtle", "name": "沉渊玄龟", "encounter_class": "boss", "enemy_class": ENEMY_CLASS_BOSS, "reference_stat_multipliers": {"max_hp": 3.0, "attack": 1.8, "defense": 1.8}, "experience_multiplier": 5.0, "max_hp": 90, "attack": 16, "defense": 8, "element": "water", "element_power": 14, "combat_affinity": "water", "attribute_point_multiplier": 1.5, "growth_primary_stat": "max_hp", "growth_secondary_stats": ["defense", "element_water"], "skills": ["spirit_shield", "water_cold_talisman"], "skill_unlock_rank": "t1", "use_class_drop_pool": true, "use_rank_drop_pool": false, "equipment_drop_chance": 0.25, "exp": 50, "use_drop": true},
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


static func blueprint_item_id(template_id: String) -> String:
	return "blueprint_%s" % template_id


static func blueprint_template_id(item_id: String) -> String:
	var definition: Dictionary = item_definition(item_id)
	if str(definition.get("type", "")) != ITEM_TYPE_BLUEPRINT:
		return ""
	return str(definition.get("payload", {}).get("equipment_template_id", ""))


static func equipment_icon_name(template_id: String, variant_id: String = "") -> String:
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	var core_definition := EquipmentConfigParserScript.equipment_definition(equipment_id)
	if not core_definition.is_empty():
		return str(core_definition.get("icon_name", equipment_id))
	var definition: Dictionary = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {}))
	return str(definition.get("icon_name", template_id))


static func equipment_icon_path(template_id: String, variant_id: String = "") -> String:
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	var core_definition := EquipmentConfigParserScript.equipment_definition(equipment_id)
	if not core_definition.is_empty():
		return str(core_definition.get("icon_path", ""))
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
	var core_path := ItemConfigParserScript.resource_path(item_id)
	if not core_path.is_empty():
		return core_path
	return "%s/%s.tres" % [ITEM_RESOURCE_ROOT, item_id]


static func equipment_resource_path(template_id: String, variant_id: String = "") -> String:
	if template_id.is_empty():
		return ""
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	var core_path := EquipmentConfigParserScript.resource_path(equipment_id)
	if not core_path.is_empty():
		return core_path
	return "%s/%s.tres" % [EQUIPMENT_RESOURCE_ROOT, template_id]


static func skill_resource_path(skill_id: String) -> String:
	if skill_id.is_empty():
		return ""
	var core_path := SkillConfigParserScript.resource_path(skill_id)
	if not core_path.is_empty():
		return core_path
	return "%s/%s.tres" % [SKILL_RESOURCE_ROOT, skill_id]


static func enemy_resource_path(enemy_id: String) -> String:
	if enemy_id.is_empty():
		return ""
	return "%s/%s.tres" % [ENEMY_RESOURCE_ROOT, enemy_id]


static func item_resource(item_id: String) -> Resource:
	return _load_resource(item_resource_path(item_id))


static func equipment_resource(template_id: String, variant_id: String = "") -> Resource:
	return _load_resource(equipment_resource_path(template_id, variant_id))


static func skill_resource(skill_id: String) -> Resource:
	return _load_resource(skill_resource_path(skill_id))


static func enemy_resource(enemy_id: String) -> Resource:
	return _load_resource(enemy_resource_path(enemy_id))


static func item_icon_texture(item_id: String) -> Texture2D:
	return _icon_texture_from_resource(item_resource_path(item_id))


static func equipment_icon_texture(template_id: String, variant_id: String = "") -> Texture2D:
	return _icon_texture_from_resource(equipment_resource_path(template_id, variant_id))


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


static func equipment_template_description(template_id: String, variant_id: String = "") -> String:
	var core_definition := EquipmentConfigParserScript.equipment_definition(EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id))
	if not core_definition.is_empty():
		return str(core_definition.get("description", ""))
	var resource: Resource = equipment_resource(template_id)
	var description: String = _resource_string(resource, "description", "")
	if not description.is_empty():
		return description
	return str(content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {})).get("description", ""))


static func equipment_template_description_effects(template_id: String, variant_id: String = "") -> Array:
	var core_definition := EquipmentConfigParserScript.equipment_definition(EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id))
	if not core_definition.is_empty():
		var core_effects = core_definition.get("description_effects", [])
		return core_effects.duplicate(true) if core_effects is Array else []
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
		var template_description: String = equipment_template_description(item_id, str(item.get("equipment_variant_id", "")))
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
	var icon_path := str(item.get("icon_path", "")) if item_type == ITEM_TYPE_EQUIPMENT else _resource_string(resource, "icon_path", "")
	if icon_path.is_empty():
		icon_path = _resource_string(resource, "icon_path", "")
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
		"use_context": str(definition.get("use_context", definition.get("use_scope", ITEM_USE_SCOPE_NONE))),
		"effects": definition.get("effects", []).duplicate(true),
		"combat_cooldown_turns": int(definition.get("combat_cooldown_turns", 0)),
		"shared_cooldown_group": str(definition.get("shared_cooldown_group", "")),
		"ai_action_type": str(definition.get("ai_action_type", "")),
		"payload": definition.get("payload", {}).duplicate(true),
		"obtain_source": "non_drop",
		"gain_target": definition.get("gain_target", "none"),
		"item_no": item_no(item_id),
		"icon_name": item_icon_name(item_id),
		"icon_path": item_icon_path(item_id),
		"resource_path": item_resource_path(item_id),
	}


static func create_skill(skill_id: String, obtain_source: String = "non_drop") -> Dictionary:
	var definition: Dictionary = content_definition("skill", skill_id, core_skill_definition(skill_id))
	if definition.is_empty():
		return {}
	var skill: Dictionary = normalize_skill_definition(definition)
	skill["obtain_source"] = obtain_source
	if not bool(skill.get("enemy_only", false)):
		skill["locked"] = true
		skill["replaceable"] = false
	return skill


static func core_skill_definition(skill_id: String) -> Dictionary:
	var definition: Dictionary = SKILL_DEFS.get(skill_id, {}).duplicate(true)
	var resource: Resource = skill_resource(skill_id)
	if resource != null and resource.has_method("to_dictionary"):
		var authored = resource.call("to_dictionary")
		if authored is Dictionary and not authored.is_empty():
			definition.merge(authored, true)
	return definition


static func all_core_skill_definitions() -> Dictionary:
	var result: Dictionary = {}
	for skill_id in SKILL_DEFS.keys():
		result[str(skill_id)] = core_skill_definition(str(skill_id))
	return result


static func core_enemy_definition(enemy_id: String) -> Dictionary:
	var definition: Dictionary = ENEMY_TEMPLATES.get(enemy_id, {}).duplicate(true)
	var resource: Resource = enemy_resource(enemy_id)
	if resource != null and resource.has_method("to_dictionary"):
		var authored = resource.call("to_dictionary")
		if authored is Dictionary and not authored.is_empty():
			definition.merge(authored, true)
	return definition


static func all_core_enemy_definitions() -> Dictionary:
	var result: Dictionary = {}
	for enemy_id in ENEMY_TEMPLATES.keys():
		result[str(enemy_id)] = core_enemy_definition(str(enemy_id))
	return result


static func create_basic_attack(attack_mode: String, base_damage: int = 0) -> Dictionary:
	var resolved_mode: String = attack_mode if ATTACK_MODES.has(attack_mode) else ATTACK_MODE_MELEE
	var attack: Dictionary = normalize_skill_definition(content_definition("basic_attack", resolved_mode, BASIC_ATTACK_DEFS[resolved_mode]))
	attack["type"] = "normal_attack"
	var effects: Array = attack.get("effects", []).duplicate(true)
	if not effects.is_empty() and effects[0] is Dictionary:
		effects[0]["base_amount"] = maxi(0, base_damage)
	attack["effects"] = effects
	attack["damage_marker"] = "impact"
	return attack


static func normalize_combat_affinity(value: String) -> String:
	return value if COMBAT_AFFINITY_IDS.has(value) else COMBAT_AFFINITY_NORMAL


static func combat_affinity_name(value: String) -> String:
	var affinity := normalize_combat_affinity(value)
	return str(COMBAT_AFFINITY_NAMES.get(affinity, affinity))


static func combat_affinity_relation(attacker_affinity: String, target_affinity: String) -> String:
	var attacker := normalize_combat_affinity(attacker_affinity)
	var target := normalize_combat_affinity(target_affinity)
	if attacker == COMBAT_AFFINITY_NORMAL or target == COMBAT_AFFINITY_NORMAL:
		return AFFINITY_RELATION_NEUTRAL
	if str(COMBAT_AFFINITY_OVERCOMES.get(attacker, "")) == target:
		return AFFINITY_RELATION_OVERCOME
	if str(COMBAT_AFFINITY_OVERCOMES.get(target, "")) == attacker:
		return AFFINITY_RELATION_RESTRAINED
	return AFFINITY_RELATION_NEUTRAL


static func combat_affinity_multiplier(relation: String) -> float:
	match relation:
		AFFINITY_RELATION_OVERCOME:
			return 1.25
		AFFINITY_RELATION_RESTRAINED:
			return 0.75
		_:
			return 1.0


static func apply_combat_affinity_multiplier(amount: int, relation: String) -> int:
	if amount <= 0:
		return 0
	return maxi(1, roundi(float(amount) * combat_affinity_multiplier(relation)))


static func normalize_skill_definition(definition: Dictionary) -> Dictionary:
	var skill: Dictionary = definition.duplicate(true)
	var scope: String = str(skill.get("target_scope", ""))
	if not SKILL_TARGET_SCOPES.has(scope):
		scope = _default_skill_target_scope(str(skill.get("type", "")))
	skill["target_scope"] = scope
	skill["target_mode"] = SKILL_TARGET_MODE_AOE if scope in [SKILL_TARGET_ALL_ALLIES, SKILL_TARGET_ALL_ENEMIES] else SKILL_TARGET_MODE_SINGLE
	skill.erase("release_distance")
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
		var kind: String = str(raw_effect.get("status_kind", raw_effect.get("kind", "")))
		if str(raw_effect.get("kind", "")) == "damage" and not tags.has("damage"):
			tags.append("damage")
		if str(raw_effect.get("kind", "")) == "heal" and not tags.has("heal"):
			tags.append("heal")
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
	var is_core_enemy := ENEMY_TEMPLATES.has(resolved_enemy_id)
	var template: Dictionary = content_definition("enemy", resolved_enemy_id, core_enemy_definition(resolved_enemy_id))
	var enemy_level: int = maxi(1, level + int(template.get("level_offset", 0)))
	var rank_id := enemy_rank_for_level(enemy_level)
	var rank: Dictionary = content_definition("enemy_rank", rank_id, ENEMY_RANK_DEFS[rank_id])
	var rank_level: int = enemy_rank_level(enemy_level)
	var multipliers: Dictionary = rank.get("stat_multipliers", {})
	var growth: Dictionary = rank.get("level_growth", {})
	var reference_multipliers: Dictionary = template.get("reference_stat_multipliers", {})
	var max_hp: int = maxi(1, roundi(float(_enemy_scaled_stat(int(template.get("max_hp", 1)), enemy_level, multipliers, growth, "max_hp")) * float(reference_multipliers.get("max_hp", 1.0))))
	var attack: int = maxi(1, roundi(float(_enemy_scaled_stat(int(template.get("attack", 1)), enemy_level, multipliers, growth, "attack")) * float(reference_multipliers.get("attack", 1.0))))
	var defense: int = maxi(0, roundi(float(_enemy_scaled_stat(int(template.get("defense", 0)), enemy_level, multipliers, growth, "defense")) * float(reference_multipliers.get("defense", 1.0))))
	var element_id := str(template.get("element", ""))
	var element_power := maxi(0, int(template.get("element_power", 0)) + int(float(rank_level) / 5.0))
	var elements: Dictionary = {element_id: element_power} if not element_id.is_empty() else {}
	var skills: Array = template.get("skills", []).duplicate(true) if template.get("skills", []) is Array else []
	var skill_limit := int(rank.get("skill_count", 0))
	while skills.size() > skill_limit:
		skills.pop_back()
	var drop_profile: Dictionary = rank_drop_profile(rank_id, template.get("drop_profile", {}))
	var enemy_class: String = str(template.get("enemy_class", ENEMY_CLASS_NORMAL))
	var combat_affinity := COMBAT_AFFINITY_NORMAL
	var growth_primary_stat := ""
	var growth_secondary_stats: Array[String] = []
	var attribute_point_multiplier := 0.0
	var attribute_point_budget := 0
	if is_core_enemy:
		combat_affinity = normalize_combat_affinity(str(template.get("combat_affinity", ""))) if template.has("combat_affinity") else _random_combat_affinity(rng)
		attribute_point_multiplier = maxf(0.0, float(template.get("attribute_point_multiplier", ENEMY_CLASS_ATTRIBUTE_POINT_MULTIPLIERS.get(enemy_class, 0.0))))
		growth_primary_stat = str(template.get("growth_primary_stat", ""))
		for value in template.get("growth_secondary_stats", []):
			var stat_id := str(value)
			if ENEMY_GROWTH_ATTRIBUTE_TARGETS.has(stat_id) and stat_id != growth_primary_stat and not growth_secondary_stats.has(stat_id):
				growth_secondary_stats.append(stat_id)
		var available_growth_stats: Array[String] = []
		for value in ENEMY_GROWTH_ATTRIBUTE_TARGETS:
			var stat_id := str(value)
			if stat_id != growth_primary_stat and not growth_secondary_stats.has(stat_id):
				available_growth_stats.append(stat_id)
		if not ENEMY_GROWTH_ATTRIBUTE_TARGETS.has(growth_primary_stat):
			growth_primary_stat = _take_random_string(available_growth_stats, rng)
		while growth_secondary_stats.size() < 2 and not available_growth_stats.is_empty():
			growth_secondary_stats.append(_take_random_string(available_growth_stats, rng))
		attribute_point_budget = floori(float(maxi(0, enemy_level - 1) * 5) * attribute_point_multiplier)
		for _point_index in range(attribute_point_budget):
			var target_stat := _weighted_growth_target(growth_primary_stat, growth_secondary_stats, ENEMY_GROWTH_ATTRIBUTE_TARGETS, rng)
			if target_stat == "max_hp":
				max_hp += 4
			elif target_stat == "attack":
				attack += 1
			elif target_stat == "defense":
				defense += 1
			elif target_stat.begins_with(ELEMENT_ATTRIBUTE_PREFIX):
				var growth_element := element_id_from_attribute(target_stat)
				elements[growth_element] = int(elements.get(growth_element, 0)) + 1
	var drop_chance_bonus: float = float(template.get("drop_chance_bonus", 0.15 if enemy_class == ENEMY_CLASS_ELITE else 0.0))
	if drop_chance_bonus > 0.0:
		drop_profile["base_chance"] = clampf(float(drop_profile.get("base_chance", 0.0)) + drop_chance_bonus, 0.0, 1.0)
	var use_class_drop_pool: bool = bool(template.get("use_class_drop_pool", false))
	var class_drop_profile: Dictionary = enemy_class_drop_profile(enemy_class) if use_class_drop_pool else {}
	var use_rank_drop_pool: bool = bool(template.get("use_rank_drop_pool", not bool(template.get("is_training_dummy", false))))
	var equipment_drop_chance: float = clampf(float(template.get("equipment_drop_chance", ENEMY_CLASS_EQUIPMENT_CHANCES.get(enemy_class, 0.05))), 0.0, 1.0)
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
		"enemy_class": enemy_class,
		"encounter_class": str(template.get("encounter_class", enemy_class)),
		"reference_stat_multipliers": reference_multipliers.duplicate(true),
		"experience_multiplier": float(template.get("experience_multiplier", 1.0)),
		"drop_chance_bonus": drop_chance_bonus,
		"skill_unlock_rank": str(template.get("skill_unlock_rank", "t2")),
		"move_speed": float(template.get("move_speed", 120.0)),
		"player_move_speed": float(template.get("player_move_speed", 120.0)),
		"attack_range": float(template.get("attack_range", 88.0)),
		"player_attack_range": float(template.get("player_attack_range", 96.0)),
		"spawn_delay": float(template.get("spawn_delay", 0.6)),
		"turn_wait": float(template.get("turn_wait", 1.4)),
		"element": element_id,
		"elements": elements,
		"combat_affinity": combat_affinity,
		"growth_primary_stat": growth_primary_stat,
		"growth_secondary_stats": growth_secondary_stats,
		"attribute_point_multiplier": attribute_point_multiplier,
		"attribute_point_budget": attribute_point_budget,
		"skills": skills,
		"skill_cooldowns": {},
		"drop_profile": drop_profile,
		"drops": template.get("drops", {}).duplicate(true),
		"class_drop_profile": class_drop_profile,
		"use_class_drop_pool": use_class_drop_pool,
		"use_rank_drop_pool": use_rank_drop_pool,
		"equipment_drop_chance": equipment_drop_chance,
		"effects": template.get("effects", []).duplicate(true),
		"combat_effects": [],
		"turn_start_processed": false,
		"exp": roundi(float(int(template.get("exp", 5)) + enemy_level * 2) * float(template.get("experience_multiplier", 1.0))),
		"use_drop": bool(template.get("use_drop", true)),
		"is_training_dummy": bool(template.get("is_training_dummy", false)),
	}


static func _random_combat_affinity(rng: RandomNumberGenerator) -> String:
	if rng == null:
		return COMBAT_AFFINITY_NORMAL
	return str(COMBAT_AFFINITY_IDS[rng.randi_range(0, COMBAT_AFFINITY_IDS.size() - 1)])


static func _take_random_string(values: Array[String], rng: RandomNumberGenerator) -> String:
	if values.is_empty():
		return ""
	var index := rng.randi_range(0, values.size() - 1) if rng != null else 0
	var value := str(values[index])
	values.remove_at(index)
	return value


static func _weighted_growth_target(primary_stat: String, secondary_stats: Array[String], pool: Array, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf() if rng != null else 0.0
	if roll < 0.5:
		return primary_stat
	if roll < 0.65 and secondary_stats.size() >= 1:
		return secondary_stats[0]
	if roll < 0.8 and secondary_stats.size() >= 2:
		return secondary_stats[1]
	if pool.is_empty():
		return primary_stat
	var index := rng.randi_range(0, pool.size() - 1) if rng != null else 0
	return str(pool[index])


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
	var expanded_items: Array = profile["items"].duplicate(true) if profile["items"] is Array else []
	if expanded_items.is_empty():
		var drop_table := content_definition("drop_table", "enemy_drop_categories", {"categories": ENEMY_DROP_CATEGORY_ITEMS})
		for category in profile["categories"]:
			for item_id in drop_table.get("categories", {}).get(str(category), []):
				expanded_items.append(item_id)
	var unique_items: Array = []
	var seen_item_ids: Dictionary = {}
	for item_id in expanded_items:
		var resolved_id := str(item_id)
		if seen_item_ids.has(resolved_id) or not content_has("item", resolved_id, ITEM_DEFS):
			continue
		seen_item_ids[resolved_id] = true
		unique_items.append(resolved_id)
	profile["items"] = unique_items
	return profile


static func enemy_class_drop_profile(enemy_class: String) -> Dictionary:
	if not enemy_class_drop_profile_errors().is_empty():
		return {}
	var profile = ENEMY_CLASS_DROP_PROFILES.get(enemy_class, {})
	return profile.duplicate(true) if profile is Dictionary else {}


static func enemy_class_drop_profile_errors() -> Array[String]:
	var errors: Array[String] = []
	var assigned_classes: Dictionary = {}
	for enemy_class in [ENEMY_CLASS_NORMAL, ENEMY_CLASS_ELITE, ENEMY_CLASS_BOSS]:
		var profile = ENEMY_CLASS_DROP_PROFILES.get(enemy_class, {})
		if not (profile is Dictionary):
			errors.append("%s drop profile must be a dictionary" % enemy_class)
			continue
		var mode := str(profile.get("mode", ""))
		if not ["independent", "weighted_one"].has(mode):
			errors.append("%s drop profile has invalid mode" % enemy_class)
		var entries = profile.get("entries", [])
		if not (entries is Array) or entries.is_empty():
			errors.append("%s drop profile must contain entries" % enemy_class)
			continue
		var local_item_ids: Dictionary = {}
		for entry_value in entries:
			if not (entry_value is Dictionary):
				errors.append("%s drop entry must be a dictionary" % enemy_class)
				continue
			var entry: Dictionary = entry_value
			var item_id := str(entry.get("item_id", ""))
			if item_id.is_empty() or item_definition(item_id).is_empty():
				errors.append("%s drop entry references unknown item %s" % [enemy_class, item_id])
				continue
			if local_item_ids.has(item_id):
				errors.append("%s drop profile repeats %s" % [enemy_class, item_id])
				continue
			local_item_ids[item_id] = true
			if assigned_classes.has(item_id):
				errors.append("%s is shared by %s and %s" % [item_id, assigned_classes[item_id], enemy_class])
			else:
				assigned_classes[item_id] = enemy_class
			if int(entry.get("amount", 0)) <= 0:
				errors.append("%s drop entry has invalid amount" % item_id)
			if mode == "independent":
				var chance := float(entry.get("chance", 0.0))
				if chance <= 0.0 or chance > 1.0:
					errors.append("%s drop entry has invalid chance" % item_id)
			elif float(entry.get("weight", 0.0)) <= 0.0:
				errors.append("%s drop entry has invalid weight" % item_id)
	return errors


static func resolve_enemy_id(enemy_id: String) -> String:
	if enemy_id.is_empty() or not content_has("enemy", enemy_id, ENEMY_TEMPLATES):
		return DEFAULT_ENEMY_ID
	return enemy_id


static func enemy_scene_path(enemy_id: String) -> String:
	var resolved_enemy_id: String = resolve_enemy_id(enemy_id)
	var definition := content_definition("enemy", resolved_enemy_id, core_enemy_definition(resolved_enemy_id))
	var registered_path := str(definition.get("scene_path", ""))
	if not registered_path.is_empty():
		return registered_path
	return str(ENEMY_SCENE_PATHS.get(resolved_enemy_id, ENEMY_SCENE_PATHS[DEFAULT_ENEMY_ID]))


static func create_equipment(level: int, rng: RandomNumberGenerator, craft_bonus: int = 0, obtain_source: String = "non_drop", rarity_weights: Dictionary = {}) -> Dictionary:
	var template_ids := content_ids("equipment", EQUIPMENT_DEFS)
	if template_ids.is_empty():
		return {}
	var has_mod_templates := false
	for candidate_id in template_ids:
		if not EQUIPMENT_DEFS.has(str(candidate_id)):
			has_mod_templates = true
			break
	var template_id := "" if has_mod_templates else EquipmentConfigParserScript.roll_template_id(rng)
	if template_id.is_empty() or not template_ids.has(template_id):
		template_id = str(template_ids[rng.randi_range(0, template_ids.size() - 1)])
	var rarity := "" if rarity_weights.is_empty() else random_rarity_from_weights(rng, rarity_weights)
	return create_equipment_from_template(template_id, level, rng, craft_bonus, "", rarity, obtain_source)


static func create_equipment_from_template(template_id: String, _level: int, rng: RandomNumberGenerator, _craft_bonus: int = 0, _name_prefix: String = "", rarity: String = "t1", obtain_source: String = "non_drop") -> Dictionary:
	var forced_variant_id := ""
	if LEGACY_EQUIPMENT_VARIANT_ALIASES.has(template_id):
		var alias: Dictionary = LEGACY_EQUIPMENT_VARIANT_ALIASES[template_id]
		forced_variant_id = str(alias.get("variant_id", ""))
		template_id = str(alias.get("template_id", template_id))
	var template: Dictionary = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {}))
	if template.is_empty():
		return {}
	var rarity_name: String = str(EQUIPMENT_RARITY_NAMES.get(rarity, "一阶"))
	var slot := str(template.get("slot", template_id))
	var variant_id := forced_variant_id
	var variants := equipment_attribute_variants(template_id)
	if variant_id.is_empty() and not variants.is_empty():
		variant_id = EquipmentConfigParserScript.roll_equipment_id(template_id, rng)
		if variant_id.is_empty():
			var variant_ids: Array = variants.keys()
			variant_ids.sort()
			variant_id = str(variant_ids[rng.randi_range(0, variant_ids.size() - 1)])
	var variant: Dictionary = variants.get(variant_id, {}) if not variant_id.is_empty() else {}
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	var core_definition := EquipmentConfigParserScript.equipment_definition(equipment_id)
	if rarity.is_empty() or not EQUIPMENT_RARITY_ORDER.has(rarity):
		var rarity_weights := EquipmentConfigParserScript.rarity_weights(equipment_id)
		rarity = random_rarity_from_weights(rng, rarity_weights if not rarity_weights.is_empty() else EQUIPMENT_RARITY_WEIGHTS)
	var tier_definition := EquipmentConfigParserScript.tier_definition(equipment_id, rarity)
	rarity_name = str(tier_definition.get("rarity_name", EQUIPMENT_RARITY_NAMES.get(rarity, "一阶")))
	var equipment_name: String = str(variant.get("name", template.get("name", slot_name(slot))))
	if not core_definition.is_empty():
		equipment_name = str(core_definition.get("name", equipment_name))
	var equipment_level := 1
	var fixed_attributes := equipment_tier_base_attributes(template_id, rarity, variant_id)
	var rolled_attribute_stats := roll_equipment_attribute_stats(template_id, rarity, fixed_attributes, [], rng, variant_id)
	var base_attributes := build_equipment_base_attributes(template_id, rarity, variant_id, rolled_attribute_stats)
	var icon_name := str(core_definition.get("icon_name", variant.get("icon_name", equipment_icon_name(template_id, variant_id))))
	var icon_path := str(core_definition.get("icon_path", variant.get("icon_path", equipment_icon_path(template_id, variant_id))))
	return {
		"instance_id": "%s_%d_%d" % [template_id, Time.get_ticks_usec(), rng.randi()],
		"item_id": template_id,
		"name": "%s·%s" % [rarity_name, equipment_name],
		"equipment_base_name": equipment_name,
		"equipment_variant_id": variant_id,
		"description": "%s等级装备" % rarity_name,
		"type": ITEM_TYPE_EQUIPMENT,
		"count": 1,
		"stackable": false,
		"usable": true,
		"payload": {},
		"obtain_source": obtain_source,
		"icon_name": icon_name,
		"icon_path": icon_path,
		"resource_path": equipment_resource_path(template_id, variant_id),
		"slot": slot,
		"rarity": rarity,
		"equipment_level": equipment_level,
		"base_attributes": base_attributes,
		"rolled_attribute_stats": rolled_attribute_stats,
		"attribute_generation_version": EQUIPMENT_ATTRIBUTE_GENERATION_VERSION,
		"description_effects": equipment_template_description_effects(template_id, variant_id),
		"enhanced_attributes": [],
		"enhancement_allocations": {},
		"refine_affixes": [],
		"enhance_count": 0,
		"refine_count": 0,
		"equipped": false,
		"equipped_by": "",
		"attack_bonus": 0,
		"defense_bonus": 0,
		"enhance_attack_bonus": 0,
		"enhance_defense_bonus": 0,
		"equip_requirement": {},
		"affixes": generate_equipment_affixes(rarity, rng, template_id, variant_id),
	}


static func equipment_tier_base_attributes(template_id: String, rarity: String, variant_id: String = "") -> Array:
	if LEGACY_EQUIPMENT_VARIANT_ALIASES.has(template_id):
		var alias: Dictionary = LEGACY_EQUIPMENT_VARIANT_ALIASES[template_id]
		variant_id = str(alias.get("variant_id", variant_id))
		template_id = str(alias.get("template_id", template_id))
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	var core_tier := EquipmentConfigParserScript.tier_definition(equipment_id, rarity)
	var core_attributes = core_tier.get("base_attributes", [])
	if core_attributes is Array and not core_attributes.is_empty():
		return core_attributes.duplicate(true)
	if _is_indexed_core_equipment_reference(template_id):
		return []
	if not variant_id.is_empty():
		var variant: Dictionary = equipment_attribute_variants(template_id).get(variant_id, {})
		var variant_tiers = variant.get("tier_base_attributes", {})
		if variant_tiers is Dictionary:
			var variant_attributes = variant_tiers.get(rarity)
			if variant_attributes is Array and not variant_attributes.is_empty():
				return variant_attributes.duplicate(true)
	var tier_attributes = null
	var resource: Resource = equipment_resource(template_id)
	if resource != null:
		var resource_tiers = resource.get("tier_base_attributes")
		if resource_tiers is Dictionary:
			tier_attributes = resource_tiers.get(rarity)
	if not (tier_attributes is Array):
		var resource_definition: Dictionary = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {}))
		var definition_tiers = resource_definition.get("tier_base_attributes", {})
		if definition_tiers is Dictionary:
			tier_attributes = definition_tiers.get(rarity)
	if tier_attributes is Array and not tier_attributes.is_empty():
		return tier_attributes.duplicate(true)
	var definition: Dictionary = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {}))
	return _default_equipment_tier_base_attributes(str(definition.get("slot", template_id)), rarity)


static func equipment_attribute_variants(template_id: String) -> Dictionary:
	var core_ids := EquipmentConfigParserScript.equipment_ids_for_template(template_id)
	var core_variants := {}
	for equipment_id in core_ids:
		var core_definition := EquipmentConfigParserScript.equipment_definition(equipment_id)
		var variant_id := str(core_definition.get("variant_id", ""))
		if variant_id.is_empty():
			continue
		var tiers := {}
		for raw_tier in core_definition.get("tiers", []):
			if raw_tier is Dictionary:
				tiers[str(raw_tier.get("rarity", ""))] = raw_tier.get("base_attributes", []).duplicate(true)
		core_variants[variant_id] = {
			"name": str(core_definition.get("name", variant_id)),
			"icon_name": str(core_definition.get("icon_name", template_id)),
			"icon_path": str(core_definition.get("icon_path", "")),
			"tier_base_attributes": tiers,
			"selection_weight": int(core_definition.get("selection_weight", 1)),
		}
	if not core_variants.is_empty():
		return core_variants
	if _is_indexed_core_equipment_reference(template_id):
		return {}
	var resource: Resource = equipment_resource(template_id)
	if resource != null:
		var resource_variants = resource.get("attribute_variants")
		if resource_variants is Dictionary and not resource_variants.is_empty():
			return resource_variants.duplicate(true)
	var definition: Dictionary = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {}))
	var variants = definition.get("attribute_variants", {})
	return variants.duplicate(true) if variants is Dictionary else {}


static func equipment_variant_definition(template_id: String, variant_id: String) -> Dictionary:
	var variant = equipment_attribute_variants(template_id).get(variant_id, {})
	return variant.duplicate(true) if variant is Dictionary else {}


static func equipment_random_attribute_pool(template_id: String, variant_id: String = "") -> Array[String]:
	var values = null
	var core_definition := EquipmentConfigParserScript.equipment_definition(EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id))
	if not core_definition.is_empty():
		values = core_definition.get("random_attribute_pool", [])
	elif _is_indexed_core_equipment_reference(template_id):
		return []
	var resource: Resource = equipment_resource(template_id)
	if (not (values is Array) or values.is_empty()) and resource != null:
		values = resource.get("random_attribute_pool")
	if not (values is Array) or values.is_empty():
		values = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {})).get("random_attribute_pool", [])
	var result: Array[String] = []
	if values is Array:
		for value in values:
			var stat_id := str(value)
			if EQUIPMENT_ALL_ATTRIBUTE_STATS.has(stat_id) and not result.has(stat_id):
				result.append(stat_id)
	return result


static func equipment_random_attribute_count(template_id: String, rarity: String, variant_id: String = "") -> int:
	return _equipment_tier_random_value(template_id, "tier_random_attribute_counts", rarity, variant_id)


static func equipment_random_attribute_budget(template_id: String, rarity: String, variant_id: String = "") -> int:
	return _equipment_tier_random_value(template_id, "tier_random_attribute_budgets", rarity, variant_id)


static func _equipment_tier_random_value(template_id: String, property_name: String, rarity: String, variant_id: String = "") -> int:
	var core_tier := EquipmentConfigParserScript.tier_definition(EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id), rarity)
	if not core_tier.is_empty():
		var core_key := "random_count" if property_name == "tier_random_attribute_counts" else "random_budget"
		return maxi(0, int(core_tier.get(core_key, 0)))
	if _is_indexed_core_equipment_reference(template_id):
		return 0
	var tiers = null
	var resource: Resource = equipment_resource(template_id)
	if resource != null:
		tiers = resource.get(property_name)
	if not (tiers is Dictionary) or tiers.is_empty():
		tiers = content_definition("equipment", template_id, EQUIPMENT_DEFS.get(template_id, {})).get(property_name, {})
	return maxi(0, int(tiers.get(rarity, 0))) if tiers is Dictionary else 0


static func roll_equipment_attribute_stats(template_id: String, rarity: String, fixed_attributes: Array, existing_stats: Array, rng: RandomNumberGenerator, variant_id: String = "") -> Array[String]:
	var result: Array[String] = []
	var excluded: Array[String] = []
	for attribute in fixed_attributes:
		if attribute is Dictionary:
			excluded.append(str(attribute.get("stat", "")))
	for value in existing_stats:
		var stat_id := str(value)
		if not stat_id.is_empty() and not excluded.has(stat_id) and not result.has(stat_id):
			result.append(stat_id)
	var target_count := equipment_random_attribute_count(template_id, rarity, variant_id)
	if target_count <= 0:
		return []
	if result.size() > target_count:
		result.resize(target_count)
	var available := equipment_random_attribute_pool(template_id, variant_id)
	for stat_id in excluded + result:
		available.erase(stat_id)
	while result.size() < target_count and not available.is_empty():
		var index := rng.randi_range(0, available.size() - 1)
		result.append(str(available[index]))
		available.remove_at(index)
	return result


static func build_equipment_base_attributes(template_id: String, rarity: String, variant_id: String, rolled_attribute_stats: Array) -> Array:
	var attributes := equipment_tier_base_attributes(template_id, rarity, variant_id)
	var count := rolled_attribute_stats.size()
	if count <= 0:
		return attributes
	var budget := equipment_random_attribute_budget(template_id, rarity, variant_id)
	var points_per_attribute := floori(float(budget) / float(count))
	var remainder := budget % count
	for index in range(count):
		var stat_id := str(rolled_attribute_stats[index])
		var points := points_per_attribute + (1 if index < remainder else 0)
		attributes.append({"stat": stat_id, "amount": points * equipment_attribute_unit_amount(stat_id, template_id, variant_id)})
	return attributes


static func _default_equipment_tier_base_attributes(slot: String, rarity: String) -> Array:
	var tier_index := maxi(0, EQUIPMENT_RARITY_ORDER.find(rarity))
	var default_amounts := [2, 5, 10, 18, 30]
	var hp_amounts := [8, 20, 40, 72, 120]
	var mp_amounts := [4, 10, 20, 36, 60]
	var amount := int(default_amounts[tier_index])
	match slot:
		"weapon":
			return [{"stat": "attack", "amount": amount}]
		"helmet":
			return [{"stat": "max_mp", "amount": int(mp_amounts[tier_index])}]
		"armor":
			return [{"stat": "defense", "amount": amount}]
		"leggings":
			return [{"stat": "max_hp", "amount": int(hp_amounts[tier_index])}]
		"gloves":
			return [{"stat": "root_bone", "amount": amount}]
		"accessory":
			return [{"stat": "element_wood", "amount": amount}]
	return [{"stat": "attack", "amount": amount}]


static func equipment_affix_count(rarity: String, template_id: String = "", variant_id: String = "") -> int:
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	if not template_id.is_empty() and equipment_id.is_empty() and _is_indexed_core_equipment_reference(template_id):
		return 0
	if equipment_id.is_empty():
		equipment_id = str(EquipmentConfigParserScript.index_data().get("default_equipment_id", ""))
	var tier := EquipmentConfigParserScript.tier_definition(equipment_id, rarity)
	return maxi(0, int(tier.get("affix_count", 0)))


static func generate_equipment_affixes(rarity: String, rng: RandomNumberGenerator, template_id: String = "", variant_id: String = "") -> Array:
	var affix_ids: Array = EQUIPMENT_AFFIX_DEFS.keys()
	var affixes: Array = []
	for _index in range(equipment_affix_count(rarity, template_id, variant_id)):
		var affix_id := str(affix_ids[rng.randi_range(0, affix_ids.size() - 1)])
		affixes.append({"id": affix_id, "value": equipment_affix(affix_id).get("value", 0)})
	return affixes


static func generate_stable_equipment_affixes(rarity: String, instance_id: String, template_id: String = "", variant_id: String = "") -> Array:
	var stable_rng := RandomNumberGenerator.new()
	stable_rng.seed = hash("equipment_affixes:%s:%s" % [rarity, instance_id])
	return generate_equipment_affixes(rarity, stable_rng, template_id, variant_id)


static func equipment_affix(affix_id: String) -> Dictionary:
	return EQUIPMENT_AFFIX_DEFS.get(affix_id, {}).duplicate(true)


static func equipment_affix_name(affix_id: String) -> String:
	return str(EQUIPMENT_AFFIX_DEFS.get(affix_id, {}).get("name", affix_id))


static func equipment_affix_text(affix: Dictionary) -> String:
	var affix_id := str(affix.get("id", affix.get("type", "")))
	var definition := equipment_affix(affix_id)
	var value = affix.get("value", definition.get("value", 0))
	if str(definition.get("format", "flat")) == "percent":
		return "%s +%d%%" % [equipment_affix_name(affix_id), roundi(float(value) * 100.0)]
	return "%s +%d" % [equipment_affix_name(affix_id), int(value)]


static func equipment_combat_modifier_cap(affix_id: String) -> float:
	return float(EQUIPMENT_COMBAT_MODIFIER_CAPS.get(affix_id, INF))


static func equipment_attribute_unit_amount(stat_id: String, template_id: String = "", variant_id: String = "") -> int:
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	if not template_id.is_empty() and equipment_id.is_empty() and _is_indexed_core_equipment_reference(template_id):
		return 0
	if equipment_id.is_empty():
		equipment_id = str(EquipmentConfigParserScript.index_data().get("default_equipment_id", ""))
	var definition := EquipmentConfigParserScript.equipment_definition(equipment_id)
	var units = definition.get("attribute_units", {})
	return maxi(1, int(units.get(stat_id, 1))) if units is Dictionary else 1


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
	return "；".join(parts) if not parts.is_empty() else "暂无直接效果"


static func innate_trait_compact_summary(raw_trait) -> String:
	return "%s·%s %s" % [
		innate_trait_rarity_name(innate_trait_rarity(raw_trait)),
		innate_trait_slot_name(innate_trait_slot(raw_trait)),
		innate_trait_name(raw_trait),
	]


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
		ITEM_USE_SCOPE_BOTH:
			return "家园/战斗"
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


static func permanent_attribute_enhance_tier_limit(tier_id: String) -> int:
	return int(PERMANENT_ATTRIBUTE_ENHANCE_TIER_LIMITS.get(tier_id, 0))


static func permanent_attribute_enhance_tier_name(tier_id: String) -> String:
	return str(PERMANENT_ATTRIBUTE_ENHANCE_TIER_NAMES.get(tier_id, tier_id))


static func obtain_source_name(source_id: String) -> String:
	return OBTAIN_SOURCE_NAMES.get(source_id, source_id)


static func slot_name(slot_id: String) -> String:
	return SLOT_NAMES.get(slot_id, slot_id)


static func equipment_rarity_name(rarity: String) -> String:
	return EQUIPMENT_RARITY_NAMES.get(rarity, rarity)


static func equipment_equip_level_requirement(rarity: String) -> int:
	return int(EQUIPMENT_EQUIP_LEVEL_REQUIREMENTS.get(rarity, 1))


static func equipment_salvage_ore(rarity: String) -> int:
	return int(EQUIPMENT_SALVAGE_ORE.get(rarity, 1))


static func random_equipment_rarity(rng: RandomNumberGenerator, template_id: String = "", variant_id: String = "") -> String:
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	var weights := EquipmentConfigParserScript.rarity_weights(equipment_id)
	return random_rarity_from_weights(rng, weights if not weights.is_empty() else EQUIPMENT_RARITY_WEIGHTS)


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


static func equipment_enhance_limit(rarity: String, template_id: String = "", variant_id: String = "") -> int:
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	if not template_id.is_empty() and equipment_id.is_empty() and _is_indexed_core_equipment_reference(template_id):
		return 0
	if equipment_id.is_empty():
		equipment_id = str(EquipmentConfigParserScript.index_data().get("default_equipment_id", ""))
	return maxi(0, int(EquipmentConfigParserScript.tier_definition(equipment_id, rarity).get("enhance_limit", 0)))


static func equipment_enhance_cost(rarity: String, next_enhance_level: int, template_id: String = "", variant_id: String = "") -> int:
	return int(equipment_enhance_costs(rarity, next_enhance_level, template_id, variant_id).get(ITEM_ID_ENHANCEMENT_STONE, 0))


static func equipment_enhance_costs(rarity: String, next_enhance_level: int, template_id: String = "", variant_id: String = "") -> Dictionary:
	if next_enhance_level < 1 or next_enhance_level > equipment_enhance_limit(rarity, template_id, variant_id):
		return {}
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	if not template_id.is_empty() and equipment_id.is_empty() and _is_indexed_core_equipment_reference(template_id):
		return {}
	if equipment_id.is_empty():
		equipment_id = str(EquipmentConfigParserScript.index_data().get("default_equipment_id", ""))
	var cost = EquipmentConfigParserScript.tier_definition(equipment_id, rarity).get("enhance_cost", {})
	return cost.duplicate(true) if cost is Dictionary else {}


static func equipment_ascension_cost(rarity: String, template_id: String = "", variant_id: String = "") -> Dictionary:
	var equipment_id := EquipmentConfigParserScript.resolve_equipment_id(template_id, variant_id)
	if not template_id.is_empty() and equipment_id.is_empty() and _is_indexed_core_equipment_reference(template_id):
		return {}
	if equipment_id.is_empty():
		equipment_id = str(EquipmentConfigParserScript.index_data().get("default_equipment_id", ""))
	var cost = EquipmentConfigParserScript.tier_definition(equipment_id, rarity).get("ascension_cost", {})
	return cost.duplicate(true) if cost is Dictionary else {}


static func alchemy_recipe_def(recipe_id: String) -> Dictionary:
	return content_definition("recipe", recipe_id, ALCHEMY_RECIPE_DEFS.get(recipe_id, {}))


static func alchemy_recipe_materials(recipe_id: String) -> Array:
	return content_definition("recipe", recipe_id, ALCHEMY_RECIPE_DEFS.get(recipe_id, {})).get("materials", []).duplicate(true)
