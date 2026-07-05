# 历练地图、随机遇怪与循环战斗

## 玩法流程

玩家点击家园 `fight` 节点后，HUD 打开打怪面板。点击面板执行按钮后进入 `BattleMap` 历练地图，但不会立刻开战。

进入历练时，家园侧的打怪入口面板会自动关闭，并播放 `LoadingOverlay` 加载遮罩过渡，避免面板残留在地图上。

历练状态下：

- `Home` 隐藏，`BattleMap` 显示。
- HUD 显示 `ExpeditionHud`，只提供 `返回家园` 入口。
- 队伍沿着历练地图持续前进，地图背景和地面层横向循环滚动。
- 怪物按随机间隔刷新，默认范围是 `8.0` 到 `20.0` 秒。
- 遇怪后进入地图内自动战斗，队伍成员按 HUD 队伍顺序排队生成，所有存活成员独立冷却并自动出招。
- 训练敌人可使用固定普攻策略，受击表现由战斗控制器触发，表现层不参与伤害计算。

完整流程为：家园入口 -> 加载过渡 -> 历练跑图 -> 随机间隔遇怪 -> 地图内自动战斗 -> 继续跑图等待下次遇怪。点击 `返回家园` 时会播放同一套加载过渡，清空当前战斗并回到家园，不结算本场战斗奖励。

## 刷怪规则

`BattleMap` 负责维护刷怪计时器。进入历练或一场战斗结束时，会重新随机下一次遇怪时间。

当计时到达并且当前不在战斗中时，`BattleMap` 发出 `monster_spawn_requested` 信号。主场景收到信号后调用 `CombatController.begin_encounter(game_state, battle_map)` 创建敌人，并把当前循环地图作为战斗坐标参考。

`CombatController` 根据敌人 ID 读取 `scripts/game/enemies/<enemy_id>/enemy.tscn`，再用统一接口同步运行时数值。敌人定义和掉落表见 `docs/item-table.md`。

战斗结束后，主场景调用 `BattleMap.finish_combat()` 重置刷怪计时。因此不会出现一场战斗结束后立刻无间隔进入下一场战斗。

## 循环战斗

`CombatController` 负责当前遭遇的一场战斗，包括敌人生成、队伍成员自动行动、技能冷却、战斗内受伤、胜负、掉落和经验结算。`CombatAI` 只负责当前行动成员的自动出招选择；技能场景脚本负责技能动画节点上的实际结算或状态投递；`CombatEffectResolver` 负责技能、装备、命格、敌人动作和临时状态的附加效果判定；敌人自身场景负责自己的攻击与受击反馈。

HUD 不提供自动/手动切换、攻击、防御、技能按钮或伤害浮字。

队伍规则：

- 玩家只有一队，最多 4 人。
- 历练战斗按 `party_order` 生成成员站位。
- 全员同场战斗，每个存活成员拥有独立行动冷却、技能冷却和战斗 Buff。
- 新战斗 Buff/Debuff 写入成员 combatant 的 `combat_effects`，旧 `combat_buffs` 继续兼容。
- 敌人默认攻击队首存活成员，阵亡成员跳过行动。
- 胜利经验发给队伍内所有成员。

高层伤害规则：

- 队伍成员普通攻击基础伤害：`max(1, total_attack_for(member_id) - enemy.defense)`。
- 普通攻击元素为成员主五行；技能攻击元素为技能自身 `element`。
- 元素伤害加成：`int(total_element(element) * 0.5)`。
- 命中敌人弱点时额外增加：`max(1, int(base_damage * 0.25)) + total_element(element)`。
- 技能伤害基础值：`int(total_attack * skill.damage_multiplier)`，再走同元素、弱点和防御规则。
- 物理减伤：`max(1, amount - total_defense)`。
- 元素减伤：`max(0, amount - int(total_element(element) * 0.35))`。
- 敌人攻击可按 `element_attack_ratio` 随机附带自身五行。

## 战斗附加效果

战斗内技能、装备、命格、敌人动作和临时状态统一使用 `effects` 字段。

技能本体使用独立场景和脚本。直伤、治疗技能可在技能场景内直接结算；Buff 类技能只把状态写入目标 `CombatActorStatus` 的 `combat_effects` 队列。角色模板只提供技能列表、属性读取和状态队列，不写入具体技能机制。

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

一场战斗胜利后：

- 结算敌人 `drops` 表。
- 独立进行装备掉落判定。
- 结算队伍经验。
- 主场景结算打怪熟练度。
- 清空当前战斗状态。
- 历练地图保持显示。
- 角色继续沿循环地图前进。
- `BattleMap` 安排下一次随机遇怪。

返回家园或主动离开时：

- 如果正在自动战斗，先调用 `combat.clear()` 放弃当前战斗。
- 不结算本场战斗奖励。

## 返回家园

`ExpeditionHud` 的 `返回家园` 按钮发出 `expedition_exit_requested`。主场景收到后：

- 如果正在自动战斗，先调用 `combat.clear()` 放弃当前战斗。
- 播放 `hud.play_scene_transition("返回家园...")`。
- 在遮罩中点调用 `BattleMap.exit_expedition()`。
- 恢复 `Home.visible = true`。
- 让角色退出历练跑步状态。
- 隐藏 `ExpeditionHud` 并刷新 HUD。
