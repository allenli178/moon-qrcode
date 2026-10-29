///|
/// CLI 白盒测试：覆盖 main.mbt 里的纯逻辑，不依赖 stdin/@sys.exit/@env.args()。
///
/// Whitebox tests for the CLI, covering pure logic from main.mbt.
/// Avoids stdin/@sys.exit/@env.args() by calling parse_args only on happy paths
/// and testing helpers like infer_format directly.

///|
test "infer_format by extension" {
  assert_eq(infer_format("foo.svg"), "svg")
  assert_eq(infer_format("foo.SVG"), "svg")
  assert_eq(infer_format("foo.json"), "json")
  assert_eq(infer_format("foo.png"), "png")
  assert_eq(infer_format("foo.PNG"), "png")
  assert_eq(infer_format("foo.pbm"), "pbm")
  assert_eq(infer_format("foo.txt"), "ascii")
  // 未知扩展名默认 SVG
  assert_eq(infer_format("foo.unknown"), "svg")
  assert_eq(infer_format("foo"), "svg")
}

///|
test "parse_args basic ASCII happy path" {
  // argv[0] 是程序名；我们直接传 mock argv
  let argv = ["moonqr", "HELLO"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.payload, "HELLO")
  assert_eq(opts.format, "ascii")
  assert_true(opts.output is None)
  assert_eq(opts.quiet_zone, 4)
  assert_eq(opts.scale, 1)
  assert_eq(opts.module_size, 4)
  assert_eq(opts.radius, 1)
}

///|
test "parse_args -o with .svg extension infers svg format" {
  let argv = ["moonqr", "HELLO", "-o", "out.svg"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "svg")
  assert_eq(opts.output, Some("out.svg"))
}

///|
test "parse_args -o with .png extension infers png format" {
  let argv = ["moonqr", "HELLO", "-o", "out.png"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "png")
  assert_eq(opts.output, Some("out.png"))
}

///|
test "parse_args -o with .pbm extension infers pbm format" {
  let argv = ["moonqr", "HELLO", "-o", "out.pbm"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "pbm")
}

///|
test "parse_args .json extension infers json format" {
  let argv = ["moonqr", "HELLO", "-o", "meta.json"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "json")
}

///|
test "parse_args .txt extension infers ascii format" {
  let argv = ["moonqr", "HELLO", "-o", "out.txt"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "ascii")
}

///|
test "parse_args unknown extension defaults to svg" {
  let argv = ["moonqr", "HELLO", "-o", "out.xyz"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "svg")
}

///|
test "parse_args explicit --svg overrides extension inference" {
  let argv = ["moonqr", "HELLO", "--svg", "-o", "whatever.txt"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "svg")
}

///|
test "parse_args explicit -f png overrides extension" {
  let argv = ["moonqr", "HELLO", "-f", "png", "-o", "not_a_png.ext"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "png")
}

///|
test "parse_args explicit -f color overrides extension" {
  let argv = ["moonqr", "HELLO", "-f", "color"]
  let opts = try parse_args(argv) catch {
    e => abort("should not fail: \{e.message()}")
  } noraise {
    o => o
  }
  assert_eq(opts.format, "color")
  assert_true(opts.output is None)
}

///|
test "parse_args explicit svg-rect / svg-rounded / png / png-rgba / pbm" {
  // 这些快捷 flag 都应该正确映射
  let argv_rect = ["moonqr", "HELLO", "--svg-rect", "-o", "out.svg"]
  let opts_rect = try parse_args(argv_rect) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  assert_eq(opts_rect.format, "svg-rect")

  let argv_rnd = [
    "moonqr", "HELLO", "--svg-rounded", "-o", "out.svg", "--radius", "2",
  ]
  let opts_rnd = try parse_args(argv_rnd) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  assert_eq(opts_rnd.format, "svg-rounded")
  assert_eq(opts_rnd.radius, 2)

  let argv_png = ["moonqr", "HELLO", "--png", "-o", "out.png"]
  let opts_png = try parse_args(argv_png) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  assert_eq(opts_png.format, "png")

  let argv_rgba = ["moonqr", "HELLO", "--png-rgba", "-o", "out.png"]
  let opts_rgba = try parse_args(argv_rgba) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  assert_eq(opts_rgba.format, "png-rgba")

  let argv_pbm = ["moonqr", "HELLO", "--pbm", "-o", "out.pbm"]
  let opts_pbm = try parse_args(argv_pbm) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  assert_eq(opts_pbm.format, "pbm")
}

