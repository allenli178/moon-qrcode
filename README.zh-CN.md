# MoonQR

[![CI](https://github.com/allenli178/moon-qrcode/actions/workflows/ci.yml/badge.svg)](https://github.com/allenli178/moon-qrcode/actions/workflows/ci.yml)

[English](./README.md) | 中文

纯 MoonBit 实现的 QR Code **编码器**，遵循 ISO/IEC 18004 Model 2 标准。
输出模块矩阵；核心库、渲染器和载荷模板零依赖，CLI 是在其之上的薄层。

- 版本 1–40，纠错等级 L / M / Q / H
- 数字、字母数字和 UTF-8 字节段；自动模式使用动态规划求最优分段
- 原始 `Bytes` 载荷与调用方自定义的段序列
- 自动选择最小版本，8 种数据掩码 + Annex J 惩罚评分
- Reed–Solomon 编码，基于 GF(2<sup>8</sup>)（本原多项式 0x11D），BCH 格式/版本信息
- 不可变 `QrCode` 矩阵（`size`、`get`、`modules`、`to_bytes`）
- ASCII、半高字符和 SVG 渲染器；SVG 将连续深色模块合并为单个 `<path>`
- 载荷模板：URL、WiFi、电话、邮件、短信、地理坐标、vCard 和纯文本
- 扁平 `Uint8Array` ABI、带类型的 ESM/npm 封装；CLI 支持标准输入和 JSON 输出
- 容量契约的机器验证（`moon prove` + Z3）与 Python `qrcode` 参考交叉比对

## 安装

```bash
moon add allenli178/moon-qrcode
```

需要 MoonBit `0.1.20261023` 或更新版本。

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

### 原始字节与自定义段

`encode_bytes` 将任意二进制数据编码为单个 Byte 段，即使不是合法 UTF-8
也逐字节保留。`encode_segments` 接受调用方指定的段序列并按顺序编码。

```mbt check
///|
test "README 载荷选项" {
  let binary = @moon-qrcode.encode_bytes(
    b"\xff\x00\x80",
    ec_level=@moon-qrcode.EcLevel::L,
  )
  assert_eq(binary.version().value(), 1)
  let segments : Array[@moon-qrcode.Segment] = [
    @moon-qrcode.Segment::new(@moon-qrcode.Mode::Numeric, "12345"),
    @moon-qrcode.Segment::from_bytes(b"\xff\x00"),
  ]
  let qr = @moon-qrcode.encode_segments(
    segments,
    ec_level=@moon-qrcode.EcLevel::M,
  )
  assert_eq(qr.version().value(), 1)
}
```

自动模式下，`encode` 在三种模式与各版本组上运行动态规划分段，混合载荷
会得到最省的编码，而不是按贪心类别切分。显式传入 `mode` 时仍使用
`split_segments` 的确定性贪心切分。

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
  水平方向的连续深色模块合并到单个 `<path>`；颜色值会被校验，`url(...)`
  会被拒绝，非法颜色抛出 `QrError::InvalidColor`。

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
  moonqr - [选项] < 文件
  moonqr [选项] -- <载荷>

  -l, --level <L|M|Q|H>      纠错等级（默认 M）
  -v, --version <1..40>      指定版本
      --min-version <n>      最小候选版本
      --max-version <n>      最大候选版本
  -m, --mode <name>          numeric | alphanumeric | byte（默认自动）
      --mask <0..7>          指定掩码图案
  -q, -qz, --quiet-zone <n>  静默区宽度（默认 4）
  -s, --scale <n>            ASCII 缩放倍数（默认 1）
      --module-size <n>      SVG 模块像素大小（默认 4）
  -f, --format <name>        ascii | half | svg | json（默认按扩展名）
      --json                 JSON 元数据与模块行
  -o, --output <path>        输出到文件而非标准输出
      --svg / --half         格式快捷方式
      --dark / --light       SVG 颜色
  -h, --help                 显示帮助
  -V, --cli-version          显示 CLI 版本
```

载荷写为 `-` 时从标准输入读取，末尾换行会被去除；载荷以 `-` 开头时，
在它之前加 `--`。诊断信息写入 stderr，stdout 可直接用于管道和文件。

示例：

```bash
moonqr "https://moonbitlang.com" --svg -o site.svg
moonqr "0123456789" -v 2 -m numeric -s 2
moonqr "内容" --min-version 5 --max-version 10 -l Q -f half
echo -n "HELLO" | moonqr - -l H --svg
cat payload.txt | moonqr - -o code.svg
moonqr --json "HELLO" | jq '.version, .size'
moonqr -- --以短横线开头的载荷
```

`--json`（或 `-f json`，或 `.json` 输出路径）输出
`{"version":1,"ecLevel":"L","mask":7,"size":21,"modules":["…", …]}`，
其中每个模块行是由 `0`/`1` 组成的字符串。

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
`encode_bytes_flat_buffer` 接受二进制数据，`encode_bytes_to_modules`
直接返回模块数组，`flat_error_message` 生成可读的错误信息。

### 带类型的 ESM/npm 封装

`npm/` 将 JS 构建封装为带类型的 ESM API：

```bash
npm ci --prefix npm
npm test --prefix npm   # 构建 dist/moonbit.js，运行 Node + tsc 检查
```

```js
import { encode, encodeBytes } from "./npm/index.js";

const qr = encode("HELLO WORLD", { ecLevel: "H", mask: 3 });
const binary = encodeBytes(new Uint8Array([0xff, 0x00]), { ecLevel: "L" });
```

`encode(text, options?)` 与 `encodeBytes(data, options?)` 返回
`{ size, version, ecLevel, mask, modules }`；`encodeToBytes` 返回
`Uint8Array` 矩阵；非法选项抛出 `QrCodeError`。该包标记为
`private: true`，尚未发布到 npm registry。

实测产物大小（release 构建，本仓库）：

| 产物 | 原始大小 | gzip 后 |
| --- | --- | --- |
| wasm-gc 编码器 + 扁平 API（`js.wasm`） | 33.9 KiB | 12.9 KiB |
| JS ESM 编码器 + 扁平 API（`js.js`） | 100.9 KiB | 14.0 KiB |
| native release CLI（`moonqr.exe`） | 354.2 KiB | — |

## 正确性与测试

```bash
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
moon fmt --check && moon info

# 容量契约形式化验证（需要 z3）
moon prove core/capacity_model

# 参考实现交叉比对（Python 3 + qrcode==8.2）
python3 -m pip install -r tools/fuzz/requirements.txt
moon build cmd/moonqr --target native --release
python3 tools/fuzz/verify.py

# CLI 冒烟测试
python3 tools/cli/smoke.py

# ZXing 解码校验（Node 18+）
npm ci --prefix tools/zxing
node tools/zxing/verify.js

# npm 封装测试
npm ci --prefix npm
npm test --prefix npm

# native 基准测试
moon bench benchmarks --target native --release
```

- 88 个单元/README 测试，覆盖 `core`、`render`、`content`、`js` 和根包门面；
  另有 7 个 native 基准测试。
- 矩阵摘要来自 Python `qrcode` 参考实现：72 个字节模式向量
  （跨版本/纠错等级/掩码），32 个字母数字和 8 个数字向量（共 112 个），
  加上完整矩阵快照。
- 每次运行 `tools/fuzz/verify.py` 都会用 Python `qrcode` 8.2 比对
  203 个强制版本/纠错等级/模式/掩码的矩阵。
- 4 个容量契约（`total_codewords`、`char_count_bits`、`numeric_capacity`、
  `byte_capacity`）已通过 `moon prove` 与 Z3 证明。
- GF(2<sup>8</sup>)、BCH 整除性/已知值、RS 校验向量、容量核算、贪心与
  最优分段、错误路径和 SVG/ASCII 输出均有覆盖。
- 同一套测试在 wasm、wasm-gc、JS 和 native 目标上通过，四个后端输出
  比特一致。
- 核心覆盖率 95.5%（`moon coverage analyze`）；未覆盖行
  为防御性不变量检查和不可达枚举分支。
- 12 个生成符号（覆盖全部纠错等级、UTF-8、强制掩码/版本、长载荷和
  模板载荷）均可被 ZXing 参考实现正确解码。
- CI 在 Ubuntu 与 macOS 上运行测试矩阵，并包含体积、ZXing、覆盖率、
  npm、fuzz、基准和形式化证明任务。

真机摄像头（iOS/Android/微信）验证仍为手动；ZXing 解码、矩阵级交叉比对
和容量契约证明是自动保障。

## 范围

已实现：Model 2 版本 1–40，L/M/Q/H，数字/字母数字/字节，动态规划最优
自动分段，原始字节与自定义段，掩码，渲染器，模板，支持标准输入/JSON 的
CLI，扁平 JS/wasm ABI，带类型的 npm 封装，容量契约证明和参考实现 fuzz。

有意排除：解码、PNG/JPEG/PDF 导出、Logo/样式、Micro QR、汉字模式、
ECI 和结构化追加。上述功能、npm 正式发布和真机自动化验证是 1.0 的候选。

## 项目结构

```
core/                 编码器：类型、容量、分段、位缓冲、RS、BCH、矩阵、惩罚
core/capacity_model/  容量计算与 `moon prove` 契约
benchmarks/           native 基准测试套件
render/               ASCII 和 SVG 渲染器
content/              载荷模板
js/                   扁平 Uint8Array ABI + ESM/wasm-gc 链接导出
npm/                  带类型的 ESM 封装（private）+ Node/TypeScript 测试
cmd/moonqr            CLI 命令行工具
tools/zxing           ZXing 解码验证工具（Node）
tools/fuzz            Python qrcode 矩阵交叉比对
tools/cli             CLI 冒烟测试
```

`core`、`core/capacity_model`、`render`、`content` 和 `js` 仅依赖
MoonBit 标准库。CLI 额外依赖 `moonbitlang/x` 用于文件系统和进程支持。

## 许可证

Apache-2.0.
