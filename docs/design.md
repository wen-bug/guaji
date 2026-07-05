# 挂机家园 2D 横版原型设计文档

## 项目定位

这是一个运行在桌面任务栏上方的 2D 横版挂机家园原型。玩家点击家园地图节点打开对应 HUD 面板，通过招募、种田、炼器、炼丹和历练战斗获得资源、经验、装备、熟练度、根骨与五行成长。

第一版目标是验证核心闭环：

- 桌宠窗口：无边框、置顶、透明背景，窗口底边贴住系统任务栏顶部。
- 双区块地图：家园负责恢复、招募、种田、炼器、炼丹和后续商店补给；历练入口负责打怪、经验、掉落和装备。
- 家园交互：点击原 `meditate` 位置打开招募 HUD；点击 `farmland`、`forge`、`alchemy`、`fight` 打开对应 HUD 面板。`shop` 属于规划入口，若场景存在则按商店 HUD 接入。
- 背包系统：统一管理技能书、装备、材料、作物、丹药和图纸，支持使用、丢弃、装备强化与洗练。
- 成长系统：玩家和队友共享等级、熟练度、根骨、五行、先天命格、装备词条和丹药 Buff 等数值规则。

详细物品定义以 `docs/item-table.md` 为准；物品与背包规则见 `docs/items.md`；命格细则见 `docs/innate-traits.md`；历练和战斗细则见 `docs/battle-expedition.md`。

## 地图与交互

家园场景 `res://scripts/map/home.tscn` 的根节点挂载 `HomeMap` 脚本。可交互节点按名称匹配逻辑：原 `meditate` 节点映射为招募，`farmland`、`forge`、`alchemy`、`fight` 保持对应用途。节点下的 `Area2D` 接收左键点击并发出节点名称，由主场景打开对应 HUD 面板。

当前动作流程：

1. 玩家点击家园节点。
2. HUD 打开对应弹窗，并应用已保存的弹窗位置。
3. 玩家点击弹窗按钮或选择配方、数量、执行者。
4. `main.gd` 或 `GameState` 结算资源、经验、熟练度、装备、丹药或战斗状态。
5. `GameState.changed` 触发 HUD 刷新与存档延迟写入。

角色表现保留桌宠待机逻辑：`IDLE`、`ROAMING`、`TALKING`、`PAUSED`。进入历练后，角色切换为历练跑图状态，在循环地图中持续前进；进入战斗时仍处于地图内移动表现，由战斗控制器按距离、冷却和技能规则决定出手。

## 核心系统

### 背包与物品

已实现的物品实例统一包含 `item_id`、`type`、`name`、`description`、`count`、`stackable`、`usable`、`payload`、`obtain_source` 等字段。当前代码中的真实物品、技能、配方、装备模板和敌人掉落以 `DataTables` 为事实来源，见 `docs/item-table.md`。

物品系统的设计边界：

- 技能书：使用后学习对应技能，已学习则不重复消耗。
- 装备：使用后尝试给当前选中队伍成员穿戴到对应槽位；同一装备只能由一名成员穿戴。
- 材料：用于炼器、强化、洗练、战斗奖励和其他消耗项。
- 作物：既是炼丹材料，也可作为农田种子。
- 丹药：一次性丹药立即结算；持续丹药写入 `active_buffs`。
- 图纸：`alchemy_recipe` 类型，使用后学习丹方并写入 `known_alchemy_recipes`。

背包 UI 使用 5x5 网格。每格显示图块或占位，悬浮时展示名称、类型、数量、描述、使用分组与来源。

### 成长与突破

玩家和队友各自拥有 `stats`、`elements`、`equipped`、`skills` 等成员数据，队伍顺序由 `party_order` 保存。队伍最多 4 人，玩家始终在队伍中。

- 经验增加后，只要 `exp >= next_exp` 且等级上限已打开，就升级。
- 经验升级消耗当前 `next_exp`，然后 `next_exp = int(next_exp * 1.35) + 20`。
- 每次升级自动获得 5 点属性成长；`max_hp` 每点 +4，`max_mp` 每点 +2，其余每点 +1。
- 玩家升级成长从攻击、防御、根骨、气血、法力和五行属性中随机分配。
- 招募候选人的等级等于当前玩家等级，并带有自身成长主属性和命格。
- 达到等级上限时，使用突破丹可提升阶段并使 `level_cap += 10`；若根骨高于当前等级，可免突破丹打开下一阶段。

### 属性总值

普通属性来自成员基础 `stats`，五行属性来自 `elements`；装备、Buff 和命格通过属性读取入口叠加。

- `total_stat(stat) = stats[stat] + active_buff_bonus(stat) + equipped_attribute_bonus(stat) + innate_trait_bonus(stat)`
- `total_element(element) = elements[element] + equipped_attribute_bonus("element_" + element) + innate_trait_element_bonus(element)`
- `element_power = sum(total_element(wood, fire, earth, metal, water))`
- `total_attack = stats.attack + int(element_power * 0.15) + active_buff_bonus("attack") + equipped_attribute_bonus("attack") + innate_trait_bonus("attack")`
- `total_defense = stats.defense + active_buff_bonus("defense") + equipped_attribute_bonus("defense") + innate_trait_bonus("defense")`
- 主五行为 `total_element()` 数值最高的五行。

### 先天命格

命格属于玩家和队友的先天特质，用来决定长期差异和队伍定位，不与装备随机词条混用。命格不允许普通洗练或频繁替换，只在角色生成、玩家开局选择或后续突破觉醒时确定。

设计摘要：

