@tool
extends RefCounted
## 五行技能脚手架生成器（用法见 docs/skill-authoring.md「脚手架生成器」章节）。
## 为 MANIFEST 中列出的技能批量生成契约合法的三件套并注册索引：
##   1. resources/skills/<id>.tres                  SkillDef（占位数值，数值待填）
##   2. scripts/game/skills/<分类>/<id>_skill.tscn   释放场景（空白 EffectSprite，素材待贴）
##   3. resources/items/skill_book_<id>.tres         技能书 ItemDef
## 幂等：目标文件已存在则跳过生成；索引只追加缺失条目。
## 调用方式（game_eval 或任意编辑器/调试上下文）：
##   load("res://scripts/editor/skill_scaffold.gd").generate_all()
## 生成后人工三步：1. Inspector 填数值；2. EffectSprite 贴 SpriteFrames（参照 thunder_skill
## 三轨道模式补 play/visible 轨道）；3. 判定块模式实放微调时机与判定形状。

const SKILL_INDEX_PATH := "res://resources/skills/index.tres"
const ITEM_INDEX_PATH := "res://resources/items/index.tres"
const ITEM_NO_BASE := 1070

## 兑换成本与优先级按技能阶段（docs/skills.md 规划表）。
const STAGE_EXCHANGE := {
	1: {"fragment": 3, "stone": 1, "priority": 45},
	2: {"fragment": 6, "stone": 2, "priority": 60},
	3: {"fragment": 10, "stone": 3, "priority": 75},
	4: {"fragment": 15, "stone": 5, "priority": 90},
}

## preset -> 场景结构参数。分类目录与根脚本按 SkillDef type 推导。
const PRESETS := {
	"single_enemy": {"type": "damage", "target_scope": "single_enemy", "anchor": "primary_target", "shape": "rect", "size": [72, 96], "length": 0.3, "keys": [0, 0.1, 0.11, 0.29]},
	"aoe_enemy": {"type": "damage", "target_scope": "all_enemies", "anchor": "primary_target", "shape": "rect", "size": [480, 96], "length": 0.4, "keys": [0, 0.15, 0.16, 0.39]},
	"self_buff": {"type": "buff", "target_scope": "self", "anchor": "caster", "shape": "rect", "size": [72, 96], "length": 0.3, "keys": [0, 0.1, 0.11, 0.29]},
	"ally_buff": {"type": "defense", "target_scope": "single_ally", "anchor": "primary_target", "shape": "circle", "size": 96, "length": 0.5, "keys": [0, 0.2, 0.21, 0.49]},
	"heal_ally": {"type": "heal", "target_scope": "single_ally", "anchor": "primary_target", "shape": "circle", "size": 96, "length": 0.5, "keys": [0, 0.2, 0.21, 0.49]},
	"heal_all": {"type": "heal", "target_scope": "all_allies", "anchor": "caster", "shape": "rect", "size": [480, 96], "length": 0.5, "keys": [0, 0.2, 0.21, 0.49]},
	"team_buff": {"type": "defense", "target_scope": "all_allies", "anchor": "caster", "shape": "rect", "size": [480, 96], "length": 0.5, "keys": [0, 0.2, 0.21, 0.49]},
	"projectile": {"type": "damage", "target_scope": "single_enemy", "anchor": "primary_target", "shape": "capsule", "size": [12, 48], "length": 0.6, "keys": [0.45, 0.55, 0.57, 0.59], "projectile": true},
	"multi_hit_2": {"type": "damage", "target_scope": "single_enemy", "anchor": "primary_target", "shape": "rect", "size": [72, 96], "length": 0.7, "windows": [[0.05, 0.2, 0.25], [0.4, 0.55, 0.6]], "finish": 0.69},
	"multi_hit_3": {"type": "damage", "target_scope": "single_enemy", "anchor": "primary_target", "shape": "rect", "size": [72, 96], "length": 1.0, "windows": [[0.05, 0.2, 0.25], [0.4, 0.55, 0.6], [0.75, 0.9, 0.95]], "finish": 0.99},
}

const ROOT_SCRIPTS := {
	"damage": "res://scripts/game/skills/damage/direct_damage_skill.gd",
	"buff": "res://scripts/game/skills/buff/buff_skill.gd",
	"defense": "res://scripts/game/skills/buff/buff_skill.gd",
	"heal": "res://scripts/game/skills/heal/heal_skill.gd",
}
const SCENE_DIRS := {
	"damage": "damage",
	"buff": "buff",
	"defense": "buff",
	"heal": "heal",
}
const PROJECTILE_SCRIPT := "res://scripts/game/skills/base/skill_projectile_path.gd"

## 通用状态场景（status_kind -> .tscn）。
const STATUS_SCENES := {
	"dot": "res://scripts/game/skills/status/visuals/dot.tscn",
	"hot": "res://scripts/game/skills/status/visuals/hot.tscn",
	"shield": "res://scripts/game/skills/status/visuals/shield.tscn",
	"buff_stat": "res://scripts/game/skills/status/visuals/buff.tscn",
	"debuff_stat": "res://scripts/game/skills/status/visuals/debuff.tscn",
}

