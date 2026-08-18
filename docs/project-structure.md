# 项目结构说明

## 当前玩法概览

当前主要玩法是家园点击交互、招募队友、队伍排序、种田、炼器、炼丹、自动历练战斗、背包、装备、属性成长、五行、先天命格与突破。玩家点击家园节点后打开对应 HUD 面板；点击打怪入口会通过加载遮罩进入历练地图，随机遇怪并由全队自动战斗。

## 目录结构

```text
.
├── main.tscn
├── scripts/
│   ├── main.gd
│   ├── actors/
│   │   ├── actor.tscn
│   │   ├── actor_controller.gd
│   │   └── visuals/
│   │       ├── combat_visual.gd
│   │       ├── combat_hitbox.gd
│   │       ├── combat_hurtbox.gd
│   │       ├── party/actor_default.tscn
│   │       └── enemies/
│   │           ├── enemy_default.tscn
│   │           ├── forest_wolf.tscn
│   │           └── training_dummy.tscn
│   ├── game/
│   │   ├── core/
│   │   │   ├── game_defs.gd
│   │   │   ├── game_state.gd
│   │   │   └── save_manager.gd
│   │   ├── data/
│   │   │   ├── data_tables.gd
│   │   │   ├── equipment_template.gd
│   │   │   ├── item_def.gd
│   │   │   └── skill_def.gd
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
│   │   │   ├── skill_resolver.gd
│   │   │   └── skill_value_resolver.gd
│   │   ├── skills/
│   │   │   ├── base/
│   │   │   │   ├── skill_cast_context.gd
│   │   │   │   ├── skill_scene_base.gd
│   │   │   │   └── skill_scene_registry.gd
│   │   │   ├── damage/
│   │   │   │   ├── basic_attack.tscn
│   │   │   │   ├── direct_damage_skill.gd
│   │   │   │   └── direct_damage_skill.tscn
│   │   │   ├── heal/
│   │   │   │   ├── heal_skill.gd
│   │   │   │   └── heal_skill.tscn
│   │   │   ├── buff/
│   │   │   │   ├── buff_skill.gd
│   │   │   │   └── buff_skill.tscn
│   │   │   └── status/
│   │   │       ├── status_visual_base.gd
│   │   │       ├── status_visual_template.tscn
│   │   │       └── visuals/
│   │   ├── enemies/
│   │   │   ├── base_enemy.gd
│   │   │   ├── enemy_template.tscn
│   │   │   ├── forest_wolf/
│   │   │   │   ├── enemy.gd
│   │   │   │   └── enemy.tscn
│   │   │   └── training_dummy/
│   │   │       ├── enemy.gd
│   │   │       └── enemy.tscn
│   ├── map/
│   │   ├── battle_map.gd
│   │   ├── battle_map.tscn
│   │   ├── encounters/
│   │   │   ├── map_encounter_profile.gd
│   │   │   ├── map_encounter_variant.gd
│   │   │   └── map_enemy_class_pool.gd
│   │   ├── home.tscn
│   │   ├── home_map.gd
│   │   └── outline_highlight.gdshader
│   └── ui/
│       ├── hud.gd
│       ├── hud.tscn
│       ├── inventory_detail_view.gd
│       └── rich_text_description_renderer.gd
├── docs/
├── resources/
│   ├── items/
│   ├── equipment/
│   ├── skills/
│   └── maps/
├── assets/
│   ├── actors/
│   └── items/
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
- 根据 HUD 请求直接执行招募或进入历练；种田、炼器、炼丹由 HUD 通过无人物生产接口结算。
- 处理家园和历练地图之间的加载遮罩过渡。
- 每帧更新 Buff、农田、自动战斗状态并刷新 HUD。
- 正常退出或窗口关闭时强制保存尚未写入的状态。

## 核心脚本

### `scripts/game/core/game_defs.gd`

定义全局动作类型：`RECRUIT`、`FARM`、`FORGE`、`ALCHEMY`、`FIGHT`。这些类型用于家园节点、HUD 面板和熟练度统计。

### `scripts/game/core/game_state.gd`

游戏状态门面，集中保存账号、招募成员和玩法数据并协调各服务：

- 基础属性：等级、经验、生命、法力、攻击、防御、根骨、阶段、等级上限。
- 五行属性：木、火、土、金、水。
- 账号历练：保存独立等级与经验，决定敌人、新候选和掉落等级。
- 角色库与队伍：通过 `PartyService` 管理最多 8 名招募成员、候选人、4 人出战顺序、候补顺序、上阵/下阵与放生，不存在固定主角。
- 熟练度：招募、种田、炼器、炼丹、战斗。
- 背包：通过 `InventoryService` 管理堆叠物品、装备实例、使用、丢弃、消耗。
- 坊市：通过 `MarketService` 管理独立 RNG、现实时间轮换、购买、回收和委托原子事务。
- 装备：穿戴、槽位、穿戴需求、强化、洗练、词条、属性加成。
- 技能：已学习技能与技能书使用。
- 丹方：已学习丹方、最大制作数量和批量炼丹。
- Buff：持续丹药效果、每帧更新与属性叠加。
- 成长与生产：各角色经验升级、自动属性成长、成长主属性、先天命格、突破道具、根骨突破，以及无人物的种田、即时炼器和即时炼丹。
- 建筑品质：账号永久保存各生产建筑的 `output_quality`，并处理通用永久品质物品 payload。
- 调试：提供添加物品、生成装备、直接设置基础属性的测试方法。
- 存档：`to_save_data()` / `load_save_data(data)`。
- 战败恢复：全灭返回家园前按总上限恢复队伍生命和法力。
- 委托边界：背包规则交给 `InventoryService`，队伍和成长交给 `PartyService`。
- 禁止职责：不处理战斗 AI、战斗动画、伤害浮字或窗口表现。

### `scripts/game/data/data_tables.gd`

静态数据表与工厂函数：

- 物品定义：技能书、材料、作物、丹药、图纸、灵石等。
- 丹方定义：结果物品和材料消耗。
- 技能定义：技能 ID、名称、五行、冷却、蓝耗、伤害倍率。
- 装备模板：武器、防具、饰品等装备生成基础。
- 图标资源路径：物品、装备和技能 `.tres` 的约定路径与 `icon_texture` 读取入口。
- 装备阶位、属性池、强化石和洗练词条定义。
- 先天命格定义：命格 ID、名称、描述和效果列表。
- 敌人静态定义：敌人属性、等级、五行、弱点与掉落配置。
- 坊市定义：商品分类权重、价格、回收比例、委托候选、刷新周期和手动刷新费用。
- 工厂方法：创建堆叠物品、技能、敌人和装备实例。

### `scripts/game/data/item_def.gd`

物品 `.tres` 资源脚本，导出物品 ID、编号、名称、描述、分类、图标贴图、图标路径、使用范围、成长目标和 payload。当前作为美术引用和 Inspector 可视化编辑承载，不替代 `DataTables.ITEM_DEFS`。

### `scripts/game/data/equipment_template.gd`

装备模板 `.tres` 资源脚本，导出模板 ID、槽位、模板名称、槽位显示名、图标贴图、默认图标路径、基础属性、等级成长、需求属性和描述。资源内不写入阶位文本；阶位由运行时装备实例动态生成。

### `scripts/game/data/skill_def.gd`

技能 `.tres` 资源脚本，导出技能 ID、显示名、图标、分类、目标、五行、蓝耗、冷却、AI 条件和有序效果列表。施法场景在根节点选择该资源；状态效果在 Inspector 直接选择独立状态表现场景。完整制作接口见 `docs/skill-authoring.md`。

## Mod 子系统

- `scripts/modding/mod_api.gd`：`ModAPI` Autoload；在 `GameState` 前挂载 PCK/ZIP、解析依赖、执行事务注册并冻结内容。
- `scripts/modding/api/`：API 1 稳定类，包括 `ModPlugin`、`ModContext`、只读内容注册表、事件、隔离存储/RNG 和 `ActorState`。
- `scripts/modding/internal/`：Manifest/内容运行时校验和条件对白选择器，不属于兼容 API。
- `scripts/modding/ui/mod_manager_panel.gd`：Mod 启停、代码授权、排序、错误和重启提示。
- `docs/modding/schemas/v1/`：Manifest、统一内容信封和 11 类内容的 JSON Schema Draft 2020-12。
- `mod_sdk/example_mod/`：可构建示例，覆盖技能、物品、形象、对白、自定义状态/effect/AI、存储和迁移。

`DataTables` 保留为本体兼容门面，业务查询转发到冻结的 Mod 内容注册表；本体静态定义在 Mod 注册阶段以 `core` 来源导入。Mod 不应直接读取 `DataTables` 或其他业务脚本。

## 资源目录

- `resources/items/`：物品资源，文件名为 `<item_id>.tres`。
- `resources/equipment/`：装备模板资源，文件名为 `<template_id>.tres`，例如 `weapon.tres`。
- `resources/skills/`：技能资源，文件名为 `<skill_id>.tres`。
- `resources/maps/`：地图独立遭遇 Profile；默认历练配置为 `default_expedition_encounters.tres`。

这些资源的 `icon_texture` 供手动拖图使用。运行时图标读取顺序为 `.tres.icon_texture`、默认 `icon_path` 图片、UI 占位。

### `scripts/game/inventory/inventory_service.gd`

背包业务服务：

- 添加堆叠物品或独立实例。
- 按类型/实例 ID 查询背包内容。
- 消耗指定物品或指定类型资源。
- 处理物品使用、丢弃和资源摘要。

### `scripts/game/core/market_service.gd`

坊市业务服务：

- 使用独立持久化 RNG 生成 6 个不重复商品和 3 项跨委托不重复需求。
- 处理 600 秒现实时间免费刷新、系统时钟回退修正与 2/4/8/16 手动刷新。
- 原子结算购买、批次回收、贵重确认和一次性委托。
- 根据历练、炼丹、已学技能、图纸和强化丹额度过滤候选，并校验直接回收及委托套利。

### `scripts/game/party/party_service.gd`

队伍与成员业务服务：

- 统一招募成员和候选人的成员数据结构，并补齐稳定的 `visual_id`。
- 维护队伍顺序、队伍人数、招募、移动和离队。
- 处理成员自动成长、先天命格生成、升级、突破和旧存档加点迁移。

### `scripts/game/enemies/`

`enemy_template.tscn` 只承载敌人数据、状态、血量、AI 和形象装配入口，不包含具体 Sprite、Marker 或碰撞块。森林狼和木桩继承该模板，只保留模板 ID、数值与特殊 AI。

每个敌人按稳定英文 ID 保留自己的数据场景：

- `enemy.tscn`：该敌人的独立场景节点。
- `enemy.gd`：该敌人的独立脚本。
- `BaseEnemy` 根据 `visual_id` 从 `scripts/actors/visuals/enemies/` 装配形象，并转发动画和碰撞信号。

### `scripts/game/combat/combat_controller.gd`

单场战斗控制器：

- 接受地图生成的异种敌人 ID 序列，按顺序创建各自场景并启动战斗；旧单 ID 调用继续兼容。
- 按 `party_order` 生成成员站位，并以严格回合指针逐个执行玩家成员，之后才执行敌人回合。
- 单名成员使用 `READY -> APPROACH -> ATTACK -> RETURN -> RECOVERY` 状态，预约目标 Marker 后接敌；攻击动画和归位完全结束后才轮到下一名。
- 普通攻击只接受形象 Hitbox 与敌方 Hurtbox 的碰撞信号，每个行动对每个目标只结算一次。
- 处理技能冷却与技能伤害。
- 按阶段调用 `CombatEffectResolver` 处理攻击、受击、护盾、DOT/HOT、吸血、Buff/Debuff 和击杀触发。
- 敌人按独立目录组织，木桩和普通怪物各自拥有自己的场景与脚本。
- 更新敌人血条与受击表现。
- 战斗胜利时结算经验、敌人掉落表和独立装备掉落。
- 对外提供 `none`、`victory`、`defeat` 战斗结果；全灭本身不结算奖励。
- 技能和丹药冷却按角色自身回合递减，修正后的回合数向上取整。
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
- 生成伤害、治疗、状态覆盖/叠加、一次性消耗、护盾抵消和冷却修正事件。
- 不负责动画、伤害浮字、HUD 或掉落结算。

### `scripts/game/core/save_manager.gd`

统一存档管理器，使用 `user://save.cfg` 保存版本、游戏状态、HUD 面板位置和基础配置。缺少有效游戏段或解析失败时回退默认新档；测试可传入临时路径避免污染真实存档。

