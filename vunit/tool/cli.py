# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""Standalone VUnit command-line interface."""

import argparse
import sys

from prompt_toolkit import PromptSession
from prompt_toolkit.application import get_app
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.key_binding import KeyBindings

from . import create_project, create_testbench, version
from .cli_helpers import (
    _PathCompleter,
    _add_path_completion_binding,
    _ask,
    _clean_answer,
    _interactive_terminal,
    _prompt,
    _prompt_with_controls,
    PreviewOptions,
)

COMMANDS = ("create-project", "create-testbench", "version")


class _ProjectSourceOption(argparse.Action):
    """Record source locations in command-line order with their recursion mode."""

    def __call__(self, parser, namespace, values, option_string=None):
        sources = getattr(namespace, self.dest) or []
        sources.append((values[0], values[1], option_string == "--recursive-source"))
        setattr(namespace, self.dest, sources)


def _choose_command():
    session = PromptSession(completer=WordCompleter(COMMANDS), complete_while_typing=True)
    return session.prompt(_prompt("Command"), pre_run=_show_commands)


def _show_commands():
    get_app().current_buffer.start_completion()


def _ask_testbench_path(prompt):
    """Prompt for a testbench path with completion when available."""
    if not _interactive_terminal():
        return _ask(prompt)
    controls = "Controls: Tab complete"
    bindings = KeyBindings()
    _add_path_completion_binding(bindings)
    session = PromptSession(
        completer=_PathCompleter(expanduser=True),
        complete_while_typing=False,
        bottom_toolbar=controls,
        key_bindings=bindings,
    )
    return _clean_answer(session.prompt(lambda: _prompt_with_controls(prompt, controls)))


def _review_testbench(source, testbench, library, preview=None, tests=None):
    return create_testbench.review(source, testbench, library, preview, tests)


def _add_preview_options(parser):
    parser.add_argument("--preview", action="store_true", help="Show what would be generated without writing files")
    parser.add_argument("--json", action="store_true", help="With --preview, print the plan as JSON (never prompts)")
    parser.add_argument("--show-content", action="store_true", help="With --preview, include the generated content")


def _preview_options(parser, args, complete):
    """Validate the preview flags and return PreviewOptions, or None when not previewing."""
    if (args.json or args.show_content) and not args.preview:
        parser.error("--json and --show-content require --preview")
    if args.json and not complete:
        parser.error("--json never prompts; supply all required options")
    return PreviewOptions(args.json, args.show_content) if args.preview else None


def main(argv=None):
    """Select and run a VUnit command."""
    parser = argparse.ArgumentParser(prog="vunit", description="Standalone VUnit command-line tool")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("version", help="Print the installed VUnit version")
    project = commands.add_parser("create-project", help="Create a VUnit run.py project")
    project.add_argument("--root", metavar="DIR", help="Project root directory (default: current directory)")
    project.add_argument(
        "--library", metavar="NAME", action="append", help="VUnit library name; may be repeated (default: lib)"
    )
    project.add_argument(
        "--source",
        dest="sources",
        action=_ProjectSourceOption,
        nargs=2,
        metavar=("LIBRARY", "PATH"),
        help="Add a file or non-recursive directory to a library; may be repeated",
    )
    project.add_argument(
        "--recursive-source",
        dest="sources",
        action=_ProjectSourceOption,
        nargs=2,
        metavar=("LIBRARY", "DIR"),
        help="Add a recursive source directory to a library; may be repeated",
    )
    project.add_argument("--no-sources", action="store_true", help="Create the project without any source paths")
    _add_preview_options(project)
    testbench = commands.add_parser("create-testbench", help="Create a VHDL testbench for an entity")
    testbench.add_argument("--source", metavar="FILE", help="VHDL source file containing one entity")
    testbench.add_argument("--testbench", metavar="FILE", help="Path to the new VHDL testbench")
    testbench.add_argument("--library", metavar="NAME", help="Library containing the source entity (default: work)")
    testbench.add_argument(
        "--tests",
        metavar="NAME",
        nargs="+",
        help="Test names, quote names containing spaces (default: a single first_test), "
        'e.g. --tests "reset behavior" "write and read". Tests are marked .todo and fail until implemented',
    )
    _add_preview_options(testbench)

    try:
        arguments = list(sys.argv[1:] if argv is None else argv)
        if not arguments and _interactive_terminal():
            command = _choose_command().strip()
            arguments = [command]
        args = parser.parse_args(arguments)
        if args.command == "version":
            return version.run()
        if args.command == "create-project":
            if args.no_sources and args.sources:
                parser.error("--no-sources cannot be combined with --source or --recursive-source")
            preview = _preview_options(parser, args, args.sources is not None or args.no_sources)
            if args.root is not None or args.library is not None or args.sources is not None or args.no_sources:
                return create_project.run_with_options(args.root, args.library, args.sources, args.no_sources, preview)
            return create_project.run(preview) if preview else create_project.run()
        if args.command == "create-testbench":
            preview = _preview_options(parser, args, args.source is not None and args.testbench is not None)
            source = args.source if args.source is not None else _ask_testbench_path("DUT file")
            testbench_path = args.testbench if args.testbench is not None else _ask_testbench_path("Testbench file")
            use_options = any(value is not None for value in (args.source, args.testbench, args.library, args.tests))
            if use_options:
                library = args.library if args.library is not None else "work"
            else:
                library = _ask("DUT library", "work")
            extra = (preview,) if preview else ()
            if use_options:
                tests = {"tests": args.tests} if args.tests is not None else {}
                return create_testbench.run(source, testbench_path, library, *extra, **tests)
            return _review_testbench(source, testbench_path, library, *extra, tests=create_testbench.ask_tests())
    except (KeyboardInterrupt, EOFError):
        print("\nCancelled.")
        return 130
    return 1
