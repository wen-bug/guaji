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
- `description_effects`：装备结构化富文本公式；格式与维护边界见[物品系统](items.md)。

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
| `heal` | 回春术 | `heal` | `wood` | 6 | 5 | 96 | 治疗 `7 + 木属性 x 1.0`；血量低于 35% 时优先使用 |
| `thunder` | 雷击术 | `damage` | `metal` | 12 | 5 | 140 | 伤害 `13 + 金属性 x 1.75` |
| `poison` | 蚀骨毒雾 | `damage` | `wood` | 8 | 4 | 120 | 伤害 `7 + 木属性 x 0.9`；DOT 每回合 `2 + 木属性 x 0.5`，持续 3 回合 |
| `attack_up` | 燃锋诀 | `buff` | `fire` | 5 | 6 | 0 | 攻击提升 `2 + 火属性 x 0.5`，持续 3 个自身回合 |
| `spirit_shield` | 玄甲术 | `defense` | `earth` | 7 | 6 | 0 | 护盾 `10 + 土属性 x 0.5`，最多持续 3 回合；血量低于 60% 时优先使用 |

冷却在角色每次获得自身回合时递减 1；百分比修正后的冷却向上取整。

所有属性倍率公式最终向下取整。技能使用自身五行对应的施法者属性；effect 显式提供 `element` 时以 effect 为准。敌人技能遵循同一规则并读取敌人运行时 `elements`。

五本初阶技能书由正式新档各赠送 1 本；版本 9 迁移会为旧存档补齐尚未持有且尚未学会的技能书。技能书不进入敌人掉落；历练 6 级后，队伍仍有学习需求的六种已实现技能书可低概率进入坊市稀有池。技能书成功学习后消耗 1 本；重复学习失败时不消耗，人物已学技能不可替换或遗忘。

二十个五行技能属于独立规划，完整特色、数值和 AI 条件见[五行技能](skills.md)，不能作为当前 `SKILL_DEFS` 的已实现内容。

## 已实现：炼丹配方

| recipe_id | 产物 | 材料 |
| --- | --- | --- |
| `pill` | `pill` 调息丹 | `herb x2` |

更多丹方属于规划内容，见本文“规划物品与装备设定”。

## 已实现：装备模板

当前装备使用十四个稳定模板和 `.tres` 内的 `tier_base_attributes`，不使用随机基础属性或穿戴等级要求。模板、五阶数值、强化、三词条、升阶、分解经济和 Schema 18 迁移的完整事实以[装备成长 V2](equipment-progression-v2.md)为准。

## 已实现：命格数据索引

完整规则见[先天命格](innate-traits.md)。当前 `DataTables.INNATE_TRAIT_DEFS` 中已实现：

| id | 名称 | 方向 | 效果摘要 |
| --- | --- | --- | --- |
| `robust_body` | 健体 | 生存 | `max_hp +20` |
| `sharp_edge` | 锋芒 | 输出 | `attack +2` |
| `steady_guard` | 稳守 | 防御 | `defense +2` |
| `full_vigor` | 充沛 | 法力 | `max_mp +12` |
| `good_root` | 良根 | 根骨 | `root_bone +2` |

基础招募命格池当前为 `robust_body`、`sharp_edge`、`steady_guard`、`full_vigor`、`good_root`。

## 已实现：敌人与掉落

现有 9 个战斗敌人按 `enemy_class` 使用互不重叠的完整类别池，所有条目从 `t1` 开放。同一敌人一次击杀内，同一 `item_id` 最多发放一次；不同敌人分别结算。

| 类别 | 敌人 | 材料池与概率 | 装备 |
| --- | --- | --- | ---: |
| normal | `forest_wolf`、`venom_spider`、`ember_gnome`、`stone_lizard`、`iron_lancer`、`tide_fish` | 草药 55%、矿石 30%、灵石 10%；十种属性作物各 2%，逐项独立判定，数量均为 1 | 5% |
| elite | `blight_shaman`、`stone_overlord` | 五种五行灵石各 10%；丰收符、洗练符各 5%，逐项独立判定，数量均为 1 | 12% |
| boss | `abyssal_turtle` | 每次在调息丹、破境丹中等权必出 1 个 | 25% |

材料池之间没有重复物品。装备仍独立结算；永久强化丹、技能书和图纸不进入上述池。`training_dummy` 保持 `use_drop=false`。Mod 显式 `drops` 与旧 `drop_profile` 继续兼容，但与其他来源命中同一物品时不重复发放。

## 已实现：开局、建筑与生产节奏

正式新档物资为 `spirit_stone x1`、`herb x1`、`recipe_pill x1` 和五本初阶技能书各 1 本。项目设置 `game/development/seed_test_inventory` 默认为 `false`，开启后才补齐其余测试物品和基础装备。

