///|
suberror CliError {
  Usage(String)
}

///|
fn CliError::message(self : CliError) -> String {
  match self {
    Usage(reason) => reason
  }
}

///|
/// Prints a diagnostic and terminates with a non-zero exit status.
///
/// 打印诊断信息并以非零状态码退出。
fn[T] die(message : String) -> T {
  eprintln("moonqr: \{message}")
  @sys.exit(1)
  abort("unreachable")
}

///|
struct Options {
  payload : String
  ec_level : @lib.EcLevel
  min_version : Int32
  max_version : Int32
  mode : @lib.Mode?
  mask : @lib.Mask?
  quiet_zone : Int32
  scale : Int32
  module_size : Int32
  format : String
  output : String?
  dark : String
  light : String
}

///|
fn parse_ec(value : String) -> @lib.EcLevel raise CliError {
  match value {
    "L" | "l" => @lib.EcLevel::L
    "M" | "m" => @lib.EcLevel::M
    "Q" | "q" => @lib.EcLevel::Q
    "H" | "h" => @lib.EcLevel::H
    _ =>
      raise CliError::Usage(
        "invalid EC level '\{value}'; expected L, M, Q or H",
      )
  }
}

///|
fn parse_mode(value : String) -> @lib.Mode raise CliError {
  match value {
    "numeric" | "Numeric" | "N" => @lib.Mode::Numeric
    "alphanumeric" | "Alphanumeric" | "A" => @lib.Mode::Alphanumeric
    "byte" | "Byte" | "B" => @lib.Mode::Byte
    _ =>
      raise CliError::Usage(
        "invalid mode '\{value}'; expected numeric, alphanumeric or byte",
      )
  }
}

///|
fn parse_mask(value : String) -> @lib.Mask raise CliError {
  match value {
    "0" => @lib.Mask::M0
    "1" => @lib.Mask::M1
    "2" => @lib.Mask::M2
    "3" => @lib.Mask::M3
    "4" => @lib.Mask::M4
    "5" => @lib.Mask::M5
    "6" => @lib.Mask::M6
    "7" => @lib.Mask::M7
    _ => raise CliError::Usage("invalid mask '\{value}'; expected 0..7")
  }
}

///|
fn parse_int(value : String, what : String) -> Int32 raise CliError {
  if value.is_empty() {
    raise CliError::Usage("missing value for \{what}")
  }
  let mut result = 0
  for c in value {
    if c < '0' || c > '9' {
      raise CliError::Usage("invalid integer '\{value}' for \{what}")
    }
    result = result * 10 + (c.to_int() - '0'.to_int())
  }
  result
}

///|
fn take_value(
  argv : Array[String],
  index : Int32,
  flag : String,
) -> (String, Int32) raise CliError {
  if index + 1 >= argv.length() {
    raise CliError::Usage("missing value after \{flag}")
  }
  (argv[index + 1], index + 2)
}

///|
fn print_help() -> Unit {
  println(
    "moonqr - MoonBit QR Code 生成器 / QR Code Generator\n\n用法 / USAGE:\n  moonqr <载荷/payload> [选项/options]\n  moonqr - [选项/options] < 文件\n  moonqr [选项/options] -- <载荷/payload>\n\n选项 / OPTIONS:\n  -l, --level <L|M|Q|H>      纠错等级 / error correction level (default M)\n  -v, --version <1..40>      指定版本 / force an explicit version\n      --min-version <n>      最小候选版本 / smallest version considered\n      --max-version <n>      最大候选版本 / largest version considered\n  -m, --mode <name>          numeric | alphanumeric | byte (default auto)\n      --mask <0..7>          指定掩码 / force a mask pattern\n  -q, -qz, --quiet-zone <n>  静默区宽度 / quiet zone width in modules (default 4)\n  -s, --scale <n>            ASCII 缩放倍数 / ASCII scale factor (default 1)\n      --module-size <n>      SVG 模块像素大小 / SVG module size in pixels (default 4)\n  -f, --format <name>        ascii | half | svg | json (default: by output extension)\n      --json                 JSON 元数据与模块矩阵 / JSON metadata and module rows\n  -o, --output <path>        输出到文件 / write to a file instead of stdout\n      --svg                  格式快捷方式 / shorthand for --format svg\n      --half                 格式快捷方式 / shorthand for --format half\n      --dark <css-color>     SVG 前景色 / SVG foreground color (default #000000)\n      --light <css-color>    SVG 背景色 / SVG background color (default #ffffff)\n  -h, --help                 显示帮助 / show this help\n  -V, --cli-version          显示版本 / show the CLI version\n\n将载荷写成 - 时从标准输入读取，末尾换行会被去除。\nUse - as the payload to read from stdin; trailing newlines are stripped.\n使用 -- 可编码以 - 开头的载荷。\nUse -- before a payload that starts with -.\n\n示例 / EXAMPLES:\n  moonqr \"HELLO WORLD\" -l H -o hello.svg\n  moonqr \"https://moonbitlang.com\" --format half\n  moonqr \"你好世界\" -l M -o hello.svg\n  moonqr \"0123456789\" -v 2 -m numeric -s 2\n  echo -n \"HELLO\" | moonqr - -l H --svg\n  cat payload.txt | moonqr - -o code.svg\n  moonqr --json \"HELLO\" | jq .version\n  moonqr -- --payload-starting-with-dash",
  )
}

