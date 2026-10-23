MoonQR —— MoonBit QR Code 生成库

产品需求文档（PRD）+ 详细设计方案

版本：v0.1（草案）｜适用标准：ISO/IEC 18004:2015 Model 2（仅编码，不解码）
目标后端：wasm-gc / wasm(MVP) / js / native(x86_64, aarch64)

一、产品概述

1.1 背景

QR 码生成是基础设施级的成熟需求，但现有实现存在结构性缺口：

跨语言靠人工移植：Nayuki 的 qrcodegen 为了覆盖 C/C++/Java/JS/Python/Rust/TS，维护了 N 套代码树，同步成本全在人身上。
Wasm 场景不经济：Go 的 Wasm 产物 MB 级，Rust 需要 wasm-bindgen 胶水，Python 必须走服务端往返。
正确性只有测试没有证明：最好的情况是「高覆盖率 + 公开 test vector」，依然是概率性保证。RS 编码、掩码选择、BCH 格式信息这三处一旦出错，表现是「大部分码能扫、个别不能扫」，极难定位。

MoonBit 恰好能同时解决这三件事：一份代码多后端、产物 KB 级、类型系统 + 契约可证伪。

1.2 产品定位

一个纯 MoonBit 实现的、零依赖的 QR Model 2 编码器，输出模块矩阵；配套提供 SVG/字符画渲染与 CLI，主打「小、快、可验证」。

关键定位决策：只做编码，不做解码。解码涉及二值化、透视校正、摄像头帧处理，属于 CV 领域，MoonBit 无优势且生态已饱和（ZBar/jsQR/ZXing）。

1.3 目标用户
用户   场景   最在意的点
前端工程师   浏览器内生成支付码/登录码/名片码   产物体积、冷启动、隐私（数据不出端）

Wasm/边缘平台方   网关插件、组件市场里的「签发二维码」组件   隔离性、启动时间、确定性

CLI/工具开发者   CI 里生成静态资源二维码、文档里嵌码   单二进制、零依赖、秒级启动

教学/语言爱好者   学习 MoonBit 的参考项目   代码可读性、有 test vector 对照

1.4 不做的事（明确排除范围）
排除   理由
解码/扫码   CV 问题，已有饱和方案

PNG/JPEG/PDF 导出   交给 JS 渲染层；避免引入图像库依赖

Logo 嵌入、渐变色、圆点形状   qr-code-styling 类库已做到极致，且属视觉层

Micro QR / iQR / SQRC / Frame QR   v1.0 之后再议，先坐实 Model 2 主线

完整论文级段划分 DP 优化   v0.x 做「正确 + 够用」，v2 再做最优分割并配 benchmark

自定义 ECI / 结构化追加（Structured Append）   列入 v1.0 候选，不进入 v0.x

二、需求规格

2.1 功能性需求

FR-1 输入与内容类型
FR-1.1 支持 Numeric / Alphanumeric / Byte(Kanji 作为 v1.0 候选) 三种段模式。
FR-1.2 支持混合段模式自动划分（相邻同模式合并）。
FR-1.3 支持显式指定 version(1–40)、纠错等级(L/M/Q/H)、最小/最大 version。
FR-1.4 未指定 version 时自动选择最小可用 version。
FR-1.5 数据超出容量时报明确错误（带 version/ecLevel/超出字节数）。

FR-2 编码流水线
FR-2.1 模式指示符 + 字符计数指示符 + 数据编码。
FR-2.2 终止符 + 位对齐 + 垫字(0xEC, 0x11)交替填充。
FR-2.3 按 EC 等级分块、交错。
FR-2.4 Reed-Solomon 在 GF(2⁸) 上的编解码（模多项式 0x11D）。
FR-2.5 功能图形布置： finder / alignment / timing / dark module。
FR-2.6 8 种 mask 试算 + 四项惩罚评分，选最低分。
FR-2.7 15bit 格式信息 BCH(15,5) + 18bit 版本信息 BCH(18,6, v7+)。
FR-2.8 输出不可变模块矩阵 Bool 二维结构 + 尺寸。

FR-3 渲染
FR-3.1 字符画渲染（终端），支持 quiet zone 与缩放。
FR-3.2 SVG 字符串输出（<svg> + <rect>），可选 quiet zone、模块尺寸、前景/背景色。
FR-3.3 不提供 PNG/JPEG，由调用方在 JS 侧用 Canvas 消费矩阵。

