# 技能与状态动画制作

主动技能的目标由 `CombatController` 在施法开始时按 `target_scope`、`target_count` 和 `target_tendency` 选定，并写入 `SkillCastContext.selected_targets`。`impact()` 在动画关键帧直接结算这些仍存活的目标；技能和角色表现的坐标、Area2D、CollisionShape2D 都不会改变命中结果。

## 主动技能场景

场景根节点继承对应的 `SkillSceneBase` 子类，并绑定 `SkillDef`。必须包含 `AnimationPlayer`、`RESET` 动画和非循环 `cast` 动画。`cast` 的根节点方法轨道至少包含：

```text
impact() -> finish_cast()
```

多段技能为每个效果声明唯一的 `impact_id`，并在对应表现帧调用：

```text
impact("hit_1") -> impact("hit_2") -> finish_cast()
```

`impact_id` 在一次施法内只能结算一次。施法前死亡的预选目标会被跳过；候选范围之外的单位不会因为位置接近而被命中。技能素材使用 `EffectSprite` 或加入 `skill_material_visual` 分组的 CanvasItem，始终按动画正常显示。

新场景不得创建 `SkillHitbox`、`CollisionShape2D` 或物理帧时间轴。`open_hitbox()`、`close_hitbox()` 仅保留为空方法，用于兼容旧技能场景。

## 定位与状态

`anchor_role` 为 `auto` 时，自身技能锚到施法者，其他技能锚到首个逻辑目标。`effect_offset` 只影响特效位置，不能影响目标集合。

状态场景继承 `StatusVisualBase`，只负责 `apply`、`refresh`、`stack`、`loop`、`tick`、`absorb`、`break`、`remove` 等表现动画，不结算主动技能或物理重叠。状态表现始终正常播放，不存在判定块模式。

## 脚手架与检查

`scripts/editor/skill_scaffold.gd` 只生成逻辑结算时间轴：单段技能生成 `impact()` 和 `finish_cast()`，多段技能生成带 `impact_id` 的多个 `impact()`。生成后补齐 SkillDef 数值、EffectSprite 素材与动画时机。

提交前检查：

- 每个内置主动技能都没有 `SkillHitbox` 或碰撞形状。
- 每个 `cast` 动画都有 `impact()` 和 `finish_cast()`，且所有效果的 `impact_id` 都有关键帧。
- 单体、群体、自身和友方技能均按逻辑选中的目标结算。
- 目标移动、特效偏移或旧碰撞节点不会改变命中结果。
- 从 HUD 调试面板进入战斗技能沙盒，通过 Godot MCP 检查技能、状态和视觉表现。
