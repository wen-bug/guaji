# Mod API 变更记录

## API 1 / Game 0.1.0

- 首次提供 PCK/ZIP 加载、Manifest 1、内容信封 1 和事务式注册。
- 开放内容注册表、事件、独立存储、可存档 RNG。
- 开放技能场景、effect、AI 条件、CombatVisual、条件对白和角色表现状态。
- `ModPlugin.storage` 与 `rng` 自动绑定当前 Mod 命名空间；查询值和事件载荷均使用深拷贝。
- `CombatVisual` 可为省略的碰撞盒、标记点和动画播放器建立默认契约节点。
- 存档 Schema 升至 10，支持缺失 Mod 内容休眠与恢复。

API 1 内只允许增加可选字段和带默认值的方法。废弃接口至少保留一个游戏次版本并在日志警告；删除或改变既有参数语义必须升级 MOD_API_VERSION。