### `scripts/actors/actor_controller.gd`

场景角色表现控制与状态机：

- `IDLE`：家园待机。
- `ROAMING`：家园范围内闲逛，播放 `walk`。
- `TALKING`：显示一句短对白，播放 `idle`。
- `EXPEDITION_RUNNING`：历练地图跑图，播放 `run`。
- `COMBAT_READY`：战斗待机，播放 `idle`。
- `COMBAT_MOVING`：按战斗逻辑位置移动，播放 `run`。
- `COMBAT_ACTING`：执行战斗动作，近战播放非循环 `melee_attack`，远程普通攻击播放 `ranged_attack`。
- `PAUSED`：暂停表现，播放 `idle`。

家园和战斗共用 `actor.tscn`，根节点为 `CharacterBody2D`，只保留 `VisualRoot` 与 `TalkLabel`。`ActorController` 根据成员 `visual_id` 从 `scripts/actors/visuals/party/<visual_id>.tscn` 装配完整形象；缺失或契约不完整时降级到 `actor_default`。

每个 `CombatVisual` 自行维护 Sprite/AnimatedSprite、AnimationPlayer、Hurtbox、AttackHitbox、近战 `Marker2D`、`HitSocket` 和 `EffectSocket`。后续新增形象只需创建满足统一接口的新场景，不修改角色数值、AI 或控制器。

