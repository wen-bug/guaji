# 物品系统设计

## 概览

本文档描述物品、背包、装备、炼丹、种田和商店的系统规则。具体已实现物品、配方、技能、装备模板、敌人掉落以 `docs/item-table.md` 和 `scripts/game/data/data_tables.gd` 为准。

状态标记：

- 已实现：当前代码已有入口或数据支撑。
- 规划：保留设计方向，但不能当作当前已上线能力。

物品系统采用双层模型：

- 已实现：静态定义集中在 `DataTables.ITEM_DEFS`、`EQUIPMENT_DEFS`、`SKILL_DEFS`、`ALCHEMY_RECIPE_DEFS` 等表。
- 已实现：背包运行时实例使用轻量 `Dictionary`，保存数量、实例 ID、装备随机属性、强化、洗练和临时状态。

## 背包实例结构

所有物品实例存放在 `GameState.inventory`。

已实现的基础字段：

- `instance_id`：背包内唯一实例 ID。堆叠物品通常等于 `item_id`，装备为独立 ID。
- `item_id`：静态定义 ID，也是代码调用主键和默认美术素材名。
- `item_no`：稳定整数编号，用于统计、导出和日志聚合；新增物品只追加编号，不复用、不重排。
- `icon_name`：图标素材名，默认等于 `item_id`。
- `icon_path`：图标资源路径，默认 `res://assets/items/<item_id>.png`。
- `type`：物品分类。
- `name`：显示名。
- `description`：描述文本。
- `count`：数量。装备固定为 1。
- `stackable`：是否堆叠。
- `usable`：是否允许使用。
- `payload`：分类专属数据。
- `obtain_source`：来源标记，当前用 `drop`、`non_drop`、`debug` 区分。
- `gain_target`：成长或强化倾向，用于 UI 标签。

已实现的装备额外字段：

- `slot`：基础槽位，可为 `weapon`、`helmet`、`armor`、`leggings`、`gloves`、`accessory`。
- `equipped_by`：当前穿戴者成员 ID，空字符串表示未穿戴。
- `equipped_slot`：实际穿戴槽位。饰品会落到 `accessory_1` 或 `accessory_2`。
- `rarity` / `equipment_level`：阶位与装备等级。
- `base_attributes`：装备实例按阶位预算随机生成的属性。
- `affixes`：已废弃的旧数值词条字段；新装备始终为空。
- `enhanced_attributes`：普通强化加法属性。
- `refine_affixes`：已废弃的旧洗练百分比词条字段；新装备始终为空。
- `enhance_count` / `refine_count`：强化和洗练次数。
- `equip_requirement`：穿戴需求。
- `description_effects`：结构化描述效果，只保存公式参数，不保存已渲染文本或颜色。

## 富文本描述数据格式

物品详情使用 `RichTextLabel`，由 `RichTextDescriptionRenderer` 根据物品实例和当前选中角色生成语义颜色。普通 `description` 只保存不参与计算的背景说明；装备属性和公式必须保存为结构化数据。

`RichTextLabel` 是场景中的 `Control` 节点，应放在 `.tscn`，不能作为物品 `.tres` 本身。装备 `.tres` 只保存 `description_effects` 数据，运行时由详情面板把资源数据交给渲染器。这样新增物品只需编辑资源或数据表，不需要为每件物品创建一个 UI 节点。

装备属性会自动渲染，无需重复写入描述：

- `base_attributes`：显示为“随机属性”。
- `enhanced_attributes`：显示为“强化”。

特殊公式写入 `description_effects`。元素伤害公式格式：

```gdscript
"description_effects": [
	{
		"kind": "element_damage_formula",
		"element": "fire",
		"stat": "element_fire",
		"multiplier": 0.75,
		"rounding": "floor",
	}
]
```

同一内容序列化到装备 `.tres` 时使用 Godot 的数组和字典格式：

