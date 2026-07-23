# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 区分源码工程、内置内容的 Web／Android 包与桌面导出包的本地生成内容目录。
## 编辑器／内置包使用 `res://generated/pal`；桌面包首次导入必须写入可写的 `user://`。
class_name PalRuntimePaths
extends RefCounted

const EDITOR_GENERATED_ROOT := "res://generated/pal"
const EXPORTED_GENERATED_ROOT := "user://generated/pal"


## 返回当前运行环境应使用的 PAL 生成内容根目录。
static func generated_root() -> String:
	return generated_root_for(OS.has_feature("editor"), OS.has_feature("web") or OS.has_feature("android"))


## 按明确的编辑器／内置内容标记返回根目录；该入口也供无平台依赖的发布路径测试使用。
static func generated_root_for(editor_build: bool, bundled_content_build: bool = false) -> String:
	return EDITOR_GENERATED_ROOT if editor_build or bundled_content_build else EXPORTED_GENERATED_ROOT


## 返回当前运行环境的内容数据库目录。
static func content_root() -> String:
	return generated_root().path_join("content")


## 在当前生成内容根目录下拼接相对路径。
static func generated_path(relative_path: String) -> String:
	return generated_root().path_join(relative_path.trim_prefix("/"))
