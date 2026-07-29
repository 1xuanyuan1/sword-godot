# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 在 Web 导出中使用浏览器系统字体把未知运行时文字同步生成为透明纹理。
## 仅用于 Toy 昵称等构建时无法预知的文本；静态游戏 UI 继续使用经典点阵字库。
class_name PalWebTextRenderer
extends RefCounted

const FONT_CSS := '400 16px "PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans SC", sans-serif'
const TEXTURE_HEIGHT := 20
const ALPHA_THRESHOLD := 128

const RENDER_SCRIPT_TEMPLATE := """
(() => {
  const value = __TEXT__;
  const maximumWidth = __MAXIMUM_WIDTH__;
  const font = __FONT__;
  const measureCanvas = document.createElement("canvas");
  const measureContext = measureCanvas.getContext("2d");
  if (!measureContext) return JSON.stringify({ success: false, error: "canvas unavailable" });
  measureContext.font = font;
  const characters = Array.from(value);
  let fitted = value;
  if (measureContext.measureText(fitted).width > maximumWidth) {
    const suffix = "…";
    while (characters.length && measureContext.measureText(characters.join("") + suffix).width > maximumWidth) {
      characters.pop();
    }
    fitted = characters.join("") + suffix;
  }
  const width = Math.max(1, Math.min(maximumWidth, Math.ceil(measureContext.measureText(fitted).width) + 2));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = __TEXTURE_HEIGHT__;
  const context = canvas.getContext("2d");
  if (!context) return JSON.stringify({ success: false, error: "canvas unavailable" });
  context.font = font;
  context.textAlign = "left";
  context.textBaseline = "middle";
  context.fillStyle = "#ffffff";
  context.fillText(fitted, 0, __TEXT_MIDDLE__);
  return JSON.stringify({
    success: true,
    text: fitted,
    png: canvas.toDataURL("image/png").split(",")[1],
  });
})()
"""


## 使用浏览器系统字体渲染 `text`；非 Web 环境或浏览器失败时返回空字典。
static func render(text: String, maximum_width: int) -> Dictionary:
	if not OS.has_feature("web") or text.is_empty() or maximum_width <= 0:
		return {}
	var script := RENDER_SCRIPT_TEMPLATE
	script = script.replace("__TEXT__", JSON.stringify(text))
	script = script.replace("__MAXIMUM_WIDTH__", str(maximum_width))
	script = script.replace("__FONT__", JSON.stringify(FONT_CSS))
	script = script.replace("__TEXTURE_HEIGHT__", str(TEXTURE_HEIGHT))
	script = script.replace("__TEXT_MIDDLE__", str(TEXTURE_HEIGHT / 2))
	var raw_result = JavaScriptBridge.eval(script, true)
	if raw_result is not String:
		return {}
	var result = JSON.parse_string(raw_result)
	if result is not Dictionary or not bool(result.get("success", false)):
		return {}
	var encoded := str(result.get("png", ""))
	if encoded.is_empty():
		return {}
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK or image.is_empty():
		return {}
	_pixelate_image(image)
	return {
		"text": str(result.get("text", text)),
		"texture": ImageTexture.create_from_image(image),
	}


## 把浏览器字体的抗锯齿灰边转为硬边像素，避免随 320×200 画面放大后发糊。
static func _pixelate_image(image: Image, alpha_threshold: int = ALPHA_THRESHOLD) -> void:
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var pixels := image.get_data()
	var threshold := clampi(alpha_threshold, 0, 255)
	for alpha_index in range(3, pixels.size(), 4):
		pixels[alpha_index - 3] = 255
		pixels[alpha_index - 2] = 255
		pixels[alpha_index - 1] = 255
		pixels[alpha_index] = 255 if pixels[alpha_index] >= threshold else 0
	image.set_data(width, height, false, Image.FORMAT_RGBA8, pixels)
