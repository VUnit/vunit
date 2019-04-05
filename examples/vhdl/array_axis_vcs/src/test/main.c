#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

extern int ghdl_main (int argc, char **argv);

uint8_t *V[2];
uint32_t length = 100;

// get_param is used by GHDL to retrieve parameter values (integers).
uint32_t get_param(uint32_t w) {
  uint32_t o = 0;
  switch(w) {
    case 0 : // buffer length
      o = length;
      break;;
    case 1 : // data width (in bits)
      o = 8*sizeof(int32_t);
      break;;
    case 2 : // fifo depth
      o = 5;
      break;;
  }
  printf("get_p(%d): %d\n", w, (int)o);
  return o;
}

void write_byte ( uint8_t id, uint32_t i, uint8_t v ) {
   V[id][i] = v;
}

uint8_t read_byte ( uint8_t id, uint32_t i ) {
  return V[id][i];
}

// check evaluates if the result produced by the UUT is equivalent to some other softwre procedure.
int check(int32_t *I, int32_t *O, uint32_t l) {
  int i;
  for ( i=0 ; i<l ; i++ ) {
    if ( I[i] != O[i] ) {
      printf("check failed! %d: %d %d\n", i, I[i], O[i]);
      return -1;
    }
  }
  printf("check successful\n");
  return 0;
}

// main is the entrypoint to the application.
int main(int argc, char **argv) {

  // Optionally, some of the CLI arguments can be processed by the software app and others forwarded to GHDL.
  int gargc = argc;
  char **gargv = argv;

  // Allocate the memory buffers that are to be shared between the software and the simulation.
  int i;
  for (i=0 ; i<2 ; i++) {
    V[i] = (uint8_t *) malloc(length*sizeof(uint32_t));
    if ( V[i] == NULL ) {
      perror("execution of malloc() failed!\n");
      return -1;
    }
  }

  // Initialize one of the buffers with random data.
  for (i=0 ; i<length ; i++) {
    ((int32_t*)V[0])[i] = i*100+rand()/(RAND_MAX/100);
    printf("V[%d]: %d\n", i, ((int32_t*)V[0])[i]);
  }

  // Execute the simulation to let the UUT copy the data from one buffer to another.
  ghdl_main(gargc, gargv);

  // Check that the UUT did what it was expected to do.
  printf("> Call 'check'\n");
  if ( check((int32_t*)V[0], (int32_t*)V[1], length) != 0 ) {
    printf("check failed!\n");
    return -1;
  }

  // Free the allocated memory, since we don't need it anymore.
  free(V[0]);
  free(V[1]);

  return 0;
}
