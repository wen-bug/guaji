# 璇︾粏鐗╁搧琛?
鏈枃妗ｆ槸鐙珛鐗╁搧琛紝渚濇嵁 `scripts/game/data_tables.gd` 褰撳墠鏁版嵁鏁寸悊锛屼笉瑕嗙洊 `docs/items.md` 鐨勭郴缁熻鏄庛€?
## 绫诲瀷绱㈠紩

| 绫诲瀷 ID | 涓枃鍒嗙被 | 鍫嗗彔 | 鍙娇鐢?| 璇存槑 |
|---|---|---:|---:|---|
| `skill_book` | 鎶€鑳戒功 | 鏄?| 鏄?| 浣跨敤鍚庡涔犳妧鑳?|
| `equipment` | 瑁呭 | 鍚?| 鏄?| 浣跨敤鍚庣┛鎴村埌瑁呭妲?|
| `material` | 鏉愭枡 | 鏄?| 鍚?| 鐐煎櫒銆佸己鍖栥€佹礂缁冦€佹帀钀?|
| `crop` | 浣滅墿 | 鏄?| 鍚?| 绉嶇敯绉嶅瓙銆佺偧涓规秷鑰?|
| `pill` | 涓硅嵂 | 鏄?| 鏄?| 鎭㈠銆佹寔缁?Buff銆佺獊鐮?|
| `alchemy_recipe` | 鍥剧焊 | 鏄?| 鏄?| 瀛︿範涓规柟 |

## 闈欐€佺墿鍝佹槑缁?
### 鎶€鑳戒功

| 鐗╁搧 ID | 鍚嶇О | 绫诲瀷 | 鍫嗗彔 | 鍙娇鐢?| payload | 鑾峰彇/鐢ㄩ€?|
|---|---|---|---:|---:|---|---|
| `skill_book_spark` | 鐏电伀鏈绫?| `skill_book` | 鏄?| 鏄?| `skill_id: spark` | 浣跨敤鍚庡涔犵伒鐏湳 |
| `skill_book_water_needle` | 鐜勬按閽堢绫?| `skill_book` | 鏄?| 鏄?| `skill_id: water_needle` | 浣跨敤鍚庡涔犵巹姘撮拡 |
| `skill_book_stone_seal` | 瑁傚湡鍗扮绫?| `skill_book` | 鏄?| 鏄?| `skill_id: stone_seal` | 浣跨敤鍚庡涔犺鍦熷嵃 |

### 鏉愭枡

| 鐗╁搧 ID | 鍚嶇О | 绫诲瀷 | 鍫嗗彔 | 鍙娇鐢?| payload | 鑾峰彇/鐢ㄩ€?|
|---|---|---|---:|---:|---|---|
| `ore` | 鐭跨煶 | `material` | 鏄?| 鍚?| `{}` | 鎴樻枟鎺夎惤锛涚偧鍣ㄦ秷鑰楁潗鏂?|
| `spirit_sand` | 鐏电爞 | `material` | 鏄?| 鍚?| `{}` | 鎴樻枟鎺夎惤锛涙潗鏂欐秷鑰?|
| `beast_core` | 濡栨牳 | `material` | 鏄?| 鍚?| `{}` | 鎴樻枟鎺夎惤锛涙潗鏂欐秷鑰?|
| `refine_talisman` | 娲楃粌绗?| `material` | 鏄?| 鍚?| `refine: true` | 鍔ㄦ€佺墿鍝侊紱瑁呭鍔犺瘝鏉℃秷鑰?|

### 浣滅墿

