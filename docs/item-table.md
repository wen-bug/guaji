# 详细物品表

本文档是独立物品表，依据 `scripts/game/data_tables.gd` 当前数据整理，不覆盖 `docs/design.md` 的玩法说明。

## 物品分类

- `skill_book`：技能书，使用后学习技能。
- `equipment`：装备，穿戴后提供属性加成。
- `material`：材料，炼器、强化、洗练和掉落用途。
- `crop`：作物，既可作为种子，也可作为炼丹材料。
- `pill`：丹药，一次性丹药或持续丹药。
- `alchemy_recipe`：炼丹图纸，使用后学习丹方。
- `stone`：灵石，强化装备时消耗。

## 物品定义字段

- `item_id`：物品唯一 ID。
- `name`：显示名称。
- `description`：描述文本。
- `type`：物品类型。
- `stackable`：是否堆叠。
- `usable`：是否可直接使用。
- `payload`：物品专属数据。

## 技能书

技能书使用后解锁对应技能；如果角色已学习，则不再消耗。

## 装备

装备分为武器、头盔、护甲、胫甲、护手和饰品。装备使用后会尝试穿戴到对应槽位，饰品槽优先填空槽，满槽时替换饰品 1。

装备生成与养成字段包括：

- `equipment_level`：装备等级。
- `rarity_tier`：阶位。
- `base_attributes`：基础属性。
- `enhanced_attributes`：强化属性。
- `refine_affixes`：洗练词条。
- `equip_requirement`：穿戴需求。

## 材料

材料用于炼器、强化、洗练、战斗掉落和其他消耗项。

常见材料包括：

- 灵石。
- 强化石。
- 洗练符。
- 炼器矿材。
- 战斗掉落素材。

## 作物

作物既是农田种子，也可作为炼丹材料。种田时会自动消耗背包里第一个可用作物。

## 丹药

丹药分为两类：

- 一次性丹药：使用后立即结算恢复、加成或突破效果。
- 持续丹药：使用后写入 `active_buffs`，持续一段时间。

## 炼丹图纸

图纸使用后写入 `known_alchemy_recipes`。炼丹面板只显示已学丹方。

## 背包规则

- 背包采用 5×5 网格。
- 悬浮时显示物品说明。
- 双击只直接使用装备和丹药。
- 图纸、技能书、材料和作物通过右键菜单或专用面板使用。
- 堆叠物品优先合并，同类物品共享数量字段。

## 装备穿戴规则

- 武器只穿戴到武器槽。
- 头盔、护甲、胫甲、护手分别进入对应防具槽。
- 饰品会优先填空槽，再替换饰品 1。
- 穿戴时检查 `equip_requirement`。
- 已穿戴装备参与属性总值计算。

## 物品表维护

新增物品时优先补充 `DataTables.ITEM_DEFS`，再补充 UI 展示与掉落来源。新增丹方、装备或技能时应同步更新对应的工厂函数和测试用例。

## 数值平衡基准

本节用于统一角色成长、装备阶位、武器基础属性与词条数值，方便后续在 `DataTables` 中实现。

### 角色等级属性点

- 角色每升 1 级获得 `5` 点自由属性点。
- 每 `10` 级额外获得 `+2` 点。
- 每 `20` 级额外获得 `+3` 点。
- `50` 级后仍保持每级 `5` 点，但主强度更依赖装备与词条。

### 初始基础属性

- `attack = 10`
- `defense = 8`
- `max_hp = 120`
- `accuracy = 10`
- `evasion = 10`
- `crit_rate = 5`
- `attack_speed = 100`
- 五行初始各 `5`

### 属性换算规则

- `1 attack` = `+2` 伤害底值。
- `1 defense` = `+1.5%` 等效减伤。
- `1 max_hp` = `+10 HP`。
- `1 accuracy` = `+1` 命中。
- `1 evasion` = `+1` 闪避。
- `1 crit_rate` = `+0.5%` 暴击率。
- `1 crit_damage` = `+1%` 暴击伤害。
- `1 attack_speed` = `+0.5%` 攻速。
- `1 move_speed` = `+0.5%` 移速。

### 装备阶位倍率

- `t1`：基础属性倍率 `1.00`，词条数量 `1`，词条强度倍率 `1.00`。
- `t2`：基础属性倍率 `1.15`，词条数量 `2`，词条强度倍率 `1.10`。
- `t3`：基础属性倍率 `1.35`，词条数量 `3`，词条强度倍率 `1.25`。
- `t4`：基础属性倍率 `1.60`，词条数量 `4`，词条强度倍率 `1.45`。
- `t5`：基础属性倍率 `1.90`，词条数量 `5`，词条强度倍率 `1.70`。

### 武器基础属性模板

武器按等级给出主副属性，便于统一掉落、炼器和阵营武器设计。

- 主属性基础值：`8 + equipment_level * 2.2`
- 副属性基础值：`3 + equipment_level * 0.9`
- 高阶武器可额外附带 1 个小词条

### 词条数值范围

- `1~10` 级：`+3 ~ +8`
- `11~20` 级：`+8 ~ +16`
- `21~30` 级：`+16 ~ +28`
- `31~40` 级：`+28 ~ +45`
- `41~50` 级：`+45 ~ +70`

