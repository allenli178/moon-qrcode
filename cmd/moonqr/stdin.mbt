///|
fn read_stdin_text() -> String raise CliError {
  let raw = read_stdin_bytes()
  let text = try @utf8.decode(raw) catch {
    _ => raise CliError::Usage("stdin is not valid UTF-8")
  } noraise {
    text => text
  }
  text.trim_end(chars="\r\n").to_owned()
}
