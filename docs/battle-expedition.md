# 历练地图、随机遇怪与循环战斗

## 玩法流程

玩家点击家园 `fight` 节点后，HUD 打开打怪面板。点击面板执行按钮后进入 `BattleMap` 历练地图，约 1 秒后触发首场战斗。

进入历练时，家园侧的打怪入口面板会自动关闭，并播放 `LoadingOverlay` 加载遮罩过渡，避免面板残留在地图上。

历练状态下：

- `Home` 隐藏，`BattleMap` 显示。
- HUD 显示 `ExpeditionHud`，只提供 `返回家园` 入口。
- 队伍沿着透明历练层持续前进，历练层不绘制独立背景。
- 首只怪物在进入历练约 `1.0` 秒后刷新；后续怪物按 `3.0` 到 `5.0` 秒随机间隔刷新。
- 遇怪后进入地图内自动回合战斗，玩家队伍先按 HUD 队伍顺序逐个行动，全员结束后敌人才行动。
- 人物与敌人的普通攻击由形象场景在有效帧开启 Hitbox；只有 Hitbox 与敌方 Hurtbox 的真实碰撞会结算伤害。

完整流程为：家园入口 -> 加载过渡 -> 透明历练层待机 -> 随机间隔遇怪 -> 地图内自动战斗 -> 继续等待下次遇怪。点击 `返回家园` 时会播放同一套加载过渡，清空当前战斗并回到家园，不结算本场战斗奖励。

## 刷怪规则

`BattleMap` 负责维护刷怪计时器。进入历练时使用 1 秒首遇敌延迟；一场战斗结束后，会在 3–5 秒范围内重新随机下一次遇怪时间。

当计时到达并且当前不在战斗中时，`BattleMap` 发出 `monster_spawn_requested` 信号。主场景收到信号后调用当前地图的 `roll_encounter(party_size, level, rng)` 取得最终敌人 ID 序列，再交给 `CombatController.begin_encounter()`，刷新信号本身不携带敌人规则。

每张地图通过 `encounter_profile` 引用自己的 `MapEncounterProfile`。Profile 保存地图专属兜底敌人、人数换算和数量上下限，以及按任意正权重选择的 `MapEncounterVariant`：固定方案严格使用配置顺序且忽略数量规则；随机方案逐位置按 `MapEnemyClassPool` 权重选择类别池，再从池内有效敌人中等概率、有放回抽取。无效 ID 或类别不匹配项会被过滤并报警；整份配置不可用时只使用该地图的 `fallback_enemy_id`。

当前默认历练地图引用 `resources/maps/default_expedition_encounters.tres`，每名队员生成 2 只、总数限制为 1–8，只会刷新 `forest_wolf`。`training_dummy` 不在正式随机遭遇池内。

`CombatController` 根据敌人 ID 读取 `scripts/game/enemies/<enemy_id>/enemy.tscn`，再用统一接口同步运行时数值。敌人定义和掉落表见 `docs/item-table.md`。

战斗结束后，主场景调用 `BattleMap.finish_combat()` 重置刷怪计时。因此不会出现一场战斗结束后立刻无间隔进入下一场战斗。

### 后续：普通、精英与 Boss 内容

完整内容规划见 `docs/enemy-encounters.md`，Boss 具体数据见 `docs/boss-encounters.md`。地图驱动的类别池、权重、固定编队和异种序列框架已经实现，但规划中的普通、精英及 Boss 敌人数据尚未落地；后续特殊地图应新增独立 Profile，而不是修改全局敌人默认值。

规划允许同种重复、三类敌人混编和低概率多个 Boss。敌人仍按生成顺序逐个出场，每只阵亡时立即结算自身经验、材料和装备；之后全灭或主动返回不会回滚已结算奖励，也不会补发未击败敌人的奖励。

后续仍需补齐具体敌人的 `encounter_class`、普通/精英形象池校验、精英倍率、Boss 按阶技能和对应自动化测试。所有敌人技能继续使用现有伤害、DOT、HOT、护盾、吸血、属性增减和破防，不引入职业、召唤、眩晕、冻结或跳过回合。

## 循环战斗

`CombatController` 负责当前遭遇的一场战斗，包括按地图给出的异种敌人序列加载各自场景、队伍成员自动行动、技能冷却、战斗内受伤、胜负、掉落和经验结算。敌人按序逐只出场，每只死亡后立即结算自身奖励并加载下一只；旧调用者仍可传入单个敌人 ID 并按旧数量规则重复生成。`CombatAI` 只负责当前行动成员的自动出招选择；技能场景脚本负责技能动画节点上的实际结算或状态投递；`CombatEffectResolver` 负责技能、装备、命格、敌人动作和临时状态的附加效果判定；敌人自身场景负责自己的攻击与受击反馈。

HUD 不提供自动/手动切换、攻击、防御或技能按钮；战斗过程显示伤害与治疗浮字。

队伍规则：