```ini
description_effects = [{
"element": "fire",
"kind": "element_damage_formula",
"multiplier": 0.75,
"rounding": "floor",
"stat": "element_fire"
}]
```

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `kind` | 是 | 当前支持 `element_damage_formula`、`text` |
| `element` | 元素公式必填 | `wood`、`fire`、`earth`、`metal`、`water` |
| `stat` | 否 | 取值属性；元素公式默认使用 `element_<element>` |
| `multiplier` | 否 | 公式倍率，默认 `1.0` |
| `rounding` | 否 | `floor`、`round`、`ceil`，默认 `floor` |
| `text` | 文本效果必填 | `kind=text` 的显示文字 |
| `role` | 否 | 文本语义颜色，默认 `primary` |

有选中角色时，公式显示实时数值与结果，例如“造成火属性伤害（火属性 32 × 0.75 = 24）”；没有角色上下文时只显示“火属性 × 0.75”，不以 0 冒充实际属性。

语义颜色：

| role | 用途 | 颜色 |
| --- | --- | --- |
| `primary` | 正文 | `#F1E7D2` |
| `secondary` | 标签、分隔和次要说明 | `#B8B0A2` |
| `value` | 属性和普通数值 | `#7DD3FC` |
| `multiplier` / `warning` | 倍率、持续时间、警告 | `#F2C14E` |
| `result` / `positive` | 公式结果、成功状态 | `#86D98B` |
| `error` | 不足、失败 | `#FF6B6B` |
| `element_<id>` | 五行文本 | 木绿、火红、土黄、金灰、水蓝 |

装备名称按 `t1..t5` 使用灰、绿、蓝、紫、金阶位色。颜色只增强信息，关键状态仍必须保留文字。

维护边界：

- `description_effects` 只负责展示，不会改变战斗结算。
- 会造成真实战斗效果的装备必须同时拥有已实现的 `effects` 或对应属性字段，二者参数必须来自同一数据定义，不能只写彩色描述。
- 存档保存结构化字段，绝不保存 BBCode、最终句子或公式结果；角色属性变化后重新渲染。
- 装备实例优先使用自身 `description_effects`，旧存档缺失时从 `EquipmentTemplate` / `EQUIPMENT_DEFS` 回填。
- `description_effects` 是可选的新增字段，加载旧档时由背包实例规范化补齐空数组，不单独提升存档 schema；若以后改变字段含义或删除字段，则必须增加 schema 迁移。
- 未支持的 `kind` 默认不显示；新增类型时必须扩展渲染器、本文字段表和回归测试。
- 渲染器使用 `push_color()`，不解析物品名称或描述中的 BBCode，避免特殊字符破坏格式。
- 当前装备尚无通用“公式伤害”结算入口；在真实 `effects` 或属性结算逻辑接通前，元素伤害公式只能用于开发验证，不能作为已生效的正式装备效果发布。

## 物品分类

掉落物品可通过 `drop_rarity` 标记五档稀有度；敌人掉落配置使用 `drop_categories` 或模板物品列表限制可掉落类别。掉落概率由敌人阶级基础概率和阶内等级修正共同决定。

已实现分类：

| 分类 | type | 是否可堆叠 | 是否可使用 | 当前用途 |
| --- | --- | --- | --- | --- |
| 技能书 | `skill_book` | 是 | 是 | 学习技能 |
| 装备 | `equipment` | 否 | 是 | 穿戴、强化、洗练，影响属性 |
| 材料 | `material` | 是 | 视定义 | 炼器、强化、洗练、招募和其他消耗 |
| 作物 | `crop` | 是 | 否 | 炼丹材料，也可作为农田种子 |
| 丹药 | `pill` | 是 | 是 | 恢复、突破或后续持续 Buff |
| 图纸 | `alchemy_recipe` | 是 | 是 | 学习炼丹配方 |

## 使用与丢弃

已实现规则：

