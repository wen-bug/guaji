# 技能与状态动画制作手册

本文档是技能数值资源、单次释放动画和持续状态动画的唯一制作入口。技能机制由
`SkillDef` / `SkillEffectDef` 描述，动画只负责标记结算时机和播放战斗表现。

## 双表现模式

历练 HUD 的“判定块模式”开关控制所有主动技能和持续状态场景的表现，不改变战斗逻辑：

| 模式 | 释放场景 | 持续状态场景 | 物理结算 |
| --- | --- | --- | --- |
| `material` | 显示已有素材；没有素材时保持空白 | 正常播放事件与循环动画 | 使用真实 `SkillHitbox` |
| `hitbox` | 隐藏素材，仅在有效窗口显示真实碰撞形状 | 隐藏且不等待动画 | 使用同一个真实 `SkillHitbox` |

运行时单例为 `SkillPresentation`，公开 `set_mode(mode)`、`get_mode()`、
`is_hitbox_mode()` 和 `mode_changed(mode)`。合法常量是 `MODE_MATERIAL` 与
`MODE_HITBOX`。模式可在释放过程中即时切换：素材使用 `visibility_layer` 隐藏，
不会覆盖动画轨道写入的 `visible`；判定块按当前窗口立即出现或消失。

释放素材节点加入 `skill_material_visual` 分组。为兼容旧场景，根节点直属且名为
`EffectSprite` 的 `CanvasItem` 也会自动识别；新场景仍必须主动加入分组。分组可以包含
多个 `Sprite2D`、`AnimatedSprite2D`、粒子或其他 `CanvasItem`。没有素材时保留空的
`EffectSprite`，不要用判定块或占位图冒充素材。

判定块颜色只表达阵营：敌方目标为半透明红色，友方和自身目标为半透明青绿色。
状态图标、剩余回合、护盾数值、伤害数字和角色受击反馈不属于技能素材，两种模式都显示。
普通攻击继续使用角色自身 `AttackHitbox`，不受本开关影响。

## 三层职责

```text
SkillDef.tres
    数值、目标、消耗、冷却、有序 effects
        |
        v
SkillSceneBase
    单次 cast、可选手工碰撞窗口、一次或多次 impact、finish_cast
        |
        v
CombatSkillExecutor -> 战斗事件 FIFO -> StatusVisualBase
                                      挂载到目标 EffectSocket
```

- 技能释放场景在 `finish_cast()` 后销毁，不持有持续状态生命周期。
- 状态场景不结算技能、不检测技能碰撞、不推进回合。
- 每次 `impact()` 产生的状态事件会立即进入表现 FIFO；`apply` 可以在剩余的 `cast`
  动画仍在播放时开始，但回合必须等待 `cast` 结束且关键表现 FIFO 清空。
- `effects` 中任何 `kind = "status"` 的效果都必须选择状态动画场景，不受技能
  `type` 是 `damage`、`buff` 或 `defense` 的影响。

## 创建技能资源

1. 在 `resources/skills/` 创建 `<skill_id>.tres`，脚本选择 `SkillDef`。
2. 填写稳定 `id`、显示名、类型、目标范围、蓝耗、冷却、距离和 AI 条件。
3. 在 `effects` 中按实际结算顺序添加 `SkillEffectDef`。
4. 每个效果填写 `impact_id`；单段技能保持默认 `impact`，多段技能使用 `hit_1`、
   `hit_2` 等稳定名称，同一段的伤害和状态填写相同 ID。
5. 状态效果填写稳定 `status_id`、`status_kind`、数值、持续回合和叠加策略。
6. 每个状态效果都在 Inspector 的 `status_visual_scene` 中直接选择一个状态场景。

共享状态场景位于 `res://scripts/game/skills/status/visuals/`。可直接选择通用的
`dot.tscn`、`hot.tscn`、`buff.tscn`、`debuff.tscn`、`shield.tscn`，也可选择毒、
流血、攻击提升、狼嚎和玄甲护盾等专属变体。

## 创建技能释放场景

### 场景结构

```text
SkillSceneRoot             Node2D，绑定对应技能类型脚本
├─ EffectSprite            AnimatedSprite2D，加入 skill_material_visual 分组
├─ AnimationPlayer
└─ SkillHitbox             Area2D，正式主动技能应手工创建且只能有一个
   └─ CollisionShape2D     一个或多个，完全手工创建
```

根脚本按技能类型选择：

| 技能用途 | 根脚本 |
| --- | --- |
| 伤害、伤害并附加 DOT/Debuff | `DirectDamageSkill` |
| 治疗、治疗并附加 HOT | `HealSkill` |
| Buff、Debuff、护盾、防御 | `BuffSkill` |

在根节点 Inspector 的 `skill_resource` 选择对应 `.tres`。根节点还可配置锚点和表现
偏移，但代码不会创建、移动或缩放 `SkillHitbox` 和碰撞形状。

