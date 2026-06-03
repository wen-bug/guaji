# 物品系统设计

## 概览

物品系统统一管理背包内可显示、可使用或可消耗的内容。当前覆盖六类物品：技能书、装备、材料、作物、丹药、炼丹图纸。

系统采用“双层模型”：
- 静态定义 Resource 化：`ItemDef`、`EquipmentTemplate` 等定义描述不可变的物品和装备模板。
- 背包实例轻量 Dictionary：运行时只保存数量、实例 ID、装备随机属性、强化、词条和临时状态。

新增物品时优先扩展 `DataTables.ITEM_DEFS`。新增装备模板扩展 `DataTables.EQUIPMENT_DEFS`，新增词条扩展 `DataTables.AFFIX_DEFS`。

## 背包实例结构

所有物品实例存放在 `GameState.inventory`。

基础字段：
- `instance_id`：背包内唯一实例 ID。堆叠物品通常等于 `item_id`，装备为独立 ID。
- `item_id`：静态定义 ID。
- `type`：物品分类。
- `name`：显示名。
- `description`：描述文本。
- `count`：数量。装备固定为 1。
- `usable`：是否允许右键使用。
- `payload`：分类专属数据。

装备额外字段：
- `slot`：基础槽位，可为 `weapon`、`helmet`、`armor`、`leggings`、`gloves`、`accessory`。
- `equipped_slot`：实际穿戴槽位。饰品会落到 `accessory_1` 或 `accessory_2`。
- `attack_bonus`：基础攻击加成。
- `defense_bonus`：基础防御加成。
- `element`：装备五行。
- `rarity`：品质。
- `equipped`：是否已装备。
- `enhance_level`：强化等级。
- `enhance_attack_bonus`：强化提供的攻击加成。
- `enhance_defense_bonus`：强化提供的防御加成。
- `affixes`：词条列表，每条包含 `id`、`name`、`stat`、`amount`。

## 物品分类

| 分类 | type | 是否可堆叠 | 是否可使用 | 当前用途 |
| --- | --- | --- | --- | --- |
| 技能书 | `skill_book` | 是 | 是 | 学习技能 |
| 装备 | `equipment` | 否 | 是 | 穿戴、强化、加词条，影响属性 |
| 材料 | `material` | 是 | 否 | 炼器、强化、加词条、家园操作消耗 |
| 作物 | `crop` | 是 | 否 | 炼丹材料，也可作为农田种子 |
| 丹药 | `pill` | 是 | 是 | 一次性恢复、突破或持续 Buff |
| 图纸 | `alchemy_recipe` | 是 | 是 | 学习炼丹配方 |

## 技能书

| item_id | 名称 | 对应技能 | 当前用途 |
| --- | --- | --- | --- |
| `skill_fireball` | 火球术残卷 | `fireball` | 学习火属性攻击技能 |
| `skill_heal` | 回春术残卷 | `heal` | 学习治疗技能 |
| `skill_thunder` | 雷击术残卷 | `thunder` | 学习高伤害技能 |

技能书使用规则：
- 未学习对应技能时，使用后加入 `GameState.skills` 并消耗 1 本。
- 已学习时只提示，不消耗。

## 装备模板与槽位

装备由 `EquipmentTemplate` 静态模板生成，进入背包时创建独立实例。生成时会随机五行与五阶品质，并初始化强化和词条字段。名称格式为 `<五行名>·<阶位名>·<槽位名>`，例如 `赤焰·三阶·武器`。

五阶品质按慢热挂机节奏分布：`t1` 一阶 55%、`t2` 二阶 28%、`t3` 三阶 12%、`t4` 四阶 4%、`t5` 五阶 1%。基础属性倍率分别为 `1.00`、`1.12`、`1.28`、`1.50`、`1.80`，五阶是周级长期目标而非短时毕业。

| 模板 item_id | 基础槽位 | 装备定位 |
| --- | --- | --- |
| `weapon` | `weapon` | 主要增加攻击 |
| `helmet` | `helmet` | 主要增加防御 |
| `armor` | `armor` | 主要增加防御 |
| `leggings` | `leggings` | 主要增加防御 |
| `gloves` | `gloves` | 兼顾攻击和防御 |
| `accessory` | `accessory` | 兼顾攻击、防御或特殊属性 |

实际穿戴槽位：
- `weapon`：武器。
- `helmet`：头盔。
- `armor`：护甲。
- `leggings`：腿甲。
- `gloves`：护手。
- `accessory_1`：饰品槽 1。
- `accessory_2`：饰品槽 2。

饰品穿戴规则：
- 优先穿到空的 `accessory_1`。
- `accessory_1` 已占用时，优先穿到空的 `accessory_2`。
- 两个饰品槽都满时，默认替换 `accessory_1`。

属性统计规则：
- `total_attack()` 遍历所有已装备实例，累计基础攻击、强化攻击和攻击类词条。
- `total_defense()` 遍历所有已装备实例，累计基础防御、强化防御和防御类词条。
- 最大生命、最大灵力、根骨和五行类词条通过对应属性读取入口叠加。

