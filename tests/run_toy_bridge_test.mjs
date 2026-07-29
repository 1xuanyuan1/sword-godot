// Copyright (C) 2026 sword-godot contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// 使用内存 Toy SDK 验证嵌入 GDScript 的浏览器桥接协议，不访问线上账号。
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'

const serviceSource = await readFile(new URL('../src/platform/pal_toy_service.gd', import.meta.url), 'utf8')
const bridgeMatch = serviceSource.match(/const BRIDGE_SOURCE := """\n([\s\S]*?)\n"""/)
assert.ok(bridgeMatch, 'pal_toy_service.gd must contain an embedded JavaScript bridge')

const storage = {
  'pal-save-v1-manifest': JSON.stringify({ chunks: 3, saved_at: 'old' }),
  'pal-save-v1-002': 'stale',
}
const operations = []
const submitted = []
const toy = {
  async isSupport() {
    return true
  },
  async getCloudStorage(keys = []) {
    const selected = keys.length ? keys : Object.keys(storage)
    return Object.fromEntries(selected.filter((key) => key in storage).map((key) => [key, storage[key]]))
  },
  async setCloudStorage(items) {
    operations.push({ kind: 'set', keys: Object.keys(items) })
    Object.assign(storage, items)
  },
  async removeCloudStorage(keys) {
    operations.push({ kind: 'remove', keys: [...keys] })
    for (const key of keys) delete storage[key]
  },
  async submitScore({ board, score }) {
    submitted.push({ board, score })
    return { score }
  },
  async getRankList({ board, period, limit }) {
    assert.deepEqual({ board, period, limit }, { board: 2, period: 'all', limit: 5 })
    return [{ rank: 1, score: 30, nickname: '灵儿', avatar: '//example/avatar.png' }]
  },
  async getMyRank({ board, period }) {
    assert.deepEqual({ board, period }, { board: 2, period: 'all' })
    return { ranked: true, rank: 4, score: 20 }
  },
  async closeBrowser() {
    operations.push({ kind: 'close' })
  },
}

const window = { toy }
vm.runInNewContext(bridgeMatch[1], { window, TextEncoder, Promise, JSON, String, Number, Array, Boolean, Error })
const bridge = window.SwordPalToyBridge
assert.ok(bridge?.available(), 'bridge must detect the injected Toy SDK')

const invoke = (call) => new Promise((resolve) => call((text) => resolve(JSON.parse(text))))
const abilities = await invoke((callback) => bridge.checkAbilities(callback))
assert.equal(abilities.success && abilities.cloud && abilities.rank && abilities.closeBrowser, true)

const manifest = { protocol: 1, chunks: 2, sha256: 'abc', saved_at: 'new' }
const upload = await invoke((callback) => bridge.uploadCloud(
  JSON.stringify(manifest),
  JSON.stringify(['first-', 'second']),
  callback,
))
assert.equal(upload.success, true)
assert.deepEqual(operations.slice(0, 3), [
  { kind: 'set', keys: ['pal-save-v1-000', 'pal-save-v1-001'] },
  { kind: 'remove', keys: ['pal-save-v1-002'] },
  { kind: 'set', keys: ['pal-save-v1-manifest'] },
], 'chunks and stale cleanup must complete before publishing the manifest')

const cloudInfo = await invoke((callback) => bridge.getCloudInfo(callback))
assert.deepEqual(cloudInfo.manifest, manifest)
const download = await invoke((callback) => bridge.downloadCloud(callback))
assert.equal(download.success, true)
assert.equal(download.data, 'first-second')
assert.deepEqual(download.manifest, manifest)

const ranks = await invoke((callback) => bridge.getRanks(2, callback))
assert.equal(ranks.success, true)
assert.equal(ranks.entries[0].nickname, '灵儿')
assert.deepEqual(ranks.mine, { ranked: true, rank: 4, score: 20 })

const scores = await invoke((callback) => bridge.submitScores(JSON.stringify({ 1: 12, 2: 30, 3: 3456 }), callback))
assert.equal(scores.success, true)
assert.deepEqual(submitted, [{ board: 1, score: 12 }, { board: 2, score: 30 }, { board: 3, score: 3456 }])

const close = await invoke((callback) => bridge.closeBrowser(callback))
assert.equal(close.success, true)
assert.equal(operations.at(-1).kind, 'close')

console.log('PASS: Toy JS bridge cloud ordering, download, ranks, score submission and closeBrowser')
