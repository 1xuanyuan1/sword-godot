# Godot 版本化存档系统

本项目使用独立的 Godot JSON 存档，不读写原版 `.rpg` 文件。存档只保存玩家依法导入的数据所产生的运行状态，不包含原版地图、文字、图片或音频资源。

## 槽位与操作

- 系统菜单提供 100 个独立槽位，每页显示 5 个。
- 资源实验室启动页提供“读取存档”，直接打开同一套 100 槽界面；确认后进入对应探索场景，Esc 直接返回实验室。
- 上／下键按 1–100 连续切换槽位，经过每页第 5 槽时自动翻页；左／右键每次翻 5 个槽位并保留当前行，空格或回车确认，Esc 返回。
- 槽位摘要显示中文地点名、保存时间、队伍头像、姓名和等级；右侧小数字是该槽累计保存次数。
- 保存和读取只允许在探索地图的空闲状态执行，不保存半句对话、战斗中间帧、渐变或菜单内部选择。

存档位于 `user://saves/slot_001.json` 至 `slot_100.json`。macOS 默认对应 `~/Library/Application Support/Godot/app_userdata/Sword Godot Study Port/saves/`，Windows 默认对应 `%APPDATA%\Godot\app_userdata\Sword Godot Study Port\saves\`；实际路径以 Godot 的 `user://` 为准。

## Toy 云存档与排行榜

Web 发布页加载官方 Toy JS SDK；SDK 可用时，标题菜单保留同级的“云端存档／排行榜”入口，游戏内则把两项收进“系统”子菜单并放在“结束游戏”之前。云存档页只处理上传与下载，排行榜不再藏在存档操作中。桌面和 Android 等非 Toy 容器保持原菜单，不显示不可用入口。

Toy 云存储按“登录用户 + 当前 Toy”隔离并跨设备持久化。受平台最多 128 个 key、单 value 不超过 1024 字节的限制，本项目提供一个独立云端槽位，而不是同步全部 100 个本地槽位：玩家选择任一本地槽上传，或把当前云存档下载到指定本地槽。上传与下载覆盖前都显示确认；下载完成后仍由 `PalSaveManager` 检查格式版本、PAL 内容指纹、载荷校验和及完整运行状态，不兼容或损坏的数据不会覆盖本地存档。

游戏内统一使用“本地存档／上传此存档／下载到本地”文案。原版 DOS 字形优先，缺失的简体字由提交到仓库的 GNU Unifont 16×16 子集补齐，并沿用相同的调色板着色、单像素阴影和整数缩放；排行榜的“级／暂／数／据／钱”以及预览提示因此保留简体，不再用繁体近似字或浏览器系统字体。当前本地存档显示为 `<  本地存档 001  >`：键盘左右键或直接点击箭头逐槽移动，不在首尾之间循环；第一槽的左箭头和第一百槽的右箭头使用红色不可用状态。覆盖确认使用独立居中经典窗口，上方显示完整操作与目标存档，下方横向选择“否／是”。Toy 更新预览地址没有正式 Toy ID，因而不能真实读写云存储；预览仍展示完整入口和界面，并以“预览模式：正式页面将连接云存档”说明正式页面才连接云端，不把 SDK 英文错误直接显示给玩家。

云存档协议把完整 JSON 以 gzip 压缩并转换为 Base64，按 960 字符拆为最多 120 个数据块。数据块键为 `pal-save-v1-000` 起的连续编号，清单键为 `pal-save-v1-manifest`；上传先写数据块、清理旧尾块，最后发布清单。清单记录协议、编码、分块数、原始大小、SHA-256、存档格式版本、内容指纹、保存时间、场景和来源槽位。下载按清单组装后验证协议、大小与 SHA-256，再交给存档管理器原子写入。

排行榜使用三个永久总榜，分数均由当前 `GameSession` 产生：

- 榜位 1：李逍遥达到过的最高等级；
- 榜位 2：当前不重复队员的等级总和最高值；
- 榜位 3：持有金钱最高值。