## 待生成技能清单（docs/skills.md 规划表；数值均为占位，待人工填写）。
## fx 简写：["d",倍率] 或 ["d",倍率,无视防御,impact_id]；["h",倍率]；
## ["dot",数值,回合]；["hot",数值,回合,目标?]；["shield",数值,回合,目标?]；
## ["stat","属性",±数值,回合]（正=增益 负=减益）；["cd",冷却倍率]。
const MANIFEST := [
	# 金·庚（一阶）
	{"id": "metal_sword_flash", "name": "流光剑", "element": "metal", "stage": 1, "preset": "single_enemy", "mp": 5, "cd": 2.0, "fx": [["d", 1.15]], "desc": "剑光如虹，斩向单个敌人。"},
	{"id": "metal_mountain_break", "name": "断岳式", "element": "metal", "stage": 1, "preset": "single_enemy", "mp": 8, "cd": 4.0, "fx": [["d", 1.2, 3]], "desc": "重剑破岳，无视部分防御。"},
	{"id": "metal_hidden_edge", "name": "藏锋诀", "element": "metal", "stage": 1, "preset": "self_buff", "mp": 6, "cd": 6.0, "fx": [["stat", "attack", 3, 3]], "desc": "敛息藏锋，短时间提升自身攻击。"},
	{"id": "metal_ten_thousand_blades", "name": "万剑归宗", "element": "metal", "stage": 1, "preset": "aoe_enemy", "mp": 16, "cd": 7.0, "fx": [["d", 1.4]], "desc": "万剑齐发，席卷全场敌人。"},
	# 金·辛（二阶）
	{"id": "metal_xin_thread_pierce", "name": "穿云一线", "element": "metal", "stage": 2, "preset": "multi_hit_2", "mp": 5, "cd": 2.0, "fx": [["d", 0.6, 0, "hit_1"], ["d", 0.6, 0, "hit_2"]], "desc": "剑气连绵，两段穿刺单个敌人。"},
	{"id": "metal_xin_needle_storm", "name": "漫天花雨", "element": "metal", "stage": 2, "preset": "aoe_enemy", "mp": 8, "cd": 4.0, "fx": [["d", 0.6], ["stat", "defense", -2, 3]], "desc": "飞针如雨，伤敌并削弱其防御。"},
	{"id": "metal_xin_jade_bind", "name": "珠缚诀", "element": "metal", "stage": 2, "preset": "single_enemy", "mp": 7, "cd": 5.0, "fx": [["d", 0.85], ["stat", "attack", -2, 3]], "desc": "金珠锁脉，压制单个敌人攻击。"},
	{"id": "metal_xin_thousand_needles", "name": "千针封喉", "element": "metal", "stage": 2, "preset": "multi_hit_3", "mp": 15, "cd": 7.0, "fx": [["d", 0.6, 5, "hit_1"], ["d", 0.6, 5, "hit_2"], ["d", 0.6, 5, "hit_3"]], "desc": "千针连刺，三段贯穿单个敌人。"},
	# 木·甲（一阶）
	{"id": "wood_dew_heal", "name": "青露回春", "element": "wood", "stage": 1, "preset": "heal_ally", "mp": 6, "cd": 4.0, "trigger": "hp_below_35", "fx": [["h", 0.9]], "desc": "青露润体，救治伤重的同伴。"},
	{"id": "wood_breath_array", "name": "生息阵", "element": "wood", "stage": 1, "preset": "heal_all", "mp": 10, "cd": 6.0, "trigger": "hp_below_35", "fx": [["h", 0.6], ["hot", 3, 3]], "desc": "布下生息阵，全体同伴持续回复。"},
	{"id": "wood_corroding_vine", "name": "蚀骨藤", "element": "wood", "stage": 1, "preset": "aoe_enemy", "mp": 8, "cd": 4.0, "fx": [["d", 0.8], ["dot", 2, 3]], "desc": "藤蔓缠身，腐蚀全场敌人。"},
	{"id": "wood_meridian_guard", "name": "青木护脉", "element": "wood", "stage": 1, "preset": "ally_buff", "mp": 11, "cd": 7.0, "trigger": "hp_below_60", "fx": [["shield", 8, 2], ["hot", 2, 2]], "desc": "木灵护脉，为同伴护盾并续疗。"},
	# 木·乙（二阶）
	{"id": "wood_yi_vine_lash", "name": "绊藤击", "element": "wood", "stage": 2, "preset": "single_enemy", "mp": 5, "cd": 2.0, "fx": [["d", 0.85], ["dot", 2, 4]], "desc": "藤鞭抽击，令单个敌人持续中毒。"},
	{"id": "wood_yi_parasitic_seed", "name": "寄种术", "element": "wood", "stage": 2, "preset": "single_enemy", "mp": 8, "cd": 4.0, "fx": [["d", 0.7], ["dot", 2, 4], ["hot", 2, 4, "caster"]], "desc": "寄生种子汲取敌血反哺自身。"},
	{"id": "wood_yi_creeping_thicket", "name": "蔓生棘丛", "element": "wood", "stage": 2, "preset": "aoe_enemy", "mp": 10, "cd": 6.0, "fx": [["d", 0.65], ["stat", "attack", -1, 3]], "desc": "棘丛蔓生，削弱全场敌人攻击。"},
	{"id": "wood_yi_strangling_root", "name": "绞根杀", "element": "wood", "stage": 2, "preset": "aoe_enemy", "mp": 14, "cd": 8.0, "fx": [["d", 0.7], ["dot", 3, 4]], "desc": "绞根骤紧，重创并腐蚀敌人。"},
	# 土·戊（一阶）
	{"id": "earth_mountain_strike", "name": "震岳击", "element": "earth", "stage": 1, "preset": "single_enemy", "mp": 6, "cd": 3.0, "fx": [["d", 1.1], ["shield", 4, 2, "caster"]], "desc": "崩山一击，并以土盾护身。"},
	{"id": "earth_immovable_stance", "name": "不动势", "element": "earth", "stage": 1, "preset": "self_buff", "mp": 6, "cd": 6.0, "trigger": "hp_below_60", "fx": [["stat", "defense", 3, 3]], "desc": "稳如山岳，短时间提升自身防御。"},
	{"id": "earth_spirit_armor", "name": "厚土玄甲", "element": "earth", "stage": 1, "preset": "team_buff", "mp": 10, "cd": 6.0, "trigger": "hp_below_60", "fx": [["shield", 8, 2]], "desc": "厚土化甲，为全体同伴护盾。"},
	{"id": "earth_mountain_wall", "name": "山河壁", "element": "earth", "stage": 1, "preset": "self_buff", "mp": 14, "cd": 8.0, "trigger": "hp_below_60", "fx": [["shield", 16, 3], ["stat", "defense", 4, 3]], "desc": "山河为壁，大幅强化自身防御。"},
	# 土·己（二阶）
	{"id": "earth_ji_loam_strike", "name": "沃土击", "element": "earth", "stage": 2, "preset": "single_enemy", "mp": 6, "cd": 3.0, "fx": [["d", 1.0], ["hot", 2, 2, "caster"]], "desc": "沃土翻击，伤敌并滋养自身。"},
	{"id": "earth_ji_garden_ward", "name": "田园护", "element": "earth", "stage": 2, "preset": "ally_buff", "mp": 7, "cd": 5.0, "trigger": "hp_below_60", "fx": [["shield", 6, 2], ["hot", 2, 2]], "desc": "园圃之护，为同伴护盾并续疗。"},
	{"id": "earth_ji_furrow_shelter", "name": "垄亩庇", "element": "earth", "stage": 2, "preset": "team_buff", "mp": 9, "cd": 6.0, "trigger": "hp_below_60", "fx": [["shield", 5, 2]], "desc": "田垄庇佑，为全体同伴护盾。"},
	{"id": "earth_ji_harvest_bulwark", "name": "丰穣壁", "element": "earth", "stage": 2, "preset": "ally_buff", "mp": 13, "cd": 8.0, "trigger": "hp_below_60", "fx": [["shield", 12, 2], ["hot", 3, 2], ["stat", "defense", 2, 3]], "desc": "丰穣为壁，厚护一名同伴。"},
	# 水·壬（三阶）
	{"id": "water_mirror_art", "name": "水镜诀", "element": "water", "stage": 3, "preset": "self_buff", "mp": 8, "cd": 5.0, "trigger": "hp_below_60", "fx": [["shield", 8, 2], ["hot", 2, 2], ["cd", 0.8]], "desc": "水镜护身，并加速自身技能回转。"},
	{"id": "water_binding_array", "name": "玄水缚", "element": "water", "stage": 3, "preset": "aoe_enemy", "mp": 11, "cd": 6.0, "fx": [["d", 0.7], ["stat", "defense", -2, 3]], "desc": "玄水缠身，削弱全场敌人防御。"},
	{"id": "water_returning_tide", "name": "沧海归流", "element": "water", "stage": 3, "preset": "heal_all", "mp": 15, "cd": 8.0, "trigger": "hp_below_35", "fx": [["h", 0.7]], "desc": "百川归海，救治全体同伴。"},
	# 水·癸（四阶）
	{"id": "water_gui_drizzle", "name": "细雨符", "element": "water", "stage": 4, "preset": "single_enemy", "mp": 5, "cd": 2.0, "fx": [["d", 0.9], ["stat", "attack", -1, 3]], "desc": "细雨侵体，削弱单个敌人攻击。"},
	{"id": "water_gui_mist_veil", "name": "薄雾纱", "element": "water", "stage": 4, "preset": "self_buff", "mp": 6, "cd": 4.0, "trigger": "hp_below_60", "fx": [["shield", 5, 2], ["cd", 0.8]], "desc": "薄雾掩形，并加速自身技能回转。"},
	{"id": "water_gui_eroding_rain", "name": "侵蚀雨", "element": "water", "stage": 4, "preset": "aoe_enemy", "mp": 11, "cd": 6.0, "fx": [["d", 0.6], ["stat", "attack", -1, 3], ["stat", "defense", -1, 3]], "desc": "侵蚀之雨，全面削弱全场敌人。"},
	{"id": "water_gui_dew_mercy", "name": "甘霖降", "element": "water", "stage": 4, "preset": "heal_all", "mp": 13, "cd": 8.0, "trigger": "hp_below_35", "fx": [["h", 0.6]], "desc": "甘霖普降，救治全体同伴。"},
	# 火·丙（三阶）
	{"id": "fire_heart_flame", "name": "焚心火", "element": "fire", "stage": 3, "preset": "projectile", "mp": 6, "cd": 3.0, "fx": [["d", 1.3]], "desc": "心火化矢，掷向单个敌人。"},
	{"id": "fire_blazing_mark", "name": "烈焰印", "element": "fire", "stage": 3, "preset": "aoe_enemy", "mp": 9, "cd": 5.0, "fx": [["d", 0.85], ["dot", 3, 2]], "desc": "烈焰烙印，灼烧全场敌人。"},
	{"id": "fire_edge_rite", "name": "燃锋祭", "element": "fire", "stage": 3, "preset": "self_buff", "mp": 7, "cd": 6.0, "fx": [["stat", "attack", 4, 3]], "desc": "以火祭锋，短时间大幅提升攻击。"},
	{"id": "fire_heavenly_flame", "name": "天火劫", "element": "fire", "stage": 3, "preset": "aoe_enemy", "mp": 16, "cd": 8.0, "fx": [["d", 1.55]], "desc": "天火降临，重创全场敌人。"},
	# 火·丁（四阶）
	{"id": "fire_ding_ember_touch", "name": "星火引", "element": "fire", "stage": 4, "preset": "single_enemy", "mp": 5, "cd": 2.0, "fx": [["d", 0.7], ["dot", 4, 2]], "desc": "星火燎原，灼烧单个敌人。"},
	{"id": "fire_ding_smolder_seal", "name": "慢灼印", "element": "fire", "stage": 4, "preset": "aoe_enemy", "mp": 8, "cd": 4.0, "fx": [["d", 0.55], ["dot", 4, 2]], "desc": "慢灼之印，灼烧全场敌人。"},
	{"id": "fire_ding_wick_flare", "name": "灯心焰", "element": "fire", "stage": 4, "preset": "single_enemy", "mp": 9, "cd": 5.0, "fx": [["d", 0.9], ["dot", 6, 2]], "desc": "灯心骤焰，重伤并灼烧敌人。"},
	{"id": "fire_ding_cinder_storm", "name": "余烬劫", "element": "fire", "stage": 4, "preset": "aoe_enemy", "mp": 14, "cd": 7.0, "fx": [["d", 0.75], ["dot", 5, 3]], "desc": "余烬成劫，长时间灼烧全场。"},
]


