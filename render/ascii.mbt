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
