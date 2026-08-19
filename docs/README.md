# 文档索引

本文档是仓库文档的统一入口。游戏当前版本为 `0.2.0`，存档版本为 Schema 18，Mod 接口为 API 2。

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
- [先天命格](innate-traits.md)：已实现命格字段与后续觉醒规划。
- [五行技能](skills.md)：当前技能规则和五行技能规划。
- [装备成长 V2](equipment-progression-v2.md)：当前五阶装备、强化、词条、升阶与经济循环。

## 内容制作

- [技能与状态动画制作](skill-authoring.md)：本体技能资源、场景和状态动画契约。

## Mod 开发

- [快速开始](modding/quick-start.md)
- [包格式](modding/package-format.md)
- [内容格式参考](modding/content-reference.md)
- [GDScript API 2](modding/scripting-api.md)
- [技能](modding/skills.md)
- [形象](modding/appearances.md)
- [角色状态](modding/actor-states.md)
- [条件对白](modding/dialogues.md)
- [存档与迁移](modding/save-and-migration.md)
- [安全与排错](modding/security-and-troubleshooting.md)
- [API 变更记录](modding/api-changelog.md)
- [JSON Schema 2](modding/schemas/v2/manifest.schema.json)

## 事实来源

文档中的“当前实现”必须能在以下来源中得到验证：

1. 运行时代码和 `project.godot`。
2. `resources/` 下的 Godot 资源。
3. `scripts/tests/` 下的回归测试。
4. 数据类内容以 `scripts/game/data/data_tables.gd` 为最终事实来源，[内容数据表](item-table.md) 是其人工维护索引。
5. Mod 契约以 `scripts/modding/internal/mod_schema_validator.gd`、公开 API 类和 JSON Schema 2 共同定义。

## 维护规范

- 每篇文档只保留一个一级标题，章节层级不得跳级。
- 当前行为置于规划之前；未实现内容必须在标题或段首明确标记为“规划”。
- 不用存档 Schema 编号命名普通功能章节；Schema 编号只用于迁移记录。
- 文档、代码和资源引用使用相对链接；运行时 `res://` 路径保留为代码格式。
- JSON 示例必须使用当前 Manifest/内容 Schema 2，且能够通过运行时校验。
- 修改物品、战斗、命格、技能或 Mod 接口时，同步更新对应主题文档。