| 建筑 | 1 级升级消耗 | 升级成本 | 生产方式 |
| --- | --- | --- | --- |
| 招募 | `spirit_stone x1` | 当前等级个灵石 | 即时 |
| 农田 | `herb x1` | 当前等级个草药 | 作物独立计时；草药基础 600 秒，满级为基础时间的 55% |
| 炼器 | `ore x2` | 当前等级 + 1 个矿石 | 即时 |
| 炼丹 | `herb x2` | 当前等级 + 1 个草药 | 即时 |

炼器固定消耗 `ore x4`，装备等级使用账号历练等级。随机炼器和定向打造都不需要图纸或其他解锁条件；定向打造可直接选择任一已注册装备模板。炼器和炼丹不依赖人物；只有农田生长时间在程序运行时推进，不补算离线时间。

## 已实现：维护规则

- 新增物品时优先补充 `DataTables.ITEM_ID_*` 常量、`DataTables.ITEM_DEFS` 和稳定 `item_no`。
- 新增编号只追加，不复用历史编号。
- 新增图标资源时保持 `DataTables` 为事实来源，`.tres` 只承载 `icon_texture` 和可视化编辑字段。
- 新增丹方同步补充 `ALCHEMY_RECIPE_DEFS`。
- 新增装备模板同步补充 `EQUIPMENT_DEFS`、`resources/equipment/<template_id>.tres` 和默认图标路径。
- 新增随机词条同步补充 `EQUIPMENT_ATTRIBUTE_DEFS`。
- 新增技能同步补充 `SKILL_DEFS`，若要通过背包学习，还要新增对应技能书物品。
- 新增本体敌人时创建 `resources/enemies/<enemy_id>.tres`，并同步补充兼容用 `ENEMY_TEMPLATES`、场景映射与敌人场景目录。

## 已实现：五行材料、图纸与技能书

| item_no | item_id | 名称 | 用途 |
| ---: | --- | --- | --- |
| 1034 | `blueprint_weapon` | 武器图纸 | 永久解锁武器定向打造 |
| 1035 | `blueprint_helmet` | 头盔图纸 | 永久解锁头盔定向打造 |
| 1036 | `blueprint_armor` | 护甲图纸 | 永久解锁护甲定向打造 |
| 1037 | `blueprint_leggings` | 胫甲图纸 | 永久解锁胫甲定向打造 |
| 1038 | `blueprint_gloves` | 护手图纸 | 永久解锁护手定向打造 |
| 1039 | `blueprint_accessory` | 饰品图纸 | 永久解锁饰品定向打造 |
| 1040 | `manual_fragment` | 功法残页 | 3 张加对应五行灵石 1 个兑换功法 |
| 1041 | `skill_book_water_cold_talisman` | 寒潮符技能书 | 学会水行单体技能寒潮符 |
| 1042 | `life_pill` | 归元丹 | 恢复 25% 最大生命 |
| 1043 | `spirit_pill` | 聚灵丹 | 恢复 25% 最大法力 |
| 1044 | `attack_pill` | 破军丹 | 攻击 +3，3 回合，`buff_pill` 组 |
| 1045 | `defense_pill` | 玄甲丹 | 防御 +3，3 回合，`buff_pill` 组 |
| 1046 | `wood_pill` | 青木丹 | 木行 +3，3 回合，`buff_pill` 组 |
| 1047 | `fire_pill` | 赤焰丹 | 火行 +3，3 回合，`buff_pill` 组 |
| 1048 | `earth_pill` | 厚土丹 | 土行 +3，3 回合，`buff_pill` 组 |
| 1049 | `metal_pill` | 玄金丹 | 金行 +3，3 回合，`buff_pill` 组 |
| 1050 | `water_pill` | 玄水丹 | 水行 +3，3 回合，`buff_pill` 组 |

炼丹建筑自动解锁：1 级调息丹；2 级破境丹（`pill x1 + herb x8`）；3 级归元丹/聚灵丹；4 级破军丹/玄甲丹；5 级五行丹。新档不再发放调息丹方，旧档丹方会自动学习并移除。调息丹恢复 15% 最大生命和法力。炼器 3 级开放通用灵石 3 个兑换指定五行灵石 1 个。

## 已实现：一阶永久属性强化丹

