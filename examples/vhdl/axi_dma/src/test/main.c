#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "vhpidirect_user.h"

static void exit_handler(void) {
  atexit(exit_handler);
  free(D[0]);
}

int main(int argc, char **argv) {
  D[0] = (uint8_t *) malloc(2097152 * sizeof(uint8_t));
  if ( D[0] == NULL ) {
    perror("execution of malloc() failed!\n");
    return -1;
  }
  return ghdl_main(argc, argv);
}
