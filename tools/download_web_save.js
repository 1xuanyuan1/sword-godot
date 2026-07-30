/*
 * 从 Sword Godot Study Port 网页版的 Godot IDBFS 下载一个本地存档。
 *
 * 用法：
 * 1. 打开 Web 游戏及浏览器开发者工具。
 * 2. 把 Console 执行上下文切换到 Godot 画布所在的 iframe。
 * 3. 把本文件完整粘贴到 Console 后执行，再按提示选择槽位。
 */
(async () => {
  "use strict";

  const DATABASE_NAME = "/userfs";
  const STORE_NAME = "FILE_DATA";
  const SAVE_DIRECTORY =
    "/userfs/godot/app_userdata/Sword Godot Study Port/saves/";
  const SAVE_NAME_PATTERN = /^slot_(\d{3})\.json$/;

  const openDatabase = () =>
    new Promise((resolve, reject) => {
      let missingDatabase = false;
      const request = indexedDB.open(DATABASE_NAME);

      // 在错误的页面来源或 iframe 执行时，open() 会尝试新建空数据库。
      // 立即中止升级，既不留下无用数据库，也能给出明确提示。
      request.onupgradeneeded = () => {
        missingDatabase = true;
        request.transaction.abort();
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () =>
        reject(
          new Error(
            missingDatabase
              ? "当前页面来源没有 Godot /userfs 数据库，请切换到运行游戏画布的 iframe"
              : `无法打开 Godot IndexedDB：${request.error?.message ?? "未知错误"}`,
          ),
        );
      request.onblocked = () =>
        reject(new Error("Godot IndexedDB 正被其他页面操作，请关闭其他游戏标签页后重试"));
    });

  const runRequest = (request) =>
    new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });

  const readSaveBytes = async (contents) => {
    if (contents instanceof Blob) {
      return new Uint8Array(await contents.arrayBuffer());
    }
    if (contents instanceof ArrayBuffer) {
      return new Uint8Array(contents);
    }
    if (ArrayBuffer.isView(contents)) {
      return new Uint8Array(
        contents.buffer,
        contents.byteOffset,
        contents.byteLength,
      );
    }
    throw new Error("存档的 IndexedDB 内容类型无法识别");
  };

  let database;
  try {
    database = await openDatabase();
    if (!database.objectStoreNames.contains(STORE_NAME)) {
      throw new Error("Godot IndexedDB 中不存在 FILE_DATA");
    }

    const transaction = database.transaction(STORE_NAME, "readonly");
    const store = transaction.objectStore(STORE_NAME);
    const keys = await runRequest(store.getAllKeys());
    const slots = keys
      .filter((key) => typeof key === "string" && key.startsWith(SAVE_DIRECTORY))
      .map((key) => key.slice(SAVE_DIRECTORY.length).match(SAVE_NAME_PATTERN)?.[1])
      .filter(Boolean)
      .sort();

    if (slots.length === 0) {
      throw new Error("当前网页来源中没有可下载的 slot_NNN.json 存档");
    }

    const selected = window.prompt(
      `可下载的存档槽位：${slots.join(", ")}\n请输入要下载的槽位编号：`,
      slots.at(-1),
    );
    if (selected === null) {
      console.info("已取消下载网页存档");
      return;
    }

    const slot = String(Number.parseInt(selected, 10)).padStart(3, "0");
    if (!slots.includes(slot)) {
      throw new Error(`槽位 ${selected} 不存在；可用槽位为：${slots.join(", ")}`);
    }

    const savePath = `${SAVE_DIRECTORY}slot_${slot}.json`;
    const readTransaction = database.transaction(STORE_NAME, "readonly");
    const record = await runRequest(
      readTransaction.objectStore(STORE_NAME).get(savePath),
    );
    if (!record || record.contents == null) {
      throw new Error(`IndexedDB 记录缺少存档内容：${savePath}`);
    }

    const bytes = await readSaveBytes(record.contents);
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    const parsed = JSON.parse(text);
    if (
      !parsed ||
      typeof parsed !== "object" ||
      !parsed.header ||
      !Number.isInteger(parsed.header.format_version) ||
      typeof parsed.payload_json !== "string"
    ) {
      throw new Error("IndexedDB 记录不是有效的 Sword Godot 版本化存档");
    }

    const fileName = `slot_${slot}.json`;
    const url = URL.createObjectURL(
      new Blob([bytes], { type: "application/json;charset=utf-8" }),
    );
    const link = document.createElement("a");
    link.href = url;
    link.download = fileName;
    link.style.display = "none";
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);

    console.info(`已下载网页存档：${fileName}（${bytes.byteLength} 字节）`);
  } catch (error) {
    console.error("网页存档下载失败：", error);
  } finally {
    database?.close();
  }
})();
