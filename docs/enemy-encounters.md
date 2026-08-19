# 普通、精英与混编敌人遭遇设计

## 状态与边界

地图驱动遭遇框架已经实现，包括地图独立 Profile、加权方案、类别池、固定编队、异种序列和地图专属兜底。当前已接入六种普通敌人、两种精英和一种 Boss；完整事实来源为[内容数据表](item-table.md)。本文列出的扩展池和未接入 Boss 仍属于规划。

普通、精英和 Boss 都是敌人类别，不是职业。核心敌人拥有唯一 `combat_affinity`；技能使用的 `element` 和 `element_power` 是独立数值，不新增职业、学习限制或装备限制。Boss 的详细数据与奖励见[Boss 遭遇](boss-encounters.md)。

## 当前敌人池

| enemy_id | 名称 | 类别 | 形象 |
| --- | --- | --- | --- |
| `forest_wolf` | 林狼 | normal | wolf |
| `venom_spider` | 毒纹蛛 | normal | spider |
| `blight_shaman` | 腐木巫祝 | elite | shaman |
| `ember_gnome` | 灰烬地精 | normal | gnome |
| `stone_lizard` | 岩甲蜥 | normal | lizard |
| `stone_overlord` | 镇岳兽王 | elite | minotaur |
| `iron_lancer` | 玄锋枪卒 | normal | lancer |
| `tide_fish` | 潮鳍鱼妖 | normal | paddle_fish |
| `abyssal_turtle` | 沉渊玄龟 | boss | turtle |

这些敌人启用类别掉落池并关闭旧阶级材料池。六种普通敌人、两种精英和沉渊玄龟分别使用各自类别规则；训练木桩保持无掉落。普通、精英、Boss 的独立装备率为 5%、12%、25%。

普通和精英实例生成时从普通、木、火、土、金、水中等概率抽取唯一标签，并从生命、攻击、防御和五项五行数值中抽取一主两副成长属性。普通敌人每级属性点倍率为 `0.8`，精英为 `1.2`。训练木桩固定普通且倍率为 0；核心 Boss 的标签、主副属性和倍率由模板手工配置。

## 已实现：地图驱动生成

每个 `BattleMap` 通过 `encounter_profile` 引用独立的 `MapEncounterProfile`。地图收到刷新时，按以下顺序生成最终 ID 序列：

```text
variant = weighted_pick(profile.variants)
if variant.fixed_enemy_ids is not empty:
    return valid_ids_in_original_order
enemy_count = clamp(active_party_size * enemies_per_party_member, min_enemy_count, max_enemy_count)
for each position:
    class_pool = weighted_pick(variant.class_pools)
    enemy_id = pick_with_replacement(class_pool.valid_enemy_ids)
```

- Variant 和类别池权重只要求大于 0，不要求合计为 100。
- 固定编队不再应用队伍人数和数量规则，允许混合任意类别。
- 随机池内等概率、有放回抽取；未声明 `encounter_class` 的敌人按 `normal` 处理。
- 无效 ID 与类别不匹配项会被过滤并报警。所有 Variant 都不可用时使用当前地图的 `fallback_enemy_id`，不使用全局默认敌人。
- 当前正式地图每名队员生成 2 只、限制 1-8，并按各地图 Profile 使用已配置的普通、精英或 Boss 池；训练木桩不进入正式随机池。

## 规划：默认普通、精英与 Boss 池

未来默认历练地图计划使用以下类别权重和内容规模；这些数值尚未写入当前 Profile：

| 类别 | 每位置权重 | 池规模 | 抽取规则 |
| --- | ---: | ---: | --- |
| 普通 | 85% | 10 | 全等级等概率、有放回 |
| 精英 | 14% | 5 | 全等级等概率、有放回 |
| Boss | 1% | 5 | 全等级等概率、有放回 |

- 三个敌人池从历练 1 级起全部开放，不按等级移除或累积解锁敌人。
- 同一敌群允许同种重复、普通与精英混编、Boss 与其他敌人混编，以及低概率出现多个 Boss。
- 敌人按生成顺序逐个进入战斗。每只敌人阵亡时立即结算自身经验、材料和装备；队伍之后全灭不会回滚已获得奖励。
- 类别抽取不设置保底、连续未出现补偿或单场数量上限。四人队的 8 敌人遭遇中，至少出现一个 Boss 的概率为 `1 - 0.99^8 = 7.7255%`，约 7.73%。
- 某个池为空或敌人定义无效时会被过滤；整份地图配置不可用时使用该地图的专属兜底。场景加载失败仍由战斗控制器报警并终止该场遭遇。

## 规划：数据与形象池

敌人模板新增兼容字段 `encounter_class`，枚举为 `normal`、`elite`、`boss`，未填写时固定按 `normal` 处理。该默认值保证已有本体敌人和未更新 Mod 继续进入普通池。

