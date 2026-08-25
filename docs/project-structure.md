# 项目结构

本文说明当前 `0.2.0` 工程的稳定子系统边界和主要入口。具体文件列表以仓库为准，不在文档中复制完整目录树。

## 当前玩法

玩家在家园招募并编组角色，通过种田、炼器、炼丹和坊市管理资源；进入五行历练地图后，队伍自动遭遇普通、精英和 Boss 敌人并循环战斗。角色、装备、技能、命格、建筑、账号历练和坊市状态均进入存档。

玩法规则见[设计基线](design.md)，已实现内容 ID 和数值见[内容数据表](item-table.md)。

## 启动与场景

[主场景](../main.tscn)挂载 `scripts/main.gd`，负责组合家园、历练地图、战斗控制器和 HUD。`project.godot` 注册 `ModAPI` Autoload，并在主场景创建 `GameState` 前加载启用的 Mod 内容。

| 子系统 | 主要入口 | 职责 |
| --- | --- | --- |
| 主流程 | `scripts/main.gd` | 场景切换、系统装配、存档时机和跨系统信号 |
| 家园地图 | `scripts/map/home_map.gd` | 建筑点击和家园角色表现 |
| 历练地图 | `scripts/map/battle_map.gd` | 地图选择、刷怪计时和遭遇 Profile |
| HUD | `scripts/ui/hud.gd` | 家园、队伍、背包、生产、坊市和历练面板 |

## 游戏状态与数据

`scripts/game/core/game_state.gd` 是账号和角色持久状态的聚合入口。它维护存档 Schema 22，向 UI 提供稳定门面，并把背包、队伍、生产、坊市和战斗结算委派给相应服务。

`resources/items/` 与 `resources/skills/` 分别是 58 个核心物品和 12 个核心技能配置的唯一事实来源；两个 Inspector 可编辑 `index.tres` 由 `ItemConfigParser`、`SkillConfigParser` 严格加载、校验和缓存。`DataTables` 只保留稳定 ID、枚举、经济表及解析器生成的兼容字典。核心装备仍以十四个 Inspector 可编辑 `.tres` 为数值事实来源。

主要服务边界：

- `scripts/game/inventory/inventory_service.gd`：物品实例、堆叠、使用、装备、分解和清洗。
- `scripts/game/party/party_service.gd`：招募、队伍顺序、角色成长、技能和命格。
- `scripts/game/core/market_service.gd`：坊市轮换、购买、回收、委托、独立 RNG 和原子事务。
- `scripts/game/core/save_manager.gd`：防抖保存、退出保存、读取和损坏存档回退。

## 战斗与历练

`scripts/map/encounters/` 定义地图遭遇 Profile、Variant 和敌人类别池；`resources/maps/` 保存五行地图及其遭遇资源。详细规则见[历练与战斗](battle-expedition.md)和[敌人遭遇](enemy-encounters.md)。

`scripts/game/combat/combat_controller.gd` 负责一场遭遇的角色顺序、敌人序列、胜负和奖励。`combat_ai.gd` 选择当前行动，`combat_effect_resolver.gd` 与技能执行器结算效果。角色和敌人的场景只负责表现、碰撞和动作反馈。

技能场景统一继承 `SkillSceneBase`，绑定 `SkillDef` 资源，并在动画或碰撞时调用 `impact()`。制作契约见[技能与状态动画制作](skill-authoring.md)。

## 角色与表现

家园和战斗共用 `scripts/actors/actor.tscn`。`ActorController` 根据 `visual_id` 从角色或敌人表现目录装配 `CombatVisual`；形象缺失或契约无效时回退到默认形象。

战斗表现通过 `AnimationPlayer`、`Hurtbox`、`AttackHitbox` 和定位标记与逻辑层连接。表现脚本不能直接推进回合、修改存档或绕过效果结算器。

## UI

`scripts/ui/hud.gd` 负责主要面板编排和刷新，业务校验与提交仍由 `GameState` 及服务完成。物品详情通过 `rich_text_description_renderer.gd` 渲染结构化效果描述，显示文本不能代替实际结算字段。

## Mod 子系统

Mod API 当前版本为 2：

- `scripts/modding/mod_api.gd`：包发现、依赖排序、事务注册、存档导入和公开服务。
- `scripts/modding/api/`：稳定公开类，包括 `ModPlugin`、`ModContext`、内容注册表、事件、隔离存储、RNG 和角色状态。
- `scripts/modding/internal/`：Manifest、内容和资源引用校验，不属于兼容承诺。
- `scripts/modding/ui/`：Mod 启停、授权、排序、错误和重启提示。
- [Mod API 2 文档](modding/quick-start.md)：包、内容、脚本和迁移契约。
- [示例 Mod](../mod_sdk/example_mod/README.md)：可构建的完整示例。

## 资源目录

| 路径 | 内容 |
| --- | --- |
| `resources/items/` | `ItemDef` 资源 |
| `resources/equipment/` | 核心装备索引与十四件独立数值配置 |
| `resources/skills/` | `SkillDef` 资源 |
| `resources/maps/` | 地图和遭遇 Profile |
| `assets/` | 图片、字体和其他导入资产 |

运行时资源路径使用 `res://`。文档链接使用相对仓库路径，避免把本机绝对路径写入文档。

## 测试

`scripts/tests/` 下的 `.tscn` 可以直接作为 Godot 无界面启动场景。测试覆盖生产、核心循环、经济模拟、地图遭遇、敌人掉落、坊市、永久强化丹、技能属性和状态技能框架；`mod_api_v2_contract_test.gd` 验证构建后的示例 Mod。

新增跨系统行为时，应在最接近的现有测试中补充回归；只有形成独立生命周期或大量新边界时才新增测试场景。

## 维护规则

- 核心物品、材料和技能直接修改对应 `.tres` 与 Inspector 索引；配方、坊市和掉落经济表仍修改 `DataTables`。核心装备修改独立 `.tres` 与索引。
- 物品交互、装备、生产或坊市规则同步更新[物品系统](items.md)。
- 战斗、遭遇、效果或返回流程同步更新[历练与战斗](battle-expedition.md)。
- 技能和命格分别同步更新[五行技能](skills.md)与[先天命格](innate-traits.md)。
- 修改 Mod 公开类、Schema 或参数语义时，先更新 [API 变更记录](modding/api-changelog.md)、JSON Schema 和示例包；破坏性变更必须提升 `MOD_API_VERSION`。
- 未实现内容必须明确标记为“规划”，不能写入当前事实表。
