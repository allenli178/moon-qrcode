///|
/// Encoder facade: value types, capacity helpers and the single `encode` entry
/// point.
///
/// 编码器门面：值类型、容量辅助函数和统一的 `encode` 入口。
pub using @core {
  type EcLevel,
  type Mask,
  type Mode,
  type QrCode,
  type QrError,
  type Segment,
  type Version,
  encode,
  encode_bytes,
  encode_segments,
  split_segments,
  bits_needed,
  character_capacity,
  char_count_bits,
  data_capacity_bits,
  data_codewords,
  ecc_codewords,
  block_count,
  total_codewords,
  format_info,
  version_info,
  gf_mul,
  rs_encode,
}

///|
/// ASCII, SVG, PNG and PBM renderers.
///
/// ASCII、SVG、PNG 和 PBM 渲染器。
pub using @render {
  to_ascii,
  to_ascii_half,
  to_ascii_color,
  to_svg,
  to_svg_rect,
  to_svg_rounded,
  is_valid_color,
  to_png,
  to_png_rgba,
  to_pbm,
}

///|
/// Payload templates (URL, WiFi, vCard, tel, mailto, SMS, geo).
///
/// 载荷模板（URL、WiFi、vCard、电话、邮件、短信、地理坐标）。
pub using @content {type Content, encode_content}
