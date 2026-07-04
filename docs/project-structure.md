# 项目结构说明

## 当前玩法概览

当前主要玩法是家园点击交互、招募队友、队伍排序、种田、炼器、炼丹、自动历练战斗、背包、装备、属性成长、五行、先天命格与突破。玩家点击家园节点后打开对应 HUD 面板；点击打怪入口会通过加载遮罩进入历练地图，随机遇怪并由全队自动战斗。

## 目录结构

```text
.
├── main.tscn
├── scripts/
│   ├── main.gd
│   ├── character/
│   │   ├── me.tscn
│   │   └── character_controller.gd
│   ├── game/
│   │   ├── core/
│   │   │   ├── game_defs.gd
│   │   │   ├── game_state.gd
│   │   │   └── save_manager.gd
│   │   ├── data/
│   │   │   ├── data_tables.gd
│   │   │   ├── equipment_template.gd
│   │   │   └── item_def.gd
│   │   ├── inventory/
│   │   │   └── inventory_service.gd
│   │   ├── party/
│   │   │   └── party_service.gd
│   │   ├── combat/
│   │   │   ├── combat_actor_state_machine.gd
│   │   │   ├── combat_actor_status.gd
│   │   │   ├── combat_ai.gd
│   │   │   ├── combat_controller.gd
│   │   │   ├── combat_controller.tscn
│   │   │   ├── combat_effect_resolver.gd
│   │   │   └── skill_resolver.gd
│   │   ├── skills/
│   │   │   ├── base/
│   │   │   │   └── skill_scene_base.gd
│   │   │   ├── damage/
│   │   │   │   ├── basic_attack.tscn
│   │   │   │   ├── direct_damage_skill.gd
│   │   │   │   └── direct_damage_skill.tscn
│   │   │   ├── heal/
│   │   │   │   ├── heal_skill.gd
│   │   │   │   └── heal_skill.tscn
│   │   │   └── buff/
│   │   │       ├── buff_skill.gd
│   │   │       └── buff_skill.tscn
│   │   ├── enemies/
│   │   │   ├── base_enemy.gd
│   │   │   ├── forest_wolf/
│   │   │   │   ├── enemy.gd
│   │   │   │   └── enemy.tscn
│   │   │   └── training_dummy/
│   │   │       ├── enemy.gd
│   │   │       └── enemy.tscn
│   ├── map/
│   │   ├── battle_map.gd
│   │   ├── battle_map.tscn
│   │   ├── home.tscn
│   │   ├── home_map.gd
│   │   └── outline_highlight.gdshader
│   └── ui/
│       ├── hud.gd
│       └── hud.tscn
├── docs/
├── AGENTS.md
├── PLAN.md
└── project.godot
```

## 主场景

`main.tscn` 挂载 `scripts/main.gd`，负责：

- 初始化透明置顶窗口。
- 统一窗口和场景视口尺寸为 `960×480`。
- 读取和写入 `SaveManager` 存档。
- 连接家园点击信号、HUD 动作信号、历练返回信号、战斗日志信号、状态日志信号。
- 根据家园节点点击打开对应 HUD 面板。
- 根据 HUD 请求直接执行招募或进入历练；种田、炼器、炼丹由 HUD 选择执行者后调用 `GameState` 生产接口结算。
- 处理家园和历练地图之间的加载遮罩过渡。
- 每帧更新 Buff、农田、自动战斗状态并刷新 HUD。

## 核心脚本

### `scripts/game/core/game_defs.gd`

定义全局动作类型：`RECRUIT`、`FARM`、`FORGE`、`ALCHEMY`、`FIGHT`。这些类型用于家园节点、HUD 面板和熟练度统计。

### `scripts/game/core/game_state.gd`

游戏状态门面，集中保存玩家数据并协调各玩法服务：

