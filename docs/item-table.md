# 详细物品表

本文档是 `scripts/game/data/data_tables.gd` 的文档化索引。除“规划物品与装备设定”外，已实现内容必须与当前代码数据表一致。

## 已实现：物品分类

| type | 中文分类 | 用途 |
| --- | --- | --- |
| `skill_book` | 技能书 | 使用后学习技能 |
| `equipment` | 装备 | 穿戴、强化、洗练 |
| `material` | 材料 | 消耗、强化、洗练、招募等 |
| `crop` | 作物 | 农田种子和炼丹材料 |
| `pill` | 丹药 | 恢复、突破或 Buff |
| `alchemy_recipe` | 炼丹图纸 | 使用后学习丹方 |

## 已实现：物品定义字段

- `item_id`：物品唯一 ID，也是代码调用主键和默认美术素材名。
- `item_no`：稳定整数编号，用于统计、导出和日志聚合；一经分配不复用、不重排。
- `name`：显示名称。
- `description`：描述文本。
- `type`：物品类型。
- `stackable`：是否堆叠。
- `usable`：是否可直接使用。
- `payload`：物品专属数据。
- `use_scope`：使用范围，当前为 `home`、`combat`、`none`。
- `gain_target`：成长或强化倾向标签。
- `icon_name` / `icon_path`：可选图标覆盖；默认由 `item_id` 推导。
- `description_effects`：装备结构化富文本公式；格式与维护边界见 `docs/items.md`。

## 已实现：物品编号与素材命名

代码中优先使用 `DataTables.ITEM_ID_*` 常量引用物品。数量统计仍按 `item_id` 聚合，可通过 `DataTables.item_no(item_id)` 获取稳定统计编号，或用 `DataTables.item_id_from_no(item_no)` 反查。

美术图标默认按 `item_id` 命名并放在 `assets/items/` 下，例如 `herb` 对应 `res://assets/items/herb.png`。若没有对应文件，背包 UI 继续显示占位色块。

当前还生成了 `.tres` 图标承载资源：

- 物品：`resources/items/<item_id>.tres`，字段来自 `ITEM_DEFS`，`icon_texture` 可直接引用对应美术资源。
- 装备：`resources/equipment/<template_id>.tres`，字段来自 `EQUIPMENT_DEFS`，`icon_texture` 可在 Inspector 中配置。
- 技能：`resources/skills/<skill_id>.tres`，字段来自 `SKILL_DEFS`，`icon_texture` 可直接引用技能特效的代表帧。

图标读取顺序：`.tres.icon_texture` -> `icon_path` 图片 -> UI 占位色块或文字。`DataTables` 仍是数据事实来源，`.tres` 只作为美术引用和可视化编辑承载。

