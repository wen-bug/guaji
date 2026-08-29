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

## 物理判定与双表现模式

API 2 保持向后兼容：已有 Mod 技能可以没有 `SkillHitbox`，此时 `impact()` 继续使用控制器
预选目标。API 版本和 JSON 数据格式没有变化。但是新制作或重做的主动技能应采用真实
物理判定契约：

- 场景内恰好一个名为 `SkillHitbox` 的 `Area2D`，包含至少一个手工配置的
  `CollisionShape2D`。
- 支持矩形、圆、胶囊和凸多边形；`AnimationPlayer` 处理模式设为 `Physics`，方法回调
  保持 `Immediate`。
- 每段方法轨道严格为 `open_hitbox(impact_id) -> 至少一个物理帧 ->
  impact(impact_id) -> close_hitbox()`，全部结束后调用 `finish_cast()`。
- 物理重叠结果仍按 `context.ordered_candidates` 过滤和排序。碰撞落空不会回退到预选目标，
  但施法正常成功、消耗法力并进入冷却。
- 自身和友方技能也必须让形状与对应 `CombatHurtbox` 真实重叠。

Mod 释放素材节点应加入 `skill_material_visual` 分组；直属且名为 `EffectSprite` 的旧节点
仍兼容。素材模式显示这些节点并隐藏判定轮廓，判定块模式隐藏这些节点并只在窗口内绘制
真实形状。没有素材时素材模式保持空白。Mod 不应读取当前表现模式来改变 effects、目标、
碰撞层、命中帧、冷却或其他玩法结果。

状态表现根节点继承 `StatusVisualBase` 后会自动遵循模式：判定块模式隐藏状态动画并立即
释放表现等待，状态数据、图标和生命周期仍正常。自行实现的状态表现也必须保证隐藏表现
不会跳过逻辑或阻塞回合。

完整的形状选型、坐标对齐、单段/多段/弹道时间轴、素材后补流程和检查清单见
[技能与状态动画制作](../skill-authoring.md)。旧 API 2 的无碰撞兼容只用于保持已有内容可用，
不代表新技能推荐省略物理判定。

`SkillEffectDef.kind` 支持 `damage`、`heal`、`status` 和 `cooldown`。状态还必须声明 `status_id`、状态类型、持续回合和继承 `StatusVisualBase` 的表现资源。完整场景规则见[技能与状态动画制作](../skill-authoring.md)。

## 自定义处理器

`context.register_effect_handler(local_id, callable)` 注册自定义效果。技能场景执行器调用 `(effect, context) -> Dictionary`，其中 context 提供施法者、目标、技能和 RNG；装备、命格等触发式效果管线调用 `(effect, trigger, context, owner_role) -> Dictionary`。需要复用同一处理器时，应为后三个参数提供默认值。返回值可以包含 `events` 和 `cooldown_multiplier`。

`register_ai_condition()` 仍属于公开注册接口并会参与引用校验，但当前核心 `CombatAI` 只执行内置触发条件；Mod 不应依赖自定义 AI 条件决定技能释放。

核心触发条件以 `CombatAI` 当前实现为准。未注册的自定义效果或条件引用会使整个 Mod 注册事务回滚。
