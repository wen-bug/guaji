# Mod API 变更记录

## API 1 / Game 0.1.0

- 首次提供 PCK/ZIP 加载、Manifest 1、内容信封 1 和事务式注册。
- 开放内容注册表、事件、独立存储、可存档 RNG。
- 开放技能场景、effect、AI 条件、CombatVisual、条件对白和角色表现状态。
- `ModPlugin.storage` 与 `rng` 自动绑定当前 Mod 命名空间；查询值和事件载荷均使用深拷贝。
- `CombatVisual` 可为省略的碰撞盒、标记点和动画播放器建立默认契约节点。
- 存档 Schema 升至 10，支持缺失 Mod 内容休眠与恢复。

API 1 内只允许增加可选字段和带默认值的方法。废弃接口至少保留一个游戏次版本并在日志警告；删除或改变既有参数语义必须升级 MOD_API_VERSION。


## API 1 / Game Schema 14

- 新增建筑等级上限查询、完整胜利奖励进度、图纸解锁、定向打造、装备分解、功法兑换、灵石转换和建筑配方解锁接口。
- 存档新增 `reward_progress`，不属于任务系统。
- 技能统一为 `target_scope + target_mode`，后者只接受 `single/aoe`；旧 `release_distance` 接受但忽略。
- 敌人 Schema 新增类别、参考倍率、经验倍率、掉率加成、装备率、技能阶位与阶级池开关。
- 配方 Schema 新增 `unlock_building_level`。
- 永久建筑品质接口继续保留，但普通 HUD 不展示。
