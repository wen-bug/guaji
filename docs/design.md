# 挂机家园 2D 横版原型设计文档。

## 项目定位

这是一个运行在桌面任务栏上方的 2D 横版挂机家园原型。玩家点击家园地图节点打开对应 HUD 面板，通过面板按钮进行招募、种田、炼器、炼丹或战斗，并在挂机过程中获得资源、经验、装备、熟练度、根骨与五行成长。
第一版目标是验证核心闭环：
- 桌宠窗口：无边框、置顶、透明背景，窗口底边贴住系统任务栏顶部。
- 双区块地图：家园负责恢复、种田、炼器、炼丹；历练入口负责打怪、经验、掉落和装备。
- 家园交互：点击原 `meditate` 位置打开招募 HUD；点击 `farmland`、`forge`、`alchemy`、`fight` 打开对应 HUD 面板。
- 背包系统：统一管理技能书、装备、材料、作物、丹药和图纸，主背包仅保留家园效率类物品的使用入口，支持丢弃、装备强化与洗练。
- 成长系统：玩家和队友共享等级、熟练度、根骨、五行、先天命格、装备词条和丹药 Buff 等数值规则。

## 地图与交互

家园场景 `res://scripts/map/home.tscn` 的根节点挂载 `HomeMap` 脚本。可交互节点按名称匹配逻辑：原 `meditate` 节点现在映射为招募，`farmland`、`forge`、`alchemy`、`fight` 保持原用途。节点下的 `Area2D` 接收左键点击并发出节点名称，由主场景打开对应 HUD 面板。

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
- `obtain_source`：来源标记，当前用 `drop` / `non_drop` 区分掉落与非掉落实例。
- `use_scope` / `use_target`：使用分组与用途目标，当前按 `home / combat / none` 分层，家园目标再细分为农田、炼丹、炼器和招募等用途。

### 主要类型

- 技能书：使用后学习对应技能，已学习则不重复消耗。
- 装备：使用后尝试给当前选中的队伍成员穿戴到武器、头盔、护甲、胫甲、护手、饰品 1 或饰品 2；饰品优先填空槽，满槽时替换饰品 1。同一装备只能由一名成员穿戴。
- 材料：炼器、强化、洗练、战斗奖励和其他消耗项。
- 作物：既是炼丹材料，也可作为农田种子。
- 丹药：分为一次性丹药和持续丹药；一次性立即结算，持续型加入 `active_buffs`。
- 图纸：`alchemy_recipe` 类型，使用后学习丹方并写入 `known_alchemy_recipes`。

背包 UI 使用 5×5 网格。每格只显示图块，悬浮时展示名称、类型、数量、描述、使用分组与来源；主背包仅允许家园效率类物品使用，战斗类物品只展示不直接使用。

## 核心计算公式

### 属性总值

人物与装备可叠加的基础属性类型见 `docs/item-table.md` 的“人物与装备基础属性类型表”。普通属性来自 `GameState.stats`，五行属性来自 `GameState.elements`；装备使用同名 `stat` 写入 `base_attributes`、`enhanced_attributes` 和 `refine_affixes`。

- `total_stat(stat) = stats[stat] + active_buff_bonus(stat) + equipped_attribute_bonus(stat) + innate_trait_bonus(stat)`
- `total_element(element) = elements[element] + equipped_attribute_bonus("element_" + element) + innate_trait_element_bonus(element)`
- `element_power = sum(total_element(wood, fire, earth, metal, water))`
- `total_attack = stats.attack + int(element_power * 0.15) + active_buff_bonus("attack") + equipped_attribute_bonus("attack") + innate_trait_bonus("attack")`
- `total_defense = stats.defense + active_buff_bonus("defense") + equipped_attribute_bonus("defense") + innate_trait_bonus("defense")`
- 主五行为 `total_element()` 数值最高的五行。

### 成长与突破

