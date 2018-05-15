import sys

with open(sys.argv[1], "r", buffering=1) as fptr:
    i = 0
    for line in fptr:
        assert int(line) == 11*i
        i += 1
