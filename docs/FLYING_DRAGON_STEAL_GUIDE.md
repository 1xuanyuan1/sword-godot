# 飞龙探云手偷窃图鉴

本文按主线推进顺序，以“地图／区域 → 敌人 → 可偷物品”列出《仙剑奇侠传》DOS 繁体中文版的飞龙探云手目标。敌人与物品名称保留 `WORD.DAT` 原文；对象编号只放在末列，用来区分同名但属性不同的敌人。

当前共识别 135 个拥有可偷内容的敌人对象，涉及 72 种物品和金钱。其中 133 个能关联到正式剧情地图，2 个仅存在于备用敌队数据。同一敌人会在它实际出现的每个区域重复列出，方便游玩时直接查当前地图；同一区域的楼层和剧情状态地图已合并。

## 图片显示

怪物图取自本机合法导入的 `ABC.MKF` 战斗首帧，物品图取自 `BALL.MKF`。原版图片不会提交到 Git；首次导入资源后运行以下命令，即可在本文表格中显示缩略图：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/generate_steal_guide_images.gd
```

缩略图只写入被 Git 忽略的 `generated/pal/guide/steal/`。没有本机资源或尚未生成图片时，表格仍会显示敌人与物品文字。

## 偷窃规则

- 飞龙探云手对象 377 的成功脚本以成功参数 `6` 执行 `006A`；每次按 `RandomLong(0, 10) <= 6` 判定，成功概率为 `7/11`。
- 物品类每次成功取得 1 个，并从敌人的“初始可偷数量”中扣除 1；数量耗尽后仍会播放偷窃动作，但不会获得物品。
- 金钱类的数量是敌人携带的初始金钱池。每次成功取得 `剩余金钱池 / RandomLong(2, 3)`，使用整数除法，并从池中扣除本次所得；因此实际金额会随随机数和之前的偷窃结果变化。
- 当背包中的目标物品已经达到 99 个时，本次不会再增加物品。
- 同名敌人如果对象编号不同，会按各自的独立数据分别列出。

## 余杭（客栈、十里坡）

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/495.png" alt="苗人拳" height="48"> | 苗人拳 | — | 金钱 | 300 | `495` |
| <img src="../generated/pal/guide/steal/enemies/404.png" alt="蛹" height="48"> | 蛹 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `404` |
| <img src="../generated/pal/guide/steal/enemies/415.png" alt="酒甕" height="48"> | 酒甕 | <img src="../generated/pal/guide/steal/items/086.png" alt="酒" height="24"> | 酒 | 2 | `415` |
| <img src="../generated/pal/guide/steal/enemies/400.png" alt="黑毛球" height="48"> | 黑毛球 | <img src="../generated/pal/guide/steal/items/091.png" alt="十里香" height="24"> | 十里香 | 1 | `400` |

## 苏州城外

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/480.png" alt="林月如一" height="48"> | 林月如一 | — | 金钱 | 1000 | `480` |

## 苏州客栈

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/477.png" alt="小雙鉤" height="48"> | 小雙鉤 | <img src="../generated/pal/guide/steal/items/154.png" alt="袖裡劍" height="24"> | 袖裡劍 | 1 | `477` |
| <img src="../generated/pal/guide/steal/enemies/481.png" alt="暗器手" height="48"> | 暗器手 | <img src="../generated/pal/guide/steal/items/153.png" alt="梅花鏢" height="24"> | 梅花鏢 | 2 | `481` |
| <img src="../generated/pal/guide/steal/enemies/476.png" alt="錘護院" height="48"> | 錘護院 | <img src="../generated/pal/guide/steal/items/250.png" alt="鐵護腕" height="24"> | 鐵護腕 | 1 | `476` |

## 林家堡

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/483.png" alt="林月如二" height="48"> | 林月如二 | — | 金钱 | 1000 | `483` |

## 隐龙窟

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/520.png" alt="九頭蛇" height="48"> | 九頭蛇 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 2 | `520` |
| <img src="../generated/pal/guide/steal/enemies/491.png" alt="五毒巨蛇" height="48"> | 五毒巨蛇 | <img src="../generated/pal/guide/steal/items/130.png" alt="腹蛇涎" height="24"> | 腹蛇涎 | 1 | `491` |
| <img src="../generated/pal/guide/steal/enemies/486.png" alt="半人蛇" height="48"> | 半人蛇 | <img src="../generated/pal/guide/steal/items/096.png" alt="贖魂燈" height="24"> | 贖魂燈 | 1 | `486` |
| <img src="../generated/pal/guide/steal/enemies/469.png" alt="狐狸精" height="48"> | 狐狸精 | <img src="../generated/pal/guide/steal/items/127.png" alt="忘魂花" height="24"> | 忘魂花 | 2 | `469` |
| <img src="../generated/pal/guide/steal/enemies/488.png" alt="綠色小蛇" height="48"> | 綠色小蛇 | <img src="../generated/pal/guide/steal/items/117.png" alt="毒蛇卵" height="24"> | 毒蛇卵 | 1 | `488` |
| <img src="../generated/pal/guide/steal/enemies/404.png" alt="蛹" height="48"> | 蛹 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `404` |
| <img src="../generated/pal/guide/steal/enemies/426.png" alt="蜥蜴" height="48"> | 蜥蜴 | — | 金钱 | 1 | `426` |
| <img src="../generated/pal/guide/steal/enemies/487.png" alt="赤色小蛇" height="48"> | 赤色小蛇 | <img src="../generated/pal/guide/steal/items/117.png" alt="毒蛇卵" height="24"> | 毒蛇卵 | 2 | `487` |
| <img src="../generated/pal/guide/steal/enemies/415.png" alt="酒甕" height="48"> | 酒甕 | <img src="../generated/pal/guide/steal/items/086.png" alt="酒" height="24"> | 酒 | 2 | `415` |
| <img src="../generated/pal/guide/steal/enemies/400.png" alt="黑毛球" height="48"> | 黑毛球 | <img src="../generated/pal/guide/steal/items/091.png" alt="十里香" height="24"> | 十里香 | 1 | `400` |

## 白河村后山路

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/419.png" alt="殭屍" height="48"> | 殭屍 | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 1 | `419` |
| <img src="../generated/pal/guide/steal/enemies/404.png" alt="蛹" height="48"> | 蛹 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `404` |

## 玉佛寺

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/524.png" alt="智修大師" height="48"> | 智修大師 | <img src="../generated/pal/guide/steal/items/072.png" alt="舍利子" height="24"> | 舍利子 | 9 | `524` |
| <img src="../generated/pal/guide/steal/enemies/482.png" alt="智杖和尚" height="48"> | 智杖和尚 | <img src="../generated/pal/guide/steal/items/074.png" alt="銀杏子" height="24"> | 銀杏子 | 1 | `482` |
| <img src="../generated/pal/guide/steal/enemies/453.png" alt="灰衣喇嘛" height="48"> | 灰衣喇嘛 | <img src="../generated/pal/guide/steal/items/072.png" alt="舍利子" height="24"> | 舍利子 | 1 | `453` |
| <img src="../generated/pal/guide/steal/enemies/451.png" alt="紅衣喇嘛" height="48"> | 紅衣喇嘛 | <img src="../generated/pal/guide/steal/items/254.png" alt="唸珠" height="24"> | 唸珠 | 2 | `451` |
| <img src="../generated/pal/guide/steal/enemies/442.png" alt="黃衣刀僧" height="48"> | 黃衣刀僧 | — | 金钱 | 500 | `442` |

## 黑水镇／乱葬岗

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/408.png" alt="半截殭屍" height="48"> | 半截殭屍 | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 1 | `408` |
| <img src="../generated/pal/guide/steal/enemies/419.png" alt="殭屍" height="48"> | 殭屍 | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 1 | `419` |
| <img src="../generated/pal/guide/steal/enemies/452.png" alt="白無常" height="48"> | 白無常 | <img src="../generated/pal/guide/steal/items/158.png" alt="吸星鎖" height="24"> | 吸星鎖 | 1 | `452` |
| <img src="../generated/pal/guide/steal/enemies/409.png" alt="菜刀婆婆" height="48"> | 菜刀婆婆 | <img src="../generated/pal/guide/steal/items/167.png" alt="短刀" height="24"> | 短刀 | 1 | `409` |
| <img src="../generated/pal/guide/steal/enemies/415.png" alt="酒甕" height="48"> | 酒甕 | <img src="../generated/pal/guide/steal/items/086.png" alt="酒" height="24"> | 酒 | 2 | `415` |
| <img src="../generated/pal/guide/steal/enemies/407.png" alt="開膛鬼" height="48"> | 開膛鬼 | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 1 | `407` |
| <img src="../generated/pal/guide/steal/enemies/400.png" alt="黑毛球" height="48"> | 黑毛球 | <img src="../generated/pal/guide/steal/items/091.png" alt="十里香" height="24"> | 十里香 | 1 | `400` |

## 将军冢／血池

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/491.png" alt="五毒巨蛇" height="48"> | 五毒巨蛇 | <img src="../generated/pal/guide/steal/items/130.png" alt="腹蛇涎" height="24"> | 腹蛇涎 | 1 | `491` |
| <img src="../generated/pal/guide/steal/enemies/436.png" alt="伏地羅漢" height="48"> | 伏地羅漢 | <img src="../generated/pal/guide/steal/items/067.png" alt="風靈符" height="24"> | 風靈符 | 1 | `436` |
| <img src="../generated/pal/guide/steal/enemies/408.png" alt="半截殭屍" height="48"> | 半截殭屍 | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 1 | `408` |
| <img src="../generated/pal/guide/steal/enemies/419.png" alt="殭屍" height="48"> | 殭屍 | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 1 | `419` |
| <img src="../generated/pal/guide/steal/enemies/504.png" alt="殭屍兵A" height="48"> | 殭屍兵A | <img src="../generated/pal/guide/steal/items/100.png" alt="行軍丹" height="24"> | 行軍丹 | 1 | `504` |
| <img src="../generated/pal/guide/steal/enemies/505.png" alt="殭屍兵B" height="48"> | 殭屍兵B | <img src="../generated/pal/guide/steal/items/100.png" alt="行軍丹" height="24"> | 行軍丹 | 1 | `505` |
| <img src="../generated/pal/guide/steal/enemies/506.png" alt="殭屍兵C" height="48"> | 殭屍兵C | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 2 | `506` |
| <img src="../generated/pal/guide/steal/enemies/472.png" alt="殭屍王" height="48"> | 殭屍王 | <img src="../generated/pal/guide/steal/items/213.png" alt="青銅甲" height="24"> | 青銅甲 | 1 | `472` |
| <img src="../generated/pal/guide/steal/enemies/452.png" alt="白無常" height="48"> | 白無常 | <img src="../generated/pal/guide/steal/items/158.png" alt="吸星鎖" height="24"> | 吸星鎖 | 1 | `452` |
| <img src="../generated/pal/guide/steal/enemies/488.png" alt="綠色小蛇" height="48"> | 綠色小蛇 | <img src="../generated/pal/guide/steal/items/117.png" alt="毒蛇卵" height="24"> | 毒蛇卵 | 1 | `488` |
| <img src="../generated/pal/guide/steal/enemies/409.png" alt="菜刀婆婆" height="48"> | 菜刀婆婆 | <img src="../generated/pal/guide/steal/items/167.png" alt="短刀" height="24"> | 短刀 | 1 | `409` |
| <img src="../generated/pal/guide/steal/enemies/406.png" alt="血口蟲" height="48"> | 血口蟲 | <img src="../generated/pal/guide/steal/items/147.png" alt="碧血蠶" height="24"> | 碧血蠶 | 1 | `406` |
| <img src="../generated/pal/guide/steal/enemies/473.png" alt="赤鬼王" height="48"> | 赤鬼王 | <img src="../generated/pal/guide/steal/items/162.png" alt="血玲瓏" height="24"> | 血玲瓏 | 2 | `473` |
| <img src="../generated/pal/guide/steal/enemies/439.png" alt="連體妖" height="48"> | 連體妖 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 1 | `439` |
| <img src="../generated/pal/guide/steal/enemies/407.png" alt="開膛鬼" height="48"> | 開膛鬼 | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 1 | `407` |

## 鬼阴山

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/520.png" alt="九頭蛇" height="48"> | 九頭蛇 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 2 | `520` |
| <img src="../generated/pal/guide/steal/enemies/454.png" alt="刀手" height="48"> | 刀手 | — | 金钱 | 400 | `454` |
| <img src="../generated/pal/guide/steal/enemies/475.png" alt="劍護院" height="48"> | 劍護院 | — | 金钱 | 500 | `475` |
| <img src="../generated/pal/guide/steal/enemies/477.png" alt="小雙鉤" height="48"> | 小雙鉤 | <img src="../generated/pal/guide/steal/items/154.png" alt="袖裡劍" height="24"> | 袖裡劍 | 1 | `477` |
| <img src="../generated/pal/guide/steal/enemies/481.png" alt="暗器手" height="48"> | 暗器手 | <img src="../generated/pal/guide/steal/items/153.png" alt="梅花鏢" height="24"> | 梅花鏢 | 2 | `481` |
| <img src="../generated/pal/guide/steal/enemies/450.png" alt="槍卒" height="48"> | 槍卒 | — | 金钱 | 300 | `450` |
| <img src="../generated/pal/guide/steal/enemies/496.png" alt="石長老" height="48"> | 石長老 | <img src="../generated/pal/guide/steal/items/123.png" alt="孔雀膽" height="24"> | 孔雀膽 | 3 | `496` |
| <img src="../generated/pal/guide/steal/enemies/488.png" alt="綠色小蛇" height="48"> | 綠色小蛇 | <img src="../generated/pal/guide/steal/items/117.png" alt="毒蛇卵" height="24"> | 毒蛇卵 | 1 | `488` |
| <img src="../generated/pal/guide/steal/enemies/443.png" alt="羅漢腿" height="48"> | 羅漢腿 | — | 金钱 | 100 | `443` |
| <img src="../generated/pal/guide/steal/enemies/485.png" alt="胖苗" height="48"> | 胖苗 | <img src="../generated/pal/guide/steal/items/101.png" alt="金創藥" height="24"> | 金創藥 | 1 | `485` |
| <img src="../generated/pal/guide/steal/enemies/495.png" alt="苗人拳" height="48"> | 苗人拳 | — | 金钱 | 300 | `495` |
| <img src="../generated/pal/guide/steal/enemies/527.png" alt="苗槍卒" height="48"> | 苗槍卒 | — | 金钱 | 1000 | `527` |
| <img src="../generated/pal/guide/steal/enemies/404.png" alt="蛹" height="48"> | 蛹 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `404` |
| <img src="../generated/pal/guide/steal/enemies/476.png" alt="錘護院" height="48"> | 錘護院 | <img src="../generated/pal/guide/steal/items/250.png" alt="鐵護腕" height="24"> | 鐵護腕 | 1 | `476` |

## 鬼阴山后山道

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/491.png" alt="五毒巨蛇" height="48"> | 五毒巨蛇 | <img src="../generated/pal/guide/steal/items/130.png" alt="腹蛇涎" height="24"> | 腹蛇涎 | 1 | `491` |
| <img src="../generated/pal/guide/steal/enemies/410.png" alt="小土鬼" height="48"> | 小土鬼 | <img src="../generated/pal/guide/steal/items/087.png" alt="雄黃" height="24"> | 雄黃 | 2 | `410` |
| <img src="../generated/pal/guide/steal/enemies/488.png" alt="綠色小蛇" height="48"> | 綠色小蛇 | <img src="../generated/pal/guide/steal/items/117.png" alt="毒蛇卵" height="24"> | 毒蛇卵 | 1 | `488` |
| <img src="../generated/pal/guide/steal/enemies/537.png" alt="綠食火蟾" height="48"> | 綠食火蟾 | <img src="../generated/pal/guide/steal/items/119.png" alt="毒蟾卵" height="24"> | 毒蟾卵 | 2 | `537` |
| <img src="../generated/pal/guide/steal/enemies/434.png" alt="肥肥" height="48"> | 肥肥 | — | 金钱 | 340 | `434` |
| <img src="../generated/pal/guide/steal/enemies/426.png" alt="蜥蜴" height="48"> | 蜥蜴 | — | 金钱 | 1 | `426` |
| <img src="../generated/pal/guide/steal/enemies/406.png" alt="血口蟲" height="48"> | 血口蟲 | <img src="../generated/pal/guide/steal/items/147.png" alt="碧血蠶" height="24"> | 碧血蠶 | 1 | `406` |
| <img src="../generated/pal/guide/steal/enemies/487.png" alt="赤色小蛇" height="48"> | 赤色小蛇 | <img src="../generated/pal/guide/steal/items/117.png" alt="毒蛇卵" height="24"> | 毒蛇卵 | 2 | `487` |

## 扬州

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/478.png" alt="女飛賊" height="48"> | 女飛賊 | <img src="../generated/pal/guide/steal/items/255.png" alt="銀針" height="24"> | 銀針 | 9 | `478` |
| <img src="../generated/pal/guide/steal/enemies/479.png" alt="女飛賊" height="48"> | 女飛賊 | <img src="../generated/pal/guide/steal/items/255.png" alt="銀針" height="24"> | 銀針 | 9 | `479` |
| <img src="../generated/pal/guide/steal/enemies/526.png" alt="黑衣女賊" height="48"> | 黑衣女賊 | <img src="../generated/pal/guide/steal/items/154.png" alt="袖裡劍" height="24"> | 袖裡劍 | 2 | `526` |

## 蛤蟆谷／蛤蟆洞

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/491.png" alt="五毒巨蛇" height="48"> | 五毒巨蛇 | <img src="../generated/pal/guide/steal/items/130.png" alt="腹蛇涎" height="24"> | 腹蛇涎 | 1 | `491` |
| <img src="../generated/pal/guide/steal/enemies/410.png" alt="小土鬼" height="48"> | 小土鬼 | <img src="../generated/pal/guide/steal/items/087.png" alt="雄黃" height="24"> | 雄黃 | 2 | `410` |
| <img src="../generated/pal/guide/steal/enemies/516.png" alt="小毒蠍" height="48"> | 小毒蠍 | <img src="../generated/pal/guide/steal/items/118.png" alt="毒蠍卵" height="24"> | 毒蠍卵 | 1 | `516` |
| <img src="../generated/pal/guide/steal/enemies/537.png" alt="綠食火蟾" height="48"> | 綠食火蟾 | <img src="../generated/pal/guide/steal/items/119.png" alt="毒蟾卵" height="24"> | 毒蟾卵 | 2 | `537` |
| <img src="../generated/pal/guide/steal/enemies/434.png" alt="肥肥" height="48"> | 肥肥 | — | 金钱 | 340 | `434` |
| <img src="../generated/pal/guide/steal/enemies/538.png" alt="藍食火蟾" height="48"> | 藍食火蟾 | <img src="../generated/pal/guide/steal/items/142.png" alt="冰蠶蠱" height="24"> | 冰蠶蠱 | 1 | `538` |
| <img src="../generated/pal/guide/steal/enemies/426.png" alt="蜥蜴" height="48"> | 蜥蜴 | — | 金钱 | 1 | `426` |
| <img src="../generated/pal/guide/steal/enemies/406.png" alt="血口蟲" height="48"> | 血口蟲 | <img src="../generated/pal/guide/steal/items/147.png" alt="碧血蠶" height="24"> | 碧血蠶 | 1 | `406` |
| <img src="../generated/pal/guide/steal/enemies/517.png" alt="赤蜈蚣" height="48"> | 赤蜈蚣 | <img src="../generated/pal/guide/steal/items/121.png" alt="蜈蚣卵" height="24"> | 蜈蚣卵 | 1 | `517` |
| <img src="../generated/pal/guide/steal/enemies/500.png" alt="金蟾鬼母" height="48"> | 金蟾鬼母 | <img src="../generated/pal/guide/steal/items/125.png" alt="斷腸草" height="24"> | 斷腸草 | 9 | `500` |
| <img src="../generated/pal/guide/steal/enemies/518.png" alt="食火蟾" height="48"> | 食火蟾 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 1 | `518` |

## 长安·尚书府

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/525.png" alt="林天南" height="48"> | 林天南 | <img src="../generated/pal/guide/steal/items/184.png" alt="龍泉劍" height="24"> | 龍泉劍 | 1 | `525` |
| <img src="../generated/pal/guide/steal/enemies/468.png" alt="蝶精彩依" height="48"> | 蝶精彩依 | <img src="../generated/pal/guide/steal/items/109.png" alt="天仙玉露" height="24"> | 天仙玉露 | 3 | `468` |

## 毒仙林

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/514.png" alt="五彩蜘蛛" height="48"> | 五彩蜘蛛 | <img src="../generated/pal/guide/steal/items/159.png" alt="纏魂絲" height="24"> | 纏魂絲 | 1 | `514` |
| <img src="../generated/pal/guide/steal/enemies/435.png" alt="六腳蜘蛛" height="48"> | 六腳蜘蛛 | <img src="../generated/pal/guide/steal/items/159.png" alt="纏魂絲" height="24"> | 纏魂絲 | 2 | `435` |
| <img src="../generated/pal/guide/steal/enemies/508.png" alt="小樹妖" height="48"> | 小樹妖 | <img src="../generated/pal/guide/steal/items/129.png" alt="鬼枯籐" height="24"> | 鬼枯籐 | 1 | `508` |
| <img src="../generated/pal/guide/steal/enemies/412.png" alt="小蜘蛛" height="48"> | 小蜘蛛 | <img src="../generated/pal/guide/steal/items/120.png" alt="蜘蛛卵" height="24"> | 蜘蛛卵 | 1 | `412` |
| <img src="../generated/pal/guide/steal/enemies/498.png" alt="黑蜘蛛精" height="48"> | 黑蜘蛛精 | <img src="../generated/pal/guide/steal/items/159.png" alt="纏魂絲" height="24"> | 纏魂絲 | 3 | `498` |

## 蜀山云海／锁妖塔外

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/446.png" alt="哈將" height="48"> | 哈將 | <img src="../generated/pal/guide/steal/items/160.png" alt="綑仙繩" height="24"> | 綑仙繩 | 1 | `446` |
| <img src="../generated/pal/guide/steal/enemies/418.png" alt="小雷公" height="48"> | 小雷公 | <img src="../generated/pal/guide/steal/items/068.png" alt="雷靈符" height="24"> | 雷靈符 | 3 | `418` |
| <img src="../generated/pal/guide/steal/enemies/448.png" alt="巨斧武士" height="48"> | 巨斧武士 | — | 金钱 | 500 | `448` |
| <img src="../generated/pal/guide/steal/enemies/449.png" alt="角力士" height="48"> | 角力士 | <img src="../generated/pal/guide/steal/items/105.png" alt="還神丹" height="24"> | 還神丹 | 1 | `449` |
| <img src="../generated/pal/guide/steal/enemies/444.png" alt="醉羅漢" height="48"> | 醉羅漢 | <img src="../generated/pal/guide/steal/items/086.png" alt="酒" height="24"> | 酒 | 3 | `444` |
| <img src="../generated/pal/guide/steal/enemies/447.png" alt="金鎚武士" height="48"> | 金鎚武士 | <img src="../generated/pal/guide/steal/items/063.png" alt="金剛符" height="24"> | 金剛符 | 1 | `447` |

## 锁妖塔

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/520.png" alt="九頭蛇" height="48"> | 九頭蛇 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 2 | `520` |
| <img src="../generated/pal/guide/steal/enemies/491.png" alt="五毒巨蛇" height="48"> | 五毒巨蛇 | <img src="../generated/pal/guide/steal/items/130.png" alt="腹蛇涎" height="24"> | 腹蛇涎 | 1 | `491` |
| <img src="../generated/pal/guide/steal/enemies/436.png" alt="伏地羅漢" height="48"> | 伏地羅漢 | <img src="../generated/pal/guide/steal/items/067.png" alt="風靈符" height="24"> | 風靈符 | 1 | `436` |
| <img src="../generated/pal/guide/steal/enemies/428.png" alt="公揹婆" height="48"> | 公揹婆 | <img src="../generated/pal/guide/steal/items/080.png" alt="糖葫蘆" height="24"> | 糖葫蘆 | 3 | `428` |
| <img src="../generated/pal/guide/steal/enemies/543.png" alt="冰神龍" height="48"> | 冰神龍 | <img src="../generated/pal/guide/steal/items/069.png" alt="水靈符" height="24"> | 水靈符 | 3 | `543` |
| <img src="../generated/pal/guide/steal/enemies/440.png" alt="刑天" height="48"> | 刑天 | <img src="../generated/pal/guide/steal/items/101.png" alt="金創藥" height="24"> | 金創藥 | 1 | `440` |
| <img src="../generated/pal/guide/steal/enemies/494.png" alt="劍老頭" height="48"> | 劍老頭 | <img src="../generated/pal/guide/steal/items/066.png" alt="天師符" height="24"> | 天師符 | 9 | `494` |
| <img src="../generated/pal/guide/steal/enemies/408.png" alt="半截殭屍" height="48"> | 半截殭屍 | <img src="../generated/pal/guide/steal/items/116.png" alt="屍腐肉" height="24"> | 屍腐肉 | 1 | `408` |
| <img src="../generated/pal/guide/steal/enemies/541.png" alt="土神龍" height="48"> | 土神龍 | <img src="../generated/pal/guide/steal/items/071.png" alt="土靈符" height="24"> | 土靈符 | 3 | `541` |
| <img src="../generated/pal/guide/steal/enemies/532.png" alt="土蛟龍" height="48"> | 土蛟龍 | <img src="../generated/pal/guide/steal/items/114.png" alt="八仙石" height="24"> | 八仙石 | 1 | `532` |
| <img src="../generated/pal/guide/steal/enemies/529.png" alt="天鬼皇" height="48"> | 天鬼皇 | <img src="../generated/pal/guide/steal/items/098.png" alt="天香續命露" height="24"> | 天香續命露 | 1 | `529` |
| <img src="../generated/pal/guide/steal/enemies/410.png" alt="小土鬼" height="48"> | 小土鬼 | <img src="../generated/pal/guide/steal/items/087.png" alt="雄黃" height="24"> | 雄黃 | 2 | `410` |
| <img src="../generated/pal/guide/steal/enemies/508.png" alt="小樹妖" height="48"> | 小樹妖 | <img src="../generated/pal/guide/steal/items/129.png" alt="鬼枯籐" height="24"> | 鬼枯籐 | 1 | `508` |
| <img src="../generated/pal/guide/steal/enemies/422.png" alt="怪老子" height="48"> | 怪老子 | <img src="../generated/pal/guide/steal/items/126.png" alt="醍醐香" height="24"> | 醍醐香 | 1 | `422` |
| <img src="../generated/pal/guide/steal/enemies/519.png" alt="明王" height="48"> | 明王 | <img src="../generated/pal/guide/steal/items/073.png" alt="玉菩提" height="24"> | 玉菩提 | 9 | `519` |
| <img src="../generated/pal/guide/steal/enemies/539.png" alt="毒神龍" height="48"> | 毒神龍 | <img src="../generated/pal/guide/steal/items/278.png" alt="毒龍膽" height="24"> | 毒龍膽 | 13 | `539` |
| <img src="../generated/pal/guide/steal/enemies/542.png" alt="火神龍" height="48"> | 火神龍 | <img src="../generated/pal/guide/steal/items/070.png" alt="火靈符" height="24"> | 火靈符 | 3 | `542` |
| <img src="../generated/pal/guide/steal/enemies/469.png" alt="狐狸精" height="48"> | 狐狸精 | <img src="../generated/pal/guide/steal/items/127.png" alt="忘魂花" height="24"> | 忘魂花 | 2 | `469` |
| <img src="../generated/pal/guide/steal/enemies/452.png" alt="白無常" height="48"> | 白無常 | <img src="../generated/pal/guide/steal/items/158.png" alt="吸星鎖" height="24"> | 吸星鎖 | 1 | `452` |
| <img src="../generated/pal/guide/steal/enemies/535.png" alt="紫獸人" height="48"> | 紫獸人 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `535` |
| <img src="../generated/pal/guide/steal/enemies/434.png" alt="肥肥" height="48"> | 肥肥 | — | 金钱 | 340 | `434` |
| <img src="../generated/pal/guide/steal/enemies/416.png" alt="芒刺鬼" height="48"> | 芒刺鬼 | <img src="../generated/pal/guide/steal/items/144.png" alt="食妖蟲" height="24"> | 食妖蟲 | 1 | `416` |
| <img src="../generated/pal/guide/steal/enemies/417.png" alt="豬頭人" height="48"> | 豬頭人 | — | 金钱 | 500 | `417` |
| <img src="../generated/pal/guide/steal/enemies/420.png" alt="跳跳蛙" height="48"> | 跳跳蛙 | <img src="../generated/pal/guide/steal/items/112.png" alt="試煉果" height="24"> | 試煉果 | 1 | `420` |
| <img src="../generated/pal/guide/steal/enemies/439.png" alt="連體妖" height="48"> | 連體妖 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 1 | `439` |
| <img src="../generated/pal/guide/steal/enemies/415.png" alt="酒甕" height="48"> | 酒甕 | <img src="../generated/pal/guide/steal/items/086.png" alt="酒" height="24"> | 酒 | 2 | `415` |
| <img src="../generated/pal/guide/steal/enemies/540.png" alt="金神龍" height="48"> | 金神龍 | <img src="../generated/pal/guide/steal/items/063.png" alt="金剛符" height="24"> | 金剛符 | 3 | `540` |
| <img src="../generated/pal/guide/steal/enemies/465.png" alt="金蟾" height="48"> | 金蟾 | <img src="../generated/pal/guide/steal/items/119.png" alt="毒蟾卵" height="24"> | 毒蟾卵 | 10 | `465` |
| <img src="../generated/pal/guide/steal/enemies/414.png" alt="鐮刀鼬" height="48"> | 鐮刀鼬 | <img src="../generated/pal/guide/steal/items/162.png" alt="血玲瓏" height="24"> | 血玲瓏 | 1 | `414` |
| <img src="../generated/pal/guide/steal/enemies/455.png" alt="鐵叉牛頭" height="48"> | 鐵叉牛頭 | — | 金钱 | 600 | `455` |
| <img src="../generated/pal/guide/steal/enemies/545.png" alt="雷神龍" height="48"> | 雷神龍 | <img src="../generated/pal/guide/steal/items/068.png" alt="雷靈符" height="24"> | 雷靈符 | 3 | `545` |
| <img src="../generated/pal/guide/steal/enemies/544.png" alt="風神龍" height="48"> | 風神龍 | <img src="../generated/pal/guide/steal/items/067.png" alt="風靈符" height="24"> | 風靈符 | 3 | `544` |

## 桃花源／树洞

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/514.png" alt="五彩蜘蛛" height="48"> | 五彩蜘蛛 | <img src="../generated/pal/guide/steal/items/159.png" alt="纏魂絲" height="24"> | 纏魂絲 | 1 | `514` |
| <img src="../generated/pal/guide/steal/enemies/507.png" alt="半人樹妖" height="48"> | 半人樹妖 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `507` |
| <img src="../generated/pal/guide/steal/enemies/508.png" alt="小樹妖" height="48"> | 小樹妖 | <img src="../generated/pal/guide/steal/items/129.png" alt="鬼枯籐" height="24"> | 鬼枯籐 | 1 | `508` |
| <img src="../generated/pal/guide/steal/enemies/509.png" alt="尖頭樹妖" height="48"> | 尖頭樹妖 | <img src="../generated/pal/guide/steal/items/129.png" alt="鬼枯籐" height="24"> | 鬼枯籐 | 1 | `509` |
| <img src="../generated/pal/guide/steal/enemies/474.png" alt="木靈道士" height="48"> | 木靈道士 | <img src="../generated/pal/guide/steal/items/062.png" alt="聖靈符" height="24"> | 聖靈符 | 3 | `474` |
| <img src="../generated/pal/guide/steal/enemies/401.png" alt="爛香菇" height="48"> | 爛香菇 | <img src="../generated/pal/guide/steal/items/107.png" alt="靈山仙芝" height="24"> | 靈山仙芝 | 1 | `401` |
| <img src="../generated/pal/guide/steal/enemies/470.png" alt="牡丹精" height="48"> | 牡丹精 | <img src="../generated/pal/guide/steal/items/109.png" alt="天仙玉露" height="24"> | 天仙玉露 | 1 | `470` |
| <img src="../generated/pal/guide/steal/enemies/469.png" alt="狐狸精" height="48"> | 狐狸精 | <img src="../generated/pal/guide/steal/items/127.png" alt="忘魂花" height="24"> | 忘魂花 | 2 | `469` |
| <img src="../generated/pal/guide/steal/enemies/413.png" alt="石鬼頭" height="48"> | 石鬼頭 | <img src="../generated/pal/guide/steal/items/113.png" alt="女媧石" height="24"> | 女媧石 | 1 | `413` |
| <img src="../generated/pal/guide/steal/enemies/537.png" alt="綠食火蟾" height="48"> | 綠食火蟾 | <img src="../generated/pal/guide/steal/items/119.png" alt="毒蟾卵" height="24"> | 毒蟾卵 | 2 | `537` |
| <img src="../generated/pal/guide/steal/enemies/404.png" alt="蛹" height="48"> | 蛹 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `404` |
| <img src="../generated/pal/guide/steal/enemies/402.png" alt="鳳梨小妖" height="48"> | 鳳梨小妖 | <img src="../generated/pal/guide/steal/items/104.png" alt="鼠兒果" height="24"> | 鼠兒果 | 1 | `402` |
| <img src="../generated/pal/guide/steal/enemies/512.png" alt="黑衣道眾" height="48"> | 黑衣道眾 | <img src="../generated/pal/guide/steal/items/067.png" alt="風靈符" height="24"> | 風靈符 | 1 | `512` |

## 神木林

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/514.png" alt="五彩蜘蛛" height="48"> | 五彩蜘蛛 | <img src="../generated/pal/guide/steal/items/159.png" alt="纏魂絲" height="24"> | 纏魂絲 | 1 | `514` |
| <img src="../generated/pal/guide/steal/enemies/513.png" alt="狒狒" height="48"> | 狒狒 | <img src="../generated/pal/guide/steal/items/092.png" alt="水果" height="24"> | 水果 | 2 | `513` |
| <img src="../generated/pal/guide/steal/enemies/456.png" alt="猩猩" height="48"> | 猩猩 | <img src="../generated/pal/guide/steal/items/092.png" alt="水果" height="24"> | 水果 | 2 | `456` |
| <img src="../generated/pal/guide/steal/enemies/515.png" alt="紫鳳鳥" height="48"> | 紫鳳鳥 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `515` |
| <img src="../generated/pal/guide/steal/enemies/503.png" alt="鳥人" height="48"> | 鳥人 | <img src="../generated/pal/guide/steal/items/151.png" alt="引路蜂" height="24"> | 引路蜂 | 1 | `503` |
| <img src="../generated/pal/guide/steal/enemies/464.png" alt="鳳凰" height="48"> | 鳳凰 | <img src="../generated/pal/guide/steal/items/206.png" alt="鳳凰羽毛" height="24"> | 鳳凰羽毛 | 3 | `464` |

## 火麒麟洞

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/520.png" alt="九頭蛇" height="48"> | 九頭蛇 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 2 | `520` |
| <img src="../generated/pal/guide/steal/enemies/423.png" alt="樹根" height="48"> | 樹根 | <img src="../generated/pal/guide/steal/items/129.png" alt="鬼枯籐" height="24"> | 鬼枯籐 | 1 | `423` |
| <img src="../generated/pal/guide/steal/enemies/531.png" alt="火蛟龍" height="48"> | 火蛟龍 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 1 | `531` |
| <img src="../generated/pal/guide/steal/enemies/538.png" alt="藍食火蟾" height="48"> | 藍食火蟾 | <img src="../generated/pal/guide/steal/items/142.png" alt="冰蠶蠱" height="24"> | 冰蠶蠱 | 1 | `538` |
| <img src="../generated/pal/guide/steal/enemies/521.png" alt="雷龍" height="48"> | 雷龍 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `521` |
| <img src="../generated/pal/guide/steal/enemies/518.png" alt="食火蟾" height="48"> | 食火蟾 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 1 | `518` |
| <img src="../generated/pal/guide/steal/enemies/463.png" alt="麒麟" height="48"> | 麒麟 | <img src="../generated/pal/guide/steal/items/149.png" alt="赤血蠶" height="24"> | 赤血蠶 | 3 | `463` |

## 大理

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/458.png" alt="小苗女" height="48"> | 小苗女 | <img src="../generated/pal/guide/steal/items/179.png" alt="苗刀" height="24"> | 苗刀 | 1 | `458` |
| <img src="../generated/pal/guide/steal/enemies/485.png" alt="胖苗" height="48"> | 胖苗 | <img src="../generated/pal/guide/steal/items/101.png" alt="金創藥" height="24"> | 金創藥 | 1 | `485` |
| <img src="../generated/pal/guide/steal/enemies/548.png" alt="苗人拳" height="48"> | 苗人拳 | — | 金钱 | 1000 | `548` |
| <img src="../generated/pal/guide/steal/enemies/549.png" alt="苗槍卒" height="48"> | 苗槍卒 | — | 金钱 | 1200 | `549` |
| <img src="../generated/pal/guide/steal/enemies/460.png" alt="長鞭苗女" height="48"> | 長鞭苗女 | <img src="../generated/pal/guide/steal/items/163.png" alt="長鞭" height="24"> | 長鞭 | 1 | `460` |
| <img src="../generated/pal/guide/steal/enemies/457.png" alt="雙節棍苗" height="48"> | 雙節棍苗 | — | 金钱 | 1600 | `457` |

## 试炼窟

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/520.png" alt="九頭蛇" height="48"> | 九頭蛇 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 2 | `520` |
| <img src="../generated/pal/guide/steal/enemies/514.png" alt="五彩蜘蛛" height="48"> | 五彩蜘蛛 | <img src="../generated/pal/guide/steal/items/159.png" alt="纏魂絲" height="24"> | 纏魂絲 | 1 | `514` |
| <img src="../generated/pal/guide/steal/enemies/491.png" alt="五毒巨蛇" height="48"> | 五毒巨蛇 | <img src="../generated/pal/guide/steal/items/130.png" alt="腹蛇涎" height="24"> | 腹蛇涎 | 1 | `491` |
| <img src="../generated/pal/guide/steal/enemies/490.png" alt="五毒巨蠍" height="48"> | 五毒巨蠍 | <img src="../generated/pal/guide/steal/items/133.png" alt="赤蠍粉" height="24"> | 赤蠍粉 | 1 | `490` |
| <img src="../generated/pal/guide/steal/enemies/492.png" alt="五毒蜈蚣" height="48"> | 五毒蜈蚣 | <img src="../generated/pal/guide/steal/items/157.png" alt="毒龍砂" height="24"> | 毒龍砂 | 1 | `492` |
| <img src="../generated/pal/guide/steal/enemies/536.png" alt="土蜘蛛" height="48"> | 土蜘蛛 | <img src="../generated/pal/guide/steal/items/120.png" alt="蜘蛛卵" height="24"> | 蜘蛛卵 | 1 | `536` |
| <img src="../generated/pal/guide/steal/enemies/508.png" alt="小樹妖" height="48"> | 小樹妖 | <img src="../generated/pal/guide/steal/items/129.png" alt="鬼枯籐" height="24"> | 鬼枯籐 | 1 | `508` |
| <img src="../generated/pal/guide/steal/enemies/516.png" alt="小毒蠍" height="48"> | 小毒蠍 | <img src="../generated/pal/guide/steal/items/118.png" alt="毒蠍卵" height="24"> | 毒蠍卵 | 1 | `516` |
| <img src="../generated/pal/guide/steal/enemies/412.png" alt="小蜘蛛" height="48"> | 小蜘蛛 | <img src="../generated/pal/guide/steal/items/120.png" alt="蜘蛛卵" height="24"> | 蜘蛛卵 | 1 | `412` |
| <img src="../generated/pal/guide/steal/enemies/470.png" alt="牡丹精" height="48"> | 牡丹精 | <img src="../generated/pal/guide/steal/items/109.png" alt="天仙玉露" height="24"> | 天仙玉露 | 1 | `470` |
| <img src="../generated/pal/guide/steal/enemies/469.png" alt="狐狸精" height="48"> | 狐狸精 | <img src="../generated/pal/guide/steal/items/127.png" alt="忘魂花" height="24"> | 忘魂花 | 2 | `469` |
| <img src="../generated/pal/guide/steal/enemies/550.png" alt="紫九頭蛇" height="48"> | 紫九頭蛇 | <img src="../generated/pal/guide/steal/items/142.png" alt="冰蠶蠱" height="24"> | 冰蠶蠱 | 2 | `550` |
| <img src="../generated/pal/guide/steal/enemies/488.png" alt="綠色小蛇" height="48"> | 綠色小蛇 | <img src="../generated/pal/guide/steal/items/117.png" alt="毒蛇卵" height="24"> | 毒蛇卵 | 1 | `488` |
| <img src="../generated/pal/guide/steal/enemies/537.png" alt="綠食火蟾" height="48"> | 綠食火蟾 | <img src="../generated/pal/guide/steal/items/119.png" alt="毒蟾卵" height="24"> | 毒蟾卵 | 2 | `537` |
| <img src="../generated/pal/guide/steal/enemies/501.png" alt="蓋羅嬌" height="48"> | 蓋羅嬌 | <img src="../generated/pal/guide/steal/items/122.png" alt="鶴頂紅" height="24"> | 鶴頂紅 | 5 | `501` |
| <img src="../generated/pal/guide/steal/enemies/538.png" alt="藍食火蟾" height="48"> | 藍食火蟾 | <img src="../generated/pal/guide/steal/items/142.png" alt="冰蠶蠱" height="24"> | 冰蠶蠱 | 1 | `538` |
| <img src="../generated/pal/guide/steal/enemies/426.png" alt="蜥蜴" height="48"> | 蜥蜴 | — | 金钱 | 1 | `426` |
| <img src="../generated/pal/guide/steal/enemies/517.png" alt="赤蜈蚣" height="48"> | 赤蜈蚣 | <img src="../generated/pal/guide/steal/items/121.png" alt="蜈蚣卵" height="24"> | 蜈蚣卵 | 1 | `517` |
| <img src="../generated/pal/guide/steal/enemies/415.png" alt="酒甕" height="48"> | 酒甕 | <img src="../generated/pal/guide/steal/items/086.png" alt="酒" height="24"> | 酒 | 2 | `415` |
| <img src="../generated/pal/guide/steal/enemies/465.png" alt="金蟾" height="48"> | 金蟾 | <img src="../generated/pal/guide/steal/items/119.png" alt="毒蟾卵" height="24"> | 毒蟾卵 | 10 | `465` |
| <img src="../generated/pal/guide/steal/enemies/484.png" alt="食人獸" height="48"> | 食人獸 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `484` |
| <img src="../generated/pal/guide/steal/enemies/518.png" alt="食火蟾" height="48"> | 食火蟾 | <img src="../generated/pal/guide/steal/items/143.png" alt="火蠶蠱" height="24"> | 火蠶蠱 | 1 | `518` |
| <img src="../generated/pal/guide/steal/enemies/402.png" alt="鳳梨小妖" height="48"> | 鳳梨小妖 | <img src="../generated/pal/guide/steal/items/104.png" alt="鼠兒果" height="24"> | 鼠兒果 | 1 | `402` |
| <img src="../generated/pal/guide/steal/enemies/498.png" alt="黑蜘蛛精" height="48"> | 黑蜘蛛精 | <img src="../generated/pal/guide/steal/items/159.png" alt="纏魂絲" height="24"> | 纏魂絲 | 3 | `498` |

## 回魂仙梦·南诏／水底秘道

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/429.png" alt="傻仔龜" height="48"> | 傻仔龜 | <img src="../generated/pal/guide/steal/items/147.png" alt="碧血蠶" height="24"> | 碧血蠶 | 1 | `429` |
| <img src="../generated/pal/guide/steal/enemies/547.png" alt="八頭蛇" height="48"> | 八頭蛇 | <img src="../generated/pal/guide/steal/items/278.png" alt="毒龍膽" height="24"> | 毒龍膽 | 3 | `547` |
| <img src="../generated/pal/guide/steal/enemies/437.png" alt="海螺女" height="48"> | 海螺女 | <img src="../generated/pal/guide/steal/items/144.png" alt="食妖蟲" height="24"> | 食妖蟲 | 2 | `437` |
| <img src="../generated/pal/guide/steal/enemies/430.png" alt="短腿章魚" height="48"> | 短腿章魚 | <img src="../generated/pal/guide/steal/items/147.png" alt="碧血蠶" height="24"> | 碧血蠶 | 1 | `430` |
| <img src="../generated/pal/guide/steal/enemies/485.png" alt="胖苗" height="48"> | 胖苗 | <img src="../generated/pal/guide/steal/items/101.png" alt="金創藥" height="24"> | 金創藥 | 1 | `485` |
| <img src="../generated/pal/guide/steal/enemies/527.png" alt="苗槍卒" height="48"> | 苗槍卒 | — | 金钱 | 1000 | `527` |
| <img src="../generated/pal/guide/steal/enemies/432.png" alt="蚌殼" height="48"> | 蚌殼 | <img src="../generated/pal/guide/steal/items/252.png" alt="珍珠" height="24"> | 珍珠 | 1 | `432` |
| <img src="../generated/pal/guide/steal/enemies/461.png" alt="蛟龍" height="48"> | 蛟龍 | <img src="../generated/pal/guide/steal/items/106.png" alt="龍涎草" height="24"> | 龍涎草 | 2 | `461` |

## 回魂仙梦·余杭

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/423.png" alt="樹根" height="48"> | 樹根 | <img src="../generated/pal/guide/steal/items/129.png" alt="鬼枯籐" height="24"> | 鬼枯籐 | 1 | `423` |
| <img src="../generated/pal/guide/steal/enemies/401.png" alt="爛香菇" height="48"> | 爛香菇 | <img src="../generated/pal/guide/steal/items/107.png" alt="靈山仙芝" height="24"> | 靈山仙芝 | 1 | `401` |
| <img src="../generated/pal/guide/steal/enemies/404.png" alt="蛹" height="48"> | 蛹 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `404` |
| <img src="../generated/pal/guide/steal/enemies/415.png" alt="酒甕" height="48"> | 酒甕 | <img src="../generated/pal/guide/steal/items/086.png" alt="酒" height="24"> | 酒 | 2 | `415` |
| <img src="../generated/pal/guide/steal/enemies/400.png" alt="黑毛球" height="48"> | 黑毛球 | <img src="../generated/pal/guide/steal/items/091.png" alt="十里香" height="24"> | 十里香 | 1 | `400` |

## 南诏王宫／秘道

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/490.png" alt="五毒巨蠍" height="48"> | 五毒巨蠍 | <img src="../generated/pal/guide/steal/items/133.png" alt="赤蠍粉" height="24"> | 赤蠍粉 | 1 | `490` |
| <img src="../generated/pal/guide/steal/enemies/492.png" alt="五毒蜈蚣" height="48"> | 五毒蜈蚣 | <img src="../generated/pal/guide/steal/items/157.png" alt="毒龍砂" height="24"> | 毒龍砂 | 1 | `492` |
| <img src="../generated/pal/guide/steal/enemies/440.png" alt="刑天" height="48"> | 刑天 | <img src="../generated/pal/guide/steal/items/101.png" alt="金創藥" height="24"> | 金創藥 | 1 | `440` |
| <img src="../generated/pal/guide/steal/enemies/536.png" alt="土蜘蛛" height="48"> | 土蜘蛛 | <img src="../generated/pal/guide/steal/items/120.png" alt="蜘蛛卵" height="24"> | 蜘蛛卵 | 1 | `536` |
| <img src="../generated/pal/guide/steal/enemies/459.png" alt="小巫師" height="48"> | 小巫師 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `459` |
| <img src="../generated/pal/guide/steal/enemies/458.png" alt="小苗女" height="48"> | 小苗女 | <img src="../generated/pal/guide/steal/items/179.png" alt="苗刀" height="24"> | 苗刀 | 1 | `458` |
| <img src="../generated/pal/guide/steal/enemies/510.png" alt="尖嘴魔兵" height="48"> | 尖嘴魔兵 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `510` |
| <img src="../generated/pal/guide/steal/enemies/528.png" alt="巫王侍衛" height="48"> | 巫王侍衛 | <img src="../generated/pal/guide/steal/items/146.png" alt="爆烈蠱" height="24"> | 爆烈蠱 | 1 | `528` |
| <img src="../generated/pal/guide/steal/enemies/546.png" alt="拜月教主" height="48"> | 拜月教主 | <img src="../generated/pal/guide/steal/items/123.png" alt="孔雀膽" height="24"> | 孔雀膽 | 30 | `546` |
| <img src="../generated/pal/guide/steal/enemies/462.png" alt="樹妖" height="48"> | 樹妖 | <img src="../generated/pal/guide/steal/items/150.png" alt="金蠶王" height="24"> | 金蠶王 | 3 | `462` |
| <img src="../generated/pal/guide/steal/enemies/466.png" alt="牛鬼" height="48"> | 牛鬼 | <img src="../generated/pal/guide/steal/items/145.png" alt="靈蠱" height="24"> | 靈蠱 | 2 | `466` |
| <img src="../generated/pal/guide/steal/enemies/471.png" alt="玩蛇女" height="48"> | 玩蛇女 | <img src="../generated/pal/guide/steal/items/124.png" alt="血海棠" height="24"> | 血海棠 | 2 | `471` |
| <img src="../generated/pal/guide/steal/enemies/467.png" alt="瘟神" height="48"> | 瘟神 | <img src="../generated/pal/guide/steal/items/122.png" alt="鶴頂紅" height="24"> | 鶴頂紅 | 2 | `467` |
| <img src="../generated/pal/guide/steal/enemies/485.png" alt="胖苗" height="48"> | 胖苗 | <img src="../generated/pal/guide/steal/items/101.png" alt="金創藥" height="24"> | 金創藥 | 1 | `485` |
| <img src="../generated/pal/guide/steal/enemies/549.png" alt="苗槍卒" height="48"> | 苗槍卒 | — | 金钱 | 1200 | `549` |
| <img src="../generated/pal/guide/steal/enemies/511.png" alt="鐵棍魔兵" height="48"> | 鐵棍魔兵 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `511` |
| <img src="../generated/pal/guide/steal/enemies/460.png" alt="長鞭苗女" height="48"> | 長鞭苗女 | <img src="../generated/pal/guide/steal/items/163.png" alt="長鞭" height="24"> | 長鞭 | 1 | `460` |
| <img src="../generated/pal/guide/steal/enemies/457.png" alt="雙節棍苗" height="48"> | 雙節棍苗 | — | 金钱 | 1600 | `457` |
| <img src="../generated/pal/guide/steal/enemies/493.png" alt="青獸人" height="48"> | 青獸人 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `493` |
| <img src="../generated/pal/guide/steal/enemies/484.png" alt="食人獸" height="48"> | 食人獸 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `484` |
| <img src="../generated/pal/guide/steal/enemies/438.png" alt="魔獸武士" height="48"> | 魔獸武士 | <img src="../generated/pal/guide/steal/items/174.png" alt="戒刀" height="24"> | 戒刀 | 1 | `438` |
| <img src="../generated/pal/guide/steal/enemies/503.png" alt="鳥人" height="48"> | 鳥人 | <img src="../generated/pal/guide/steal/items/151.png" alt="引路蜂" height="24"> | 引路蜂 | 1 | `503` |
| <img src="../generated/pal/guide/steal/enemies/522.png" alt="黑巫師" height="48"> | 黑巫師 | <img src="../generated/pal/guide/steal/items/123.png" alt="孔雀膽" height="24"> | 孔雀膽 | 2 | `522` |
| <img src="../generated/pal/guide/steal/enemies/523.png" alt="黑苗祭司" height="48"> | 黑苗祭司 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 3 | `523` |

## 无底深渊

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/490.png" alt="五毒巨蠍" height="48"> | 五毒巨蠍 | <img src="../generated/pal/guide/steal/items/133.png" alt="赤蠍粉" height="24"> | 赤蠍粉 | 1 | `490` |
| <img src="../generated/pal/guide/steal/enemies/492.png" alt="五毒蜈蚣" height="48"> | 五毒蜈蚣 | <img src="../generated/pal/guide/steal/items/157.png" alt="毒龍砂" height="24"> | 毒龍砂 | 1 | `492` |
| <img src="../generated/pal/guide/steal/enemies/440.png" alt="刑天" height="48"> | 刑天 | <img src="../generated/pal/guide/steal/items/101.png" alt="金創藥" height="24"> | 金創藥 | 1 | `440` |
| <img src="../generated/pal/guide/steal/enemies/536.png" alt="土蜘蛛" height="48"> | 土蜘蛛 | <img src="../generated/pal/guide/steal/items/120.png" alt="蜘蛛卵" height="24"> | 蜘蛛卵 | 1 | `536` |
| <img src="../generated/pal/guide/steal/enemies/510.png" alt="尖嘴魔兵" height="48"> | 尖嘴魔兵 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `510` |
| <img src="../generated/pal/guide/steal/enemies/466.png" alt="牛鬼" height="48"> | 牛鬼 | <img src="../generated/pal/guide/steal/items/145.png" alt="靈蠱" height="24"> | 靈蠱 | 2 | `466` |
| <img src="../generated/pal/guide/steal/enemies/471.png" alt="玩蛇女" height="48"> | 玩蛇女 | <img src="../generated/pal/guide/steal/items/124.png" alt="血海棠" height="24"> | 血海棠 | 2 | `471` |
| <img src="../generated/pal/guide/steal/enemies/467.png" alt="瘟神" height="48"> | 瘟神 | <img src="../generated/pal/guide/steal/items/122.png" alt="鶴頂紅" height="24"> | 鶴頂紅 | 2 | `467` |
| <img src="../generated/pal/guide/steal/enemies/535.png" alt="紫獸人" height="48"> | 紫獸人 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `535` |
| <img src="../generated/pal/guide/steal/enemies/461.png" alt="蛟龍" height="48"> | 蛟龍 | <img src="../generated/pal/guide/steal/items/106.png" alt="龍涎草" height="24"> | 龍涎草 | 2 | `461` |
| <img src="../generated/pal/guide/steal/enemies/511.png" alt="鐵棍魔兵" height="48"> | 鐵棍魔兵 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `511` |
| <img src="../generated/pal/guide/steal/enemies/493.png" alt="青獸人" height="48"> | 青獸人 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `493` |
| <img src="../generated/pal/guide/steal/enemies/484.png" alt="食人獸" height="48"> | 食人獸 | <img src="../generated/pal/guide/steal/items/148.png" alt="蠱" height="24"> | 蠱 | 1 | `484` |
| <img src="../generated/pal/guide/steal/enemies/438.png" alt="魔獸武士" height="48"> | 魔獸武士 | <img src="../generated/pal/guide/steal/items/174.png" alt="戒刀" height="24"> | 戒刀 | 1 | `438` |

## 未关联正式地图的备用数据

以下对象存在于敌队数据中，但无法从 294 个正式场景及其 EventObject 脚本入口建立可达地图；不要把它们当作正常流程中的固定偷窃目标。

| 怪物图 | 敌人 | 物品图 | 可偷取内容 | 初始数量／金钱池 | 对象编号 |
| --- | --- | --- | --- | ---: | ---: |
| <img src="../generated/pal/guide/steal/enemies/497.png" alt="石長老" height="48"> | 石長老 | — | 金钱 | 3000 | `497` |
| <img src="../generated/pal/guide/steal/enemies/533.png" alt="黑鳳凰" height="48"> | 黑鳳凰 | <img src="../generated/pal/guide/steal/items/123.png" alt="孔雀膽" height="24"> | 孔雀膽 | 1 | `533` |

## 数据核对方式

地图归属从 294 个场景的进入／传送脚本与所属 EventObject 触发／自动脚本出发，遍历控制流中的 `0007` 敌队，再把敌人战斗脚本通过 `009E/009F` 召唤或变身产生的对象归入同一地图。金蟾鬼母、林天南与明王位于动态长剧情脚本块，按各自实际 Boss 场景归类；石长老对象 `497` 与黑凤凰对象 `533` 无正式场景可达入口，单列为备用数据。

奖励读取 `PalEnemyDefinition.steal_item` 与 `steal_item_count`；缩略图生成器同时校验 135 张怪物图和 72 张物品图，避免表格、敌人数据与本地图片集合分叉。
