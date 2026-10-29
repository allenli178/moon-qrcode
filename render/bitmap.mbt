///|
/// CRC-32 查表。标准多项式 0xEDB88320。
/// 用 Int32 存储（二进制补码和 UInt 位模式相同）。
let crc32_table : Array[Int32] = (fn() -> Array[Int32] {
  let table = Array::make(256, 0)
  for i in 0..<256 {
    let mut c = i
    for _ in 0..<8 {
      c = if (c & 1) != 0 { 0xEDB88320 ^ (c >> 1) } else { c >> 1 }
    }
    table[i] = c
  }
  table
})()

///|
fn crc32_update(crc : Int32, data : Array[Byte]) -> Int32 {
  let mut c = crc
  for b in data {
    c = crc32_table[(c ^ b.to_int()) & 0xFF] ^ (c >> 8)
  }
  c
}

///|
fn crc32_two(a : Array[Byte], b : Array[Byte]) -> Int32 {
  let mut c = crc32_update(-1, a)
  c = crc32_update(c, b)
  c ^ -1
}

///|
fn write_u32_be(buf : Array[Byte], value : Int32) -> Unit {
  buf.push(((value >> 24) & 0xFF).to_byte())
  buf.push(((value >> 16) & 0xFF).to_byte())
  buf.push(((value >> 8) & 0xFF).to_byte())
  buf.push((value & 0xFF).to_byte())
}

///|
fn str_to_bytes(s : String) -> Array[Byte] {
  let result : Array[Byte] = []
  for c in s {
    result.push(c.to_int().to_byte())
  }
  result
}

///|
fn write_chunk(buf : Array[Byte], ty : String, data : Array[Byte]) -> Unit {
  let ty_bytes = str_to_bytes(ty)
  let crc = crc32_two(ty_bytes, data)
  write_u32_be(buf, data.length())
  for b in ty_bytes {
    buf.push(b)
  }
  for b in data {
    buf.push(b)
  }
  write_u32_be(buf, crc)
}

///|
/// Adler-32 checksum (PNG zlib 需要)
fn adler32(data : Array[Byte]) -> Int32 {
  let mut a = 1
  let mut b = 0
  let base = 65521
  for bb in data {
    a = (a + bb.to_int()) % base
    b = (b + a) % base
  }
  (b << 16) | a
}

///|
/// 将图像原始数据用 zlib (DEFLATE stored block, 无压缩) 包装。
fn deflate_stored(raw : Array[Byte]) -> Array[Byte] {
  let result : Array[Byte] = []
  // zlib 头: CMF=0x78 (CM=8, CINFO=7), FLG=0x01 → (0x7801) % 31 == 0 ✓
  result.push((0x78 : Byte))
  result.push((0x01 : Byte))
  // DEFLATE stored block: BFINAL=1, BTYPE=00 → 0x01
  result.push((0x01 : Byte))
  // LEN (2 bytes LE) + NLEN (2 bytes LE)
  let total = raw.length()
  result.push((total & 0xFF).to_byte())
  result.push(((total >> 8) & 0xFF).to_byte())
  let nlen = (0xFFFF ^ total) & 0xFFFF
  result.push((nlen & 0xFF).to_byte())
  result.push(((nlen >> 8) & 0xFF).to_byte())
  // 原始数据
  for b in raw {
    result.push(b)
  }
  // Adler-32 (big-endian)
  let adler = adler32(raw)
  write_u32_be(result, adler)
  result
}

///|
/// 将颜色字符串 (#RRGGBB) 解析为 [R, G, B] 三字节。
fn parse_hex_color(color : String) -> (Byte, Byte, Byte) {
  let s = color.to_lower()
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let start = if chars.length() > 0 && chars[0] == '#' { 1 } else { 0 }
  let n = chars.length() - start
  match n {
    3 => {
      let r = hex_digit(chars[start])
      let g = hex_digit(chars[start + 1])
      let b = hex_digit(chars[start + 2])
      ((r * 16 + r).to_byte(), (g * 16 + g).to_byte(), (b * 16 + b).to_byte())
    }
    6 => {
      let r = hex_pair(chars[start], chars[start + 1])
      let g = hex_pair(chars[start + 2], chars[start + 3])
      let b = hex_pair(chars[start + 4], chars[start + 5])
      (r, g, b)
    }
    _ => ((0 : Byte), (0 : Byte), (0 : Byte))
  }
}

///|
fn hex_digit(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else {
    0
  }
}

///|
fn hex_pair(hi : Char, lo : Char) -> Byte {
  (hex_digit(hi) * 16 + hex_digit(lo)).to_byte()
}