### 判定形状与坐标

`SkillHitbox` 是物理结算的唯一依据，不是仅供调试的轮廓。支持并可在判定块模式绘制：

- `RectangleShape2D`：近战横扫、单体覆盖和横向群攻；当前角色 Hurtbox 约用
  `72 × 96`，四人横向队形约用 `480 × 96`。
- `CircleShape2D`：以锚点为中心的爆炸、光环或圆形治疗。
- `CapsuleShape2D`：冲刺、长条弹道和带圆头的直线范围。
- `ConvexPolygonShape2D`：扇形、斜切或其他凸区域；凹多边形要拆成多个凸形状。

形状的本地位置、旋转和缩放会与 `SkillHitbox`、技能根节点的完整变换一起用于物理和
绘制。先让场景根节点依照 `anchor_role` 对齐施法者或首个目标，再在 2D 编辑器中用
角色 `Hurtbox` 的实际尺寸校准形状。不要通过素材帧的位置反推判定，素材可以偏移，
判定必须直接覆盖预期的受击空间。

运行时会把 `SkillHitbox.collision_layer` 设为 `0`，并按 `target_scope` 自动设置 mask：

| 施法方与目标 | 读取的 Hurtbox 层 |
| --- | --- |
| 我方攻击敌方 | `CombatHurtbox.ENEMY_LAYER` |
| 敌方攻击我方 | `CombatHurtbox.PARTY_LAYER` |
| 我方友方/自身技能 | `CombatHurtbox.PARTY_LAYER` |
| 敌方友方/自身技能 | `CombatHurtbox.ENEMY_LAYER` |

物理重叠只是第一层筛选。最终结果还必须出现在 `SkillCastContext.ordered_candidates` 中，
并按这个数组的稳定顺序结算。因此群体宽判定不会命中技能目标范围外、已被控制器排除，
或阵营不符的单位。单个窗口内同一角色只记录一次。

### AnimationPlayer 配置

1. 创建空的 `RESET` 和非循环 `cast`。
2. 方法回调模式设置为 `Immediate`。
3. 使用碰撞窗口时，将 AnimationPlayer 处理模式设置为 `Physics`。
4. 在 `cast` 添加以场景根节点 `.` 为目标的方法轨道。
5. 根据下面的表格添加函数关键帧。

| 函数 | 是否绑定 | 推荐位置 | 作用 |
| --- | --- | --- | --- |
| `start_cast(context)` | 禁止绑定 | 无 | 战斗控制器初始化上下文并播放 `cast` |
| `open_hitbox(impact_id)` | 仅碰撞技能 | 每段碰撞有效区间开始 | 清空上一段命中并开启 `SkillHitbox` 收集 |
| `impact(impact_id = "")` | 每个 ID 必需且只能一次 | 每段实际命中帧 | 结算当前 `impact_id` 对应的有序 `effects`；空参数继承窗口 ID |
| `close_hitbox()` | 仅碰撞技能 | 碰撞有效区间结束 | 停止收集，但保留已命中的目标 |
| `finish_cast()` | 必需 | 最后一个表现帧 | 关闭碰撞兜底并交还战斗流程 |

无碰撞技能的时间轴：

```text
表现开始 -> impact() -> 余下释放表现 -> finish_cast()
```

碰撞技能的时间轴：

```text
open_hitbox() -> 至少一个物理帧 -> impact() -> close_hitbox() -> finish_cast()
```

多段碰撞技能的时间轴：

```text
open_hitbox("hit_1") -> 至少一个物理帧 -> impact() -> close_hitbox()
open_hitbox("hit_2") -> 至少一个物理帧 -> impact() -> close_hitbox()
finish_cast()
```

常见完整时间轴：

```text
单体敌方：锚到 primary_target -> open -> 物理帧 -> impact -> close -> 尾帧 -> finish
群体敌方：锚到 primary_target -> 宽形状 open -> 物理帧 -> impact -> close -> finish
自身技能：锚到 caster -> 与施法者 Hurtbox 重叠 -> open -> 物理帧 -> impact -> close -> finish
多段技能：open(hit_1) -> impact(hit_1) -> close -> open(hit_2) -> impact(hit_2) -> close -> finish
弹道技能：open -> flight_progress 0..1 -> impact -> close -> 落地/消散 -> finish
无碰撞旧场景：impact -> finish（仅为 API 2 兼容，新技能不要采用）
```

`impact()` 会冻结命中结果。存在 `SkillHitbox` 时只结算碰撞窗口命中的合法
`CombatHurtbox`，碰撞落空不会回退到预选目标；不存在时才使用 AI 或控制器预选目标。
多目标始终按战斗队伍顺序结算，不按物理回调顺序。同一目标在同一窗口去重，但可以在
下一个窗口再次受击。状态效果默认使用该段冻结的实际目标，因此状态节点和后续 Buff
动画挂到真正中招角色的 `EffectSocket`；只有显式 `target = caster` 才作用于施法者。

