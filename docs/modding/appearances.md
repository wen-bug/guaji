# Mod 形象

appearance 定义：

- kind：party 或 enemy。
- scene_path：当前 Mod 内的 PackedScene。
- fallback_id：失败时使用的形象 ID。
- contract_version：API 1 固定为 1。

```json
{
  "schema_version": 1,
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

场景根节点必须继承 `CombatVisual`。至少提供 `Sprite2D`、`AnimatedSprite2D` 或名为 `Visual` 的 `CanvasItem`。未提供 `AnimationPlayer`、`Hurtbox`、`AttackHitbox`、`Marker2D`、`HitSocket` 或 `EffectSocket` 时，API 1 会创建可用默认节点；需要精确碰撞范围和动作时应在场景内显式提供。

动画约定为 idle、walk、run、melee_attack、ranged_attack、death、level_up。walk 可回退 run，melee_attack 可回退 attack。契约或资源失败时，角色回退 actor_default，敌人回退 enemy_default；存档仍保留原 visual_id，恢复 Mod 后自动重新显示。

`fallback_id` 必须指向已注册形象，并且不能形成回退环。引用其他 Mod 的形象需要在 Manifest 声明硬依赖。