- 玩家和队友各自拥有 `stats/elements/equipped/skills` 成员数据，队伍顺序由 `party_order` 保存，队伍最多 4 人且玩家始终在队伍中。
- 经验增加后，只要 `exp >= next_exp` 且等级上限已打开，就升级。
- 经验升级消耗当前 `next_exp`，然后 `next_exp = int(next_exp * 1.35) + 20`。
- 玩家和队友每次升级自动获得 5 点属性成长，不再在 HUD 中手动加点；`max_hp` 每点 +4，`max_mp` 每点 +2，其余每点 +1。
- 玩家升级时 5 点全部从 `attack`、`defense`、`root_bone`、`max_hp`、`max_mp` 或五行属性中随机分配。
- 招募候选人的等级等于当前玩家等级，刷新时随机抽取 3 个成长主属性，从 1 级基础模板开始按 80% 主属性、20% 全随机补齐初始属性点；招募后后续升级沿用该主属性成长。
- 达到等级上限时，使用突破丹可提升阶段并使 `level_cap += 10`；若 `root_bone > level`，可免突破丹打开下一阶段。

### 先天命格

先天词条正式命名为“命格”，属于玩家和队友的先天特质。命格不与装备随机词条混用：装备词条负责短期替换、强化和洗练追求；命格负责角色身份、成长倾向、家园效率和自动战斗风格。

- 玩家开局从 3 个主命格中选择 1 个。
- 队友在招募候选人刷新时随机生成命格。基础候选人会按招募建筑等级获得 `0-n` 个基础命格：1-3 级最多 1 个，4-6 级最多 2 个，7-10 级最多 3 个。
- 每个角色最多拥有 1 个主命格、1 个副命格和 0 到 1 个缺陷命格。
- 普通候选人默认 1 个主命格；优秀候选人可拥有主命格和副命格；异禀候选人可拥有觉醒潜力或缺陷命格。
- 命格第一版不允许普通洗练或频繁替换，只能在角色生成、玩家开局选择或后续突破觉醒时确定。

第一版命格效果优先覆盖低耦合规则：升级成长权重、属性读取加成、炼器 `craft_bonus`、炼丹额外出丹概率、战斗经验、熟练度、材料掉落概率、普通攻击伤害、技能冷却和受伤减免。复杂行为触发器，例如低血护盾、治疗目标偏好、连击链、召唤物或跨成员光环，待基础命格系统稳定后再扩展。

命格详细规则、推荐命格池、数据结构和觉醒规则见 `docs/innate-traits.md`。

### 根骨加成

- 炼器/装备生成加成：`craft_bonus_for(member) = int(total_root_bone_for(member) * 0.2) + 命格修正`。
- 炼丹额外出丹概率：`alchemy_extra_chance_for(member) = total_root_bone_for(member) * 0.015 + 命格修正`，最终按上限截断。
- 种田收成加成：`farm_harvest_amount_for(member) = seed_yield + farm_level - 1 + int(total_root_bone_for(member) * 0.05) + 命格修正`。
- 根骨高于当前等级且达到等级上限时，可免道具突破。

### 战斗

- 队伍成员普通攻击基础伤害：`max(1, total_attack_for(member_id) - enemy.defense)`。
- 普通攻击元素为成员主五行；技能攻击元素为技能自身 `element`。
- 元素伤害加成：`int(total_element(element) * 0.5)`。
- 命中敌人弱点时额外增加：`max(1, int(base_damage * 0.25)) + total_element(element)`。
- 技能伤害基础值：`int(total_attack * skill.damage_multiplier)`，再走同元素/弱点加成。
- 物理减伤：`max(1, amount - total_defense)`。
- 元素减伤：`max(0, amount - int(total_element(element) * 0.35))`。
- 敌人攻击可按 `element_attack_ratio` 随机附带自身五行。
- 历练战斗在循环地图上进行，普通攻击需要满足攻击距离，技能需要满足释放距离。
- `CombatController` 负责单场战斗推进、队伍成员独立冷却、战斗内掉血、掉落和动画触发；`CombatAI` 只负责成员出招选择；`SkillResolver` 只产出技能基础结果和技能 `effects`；`GameState.take_damage_for()` 保留为非战斗兼容入口。
- 木桩敌人默认走基础普攻，作为训练目标时保留低强度攻击与普通受击反馈。