- 技能书：一次性消耗品。未学习对应技能时，使用后追加到成员技能并消耗 1 本；已学习时提示且不消耗。人物已学技能永久锁定，不提供替换、遗忘或移除入口。
- 装备：使用后尝试穿戴到当前选中成员的对应槽位；同一装备只能由一名成员穿戴。
- 丹药：一次性丹药立即结算；突破丹在达到等级上限时用于突破。
- 图纸：使用后学习对应丹方，写入 `known_alchemy_recipes`，成功后消耗 1 张。
- 材料与作物：默认不可直接使用，由家园、炼丹、炼器、强化和洗练流程消耗。
- 堆叠物品丢弃时每次减少 1 个，数量归零后从背包移除。
- 装备丢弃时直接移除实例；若正在装备，先卸下再移除。

规划规则：

- 持续丹药写入 `active_buffs` 并随时间扣减。
- 战斗类物品可按 `use_scope` 区分家园、战斗和不可使用入口。

## 装备模板与槽位

已实现模板包括武器、头盔、护甲、胫甲、护手和饰品。装备进入背包时创建独立实例，名称格式为 `<阶位名>·<装备模板名称>`。阶位名只属于运行时装备实例显示，不写入静态装备资源。

装备模板资源：

- 已实现：每个 `EQUIPMENT_DEFS` 模板在 `resources/equipment/<template_id>.tres` 有对应 `EquipmentTemplate` 资源。
- 已实现：装备 `.tres` 保留 `icon_texture: Texture2D` 空字段，方便在 Inspector 手动拖入图片。
- 已实现：装备 `.tres` 只保留 `item_id`、`slot`、`base_name`、`display_name`、`slot_label`、`icon_name`、`icon_path`、`requirement_stat`、`description` 和 `description_effects`；不再定义固定基础属性。
- 已实现：装备默认图标路径为 `res://assets/equipment/<template_id>.png`；背包装备图标优先读取装备 `.tres` 的 `icon_texture`，再回退到实例 `icon_path` 和占位色块。

实际穿戴槽位：

- `weapon`：武器。
- `helmet`：头盔。
- `armor`：护甲。
- `leggings`：胫甲。
- `gloves`：护手。
- `accessory_1`：饰品槽 1。
- `accessory_2`：饰品槽 2。

饰品穿戴规则：

- 优先穿到空的 `accessory_1`。
- `accessory_1` 已占用时，优先穿到空的 `accessory_2`。
- 两个饰品槽都满时，默认替换 `accessory_1`。
- 给其他成员穿戴已装备物品时，会自动从旧成员身上卸下。

属性统计规则：

- 新装备按阶位获得可分配属性点：一至五阶分别为 `20/50/100/180/300`。
- 每件装备随机生成 1 至 5 条不重复属性；每条以 50% 概率从普通池或五行池选择。
- 普通池为攻击、防御、生命、法力、根骨；五行池为木、火、土、金、水。
- 点数平均分配到随机属性，无法整除的余数直接舍弃；装备等级不影响属性点预算。

- 装备随机属性和强化属性通过属性读取入口叠加。
- 五行词条使用 `element_wood`、`element_fire`、`element_earth`、`element_metal`、`element_water`。
- 穿戴时检查 `equip_requirement`；掉落或炼器获得装备时不检查门槛。

## 装备强化与洗练

已实现规则：

- 每次强化从装备已有的随机属性中随机选择一条，选中属性直接 `+1`。
- 普通强化消耗随机选中属性对应的灵石；普通属性使用通用灵石，五行属性使用对应五行灵石。
- 强化上限按装备阶位为：一阶 `+5`、二阶 `+10`、三阶 `+20`、四阶 `+30`、五阶 `+40`。
- 单次消耗为“阶位基础消耗 + `floor((下一强化等级 - 1) / 5)`”；阶位基础消耗依次为 `1/2/3/5/8`。
- 普通属性 `attack`、`defense`、`max_hp`、`max_mp`、`root_bone` 消耗通用 `spirit_stone`；五行属性消耗对应五行灵石。
- 当前静态物品 ID 不按阶级拆分，强化值统一为 `+1`；每次只强化随机命中的一条装备属性。
- 强化成功后向 `enhanced_attributes` 追加记录，并增加 `enhance_count`。
- 洗练消耗 `refine_talisman`，消耗数量为 `refine_count + 1`。
- 洗练会重新随机装备属性的数量、种类和点数分配，并按原强化等级随机重新分配强化点；强化等级不变。
- 洗练不再生成百分比词条，`refine_affixes` 固定为空。

