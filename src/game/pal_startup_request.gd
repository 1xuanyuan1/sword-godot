# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 启动场景与探索场景之间的一次性请求邮箱，目前用于从资源实验室读取正式存档。
## 它只传递槽位编号；存档内容仍由探索场景中的 `PalSaveManager` 重新校验和恢复。
class_name PalStartupRequest
extends RefCounted

static var _pending_load_slot: int = 0


## 请求下一次进入探索场景时读取 `slot`；槽位越界时清空请求并返回 `false`。
static func request_load_slot(slot: int) -> bool:
	if slot < 1 or slot > PalSaveManager.SLOT_COUNT:
		_pending_load_slot = 0
		return false
	_pending_load_slot = slot
	return true


## 取走并清空待读取槽位；没有请求时返回 0，保证一次选择不会在后续新游戏中重放。
static func consume_load_slot() -> int:
	var slot := _pending_load_slot
	_pending_load_slot = 0
	return slot
