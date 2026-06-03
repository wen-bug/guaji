# 项目结构说明

本文档整理当前 Godot 项目的目录布局、运行入口、核心模块职责与主要调用链，便于后续开发和维护。

## 项目概览

- 项目类型：Godot 4.6 2D 横版挂机桌宠 / 修仙原型。
- 项目名称：`guaji`，定义于 `project.godot`。
- 主场景：`res://main.tscn`。
- 主控制脚本：`res://scripts/main.gd`。
- 当前主要玩法：家园点击交互、打坐、种田、炼器、炼丹、战斗、背包、装备、属性成长、五行与突破。

## 顶层目录

```text
.
├── assets/                  # Tiny Swords 素材与 Godot 导入资源
├── docs/                    # 项目设计、物品系统与结构文档
├── scripts/                 # 游戏场景脚本与核心玩法逻辑
├── tests/                   # Godot 脚本测试
├── icon.svg                 # 项目图标
├── main.tscn                # 主场景
└── project.godot            # Godot 项目配置
```

## 运行入口

### `project.godot`

- 配置项目名称为 `guaji`。
- 配置主场景为 `res://main.tscn`。
- 使用 Godot 4.6 / Forward Plus 配置。

### `main.tscn`

主场景由以下节点组成：

- `Main`：根节点，挂载 `scripts/main.gd`。
- `Home`：家园地图实例，来自 `scripts/map/home.tscn`。
- `CharacterController`：角色实例，来自 `scripts/character/me.tscn`。
- `CombatController`：战斗控制器实例，来自 `scripts/game/combat_controller.tscn`。
- `Hud`：界面实例，来自 `scripts/ui/hud.tscn`。

### `scripts/main.gd`

`main.gd` 是当前运行时调度中心，主要职责如下：

- 初始化透明、无边框、置顶的桌宠窗口。
- 获取并缓存 `Home`、`CharacterController`、`CombatController`、`Hud` 节点。
- 连接家园点击信号、HUD 动作信号、战斗日志信号、状态日志信号。
- 根据家园节点点击打开对应 HUD 面板。
- 根据 HUD 请求执行打坐、种田、炼器、炼丹或战斗。
- 每帧更新 Buff、推进战斗状态并刷新 HUD。

当前主流程没有把家园动作加入任务队列，而是由 HUD 面板确认后直接执行。

## 脚本目录结构

```text
scripts/
├── main.gd
├── character/
│   ├── character_controller.gd
│   ├── character_controller.tscn
│   └── me.tscn
├── game/
│   ├── combat_controller.gd
│   ├── combat_controller.tscn
│   ├── data_tables.gd
│   ├── equipment_template.gd
│   ├── game_defs.gd
│   ├── game_state.gd
│   ├── item_def.gd
│   ├── task_manager.gd
│   └── zone_manager.gd
├── map/
│   ├── home.tscn
│   ├── home_map.gd
│   ├── outline_highlight.gdshader
│   └── outline_highlight.gdshader.uid
└── ui/
    ├── hud.gd
    └── hud.tscn
```

## 核心模块职责

### `scripts/game/game_defs.gd`

定义全局枚举：

- `TaskType`：`MEDITATE`、`FARM`、`FORGE`、`ALCHEMY`、`FIGHT`。
- `TaskStatus`：`WAITING`、`MOVING`、`RUNNING`、`DONE`。

`TaskStatus` 主要服务于历史任务队列模型，当前主流程中使用较少。

### `scripts/game/game_state.gd`

游戏状态核心，集中维护玩家数据与多数玩法结算：

- 基础属性：等级、经验、生命、法力、攻击、防御、根骨、阶段、等级上限。
- 五行属性：木、火、土、金、水。
- 熟练度：打坐、种田、炼器、炼丹、战斗。
- 背包：堆叠物品、装备实例、使用、丢弃、消耗。
- 装备：穿戴、槽位、强化、词条、属性加成。
- 技能：已学习技能与技能书使用。
- 丹方：已学习丹方与炼丹产物查询。
- Buff：持续丹药效果、每帧更新与属性叠加。
- 成长：经验升级、随机属性成长、突破道具、根骨突破。

该文件是目前体量最大的业务脚本，新增复杂玩法时应优先考虑是否需要拆分职责。

### `scripts/game/data_tables.gd`

静态数据表与工厂方法集合：

- 物品定义：技能书、材料、作物、丹药、图纸、灵石等。
- 技能定义：技能 ID、名称、伤害倍率等。
- 装备模板：武器、防具、饰品等装备生成基础。
- 词条池：装备随机词条来源。
- 敌人模板：敌人属性、等级与掉落配置。
- 工厂方法：创建堆叠物品、技能书、技能、敌人、装备。

### `scripts/game/combat_controller.gd`

战斗控制器，负责单场战斗状态：

- 创建敌人并启动战斗。
- 按时间推进玩家攻击与敌人攻击。
- 处理技能冷却与技能伤害。
- 判断胜利或失败。
- 结算经验、材料、装备掉落。
- 更新敌人血条等视觉表现。

### `scripts/game/task_manager.gd`

历史任务队列控制器，保留了队列相关接口：

- `add_task()`
- `clear_queue()`
- `toggle_pause()`
- `queue_summary()`
- `current_task_name()`

当前主流程没有实例化或驱动该管理器；测试中也验证家园动作不会进入队列。后续若恢复自动任务队列，需要重新接入 `main.gd`、`CharacterController` 和 HUD。

### `scripts/game/zone_manager.gd`

区域数据管理器，维护任务目标区域与区块信息。当前同样偏历史任务队列模型，主流程没有直接使用。

### `scripts/game/item_def.gd`

物品资源定义包装，用于从数据字典生成标准物品数据。

### `scripts/game/equipment_template.gd`

