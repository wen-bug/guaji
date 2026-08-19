# 装备成长 V2

## 状态摘要

当前实现使用五阶装备、固定模板基础属性、手动强化分配和随机战斗词条。装备没有角色等级穿戴要求；炼器不需要图纸解锁。

事实来源：

- 模板与经济常量：[data_tables.gd](../scripts/game/data/data_tables.gd)
- 装备静态资源：[`resources/equipment/`](../resources/equipment/)
- 存档与操作接口：[game_state.gd](../scripts/game/core/game_state.gd)
- 战斗结算：[combat_skill_executor.gd](../scripts/game/combat/combat_skill_executor.gd)

## 当前实现

### 模板与基础数值

装备实例只保存模板 ID 和当前阶位，固定基础属性每次从模板 `.tres` 的 `tier_base_attributes` 读取。

| 模板 | 固定属性 | t1 | t2 | t3 | t4 | t5 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 玄金剑、青木杖、镇岳拳套、沧水符笔、赤焰法环 | `attack` | 2 | 5 | 10 | 18 | 30 |
| 上述五种武器 | 对应 `element_*` | 1 | 2 | 4 | 7 | 12 |
| 聚灵冠 | `max_mp` | 4 | 10 | 20 | 36 | 60 |
| 镇元法衣 | `defense` | 2 | 5 | 10 | 18 | 30 |
| 行脉胫甲 | `max_hp` | 8 | 20 | 40 | 72 | 120 |
| 锻骨护手 | `root_bone` | 2 | 5 | 10 | 18 | 30 |
| 五行饰品 | 对应 `element_*` | 2 | 5 | 10 | 18 | 30 |

稳定模板 ID：

- 武器：`weapon_metal_sword`、`weapon_wood_staff`、`weapon_earth_gauntlet`、`weapon_water_brush`、`weapon_fire_orb`
- 防具：`helmet`、`armor`、`leggings`、`gloves`
- 饰品：`accessory_wood`、`accessory_fire`、`accessory_earth`、`accessory_metal`、`accessory_water`

### 强化

各阶累计强化点上限为 `10/20/30/40/50`。每点消耗强化石 `enhancement_stone` x1，只能选择模板已有的固定基础属性。

| 属性 | 每点收益 |
| --- | ---: |
| `max_hp` | +4 |
| `max_mp` | +2 |
| 其他固定属性 | +1 |

实例通过 `enhancement_allocations` 保存各属性投入点数；`enhanced_attributes` 和 `enhance_count` 作为兼容视图同步生成。

### 词条与洗练

阶位词条槽数为 `1/2/3/3/3`，单件装备最多三个词条，允许同类型重复。

| 词条 ID | 单条效果 |
| --- | ---: |
| `direct_damage_percent` | 直接伤害 +5% |
| `critical_chance` | 暴击率 +3% |
| `leech_percent` | 吸血 +2% |
| `defense_ignore` | 固定破防 +3 |
| `direct_damage_reduction` | 直接受伤减免 +2% |
| `direct_heal_percent` | 直接技能治疗 +5% |

暴击伤害固定为 1.5 倍。跨装备上限为：暴击率 30%、吸血 20%、直接减伤 30%、直接治疗 50%；直接伤害和破防按加法累计。

洗练通过词条索引选择一个槽位，仅替换该槽。新词条保证不同于原类型，但可与其他槽重复。第 N 次洗练消耗 `N` 张 `refine_talisman`，计数由整件装备的 `refine_count` 保存。

### 升阶

`T -> T+1` 消耗矿石 `8T` 和升阶石 `2T`。升阶不要求强化满级，已穿戴装备也可操作。

升阶保留强化分配、现有词条、洗练次数、穿戴者和来源；基础属性切换到新阶位资源值。升至二阶和三阶时补齐新增词条槽，三阶以后不再增加。五阶不可继续升阶。

### 经济循环

- 强化石 `enhancement_stone`：物品号 1062，不可购买、回收、委托或直接使用。
- 升阶石 `ascension_stone`：物品号 1063，不可购买、回收、委托或直接使用。
- Boss 每次死亡必掉与自身数字阶位相同数量的升阶石，且不替换原有掉落。
- 分解装备获得 `T + floor(已分配强化点 / 2)` 个强化石，不再返矿石。
- 已装备物品不能分解。
- 敌人掉落和炼器仍可按现有权重直接产出高阶装备。
- 装备图纸已退出掉落、保底、坊市和炼器解锁。

### 战斗顺序

装备词条只影响普通攻击和直接技能伤害，不影响 DOT、反伤或 Mod 自定义伤害。直接伤害顺序为：

1. 直接伤害加成。
2. 暴击判定与 1.5 倍暴击伤害。
3. 固定破防后进行防御结算。
4. 五行克制倍率。
5. 直接受伤减免。
6. 护盾吸收。
7. 按实际扣血计算吸血。

直接技能治疗在治疗值解析后应用治疗加成。

## 存档迁移

当前存档版本为 Schema 18。

- 旧 `weapon` 映射为 `weapon_metal_sword`；旧 `accessory` 映射为 `accessory_wood`。
- 固定基础属性改为读取当前阶位资源配置，旧随机基础属性不再参与结算。
- 旧强化总次数投入模板第一项固定属性，不重置强化和洗练次数。
- 旧装备按 `instance_id` 稳定生成 `min(T, 3)` 个词条，不消耗存档 RNG。
- 旧图纸每张补偿矿石 x4 后移除；解锁状态和保底计数清空。

## Mod API 2

装备定义可选提供 `tier_base_attributes`，缺失时按槽位使用核心默认值。本版本不开放 Mod 自定义词条类型。

## 维护与验收

- 十四个装备资源必须完整配置 t1 至 t5。
- 新增词条必须同时更新定义、聚合、结算、详情显示和测试。
- 装备实例的 `affixes` 不得超过三个。
- Schema 18 迁移必须保持确定性，不得消耗主存档 RNG。
