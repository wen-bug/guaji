# Mod API 变更记录

## API 2 / Game 0.2.0

- Manifest 和内容信封升级到 Schema 2；API/Schema 1 停止加载。
- 技能改为场景绑定 `SkillDef`/`SkillEffectDef`，运行时从资源生成标准定义。
- 技能场景统一使用 `impact()`、`finish_cast()` 和状态表现契约，旧版脚本辅助方法不再提供。
- 技能统一使用 `target_scope + target_mode`；`target_mode` 只接受 `single` 或 `aoe`，技能距离不再参与可用性判断。
- 新增 `ModAPI.skill_scene()` 和 `skill_scene_definition()` 查询。
- 敌人内容支持类别、参考倍率、经验和掉率倍率、技能解锁阶位及类别掉落池。
- 配方支持 `unlock_building_level`，物品支持永久属性强化数据。
- 物品增加可选 `combat_target_mode`（`single` / `aoe`）。旧 API 2 内容省略时按效果推导：含 `combat_global` 为群体，否则为单人；显式单人与 `combat_global` 的组合会被拒绝。本扩展保持 API 2。
- 存档当前为 Schema 23；核心物品支持标准 `effects` 数组，旧 `payload` 在 API 2 注册时自动适配。人物、家园全局和战斗全局 Buff 使用统一秒计时容器，自动道具栏引用稳定物品 ID。核心装备兼容接口、隔离存储和 Mod RNG 不变。Schema 23 移除炼丹学习机制（配方仍按 `unlock_building_level` 解锁），不影响任何 Mod 公开接口。

API 2 内只允许增加可选字段和带默认值的方法。删除接口或改变既有参数语义必须提升 `MOD_API_VERSION`。

## 历史：API 1 / Game 0.1.0

- 首次提供 PCK/ZIP 加载、Manifest 1、内容信封 1 和事务式注册。
- 开放内容注册表、事件、独立存储、可存档 RNG、形象、对白和角色表现状态。
- API 1 包只适用于旧版游戏，当前 `0.2.0` 运行时不会加载。
