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
	return self
