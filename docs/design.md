# 挂机家园 2D 横版原型设计文档。

## 项目定位

这是一个运行在桌面任务栏上方的 2D 横版挂机家园原型。玩家点击家园地图节点打开对应 HUD 面板，通过面板按钮直接进行打坐、种田、炼器、炼丹或战斗，并在挂机过程中获得资源、经验、装备、熟练度、根骨与五行成长。
第一版目标是验证核心闭环：
- 桌宠窗口：无边框、置顶、透明背景，窗口底边贴住系统任务栏顶部。
- 双区块地图：家园负责恢复、种田、炼器、炼丹；历练入口负责打怪、经验、掉落和装备。
- 家园交互：点击 `meditate`、`farmland`、`forge`、`alchemy`、`fight` 打开对应 HUD 面板。
- 背包系统：统一管理技能书、装备、材料、作物、丹药和图纸，支持右键使用、丢弃、装备强化与洗练。
- 成长系统：等级、修为、熟练度、根骨、五行、装备词条和丹药 Buff 共同影响玩家数值。

## 地图与交互

家园场景 `res://scripts/map/home.tscn` 的根节点挂载 `HomeMap` 脚本。可交互节点按名称匹配逻辑：`meditate`、`farmland`、`forge`、`alchemy`、`fight`。节点下的 `Area2D` 接收左键点击并发出节点名称，由主场景打开对应 HUD 面板。

当前动作流程：
1. 玩家点击家园节点。
2. HUD 打开对应弹窗，并应用已保存的弹窗位置。
3. 玩家点击弹窗按钮或选择配方/数量。
4. `main.gd` 或 `GameState` 直接结算资源、经验、熟练度、装备、丹药或战斗状态。
5. `GameState.changed` 触发 HUD 刷新与存档延迟写入。

角色表现保留桌宠待机逻辑：`IDLE`、`ROAMING`、`TALKING`、`PAUSED`。进入历练后，角色切换为 `EXPEDITION_RUNNING`，在循环地图中持续前进；进入战斗时保持在地图内移动状态，按攻击距离和技能释放距离决定出手时机。

## 背包与物品

物品实例统一包含：
- `item_id`：物品定义 ID。
- `type`：物品类型，例如 `equipment`、`material`、`crop`、`pill`、`alchemy_recipe`、`skill_book`。
- `name` / `description`：显示文本。
- `count` / `stackable`：数量与是否堆叠。
- `usable`：是否允许右键使用。
- `payload`：分类专属数据，例如恢复量、丹方 ID、种子产量、持续 Buff、突破效果等。

### 主要类型

- 技能书：使用后学习对应技能，已学习则不重复消耗。
- 装备：使用后尝试穿戴到武器、头盔、护甲、胫甲、护手、饰品 1 或饰品 2；饰品优先填空槽，满槽时替换饰品 1。
- 材料：炼器、强化、洗练、战斗奖励和其他消耗项。
- 作物：既是炼丹材料，也可作为农田种子。
- 丹药：分为一次性丹药和持续丹药；一次性立即结算，持续型加入 `active_buffs`。
- 图纸：`alchemy_recipe` 类型，使用后学习丹方并写入 `known_alchemy_recipes`。

背包 UI 使用 5×5 网格。每格预留图标位置，悬浮显示物品介绍，双击只直接使用装备和丹药；图纸、技能书、材料、作物仍通过右键菜单使用或不响应直接使用。

## 核心计算公式

### 属性总值

人物与装备可叠加的基础属性类型见 `docs/item-table.md` 的“人物与装备基础属性类型表”。普通属性来自 `GameState.stats`，五行属性来自 `GameState.elements`；装备使用同名 `stat` 写入 `base_attributes`、`enhanced_attributes` 和 `refine_affixes`。

- `total_stat(stat) = stats[stat] + active_buff_bonus(stat) + equipped_attribute_bonus(stat)`
- `total_element(element) = elements[element] + equipped_attribute_bonus("element_" + element)`
- `element_power = sum(total_element(wood, fire, earth, metal, water))`
- `total_attack = stats.attack + int(element_power * 0.15) + active_buff_bonus("attack") + equipped_attribute_bonus("attack")`
- `total_defense = stats.defense + active_buff_bonus("defense") + equipped_attribute_bonus("defense")`
- 主五行为 `total_element()` 数值最高的五行。

### 成长与突破

