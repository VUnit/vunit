# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""Interactively create a VUnit project."""

import os
from pathlib import Path

from prompt_toolkit import PromptSession
from prompt_toolkit.application import get_app
from prompt_toolkit.completion import Completer, PathCompleter
from prompt_toolkit.document import Document
from prompt_toolkit.key_binding import KeyBindings

from .cli_helpers import (
    _add_path_completion_binding,
    _ask,
    _ask_path,
    _choose_action,
    _clean_answer,
    _interactive_terminal,
    _print_error,
    _print_preview,
    _print_result,
    _prompt,
)
from .generation import project as generator
from .generation.project import HDL_EXTENSIONS, SourceLocation as _SourceLocation
from .generation.project import hdl_files as _hdl_files


def _ask_libraries():
    """Collect at least one valid, unique library name."""
    libraries = []
    while True:
        prompt = "Add library name (blank to finish)" if libraries else "Add library name"
        library = _ask(prompt, "lib" if not libraries else None)
        if not library:
            return libraries
        if _valid_library(library, libraries):
            libraries.append(library)


def _valid_library(library, existing):
    """Check a library name against the current selections."""
    try:
        generator.validate_library(library, existing)
    except ValueError as exc:
        print(exc)
        return False
    return True


class _SourcePathCompleter(Completer):
    """Complete HDL paths relative to the project root."""

    def __init__(self, root):
        self.completer = PathCompleter(
            get_paths=lambda: [str(root)],
            file_filter=lambda path: Path(path).is_dir() or Path(path).suffix.lower() in HDL_EXTENSIONS,
            expanduser=True,
        )

    def get_completions(self, document, complete_event):
        text = document.text_before_cursor
        if text.startswith(('"', "'")):
            text = text[1:]
        text = os.path.expandvars(text)
        return self.completer.get_completions(Document(text, cursor_position=len(text)), complete_event)


class _SourcePrompt:
    """Collect source paths while selecting their target library."""

    def __init__(self, libraries, root):
        self.libraries = libraries
        self.index = 0
        self.recursive = False
        self.session = None
        if _interactive_terminal():
            bindings = KeyBindings()
            _add_path_completion_binding(bindings, root)

            if len(libraries) > 1:

                @bindings.add("c-l")
                def switch_library(event):
                    self.index = (self.index + 1) % len(self.libraries)
                    event.app.invalidate()

            @bindings.add("c-r")
            def toggle_recursion(event):
                self.recursive = not self.recursive
                event.app.invalidate()

            self.session = PromptSession(
                key_bindings=bindings,
                completer=_SourcePathCompleter(root),
                complete_while_typing=False,
                bottom_toolbar=self._toolbar,
            )

    @property
    def library(self):
        """Return the currently selected library."""
        return self.libraries[self.index]

    def _message(self):
        """Show the selected library and directory mode."""
        mode = "recursive" if self.recursive else "non-recursive"
        return f"  Library: {self.library} | Mode: {mode}\n{_prompt('Add source path (blank to finish)')}"

    def _toolbar(self):
        """Show the controls available for the source prompt."""
        controls = ["Ctrl-R toggle recursion"]
        if len(self.libraries) > 1:
            controls.append("Ctrl-L switch library")
        if self.session is not None:
            controls.append("Tab complete")
        else:
            controls.append("enter control on its own line")
        return "Controls: " + " | ".join(controls)

    def _prompt_message(self):
        """Keep controls visible when the terminal cannot display a toolbar."""
        message = self._message()
        if not get_app().renderer.height_is_known:
            return f"{self._toolbar()}\n{message}"
        return message

    def ask(self):
        """Read a source path, handling library switches."""
        if self.session is not None:
            return _clean_answer(self.session.prompt(self._prompt_message))
        while True:
            print(self._toolbar())
            answer = input(self._message())
            control = answer.strip(" \t")
            if control == "\x12":
                self.recursive = not self.recursive
            elif control == "\x0c" and len(self.libraries) > 1:
                self.index = (self.index + 1) % len(self.libraries)
            else:
                return _clean_answer(answer)


def _path(text, base):
    """Resolve an entered path relative to the project root."""
    path = Path(os.path.expandvars(text)).expanduser()
    if not path.is_absolute():
        path = base / path
    return path.resolve()


def _collect_sources(root, locations):
    """Add validated source paths to their selected libraries."""
    prompt = _SourcePrompt(list(locations), root)
    while True:
        entry = prompt.ask()
        if not entry:
            return
        location = _path(entry, root)
        if not location.exists():
            print(f"Not found: {location}")
            continue
        if not _hdl_files(location, prompt.recursive):
            print("No supported HDL files found there; skipping.")
            continue
        _add_source(locations[prompt.library], location, prompt.recursive)


def _add_source(paths, location, recursive):
    """Add or update a source selection without changing its order."""
    selected = _SourceLocation(location, location.is_dir() and recursive)
    for index, previous in enumerate(paths):
        if previous.path == location:
            paths[index] = selected
            return
    paths.append(selected)


