# Mod 技能

技能 data 至少包含 `name` 与 `scene_path`。常用字段包括 `type`、`target_scope`、`mp_cost`、`cooldown`、`release_distance`、`damage_multiplier`、`heal_multiplier`、`trigger`、`priority`、`effects`。

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

自定义场景根脚本必须继承 `SkillSceneBase`，接受 `setup` 后在 `start_cast` 播放表现，并通过既有 impact marker 结算、`finished` 信号结束。不得自行推进战斗回合。最小脚本可以在 `apply_marker` 中调用 `attack_context`、`resolve_static_trigger` 和 `apply_effect_events`；完整实现见 `mod_sdk/example_mod`。

自定义 effect 用 `register_effect_handler(local_id, callable)` 注册。回调签名为 `(effect, trigger, context, owner_role)`，可原地修改 context 或返回需要合并的 Dictionary。未知且未注册的 effect 会被规范化阶段过滤。

自定义 AI 条件回调签名为 `(skill, actor_data, target_status) -> bool`。技能 trigger 填写完整条件 ID。核心条件和效果触发阶段顺序不可覆盖。

核心 trigger 为 `always`、`hp_below_50`、`hp_below_35`、`target_hp_below_35`。自定义 ID 必须由当前 Mod 或硬依赖注册。未注册的 effect 或 AI condition 会使当前 Mod 的整个注册事务回滚。