人物形象统一预留 `idle`、`walk`、`run`、`melee_attack`、`ranged_attack`、`death` 和 `level_up` 动画。旧形象的 `attack` 仍作为近战兼容名；缺少 `walk` 时回退到 `run`。远程动作不会开启近战 Hitbox，动画结束时由控制器结算远程普通攻击；当前火球术作为 `attack_mode=ranged` 的零蓝耗普通攻击。

### `scripts/map/home_map.gd`

家园地图脚本：

- 维护可点击建筑节点与动作类型映射。
- 通过透明 `ViewportBounds` 保持家园场景视口边界一致。
- 根据地面 TileMap 的实际使用范围提供横向镜头边界，家园扩建后无需同步硬编码宽度。
- 处理鼠标悬浮描边。
- 通过 `home_node_selected` 信号把点击动作交给主场景。
- 维护农田成熟提示标记。

### `scripts/map/battle_map.gd`

历练地图脚本：

- 默认隐藏，进入历练时显示，退出历练时隐藏。
- 作为透明历练层使用，不绘制独立背景。
- 维护首场 1 秒、后续 3–5 秒的遇怪计时，发出 `monster_spawn_requested`。
- 持有地图自己的 `encounter_profile`，通过 `roll_encounter()` 生成最终敌人 ID 序列；计时信号不决定敌人内容。
- 战斗结束后重新安排下一次遇怪。

