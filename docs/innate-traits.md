# 先天命格设计

## 定位

命格是角色出生时确定的长期特质，不允许普通洗练、替换、升级或觉醒。装备负责可替换的属性追求；命格只提供容易理解的固定属性、增伤、减伤和技能冷却回合修正。

成员数据使用 `innate_traits` 数组。每条命格保存 `id`、`slot`、`rarity` 和兼容字段 `awakened`；`awakened` 不参与显示或结算，旧存档中的 `true` 也不会改变效果。

## 槽位与品质

- 1 个主命格：从 `MAIN_TRAIT_IDS` 的 15 条中抽取。
- 招募建筑 4 级起追加 1 个副命格，所有品质均可获得。
- 招募建筑 7 级起，异禀候选有 35% 概率追加 1 个缺陷命格；缺陷不占主、副槽位。

候选品质固定为普通 70%、优秀 25%、异禀 5%。候选人的所有命格共享同一品质，品质在生成后不会变化。命格定义使用 `effects_by_rarity` 保存 `common`、`rare`、`exceptional` 三档效果。

## 主命格

基础属性主命格：

| id | 名称 | 普通 | 优秀 | 异禀 |
| --- | --- | ---: | ---: | ---: |
| `robust_body` | 健体 | 气血 +20 | 气血 +24 | 气血 +28 |
| `sharp_edge` | 锋芒 | 攻击 +2 | 攻击 +3 | 攻击 +4 |
| `steady_guard` | 稳守 | 防御 +2 | 防御 +3 | 防御 +4 |
| `full_vigor` | 充沛 | 法力 +12 | 法力 +15 | 法力 +18 |
| `good_root` | 良根 | 根骨 +2 | 根骨 +3 | 根骨 +4 |

战斗主命格：

| id | 名称 | 普通 | 优秀 | 异禀 |
| --- | --- | ---: | ---: | ---: |
| `wood_virtue` | 木德长生 | 直接伤害 +5% | +7% | +10% |
| `venom_body` | 万毒灵胎 | 受元素伤害 -5% | -7% | -10% |
| `fire_aspect` | 离火真脉 | 直接伤害 +5% | +7% | +10% |
| `blazing_soul` | 赤阳命火 | 克制伤害 +5% | +7% | +10% |
| `earth_body` | 厚土道体 | 受物理伤害 -5% | -7% | -10% |
| `mountain_bone` | 镇岳灵骨 | 受元素伤害 -5% | -7% | -10% |
| `sword_bone` | 天生剑骨 | 普攻伤害 +5% | +7% | +10% |
| `metal_edge` | 庚金锋魄 | 直接伤害 +5% | +7% | +10% |
| `full_spirit_root` | 太阴灵脉 | CD -1 回合、直接伤害 -6% | CD -1 回合 | CD -2 回合 |
| `water_mind` | 水镜道心 | 受元素伤害 -5% | -7% | -10% |

## 副命格

| id | 名称 | 普通 | 优秀 | 异禀 |
| --- | --- | ---: | ---: | ---: |
| `earth_scout` | 地听寻珍 | 直接伤害 +2% | +3% | +4% |
| `clear_mind` | 澄心善学 | 受物理伤害 -2% | -3% | -4% |

## 缺陷命格

正常生成时缺陷只会是异禀档。普通和优秀档保留给旧存档或 Mod 内容使用。

| id | 名称 | 普通 | 优秀 | 异禀 |
| --- | --- | --- | --- | --- |
| `withered_meridian` | 枯荣逆脉 | 伤害 +8%、受物伤 +4% | +10%、+5% | +12%、+6% |
| `burning_heart` | 烈性攻心 | 普攻 +8%、受元素伤 +4% | +10%、+5% | +12%、+6% |
| `heavy_body` | 重浊之身 | CD -1、伤害 -4% | CD -1、伤害 -5% | CD -2、伤害 -6% |
| `lone_edge` | 孤锋煞命 | 克制伤害 +8%、受元素伤 +4% | +10%、+5% | +12%、+6% |
| `cold_obsession` | 寒魄偏执 | CD -1、普攻 -6% | CD -1、普攻 -8% | CD -2、普攻 -10% |

## 效果字段

内置命格只使用以下字段：

| kind | 用途 |
| --- | --- |
| `stat_flat` | 人物属性固定加成 |
| `element_flat` | 五行属性固定加成 |
| `stat_percent` | 人物属性百分比修正，保留兼容 |
| `element_percent` | 五行属性百分比修正，保留兼容 |
| `direct_damage_percent` | 直接伤害修正 |
| `normal_attack_percent` | 普通攻击伤害修正 |
| `weakness_damage_percent` | 五行克制时的伤害修正 |
| `physical_damage_taken_percent` | 受到的物理伤害修正，负值为减伤 |
| `element_damage_taken_percent` | 受到的元素伤害修正，负值为减伤 |
| `skill_cooldown_turns` | 技能冷却固定回合修正 |

命格 CD 在技能自身冷却倍率结算后加减：

```text
final_cooldown = max(0, ceil(base_cooldown * skill_multiplier) + skill_cooldown_turns)
```

内置命格不再使用成长权重、掉落、熟练度、吸血、毒伤或无视防御。`effects` 和旧 `skill_cooldown_percent` 仍作为 Mod/旧内容兼容入口，但新内容应使用 `effects_by_rarity` 和 `skill_cooldown_turns`。

## 数据结构

```gdscript
"innate_traits": [
    {
        "id": "sword_bone",
        "name": "天生剑骨",
        "slot": "main",
        "rarity": "rare",
        "level": 1,
        "awakened": false
    }
]
```

定义示例：

```gdscript
"sword_bone": {
    "name": "天生剑骨",
    "description": "普通攻击伤害提高 5% / 7% / 10%。",
    "effects_by_rarity": {
        "common": [{"kind": "normal_attack_percent", "amount": 0.05}],
        "rare": [{"kind": "normal_attack_percent", "amount": 0.07}],
        "exceptional": [{"kind": "normal_attack_percent", "amount": 0.10}]
    }
}
```

## UI 与扩展边界

成员面板和招募候选列表显示命格名称、槽位、品质以及当前品质的实际效果，不显示觉醒状态。缺陷命格使用独立样式。

新增命格时同步更新 `DataTables.INNATE_TRAIT_DEFS`、本文档和命格测试。命格不承担复杂战斗触发器、生产收益或成长分配；这类能力应由技能、装备或独立系统实现。
