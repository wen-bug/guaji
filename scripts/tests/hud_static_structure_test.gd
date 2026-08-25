extends Node

const HUD_SCENE := preload("res://scripts/ui/hud.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	_check_static_nodes(hud)
	_check_single_initialization(hud)
	_check_global_buff_details(hud)
	hud.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("HUD_STATIC_STRUCTURE_PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_static_nodes(hud: Node) -> void:
	var required_paths := [
		"Root/MenuPanel/MenuLayout/MarketButton",
		"Root/MenuPanel/MenuLayout/GlobalItemBuffStatus",
		"Root/GlobalBuffPanel/PanelLayout/Header/CloseButton",
		"Root/GlobalBuffPanel/PanelLayout/EmptyState",
		"Root/GlobalBuffPanel/PanelLayout/BuffScroll/BuffSections/HomeSection/Rows",
		"Root/GlobalBuffPanel/PanelLayout/BuffScroll/BuffSections/CombatSection/Rows",
		"Root/MarketPanel/PanelLayout/MarketTabs/货架/OfferGrid",
		"Root/MarketPanel/PanelLayout/MarketTabs/委托/CommissionList",
		"Root/MarketPanel/PanelLayout/MarketTabs/回收/RecycleItemOption",
		"Root/InventoryPanel/InventoryLayout/CategoryRow/BlueprintButton",
		"Root/InventoryPanel/InventoryLayout/AutoItemSection/Slots/AutoItemSlot1",
		"Root/InventoryPanel/InventoryLayout/AutoItemSection/Slots/AutoItemSlot4",
		"Root/ForgePanel/PanelLayout/ModeRow/ForgeAscendButton",
		"Root/ForgePanel/PanelLayout/ForgeTargetOption",
		"Root/ForgePanel/PanelLayout/BlueprintForgeRow/TargetForgeButton",
		"Root/ForgePanel/PanelLayout/SpiritStoneRow/SpiritStoneConvertButton",
		"Root/RecruitPanel/PanelLayout/RecruitModeRow/ManualModeButton",
		"Root/RecruitPanel/PanelLayout/ManualExchangePage/ManualExchangeList",
		"Root/FarmPanel/PanelLayout/FarmUpgradeButton",
		"Root/ForgePanel/PanelLayout/ForgeUpgradeButton",
		"Root/AlchemyPanel/PanelLayout/AlchemyUpgradeButton",
		"Root/RecruitPanel/PanelLayout/RecruitUpgradeButton",
		"Root/SalvageConfirmationDialog",
		"Root/MarketRecycleConfirmation",
		"AutoItemPicker",
	]
	for path in required_paths:
		_expect_true("static node %s" % path, hud.has_node(path))
	_expect_true("global status is button", hud.get_node("Root/MenuPanel/MenuLayout/GlobalItemBuffStatus") is Button)
	_expect_equal("inventory slots", hud.get_node("Root/InventoryPanel/InventoryLayout/InventoryGrid").get_child_count(), 25)
	_expect_equal("auto item slots", hud.get_node("Root/InventoryPanel/InventoryLayout/AutoItemSection/Slots").get_child_count(), 4)
	for method_name in [
		"_ensure_menu_panel_refs",
		"_ensure_market_controls",
		"_ensure_equipment_loop_controls",
		"_ensure_progression_exchange_controls",
		"_ensure_auto_item_controls",
		"_ensure_building_upgrade_button",
	]:
		_expect_true("removed method %s" % method_name, not hud.has_method(method_name))


func _check_single_initialization(hud: Node) -> void:
	var signal_paths := [
		"Root/MenuPanel/MenuLayout/MarketButton",
		"Root/MenuPanel/MenuLayout/GlobalItemBuffStatus",
		"Root/GlobalBuffPanel/PanelLayout/Header/CloseButton",
		"Root/ForgePanel/PanelLayout/ModeRow/ForgeAscendButton",
		"Root/ForgePanel/PanelLayout/BlueprintForgeRow/TargetForgeButton",
		"Root/FarmPanel/PanelLayout/FarmUpgradeButton",
		"Root/ForgePanel/PanelLayout/ForgeUpgradeButton",
		"Root/AlchemyPanel/PanelLayout/AlchemyUpgradeButton",
		"Root/RecruitPanel/PanelLayout/RecruitUpgradeButton",
		"Root/InventoryPanel/InventoryLayout/AutoItemSection/Slots/AutoItemSlot1",
		"Root/InventoryPanel/InventoryLayout/AutoItemSection/Slots/AutoItemSlot2",
		"Root/InventoryPanel/InventoryLayout/AutoItemSection/Slots/AutoItemSlot3",
		"Root/InventoryPanel/InventoryLayout/AutoItemSection/Slots/AutoItemSlot4",
	]
	for path in signal_paths:
		var button := hud.get_node(path) as Button
		_expect_equal("single pressed connection %s" % path, button.pressed.get_connections().size(), 1)
	var state := GameState.new()
	hud.refresh(state)
	hud.refresh(state)
	hud.show_home_action_panel(GameDefs.TaskType.FORGE)
	_expect_true("blueprint row visible in craft mode", hud.get_node("Root/ForgePanel/PanelLayout/BlueprintForgeRow").visible)
	hud.call("_set_forge_mode", "ascend")
	_expect_true("blueprint row hidden outside craft mode", not hud.get_node("Root/ForgePanel/PanelLayout/BlueprintForgeRow").visible)
	for path in signal_paths:
		var button := hud.get_node(path) as Button
		_expect_equal("stable pressed connection %s" % path, button.pressed.get_connections().size(), 1)


func _check_global_buff_details(hud: Node) -> void:
	var state := GameState.new()
	state.active_item_buffs = [
		{
			"buff_id": "farm_speed",
			"source_item_id": "farm_speed_talisman",
			"target": "home_global",
			"member_id": "",
			"stat": "farm_speed",
			"operation": "percent",
			"value": 0.5,
			"stacks": 2,
			"remaining_seconds": 65.0,
		},
		{
			"buff_id": "attack_pill_buff",
			"source_item_id": "attack_pill",
			"target": "combat_global",
			"member_id": "",
			"stat": "attack",
			"operation": "flat",
			"value": 3.0,
			"stacks": 1,
			"remaining_seconds": 8.2,
		},
		{
			"buff_id": "member_only",
			"source_item_id": "attack_pill",
			"target": "member",
			"member_id": "member_1",
			"stat": "attack",
			"operation": "flat",
			"value": 99.0,
			"stacks": 1,
			"remaining_seconds": -1.0,
		},
	]
	hud.refresh(state)
	var status_button := hud.get_node("Root/MenuPanel/MenuLayout/GlobalItemBuffStatus") as Button
	var panel := hud.get_node("Root/GlobalBuffPanel") as PanelContainer
	var home_rows := hud.get_node("Root/GlobalBuffPanel/PanelLayout/BuffScroll/BuffSections/HomeSection/Rows") as VBoxContainer
	var combat_rows := hud.get_node("Root/GlobalBuffPanel/PanelLayout/BuffScroll/BuffSections/CombatSection/Rows") as VBoxContainer
	_expect_equal("global status count excludes member buffs", status_button.text, "全局效果 · 2")
	_expect_equal("global status icon follows source config", status_button.icon, DataTables.item_icon_texture("farm_speed_talisman"))
	_expect_equal("home buff row count", home_rows.get_child_count(), 1)
	_expect_equal("combat buff row count", combat_rows.get_child_count(), 1)
	var home_row := home_rows.get_child(0)
	var combat_row := combat_rows.get_child(0)
	_expect_equal("home buff source", home_row.get_node("RowLayout/SourceColumn/SourceLabel").text, "丰收符")
	_expect_equal("home buff scope", home_row.get_node("RowLayout/SourceColumn/ScopeLabel").text, "家园全局")
	_expect_equal("stacked percent bonus", home_row.get_node("RowLayout/RightColumn/BonusLabel").text, "农田速度 +100%")
	_expect_equal("stack count", home_row.get_node("RowLayout/RightColumn/MetaRow/StackLabel").text, "2层")
	_expect_equal("home countdown", home_row.get_node("RowLayout/RightColumn/MetaRow/TimeLabel").text, "01:05")
	_expect_equal("combat buff scope", combat_row.get_node("RowLayout/SourceColumn/ScopeLabel").text, "战斗全队")
	_expect_equal("flat bonus", combat_row.get_node("RowLayout/RightColumn/BonusLabel").text, "攻击 +3")
	_expect_equal("near expiry countdown", combat_row.get_node("RowLayout/RightColumn/MetaRow/TimeLabel").text, "00:09")

	var home_row_id := home_row.get_instance_id()
	state.active_item_buffs[0]["remaining_seconds"] = 64.0
	hud.refresh(state)
	_expect_equal("countdown refresh preserves row", home_rows.get_child(0).get_instance_id(), home_row_id)
	_expect_equal("countdown refresh updates label", home_rows.get_child(0).get_node("RowLayout/RightColumn/MetaRow/TimeLabel").text, "01:04")

	state.active_item_buffs[0]["stacks"] = 3
	hud.refresh(state)
	_expect_true("stack change rebuilds row", home_rows.get_child(0).get_instance_id() != home_row_id)
	_expect_equal("rebuilt stacked bonus", home_rows.get_child(0).get_node("RowLayout/RightColumn/BonusLabel").text, "农田速度 +150%")

	status_button.pressed.emit()
	_expect_true("global panel opens", panel.visible)
	_expect_true("menu closes for global panel", not hud.get_node("Root/MenuPanel").visible)
	var saved_position := Vector2(250.0, 96.0)
	panel.position = saved_position
	var save_data: Dictionary = hud.to_hud_save_data()
	panel.position = Vector2.ZERO
	hud.load_hud_save_data(save_data)
	_expect_equal("global panel position restored and clamped", panel.position, hud.call("_clamp_panel_position", panel, saved_position))

	state.active_item_buffs.clear()
	hud.refresh(state)
	_expect_equal("empty global status", status_button.text, "全局效果 · 0")
	_expect_equal("expired rows removed", home_rows.get_child_count() + combat_rows.get_child_count(), 0)
	_expect_true("empty state visible", hud.get_node("Root/GlobalBuffPanel/PanelLayout/EmptyState").visible)


func _expect_true(label: String, condition: bool) -> void:
	if not condition:
		failures.append("%s: expected true" % label)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