规划规则：

- 强化失败率、词条锁定、保底机制和高阶灵石合成暂未实现。
- 阵营装备和套装效果保留为规划设定，见 `docs/item-table.md`。

## 作物与种田

已实现规则：

- 当前所有带 `seed_yield` payload 的 `crop` 都可作为农田种子，包括 `herb` 和 10 种属性作物。
- 种田消耗 1 个作物种子。
- 产量为 `seed_yield + farm_level - 1 + int(执行者总根骨 * 0.05) + 命格修正`。
- 农田等级缩短生长时间，倍率为 `max(0.55, 1.0 - 0.05 * (farm_level - 1))`；基础草药为 600 秒，属性作物为 900-1800 秒。
- 农田可使用 `farm_speed_talisman` 作为加速类材料入口。

规划规则：

- 批量种植、作物外观差异和农田升级消耗继续保留为后续扩展。

## 炼丹与丹方

已实现规则：

- 图纸物品类型为 `alchemy_recipe`，payload 中保存 `recipe_id`。
- 使用图纸后学习丹方，炼丹面板只显示 `known_alchemy_recipes` 中已学丹方。
- `ALCHEMY_RECIPE_DEFS` 定义丹方产物和材料。
- 当前已实现丹方为调息丹：`pill = herb x2`。
- 炼丹可按材料库存计算最大制作数量，批量扣除材料并添加产物。
- 额外出丹概率通过执行者根骨和命格修正。
- 炼丹是单队列在线计时任务，1 级建筑每份基础耗时 600 秒；完成后需要手动领取。

规划规则：

- 归元丹、聚灵丹、壮气丹、属性丹、五行丹和对应属性作物仍是规划内容。
- 材料减免、固定额外产物、概率额外产物和持续 Buff 叠加规则需要实现后再转为已实现。

## 正式开局与资源闭环

正式新档拥有 `spirit_stone x1`、`herb x1`、`recipe_pill x1`，以及雷击术、蚀骨毒雾、回春术、燃锋诀、玄甲术技能书各 1 本。版本 9 迁移会为旧存档补齐尚未持有且尚未学会的技能书，不会重复发放。技能书不进入敌人掉落、商店或生产经济；其余测试物资仍由项目设置 `game/development/seed_test_inventory` 显式开启，默认关闭。

| 资源 | 当前来源 | 当前消耗 |
| --- | --- | --- |
| `herb` | 农田；林狼 55%，1-2 个 | 种田、调息丹、农田/炼丹升级 |
| `ore` | 林狼 30%，1 个 | 炼器基础消耗 4 个、炼器升级 |
| `spirit_stone` | 林狼 10%，1 个 | 招募、招募升级、普通属性强化 |
| 装备 | 炼器；林狼 5% 独立装备掉落 | 穿戴、强化、洗练、替换 |

炼器只消耗 `ore`，不能再用其他材料代替。1 级炼器耗时 900 秒；1 级炼丹每份耗时 600 秒。生产只在程序运行时推进，关闭游戏后从保存进度继续，不结算离线时间。

首轮中位节奏目标为：5 分钟内招募，20 分钟内收获，40 分钟内领取首次炼丹或炼器结果，45-60 分钟完成穿戴、账号升级和一次建筑升级。

## 商店

规划：商店是家园随机补给入口，用来把灵石转化为材料、种子、丹药、图纸和少量稀有成长物品。当前文档保留规则，但若 `DataTables` 中没有商品池和存档字段，不应按已实现处理。