装备模板资源定义包装，用于保存装备模板基础字段。

## 地图与交互

### `scripts/map/home.tscn`

家园场景，根节点挂载 `HomeMap`，主要交互节点包括：

- `meditate`：打坐。
- `farmland`：种田。
- `forge`：炼器。
- `alchemy`：炼丹。
- `fight`：战斗入口。
- `farmland/crop`：作物显示模板，运行时复制到农田槽位。

### `scripts/map/home_map.gd`

家园地图控制脚本：

- 将家园节点名映射到 `GameDefs.TaskType`。
- 为交互节点绑定 `Area2D` 输入事件。
- 鼠标悬停时启用描边高亮。
- 管理农田槽位与作物显示。
- 发出 `home_node_selected(node_name)` 信号交给 `main.gd` 分发。

### `scripts/map/outline_highlight.gdshader`

家园交互节点描边高亮 shader，由 `HomeMap` 动态绑定到可高亮节点。

## 角色系统

### `scripts/character/me.tscn`

实际角色场景，根节点为 `CharacterBody2D`，挂载 `character_controller.gd`，包含：

- `AnimatedSprite2D`：角色动画。
- `CollisionShape2D`：碰撞形状。
- `TalkLabel`：闲置对白。
- `ProgressBack` / `ProgressFill`：任务进度条。

### `scripts/character/character_controller.gd`

角色控制与表现状态机：

- `IDLE`：空闲。
- `ROAMING`：家园闲逛。
- `TALKING`：显示闲置对白。
- `MOVING_TO_TASK`：移动到任务位置。
- `WORKING`：执行任务。
- `PAUSED`：暂停。
- `RETURNING_HOME`：返回家园。

当前主流程主要使用 `setup()` 和 `set_idle_roam()`，角色任务移动相关接口保留但接入较少。

## HUD 与界面

### `scripts/ui/hud.tscn`

HUD 场景包含：

- 菜单按钮与菜单面板。
- 角色信息面板。
- 背包面板。
- 种田、炼器、炼丹、打坐、战斗动作面板。
- 背包右键菜单。

### `scripts/ui/hud.gd`

HUD 控制脚本：

- 刷新角色状态、五行、日志和背包。
- 根据家园动作类型打开对应动作面板。
- 发出 `home_action_requested(task_type)` 信号。
- 背包分类切换。
- 背包物品格式化显示。
- 右键菜单处理使用、丢弃、强化、加词条。

## 资源目录

### `assets/`

资源主要来自 Tiny Swords 系列素材包，包括：

- 地图建筑与装饰。
- 角色与敌人动画图。
- UI 元素。
- Godot `.import` 文件。

Godot 还会在 `.godot/imported/` 中生成导入缓存，该目录文件数量较多，通常不需要人工维护。

## 文档目录

```text
docs/
├── design.md              # 原型总体设计文档
├── items.md               # 物品、背包、装备、炼丹、炼器说明
└── project-structure.md   # 当前项目结构说明
```

### `docs/design.md`

描述项目定位、地图结构、角色状态机、任务队列、家园交互、背包、输入熟练度、属性成长等设计。

需要注意：该文档中仍保留任务队列式流程描述，而当前主流程已经改为家园面板直接执行动作。

### `docs/items.md`

描述物品系统细节，包括：

- 物品分类。
- 右键菜单行为。
- 装备强化与词条。
- 丹药与持续 Buff。
- 丹方与炼丹。
- DataTables 约定。
- 后续扩展方向。

## 测试目录

### `tests/gameplay_system_test.gd`

Godot 脚本测试入口，覆盖：

- 初始成长属性。
- 等级上限与突破道具。
- 根骨突破。
- 根骨活动加成。
- 炼丹丹方与持续 Buff。
- 种田种子与农田等级产量。
- 家园动作不进入任务队列。
- 家园节点映射与农田槽位。
- HUD 场景节点绑定。
- 角色重力与角色场景引用链。
- 装备槽位、强化、词条、灵石与洗练。
- 敌人模板。
- 元素与物理减伤。

运行测试可使用 Godot headless 脚本模式，例如：

```powershell
& 'D:\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/gameplay_system_test.gd
```

## 当前架构关系

```text
project.godot
    └── main.tscn
        ├── scripts/main.gd
        │   ├── GameState
        │   ├── HomeMap
        │   ├── CharacterController
        │   ├── CombatController
        │   └── Hud
        ├── scripts/map/home.tscn
        ├── scripts/character/me.tscn
        ├── scripts/game/combat_controller.tscn
        └── scripts/ui/hud.tscn
```

主要信号流：

```text
HomeMap.home_node_selected
    -> Main._on_home_node_selected
    -> Hud.show_home_action_panel
    -> Hud.home_action_requested
    -> Main._on_home_action_requested
    -> GameState / CombatController
    -> Hud.refresh
```

主要数据依赖：

```text
GameState
    ├── GameDefs
    └── DataTables
            ├── ItemDef
            └── EquipmentTemplate

CombatController
    ├── GameState
    └── DataTables

Hud
    ├── GameState
    └── GameDefs

HomeMap
    └── GameDefs
```

## 维护建议

- `game_state.gd` 已承担大量职责，后续可按背包、装备、成长、Buff 等方向逐步拆分。
- `task_manager.gd` 与 `zone_manager.gd` 当前偏历史遗留；若不再恢复任务队列，可考虑移除或在文档中明确为弃用模块。
- `docs/design.md` 中任务队列描述与当前实现不完全一致，建议后续同步更新设计文档。
- 新增玩法时优先补充 `DataTables` 静态定义，再接入 `GameState` 结算与 HUD 展示。
- 修改场景节点名称时要同步检查 `hud.gd`、`home_map.gd` 中的 `$NodePath` 与节点名映射。
