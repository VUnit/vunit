# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""Shared terminal input and display helpers."""

import json
import os
import sys
from functools import partial
from pathlib import Path
from typing import NamedTuple

from prompt_toolkit import PromptSession
from prompt_toolkit.application import get_app
from prompt_toolkit.completion import PathCompleter, WordCompleter
from prompt_toolkit.document import Document
from prompt_toolkit.filters import Condition
from prompt_toolkit.key_binding import KeyBindings


class _PathCompleter(PathCompleter):
    """Complete paths with optional opening quotes."""

    def get_completions(self, document, complete_event):
        text = document.text_before_cursor
        if text.startswith(('"', "'")):
            text = text[1:]
        return super().get_completions(Document(text, cursor_position=len(text)), complete_event)


def _clean_answer(answer):
    """Remove surrounding whitespace and optional quotes."""
    answer = answer.strip()
    if len(answer) >= 2 and answer[0] == answer[-1] and answer[0] in "\"'":
        answer = answer[1:-1]
    return answer


def _prompt(label):
    """Format an input prompt consistently."""
    return f"> {label}: "


def _prompt_with_controls(label, controls):
    """Show controls above the prompt if a toolbar cannot be displayed."""
    message = _prompt(label)
    if not get_app().renderer.height_is_known:
        return f"{controls}\n{message}"
    return message


def _add_path_completion_binding(bindings, root=None):
    """Enter a selected directory on Tab without replacing other Tab behavior."""

    @Condition
    def selected_directory():
        buffer = get_app().current_buffer
        if buffer.complete_state is None or buffer.complete_state.current_completion is None:
            return False
        text = buffer.document.text_before_cursor
        if text.startswith(('"', "'")):
            text = text[1:]
        try:
            path = Path(os.path.expandvars(text)).expanduser()
            if not path.is_absolute():
                path = (root if root is not None else Path.cwd()) / path
            return path.is_dir()
        except (OSError, ValueError, RuntimeError):
            return False

    @bindings.add("c-i", filter=selected_directory)
    def enter_directory(event):
        buffer = event.current_buffer
        if not buffer.document.text_before_cursor.endswith(("/", "\\")):
            buffer.insert_text(os.sep, fire_event=False)
        buffer.start_completion(select_first=False)


def _ask(prompt, default=None):
    """Prompt for one value, optionally providing a default."""
    suffix = f" [{default}]" if default is not None else ""
    answer = input(_prompt(f"{prompt}{suffix}")).strip()
    if not answer and default is not None:
        return default
    return _clean_answer(answer)


def _interactive_terminal():
    return sys.stdin.isatty() and sys.stdout.isatty()


def _show_actions():
    get_app().current_buffer.start_completion()


def _choose_action(actions):
    """Select an action using completion or numbered line input."""
    session = None
    if _interactive_terminal():
        session = PromptSession(completer=WordCompleter(actions, sentence=True), complete_while_typing=True)
    else:
        for index, action in enumerate(actions, 1):
            print(f"{index}. {action}")
    while True:
        answer = session.prompt(_prompt("Action"), pre_run=_show_actions) if session else input(_prompt("Action"))
        answer = answer.strip()
        if answer.lower() in {"y", "yes"} and "Create" in actions:
            return "Create"
        if answer.lower() in {"n", "no"} and "Cancel" in actions:
            return "Cancel"
        if answer.isdigit() and 1 <= int(answer) <= len(actions):
            return actions[int(answer) - 1]
        for action in actions:
            if answer.lower() == action.lower():
                return action
        print("Select one of the listed actions.")


def _ask_path(prompt, default, directories=False, show_controls=False, prefill=True):
    """Read a path with terminal completion and an optional prefilled default."""
    if not _interactive_terminal():
        return _ask(prompt, str(default))
    bindings = KeyBindings()
    _add_path_completion_binding(bindings)
    options = {"completer": _PathCompleter(only_directories=directories, expanduser=True), "key_bindings": bindings}
    label = prompt if prefill else f"{prompt} [{default}]"
    message = _prompt(label)
    if show_controls:
        controls = "Controls: Tab complete"
        options["bottom_toolbar"] = controls
        message = partial(_prompt_with_controls, label, controls)
    session = PromptSession(**options)
    initial = str(default) if prefill else ""
    return _clean_answer(session.prompt(message, default=initial)) or str(default)


def _print_preview(content):
    """Display generated code between clear separators."""
    separator = "\u2500" * 60
    print(f"\n{separator}\n")
    print(content, end="" if content.endswith("\n") else "\n")
    print(f"\n{separator}\n")


def _print_summary(summary):
    for path in summary["files_created"]:
        print(f"Created {path}")


class PreviewOptions(NamedTuple):
    """How to present a generation plan instead of writing files."""

    json: bool = False
    show_content: bool = False


def _print_plan(plan, options):
    """Display the files a generator's preview would create."""
    if options.json:
        files = [
            {"path": item["path"], "action": "create", **({"content": item["content"]} if options.show_content else {})}
            for item in plan["files"]
        ]
        print(json.dumps({"files": files}, indent=2))
        return
    print("Files to create:")
    for item in plan["files"]:
        print(f"  {item['path']}")
    if options.show_content:
        for item in plan["files"]:
            print(f"\n{item['path']}:")
            _print_preview(item["content"])
    else:
        print()
    print("No files written.")


def _print_error(context, exc, preview):
    """Report a failure, keeping stdout clean for preview output."""
    if preview is None:
        print(f"{context}: {exc}")
    else:
        print(f"Error: {exc}", file=sys.stderr)


def _print_result(result, preview):
    """Display either the creation summary or the generation plan."""
    if preview is None:
        _print_summary(result)
    else:
        _print_plan(result, preview)
