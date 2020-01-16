When VHDL 1993 is used, the simulation is terminated with an `abort`, which prevents the user from running post-checks.
These are some snippets to test it. See https://github.com/VUnit/vunit/pull/469#issuecomment-485723516.

``` python
https://bugs.python.org/issue12423
def handler(signum, frame):
    print('Signal handler called with signal', signum)
import signal
signal.signal(signal.SIGABRT, handler)
import os
os.abort()
```

``` c
#include <signal.h>

void sigabrtHandler(int sig_num)
{
    // Reset handler to catch SIGINT next time. Refer http://en.cppreference.com/w/c/program/signal
    signal(SIGABRT, sigabrtHandler);
    printf("\nSIGABRT caught!\n");
    fflush(stdout);
}

signal(SIGABRT, sigabrtHandler);
```