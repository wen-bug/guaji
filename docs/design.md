# 鎸傛満妗屽疇 2D 妯増鍘熷瀷璁捐鏂囨。

## 椤圭洰瀹氫綅

杩欐槸涓€涓繍琛屽湪妗岄潰浠诲姟鏍忎笂鏂圭殑 2D 妯増鎸傛満妗屽疇鍘熷瀷銆傜帺瀹剁偣鍑诲鍥湴鍥捐妭鐐规墦寮€瀵瑰簲 HUD 闈㈡澘锛岄€氳繃闈㈡澘鎸夐挳鐩存帴杩涜鎵撳潗銆佺鐢般€佺偧鍣ㄣ€佺偧涓规垨鎴樻枟锛屽苟鍦ㄦ寕鏈鸿繃绋嬩腑鑾峰緱璧勬簮銆佺粡楠屻€佽澶囥€佺啛缁冨害銆佹牴楠ㄤ笌浜旇鎴愰暱銆?
绗竴鐗堢洰鏍囨槸楠岃瘉鏍稿績闂幆锛?
- 妗屽疇绐楀彛锛氭棤杈规銆佺疆椤躲€侀€忔槑鑳屾櫙锛岀獥鍙ｅ簳杈硅创浣忕郴缁熶换鍔℃爮椤堕儴銆?- 鍙屽尯鍧楀湴鍥撅細瀹跺洯璐熻矗鎭㈠銆佺鐢般€佺偧鍣ㄣ€佺偧涓癸紱鍘嗙粌鍏ュ彛璐熻矗鎵撴€€佺粡楠屻€佹帀钀藉拰瑁呭銆?- 瀹跺洯浜や簰锛氱偣鍑?`meditate`銆乣farmland`銆乣forge`銆乣alchemy`銆乣fight` 鎵撳紑瀵瑰簲 HUD 闈㈡澘銆?- 鑳屽寘绯荤粺锛氱粺涓€绠＄悊鎶€鑳戒功銆佽澶囥€佹潗鏂欍€佷綔鐗┿€佷腹鑽拰鍥剧焊锛屾敮鎸佸彸閿娇鐢ㄣ€佷涪寮冦€佽澶囧己鍖栦笌娲楃粌銆?- 鎴愰暱绯荤粺锛氱瓑绾с€佷慨涓恒€佺啛缁冨害銆佹牴楠ㄣ€佷簲琛屻€佽澶囪瘝鏉″拰涓硅嵂 Buff 鍏卞悓褰卞搷鐜╁鏁板€笺€?
## 鍦板浘涓庝氦浜?
瀹跺洯鍦烘櫙 `res://scripts/map/home.tscn` 鐨勬牴鑺傜偣鎸傝浇 `HomeMap` 鑴氭湰銆傚彲浜や簰鑺傜偣鎸夊悕绉板尮閰嶉€昏緫锛歚meditate`銆乣farmland`銆乣forge`銆乣alchemy`銆乣fight`銆傝妭鐐逛笅鐨?`Area2D` 鎺ユ敹宸﹂敭鐐瑰嚮骞跺彂鍑鸿妭鐐瑰悕绉帮紝鐢变富鍦烘櫙鎵撳紑瀵瑰簲 HUD 闈㈡澘銆?
褰撳墠鍔ㄤ綔娴佺▼锛?
1. 鐜╁鐐瑰嚮瀹跺洯鑺傜偣銆?2. HUD 鎵撳紑瀵瑰簲寮圭獥锛屽苟搴旂敤宸蹭繚瀛樼殑寮圭獥浣嶇疆銆?3. 鐜╁鐐瑰嚮寮圭獥鎸夐挳鎴栭€夋嫨閰嶆柟/鏁伴噺銆?4. `main.gd` 鎴?`GameState` 鐩存帴缁撶畻璧勬簮銆佺粡楠屻€佺啛缁冨害銆佽澶囥€佷腹鑽垨鎴樻枟鐘舵€併€?5. `GameState.changed` 瑙﹀彂 HUD 鍒锋柊涓庡瓨妗ｅ欢杩熷啓鍏ャ€?
瑙掕壊琛ㄧ幇鍙繚鐣欐瀹犲緟鏈洪€昏緫锛歚IDLE`銆乣ROAMING`銆乣TALKING`銆乣PAUSED`銆傜┖闂叉椂瑙掕壊鍦ㄥ鍥寖鍥村唴闂查€涙垨鏄剧ず鐭鐧姐€?
## 鑳屽寘涓庣墿鍝?
鐗╁搧瀹炰緥缁熶竴鍖呭惈锛?
- `item_id`锛氱墿鍝佸畾涔?ID銆?- `type`锛氱墿鍝佺被鍨嬶紝濡?`equipment`銆乣material`銆乣crop`銆乣pill`銆乣alchemy_recipe`銆乣skill_book`銆?- `name` / `description`锛氭樉绀烘枃鏈€?- `count` / `stackable`锛氭暟閲忎笌鏄惁鍫嗗彔銆?- `usable`锛氭槸鍚﹀厑璁稿彸閿娇鐢ㄣ€?- `payload`锛氬垎绫讳笓灞炴暟鎹紝渚嬪鎭㈠閲忋€佷腹鏂?ID銆佺瀛愪骇閲忋€佹寔缁?Buff銆佺獊鐮存晥鏋滅瓑銆?
涓昏绫诲瀷锛?
- 鎶€鑳戒功锛氫娇鐢ㄥ悗瀛︿範瀵瑰簲鎶€鑳斤紝宸插涔犲垯涓嶉噸澶嶆秷鑰椼€?- 瑁呭锛氫娇鐢ㄥ悗灏濊瘯绌挎埓鍒版鍣ㄣ€佸ご鐩斻€佹姢鐢层€佽吙鐢层€佹姢鎵嬨€侀グ鍝?1 鎴栭グ鍝?2锛涢グ鍝佷紭鍏堝～绌烘Ы锛屾弧妲芥椂鏇挎崲楗板搧 1銆?- 鏉愭枡锛氱偧鍣ㄣ€佸己鍖栥€佹礂缁冦€佹垬鏂楀鍔卞拰鍏朵粬娑堣€楅」銆?- 浣滅墿锛氭棦鏄偧涓规潗鏂欙紝涔熷彲浣滀负鍐滅敯绉嶅瓙銆?- 涓硅嵂锛氬垎涓轰竴娆℃€т腹鑽拰鎸佺画涓硅嵂锛涗竴娆℃€х珛鍗崇粨绠楋紝鎸佺画鍨嬪姞鍏?`active_buffs`銆?- 鍥剧焊锛歚alchemy_recipe` 绫诲瀷锛屼娇鐢ㄥ悗瀛︿範涓规柟骞跺啓鍏?`known_alchemy_recipes`銆?
鑳屽寘 UI 浣跨敤 5脳5 鏍煎瓙銆傛瘡鏍奸鐣欏浘鏍囦綅缃紝鎮诞鏄剧ず鐗╁搧浠嬬粛锛屽弻鍑诲彧鐩存帴浣跨敤瑁呭鍜屼腹鑽紱鍥剧焊銆佹妧鑳戒功銆佹潗鏂欍€佷綔鐗╀粛閫氳繃鍙抽敭鑿滃崟浣跨敤鎴栦笉鍝嶅簲鐩存帴浣跨敤銆?
## 鏍稿績璁＄畻鍏紡

### 灞炴€ф€诲€?
浜虹墿涓庤澶囧彲鍙犲姞鐨勫熀纭€灞炴€х被鍨嬭 `docs/item-table.md` 鐨勨€滀汉鐗╀笌瑁呭鍩虹灞炴€х被鍨嬭〃鈥濄€傛櫘閫氬睘鎬ф潵鑷?`GameState.stats`锛屼簲琛屽睘鎬ф潵鑷?`GameState.elements`锛涜澶囦娇鐢ㄥ悓鍚?`stat` 鍐欏叆 `base_attributes`銆乣enhanced_attributes` 鍜?`refine_affixes`銆?
- `total_stat(stat) = stats[stat] + active_buff_bonus(stat) + equipped_attribute_bonus(stat)`銆?- `total_element(element) = elements[element] + equipped_attribute_bonus("element_" + element)`銆?- `element_power = sum(total_element(鏈? 鐏? 鍦? 閲? 姘?)`銆?- `total_attack = stats.attack + int(element_power * 0.15) + active_buff_bonus("attack") + equipped_attribute_bonus("attack")`銆?- `total_defense = stats.defense + active_buff_bonus("defense") + equipped_attribute_bonus("defense")`銆?- 涓讳簲琛屼负 `total_element()` 鏁板€兼渶楂樼殑浜旇銆?
### 鎴愰暱涓庣獊鐮?
- 缁忛獙澧炲姞鍚庯紝鍙 `exp >= next_exp` 涓旂瓑绾т笂闄愬凡鎵撳紑锛屽氨鍗囩骇銆?- 缁忛獙鍗囩骇娑堣€楀綋鍓?`next_exp`锛岀劧鍚?`next_exp = int(next_exp * 1.35) + 20`銆?- 鎵撳潗鍩虹淇负鏉ヨ嚜涓绘祦绋嬶細`8 + level`銆?- 瀹為檯淇负鏀剁泭锛歚base_amount + int(total_root_bone * 0.4)`銆?- 淇负鍗囩骇娑堣€楀綋鍓?`next_cultivation`锛岀劧鍚?`next_cultivation = int(next_cultivation * 1.35) + 15`銆?- 姣忔鍗囩骇闅忔満澧炲姞锛歚max_hp 8~20`銆乣max_mp 4~12`銆乣attack 1~3`銆乣defense 0~2`銆乣root_bone 0~1`锛屽苟闅忔満涓€涓簲琛屽鍔?`1~3`銆?- 杈惧埌绛夌骇涓婇檺鏃讹紝浣跨敤绐佺牬涓瑰彲鎻愬崌闃舵骞朵娇 `level_cap += 10`锛涜嫢 `root_bone > level`锛屽彲鍏嶇獊鐮翠腹鎵撳紑涓嬩竴闃舵銆?
### 鏍归鍔犳垚