普通和精英分别维护独立形象池。每个 `enemy_id` 在数据落地时固定绑定一个 `visual_id`，不能在每次生成时独立随机外观；绑定的形象必须存在于相同 `encounter_class` 的形象池。Boss 使用自身独立形象，不进入普通或精英形象池。

以下 14 个形象已经可用，但本次仅作为候选资源，不决定池归属或敌人绑定：

`bear`、`gnome`、`lancer`、`lizard`、`minotaur`、`paddle_fish`、`panda`、`shaman`、`skull`、`snake`、`spider`、`thief`、`troll`、`turtle`。

正式实现前必须先提供普通与精英形象池名单，再为本文 15 个普通/精英 `enemy_id` 补齐固定 `visual_id`。不得使用临时占位 ID 写入运行时数据。

## 规划：通用数值与技能

同等级林狼完成阶级和阶内等级成长后的最终属性记为 `W`。本文属性倍率均在 `W.max_hp`、`W.attack`、`W.defense` 上相乘后向下取整；生命和攻击最低为 1，防御最低为 0。

- 五行克制固定为金克木、木克土、土克水、水克火、火克金；普通属性不参与克制。
- 普通攻击使用敌人的唯一标签，技能和 DOT 使用自身 `element`，不再随机附加模板元素。
- 所有敌人技能法力消耗为 0。普通敌人三个技能依次在 t2、t3、t4 解锁；精英四个技能依次在 t1、t2、t3、t4 解锁；t5 不新增技能。
- 短冷却单体攻击优先级 50，群攻和减益优先级 70，无条件自身强化优先级 80，生命条件、终结技和保命技能优先级 90。相同优先级按模板技能列表顺序选择。
- 技能完整 ID 使用 `<enemy_id>_<技能后缀>`。持续数值写作“每回合数值 x 持续回合”，持续回合归属沿用现有目标回合/自身回合规则。

## 规划：普通敌人

普通敌人经验统一为 `10 + enemy_level * 2`，材料使用当前阶级掉落池和阶内掉率，装备掉率固定为 5%。

| 五行 | enemy_id / 名称 | HP/攻/防倍率 | 依次解锁的三个技能 |
| --- | --- | --- | --- |
| 金 | `iron_lancer` 玄锋枪卒 | 1.00 / 1.10 / 1.05 | `pierce`：单体1.20、破防2、CD2；`armor_break`：单体1.00、防御-2两回合、CD4；`sweep`：全体0.95、破防2、CD5 |
| 金 | `shadow_thief` 影刃盗徒 | 0.85 / 1.20 / 0.80 | `ambush`：单体1.30、CD3；`expose`：单体1.05、防御-3两回合、CD4；`execution`：目标生命不高于35%时单体1.70、CD5 |
| 木 | `briar_bear` 荆背熊 | 1.30 / 0.95 / 1.00 | `maul`：单体1.20、CD2；`regrowth`：自身HOT 3 x 3、生命不高于50%、CD6；`roar`：全体0.80、攻击-2两回合、CD5 |
| 木 | `venom_spider` 毒纹蛛 | 0.90 / 1.00 / 0.85 | `venom_bite`：单体0.95、DOT 2 x 3、CD3；`poison_web`：全体0.65、DOT 2 x 2、CD5；`drain`：单体1.10、吸血25%、CD4 |
| 土 | `stone_lizard` 岩甲蜥 | 1.15 / 0.90 / 1.25 | `stone_strike`：单体1.05、自身护盾5、CD3；`harden`：防御+3三回合、生命不高于60%、CD6；`earth_shock`：全体0.75、攻击-2两回合、CD5 |
| 土 | `horned_brute` 角岩蛮兽 | 1.25 / 1.10 / 0.95 | `charge`：单体1.25、CD3；`quake`：全体0.85、CD5；`guard`：护盾12且防御+2三回合、生命不高于60%、CD7 |
| 水 | `tide_fish` 潮鳍鱼妖 | 1.00 / 0.95 / 0.90 | `splash`：单体1.05、攻击-1两回合、CD3；`surge`：全体0.75、攻击-2两回合、CD5；`flow`：护盾6且HOT 2 x 2、生命不高于60%、CD6 |
| 水 | `frost_snake` 寒潭蛇 | 0.95 / 1.05 / 0.85 | `cold_bite`：单体1.10、攻击-2两回合、CD3；`shed`：自身HOT 3 x 2、生命不高于50%、CD5；`binding_mist`：全体0.70、防御-2三回合、CD6 |
| 火 | `ember_gnome` 灰烬地精 | 0.85 / 1.15 / 0.80 | `ember`：单体1.25、CD3；`firepot`：全体0.80、DOT 3 x 2、CD5；`fan_flame`：攻击+3三回合、CD6 |
| 火 | `flame_raider` 赤焰劫徒 | 1.00 / 1.20 / 0.90 | `flame_slash`：单体1.30、CD3；`burn_mark`：单体1.00、DOT 4 x 2、CD4；`final_burn`：目标生命不高于35%时单体1.75、CD6 |

