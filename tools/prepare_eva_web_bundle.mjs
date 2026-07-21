#!/usr/bin/env node

import { createHash } from 'node:crypto'
import { createReadStream } from 'node:fs'
import { access, mkdir, readdir, stat, unlink, writeFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { Writable } from 'node:stream'
import { pipeline } from 'node:stream/promises'
import { fileURLToPath } from 'node:url'
import { constants as zlibConstants, createGzip } from 'node:zlib'

class SplitWriter extends Writable {
  constructor(directory, prefixName, maximumSize) {
    super()
    this.directory = directory
    this.prefixName = prefixName
    this.maximumSize = maximumSize
    this.buffers = []
    this.bufferedSize = 0
    this.parts = []
  }

  _write(chunk, _encoding, callback) {
    this.writeChunk(chunk).then(() => callback(), callback)
  }

  _final(callback) {
    this.flushPart().then(() => callback(), callback)
  }

  async writeChunk(chunk) {
    let offset = 0
    while (offset < chunk.length) {
      const length = Math.min(this.maximumSize - this.bufferedSize, chunk.length - offset)
      this.buffers.push(chunk.subarray(offset, offset + length))
      this.bufferedSize += length
      offset += length
      if (this.bufferedSize === this.maximumSize) await this.flushPart()
    }
  }

  async flushPart() {
    if (this.bufferedSize === 0) return
    const data = Buffer.concat(this.buffers, this.bufferedSize)
    const file = `${this.prefixName}${String(this.parts.length).padStart(3, '0')}`
    await writeFile(join(this.directory, file), data)
    this.parts.push({
      file,
      size: data.length,
      sha256: createHash('sha256').update(data).digest('hex'),
    })
    this.buffers = []
    this.bufferedSize = 0
  }
}

const PART_SIZE = 8 * 1024 * 1024
const projectDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const pckPath = join(projectDir, 'builds/eva/index.pck')
const assetDir = join(projectDir, 'builds/eva-assets')
const manifestPath = join(assetDir, 'manifest.json')

if (!await fileExists(pckPath)) {
  throw new Error(`缺少 Godot Web 数据包：${pckPath}`)
}

await mkdir(assetDir, { recursive: true })
for (const fileName of await readdir(assetDir)) {
  if (fileName === 'manifest.json' || /^index-[a-f0-9]+\.pck\.gz\.part\d+$/.test(fileName)) {
    await unlink(join(assetDir, fileName))
  }
}

const sourceStat = await stat(pckPath)
const sourceHash = await sha256File(pckPath)
const prefix = `index-${sourceHash.slice(0, 16)}.pck.gz.part`
const splitter = new SplitWriter(assetDir, prefix, PART_SIZE)

console.log(`压缩并拆分 PCK：${formatBytes(sourceStat.size)}`)
await pipeline(
  createReadStream(pckPath),
  createGzip({
    level: zlibConstants.Z_BEST_COMPRESSION,
    chunkSize: 256 * 1024,
  }),
  splitter,
)

const manifest = {
  version: 1,
  compression: 'gzip',
  sourceHash,
  sourceSize: sourceStat.size,
  compressedSize: splitter.parts.reduce((total, part) => total + part.size, 0),
  partSize: PART_SIZE,
  parts: splitter.parts,
}
await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
await unlink(pckPath)

console.log(`PCK 分包完成：${splitter.parts.length} 片，${formatBytes(manifest.compressedSize)}`)

async function sha256File(filePath) {
  const hash = createHash('sha256')
  await new Promise((resolvePromise, rejectPromise) => {
    const stream = createReadStream(filePath)
    stream.on('data', (chunk) => hash.update(chunk))
    stream.on('error', rejectPromise)
    stream.on('end', resolvePromise)
  })
  return hash.digest('hex')
}

async function fileExists(filePath) {
  try {
    await access(filePath)
    return true
  } catch {
    return false
  }
}

function formatBytes(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(2)} MiB`
}