FR-4 上层糖
FR-4.1 ADT 封装常见载荷：URL / WiFi(vCard 简化版) / tel / mailto / SMS / geo / 纯文本。
FR-4.2 WiFi 模板生成 WIFI:T:WPA;S:<ssid>;P:<pass>;;，SSID/密码中的 :;," 转义。
FR-4.3 CLI：moonqr "payload" -o out.svg -l H -qz 4。

FR-5 多后端
FR-5.1 同一份核心编译到 wasm-gc / js / native。
FR-5.2 JS 后端导出符合 ES Module 规范的入口，可直接发 npm。
FR-5.3 Wasm 侧提供 encode_to_modules(text, options) -> Uint8Array 扁平化接口（行优先 bit-packed 或 byte-per-module），避免 JSON 序列化开销。

2.2 非功能性需求
编号   指标   目标值   验收方式
NFR-1   wasm-gc gzipped 体积   ≤ 20 KB（仅编码器）；≤ 35 KB（含 SVG）   moon build --target wasm-gc + gzip -c

NFR-2   JS 产物体积   ≤ 30 KB gzipped   同上

NFR-3   native CLI 体积   ≤ 2 MB（strip 后）   ls -lh

NFR-4   浏览器端生成耗时（version 10, 中等文本）   ≤ 5 ms（中端笔记本）   benchmark 套件

NFR-5   正确性   通过全部公开 test vector + 与 libqrencode/qrcodegen 交叉比对   CI 快照比对

NFR-6   确定性   同输入同输出（bit-for-bit），跨后端一致   三后端输出哈希比对

NFR-7   零运行时依赖   除标准库外无任何第三方依赖   moon.mod.json 审计

NFR-8   无 unsafe / 无 FFI（除 JS 绑定层）   核心包纯 MoonBit   代码审查

NFR-9   覆盖率   核心包 ≥ 90%   moon coverage

NFR-10   形式化证明   ≥ 4 条契约通过 moon prove   CI

2.3 兼容性需求

生成的码必须能被 ZXing、iOS 原生相机、Android CameraX、微信/支付宝扫码正常识别。
验收方法：每个 test vector 的输出渲染成 PNG 后，用 zxing 命令行解码器回读比对原文。

三、架构设计

3.1 分层

┌─────────────────────────────────────────┐
│  CLI / JS Binding (thin, per-backend)   │  适配层：参数解析、扁平化 IO
├─────────────────────────────────────────┤
│  Renderer: ASCII / SVG                  │  纯展示，不碰编码逻辑
├─────────────────────────────────────────┤
│  Encoder: 段划分 → 比特流 → RS → 矩阵    │  ★核心包，零依赖、可独立测试
├─────────────────────────────────────────┤
│  Primitives: GF(2^8), BCH, 容量表, 惩罚  │  纯函数 + 编译期常量表
└─────────────────────────────────────────┘

硬约束：Encoder 层不得引用 Renderer 层；Primitives 层不得分配可变状态；任何一层都不得有 IO。

3.2 模块划分与目录结构

moonbit-qrcode/
├── moon.mod.json          # name: yourname/qrcode
├── moon.pkg.json
├── README.md / DESIGN.md / CHANGELOG.md
├── core/
│   ├── moon.pkg.json
│   ├── types.mbt          # Version/EcLevel/Mode/Mask 等值类型
│   ├── capacity.mbt       # 容量表 + 自动选 version
│   ├── bitbuf.mbt         # 比特流构建
│   ├── segments.mbt       # 段划分
│   ├── rs.mbt             # Reed-Solomon GF(2^8)
│   ├── bch.mbt            # 格式/版本信息 BCH
│   ├── matrix.mbt         # 矩阵布局 + 功能图形 + mask
│   ├── penalty.mbt        # 四项惩罚评分
│   ├── encode.mbt         # 流水线编排（唯一对外入口）
│   └── error.mbt          # 错误类型
├── render/
│   ├── moon.pkg.json
│   ├── ascii.mbt
│   └── svg.mbt
├── content/
│   ├── moon.pkg.json
│   └── templates.mbt      # WiFi/vCard/tel/mailto/SMS/geo
├── js/
│   └── moon.pkg.json      # JS 后端入口 + 扁平化导出
├── cli/
│   └── main.mbt
├── verify/                 # 形式化验证子集（单独包，避免污染主包）
│   ├── moon.pkg.json
│   ├── rs_proof.mbt
│   └── capacity_proof.mbt
└── tests/
    ├── vectors.mbt         # 公开 test vector 快照
    ├── cross.mbt           # 交叉比对
    └── prop.mbt            # 性质测试

