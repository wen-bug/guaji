# Mod 形象

`appearance` 定义包含：

- `kind`：`party` 或 `enemy`。
- `scene_path`：当前 Mod 内的 `PackedScene`。
- `fallback_id`：失败时使用的已注册形象 ID。
- `contract_version`：当前固定为 `1`；它独立于 Mod API 版本。

```json
{
  "schema_version": 2,
  "kind": "appearance",
  "entries": [
    {
      "operation": "add",
      "local_id": "disciple",
      "data": {
        "kind": "party",
        "scene_path": "res://mods/com.author.example/scenes/disciple.tscn",
        "fallback_id": "actor_default",
        "contract_version": 1
      }
    }
  ]
}
```

场景根节点必须继承 `CombatVisual`，并提供 `Sprite2D`、`AnimatedSprite2D` 或名为 `Visual` 的 `CanvasItem`。精确动作和碰撞应显式提供 `AnimationPlayer`、`Hurtbox`、`AttackHitbox`、`Marker2D`、`HitSocket` 和 `EffectSocket`。

动画名为 `idle`、`walk`、`run`、`melee_attack`、`ranged_attack`、`death`、`level_up`。`fallback_id` 必须存在且不能形成环；引用其他 Mod 的形象必须声明硬依赖。