| item_no | item_id | 名称 | type | usable | gain_target | payload 摘要 |
| ---: | --- | --- | --- | --- | --- | --- |
| 1001 | `herb` | 草药 | `crop` | 否 | `none` | `seed_yield=3`, `growth_seconds=600` |
| 1004 | `ore` | 矿石 | `material` | 否 | `none` | 通用炼器材料 |
| 1005 | `spirit_stone` | 灵石 | `material` | 否 | `none` | 招募货币；强化普通属性，`enhance_amount=1` |
| 1006 | `farm_speed_talisman` | 丰收符 | `material` | 是 | `none` | `farm_speed=true` |
| 1009 | `spirit_stone_fire` | 火灵石 | `material` | 否 | `fire` | 强化 `element_fire`, `+1` |
| 1010 | `spirit_stone_earth` | 土灵石 | `material` | 否 | `earth` | 强化 `element_earth`, `+1` |
| 1011 | `spirit_stone_wood` | 木灵石 | `material` | 否 | `wood` | 强化 `element_wood`, `+1` |
| 1012 | `spirit_stone_metal` | 金灵石 | `material` | 否 | `metal` | 强化 `element_metal`, `+1` |
| 1013 | `spirit_stone_water` | 水灵石 | `material` | 否 | `water` | 强化 `element_water`, `+1` |
| 1014 | `refine_talisman` | 洗练符 | `material` | 否 | `none` | 装备洗练材料 |
| 1015 | `recipe_pill` | 调息丹方 | `alchemy_recipe` | 是 | `none` | 学习 `pill` 丹方 |
| 1016 | `pill` | 调息丹 | `pill` | 是 | `none` | 恢复 `hp=18`, `mp=12` |
| 1017 | `breakthrough_pill` | 破境丹 | `pill` | 是 | `none` | `breakthrough=true` |
| 1019 | `blade_grass` | 刃纹草 | `crop` | 否 | `attack` | `seed_yield=1`, `growth_seconds=900` |
| 1020 | `ironroot` | 铁根藤 | `crop` | 否 | `defense` | `seed_yield=1`, `growth_seconds=900` |
| 1021 | `blood_ginseng` | 血参 | `crop` | 否 | `max_hp` | `seed_yield=1`, `growth_seconds=1200` |
| 1022 | `spirit_lotus` | 灵泉莲 | `crop` | 否 | `max_mp` | `seed_yield=1`, `growth_seconds=1200` |
| 1023 | `bone_bamboo` | 玉骨竹 | `crop` | 否 | `root_bone` | `seed_yield=1`, `growth_seconds=1800` |
| 1024 | `woodvine` | 青木藤 | `crop` | 否 | `wood` | `seed_yield=1`, `growth_seconds=900` |
| 1025 | `flame_flower` | 赤焰花 | `crop` | 否 | `fire` | `seed_yield=1`, `growth_seconds=1050` |
| 1026 | `earth_moss` | 厚土苔 | `crop` | 否 | `earth` | `seed_yield=1`, `growth_seconds=1050` |
| 1027 | `metal_reed` | 玄金苇 | `crop` | 否 | `metal` | `seed_yield=1`, `growth_seconds=1500` |
| 1028 | `water_orchid` | 玄水兰 | `crop` | 否 | `water` | `seed_yield=1`, `growth_seconds=1200` |
| 1029 | `skill_book_thunder` | 雷击术技能书 | `skill_book` | 是 | `metal` | 学习 `thunder` |
| 1030 | `skill_book_poison` | 蚀骨毒雾技能书 | `skill_book` | 是 | `wood` | 学习 `poison` |
| 1031 | `skill_book_heal` | 回春术技能书 | `skill_book` | 是 | `wood` | 学习 `heal` |
| 1032 | `skill_book_attack_up` | 燃锋诀技能书 | `skill_book` | 是 | `fire` | 学习 `attack_up` |
| 1033 | `skill_book_spirit_shield` | 玄甲术技能书 | `skill_book` | 是 | `earth` | 学习 `spirit_shield` |

`item_no` 1002、1003、1007、1008 和 1018 曾用于已删除物品，后续不复用。

## 已实现：普通攻击

| attack_mode | 名称 | 五行 | 蓝耗 | 冷却（角色回合） | 释放距离 | 说明 |
| --- | --- | --- | ---: | ---: | ---: | --- |
| `melee` | 普通攻击 | 无 | 0 | 0 | 敌方近战点 | 使用近战动画和 Hitbox 命中 |
| `ranged` | 火球术 | `fire` | 0 | 0 | 120 | 远程角色的普通攻击，不属于技能列表 |

## 已实现：技能

| skill_id | 名称 | 类型 | 五行 | 蓝耗 | 冷却（角色回合） | 释放距离 | 说明 |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| `heal` | 回春术 | `heal` | `wood` | 6 | 5 | 96 | 血量低于 35% 时优先治疗 |
| `thunder` | 雷击术 | `damage` | `metal` | 12 | 5 | 140 | 伤害倍率 1.75 |
| `poison` | 蚀骨毒雾 | `damage` | `wood` | 8 | 4 | 120 | 伤害倍率 0.9；命中后每回合 2 点 DOT，持续 3 回合 |
| `attack_up` | 燃锋诀 | `buff` | `fire` | 5 | 6 | 0 | 攻击 +2，持续 3 个自身回合 |
| `spirit_shield` | 玄甲术 | `defense` | `earth` | 7 | 6 | 0 | 血量低于 60% 时获得 10 点护盾，最多持续 3 回合 |

冷却在角色每次获得自身回合时递减 1；百分比修正后的冷却向上取整。

五本初阶技能书由正式新档各赠送 1 本；版本 9 迁移会为旧存档补齐尚未持有且尚未学会的技能书。它们不进入敌人掉落、商店或生产经济。技能书成功学习后消耗 1 本；重复学习失败时不消耗，人物已学技能不可替换或遗忘。

## 已实现：炼丹配方

| recipe_id | 产物 | 材料 |
| --- | --- | --- |
| `pill` | `pill` 调息丹 | `herb x2` |

