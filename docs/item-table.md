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

| 物品 ID | 名称 | 类型 | 堆叠 | 成熟时间 | payload | 获取/用途 |
|---|---|---|---:|---:|---|---|
| `herb` | 草药 | `crop` | 是 | 60s | `seed_yield: 3, growth_seconds: 60` | 通用种子；基础炼丹消耗 |
| `rice` | 灵米 | `crop` | 是 | 90s | `seed_yield: 2, growth_seconds: 90` | 通用种子；基础炼丹消耗 |
| `mushroom` | 灵菇 | `crop` | 是 | 120s | `seed_yield: 1, growth_seconds: 120` | 通用种子；基础炼丹消耗 |
| `blade_grass` | 刃纹草 | `crop` | 是 | 180s | `seed_yield: 1, growth_seconds: 180, stat: attack` | 攻击丹药主材料 |
| `ironroot` | 铁根藤 | `crop` | 是 | 180s | `seed_yield: 1, growth_seconds: 180, stat: defense` | 防御丹药主材料 |
| `blood_ginseng` | 血参 | `crop` | 是 | 240s | `seed_yield: 1, growth_seconds: 240, stat: max_hp` | 生命丹药主材料 |
| `spirit_lotus` | 灵泉莲 | `crop` | 是 | 240s | `seed_yield: 1, growth_seconds: 240, stat: max_mp` | 灵力丹药主材料 |
| `bone_bamboo` | 玉骨竹 | `crop` | 是 | 360s | `seed_yield: 1, growth_seconds: 360, stat: root_bone` | 根骨丹药主材料 |
| `woodvine` | 青木藤 | `crop` | 是 | 180s | `seed_yield: 1, growth_seconds: 180, element: wood` | 木行丹药主材料 |
| `flame_flower` | 赤焰花 | `crop` | 是 | 210s | `seed_yield: 1, growth_seconds: 210, element: fire` | 火行丹药主材料 |
| `earth_moss` | 厚土苔 | `crop` | 是 | 210s | `seed_yield: 1, growth_seconds: 210, element: earth` | 土行丹药主材料 |
| `metal_reed` | 玄金苇 | `crop` | 是 | 300s | `seed_yield: 1, growth_seconds: 300, element: metal` | 金行丹药主材料 |
| `water_orchid` | 玄水兰 | `crop` | 是 | 240s | `seed_yield: 1, growth_seconds: 240, element: water` | 水行丹药主材料 |

### 丹药

| 物品 ID | 名称 | 类型 | 堆叠 | 可使用 | payload | 效果 |
|---|---|---|---:|---:|---|---|
| `pill` | 调息丹 | `pill` | 是 | 是 | `effect_mode: instant, hp: 30, mp: 20` | 立即恢复生命和法力 |
| `life_pill` | 归元丹 | `pill` | 是 | 是 | `effect_mode: instant, hp: 55, mp: 0` | 立即恢复生命 |
| `spirit_pill` | 聚灵丹 | `pill` | 是 | 是 | `effect_mode: instant, hp: 0, mp: 42` | 立即恢复法力 |
| `might_pill` | 壮气丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 30, stat: attack, amount: 3` | 30 秒攻击 Buff |
| `breakthrough_pill` | 破境丹 | `pill` | 是 | 是 | `breakthrough: true` | 达到等级上限后突破下一阶段 |
| `attack_pill` | 破军丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: attack, amount: 5` | 300 秒攻击 +5 |
| `defense_pill` | 玄甲丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: defense, amount: 5` | 300 秒防御 +5 |
| `life_boost_pill` | 血元丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: max_hp, amount: 30` | 300 秒最大生命 +30 |
| `mana_boost_pill` | 灵泉丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: max_mp, amount: 20` | 300 秒最大灵力 +20 |
| `root_bone_pill` | 锻骨丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: root_bone, amount: 2` | 300 秒根骨 +2 |
| `wood_pill` | 青木丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: element_wood, amount: 5` | 300 秒木行 +5 |
| `fire_pill` | 赤焰丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: element_fire, amount: 5` | 300 秒火行 +5 |
| `earth_pill` | 厚土丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: element_earth, amount: 5` | 300 秒土行 +5 |
| `metal_pill` | 玄金丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: element_metal, amount: 5` | 300 秒金行 +5 |
| `water_pill` | 玄水丹 | `pill` | 是 | 是 | `effect_mode: duration, duration: 300, stat: element_water, amount: 5` | 300 秒水行 +5 |

