class_name DataTables
extends RefCounted

const ItemDefScript = preload("res://scripts/game/item_def.gd")
const EquipmentTemplateScript = preload("res://scripts/game/equipment_template.gd")

const ELEMENT_IDS := ["wood", "fire", "earth", "metal", "water"]
const ELEMENT_ATTRIBUTE_PREFIX := "element_"

const EQUIPMENT_ATTRIBUTE_DEFS := [
	{"stat": "max_hp", "name": "HP", "min": 8, "max": 16, "scale": 2},
	{"stat": "max_mp", "name": "MP", "min": 4, "max": 10, "scale": 1},
	{"stat": "attack", "name": "ATK", "min": 1, "max": 3, "scale": 1},
	{"stat": "defense", "name": "DEF", "min": 1, "max": 3, "scale": 1},
	{"stat": "root_bone", "name": "Root", "min": 1, "max": 2, "scale": 0},
	{"stat": "element_wood", "name": "Wood", "min": 1, "max": 2, "scale": 0},
	{"stat": "element_fire", "name": "Fire", "min": 1, "max": 2, "scale": 0},
	{"stat": "element_earth", "name": "Earth", "min": 1, "max": 2, "scale": 0},
	{"stat": "element_metal", "name": "Metal", "min": 1, "max": 2, "scale": 0},
	{"stat": "element_water", "name": "Water", "min": 1, "max": 2, "scale": 0},
]

const SPIRIT_STONE_QUALITY_DEFS := {
	"t1": {"name": "一阶", "amount": 1},
	"t2": {"name": "二阶", "amount": 2},
	"t3": {"name": "三阶", "amount": 4},
	"t4": {"name": "四阶", "amount": 7},
	"t5": {"name": "五阶", "amount": 11},
}
const SPIRIT_STONE_QUALITY_ORDER := ["t5", "t4", "t3", "t2", "t1"]
const STAT_STONE_IDS := ["attack", "defense", "max_hp", "max_mp", "root_bone"]

const ELEMENT_THEME_NAMES := {
	"wood": "青木",
	"fire": "赤焰",
	"earth": "厚土",
	"metal": "玄金",
	"water": "玄水",
}

const EQUIPMENT_RARITY_DEFS := {
	"t1": {"name": "一阶", "chance": 0.55, "multiplier": 1.0},
	"t2": {"name": "二阶", "chance": 0.28, "multiplier": 1.12},
	"t3": {"name": "三阶", "chance": 0.12, "multiplier": 1.28},
	"t4": {"name": "四阶", "chance": 0.04, "multiplier": 1.5},
	"t5": {"name": "五阶", "chance": 0.01, "multiplier": 1.8},
}
const EQUIPMENT_RARITY_ORDER := ["t1", "t2", "t3", "t4", "t5"]

const ITEM_TYPE_SKILL_BOOK := "skill_book"
const ITEM_TYPE_EQUIPMENT := "equipment"
const ITEM_TYPE_MATERIAL := "material"
const ITEM_TYPE_CROP := "crop"
const ITEM_TYPE_PILL := "pill"
const ITEM_TYPE_ALCHEMY_RECIPE := "alchemy_recipe"

