#!/usr/bin/env node

import { createHmac } from 'node:crypto'
import { createReadStream } from 'node:fs'
import { access, readFile, stat, unlink, writeFile } from 'node:fs/promises'
import { basename, dirname, join, resolve } from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { homedir } from 'node:os'
import OSS from 'ali-oss'

const PAGE_ID = '3ERAcwloghvtci00'
const PUBLIC_BASE_URL = `https://activity.hdslb.com/blackboard/activity${PAGE_ID}/`
const PALADIN_CONFIG_PATH = process.env.EVA_ASSET_CONFIG_PATH || process.env.BFS_CONFIG_PATH ||
  '/Users/xuanyuan/Documents/workspace/music-app-backend/server/.paladin-cache.json'
const projectDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const outputDir = join(projectDir, 'builds/eva')
const htmlPath = join(outputDir, 'index.html')
const assetDir = join(projectDir, 'builds/eva-assets')
const manifestPath = join(assetDir, 'manifest.json')
const evaBin = join(projectDir, 'node_modules/.bin/eva')
const assetUploadMode = process.env.EVA_ASSET_UPLOAD || 'oss'
const ossAlias = process.env.EVA_OSS_ALIAS || 'uat-resource'
const cachePath = join(projectDir, `builds/eva-${assetUploadMode}-manifest.json`)
const args = process.argv.slice(2)
const prepareOnly = takeFlag('--prepare-only')
const assetBaseUrl = takeOption('--asset-base-url')
const htmlBaseUrl = takeOption('--html-base-url')

await requireFile(htmlPath, '请先运行 npm run build:web')
await requireFile(manifestPath, '请先运行 npm run build:web')

const manifest = await readJson(manifestPath)
validateManifest(manifest)
const published = await resolveAssetUrls(manifest)
await patchGodotHtml(htmlPath, published)

const uploadSize = await compressedUploadSize(outputDir)
console.log(`EVA 代码包预估上传体积：${formatBytes(uploadSize)}`)

if (!prepareOnly) {
  await run(evaBin, [
    'publish:code',
    PAGE_ID,
    outputDir,
    '--oss',
    '--not-open',
    ...args,
  ])
}

async function resolveAssetUrls(source) {
  if (assetBaseUrl) {
    return {
      ...source,
      parts: source.parts.map((part) => ({
        ...part,
        url: new URL(part.file, assetBaseUrl).href,
      })),
    }
  }

  const cached = await readJson(cachePath)
  const cachedParts = cached?.sourceHash === source.sourceHash && cached?.uploadMode === assetUploadMode
    ? cached.parts || []
    : []
  const parts = []
  for (let index = 0; index < source.parts.length; index += 1) {
    const part = source.parts[index]
    const previous = cachedParts.find((item) => item.file === part.file && item.sha256 === part.sha256)
    let url = previous?.url || ''
    if (!url || !await remoteFileExists(url)) {
      url = await uploadAsset(join(assetDir, part.file), source.sourceHash, part.file)
    } else {
      console.log(`复用 ${assetUploadMode.toUpperCase()} 分包 ${index + 1}/${source.parts.length}`)
    }
    parts.push({ ...part, url })
    await writeFile(cachePath, `${JSON.stringify({ ...source, uploadMode: assetUploadMode, parts }, null, 2)}\n`)
  }
  return { ...source, parts }
}

async function uploadAsset(filePath, sourceHash, fileName) {
  if (assetUploadMode === 'oss') {
    return uploadToOss(filePath, sourceHash, fileName)
  }
  if (assetUploadMode === 'bfs') {
    return uploadToBfs(filePath, sourceHash, fileName)
  }
  if (assetUploadMode === 'eva') {
    return uploadToEvaInternal(filePath, sourceHash, fileName)
  }
  throw new Error(`不支持的 EVA_ASSET_UPLOAD：${assetUploadMode}`)
}

