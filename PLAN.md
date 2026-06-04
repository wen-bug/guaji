# 炼丹 UI：图纸槽位、材料槽位与手动批量制作

## Summary
- 重做 `AlchemyPanel` 为“图纸槽位 → 材料槽位 → 数量选择 → 制作按钮”的炼丹界面。
- 图纸选择使用**炼丹面板内嵌图纸列表**，不复用完整背包面板。
- 点击图纸槽位打开内嵌图纸列表；点击图纸后自动选中配方并关闭列表。
- 材料槽位显示材料图标占位、名称、右下角 `当前数量/需要数量`。
- 底部使用手动数量选择，默认填入当前材料最多可制作数量。

## Key Changes
- **数据接口**
  - 新增 `DataTables.ALCHEMY_RECIPE_DEFS`，按丹药 ID 定义配方材料。
  - 每条配方包含：
    - `recipe_id`：丹药 ID，例如 `attack_pill`
    - `result_item_id`：产物 ID
    - `materials`：材料数组，每项包含 `item_id` 和 `amount`
  - 属性丹药使用已文档化材料：
    - `attack_pill`: `blade_grass ×2`、`rice ×1`、`stat_stone_attack_t1 ×1`
    - `fire_pill`: `flame_flower ×2`、`spirit_sand ×1`、`spirit_stone_fire_t1 ×1`
    - 其他属性丹按 `docs/item-table.md` 的“属性丹药配方材料”表补齐。
  - 新增查询函数：
    - `DataTables.alchemy_recipe_def(recipe_id)`
    - `DataTables.alchemy_recipe_materials(recipe_id)`
    - `DataTables.alchemy_recipe_result(recipe_id)`

- **炼丹逻辑**
  - `GameState` 新增 `alchemy_max_craft_count(recipe_id)`，根据材料库存返回最大可制作数量。
  - `GameState` 新增 `craft_alchemy_recipe(recipe_id, amount)`：
    - 要求 `recipe_id` 已在 `known_alchemy_recipes`。
    - 要求 `amount >= 1` 且材料足够。
    - 按 `amount` 批量扣除每种材料。
    - 添加产物丹药 `amount` 个。
    - 额外出丹概率暂按每次制作独立结算，使用现有 `alchemy_extra_chance()`。
  - 保留旧炼丹入口兼容：如果没有 UI 选中配方，旧任务逻辑仍可随机从已学丹方产出。

- **AlchemyPanel UI**
  - 扩大 `Root/AlchemyPanel` 尺寸，容纳槽位和列表。
  - 节点结构建议：
    - `RecipeSlotButton`：图纸槽位按钮，显示“选择图纸”或已选丹方名。
    - `RecipePickerPanel`：内嵌图纸列表容器，默认隐藏。
    - `RecipeList`：只列出背包内 `alchemy_recipe` 类型图纸。
    - `MaterialGrid`：材料槽位网格，按配方材料动态刷新。
    - `CraftCountSpinBox`：手动选择制作数量，最小 1，最大为材料可制作数量。
    - `CraftButton`：制作指定数量。
    - `MaxCountLabel`：显示“最多可做：N”。
  - 材料槽位使用 `PanelContainer` 或 `Button` 预留美术素材：
    - `IconPlaceholder`：空 `TextureRect`，后续可替换图标。
    - `NameLabel`：材料名。
    - `CountLabel`：右下角显示 `当前/需要`，例如 `6/2`。
    - 材料不足时 `CountLabel` 标红，制作按钮禁用。

- **交互规则**
  - 点击 `RecipeSlotButton`：
    - 刷新并显示 `RecipePickerPanel`。
    - 列表只显示背包中持有的图纸，格式为 `丹方名 x数量`。
  - 点击 `RecipeList` 中图纸：
    - 读取图纸 payload 的 `recipe_id`。
    - 设置为当前炼丹配方。
    - 隐藏 `RecipePickerPanel`。
    - 刷新材料槽位、最大可做数量和数量选择器。
  - 点击 `CraftButton`：
    - 调用 `craft_alchemy_recipe(selected_recipe_id, CraftCountSpinBox.value)`。
    - 成功后刷新材料槽、背包图纸列表、最大可做数量。
    - 材料不足或未选图纸时禁用按钮并显示提示文案。

## Test Plan
- **GameState**
  - 已学配方且材料足够时，`alchemy_max_craft_count()` 返回正确最大数量。
  - 批量制作会按数量扣除所有材料，并添加对应丹药。
  - 材料不足、未学习配方、数量为 0 时制作失败且不扣材料。
  - 额外出丹不会减少额外材料消耗，只增加产物数量。

- **HUD / UI**
  - `AlchemyPanel` 存在 `RecipeSlotButton`、`RecipePickerPanel`、`RecipeList`、`MaterialGrid`、`CraftCountSpinBox`、`CraftButton`。
  - 点击图纸槽位会显示内嵌图纸列表。
  - 点击图纸后列表隐藏，图纸槽位显示丹方名，材料槽位刷新。
  - 材料槽位右下角显示 `当前/需要`。
  - 最大可做数量为 0 时制作按钮禁用。
  - 手动数量不能超过最大可做数量。
  - 批量制作后库存和材料槽位显示同步刷新。

## Assumptions
- 图纸选择采用用户选择的“炼丹内嵌列表”，不打开完整 `InventoryPanel`。
- 批量制作采用用户选择的“手动选数量”，默认数量为当前最大可做数。
- 现阶段不接入真实美术素材，只预留 `TextureRect`/槽位节点，后续替换贴图即可。
- 现有旧炼丹任务逻辑保留兼容，不阻塞这次 UI 改造。
