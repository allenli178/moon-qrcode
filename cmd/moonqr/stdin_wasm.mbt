///|
fn read_stdin_bytes() -> Bytes raise CliError {
  raise CliError::Usage("reading payload from stdin requires a native build")
}
