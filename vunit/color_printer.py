# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Provides capability to print in color to the terminal in both Windows and Linux.
"""

import sys
import ctypes
from ctypes import Structure, c_short, c_ushort, byref
from vunit.ostools import IS_WINDOWS_SYSTEM


class LinuxColorPrinter(object):
    """
    Print in color on linux
    """

    BLUE = 'b'
    GREEN = 'g'
    RED = 'r'
    INTENSITY = 'i'
    WHITE = RED + GREEN + BLUE

    def __init__(self):
        pass

    def write(self, text, output_file=None, fg=None, bg=None):
        """
        Print the text in color to the output_file
        uses stdout if output_file is None
        """
        if output_file is None:
            output_file = sys.stdout

        text = self._ansi_wrap(text, fg, bg)
        output_file.write(text)

    @staticmethod
    def _to_code(rgb):
        """
        Translate strings containing 'rgb' characters to numerical color codes
        """
        code = 0
        if 'r' in rgb:
            code += 1

        if 'g' in rgb:
            code += 2

        if 'b' in rgb:
            code += 4
        return code

    def _ansi_wrap(self, text, fg, bg):
        """
        Wrap the text into ANSI color escape codes
        fg -- the foreground color
        bg -- the background color
        """
        codes = []

        if fg is not None:
            codes.append(30 + self._to_code(fg))

        if bg is not None:
            codes.append(40 + self._to_code(bg))

        if fg is not None and 'i' in fg:
            codes.append(1)  # Bold

        if bg is not None and 'i' in bg:
            codes.append(4)  # Underscore

        return "\033[" + ";".join([str(code) for code in codes]) + "m" + text + "\033[0m"


class Coord(Structure):
    """struct in wincon.h."""
    _fields_ = [
        ("X", c_short),
        ("Y", c_short)]


class SmallRect(Structure):
    """struct in wincon.h."""
    _fields_ = [
        ("Left", c_short),
        ("Top", c_short),
        ("Right", c_short),
        ("Bottom", c_short)]


class ConsoleScreenBufferInfo(Structure):
    """struct in wincon.h."""
    _fields_ = [
        ("dwSize", Coord),
        ("dwCursorPosition", Coord),
        ("wAttributes", c_ushort),
        ("srWindow", SmallRect),
        ("dwMaximumWindowSize", Coord)]


class Win32ColorPrinter(LinuxColorPrinter):
    """
    Prints in color on windows
    """
    def __init__(self):
        LinuxColorPrinter.__init__(self)
        self._stdout_handle = ctypes.windll.kernel32.GetStdHandle(-11)
        self._stderr_handle = ctypes.windll.kernel32.GetStdHandle(-12)
        self._default_attr = self._get_text_attr(self._stdout_handle)

        self._color_to_code = {self.RED: 4,
                               self.GREEN: 2,
                               self.BLUE: 1,
                               self.INTENSITY: 8}

    def write(self, text, output_file=None, fg=None, bg=None):
        """
        Print the text in color to the output_file
        uses stdout if output_file is None
        """
        if output_file is None:
            output_file = sys.stdout

        if output_file is sys.stdout:
            handle = self._stdout_handle
        elif output_file is sys.stderr:
            handle = self._stderr_handle
        else:
            handle = None

        if handle is not None:
            output_file.flush()
            attr = self._default_attr
            if fg is not None:
                attr &= 0xf0
                attr |= self._decode_color(fg)
            if bg is not None:
                attr &= 0x0f
                attr |= self._decode_color(bg) * 16
            self._set_text_attr(handle, attr)

        output_file.write(text)

        if handle is not None:
            output_file.flush()
            ctypes.windll.kernel32.SetConsoleTextAttribute(handle, self._default_attr)

    @staticmethod
    def _get_text_attr(handle):
        """
        Get current text attribute using win-api
        """
        csbi = ConsoleScreenBufferInfo()
        ctypes.windll.kernel32.GetConsoleScreenBufferInfo(handle, byref(csbi))
        return csbi.wAttributes

    @staticmethod
    def _set_text_attr(handle, attr):
        """
        Set current text attribute using win-api
        """
        ctypes.windll.kernel32.SetConsoleTextAttribute(handle, attr)

    def _decode_color(self, color_str):
        """
        Decode color string into numerical color code
        """
        code = 0
        for char in color_str:
            code |= self._color_to_code.get(char, 0)
        return code


class NoColorPrinter(object):
    """
    Dummy printer that does not print in color
    """
    def __init__(self):
        pass

    @staticmethod
    def write(text, output_file=None, fg=None, bg=None):  # pylint: disable=unused-argument
        """
        Print the text in color to the output_file
        uses stdout if output_file is None
        """
        if output_file is None:
            output_file = sys.stdout
        output_file.write(text)


NO_COLOR_PRINTER = NoColorPrinter()
if IS_WINDOWS_SYSTEM:
    COLOR_PRINTER = Win32ColorPrinter()
else:
    COLOR_PRINTER = LinuxColorPrinter()