static func generate_all() -> Dictionary:
	var report := {"generated": [], "skipped": [], "errors": [], "manual_steps": []}
	for spec in MANIFEST:
		var id := str(spec["id"])
		if not PRESETS.has(str(spec["preset"])):
			report["errors"].append("%s: 未知预设 %s" % [id, str(spec["preset"])])
			continue
		var preset: Dictionary = PRESETS[str(spec["preset"])]
		var scene_dir := str(SCENE_DIRS[str(preset["type"])])
		var skill_path := "res://resources/skills/%s.tres" % id
		var scene_path := "res://scripts/game/skills/%s/%s_skill.tscn" % [scene_dir, id]
		var book_path := "res://resources/items/skill_book_%s.tres" % id
		if FileAccess.file_exists(skill_path) or FileAccess.file_exists(scene_path) or FileAccess.file_exists(book_path):
			report["skipped"].append(id)
			continue
		if not _write_text(skill_path, _skill_def_text(spec)):
			report["errors"].append("%s: SkillDef 写入失败" % id)
			continue
		if not _write_text(scene_path, _scene_text(spec, preset)):
			report["errors"].append("%s: 场景写入失败" % id)
			continue
		if not _write_text(book_path, _book_text(spec, ITEM_NO_BASE + MANIFEST.find(spec))):
			report["errors"].append("%s: 技能书写入失败" % id)
			continue
		report["generated"].append(id)
	# 索引注册（幂等：条目或分组已含 id 则跳过；跳过生成的条目也补注册，支持分批/断点生成）
	for spec in MANIFEST:
		var id := str(spec["id"])
		if not PRESETS.has(str(spec["preset"])):
			continue
		var preset: Dictionary = PRESETS[str(spec["preset"])]
		var scene_dir := str(SCENE_DIRS[str(preset["type"])])
		var scene_path := "res://scripts/game/skills/%s/%s_skill.tscn" % [scene_dir, id]
		var book_id := "skill_book_" + id
		var skill_entry := "{\"category\": \"active\", \"resource_path\": \"res://resources/skills/%s.tres\", \"scene_path\": \"%s\"}" % [id, scene_path]
		if not _index_insert_entry(SKILL_INDEX_PATH, id, skill_entry):
			report["errors"].append("%s: 技能索引注册失败" % id)
		if not _index_append_group(SKILL_INDEX_PATH, "active", id):
			report["errors"].append("%s: 技能索引分组失败" % id)
		if not _index_insert_entry(ITEM_INDEX_PATH, book_id, "\"res://resources/items/%s.tres\"" % book_id):
			report["errors"].append("%s: 物品索引注册失败" % book_id)
		if not _index_append_group(ITEM_INDEX_PATH, "all", book_id):
			report["errors"].append("%s: 物品索引分组失败" % book_id)
	report["manual_steps"] = [
		"1. Inspector 填写 SkillDef 数值与效果（生成值为占位：伤害/治疗 base_amount=7）",
		"2. EffectSprite 贴 SpriteFrames，参照 thunder_skill 三轨道模式补 play/visible 轨道",
		"3. 判定块模式实放，微调 open/impact/close 时机与判定形状",
		"4. 补图标素材 res://assets/skills/<id>.png 与 res://assets/items/skill_book_<id>.png",
		"5. 多段技能若追加状态效果，需为该效果显式指定 impact_id 对应窗口",
	]
	print("技能脚手架：生成 %d，跳过 %d，错误 %d" % [report["generated"].size(), report["skipped"].size(), report["errors"].size()])
	for id in report["generated"]:
		print("  生成 ", id)
	for message in report["errors"]:
		push_error("脚手架错误：" + str(message))
	return report