- 玩家只有一队，最多 4 人。
- 历练战斗按 `party_order` 生成成员站位。
- 全员同场战斗，每轮严格按 `party_order` 依次行动；未轮到的成员保持等待。
- 单名成员的普通攻击按 `READY -> APPROACH -> ATTACK -> RETURN -> RECOVERY` 推进。
- 主动技能按 `READY -> SKILL -> RECOVERY` 推进；特效有效帧只结算一次，动画结束后才推进回合。
- 近战出手前预约目标形象的 `Marker2D`，攻击者实时走到 Marker，动画有效帧开启 Hitbox。
- 当前成员必须完成攻击动画并返回阵型、释放 Marker 后，回合指针才会推进到下一名成员。
- 所有存活成员完成后敌人执行一次行动；敌人攻击并归位后开始下一轮。
- 丹药即时结算；技能在各自场景配置的有效帧结算。技能与丹药冷却单位为角色自身回合，每次获得回合时递减 1。
- 冷却基础值使用整数；百分比修正后的结果向上取整。冷却 5 表示释放后需要经历该角色 5 次回合递减才能再次使用。
- 每个目标每次行动最多结算一次；未发生碰撞不造成普通攻击伤害。
- 新战斗 Buff/Debuff 写入成员 combatant 的 `combat_effects`，旧 `combat_buffs` 继续兼容。
- 默认单体攻击优先选择前排：玩家攻击当前出场的第一名存活敌人，敌人攻击 `party_order` 中第一名存活成员。
- 前排阵亡后，默认目标按各自编队顺序自动顺延到下一名存活单位；当前实现的敌人组按生成顺序逐个出场，因此场上敌人就是玩家侧前排目标。
- 明确传入的有效目标优先于默认前排目标；自身、单体友方、全体友方和全体敌方技能继续按各自 `target_scope` 结算。
- 阵亡成员跳过行动。
- 胜利经验分别发给账号历练和本场参战成员。

高层伤害规则：

- 队伍成员普通攻击基础伤害：`max(1, total_attack_for(member_id) - enemy.defense)`。
- 普通攻击元素为成员主五行；技能攻击元素为技能自身 `element`。
- 普通攻击元素加成：`int(total_element(element) * 0.5)`；已配置属性倍率的技能不再重复获得这项固定加成。
- 命中敌人弱点时额外增加：`max(1, int(base_damage * 0.25)) + total_element(element)`。
- 伤害存在 `damage_attribute_multiplier` 时为 `floor(base_damage + 对应五行属性 * 倍率)`；仅存在 `base_damage` 时为固定伤害；两者都没有时兼容 `总攻击 * damage_multiplier`。
- 治疗采用相同优先级。存在 `heal_attribute_multiplier` 时缩放，仅存在 `heal_amount` 时固定（包括固定 0），两者都没有时兼容 `总攻击 * heal_multiplier`。
- `damage_flat`、`defense_ignore`、DOT、HOT、护盾、治疗和属性增减 effect 仅在自身存在 `attribute_multiplier` 时缩放；省略时 `amount/value` 是固定值。概率、持续时间、冷却比例和吸血比例不参与属性缩放。
- 物理减伤：`max(1, amount - total_defense)`。
- 元素减伤：`max(0, amount - int(total_element(element) * 0.35))`。
- 敌人攻击可按 `element_attack_ratio` 随机附带自身五行。

## 战斗附加效果

战斗内技能、装备、命格、敌人动作和临时状态统一使用 `effects` 字段。

技能本体使用独立场景和脚本。直伤、治疗技能可在技能场景内直接结算；Buff 类技能只把状态写入目标 `CombatActorStatus` 的 `combat_effects` 队列。角色模板只提供技能列表、属性读取和状态队列，不写入具体技能机制。

五行技能特色和规划数值见 `docs/skills.md`。五行只约束技能方向，不绑定角色职业；其中“最低生命友方”选择需要扩展自动战斗目标策略，不能按当前已实现能力处理。

五行主命格、缺陷命格和觉醒数值见 `docs/innate-traits.md`。这些规划战斗命格仍需要把成员的静态命格效果注入技能与普通攻击结算；在该接线完成前，不能把对应战斗修正标记为已实现。

单条效果通用结构：

- `trigger`：触发阶段。
- `kind`：效果类型。
- `target`：目标。
- `value`：数值。
- `stat`：属性。
- `element`：五行。
- `duration_turns`：持续回合。
- `chance`：触发概率。
- `buff_id`：Buff 唯一标识，优先用于覆盖同类状态。
- `stack_key`：叠层键。
- `stack_mode`：叠层模式，默认 `overwrite`，显式 `stack` 时才叠层。
- `max_stacks`：最大层数。
- `consume_on_trigger`：到达触发机会后消耗一次。
- `uses`：可触发次数，`1` 表示一次性 Buff。

触发阶段：

- `attack_start`
- `before_hit`
- `on_hit`
- `after_damage`
- `on_kill`
- `on_damaged`
- `turn_start`
- `turn_end`

效果类型：

- `damage_percent`
- `damage_flat`
- `defense_ignore`
- `element_attach`
- `dot`
- `hot`
- `shield`
- `heal`
- `leech`
- `buff_stat`
- `debuff_stat`
- `cooldown_percent`

解析职责：

