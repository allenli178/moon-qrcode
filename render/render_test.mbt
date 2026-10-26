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
test "SVG contains the expected frame and merged dark runs" {
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
  // The top-left finder row is one seven-module run after the quiet zone.
  assert_true(svg.contains("<path d=\"M4 4h7v1h-7"))
  assert_false(svg.contains("<rect x="))
  assert_eq(svg.split("<path").to_array().length(), 2)
}

///|
test "SVG emits one subpath per horizontal dark run" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let svg = @render.to_svg(qr, quiet_zone=4, module_size=4)
  let mut runs = 0
  for y in 0..<qr.size() {
    let mut x = 0
    while x < qr.size() {
      if qr.get(y, x) {
        runs = runs + 1
        while x < qr.size() && qr.get(y, x) {
          x = x + 1
        }
      } else {
        x = x + 1
      }
    }
  }
  // Every run contributes exactly one `v1h-` tail.
  assert_eq(svg.split("v1h-").to_array().length(), runs + 1)
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
  assert_true(svg.contains("<path d=\"M0 0h7v1h-7"))
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