| 鐗╁搧 ID | 鍚嶇О | 绫诲瀷 | 鍫嗗彔 | 鎴愮啛鏃堕棿 | payload | 鑾峰彇/鐢ㄩ€?|
|---|---|---|---:|---:|---|---|
| `herb` | 鑽夎嵂 | `crop` | 鏄?| 60s | `seed_yield: 3, growth_seconds: 60` | 閫氱敤绉嶅瓙锛涘熀纭€鐐间腹娑堣€?|
| `rice` | 鐏电背 | `crop` | 鏄?| 90s | `seed_yield: 2, growth_seconds: 90` | 閫氱敤绉嶅瓙锛涘熀纭€鐐间腹娑堣€?|
| `mushroom` | 鐏佃弴 | `crop` | 鏄?| 120s | `seed_yield: 1, growth_seconds: 120` | 閫氱敤绉嶅瓙锛涘熀纭€鐐间腹娑堣€?|
| `blade_grass` | 鍒冪汗鑽?| `crop` | 鏄?| 180s | `seed_yield: 1, growth_seconds: 180, stat: attack` | 鏀诲嚮涓硅嵂涓绘潗鏂?|
| `ironroot` | 閾佹牴钘?| `crop` | 鏄?| 180s | `seed_yield: 1, growth_seconds: 180, stat: defense` | 闃插尽涓硅嵂涓绘潗鏂?|
| `blood_ginseng` | 琛€鍙?| `crop` | 鏄?| 240s | `seed_yield: 1, growth_seconds: 240, stat: max_hp` | 鐢熷懡涓硅嵂涓绘潗鏂?|
| `spirit_lotus` | 鐏垫硥鑾?| `crop` | 鏄?| 240s | `seed_yield: 1, growth_seconds: 240, stat: max_mp` | 鐏靛姏涓硅嵂涓绘潗鏂?|
| `bone_bamboo` | 鐜夐绔?| `crop` | 鏄?| 360s | `seed_yield: 1, growth_seconds: 360, stat: root_bone` | 鏍归涓硅嵂涓绘潗鏂?|
| `woodvine` | 闈掓湪钘?| `crop` | 鏄?| 180s | `seed_yield: 1, growth_seconds: 180, element: wood` | 鏈ㄨ涓硅嵂涓绘潗鏂?|
| `flame_flower` | 璧ょ劙鑺?| `crop` | 鏄?| 210s | `seed_yield: 1, growth_seconds: 210, element: fire` | 鐏涓硅嵂涓绘潗鏂?|
| `earth_moss` | 鍘氬湡鑻?| `crop` | 鏄?| 210s | `seed_yield: 1, growth_seconds: 210, element: earth` | 鍦熻涓硅嵂涓绘潗鏂?|
| `metal_reed` | 鐜勯噾鑻?| `crop` | 鏄?| 300s | `seed_yield: 1, growth_seconds: 300, element: metal` | 閲戣涓硅嵂涓绘潗鏂?|
| `water_orchid` | 鐜勬按鍏?| `crop` | 鏄?| 240s | `seed_yield: 1, growth_seconds: 240, element: water` | 姘磋涓硅嵂涓绘潗鏂?|

### 涓硅嵂

