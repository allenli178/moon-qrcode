///|
test "flat encoding matches the core matrix" {
  let flat = @js.encode_to_modules(
    "hi",
    ec_level=@core.EcLevel::L,
    min_version=1,
    max_version=1,
  )
  let qr = @core.encode(
    "hi",
    ec_level=@core.EcLevel::L,
    min_version=1,
    max_version=1,
  )
  assert_eq(flat.size(), 21)
  assert_eq(flat.version(), 1)
  assert_eq(flat.data().length(), 441)
  assert_eq(flat.data().to_array(), qr.to_bytes())
  for y in 0..<flat.size() {
    for x in 0..<flat.size() {
      assert_true(flat.module_at(y, x) == qr.get(y, x))
    }
  }
}

///|
test "flat encoding reports the mask index" {
  let flat = @js.encode_to_modules(
    "HELLO WORLD",
    ec_level=@core.EcLevel::M,
    mask=@core.Mask::M3,
  )
  assert_eq(flat.mask(), 3)
  assert_eq(flat.ec_level(), @core.EcLevel::M)
}

///|
test "flat encoding propagates capacity errors" {
  let mut caught = false
  try
    ignore(
      @js.encode_to_modules(
        "this payload is far too long for version 1",
        min_version=1,
        max_version=1,
      ),
    )
  catch {
    @core.QrError::DataTooLong(_) => caught = true
    _ => ()
  } noraise {
    _ => ()
  }
  assert_true(caught)
}

///|
test "flat byte encoding matches core byte encoding" {
  let data = b"\xff\x00\x80hi"
  let flat = @js.encode_bytes_to_modules(
    data,
    ec_level=@core.EcLevel::L,
    mask=@core.Mask::M2,
  )
  let qr = @core.encode_bytes(
    data,
    ec_level=@core.EcLevel::L,
    mask=@core.Mask::M2,
  )
  assert_eq(flat.mask(), 2)
  assert_eq(flat.data().to_array(), qr.to_bytes())
}

///|
test "flat buffer honours forced masks" {
  let buf = @js.encode_flat_buffer("hi", 0, 1, 1, mask=@core.Mask::M5)
  let size = (buf[0].to_int() << 8) | buf[1].to_int()
  assert_eq(size, 21)
  assert_eq(buf[2].to_int(), 1)
  assert_eq(buf[3].to_int(), 5)
  assert_eq(buf.length(), 4 + 21 * 21)
}

///|
test "flat errors carry readable messages" {
  let mut message = ""
  try
    ignore(
      @js.encode_to_modules(
        "this payload is far too long for version 1",
        min_version=1,
        max_version=1,
      ),
    )
  catch {
    @core.QrError::DataTooLong(_) as err =>
      message = @js.flat_error_message(err)
    _ => ()
  } noraise {
    _ => ()
  }
  assert_true(message.contains("bits but V1"))
}
