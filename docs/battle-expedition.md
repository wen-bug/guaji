# 历练地图、随机遇怪与循环战斗

## 玩法流程

玩家点击家园 `fight` 节点后，HUD 打开打怪面板。点击面板执行按钮后进入 `BattleMap` 历练地图，但不会立刻开战。
进入历练时，家园侧的打怪入口面板会自动关闭，并播放 `LoadingOverlay` 加载遮罩过渡，避免面板残留在地图上。

历练状态下：
- `Home` 隐藏，`BattleMap` 显示。
- HUD 显示 `ExpeditionHud`，只提供 `返回家园` 入口。
- 队伍沿着历练地图持续前进，地图背景和地面层横向循环滚动。
- 遇怪后进入地图内自动战斗，队伍成员按 HUD 队伍顺序排队生成，所有存活成员独立冷却并自动出招。
- 怪物按随机间隔刷新，默认范围是 `8.0` 到 `20.0` 秒。
- 训练敌人可使用固定普攻策略，受击表现由战斗控制器触发，表现层不参与伤害计算。

完整流程为：家园入口 → 加载过渡 → 历练跑图 → 随机间隔遇怪 → 地图内自动战斗 → 继续跑图等待下次遇怪。点击 `返回家园` 时会播放同一套加载过渡，清空当前战斗并回到家园，不结算本场战斗奖励。

## 刷怪规则

`BattleMap` 负责维护刷怪计时器。进入历练或一场战斗结束时，会重新随机下一次遇怪时间。

当计时到达并且当前不在战斗中时，`BattleMap` 发出 `monster_spawn_requested` 信号。主场景收到信号后调用 `CombatController.begin_encounter(game_state, battle_map)` 创建敌人，并把当前循环地图作为战斗坐标参考。`CombatController` 根据敌人 ID 读取 `scripts/game/enemies/<enemy_id>/enemy.tscn`，再用统一接口同步运行时数值。

战斗结束后，主场景调用 `BattleMap.finish_combat()` 重置刷怪计时。因此不会出现一场战斗结束后立刻无间隔进入下一场战斗。

## 循环战斗

`CombatController` 现在负责当前遭遇的一场战斗，包括敌人生成、队伍成员自动行动、技能冷却、战斗内受伤、胜负、掉落和经验结算。`CombatAI` 只负责当前行动成员的自动出招选择；`CombatEffectResolver` 负责技能、装备、命格、敌人动作和临时状态的附加效果判定；敌人自身场景负责自己的攻击与受击反馈。HUD 不提供自动/手动切换、攻击、防御、技能按钮或伤害浮字。

队伍规则：
- 玩家只有一队，最多 4 人。
- 历练战斗按 `party_order` 生成成员站位。
- 全员同场战斗，每个存活成员拥有独立行动冷却、技能冷却和战斗 Buff。
- 新战斗 Buff/Debuff 写入成员 combatant 的 `combat_effects`，旧 `combat_buffs` 继续兼容。
- 敌人默认攻击队首存活成员，阵亡成员跳过行动。
- 胜利经验发给队伍内所有成员。

附加效果规则：
- 效果统一使用 `effects`，触发阶段包括 `attack_start`、`before_hit`、`on_hit`、`after_damage`、`on_kill`、`on_damaged`、`turn_start`、`turn_end`。
- 同阶段来源顺序为技能、装备、命格、临时状态；敌人动作也可以携带 `effects`。
- 护盾先抵消伤害，完全抵消时不触发 `on_hit`，但可触发 `on_damaged`。
- DOT/HOT 只在回合开始结算，不再次触发攻击命中效果。

一场战斗结束后：
- 主场景结算打怪熟练度。
- 清空当前战斗状态。
- 历练地图保持显示。
- 角色继续沿循环地图前进。
- `BattleMap` 安排下一次随机遇怪。

## 返回家园

`ExpeditionHud` 的 `返回家园` 按钮发出 `expedition_exit_requested`。主场景收到后：
- 如果正在自动战斗，先调用 `combat.clear()` 放弃当前战斗。
- 播放 `hud.play_scene_transition("返回家园...")`。
- 在遮罩中点调用 `BattleMap.exit_expedition()`、恢复 `Home.visible = true`、让角色退出历练跑步状态。
- 隐藏 `ExpeditionHud` 并刷新 HUD。
