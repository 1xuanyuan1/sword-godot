#!/usr/bin/env node

import { copyFile, mkdir, readFile, readdir, rm, symlink, writeFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { deflateSync } from 'node:zlib'
import * as OpenCC from 'opencc-js'

const projectDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const stagingDir = join(projectDir, 'builds/eva-project')
const buildResourceDir = join(stagingDir, 'eva_build')
const exportPluginDir = join(stagingDir, 'addons/eva_web_export')

await rm(stagingDir, { recursive: true, force: true })
await mkdir(buildResourceDir, { recursive: true })
await mkdir(exportPluginDir, { recursive: true })

for (const directory of ['generated', 'scenes', 'shaders', 'src']) {
  await symlink(join(projectDir, directory), join(stagingDir, directory), 'dir')
}

await copyFile(join(projectDir, 'export_presets.cfg'), join(stagingDir, 'export_presets.cfg'))
await prepareProjectConfig()
await preparePalBitmapFont()
await prepareExportPlugin()

console.log(`EVA 临时构建工程已准备：${stagingDir}`)

async function prepareProjectConfig() {
  const sourcePath = join(projectDir, 'project.godot')
  let config = await readFile(sourcePath, 'utf8')
  const originalEntry = 'run/main_scene="res://scenes/main.tscn"'
  if (!config.includes(originalEntry)) {
    throw new Error(`无法定位原项目入口：${sourcePath}`)
  }
  config = config.replace(originalEntry, 'run/main_scene="res://scenes/map_explorer.tscn"')
  if (/^\[autoload\]$/m.test(config)) {
    config = config.replace(
      /^\[autoload\]$/m,
      '[autoload]\nEvaWebFontBootstrap="*res://eva_build/eva_web_font_bootstrap.gd"',
    )
  } else {
    config += '\n[autoload]\n\nEvaWebFontBootstrap="*res://eva_build/eva_web_font_bootstrap.gd"\n'
  }
  config += '\n[editor]\n\nexport/convert_text_resources_to_binary=false\n'
  config += '\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/eva_web_export/plugin.cfg")\n'
  await writeFile(join(stagingDir, 'project.godot'), config)
}

async function preparePalBitmapFont() {
  const metadataPath = join(projectDir, 'generated/pal/content/text/font_glyphs.json')
  const atlasPath = join(projectDir, 'generated/pal/content/text/font_atlas.png')
  const classicFontPath = join(projectDir, 'src/ui/pal_classic_font.gd')
  const metadata = JSON.parse(await readFile(metadataPath, 'utf8'))
  const glyphs = { ...metadata.glyphs }
  const classicFontSource = await readFile(classicFontPath, 'utf8')
  const aliasesMatch = classicFontSource.match(/const GLYPH_ALIASES := \{([\s\S]*?)\n\}/)
  if (!aliasesMatch) throw new Error(`无法读取简繁字形兼容表：${classicFontPath}`)
  for (const match of aliasesMatch[1].matchAll(/"([^"]+)":\s*"([^"]+)"/g)) {
    const [, simplified, traditional] = match
    if (!glyphs[simplified] && glyphs[traditional]) glyphs[simplified] = glyphs[traditional]
  }
  const toTraditional = OpenCC.Converter({ from: 'cn', to: 'tw' })
  for (const character of await collectSourceCharacters()) {
    if (glyphs[character]) continue
    const traditional = toTraditional(character)
    if ([...traditional].length === 1 && glyphs[traditional]) {
      glyphs[character] = glyphs[traditional]
    }
  }

  const entries = Object.entries(glyphs)
    .filter(([character, values]) => [...character].length === 1 && isGlyphRect(values))
    .map(([character, values]) => [character, [...values, 0]])
  entries.push(
    ['▼', [0, 0, 16, 16, 1]],
    ['▶', [16, 0, 16, 16, 1]],
  )
  entries
    .sort(([left], [right]) => left.codePointAt(0) - right.codePointAt(0))
  const lines = [
    'info face="PAL Classic" size=16 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0 outline=0',
    'common lineHeight=16 base=15 scaleW=512 scaleH=1344 pages=2 packed=0',
    'page id=0 file="pal_font.png"',
    'page id=1 file="pal_font_symbols.png"',
    `chars count=${entries.length}`,
  ]
  for (const [character, [x, y, width, height, page]] of entries) {
    lines.push(
      `char id=${character.codePointAt(0)} x=${x} y=${y} width=${width} height=${height} xoffset=0 yoffset=0 xadvance=16 page=${page} chnl=15`,
    )
  }
  await writeFile(join(buildResourceDir, 'pal_font.fnt'), `${lines.join('\n')}\n`)
  await copyFile(atlasPath, join(buildResourceDir, 'pal_font.png'))
  await writeFile(join(buildResourceDir, 'pal_font_symbols.png'), createSymbolAtlasPng())
  await writeFile(join(buildResourceDir, 'eva_web_font_bootstrap.gd'), `extends Node

func _enter_tree() -> void:
\tvar pal_font := load("res://eva_build/pal_font.fnt") as Font
\tif pal_font == null:
\t\tpush_error("EVA Web 中文点阵字体加载失败")
\t\treturn
\tvar fallbacks: Array[Font] = ThemeDB.fallback_font.fallbacks.duplicate()
\tfallbacks.push_front(pal_font)
\tThemeDB.fallback_font.fallbacks = fallbacks
`)
}

async function collectSourceCharacters() {
  const characters = new Set()
  for (const directory of ['scenes', 'src']) {
    for (const filePath of await listFiles(join(projectDir, directory))) {
      if (!/\.(?:gd|tscn)$/.test(filePath)) continue
      for (const character of await readFile(filePath, 'utf8')) {
        if (/\p{Script=Han}/u.test(character)) characters.add(character)
      }
    }
  }
  return characters
}

async function listFiles(directory) {
  const files = []
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const filePath = join(directory, entry.name)
    if (entry.isDirectory()) files.push(...await listFiles(filePath))
    else if (entry.isFile()) files.push(filePath)
  }
  return files
}

