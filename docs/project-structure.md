# 项目结构说明

## 当前玩法概览

当前主要玩法是家园点击交互、打坐、种田、炼器、炼丹、战斗、背包、装备、属性成长、五行与突破。玩家点击家园节点后打开对应 HUD 面板，再由面板按钮或选择控件直接触发结算。

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
│   │   ├── combat_controller.gd
│   │   ├── combat_controller.tscn
│   │   ├── data_tables.gd
│   │   ├── equipment_template.gd
│   │   ├── game_defs.gd
│   │   ├── game_state.gd
│   │   ├── item_def.gd
│   │   └── save_manager.gd
│   ├── map/
│   │   ├── home.tscn
│   │   └── home_map.gd
│   └── ui/
│       ├── hud.gd
│       └── hud.tscn
├── docs/
└── tests/
```

## 主场景

`main.tscn` 挂载 `scripts/main.gd`，负责：

- 初始化透明置顶窗口。
- 读取和写入 `SaveManager` 存档。
- 连接家园点击信号、HUD 动作信号、战斗日志信号、状态日志信号。
- 根据家园节点点击打开对应 HUD 面板。
- 根据 HUD 请求直接执打坐、种田、炼器、炼丹或战斗。
- 每帧更新 Buff、推进战斗状态并刷新 HUD。

## 核心脚本

### `scripts/game/game_defs.gd`

定义全局动作类型：`MEDITATE`、`FARM`、`FORGE`、`ALCHEMY`、`FIGHT`。这些类型用于家园节点、HUD 面板和熟练度统计。

### `scripts/game/game_state.gd`

游戏状态核心，集中维护玩家数据与多数玩法结算：

- 基础属性：等级、经验、生命、法力、攻击、防御、根骨、阶段、等级上限。
- 五行属性：木、火、土、金、水。
- 熟练度：打坐、种田、炼器、炼丹、战斗。
- 背包：堆叠物品、装备实例、使用、丢弃、消耗。
- 装备：穿戴、槽位、穿戴需求、强化、洗练、词条、属性加成。
- 技能：已学习技能与技能书使用。
- 丹方：已学习丹方、最大制作数量和批量炼丹。
- Buff：持续丹药效果、每帧更新与属性叠加。
- 成长：经验升级、修为升级、随机属性成长、突破道具、根骨突破。
- 存档：`to_save_data()` / `load_save_data(data)`。

### `scripts/game/data_tables.gd`

静态数据表与工厂函数：

- 物品定义：技能书、材料、作物、丹药、图纸、灵石等。
- 丹方定义：结果物品和材料消耗。
- 技能定义：技能 ID、名称、五行、冷却、蓝耗、伤害倍率。
- 装备模板：武器、防具、饰品等装备生成基础。
- 装备阶位、属性池、强化石和洗练词条定义。
- 敌人模板：敌人属性、等级、五行、弱点与掉落配置。
- 工厂方法：创建堆叠物品、技能书、技能、敌人、装备。

### `scripts/game/combat_controller.gd`

单场战斗控制器：

- 创建敌人并启动战斗。
- 按攻击间隔结算玩家与敌人伤害。
- 处理技能冷却与技能伤害。
- 更新敌人血条等视觉表现。
- 战斗胜利时结算经验、敌人掉落表和独立装备掉落。

### `scripts/game/save_manager.gd`

统一存档管理器，使用 `user://save.cfg` 保存版本、游戏状态、HUD 面板位置和基础配置。测试可传入临时路径避免污染真实存档。

### `scripts/character/character_controller.gd`

角色控制与表现状态机：

- `IDLE`：家园待机。
- `ROAMING`：家园范围内闲逛，播放 `run`。
- `TALKING`：显示一句短对白，播放 `idle`。
- `PAUSED`：暂停表现，播放 `idle`。

角色场景 `me.tscn` 根节点为 `CharacterBody2D`，子节点包含 `Sprite`、`CollisionShape2D` 和 `TalkLabel`。

### `scripts/map/home_map.gd`

家园地图脚本：

- 维护可点击建筑节点与动作类型映射。
- 处理鼠标悬浮描边。
- 通过 `home_node_selected` 信号把点击动作交给主场景。
- 按作物数量刷新农田显示槽位。

### `scripts/ui/hud.gd`

HUD 控制脚本：

- 控制菜单与各动作弹窗打开/关闭。
- 玩家信息显示属性、已穿戴装备和已学习技能。
- 背包 5×5 格子、分类、悬浮详情、右键菜单与双击使用。
- 种田、炼器、打坐、战斗面板的动作请求。
- 炼丹面板的已学丹方选择、材料槽、数量选择和批量制作。
- 弹窗拖动、位置保存与视口内 clamp。

## 文档目录

- `design.md`：当前玩法设计与核心公式。
- `items.md`：物品、背包、装备、炼丹和炼器说明。
- `item-table.md`：物品、配方、灵石、技能、装备、敌人掉落表。
- `project-structure.md`：项目结构说明。

## 维护约定

- 新增物品优先补 `DataTables.ITEM_DEFS` 和 `docs/item-table.md`。
- 新增玩法先接入 `GameState` 结算，再接入 HUD 展示。
- 涉及数值公式时同步更新 `docs/design.md`。

## 历练战斗补充

- `scripts/map/battle_map.tscn`：历练地图场景，默认隐藏；进入打怪历练后显示，提供远景与地面两层循环滚动背景。
- `scripts/map/battle_map.gd`：历练地图控制器，维护随机刷怪计时，发出 `monster_spawn_requested`，并在战斗结束后重新安排下一次遇怪。
- `scripts/game/combat_controller.gd`：单场自动战斗控制器，只处理当前遇怪战斗，不负责怪物刷新频率。
- `docs/battle-expedition.md`：记录家园入口、历练跑图、随机遇怪、自动战斗和战后继续跑图的流程。