- 基础属性：等级、经验、生命、法力、攻击、防御、根骨、阶段、等级上限。
- 五行属性：木、火、土、金、水。
- 队伍：通过 `PartyService` 管理玩家、队友、招募候选人、队伍顺序和最多 4 人限制。
- 熟练度：招募、种田、炼器、炼丹、战斗。
- 背包：通过 `InventoryService` 管理堆叠物品、装备实例、使用、丢弃、消耗。
- 装备：穿戴、槽位、穿戴需求、强化、洗练、词条、属性加成。
- 技能：已学习技能与技能书使用。
- 丹方：已学习丹方、最大制作数量和批量炼丹。
- Buff：持续丹药效果、每帧更新与属性叠加。
- 成长与生产：玩家与队友经验升级、自动属性成长、伙伴成长主属性、先天命格、突破道具、根骨突破，以及种田、炼器、炼丹的执行者根骨/命格加成。
- 调试：提供添加物品、生成装备、直接设置基础属性的测试方法。
- 存档：`to_save_data()` / `load_save_data(data)`。

### `scripts/game/data/data_tables.gd`

静态数据表与工厂函数：

- 物品定义：技能书、材料、作物、丹药、图纸、灵石等。
- 丹方定义：结果物品和材料消耗。
- 技能定义：技能 ID、名称、五行、冷却、蓝耗、伤害倍率。
- 装备模板：武器、防具、饰品等装备生成基础。
- 装备阶位、属性池、强化石和洗练词条定义。
- 先天命格定义：命格 ID、名称、品质、槽位、描述和效果列表。
- 敌人静态定义：敌人属性、等级、五行、弱点与掉落配置。
- 工厂方法：创建堆叠物品、技能书、技能、敌人、装备和命格实例。

### `scripts/game/inventory/inventory_service.gd`

背包业务服务：

- 添加堆叠物品或独立实例。
- 按类型/实例 ID 查询背包内容。
- 消耗指定物品或指定类型资源。
- 处理物品使用、丢弃和资源摘要。

### `scripts/game/party/party_service.gd`

队伍与成员业务服务：

- 统一玩家、队友和招募候选人的成员数据结构。
- 维护队伍顺序、队伍人数、招募、移动和离队。
- 处理成员自动成长、先天命格生成、升级、突破和旧存档加点迁移。

### `scripts/game/enemies/<enemy_id>/`

每个敌人按怪物名或稳定英文 ID 独立放在自己的目录：

- `enemy.tscn`：该敌人的独立场景节点。
- `enemy.gd`：该敌人的独立脚本。
- `CombatController` 只通过统一接口实例化敌人，不再依赖具体怪物的内部节点结构。

### `scripts/game/combat/combat_controller.gd`

单场战斗控制器：

- 创建敌人并启动战斗。
- 按队伍 HUD 顺序生成成员站位，所有存活成员独立冷却并自动出招。
- 处理技能冷却与技能伤害。
- 按阶段调用 `CombatEffectResolver` 处理攻击、受击、护盾、DOT/HOT、吸血、Buff/Debuff 和击杀触发。
- 敌人按独立目录组织，木桩和普通怪物各自拥有自己的场景与脚本。
- 更新敌人血条与受击表现。
- 战斗胜利时结算经验、敌人掉落表和独立装备掉落。
- 不提供自动/手动切换、攻击、防御、技能按钮等手动战斗入口。

### `scripts/game/combat/combat_ai.gd`

战斗决策辅助模块：

- 负责玩家或队友自动出招选择，按血量、法力、冷却和距离挑选技能或丹药。
- 负责敌人回合选择，当前默认木桩敌人走固定基础普攻。
- 只产出行动字典，不直接修改 `GameState` 或播放表现。

### `scripts/game/combat/combat_effect_resolver.gd`

战斗附加效果解析器：

- 统一识别技能、装备、命格、敌人动作和临时状态上的 `effects`。
- 按 `attack_start`、`before_hit`、`on_hit`、`after_damage`、`on_kill`、`on_damaged`、`turn_start`、`turn_end` 阶段筛选并判定 `chance`。
- 生成伤害、治疗、状态叠加、护盾抵消和冷却修正事件。
- 不负责动画、伤害浮字、HUD 或掉落结算。

### `scripts/game/core/game_state.gd`

`GameState` 继续承担全局结算与服务门面：

- 属性、五行、成长、熟练度、存档数据。
- 背包与队伍规则分别委托给 `InventoryService` 和 `PartyService`。
- 学习技能、学习丹方、炼丹、炼器、强化和洗练。
- 普通受击、回血、Buff 更新和大部分资源结算。
- 不负责战斗 AI 选招和战斗表现动画。

### `scripts/game/core/save_manager.gd`

统一存档管理器，使用 `user://save.cfg` 保存版本、游戏状态、HUD 面板位置和基础配置。测试可传入临时路径避免污染真实存档。