### `scripts/ui/hud.gd`

HUD 控制脚本：

- 控制菜单与各动作弹窗打开/关闭。
- 玩家信息显示属性、先天命格、已穿戴装备和已学习技能。
- 背包 5×5 格子、分类、长物品名换行显示、悬浮详情、右键菜单与双击使用。
- 招募、种田、炼器、历练入口面板的动作请求。
- 种田面板显示种子、农田格、生长进度和加速道具；炼器与炼丹面板直接展示固定材料、即时产出和建筑加成，不选择人物。
- 招募 HUD：显示候选人命格摘要、材料成本、角色库与出战人数、上移/下移、上阵/下阵和带确认的永久放生。
- 炼丹面板的已学丹方选择、材料槽、数量选择和批量制作。
- 坊市面板的货架、委托、回收页签，以及坊市令、倒计时、手动刷新费用和贵重回收确认。
- 历练控制 HUD：显示 `返回家园`，仅用于结束当前历练并回到家园。
- 家园镜头控制：屏幕左右按钮支持点按步进和长按连续横移，到达边界后禁用对应方向。
- 战斗伤害和治疗通过 `DamagePopupManager` 显示浮字。
- 加载遮罩：家园进入历练、历练返回家园时播放淡入/淡出过渡。
- 调试 HUD：常驻 `调试` 按钮，支持添加物品、生成装备、直接设置基础属性。
- 弹窗拖动、位置保存与视口内 clamp。