#### 战斗附加效果管线

战斗内技能、装备、命格、敌人动作和临时状态统一使用 `effects` 字段。单条效果通用结构为：`trigger`、`kind`、`target`、`value`、`stat`、`element`、`duration_turns`、`chance`、`stack_key`、`max_stacks`。第一版触发阶段为 `attack_start`、`before_hit`、`on_hit`、`after_damage`、`on_kill`、`on_damaged`、`turn_start`、`turn_end`；效果类型为 `damage_percent`、`damage_flat`、`defense_ignore`、`element_attach`、`dot`、`hot`、`shield`、`heal`、`leech`、`buff_stat`、`debuff_stat`、`cooldown_percent`。

`CombatEffectResolver` 只负责效果筛选、概率判定、状态叠加和事件生成，不播放动画、不直接操作 HUD。`CombatController` 按固定顺序调用：出手 `attack_start` → 入防御前 `before_hit` → 基础伤害与元素/弱点/防御 → 护盾吸收 → 有效伤害后的 `on_hit` → 扣血后的 `on_damaged` / `after_damage` → 死亡后的 `on_kill`。回合开始处理 DOT/HOT，回合结束递减持续 Buff。

玩家和队友的战斗状态写入各自 combatant 的 `combat_effects`，敌人写入 `enemy.combat_effects`。旧 `combat_buffs` 仍保留兼容，属性读取会同时识别旧 Buff 与新 `buff_stat` / `debuff_stat` 效果。未命中、0 伤害或完全被护盾抵消时不触发 `on_hit`，但可以触发 `on_damaged`；DOT/HOT 不触发 `on_hit`；同 `stack_key` 按层数叠加，无 `stack_key` 的同类状态独立存在。同阶段多来源顺序固定为：技能效果 → 装备效果 → 命格效果 → 临时战斗状态。

### 掉落与装备掉落

- 战斗胜利先结算敌人 `drops` 表：每个物品独立判断 `rng.randf() <= chance`，数量为 `randi_range(min, max)`。
- 普通掉落结算后，独立进行装备掉落：当前条件下有 35% 概率获得 1 件装备。
- 掉落装备调用 `create_equipment(enemy.level, rng, craft_bonus, "drop")`，因此 `equipment_level = enemy.level`，并标记为掉落来源。
- 掉落装备槽位从 `EQUIPMENT_DEFS` 随机选择：武器、头盔、护甲、胫甲、护手或饰品。
- 掉落装备不再随机五行身份，统一按槽位模板生成基础属性；五行只作为随机词条出现。
- 掉落装备阶位按 `EQUIPMENT_RARITY_DEFS` 概率随机，阶位决定显示名、随机词条数量、词条倍率和穿戴需求倍率。
- 掉落装备获得不做属性门槛；穿戴时才检查 `equip_requirement`。
- 炼器等非掉落生成的装备调用同一工厂函数，但传入 `non_drop` 来源标记。

### 生产与炼制

