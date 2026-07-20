# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h STORE.
# SPDX-License-Identifier: GPL-3.0-or-later
## `DATA.MKF #0` 的经典商店定义；每条记录最多保存九个物品对象编号。
class_name PalStoreDefinition
extends RefCounted

const ITEM_COUNT := 9
const BYTE_SIZE := ITEM_COUNT * 2

var store_id: int = 0
var item_ids: PackedInt32Array = PackedInt32Array()


## 从 DATA.MKF 商店分块解析一条记录；字节范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalStoreDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var store := PalStoreDefinition.new()
	store.store_id = id
	for item_index in range(ITEM_COUNT):
		var item_id := PalBinary.u16_le(data, offset + item_index * 2)
		if item_id > 0:
			store.item_ids.append(item_id)
	return store
