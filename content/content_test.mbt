///|
test "text and url payloads pass through unchanged" {
  assert_eq(@content.Content::Text("hello world").to_text(), "hello world")
  assert_eq(
    @content.Content::Url("https://moonbitlang.com").to_text(),
    "https://moonbitlang.com",
  )
}

///|
test "wifi payload escapes reserved characters" {
  let plain = @content.Content::wifi("HomeNet", "secret123")
  assert_eq(plain.to_text(), "WIFI:T:WPA;S:HomeNet;P:secret123;;")
  let open = @content.Content::wifi("Cafe", "", auth="nopass")
  assert_eq(open.to_text(), "WIFI:T:nopass;S:Cafe;P:;;")
  let tricky = @content.Content::wifi("My;Net,1", "p:a\"s\\s")
  assert_eq(tricky.to_text(), "WIFI:T:WPA;S:My\\;Net\\,1;P:p\\:a\\\"s\\\\s;;")
}

///|
test "tel and sms payloads" {
  assert_eq(
    @content.Content::tel("+8613800138000").to_text(),
    "tel:+8613800138000",
  )
  assert_eq(@content.Content::sms("10086").to_text(), "SMSTO:10086:")
  assert_eq(
    @content.Content::sms("10086", message="hello").to_text(),
    "SMSTO:10086:hello",
  )
}

///|
test "mailto payload percent-encodes subject and body" {
  assert_eq(
    @content.Content::mailto("hi@example.com").to_text(),
    "mailto:hi@example.com",
  )
  assert_eq(
    @content.Content::mailto("hi@example.com", subject="a b&c").to_text(),
    "mailto:hi@example.com?subject=a%20b%26c",
  )
  assert_eq(
    @content.Content::mailto("hi@example.com", body="x+y").to_text(),
    "mailto:hi@example.com?body=x%2By",
  )
  assert_eq(
    @content.Content::mailto("hi@example.com", subject="hi", body="there").to_text(),
    "mailto:hi@example.com?subject=hi&body=there",
  )
  // UTF-8 bytes are percent-encoded; unreserved characters stay literal.
  assert_eq(
    @content.Content::mailto("hi@example.com", subject="你好 -._~").to_text(),
    "mailto:hi@example.com?subject=%E4%BD%A0%E5%A5%BD%20-._~",
  )
}

///|
test "geo payload joins coordinates" {
  assert_eq(
    @content.Content::geo("31.2304", "121.4737").to_text(),
    "geo:31.2304,121.4737",
  )
}

///|
test "vcard payload includes optional fields and escapes them" {
  let full = @content.Content::vcard(
    "Doe;John",
    phone="+1-555-0100",
    email="john@example.com",
    org="ACME, Inc.",
  )
  let expected = "BEGIN:VCARD\n" +
    "VERSION:3.0\n" +
    "N:Doe\\;John\n" +
    "FN:Doe\\;John\n" +
    "ORG:ACME\\, Inc.\n" +
    "TEL:+1-555-0100\n" +
    "EMAIL:john@example.com\n" +
    "END:VCARD"
  assert_eq(full.to_text(), expected)
  let minimal = @content.Content::vcard("Jane\nDoe")
  let minimal_expected = "BEGIN:VCARD\n" +
    "VERSION:3.0\n" +
    "N:Jane\\nDoe\n" +
    "FN:Jane\\nDoe\n" +
    "END:VCARD"
  assert_eq(minimal.to_text(), minimal_expected)
}

///|
test "encode_content encodes the rendered payload" {
  let content = @content.Content::vcard(
    "Ada Lovelace",
    phone="+44 20 7946 0958",
    email="ada@example.com",
    org="Analytical Engines",
  )
  let qr = @content.encode_content(content, ec_level=@core.EcLevel::H)
  let direct = @core.encode(content.to_text(), ec_level=@core.EcLevel::H)
  assert_eq(qr.size(), direct.size())
  assert_true(qr.mask() == direct.mask())
  assert_eq(qr.to_bytes(), direct.to_bytes())
}

///|
test "encode_content rejects empty payloads" {
  let mut rejected = false
  try ignore(@content.encode_content(@content.Content::Text(""))) catch {
    @core.QrError::EmptyInput => rejected = true
    _ => ()
  } noraise {
    _ => ()
  }
  assert_true(rejected)
}