- 家园建筑包含招募、农田、炼器、炼丹 4 个主动升级等级，等级上限为 10。升级消耗分别为灵石、草药、矿石、草药；旧 `farm_level` 只作为农田建筑等级的兼容显示字段。
- 种田面板可选择执行队友。种植消耗 1 个种子，产量按农田等级、执行者根骨、装备、Buff 和命格计算，结果写入农田槽位，收取时经验给该执行者。农田等级同时缩短种植时间，时间倍率为 `max(0.55, 1.0 - 0.05 * (farm_level - 1))`。
- 招募消耗灵石；刷新候选免费。招募等级影响候选人的基础命格数量上限。
- 炼器面板可选择执行队友并启动单队列任务。开始时消耗材料，耗时 `max(20, 60 - 4 * (forge_level - 1))` 秒，完成后领取 1 件装备；炼器 6 级后每次领取 2 件装备。炼器等级每级提供 3% 额外装备阶位提升概率。
- 炼丹面板只展示 `known_alchemy_recipes` 中的已学丹方。
- 炼丹面板可选择执行队友。单个丹方最大可制作数量按执行者材料减免后的实际消耗计算。
- 炼丹启动单队列任务。批量炼丹开始时消耗执行者修正后的材料数量，耗时 `max(8, 20 - (alchemy_level - 1)) * amount` 秒，完成后领取丹药。
- 炼丹基础产物数量为 `amount`；炼丹 6 级后基础产物数量翻倍。每次制作独立判定额外出丹：若 `rng.randf() < alchemy_extra_chance_for(member) + 0.02 * (alchemy_level - 1)`，本次额外 `+1` 产物，不增加材料消耗；命格可额外提供固定产量或概率产量。
- 相关炼丹与 Buff 结算仍在 `GameState` 中完成，不放入 HUD 或战斗控制器。

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

HUD 包含菜单按钮、队伍成员信息、背包、种田、炼器、炼丹、招募、历练入口、历练返回和调试等弹窗或控制层。队伍成员信息可选择玩家或队友，展示属性、先天命格、已穿戴装备和已学习技能；招募 HUD 显示候选人、命格摘要、材料成本、队伍顺序、上移/下移和离队操作。所有弹窗支持拖动，拖动位置写入 `user://save.cfg` 并在下次打开时恢复，超出视口时会 clamp 回可见区域。

存档由 `SaveManager` 写入 `user://save.cfg`，包含版本号、游戏状态、HUD 面板位置和基础配置。缺失字段使用默认值，不阻塞启动。

## 扩展约定

新增堆叠物品时优先在 `DataTables.ITEM_DEFS` 增加定义；新增技能同步扩展 `SKILL_DEFS`；新增装备模板同步扩展 `EQUIPMENT_DEFS`；新增敌人时先新增 `scripts/game/enemies/<enemy_id>/enemy.tscn` 和 `enemy.gd`，再补充 `DataTables.ENEMY_TEMPLATES` / `ENEMY_SCENE_PATHS`；新增装备词条同步扩展 `EQUIPMENT_ATTRIBUTE_DEFS`；新增命格同步扩展 `INNATE_TRAIT_DEFS` 和 `docs/innate-traits.md`。
后续可扩展：物品品质颜色和图标字串、配方 UI、商店、技能书掉落来源、丹药持续 Buff 的更多类型和叠加规则、农田升级消耗、种子选择 UI、强化失败率、词条锁定和保底机制。

## 历练地图、随机遇怪与循环战斗补充

点击家园 `fight` 节点后，玩家通过 HUD 打开历练面板进入 `BattleMap` 历练地图。进入和返回历练时会播放加载遮罩。进入历练后不会立刻连续战斗，而是隐藏家园、显示历练地图、让角色播放 `run` 动画，并通过远景/地面两层循环滚动背景表现持续赶路。

怪物刷新由 `BattleMap` 维护随机间隔计时，默认在 `8.0` 到 `20.0` 秒之间。计时到达且当前不在战斗时，`BattleMap` 发出 `monster_spawn_requested`，主场景再调用 `CombatController.begin_encounter(game_state, battle_map)` 开始一场循环地图内战斗。`CombatController` 根据敌人 ID 实例化对应目录下的敌人场景，再把运行时数值同步进该敌人节点。战斗结束后清空当前遭遇，结算打怪熟练度，并调用 `BattleMap.finish_combat()` 重新安排下一次随机遇怪，角色继续留在历练地图中跑步等待。

`CombatController` 负责这一场战斗的全部处理，包括敌人实例化、队伍成员自动行动、技能冷却、受伤、胜负、掉落和经验结算。`CombatAI` 只负责当前成员自动出招；敌人自己的脚本负责攻击与受击反馈。HUD 不提供自动/手动切换、攻击、防御或技能按钮；返回家园会清空当前战斗且不结算本场奖励。