`regrowth`、`harden`、`guard`、`flow` 和 `shed` 使用优先级 90；`execution` 和 `final_burn` 使用优先级 90；`fan_flame` 使用优先级 80；其余技能按通用单体/群攻规则取 50 或 70。

## 规划：精英敌人

精英统一使用 `W.max_hp * 2.5`、`W.attack * 1.20`、`W.defense * 1.15`。经验为 `floor((10 + enemy_level * 2) * 2.5)`；材料掉率为同阶普通敌人最终掉率增加 15 个百分点并限制在 100% 内；装备掉率固定为 12%。

| 五行 | enemy_id / 名称 | 依次解锁的四个技能 |
| --- | --- | --- |
| 金 | `edge_commander` 断锋统领 | `pierce_array`：单体1.35、破防4、CD2；`break_formation`：全体1.00、破防3、CD4；`hidden_edge`：攻击+4三回合、CD6；`execution`：目标生命不高于35%时单体1.90、CD5 |
| 木 | `blight_shaman` 腐木巫祝 | `miasma`：全体0.75、DOT 3 x 3、CD4；`drain_life`：单体1.15、吸血30%、CD3；`regrowth`：自身HOT 6 x 3、生命不高于50%、CD6；`overgrowth`：全体0.95、攻击-3两回合、CD5 |
| 土 | `stonehide_overlord` 镇岳兽王 | `rockfall`：单体1.20、自身护盾8、CD3；`earthquake`：全体0.90、攻击-3两回合、CD5；`ironhide`：护盾20且防御+4三回合、生命不高于60%、CD7；`crushing_horn`：目标生命不高于35%时单体1.65、破防4、CD6 |
| 水 | `black_tide_guardian` 玄潮甲将 | `black_tide`：全体0.85、攻击-3两回合、CD4；`water_mirror`：护盾16且HOT 4 x 3、生命不高于60%、CD6；`binding_current`：全体0.75、防御-3三回合、CD5；`overflow`：全体1.20、CD7 |
| 火 | `cinder_warlord` 烬火战酋 | `cinder_strike`：单体1.40、CD2；`burning_ground`：全体0.90、DOT 4 x 2、CD4；`bloodflame`：攻击+5三回合、CD6；`inferno`：全体1.45、CD7 |

`execution`、`regrowth`、`ironhide`、`crushing_horn` 和 `water_mirror` 使用优先级 90；`hidden_edge` 与 `bloodflame` 使用优先级 80；所有全体伤害或减益技能使用优先级 70；其余短冷却单体技能使用优先级 50。

## 规划：奖励与失败

| 类别 | 经验 | 材料 | 装备掉率 |
| --- | --- | --- | ---: |
| 普通 | `10 + level * 2` | 阶级池最终掉率 | 5% |
| 精英 | 普通基准 x2.5，向下取整 | 普通最终掉率 +15个百分点，最高100% | 12% |
| Boss | 同等级林狼 x6 | Boss 独立掉落表 | 25% |

奖励按敌人逐只结算，不等待整组全部击败。主动返回会清空尚未击败的敌人，不补发奖励；队伍全灭沿用现有半血半蓝返回家园规则，不扣回已结算物品、装备或经验。

## 实现边界

正式落地前必须补齐：

- 可配置的类别权重、普通/精英/Boss 敌人池，以及池内容与 `encounter_class` 一致性校验。
- `CombatController` 从单一 `enemy_id` 重复生成改为接收异种敌人 ID 序列，并逐只加载各自场景。
- `encounter_class`、精英属性/奖励倍率、技能解锁偏移和形象池约束的运行时数据与 Mod Schema。
- 10 个普通、5 个精英的敌人定义、技能定义、场景、固定形象绑定、掉落和自动化测试。
- Boss 全等级池、逐位置抽取和按阶技能解锁；详细边界见[Boss 遭遇](boss-encounters.md)。

不规划召唤、眩晕、冻结、跳过回合、强制嘲讽、锁血或复杂阶段脚本。所有技能只使用现有直伤、DOT、HOT、护盾、吸血、属性增减和破防能力。

## 文档验收

- 普通、精英、Boss 敌人池分别拥有 10、5、5 个唯一 ID；普通每行 2 种，精英和 Boss 每行 1 种。
- 每位置类别权重总和为 100%，全池全等级开放，抽取有放回，允许异种混编与多个 Boss。
- 普通敌人均有三个按阶技能，精英均有四个按阶技能；所有技能均有稳定 ID、倍率或效果、冷却、优先级和触发条件。
- 形象池保持普通/精英分离，现有 14 个候选形象不在缺少用户配置时擅自分池。
- 本文、[Boss 遭遇](boss-encounters.md)与[历练与战斗](battle-expedition.md)不再沿用旧版整场替换、Boss 等级分池或固定单体规则。