def _edit_libraries(locations):
    """Add, rename, or remove libraries while retaining their sources."""
    while True:
        actions = [f"Rename {name}" for name in locations] + [f"Remove {name}" for name in locations]
        action = _choose_action(actions + ["Add library", "Done"])
        if action == "Done":
            return
        if action == "Add library":
            name = _ask("Add library name")
            if name and _valid_library(name, locations):
                locations[name] = []
        elif action.startswith("Remove "):
            if len(locations) == 1:
                print("At least one library is required.")
            else:
                del locations[action[len("Remove ") :]]
        else:
            old_name = action[len("Rename ") :]
            name = _ask("Add library name", old_name)
            if _valid_library(name, [item for item in locations if item != old_name]):
                updated = {name if item == old_name else item: paths for item, paths in locations.items()}
                locations.clear()
                locations.update(updated)


def _edit_sources(root, locations):
    """Add or remove source paths from the selected libraries."""
    while True:
        entries = [(name, source) for name, paths in locations.items() for source in paths]
        actions = [f"Remove {name}: {_source_description(source)}" for name, source in entries]
        action = _choose_action(actions + ["Add source paths", "Done"])
        if action == "Done":
            return
        if action == "Add source paths":
            _collect_sources(root, locations)
        else:
            name, source = entries[actions.index(action)]
            locations[name].remove(source)


def _source_description(source):
    if source.path.is_dir():
        return f"{source.path} ({'recursive' if source.recursive else 'non-recursive'})"
    return str(source.path)


def _validate_project(root, locations):
    """Check the destination and current source paths before writing."""
    try:
        generator.validate_root(root)
        generator.validate_sources(locations)
    except (OSError, ValueError) as exc:
        print(f"Error: {exc}")
        return False
    return True


def _config(root, locations):
    return {
        "root": root,
        "libraries": {
            name: [{"path": source.path, "recursive": source.recursive} for source in sources]
            for name, sources in locations.items()
        },
    }


def _preview_project(root, locations):
    """Show the generated script if the current project configuration is valid."""
    if _validate_project(root, locations):
        try:
            result = generator.preview(_config(root, locations))
        except (OSError, ValueError) as exc:
            print(f"Error: {exc}")
        else:
            _print_preview(result["files"][0]["content"])


def run_with_options(root, libraries, sources, no_sources, preview=None):
    """Create a project using supplied options and prompt for missing source paths.

    With ``preview`` (a ``PreviewOptions``), display the generation plan instead of writing files.
    """
    root = _path(root if root is not None else ".", Path.cwd())
    locations = {}
    try:
        generator.validate_root(root)
        for library in libraries if libraries is not None else ["lib"]:
            generator.validate_library(library, locations)
            locations[library] = []
        if sources is not None:
            for library, path, recursive in sources:
                if library not in locations:
                    raise ValueError(f"Unknown library for source path: {library}")
                _add_source(locations[library], _path(path, root), recursive)
        elif not no_sources:
            _collect_sources(root, locations)
        config = _config(root, locations)
        result = generator.preview(config) if preview else generator.generate(config)
    except (OSError, ValueError) as exc:
        _print_error("Error creating run.py", exc, preview)
        return 1
    _print_result(result, preview)
    return 0


def _ask_root(default):
    """Prompt for a project root with a visible default and completion controls."""
    return _ask_path("Project root directory", default, directories=True, show_controls=True, prefill=False)


def run(preview=None):
    """Collect paths interactively and create a starter run.py.

    With ``preview`` (a ``PreviewOptions``), the final action displays the generation plan instead of writing files.
    """
    root = _path(_ask_root("."), Path.cwd())
    while not _validate_project(root, {}):
        root = _path(_ask_root(root), Path.cwd())

    libraries = _ask_libraries()
    locations = {library: [] for library in libraries}
    _collect_sources(root, locations)
    final_actions = ["Preview", "Cancel"] if preview else ["Preview", "Create", "Cancel"]
    while True:
        print(f"\nProject directory: {root}")
        for library, paths in locations.items():
            print(f"Library: {library}")
            for source in paths:
                print(f"  {_source_description(source)}")
        action = _choose_action(["Edit project directory", "Edit libraries", "Edit source paths"] + final_actions)
        if action == "Cancel":
            print("Cancelled; no files written.")
            return 0
        if action == "Edit project directory":
            candidate = _path(_ask_root(root), Path.cwd())
            if _validate_project(candidate, {}):
                root = candidate
        elif action == "Edit libraries":
            _edit_libraries(locations)
        elif action == "Edit source paths":
            _edit_sources(root, locations)
        elif action == "Preview" and not preview:
            _preview_project(root, locations)
        elif _validate_project(root, locations):
            break

    try:
        config = _config(root, locations)
        result = generator.preview(config) if preview else generator.generate(config)
    except (OSError, ValueError) as exc:
        _print_error("Error creating run.py", exc, preview)
        return 1

    _print_result(result, preview)
    return 0
