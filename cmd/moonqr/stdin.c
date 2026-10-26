#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

#include "moonbit.h"

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonqr_read_stdin(void) {
#ifdef _WIN32
  _setmode(_fileno(stdin), _O_BINARY);
#endif
  size_t capacity = 8192;
  size_t length = 0;
  unsigned char *buffer = (unsigned char *)malloc(capacity);
  if (buffer == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  for (;;) {
    if (length == capacity) {
      size_t grown_capacity = capacity * 2;
      unsigned char *grown =
          (unsigned char *)realloc(buffer, grown_capacity);
      if (grown == NULL) {
        free(buffer);
        return moonbit_make_bytes(0, 0);
      }
      buffer = grown;
      capacity = grown_capacity;
    }
    size_t read = fread(buffer + length, 1, capacity - length, stdin);
    length += read;
    if (read == 0) {
      if (ferror(stdin)) {
        free(buffer);
        return moonbit_make_bytes(0, 0);
      }
      break;
    }
  }
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)length, 0);
  if (length > 0) {
    memcpy(result, buffer, length);
  }
  free(buffer);
  return result;
}