const ITEM_DEFS := {
	"skill_book_spark": {
		"type": ITEM_TYPE_SKILL_BOOK,
		"name": "灵火术秘籍",
		"description": "使用后学习技能：灵火术。",
		"stackable": true,
		"usable": true,
		"payload": {"skill_id": "spark"},
	},
	"skill_book_water_needle": {
		"type": ITEM_TYPE_SKILL_BOOK,
		"name": "玄水针秘籍",
		"description": "使用后学习技能：玄水针。",
		"stackable": true,
		"usable": true,
		"payload": {"skill_id": "water_needle"},
	},
	"skill_book_stone_seal": {
		"type": ITEM_TYPE_SKILL_BOOK,
		"name": "裂土印秘籍",
		"description": "使用后学习技能：裂土印。",
		"stackable": true,
		"usable": true,
		"payload": {"skill_id": "stone_seal"},
	},
	"ore": {
		"type": ITEM_TYPE_MATERIAL,
		"name": "矿石",
		"description": "炼器所需的基础材料。",
		"stackable": true,
		"usable": false,
		"payload": {},
	},
	"spirit_sand": {
		"type": ITEM_TYPE_MATERIAL,
		"name": "灵砂",
		"description": "带有灵气的细砂，适合后续扩展精炼配方。",
		"stackable": true,
		"usable": false,
		"payload": {},
	},
	"beast_core": {
		"type": ITEM_TYPE_MATERIAL,
		"name": "妖核",
		"description": "小妖体内凝结的核心，适合后续扩展高阶配方。",
		"stackable": true,
		"usable": false,
		"payload": {},
	},
	"herb": {
		"type": ITEM_TYPE_CROP,
		"name": "草药",
		"description": "种田获得的药草，可用于炼丹。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 3},
	},
	"rice": {
		"type": ITEM_TYPE_CROP,
		"name": "灵米",
		"description": "带有灵气的谷物，适合后续扩展食补或炼丹配方。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 2},
	},
	"mushroom": {
		"type": ITEM_TYPE_CROP,
		"name": "灵菇",
		"description": "生长在家园角落的灵菇，适合后续扩展特殊丹方。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1},
	},

	"blade_grass": {
		"type": ITEM_TYPE_CROP,
		"name": "刃纹草",
		"description": "攻击属性丹药主材料，成熟时间 180 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 180, "stat": "attack"},
	},

	"ironroot": {
		"type": ITEM_TYPE_CROP,
		"name": "铁根藤",
		"description": "防御属性丹药主材料，成熟时间 180 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 180, "stat": "defense"},
	},
	"blood_ginseng": {
		"type": ITEM_TYPE_CROP,
		"name": "血参",
		"description": "生命属性丹药主材料，成熟时间 240 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 240, "stat": "max_hp"},
	},
	"spirit_lotus": {
		"type": ITEM_TYPE_CROP,
		"name": "灵泉莲",
		"description": "灵力属性丹药主材料，成熟时间 240 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 240, "stat": "max_mp"},
	},
	"bone_bamboo": {
		"type": ITEM_TYPE_CROP,
		"name": "玉骨竹",
		"description": "根骨属性丹药主材料，成熟时间 360 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 360, "stat": "root_bone"},
	},
	"woodvine": {
		"type": ITEM_TYPE_CROP,
		"name": "青木藤",
		"description": "木行丹药主材料，成熟时间 180 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 180, "element": "wood"},
	},
	"flame_flower": {
		"type": ITEM_TYPE_CROP,
		"name": "赤焰花",
		"description": "火行丹药主材料，成熟时间 210 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 210, "element": "fire"},
	},
	"earth_moss": {
		"type": ITEM_TYPE_CROP,
		"name": "厚土苔",
		"description": "土行丹药主材料，成熟时间 210 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 210, "element": "earth"},
	},
	"metal_reed": {
		"type": ITEM_TYPE_CROP,
		"name": "玄金苇",
		"description": "金行丹药主材料，成熟时间 300 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 300, "element": "metal"},
	},
	"water_orchid": {
		"type": ITEM_TYPE_CROP,
		"name": "玄水兰",
		"description": "水行丹药主材料，成熟时间 240 秒。",
		"stackable": true,
		"usable": false,
		"payload": {"seed_yield": 1, "growth_seconds": 240, "element": "water"},
	},
	"pill": {
		"type": ITEM_TYPE_PILL,
		"name": "调息丹",
		"description": "使用后恢复 30 生命和 20 灵力。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "instant", "hp": 30, "mp": 20},
	},
	"life_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "归元丹",
		"description": "使用后恢复 55 生命。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "instant", "hp": 55, "mp": 0},
	},
	"spirit_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "聚灵丹",
		"description": "使用后恢复 42 灵力。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "instant", "hp": 0, "mp": 42},
	},
	"might_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "Might Pill",
		"description": "Grants a temporary attack buff.",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 30.0, "stat": "attack", "amount": 3},
	},
	"recipe_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "Rest Pill Recipe",
		"description": "Teaches the Rest Pill recipe.",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "pill"},
	},
	"recipe_life_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "Life Pill Recipe",
		"description": "Teaches the Life Pill recipe.",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "life_pill"},
	},
	"recipe_spirit_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "Spirit Pill Recipe",
		"description": "Teaches the Spirit Pill recipe.",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "spirit_pill"},
	},
	"recipe_might_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "Might Pill Recipe",
		"description": "Teaches the Might Pill recipe.",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "might_pill"},
	},

	"recipe_attack_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "破军丹方",
		"description": "学习破军丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "attack_pill"},
	},
	"recipe_defense_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "玄甲丹方",
		"description": "学习玄甲丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "defense_pill"},
	},
	"recipe_life_boost_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "血元丹方",
		"description": "学习血元丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "life_boost_pill"},
	},
	"recipe_mana_boost_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "灵泉丹方",
		"description": "学习灵泉丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "mana_boost_pill"},
	},
	"recipe_root_bone_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "锻骨丹方",
		"description": "学习锻骨丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "root_bone_pill"},
	},
	"recipe_wood_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "青木丹方",
		"description": "学习青木丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "wood_pill"},
	},
	"recipe_fire_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "赤焰丹方",
		"description": "学习赤焰丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "fire_pill"},
	},
	"recipe_earth_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "厚土丹方",
		"description": "学习厚土丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "earth_pill"},
	},
	"recipe_metal_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "玄金丹方",
		"description": "学习玄金丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "metal_pill"},
	},
	"recipe_water_pill": {
		"type": ITEM_TYPE_ALCHEMY_RECIPE,
		"name": "玄水丹方",
		"description": "学习玄水丹炼制配方。",
		"stackable": true,
		"usable": true,
		"payload": {"recipe_id": "water_pill"},
	},
	"attack_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "破军丹",
		"description": "300 秒攻击 +5。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "attack", "amount": 5},
	},
	"defense_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "玄甲丹",
		"description": "300 秒防御 +5。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "defense", "amount": 5},
	},
	"life_boost_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "血元丹",
		"description": "300 秒最大生命 +30。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "max_hp", "amount": 30},
	},
	"mana_boost_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "灵泉丹",
		"description": "300 秒最大灵力 +20。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "max_mp", "amount": 20},
	},
	"root_bone_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "锻骨丹",
		"description": "300 秒根骨 +2。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "root_bone", "amount": 2},
	},
	"wood_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "青木丹",
		"description": "300 秒木行 +5。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "element_wood", "amount": 5},
	},
	"fire_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "赤焰丹",
		"description": "300 秒火行 +5。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "element_fire", "amount": 5},
	},
	"earth_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "厚土丹",
		"description": "300 秒土行 +5。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "element_earth", "amount": 5},
	},
	"metal_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "玄金丹",
		"description": "300 秒金行 +5。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "element_metal", "amount": 5},
	},
	"water_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "玄水丹",
		"description": "300 秒水行 +5。",
		"stackable": true,
		"usable": true,
		"payload": {"effect_mode": "duration", "duration": 300.0, "stat": "element_water", "amount": 5},
	},
	"breakthrough_pill": {
		"type": ITEM_TYPE_PILL,
		"name": "Breakthrough Pill",
		"description": "Unlocks the next 10-level stage cap.",
		"stackable": true,
		"usable": true,
		"payload": {"breakthrough": true},
	},
}


