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

二十个五行技能属于独立规划，完整特色、数值和 AI 条件见 `docs/skills.md`，不能作为当前 `SKILL_DEFS` 的已实现内容。

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

装备十阶成长、阶内等级、图纸打造、掉落等级、分解经济和迁移规则统一见 `docs/equipment-progression-v2.md`。在运行时、存档迁移与测试完成前，本文前面的五阶装备表仍是当前事实来源。

五行只定义技能特色，不新增角色职业或学习限制。二十个五行技能的完整数值、目标和 AI 条件见 `docs/skills.md`；五种武器和九种防具、饰品的固定主属性见 `docs/equipment-progression-v2.md`。

### 规划：装备图纸

规划类型 `equipment_blueprint` 可堆叠、可在家园使用。使用后永久解锁 `payload.template_id` 并消耗 1 张；图纸本身没有正式 `item_no`。

| item_id | 名称 | template_id | 来源 | 用途 |
| --- | --- | --- | --- | --- |
| `blueprint_weapon_metal_sword` | 玄金剑图纸 | `weapon_metal_sword` | 有效胜利图纸池 | 解锁玄金剑打造 |
| `blueprint_weapon_wood_staff` | 青木杖图纸 | `weapon_wood_staff` | 有效胜利图纸池 | 解锁青木杖打造 |
| `blueprint_weapon_earth_gauntlet` | 镇岳拳套图纸 | `weapon_earth_gauntlet` | 有效胜利图纸池 | 解锁镇岳拳套打造 |
| `blueprint_weapon_water_brush` | 沧水符笔图纸 | `weapon_water_brush` | 有效胜利图纸池 | 解锁沧水符笔打造 |
| `blueprint_weapon_fire_orb` | 赤焰法环图纸 | `weapon_fire_orb` | 有效胜利图纸池 | 解锁赤焰法环打造 |
| `blueprint_helmet` | 聚灵冠图纸 | `helmet` | 有效胜利图纸池 | 解锁聚灵冠打造 |
| `blueprint_armor` | 镇元法衣图纸 | `armor` | 有效胜利图纸池 | 解锁镇元法衣打造 |
| `blueprint_leggings` | 行脉胫甲图纸 | `leggings` | 有效胜利图纸池 | 解锁行脉胫甲打造 |
| `blueprint_gloves` | 锻骨护手图纸 | `gloves` | 有效胜利图纸池 | 解锁锻骨护手打造 |
| `blueprint_accessory_wood` | 青木佩图纸 | `accessory_wood` | 有效胜利图纸池 | 解锁青木佩打造 |
| `blueprint_accessory_fire` | 赤焰珠图纸 | `accessory_fire` | 有效胜利图纸池 | 解锁赤焰珠打造 |
| `blueprint_accessory_earth` | 厚土印图纸 | `accessory_earth` | 有效胜利图纸池 | 解锁厚土印打造 |
| `blueprint_accessory_metal` | 玄金令图纸 | `accessory_metal` | 有效胜利图纸池 | 解锁玄金令打造 |
| `blueprint_accessory_water` | 沧水环图纸 | `accessory_water` | 有效胜利图纸池 | 解锁沧水环打造 |

图纸每场有效胜利以 10% 概率判定，连续 10 场未获得新图纸时优先保底未解锁图纸。全部解锁后才能获得重复图纸，重复图纸分解为 `ascension_stone x1`。

### 规划：成长材料

| item_id | 名称 | 类型 | 堆叠 | 可使用 | 来源 | 用途 |
| --- | --- | --- | --- | --- | --- | --- |
| `ascension_stone` | 升阶石 | `material` | 是 | 否 | 装备分解、重复图纸分解 | 装备升阶 |
| `manual_fragment` | 秘法残页 | `material` | 是 | 否 | 每 5 场有效胜利固定获得 1 页 | 定向兑换五行技能书 |

`ascension_stone` 的装备分解产量和升阶消耗以 `docs/equipment-progression-v2.md` 为准。秘法残页计数独立于普通掉落、图纸保底和装备掉落；`use_drop=false` 的战斗不推进计数。

### 规划：五行技能书

技能书均使用现有 `skill_book` 类型，可堆叠、可在家园使用；成功学习后消耗 1 本，重复学习不消耗。来源统一为秘法残页加对应五行灵石的定向兑换。

