# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 一次资源校验/导入的结构化结果，供 UI、CLI 和 `manifest.json` 共用。
## 报告不包含原版文件内容，只记录统计、诊断和本地输出路径。
class_name PalImportReport
extends RefCounted

const FORMAT_VERSION := 2

## 用户选择的源数据目录。
var source_directory: String = ""
## 本次生成产物目录。
var output_directory: String = ""
## 所有必需步骤是否没有错误。
var success: bool = false
## 阻止导入完成的诊断。
var errors: Array[String] = []
## 不阻止基础导入但需要用户注意的诊断。
var warnings: Array[String] = []
## 按转换步骤保存的数量、路径和详细结果。
var files: Dictionary = {}
## 资源实验室优先展示的本地预览路径。
var preview_path: String = ""
## 写入的清单路径。
var manifest_path: String = ""
## 根据文本编码和结构识别的源版本说明。
var source_edition: String = "DOS PAL candidate"


## 返回适合 UI 状态栏显示的中文摘要。
func summary() -> String:
	if success:
		return "校验完成：%d 个文件，%d 条警告" % [files.size(), warnings.size()]
	return "校验失败：%d 个错误，%d 条警告" % [errors.size(), warnings.size()]


## 转为可安全写入 JSON 的清单字典，不包含原版资源字节。
func to_dictionary() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"source_edition": source_edition,
		"source_directory": source_directory,
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"files": files,
		"warnings": warnings,
	}