///|
fn parse_args(argv : Array[String]) -> Options raise CliError {
  let mut payload : String? = None
  let mut ec_level = @lib.EcLevel::M
  let mut min_version = 1
  let mut max_version = 40
  let mut mode : @lib.Mode? = None
  let mut mask : @lib.Mask? = None
  let mut quiet_zone = 4
  let mut scale = 1
  let mut module_size = 4
  let mut format = "auto"
  let mut output : String? = None
  let mut dark = "#000000"
  let mut light = "#ffffff"
  let mut i = 1
  let mut options_done = false
  while i < argv.length() {
    let arg = argv[i]
    if !options_done && arg == "--" {
      options_done = true
      i = i + 1
      continue
    }
    if options_done || arg == "-" || !arg.has_prefix("-") {
      match payload {
        None => payload = Some(arg)
        Some(_) => raise CliError::Usage("unexpected extra argument '\{arg}'")
      }
      i = i + 1
      continue
    }
    match arg {
      "-h" | "--help" => {
        print_help()
        @sys.exit(0)
        abort("unreachable")
      }
      "-V" | "--cli-version" => {
        println("moonqr 0.2.0")
        @sys.exit(0)
        abort("unreachable")
      }
      "--json" => {
        format = "json"
        i = i + 1
      }
      "--svg" => {
        format = "svg"
        i = i + 1
      }
      "--half" => {
        format = "half"
        i = i + 1
      }
      "-l" | "--level" => {
        let (value, next) = take_value(argv, i, arg)
        ec_level = parse_ec(value)
        i = next
      }
      "-v" | "--version" => {
        let (value, next) = take_value(argv, i, arg)
        let v = parse_int(value, arg)
        min_version = v
        max_version = v
        i = next
      }
      "--min-version" => {
        let (value, next) = take_value(argv, i, arg)
        min_version = parse_int(value, arg)
        i = next
      }
      "--max-version" => {
        let (value, next) = take_value(argv, i, arg)
        max_version = parse_int(value, arg)
        i = next
      }
      "-m" | "--mode" => {
        let (value, next) = take_value(argv, i, arg)
        mode = Some(parse_mode(value))
        i = next
      }
      "--mask" => {
        let (value, next) = take_value(argv, i, arg)
        mask = Some(parse_mask(value))
        i = next
      }
      "-q" | "-qz" | "--quiet-zone" => {
        let (value, next) = take_value(argv, i, arg)
        quiet_zone = parse_int(value, arg)
        i = next
      }
      "-s" | "--scale" => {
        let (value, next) = take_value(argv, i, arg)
        scale = parse_int(value, arg)
        i = next
      }
      "--module-size" => {
        let (value, next) = take_value(argv, i, arg)
        module_size = parse_int(value, arg)
        i = next
      }
      "-f" | "--format" => {
        let (value, next) = take_value(argv, i, arg)
        match value {
          "ascii" | "half" | "svg" | "json" => format = value
          _ =>
            raise CliError::Usage(
              "invalid format '\{value}'; expected ascii, half, svg or json",
            )
        }
        i = next
      }
      "-o" | "--output" => {
        let (value, next) = take_value(argv, i, arg)
        output = Some(value)
        i = next
      }
      "--dark" => {
        let (value, next) = take_value(argv, i, arg)
        dark = value
        i = next
      }
      "--light" => {
        let (value, next) = take_value(argv, i, arg)
        light = value
        i = next
      }
      _ => raise CliError::Usage("unknown option '\{arg}' (try --help)")
    }
  }
  let payload = match payload {
    Some("-") => read_stdin_text()
    Some(text) => text
    None => raise CliError::Usage("missing payload (try --help)")
  }
  if min_version < 1 || min_version > 40 {
    raise CliError::Usage("min version must be within 1..40")
  }
  if max_version < 1 || max_version > 40 {
    raise CliError::Usage("max version must be within 1..40")
  }
  if min_version > max_version {
    raise CliError::Usage("min version must not exceed max version")
  }
  if quiet_zone < 0 {
    raise CliError::Usage("quiet zone must be non-negative")
  }
  if scale < 1 {
    raise CliError::Usage("scale must be at least 1")
  }
  if module_size < 1 {
    raise CliError::Usage("module size must be at least 1")
  }
  {
    payload,
    ec_level,
    min_version,
    max_version,
    mode,
    mask,
    quiet_zone,
    scale,
    module_size,
    format,
    output,
    dark,
    light,
  }
}

