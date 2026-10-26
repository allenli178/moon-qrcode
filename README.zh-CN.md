# MoonQR

[![CI](https://github.com/allenli178/moon-qrcode/actions/workflows/ci.yml/badge.svg)](https://github.com/allenli178/moon-qrcode/actions/workflows/ci.yml)

[English](./README.md) | 中文

纯 MoonBit 实现的 QR Code **编码器**，核心库零依赖，遵循 ISO/IEC 18004
Model 2 标准。输出模块矩阵；渲染、载荷模板和 CLI 是在其之上的薄层。

- 版本 1–40，纠错等级 L / M / Q / H
- 数字、字母数字和 UTF-8 字节段，支持贪心自动分段
- 自动选择最小版本，8 种数据掩码 + Annex J 惩罚评分
- Reed–Solomon 编码，基于 GF(2<sup>8</sup>)（本原多项式 0x11D），BCH 格式/版本信息
- 不可变 `QrCode` 矩阵（`size`、`get`、`modules`、`to_bytes`）
- ASCII、半高字符和 SVG 渲染器
- 载荷模板：URL、WiFi、电话、邮件、短信、地理坐标、vCard 和纯文本
- JS/wasm 扁平化 `Uint8Array` ABI；原生 CLI

## 安装

```bash
moon add allenli178/moon-qrcode
```

需要 MoonBit `0.1.20261020` 或更新版本。

## 快速开始

```mbt check
///|
test "README 快速开始" {
  let qr = @moon-qrcode.encode("你好世界", ec_level=@moon-qrcode.EcLevel::M)
  assert_true(qr.size() >= 21)
  assert_true(qr.get(0, 0))
  let svg = @moon-qrcode.to_svg(qr, quiet_zone=4, module_size=4)
  assert_true(svg.contains("<svg"))
}
```

`encode` 会在 `min_version..max_version` 范围内选择能容纳数据的最小版本，
然后选择惩罚分最低的掩码。

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `text` | — | 载荷字符串（字节模式下为 UTF-8） |
| `ec_level` | `M` | 纠错等级 |
| `min_version` / `max_version` | `1` / `40` | 版本搜索范围 |
| `mode` | 自动 | 强制使用 `Numeric`、`Alphanumeric` 或 `Byte` |
| `mask` | 自动 | 强制使用掩码 `M0`–`M7` |

### 读取矩阵

| 函数 | 返回值 |
| --- | --- |
| `size()` | 模块边长（`4 * version + 17`） |
| `get(row, col)` | 单个模块的 `Bool` 值 |
| `modules()` | 行优先的 `Array[Bool]` 副本 |
| `to_bytes()` | 行优先的 `Array[Byte]`，`1` = 深色 |
| `version()` / `ec_level()` / `mask()` | 元数据 |

错误会被检查：`DataTooLong` 携带所需比特数、容量、版本和纠错等级信息，
`QrError::message()` 会输出可操作的诊断信息。

## 渲染

```mbt check
///|
test "README 渲染" {
  let qr = @moon-qrcode.encode("https://moonbitlang.com")
  let ascii = @moon-qrcode.to_ascii(qr, quiet_zone=2)
  let half = @moon-qrcode.to_ascii_half(qr)
  assert_true(ascii.length() > 0)
  assert_true(half.length() > 0)
  let custom = @moon-qrcode.to_svg(qr, dark="navy", light="#ffffff")
  assert_true(custom.contains("fill=\"navy\""))
}
```

- `to_ascii(qr, quiet_zone?, scale?)` 使用双宽字符块；`scale` 控制每个模块的重复次数。
- `to_ascii_half(qr, quiet_zone?)` 将两行模块压缩到一行终端输出。
- `to_svg(qr, quiet_zone?, module_size?, dark?, light?)` 返回完整的 SVG 文档。
  颜色值会被校验，`url(...)` 会被拒绝；非法颜色会抛出 `QrError::InvalidColor`。

## 载荷模板

```mbt check
///|
test "README 模板" {
  let wifi = @moon-qrcode.Content::wifi("Cafe", "latte")
  assert_eq(wifi.to_text(), "WIFI:T:WPA;S:Cafe;P:latte;;")
  let card = @moon-qrcode.Content::vcard(
    "张三",
    phone="13800138000",
    email="zhangsan@example.com",
  )
  let qr = @moon-qrcode.encode_content(card, ec_level=@moon-qrcode.EcLevel::H)
  assert_true(qr.size() >= 21)
}
```

可用的构造器：`Content::wifi(ssid, password, auth?)`、
`Content::mailto(address, subject?, body?)`、`Content::sms(number, message?)`、
`Content::tel(number)`、`Content::geo(lat, lng)`、
`Content::vcard(name, phone?, email?, org?)`，以及 `Text` 和 `Url`。
`to_text()` 将模板序列化为文本；`encode_content()` 序列化并编码。

## 命令行工具

```bash
# 在模块目录下执行
moon run cmd/moonqr --target native -- "你好世界" -l H -o hello.svg

# 发布二进制：_build/native/release/build/cmd/moonqr/moonqr.exe
moon build cmd/moonqr --target native --release
```

```
用法：
  moonqr <载荷> [选项]

  -l, --level <L|M|Q|H>      纠错等级（默认 M）
  -v, --version <1..40>      指定版本
      --min-version <n>      最小候选版本
      --max-version <n>      最大候选版本
  -m, --mode <name>          numeric | alphanumeric | byte（默认自动）
      --mask <0..7>          指定掩码图案
  -q, -qz, --quiet-zone <n>  静默区宽度（默认 4）
  -s, --scale <n>            ASCII 缩放倍数（默认 1）
      --module-size <n>      SVG 模块像素大小（默认 4）
  -f, --format <name>        ascii | half | svg（默认按输出扩展名）
  -o, --output <path>        输出到文件而非标准输出
      --svg / --half         格式快捷方式
      --dark / --light       SVG 颜色
```

示例：

```bash
moonqr "https://moonbitlang.com" --svg -o site.svg
moonqr "0123456789" -v 2 -m numeric -s 2
moonqr "内容" --min-version 5 --max-version 10 -l Q -f half
```

## JS / wasm 扁平化 API

`js` 包导出了原始类型缓冲区 ABI，宿主端无需承担 JSON 或嵌套数组的开销。构建方式：

```bash
moon build js --target js --release       # _build/js/release/build/js/js.js + .d.ts
moon build js --target wasm-gc --release  # _build/wasm-gc/release/build/js/js.wasm
```

```js
import { encode_flat_buffer } from "./_build/js/release/build/js/js.js";

// ec_level: 0=L, 1=M, 2=Q, 3=H
const result = encode_flat_buffer("你好世界", 1, 1, 40);
if (result.$tag === 1) {
  const buf = result._0;                  // Uint8Array
  const size = (buf[0] << 8) | buf[1];    // 模块边长
  const version = buf[2];
  const mask = buf[3];
  const modules = buf.subarray(4);        // size * size 字节，1 = 深色
}
```

缓冲区布局：`[size_hi, size_lo, version, mask, modules...]`。JS
绑定类型为 `Uint8Array`；错误以 `Result`（`$tag === 0`）形式返回。

实测产物大小（release 构建，本仓库）：

| 产物 | 原始大小 | gzip 后 |
| --- | --- | --- |
| wasm-gc 编码器 + 扁平 API（`js.wasm`） | 20.6 KB | 8.6 KB |
| JS ESM 编码器 + 扁平 API（`js.js`） | 71.7 KB | 10.5 KB |
| native release CLI（`moonqr.exe`） | 353 KB | — |

## 正确性与测试

```bash
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
moon fmt --check && moon info

# ZXing 解码校验（Node 18+）
moon build cmd/moonqr --target native --release
npm ci --prefix tools/zxing
node tools/zxing/verify.js
```

- 71 个测试，覆盖 `core`、`render`、`content`、`js` 和根包门面。
- 矩阵摘要来自 Python `qrcode` 参考实现：
  72 个字节模式向量（跨版本/纠错等级/掩码），32 个字母数字和
  8 个数字向量（共 112 个），加上完整矩阵快照。
- GF(2<sup>8</sup>)、BCH 整除性/已知值、RS 校验向量、容量
  核算、段分割、错误路径和 SVG/ASCII 输出均有覆盖。
- 同一套测试在 wasm、wasm-gc、JS 和 native 目标上通过，四个后端输出
  比特一致。
- 核心覆盖率超过 90%（`moon coverage analyze`）；未覆盖行
  为防御性不变量检查和不可达枚举分支。
- 12 个生成符号（覆盖全部纠错等级、UTF-8、强制掩码/版本、长载荷和
  模板载荷）均可被 ZXing 参考实现正确解码，该校验在 CI 中运行。

真机摄像头（iOS/Android/微信）验证仍为手动；CI 以 ZXing 解码和
矩阵级交叉比对作为自动保障。

## 范围

已实现：Model 2 版本 1–40，L/M/Q/H，数字/字母数字/字节，贪心
自动分段，掩码，渲染器，模板，CLI，扁平 JS/wasm ABI。

有意排除：解码、PNG/JPEG/PDF 导出、Logo/样式、Micro QR、
汉字模式、ECI 和结构化追加。形式化 `moon prove` 契约、
基准测试套件、真机自动化验证和 npm 包装器在路线图中；
当前以性质测试替代证明。

## 项目结构

```
core/      编码器：类型、容量、分段、位缓冲、RS、BCH、矩阵、惩罚
render/    ASCII 和 SVG 渲染器
content/   载荷模板
js/        扁平 Uint8Array ABI + ESM/wasm-gc 链接导出
cmd/moonqr CLI 命令行工具
tools/zxing ZXing 解码验证工具（Node）
```

`core`、`render`、`content` 和 `js` 仅依赖 MoonBit 标准库。
CLI 额外依赖 `moonbitlang/x` 用于文件系统和进程支持。

## 许可证

Apache-2.0.
