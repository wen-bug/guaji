# 文档索引

本文档是仓库文档的统一入口。游戏当前版本为 `0.2.0`，存档版本为 Schema 23。

## 项目与架构

- [设计基线](design.md)：产品边界、核心循环、经济、成长和 MVP 验收。
- [项目结构](project-structure.md)：子系统职责、主要入口和维护关系。
- [开发路线](../PLAN.md)：未完成事项和后续规划。

## 玩法系统

- [历练与战斗](battle-expedition.md)：地图、遭遇、自动战斗、奖励和返回流程。
- [敌人遭遇](enemy-encounters.md)：当前敌人池和后续普通、精英、Boss 规划。
- [Boss 遭遇](boss-encounters.md)：当前 Boss 和后续 Boss 规格。
- [物品系统](items.md)：背包、装备、生产、炼丹和坊市规则。
- [内容数据表](item-table.md)：已实现物品、配方、技能、装备、敌人和掉落索引。
- [先天命格](innate-traits.md)：已实现三档命格池、固定战斗效果与回合冷却修正。
- [五行技能](skills.md)：当前技能规则和五行技能规划。
- [装备成长 V2](equipment-progression-v2.md)：当前五阶装备、强化、词条、升阶与经济循环。

## 内容制作

- [技能与状态动画制作](skill-authoring.md)：本体技能资源、场景和状态动画契约。

## 事实来源

文档中的“当前实现”必须能在以下来源中得到验证：

1. 运行时代码和 `project.godot`。
2. `resources/` 下的 Godot 资源。
3. `scripts/debug/combat_sandbox.tscn` 交互调试场景及 Godot MCP 的场景树、UI 操作、运行日志和 `game_eval` 结果。
4. 物品、技能、装备和敌人的静态定义以 `resources/` 下对应 `.tres` 为最终事实来源；`scripts/game/data/data_tables.gd` 保留稳定 ID、枚举、经济表、兼容回退及解析器生成的运行时字典；[内容数据表](item-table.md)是人工维护索引。

## 维护规范

- 每篇文档只保留一个一级标题，章节层级不得跳级。
- 当前行为置于规划之前；未实现内容必须在标题或段首明确标记为“规划”。
- 不用存档 Schema 编号命名普通功能章节；Schema 编号只用于迁移记录。
- 文档、代码和资源引用使用相对链接；运行时 `res://` 路径保留为代码格式。
- 修改物品、战斗、命格或技能时，同步更新对应主题文档。
