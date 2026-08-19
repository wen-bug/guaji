# Mod 角色状态

状态脚本继承 `ActorState`，可以实现 `can_enter()`、`enter()`、`update()`、`handle_event()` 和 `exit()`。使用 `context.register_actor_state(local_id, factory)` 注册，再由角色调用完整状态 ID 进入。

```gdscript
extends ActorState

var remaining := 2.0

func enter(actor: Node, _payload: Dictionary = {}) -> void:
    remaining = 2.0
    if actor.has_method("_play_visual_state"):
        actor.call("_play_visual_state", &"idle")

func update(_actor: Node, delta: float):
    remaining -= delta
    return "core:idle" if remaining <= 0.0 else null
```

`update()` 或 `handle_event()` 返回 `null` 表示保持状态，返回完整状态 ID 表示转换。核心战斗和死亡命令可以中断自定义状态；角色状态只能控制表现，不能推进战斗回合或直接修改结算。