static func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("读取失败：" + path)
		return ""
	var content := file.get_as_text()
	file.close()
	return content.replace("\r\n", "\n")


static func _write_text(path: String, content: String) -> bool:
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			push_error("目录创建失败：" + dir)
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("写入失败：" + path)
		return false
	file.store_string(content)
	file.close()
	return true


static func _pascal_case(snake: String) -> String:
	var result := ""
	for part in snake.split("_"):
		result += part.capitalize()
	return result


## ---- SkillDef .tres 生成（参照 water_cold_talisman.tres）----

static func _skill_def_text(spec: Dictionary) -> String:
	var id := str(spec["id"])
	var stage: Dictionary = STAGE_EXCHANGE[int(spec["stage"])]
	var ext_lines: Array[String] = [
		"[ext_resource type=\"Script\" path=\"res://scripts/game/data/skill_def.gd\" id=\"1_skill\"]",
		"[ext_resource type=\"Script\" path=\"res://scripts/game/data/skill_effect_def.gd\" id=\"2_effect\"]",
	]
	var effect_kinds := _effect_kinds(spec)
	for kind in effect_kinds:
		var scene_path: String = STATUS_SCENES[kind]
		var ext_id := "3_status_%s" % kind
		if not ext_lines.any(func(line: String) -> bool: return line.contains(scene_path)):
			ext_lines.append("[ext_resource type=\"PackedScene\" path=\"%s\" id=\"%s\"]" % [scene_path, ext_id])
	var lines: Array[String] = ["[gd_resource type=\"Resource\" script_class=\"SkillDef\" format=3]", ""]
	lines.append_array(ext_lines)
	lines.append("")
	# 效果子资源
	var sub_ids: Array[String] = []
	for index in range(spec["fx"].size()):
		var sub_id := "Resource_fx_%d" % index
		sub_ids.append(sub_id)
		lines.append_array(_effect_sub_resource(spec, index, sub_id))
	lines.append("")
	# 主资源
	lines.append("[resource]")
	lines.append("script = ExtResource(\"1_skill\")")
	lines.append("id = \"%s\"" % id)
	lines.append("display_name = \"%s\"" % str(spec["name"]))
	lines.append("icon_name = \"%s\"" % id)
	lines.append("icon_path = \"res://assets/skills/%s.png\"" % id)
	lines.append("element = \"%s\"" % str(spec["element"]))
	lines.append("mp_cost = %d" % int(spec["mp"]))
	lines.append("cooldown = %s" % _float_text(float(spec["cd"])))
	lines.append("priority = %d" % int(stage["priority"]))
	var preset: Dictionary = PRESETS[str(spec["preset"])]
	if str(preset["type"]) != "damage":
		lines.append("type = \"%s\"" % str(preset["type"]))
	if str(preset["target_scope"]) != "single_enemy":
		lines.append("target_scope = \"%s\"" % str(preset["target_scope"]))
	if spec.has("trigger"):
		lines.append("triggers = Array[String]([\"%s\"])" % str(spec["trigger"]))
	lines.append("effects = Array[Resource]([%s])" % ", ".join(sub_ids.map(func(sub: String) -> String: return "SubResource(\"%s\")" % sub)))
	lines.append("exchange_book_item_id = \"skill_book_%s\"" % id)
	lines.append("exchange_element_stone_id = \"spirit_stone_%s\"" % str(spec["element"]))
	lines.append("exchange_fragment_cost = %d" % int(stage["fragment"]))
	lines.append("exchange_stone_cost = %d" % int(stage["stone"]))
	lines.append("description = \"%s\"" % str(spec["desc"]))
	lines.append("")
	return "\n".join(lines)


