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
- `base_attributes`：模板基础属性。
- `affixes`：随机词条。
- `enhanced_attributes`：普通强化加法属性。
- `refine_affixes`：洗练百分比词条。
- `enhance_count` / `refine_count`：强化和洗练次数。
- `equip_requirement`：穿戴需求。

## 物品分类

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

- 技能书：未学习对应技能时，使用后加入成员技能并消耗 1 本；已学习时提示且不消耗。
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
- 已实现：装备 `.tres` 补齐 `item_id`、`slot`、`base_name`、`display_name`、`slot_label`、`icon_name`、`icon_path`、`level_scale`、`base_attributes`、`requirement_stat` 和 `description`。
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

- 装备基础属性、强化属性和随机词条通过属性读取入口叠加。
- 五行词条使用 `element_wood`、`element_fire`、`element_earth`、`element_metal`、`element_water`。
- 穿戴时检查 `equip_requirement`；掉落或炼器获得装备时不检查门槛。

## 装备强化与洗练

已实现规则：

- 普通强化消耗装备已有基础属性对应的灵石。
- 消耗数量为 `enhance_count + 1`。
- 普通属性 `attack`、`defense`、`max_hp`、`max_mp`、`root_bone` 消耗通用 `spirit_stone`；五行属性消耗对应五行灵石。
- 当前静态物品 ID 不按阶级拆分，强化值统一为 `+1`；后续阶级通过动态显示或额外数据扩展。
- 强化成功后向 `enhanced_attributes` 追加记录，并增加 `enhance_count`。
- 洗练消耗 `refine_talisman`，消耗数量为 `refine_count + 1`。
- 洗练成功后向 `refine_affixes` 追加百分比词条，并增加 `refine_count`。

规划规则：

- 强化失败率、词条锁定、保底机制和高阶灵石合成暂未实现。
- 阵营装备和套装效果保留为规划设定，见 `docs/item-table.md`。

## 作物与种田

已实现规则：

- 当前所有带 `seed_yield` payload 的 `crop` 都可作为农田种子，包括 `herb` 和 10 种属性作物。
- 种田消耗 1 个作物种子。
- 产量为 `seed_yield + farm_level - 1 + int(执行者总根骨 * 0.05) + 命格修正`。
- 农田等级缩短生长时间，倍率为 `max(0.55, 1.0 - 0.05 * (farm_level - 1))`。
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

规划规则：

- 归元丹、聚灵丹、壮气丹、属性丹、五行丹和对应属性作物仍是规划内容。
- 材料减免、固定额外产物、概率额外产物和持续 Buff 叠加规则需要实现后再转为已实现。

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
