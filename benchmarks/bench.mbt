///|
/// Deterministic payloads used by every benchmark so results stay comparable
/// across runs and backends.
fn payload_for(version : Int32, ec : @lib.EcLevel) -> String {
  let length = match (version, ec) {
    (1, _) => 11
    (10, L) => 150
    (10, M) => 120
    (10, Q) => 80
    (10, H) => 60
    (40, L) => 2000
    (40, M) => 1500
    (40, Q) => 900
    (40, H) => 600
    _ => 100
  }
  let sb = StringBuilder()
  for i in 0..<length {
    sb.write_char(if i % 2 == 0 { 'A' } else { 'B' })
  }
  sb.to_string()
}

///|
fn encode_checked(
  text : String,
  ec : @lib.EcLevel,
  min_version : Int32,
  max_version : Int32,
) -> Int32 {
  try {
    let qr = @lib.encode(text, ec_level=ec, min_version~, max_version~)
    qr.size()
  } catch {
    _ => 0
  }
}

///|
test (b : @bench.T) {
  let text = payload_for(1, @lib.EcLevel::L)
  b.bench(name="encode v1-L", () => {
    b.keep(encode_checked(text, @lib.EcLevel::L, 1, 1))
  })
}

///|
test (b : @bench.T) {
  let text = payload_for(10, @lib.EcLevel::M)
  b.bench(name="encode v10-M", () => {
    b.keep(encode_checked(text, @lib.EcLevel::M, 10, 10))
  })
}

///|
test (b : @bench.T) {
  let text = payload_for(10, @lib.EcLevel::H)
  b.bench(name="encode v10-H", () => {
    b.keep(encode_checked(text, @lib.EcLevel::H, 10, 10))
  })
}

///|
test (b : @bench.T) {
  let text = payload_for(40, @lib.EcLevel::L)
  b.bench(name="encode v40-L", () => {
    b.keep(encode_checked(text, @lib.EcLevel::L, 40, 40))
  })
}

///|
test (b : @bench.T) {
  let text = "ORDER000123456789-ABCDEF/xyz?q=1234567890&ref=MOONQR"
  b.bench(name="encode v10-M auto mixed", () => {
    b.keep(encode_checked(text, @lib.EcLevel::M, 10, 10))
  })
}

///|
test (b : @bench.T) {
  let text = payload_for(10, @lib.EcLevel::M)
  let qr = @lib.encode(
    text,
    ec_level=@lib.EcLevel::M,
    min_version=10,
    max_version=10,
  ) catch {
    _ => abort("benchmark payload must encode")
  }
  b.bench(name="svg v10-M", () => {
    let length = @lib.to_svg(qr, quiet_zone=4, module_size=4).length() catch {
      _ => 0
    }
    b.keep(length)
  })
}

///|
test (b : @bench.T) {
  let text = payload_for(10, @lib.EcLevel::M)
  let qr = @lib.encode(
    text,
    ec_level=@lib.EcLevel::M,
    min_version=10,
    max_version=10,
  ) catch {
    _ => abort("benchmark payload must encode")
  }
  b.bench(name="ascii-half v10-M", () => {
    b.keep(@lib.to_ascii_half(qr, quiet_zone=4).length())
  })
}