const ALCHEMY_RECIPE_DEFS := {
	"pill": {"recipe_id": "pill", "result_item_id": "pill", "materials": [{"item_id": "herb", "amount": 2}]},
	"life_pill": {"recipe_id": "life_pill", "result_item_id": "life_pill", "materials": [{"item_id": "herb", "amount": 2}, {"item_id": "rice", "amount": 1}]},
	"spirit_pill": {"recipe_id": "spirit_pill", "result_item_id": "spirit_pill", "materials": [{"item_id": "mushroom", "amount": 2}, {"item_id": "rice", "amount": 1}]},
	"might_pill": {"recipe_id": "might_pill", "result_item_id": "might_pill", "materials": [{"item_id": "blade_grass", "amount": 2}, {"item_id": "rice", "amount": 1}]},
	"attack_pill": {"recipe_id": "attack_pill", "result_item_id": "attack_pill", "materials": [{"item_id": "blade_grass", "amount": 2}, {"item_id": "rice", "amount": 1}, {"item_id": "stat_stone_attack_t1", "amount": 1}]},
	"defense_pill": {"recipe_id": "defense_pill", "result_item_id": "defense_pill", "materials": [{"item_id": "ironroot", "amount": 2}, {"item_id": "rice", "amount": 1}, {"item_id": "stat_stone_defense_t1", "amount": 1}]},
	"life_boost_pill": {"recipe_id": "life_boost_pill", "result_item_id": "life_boost_pill", "materials": [{"item_id": "blood_ginseng", "amount": 2}, {"item_id": "herb", "amount": 1}, {"item_id": "stat_stone_max_hp_t1", "amount": 1}]},
	"mana_boost_pill": {"recipe_id": "mana_boost_pill", "result_item_id": "mana_boost_pill", "materials": [{"item_id": "spirit_lotus", "amount": 2}, {"item_id": "rice", "amount": 1}, {"item_id": "stat_stone_max_mp_t1", "amount": 1}]},
	"root_bone_pill": {"recipe_id": "root_bone_pill", "result_item_id": "root_bone_pill", "materials": [{"item_id": "bone_bamboo", "amount": 2}, {"item_id": "monster_core", "amount": 1}, {"item_id": "stat_stone_root_bone_t1", "amount": 1}]},
	"wood_pill": {"recipe_id": "wood_pill", "result_item_id": "wood_pill", "materials": [{"item_id": "woodvine", "amount": 2}, {"item_id": "herb", "amount": 1}, {"item_id": "spirit_stone_wood_t1", "amount": 1}]},
	"fire_pill": {"recipe_id": "fire_pill", "result_item_id": "fire_pill", "materials": [{"item_id": "flame_flower", "amount": 2}, {"item_id": "spirit_sand", "amount": 1}, {"item_id": "spirit_stone_fire_t1", "amount": 1}]},
	"earth_pill": {"recipe_id": "earth_pill", "result_item_id": "earth_pill", "materials": [{"item_id": "earth_moss", "amount": 2}, {"item_id": "rice", "amount": 1}, {"item_id": "spirit_stone_earth_t1", "amount": 1}]},
	"metal_pill": {"recipe_id": "metal_pill", "result_item_id": "metal_pill", "materials": [{"item_id": "metal_reed", "amount": 2}, {"item_id": "ore", "amount": 1}, {"item_id": "spirit_stone_metal_t1", "amount": 1}]},
	"water_pill": {"recipe_id": "water_pill", "result_item_id": "water_pill", "materials": [{"item_id": "water_orchid", "amount": 2}, {"item_id": "mushroom", "amount": 1}, {"item_id": "spirit_stone_water_t1", "amount": 1}]},
}