三个榜位在排行榜页顶部按同级标签排列，可用键盘左右键或直接点击标签切换。Toy 预览地址没有正式 ID 时，切换仍立即更新当前标签并返回预览提示，不会因无效 SDK 请求长期停留在忙碌状态；正式页面再读取对应真实榜单。

每次本地保存或成功上传云存档后上报三个绝对分数，Toy 服务端只保留历史最高值。榜单页显示各榜前五名和自己的名次；游客可以读取榜单，个人名次与提交成绩需要登录，首次提交按平台规则完成用户数据确认。排行榜昵称属于 SDK 返回的运行时文本，无法预先收集进静态点阵子集；Web 端使用浏览器 Canvas 和系统中文字体生成 400 字重的 16px 字形，再以 alpha 128 二值化抗锯齿透明度，支持未预置的中文、英文与常见符号，并在游戏画面整数放大后保持清晰、避免粗笔画粘连。云存储本身只要求登录，不触发用户资料确认。

其他 SDK 能力中，`closeBrowser` 适合在 B 站 App 内结束游戏；`getUserProfile` 可用于可选头像／昵称个性化，但首次调用会触发平台确认，当前榜单已经直接返回展示信息，因此暂不额外索取。`navigate`、作者资料、作者视频及互动状态适合未来明确配置作者内容后增加社区入口。相册、摄像头、麦克风与本 RPG 核心玩法无关；文档只列出名称而未给出调用契约的 `reportAction` 不接入。

## 把桌面存档导入 Web

桌面、Android 和 Web 使用同一份版本化 JSON 存档格式。只要 `format_version` 和 PAL 内容指纹一致，桌面端的 `slot_NNN.json` 可以在 Web 端继续读取。Web 存档存在当前网页来源的 IndexedDB，不是普通的本地文件。

当前项目名下，Web 端 `user://saves/` 的真实 IDBFS 路径是：

```text
/userfs/godot/app_userdata/Sword Godot Study Port/saves/
```

下面是尚未提供游戏内导入界面时的开发者手动方法：

1. 打开 Web 游戏和浏览器开发者工具。
2. 在 Console 顶部把执行上下文切换到真正运行 Godot 画布的 iframe。执行 `typeof engine` 应返回 `"object"`，`document.querySelector("#canvas")?.tagName` 应返回 `"CANVAS"`。
3. 选择一个尚未使用的目标槽位，修改下面脚本中的 `slot`，再在 Console 执行整段脚本。脚本使用 IndexedDB `put`，如果目标槽位已存在，会直接覆盖它。

```javascript
(() => {
  const slot = "010";
  const savePath =
    `/userfs/godot/app_userdata/Sword Godot Study Port/saves/slot_${slot}.json`;

  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".json";

  input.onchange = async () => {
    try {
      const file = input.files[0];
      if (!file) return;

      const contents = new Uint8Array(await file.arrayBuffer());
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open("/userfs");
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });

      if (!db.objectStoreNames.contains("FILE_DATA")) {
        throw new Error("Godot IndexedDB 中不存在 FILE_DATA");
      }

      await new Promise((resolve, reject) => {
        const transaction = db.transaction("FILE_DATA", "readwrite");
        transaction.objectStore("FILE_DATA").put(
          { timestamp: new Date(), mode: 33206, contents },
          savePath
        );
        transaction.oncomplete = resolve;
        transaction.onerror = () => reject(transaction.error);
        transaction.onabort = () => reject(transaction.error);
      });

      db.close();
      console.log(`已导入 Web 存档：${savePath}`);
      setTimeout(() => location.reload(), 300);
    } catch (error) {
      console.error("Web 存档导入失败：", error);
    }
  };

  input.click();
})();
```

脚本会在 IndexedDB 事务完成后自动刷新当前 Godot iframe。刷新后从“读取存档”打开对应槽位。不要把文件写到 `/userfs/saves/`；该路径不是本项目的 `user://saves/`，游戏不会扫描其中的文件。

Web 存档与网页来源、浏览器及当前用户配置绑定。更换域名、使用另一个浏览器配置或清理站点数据后，IndexedDB 中的存档不会自动迁移。

## 把 Web 存档下载到本地

