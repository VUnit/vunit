# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Support functions for creating blogs
"""

import re
from pathlib import Path
from pygments import highlight
from pygments.lexers.hdl import VhdlLexer
from pygments.lexers.python import PythonLexer
from pygments.filters import NameHighlightFilter
from pygments.formatters.html import HtmlFormatter
from pygments.token import Name, Keyword, Generic


def left_justify(code):
    """Remove common indentation to the left."""
    lines = code.split("\n")
    leading_whitespaces = [len(line) - len(line.lstrip()) for line in lines if len(line.lstrip()) > 0]
    n_spaces_to_remove = min(leading_whitespaces)

    return "\n".join([line[n_spaces_to_remove:] for line in lines])


def remove_nested_snippets(code):
    """Remove snippet start and end markers within another snippet."""
    return "\n".join(
        [line for line in code.split("\n") if ("start_snippet" not in line) and ("end_snippet" not in line)]
    )


def fold(code, comment_prefix):
    """Fold snippets mark for folding."""
    start_re = re.compile(
        rf"^\s*(?P<comment_prefix_start>{comment_prefix})\s*start_folding(?P<folding_comment>.*?)$",
        re.IGNORECASE | re.MULTILINE,
    )
    starts = list(start_re.finditer(code))
    starts.sort(key=lambda start: start.start(), reverse=True)

    for start in starts:
        folding_comment = start.group("folding_comment")
        if folding_comment:
            folding_comment = folding_comment.strip()
            end_re = re.compile(
                rf"^\s*{comment_prefix}\s*end_folding\s+{folding_comment}$", re.IGNORECASE | re.MULTILINE
            )
        else:
            folding_comment = ""
            end_re = re.compile(rf"^\s*{comment_prefix}\s*end_folding$", re.IGNORECASE | re.MULTILINE)
        end = end_re.search(code, start.start())
        if not end:
            raise RuntimeError(f"Filed to find end of folded section {folding_comment}")

        code = code[: start.start("comment_prefix_start")] + folding_comment + code[end.end() :]

    return code


def highlight_code(
    code_path,
    output_path,
    snippet_name=None,
    *,
    line_no_offset=None,
    functions=None,
    types=None,
    highlights=None,
    language="vhdl",
):  # pylint: disable=too-many-arguments
    """Create HTML with syntax highlighted code."""
    if language.lower() not in ["vhdl", "python"]:
        raise RuntimeError(f"{language} not supported")

    code = code_path.read_text()

    if snippet_name:
        comment_prefix = "--" if language.lower() == "vhdl" else "#"
        start_re = re.compile(
            rf"^\s*{comment_prefix}\s*start_snippet\s+{snippet_name}\s*$", re.IGNORECASE | re.MULTILINE
        )
        start = start_re.search(code)
        if not start:
            raise RuntimeError(f"Failed to find start of snippet {snippet_name} in {code_path}")

        end_re = re.compile(rf"^\s*{comment_prefix}\s*end_snippet\s+{snippet_name}\s*$", re.IGNORECASE | re.MULTILINE)
        end = end_re.search(code)
        if not end:
            raise RuntimeError(f"Failed to find end of snippet {snippet_name} in {code_path}")

        code = code[start.end() + 1 : end.start()]
        code = fold(code, comment_prefix)
        code = left_justify(code)
        code = remove_nested_snippets(code)

    lexer = VhdlLexer() if language.lower() == "vhdl" else PythonLexer()

    if functions:
        lexer.add_filter(NameHighlightFilter(names=functions, tokentype=Name.Function))

    if types:
        lexer.add_filter(NameHighlightFilter(names=types, tokentype=Keyword.Type))

    if highlights:
        lexer.add_filter(NameHighlightFilter(names=highlights, tokentype=Generic.Error))

    if not output_path.parent.exists():
        output_path.parent.mkdir(parents=True, exist_ok=True)

    output_path.write_text(
        highlight(
            code,
            lexer,
            HtmlFormatter(
                linenos=line_no_offset is not None,
                linenostart=1 if line_no_offset is None else line_no_offset,
            ),
        )
    )


_CONEMU_COLORS = {
    30: "#002b36",
    31: "#cb4b16",
    32: "#008000",
    33: "#859900",
    34: "#073642",
    35: "#9c36b6",
    36: "#3182a4",
    37: "#eee8d5",
    39: "",
    90: "#93a1a1",
    91: "#dc322f",
    92: "#4fb636",
    93: "#b58900",
    94: "#268bd2",
    95: "#d33682",
    96: "#2aa198",
    97: "#fdf6e3",
}

_CONEMU_BACKGROUNDS = {
    40: "#002b36",
    41: "#cb4b16",
    42: "#008080",
    43: "#859900",
    44: "#073642",
    45: "#9c36b6",
    46: "#3182a4",
    47: "#eee8d5",
    49: "",
    100: "#93a1a1",
    101: "#dc322f",
    102: "#4fb636",
    103: "#b58900",
    104: "#268bd2",
    105: "#d33682",
    106: "#2aa198",
    107: "#fdf6e3",
}


def create_span(style, fg, bg):
    """Create HTML span with color and style."""
    font_weights = {1: "bold", 2: "lighter", 22: ""}

    font_weight = font_weights.get(style, None)
    if font_weight is None:
        style, fg = fg, style

    if fg:
        color = _CONEMU_COLORS.get(fg, None)
        if color is None:
            raise RuntimeError(f"Unknown foreground color {fg}")
    else:
        color = None

    if bg:
        background = _CONEMU_BACKGROUNDS.get(bg, None)
        if background is None:
            raise RuntimeError(f"Unknown background color {bg}")
    else:
        background = None

    span = "<span>"
    if font_weight or color or background:
        span = '<span style="'

        if font_weight:
            span += f"font_weight: {font_weight}; "

        if color:
            span += f"color: {color}; "

        if background:
            span += f"background: {background}; "

        span += '">'

    return span


def highlight_log(log_path, output_path):
    """Create HTML from VUnit text log with color codes."""

    ansi_esc_re = re.compile(r"\x1B\[", re.MULTILINE)
    color_start_re = re.compile(r"(?P<style>\d+)?(;(?P<fg>\d+))?(;(?P<bg>\d+))?m", re.MULTILINE)
    html = f'<div class="highlight" style="background: {_CONEMU_BACKGROUNDS[40]}; color: {_CONEMU_COLORS[37]};">'
    html += f'<pre style="line-height: 125%; background: {_CONEMU_BACKGROUNDS[40]}; color: {_CONEMU_COLORS[37]};">'

    log = log_path.read_text()
    log = left_justify(log)
    while True:
        ansi_esc = ansi_esc_re.search(log)
        if not ansi_esc:
            html += log
            break

        start_pos = ansi_esc.start()
        if start_pos > 0:
            html += log[:start_pos]
        log = log[ansi_esc.end() :]

        color_start = color_start_re.match(log)
        if not color_start:
            raise RuntimeError(f"Expected color start code in {log}")

        log = log[color_start.end() :]
        if color_start.group("style"):
            span = create_span(
                int(color_start.group("style")),
                int(color_start.group("fg")) if color_start.group("fg") is not None else None,
                int(color_start.group("bg")) if color_start.group("bg") is not None else None,
            )
        else:
            span = None

        color_end = ansi_esc_re.search(log)
        if not color_end:
            raise RuntimeError("No matching end of ANSI color code")

        if span:
            html += span + log[: color_end.start()] + "</span>"
        else:
            html += log[: color_end.start()]

        if log[color_end.end() : color_end.end() + 2] == "0m":
            log = log[color_end.end() + 2 :]
        else:  # Ended by a back-to-back color code
            log = log[color_end.start() :]

    html += "</pre></div>\n"

    output_path.write_text(html)


class LogRegistry:
    """Registry log paths from which html documents shall be generated."""

    def __init__(self):
        self._paths = {}

    def register(self, log_path, html_path):
        self._paths[log_path] = html_path

    def generate_logs(self):
        for log_path, html_path in self._paths.items():
            highlight_log(Path(log_path), Path(html_path))