更多丹方属于规划内容，见本文“规划物品与装备设定”。

## 已实现：装备模板

| template_id | 槽位 | 名称 | 基础属性 | level_scale |
| --- | --- | --- | --- | ---: |
| `weapon` | `weapon` | 武器 | `attack +8` | 2.2 |
| `helmet` | `helmet` | 头盔 | `defense +5`, `max_hp +12` | 1.6 |
| `armor` | `armor` | 护甲 | `defense +7`, `max_hp +18` | 2.0 |
| `leggings` | `leggings` | 胫甲 | `defense +4`, `max_hp +10` | 1.5 |
| `gloves` | `gloves` | 护手 | `attack +4`, `defense +2` | 1.4 |
| `accessory` | `accessory` | 饰品 | `root_bone +2` | 1.0 |

对应装备资源：

- `resources/equipment/weapon.tres`
- `resources/equipment/helmet.tres`
- `resources/equipment/armor.tres`
- `resources/equipment/leggings.tres`
- `resources/equipment/gloves.tres`
- `resources/equipment/accessory.tres`

装备 `.tres` 字段包括 `item_id`、`slot`、`base_name`、`display_name`、`slot_label`、`icon_texture`、`icon_name`、`icon_path`、`requirement_stat`、`description` 和 `description_effects`。模板不再保存固定基础属性；`RichTextLabel` 节点仍由 `hud.tscn` 提供；资源内不写入 `一阶`、`二阶` 等阶位文本，阶位只在运行时装备实例名称中动态生成。

装备生成公式：

- 名称：`<阶位名>·<EQUIPMENT_DEFS.name>`。
- 属性点预算：一至五阶为 `20/50/100/180/300`。
- 随机属性：随机生成 1 至 5 条不重复属性，每条有 50% 概率来自普通池或五行池，按 `floor(预算 / 条数)` 平均分配；余数舍弃。
- 旧随机数值词条不再生成，`affixes` 保留为空以兼容旧存档结构。
- 洗练会重洗随机属性并保留强化等级；强化点按新属性重新随机分配，不再生成百分比洗练词条。
- 穿戴需求：`level >= max(1, equipment_level * rarity_tier)`

## 已实现：装备阶位与随机属性

| rarity | 名称 | 权重 | 属性点预算 |
| --- | --- | ---: | ---: |
| `t1` | 一阶 | 55 | 20 |
| `t2` | 二阶 | 28 | 50 |
| `t3` | 三阶 | 12 | 100 |
| `t4` | 四阶 | 4 | 180 |
| `t5` | 五阶 | 1 | 300 |

随机属性池：

- `attack`
- `defense`
- `max_hp`
- `max_mp`
- `root_bone`
- `element_wood`
- `element_fire`
- `element_earth`
- `element_metal`
- `element_water`

强化灵石规则：

- 普通属性 `attack`、`defense`、`max_hp`、`max_mp`、`root_bone` 消耗通用 `spirit_stone`。
- 五行属性 `element_wood`、`element_fire`、`element_earth`、`element_metal`、`element_water` 消耗对应五行灵石。
- 当前静态物品 ID 不按阶级拆分；强化随机命中已有基础属性并直接 `+1`，上限按装备阶位为 `5/10/20/30/40`，每五级提高一次灵石消耗。
- 后续阶级通过动态显示或额外数据扩展，不使用 `*_t1` 这类静态物品 ID；同类灵石默认共用同一素材图。

## 已实现：命格数据索引

完整规则见 `docs/innate-traits.md`。当前 `DataTables.INNATE_TRAIT_DEFS` 中已实现：

| id | 名称 | 方向 | 效果摘要 |
| --- | --- | --- | --- |
| `robust_body` | 健体 | 生存 | `max_hp +20` |
| `sharp_edge` | 锋芒 | 输出 | `attack +2` |
| `steady_guard` | 稳守 | 防御 | `defense +2` |
| `full_vigor` | 充沛 | 法力 | `max_mp +12` |
| `good_root` | 良根 | 根骨 | `root_bone +2` |
| `craft_hand` | 巧匠 | 炼器 | `craft_bonus +1`, 炼器升阶概率 +5% |
| `craft_touch` | 巧手 | 炼器 | `craft_bonus +1` |
| `pill_heart` | 丹心 | 炼丹 | 额外出丹概率 +5% |
| `pill_sense` | 丹感 | 炼丹 | 额外出丹概率 +4% |
| `field_sense` | 识田 | 种田 | 收成 +1 |

