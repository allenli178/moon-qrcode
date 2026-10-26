// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "allenli178/moon-qrcode"

version = "0.2.0"

readme = "README.mbt.md"

repository = "https://github.com/allenli178/moon-qrcode"

license = "Apache-2.0"

keywords = [ "qrcode", "qr", "encoder", "iso18004", "svg" ]

preferred_target = "wasm-gc"

description = "Pure-MoonBit QR Code Model 2 encoder with optimal segmentation, ASCII/SVG renderers, payload templates, a native CLI and a typed JS/npm API | 纯 MoonBit 实现的 QR Code Model 2 编码器，支持最优分段、ASCII/SVG 渲染、载荷模板、原生 CLI 和带类型的 JS/npm API"

import {
  "moonbitlang/x@0.5.6",
}
