#include <stdint.h>

extern int ghdl_main (int argc, char **argv);

uint8_t *D[256];

//---

// External string/byte_vector through access (mode = extacc)

void set_string_ptr(uint8_t id, uintptr_t p) {
  D[id] = (uint8_t*)p;
}

uintptr_t get_string_ptr(uint8_t id) {
  return (uintptr_t)D[id];
}

// External string/byte_vector through functions (mode = extfnc)

void write_char(uint8_t id, uint32_t i, uint8_t v) {
  ((uint8_t*)D[id])[i] = v;
}

uint8_t read_char(uint8_t id, uint32_t i) {
  return ((uint8_t*)D[id])[i];
}

//---

// External integer_vector through access (mode = extacc)

void set_intvec_ptr(uint8_t id, uintptr_t p) {
  D[id] = (uint8_t*)p;
}

uintptr_t get_intvec_ptr(uint8_t id) {
  return (uintptr_t)D[id];
}

// External integer_vector through functions (mode = extfnc)

void write_integer(uint8_t id, uint32_t i, int32_t v) {
  ((int32_t*)D[id])[i] = v;
}

int32_t read_integer(uint8_t id, uint32_t i) {
  return ((int32_t*)D[id])[i];
}