3.3 数据流

String input
   │ segments.mbt      → List<Segment>
   │ capacity.mbt      → Version
   │ bitbuf.mbt        → BitBuffer
   │ rs.mbt            → List<Codeword>
   │ matrix.mbt        → Matrix (mutable during build, frozen on output)
   │ penalty.mbt       → (score, mask) × 8
   ▼ encode.mbt        → QrCode { size: Int, modules: ImmutableMatrix }
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
          ascii.mbt        svg.mbt        js flat buffer

QrCode 为唯一对外输出类型，保证构造即合法：不存在「半成品的、未掩码的」矩阵流出核心包。这是通过内部 builder 类型 + 私有构造器实现的。

四、详细设计

4.1 值类型设计（types.mbt）

// 纠错等级：注意容量表顺序 L < M < Q < H，但纠错能力相反
enum EcLevel { L; M; Q; H } deriving(Eq, Show)

// Version 1..40，用私有构造 + 智能构造器保证范围
type Version Int
fn make_version(v: Int) -> Option[Version] { ... }
fn version_size(self: Version) -> Int { self.0 * 4 + 17 }

enum Mode { Numeric; Alphanumeric; Byte; Kanji }

// Mask 0..7，直接对应 ISO 的 (i+j)%2 ... 条件
enum Mask { M0; M1; M2; M3; M4; M5; M6; M7 }
fn mask_condition(self: Mask, i: Int, j: Int) -> Bool { ... }

// 对外唯一输出：构造即完成品
type QrCode {
  version: Version
  ec_level: EcLevel
  mask: Mask
  size: Int
  modules: Array[Array[Bool]]   // 实际用一维 Array[Bool] + stride 更省
}
fn get(self: QrCode, r: Int, c: Int) -> Bool { ... }

关键设计点：
EcLevel/Mask 用枚举而非 Int，杜绝「传了个 5 当 mask」这类错误。
Version 构造器返回 Option，非法值在入口处死掉。
QrCode 构造器放在 encode.mbt 且标记为 private，外部只能通过 encode() 获得实例。

4.2 容量表（capacity.mbt）

用三维常量表 (version, ecLevel, mode) -> maxDataBits，数据来源 ISO/IEC 18004 Table 7。

fn max_data_bits(version: Version, ec: EcLevel, mode: Mode) -> Int
fn choose_version(total_bits: Int, ec: EcLevel, min_v: Version, max_v: Version) -> Result[Version, Error]

契约（供 moon prove）：
proof_requires total_bits >= 0
proof_ensures 返回值 v 满足 max_data_bits(v, ec, mode) >= total_bits 且对所有 v' < v 不成立（单调性）。
单独证明：固定 ec/mode 下 max_data_bits 关于 version 严格单调递增。

4.3 段划分（segments.mbt）

v0.x 采用贪心合并 + 按字符类别分段：扫描输入，连续同类字符归为一段，相邻同模式段合并。Kanji 判定需 Shift-JIS 范围判断，v0.x 降级为 Byte 模式（中文走 UTF-8 Byte，完全合规，只是容量略低）。

type Segment { mode: Mode; data: String }
fn split(s: String) -> List[Segment]
fn bits_needed(segs: List[Segment], version: Version) -> Int
// = Σ (4 + cc_bits(mode,version) + data_bits(mode, seg))

边界用例：空字符串（应报错或视为无效）、纯数字长串、emoji（UTF-8 下 4 字节/字符，必须在 Byte 模式下正确处理）、超过 version 40 容量的输入。

4.4 比特流（bitbuf.mbt）

type BitBuffer {
  data: Array[Byte]
  bit_len: Int
}
fn push_bits(buf: BitBuffer, value: Int, n: Int) -> Unit
fn push_byte(buf: BitBuffer, b: Byte) -> Unit
fn pad(buf: BitBuffer, capacity_bytes: Int) -> Unit  // 终止符+对齐+0xEC/0x11 交替
fn as_bytes(self: BitBuffer) -> Array[Byte]

