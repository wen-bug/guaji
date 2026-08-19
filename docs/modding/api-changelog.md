# Mod API 变更记录

## API 2 / Game 0.2.0

- Manifest 和内容信封升级到 Schema 2；API/Schema 1 停止加载。
- 技能改为场景绑定 `SkillDef`/`SkillEffectDef`，运行时从资源生成标准定义。
- 技能场景统一使用 `impact()`、`finish_cast()` 和状态表现契约，旧版脚本辅助方法不再提供。
- 技能统一使用 `target_scope + target_mode`；`target_mode` 只接受 `single` 或 `aoe`，技能距离不再参与可用性判断。
- 新增 `ModAPI.skill_scene()` 和 `skill_scene_definition()` 查询。
- 敌人内容支持类别、参考倍率、经验和掉率倍率、技能解锁阶位及类别掉落池。
- 配方支持 `unlock_building_level`，物品支持永久属性强化数据。
- 存档当前为 Schema 18；Mod 隔离存储、RNG 和迁移接口保持不变。

API 2 内只允许增加可选字段和带默认值的方法。删除接口或改变既有参数语义必须提升 `MOD_API_VERSION`。

## 历史：API 1 / Game 0.1.0

- 首次提供 PCK/ZIP 加载、Manifest 1、内容信封 1 和事务式注册。
- 开放内容注册表、事件、独立存储、可存档 RNG、形象、对白和角色表现状态。
- API 1 包只适用于旧版游戏，当前 `0.2.0` 运行时不会加载。