static func _effect_kinds(spec: Dictionary) -> Array:
	var kinds: Array = []
	for fx in spec["fx"]:
		var kind := _fx_status_kind(fx)
		if kind != "" and not kinds.has(kind):
			kinds.append(kind)
	return kinds


static func _fx_status_kind(fx: Array) -> String:
	match fx[0]:
		"dot":
			return "dot"
		"hot":
			return "hot"
		"shield":
			return "shield"
		"stat":
			return "buff_stat" if float(fx[2]) > 0 else "debuff_stat"
	return ""


static func _effect_sub_resource(spec: Dictionary, index: int, sub_id: String) -> Array[String]:
	var fx: Array = spec["fx"][index]
	var lines: Array[String] = ["[sub_resource type=\"Resource\" id=\"%s\"]" % sub_id, "script = ExtResource(\"2_effect\")"]
	var id := str(spec["id"])
	match fx[0]:
		"d":
			lines.append("effect_id = \"%s_damage%s\"" % [id, ("_" + str(fx[3])) if fx.size() >= 4 else ""])
			lines.append("base_amount = 7")
			lines.append("attribute_multiplier = %s" % _float_text(float(fx[1])))
			if fx.size() >= 3 and int(fx[2]) != 0:
				lines.append("defense_ignore = %d" % int(fx[2]))
			if fx.size() >= 4:
				lines.append("impact_id = \"%s\"" % str(fx[3]))
		"h":
			lines.append("effect_id = \"%s_heal\"" % id)
			lines.append("kind = \"heal\"")
			lines.append("base_amount = 7")
			lines.append("attribute_multiplier = %s" % _float_text(float(fx[1])))
		"dot", "hot", "shield":
			var kind := str(fx[0])
			var is_self_target := fx.size() >= 4 and str(fx[3]) == "caster"
			lines.append("effect_id = \"%s_%s\"" % [id, kind])
			lines.append("kind = \"status\"")
			if kind == "dot":
				lines.append("target = \"hit_targets\"")
				lines.append("requires_hit = true")
			elif is_self_target:
				lines.append("target = \"caster\"")
			lines.append("base_amount = %d" % int(fx[1]))
			lines.append("status_id = \"%s_%s\"" % [id, kind])
			lines.append("status_kind = \"%s\"" % kind)
			lines.append("duration_turns = %d" % int(fx[2]))
			lines.append("status_visual_scene = ExtResource(\"3_status_%s\")" % kind)
		"stat":
			var amount := int(fx[2])
			var is_buff := amount > 0
			var is_debuff := not is_buff
			var is_self_scope := str(PRESETS[str(spec["preset"])]["target_scope"]) == "self"
			var has_damage := false
			for other_fx: Array in spec["fx"]:
				if str(other_fx[0]) == "d":
					has_damage = true
			lines.append("effect_id = \"%s_%s\"" % [id, str(fx[1])])
			lines.append("kind = \"status\"")
			if is_debuff and has_damage:
				# 减益随伤害挂命中目标（参照寒潮符 cold 效果）。
				lines.append("target = \"hit_targets\"")
				lines.append("requires_hit = true")
			elif is_buff and is_self_scope:
				# 自身预设的增益显式挂自身；同伴/全队预设保持默认 skill_targets
				# （判定块按 target_scope 绑定己方层，重叠谁增益就挂谁）。
				lines.append("target = \"caster\"")
			lines.append("base_amount = %d" % amount)
			lines.append("status_id = \"%s_%s\"" % [id, str(fx[1])])
			lines.append("status_kind = \"%s\"" % ("buff_stat" if is_buff else "debuff_stat"))
			lines.append("stat = \"%s\"" % str(fx[1]))
			lines.append("duration_turns = %d" % int(fx[3]))
			lines.append("status_visual_scene = ExtResource(\"3_status_%s\")" % ("buff_stat" if is_buff else "debuff_stat"))
		"cd":
			lines.append("effect_id = \"%s_cooldown\"" % id)
			lines.append("kind = \"cooldown\"")
			lines.append("target = \"caster\"")
			lines.append("cooldown_multiplier = %s" % _float_text(float(fx[1])))
	lines.append("")
	return lines