| item_id | 名称 | 五行 | 阶段 | 兑换成本 |
| --- | --- | --- | ---: | --- |
| `skill_book_metal_sword_flash` | 流光剑技能书 | 金 | 一 | 残页 3、金灵石 1 |
| `skill_book_metal_mountain_break` | 断岳式技能书 | 金 | 二 | 残页 6、金灵石 2 |
| `skill_book_metal_hidden_edge` | 藏锋诀技能书 | 金 | 三 | 残页 10、金灵石 3 |
| `skill_book_metal_ten_thousand_blades` | 万剑归宗技能书 | 金 | 四 | 残页 15、金灵石 5 |
| `skill_book_wood_dew_heal` | 青露回春技能书 | 木 | 一 | 残页 3、木灵石 1 |
| `skill_book_wood_breath_array` | 生息阵技能书 | 木 | 二 | 残页 6、木灵石 2 |
| `skill_book_wood_corroding_vine` | 蚀骨藤技能书 | 木 | 三 | 残页 10、木灵石 3 |
| `skill_book_wood_meridian_guard` | 青木护脉技能书 | 木 | 四 | 残页 15、木灵石 5 |
| `skill_book_earth_mountain_strike` | 震岳击技能书 | 土 | 一 | 残页 3、土灵石 1 |
| `skill_book_earth_immovable_stance` | 不动势技能书 | 土 | 二 | 残页 6、土灵石 2 |
| `skill_book_earth_spirit_armor` | 厚土玄甲技能书 | 土 | 三 | 残页 10、土灵石 3 |
| `skill_book_earth_mountain_wall` | 山河壁技能书 | 土 | 四 | 残页 15、土灵石 5 |
| `skill_book_water_cold_talisman` | 寒潮符技能书 | 水 | 一 | 残页 3、水灵石 1 |
| `skill_book_water_mirror_art` | 水镜诀技能书 | 水 | 二 | 残页 6、水灵石 2 |
| `skill_book_water_binding_array` | 玄水缚技能书 | 水 | 三 | 残页 10、水灵石 3 |
| `skill_book_water_returning_tide` | 沧海归流技能书 | 水 | 四 | 残页 15、水灵石 5 |
| `skill_book_fire_heart_flame` | 焚心火技能书 | 火 | 一 | 残页 3、火灵石 1 |
| `skill_book_fire_blazing_mark` | 烈焰印技能书 | 火 | 二 | 残页 6、火灵石 2 |
| `skill_book_fire_edge_rite` | 燃锋祭技能书 | 火 | 三 | 残页 10、火灵石 3 |
| `skill_book_fire_heavenly_flame` | 天火劫技能书 | 火 | 四 | 残页 15、火灵石 5 |

### 规划：丹药与配方

九种丹药均可堆叠、可使用。恢复丹立即结算；持续 Buff 丹药持续 3 个使用者自身回合，共享 `buff_pill` 冷却组且相同状态覆盖、不叠层。

| item_id | 名称 | 效果 | 配方 |
| --- | --- | --- | --- |
| `life_pill` | 归元丹 | 恢复 25% 最大生命 | 血参 2、草药 1 |
| `spirit_pill` | 聚灵丹 | 恢复 25% 最大法力 | 灵泉莲 2、草药 1 |
| `attack_pill` | 破军丹 | 攻击 +3，持续 3 回合 | 刃纹草 2、草药 1、灵石 1 |
| `defense_pill` | 玄甲丹 | 防御 +3，持续 3 回合 | 铁根藤 2、草药 1、灵石 1 |
| `wood_pill` | 青木丹 | 木行 +3，持续 3 回合 | 青木藤 2、草药 1、木灵石 1 |
| `fire_pill` | 赤焰丹 | 火行 +3，持续 3 回合 | 赤焰花 2、草药 1、火灵石 1 |
| `earth_pill` | 厚土丹 | 土行 +3，持续 3 回合 | 厚土苔 2、草药 1、土灵石 1 |
| `metal_pill` | 玄金丹 | 金行 +3，持续 3 回合 | 玄金苇 2、草药 1、金灵石 1 |
| `water_pill` | 玄水丹 | 水行 +3，持续 3 回合 | 玄水兰 2、草药 1、水灵石 1 |

以上规划物品均不预分配 `item_no`。正式实现时只能从当前最大编号之后追加，并同步 `ITEM_DEFS`、配方、UI、存档迁移和对应资源；在此之前不得移入本文前面的已实现表。