### `scripts/character/character_controller.gd`

角色控制与表现状态机：

- `IDLE`：家园待机。
- `ROAMING`：家园范围内闲逛，播放 `run`。
- `TALKING`：显示一句短对白，播放 `idle`。
- `EXPEDITION_RUN`：历练地图跑图，播放 `run`。
- `PAUSED`：暂停表现，播放 `idle`。

角色场景 `me.tscn` 根节点为 `CharacterBody2D`，子节点包含 `Sprite`、`CollisionShape2D` 和 `TalkLabel`。

### `scripts/map/home_map.gd`

家园地图脚本：

- 维护可点击建筑节点与动作类型映射。
- 通过透明 `ViewportBounds` 保持家园场景视口边界一致。
- 处理鼠标悬浮描边。
- 通过 `home_node_selected` 信号把点击动作交给主场景。
- 维护农田成熟提示标记。

### `scripts/map/battle_map.gd`

历练地图脚本：

- 默认隐藏，进入历练时显示，退出历练时隐藏。
- 维护 `Sky`、远景层和地面层，使用主场景下发的统一视口尺寸。
- 通过两层横向循环滚动表现跑图。
- 维护随机遇怪计时，发出 `monster_spawn_requested`。
- 战斗结束后重新安排下一次遇怪。

### `scripts/ui/hud.gd`

HUD 控制脚本：

- 控制菜单与各动作弹窗打开/关闭。
- 玩家信息显示属性、先天命格、已穿戴装备和已学习技能。
- 背包 5×5 格子、分类、长物品名换行显示、悬浮详情、右键菜单与双击使用。
- 招募、种田、炼器、历练入口面板的动作请求。
- 种田、炼器和炼丹面板提供执行者选择，按队伍成员根骨、装备、Buff 和命格刷新材料消耗、产量、额外出丹和炼器加成。
- 招募 HUD：显示候选人、命格摘要、材料成本、队伍顺序、上移/下移和队友离队。
- 炼丹面板的已学丹方选择、材料槽、数量选择和批量制作。
- 历练控制 HUD：显示 `返回家园`，仅用于结束当前历练并回到家园。
- 加载遮罩：家园进入历练、历练返回家园时播放淡入/淡出过渡。
- 调试 HUD：常驻 `调试` 按钮，支持添加物品、生成装备、直接设置基础属性。
- 弹窗拖动、位置保存与视口内 clamp。

## 文档目录

- `design.md`：当前玩法设计与核心公式。
- `innate-traits.md`：先天命格的定位、生成规则、推荐命格池、数据结构和觉醒规则。
- `items.md`：物品、背包、装备、炼丹和炼器说明。
- `item-table.md`：物品、配方、灵石、技能、装备、敌人掉落表。
- `battle-expedition.md`：历练地图、随机遇怪、自动战斗、返回家园和加载过渡流程。
- `project-structure.md`：项目结构说明。

## 维护约定

- 新增物品优先补 `DataTables.ITEM_DEFS` 和 `docs/item-table.md`。
- 新增命格优先补 `DataTables.INNATE_TRAIT_DEFS` 和 `docs/innate-traits.md`。
- 新增玩法先接入 `GameState` 结算，再决定是否需要独立决策模块或表现层。
- 涉及数值公式时同步更新 `docs/design.md`。
- 调试入口只用于测试，允许修改正式存档；新增调试能力时同步标注中文日志。

## 历练战斗补充

- `scripts/map/battle_map.tscn`：历练地图场景，默认隐藏；进入打怪历练后显示，提供远景与地面两层循环滚动背景。
- `scripts/map/battle_map.gd`：历练地图控制器，维护随机刷怪计时，发出 `monster_spawn_requested`，并在战斗结束后重新安排下一次遇怪。
- `scripts/game/combat/combat_controller.gd`：单场自动战斗控制器，只处理当前遇怪战斗，不负责怪物刷新频率。
- `scripts/ui/hud.gd`：提供 `ExpeditionHud` 返回入口和 `LoadingOverlay` 加载过渡，不恢复手动战斗控件。
- `docs/battle-expedition.md`：记录家园入口、加载过渡、历练跑图、随机遇怪、自动战斗、返回家园和战后继续跑图的流程。
