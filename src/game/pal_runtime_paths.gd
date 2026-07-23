# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 区分源码工程与桌面导出包的本地生成内容目录。
## 编辑器继续使用被 Git 忽略的 `res://generated/pal`；导出包必须写入可写的 `user://`。
class_name PalRuntimePaths
extends RefCounted

const EDITOR_GENERATED_ROOT := "res://generated/pal"
const EXPORTED_GENERATED_ROOT := "user://generated/pal"


## 返回当前运行环境应使用的 PAL 生成内容根目录。
static func generated_root() -> String:
	return generated_root_for(OS.has_feature("editor"))


## 按明确的编辑器标记返回根目录；该入口也供无平台依赖的发布路径测试使用。
static func generated_root_for(editor_build: bool) -> String:
	return EDITOR_GENERATED_ROOT if editor_build else EXPORTED_GENERATED_ROOT


## 返回当前运行环境的内容数据库目录。
static func content_root() -> String:
	return generated_root().path_join("content")


## 在当前生成内容根目录下拼接相对路径。
static func generated_path(relative_path: String) -> String:
	return generated_root().path_join(relative_path.trim_prefix("/"))