基础招募命格池当前为 `robust_body`、`sharp_edge`、`steady_guard`、`full_vigor`、`good_root`、`field_sense`、`craft_touch`、`pill_sense`。

## 已实现：敌人与掉落

敌人掉落池按阶级解锁类别，物品使用 `t1` 到 `t5` 五档稀有度。敌人模板可以通过 `drop_profile.items`、`base_chance` 和 `rarity_weights` 覆盖阶级默认值；掉落成功后先抽稀有度，再从该稀有度物品中抽取具体物品。

| enemy_id | 名称 | 五行 | 弱点 | 掉落 | 经验 | 说明 |
| --- | --- | --- | --- | --- | ---: | --- |
| `training_dummy` | 木桩 | `wood` | `fire` | 无 | `6 + level * 2` | 训练目标，`use_drop=false`，装备 0% |
| `forest_wolf` | 林狼 | `wood` | `fire` | 一阶从草药、矿石、灵石池抽取；高阶逐步解锁属性作物、五行灵石、生产与稀有材料 | `10 + level * 2` | 基础普通掉落率 55%，阶内每 5 级 +5%（最多 +15%）；独立装备掉落 5% |

敌人场景路径：

- `training_dummy`：`res://scripts/game/enemies/training_dummy/enemy.tscn`
- `forest_wolf`：`res://scripts/game/enemies/forest_wolf/enemy.tscn`

## 已实现：开局、建筑与生产节奏

正式新档物资为 `spirit_stone x1`、`herb x1`、`recipe_pill x1` 和五本初阶技能书各 1 本。项目设置 `game/development/seed_test_inventory` 默认为 `false`，开启后才补齐其余测试物品和基础装备。

| 建筑 | 1 级升级消耗 | 升级成本 | 1 级生产时间 | 满级附近生产时间 |
| --- | --- | --- | ---: | ---: |
| 招募 | `spirit_stone x1` | 当前等级个灵石 | 即时 | 即时 |
| 农田 | `herb x1` | 当前等级个草药 | 草药 600 秒 | 基础时间的 55% |
| 炼器 | `ore x2` | 当前等级 + 1 个矿石 | 900 秒 | 360 秒 |
| 炼丹 | `herb x2` | 当前等级 + 1 个草药 | 每份 600 秒 | 每份 195 秒 |

炼器任务基础消耗 `ore x4`，受执行者材料减免效果影响但最低为 1。生产时间只在程序运行时推进，不补算离线时间。

## 已实现：维护规则

- 新增物品时优先补充 `DataTables.ITEM_ID_*` 常量、`DataTables.ITEM_DEFS` 和稳定 `item_no`。
- 新增编号只追加，不复用历史编号。
- 新增图标资源时保持 `DataTables` 为事实来源，`.tres` 只承载 `icon_texture` 和可视化编辑字段。
- 新增丹方同步补充 `ALCHEMY_RECIPE_DEFS`。
- 新增装备模板同步补充 `EQUIPMENT_DEFS`、`resources/equipment/<template_id>.tres` 和默认图标路径。
- 新增随机词条同步补充 `EQUIPMENT_ATTRIBUTE_DEFS`。
- 新增技能同步补充 `SKILL_DEFS`，若要通过背包学习，还要新增对应技能书物品。
- 新增敌人同步补充 `ENEMY_TEMPLATES`、`ENEMY_SCENE_PATHS` 和敌人场景目录。

## 规划物品与装备设定

以下内容是规划设定，当前不代表 `DataTables` 已实现。

### 规划：属性丹

| item_id | 名称 | 规划效果 |
| --- | --- | --- |
| `life_pill` | 归元丹 | 恢复生命 |
| `spirit_pill` | 聚灵丹 | 恢复法力 |
| `might_pill` | 壮气丹 | 持续属性 Buff |
| `attack_pill` | 破军丹 | 攻击 Buff |
| `defense_pill` | 玄甲丹 | 防御 Buff |
| `life_boost_pill` | 血元丹 | 最大生命 Buff |
| `mana_boost_pill` | 灵泉丹 | 最大法力 Buff |
| `root_bone_pill` | 锻骨丹 | 根骨 Buff |
| `wood_pill` | 青木丹 | 木行 Buff |
| `fire_pill` | 赤焰丹 | 火行 Buff |
| `earth_pill` | 厚土丹 | 土行 Buff |
| `metal_pill` | 玄金丹 | 金行 Buff |
| `water_pill` | 玄水丹 | 水行 Buff |

