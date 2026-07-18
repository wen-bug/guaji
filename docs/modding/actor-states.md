# Mod 角色状态

状态脚本继承 `ActorState`，实现：

- `can_enter(actor, payload) -> bool`
- `enter(actor, payload)`
- `update(actor, delta)`
- `handle_event(actor, event_id, payload)`
- `exit(actor)`

用 `context.register_actor_state(local_id, StateClass.new)` 注册工厂，用角色的 `request_actor_state(full_id, payload)` 进入。update 或 handle_event 返回空值表示保持，返回完整状态 ID表示转换。

返回 `core:idle`、`core:roaming`、`core:talking`、`core:paused`、`core:expedition_running`、`core:combat_ready`、`core:combat_moving`、`core:combat_acting` 或 `core:dead` 可回到核心表现状态。进入战斗、死亡等核心命令会中断自定义状态；状态不能控制战斗回合指针。

完整状态示例：

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

入口注册：

```gdscript
extends ModPlugin

const MeditationState = preload("res://mods/com.author.example/scripts/meditation_state.gd")

func register(context: ModContext) -> void:
    context.register_actor_state("meditating", MeditationState.new)
```
