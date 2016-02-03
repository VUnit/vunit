from sys import stdout

if hasattr(stdout, "buffer"):
   # Python 3
   stdout.buffer.write(b"\x87")
else:
   # Python 2.7
   stdout.write(b"\x87")

stdout.write("\n")