const SKILL_DEFS := {
	"spark": {
		"id": "spark",
		"name": "灵火术",
		"element": "fire",
		"cooldown": 3.5,
		"mp_cost": 8,
		"damage_multiplier": 1.8,
	},
	"water_needle": {
		"id": "water_needle",
		"name": "玄水针",
		"element": "water",
		"cooldown": 2.0,
		"mp_cost": 5,
		"damage_multiplier": 1.25,
	},
	"stone_seal": {
		"id": "stone_seal",
		"name": "裂土印",
		"element": "earth",
		"cooldown": 6.0,
		"mp_cost": 13,
		"damage_multiplier": 2.3,
	},
}

const EQUIPMENT_DEFS := {
	"weapon": {
		"item_id": "weapon",
		"slot": "weapon",
		"base_name": "Sword",
		"attack_base": 1,
		"attack_scale": 2,
		"defense_base": 0,
		"defense_scale": 0,
		"description": "Equipment for this slot.",
	},
	"helmet": {
		"item_id": "helmet",
		"slot": "helmet",
		"base_name": "Helmet",
		"attack_base": 0,
		"attack_scale": 0,
		"defense_base": 1,
		"defense_scale": 1,
		"description": "Equipment for this slot.",
	},
	"armor": {
		"item_id": "armor",
		"slot": "armor",
		"base_name": "Armor",
		"attack_base": 0,
		"attack_scale": 0,
		"defense_base": 1,
		"defense_scale": 2,
		"description": "Equipment for this slot.",
	},
	"leggings": {
		"item_id": "leggings",
		"slot": "leggings",
		"base_name": "Leggings",
		"attack_base": 0,
		"attack_scale": 0,
		"defense_base": 1,
		"defense_scale": 1,
		"description": "Equipment for this slot.",
	},
	"gloves": {
		"item_id": "gloves",
		"slot": "gloves",
		"base_name": "Gloves",
		"attack_base": 1,
		"attack_scale": 1,
		"defense_base": 0,
		"defense_scale": 1,
		"description": "Equipment for this slot.",
	},
	"accessory": {
		"item_id": "accessory",
		"slot": "accessory",
		"base_name": "Charm",
		"attack_base": 1,
		"attack_scale": 1,
		"defense_base": 1,
		"defense_scale": 1,
		"description": "Accessory equipment for either accessory slot.",
	},
}

const AFFIX_DEFS := [
	{"id": "attack", "name": "ATK", "stat": "attack", "min": 1, "max": 3},
	{"id": "defense", "name": "DEF", "stat": "defense", "min": 1, "max": 3},
	{"id": "max_hp", "name": "Stat", "stat": "max_hp", "min": 5, "max": 15},
	{"id": "max_mp", "name": "Stat", "stat": "max_mp", "min": 3, "max": 10},
	{"id": "root_bone", "name": "Stat", "stat": "root_bone", "min": 1, "max": 2},
	{"id": "fire", "name": "Fire", "stat": "element_fire", "min": 1, "max": 2},
]

const ENEMY_TEMPLATES := {
	"wandering_imp": {
		"id": "wandering_imp",
		"name": "Wandering Imp",
		"base_hp": 24,
		"hp_scale": 8,
		"base_attack": 4,
		"attack_scale": 2,
		"base_defense": 0,
		"defense_scale": 1,
		"exp_base": 10,
		"exp_scale": 4,
		"element": "earth",
		"weak_element": "fire",
		"element_attack_ratio": 0.2,
		"drops": {"ore": {"min": 1, "max": 3, "chance": 1.0}, "spirit_sand": {"min": 1, "max": 1, "chance": 0.45}, "beast_core": {"min": 1, "max": 1, "chance": 0.18}, "spirit_stone_earth_t1": {"min": 1, "max": 2, "chance": 0.7}, "spirit_stone_earth_t2": {"min": 1, "max": 1, "chance": 0.22}, "refine_talisman": {"min": 1, "max": 1, "chance": 0.12}, "recipe_life_pill": {"min": 1, "max": 1, "chance": 0.08}},
	},
	"stone_beast": {
		"id": "stone_beast",
		"name": "Stone Beast",
		"base_hp": 38,
		"hp_scale": 11,
		"base_attack": 3,
		"attack_scale": 2,
		"base_defense": 2,
		"defense_scale": 1,
		"exp_base": 13,
		"exp_scale": 5,
		"element": "earth",
		"weak_element": "wood",
		"element_attack_ratio": 0.1,
		"drops": {"ore": {"min": 2, "max": 4, "chance": 1.0}, "spirit_sand": {"min": 1, "max": 2, "chance": 0.35}, "beast_core": {"min": 1, "max": 1, "chance": 0.12}, "spirit_stone_earth_t1": {"min": 1, "max": 3, "chance": 0.7}, "spirit_stone_earth_t2": {"min": 1, "max": 1, "chance": 0.22}, "spirit_stone_metal_t3": {"min": 1, "max": 1, "chance": 0.06}, "spirit_stone_metal_t4": {"min": 1, "max": 1, "chance": 0.015}, "refine_talisman": {"min": 1, "max": 1, "chance": 0.16}, "recipe_spirit_pill": {"min": 1, "max": 1, "chance": 0.08}},
	},
	"flame_sprite": {
		"id": "flame_sprite",
		"name": "Flame Sprite",
		"base_hp": 20,
		"hp_scale": 7,
		"base_attack": 7,
		"attack_scale": 3,
		"base_defense": 0,
		"defense_scale": 0,
		"exp_base": 12,
		"exp_scale": 5,
		"element": "fire",
		"weak_element": "water",
		"element_attack_ratio": 0.45,
		"drops": {"ore": {"min": 1, "max": 2, "chance": 0.85}, "spirit_sand": {"min": 1, "max": 1, "chance": 0.6}, "beast_core": {"min": 1, "max": 1, "chance": 0.2}, "spirit_stone_fire_t1": {"min": 1, "max": 2, "chance": 0.7}, "spirit_stone_fire_t2": {"min": 1, "max": 1, "chance": 0.22}, "spirit_stone_fire_t3": {"min": 1, "max": 1, "chance": 0.06}, "spirit_stone_fire_t4": {"min": 1, "max": 1, "chance": 0.015}, "spirit_stone_fire_t5": {"min": 1, "max": 1, "chance": 0.005}, "refine_talisman": {"min": 1, "max": 2, "chance": 0.2}, "recipe_might_pill": {"min": 1, "max": 1, "chance": 0.08}},
	},
}