碰撞落空时，`impact()` 仍会结算为空目标并让施法成功完成，但不会回退到
`selected_targets`，也不会产生伤害、治疗或状态。战斗控制器已支付的法力不会返还，
技能仍进入冷却。只有场景契约错误或运行时错误中止才走施法失败处理。

### 固定目标抛物线弹道

回合制目标在释放期间不移动。弹道场景使用以下手工结构：

```text
SkillSceneRoot
├─ ProjectilePath          Node2D，绑定 SkillProjectilePath
│  ├─ EffectSprite         手工配置
│  └─ SkillHitbox          Area2D，手工配置
│     └─ CollisionShape2D  手工配置
└─ AnimationPlayer
```

`SkillProjectilePath` 在 `start_cast()` 时冻结施法者效果锚点和首个预选目标命中锚点。
在 `cast` 中添加 `ProjectilePath:flight_progress` 属性轨道，从 `0` 动画到 `1`；
`arc_height` 控制抛物线高度，`start_offset` / `end_offset` 控制两端偏移。碰撞窗口和
多段方法轨道仍由制作者手工安排，代码不会创建碰撞块、形状或属性关键帧。

弹道碰撞窗口可以覆盖整段飞行，也可以只覆盖接近目标的一段；无论选择哪种，必须在
`impact()` 前至少经历一个物理帧。若要让飞行途中碰到第一个合法目标即结算，需要另写
明确的弹道行为并保持 `ordered_candidates` 过滤，不能从素材位置直接调用伤害逻辑。

### 释放场景禁止事项

- `RESET` 不绑定结算函数。
- 不为每个目标分别调用 `impact()`；只为每个静态 `impact_id` 调用一次。
- 不调用执行器、控制器、`queue_free()` 或任何回合推进函数。
- 不放置 `StatusVisualBase`，也不创建 `apply`、`loop`、`tick` 等状态动画。
- `finish_cast()` 不补做 `impact()`；动画配置错误会中止施法、跳过冷却并返还玩家蓝耗。

## 创建持续状态动画

### 场景结构

```text
StatusVisualRoot           Node2D，绑定 StatusVisualBase
├─ Sprite                  Sprite2D
└─ AnimationPlayer
```

复制 `status_visual_template.tscn` 或继承五类通用场景。状态贴图默认使用来源技能图标，
也可以在专属变体中覆盖贴图或 `tint`。状态场景只能包含属性轨道，禁止方法轨道。

| 动画名 | 战斗事件 | 是否阻塞 | 适用类型 |
| --- | --- | --- | --- |
| `apply` | `status_added` | 是 | 全部状态 |
| `refresh` | `status_refreshed` | 是 | 全部状态 |
| `stack` | `status_stacked` | 是 | `stack` 状态 |
| `loop` | 状态持续存在 | 否 | 全部状态 |
| `tick` | `status_tick` | 是 | DOT、HOT |
| `absorb` | `shield_absorbed` | 是 | 护盾 |
| `break` | 护盾以 `depleted` 移除 | 是 | 护盾 |
| `remove` | 到期、死亡或清理 | 是 | 全部状态 |

`loop` 必须循环，其他动画必须非循环。缺少 `refresh` 或 `stack` 时可以回退到 `apply`；
正式共享场景仍应创建符合自身类型的完整动画集合。多个状态共存时按施加顺序轮播
`loop`，循环表现不阻塞战斗。

状态表现与逻辑计时相互独立：命中产生 `status_added` 后立即在实际受击目标上播放
`apply`，完成后进入非阻塞 `loop`；DOT/HOT 不在命中时结算，而在该目标接下来的每次
回合开始触发 `tick`。Buff、Debuff 和护盾命中后立即提供被动数值，并在该目标回合结束
扣除持续回合。在目标当前回合内新加的状态不会于当前回合末误扣。

判定块模式下，`StatusVisualBase` 停止事件动画和 `loop`，事件返回 `0` 秒并在延迟调用中
发出完成信号，因此表现 FIFO 不会阻塞回合。切回素材模式时，仍存续的状态会恢复循环。
这个隐藏只作用于挂在 `EffectSocket` 的状态场景，不删除状态数据，也不隐藏状态栏图标。

状态场景不绑定 `start_cast()`、`open_hitbox()`、`impact()`、`close_hitbox()`、
`finish_cast()` 或任何其他函数。事件到达后由 `CombatStatusPresenter` 自动选择动画。

## 复合技能示例

直伤并附加中毒的技能资源按以下顺序配置：

```text
effects[0] = damage
effects[1] = status(dot, status_visual_scene = poison.tscn)
```