### `scripts/ui/rich_text_description_renderer.gd`

物品语义富文本渲染器：

- 将装备基础、强化、随机词条和洗练字段渲染为紧凑彩色文本。
- 根据 `description_effects` 和当前角色属性生成公式、倍率与结果。
- 统一正文、数值、结果、警告、错误、五行和装备阶位颜色。
- 只负责展示，不修改物品、角色属性或战斗状态。

## 文档目录

- `design.md`：玩法总览、核心循环、成长公式、生产/战斗高层规则和跨系统跳转。
- `items.md`：物品系统规则，包括背包实例、使用/丢弃、装备养成、种田、炼丹和规划商店。
- `item-table.md`：`DataTables` 的事实索引，包括已实现物品、配方、技能、装备模板、命格索引、敌人与掉落；未来物品和套装只放在“规划”段落。
- `equipment-progression-v2.md`：规划中的装备十阶成长、五行武器、防具饰品、图纸打造、升级升阶和旧档迁移规格。
- `skills.md`：已实现通用技能索引，以及规划中的五行技能特色、二十个五行技能、获取成本和 AI 使用条件。
- `skill-authoring.md`：技能资源、释放动画方法轨道、手工碰撞窗口和持续状态动画的唯一制作手册。
- `innate-traits.md`：先天命格的已实现命格池、效果字段、规划生成规则、数值基准、缺陷命格和觉醒规则。
- `battle-expedition.md`：历练地图、随机遇怪、自动战斗、战斗附加效果、返回家园和加载过渡流程。
- `project-structure.md`：项目结构说明。
- `modding/`：版本化 Mod 包格式、内容参考、脚本 API、专项契约、安全说明、迁移指南、Schema 和 API 变更记录。

## 维护约定