async function prepareExportPlugin() {
  await writeFile(join(exportPluginDir, 'plugin.cfg'), `[plugin]

name="EVA Web Export"
description="Build-only raw asset export compatibility"
author="sword-godot contributors"
version="1.0"
script="plugin.gd"
`)
  await writeFile(join(exportPluginDir, 'plugin.gd'), `@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin

func _enter_tree() -> void:
\t_export_plugin = preload("res://addons/eva_web_export/raw_asset_export.gd").new()
\tadd_export_plugin(_export_plugin)

func _exit_tree() -> void:
\tremove_export_plugin(_export_plugin)
`)
  await writeFile(join(exportPluginDir, 'raw_asset_export.gd'), `@tool
extends EditorExportPlugin

const RAW_FONT_ATLAS := "res://generated/pal/content/text/font_atlas.png"

func _get_name() -> String:
\treturn "EVAWebRawAssetExport"

func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
\tif path != RAW_FONT_ATLAS:
\t\treturn
\tadd_file(path, FileAccess.get_file_as_bytes(path), false)
\tskip()
`)
}

function isGlyphRect(value) {
  return Array.isArray(value) && value.length === 4 && value.every(Number.isInteger)
}

function createSymbolAtlasPng() {
  const width = 32
  const height = 16
  const pixels = Buffer.alloc(height * (1 + width * 4))
  const setPixel = (x, y) => {
    const offset = y * (1 + width * 4) + 1 + x * 4
    pixels[offset] = 255
    pixels[offset + 1] = 255
    pixels[offset + 2] = 255
    pixels[offset + 3] = 255
  }
  for (let row = 0; row < 7; row += 1) {
    for (let x = 2 + row; x <= 13 - row; x += 1) setPixel(x, 4 + row)
  }
  for (let row = 0; row < 7; row += 1) {
    const distance = row <= 3 ? row : 6 - row
    for (let x = 0; x <= distance * 2; x += 1) setPixel(19 + x, 4 + row)
  }
  const header = Buffer.alloc(13)
  header.writeUInt32BE(width, 0)
  header.writeUInt32BE(height, 4)
  header[8] = 8
  header[9] = 6
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk('IHDR', header),
    pngChunk('IDAT', deflateSync(pixels)),
    pngChunk('IEND', Buffer.alloc(0)),
  ])
}

function pngChunk(type, data) {
  const typeBytes = Buffer.from(type, 'ascii')
  const chunk = Buffer.alloc(12 + data.length)
  chunk.writeUInt32BE(data.length, 0)
  typeBytes.copy(chunk, 4)
  data.copy(chunk, 8)
  chunk.writeUInt32BE(crc32(Buffer.concat([typeBytes, data])), 8 + data.length)
  return chunk
}

function crc32(data) {
  let crc = 0xffffffff
  for (const byte of data) {
    crc ^= byte
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1))
    }
  }
  return (crc ^ 0xffffffff) >>> 0
}
