# 详细物品表

本文档是独立物品表，依据 `scripts/game/data_tables.gd` 当前数据整理，不覆盖 `docs/items.md` 的系统说明。

## 类型索引

| 类型 ID | 中文分类 | 堆叠 | 可使用 | 说明 |
|---|---|---:|---:|---|
| `skill_book` | 技能书 | 是 | 是 | 使用后学习技能 |
| `equipment` | 装备 | 否 | 是 | 使用后穿戴到装备槽 |
| `material` | 材料 | 是 | 否 | 炼器、强化、洗练、掉落 |
| `crop` | 作物 | 是 | 否 | 种田种子、炼丹消耗 |
| `pill` | 丹药 | 是 | 是 | 恢复、持续 Buff、突破 |
| `alchemy_recipe` | 图纸 | 是 | 是 | 学习丹方 |

## 静态物品明细

### 技能书

| 物品 ID | 名称 | 类型 | 堆叠 | 可使用 | payload | 获取/用途 |
|---|---|---|---:|---:|---|---|
| `skill_book_spark` | 灵火术秘籍 | `skill_book` | 是 | 是 | `skill_id: spark` | 使用后学习灵火术 |
| `skill_book_water_needle` | 玄水针秘籍 | `skill_book` | 是 | 是 | `skill_id: water_needle` | 使用后学习玄水针 |
| `skill_book_stone_seal` | 裂土印秘籍 | `skill_book` | 是 | 是 | `skill_id: stone_seal` | 使用后学习裂土印 |

### 材料

| 物品 ID | 名称 | 类型 | 堆叠 | 可使用 | payload | 获取/用途 |
|---|---|---|---:|---:|---|---|
| `ore` | 矿石 | `material` | 是 | 否 | `{}` | 战斗掉落；炼器消耗材料 |
| `spirit_sand` | 灵砂 | `material` | 是 | 否 | `{}` | 战斗掉落；材料消耗 |
| `beast_core` | 妖核 | `material` | 是 | 否 | `{}` | 战斗掉落；材料消耗 |
| `refine_talisman` | 洗练符 | `material` | 是 | 否 | `refine: true` | 动态物品；装备加词条消耗 |

### 作物

| 物品 ID | 名称 | 类型 | 堆叠 | 可使用 | payload | 获取/用途 |
|---|---|---|---:|---:|---|---|
| `herb` | 草药 | `crop` | 是 | 否 | `seed_yield: 3` | 种田种子；炼丹消耗 |
| `rice` | 灵米 | `crop` | 是 | 否 | `seed_yield: 2` | 种田种子；炼丹消耗 |
| `mushroom` | 灵菇 | `crop` | 是 | 否 | `seed_yield: 1` | 种田种子；炼丹消耗 |

### 丹药