## 装备强化与词条

装备和武器可以通过背包右键菜单操作：
- `强化`：消耗材料，成功后 `enhance_level += 1`，按装备定位增加 `enhance_attack_bonus` 或 `enhance_defense_bonus`。第一版必定成功，不做失败率。
- `加词条`：消耗材料，从 `AFFIX_DEFS` 中随机追加一个属性词条到 `affixes`。

词条池第一版包含：
- 攻击加成。
- 防御加成。
- 最大生命加成。
- 最大灵力加成。
- 根骨加成。
- 单一五行加成。

## 材料

| item_id | 名称 | 获取方式 | 当前用途 |
| --- | --- | --- | --- |
| `ore` | 矿石 | 初始 3 个；战斗掉落 | 炼器、强化 |
| `spirit_sand` | 灵砂 | 战斗概率掉落 | 炼器、加词条 |
| `beast_core` | 妖核 | 战斗概率掉落 | 高价值强化或后续配方 |

炼器当前消耗材料生成一件随机装备。根骨会为炼器结果提供 `int(root_bone * 0.2)` 的额外属性入口。

## 作物与农田种子

| item_id | 名称 | 获取方式 | 当前用途 | seed_yield |
| --- | --- | --- | --- | --- |
| `herb` | 草药 | 初始 4 个；农田产出 | 炼丹材料、农田种子 | 3 |
| `rice` | 灵米 | 农田产出 | 炼丹材料、农田种子 | 2 |
| `mushroom` | 灵菇 | 农田产出 | 炼丹材料、农田种子 | 1 |

种田操作规则：
- 点击家园 `farmland` 节点打开种田 GUI，不加入任务队列。
- 自动寻找背包中第一个可用作物作为种子。
- 消耗 1 个作物种子。
- 产量为 `seed_yield + farm_level - 1`。
- `farm_level` 初始为 1，暂由种田熟练度阶段提升。
- 若背包中没有作物种子，则操作失败并提示。
- 农田显示使用 `farmland` 下 5 个 `Marker2D` 槽位，按 `crop` 模板复制作物节点；视觉显示最多 5 个，额外产量只进入背包。

## 丹药与突破道具

丹药 `payload` 统一包含 `effect_mode`：
- `instant`：一次性丹药，使用后立即结算 `hp`、`mp`、突破等效果。
- `duration`：持续丹药，使用后加入 `active_buffs`，按剩余时间影响属性、恢复或生产/战斗加成。

| item_id | 名称 | effect_mode | 获取方式 | 当前用途 |
| --- | --- | --- | --- | --- |
| `pill` | 调息丹 | `instant` | 调息丹方炼制 | 恢复生命和灵力 |
| `life_pill` | 归元丹 | `instant` | 归元丹方炼制 | 恢复生命 |
| `spirit_pill` | 聚灵丹 | `instant` | 聚灵丹方炼制 | 恢复灵力 |
| `might_pill` | 壮气丹 | `duration` | 壮气丹方炼制 | 在持续时间内提供属性 Buff |
| `breakthrough_pill` | 破境丹 | `instant` | 战斗或任务掉落 | 达到等级上限后突破下一阶段 |

破境丹规则：
- 角色达到当前 10 级阶段上限时可使用。
- 使用后消耗 1 个 `breakthrough_pill`，`stage += 1`，`level_cap += 10`。
- 若角色尚未达到当前等级上限，则不消耗。
- 若 `root_bone > level`，角色也可不消耗道具完成突破。

持续 Buff 规则：
- 使用持续丹药后写入 `GameState.active_buffs`。
- 每帧由 `GameState.update_buffs(delta)` 扣减剩余时间。
- 到期 Buff 自动移除。
- 属性读取时通过 Buff 入口叠加对应加成。

## 炼丹图纸与丹方

图纸物品类型为 `alchemy_recipe`，归入背包“图纸”分类。

| item_id | 名称 | 学习产物 | 获取方式 |
| --- | --- | --- | --- |
| `recipe_pill` | 调息丹方 | `pill` | 初始背包 |
| `recipe_life_pill` | 归元丹方 | `life_pill` | 战斗或任务掉落 |
| `recipe_spirit_pill` | 聚灵丹方 | `spirit_pill` | 战斗或任务掉落 |
| `recipe_might_pill` | 壮气丹方 | `might_pill` | 战斗或任务掉落 |

图纸使用规则：
- 使用后学习对应丹方，写入 `known_alchemy_recipes`。
- 成功学习后消耗 1 张图纸。

炼丹操作规则：
- 点击家园 `alchemy` 节点打开炼丹 GUI，不加入任务队列。
- 只从 `known_alchemy_recipes` 中随机选择产物。
- 没有已学习丹方时炼丹失败并提示。
- 产出丹药后，根骨提供 `min(0.35, root_bone * 0.015)` 的额外产出概率。

## 右键菜单行为