规划配方结构为“属性作物 x2 + 通用辅料 x1 + 对应灵石 x1”。实现时必须先补齐丹药、图纸、丹方、UI 和测试。

### 规划：阵营武器

阵营武器是武器模板的风格化扩展，仍遵循装备生成、强化、洗练与穿戴规则。

| 武器 | 阵营 | 定位 | 主属性 | 副属性 | 词条倾向 |
| --- | --- | --- | --- | --- | --- |
| 礼剑 | 儒家 | 均衡近战 | `attack` | `accuracy`, `defense` | 稳定输出、命中 |
| 仁杖 | 儒家 | 辅助法器 | `max_hp` | `hp_regen`, `buff_duration` | 续航、治疗、护盾 |
| 义简 | 儒家 | 快速短兵 | `attack_speed` | `crit_rate`, `counter_rate` | 高频打击 |
| 礼印 | 儒家 | 防守器具 | `defense` | `block_rate`, `damage_reduce` | 承伤、保护 |
| 经卷 | 儒家 | 文法远程 | `spell_attack` | `accuracy`, `buff_duration` | 远程压制 |
| 拂尘 | 道家 | 轻灵近中程 | `evasion` | `move_speed`, `dot_damage` | 游击、持续伤害 |
| 太极环 | 道家 | 攻守法器 | `defense` | `reflect_rate`, `element_balance` | 阴阳调和 |
| 符箓 | 道家 | 远程术式 | `element_damage` | `control_rate`, `slow_rate` | 元素压制 |
| 青木杖 | 道家 | 自然法器 | `wood` | `hp_regen`, `heal_rate` | 续航、生机成长 |
| 云剑 | 道家 | 高机动爆发 | `crit_rate` | `penetration`, `move_speed` | 爆发、穿透 |

### 规划：阵营装备套装

儒家正礼套：

| 装备 | 槽位 | 主属性 | 副属性 | 定位 |
| --- | --- | --- | --- | --- |
| 正冠 | 头盔 | `defense` | `accuracy`, `max_hp` | 稳定承伤 |
| 礼袍 | 护甲 | `max_hp` | `defense`, `damage_reduce` | 生存减伤 |
| 守履 | 胫甲 | `defense` | `move_speed`, `block_rate` | 格挡防守 |
| 义护 | 护手 | `attack` | `accuracy`, `counter_rate` | 输出反击 |
| 仁佩 | 饰品 | `hp_regen` | `buff_duration`, `max_hp` | 续航增益 |
| 文璧 | 饰品 | `accuracy` | `spell_attack`, `buff_duration` | 文法命中 |

道家清虚套：

| 装备 | 槽位 | 主属性 | 副属性 | 定位 |
| --- | --- | --- | --- | --- |
| 云冠 | 头盔 | `evasion` | `move_speed`, `element_damage` | 闪避灵动 |
| 清袍 | 护甲 | `defense` | `evasion`, `reflect_rate` | 防御反弹 |
| 逍遥履 | 胫甲 | `move_speed` | `evasion`, `slow_resist` | 高机动 |
| 玄护 | 护手 | `crit_rate` | `penetration`, `attack_speed` | 爆发穿透 |
| 阴阳佩 | 饰品 | `element_balance` | `control_rate`, `element_damage` | 元素控制 |
| 太虚符 | 饰品 | `control_rate` | `slow_rate`, `crit_damage` | 控制爆发 |

规划套装效果：

- 儒家 2 件：`defense +5%`；4 件：`buff_duration +8%`；6 件：受伤后短时间提高 `damage_reduce`。
- 道家 2 件：`evasion +5%`；4 件：`move_speed +8%`；6 件：暴击或控制时提高 `element_damage`。

### 规划：数值平衡基准

这些数值用于后续扩展，不代表当前代码全部采用：

- 玩家和队友每升 1 级自动获得 5 点属性成长。
- 初始参考属性：`attack=10`、`defense=8`、`max_hp=120`、五行各 `5`。
- 装备高阶可扩大基础属性倍率和百分比词条范围。
- 儒家武器优先 `attack`、`accuracy`、`defense`、`max_hp`、`block_rate`、`buff_duration`。
- 道家武器优先 `crit_rate`、`move_speed`、`evasion`、元素、控制和穿透。