static var _item_defs_cache := {}
static var _equipment_templates_cache := {}


static func task_name(task_type: int) -> String:
	match task_type:
		GameDefs.TaskType.MEDITATE:
			return "打坐"
		GameDefs.TaskType.FARM:
			return "种田"
		GameDefs.TaskType.FORGE:
			return "炼器"
		GameDefs.TaskType.ALCHEMY:
			return "炼丹"
		GameDefs.TaskType.FIGHT:
			return "打怪"
	return "未知"


static func task_duration(task_type: int) -> float:
	match task_type:
		GameDefs.TaskType.MEDITATE:
			return 6.0
		GameDefs.TaskType.FARM:
			return 5.0
		GameDefs.TaskType.FORGE:
			return 4.5
		GameDefs.TaskType.ALCHEMY:
			return 4.5
		GameDefs.TaskType.FIGHT:
			return 30.0
	return 3.0


static func task_zone_id(task_type: int) -> String:
	match task_type:
		GameDefs.TaskType.MEDITATE:
			return "meditate"
		GameDefs.TaskType.FARM:
			return "farm"
		GameDefs.TaskType.FORGE:
			return "forge"
		GameDefs.TaskType.ALCHEMY:
			return "alchemy"
		GameDefs.TaskType.FIGHT:
			return "fight"
	return "idle"



static func resource_name(resource_id: String) -> String:
	var definition = get_item_def(resource_id)
	if definition != null:
		return definition.display_name
	return resource_id


static func alchemy_recipe_def(recipe_id: String) -> Dictionary:
	if not ALCHEMY_RECIPE_DEFS.has(recipe_id):
		return {}
	return ALCHEMY_RECIPE_DEFS[recipe_id].duplicate(true)


static func alchemy_recipe_materials(recipe_id: String) -> Array:
	return alchemy_recipe_def(recipe_id).get("materials", []).duplicate(true)


static func alchemy_recipe_result(recipe_id: String) -> String:
	return alchemy_recipe_def(recipe_id).get("result_item_id", "")


static func attribute_display_name(stat_id: String) -> String:
	if stat_id.begins_with(ELEMENT_ATTRIBUTE_PREFIX):
		return "%s属性" % element_name(element_id_from_attribute(stat_id))
	for attribute_def in EQUIPMENT_ATTRIBUTE_DEFS:
		if attribute_def.get("stat", "") == stat_id:
			return str(attribute_def.get("name", stat_id))
	return stat_id


static func spirit_stone_item_id(stat_id: String, quality: String) -> String:
	var element_id := element_id_from_attribute(stat_id)
	if element_id.is_empty() and ELEMENT_IDS.has(stat_id):
		element_id = stat_id
	return "spirit_stone_%s_%s" % [element_id if not element_id.is_empty() else stat_id, quality]


static func stat_stone_item_id(stat_id: String, quality: String) -> String:
	return "stat_stone_%s_%s" % [stat_id, quality]


static func enhance_stone_item_id(stat_id: String, quality: String) -> String:
	if stat_id.begins_with(ELEMENT_ATTRIBUTE_PREFIX) or ELEMENT_IDS.has(stat_id):
		return spirit_stone_item_id(stat_id, quality)
	return stat_stone_item_id(stat_id, quality)