///|
/// 渲染 QR 码为 8-bit 灰度 PNG（深色=0，浅色=255）。
/// 零外部依赖，使用 DEFLATE stored block（不压缩）。
///
/// 将 QR 码渲染为 8-bit 灰度 PNG（深色=0，浅色=255）。
/// 零外部依赖，使用 DEFLATE stored block（不压缩）。
pub fn to_png(
  qr : @core.QrCode,
  quiet_zone~ : Int32 = 4,
  module_size~ : Int32 = 4,
) -> Array[Byte] {
  let qz = if quiet_zone < 0 { 0 } else { quiet_zone }
  let ms = if module_size < 1 { 1 } else { module_size }
  let size = qr.size()
  let total = size + qz * 2
  let pixels = total * ms

  // 生成原始图像数据 (每行 filter=0, 然后 width 字节)
  let raw : Array[Byte] = []
  for ry in 0..<pixels {
    raw.push((0 : Byte)) // filter byte: None
    let mod_y = ry / ms
    for rx in 0..<pixels {
      let mod_x = rx / ms
      let dark = dark_at(qr, mod_y, mod_x, qz)
      raw.push(if dark { (0 : Byte) } else { (255 : Byte) })
    }
  }

  let compressed = deflate_stored(raw)

  // 组装 PNG
  let out : Array[Byte] = []
  // PNG 签名
  out.push((0x89 : Byte))
  out.push('P'.to_int().to_byte())
  out.push('N'.to_int().to_byte())
  out.push('G'.to_int().to_byte())
  out.push((0x0D : Byte))
  out.push((0x0A : Byte))
  out.push((0x1A : Byte))
  out.push((0x0A : Byte))
  // IHDR
  let ihdr : Array[Byte] = []
  write_u32_be(ihdr, pixels)
  write_u32_be(ihdr, pixels)
  ihdr.push((8 : Byte)) // bit_depth = 8
  ihdr.push((0 : Byte)) // color_type = 0 (grayscale)
  ihdr.push((0 : Byte)) // compression = 0
  ihdr.push((0 : Byte)) // filter = 0
  ihdr.push((0 : Byte)) // interlace = 0
  write_chunk(out, "IHDR", ihdr)
  // IDAT
  write_chunk(out, "IDAT", compressed)
  // IEND (无数据)
  write_chunk(out, "IEND", [])
  out
}

///|
/// 渲染 QR 码为 RGBA PNG。dark 和 light 接受 #RRGGBB 格式颜色。
///
/// 将 QR 码渲染为 RGBA PNG。dark 和 light 接受 #RRGGBB 格式颜色。
pub fn to_png_rgba(
  qr : @core.QrCode,
  quiet_zone~ : Int32 = 4,
  module_size~ : Int32 = 4,
  dark~ : String = "#000000",
  light~ : String = "#ffffff",
) -> Array[Byte] raise @core.QrError {
  if !is_valid_color(dark) {
    raise @core.QrError::InvalidColor(dark)
  }
  if !is_valid_color(light) {
    raise @core.QrError::InvalidColor(light)
  }
  let qz = if quiet_zone < 0 { 0 } else { quiet_zone }
  let ms = if module_size < 1 { 1 } else { module_size }
  let size = qr.size()
  let total = size + qz * 2
  let pixels = total * ms

  // 解析颜色
  let (dr, dg, db) = parse_hex_color(dark)
  let (lr, lg, lb) = parse_hex_color(light)

  // 生成原始图像数据 (每行 filter=0, 然后 width*4 字节)
  let raw : Array[Byte] = []
  for ry in 0..<pixels {
    raw.push((0 : Byte)) // filter byte
    let mod_y = ry / ms
    for rx in 0..<pixels {
      let mod_x = rx / ms
      let d = dark_at(qr, mod_y, mod_x, qz)
      if d {
        raw.push(dr)
        raw.push(dg)
        raw.push(db)
        raw.push((255 : Byte))
      } else {
        raw.push(lr)
        raw.push(lg)
        raw.push(lb)
        raw.push((255 : Byte))
      }
    }
  }

  let compressed = deflate_stored(raw)

  let out : Array[Byte] = []
  // PNG 签名
  out.push((0x89 : Byte))
  out.push('P'.to_int().to_byte())
  out.push('N'.to_int().to_byte())
  out.push('G'.to_int().to_byte())
  out.push((0x0D : Byte))
  out.push((0x0A : Byte))
  out.push((0x1A : Byte))
  out.push((0x0A : Byte))
  // IHDR
  let ihdr : Array[Byte] = []
  write_u32_be(ihdr, pixels)
  write_u32_be(ihdr, pixels)
  ihdr.push((8 : Byte)) // bit_depth = 8
  ihdr.push((6 : Byte)) // color_type = 6 (RGBA)
  ihdr.push((0 : Byte)) // compression = 0
  ihdr.push((0 : Byte)) // filter = 0
  ihdr.push((0 : Byte)) // interlace = 0
  write_chunk(out, "IHDR", ihdr)
  // IDAT
  write_chunk(out, "IDAT", compressed)
  // IEND
  write_chunk(out, "IEND", [])
  out
}

///|
/// 渲染为 PBM (P4 二进制位图)。最简单的 1-bit 格式，零压缩零依赖。
/// 可以直接用 convert 命令或 ImageMagick 转为 PNG/JPEG。
///
/// 将 QR 码渲染为 PBM (P4 二进制位图)。最简单的 1-bit 格式。
pub fn to_pbm(
  qr : @core.QrCode,
  quiet_zone~ : Int32 = 4,
  module_size~ : Int32 = 4,
) -> Array[Byte] {
  let qz = if quiet_zone < 0 { 0 } else { quiet_zone }
  let ms = if module_size < 1 { 1 } else { module_size }
  let size = qr.size()
  let total = size + qz * 2
  let pixels = total * ms

  // PBM P4 格式头
  let header = "P4\n\{pixels} \{pixels}\n"
  let result : Array[Byte] = []
  for c in header {
    result.push(c.to_int().to_byte())
  }

  // 每行 1-bit 打包：msb 在前。深色像素=1（P4 约定：1=黑=前景）
  for ry in 0..<pixels {
    let mod_y = ry / ms
    let mut byte_val = 0
    let mut bit_pos = 7
    for rx in 0..<pixels {
      let mod_x = rx / ms
      let dark = dark_at(qr, mod_y, mod_x, qz)
      if dark {
        byte_val = byte_val | (1 << bit_pos)
      }
      bit_pos = bit_pos - 1
      if bit_pos < 0 {
        result.push(byte_val.to_byte())
        byte_val = 0
        bit_pos = 7
      }
    }
    // 行尾补零
    if bit_pos != 7 {
      result.push(byte_val.to_byte())
    }
  }
  result
}