- 经验增加后，只要 `exp >= next_exp` 且等级上限已打开，就升级。
- 经验升级消耗当前 `next_exp`，然后 `next_exp = int(next_exp * 1.35) + 20`。
- 打坐基础修为来自主流程：`8 + level`。
- 实际修为收益：`base_amount + int(total_root_bone * 0.4)`。
- 修为升级消耗当前 `next_cultivation`，然后 `next_cultivation = int(next_cultivation * 1.35) + 15`。
- 每次升级随机增加：`max_hp 8~20`、`max_mp 4~12`、`attack 1~3`、`defense 0~2`、`root_bone 0~1`，并随机一个五行增加 `1~3`。
- 达到等级上限时，使用突破丹可提升阶段并使 `level_cap += 10`；若 `root_bone > level`，可免突破丹打开下一阶段。

### 根骨加成

- 修为收益加成：`int(total_root_bone * 0.4)`。
- 炼器/装备生成加成：`craft_bonus = int(total_root_bone * 0.2)`。
- 炼丹额外出丹概率：`min(0.35, total_root_bone * 0.015)`。
- 根骨高于当前等级且达到等级上限时，可免道具突破。

### 战斗

- 玩家普通攻击基础伤害：`max(1, total_attack - enemy.defense)`。
- 普通攻击元素为玩家主五行；技能攻击元素为技能自身 `element`。
- 元素伤害加成：`int(total_element(element) * 0.5)`。
- 命中敌人弱点时额外增加：`max(1, int(base_damage * 0.25)) + total_element(element)`。
- 技能伤害基础值：`int(total_attack * skill.damage_multiplier)`，再走同元素/弱点加成。
- 物理减伤：`max(1, amount - total_defense)`。
- 元素减伤：`max(0, amount - int(total_element(element) * 0.35))`。
- 敌人攻击可按 `element_attack_ratio` 随机附带自身五行。
- 历练战斗在循环地图上进行，普通攻击需要满足攻击距离，技能需要满足释放距离。

### 掉落与装备掉落

- 战斗胜利先结算敌人 `drops` 表：每个物品独立判断 `rng.randf() <= chance`，数量为 `randi_range(min, max)`。
- 普通掉落结算后，独立进行装备掉落：当前条件下有 35% 概率获得 1 件装备。
- 掉落装备调用 `create_equipment(enemy.level, rng, craft_bonus)`，因此 `equipment_level = enemy.level`。
- 掉落装备槽位从 `EQUIPMENT_DEFS` 随机选择：武器、头盔、护甲、胫甲、护手或饰品。
- 掉落装备不再随机五行身份，统一按槽位模板生成基础属性；五行只作为随机词条出现。
- 掉落装备阶位按 `EQUIPMENT_RARITY_DEFS` 概率随机，阶位决定显示名、随机词条数量、词条倍率和穿戴需求倍率。
- 掉落装备获得不做属性门槛；穿戴时才检查 `equip_requirement`。

### 生产与炼制

- 种田自动选择背包中第一个作物作为种子，消耗 1 个，产量为 `seed_yield + farm_level - 1`。
- 炼器消耗 2 个 `ore`，生成 1 件随机装备，并获得经验与炼器熟练度。
- 炼丹面板只展示 `known_alchemy_recipes` 中的已学丹方。
- 单个丹方最大可制作数量为所有材料 `floor(当前数量 / 单次需求)` 的最小值。
- 批量炼丹消耗 `amount * 单次需求`，基础产物数量为 `amount`。
- 每次制作独立判定额外出丹：若 `rng.randf() < alchemy_extra_chance()`，本次额外 `+1` 产物，不增加材料消耗。

### 装备生成、穿戴与养成

- 装备名称格式：`<阶位名>·<槽位名>`。
- 阶位 `t1..t5` 对应 `rarity_tier = 1..5`，随机词条数量等于 `rarity_tier`。
- 基础属性只来自装备模板，基础值：`round((base + equipment_level * level_scale + craft_bonus) * rarity_multiplier)`，最低为 1。
- 随机词条写入 `affixes`，词条值：`round((random(min, max) + equipment_level * scale + craft_bonus) * rarity_multiplier)`，最低为 1。
- 穿戴需求：按装备模板的需求属性检查；需求值为 `max(1, equipment_level * rarity_tier)`。
- 穿戴校验不计入候选装备自身属性；替换同槽位装备时，也不计入即将被替换掉的同槽位装备。
- 普通强化消耗装备已有基础属性对应的灵石，消耗数量为 `enhance_count + 1`，强化值由灵石品质决定。
- 洗练消耗洗练符，消耗数量为 `refine_count + 1`；每次随机一条属性百分比词条，百分比为 `0.05~0.15` 并按 `0.01` 对齐。
- 装备最终词条值为基础/强化加法值乘以同属性洗练百分比：`floor(flat_value * (1 + percent_bonus))`。