仓库提供了 [`tools/download_web_save.js`](../tools/download_web_save.js)，可以把浏览器 IndexedDB 中的单个存档下载为桌面版也能读取的 `slot_NNN.json`：

1. 打开 Web 游戏和浏览器开发者工具。
2. 在 Console 顶部把执行上下文切换到真正运行 Godot 画布的 iframe。执行 `typeof engine` 应返回 `"object"`。
3. 打开 `tools/download_web_save.js`，复制完整内容并粘贴到 Console 执行。
4. 脚本会列出当前网页来源实际存在的槽位；输入一个槽位编号后，浏览器开始下载对应 JSON 文件。

脚本只读 IndexedDB，不会修改或删除网页存档。下载前会确认记录是 UTF-8 JSON，并检查版本化存档的必要字段；如果浏览器阻止多媒体 iframe 下载，请允许该站点下载文件，或改用桌面浏览器打开正式游戏页。下载所得文件可复制到桌面端的 `user://saves/` 目录，文件名中的槽位号也可以在 `001`–`100` 范围内调整。

## 保存范围

`PalSaveManager` 保存并恢复以下状态：

- 当前场景、队伍位置、方向、五格轨迹和角色场景形象；
- 队伍成员、等级、经验、HP/MP、成长属性、仙术、毒和九种状态；
- 背包、六槽装备、金钱、日夜调色板、BGM 编号及音乐／音效音量；
- 全部 294 个 Scene、5332 个 EventObject、物品／仙术／敌人脚本游标。

装备属性属于当前装备和静态脚本的派生结果，不直接信任存档中的缓存；读档后由 `PalEquipmentManager` 重新执行装备脚本构建。读档加载地图时不重跑 `script_on_enter`，避免重复剧情、重复奖励或重复取得道具。

角色场景形象同样以存档恢复的 `scene_sprite_numbers` 为准。正式 TileMap 与 CPU 对照渲染器每次同步都通过内容数据库解析当前 Sprite 编号，不依赖 `0065` 换装信号清理角色缓存；因此从特殊剧情造型期间读取一个普通造型存档时，不会继续显示读档前的动作。

## 格式与损坏保护

- `format_version` 控制结构兼容；不支持的版本会在菜单中标记为不可读取。
- 内容指纹覆盖当前 PAL 结构化数据；换用不同版本资源后，旧档不会被错误套到不匹配的数据上。
- 载荷使用 SHA-256 校验；截断、手工改坏或校验不符会显示明确错误。
- 写入先生成临时文件，再备份旧档并替换；失败时尽量保留上一份有效存档。
- Godot 存档不承诺兼容原版 SDLPal／DOS `.rpg`，也不应提交 GitHub。

代码 bug 修复后，只要 `format_version` 和 PAL 内容指纹仍兼容，玩家可以继续读取修复前保存的进度。复现问题时可在异常出现前另存一个槽位，并向开发者提供操作步骤；存档可能含原版运行状态，因此默认只在本机使用，不加入仓库。

剧情测试检查点不是完整主线存档。旧版“码头乘船”检查点继续游玩后可能把客栈开场的李大娘叫醒姿势和关闭楼梯写入正式槽位；读取时若 Scene 1 已处于喂药后的稳定入口，且 EventObject 4/11/12 仍精确保持该旧检查点的矛盾组合，探索场景会自动修复并显示提示。正常主线存档不会命中该兼容规则；修复后的进度再次保存即可固化。

## 测试

不依赖原版资源的格式、校验、损坏和往返测试：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_save_system_tests.gd
```

使用本机完整数据验证全部 Scene、EventObject 和装备重建：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_save_system_test.gd
```

使用内存 Toy SDK 验证嵌入式 JavaScript 桥接的分块顺序、下载、排行榜、分数上报和容器关闭：

```bash
node tests/run_toy_bridge_test.mjs
```

存档、Toy 云端和排行榜页视觉快照包含在 `tests/run_local_menu_visual_test.gd`；输出继续写入被忽略的 `generated/pal/visual_tests/`。

启动页入口、独立取消和正式槽位只读恢复回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tests/run_local_startup_load_test.gd
```