| 鐗╁搧 ID | 鍚嶇О | 绫诲瀷 | 鍫嗗彔 | 鍙娇鐢?| payload | 鏁堟灉 |
|---|---|---|---:|---:|---|---|
| `pill` | 璋冩伅涓?| `pill` | 鏄?| 鏄?| `effect_mode: instant, hp: 30, mp: 20` | 绔嬪嵆鎭㈠鐢熷懡鍜屾硶鍔?|
| `life_pill` | 褰掑厓涓?| `pill` | 鏄?| 鏄?| `effect_mode: instant, hp: 55, mp: 0` | 绔嬪嵆鎭㈠鐢熷懡 |
| `spirit_pill` | 鑱氱伒涓?| `pill` | 鏄?| 鏄?| `effect_mode: instant, hp: 0, mp: 42` | 绔嬪嵆鎭㈠娉曞姏 |
| `might_pill` | 澹皵涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 30, stat: attack, amount: 3` | 30 绉掓敾鍑?Buff |
| `breakthrough_pill` | 鐮村涓?| `pill` | 鏄?| 鏄?| `breakthrough: true` | 杈惧埌绛夌骇涓婇檺鍚庣獊鐮翠笅涓€闃舵 |
| `attack_pill` | 鐮村啗涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: attack, amount: 5` | 300 绉掓敾鍑?+5 |
| `defense_pill` | 鐜勭敳涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: defense, amount: 5` | 300 绉掗槻寰?+5 |
| `life_boost_pill` | 琛€鍏冧腹 | `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: max_hp, amount: 30` | 300 绉掓渶澶х敓鍛?+30 |
| `mana_boost_pill` | 鐏垫硥涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: max_mp, amount: 20` | 300 绉掓渶澶х伒鍔?+20 |
| `root_bone_pill` | 閿婚涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: root_bone, amount: 2` | 300 绉掓牴楠?+2 |
| `wood_pill` | 闈掓湪涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: element_wood, amount: 5` | 300 绉掓湪琛?+5 |
| `fire_pill` | 璧ょ劙涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: element_fire, amount: 5` | 300 绉掔伀琛?+5 |
| `earth_pill` | 鍘氬湡涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: element_earth, amount: 5` | 300 绉掑湡琛?+5 |
| `metal_pill` | 鐜勯噾涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: element_metal, amount: 5` | 300 绉掗噾琛?+5 |
| `water_pill` | 鐜勬按涓?| `pill` | 鏄?| 鏄?| `effect_mode: duration, duration: 300, stat: element_water, amount: 5` | 300 绉掓按琛?+5 |

### 鐐间腹鍥剧焊

| 鐗╁搧 ID | 鍚嶇О | 绫诲瀷 | 鍫嗗彔 | 鍙娇鐢?| payload | 鏁堟灉 |
|---|---|---|---:|---:|---|---|
| `recipe_pill` | 璋冩伅涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: pill` | 瀛︿範璋冩伅涓逛腹鏂?|
| `recipe_life_pill` | 褰掑厓涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: life_pill` | 瀛︿範褰掑厓涓逛腹鏂?|
| `recipe_spirit_pill` | 鑱氱伒涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: spirit_pill` | 瀛︿範鑱氱伒涓逛腹鏂?|
| `recipe_might_pill` | 澹皵涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: might_pill` | 瀛︿範澹皵涓逛腹鏂?|
| `recipe_attack_pill` | 鐮村啗涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: attack_pill` | 瀛︿範鐮村啗涓逛腹鏂癸紱瀵瑰簲鍒冪汗鑽?|
| `recipe_defense_pill` | 鐜勭敳涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: defense_pill` | 瀛︿範鐜勭敳涓逛腹鏂癸紱瀵瑰簲閾佹牴钘?|
| `recipe_life_boost_pill` | 琛€鍏冧腹鏂?| `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: life_boost_pill` | 瀛︿範琛€鍏冧腹涓规柟锛涘搴旇鍙?|
| `recipe_mana_boost_pill` | 鐏垫硥涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: mana_boost_pill` | 瀛︿範鐏垫硥涓逛腹鏂癸紱瀵瑰簲鐏垫硥鑾?|
| `recipe_root_bone_pill` | 閿婚涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: root_bone_pill` | 瀛︿範閿婚涓逛腹鏂癸紱瀵瑰簲鐜夐绔?|
| `recipe_wood_pill` | 闈掓湪涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: wood_pill` | 瀛︿範闈掓湪涓逛腹鏂癸紱瀵瑰簲闈掓湪钘?|
| `recipe_fire_pill` | 璧ょ劙涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: fire_pill` | 瀛︿範璧ょ劙涓逛腹鏂癸紱瀵瑰簲璧ょ劙鑺?|
| `recipe_earth_pill` | 鍘氬湡涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: earth_pill` | 瀛︿範鍘氬湡涓逛腹鏂癸紱瀵瑰簲鍘氬湡鑻?|
| `recipe_metal_pill` | 鐜勯噾涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: metal_pill` | 瀛︿範鐜勯噾涓逛腹鏂癸紱瀵瑰簲鐜勯噾鑻?|
| `recipe_water_pill` | 鐜勬按涓规柟 | `alchemy_recipe` | 鏄?| 鏄?| `recipe_id: water_pill` | 瀛︿範鐜勬按涓逛腹鏂癸紱瀵瑰簲鐜勬按鍏?|

### 灞炴€т腹鑽厤鏂规潗鏂?
| 涓硅嵂 ID | 涓绘潗鏂?| 杈呮潗鏂?| 鍌寲鏉愭枡 |
|---|---|---|---|
| `attack_pill` | 鍒冪汗鑽?脳2 | 鐏电背 脳1 | `stat_stone_attack_t1` 脳1 |
| `defense_pill` | 閾佹牴钘?脳2 | 鐏电背 脳1 | `stat_stone_defense_t1` 脳1 |
| `life_boost_pill` | 琛€鍙?脳2 | 鑽夎嵂 脳1 | `stat_stone_max_hp_t1` 脳1 |
| `mana_boost_pill` | 鐏垫硥鑾?脳2 | 鐏佃弴 脳1 | `stat_stone_max_mp_t1` 脳1 |
| `root_bone_pill` | 鐜夐绔?脳2 | 濡栨牳 脳1 | `stat_stone_root_bone_t1` 脳1 |
| `wood_pill` | 闈掓湪钘?脳2 | 鑽夎嵂 脳1 | `spirit_stone_wood_t1` 脳1 |
| `fire_pill` | 璧ょ劙鑺?脳2 | 鐏电爞 脳1 | `spirit_stone_fire_t1` 脳1 |
| `earth_pill` | 鍘氬湡鑻?脳2 | 鐏电背 脳1 | `spirit_stone_earth_t1` 脳1 |
| `metal_pill` | 鐜勯噾鑻?脳2 | 鐭跨煶 脳1 | `spirit_stone_metal_t1` 脳1 |
| `water_pill` | 鐜勬按鍏?脳2 | 鐏佃弴 脳1 | `spirit_stone_water_t1` 脳1 |

## 鍔ㄦ€佺墿鍝佹槑缁?
### 灞炴€х伒鐭?
鐏电煶鐢?`_item_def_data()` 鎸?ID 鍔ㄦ€佽В鏋愶紝鍒嗕负浜旇鐏电煶鍜屾櫘閫氬睘鎬х伒鐭炽€?
浜旇鐏电煶鏍煎紡濡備笅锛?
```text
spirit_stone_<element>_<tier>
```

鏅€氬睘鎬х伒鐭虫牸寮忓涓嬶細

```text
stat_stone_<stat>_<tier>
```

| 瀛楁 | 鍙€夊€?|
|---|---|
| `element` | `wood`銆乣fire`銆乣earth`銆乣metal`銆乣water` |
| `stat` | `attack`銆乣defense`銆乣max_hp`銆乣max_mp`銆乣root_bone` |
| `tier` | `t1`銆乣t2`銆乣t3`銆乣t4`銆乣t5` |

| 闃朵綅 | 鏄剧ず鍚?| `enhance_amount` | 鎸傛満瀹氫綅 |
|---|---|---:|---|
| `t1` | 涓€闃?| 1 | 楂橀鍩虹鏉愭枡 |
| `t2` | 浜岄樁 | 2 | 绋冲畾绉疮鏉愭枡 |
| `t3` | 涓夐樁 | 4 | 鏁版棩鎴愰暱鐩爣 |
| `t4` | 鍥涢樁 | 7 | 浣庢鐜囬珮浠峰€兼潗鏂?|
| `t5` | 浜旈樁 | 11 | 鍛ㄧ骇绋€鏈夌洰鏍?|

| 浜旇 | 绀轰緥 ID | 璇存槑 |
|---|---|---|
| 鏈?| `spirit_stone_wood_t1` ~ `spirit_stone_wood_t5` | 寮哄寲 `element_wood` |
| 鐏?| `spirit_stone_fire_t1` ~ `spirit_stone_fire_t5` | 寮哄寲 `element_fire` |
| 鍦?| `spirit_stone_earth_t1` ~ `spirit_stone_earth_t5` | 寮哄寲 `element_earth` |
| 閲?| `spirit_stone_metal_t1` ~ `spirit_stone_metal_t5` | 寮哄寲 `element_metal` |
| 姘?| `spirit_stone_water_t1` ~ `spirit_stone_water_t5` | 寮哄寲 `element_water` |

| 鏅€氬睘鎬?| 绀轰緥 ID | 璇存槑 |
|---|---|---|
| 鏀诲嚮 | `stat_stone_attack_t1` ~ `stat_stone_attack_t5` | 寮哄寲 `attack` |
| 闃插尽 | `stat_stone_defense_t1` ~ `stat_stone_defense_t5` | 寮哄寲 `defense` |
| 鐢熷懡 | `stat_stone_max_hp_t1` ~ `stat_stone_max_hp_t5` | 寮哄寲 `max_hp` |
| 鐏靛姏 | `stat_stone_max_mp_t1` ~ `stat_stone_max_mp_t5` | 寮哄寲 `max_mp` |
| 鏍归 | `stat_stone_root_bone_t1` ~ `stat_stone_root_bone_t5` | 寮哄寲 `root_bone` |

寮哄寲鍙秷鑰楄澶囧凡鏈夊熀纭€灞炴€у搴旂殑鐏电煶锛氫簲琛屽睘鎬т娇鐢ㄤ簲琛岀伒鐭筹紝鏅€氬睘鎬т娇鐢ㄦ櫘閫氬睘鎬х伒鐭炽€傛秷鑰楁暟閲忎负 `enhance_count + 1`锛岃嚜鍔ㄤ紭鍏堜娇鐢?`t5 鈫?t4 鈫?t3 鈫?t2 鈫?t1`銆?
## 鎶€鑳借〃

| 鎶€鑳?ID | 鍚嶇О | 浜旇 | 鍐峰嵈 | MP 娑堣€?| 浼ゅ鍊嶇巼 |
|---|---|---|---:|---:|---:|
| `spark` | 鐏电伀鏈?| `fire` | 3.5 | 8 | 1.8 |
| `water_needle` | 鐜勬按閽?| `water` | 2.0 | 5 | 1.25 |
| `stone_seal` | 瑁傚湡鍗?| `earth` | 6.0 | 13 | 2.3 |

## 瑁呭妯℃澘琛?
鍔ㄦ€佽澶囧悕绉版牸寮忎负 `<闃朵綅鍚?路<妲戒綅鍚?`锛屼緥濡?`涓夐樁路姝﹀櫒`銆傛帀钀借澶囩殑鍩虹灞炴€у彧鏉ヨ嚜瑁呭妯℃澘鑷韩璁惧畾锛屼簲琛屻€佹牴楠ㄣ€佺敓鍛姐€佺伒鍔涚瓑闅忔満鍙樺寲浣滀负璇嶆潯鍐欏叆 `affixes`锛屼笉鍐嶄綔涓鸿澶囪韩浠芥垨寮哄埗鍩虹灞炴€с€?
### 浜虹墿涓庤澶囧熀纭€灞炴€х被鍨嬭〃

浜虹墿鍩虹灞炴€у瓨鏀惧湪 `GameState.stats` 鍜?`GameState.elements`锛涜澶囧熀纭€灞炴€у瓨鏀惧湪瑁呭瀹炰緥鐨?`base_attributes` 涓紝骞堕€氳繃鍚屽悕 `stat` 鍙犲姞鍒颁汉鐗╂€诲睘鎬с€傝澶囧己鍖栧彧鍏佽寮哄寲瑁呭宸叉湁鐨勫熀纭€灞炴€с€?
| stat ID | 涓枃鍚?| 灞炴€х粍 | 浜虹墿鏉ユ簮 | 瑁呭鏉ユ簮 | 寮哄寲鏉愭枡 | 涓昏褰卞搷 |
|---|---|---|---|---|---|---|
| `max_hp` | 鐢熷懡涓婇檺 | 鏅€氬睘鎬?| `stats.max_hp` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `stat_stone_max_hp_t*` | HP 涓婇檺涓庢仮澶嶄笂闄?|
| `max_mp` | 鐏靛姏涓婇檺 | 鏅€氬睘鎬?| `stats.max_mp` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `stat_stone_max_mp_t*` | MP 涓婇檺涓庢仮澶嶄笂闄?|
| `attack` | 鏀诲嚮 | 鏅€氬睘鎬?| `stats.attack` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `stat_stone_attack_t*` | 鏅敾銆佹妧鑳藉熀纭€浼ゅ |
| `defense` | 闃插尽 | 鏅€氬睘鎬?| `stats.defense` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `stat_stone_defense_t*` | 鐗╃悊鍑忎激 |
| `root_bone` | 鏍归 | 鏅€氬睘鎬?| `stats.root_bone` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `stat_stone_root_bone_t*` | 淇负鏀剁泭銆佺偧鍣ㄥ姞鎴愩€侀澶栧嚭涓广€佺獊鐮?|
| `element_wood` | 鏈ㄨ | 浜旇灞炴€?| `elements.wood` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `spirit_stone_wood_t*` | 鏈ㄤ激瀹冲姞鎴愩€佹湪浼ゅ鍑忓厤銆佷富浜旇鍊欓€?|
| `element_fire` | 鐏 | 浜旇灞炴€?| `elements.fire` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `spirit_stone_fire_t*` | 鐏激瀹冲姞鎴愩€佺伀浼ゅ鍑忓厤銆佷富浜旇鍊欓€?|
| `element_earth` | 鍦熻 | 浜旇灞炴€?| `elements.earth` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `spirit_stone_earth_t*` | 鍦熶激瀹冲姞鎴愩€佸湡浼ゅ鍑忓厤銆佷富浜旇鍊欓€?|
| `element_metal` | 閲戣 | 浜旇灞炴€?| `elements.metal` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `spirit_stone_metal_t*` | 閲戜激瀹冲姞鎴愩€侀噾浼ゅ鍑忓厤銆佷富浜旇鍊欓€?|
| `element_water` | 姘磋 | 浜旇灞炴€?| `elements.water` | 瑁呭鍩虹/寮哄寲/娲楃粌璇嶆潯 | `spirit_stone_water_t*` | 姘翠激瀹冲姞鎴愩€佹按浼ゅ鍑忓厤銆佷富浜旇鍊欓€?|

瑁呭鎬诲睘鎬ц础鐚寜 `base_attributes`銆乣affixes`銆乣enhanced_attributes` 鍜?`refine_affixes` 璁＄畻锛涗汉鐗╂€诲睘鎬у啀鍙犲姞鍩虹鍊笺€佹寔缁?Buff 鍜岃澶囪础鐚€傝澶囧己鍖栧彧璇诲彇 `base_attributes`锛屽洜姝よ瘝鏉″睘鎬т笉鑳借寮哄寲銆?
| 闃朵綅 | 瀛楁鍊?| 鐢熸垚姒傜巼 | 璇嶆潯鏉℃暟 | 鎸傛満瀹氫綅 |
|---|---|---:|---:|---|
| 涓€闃?| `t1` | 55% | 1 | 褰撴棩鍙緱銆佽繃娓¤澶?|
| 浜岄樁 | `t2` | 28% | 2 | 绋冲畾鏇挎崲 |
| 涓夐樁 | `t3` | 12% | 3 | 鏁版棩鐩爣 |
| 鍥涢樁 | `t4` | 4% | 4 | 闀跨嚎绋€鏈夋帀钀?|
| 浜旈樁 | `t5` | 1% | 5 | 鍛ㄧ骇姣曚笟鐩爣 |

鍩虹灞炴€у€煎叕寮忥細`round((base + equipment_level * level_scale + craft_bonus) * rarity_multiplier)`锛屾渶浣庝负 1銆?
| 妯℃澘 ID | 鐗╁搧 ID | 妲戒綅 | 鍩虹鍚?| 鍩虹灞炴€?| 绌挎埓闇€姹傚睘鎬?| 璇存槑 |
|---|---|---|---|---|---|---|
| `weapon` | `weapon` | `weapon` | Sword | `attack`: base 3, scale 2.0 | `attack` | 姝﹀櫒 |
| `helmet` | `helmet` | `helmet` | Helmet | `max_hp`: base 12, scale 3.0锛沗defense`: base 1, scale 0.7 | `defense` | 澶寸洈 |
| `armor` | `armor` | `armor` | Armor | `defense`: base 3, scale 1.5锛沗max_hp`: base 16, scale 4.0 | `defense` | 鎶ょ敳 |
| `leggings` | `leggings` | `leggings` | Leggings | `defense`: base 2, scale 1.0锛沗max_hp`: base 10, scale 2.5 | `defense` | 鑵跨敳 |
| `gloves` | `gloves` | `gloves` | Gloves | `attack`: base 2, scale 1.0锛沗defense`: base 1, scale 0.5 | `attack` | 鎶ゆ墜 |
| `accessory` | `accessory` | `accessory` | Charm | `max_mp`: base 10, scale 2.0锛沗root_bone`: base 1, scale 0.2 | `root_bone` | 楗板搧锛屽彲杩涘叆楗板搧 1/2 |

