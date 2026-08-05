# Mod 技能

技能 data 至少包含 `name` 与 `scene_path`。常用字段包括 `type`、`target_scope`、`mp_cost`、`cooldown`、`release_distance`、`base_damage`、`damage_attribute_multiplier`、`heal_amount`、`heal_attribute_multiplier`、`trigger`、`priority`、`effects`。

```json
{
  "schema_version": 1,
  "kind": "skill",
  "entries": [
    {
      "operation": "add",
      "local_id": "storm",
      "data": {
        "name": "天雷",
        "type": "damage",
        "target_scope": "all_enemies",
        "element": "metal",
        "mp_cost": 10,
        "cooldown": 4,
        "base_damage": 8,
        "damage_attribute_multiplier": 1.2,
        "release_distance": 140,
        "priority": 70,
        "trigger": ["com.author.example:target_ready"],
        "effects": [
          {
            "kind": "com.author.example:spirit_burn",
            "trigger": "before_hit",
            "target": "enemy",
            "amount": 2
          }
        ],
        "scene_path": "res://mods/com.author.example/scenes/storm.tscn"
      }
    }
  ]
}
```

所有属性倍率字段都可省略。伤害存在 `damage_attribute_multiplier` 时按 `floor(base_damage + 对应五行属性 * 倍率)` 结算；只有 `base_damage` 时是固定伤害；两者都没有时兼容旧 `总攻击 * damage_multiplier`。治疗对 `heal_amount` 和 `heal_attribute_multiplier` 使用相同规则，显式 `heal_amount: 0` 也是固定 0。

`dot`、`hot`、`shield`、`heal`、`buff_stat`、`debuff_stat`、`damage_flat` 和 `defense_ignore` 仅在 effect 自身提供 `attribute_multiplier` 时缩放，省略时 `amount/value` 是固定值。effect 自身的 `element` 优先于技能元素；两者都为空时读取施法者主五行。`chance`、持续时间、冷却比例与吸血比例不参与属性缩放。已提供的基础值和倍率字段必须是非负数。

自定义技能场景和状态场景使用与核心内容相同的 v2 契约。释放动画的方法轨道、手工碰撞窗口、`status_visual_scene` 选择和状态动画命名统一见
[`../skill-authoring.md`](../skill-authoring.md)，本页不重复维护动画接口。Mod 场景和资源必须位于当前 Mod 命名空间目录。

自定义 effect 用 `register_effect_handler(local_id, callable)` 注册。回调签名为 `(effect, trigger, context, owner_role)`，可原地修改 context 或返回需要合并的 Dictionary。未知且未注册的 effect 会被规范化阶段过滤。

自定义 AI 条件回调签名为 `(skill, actor_data, target_status) -> bool`。技能 trigger 填写完整条件 ID。核心条件和效果触发阶段顺序不可覆盖。

核心 trigger 为 `always`、`hp_below_50`、`hp_below_35`、`target_hp_below_35`。自定义 ID 必须由当前 Mod 或硬依赖注册。未注册的 effect 或 AI condition 会使当前 Mod 的整个注册事务回滚。
