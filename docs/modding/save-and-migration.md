# Mod 存档与迁移

GameState Schema 10 保存 `mod_profile`、`mod_data`、`mod_rng` 和 `orphaned_mod_data`。每个 `ModPlugin` 收到的 `storage` 都已绑定自己的 Mod ID，只能使用 `storage.get_value(key, fallback)`、`set_value(key, value)`、`erase_value(key)` 和 `all()` 访问该命名空间。值必须能由 Godot Variant/ConfigFile 序列化。

当已加载版本与存档 profile 不同，入口实例调用 `migrate_save(data, from_version, to_version)`。必须返回新的 Dictionary；返回其他类型会将该 Mod 标记为失败，并保留导入前数据。

缺失定义的背包实例、装备、技能、命格和配方会移入 `orphaned_mod_data`，不参与玩法。装备保留 owner 与 slot。相同内容 ID 恢复后，在普通存档清洗前还原原角色、槽位和列表。未知形象只回退显示，不删除 `visual_id`。

覆盖类 Mod 不改变内容 ID，因此不会触发休眠；作者负责让新定义兼容旧实例字段。
