# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

import sys
import ctypes
from ctypes import Structure, c_short, c_ushort, byref

class LinuxColorPrinter:
    """
    Print in color on linux
    """

    BLUE = 'b'
    GREEN= 'g'
    RED  = 'r'
    INTENSITY = 'i'
    WHITE = RED + GREEN + BLUE

    def write(self, text, output_file=None, fg=None, bg=None):
        """
        Print the text in color
        """
        if output_file is None:
            output_file = sys.stdout

        text = self._ansi_wrap(text, fg, bg)
        output_file.write(text)

    def _to_code(self, rgb):
        code = 0
        if 'r' in rgb:
            code += 1

        if 'g' in rgb:
            code += 2

        if 'b' in rgb:
            code += 4
        return code

    def _ansi_wrap(self, text, fg, bg):
        codes = []

        if not fg is None:
            codes.append(30 + self._to_code(fg))

        if not bg is None:
            codes.append(40 + self._to_code(bg))

        if not fg is None and 'i' in fg:
            codes.append(1) # Bold

        if not bg is None and 'i' in bg:
            codes.append(4) # Underscore

        return "\033[" + ";".join(map(str, codes)) + "m" + text + "\033[0m"

SHORT = c_short
WORD = c_ushort

class COORD(Structure):
  """struct in wincon.h."""
  _fields_ = [
    ("X", SHORT),
    ("Y", SHORT)]

class SMALL_RECT(Structure):
  """struct in wincon.h."""
  _fields_ = [
    ("Left", SHORT),
    ("Top", SHORT),
    ("Right", SHORT),
    ("Bottom", SHORT)]

class CONSOLE_SCREEN_BUFFER_INFO(Structure):
  """struct in wincon.h."""
  _fields_ = [
    ("dwSize", COORD),
    ("dwCursorPosition", COORD),
    ("wAttributes", WORD),
    ("srWindow", SMALL_RECT),
    ("dwMaximumWindowSize", COORD)]

class Win32ColorPrinter(LinuxColorPrinter):
    """
    Prints in color on windows
    """


    def __init__(self):
        self._stdout_handle = ctypes.windll.kernel32.GetStdHandle(-11)
        self._stderr_handle = ctypes.windll.kernel32.GetStdHandle(-12)

        self._color_to_code = {self.RED : 4,
                               self.GREEN : 2,
                               self.BLUE : 1,
                               self.INTENSITY : 8}

    def write(self, text, output_file=None, fg=None, bg=None):
        """
        Print the text in color
        """
        if output_file is None:
            output_file = sys.stdout

        if output_file is sys.stdout:
            handle = self._stdout_handle
        elif output_file is sys.stdout:
            handle = self._stderr_handle
        else:
            handle = None


        if handle is not None:
            output_file.flush()
            old_attr = self._get_text_attr(handle)
            attr = old_attr
            if not fg is None:
                attr &= 0xf0;
                attr |= self._decode_color(fg)
            if not bg is None:
                attr &= 0x0f;
                attr |= self._decode_color(bg)*16
            self._set_text_attr(handle, attr)

        output_file.write(text)

        if handle is not None:
            output_file.flush()
            ctypes.windll.kernel32.SetConsoleTextAttribute(handle, old_attr)

    def _get_text_attr(self, handle):
        csbi = CONSOLE_SCREEN_BUFFER_INFO()
        ctypes.windll.kernel32.GetConsoleScreenBufferInfo(handle, byref(csbi))
        return csbi.wAttributes

    def _set_text_attr(self, handle, attr):
        ctypes.windll.kernel32.SetConsoleTextAttribute(handle, attr)

    def _decode_color(self, color_str):
        """
        Decode color string into bit vector
        """
        code = 0
        for char in color_str:
            code |= self._color_to_code.get(char, 0)
        return code

class NoColorPrinter_:
    def write(self, text, output_file=None, fg=None, bg=None):
        if output_file is None:
            output_file = sys.stdout
        output_file.write(text)

NoColorPrinter = NoColorPrinter_()
if "win" in sys.platform:
    ColorPrinter = Win32ColorPrinter()
else:
    ColorPrinter = LinuxColorPrinter()