static func spirit_stone_enhance_amount(quality: String) -> int:
	return int(SPIRIT_STONE_QUALITY_DEFS.get(quality, SPIRIT_STONE_QUALITY_DEFS["t1"]).get("amount", 1))


static func stat_stone_enhance_amount(quality: String) -> int:
	return spirit_stone_enhance_amount(quality)


static func equipment_rarity_name(rarity: String) -> String:
	return EQUIPMENT_RARITY_DEFS.get(rarity, EQUIPMENT_RARITY_DEFS["t1"]).get("name", "一阶")


static func equipment_rarity_multiplier(rarity: String) -> float:
	return float(EQUIPMENT_RARITY_DEFS.get(rarity, EQUIPMENT_RARITY_DEFS["t1"]).get("multiplier", 1.0))


static func neutral_weapon_multiplier(rarity: String) -> float:
	return equipment_rarity_multiplier(rarity) + 0.35


static func element_theme_name(element_id: String) -> String:
	if element_id == "neutral":
		return "无相"
	return ELEMENT_THEME_NAMES.get(element_id, element_name(element_id))


static func equipment_attribute_count(source_level: int, rng: RandomNumberGenerator) -> int:
	var max_attributes := EQUIPMENT_ATTRIBUTE_DEFS.size()
	var upper_threshold := int(ceil(max_attributes * 2.0 / 3.0))
	if source_level < upper_threshold:
		return clampi(source_level, 1, max_attributes)
	return rng.randi_range(upper_threshold, max_attributes)


static func equipment_attribute_count_for_rarity(rarity: String) -> int:
	return clampi(EQUIPMENT_RARITY_ORDER.find(rarity) + 1, 1, EQUIPMENT_RARITY_ORDER.size())


static func equipment_rarity_tier(rarity: String) -> int:
	return clampi(EQUIPMENT_RARITY_ORDER.find(rarity) + 1, 1, EQUIPMENT_RARITY_ORDER.size())


static func element_id_from_attribute(stat_id: String) -> String:
	if stat_id.begins_with(ELEMENT_ATTRIBUTE_PREFIX):
		return stat_id.substr(ELEMENT_ATTRIBUTE_PREFIX.length())
	return ""


static func element_name(element_id: String) -> String:
	match element_id:
		"wood":
			return "木"
		"fire":
			return "火"
		"earth":
			return "土"
		"metal":
			return "金"
		"water":
			return "水"
	return element_id


static func slot_name(slot: String) -> String:
	match slot:
		"weapon":
			return "武器"
		"helmet":
			return "头盔"
		"armor":
			return "护甲"
		"leggings":
			return "腿甲"
		"gloves":
			return "护手"
		"accessory":
			return "饰品"
	return slot


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
	return "物品"


static func get_item_def(item_id: String):
	var data := _item_def_data(item_id)
	if data.is_empty():
		return null
	if not _item_defs_cache.has(item_id):
		_item_defs_cache[item_id] = ItemDefScript.new().setup(item_id, data)
	return _item_defs_cache[item_id]


static func _item_def_data(item_id: String) -> Dictionary:
	if ITEM_DEFS.has(item_id):
		return ITEM_DEFS[item_id]
	if item_id == "refine_talisman":
		return {
			"type": ITEM_TYPE_MATERIAL,
			"name": "Refine Talisman",
			"description": "Material used to add percentage refine affixes.",
			"stackable": true,
			"usable": false,
			"payload": {"refine": true},
		}
	if item_id.begins_with("spirit_stone_"):
		var parsed := _parse_spirit_stone_id(item_id)
		if parsed.is_empty():
			return {}
		var stat_id: String = parsed["stat"]
		var quality: String = parsed["quality"]
		var element_id := element_id_from_attribute(stat_id)
		return {
			"type": ITEM_TYPE_MATERIAL,
			"name": "%s%s灵石" % [element_name(element_id), SPIRIT_STONE_QUALITY_DEFS[quality]["name"]],
			"description": "用于强化%s属性的五行灵石。" % element_name(element_id),
			"stackable": true,
			"usable": false,
			"payload": {"stat": stat_id, "quality": quality, "enhance_amount": spirit_stone_enhance_amount(quality)},
		}
	if item_id.begins_with("stat_stone_"):
		var parsed := _parse_stat_stone_id(item_id)
		if parsed.is_empty():
			return {}
		var stat_id: String = parsed["stat"]
		var quality: String = parsed["quality"]
		return {
			"type": ITEM_TYPE_MATERIAL,
			"name": "%s%s灵石" % [attribute_display_name(stat_id), SPIRIT_STONE_QUALITY_DEFS[quality]["name"]],
			"description": "用于强化%s属性的属性灵石。" % attribute_display_name(stat_id),
			"stackable": true,
			"usable": false,
			"payload": {"stat": stat_id, "quality": quality, "enhance_amount": stat_stone_enhance_amount(quality)},
		}
	return {}


