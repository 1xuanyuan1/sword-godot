#!/usr/bin/env node

// Copyright (C) 2026 sword-godot contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Build the committed simplified-Chinese bitmap supplement from GNU Unifont HEX data.

import { gunzipSync, deflateSync } from 'node:zlib'
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises'
import { dirname, extname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const projectDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const inputArgument = argumentValue('--unifont')
const outputDir = resolve(argumentValue('--output') || join(projectDir, 'assets/ui'))
if (!inputArgument) {
  throw new Error('用法：node tools/build_pal_simplified_font.mjs --unifont <unifont.hex[.gz]> [--output assets/ui]')
}

const inputPath = resolve(inputArgument)
const compressed = await readFile(inputPath)
const hexText = (inputPath.endsWith('.gz') ? gunzipSync(compressed) : compressed).toString('utf8')
const unifontGlyphs = new Map()
for (const line of hexText.split(/\r?\n/)) {
  const match = line.match(/^([0-9A-Fa-f]{4,6}):([0-9A-Fa-f]+)$/)
  if (match) unifontGlyphs.set(Number.parseInt(match[1], 16), match[2])
}

const characters = await collectSourceHanCharacters()
const entries = []
const missing = []
for (const character of [...characters].sort((left, right) => left.codePointAt(0) - right.codePointAt(0))) {
  const bitmap = unifontGlyphs.get(character.codePointAt(0))
  if (!bitmap) {
    missing.push(character)
    continue
  }
  const bytes = Buffer.from(bitmap, 'hex')
  if (bytes.length !== 16 && bytes.length !== 32) {
    missing.push(character)
    continue
  }
  entries.push({ character, bytes, width: bytes.length === 16 ? 8 : 16 })
}

const columns = 32
const cellSize = 16
const rows = Math.max(1, Math.ceil(entries.length / columns))
const width = columns * cellSize
const height = rows * cellSize
const pixels = Buffer.alloc(width * height * 4)
const glyphs = {}
for (const [index, entry] of entries.entries()) {
  const cellX = (index % columns) * cellSize
  const cellY = Math.floor(index / columns) * cellSize
  const xOffset = entry.width === 8 ? 4 : 0
  const bytesPerRow = entry.width / 8
  for (let y = 0; y < cellSize; y += 1) {
    for (let byteIndex = 0; byteIndex < bytesPerRow; byteIndex += 1) {
      const bits = entry.bytes[y * bytesPerRow + byteIndex]
      for (let bit = 0; bit < 8; bit += 1) {
        if (!(bits & (1 << (7 - bit)))) continue
        const x = cellX + xOffset + byteIndex * 8 + bit
        const offset = ((cellY + y) * width + x) * 4
        pixels.fill(255, offset, offset + 4)
      }
    }
  }
  glyphs[entry.character] = [cellX, cellY, cellSize, cellSize]
}

await mkdir(outputDir, { recursive: true })
await writeFile(join(outputDir, 'pal_simplified_font.png'), createRgbaPng(width, height, pixels))
await writeFile(join(outputDir, 'pal_simplified_glyphs.json'), `${JSON.stringify({
  format_version: 1,
  source: 'GNU Unifont 17.0.03',
  source_url: 'https://unifoundry.com/pub/unifont/unifont-17.0.03/',
  license: 'GPL-2.0-or-later WITH Font-exception-2.0',
  cell_size: [cellSize, cellSize],
  glyphs,
}, null, 2)}\n`)

console.log(JSON.stringify({ glyphs: entries.length, missing: missing.join(''), atlas_size: [width, height] }))

function argumentValue(name) {
  const index = process.argv.indexOf(name)
  return index >= 0 ? process.argv[index + 1] : ''
}

async function collectSourceHanCharacters() {
  const result = new Set()
  for (const directory of ['scenes', 'src']) {
    for (const filePath of await listFiles(join(projectDir, directory))) {
      if (!['.gd', '.tscn'].includes(extname(filePath))) continue
      for (const character of await readFile(filePath, 'utf8')) {
        if (/\p{Script=Han}/u.test(character)) result.add(character)
      }
    }
  }
  return result
}

async function listFiles(directory) {
  const files = []
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) files.push(...await listFiles(path))
    else if (entry.isFile()) files.push(path)
  }
  return files
}

function createRgbaPng(width, height, rgba) {
  const scanlines = Buffer.alloc(height * (1 + width * 4))
  for (let y = 0; y < height; y += 1) {
    rgba.copy(scanlines, y * (1 + width * 4) + 1, y * width * 4, (y + 1) * width * 4)
  }
  const header = Buffer.alloc(13)
  header.writeUInt32BE(width, 0)
  header.writeUInt32BE(height, 4)
  header[8] = 8
  header[9] = 6
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk('IHDR', header),
    pngChunk('IDAT', deflateSync(scanlines, { level: 9 })),
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