### 阵营武器设定

阵营武器是武器模板的风格化扩展，仍然遵循现有的装备生成、强化、洗练与穿戴规则。两套阵营分别强调不同的数值方向：

- 儒家：礼、义、文、守、正，偏向稳定、防御、辅助与持续作战。
- 道家：道、法、自然、虚实、阴阳，偏向灵动、爆发、控制与元素调和。

#### 儒家五器

1. **礼剑**：均衡近战武器，倾向 `attack`、`accuracy`、少量 `defense`，适合稳定输出与前期过渡。
2. **仁杖**：辅助型法器，倾向 `max_hp`、`hp_regen`、护盾或治疗类词条，适合持久战与续航流。
3. **义简**：快速短兵器，倾向 `attack_speed`、`crit_rate`、`counter_rate`，适合高频打击。
4. **礼印**：防守型器具，倾向 `defense`、`block_rate`、`damage_reduce`，适合承伤与保护。
5. **经卷**：远程文法武器，倾向 `spell_attack`、`accuracy`、`buff_duration`，适合文气压制。

#### 道家五器

1. **拂尘**：轻灵近中程武器，倾向 `evasion`、`move_speed`、持续伤害类词条，适合游击打法。
2. **太极环**：攻守兼备的法器，倾向 `defense`、`reflect_rate`、`element_balance`，适合阴阳调和流。
3. **符箓**：远程术式武器，倾向 `element_damage`、`control_rate`、`slow_rate`，适合控制压制。
4. **青木杖**：自然系法器，倾向 `wood`、`hp_regen`、持续恢复类词条，适合续航与生机成长。
5. **云剑**：高机动爆发武器，倾向 `crit_rate`、`penetration`、`move_speed`，适合高风险高收益打法。

阵营武器可与对应阵营套装组成完整流派，形成“武器 + 防具 + 饰品”的统一 build。

## HUD 与存档

HUD 包含菜单按钮、玩家信息、背包、种田、炼器、炼丹、打坐、战斗等弹窗。玩家信息只展示属性、已穿戴装备和已学习技能；装备和技能槽位预留美术图标位置。所有弹窗支持拖动，拖动位置写入 `user://save.cfg` 并在下次打开时恢复，超出视口时会 clamp 回可见区域。

存档由 `SaveManager` 写入 `user://save.cfg`，包含版本号、游戏状态、HUD 面板位置和基础配置。缺失字段使用默认值，不阻塞启动。

## 扩展约定

新增堆叠物品时优先在 `DataTables.ITEM_DEFS` 增加定义；新增技能同步扩展 `SKILL_DEFS`；新增装备模板同步扩展 `EQUIPMENT_DEFS`；新增敌人同步扩展 `ENEMY_TEMPLATES`；新增词条同步扩展 `EQUIPMENT_ATTRIBUTE_DEFS`。
后续可扩展：物品品质颜色和图标字串、配方 UI、商店、技能书掉落来源、丹药持续 Buff 的更多类型和叠加规则、农田升级消耗、种子选择 UI、强化失败率、词条锁定和保底机制。

## 历练地图、随机遇怪与循环战斗补充

点击家园 `fight` 节点后，玩家通过 HUD 打开历练面板进入 `BattleMap` 历练地图。进入历练后不会立刻连续战斗，而是隐藏家园、显示历练地图、让角色播放 `run` 动画，并通过远景/地面两层循环滚动背景表现持续赶路。

怪物刷新由 `BattleMap` 维护随机间隔计时，默认在 `8.0` 到 `20.0` 秒之间。计时到达且当前不在战斗时，`BattleMap` 发出 `monster_spawn_requested`，主场景再调用 `CombatController.begin_encounter(game_state, battle_map)` 开始一场循环地图内战斗。战斗结束后清空当前遭遇，结算打怪熟练度，并调用 `BattleMap.finish_combat()` 重新安排下一次随机遇怪，角色继续留在历练地图中跑步等待。

`CombatController` 负责这一场战斗的全部处理，包括敌人生成、自动/手动动作、攻击距离判定、技能释放距离判定、技能冷却、受伤、胜负、掉落和经验结算。普通攻击按角色攻击距离判断，技能按技能 `release_distance` 判断；距离不足时先靠近，满足后再出手。