static func _float_text(value: float) -> String:
	return str(value) if value != float(int(value)) else "%.1f" % value


## ---- 释放场景 .tscn 生成（参照 water_cold_talisman_skill.tscn）----

static func _scene_text(spec: Dictionary, preset: Dictionary) -> String:
	var id := str(spec["id"])
	var root_script: String = ROOT_SCRIPTS[str(preset["type"])]
	var is_projectile := bool(preset.get("projectile", false))
	var windows: Array = preset.get("windows", [])
	var ext_count := 2 + (1 if is_projectile else 0)
	var sub_count := 4 # reset + cast + shape + library（flight 轨道在 cast 动画内部，不占子资源）
	var lines: Array[String] = ["[gd_scene load_steps=%d format=3]" % (ext_count + sub_count + 1), ""]
	lines.append("[ext_resource type=\"Script\" path=\"%s\" id=\"1_skill\"]" % root_script)
	lines.append("[ext_resource type=\"Resource\" path=\"res://resources/skills/%s.tres\" id=\"2_resource\"]" % id)
	if is_projectile:
		lines.append("[ext_resource type=\"Script\" path=\"%s\" id=\"3_projectile\"]" % PROJECTILE_SCRIPT)
	lines.append("")
	lines.append("[sub_resource type=\"Animation\" id=\"Animation_reset\"]")
	lines.append("length = 0.1")
	lines.append("")
	lines.append("[sub_resource type=\"Animation\" id=\"Animation_cast\"]")
	lines.append("length = %s" % _float_text(float(preset["length"])))
	var track_index := 0
	if windows.is_empty():
		lines.append_array(_method_track_lines(track_index, ".", preset["keys"], [["open_hitbox"], ["impact"], ["close_hitbox"], ["finish_cast"]]))
		track_index += 1
	else:
		for window_index in range(windows.size()):
			var window: Array = windows[window_index]
			var window_id := "hit_%d" % (window_index + 1)
			# close_hitbox 无参数；args 短一位时 _method_track_lines 自动回退 []。
			lines.append_array(_method_track_lines(track_index, ".", [window[0], window[1], window[2]], [["open_hitbox"], ["impact"], ["close_hitbox"]], [[window_id], [window_id]]))
			track_index += 1
		lines.append_array(_method_track_lines(track_index, ".", [float(preset["finish"])], [["finish_cast"]]))
		track_index += 1
	if is_projectile:
		# 弹道在 impact 时刻（keys[1]）抵达目标：flight_progress 0 -> 1
		lines.append_array(_value_track_lines(track_index, "ProjectilePath:flight_progress", [0.0, float(preset["keys"][1])], [0.0, 1.0]))
	lines.append("")
	lines.append_array(_shape_lines(preset))
	lines.append("")
	lines.append("[sub_resource type=\"AnimationLibrary\" id=\"AnimationLibrary_main\"]")
	lines.append("_data = {&\"RESET\": SubResource(\"Animation_reset\"), &\"cast\": SubResource(\"Animation_cast\")}")
	lines.append("")
	lines.append("[node name=\"%sSkill\" type=\"Node2D\"]" % _pascal_case(id))
	lines.append("script = ExtResource(\"1_skill\")")
	lines.append("skill_resource = ExtResource(\"2_resource\")")
	lines.append("anchor_role = \"%s\"" % str(preset["anchor"]))
	lines.append("")
	lines.append("[node name=\"EffectSprite\" type=\"AnimatedSprite2D\" parent=\".\" groups=[\"skill_material_visual\"]]")
	lines.append("")
	lines.append("[node name=\"AnimationPlayer\" type=\"AnimationPlayer\" parent=\".\"]")
	lines.append("callback_mode_process = 0")
	lines.append("callback_mode_method = 1")
	lines.append("libraries/ = SubResource(\"AnimationLibrary_main\")")
	lines.append("")
	# .tscn 的 parent 路径相对场景根：弹道命中盒挂在 ProjectilePath 下时，
	# CollisionShape2D 必须写 "ProjectilePath/SkillHitbox"，否则实例化时父节点丢失。
	var hitbox_parent := "ProjectilePath/SkillHitbox" if is_projectile else "SkillHitbox"
	if is_projectile:
		lines.append("[node name=\"ProjectilePath\" type=\"Node2D\" parent=\".\"]")
		lines.append("script = ExtResource(\"3_projectile\")")
		lines.append("")
		lines.append("[node name=\"SkillHitbox\" type=\"Area2D\" parent=\"ProjectilePath\"]")
	else:
		lines.append("[node name=\"SkillHitbox\" type=\"Area2D\" parent=\".\"]")
	lines.append("")
	lines.append("[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"%s\"]" % hitbox_parent)
	lines.append("shape = SubResource(\"%s\")" % _shape_id(preset))
	lines.append("")
	return "\n".join(lines)


