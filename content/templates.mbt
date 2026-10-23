///|
/// Common payload templates. Each variant renders to the string that should be
/// encoded into the QR symbol.
///
/// 常用载荷模板。每个变体渲染为待编码到 QR 符号中的字符串。
pub(all) enum Content {
  Text(String)
  Url(String)
  Wifi(ssid~ : String, password~ : String, auth~ : String)
  Tel(String)
  Mailto(address~ : String, subject~ : String, body~ : String)
  Sms(number~ : String, message~ : String)
  Geo(lat~ : String, lng~ : String)
  VCard(name~ : String, phone~ : String, email~ : String, org~ : String)
}

///|
pub fn Content::wifi(
  ssid : String,
  password : String,
  auth~ : String = "WPA",
) -> Content {
  Wifi(ssid~, password~, auth~)
}

///|
pub fn Content::mailto(
  address : String,
  subject~ : String = "",
  body~ : String = "",
) -> Content {
  Mailto(address~, subject~, body~)
}

///|
pub fn Content::sms(number : String, message~ : String = "") -> Content {
  Sms(number~, message~)
}

///|
pub fn Content::tel(number : String) -> Content {
  Tel(number)
}

///|
pub fn Content::geo(lat : String, lng : String) -> Content {
  Geo(lat~, lng~)
}

///|
pub fn Content::vcard(
  name : String,
  phone~ : String = "",
  email~ : String = "",
  org~ : String = "",
) -> Content {
  VCard(name~, phone~, email~, org~)
}

///|
fn escape_wifi(value : String) -> String {
  let sb = StringBuilder()
  for c in value {
    if c == '\\' || c == ';' || c == ',' || c == ':' || c == '"' {
      sb.write_char('\\')
    }
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn escape_vcard(value : String) -> String {
  let sb = StringBuilder()
  for c in value {
    match c {
      '\\' => sb.write_string("\\\\")
      ';' => sb.write_string("\\;")
      ',' => sb.write_string("\\,")
      '\n' => sb.write_string("\\n")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn hex_chars() -> Array[Char] {
  [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
}

///|
fn percent_encode(value : String) -> String {
  let digits = hex_chars()
  let sb = StringBuilder()
  for b in @utf8.encode(value) {
    let v = b.to_int()
    let digit = v >= 48 && v <= 57
    let upper = v >= 65 && v <= 90
    let lower = v >= 97 && v <= 122
    let unreserved = digit ||
      upper ||
      lower ||
      v == 45 ||
      v == 46 ||
      v == 95 ||
      v == 126
    if unreserved {
      sb.write_char(b.to_char())
    } else {
      sb.write_char('%')
      sb.write_char(digits[(v >> 4) & 15])
      sb.write_char(digits[v & 15])
    }
  }
  sb.to_string()
}

///|
/// Serializes the template into the payload text.
///
/// 将模板序列化为载荷文本。
pub fn Content::to_text(self : Content) -> String {
  match self {
    Text(s) => s
    Url(s) => s
    Wifi(ssid~, password~, auth~) =>
      "WIFI:T:\{auth};S:\{escape_wifi(ssid)};P:\{escape_wifi(password)};;"
    Tel(number) => "tel:\{number}"
    Mailto(address~, subject~, body~) => {
      let mut result = "mailto:\{address}"
      let mut sep = "?"
      if !subject.is_empty() {
        result = result + sep + "subject=" + percent_encode(subject)
        sep = "&"
      }
      if !body.is_empty() {
        result = result + sep + "body=" + percent_encode(body)
      }
      result
    }
    Sms(number~, message~) => "SMSTO:\{number}:\{message}"
    Geo(lat~, lng~) => "geo:\{lat},\{lng}"
    VCard(name~, phone~, email~, org~) => {
      let sb = StringBuilder()
      sb <+ "BEGIN:VCARD\nVERSION:3.0\n"
      sb <+ "N:\{escape_vcard(name)}\n"
      sb <+ "FN:\{escape_vcard(name)}\n"
      if !org.is_empty() {
        sb <+ "ORG:\{escape_vcard(org)}\n"
      }
      if !phone.is_empty() {
        sb <+ "TEL:\{escape_vcard(phone)}\n"
      }
      if !email.is_empty() {
        sb <+ "EMAIL:\{escape_vcard(email)}\n"
      }
      sb <+ "END:VCARD"
      sb.to_string()
    }
  }
}

///|
/// Convenience wrapper: render a template and encode it.
///
/// 便捷包装：渲染模板并编码。
pub fn encode_content(
  content : Content,
  ec_level~ : @core.EcLevel = @core.EcLevel::M,
) -> @core.QrCode raise @core.QrError {
  @core.encode(content.to_text(), ec_level~)
}