### 百分比词条范围

- `t1`：`2% ~ 4%`
- `t2`：`4% ~ 6%`
- `t3`：`6% ~ 9%`
- `t4`：`9% ~ 12%`
- `t5`：`12% ~ 16%`

### 阵营武器词条倾向

- 儒家武器优先：`attack`、`accuracy`、`defense`、`max_hp`、`block_rate`、`buff_duration`。
- 道家武器优先：`evasion`、`move_speed`、`crit_rate`、`penetration`、`element_damage`、`control_rate`。


### 阵营武器清单

以下武器作为文档级平衡参考，默认按武器槽使用，实际掉落和炼器可映射到现有 `equipment` 体系。

| 武器 | 阵营 | 定位 | 主属性 | 副属性 | 词条倾向 |
| --- | --- | --- | --- | --- | --- |
| 礼剑 | 儒家 | 均衡近战 | `attack` | `accuracy`、`defense` | 稳定输出、命中、少量防御 |
| 仁杖 | 儒家 | 辅助法器 | `max_hp` | `hp_regen`、`buff_duration` | 续航、治疗、护盾 |
| 义简 | 儒家 | 快速短兵 | `attack_speed` | `crit_rate`、`counter_rate` | 高频打击、反击 |
| 礼印 | 儒家 | 防守器具 | `defense` | `block_rate`、`damage_reduce` | 承伤、减伤、保护 |
| 经卷 | 儒家 | 文法远程 | `spell_attack` | `accuracy`、`buff_duration` | 远程压制、增益延长 |
| 拂尘 | 道家 | 轻灵近中程 | `evasion` | `move_speed`、`dot_damage` | 游击、持续伤害 |
| 太极环 | 道家 | 攻守法器 | `defense` | `reflect_rate`、`element_balance` | 阴阳调和、反弹 |
| 符箓 | 道家 | 远程术式 | `element_damage` | `control_rate`、`slow_rate` | 元素压制、控制 |
| 青木杖 | 道家 | 自然法器 | `wood` | `hp_regen`、`heal_rate` | 续航、生机成长 |
| 云剑 | 道家 | 高机动爆发 | `crit_rate` | `penetration`、`move_speed` | 爆发、穿透、机动 |

#### 武器基础值建议

- 1~10 级：主属性 `18~30`，副属性 `8~14`。
- 11~20 级：主属性 `31~52`，副属性 `14~24`。
- 21~30 级：主属性 `53~78`，副属性 `24~34`。
- 31~40 级：主属性 `79~108`，副属性 `34~46`。
- 41~50 级：主属性 `109~142`，副属性 `46~60`。



### 阵营装备套装清单

两套装备为完整阵营套装，默认对应现有武器库搭配使用；数值基准与阶位倍率仍沿用本表前文的统一规则。

#### 儒家正礼套

| 装备 | 槽位 | 主属性 | 副属性 | 套装定位 |
| --- | --- | --- | --- | --- |
| 正冠 | 头盔 | `defense` | `accuracy`、`max_hp` | 稳定承伤、提高命中 |
| 礼袍 | 护甲 | `max_hp` | `defense`、`damage_reduce` | 提升生存、减伤 |
| 守履 | 胫甲 | `defense` | `move_speed`、`block_rate` | 站稳阵线、格挡防守 |
| 义护 | 护手 | `attack` | `accuracy`、`counter_rate` | 兼顾输出与反击 |
| 仁佩 | 饰品 1 | `hp_regen` | `buff_duration`、`max_hp` | 续航与增益延长 |
| 文璧 | 饰品 2 | `accuracy` | `spell_attack`、`buff_duration` | 提高文法命中与持续收益 |

**儒家正礼套效果**
- 2 件：`defense +5%`
- 4 件：`buff_duration +8%`
- 6 件：受到伤害后短时间提高 `damage_reduce`

#### 道家清虚套

| 装备 | 槽位 | 主属性 | 副属性 | 套装定位 |
| --- | --- | --- | --- | --- |
| 云冠 | 头盔 | `evasion` | `move_speed`、`element_damage` | 提升闪避与灵动 |
| 清袍 | 护甲 | `defense` | `evasion`、`reflect_rate` | 防御兼反弹 |
| 逍遥履 | 胫甲 | `move_speed` | `evasion`、`slow_resist` | 高机动游走 |
| 玄护 | 护手 | `crit_rate` | `penetration`、`attack_speed` | 爆发与穿透 |
| 阴阳佩 | 饰品 1 | `element_balance` | `control_rate`、`element_damage` | 调和元素与控制 |
| 太虚符 | 饰品 2 | `control_rate` | `slow_rate`、`crit_damage` | 控制强化与爆发补正 |

**道家清虚套效果**
- 2 件：`evasion +5%`
- 4 件：`move_speed +8%`
- 6 件：触发暴击或控制时提高 `element_damage`

#### 武器词条权重建议

- 儒家武器：`attack` 40%、`accuracy` 20%、`defense` 15%、`max_hp` 10%、功能词条 15%。
- 道家武器：`crit_rate` 20%、`move_speed` 20%、`evasion` 15%、元素/控制 30%、功能词条 15%。