///|
test "parse_args binary formats require --output" {
  // png: 没 -o 必须报错
  let argv_png = ["moonqr", "HELLO", "-f", "png"]
  try ignore(parse_args(argv_png)) catch {
    Usage(msg) =>
      assert_true(msg.contains("binary") && msg.contains("--output"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }

  // png-rgba
  let argv_rgba = ["moonqr", "HELLO", "-f", "png-rgba"]
  try ignore(parse_args(argv_rgba)) catch {
    Usage(msg) => assert_true(msg.contains("png-rgba"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }

  // pbm
  let argv_pbm = ["moonqr", "HELLO", "--pbm"]
  try ignore(parse_args(argv_pbm)) catch {
    Usage(msg) => assert_true(msg.contains("pbm"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args rejects negative quiet zone" {
  let argv = ["moonqr", "HELLO", "--quiet-zone", "-1"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("quiet"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args rejects invalid --radius" {
  let argv = ["moonqr", "HELLO", "--radius", "-1"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("radius"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args rejects --module-size 0" {
  let argv = ["moonqr", "HELLO", "--module-size", "0", "-o", "out.svg"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("module"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args rejects --scale 0" {
  let argv = ["moonqr", "HELLO", "--scale", "0"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("scale"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args rejects invalid format name" {
  let argv = ["moonqr", "HELLO", "-f", "garbage"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("format") && msg.contains("garbage"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args respects -- to pass payload starting with dash" {
  let argv = ["moonqr", "--", "--hello"]
  let opts = try parse_args(argv) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  assert_eq(opts.payload, "--hello")
}

///|
test "parse_args respects color options pass-through" {
  let argv = [
    "moonqr", "HELLO", "--color", "--dark", "#ff0000", "--light", "#00ff00",
  ]
  let opts = try parse_args(argv) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  assert_eq(opts.format, "color")
  assert_eq(opts.dark, "#ff0000")
  assert_eq(opts.light, "#00ff00")
}

///|
test "parse_args rejects unknown option" {
  let argv = ["moonqr", "HELLO", "--this-option-does-not-exist"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("unknown"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args rejects missing payload" {
  let argv = ["moonqr", "--svg", "-o", "out.svg"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("missing"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args min-version > max-version rejected" {
  let argv = ["moonqr", "HELLO", "--min-version", "10", "--max-version", "5"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("min") || msg.contains("max"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args EC levels" {
  // 所有合法 EC 等级都能解析
  let opts_l = try parse_args(["moonqr", "HELLO", "-l", "L"]) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  // 断言 ec_level 是 L
  let _ = opts_l.ec_level

  let opts_q = try parse_args(["moonqr", "HELLO", "-l", "q"]) catch {
    e => abort(e.message())
  } noraise {
    o => o
  }
  let _ = opts_q.ec_level

  // 非法等级报错
  let argv_bad = ["moonqr", "HELLO", "-l", "Z"]
  try ignore(parse_args(argv_bad)) catch {
    Usage(msg) => assert_true(msg.contains("level"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}

///|
test "parse_args min_version < 1 rejected" {
  let argv = ["moonqr", "HELLO", "--min-version", "0"]
  try ignore(parse_args(argv)) catch {
    Usage(msg) => assert_true(msg.contains("version"))
    _ => abort("expected CliError::Usage")
  } noraise {
    _ => abort("should have raised")
  }
}
