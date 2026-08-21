@tool
## 装备模板静态资源。Inspector 中直接显示中文分类，悬停字段可查看中文用途说明。
class_name EquipmentTemplate
extends Resource

@export_category("装备模板配置（悬停字段查看说明）")
@export_group("基础信息｜ID、槽位、名称")
## 装备模板的稳定内容 ID；存档中的装备实例通过它解析当前定义。
@export var item_id := ""
## 装备模板槽位 ID，例如 weapon、armor 或 accessory。
@export_enum("weapon", "helmet", "armor", "leggings", "gloves", "accessory") var slot := "weapon"
## 不包含阶位前缀的装备基础名称。
@export var base_name := ""
## Inspector 和静态列表使用的显示名称；运行时实例可追加阶位文本。
@export var display_name := ""
## HUD 中显示的槽位中文名称。
@export var slot_label := ""

@export_group("图标｜贴图与资源路径")
## Inspector 中直接拖入的装备图标，运行时优先于 icon_path。
@export var icon_texture: Texture2D
## 默认图标文件名，不包含扩展名。
@export var icon_name := ""
## 图标资源路径；icon_texture 为空时使用。
@export var icon_path := ""

@export_group("说明｜需求与效果描述")
## 装备需求所对应的属性 ID；空字符串表示没有属性需求。
@export var requirement_stat := ""
## 装备详情的基础说明文本，不写入运行时阶位名称。
@export_multiline var description := ""
## 详情面板使用的结构化效果说明列表，不直接参与战斗结算。
@export var description_effects := []

@export_group("阶位数值｜固定基础属性")
## 各阶固定基础属性。键为 t1..t5，值为 [{"stat": String, "amount": int}]。
@export var tier_base_attributes: Dictionary = {}
## 同一槽位下可随机选择的基础原型。每个原型可配置名称、图标和 tier_base_attributes。
@export var attribute_variants: Dictionary = {}

@export_group("实例随机属性｜属性池、条数与预算")
## 实例创建和升阶时用于追加属性的候选属性 ID。
@export var random_attribute_pool: Array[String] = []
## 各阶追加的随机属性条数。键为 t1..t5。
@export var tier_random_attribute_counts: Dictionary = {}
## 各阶随机属性共享的点数预算。气血和法力在生成时应用单位换算。
@export var tier_random_attribute_budgets: Dictionary = {}


func setup(data: Dictionary) -> EquipmentTemplate:
	item_id = data.get("item_id", "")
	slot = data.get("slot", "weapon")
	base_name = data.get("base_name", data.get("name", ""))
	display_name = data.get("display_name", base_name)
	slot_label = data.get("slot_label", slot)
	icon_name = data.get("icon_name", item_id)
	icon_path = data.get("icon_path", "res://assets/equipment/%s.png" % icon_name)
	requirement_stat = data.get("requirement_stat", "")
	description = data.get("description", "")
	description_effects = data.get("description_effects", []).duplicate(true)
	tier_base_attributes = data.get("tier_base_attributes", {}).duplicate(true)
	attribute_variants = data.get("attribute_variants", {}).duplicate(true)
	random_attribute_pool.assign(data.get("random_attribute_pool", []))
	tier_random_attribute_counts = data.get("tier_random_attribute_counts", {}).duplicate(true)
	tier_random_attribute_budgets = data.get("tier_random_attribute_budgets", {}).duplicate(true)
	return self