## 瑁呭灞炴€ф睜

瑁呭鐢熸垚椤哄簭涓洪樁绾?鈫?妯℃澘鍩虹灞炴€?鈫?闅忔満璇嶆潯銆傛ā鏉垮熀纭€灞炴€у浐瀹氬啓鍏?`base_attributes`锛涢樁绾у彧鍐冲畾鍊嶇巼鍜岄殢鏈鸿瘝鏉℃潯鏁般€傝瘝鏉″€煎叕寮忥細`round((random(min, max) + int(equipment_level * stat_level_scale) + craft_bonus) * rarity_multiplier)`锛屾渶浣庝负 1銆?
| 灞炴€х粍 | 鍖呭惈 stat | `t1` | `t2` | `t3` | `t4` | `t5` | 绛夌骇鎴愰暱 |
|---|---|---:|---:|---:|---:|---:|---:|
| 鏅€氭暟鍊?| `attack`銆乣defense`銆乣root_bone`銆乣element_*` | 1-2 | 2-4 | 4-7 | 7-11 | 11-16 | 鏀婚槻 0.8锛涙牴楠?浜旇 0.4 |
| 鐏靛姏 | `max_mp` | 4-8 | 8-14 | 14-22 | 22-34 | 34-50 | 1.2 |
| 鐢熷懡 | `max_hp` | 8-16 | 16-28 | 28-44 | 44-68 | 68-100 | 2.4 |

## 娲楃粌璇嶆潯姹?
| 璇嶆潯 ID | stat | 鏈€灏?| 鏈€澶?|
|---|---|---:|---:|
| `attack` | `attack` | 1 | 3 |
| `defense` | `defense` | 1 | 3 |
| `max_hp` | `max_hp` | 5 | 15 |
| `max_mp` | `max_mp` | 3 | 10 |
| `root_bone` | `root_bone` | 1 | 2 |

## 鏁屼汉鎺夎惤琛?
鎴樻枟鑳滃埄鍏堥€愰」缁撶畻涓嬭〃鏅€氭帀钀斤細姣忛」鐙珛鍒ゆ柇 `rng.randf() <= chance`锛屾暟閲忎负 `randi_range(min, max)`銆傛櫘閫氭帀钀界粨绠楀悗锛屽啀鐙珛浠?35% 姒傜巼鎺夎惤 1 浠惰澶囷細`equipment_level = enemy.level`锛屾Ы浣嶉殢鏈猴紝闃朵綅鎸夎澶囬樁浣嶆鐜囪〃闅忔満銆傝澶囧熀纭€灞炴€ф寜妲戒綅妯℃澘鐢熸垚锛岄殢鏈哄彉鍖栧啓鍏?`affixes`锛涚┛鎴撮渶姹備负妯℃澘闇€姹傚睘鎬ц揪鍒?`max(1, equipment_level * rarity_tier)`銆?
| 鏁屼汉 ID | 鏁屼汉鍚?| 鎺夎惤鐗╁搧 ID | 鏁伴噺 | 姒傜巼 |
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

## 鎿嶄綔鍏ュ彛閫熸煡

| 鎿嶄綔 | 鍏ュ彛 | 娑堣€?| 浜у嚭/鏁堟灉 |
|---|---|---|---|
| 浣跨敤鎶€鑳戒功 | 鑳屽寘鍙抽敭浣跨敤 | 1 鏈妧鑳戒功 | 瀛︿範鎶€鑳?|
| 绌挎埓瑁呭 | 鑳屽寘鍙抽敭浣跨敤 | 鏃?| 瑁呭鍒板搴旀Ы浣?|
| 涓㈠純鐗╁搧 | 鑳屽寘鍙抽敭涓㈠純 | 鐩爣鐗╁搧 | 鏁伴噺 -1 鎴栫Щ闄よ澶囧疄渚?|
| 绉嶇敯 | 瀹跺洯 `farmland` | 1 涓綔鐗╃瀛?| 瀵瑰簲浣滅墿锛屼骇閲忓彈鍐滅敯绛夌骇褰卞搷 |
| 鐐煎櫒 | 瀹跺洯 `forge` | 2 涓?`ore` | 闅忔満瑁呭锛宍equipment_level = 鐜╁绛夌骇`锛屼娇鐢?`craft_bonus` |
| 鐐间腹 | 瀹跺洯 `alchemy` | 宸查€変腹鏂规潗鏂?脳 鍒朵綔鏁伴噺 | 鎵归噺浜у嚭宸查€変腹鏂逛腹鑽紝閫愭鍒ゅ畾棰濆鍑轰腹 |
| 寮哄寲瑁呭 | 鑳屽寘瑁呭鍙抽敭寮哄寲 | 鍖归厤鏅€?浜旇鐏电煶锛屾暟閲?`enhance_count + 1` | 杩藉姞瀵瑰簲寮哄寲灞炴€?|
| 鍔犺瘝鏉?| 鑳屽寘瑁呭鍙抽敭鍔犺瘝鏉?| 娲楃粌绗︼紝鏁伴噺 `refine_count + 1` | 杩藉姞鐧惧垎姣旇瘝鏉?|
| 浣跨敤鐮村涓?| 鑳屽寘鍙抽敭浣跨敤 | 1 涓牬澧冧腹 | 杈剧瓑绾т笂闄愭椂鎻愬崌闃舵鍜岀瓑绾т笂闄?|

