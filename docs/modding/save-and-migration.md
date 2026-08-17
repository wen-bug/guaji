# Mod 存档与迁移

GameState Schema 10 保存 `mod_profile`、`mod_data`、`mod_rng` 和 `orphaned_mod_data`。每个 `ModPlugin` 收到的 `storage` 都已绑定自己的 Mod ID，只能使用 `storage.get_value(key, fallback)`、`set_value(key, value)`、`erase_value(key)` 和 `all()` 访问该命名空间。值必须能由 Godot Variant/ConfigFile 序列化。

当已加载版本与存档 profile 不同，入口实例调用 `migrate_save(data, from_version, to_version)`。必须返回新的 Dictionary；返回其他类型会将该 Mod 标记为失败，并保留导入前数据。

缺失定义的背包实例、装备、技能、命格和配方会移入 `orphaned_mod_data`，不参与玩法。装备保留 owner 与 slot。相同内容 ID 恢复后，在普通存档清洗前还原原角色、槽位和列表。未知形象只回退显示，不删除 `visual_id`。

覆盖类 Mod 不改变内容 ID，因此不会触发休眠；作者负责让新定义兼容旧实例字段。


## Schema 14

存档新增 `reward_progress`：

- `valid_victories`：有效完整胜利数。
- `manual_fragment_progress`：功法残页五胜进度。
- `blueprint_pity`：图纸十胜保底进度。
- `unlocked_blueprints`：永久解锁的装备模板集合。

迁移会按角色实际等级重算阶段、等级上限和 `next_exp`，并按比例保留当前经验进度；装备只迁移固定阶位穿戴需求，保留属性、强化、洗练和归属。旧调息丹方会自动学习并从背包移除。

`equipment_level`、永久建筑品质和 `task_exp` 继续序列化以兼容旧档与 Mod，新逻辑不依赖旧语义。超出当前历练建筑上限的旧建筑不降级，但在历练追平前不可继续升级。
