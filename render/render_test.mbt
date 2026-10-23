///|
test "ASCII rendering dimensions and quiet zone" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let size = qr.size()
  let plain = @render.to_ascii(qr, quiet_zone=0, scale=1)
  let lines = plain.split("\n").to_array()
  assert_eq(lines.length(), size + 1)
  assert_eq(lines[size], "")
  for i in 0..<size {
    assert_eq(lines[i].length(), size * 2)
  }
  // Top-left finder: seven dark modules, then the light separator.
  assert_true(
    lines[0].has_prefix("██████████████  "),
  )
  let padded = @render.to_ascii(qr, quiet_zone=2, scale=1)
  let padded_lines = padded.split("\n").to_array()
  assert_eq(padded_lines.length(), size + 4 + 1)
  assert_true(padded_lines[0].trim().is_empty())
  assert_true(padded_lines[2].has_prefix("    "))
  assert_true(padded_lines[2].length() == (size + 4) * 2)
}

///|
test "ASCII scale repeats modules" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let size = qr.size()
  let scaled = @render.to_ascii(qr, quiet_zone=0, scale=2)
  let lines = scaled.split("\n").to_array()
  assert_eq(lines.length(), size * 2 + 1)
  assert_eq(lines[0].length(), size * 4)
  assert_true(lines[0].has_prefix("████████"))
}

///|
test "half-height rendering packs two module rows per line" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let size = qr.size()
  let text = @render.to_ascii_half(qr, quiet_zone=0)
  let lines = text.split("\n").to_array()
  assert_eq(lines.length(), (size + 1) / 2 + 1)
  for i in 0..<((size + 1) / 2) {
    assert_eq(lines[i].length(), size)
  }
  // Finder row 0 is dark across all seven modules; row 1 is dark only at
  // its ends, so the packed line starts with a full block, five upper
  // halves, and another full block.
  assert_true(lines[0].has_prefix("█▀▀▀▀▀█"))
}

///|
test "SVG contains the expected frame and one rect per dark module" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let svg = @render.to_svg(qr, quiet_zone=4, module_size=4)
  assert_true(svg.has_prefix("<?xml version=\"1.0\""))
  assert_true(svg.contains("viewBox=\"0 0 29 29\""))
  assert_true(svg.contains("width=\"116\""))
  assert_true(svg.contains("height=\"116\""))
  assert_true(svg.contains("shape-rendering=\"crispEdges\""))
  assert_true(svg.contains("<g fill=\"#000000\">"))
  assert_true(svg.contains("fill=\"#ffffff\""))
  let mut dark = 0
  for b in qr.to_bytes() {
    dark = dark + b.to_int()
  }
  // One background rect, one rect per dark module, plus the empty segment
  // before the first match.
  assert_eq(svg.split("<rect").to_array().length(), dark + 2)
}

///|
test "SVG supports zero quiet zone and custom colors" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let svg = @render.to_svg(
    qr,
    quiet_zone=0,
    module_size=1,
    dark="navy",
    light="rgb(255, 255, 255)",
  )
  assert_true(svg.contains("viewBox=\"0 0 21 21\""))
  assert_true(svg.contains("width=\"21\""))
  assert_true(svg.contains("<g fill=\"navy\">"))
  assert_true(svg.contains("fill=\"rgb(255, 255, 255)\""))
  assert_true(svg.contains("<rect x=\"0\" y=\"0\" width=\"1\" height=\"1\"/>"))
}

///|
test "SVG rejects markup and other unsafe colors" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  for color in ["<script>", "red\" onload=\"x", "url(http://x)", "red;"] {
    let mut rejected = false
    try ignore(@render.to_svg(qr, dark=color)) catch {
      @core.QrError::InvalidColor(_) => rejected = true
      _ => ()
    } noraise {
      _ => ()
    }
    assert_true(rejected)
  }
}

///|
test "color validation accepts CSS color forms" {
  for color in ["#000000", "#fff", "red", "rgb(1, 2, 3)", "hsl(0, 0%, 0%)"] {
    assert_true(@render.is_valid_color(color))
  }
  for color in ["", "\"", "a\"b", "red;blue", "<svg>", "url(#x)"] {
    assert_false(@render.is_valid_color(color))
  }
}

///|
test "negative quiet zone and tiny scale are clamped" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let text = @render.to_ascii(qr, quiet_zone=-5, scale=0)
  let lines = text.split("\n").to_array()
  assert_eq(lines.length(), qr.size() + 1)
  let svg = @render.to_svg(qr, quiet_zone=-1, module_size=0)
  assert_true(svg.contains("viewBox=\"0 0 21 21\""))
  assert_true(svg.contains("width=\"21\""))
}
