///|
test "facade encodes and renders" {
  let qr = @moon-qrcode.encode("HELLO WORLD")
  assert_eq(qr.size(), 21)
  assert_true(@moon-qrcode.to_ascii(qr).length() > 0)
}

///|
test "facade re-exports SVG and content helpers" {
  let content = @moon-qrcode.Content::wifi("Cafe", "latte")
  let qr = @moon-qrcode.encode_content(
    content,
    ec_level=@moon-qrcode.EcLevel::H,
  )
  let svg = @moon-qrcode.to_svg(qr, quiet_zone=0, module_size=2)
  assert_true(svg.contains("<svg"))
  let half = @moon-qrcode.to_ascii_half(qr, quiet_zone=0)
  assert_true(half.length() > 0)
}

///|
test "facade re-exports errors and primitives" {
  let mut caught = false
  try ignore(@moon-qrcode.encode("", ec_level=@moon-qrcode.EcLevel::L)) catch {
    @moon-qrcode.QrError::EmptyInput => caught = true
    _ => ()
  } noraise {
    _ => ()
  }
  assert_true(caught)
  assert_true(@moon-qrcode.Version::new(0) is None)
  let v40 = @moon-qrcode.Version::new(40).unwrap()
  assert_eq(v40.size(), 177)
  assert_eq(@moon-qrcode.data_codewords(1, @moon-qrcode.EcLevel::L), 19)
  assert_eq(
    @moon-qrcode.format_info(@moon-qrcode.EcLevel::M, @moon-qrcode.Mask::M0),
    0x5412,
  )
  assert_true(@moon-qrcode.version_info(7) is Some(0x07C94))
}