- 所有供 `.tres` / `.res` 使用的 `Resource` 脚本，其每个 `@export` 字段必须紧邻一条中文 `##` 文档注释，说明用途、单位、允许值或生效时机；资源顶部使用中文 `@export_category`，相关字段使用中文 `@export_group` 分组。Inspector 会直接显示分类和分组，字段 `##` 说明需悬停查看，不能把悬停说明误写成只在源码中可读的普通 `#` 注释。新增或修改导出字段时必须同步维护分类、分组和字段说明。
- 新增已实现物品、配方、技能、装备模板、敌人或掉落时，优先补 `DataTables`，再同步 `docs/item-table.md`。
- 新增或调整物品、装备、技能图标字段时，同步 `resources/` 对应 `.tres` 和 `docs/item-table.md`。
- 新增物品交互规则、背包行为、装备养成、炼丹、种田或商店规则时，同步 `docs/items.md`。
- 新增或调整五行技能规划时同步 `docs/skills.md`；只有完成数据、场景和 AI 支撑后才能移入 `docs/item-table.md` 的已实现技能表。
- 新增命格优先补 `DataTables.INNATE_TRAIT_DEFS` 和 `docs/innate-traits.md`；若命格影响战斗 AI 或战斗效果，同步 `docs/battle-expedition.md`。
- 新增玩法先接入 `GameState` 结算，再决定是否需要独立决策模块或表现层；只保留高层跨系统说明在 `docs/design.md`。
- 涉及战斗流程、随机遇怪、`effects` 管线或返回家园流程时，同步 `docs/battle-expedition.md`。
- 未实现设定必须标注为“规划”，不能写入已实现清单。
- 调试入口只用于测试，允许修改正式存档；新增调试能力时同步标注中文日志。
- 修改 API 1 的公开类、方法或参数时先更新 API 快照测试和 `docs/modding/api-changelog.md`；破坏性变更必须增加 `MOD_API_VERSION`。

## 历练战斗补充

- `scripts/map/battle_map.tscn`：历练地图场景，默认隐藏；进入打怪历练后显示，作为透明历练层承载刷怪和战斗坐标。
- `scripts/map/battle_map.gd`：历练地图控制器，维护随机刷怪计时并调用地图独立遭遇 Profile；发出 `monster_spawn_requested`，战斗结束后重新安排下一次遇怪。
- `scripts/map/encounters/`：地图遭遇资源类型，分别定义 Profile、加权 Variant 和加权类别池。
- `resources/maps/default_expedition_encounters.tres`：当前默认历练地图配置，只随机生成林狼。
- `scripts/game/combat/combat_controller.gd`：单场自动战斗控制器，只处理当前遇怪战斗，不负责怪物刷新频率。
- `scripts/ui/hud.gd`：提供 `ExpeditionHud` 返回入口和 `LoadingOverlay` 加载过渡，不恢复手动战斗控件。
- `docs/battle-expedition.md`：记录家园入口、加载过渡、历练跑图、随机遇怪、自动战斗、返回家园和战后继续跑图的流程。


## Schema 16 坊市闭环文件

- `scripts/game/core/market_service.gd`：轮换、购买、回收、委托、持久化 RNG 与经济校验。
- `scripts/game/core/game_state.gd`：保存 `market_state` 并提供坊市门面接口。
- `scripts/game/data/data_tables.gd`：1061 坊市令、商品池、回收比例、委托候选和刷新常量。
- `scripts/ui/hud.gd`：家园坊市入口与货架、委托、回收三页签。
- `scripts/tests/market_economy_test.*`：刷新、原子事务、迁移、打造分解和永久丹产出策略回归。

## Schema 14 核心闭环文件

- `scripts/game/core/game_state.gd`：建筑上限、招募初始化、突破、图纸、定向打造、分解、功法兑换、丹药配方、`reward_progress` 与 Schema 14 迁移。
- `scripts/game/data/data_tables.gd`：1034-1050 物品、六类兑换功法、丹药配方、五行敌人和掉落元数据。
- `scripts/ui/hud.gd`：建筑上限提示、功法兑换页、定向打造、灵石转换和分解确认；永久建筑品质不再出现在普通炼器 HUD。
- `resources/maps/*_encounters.tres`：五张地图的普通池、14% 精英替换与沉渊泽 1% Boss 位置概率。
- `scripts/tests/core_loop_regression_test.*`：掉落、成长、装备、技能/丹药和地图阶段回归。
- `scripts/tests/economy_simulation_test.*`：首小时固定种子资源、历练 1-46 建筑上限、回收价值和突破可达性模拟。
- `docs/modding/schemas/v1/`：技能 `single/aoe`、敌人类别/倍率/掉落字段和配方建筑等级字段。