- 玩家开局从 3 个主命格中选择 1 个。
- 队友在招募候选人刷新时随机生成命格。
- 每个角色最多拥有 1 个主命格、1 个副命格和 0 到 1 个缺陷命格。
- 第一版命格优先覆盖成长权重、属性读取、家园效率、历练收益和简单战斗修正。

命格池、数值基准、缺陷命格、数据结构和觉醒规则见 `docs/innate-traits.md`。

### 生产与炼制

家园建筑包含招募、农田、炼器、炼丹 4 个主动升级等级，等级上限为 10。建筑等级影响候选命格数量、种植时间、炼器耗时、炼丹耗时和产物收益。

- 招募消耗灵石；刷新候选免费。招募等级影响候选人的基础命格数量上限。
- 种田面板可选择执行者。种植消耗 1 个种子，产量按农田等级、执行者根骨、装备、Buff 和命格计算。
- 炼器面板可选择执行者并启动单队列任务。完成后领取装备，炼器等级影响耗时、产量和品阶提升概率。
- 炼丹面板只展示已学习丹方，可选择执行者和数量。材料消耗、额外出丹和耗时由配方、执行者根骨、建筑等级和命格共同决定。

根骨相关入口：

- `craft_bonus_for(member) = int(total_root_bone_for(member) * 0.2) + 命格修正`
- `alchemy_extra_chance_for(member) = total_root_bone_for(member) * 0.015 + 命格修正`
- `farm_harvest_amount_for(member) = seed_yield + farm_level - 1 + int(total_root_bone_for(member) * 0.05) + 命格修正`

### 战斗与掉落

历练战斗在循环地图上进行。队伍成员全员同场战斗，每个存活成员拥有独立行动冷却、技能冷却和战斗状态。战斗流程、随机遇怪、战斗附加效果和返回家园规则见 `docs/battle-expedition.md`。

高层伤害规则：

- 队伍成员普通攻击基础伤害：`max(1, total_attack_for(member_id) - enemy.defense)`。
- 普通攻击元素为成员主五行；技能攻击元素为技能自身 `element`。
- 元素伤害加成：`int(total_element(element) * 0.5)`。
- 命中敌人弱点时额外增加：`max(1, int(base_damage * 0.25)) + total_element(element)`。
- 技能伤害基础值：`int(total_attack * skill.damage_multiplier)`，再走同元素、弱点和防御规则。
- 物理减伤：`max(1, amount - total_defense)`。
- 元素减伤：`max(0, amount - int(total_element(element) * 0.35))`。

掉落规则：

- 战斗胜利先结算敌人 `drops` 表，每个物品独立判定概率和数量。
- 普通掉落后，独立进行装备掉落判定。
- 掉落装备调用统一装备工厂，`equipment_level = enemy.level`，并标记为 `drop`。
- 掉落装备获得不做属性门槛；穿戴时才检查 `equip_requirement`。

### 装备生成与养成

装备实例名称格式为 `<阶位名>·<装备模板名称>`。当前实现有武器、头盔、护甲、胫甲、护手和饰品 6 个模板。阶位名由运行时动态生成，不写入装备 `.tres` 模板资源。装备基础属性来自模板，随机词条来自装备属性池，强化和洗练通过装备实例字段记录。

装备规则摘要：

- 阶位 `t1..t5` 决定显示名、随机词条数量、词条倍率和穿戴需求倍率。
- 基础属性写入 `base_attributes`，强化加法值写入 `enhanced_attributes`，洗练百分比写入 `refine_affixes`。
- 穿戴需求按装备模板的需求属性检查。
- 强化消耗装备已有基础属性对应的灵石，消耗数量为 `enhance_count + 1`。
- 洗练消耗洗练符，消耗数量为 `refine_count + 1`。

装备表、阶位权重、属性池和规划阵营套装见 `docs/item-table.md`。

### 商店

商店是规划中的家园随机补给入口，用来把挂机掉落、生产材料和低概率成长物品串成可控的资源消耗点。规划规则保留在 `docs/items.md` 的“规划：商店”段落。

## HUD 与存档

HUD 包含菜单按钮、队伍成员信息、背包、种田、炼器、炼丹、招募、历练入口、历练返回和调试等弹窗或控制层。规划中的商店 HUD 显示随机货架、刷新倒计时、刷新成本和购买状态。

队伍成员信息可选择玩家或队友，展示属性、先天命格、已穿戴装备和已学习技能；招募 HUD 显示候选人、命格摘要、材料成本、队伍顺序、上移、下移和离队操作。所有弹窗支持拖动，拖动位置写入 `user://save.cfg` 并在下次打开时恢复，超出视口时会 clamp 回可见区域。

存档由 `SaveManager` 写入 `user://save.cfg`，包含版本号、游戏状态、HUD 面板位置和基础配置。缺失字段使用默认值，不阻塞启动。

## 扩展约定

- 新增堆叠物品时优先在 `DataTables.ITEM_DEFS` 增加定义，并同步 `docs/item-table.md`。
- 新增技能同步扩展 `SKILL_DEFS` 和 `docs/item-table.md`。
- 新增装备模板同步扩展 `EQUIPMENT_DEFS` 和 `docs/item-table.md`。
- 新增敌人时先新增 `scripts/game/enemies/<enemy_id>/enemy.tscn` 和 `enemy.gd`，再补充 `DataTables.ENEMY_TEMPLATES` / `ENEMY_SCENE_PATHS` 和 `docs/item-table.md`。
- 新增命格同步扩展 `INNATE_TRAIT_DEFS` 和 `docs/innate-traits.md`。
- 新增战斗效果或历练流程同步更新 `docs/battle-expedition.md`。
- 规划内容必须标明“规划”，避免和当前实现混淆。