| 物品 ID | 名称 | 类型 | 堆叠 | 可使用 | payload | 效果 |
|---|---|---|---:|---:|---|---|
| `pill` | 调息丹 | `pill` | 是 | 是 | `effect_mode: instant, hp: 30, mp: 20` | 立即恢复生命和法力 |
| `life_pill` | 归元丹 | `pill` | 是 | 是 | `effect_mode: instant, hp: 55, mp: 0` | 立即恢复生命 |
| `spirit_pill` | 聚灵丹 | `pill` | 是 | 是 | `effect_mode: instant, hp: 0, mp: 42` | 立即恢复法力 |
| `might_pill` | 壮气丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 30, stat: attack, amount: 3` | 30 秒攻击 Buff |
| `breakthrough_pill` | 破境丹 | `pill` | 是 | 是 | `breakthrough: true` | 达到等级上限后突破下一阶段 |

### 炼丹图纸

| 物品 ID | 名称 | 类型 | 堆叠 | 可使用 | payload | 效果 |
|---|---|---|---:|---:|---|---|
| `recipe_pill` | 调息丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: pill` | 学习调息丹丹方 |
| `recipe_life_pill` | 归元丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: life_pill` | 学习归元丹丹方 |
| `recipe_spirit_pill` | 聚灵丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: spirit_pill` | 学习聚灵丹丹方 |
| `recipe_might_pill` | 壮气丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: might_pill` | 学习壮气丹丹方 |

## 动态物品明细

### 属性灵石

灵石由 `_item_def_data()` 按 ID 动态解析，格式如下：

```text
spirit_stone_<element>_<tier>
```

| 字段 | 可选值 |
|---|---|
| `element` | `wood`、`fire`、`earth`、`metal`、`water` |
| `tier` | `t1`、`t2`、`t3`、`t4`、`t5` |

| 阶位 | 显示名 | `enhance_amount` | 挂机定位 |
|---|---|---:|
| `t1` | 一阶 | 1 | 高频基础材料 |
| `t2` | 二阶 | 2 | 稳定积累材料 |
| `t3` | 三阶 | 4 | 数日成长目标 |
| `t4` | 四阶 | 7 | 低概率高价值材料 |
| `t5` | 五阶 | 11 | 周级稀有目标 |

| 五行 | 示例 ID | 说明 |
|---|---|---|
| 木 | `spirit_stone_wood_t1` ~ `spirit_stone_wood_t5` | 强化 `element_wood` |
| 火 | `spirit_stone_fire_t1` ~ `spirit_stone_fire_t5` | 强化 `element_fire` |
| 土 | `spirit_stone_earth_t1` ~ `spirit_stone_earth_t5` | 强化 `element_earth` |
| 金 | `spirit_stone_metal_t1` ~ `spirit_stone_metal_t5` | 强化 `element_metal` |
| 水 | `spirit_stone_water_t1` ~ `spirit_stone_water_t5` | 强化 `element_water` |

强化只消耗装备已有五行基础属性对应的灵石，消耗数量为 `enhance_count + 1`，自动优先使用 `t5 → t4 → t3 → t2 → t1`。

## 技能表

| 技能 ID | 名称 | 五行 | 冷却 | MP 消耗 | 伤害倍率 |
|---|---|---|---:|---:|---:|
| `spark` | 灵火术 | `fire` | 3.5 | 8 | 1.8 |
| `water_needle` | 玄水针 | `water` | 2.0 | 5 | 1.25 |
| `stone_seal` | 裂土印 | `earth` | 6.0 | 13 | 2.3 |

## 装备模板表

动态装备名称格式为 `<五行名>·<阶位名>·<槽位名>`，例如 `赤焰·三阶·武器`。每件装备生成时会保留自身五行基础属性，确保可用对应五行灵石长期强化。

| 五行 | 装备前缀 |
|---|---|
| `wood` | 青木 |
| `fire` | 赤焰 |
| `earth` | 厚土 |
| `metal` | 玄金 |
| `water` | 玄水 |

| 阶位 | 字段值 | 生成概率 | 属性倍率 | 挂机定位 |
|---|---|---:|---:|---|
| 一阶 | `t1` | 55% | 1.00 | 当日可得、过渡装备 |
| 二阶 | `t2` | 28% | 1.12 | 稳定替换 |
| 三阶 | `t3` | 12% | 1.28 | 数日目标 |
| 四阶 | `t4` | 4% | 1.50 | 长线稀有掉落 |
| 五阶 | `t5` | 1% | 1.80 | 周级毕业目标 |

| 模板 ID | 物品 ID | 槽位 | 基础名 | 攻击基础 | 攻击成长 | 防御基础 | 防御成长 | 说明 |
|---|---|---|---|---:|---:|---:|---:|---|
| `weapon` | `weapon` | `weapon` | Sword | 1 | 2 | 0 | 0 | 武器 |
| `helmet` | `helmet` | `helmet` | Helmet | 0 | 0 | 1 | 1 | 头盔 |
| `armor` | `armor` | `armor` | Armor | 0 | 0 | 1 | 2 | 护甲 |
| `leggings` | `leggings` | `leggings` | Leggings | 0 | 0 | 1 | 1 | 腿甲 |
| `gloves` | `gloves` | `gloves` | Gloves | 1 | 1 | 0 | 1 | 护手 |
| `accessory` | `accessory` | `accessory` | Charm | 1 | 1 | 1 | 1 | 饰品，可进入饰品 1/2 |

## 装备属性池

| stat | 显示名 | 最小 | 最大 | 等级成长 |
|---|---|---:|---:|---:|
| `max_hp` | HP | 8 | 16 | 2 |
| `max_mp` | MP | 4 | 10 | 1 |
| `attack` | ATK | 1 | 3 | 1 |
| `defense` | DEF | 1 | 3 | 1 |
| `root_bone` | Root | 1 | 2 | 0 |
| `element_wood` | Wood | 1 | 2 | 0 |
| `element_fire` | Fire | 1 | 2 | 0 |
| `element_earth` | Earth | 1 | 2 | 0 |
| `element_metal` | Metal | 1 | 2 | 0 |
| `element_water` | Water | 1 | 2 | 0 |

## 洗练词条池

| 词条 ID | stat | 最小 | 最大 |
|---|---|---:|---:|
| `attack` | `attack` | 1 | 3 |
| `defense` | `defense` | 1 | 3 |
| `max_hp` | `max_hp` | 5 | 15 |
| `max_mp` | `max_mp` | 3 | 10 |
| `root_bone` | `root_bone` | 1 | 2 |

## 敌人掉落表

| 敌人 ID | 敌人名 | 掉落物品 ID | 数量 | 概率 |
|---|---|---|---|---:|
| `wandering_imp` | Wandering Imp | `ore` | 1-3 | 1.00 |
| `wandering_imp` | Wandering Imp | `spirit_sand` | 1 | 0.45 |
| `wandering_imp` | Wandering Imp | `beast_core` | 1 | 0.18 |
| `wandering_imp` | Wandering Imp | `spirit_stone_earth_t1` | 1-2 | 0.70 |
| `wandering_imp` | Wandering Imp | `spirit_stone_earth_t2` | 1 | 0.22 |
| `wandering_imp` | Wandering Imp | `refine_talisman` | 1 | 0.12 |
| `wandering_imp` | Wandering Imp | `recipe_life_pill` | 1 | 0.08 |
| `stone_beast` | Stone Beast | `ore` | 2-4 | 1.00 |
| `stone_beast` | Stone Beast | `spirit_sand` | 1-2 | 0.35 |
| `stone_beast` | Stone Beast | `beast_core` | 1 | 0.12 |
| `stone_beast` | Stone Beast | `spirit_stone_earth_t1` | 1-3 | 0.70 |
| `stone_beast` | Stone Beast | `spirit_stone_earth_t2` | 1 | 0.22 |
| `stone_beast` | Stone Beast | `spirit_stone_metal_t3` | 1 | 0.06 |
| `stone_beast` | Stone Beast | `spirit_stone_metal_t4` | 1 | 0.015 |
| `stone_beast` | Stone Beast | `refine_talisman` | 1 | 0.16 |
| `stone_beast` | Stone Beast | `recipe_spirit_pill` | 1 | 0.08 |
| `flame_sprite` | Flame Sprite | `ore` | 1-2 | 0.85 |
| `flame_sprite` | Flame Sprite | `spirit_sand` | 1 | 0.60 |
| `flame_sprite` | Flame Sprite | `beast_core` | 1 | 0.20 |
| `flame_sprite` | Flame Sprite | `spirit_stone_fire_t1` | 1-2 | 0.70 |
| `flame_sprite` | Flame Sprite | `spirit_stone_fire_t2` | 1 | 0.22 |
| `flame_sprite` | Flame Sprite | `spirit_stone_fire_t3` | 1 | 0.06 |
| `flame_sprite` | Flame Sprite | `spirit_stone_fire_t4` | 1 | 0.015 |
| `flame_sprite` | Flame Sprite | `spirit_stone_fire_t5` | 1 | 0.005 |
| `flame_sprite` | Flame Sprite | `refine_talisman` | 1-2 | 0.20 |
| `flame_sprite` | Flame Sprite | `recipe_might_pill` | 1 | 0.08 |

## 操作入口速查

| 操作 | 入口 | 消耗 | 产出/效果 |
|---|---|---|---|
| 使用技能书 | 背包右键使用 | 1 本技能书 | 学习技能 |
| 穿戴装备 | 背包右键使用 | 无 | 装备到对应槽位 |
| 丢弃物品 | 背包右键丢弃 | 目标物品 | 数量 -1 或移除装备实例 |
| 种田 | 家园 `farmland` | 1 个作物种子 | 对应作物，产量受农田等级影响 |
| 炼器 | 家园 `forge` | 2 个材料 | 随机装备 |
| 炼丹 | 家园 `alchemy` | 2 个作物 | 已学丹方中的随机丹药 |
| 强化装备 | 背包装备右键强化 | 匹配五行灵石，数量 `enhance_count + 1` | 追加五行强化属性 |
| 加词条 | 背包装备右键加词条 | 洗练符，数量 `refine_count + 1` | 追加百分比词条 |
| 使用破境丹 | 背包右键使用 | 1 个破境丹 | 达等级上限时提升阶段和等级上限 |
