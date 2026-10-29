///|
fn dark_at(qr : @core.QrCode, y : Int32, x : Int32, quiet_zone : Int32) -> Bool {
  let size = qr.size()
  let inside_y = y >= quiet_zone && y < size + quiet_zone
  let inside_x = x >= quiet_zone && x < size + quiet_zone
  inside_y && inside_x && qr.get(y - quiet_zone, x - quiet_zone)
}

///|
/// Terminal rendering. Each module is two characters wide so the result looks
/// roughly square in monospaced fonts. `quiet_zone` is measured in modules and
/// `scale` repeats every module `scale` times.
///
/// 终端渲染。每个模块占两个字符宽度，在等宽字体下近似方形。
/// `quiet_zone` 以模块为单位，`scale` 控制每个模块的重复次数。
pub fn to_ascii(
  qr : @core.QrCode,
  quiet_zone~ : Int32 = 4,
  scale~ : Int32 = 1,
) -> String {
  let qz = if quiet_zone < 0 { 0 } else { quiet_zone }
  let sc = if scale < 1 { 1 } else { scale }
  let total = qr.size() + qz * 2
  let sb = StringBuilder()
  for ry in 0..<(total * sc) {
    for rx in 0..<(total * sc) {
      let dark = dark_at(qr, ry / sc, rx / sc, qz)
      if dark {
        sb.write_string("██")
      } else {
        sb.write_string("  ")
      }
    }
    sb.write_char('\n')
  }
  sb.to_string()
}

///|
/// Half-height rendering: two module rows are packed into one text row using
/// upper/lower block characters. Good for narrow terminals.
///
/// 半高渲染：使用上下半块字符将两行模块压缩到一行终端输出。
/// 适合窄终端。
pub fn to_ascii_half(qr : @core.QrCode, quiet_zone~ : Int32 = 4) -> String {
  let qz = if quiet_zone < 0 { 0 } else { quiet_zone }
  let total = qr.size() + qz * 2
  let rows = (total + 1) / 2
  let sb = StringBuilder()
  for row in 0..<rows {
    let top_y = row * 2
    let bottom_y = top_y + 1
    for x in 0..<total {
      let top = dark_at(qr, top_y, x, qz)
      let bottom = dark_at(qr, bottom_y, x, qz)
      let ch = match (top, bottom) {
        (true, true) => '█'
        (true, false) => '▀'
        (false, true) => '▄'
        _ => ' '
      }
      sb.write_char(ch)
    }
    sb.write_char('\n')
  }
  sb.to_string()
}

///|
/// 用 ANSI 24-bit 真彩色输出 QR 码。兼容大多数现代终端（xterm、
/// iTerm、Windows Terminal 等）。默认深色前景、浅色背景。
/// 颜色接受 #RRGGBB 格式，例如 "#ff0000" 表示红色。
///
/// 用 ANSI 24-bit 真彩色输出 QR 码。兼容大多数现代终端。
/// 颜色接受 #RRGGBB 格式。
pub fn to_ascii_color(
  qr : @core.QrCode,
  quiet_zone~ : Int32 = 4,
  scale~ : Int32 = 1,
  dark~ : String = "#000000",
  light~ : String = "#ffffff",
  inverted~ : Bool = false,
) -> String raise @core.QrError {
  if !is_valid_color(dark) {
    raise @core.QrError::InvalidColor(dark)
  }
  if !is_valid_color(light) {
    raise @core.QrError::InvalidColor(light)
  }
  let qz = if quiet_zone < 0 { 0 } else { quiet_zone }
  let sc = if scale < 1 { 1 } else { scale }
  let size = qr.size()
  let total = size + qz * 2
  let sb = StringBuilder()
  // 解析颜色
  let dark_rgb = parse_hex_ansi(dark)
  let light_rgb = parse_hex_ansi(light)
  let fg_rgb = if inverted { light_rgb } else { dark_rgb }
  let bg_rgb = if inverted { dark_rgb } else { light_rgb }
  sb <+ "\u{1b}[48;2;\{bg_rgb.0};\{bg_rgb.1};\{bg_rgb.2}m"
  sb <+ "\u{1b}[38;2;\{fg_rgb.0};\{fg_rgb.1};\{fg_rgb.2}m"
  for ry in 0..<(total * sc) {
    for rx in 0..<(total * sc) {
      let dark = dark_at(qr, ry / sc, rx / sc, qz)
      if dark {
        sb.write_string("██")
      } else {
        sb.write_string("  ")
      }
    }
    sb <+ "\n"
  }
  sb <+ "\u{1b}[0m"
  sb.to_string()
}

///|
/// 将 #RRGGBB 颜色解析为 (R, G, B) Int32 三元组，用于 ANSI 24-bit 真彩色。
fn parse_hex_ansi(color : String) -> (Int32, Int32, Int32) {
  let s = color.to_lower()
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let start = if chars.length() > 0 && chars[0] == '#' { 1 } else { 0 }
  let n = chars.length() - start
  match n {
    3 => {
      let r = hex_val(chars[start])
      let g = hex_val(chars[start + 1])
      let b = hex_val(chars[start + 2])
      (r * 16 + r, g * 16 + g, b * 16 + b)
    }
    6 => {
      let r = hex_val(chars[start]) * 16 + hex_val(chars[start + 1])
      let g = hex_val(chars[start + 2]) * 16 + hex_val(chars[start + 3])
      let b = hex_val(chars[start + 4]) * 16 + hex_val(chars[start + 5])
      (r, g, b)
    }
    _ => (0, 0, 0)
  }
}

///|
fn hex_val(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else {
    0
  }
}
