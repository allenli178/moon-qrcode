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

///|
test "PNG output has valid signature and structure" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let png = @render.to_png(qr, quiet_zone=0, module_size=1)
  // PNG signature: 137 80 78 71 13 10 26 10
  assert_eq(png[0], (0x89 : Byte))
  assert_eq(png[1], (0x50 : Byte))
  assert_eq(png[2], (0x4E : Byte))
  assert_eq(png[3], (0x47 : Byte))
  assert_eq(png[4], (0x0D : Byte))
  assert_eq(png[5], (0x0A : Byte))
  assert_eq(png[6], (0x1A : Byte))
  assert_eq(png[7], (0x0A : Byte))
  // IHDR chunk starts at offset 8
  assert_eq(png[12], (0x49 : Byte)) // 'I'
  assert_eq(png[13], (0x48 : Byte)) // 'H'
  assert_eq(png[14], (0x44 : Byte)) // 'D'
  assert_eq(png[15], (0x52 : Byte)) // 'R'
  // IHDR data: width=21 (big-endian)
  assert_eq(png[16], (0 : Byte))
  assert_eq(png[17], (0 : Byte))
  assert_eq(png[18], (0 : Byte))
  assert_eq(png[19], (21 : Byte))
  // bit_depth=8, color_type=0 (grayscale)
  assert_eq(png[24], (8 : Byte))
  assert_eq(png[25], (0 : Byte))
  // Last chunk should be IEND
  let end = png.length()
  assert_eq(png[end - 8], (0x49 : Byte))
  assert_eq(png[end - 7], (0x45 : Byte))
  assert_eq(png[end - 6], (0x4E : Byte))
  assert_eq(png[end - 5], (0x44 : Byte))
  // IEND length is 0
  assert_eq(png[end - 12], (0 : Byte))
}

///|
test "PNG with quiet zone and module size scales dimensions correctly" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let png = @render.to_png(qr, quiet_zone=4, module_size=4)
  // size=21 + 8 quiet zone = 29 pixels per side * 4 = 116
  // IHDR width at bytes 16..19
  let w = (png[16].to_int() << 24) |
    (png[17].to_int() << 16) |
    (png[18].to_int() << 8) |
    png[19].to_int()
  assert_eq(w, 116)
  // IHDR height at bytes 20..23
  let h = (png[20].to_int() << 24) |
    (png[21].to_int() << 16) |
    (png[22].to_int() << 8) |
    png[23].to_int()
  assert_eq(h, 116)
}

///|
test "PNG RGBA output has color type 6 and valid colors" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let png = @render.to_png_rgba(
    qr,
    quiet_zone=0,
    module_size=1,
    dark="#ff0000",
    light="#00ff00",
  )
  // Same PNG signature
  assert_eq(png[0], (0x89 : Byte))
  assert_eq(png[1], (0x50 : Byte))
  // color_type should be 6 (RGBA)
  assert_eq(png[25], (6 : Byte))
  // bit_depth still 8
  assert_eq(png[24], (8 : Byte))
}

///|
test "PNG RGBA rejects invalid colors" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  try ignore(@render.to_png_rgba(qr, dark="<script>", light="#ffffff")) catch {
    @core.QrError::InvalidColor(_) => ()
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
test "PNG negative quiet zone and tiny scale are clamped" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let png = @render.to_png(qr, quiet_zone=-1, module_size=0)
  // Should be size 21 (no quiet zone, module_size clamped to 1)
  let w = (png[16].to_int() << 24) |
    (png[17].to_int() << 16) |
    (png[18].to_int() << 8) |
    png[19].to_int()
  assert_eq(w, 21)
}

///|
test "PBM output has correct header" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let pbm = @render.to_pbm(qr, quiet_zone=0, module_size=1)
  // PBM P4 header should start with "P4\n21 21\n"
  assert_eq(pbm[0], 'P'.to_int().to_byte())
  assert_eq(pbm[1], '4'.to_int().to_byte())
  // Width 21 and height 21 (decimal)
  let header = "P4\n21 21\n"
  for i in 0..<header.length() {
    assert_eq(pbm[i], header[i].to_int().to_byte())
  }
}

