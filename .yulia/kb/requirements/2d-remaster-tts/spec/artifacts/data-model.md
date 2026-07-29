---
name: '2D 高清重制数据模型'
summary: '定义 2D 资源包、地图 TileSet、人物 Atlas、世界快照、MOD、TTS 与章节验收实体。'
keywords: ['data model', 'tileset', 'sprite atlas', 'TTS', 'MOD']
---

# 数据模型

## RemasterAssetPack / Entry

- Pack：`schema_version`、`pack_id`、`asset_version`、`chapter`、`assets`。
- Entry：`id`、`type`、`path`、`sha256`、`generation`、`source_references`、`fallback_asset_id`、`review_status`。
- 类型：`map_tileset`、`field_sprite`、`portrait`、`battlefield`、`battle_action`、`cutscene`、`voice`、`ui_theme`。
- 状态：`draft → generated → technical_review → approved`；`rejected` 不进入正式路径。

## PalMapTilesetManifest

- `map_number`、`source_frame_count`、`scale=5`、`tile_cell_px=[160,80]`、`content_px=[160,75]`。
- `image` 与 `frames[]`；每帧包含唯一 `source_frame_index` 和 Atlas `rect`。
- 可选 `night_image`；未提供时由高清 CanvasItem 调色 Shader 表达夜景。
- 校验器结合原 MAP/GOP，确认地图实际引用帧全部覆盖、无越界、无重复。

## PalSpriteAtlas

- `source_sprite_number`、`source_frame_count`、`scale=5`、`image`、`canvas_size`、`frames[]`。
- 每帧：`source_frame_index`、`rect`、`pivot`、`alpha_bounds`、`duration_ms`。
- `source_frame_index` 必须唯一且与原 MGO 选帧一一对应；同一 Atlas 所有帧共用画布坐标和脚底原点。

## ArtGenerationRecord

- `skill`、`skill_version`、`mode`、`provider=bitto`、`model`、`protocol`。
- `input_paths`、`input_sha256`、`prompt_version`、`requested_size`、`actual_size`、`output_sha256`。
- `review_status` 与 `review_notes`；文件名版本化，不覆盖旧候选。

## PalWorldPresentationSnapshot / Actor

- Snapshot：`scene_index`、`map_number`、`night_palette`、`camera_offset`、`camera_center_pal`、party/events/followers。
- Actor：`logical_id`、`source_object_id`、`pal_world_position`、`direction`、`frame_index`、`logical_layer`、`visible`。
- 均为只读视图数据；不含 3D 坐标，不修改 GameSession/EventObject。

## ModPack

- `pack_id`、`version`、`priority`、`enabled`、`entries`。
- v1 类型白名单：portrait、field_sprite、voice、ui_theme；禁止脚本、路径穿越和地图逻辑覆盖。

## TtsManifest / TtsItem

- 第一章 Manifest 使用 MiniMax `speech-2.8-hd`、32kHz/128kbps/单声道中间音频与 Ogg 运行时文件。
- Entry 包含 `dialog_round_id`、`message_ids`、`speaker_id`、`role`、`text_sha256`、声线设置、输出路径和音频哈希。
- 运行时索引键是完整 `message_ids` 序列。

## ChapterAcceptance

- `chapter`、`code_commit`、`asset_tag`、`asset_lock_sha256` 与资源覆盖计数。
- 门禁：synthetic、mainline、tilemap、windowed_visual、performance、art_review、audio_review、rights_review。