async function uploadToOss(filePath, sourceHash, fileName) {
  const cachedConfig = await readJson(PALADIN_CONFIG_PATH)
  const oss = cachedConfig?.['oss-alias']
  const bucketName = oss?.alias?.[ossAlias]
  const config = oss?.buckets?.[bucketName]
  if (
    !config?.accessKeyId ||
    !config?.accessKeySecret ||
    !config?.bucket ||
    !config?.region ||
    !config?.publicHost
  ) {
    throw new Error(`OSS 配置不完整：${PALADIN_CONFIG_PATH}（alias: ${ossAlias}）`)
  }
  const targetPath = assetTargetPath(sourceHash, fileName)
  const data = await readFile(filePath)
  const client = new OSS(config)
  await client.put(targetPath, data, {
    headers: {
      'Content-Type': 'application/octet-stream',
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  })
  const url = new URL(targetPath, config.publicHost.replace(/\/?$/, '/')).href
  if (!await remoteFileExists(url)) throw new Error(`OSS 文件不可访问：${url}`)
  console.log(`OSS 上传完成：${fileName}（${formatBytes(data.byteLength)}）`)
  return url
}

async function uploadToBfs(filePath, sourceHash, fileName) {
  const cachedConfig = await readJson(PALADIN_CONFIG_PATH)
  const bfs = cachedConfig?.bfs
  if (!bfs?.BUCKET_NAME || !bfs?.KEY || !bfs?.SECRET) {
    throw new Error(`BFS 配置不完整：${PALADIN_CONFIG_PATH}`)
  }
  const targetPath = assetTargetPath(sourceHash, fileName)
  const expires = Math.floor(Date.now() / 1000)
  const signatureText = `PUT\n${bfs.BUCKET_NAME}\n${targetPath}\n${expires}\n`
  const signature = createHmac('sha1', bfs.SECRET).update(signatureText).digest('base64')
  const fileStat = await stat(filePath)
  const endpoint = `http://bfs.bilibili.co/bfs/${bfs.BUCKET_NAME}/${targetPath}`
  const response = await fetch(endpoint, {
    method: 'PUT',
    headers: {
      Authorization: `${bfs.KEY}:${signature}:${expires}`,
      Date: formatBfsDate(new Date()),
      Host: 'bfs.bilibili.co',
      'Content-Length': String(fileStat.size),
      'Content-Type': 'application/octet-stream',
    },
    body: createReadStream(filePath),
    duplex: 'half',
    signal: AbortSignal.timeout(120_000),
  })
  const code = response.headers.get('code')
  const location = response.headers.get('location')
  if (!response.ok || code !== '200' || !location) {
    throw new Error(`BFS 上传失败：HTTP ${response.status}，code=${code || '空'}`)
  }
  const url = normalizeUrl(location)
  if (!await remoteFileExists(url)) throw new Error(`BFS 文件不可访问：${url}`)
  console.log(`BFS 上传完成：${fileName}（${formatBytes(fileStat.size)}）`)
  return url
}

async function uploadToEvaInternal(filePath, sourceHash, fileName) {
  const evaConfig = await readJson(join(homedir(), '.eva_config'))
  if (!evaConfig?.userName || !evaConfig?.userKey) {
    throw new Error('EVA 登录配置不完整：~/.eva_config')
  }
  const { GitLabAccount } = await import('@jinkela/authenticator')
  const account = await new GitLabAccount().login()
  const form = new FormData()
  form.append('file', new Blob([await readFile(filePath)]), basename(filePath))
  form.append('customFileName', assetTargetPath(sourceHash, fileName))
  const response = await fetch('http://activity-template.bilibili.co/x/upload/internal?type=eva', {
    method: 'POST',
    headers: {
      accept: 'json',
      cookie: `_AJSESSIONID=${account.sessionId}`,
      'x-auth-user': evaConfig.userName,
      'x-auth-thirdtoken': evaConfig.userKey,
    },
    body: form,
    signal: AbortSignal.timeout(180_000),
  })
  const payload = await response.json().catch(() => null)
  const cdnPath = payload?.data?.[0]?.cdnPath
  if (!response.ok || payload?.code !== 0 || !cdnPath) {
    throw new Error(`EVA 资源上传失败：HTTP ${response.status}，code=${payload?.code ?? '空'}`)
  }
  const url = normalizeUrl(cdnPath)
  if (!await remoteFileExists(url)) throw new Error(`EVA 资源不可访问：${url}`)
  console.log(`EVA 资源上传完成：${fileName}（${formatBytes((await stat(filePath)).size)}）`)
  return url
}

async function patchGodotHtml(filePath, pack) {
  let html = await readFile(filePath, 'utf8')
  html = html.replace(/<base href="[^"]*">/, `<base href="${new URL(htmlBaseUrl || PUBLIC_BASE_URL).href}">`)
  const configMatch = html.match(/const GODOT_CONFIG = (\{[^\n]+\});/)
  if (!configMatch) throw new Error('无法在 index.html 中定位 GODOT_CONFIG')
  const config = JSON.parse(configMatch[1])
  config.fileSizes ||= {}
  delete config.fileSizes['index.pck']
  html = html.replace(configMatch[0], `const GODOT_CONFIG = ${JSON.stringify(config)};`)

  const clientManifest = {
    compression: pack.compression,
    sourceSize: pack.sourceSize,
    compressedSize: pack.compressedSize,
    parts: pack.parts.map(({ url, size, sha256 }) => ({ url, size, sha256 })),
  }
  const loader = `
// EVA_EXTERNAL_PCK_START
const EVA_PACK = ${JSON.stringify(clientManifest)};

async function evaFetchPart(part, attempts = 3) {
\ttry {
\t\tconst response = await fetch(part.url);
\t\tif (!response.ok) throw new Error('HTTP ' + response.status);
\t\tconst buffer = await response.arrayBuffer();
\t\tif (buffer.byteLength !== part.size) throw new Error('资源分片长度不符');
\t\treturn new Uint8Array(buffer);
\t} catch (error) {
\t\tif (attempts <= 1) throw error;
\t\treturn evaFetchPart(part, attempts - 1);
\t}
}

async function evaLoadMainPack(onProgress) {
\tif (typeof DecompressionStream === 'undefined') {
\t\tthrow new Error('当前浏览器不支持 gzip 流式解压，请升级后重试。');
\t}
\tlet partIndex = 0;
\tlet compressedLoaded = 0;
\tconst compressedStream = new ReadableStream({
\t\tasync pull(controller) {
\t\t\tif (partIndex >= EVA_PACK.parts.length) {
\t\t\t\tcontroller.close();
\t\t\t\treturn;
\t\t\t}
\t\t\ttry {
\t\t\t\tconst bytes = await evaFetchPart(EVA_PACK.parts[partIndex]);
\t\t\t\tpartIndex += 1;
\t\t\t\tcompressedLoaded += bytes.byteLength;
\t\t\t\tif (typeof onProgress === 'function') onProgress(compressedLoaded, EVA_PACK.compressedSize);
\t\t\t\tcontroller.enqueue(bytes);
\t\t\t} catch (error) {
\t\t\t\tcontroller.error(error);
\t\t\t}
\t\t},
\t});
\tconst reader = compressedStream.pipeThrough(new DecompressionStream(EVA_PACK.compression)).getReader();
\tconst unpacked = new Uint8Array(EVA_PACK.sourceSize);
\tlet offset = 0;
\twhile (true) {
\t\tconst { done, value } = await reader.read();
\t\tif (done) break;
\t\tif (offset + value.byteLength > unpacked.byteLength) throw new Error('PCK 解压结果超过预期长度');
\t\tunpacked.set(value, offset);
\t\toffset += value.byteLength;
\t}
\tif (offset !== unpacked.byteLength) throw new Error('PCK 解压结果长度不符');
\treturn unpacked.buffer;
}

engine.startGame = function (override) {
\tthis.config.update(override);
\tconst args = ['--main-pack', 'index.pck'].concat(this.config.args);
\tconst pack = evaLoadMainPack(this.config.onProgress)
\t\t.then((buffer) => this.preloadFile(buffer, 'index.pck'));
\treturn Promise.all([this.init(this.config.executable), pack])
\t\t.then(() => this.start({ args }));
};
// EVA_EXTERNAL_PCK_END`
  const loaderPattern = /\n\/\/ EVA_EXTERNAL_PCK_START[\s\S]*?\/\/ EVA_EXTERNAL_PCK_END/
  if (loaderPattern.test(html)) {
    html = html.replace(loaderPattern, loader)
  } else {
    const anchor = 'const engine = new Engine(GODOT_CONFIG);'
    if (!html.includes(anchor)) throw new Error('无法在 index.html 中定位 Godot 启动器')
    html = html.replace(anchor, `${anchor}${loader}`)
  }
  await writeFile(filePath, html)
}

async function compressedUploadSize(directory) {
  const zipPath = join(projectDir, 'builds/eva-upload-size.zip')
  if (await fileExists(zipPath)) await unlink(zipPath)
  await run('zip', ['-9', '-q', '-r', zipPath, '.', '-x', '*.zip'], { cwd: directory })
  const size = (await stat(zipPath)).size
  await unlink(zipPath)
  return size
}

function takeFlag(name) {
  const index = args.indexOf(name)
  if (index < 0) return false
  args.splice(index, 1)
  return true
}

function takeOption(name) {
  const inlineIndex = args.findIndex((value) => value.startsWith(`${name}=`))
  if (inlineIndex >= 0) {
    const [value] = args.splice(inlineIndex, 1)
    return value.slice(name.length + 1)
  }
  const index = args.indexOf(name)
  if (index < 0) return ''
  const value = args[index + 1]
  if (!value) throw new Error(`${name} 缺少参数`)
  args.splice(index, 2)
  return value
}

function validateManifest(value) {
  if (
    value?.version !== 1 ||
    value?.compression !== 'gzip' ||
    !Number.isInteger(value?.sourceSize) ||
    !Number.isInteger(value?.compressedSize) ||
    !Array.isArray(value?.parts) ||
    value.parts.length === 0
  ) {
    throw new Error(`EVA 分包清单无效：${manifestPath}`)
  }
}

async function remoteFileExists(url) {
  if (!url) return false
  try {
    const response = await fetch(url, { headers: { range: 'bytes=0-3' } })
    if (!response.ok) return false
    await response.body?.cancel()
    return true
  } catch {
    return false
  }
}

async function requireFile(filePath, message) {
  if (!await fileExists(filePath)) throw new Error(`${message}（缺少 ${filePath}）`)
}

async function fileExists(filePath) {
  try {
    await access(filePath)
    return true
  } catch {
    return false
  }
}

async function readJson(filePath) {
  try {
    return JSON.parse(await readFile(filePath, 'utf8'))
  } catch {
    return null
  }
}

function normalizeUrl(url) {
  if (typeof url !== 'string') return ''
  if (url.startsWith('//')) return `https:${url}`
  if (url.startsWith('http://')) return `https://${url.slice('http://'.length)}`
  return url
}

function assetTargetPath(sourceHash, fileName) {
  return `sword-eva/${PAGE_ID}/${sourceHash.slice(0, 16)}/${fileName}`
}

function formatBfsDate(date) {
  const pad = (value) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

function run(command, commandArgs, options = {}) {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(command, commandArgs, {
      cwd: options.cwd || projectDir,
      stdio: 'inherit',
    })
    child.on('error', rejectPromise)
    child.on('exit', (code) => {
      if (code === 0) resolvePromise()
      else rejectPromise(new Error(`${basename(command)} 退出码：${code}`))
    })
  })
}

function formatBytes(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(2)} MiB`
}