释放场景在命中帧调用 `impact()`。执行器先产生伤害事件，再产生 `status_added`；
表现队列随即在实际受击目标的 `EffectSocket` 播放 `apply`，释放场景继续播放剩余的
单次 `cast`。`apply` 完成后状态独立轮播 `loop`，`finish_cast()` 只销毁释放场景；
目标回合开始时逻辑结算并播放 `tick`，到期时播放 `remove`。

## 后补或替换素材

1. 在释放场景的 `EffectSprite` 配置 `SpriteFrames`，或添加新的 `CanvasItem` 子节点。
2. 把所有属于释放特效的节点加入 `skill_material_visual` 分组。
3. 在 `cast` 中只添加素材属性轨道，例如 `visible`、`frame`、`animation`、位置、缩放、
   透明度和粒子启停。
4. 保留原有方法轨道的 `open_hitbox()`、`impact()`、`close_hitbox()` 和
   `finish_cast()` 时间与顺序，并保留 `SkillHitbox` 的形状和变换。
5. 分别在素材与判定块模式下释放，确认命中目标、伤害、状态、蓝耗和冷却完全一致。

素材只能改变表现。禁止为了配合新帧而移动命中帧、扩大判定、改变目标范围，或在素材
脚本、粒子回调和帧变化信号中结算效果。确需改变手感或物理范围时，将其作为玩法变更
单独设计并更新测试，不应混入素材补充提交。

## 常见错误

- 素材模式为空：确认素材已赋值，节点加入 `skill_material_visual`，且动画轨道在需要时
  设置 `visible = true`；空素材技能本来就应为空白。
- 判定块始终不显示：确认已切到 `hitbox`，窗口已执行 `open_hitbox()`，形状未禁用。
- 判定块显示但不命中：检查 Hurtbox 阵营层、`target_scope`、`ordered_candidates` 和坐标。
- 预选目标存在却无效果：真实形状没有重叠，这是合法落空，不会回退。
- 自身技能落空：根节点应锚到 `caster`，形状必须与施法者自己的 Hurtbox 重叠。
- 群攻误伤额外单位：宽形状可重叠，但候选数组必须只包含本次技能允许的目标。
- 切换模式后素材不恢复：不要由模式代码改 `visible`；通过分组让框架控制
  `visibility_layer`。
- 判定模式仍等待状态动画：状态场景根必须继承 `StatusVisualBase`，不要自行等待
  `AnimationPlayer.animation_finished`。
- 契约报告不支持的形状：只使用矩形、圆、胶囊和凸多边形，或先扩展绘制契约和测试。

## 模板约定

要求创建“技能模板”时，只创建根节点、指定类型脚本、`EffectSprite`、
`AnimationPlayer` 和空 `RESET/cast`；不创建资源、碰撞、轨道或状态场景。

要求创建“状态动画模板”时，只创建 `StatusVisualBase` 根节点、`Sprite`、
`AnimationPlayer` 和指定的空命名动画；不修改技能资源、释放场景或效果数值。

## 保存前检查

- 技能场景根节点已选择正确 `skill_resource`。
- 正式主动技能恰好有一个名为 `SkillHitbox` 的 `Area2D`，至少一个启用的支持形状；
  普通攻击除外。
- 所有释放素材节点都加入 `skill_material_visual`；缺素材节点保持空白。
- `cast` 非循环，方法回调模式为 `Immediate`，每个 `impact_id` 准确绑定一次
  `impact()`，并准确绑定一次 `finish_cast()`。
- 每段严格按 `open -> 至少一个物理帧 -> impact -> close`，所有段之后才 `finish`。
- 碰撞技能的 AnimationPlayer 处理模式为 `Physics`；弹道技能的 `cast` 包含
  `flight_progress` 属性轨道。
- 单体/自身形状覆盖对应 Hurtbox，群体形状覆盖战斗队形；实际目标仍由候选过滤。
- 实测重叠命中、移出落空、模式中途切换，且两种模式得到相同战斗结果。
- 每个 `kind = "status"` 的效果都选择了 `status_visual_scene`。
- 状态场景根节点继承 `StatusVisualBase`，节点命名正确且没有方法轨道。
- `loop` 循环，其他状态事件动画非循环。
- 运行 `skill_presentation_mode_test.tscn`、状态框架、HUD、核心循环和 Mod API 契约测试。

## 保存兼容检查

- 技能资源同时定义 `target_scope` 和 `target_mode`。
- `target_mode` 只能是 `single` 或 `aoe`，不再区分 self/ally/enemy；阵营语义由 `target_scope` 表达。
- 本体与新 Mod 技能不得写入 `release_distance`，UI 也不显示技能距离。
- 技能可用性不得引用距离；只有普通攻击场景保留内部接近、范围和 Hitbox 数据。
- 敌人技能遵循同一规则。