契约：pad 之后 bit_len == capacity_bytes * 8；push_bits 不越界。

4.5 Reed-Solomon（rs.mbt）——正确性风险最高的一环

参数：GF(2⁸)，本原多项式 x⁸ + x⁴ + x³ + x² + 1 = 0x11D，本原元 α = 2。

// 编译期常量表，零运行时开销
let GF_EXP: Array[Byte] = ...   // 512 项，方便乘法不取模
let GF_LOG: Array[Byte] = ...

fn gf_mul(a: Byte, b: Byte) -> Byte
fn rs_encode(msg: Array[Byte], nsym: Int) -> Array[Byte]   // 返回 parity

算法：标准多项式除法（合成除法），generator 多项式递推 g(x) = g(x) * (x - α^i)。

分块与交错：按 ISO 表把码字分成 block group，每块独立 RS 编码后交错排列。此处极易出错，必须用 Nayuki 的中间结果向量做逐块比对。

契约：
proof_ensures rs_encode(msg, nsym).len() == nsym
decode(encode(cw)) == cw（用 erasure-only 解码器做反向验证，解码器只用于测试，不随库发布）

4.6 BCH（bch.mbt）

格式信息：15bit，BCH(15,5)，生成多项式 0x537，掩码 0x5412。
版本信息：18bit，BCH(18,6)，生成多项式 0x1F25，v7–v40，置于右上和左下。

fn format_info(ec: EcLevel, mask: Mask) -> Int   // 15 bit
fn version_info(v: Version) -> Option[Int]        // 18 bit, None if v < 7

测试：对全部 4×8=32 种 (ec, mask) 组合与参考实现逐位比对；对 v7/v40 的版本信息比对。

4.7 矩阵与掩码（matrix.mbt / penalty.mbt）

布局顺序：置入 finder（含分隔符）、alignment pattern 中心坐标表（ISO Table E.1）、timing、dark module（固定位置，永远不被 mask 影响）、保留格式/版本信息占位、之字形填入码字、应用 mask、写格式/版本信息。

惩罚规则（ISO Annex J）：
同行/同列连续 ≥5 个同色模块：N1=3 + (连续长度-5)
2×2 同色块数 × N2=3
模式 1:1:3:1:1（前后任意延伸 4 个暗模块）× N3=40，横竖均计
暗模块占比偏离 50% 的程度，每 5% 偏离 × N4=10

fn penalty(m: Matrix) -> Int  // = p1+p2+p3+p4
fn apply_mask(m: Matrix, k: Mask) -> Matrix

契约：penalty(m) >= 0；choose_best_mask 返回的 mask 得分 ≤ 其余 7 个。

性能注意：p3 的朴素实现是 O(size³)。v0.x 可接受（40 版本矩阵 177×177，8 次试算仍亚毫秒），但代码里要留 TODO 标注行/列滑动窗口优化位点，并在 benchmark 里记录。

4.8 渲染层

ASCII：用 ██/   双宽字符保持近似方形，quiet zone 用空格，支持缩放因子。额外提供一个「半高」模式（一行输出两行模块，用上下半块字符），终端体验更好。

SVG：纯字符串拼接，属性白名单：viewBox、width/height、shape-rendering="crispEdges"、前景/背景色（默认黑/白）、quiet zone。必须校验颜色值为合法 CSS 颜色，拒绝注入 </svg> 等字符串（虽为 SVG 而非 HTML，仍需做基本过滤）。

4.9 JS 绑定与扁平化接口

为避免 JSON 序列化，Wasm 导出：

encode_utf8(ptr: i32, len: i32, ec: i32, min_v: i32, max_v: i32) -> i64
  // 高 32bit = size, 低 32bit = 模块数组在内存中的起始偏移（行优先 1 byte/module）
modules_ptr() -> i32   // 复用缓冲区，避免每次 malloc
modules_len() -> i32
free_buf()

JS 侧包装成：

export async function encode(text, opts) {
  const mods = await wasm.encode_utf8(...)
  return { size, modules }  // modules 为 Uint8Array view
}

