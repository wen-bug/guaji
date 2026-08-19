# Mod 技能

API 2 的新增技能由场景和资源共同定义。内容 JSON 只声明当前 Mod 内的 `scene_path`；运行时实例化场景，从根节点绑定的 `SkillDef` 读取标准化数据。

```json
{
  "schema_version": 2,
  "kind": "skill",
  "entries": [
    {
      "operation": "add",
      "local_id": "storm",
      "data": {
        "scene_path": "res://mods/com.author.example/scenes/storm.tscn"
      }
    }
  ]
}
```

## 资源契约

- 场景根节点继承 `SkillSceneBase` 并绑定 `SkillDef`。
- `SkillDef.id` 必须等于内容 `local_id`；运行时自动加 Mod 命名空间。
- `SkillDef` 必须提供 `display_name`、`type`、`target_scope`、`target_mode` 和 `effects`。
- `target_mode` 只表示单体或群体；API 2 不使用技能距离。
- 场景必须包含 `AnimationPlayer` 的 `RESET` 和非循环 `cast` 动画。
- `cast` 方法轨道必须调用 `impact()` 和 `finish_cast()`；每个效果的 `impact_id` 都要有对应关键帧。

`SkillEffectDef.kind` 支持 `damage`、`heal`、`status` 和 `cooldown`。状态还必须声明 `status_id`、状态类型、持续回合和继承 `StatusVisualBase` 的表现资源。完整场景规则见[技能与状态动画制作](../skill-authoring.md)。

## 自定义处理器

`context.register_effect_handler(local_id, callable)` 注册自定义效果。技能场景执行器调用 `(effect, context) -> Dictionary`，其中 context 提供施法者、目标、技能和 RNG；装备、命格等触发式效果管线调用 `(effect, trigger, context, owner_role) -> Dictionary`。需要复用同一处理器时，应为后三个参数提供默认值。返回值可以包含 `events` 和 `cooldown_multiplier`。

`register_ai_condition()` 仍属于公开注册接口并会参与引用校验，但当前核心 `CombatAI` 只执行内置触发条件；Mod 不应依赖自定义 AI 条件决定技能释放。

核心触发条件以 `CombatAI` 当前实现为准。未注册的自定义效果或条件引用会使整个 Mod 注册事务回滚。