static func _parse_spirit_stone_id(item_id: String) -> Dictionary:
	var prefix := "spirit_stone_"
	if not item_id.begins_with(prefix):
		return {}
	for quality in SPIRIT_STONE_QUALITY_DEFS.keys():
		var suffix := "_%s" % quality
		if item_id.ends_with(suffix):
			var element_id := item_id.substr(prefix.length(), item_id.length() - prefix.length() - suffix.length())
			if ELEMENT_IDS.has(element_id):
				var stat_id := "%s%s" % [ELEMENT_ATTRIBUTE_PREFIX, element_id]
				return {"stat": stat_id, "quality": quality}
	return {}


static func _parse_stat_stone_id(item_id: String) -> Dictionary:
	var prefix := "stat_stone_"
	if not item_id.begins_with(prefix):
		return {}
	for quality in SPIRIT_STONE_QUALITY_DEFS.keys():
		var suffix := "_%s" % quality
		if item_id.ends_with(suffix):
			var stat_id := item_id.substr(prefix.length(), item_id.length() - prefix.length() - suffix.length())
			if STAT_STONE_IDS.has(stat_id):
				return {"stat": stat_id, "quality": quality}
	return {}


static func _has_equipment_attribute(stat_id: String) -> bool:
	for attribute_def in EQUIPMENT_ATTRIBUTE_DEFS:
		if attribute_def.get("stat", "") == stat_id:
			return true
	return false


static func has_item(item_id: String) -> bool:
	return get_item_def(item_id) != null


static func item_definition(item_id: String) -> Dictionary:
	var definition = get_item_def(item_id)
	if definition == null:
		return {}
	return definition.to_item_data()


static func create_stack_item(item_id: String, count: int) -> Dictionary:
	var definition = get_item_def(item_id)
	if definition == null:
		return {}

	return {
		"instance_id": item_id,
		"item_id": item_id,
		"type": definition.type,
		"name": definition.display_name,
		"count": count,
		"stackable": definition.stackable,
		"usable": definition.usable,
		"description": definition.description,
		"payload": definition.payload.duplicate(true),
	}


static func create_skill(skill_id := "spark") -> Dictionary:
	return SKILL_DEFS.get(skill_id, SKILL_DEFS["spark"]).duplicate(true)


static func create_skill_book(skill_id := "spark", count := 1) -> Dictionary:
	return create_stack_item("skill_book_%s" % skill_id, count)


static func create_enemy(level: int, rng = null) -> Dictionary:
	var template_keys := ENEMY_TEMPLATES.keys()
	var template_id := "wandering_imp"
	if rng != null:
		template_id = template_keys[rng.randi_range(0, template_keys.size() - 1)]
	var template: Dictionary = ENEMY_TEMPLATES[template_id]
	var hp: int = int(template["base_hp"] + level * template["hp_scale"])
	return {
		"template_id": template_id,
		"name": template["name"],
		"hp": hp,
		"max_hp": hp,
		"attack": int(template["base_attack"] + level * template["attack_scale"]),
		"defense": int(template["base_defense"] + level * template["defense_scale"]),
		"exp": int(template["exp_base"] + level * template["exp_scale"]),
		"element": template["element"],
		"weak_element": template["weak_element"],
		"element_attack_ratio": float(template["element_attack_ratio"]),
		"drops": template.get("drops", {}).duplicate(true),
	}


static func get_equipment_template(template_id: String):
	if not EQUIPMENT_DEFS.has(template_id):
		return null
	if not _equipment_templates_cache.has(template_id):
		_equipment_templates_cache[template_id] = EquipmentTemplateScript.new().setup(EQUIPMENT_DEFS[template_id])
	return _equipment_templates_cache[template_id]


static func create_equipment(level: int, rng: RandomNumberGenerator, craft_bonus := 0) -> Dictionary:
	var keys := EQUIPMENT_DEFS.keys()
	var template_id: String = keys[rng.randi_range(0, keys.size() - 1)]
	return create_equipment_from_template(template_id, level, rng, craft_bonus)