### 炼丹图纸

| 物品 ID | 名称 | 类型 | 堆叠 | 可使用 | payload | 效果 |
|---|---|---|---:|---:|---|---|
| `recipe_pill` | 调息丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: pill` | 学习调息丹丹方 |
| `recipe_life_pill` | 归元丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: life_pill` | 学习归元丹丹方 |
| `recipe_spirit_pill` | 聚灵丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: spirit_pill` | 学习聚灵丹丹方 |
| `recipe_might_pill` | 壮气丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: might_pill` | 学习壮气丹丹方 |
| `recipe_attack_pill` | 破军丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: attack_pill` | 学习破军丹丹方；对应刃纹草 |
| `recipe_defense_pill` | 玄甲丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: defense_pill` | 学习玄甲丹丹方；对应铁根藤 |
| `recipe_life_boost_pill` | 血元丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: life_boost_pill` | 学习血元丹丹方；对应血参 |
| `recipe_mana_boost_pill` | 灵泉丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: mana_boost_pill` | 学习灵泉丹丹方；对应灵泉莲 |
| `recipe_root_bone_pill` | 锻骨丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: root_bone_pill` | 学习锻骨丹丹方；对应玉骨竹 |
| `recipe_wood_pill` | 青木丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: wood_pill` | 学习青木丹丹方；对应青木藤 |
| `recipe_fire_pill` | 赤焰丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: fire_pill` | 学习赤焰丹丹方；对应赤焰花 |
| `recipe_earth_pill` | 厚土丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: earth_pill` | 学习厚土丹丹方；对应厚土苔 |
| `recipe_metal_pill` | 玄金丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: metal_pill` | 学习玄金丹丹方；对应玄金苇 |
| `recipe_water_pill` | 玄水丹方 | `alchemy_recipe` | 是 | 是 | `recipe_id: water_pill` | 学习玄水丹丹方；对应玄水兰 |

### 属性丹药配方材料

| 丹药 ID | 主材料 | 辅材料 | 催化材料 |
|---|---|---|---|
| `attack_pill` | 刃纹草 ×2 | 灵米 ×1 | `stat_stone_attack_t1` ×1 |
| `defense_pill` | 铁根藤 ×2 | 灵米 ×1 | `stat_stone_defense_t1` ×1 |
| `life_boost_pill` | 血参 ×2 | 草药 ×1 | `stat_stone_max_hp_t1` ×1 |
| `mana_boost_pill` | 灵泉莲 ×2 | 灵菇 ×1 | `stat_stone_max_mp_t1` ×1 |
| `root_bone_pill` | 玉骨竹 ×2 | 妖核 ×1 | `stat_stone_root_bone_t1` ×1 |
| `wood_pill` | 青木藤 ×2 | 草药 ×1 | `spirit_stone_wood_t1` ×1 |
| `fire_pill` | 赤焰花 ×2 | 灵砂 ×1 | `spirit_stone_fire_t1` ×1 |
| `earth_pill` | 厚土苔 ×2 | 灵米 ×1 | `spirit_stone_earth_t1` ×1 |
| `metal_pill` | 玄金苇 ×2 | 矿石 ×1 | `spirit_stone_metal_t1` ×1 |
| `water_pill` | 玄水兰 ×2 | 灵菇 ×1 | `spirit_stone_water_t1` ×1 |

## 动态物品明细

### 属性灵石

灵石由 `_item_def_data()` 按 ID 动态解析，分为五行灵石和普通属性灵石。

五行灵石格式如下：

```text
spirit_stone_<element>_<tier>
```

普通属性灵石格式如下：

```text
stat_stone_<stat>_<tier>
```

| 字段 | 可选值 |
|---|---|
| `element` | `wood`、`fire`、`earth`、`metal`、`water` |
| `stat` | `attack`、`defense`、`max_hp`、`max_mp`、`root_bone` |
| `tier` | `t1`、`t2`、`t3`、`t4`、`t5` |

| 阶位 | 显示名 | `enhance_amount` | 挂机定位 |
|---|---|---:|---|
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

| 普通属性 | 示例 ID | 说明 |
|---|---|---|
| 攻击 | `stat_stone_attack_t1` ~ `stat_stone_attack_t5` | 强化 `attack` |
| 防御 | `stat_stone_defense_t1` ~ `stat_stone_defense_t5` | 强化 `defense` |
| 生命 | `stat_stone_max_hp_t1` ~ `stat_stone_max_hp_t5` | 强化 `max_hp` |
| 灵力 | `stat_stone_max_mp_t1` ~ `stat_stone_max_mp_t5` | 强化 `max_mp` |
| 根骨 | `stat_stone_root_bone_t1` ~ `stat_stone_root_bone_t5` | 强化 `root_bone` |

强化只消耗装备已有基础属性对应的灵石：五行属性使用五行灵石，普通属性使用普通属性灵石。消耗数量为 `enhance_count + 1`，自动优先使用 `t5 → t4 → t3 → t2 → t1`。

## 技能表

| 技能 ID | 名称 | 五行 | 冷却 | MP 消耗 | 伤害倍率 |
|---|---|---|---:|---:|---:|
| `spark` | 灵火术 | `fire` | 3.5 | 8 | 1.8 |
| `water_needle` | 玄水针 | `water` | 2.0 | 5 | 1.25 |
| `stone_seal` | 裂土印 | `earth` | 6.0 | 13 | 2.3 |

## 装备模板表

动态装备名称格式为 `<五行名>·<阶位名>·<槽位名>`，例如 `赤焰·三阶·武器`；无属性装备名称格式为 `无相·<阶位名>·<槽位名>`，例如 `无相·三阶·武器`。五行装备会保留自身五行基础属性；无属性装备会保留槽位核心普通属性。

| 五行 | 装备前缀 |
|---|---|
| `wood` | 青木 |
| `fire` | 赤焰 |
| `earth` | 厚土 |
| `metal` | 玄金 |
| `water` | 玄水 |
| `neutral` | 无相 |

| 阶位 | 字段值 | 生成概率 | 属性条数 | 挂机定位 |
|---|---|---:|---:|---|
| 一阶 | `t1` | 55% | 1 | 当日可得、过渡装备 |
| 二阶 | `t2` | 28% | 2 | 稳定替换 |
| 三阶 | `t3` | 12% | 3 | 数日目标 |
| 四阶 | `t4` | 4% | 4 | 长线稀有掉落 |
| 五阶 | `t5` | 1% | 5 | 周级毕业目标 |

| 无属性武器阶位 | 攻击倍率 | 定位 |
|---|---:|---|
| `t1` | 1.15 | 比同阶五行武器更高直接攻击 |
| `t2` | 1.30 | 通用挂机输出 |
| `t3` | 1.50 | 中期物理主力 |
| `t4` | 1.75 | 长线物理追求 |
| `t5` | 2.10 | 周级物理毕业目标 |

| 模板 ID | 物品 ID | 槽位 | 基础名 | 攻击基础 | 攻击成长 | 防御基础 | 防御成长 | 说明 |
|---|---|---|---|---:|---:|---:|---:|---|
| `weapon` | `weapon` | `weapon` | Sword | 1 | 2 | 0 | 0 | 武器 |
| `helmet` | `helmet` | `helmet` | Helmet | 0 | 0 | 1 | 1 | 头盔 |
| `armor` | `armor` | `armor` | Armor | 0 | 0 | 1 | 2 | 护甲 |
| `leggings` | `leggings` | `leggings` | Leggings | 0 | 0 | 1 | 1 | 腿甲 |
| `gloves` | `gloves` | `gloves` | Gloves | 1 | 1 | 0 | 1 | 护手 |
| `accessory` | `accessory` | `accessory` | Charm | 1 | 1 | 1 | 1 | 饰品，可进入饰品 1/2 |

## 装备属性池

装备生成顺序为阶级 → 等级 → 属性。阶级决定属性条数和倍率，等级决定额外属性点；强制属性占用条数，不额外增加条数。属性值公式：`round((random(tier_min, tier_max) + int(equipment_level * stat_level_scale) + craft_bonus) * rarity_multiplier)`，最低为 1。

| 属性组 | 包含 stat | `t1` | `t2` | `t3` | `t4` | `t5` | 等级成长 |
|---|---|---:|---:|---:|---:|---:|---:|
| 普通数值 | `attack`、`defense`、`root_bone`、`element_*` | 1-2 | 2-4 | 4-7 | 7-11 | 11-16 | 攻防 0.8；根骨/五行 0.4 |
| 灵力 | `max_mp` | 4-8 | 8-14 | 14-22 | 22-34 | 34-50 | 1.2 |
| 生命 | `max_hp` | 8-16 | 16-28 | 28-44 | 44-68 | 68-100 | 2.4 |

## 洗练词条池

| 词条 ID | stat | 最小 | 最大 |
|---|---|---:|---:|
| `attack` | `attack` | 1 | 3 |
| `defense` | `defense` | 1 | 3 |
| `max_hp` | `max_hp` | 5 | 15 |
| `max_mp` | `max_mp` | 3 | 10 |
| `root_bone` | `root_bone` | 1 | 2 |

## 敌人掉落表

战斗胜利先逐项结算下表普通掉落：每项独立判断 `rng.randf() <= chance`，数量为 `randi_range(min, max)`。普通掉落结算后，再独立以 35% 概率掉落 1 件装备：`equipment_level = enemy.level`，槽位随机，五行从木火土金水随机，阶位按装备阶位概率表随机，属性使用装备属性公式。掉落装备获得不做属性门槛；穿戴时需求为 `max(1, equipment_level * rarity_tier)`。

| 敌人 ID | 敌人名 | 掉落物品 ID | 数量 | 概率 |
|---|---|---|---|---:|
| `wandering_imp` | Wandering Imp | `ore` | 1-3 | 1.00 |
| `wandering_imp` | Wandering Imp | `spirit_sand` | 1 | 0.45 |
| `wandering_imp` | Wandering Imp | `beast_core` | 1 | 0.18 |
| `wandering_imp` | Wandering Imp | `stat_stone_attack_t1` | 1-2 | 0.55 |
| `wandering_imp` | Wandering Imp | `stat_stone_defense_t1` | 1-2 | 0.45 |
| `wandering_imp` | Wandering Imp | `spirit_stone_earth_t1` | 1-2 | 0.70 |
| `wandering_imp` | Wandering Imp | `spirit_stone_earth_t2` | 1 | 0.22 |
| `wandering_imp` | Wandering Imp | `refine_talisman` | 1 | 0.12 |
| `wandering_imp` | Wandering Imp | `recipe_life_pill` | 1 | 0.08 |
| `stone_beast` | Stone Beast | `ore` | 2-4 | 1.00 |
| `stone_beast` | Stone Beast | `spirit_sand` | 1-2 | 0.35 |
| `stone_beast` | Stone Beast | `beast_core` | 1 | 0.12 |
| `stone_beast` | Stone Beast | `stat_stone_defense_t1` | 1-3 | 0.55 |
| `stone_beast` | Stone Beast | `stat_stone_max_hp_t1` | 1-2 | 0.35 |
| `stone_beast` | Stone Beast | `spirit_stone_earth_t1` | 1-3 | 0.70 |
| `stone_beast` | Stone Beast | `spirit_stone_earth_t2` | 1 | 0.22 |
| `stone_beast` | Stone Beast | `spirit_stone_metal_t3` | 1 | 0.06 |
| `stone_beast` | Stone Beast | `spirit_stone_metal_t4` | 1 | 0.015 |
| `stone_beast` | Stone Beast | `refine_talisman` | 1 | 0.16 |
| `stone_beast` | Stone Beast | `recipe_spirit_pill` | 1 | 0.08 |
| `flame_sprite` | Flame Sprite | `ore` | 1-2 | 0.85 |
| `flame_sprite` | Flame Sprite | `spirit_sand` | 1 | 0.60 |
| `flame_sprite` | Flame Sprite | `beast_core` | 1 | 0.20 |
| `flame_sprite` | Flame Sprite | `stat_stone_attack_t1` | 1-2 | 0.60 |
| `flame_sprite` | Flame Sprite | `stat_stone_max_mp_t1` | 1 | 0.30 |
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
| 炼器 | 家园 `forge` | 2 个 `ore` | 随机装备，`equipment_level = 玩家等级`，使用 `craft_bonus` |
| 炼丹 | 家园 `alchemy` | 已选丹方材料 × 制作数量 | 批量产出已选丹方丹药，逐次判定额外出丹 |
| 强化装备 | 背包装备右键强化 | 匹配普通/五行灵石，数量 `enhance_count + 1` | 追加对应强化属性 |
| 加词条 | 背包装备右键加词条 | 洗练符，数量 `refine_count + 1` | 追加百分比词条 |
| 使用破境丹 | 背包右键使用 | 1 个破境丹 | 达等级上限时提升阶段和等级上限 |
