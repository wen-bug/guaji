# 安全与排错

GDScript Mod 没有沙箱。代码可以读写用户文件、访问网络、调用操作系统接口并挂起游戏。只启用可信来源；游戏只能阻止资源路径覆盖和未授权的逻辑 ID patch，不能限制恶意代码。

常见状态：

- permission_required：当前代码版本尚未授权。
- invalid：包结构、Manifest、版本或路径无效。
- disabled：用户关闭、依赖缺失、循环或冲突。
- failed：内容、引用、入口类型或注册事务失败。
- loaded：本次启动已加载。

排错顺序：管理面板首条错误、`user://logs/godot.log`、Manifest Schema、内容 Schema、资源是否已由 Godot 导入。启停、排序、授权均需重启。