| item_no | item_id | 名称 | 永久效果 | 配方与解锁 |
| ---: | --- | --- | --- | --- |
| 1051 | `t1_attack_enhance_pill` | 一阶攻击强化丹 | `attack +1` | 炼丹 6；刃纹草 3、草药 8、灵石 2 |
| 1052 | `t1_defense_enhance_pill` | 一阶防御强化丹 | `defense +1` | 炼丹 6；铁根藤 3、草药 8、灵石 2 |
| 1053 | `t1_max_hp_enhance_pill` | 一阶气血强化丹 | `max_hp +1` | 炼丹 6；血参 3、草药 8、灵石 2 |
| 1054 | `t1_max_mp_enhance_pill` | 一阶法力强化丹 | `max_mp +1` | 炼丹 6；灵泉莲 3、草药 8、灵石 2 |
| 1055 | `t1_root_bone_enhance_pill` | 一阶根骨强化丹 | `root_bone +1` | 炼丹 6；玉骨竹 3、草药 8、灵石 2 |
| 1056 | `t1_wood_enhance_pill` | 一阶木行强化丹 | `element_wood +1` | 炼丹 7；青木藤 3、草药 8、木灵石 2 |
| 1057 | `t1_fire_enhance_pill` | 一阶火行强化丹 | `element_fire +1` | 炼丹 7；赤焰花 3、草药 8、火灵石 2 |
| 1058 | `t1_earth_enhance_pill` | 一阶土行强化丹 | `element_earth +1` | 炼丹 7；厚土苔 3、草药 8、土灵石 2 |
| 1059 | `t1_metal_enhance_pill` | 一阶金行强化丹 | `element_metal +1` | 炼丹 7；玄金苇 3、草药 8、金灵石 2 |
| 1060 | `t1_water_enhance_pill` | 一阶水行强化丹 | `element_water +1` | 炼丹 7；玄水兰 3、草药 8、水灵石 2 |

十种丹共享每名角色 100 次一阶用量上限，同时按 item_id 保存独立用量。效果数值读取 `amount`，省略时为 1。

## 已实现：坊市

| item_no | item_id | 名称 | type | 规则 |
| ---: | --- | --- | --- | --- |
| 1061 | `market_token` | 坊市令 | `material` | 可堆叠、不可使用、不可购买、不可回收；仅由回收和委托获得 |

坊市使用独立持久化 RNG，每 600 秒按 Unix 时间免费刷新，离线时间有效。货架每轮 6 格且 item_id 唯一，每格限购一次；手动刷新费用依次为 2、4、8、16 坊市令，之后固定 16，且不更换委托或重置免费刷新时间。

商品分类权重为基础材料 40、生产材料 25、丹药 20、图纸 10、稀有 5。已学丹方、已解锁图纸、全队无需学习的技能书、全队一阶强化丹额度已满的条目会被过滤。Mod 物品首期不进入坊市。

每轮委托基础价值为 2/4/6，奖励为 3/6/9 坊市令，三项之间不重复 item_id。回收按 `MARKET_RECYCLE_DEFS` 的完整批次结算，不保留小数；图纸、技能书和永久强化丹等贵重物品必须二次确认。购买、回收、委托和刷新均先完整校验再提交。

## 规划：装备 V2 与五行内容扩展

以下内容是规划设定，当前不代表 `DataTables` 已实现。

当前五阶装备模板、固定基础数值、强化、三词条、升阶、分解经济和 Schema 18 迁移规则统一见[装备成长 V2](equipment-progression-v2.md)。

五行只定义技能特色，不新增角色职业或学习限制。四十个五行技能的完整数值、目标和 AI 条件见[五行技能](skills.md)；五种武器和九种防具、饰品的固定主属性见[装备成长 V2](equipment-progression-v2.md)。

### 历史：装备图纸

装备图纸已退出当前掉落、保底、坊市与使用入口。下表仅保留历史 ID 说明；Schema 17 升级时每张补偿矿石 x4。

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

当前胜利不再判定装备图纸，也没有图纸解锁要求。

### 当前：成长材料

| item_id | 名称 | 类型 | 堆叠 | 可使用 | 来源 | 用途 |
| --- | --- | --- | --- | --- | --- | --- |
| `enhancement_stone` | 强化石 | `material` | 是 | 否 | 装备分解 | 装备强化 |
| `ascension_stone` | 升阶石 | `material` | 是 | 否 | Boss 必掉 | 装备升阶 |

两种成长材料的产量和消耗以[装备成长 V2](equipment-progression-v2.md)为准。

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
| `skill_book_water_mirror_art` | 水镜诀技能书 | 水 | 二 | 残页 6、水灵石 2 |
| `skill_book_water_binding_array` | 玄水缚技能书 | 水 | 三 | 残页 10、水灵石 3 |
| `skill_book_water_returning_tide` | 沧海归流技能书 | 水 | 四 | 残页 15、水灵石 5 |
| `skill_book_fire_heart_flame` | 焚心火技能书 | 火 | 一 | 残页 3、火灵石 1 |
| `skill_book_fire_blazing_mark` | 烈焰印技能书 | 火 | 二 | 残页 6、火灵石 2 |
| `skill_book_fire_edge_rite` | 燃锋祭技能书 | 火 | 三 | 残页 10、火灵石 3 |
| `skill_book_fire_heavenly_flame` | 天火劫技能书 | 火 | 四 | 残页 15、火灵石 5 |

寒潮符及对应技能书已经实现，不在规划表重复列出。尚不存在于当前数据表的规划 ID 未分配稳定 `item_no`；正式实现时只能从当前最大编号之后追加，并同步 `ITEM_DEFS`、UI、存档迁移和对应资源。
