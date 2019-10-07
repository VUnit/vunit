/*
External Buffer

Interfacing with foreign languages (C) through VHPIDIRECT:
https://ghdl.readthedocs.io/en/latest/using/Foreign.html

Two arrays of type uint8_t are allocated and some values are written to the first.
Then, the VHDL simulation is executed, where the (external) array/buffer
is used. When the simulation is finished, the results are checked. The content of
the buffer is printed both before and after the simulation.

NOTE: This file is expected to be used along with tb_extcp_byte_vector.vhd or tb_extcp_string.vhd
*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

extern int ghdl_main (int argc, char **argv);

uint8_t *D[1];
const uint32_t length = 10;

// Check procedure, to be executed when GHDL exits.
// The simulation is expected to copy the first 1/3 elements to positions [1/3, 2/3),
// while incrementing each value by one, and then copy elements from [1/3, 2/3) to
// [2/3, 3/3), while incrementing each value by two.
static void exit_handler(void) {
  int i, j, z, k;
  uint8_t expected, got;
  k = 0;

  for(i=0; i<length; i++) {
    expected = D[0][i];
    got = D[1][i];
    if (expected != got) {
      printf("check error %d: %d %d\n", i, expected, got);
      exit(1);
    }
    printf("%d: %d\n", i, got);
  }

  free(D[0]);
  free(D[1]);
}

// Main entrypoint of the application
int main(int argc, char **argv) {
  // Allocate two buffers
  int i;
  for(i=0; i<2; i++) {
    D[i] = (uint8_t *) malloc(length*sizeof(uint8_t));
    if ( D[i] == NULL ) {
      perror("execution of malloc() failed!\n");
      return -1;
    }
  }
  // Initialize the first buffer
  for(i=0; i<length; i++) {
    D[0][i] = (i+1)*11;
  }
  // Print all the buffer
  for(i=0; i<length; i++) {
    printf("%d: %d\n", i, D[0][i]);
  }

  // Register a function to be called when GHDL exits
  atexit(exit_handler);

  // Start the simulation
  return ghdl_main(argc, argv);
}

// External through access (mode = extacc)

void set_string_ptr(uint8_t id, uint8_t *p) {
  //printf("C set_string_ptr(%d, %p)\n", id, p);
  D[id] = p;
}

uintptr_t get_string_ptr(uint8_t id) {
  //printf("C get_string_ptr(%d): %p\n", id, D[id]);
  return (uintptr_t)D[id];
}

// External through functions (mode = extfnc)

void write_char(uint8_t id, uint32_t i, uint8_t v ) {
  //printf("C write_char(%d, %d): %d\n", id, i, v);
  D[id][i] = v;
}

uint8_t read_char(uint8_t id, uint32_t i) {
  //printf("C read_char(%d, %d): %d\n", id, i, D[id][i]);
  return D[id][i];
}
