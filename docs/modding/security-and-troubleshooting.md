# Mod 安全与排错

GDScript Mod 没有沙箱。代码可以访问用户文件、网络和操作系统接口，也可以挂起游戏。只启用可信来源；游戏只能限制资源路径覆盖和未授权逻辑 ID patch，不能约束恶意代码。

## 状态

- `permission_required`：当前代码版本尚未授权。
- `invalid`：包结构、Manifest、版本或路径无效。
- `disabled`：用户关闭、依赖缺失、循环或冲突。
- `failed`：内容、引用、资源契约、入口类型或注册事务失败。
- `loaded`：本次启动已加载。

## 排错顺序

1. 查看 Mod 管理面板首条错误。
2. 查看 `user://logs/godot.log`。
3. 对照 [Manifest 2](schemas/v2/manifest.schema.json) 和[内容 Schema 2](schemas/v2/content.schema.json)。
4. 确认资源已经由 Godot 导入，且所有 `*_path` 位于当前 Mod 目录。
5. 确认技能、状态和形象场景满足对应根节点及动画契约。

启停、排序和授权均需重启。API 2 不支持运行中热加载。