规划货架结构：

- `slot_index`：槽位序号。
- `item_id`：商品物品 ID。
- `count`：购买后获得数量。
- `price_item_id`：价格物品，第一版固定为 `spirit_stone`。
- `price_amount`：价格数量。
- `rarity`：商品稀有度，影响价格倍率和显示颜色。
- `sold`：是否已购买。
- `source`：固定为 `shop`，用于后续统计来源。

规划刷新规则：

- 每轮随机刷新 6 个商品槽位。
- 自动刷新间隔为 600 秒。
- 手动刷新消耗 `spirit_stone x1`。
- 已购买槽位在本轮保持售罄状态，直到下一次刷新。
- 图纸池优先从尚未学习的丹方中抽取；若图纸池为空，回退到丹药或材料池。

规划商品池：

| 池 | 权重 | 商品方向 |
| --- | ---: | --- |
| `basic_material` | 40 | 草药、矿石、属性作物等基础材料和作物 |
| `production_boost` | 20 | 丰收符、洗练符、强化灵石 |
| `alchemy_recipe` | 15 | 已配置但未学习的丹方图纸 |
| `pill` | 15 | 调息丹、破境丹和后续属性丹药 |
| `rare` | 10 | 技能书、较高阶灵石、稀有图纸或特殊材料 |

## UI 表现

已实现规则：

- 背包由 HUD 打开，显示 5x5 格子。
- 支持分类切换、悬浮详情、右键菜单和双击使用。
- 装备显示槽位、穿戴状态、强化次数、基础属性和词条。
- HUD 顶部资源摘要显示分类总量、角色等级阶段、农田等级和活跃 Buff 状态。

规划规则：

- 商店浮层包含随机货架、刷新倒计时、手动刷新按钮、商品详情和购买按钮。
- 商品格显示图标占位、名称、数量、价格和售罄状态。

## DataTables 约定

`DataTables` 提供统一入口，避免 UI、任务和背包逻辑手写重复字段：

- `ITEM_ID_*`：物品代码主键常量，例如 `DataTables.ITEM_ID_HERB`。
- `ITEM_DEFS`：通用静态物品定义。
- `SKILL_DEFS`：技能定义。
- `ALCHEMY_RECIPE_DEFS`：炼丹配方定义。
- `EQUIPMENT_DEFS`：装备模板定义。
- `EQUIPMENT_ATTRIBUTE_DEFS`：装备随机词条池。
- `ENEMY_TEMPLATES`：敌人静态数值和掉落配置。
- `ENEMY_SCENE_PATHS`：敌人场景路径映射。
- `item_no(item_id)`：按 `item_id` 获取稳定统计编号。
- `item_id_from_no(item_no)`：按统计编号反查 `item_id`。
- `item_icon_name(item_id)`：获取图标素材名，默认等于 `item_id`。
- `item_icon_path(item_id)`：获取图标资源路径，默认 `res://assets/items/<item_id>.png`。
- `equipment_icon_name(template_id)`：获取装备图标素材名，默认等于装备模板 ID。
- `equipment_icon_path(template_id)`：获取装备图标资源路径，默认 `res://assets/equipment/<template_id>.png`。
- `item_icon_texture(item_id)` / `equipment_icon_texture(template_id)` / `skill_icon_texture(skill_id)`：优先从对应 `.tres` 读取手动配置的 `icon_texture`。

调用示例：

- `DataTables.item_definition(DataTables.ITEM_ID_HERB)`
- `game_state.inventory_item_count(DataTables.ITEM_ID_HERB)`
- `DataTables.item_no(DataTables.ITEM_ID_HERB)`

## 扩展约定

- 新增物品优先补 `DataTables.ITEM_ID_*`、`DataTables.ITEM_DEFS` 和稳定 `item_no`，再同步 `docs/item-table.md`。
- 新增物品规则或交互流程同步更新本文档。
- 新增规划设定时必须标注“规划”，实现后再移动到“已实现”段落。
