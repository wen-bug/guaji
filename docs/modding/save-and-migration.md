# Mod 存档与迁移

GameState Schema 10 保存 `mod_profile`、`mod_data`、`mod_rng` 和 `orphaned_mod_data`。每个 `ModPlugin` 收到的 `storage` 都已绑定自己的 Mod ID，只能使用 `storage.get_value(key, fallback)`、`set_value(key, value)`、`erase_value(key)` 和 `all()` 访问该命名空间。值必须能由 Godot Variant/ConfigFile 序列化。

当已加载版本与存档 profile 不同，入口实例调用 `migrate_save(data, from_version, to_version)`。必须返回新的 Dictionary；返回其他类型会将该 Mod 标记为失败，并保留导入前数据。

缺失定义的背包实例、装备、技能、命格和配方会移入 `orphaned_mod_data`，不参与玩法。装备保留 owner 与 slot。相同内容 ID 恢复后，在普通存档清洗前还原原角色、槽位和列表。未知形象只回退显示，不删除 `visual_id`。

覆盖类 Mod 不改变内容 ID，因此不会触发休眠；作者负责让新定义兼容旧实例字段。



## Schema 16

存档新增 `market_state`，包含下一次免费刷新 Unix 时间、付费刷新次数、坊市独立 RNG 状态、6 个货架商品和 3 项委托。Schema 15 及更早存档首次加载时自动生成有效坊市状态，不修改已有角色、装备、物品、配方或进度。

免费刷新使用现实时间，离线期间到期只生成最新一轮，不累计多轮商品。系统时钟回退导致剩余时间超过 600 秒时，下一次刷新会修正为当前时间加 600 秒。Mod 物品首期不自动进入坊市池，Mod 存档命名空间和迁移接口保持不变。

## Schema 15

角色和招募候选新增 `enhance_pill_uses_by_tier` 与 `enhance_pill_uses_by_item`。前者保存各强化丹阶级的共享使用次数，后者按稳定 item_id 保存每种丹药的使用次数。旧存档缺少字段时自动初始化为空字典，所有已有属性、装备、技能和背包内容保持不变。

## Schema 14

存档新增 `reward_progress`：

- `valid_victories`：有效完整胜利数。
- `manual_fragment_progress`：功法残页五胜进度。
- `blueprint_pity`：图纸十胜保底进度。
- `unlocked_blueprints`：永久解锁的装备模板集合。

迁移会按角色实际等级重算阶段、等级上限和 `next_exp`，并按比例保留当前经验进度；装备只迁移固定阶位穿戴需求，保留属性、强化、洗练和归属。旧调息丹方会自动学习并从背包移除。

`equipment_level`、永久建筑品质和 `task_exp` 继续序列化以兼容旧档与 Mod，新逻辑不依赖旧语义。超出当前历练建筑上限的旧建筑不降级，但在历练追平前不可继续升级。
