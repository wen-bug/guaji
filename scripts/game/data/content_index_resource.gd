@tool
class_name ContentIndexResource
extends Resource

@export_category("核心内容索引")
## 索引格式版本；解析器只接受明确支持的版本。
@export var format_version := 1
## 内容 ID 到资源路径（或带资源/场景路径的字典）的映射。
@export var entries: Dictionary = {}
## 供生成、筛选和兼容查询使用的有序分组。
@export var groups: Dictionary = {}
