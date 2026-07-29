# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 为原版 Big5 点阵字库补充简体 UI 点阵与最后一级繁体兼容映射。
## 原版已有字形始终优先；缺失简体字使用 GNU Unifont 补充图集，仍缺失时才复用繁体。
class_name PalClassicFont
extends RefCounted

const BASE_ATLAS_WIDTH := 512
const SUPPLEMENTAL_ATLAS_PATH := "res://assets/ui/pal_simplified_font.png"
const SUPPLEMENTAL_METADATA_PATH := "res://assets/ui/pal_simplified_glyphs.json"

# 当前自定义菜单、战斗 UI 与地点目录用到的简体字中，原版字库已有对应繁体
# 点阵的部分。映射只在简体键不存在时应用，未来导入真正简体字库时不会覆盖它。
const GLYPH_ALIASES := {
	"业": "業",
	"东": "東",
	"个": "個",
	"为": "為",
	"书": "書",
	"乱": "亂",
	"云": "雲",
	"产": "產",
	"亲": "親",
	"伤": "傷",
	"侠": "俠",
	"儿": "兒",
	"关": "關",
	"兽": "獸",
	"内": "內",
	"军": "軍",
	"决": "決",
	"凤": "鳳",
	"刘": "劉",
	"剑": "劍",
	"动": "動",
	"区": "區",
	"医": "醫",
	"单": "單",
	"厅": "廳",
	"厢": "廂",
	"双": "雙",
	"叹": "嘆",
	"员": "員",
	"园": "園",
	"圣": "聖",
	"场": "場",
	"坏": "壞",
	"坛": "壇",
	"墙": "牆",
	"备": "備",
	"奖": "獎",
	"娇": "嬌",
	"娲": "媧",
	"宝": "寶",
	"并": "並",
	"宫": "宮",
	"将": "將",
	"尽": "盡",
	"层": "層",
	"岗": "崗",
	"岛": "島",
	"师": "師",
	"庙": "廟",
	"废": "廢",
	"开": "開",
	"当": "當",
	"径": "徑",
	"忆": "憶",
	"忧": "憂",
	"怀": "懷",
	"戏": "戲",
	"战": "戰",
	"传": "傳",
	"数": "數",
	"户": "戶",
	"扬": "揚",
	"择": "擇",
	"损": "損",
	"摆": "擺",
	"敌": "敵",
	"断": "斷",
	"无": "無",
	"显": "顯",
	"暂": "暫",
	"晋": "晉",
	"败": "敗",
	"术": "術",
	"杀": "殺",
	"杂": "雜",
	"来": "來",
	"栈": "棧",
	"树": "樹",
	"档": "檔",
	"梦": "夢",
	"楼": "樓",
	"欢": "歡",
	"残": "殘",
	"气": "氣",
	"汉": "漢",
	"没": "沒",
	"渊": "淵",
	"渔": "漁",
	"溃": "潰",
	"满": "滿",
	"灵": "靈",
	"点": "點",
	"炼": "煉",
	"犹": "猶",
	"独": "獨",
	"画": "畫",
	"盖": "蓋",
	"盘": "盤",
	"离": "離",
	"约": "約",
	"级": "級",
	"终": "終",
	"结": "結",
	"绝": "絕",
	"缚": "縛",
	"罗": "羅",
	"苏": "蘇",
	"药": "藥",
	"莲": "蓮",
	"莺": "鶯",
	"装": "裝",
	"订": "訂",
	"讨": "討",
	"议": "議",
	"论": "論",
	"诊": "診",
	"试": "試",
	"该": "該",
	"读": "讀",
	"谋": "謀",
	"贼": "賊",
	"资": "資",
	"钱": "錢",
	"赌": "賭",
	"据": "據",
	"赠": "贈",
	"载": "載",
	"辩": "辯",
	"还": "還",
	"这": "這",
	"连": "連",
	"迹": "跡",
	"选": "選",
	"遗": "遺",
	"遥": "遙",
	"铁": "鐵",
	"铺": "鋪",
	"锁": "鎖",
	"镇": "鎮",
	"长": "長",
	"门": "門",
	"闭": "閉",
	"间": "間",
	"队": "隊",
	"阴": "陰",
	"隐": "隱",
	"难": "難",
	"雾": "霧",
	"预": "預",
	"韩": "韓",
	"顶": "頂",
	"飞": "飛",
	"龙": "龍",
}

static var _supplemental_loaded: bool = false
static var _supplemental_glyphs: Dictionary = {}


## 返回补齐简体点阵与兼容别名后的新字形表；输入字典及其中已有字形不会被修改。
static func with_compatibility_aliases(glyphs: Dictionary) -> Dictionary:
	var resolved := glyphs.duplicate(true)
	for character: String in _load_supplemental_glyphs():
		if resolved.has(character):
			continue
		var values: Array = _supplemental_glyphs[character]
		if values.size() != 4:
			continue
		var shifted := values.duplicate()
		shifted[0] = int(shifted[0]) + BASE_ATLAS_WIDTH
		resolved[character] = shifted
	for simplified: String in GLYPH_ALIASES:
		var traditional: String = GLYPH_ALIASES[simplified]
		if not resolved.has(simplified) and resolved.has(traditional):
			resolved[simplified] = resolved[traditional]
	return resolved


## 加载经典字库图集，同时兼容包内导入纹理与桌面运行时生成的原始 PNG。
static func load_atlas_texture(path: String) -> Texture2D:
	var base_texture := _load_texture(path)
	if base_texture == null or path.get_file() != "font_atlas.png":
		return base_texture
	var supplemental_texture := _load_texture(SUPPLEMENTAL_ATLAS_PATH)
	if supplemental_texture == null:
		return base_texture
	var base_image := base_texture.get_image()
	var supplemental_image := supplemental_texture.get_image()
	if base_image == null or supplemental_image == null or base_image.get_width() != BASE_ATLAS_WIDTH:
		return base_texture
	base_image.convert(Image.FORMAT_RGBA8)
	supplemental_image.convert(Image.FORMAT_RGBA8)
	var combined := Image.create(
		base_image.get_width() + supplemental_image.get_width(),
		maxi(base_image.get_height(), supplemental_image.get_height()),
		false,
		Image.FORMAT_RGBA8
	)
	combined.fill(Color.TRANSPARENT)
	combined.blit_rect(base_image, Rect2i(Vector2i.ZERO, base_image.get_size()), Vector2i.ZERO)
	combined.blit_rect(supplemental_image, Rect2i(Vector2i.ZERO, supplemental_image.get_size()), Vector2i(BASE_ATLAS_WIDTH, 0))
	return ImageTexture.create_from_image(combined)


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		return ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return null if image.is_empty() else ImageTexture.create_from_image(image)


static func _load_supplemental_glyphs() -> Dictionary:
	if _supplemental_loaded:
		return _supplemental_glyphs
	_supplemental_loaded = true
	var metadata_file := FileAccess.open(SUPPLEMENTAL_METADATA_PATH, FileAccess.READ)
	if metadata_file == null:
		return _supplemental_glyphs
	var parsed = JSON.parse_string(metadata_file.get_as_text())
	if parsed is Dictionary and parsed.get("glyphs") is Dictionary:
		_supplemental_glyphs = parsed["glyphs"]
	return _supplemental_glyphs