///|
test "PNG IDAT chunk contains compressed data" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let png = @render.to_png(qr, quiet_zone=0, module_size=1)
  // Find IDAT chunk (should be after IHDR)
  let mut found = false
  let mut i = 8
  while i < png.length() - 4 {
    // Check for IDAT type marker
    if png[i] == (0x49 : Byte) &&
      png[i + 1] == (0x44 : Byte) &&
      png[i + 2] == (0x41 : Byte) &&
      png[i + 3] == (0x54 : Byte) {
      found = true
      // zlib header should be 0x78 0x01
      assert_eq(png[i + 4], (0x78 : Byte))
      assert_eq(png[i + 5], (0x01 : Byte))
      break
    }
    i = i + 1
  }
  assert_true(found)
}

///|
test "SVG rect mode emits one <rect> per dark module" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let svg = @render.to_svg_rect(qr, quiet_zone=0, module_size=1)
  assert_true(svg.has_prefix("<?xml version=\"1.0\""))
  assert_true(svg.contains("preserveAspectRatio=\"xMidYMid meet\""))
  assert_true(svg.contains("shape-rendering=\"crispEdges\""))
  let dark_count = svg.split("<rect x=").to_array().length() - 1
  // Count dark modules in QR
  let mut expected = 0
  for y in 0..<qr.size() {
    for x in 0..<qr.size() {
      if qr.get(y, x) {
        expected = expected + 1
      }
    }
  }
  assert_eq(dark_count, expected)
}

///|
test "SVG rect mode supports custom preserveAspectRatio and colors" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let svg = @render.to_svg_rect(
    qr,
    quiet_zone=2,
    module_size=2,
    dark="#ff0000",
    light="#00ff00",
    preserve_aspect_ratio="xMinYMin slice",
  )
  assert_true(svg.contains("preserveAspectRatio=\"xMinYMin slice\""))
  assert_true(svg.contains("fill=\"#00ff00\""))
  assert_true(svg.contains("fill=\"#ff0000\""))
  // viewBox should be 25 (21 + 4 quiet zone)
  assert_true(svg.contains("viewBox=\"0 0 25 25\""))
}

///|
test "SVG rounded groups runs with rx/ry attributes" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let svg = @render.to_svg_rounded(qr, quiet_zone=0, module_size=1, radius=1)
  assert_true(svg.contains("rx=\"1\""))
  assert_true(svg.contains("ry=\"1\""))
  assert_true(svg.contains("shape-rendering=\"geometricPrecision\""))
  assert_true(svg.contains("<g fill=\"#000000\" rx=\"1\" ry=\"1\">"))
  // Should have runs merged into single <rect> per row
  assert_true(svg.contains("<rect x="))
}

///|
test "SVG rounded rejects invalid colors" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  try ignore(@render.to_svg_rounded(qr, dark="red\" onload=\"alert(1)")) catch {
    @core.QrError::InvalidColor(_) => ()
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
test "ASCII color output includes ANSI escape sequences" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let text = @render.to_ascii_color(qr, quiet_zone=0, scale=1)
  // Should contain ANSI 24-bit escape sequences
  assert_true(text.contains("\x1b[48;2;"))
  assert_true(text.contains("\x1b[38;2;"))
  assert_true(text.contains("\x1b[0m"))
  // total size=21 rows, each ending with \n, plus escape prefix (no \n) and reset suffix
  // split("\n") gives: escape+line1, line2..line21, reset  -> size + 1 elements
  let lines = text.split("\n").to_array()
  assert_eq(lines.length(), qr.size() + 1)
}

///|
test "ASCII color inverted swaps foreground and background" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  let text = @render.to_ascii_color(
    qr,
    quiet_zone=0,
    scale=1,
    dark="#ff0000",
    light="#0000ff",
    inverted=true,
  )
  // inverted: bg should be dark color (ff0000), fg should be light (0000ff)
  assert_true(text.contains("\x1b[48;2;255;0;0m"))
  assert_true(text.contains("\x1b[38;2;0;0;255m"))
}

///|
test "ASCII color rejects invalid colors" {
  let qr = @core.encode(
    "hi",
    min_version=1,
    max_version=1,
    mode=@core.Mode::Byte,
  )
  try ignore(@render.to_ascii_color(qr, dark="<script>")) catch {
    @core.QrError::InvalidColor(_) => ()
    _ => ()
  } noraise {
    _ => ()
  }
}
