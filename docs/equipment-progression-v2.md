# 装备成长 V2

## 状态摘要

当前实现使用五阶装备、六个槽位基础模板、实例五行原型、随机基础属性、手动强化分配和随机战斗词条。装备没有角色等级穿戴要求；炼器不需要图纸解锁。

事实来源：

- 模板、原型与经济常量：[data_tables.gd](../scripts/game/data/data_tables.gd)
- 装备静态资源：[resources/equipment/](../resources/equipment/)
- 存档与操作接口：[game_state.gd](../scripts/game/core/game_state.gd)
- 战斗结算：[combat_skill_executor.gd](../scripts/game/combat/combat_skill_executor.gd)

## 六槽位模板

核心注册表只包含 `weapon`、`helmet`、`armor`、`leggings`、`gloves`、`accessory`。随机炼器和敌人掉落在六个模板间等概率选择；定向打造只选择槽位，不能指定五行原型或随机属性。

武器和饰品生成时等概率选择一个五行原型。旧五行模板 ID 只作为创建和存档迁移别名，不进入打造、掉落或调试模板列表。

装备实例保存 `equipment_variant_id`、`equipment_base_name`、`rolled_attribute_stats` 和最终 `base_attributes`。加载存档时不会重新抽取实例属性。

## 固定双属性

| 序列 | t1 | t2 | t3 | t4 | t5 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 武器主属性 `P` | 2 | 5 | 10 | 18 | 30 |
| 武器特色副属性 `Q` | 1 | 2 | 4 | 7 | 12 |
| 非武器主属性 `A` | 1 | 3 | 6 | 12 | 20 |
| 非武器特色副属性 `B` | 1 | 2 | 4 | 6 | 10 |

气血按点数乘 4，法力乘 2，其他属性按原点数计算。

| 原型或模板 | 主属性 | 特色副属性 |
| --- | --- | --- |
| 玄金剑 | `element_metal P` | `attack Q` |
| 青木杖 | `element_wood P` | `max_hp Q×4` |
| 镇岳拳套 | `element_earth P` | `defense Q` |
| 沧水符笔 | `element_water P` | `max_mp Q×2` |
| 赤焰法环 | `element_fire P` | `attack Q` |
| 聚灵冠 | `max_mp A×2` | `defense B` |
| 镇元法衣 | `defense A` | `max_hp B×4` |
| 行脉胫甲 | `max_hp A×4` | `defense B` |
| 锻骨护手 | `root_bone A` | `attack B` |
| 青木佩 | `element_wood A` | `max_hp B×4` |
| 赤焰珠 | `element_fire A` | `attack B` |
| 厚土印 | `element_earth A` | `defense B` |
| 玄金令 | `element_metal A` | `attack B` |
| 沧水环 | `element_water A` | `max_mp B×2` |

## 实例随机属性

- t1 至 t5 分别追加 1/2/3/4/5 项随机属性，因此最终基础属性总数为 3/4/5/6/7。
- 随机池包含攻击、防御、气血、法力、根骨和五行十种属性。
- 随机属性不与固定双属性或其他随机属性重复，保存顺序即抽取顺序。
- 武器随机层共享一份 `Q` 预算，其他槽位共享一份 `B` 预算。整除余数按保存顺序分给前几项。
- 换算后，同阶总点数预算为武器 `P + 2Q`、非武器 `A + 2B`；随机属性数量只改变分配宽度，不改变该层总预算。
- 相同 RNG 状态会得到相同原型、随机属性和数值。实例生成后以存档字段为准，不按模板重新抽取。

## 强化、词条与升阶

各阶累计强化点上限为 `10/20/30/40/50`。每点消耗强化石 x1，可选择实例 `base_attributes` 中任一属性；气血每点 +4，法力每点 +2，其他属性每点 +1。

阶位词条槽数为 `1/2/3/3/3`，单件装备最多三个随机战斗词条。洗练通过索引替换一个词条槽，第 N 次洗练消耗 N 张洗练符。

`T -> T+1` 消耗矿石 `8T` 和升阶石 `2T`。升阶保留五行原型、已有随机属性及顺序、强化分配、词条、洗练次数、穿戴者和来源；补抽到新阶位要求的随机属性数量，再按新阶固定值和随机预算重算 `base_attributes`。五阶不可继续升阶。

## 经济与战斗

- Boss 每次死亡必掉与自身数字阶位相同数量的升阶石。
- 分解装备获得 `T + floor(已分配强化点 / 2)` 个强化石，不返还矿石；已装备物品不能分解。
- 装备图纸已退出掉落、保底、坊市和炼器解锁。
- 装备词条影响普通攻击和直接技能伤害，不影响 DOT、反伤或 Mod 自定义伤害。
- 直接伤害依次结算直接伤害加成、暴击、破防与防御、五行克制、直接减伤、护盾和吸血。

## 存档迁移

当前存档版本为 Schema 20。

- Schema 20 将五个旧武器 ID 映射到 `weapon`，五个旧饰品 ID 映射到 `accessory`，并保存对应五行原型、名称和图标。
- 旧装备已有 `base_attributes` 原样固化，缺失时按旧模板和阶位确定性还原；迁移不会添加随机属性或消耗 RNG。
- 旧装备的 `rolled_attribute_stats` 初始化为空，之后只有升阶会补抽新属性。
- 强化分配、强化总数、词条、洗练、穿戴者、实例 ID 和来源保持不变。
- Schema 19 的木杖、土拳套和水符笔攻击强化映射仍先执行，再进行 Schema 20 模板收敛。
- Schema 18 的图纸补偿、稳定词条和旧单模板兼容继续保留。

## Mod API 2

Mod 装备继续兼容固定模板格式。`EquipmentTemplate` 可选提供 `attribute_variants`、`random_attribute_pool`、`tier_random_attribute_counts` 和 `tier_random_attribute_budgets`；随机配置为空时不启用实例随机层，仍直接使用 `tier_base_attributes`。本版本不开放 Mod 自定义战斗词条类型。

## 维护与验收

- 六个核心资源必须完整配置 t1 至 t5；武器和饰品资源必须各包含五个五行原型。
- 固定双属性与随机属性不得重复，最终基础属性顺序必须稳定。
- 新增词条必须同步更新定义、聚合、结算、详情显示和测试。
- Schema 18、19 和 20 迁移必须保持确定性，不得消耗主存档 RNG。