static func create_equipment_from_template(template_id: String, level: int, rng: RandomNumberGenerator, craft_bonus := 0, forced_element_id := "", forced_rarity := "") -> Dictionary:
	var template = get_equipment_template(template_id)
	if template == null:
		return {}
	var rarity: String = forced_rarity if not forced_rarity.is_empty() else _roll_equipment_rarity(rng)
	var element_id: String = forced_element_id if not forced_element_id.is_empty() else ELEMENT_IDS[rng.randi_range(0, ELEMENT_IDS.size() - 1)]
	var multiplier := neutral_weapon_multiplier(rarity) if element_id == "neutral" else equipment_rarity_multiplier(rarity)
	var base_attributes := _roll_equipment_attributes(level, rng, craft_bonus, multiplier, equipment_attribute_count_for_rarity(rarity))
	if element_id != "neutral":
		_ensure_equipment_element_attribute(base_attributes, element_id, level, rng, craft_bonus, multiplier)
	else:
		_ensure_equipment_stat_attribute(base_attributes, "attack", level, rng, craft_bonus, multiplier)
	var attack_bonus := _sum_attribute_amount(base_attributes, "attack")
	var defense_bonus := _sum_attribute_amount(base_attributes, "defense")
	var rarity_name := equipment_rarity_name(rarity)
	var equipment_name := "%s·%s·%s" % [element_theme_name(element_id), rarity_name, slot_name(template.slot)]
	var equip_requirement := _equipment_requirement(template, level, element_id, rarity)
	return {
		"instance_id": "equipment_%d" % rng.randi(),
		"item_id": template.item_id,
		"type": ITEM_TYPE_EQUIPMENT,
		"name": equipment_name,
		"count": 1,
		"stackable": false,
		"usable": true,
		"description": "%s%s装备，适合长期挂机养成。" % [element_theme_name(element_id), rarity_name],
		"payload": {},
		"slot": template.slot,
		"equipment_level": level,
		"base_attributes": base_attributes,
		"enhanced_attributes": [],
		"refine_affixes": [],
		"enhance_count": 0,
		"refine_count": 0,
		"attack_bonus": attack_bonus,
		"defense_bonus": defense_bonus,
		"enhance_level": 0,
		"enhance_attack_bonus": 0,
		"enhance_defense_bonus": 0,
		"affixes": [],
		"element": element_id,
		"rarity": rarity,
		"equip_requirement": equip_requirement,
		"equipped": false,
	}


static func _equipment_requirement(template, level: int, element_id: String, rarity: String) -> Dictionary:
	var stat_id := ""
	if element_id != "neutral":
		stat_id = "%s%s" % [ELEMENT_ATTRIBUTE_PREFIX, element_id]
	else:
		stat_id = _neutral_equipment_requirement_stat(template)
	return {
		"stat": stat_id,
		"min": max(1, int(level) * equipment_rarity_tier(rarity)),
	}


static func _neutral_equipment_requirement_stat(template) -> String:
	if template.slot == "weapon":
		return "attack"
	if int(template.attack_base) + int(template.attack_scale) > int(template.defense_base) + int(template.defense_scale):
		return "attack"
	return "defense"


static func _roll_equipment_rarity(rng: RandomNumberGenerator) -> String:
	var rarity_roll := rng.randf()
	var accumulated := 0.0
	for rarity in EQUIPMENT_RARITY_ORDER:
		accumulated += float(EQUIPMENT_RARITY_DEFS[rarity].get("chance", 0.0))
		if rarity_roll <= accumulated:
			return rarity
	return "t1"


static func _roll_equipment_attributes(source_level: int, rng: RandomNumberGenerator, craft_bonus := 0, rarity_multiplier := 1.0, fixed_count := 0) -> Array:
	var pool := EQUIPMENT_ATTRIBUTE_DEFS.duplicate(true)
	var attributes := []
	var count := fixed_count if fixed_count > 0 else equipment_attribute_count(source_level, rng)
	for _i in range(count):
		var index := rng.randi_range(0, pool.size() - 1)
		var attribute_def: Dictionary = pool[index]
		pool.remove_at(index)
		var amount := rng.randi_range(int(attribute_def.get("min", 1)), int(attribute_def.get("max", 1)))
		amount += int(source_level * int(attribute_def.get("scale", 0)))
		amount += craft_bonus
		amount = int(round(amount * rarity_multiplier))
		attributes.append({"stat": attribute_def["stat"], "amount": max(1, amount)})
	return attributes


static func _ensure_equipment_element_attribute(attributes: Array, element_id: String, source_level: int, rng: RandomNumberGenerator, craft_bonus := 0, rarity_multiplier := 1.0) -> void:
	var stat_id := "%s%s" % [ELEMENT_ATTRIBUTE_PREFIX, element_id]
	_ensure_equipment_stat_attribute(attributes, stat_id, source_level, rng, craft_bonus, rarity_multiplier)


static func _ensure_equipment_stat_attribute(attributes: Array, stat_id: String, source_level: int, rng: RandomNumberGenerator, craft_bonus := 0, rarity_multiplier := 1.0) -> void:
	for attribute in attributes:
		if attribute.get("stat", "") == stat_id:
			return
	var attribute_def := _equipment_attribute_def(stat_id)
	if attribute_def.is_empty():
		return
	var amount := rng.randi_range(int(attribute_def.get("min", 1)), int(attribute_def.get("max", 1)))
	amount += int(source_level * int(attribute_def.get("scale", 0)))
	amount += craft_bonus
	amount = int(round(amount * rarity_multiplier))
	var element_attribute := {"stat": stat_id, "amount": max(1, amount)}
	if attributes.is_empty():
		attributes.append(element_attribute)
	else:
		attributes[0] = element_attribute


static func _equipment_attribute_def(stat_id: String) -> Dictionary:
	for attribute_def in EQUIPMENT_ATTRIBUTE_DEFS:
		if attribute_def.get("stat", "") == stat_id:
			return attribute_def
	return {}


static func _sum_attribute_amount(attributes: Array, stat_id: String) -> int:
	var value := 0
	for attribute in attributes:
		if attribute.get("stat", "") == stat_id:
			value += int(attribute.get("amount", 0))
	return value
