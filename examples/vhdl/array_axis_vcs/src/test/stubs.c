#include <stdio.h>

extern int ghdl_main (int argc, char **argv);

// main is the entrypoint to the application.
int main(int argc, char **argv) {

  printf("This is an example of how to wrap a GHDL + VUnit simulation in a C application.\n");

  ghdl_main(argc, argv);

  return 0;
}