///|
fn encode_qr(options : Options) -> @lib.QrCode {
  try
    @lib.encode(
      options.payload,
      ec_level=options.ec_level,
      min_version=options.min_version,
      max_version=options.max_version,
      mode?=options.mode,
      mask?=options.mask,
    )
  catch {
    e => die(e.message())
  } noraise {
    qr => qr
  }
}

///|
fn inferred_format(options : Options) -> String {
  if options.format != "auto" {
    return options.format
  }
  match options.output {
    Some(path) => {
      let lower = path.to_lower()
      if lower.has_suffix(".txt") {
        "ascii"
      } else if lower.has_suffix(".json") {
        "json"
      } else {
        "svg"
      }
    }
    None => "ascii"
  }
}

///|
fn mask_number(mask : @lib.Mask) -> Int32 {
  match mask {
    @lib.Mask::M0 => 0
    @lib.Mask::M1 => 1
    @lib.Mask::M2 => 2
    @lib.Mask::M3 => 3
    @lib.Mask::M4 => 4
    @lib.Mask::M5 => 5
    @lib.Mask::M6 => 6
    @lib.Mask::M7 => 7
  }
}

///|
/// JSON metadata plus row-major module rows (`1` dark, `0` light), without
/// the quiet zone.
///
/// JSON 元数据与行优先模块行（`1` 深色，`0` 浅色），不含静默区。
fn render_json(qr : @lib.QrCode) -> String {
  let sb = StringBuilder()
  sb <+
    "{\"version\":\{qr.version().value()},\"ecLevel\":\"\{qr.ec_level()}\",\"mask\":\{mask_number(qr.mask())},\"size\":\{qr.size()},\"modules\":["
  for y in 0..<qr.size() {
    if y > 0 {
      sb <+ ","
    }
    sb <+ "\""
    for x in 0..<qr.size() {
      sb.write_string(if qr.get(y, x) { "1" } else { "0" })
    }
    sb <+ "\""
  }
  sb <+ "]}"
  sb.to_string()
}

///|
fn render(qr : @lib.QrCode, options : Options) -> String {
  let format = inferred_format(options)
  match format {
    "json" => render_json(qr)
    "svg" =>
      try
        @lib.to_svg(
          qr,
          quiet_zone=options.quiet_zone,
          module_size=options.module_size,
          dark=options.dark,
          light=options.light,
        )
      catch {
        e => die(e.message())
      } noraise {
        text => text
      }
    "half" => @lib.to_ascii_half(qr, quiet_zone=options.quiet_zone)
    _ => @lib.to_ascii(qr, quiet_zone=options.quiet_zone, scale=options.scale)
  }
}

///|
fn write_output(path : String, text : String) -> Unit {
  try @fs.write_string_to_file(path, text) catch {
    _ => die("failed to write output file '\{path}'")
  } noraise {
    _ => ()
  }
}

///|
fn main {
  let argv = @env.args()
  let options = try parse_args(argv) catch {
    e => die(e.message())
  } noraise {
    options => options
  }
  let qr = encode_qr(options)
  let text = render(qr, options)
  match options.output {
    Some(path) => write_output(path, text)
    None => println(text.trim(chars="\n"))
  }
}
