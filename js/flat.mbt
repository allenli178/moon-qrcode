///|
/// Flattened encoding result for JS/wasm consumers: row-major modules,
/// one byte each (`1` dark, `0` light), plus the metadata needed to draw it.
///
/// 面向 JS/wasm 消费者的扁平编码结果：行优先模块，每模块一字节
/// （`1` 深色，`0` 浅色），加上绘制所需的元数据。
pub struct FlatQr {
  size_ : Int32
  version_ : Int32
  ec_level_ : @core.EcLevel
  mask_ : @core.Mask
  data_ : Bytes
}

///|
/// Encodes `text` and flattens the matrix into a `Bytes` buffer, avoiding
/// nested arrays and JSON serialization on the JS boundary.
///
/// 编码 `text` 并将矩阵扁平化为 `Bytes` 缓冲区，
/// 避免 JS 边界上的嵌套数组和 JSON 序列化。
///
/// # Example
/// ```mbt check
/// test "flat encode" {
///   let qr = @js.encode_to_modules("hi", ec_level=@core.EcLevel::L)
///   assert_eq(qr.size(), 21)
///   assert_eq(qr.data().length(), 441)
///   assert_eq(qr.data()[0].to_int(), 1)
/// }
/// ```
pub fn encode_to_modules(
  text : String,
  ec_level~ : @core.EcLevel = @core.EcLevel::M,
  min_version~ : Int32 = 1,
  max_version~ : Int32 = 40,
  mask? : @core.Mask,
) -> FlatQr raise @core.QrError {
  let qr = @core.encode(text, ec_level~, min_version~, max_version~, mask?)
  {
    size_: qr.size(),
    version_: qr.version().value(),
    ec_level_: qr.ec_level(),
    mask_: qr.mask(),
    data_: Bytes::from_array(qr.to_bytes()),
  }
}

///|
/// Side length in modules.
///
/// 模块边长。
pub fn FlatQr::size(self : FlatQr) -> Int32 {
  self.size_
}

///|
/// QR version (1..40).
///
/// QR 版本（1..40）。
pub fn FlatQr::version(self : FlatQr) -> Int32 {
  self.version_
}

///|
pub fn FlatQr::ec_level(self : FlatQr) -> @core.EcLevel {
  self.ec_level_
}

///|
/// Mask pattern index (0..7).
///
/// 掩码图案索引（0..7）。
pub fn FlatQr::mask(self : FlatQr) -> Int32 {
  match self.mask_ {
    M0 => 0
    M1 => 1
    M2 => 2
    M3 => 3
    M4 => 4
    M5 => 5
    M6 => 6
    M7 => 7
  }
}

///|
/// Flat row-major buffer of `size * size` bytes.
///
/// 行优先的扁平缓冲区，包含 `size * size` 字节。
pub fn FlatQr::data(self : FlatQr) -> Bytes {
  self.data_
}

///|
pub fn FlatQr::module_at(self : FlatQr, row : Int32, col : Int32) -> Bool {
  self.data_[row * self.size_ + col].to_int() == 1
}

///|
fn ec_from_index(index : Int32) -> @core.EcLevel? {
  match index {
    0 => Some(@core.EcLevel::L)
    1 => Some(@core.EcLevel::M)
    2 => Some(@core.EcLevel::Q)
    3 => Some(@core.EcLevel::H)
    _ => None
  }
}

///|
/// Primitive-typed buffer ABI for JS/wasm hosts:
/// `[size_hi, size_lo, version, mask, row-major modules...]`.
///
/// 面向 JS/wasm 宿主的原始类型缓冲区 ABI：
/// `[size_hi, size_lo, version, mask, 行优先模块...]`。
///
/// `ec_level` 为 `0=L, 1=M, 2=Q, 3=H`；`min_version`/`max_version` 为
/// `1..40`。总长度为 `4 + size * size`。
///
/// # Example
/// ```mbt check
/// test "flat buffer ABI" {
///   let buf = @js.encode_flat_buffer("hi", 0, 1, 1)
///   let size = (buf[0].to_int() << 8) | buf[1].to_int()
///   assert_eq(size, 21)
///   assert_eq(buf.length(), 4 + 21 * 21)
/// }
/// ```
pub fn encode_flat_buffer(
  text : String,
  ec_level : Int32,
  min_version : Int32,
  max_version : Int32,
) -> Bytes raise @core.QrError {
  let ec = match ec_from_index(ec_level) {
    Some(ec) => ec
    None => raise @core.QrError::Internal("EC level index must be 0..3")
  }
  let qr = @core.encode(text, ec_level=ec, min_version~, max_version~)
  let bytes : Array[Byte] = [
    (qr.size() >> 8).to_byte(),
    (qr.size() & 0xFF).to_byte(),
    qr.version().value().to_byte(),
    match qr.mask() {
      M0 => (0 : Byte)
      M1 => (1 : Byte)
      M2 => (2 : Byte)
      M3 => (3 : Byte)
      M4 => (4 : Byte)
      M5 => (5 : Byte)
      M6 => (6 : Byte)
      M7 => (7 : Byte)
    },
  ]
  for bit in qr.to_bytes() {
    bytes.push(bit)
  }
  Bytes::from_array(bytes)
}