重要：JS 侧负责 Canvas 渲染与 Data URL 生成，MoonBit 侧绝不引入图像编码。

4.10 错误处理

enum Error {
  InputEmpty
  DataTooLong { needed: Int; capacity: Int; version: Version; ec: EcLevel }
  InvalidVersion(Int)
  InvalidUtf8
  Internal(String)   // 只在 invariant 被破坏时使用，视为 bug
}

错误消息必须包含可操作的诊断信息（例如「数据需 312 bit，V5-H 容量 232 bit，建议改用 V7-M 或缩短输入」）。

五、正确性保障方案（本项目的核心竞争力）

5.1 四层保障金字塔

L4  moon prove 契约     ← 4~6 条核心不变量（最强，最窄）
L3  性质测试 fuzz       ← 往返恒等、幂等、单调性
L2  公开 test vector    ← ISO 附录、Nayuki、libqrencode
L1  交叉比对 + 真机扫码  ← zxing 回读、手机相机实测

5.2 Test Vector 清单（必须全部纳入快照）
来源   内容   用途
ISO/IEC 18004 Annex H / I   V1-H "01234567"、V5-H 数字串、V1-M 字母数字等   官方基准，逐模块比对

Nayuki qrcodegen 测试集   多版本×多纠错×多模式   覆盖面广，MIT 可参照

libqrencode 输出   同一批输入   工业实现交叉验证

自造边界集   空串/超长/emoji/恰好填满/跨 version 边界/最大 version   错误路径覆盖

存储方式：tests/vectors.mbt 用 expect 测试 + moon test -u 更新快照，矩阵存为一维 run-length 或 base64 以控制可读性。

5.3 真机回读（CI 可做）

CI 中用 zxing-cpp 命令行或 pyzbar 对生成的 PNG 解码，断言回读文本 == 原文。这一条能拦住 90% 的「看起来对其实错了」的问题（尤其是 dark module、alignment 坐标、交错顺序）。

5.4 性质测试（prop.mbt）

往返恒等：decode_rs(encode_rs(cw)) == cw（自研 erasure 解码器，仅测试用）。
mask 幂等：apply_mask(apply_mask(m, k), k) == m。
容量单调：v1 < v2 → capacity(v1) < capacity(v2)；L ≤ M ≤ Q ≤ H 对应容量递减。
惩罚非负。
确定性：同一输入跑 1000 次哈希一致。
fuzz：随机 UTF-8 字符串 × 随机 ec/minV/maxV，要求要么成功生成且能被 zxing 回读，要么报 DataTooLong，不允许 panic。

5.5 moon prove 契约（verify/ 包）

只做小而硬、证明器能 discharged 的：

fn gf_mul(a: Byte, b: Byte) -> Byte
  proof_requires true
  proof_ensures gf_mul(a, b) == gf_mul(b, a)   // 交换律

fn rs_encode(msg: Array[Byte], nsym: Int) -> Array[Byte]
  proof_ensures result.len() == nsym

fn penalty(m: Matrix) -> Int
  proof_ensures result >= 0

fn choose_version(bits: Int, ...) -> Option[Version]
  proof_ensures match result { None => false; Some(v) => capacity(v) >= bits }

纪律：若某条契约 30 分钟内证不出，就降级为性质测试，不要陷入。证明的目的是增加可信度，不是证明本身。

六、性能与体积目标

6.1 体积预算（NFR-1/2/3 拆解）
模块   wasm-gc 增量目标
types + capacity（常量表）   ~4 KB

bitbuf + segments   ~3 KB

rs + bch（含 GF 表）   ~5 KB

matrix + penalty   ~5 KB

encode 编排   ~2 KB

svg renderer（可选）   ~4 KB

合计   ≤ 25 KB（未压缩）/ ≤ 12 KB gzipped

每 commit 由 CI 记录体积趋势图，超阈值即告警。

6.2 Benchmark 套件

对标对象：fast_qr(Rust)、qrcodegen(C)、qrcode.js(TS)、go-qrcode(wasm)。

维度：version 1/10/25/40 × 三种模式 × 8 种 mask；指标：吞吐(ops/s)、P50/P99 延迟、产物体积。

诚实原则：benchmark 代码与脚本必须开源可复现；若输给 fast_qr，就在 README 里写明「比 fast_qr 慢 X%，但产物小 Y 倍」——这比夸大更有说服力。

