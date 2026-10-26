///|
/// Accepts hex colors, named CSS colors, and rgb()/rgba()/hsl() style values.
/// Rejects anything containing markup or characters that could escape an
/// attribute.
///
/// 接受十六进制颜色、CSS 命名颜色以及 rgb()/rgba()/hsl() 格式。
/// 拒绝包含标记或可能逃逸属性的字符。
pub fn is_valid_color(color : String) -> Bool {
  if color.is_empty() || color.length() > 64 {
    false
  } else {
    let mut ok = true
    for c in color {
      let alpha = c >= 'a' && c <= 'z'
      let upper = c >= 'A' && c <= 'Z'
      let digit = c >= '0' && c <= '9'
      let punct = c == '#' || c == '(' || c == ')' || c == ',' || c == '.'
      let allowed = alpha || upper || digit || punct || c == '%' || c == ' '
      if !allowed {
        ok = false
      }
    }
    ok && !contains_url_reference(color)
  }
}

///|
/// `url(...)` would let a rendered SVG pull external resources, so it is
/// rejected even though its characters pass the color allowlist.
fn contains_url_reference(color : String) -> Bool {
  let sb = StringBuilder()
  for c in color {
    sb.write_char(c.to_ascii_lowercase())
  }
  sb.to_string().contains("url(")
}

///|
/// Renders the symbol as an SVG document. Consecutive dark modules in each
/// row are merged into horizontal runs inside a single `<path>`, which keeps
/// high-version output small.
///
/// 将 QR 码渲染为 SVG 文档。每行连续的深色模块合并为水平行程，
/// 统一写入一个 `<path>`，以控制高版本码的输出体积。
pub fn to_svg(
  qr : @core.QrCode,
  quiet_zone~ : Int32 = 4,
  module_size~ : Int32 = 4,
  dark~ : String = "#000000",
  light~ : String = "#ffffff",
) -> String raise @core.QrError {
  if !is_valid_color(dark) {
    raise @core.QrError::InvalidColor(dark)
  }
  if !is_valid_color(light) {
    raise @core.QrError::InvalidColor(light)
  }
  let qz = if quiet_zone < 0 { 0 } else { quiet_zone }
  let ms = if module_size < 1 { 1 } else { module_size }
  let size = qr.size()
  let full = size + qz * 2
  let pixels = full * ms
  let sb = StringBuilder()
  sb <+ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  sb <+
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{full} \{full}\" width=\"\{pixels}\" height=\"\{pixels}\" shape-rendering=\"crispEdges\">\n"
  sb <+ "<rect width=\"\{full}\" height=\"\{full}\" fill=\"\{light}\"/>\n"
  sb <+ "<g fill=\"\{dark}\">\n"
  sb <+ "<path d=\""
  for y in 0..<size {
    let mut x = 0
    while x < size {
      if qr.get(y, x) {
        let start = x
        while x < size && qr.get(y, x) {
          x = x + 1
        }
        let run = x - start
        sb <+ "M\{start + qz} \{y + qz}h\{run}v1h-\{run}"
      } else {
        x = x + 1
      }
    }
  }
  sb <+ "\"/>\n</g>\n</svg>\n"
  sb.to_string()
}
