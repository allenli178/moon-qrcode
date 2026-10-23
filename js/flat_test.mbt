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