七、版本规划与里程碑
版本   周期   交付   验收标准
v0.1   W1–W3   类型系统 + 比特流 + 容量表 + ASCII 输出   扫出 "HELLO WORLD"（V1-L）

v0.2   W4–W6   RS + BCH + mask 8 选 1 + SVG + 全量 test vector 快照   ISO/Nayuki 向量逐位通过；zxing 回读通过率 100%

v0.3   W7–W8   js/native 后端 + CLI + benchmark + 体积 CI   三后端输出哈希一致

v0.4   W9–W10   content 模板 + 性质测试 + 覆盖率报告   核心包覆盖率 ≥ 90%

v0.5   W11–W12   moon prove 4 条契约 + README/示例/文档站   CI 全绿；首个 mooncakes 公开发布

v1.0   +4–6 周   Kanji 模式 + Structured Append + API 冻结 + semver   下游 2 个真实使用者反馈

每周节奏：周一拆任务、周五出可演示物（哪怕只是终端里一个更清晰的二维码）。

八、风险评估与应对
风险   概率   影响   应对
RS 交错顺序出错，个别码扫不出   高   高   逐块中间结果比对 + zxing 回读双重保险

moon prove 超时/报错不友好导致卡壳   高   中   设 30 分钟止损线，降级为性质测试

Beta 编译器/LSP bug   中   中   锁定工具链版本，记录 workaround，遇 ICE 提 issue

mooncakes 上已有人发 QR 包   中   低   若对方无测试无文档则视为机会；若有完整实现则转向「差异化需求文档」路线

渲染层需求蔓延（Logo/渐变）   高   中   PRD 明确排除范围，相关 issue 一律标 wontfix 并引导至 JS 生态

GC 暂停影响实时性   低   低   本项目非实时场景，忽略；但若做音频/游戏方向需重估

九、发布与运营

命名：yourname/qrcode（mooncakes 命名空间唯一），CLI 另开 moonqr。
semver：v0.x 允许 breaking；API 冻结后才上 v1.0。
CI（GitHub Actions）：moon check / moon test / moon coverage / 体积预算 / test vector 快照 / zxing 回读 / 三后端一致性。
文档最小集：README（5 分钟上手 + 体积数字 + benchmark 表）、DESIGN.md（本文档精简版）、API 示例、FAQ（含「为什么不解码」「为什么不支持 Logo」）。
传播资产：一张「同一段码，四种产物」的截图、一张 benchmark 柱状图、一段「这段非法代码在 MoonBit 里编译不过」的截图。
回馈生态：把 test vector 集抽成独立的 qrcode-test-vectors 包，供其他 MoonBit 实现复用——这是低成本建立影响力的做法。

十、附录

A. 关键常量

GF(2⁸) 本原多项式：0x11D；本原元：2
BCH 格式：gen 0x537，mask 0x5412，15bit
BCH 版本：gen 0x1F25，18bit
垫字序列：0xEC, 0x11 交替
惩罚系数：N1=3, N2=3, N3=40, N4=10
Alignment 中心坐标：见 ISO Table E.1（v2–v40 共 39 组）

B. 参考实现对读清单

Nayuki qrcodegen（MIT）— test vector 与中间结果首选
libqrencode（LGPL）— 工业级交叉验证，只比对输出，不抄代码
fast_qr（Rust, MIT/Apache）— benchmark 对手
segno（Python, MIT）— 测试用例覆盖思路参考

合规提醒：本项目为 clean-room 实现，仅参考公开的 ISO 规范与 test vector 输出值，不复制任何实现的代码。

C. 第一周具体任务（可直接开工）

建仓库 + moon new，搭好目录结构与 CI 骨架。
types.mbt：EcLevel/Mask/Mode/Version + 构造器合法性测试。
capacity.mbt：录入容量表（先录 V1–V10 三个 ec 等级，跑通再补全），写单调性测试。
segments.mbt + bitbuf.mbt：贪心分段 + 比特流，断言 bits_needed 与手工计算一致。
用 "HELLO WORLD"（Numeric 不行，走 Alphanumeric）算出手工期望比特流，写第一条 expect 测试。
周末目标：ASCII 矩阵打印出来，手机能扫出字。