- 淇负鏀剁泭鍔犳垚锛歚int(total_root_bone * 0.4)`銆?- 鐐煎櫒/瑁呭鐢熸垚鍔犳垚锛歚craft_bonus = int(total_root_bone * 0.2)`銆?- 鐐间腹棰濆鍑轰腹姒傜巼锛歚min(0.35, total_root_bone * 0.015)`銆?- 鏍归楂樹簬褰撳墠绛夌骇涓旇揪鍒扮瓑绾т笂闄愭椂锛屽彲鍏嶉亾鍏风獊鐮淬€?
### 鎴樻枟

- 鐜╁鏅€氭敾鍑诲熀纭€浼ゅ锛歚max(1, total_attack - enemy.defense)`銆?- 鏅€氭敾鍑诲厓绱犱负鐜╁涓讳簲琛岋紱鎶€鑳芥敾鍑诲厓绱犱负鎶€鑳借嚜韬?`element`銆?- 鍏冪礌浼ゅ鍔犳垚锛歚int(total_element(element) * 0.5)`銆?- 鍛戒腑鏁屼汉寮辩偣鏃堕澶栧鍔狅細`max(1, int(base_damage * 0.25)) + total_element(element)`銆?- 鎶€鑳戒激瀹冲熀纭€鍊硷細`int(total_attack * skill.damage_multiplier)`锛屽啀璧板悓涓€鍏冪礌/寮辩偣鍔犳垚銆?- 鐗╃悊鍑忎激锛歚max(1, amount - total_defense)`銆?- 鍏冪礌鍑忎激锛歚max(0, amount - int(total_element(element) * 0.35))`銆?- 鏁屼汉鏀诲嚮鍙寜 `element_attack_ratio` 闅忔満闄勫甫鏁屼汉鑷韩浜旇銆?
### 鎺夎惤涓庤澶囨帀钀?
- 鎴樻枟鑳滃埄鍏堢粨绠楁晫浜?`drops` 琛細姣忎釜鐗╁搧鐙珛鍒ゆ柇 `rng.randf() <= chance`锛屾暟閲忎负 `randi_range(min, max)`銆?- 鏅€氭帀钀界粨绠楀悗锛岀嫭绔嬭繘琛岃澶囨帀钀斤細褰撳墠鏉′欢涓?`rng.randf() > 0.65`锛屽嵆 35% 姒傜巼鑾峰緱 1 浠惰澶囥€?- 鎺夎惤瑁呭璋冪敤 `create_equipment(enemy.level, rng, craft_bonus)`锛屽洜姝?`equipment_level = enemy.level`銆?- 鎺夎惤瑁呭妲戒綅浠?`EQUIPMENT_DEFS` 闅忔満閫夋嫨锛氭鍣ㄣ€佸ご鐩斻€佹姢鐢层€佽吙鐢层€佹姢鎵嬫垨楗板搧銆?- 鎺夎惤瑁呭涓嶅啀闅忔満浜旇韬唤锛岀粺涓€鎸夋Ы浣嶆ā鏉跨敓鎴愬熀纭€灞炴€э紱浜旇鍙綔涓洪殢鏈鸿瘝鏉″嚭鐜般€?- 鎺夎惤瑁呭闃朵綅鎸?`EQUIPMENT_RARITY_DEFS` 姒傜巼闅忔満锛岄樁浣嶅喅瀹氭樉绀哄悕銆侀殢鏈鸿瘝鏉℃暟閲忋€佽瘝鏉″€嶇巼鍜岀┛鎴撮渶姹傚€嶇巼銆?- 鎺夎惤瑁呭鑾峰緱涓嶅仛灞炴€ч棬妲涳紱绌挎埓鏃舵墠妫€鏌?`equip_requirement`銆?
### 鐢熶骇涓庣偧涓?
- 绉嶇敯鑷姩閫夋嫨鑳屽寘涓涓€涓綔鐗╀綔涓虹瀛愶紝娑堣€?1 涓紝浜ч噺涓?`seed_yield + farm_level - 1`銆?- 鐐煎櫒娑堣€?2 涓?`ore`锛岀敓鎴?1 浠堕殢鏈鸿澶囷紝骞惰幏寰楃粡楠屼笌鐐煎櫒鐔熺粌搴︺€?- 鐐间腹闈㈡澘鍙睍绀?`known_alchemy_recipes` 涓殑宸插涓规柟銆?- 鍗曚釜涓规柟鏈€澶у彲鍒朵綔鏁伴噺涓烘墍鏈夋潗鏂?`floor(褰撳墠鏁伴噺 / 鍗曟闇€姹?` 鐨勬渶灏忓€笺€?- 鎵归噺鐐间腹娑堣€?`amount * 鍗曟闇€姹俙锛屽熀纭€浜х墿鏁伴噺涓?`amount`銆?- 姣忔鍒朵綔鐙珛鍒ゅ畾棰濆鍑轰腹锛氳嫢 `rng.randf() < alchemy_extra_chance()`锛屾湰娆￠澶?+1 浜х墿锛屼笉澧炲姞鏉愭枡娑堣€椼€?
### 瑁呭鐢熸垚銆佺┛鎴翠笌鍏绘垚

- 瑁呭鍚嶇О鏍煎紡锛歚<闃朵綅鍚?路<妲戒綅鍚?`銆?- 闃朵綅 `t1..t5` 瀵瑰簲 `rarity_tier = 1..5`锛岄殢鏈鸿瘝鏉℃暟閲忕瓑浜?`rarity_tier`銆?- 鍩虹灞炴€у彧鏉ヨ嚜瑁呭妯℃澘锛屽熀纭€鍊硷細`round((base + equipment_level * level_scale + craft_bonus) * rarity_multiplier)`锛屾渶浣庝负 1銆?- 闅忔満璇嶆潯鍐欏叆 `affixes`锛岃瘝鏉″€硷細`round((random(min, max) + equipment_level * scale + craft_bonus) * rarity_multiplier)`锛屾渶浣庝负 1銆?- 绌挎埓闇€姹傦細鎸夎澶囨ā鏉跨殑闇€姹傚睘鎬ф鏌ワ紱闇€姹傚€间负 `max(1, equipment_level * rarity_tier)`銆?- 绌挎埓鏍￠獙涓嶈鍏ュ€欓€夎澶囪嚜韬睘鎬э紱鏇挎崲鍚屾Ы浣嶈澶囨椂锛屼篃涓嶈鍏ュ嵆灏嗚鏇挎崲鎺夌殑鍚屾Ы浣嶈澶囥€?- 鏅€氬己鍖栨秷鑰楄澶囧凡鏈夊熀纭€灞炴€у搴旂殑鐏电煶锛屾秷鑰楁暟閲忎负 `enhance_count + 1`锛屽己鍖栧€肩敱鐏电煶鍝佽川鍐冲畾銆?- 娲楃粌娑堣€楁礂缁冪锛屾秷鑰楁暟閲忎负 `refine_count + 1`锛涙瘡娆￠殢鏈轰竴鏉″睘鎬х櫨鍒嗘瘮璇嶆潯锛岀櫨鍒嗘瘮涓?`0.05~0.15` 骞舵寜 `0.01` 瀵归綈銆?- 瑁呭鏈€缁堣瘝鏉″€间负鍩虹/寮哄寲鍔犳硶鍊间箻浠ュ悓灞炴€ф礂缁冪櫨鍒嗘瘮锛歚floor(flat_value * (1 + percent_bonus))`銆?
## HUD 涓庡瓨妗?
HUD 鍖呭惈鑿滃崟鎸夐挳銆佺帺瀹朵俊鎭€佽儗鍖呫€佺鐢般€佺偧鍣ㄣ€佺偧涓广€佹墦鍧愩€佹垬鏂楃瓑寮圭獥銆傜帺瀹朵俊鎭彧灞曠ず灞炴€с€佸凡绌挎埓瑁呭鍜屽凡瀛︿範鎶€鑳斤紱瑁呭鍜屾妧鑳芥Ы浣嶉鐣欑編鏈浘鏍囦綅缃€傛墍鏈夊脊绐楁敮鎸佹嫋鍔紝鎷栧姩浣嶇疆鍐欏叆 `user://save.cfg` 骞跺湪涓嬫鎵撳紑鏃舵仮澶嶏紝瓒呭嚭瑙嗗彛鏃朵細 clamp 鍥炲彲瑙佸尯鍩熴€?
瀛樻。鐢?`SaveManager` 鍐欏叆 `user://save.cfg`锛屽寘鍚増鏈彿銆佹父鎴忕姸鎬併€丠UD 闈㈡澘浣嶇疆鍜屽熀纭€閰嶇疆銆傜己澶卞瓧娈典娇鐢ㄩ粯璁ゅ€硷紝涓嶉樆濉炲惎鍔ㄣ€?
## 鎵╁睍绾﹀畾

鏂板鍫嗗彔鐗╁搧鏃朵紭鍏堝湪 `DataTables.ITEM_DEFS` 澧炲姞瀹氫箟锛涙柊澧炴妧鑳藉悓姝ユ墿灞?`SKILL_DEFS`锛涙柊澧炶澶囨ā鏉垮悓姝ユ墿灞?`EQUIPMENT_DEFS`锛涙柊澧炴晫浜哄悓姝ユ墿灞?`ENEMY_TEMPLATES`锛涙柊澧炶瘝鏉″悓姝ユ墿灞?`EQUIPMENT_ATTRIBUTE_DEFS`銆?
鍚庣画鍙墿灞曪細鐗╁搧鍝佽川棰滆壊鍜屽浘鏍囧瓧娈点€侀厤鏂?UI銆佸晢搴椼€佹妧鑳戒功鎺夎惤鏉ユ簮銆佷腹鑽寔缁?Buff 鐨勬洿澶氱被鍨嬪拰鍙犲姞瑙勫垯銆佸啘鐢板崌绾ф秷鑰椼€佺瀛愰€夋嫨 UI銆佸己鍖栧け璐ョ巼銆佽瘝鏉￠攣瀹氬拰淇濆簳鏈哄埗銆?# 鍘嗙粌鍦板浘銆侀殢鏈洪亣鎬笌鑷姩鎴樻枟琛ュ厖

鐐瑰嚮瀹跺洯 `fight` 鑺傜偣鍚庯紝鐜╁閫氳繃 HUD 鎵撴€潰鏉胯繘鍏?`BattleMap` 鍘嗙粌鍦板浘銆傝繘鍏ュ巻缁冨悗涓嶄細绔嬪嵆杩炵画鎴樻枟锛岃€屾槸闅愯棌瀹跺洯銆佹樉绀哄巻缁冨湴鍥俱€佽瑙掕壊鍥哄畾绔欎綅鎾斁 `run` 鍔ㄧ敾锛屽苟閫氳繃杩滄櫙/鍦伴潰涓ゅ眰寰幆婊氬姩鑳屾櫙琛ㄧ幇鎸佺画璧惰矾銆?
鎬墿鍒锋柊鐢?`BattleMap` 缁存姢闅忔満闂撮殧璁℃椂锛岄粯璁ゅ湪 `8.0` 鍒?`20.0` 绉掍箣闂淬€傝鏃跺埌杈句笖褰撳墠涓嶅湪鎴樻枟鏃讹紝`BattleMap` 鍙戝嚭 `monster_spawn_requested`锛屼富鍦烘櫙鍐嶈皟鐢?`CombatController.begin_encounter(game_state)` 寮€濮嬩竴鍦鸿嚜鍔ㄦ垬鏂椼€傛垬鏂楃粨鏉熷悗娓呯┖褰撳墠閬亣锛岀粨绠楁墦鎬啛缁冨害锛屽苟璋冪敤 `BattleMap.finish_combat()` 閲嶆柊瀹夋帓涓嬩竴娆￠殢鏈洪亣鎬紝瑙掕壊缁х画鐣欏湪鍘嗙粌鍦板浘璺戞绛夊緟銆?
