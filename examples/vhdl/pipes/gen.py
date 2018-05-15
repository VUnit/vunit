import sys

with open(sys.argv[1], "w", buffering=1) as fptr:
    for i in range(10000):
        fptr.write("%i\n" % i)
