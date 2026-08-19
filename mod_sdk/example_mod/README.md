# 示例 Mod

从仓库根目录构建：

```powershell
godot --headless --path . --script mod_sdk/example_mod/build_mod.gd -- example_mod.pck
```

将生成的 PCK 放入游戏的 `user://mods/`，在 Mod 管理器启用，确认代码权限并重启。示例覆盖技能场景与资源、技能书、形象、条件对白、自定义效果处理器、角色状态、隔离存储、可复现 RNG 生命周期和存档迁移。

示例使用 Manifest/内容 Schema 2 和 Mod API 2。以 `.gd.txt`、`.tscn.txt` 或 `.tres.txt` 结尾的文件是模板；构建脚本会移除最后的 `.txt`，因此 PCK 中使用正常的 Godot 资源路径，同时不会让示例资源参与本体导入。
