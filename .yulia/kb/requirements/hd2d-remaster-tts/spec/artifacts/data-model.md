---
name: 'HD-2D 重构数据模型'
summary: '定义资源包、资源条目、世界快照、MOD、TTS 与章节验收实体。'
keywords: ['data model', 'asset manifest', 'TTS', 'MOD']
---

# 数据模型

## RemasterAssetPack

- `schema_version: String`：当前为 `1.0.0`。
- `pack_id: String`、`asset_version: String`、`chapter: int`。
- `assets: Array[RemasterAssetEntry]`。
- 状态：`draft → generated → technical_review → approved`；rejected 条目不得进入正式高清路径。

## RemasterAssetEntry

- `id: String`：稳定命名空间 ID。
- `type: String`：environment、field_sprite、portrait、battlefield、battle_action、cutscene、voice、ui_theme。
- `path: String`：包内相对路径，禁止绝对路径和 `..`。
- `sha256: String`：64 位十六进制。
- `generation`: 生成服务、模型、协议、提示词清单 ID 和请求尺寸。
- `source_references: Array[String]`：素材来源与权利审核引用。
- `fallback_asset_id: String`：可选的下一层逻辑 ID。
- `review_status: String`：draft/generated/technical_review/approved/rejected。

## PalWorldPresentationSnapshot

- `scene_index`、`map_number`、`night_palette`、`camera_offset`。
- `party: Array[PalPresentationActor]`、`events: Array[PalPresentationActor]`。
- 只读视图数据；不得持有或修改 GameSession/EventObject。

## PalPresentationActor

- `logical_id`、`source_object_id`、`pal_world_position`、`world_position_3d`。
- `direction`、`frame_index`、`logical_layer`、`visible`、`is_party_member`。

## ModPack

- `pack_id`、`version`、`priority`、`enabled`、`entries`。
- `enabled` 省略时默认为 true；高 priority 包覆盖低 priority 包。
- v1 类型白名单：portrait、field_sprite、voice、ui_theme。
- 禁止脚本、绝对路径、路径穿越和未声明类型。

## TtsManifest / TtsItem

- Manifest 保存 `speech-2.8-hd` 模型、32kHz/128kbps/单声道音频配置和 `entries`。
- Entry 包含 `dialog_round_id`、`message_ids`、`speaker_id`、`role`、`text`、`text_sha256`、`voice_id/voice_settings`、`output_path`、`audio_sha256`。
- 运行时索引键为完整 `message_ids` 序列，不是显示文本或说话人标题。

## ChapterAcceptance

- `chapter`、`code_commit`、`asset_tag`、`asset_lock_sha256`。
- 覆盖计数：maps、scenes、characters、portraits、battlefields、battle_actions、cutscenes、voice_rounds。
- 门禁：synthetic、mainline、tilemap、windowed_visual、performance、audio_review、rights_review。