static func _method_track_lines(index: int, path: String, times: Array, methods: Array, args: Array = []) -> Array[String]:
	var times_text := ", ".join(times.map(func(value) -> String: return _float_text(float(value))))
	var transitions := ", ".join(times.map(func(_value) -> String: return "1"))
	var values: Array[String] = []
	for value_index in range(methods.size()):
		var method_args: Array = args[value_index] if value_index < args.size() else []
		var args_text := ", ".join(method_args.map(func(arg) -> String: return "\"%s\"" % arg))
		values.append("{\"args\": [%s], \"method\": &\"%s\"}" % [args_text, methods[value_index][0]])
	var lines: Array[String] = []
	lines.append("tracks/%d/type = \"method\"" % index)
	lines.append("tracks/%d/imported = false" % index)
	lines.append("tracks/%d/enabled = true" % index)
	lines.append("tracks/%d/path = NodePath(\"%s\")" % [index, path])
	lines.append("tracks/%d/interp = 1" % index)
	lines.append("tracks/%d/loop_wrap = true" % index)
	lines.append("tracks/%d/keys = {" % index)
	lines.append("\"times\": PackedFloat32Array(%s)," % times_text)
	lines.append("\"transitions\": PackedFloat32Array(%s)," % transitions)
	lines.append("\"values\": [%s]" % ", ".join(values))
	lines.append("}")
	return lines


static func _value_track_lines(index: int, path: String, times: Array, values: Array) -> Array[String]:
	var times_text := ", ".join(times.map(func(value) -> String: return _float_text(float(value))))
	var transitions := ", ".join(times.map(func(_value) -> String: return "1"))
	var lines: Array[String] = []
	lines.append("tracks/%d/type = \"value\"" % index)
	lines.append("tracks/%d/imported = false" % index)
	lines.append("tracks/%d/enabled = true" % index)
	lines.append("tracks/%d/path = NodePath(\"%s\")" % [index, path])
	lines.append("tracks/%d/interp = 1" % index)
	lines.append("tracks/%d/loop_wrap = true" % index)
	lines.append("tracks/%d/keys = {" % index)
	lines.append("\"times\": PackedFloat32Array(%s)," % times_text)
	lines.append("\"transitions\": PackedFloat32Array(%s)," % transitions)
	lines.append("\"update\": 0,")
	lines.append("\"values\": [%s]" % ", ".join(values.map(func(value) -> String: return _float_text(float(value)))))
	lines.append("}")
	return lines