- `CombatEffectResolver` 只负责效果筛选、概率判定、状态覆盖或叠加、一次性消耗和事件生成。
- `CombatEffectResolver` 不播放动画、不直接操作 HUD。
- `CombatController` 负责按固定顺序调用解析器并应用结果。

处理顺序：

1. 出手 `attack_start`。
2. 入防御前 `before_hit`。
3. 基础伤害与元素、弱点、防御。
4. 护盾吸收。
5. 有效伤害后的 `on_hit`。
6. 扣血后的 `on_damaged` / `after_damage`。
7. 死亡后的 `on_kill`。
8. 回合开始处理 DOT/HOT。
9. 回合结束递减持续 Buff。

状态规则：

- 玩家和队友的战斗状态写入各自 combatant 的 `combat_effects`。
- 敌人战斗状态写入 `enemy.combat_effects`。
- 旧 `combat_buffs` 保留兼容，属性读取同时识别旧 Buff 与新 `buff_stat` / `debuff_stat` 效果。
- 未命中、0 伤害或完全被护盾抵消时不触发 `on_hit`，但可以触发 `on_damaged`。
- DOT/HOT 不触发 `on_hit`。
- 相同 Buff 默认覆盖。判断顺序为：`buff_id` -> `stack_key` -> `source_skill_id + kind + trigger + target + stat/element`。
- 只有 `stack_mode = "stack"` 时才按层数叠加，叠层上限使用 `max_stacks`。
- 一次性 Buff 使用 `consume_on_trigger = true` 或 `uses = 1`。到达对应触发阶段并完成一次判定后消耗，即使 `chance` 未命中也移除。
- 装备、命格等静态效果不会被一次性消耗；只有写入 `combat_effects` 的临时状态会扣 `uses` 或移除。
- 同阶段多来源顺序固定为：技能效果 -> 装备效果 -> 命格效果 -> 临时战斗状态。

## 战斗结束

### 敌人阶级与成长

敌人阶级由账号历练等级决定：每 20 个历练等级进入下一阶，一至五阶分别为 1-20、21-40、41-60、61-80、81+。敌人运行时保存 `rank`、`rank_level`、`elements`、`skills` 和 `drop_profile`。

生命、攻击和防御使用“模板基础值 + 阶内等级成长”乘以阶级倍率计算。阶级默认技能数量为 0/1/2/3/4，具体敌人可以覆盖技能列表。敌人回合开始时选择一次技能，按条件、冷却和优先级执行，命中帧不会重新随机选择。

掉落先按当前阶级和敌人模板生成掉落池，再进行一次等级修正后的掉落成功判定；成功后按五档稀有度权重抽取物品。阶内每 5 级增加 5% 额外掉落概率，最多增加 15%。

一场战斗胜利后：

- 等待敌人死亡动画完成。
- 结算敌人 `drop_profile`；旧敌人仍兼容 `drops` 表。
- 独立进行装备掉落判定。
- 结算账号历练经验和参战成员经验。
- 主场景结算打怪熟练度。
- 清空当前战斗状态。
- 历练地图保持显示。
- 角色继续沿循环地图前进。
- `BattleMap` 安排下一次随机遇怪。

队伍全灭后：

- 战斗结果标记为 `defeat`，不结算账号经验、角色经验、掉落或战斗熟练度。
- 清空本场临时战斗状态。
- 所有队员生命和法力恢复到各自总上限的 50%，向上取整，生命最低为 1。
- 播放返回家园过渡并退出历练，不再安排下一次遇怪。

返回家园或主动离开时：

- 如果正在自动战斗，先调用 `combat.clear()` 放弃当前战斗。
- 不结算本场战斗奖励。
- 不触发全灭恢复，保留角色当前生命和法力。

## 返回家园

`ExpeditionHud` 的 `返回家园` 按钮发出 `expedition_exit_requested`。主场景收到后：

- 如果正在自动战斗，先调用 `combat.clear()` 放弃当前战斗。
- 播放 `hud.play_scene_transition("返回家园...")`。
- 在遮罩中点调用 `BattleMap.exit_expedition()`。
- 恢复 `Home.visible = true`。
- 让角色退出历练跑步状态。
- 隐藏 `ExpeditionHud` 并刷新 HUD。


## 当前实现：五行地图与有效胜利

| 地图 | 解锁历练 | 普通池 | 特殊位置概率 |
|---|---:|---|---|
| 青木林 | 1 | 林狼、毒纹蛛 | 腐木巫祝精英 14% |
| 赤焰谷 | 6 | 灰烬地精 | 无 |
| 镇岳岭 | 11 | 岩甲蜥 | 镇岳兽王精英 14% |
| 玄金道 | 16 | 玄锋枪卒 | 无 |
| 沉渊泽 | 21 | 潮鳍鱼妖 | 沉渊玄龟 Boss 每位置 1% |

每名出战队员对应 2 个敌人，敌人总数限制 1-8；位置独立、有放回抽取。奖励逐只结算，只有完整清场且该遭遇允许奖励时，才推进功法残页和图纸计数。失败、主动返回及训练战不推进。

历练等级影响地图解锁和地图怪物等级，但不再影响招募候选等级或新装备穿戴需求。
