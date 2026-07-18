# GDScript API 1

## 稳定边界

唯一稳定入口是 Autoload `ModAPI`、`scripts/modding/api/` 下的公开类、`SkillSceneBase` 和 `CombatVisual`。直接访问 Main、HUD、DataTables 内部字典或战斗控制器节点不受兼容承诺保护。

入口脚本继承 `ModPlugin`。生命周期依次为 `register(context)`、存档导入与可选 `migrate_save`、`on_game_ready(api)`。注册和事件回调在主线程同步执行，禁止 `await`。

## 注册 API

- `context.define(kind, local_id, data)`
- `context.patch(kind, target_id, merge_patch)`
- `context.register_actor_state(local_id, factory)`
- `context.register_effect_handler(local_id, callable)`
- `context.register_ai_condition(local_id, callable)`
- `context.register_dialogue_condition(local_id, callable)`
- `context.fail(code, message)`

注册项先暂存，校验通过后原子提交。注册表冻结后使用 `ModAPI.content.definition/has/ids/source_of/all` 查询，结果均为深拷贝。

Godot 的 `Object.get` 和 `Object.set` 是保留的原生方法，GDScript 不能用不同参数签名覆盖它们。因此 API 1 使用 `definition`、`get_value` 和 `set_value`，分别对应通用规范中的 `get`、`storage.get` 和 `storage.set`。

## 运行服务

每个 `ModPlugin` 实例的 `storage` 和 `rng` 已绑定到当前 Mod ID。不要传入或拼接 Mod ID，也不要直接调用 `ModAPI.storage` 的内部导入导出方法。

- `storage.get_value(key, fallback)`
- `storage.set_value(key, value)`
- `storage.erase_value(key)`
- `storage.all()`
- `rng.stream(purpose)`
- `ModAPI.events.subscribe(event_id, callback)`

存储查询返回深拷贝。RNG 流的状态随存档保存；需要可复现结果时不要使用全局随机函数。

开放事件：`game_ready`、`save_loaded`、`before_save`、`member_created`、`combat_started`、`combat_finished`。事件载荷为深拷贝，监听器返回值不会修改核心结果。

事件载荷只包含可复制、可序列化的值，不暴露场景节点：`game_ready` 提供游戏/API 版本，`before_save` 提供存档 Schema 和队伍成员 ID，`member_created` 提供成员快照，战斗事件提供敌人、队伍和结果摘要。
