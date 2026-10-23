///|
/// A run of input characters encoded with one mode.
///
/// 使用同一模式编码的一段输入字符。
pub struct Segment {
  mode_ : Mode
  data_ : String
}

///|
pub fn Segment::new(mode : Mode, data : String) -> Segment {
  { mode_: mode, data_: data, }
}

///|
pub fn Segment::mode(self : Segment) -> Mode {
  self.mode_
}

///|
pub fn Segment::data(self : Segment) -> String {
  self.data_
}

///|
/// Value of an alphanumeric character (ISO Table 5), if it belongs to the set.
fn alnum_value(c : Char) -> Int32? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'A' && c <= 'Z' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    match c {
      ' ' => Some(36)
      '$' => Some(37)
      '%' => Some(38)
      '*' => Some(39)
      '+' => Some(40)
      '-' => Some(41)
      '.' => Some(42)
      '/' => Some(43)
      ':' => Some(44)
      _ => None
    }
  }
}

///|
fn classify(c : Char) -> Mode {
  if c >= '0' && c <= '9' {
    Numeric
  } else if alnum_value(c) is Some(_) {
    Alphanumeric
  } else {
    Byte
  }
}

///|
fn validate(text : String, mode : Mode) -> Unit raise QrError {
  for c in text {
    let ok = match mode {
      Numeric => c >= '0' && c <= '9'
      Alphanumeric => alnum_value(c) is Some(_)
      Byte => true
    }
    if !ok {
      raise QrError::InvalidCharacter(char=c, mode~)
    }
  }
}

///|
/// Character count written into the segment header.
///
/// 写入段头的字符计数。
pub fn Segment::char_count(self : Segment) -> Int32 {
  match self.mode_ {
    Byte => @utf8.encode(self.data_).length()
    _ => self.data_.length()
  }
}

///|
/// Payload bit length, excluding mode and character-count fields.
///
/// 载荷比特长度，不含模式和字符计数字段。
pub fn Segment::data_bits(self : Segment) -> Int32 {
  match self.mode_ {
    Numeric => {
      let n = self.data_.length()
      let rem = n % 3
      n / 3 * 10 + (if rem == 2 { 7 } else if rem == 1 { 4 } else { 0 })
    }
    Alphanumeric => {
      let n = self.data_.length()
      n / 2 * 11 + (if n % 2 == 1 { 6 } else { 0 })
    }
    Byte => @utf8.encode(self.data_).length() * 8
  }
}

///|
/// Merges short non-byte runs into an adjacent byte run when doing so saves
/// header bits, then merges adjacent byte runs. Purely numeric/alphanumeric
/// inputs are left alone because they have no byte neighbour.
fn merge_short_runs(segments : Array[Segment]) -> Array[Segment] {
  let result : Array[Segment] = []
  let n = segments.length()
  for i in 0..<n {
    let seg = segments[i]
    let prev_byte = i > 0 && segments[i - 1].mode_ == Byte
    let next_byte = i + 1 < n && segments[i + 1].mode_ == Byte
    let has_byte_neighbor = prev_byte || next_byte
    let short = seg.data_.length()
    let numeric_short = seg.mode_ == Numeric && short <= 2
    let alpha_short = seg.mode_ == Alphanumeric && short <= 4
    let absorb = has_byte_neighbor && (numeric_short || alpha_short)
    let as_byte = if seg.mode_ == Byte || absorb {
      Some(Segment::new(Byte, seg.data_))
    } else {
      None
    }
    match as_byte {
      Some(b) =>
        if result.length() > 0 && result[result.length() - 1].mode_ == Byte {
          match result.pop() {
            Some(prev) => result.push(Segment::new(Byte, prev.data_ + b.data_))
            None => result.push(b)
          }
        } else {
          result.push(b)
        }
      None => result.push(seg)
    }
  }
  result
}

///|
/// Splits text into greedy class runs. Forcing `mode` produces a single segment
/// and rejects characters outside that mode's repertoire.
///
/// 将文本拆分为贪心分类段。强制指定 `mode` 时生成单个段，
/// 并拒绝该模式字符集之外的字符。
pub fn split_segments(
  text : String,
  mode? : Mode,
) -> Array[Segment] raise QrError {
  if text.is_empty() {
    raise QrError::EmptyInput
  }
  match mode {
    Some(m) => {
      validate(text, m)
      [Segment::new(m, text)]
    }
    None => {
      let segments : Array[Segment] = []
      let sb = StringBuilder()
      let mut current = Mode::Byte
      let mut has_content = false
      for c in text {
        let m = classify(c)
        if !has_content {
          current = m
          has_content = true
          sb.write_char(c)
        } else if m == current {
          sb.write_char(c)
        } else {
          segments.push(Segment::new(current, sb.to_string()))
          sb.reset()
          current = m
          sb.write_char(c)
        }
      }
      segments.push(Segment::new(current, sb.to_string()))
      merge_short_runs(segments)
    }
  }
}

///|
/// Mode indicator, ISO Table 4 (Kanji omitted in v0.x).
fn mode_indicator(mode : Mode) -> Int32 {
  match mode {
    Numeric => 1
    Alphanumeric => 2
    Byte => 4
  }
}

///|
/// Total bits needed for the segments at a given version, headers included.
///
/// 给定版本下所有段的总比特数，包含段头。
pub fn bits_needed(segments : Array[Segment], version : Int32) -> Int32 {
  let mut total = 0
  for seg in segments {
    total += 4 + char_count_bits(version, seg.mode_) + seg.data_bits()
  }
  total
}

///|
fn append_segment(buf : BitBuffer, seg : Segment, version : Int32) -> Unit {
  buf.push_bits(mode_indicator(seg.mode_), 4)
  buf.push_bits(seg.char_count(), char_count_bits(version, seg.mode_))
  match seg.mode_ {
    Numeric => {
      let digits : Array[Int32] = []
      for c in seg.data_ {
        digits.push(c.to_int() - '0'.to_int())
      }
      let mut i = 0
      while i < digits.length() {
        let remaining = digits.length() - i
        if remaining >= 3 {
          buf.push_bits(
            digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2],
            10,
          )
          i += 3
        } else if remaining == 2 {
          buf.push_bits(digits[i] * 10 + digits[i + 1], 7)
          i += 2
        } else {
          buf.push_bits(digits[i], 4)
          i += 1
        }
      }
    }
    Alphanumeric => {
      let mut pending : Int32? = None
      for c in seg.data_ {
        if alnum_value(c) is Some(v) {
          match pending {
            None => pending = Some(v)
            Some(first) => {
              buf.push_bits(first * 45 + v, 11)
              pending = None
            }
          }
        }
      }
      if pending is Some(first) {
        buf.push_bits(first, 6)
      }
    }
    Byte =>
      for b in @utf8.encode(seg.data_) {
        buf.push_bits(b.to_int(), 8)
      }
  }
}