右键物品打开菜单。

使用效果：
- 技能书：未学习则学习并消耗 1 本；已学习则提示，不消耗。
- 装备：穿戴到对应槽位；若目标槽位已有装备，则替换旧装备的穿戴状态。
- 丹药：一次性丹药立即结算；持续丹药加入 `active_buffs`；破境丹触发等级上限突破。
- 图纸：学习丹方并消耗 1 张；已学习则不消耗。
- 材料与作物：当前不可直接使用。

装备额外操作：
- `强化`：消耗材料并提升强化等级和强化加成。
- `加词条`：消耗材料并追加一个随机属性词条。

丢弃效果：
- 堆叠物品：每次丢弃 1 个，数量归零后从背包移除。
- 装备：直接移除该装备实例；若正在装备，先卸下再移除。

## UI 表现

背包由顶部“背包”按钮打开，显示为右侧浮层。

浮层包含：
- 分类切换：技能书、装备、材料、作物、丹药、图纸。
- 物品列表：显示名称和数量；装备显示槽位、是否已装备、强化等级、攻防加成和词条。
- 右键菜单：使用、丢弃；装备额外显示强化和加词条。

HUD 顶部资源摘要显示分类总量：作物、材料、丹药、图纸，并显示角色等级阶段、农田等级和活跃 Buff 状态。

## DataTables 约定

`DataTables` 提供统一入口，避免 UI、任务和背包逻辑手写重复字段：
- `ITEM_DEFS`：通用静态物品定义。
- `EQUIPMENT_DEFS`：装备模板定义。
- `AFFIX_DEFS`：装备词条池。
- `ENEMY_TEMPLATES`：敌人模板和掉落表。
- 堆叠物品创建：创建包含 `item_id`、`type`、`count`、`payload` 的轻量实例。
- 装备创建：创建包含五阶品质、五行、强化字段和词条列表的独立实例。
- 突破道具查询：通过 `breakthrough_pill` 的 payload 和角色阶段状态判断是否可突破。

## 扩展约定

后续可扩展：
- 图标字段：`icon_path`。
- 品质颜色和装备等级需求。
- 丹方 UI、配方材料表、炼丹失败率。
- 种子选择 UI、农田升级消耗、批量种植、不同作物外观。
- 强化失败率、词条洗练、词条锁定、保底机制。
- 持续 Buff 叠加规则和任务次数型 Buff。

## 装备属性条目与灵石材料

装备基础属性从人物属性模板中抽取，当前模板包含 `max_hp`、`max_mp`、`attack`、`defense`、`root_bone`、`element_wood`、`element_fire`、`element_earth`、`element_metal`、`element_water`。生成装备时按来源等级决定抽取条数，并保证 `base_attributes` 中的 `stat` 不重复；每件装备会保留自身五行基础属性，确保可用对应五行灵石长期强化。

装备实例字段补充：
- `equipment_level`：生成来源等级。炼器取玩家等级，掉落取敌人等级。
- `base_attributes`：基础属性数组，每条包含 `stat` 和 `amount`。
- `enhanced_attributes`：普通强化数组，每条包含 `stat`、`amount`、`quality`。
- `refine_affixes`：洗练百分比词条数组，每条包含 `stat` 和 `percent`。
- `enhance_count`：普通强化次数，用于计算下一次灵石消耗。
- `refine_count`：洗练次数，用于计算下一次洗练符消耗。

五行灵石属于材料分类，物品 ID 采用 `spirit_stone_<element>_<tier>` 结构，例如 `spirit_stone_fire_t1`、`spirit_stone_earth_t3`、`spirit_stone_water_t5`。灵石 payload 包含：
- `stat`：对应的五行人物属性，例如 `element_fire`。
- `quality`：阶位，当前为 `t1`、`t2`、`t3`、`t4`、`t5`。
- `enhance_amount`：该阶位提供的加法强化值，分别为 `1`、`2`、`4`、`7`、`11`。

五行灵石掉落按长期挂机设计：`t1` 高频、`t2` 稳定积累、`t3` 数日目标、`t4` 低概率高价值、`t5` 极低概率周级惊喜。当前不提供合成系统。

普通强化规则：
- 右键装备选择“强化”。
- 只能消耗装备已有五行基础属性对应的灵石。
- 自动优先使用高阶灵石，再按装备基础属性顺序选择可强化属性，顺序为 `t5 → t4 → t3 → t2 → t1`。
- 消耗数量为 `enhance_count + 1`。
- 成功后向 `enhanced_attributes` 追加一条加法强化记录，并增加 `enhance_count`。

洗练规则：
- 洗练材料为 `refine_talisman`，显示名为“洗练符”。
- 右键装备选择“洗练”。
- 消耗数量为 `refine_count + 1`。
- 成功后随机抽取一项人物属性，向 `refine_affixes` 追加百分比词条，并增加 `refine_count`。
- 洗练百分比只影响该装备贡献的对应属性，不直接修改人物基础属性。