static func _shape_lines(preset: Dictionary) -> Array[String]:
	var shape := str(preset["shape"])
	var raw_size = preset["size"]
	var size: Array = raw_size if raw_size is Array else [raw_size]
	if shape == "circle":
		return ["[sub_resource type=\"CircleShape2D\" id=\"CircleShape2D_hitbox\"]", "radius = %s" % _float_text(float(size[0]))]
	if shape == "capsule":
		return ["[sub_resource type=\"CapsuleShape2D\" id=\"CapsuleShape2D_hitbox\"]", "radius = %s" % _float_text(float(size[0])), "height = %s" % _float_text(float(size[1]))]
	return ["[sub_resource type=\"RectangleShape2D\" id=\"RectangleShape2D_hitbox\"]", "size = Vector2(%s, %s)" % [_float_text(float(size[0])), _float_text(float(size[1]))]]


static func _shape_id(preset: Dictionary) -> String:
	match str(preset["shape"]):
		"circle":
			return "CircleShape2D_hitbox"
		"capsule":
			return "CapsuleShape2D_hitbox"
	return "RectangleShape2D_hitbox"


## ---- 技能书 .tres 生成（参照 skill_book_water_cold_talisman.tres）----

static func _book_text(spec: Dictionary, item_no: int) -> String:
	var id := str(spec["id"])
	var name := str(spec["name"])
	var lines: Array[String] = [
		"[gd_resource type=\"Resource\" script_class=\"ItemDef\" format=3]",
		"",
		"[ext_resource type=\"Script\" path=\"res://scripts/game/data/item_effect_def.gd\" id=\"1_effect\"]",
		"[ext_resource type=\"Script\" path=\"res://scripts/game/data/item_def.gd\" id=\"2_item\"]",
		"",
		"[sub_resource type=\"Resource\" id=\"Resource_unlock\"]",
		"script = ExtResource(\"1_effect\")",
		"effect_id = \"unlock_skill\"",
		"kind = \"unlock_content\"",
		"reference_kind = \"skill\"",
		"reference_id = \"%s\"" % id,
		"",
		"[resource]",
		"script = ExtResource(\"2_item\")",
		"id = \"skill_book_%s\"" % id,
		"item_no = %d" % item_no,
		"type = \"skill_book\"",
		"display_name = \"%s技能书\"" % name,
		"icon_name = \"skill_book_%s\"" % id,
		"icon_path = \"res://assets/items/skill_book_%s.png\"" % id,
		"description = \"使用后令选中角色永久学会%s。\"" % name,
		"usable = true",
		"use_context = \"home\"",
		"gain_target = \"%s\"" % str(spec["element"]),
		"effects = Array[Resource]([SubResource(\"Resource_unlock\")])",
		"",
	]
	return "\n".join(lines)


## ---- 索引注册（文本级幂等插入）----

## entries 为 key 排序的字典字面量；value_text 已含引号或为字典字面量文本。
static func _index_insert_entry(path: String, key: String, value_text: String) -> bool:
	var text := _read_text(path)
	if text.is_empty():
		return false
	var entries_start := text.find("entries = {")
	var entries_end := text.find("\n}", entries_start)
	if entries_start < 0 or entries_end < 0:
		push_error("索引缺少 entries 块：" + path)
		return false
	var block := text.substr(entries_start, entries_end - entries_start)
	if block.contains("\n\"%s\":" % key):
		return true
	var insert_regex := RegEx.create_from_string("\\n\\\"([a-z0-9_]+)\\\":")
	var matches := insert_regex.search_all(block)
	if matches.is_empty():
		push_error("索引 entries 为空：" + path)
		return false
	var new_line := "\n\"%s\": %s," % [key, value_text]
	var insert_pos := -1
	for match in matches:
		if str(match.get_string(1)) > key:
			insert_pos = match.get_start()
			break
	if insert_pos >= 0:
		block = block.insert(insert_pos, new_line)
	else:
		var last_match: RegExMatch = matches[matches.size() - 1]
		var last_line_end := block.find("\n", last_match.get_start() + 1)
		if last_line_end < 0:
			last_line_end = block.length()
		var last_line := block.substr(last_match.get_start(), last_line_end - last_match.get_start())
		var tail := block.substr(last_line_end)
		block = block.substr(0, last_match.get_start()) + last_line.trim_suffix(",") + new_line.trim_suffix(",") + "," + tail
	text = text.substr(0, entries_start) + block + text.substr(entries_end)
	return _write_text(path, text)


## groups 为 {组名: [id, ...]} 字面量；仅当组存在且未含 id 时追加。
static func _index_append_group(path: String, group: String, id: String) -> bool:
	var text := _read_text(path)
	if text.is_empty():
		return false
	var group_pattern := "\"%s\": [" % group
	var group_pos := text.find(group_pattern)
	if group_pos < 0:
		push_error("索引缺少分组 %s：%s" % [group, path])
		return false
	if text.contains("\"%s\"]" % id) or text.contains("\"%s\", " % id):
		return true
	var close_pos := text.find("]", group_pos)
	text = text.insert(close_pos, ", \"%s\"" % id)
	return _write_text(path, text)
