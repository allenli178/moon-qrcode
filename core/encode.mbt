///|
fn choose_version(
  segments : Array[Segment],
  ec : EcLevel,
  min_version : Int32,
  max_version : Int32,
) -> Int32 raise QrError {
  if min_version < 1 || min_version > 40 {
    raise QrError::InvalidVersion(min_version)
  }
  if max_version < min_version || max_version > 40 {
    raise QrError::InvalidVersion(max_version)
  }
  let mut chosen = 0
  for v in min_version..<=max_version {
    let bits = bits_needed(segments, v)
    if chosen == 0 && bits <= data_capacity_bits(v, ec) {
      chosen = v
    }
  }
  if chosen == 0 {
    raise QrError::DataTooLong(
      needed=bits_needed(segments, max_version),
      capacity=data_capacity_bits(max_version, ec),
      version=max_version,
      ec_level=ec,
    )
  }
  chosen
}

///|
/// Splits data codewords into RS blocks, appends parity, and interleaves both.
///
/// 将数据码字拆分为 RS 块，追加校验字节，并交错排列。
fn interleave_blocks(
  data : Array[Byte],
  version : Int32,
  ec : EcLevel,
) -> Array[Byte] {
  let nblocks = block_count(version, ec)
  let ecc_len = ecc_codewords(version, ec)
  let raw_len = data.length()
  let short_len = raw_len / nblocks
  let num_short = nblocks - raw_len % nblocks
  let blocks : Array[Array[Byte]] = []
  let eccs : Array[Array[Byte]] = []
  let mut offset = 0
  for i in 0..<nblocks {
    let len = short_len + (if i < num_short { 0 } else { 1 })
    let block = Array::make(len, (0 : Byte))
    for j in 0..<len {
      block[j] = data[offset + j]
    }
    offset += len
    blocks.push(block)
    eccs.push(rs_encode(block, ecc_len))
  }
  let result : Array[Byte] = []
  let max_len = short_len + (if num_short < nblocks { 1 } else { 0 })
  for i in 0..<max_len {
    for block in blocks {
      if i < block.length() {
        result.push(block[i])
      }
    }
  }
  for i in 0..<ecc_len {
    for ecc in eccs {
      result.push(ecc[i])
    }
  }
  result
}

///|
fn make_qr(version : Int32, ec : EcLevel, mask : Mask, m : Matrix) -> QrCode {
  {
    version_: Version(version),
    ec_level_: ec,
    mask_: mask,
    size_: m.size,
    modules_: m.modules.copy(),
  }
}

///|
/// Encodes `text` as a QR Model 2 symbol.
///
/// 将 `text` 编码为 QR Model 2 符号。
///
/// `ec_level` defaults to M, version range to 1..40, mode is chosen
/// automatically, and the mask is selected by minimizing the Annex J penalty.
///
/// `ec_level` 默认为 M，版本范围为 1..40，模式自动选择，
/// 掩码通过最小化 Annex J 惩罚分选出。
///
/// # Example
/// ```mbt check
/// test "encode hello world" {
///   let qr = @core.encode("HELLO WORLD") // V1-M
///   assert_eq(qr.size(), 21)
///   assert_eq(qr.version().value(), 1)
/// }
/// ```
pub fn encode(
  text : String,
  ec_level~ : EcLevel = EcLevel::M,
  min_version~ : Int32 = 1,
  max_version~ : Int32 = 40,
  mode? : Mode,
  mask? : Mask,
) -> QrCode raise QrError {
  let segments = match mode {
    Some(m) => split_segments(text, mode=m)
    None => split_segments(text)
  }
  let version = choose_version(segments, ec_level, min_version, max_version)
  let capacity_bytes = data_codewords(version, ec_level)
  let buf = BitBuffer::new()
  for seg in segments {
    append_segment(buf, seg, version)
  }
  buf.pad_to(capacity_bytes)
  let codewords = interleave_blocks(buf.to_bytes(), version, ec_level)
  let base = build_matrix(version, codewords)
  match mask {
    Some(m) => make_qr(version, ec_level, m, apply_mask(base, m, ec_level))
    None => {
      let (best, best_mask) = choose_best_mask(base, ec_level)
      make_qr(version, ec_level, best_mask, best)
    }
  }
}
