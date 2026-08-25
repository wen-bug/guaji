@tool
class_name EquipmentConfigResource
extends Resource

@export_category("核心装备配置")
@export_group("格式与身份")
## 核心装备资源格式版本，由解析器校验。
@export var config_format_version := 1
## 具体装备的稳定 ID，同时也是索引中的主键。
@export var item_id := ""
## 运行时六槽位模板 ID。
@export_enum("weapon", "helmet", "armor", "leggings", "gloves", "accessory") var template_id := "weapon"
## 武器、饰品的五行原型 ID；固定防具留空。
@export var variant_id := ""
## 实际穿戴槽位，必须与 template_id 一致。
@export_enum("weapon", "helmet", "armor", "leggings", "gloves", "accessory") var slot := "weapon"
## 同槽位具体装备的随机抽取权重。
@export_range(1, 100000, 1) var selection_weight := 1

@export_group("显示信息")
## 不包含阶位前缀的装备名称。
@export var display_name := ""
## 默认图标文件名，不包含扩展名。
@export var icon_name := ""
## 可在 Inspector 中直接拖入的装备图标；为空时使用 icon_path。
@export var icon_texture: Texture2D
## 装备图标资源路径。
@export_file("*.png", "*.webp", "*.svg") var icon_path := ""
## 装备基础说明。
@export_multiline var description := ""
## 详情面板使用的结构化效果说明。
@export var description_effects: Array = []

@export_group("属性生成")
## 两项固定基础属性的保存顺序。
@export var attribute_order: Array[String] = []
## 实例随机属性候选池。
@export var random_attribute_pool: Array[String] = []
## 每个强化点对应的最终面板增量。
@export var attribute_units: Dictionary = {}

@export_group("五阶成长")
## t1 至 t5 的完整配置。每项包含基础属性、随机层、权重、词条、强化和升阶成本。
@export var tiers: Array[Dictionary] = []


func to_equipment_data() -> Dictionary:
	return {
		"format_version": config_format_version,
		"id": item_id,
		"template_id": template_id,
		"variant_id": variant_id,
		"slot": slot,
		"name": display_name,
		"icon_name": icon_name,
		"icon_texture": icon_texture,
		"icon_path": icon_path,
		"description": description,
		"description_effects": description_effects.duplicate(true),
		"selection_weight": selection_weight,
		"attribute_order": attribute_order.duplicate(),
		"random_attribute_pool": random_attribute_pool.duplicate(),
		"attribute_units": attribute_units.duplicate(true),
		"tiers": tiers.duplicate(true),
	}
