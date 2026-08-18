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

@export_group("使用规则｜堆叠、使用范围、附加数据")
## 是否允许同 ID 物品合并为一个堆叠。
@export var stackable := true
## 是否允许玩家主动使用该物品。
@export var usable := false
## 可使用场景范围；none 表示没有主动使用入口。
@export_enum("none", "home", "combat") var use_scope := "none"
## 物品获得时关联的五行或成长目标；无目标时填写 none。
@export_enum("none", "attack", "defense", "max_hp", "max_mp", "root_bone", "wood", "fire", "earth", "metal", "water") var gain_target := "none"
## 按物品类型解释的附加数据，例如技能书的 skill_id。
@export var payload: Dictionary = {}


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
	use_scope = data.get("use_scope", "none")
	gain_target = data.get("gain_target", "none")
	payload = data.get("payload", {}).duplicate(true)
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
		"use_scope": use_scope,
		"gain_target": gain_target,
		"payload": payload.duplicate(true),
	}
