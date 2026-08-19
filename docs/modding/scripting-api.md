# GDScript API 2

## 稳定边界

稳定入口是 Autoload `ModAPI`、`scripts/modding/api/` 下的公开类、`SkillSceneBase` 和 `CombatVisual`。Main、HUD、DataTables 内部字典、战斗控制器节点和 `scripts/modding/internal/` 不属于兼容承诺。

入口脚本继承 `ModPlugin`。生命周期依次为 `register(context)`、存档导入和可选 `migrate_save()`、`on_game_ready(api)`。注册和事件回调在主线程同步执行，不得 `await`。

## 注册

- `context.define(kind, local_id, data)`
- `context.patch(kind, target_id, merge_patch)`
- `context.register_actor_state(local_id, factory)`
- `context.register_effect_handler(local_id, callable)`
- `context.register_ai_condition(local_id, callable)`
- `context.register_dialogue_condition(local_id, callable)`
- `context.fail(code, message)`

注册项先暂存，全部校验通过后原子提交。注册表冻结后使用 `ModAPI.content.definition()`、`has()`、`ids()`、`source_of()` 和 `all()` 查询；结果均为深拷贝。

API 2 公开 `ModAPI.skill_scene(skill_id)` 和 `skill_scene_definition(skill_id)`，用于查询已通过契约校验的技能场景及标准化定义。

## 存储、随机与事件

每个 `ModPlugin` 的 `storage` 和 `rng` 自动绑定当前 Mod ID：

- `storage.get_value(key, fallback)`、`set_value()`、`erase_value()`、`all()`。
- `rng.stream(purpose)` 返回独立、可随存档恢复的随机流。
- `ModAPI.events.subscribe(event_id, callback)` 和 `unsubscribe()` 管理事件监听。

开放事件为 `game_ready`、`save_loaded`、`before_save`、`member_created`、`combat_started`、`combat_finished`。载荷只包含可复制、可序列化的值，不暴露场景节点。

`combat_started.enemy_ids` 是完整有序敌人序列，兼容字段 `enemy_id` 为首只敌人；`combat_finished` 同时提供结果、当前结算敌人和完整序列。

## 兼容规则

API 2 内只增加可选字段或带默认值的方法。删除接口、改变参数语义或改变持久化格式时必须提升 `MOD_API_VERSION`，并在 [API 变更记录](api-changelog.md) 中说明迁移方式。
