# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""Tests for the interactive project generator."""

import json
import os
import runpy
import shutil
import subprocess
import sys
import threading
import unittest
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import MagicMock, call, patch

from prompt_toolkit import PromptSession
from prompt_toolkit.completion import CompleteEvent
from prompt_toolkit.document import Document
from prompt_toolkit.input import create_pipe_input
from prompt_toolkit.output import DummyOutput
from prompt_toolkit.output.vt100 import Vt100_Output
from prompt_toolkit.data_structures import Size

from vunit.app import cli, cli_helpers, create_project as new, create_testbench
from vunit.app.generation import project as project_generator
from vunit.app.generation import testbench as testbench_generator


class TestProjectGenerator(unittest.TestCase):
    def test_preview_and_generate_are_json_serializable_and_silent(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "sources" / "nested" / "device.vhd"
            source.parent.mkdir(parents=True)
            source.touch()
            destination = root / "project"
            config = {
                "root": destination,
                "libraries": {"rtl": [{"path": source.parent.parent, "recursive": True}]},
            }
            with patch("builtins.print") as output_print:
                result = project_generator.preview(config)
                self.assertFalse(destination.exists())
                summary = project_generator.generate(config)
                output_print.assert_not_called()
            output = destination / "run.py"
            self.assertEqual(result["files"][0]["content"], output.read_text(encoding="utf-8"))
            self.assertEqual(summary["files_created"], [str(output)])
            self.assertEqual(summary["details"]["libraries"]["rtl"][0]["path"], str(source.parent.parent))
            self.assertTrue(summary["details"]["libraries"]["rtl"][0]["recursive"])
            json.dumps(result)
            json.dumps(summary)
            with self.assertRaises(ValueError):
                project_generator.generate(config)

    def test_validation_does_not_depend_on_the_cli(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            with patch("builtins.print") as output_print:
                for libraries in ({}, {"work": []}, {"lib": [], "LIB": []}, {"lib": [{"path": "missing"}]}):
                    with self.subTest(libraries=libraries), self.assertRaises(ValueError):
                        project_generator.generate({"root": root, "libraries": libraries})
                output_print.assert_not_called()
            self.assertFalse((root / "run.py").exists())

    def test_creation_revalidates_sources_after_preview(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.touch()
            config = {"root": root, "libraries": {"lib": [{"path": "device.vhd"}]}}
            project_generator.preview(config)
            source.unlink()
            with self.assertRaises(ValueError):
                project_generator.generate(config)
            self.assertFalse((root / "run.py").exists())

    def test_creation_does_not_overwrite_a_file_created_after_validation(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            output = root / "run.py"
            original_open = Path.open

            def open_after_race(path, *args, **kwargs):
                if path == output and args and args[0] == "x":
                    with original_open(output, "w", encoding="utf-8") as stream:
                        stream.write("existing")
                return original_open(path, *args, **kwargs)

            with patch.object(Path, "open", open_after_race), self.assertRaises(FileExistsError):
                project_generator.generate({"root": root, "libraries": {"lib": []}})
            self.assertEqual(output.read_text(encoding="utf-8"), "existing")


class TestTestbenchGenerator(unittest.TestCase):
    def test_preview_and_generate_are_json_serializable_and_silent(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "nested" / "tb_device.vhd"
            config = {"source": source, "testbench": output, "library": "rtl"}
            with patch("builtins.print") as output_print:
                result = testbench_generator.preview(config)
                self.assertFalse(output.parent.exists())
                summary = testbench_generator.generate(config)
                output_print.assert_not_called()
            self.assertEqual(result["files"][0]["content"], output.read_text(encoding="latin-1"))
            self.assertEqual(summary["files_created"], [str(output)])
            self.assertEqual(summary["details"], {"source": str(source), "library": "rtl", "entity": "device"})
            json.dumps(result)
            json.dumps(summary)
            with self.assertRaises(ValueError):
                testbench_generator.generate(config)

    def test_creation_revalidates_sources_after_preview(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "nested" / "tb_device.vhd"
            config = {"source": source, "testbench": output}
            testbench_generator.preview(config)
            source.unlink()
            with patch("builtins.print") as output_print, self.assertRaises(OSError):
                testbench_generator.generate(config)
            output_print.assert_not_called()
            self.assertFalse(output.parent.exists())

    def test_creation_does_not_overwrite_a_file_created_after_validation(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "tb_device.vhd"
            original_open = Path.open

            def open_after_race(path, *args, **kwargs):
                if path == output and args and args[0] == "x":
                    with original_open(output, "w", encoding="latin-1") as stream:
                        stream.write("existing")
                return original_open(path, *args, **kwargs)

            with patch.object(Path, "open", open_after_race), self.assertRaises(FileExistsError):
                testbench_generator.generate({"source": source, "testbench": output})
            self.assertEqual(output.read_text(encoding="latin-1"), "existing")


class TestLibraryInput(unittest.TestCase):
    def test_default_library_and_finish(self):
        with patch("builtins.input", side_effect=["", ""]) as read:
            self.assertEqual(new._ask_libraries(), ["lib"])
        self.assertEqual(
            read.call_args_list, [call("> Add library name [lib]: "), call("> Add library name (blank to finish): ")]
        )

    def test_invalid_and_duplicate_names_are_rejected(self):
        with patch("builtins.input", side_effect=["work", "1bad", "First", "FIRST", "second", ""]):
            self.assertEqual(new._ask_libraries(), ["First", "second"])

    def test_library_editor_uses_add_library_name_prompt(self):
        locations = {"lib": []}
        with (
            patch.object(new, "_choose_action", side_effect=["Add library", "Rename lib", "Done"]),
            patch.object(new, "_ask", side_effect=["other", "renamed"]) as ask,
        ):
            new._edit_libraries(locations)
        self.assertEqual(ask.call_args_list, [call("Add library name"), call("Add library name", "lib")])
        self.assertEqual(locations, {"renamed": [], "other": []})


class TestReviewMenu(unittest.TestCase):
    def test_numbered_selection_recovers_from_invalid_input(self):
        with (
            patch.object(new, "_interactive_terminal", return_value=False),
            patch("builtins.input", side_effect=["invalid", "2"]) as read,
        ):
            self.assertEqual(new._choose_action(["Edit", "Create", "Cancel"]), "Create")
        self.assertEqual(read.call_args_list, [call("> Action: "), call("> Action: ")])

    def test_editable_path_uses_prompt_marker(self):
        session = MagicMock()
        session.prompt.return_value = "path"
        with (
            patch.object(cli_helpers, "_interactive_terminal", return_value=True),
            patch.object(cli_helpers, "PromptSession", return_value=session),
        ):
            self.assertEqual(cli_helpers._ask_path("Project root directory", "."), "path")
        session.prompt.assert_called_once_with("> Project root directory: ", default=".")

    def test_path_can_show_a_default_without_prefilling_it(self):
        session = MagicMock()
        session.prompt.side_effect = ["", "other"]
        with (
            patch.object(cli_helpers, "_interactive_terminal", return_value=True),
            patch.object(cli_helpers, "PromptSession", return_value=session) as create_session,
        ):
            self.assertEqual(
                cli_helpers._ask_path(
                    "Project root directory", ".", directories=True, show_controls=True, prefill=False
                ),
                ".",
            )
            self.assertEqual(
                cli_helpers._ask_path(
                    "Project root directory", ".", directories=True, show_controls=True, prefill=False
                ),
                "other",
            )
        self.assertEqual(create_session.call_args.kwargs["bottom_toolbar"], "Controls: Tab complete")
        self.assertEqual(session.prompt.call_args.kwargs["default"], "")
        message = session.prompt.call_args.args[0]
        with patch.object(cli_helpers, "get_app") as app:
            app.return_value.renderer.height_is_known = True
            self.assertEqual(message(), "> Project root directory [.]: ")
            app.return_value.renderer.height_is_known = False
            self.assertEqual(message(), "Controls: Tab complete\n> Project root directory [.]: ")

    def test_named_selection(self):
        with (
            patch.object(new, "_interactive_terminal", return_value=False),
            patch("builtins.input", return_value="cancel"),
        ):
            self.assertEqual(new._choose_action(["Edit", "Create", "Cancel"]), "Cancel")

    def test_arrow_keys_select_action(self):
        with create_pipe_input() as pipe_input:

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)
                sent = False

                def select_action(buffer):
                    nonlocal sent
                    state = buffer.complete_state
                    if not sent and state is not None and len(state.completions) == 3:
                        sent = True
                        pipe_input.send_text("\x1b[B\x1b[B\r")

                session.default_buffer.on_completions_changed += select_action
                return session

            with (
                patch.object(cli_helpers, "_interactive_terminal", return_value=True),
                patch.object(cli_helpers, "PromptSession", side_effect=make_session),
            ):
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\x03"))
                timeout.start()
                try:
                    self.assertEqual(new._choose_action(["Edit", "Create", "Cancel"]), "Create")
                finally:
                    timeout.cancel()


class TestCLI(unittest.TestCase):
    def test_project_command_is_hyphenated(self):
        self.assertIn("create-project", cli.COMMANDS)
        self.assertIn("create-testbench", cli.COMMANDS)
        with patch.object(cli.create_project, "run", return_value=0) as create_project:
            self.assertEqual(cli.main(["create-project"]), 0)
            create_project.assert_called_once_with()
        with self.assertRaises(SystemExit) as exc:
            cli.main(["create_project"])
        self.assertEqual(exc.exception.code, 2)

    def test_testbench_command_is_hyphenated(self):
        with patch.object(create_testbench, "run", return_value=0) as create_tb:
            self.assertEqual(cli.main(["create-testbench", "--source", "source.vhd", "--testbench", "tb.vhd"]), 0)
            create_tb.assert_called_once_with("source.vhd", "tb.vhd", "work")
        with self.assertRaises(SystemExit) as exc:
            cli.main(["create_testbench"])
        self.assertEqual(exc.exception.code, 2)

    def test_project_options_create_without_prompting_and_preserve_source_order(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            (root / "one.vhd").touch()
            nested = root / "dir" / "nested"
            nested.mkdir(parents=True)
            (nested / "two.sv").touch()
            with patch("builtins.input", side_effect=AssertionError("unexpected prompt")):
                self.assertEqual(
                    cli.main(
                        [
                            "create-project",
                            "--root",
                            str(root),
                            "--library",
                            "rtl",
                            "--source",
                            "rtl",
                            "one.vhd",
                            "--recursive-source",
                            "rtl",
                            "dir",
                        ]
                    ),
                    0,
                )
            text = (root / "run.py").read_text(encoding="utf-8")
            self.assertIn('vu.add_library("rtl")', text)
            self.assertIn('rtl.add_source_file(root / "one.vhd")', text)
            self.assertIn('rtl.add_source_files(root / "dir" / "**" / "*.sv")', text)
            self.assertLess(text.index('"one.vhd"'), text.index('"dir"'))

    def test_project_options_prompt_for_missing_sources_and_use_default_library(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "one.vhd"
            source.touch()
            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch("builtins.input", side_effect=["one.vhd", ""]),
            ):
                self.assertEqual(cli.main(["create-project", "--root", str(root)]), 0)
            text = (root / "run.py").read_text(encoding="utf-8")
            self.assertIn('vu.add_library("lib")', text)
            self.assertIn('lib.add_source_file(root / "one.vhd")', text)

    def test_project_option_no_sources_uses_defaults(self):
        with TemporaryDirectory() as tempdir, patch.object(new.Path, "cwd", return_value=Path(tempdir)):
            with patch("builtins.input", side_effect=AssertionError("unexpected prompt")):
                self.assertEqual(cli.main(["create-project", "--no-sources"]), 0)
            self.assertIn('vu.add_library("lib")', (Path(tempdir) / "run.py").read_text(encoding="utf-8"))

    def test_project_options_assign_sources_to_multiple_libraries(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            (root / "one.vhd").touch()
            (root / "two.sv").touch()
            with patch("builtins.input", side_effect=AssertionError("unexpected prompt")):
                self.assertEqual(
                    cli.main(
                        [
                            "create-project",
                            "--root",
                            str(root),
                            "--library",
                            "rtl",
                            "--library",
                            "tb",
                            "--source",
                            "rtl",
                            "one.vhd",
                            "--source",
                            "tb",
                            "two.sv",
                        ]
                    ),
                    0,
                )
            text = (root / "run.py").read_text(encoding="utf-8")
            self.assertIn('rtl.add_source_file(root / "one.vhd")', text)
            self.assertIn('tb.add_source_file(root / "two.sv")', text)

    def test_project_options_replace_an_existing_source_selection(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "dir"
            nested = source / "nested"
            nested.mkdir(parents=True)
            (source / "one.vhd").touch()
            (nested / "two.vhd").touch()
            with patch("builtins.input", side_effect=AssertionError("unexpected prompt")):
                self.assertEqual(
                    cli.main(
                        [
                            "create-project",
                            "--root",
                            str(root),
                            "--source",
                            "lib",
                            "dir",
                            "--recursive-source",
                            "lib",
                            "dir",
                        ]
                    ),
                    0,
                )
            text = (root / "run.py").read_text(encoding="utf-8")
            self.assertEqual(text.count("lib.add_source_files("), 1)
            self.assertIn('lib.add_source_files(root / "dir" / "**" / "*.vhd")', text)

    def test_project_options_reject_invalid_configuration_without_writing(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            (root / "one.vhd").touch()
            for arguments in (
                ["--library", "work", "--no-sources"],
                ["--library", "rtl", "--library", "RTL", "--no-sources"],
                ["--source", "other", "one.vhd"],
                ["--source", "lib", "missing.vhd"],
            ):
                with self.subTest(arguments=arguments), patch("builtins.input", side_effect=AssertionError("prompt")):
                    self.assertEqual(cli.main(["create-project", "--root", str(root)] + arguments), 1)
                    self.assertFalse((root / "run.py").exists())

    def test_project_no_sources_conflicts_with_source_options(self):
        with self.assertRaises(SystemExit) as exc:
            cli.main(["create-project", "--no-sources", "--source", "lib", "one.vhd"])
        self.assertEqual(exc.exception.code, 2)

    def test_testbench_options_create_without_prompting(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "tb_device.vhd"
            with patch("builtins.input", side_effect=AssertionError("unexpected prompt")):
                self.assertEqual(cli.main(["create-testbench", "--source", str(source), "--testbench", str(output)]), 0)
            self.assertIn("dut : entity work.device;", output.read_text(encoding="latin-1"))

    def test_testbench_options_prompt_for_missing_path_and_use_default_library(self):
        with (
            patch.object(cli, "_ask_testbench_path", return_value="tb_source.vhd") as ask,
            patch.object(create_testbench, "run", return_value=0) as create,
            patch.object(cli, "_review_testbench", side_effect=AssertionError("unexpected review")),
        ):
            self.assertEqual(cli.main(["create-testbench", "--source", "source.vhd"]), 0)
            ask.assert_called_once_with("Testbench file")
            create.assert_called_once_with("source.vhd", "tb_source.vhd", "work")

    def test_testbench_option_prompts_for_missing_source(self):
        with (
            patch.object(cli, "_ask_testbench_path", return_value="source.vhd") as ask,
            patch.object(create_testbench, "run", return_value=0) as create,
        ):
            self.assertEqual(cli.main(["create-testbench", "--testbench", "tb_source.vhd"]), 0)
            ask.assert_called_once_with("DUT file")
            create.assert_called_once_with("source.vhd", "tb_source.vhd", "work")

    def test_testbench_library_option_prompts_for_both_paths_without_review(self):
        with (
            patch.object(cli, "_ask_testbench_path", side_effect=["source.vhd", "tb_source.vhd"]) as ask,
            patch.object(create_testbench, "run", return_value=0) as create,
            patch.object(cli, "_review_testbench", side_effect=AssertionError("unexpected review")),
        ):
            self.assertEqual(cli.main(["create-testbench", "--library", "rtl"]), 0)
            self.assertEqual(ask.call_args_list, [call("DUT file"), call("Testbench file")])
            create.assert_called_once_with("source.vhd", "tb_source.vhd", "rtl")

    def test_testbench_rejects_positional_path_arguments(self):
        for arguments in (
            ["source.vhd"],
            ["source.vhd", "tb.vhd"],
            ["source.vhd", "--source", "other.vhd"],
            ["--source", "source.vhd", "tb.vhd"],
        ):
            with self.subTest(arguments=arguments), self.assertRaises(SystemExit) as exc:
                cli.main(["create-testbench"] + arguments)
            self.assertEqual(exc.exception.code, 2)

    def test_testbench_help_lists_only_options(self):
        with patch("sys.stdout") as output, self.assertRaises(SystemExit) as exc:
            cli.main(["create-testbench", "--help"])
        self.assertEqual(exc.exception.code, 0)
        text = "".join(item.args[0] for item in output.write.call_args_list)
        self.assertIn("--source FILE", text)
        self.assertIn("--testbench FILE", text)
        self.assertIn("--library NAME", text)
        self.assertNotIn("[source]", text)
        self.assertNotIn("[testbench]", text)

    def test_testbench_options_do_not_overwrite_existing_file(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "tb_device.vhd"
            output.write_text("existing", encoding="utf-8")
            with patch("builtins.input", side_effect=AssertionError("unexpected prompt")):
                self.assertEqual(cli.main(["create-testbench", "--source", str(source), "--testbench", str(output)]), 1)
            self.assertEqual(output.read_text(encoding="utf-8"), "existing")

    def test_version_command(self):
        with patch.object(cli.version, "run", return_value=0) as version:
            self.assertEqual(cli.main(["version"]), 0)
            version.assert_called_once_with()

    def test_explicit_commands(self):
        with patch.object(cli.create_project, "run", return_value=0) as create_project:
            self.assertEqual(cli.main(["create-project"]), 0)
            create_project.assert_called_once_with()
        with patch.object(create_testbench, "run", return_value=0) as create_tb:
            self.assertEqual(
                cli.main(
                    ["create-testbench", "--source", "source.vhd", "--testbench", "tb_source.vhd", "--library", "rtl"]
                ),
                0,
            )
            create_tb.assert_called_once_with("source.vhd", "tb_source.vhd", "rtl")

    def test_no_arguments_selects_command_in_terminal(self):
        with (
            patch.object(cli, "_interactive_terminal", return_value=True),
            patch.object(cli, "_choose_command", return_value="create-testbench"),
            patch.object(cli, "_ask_testbench_path", side_effect=["source.vhd", "tb_source.vhd"]),
            patch.object(cli, "_ask", return_value="rtl"),
            patch.object(create_testbench, "ask_tests", return_value=["t"]),
            patch.object(cli, "_review_testbench", return_value=0) as create_tb,
        ):
            self.assertEqual(cli.main([]), 0)
            create_tb.assert_called_once_with("source.vhd", "tb_source.vhd", "rtl", tests=["t"])

    def test_explicit_testbench_command_prompts_for_source_library(self):
        with (
            patch.object(cli, "_ask_testbench_path", side_effect=["source.vhd", "tb_source.vhd"]),
            patch.object(cli, "_ask", return_value="rtl") as ask,
            patch.object(create_testbench, "ask_tests", return_value=[]),
            patch.object(cli, "_review_testbench", return_value=0) as review,
        ):
            self.assertEqual(cli.main(["create-testbench"]), 0)
            ask.assert_called_once_with("DUT library", "work")
            review.assert_called_once_with("source.vhd", "tb_source.vhd", "rtl", tests=[])

    def test_testbench_command_prompts_for_missing_paths(self):
        with (
            patch.object(cli, "_interactive_terminal", return_value=False),
            patch("builtins.input", side_effect=['"source.vhd"', "tb_source.vhd", "rtl", "a b", "c", ""]) as read,
            patch.object(cli, "_review_testbench", return_value=0) as review,
        ):
            self.assertEqual(cli.main(["create-testbench"]), 0)
            self.assertEqual(
                read.call_args_list,
                [
                    call("> DUT file: "),
                    call("> Testbench file: "),
                    call("> DUT library [work]: "),
                    call("> Add test name [first_test]: "),
                    call("> Add test name (blank to finish): "),
                    call("> Add test name (blank to finish): "),
                ],
            )
            review.assert_called_once_with("source.vhd", "tb_source.vhd", "rtl", tests=["a b", "c"])

    def test_testbench_command_prompts_only_for_missing_output(self):
        with (
            patch.object(cli, "_ask_testbench_path", return_value="tb_source.vhd") as ask,
            patch.object(create_testbench, "run", return_value=0) as create,
        ):
            self.assertEqual(cli.main(["create-testbench", "--source", "source.vhd", "--library", "rtl"]), 0)
            ask.assert_called_once_with("Testbench file")
            create.assert_called_once_with("source.vhd", "tb_source.vhd", "rtl")

    def test_testbench_path_prompt_can_be_cancelled(self):
        with patch.object(cli, "_ask_testbench_path", side_effect=EOFError):
            self.assertEqual(cli.main(["create-testbench"]), 130)

    def test_testbench_path_prompt_uses_terminal_completion(self):
        session = MagicMock()
        session.prompt.return_value = '"source.vhd"'
        with (
            patch.object(cli, "_interactive_terminal", return_value=True),
            patch.object(cli, "PromptSession", return_value=session) as create_session,
        ):
            self.assertEqual(cli._ask_testbench_path("DUT file"), "source.vhd")
        self.assertIsInstance(create_session.call_args.kwargs["completer"], cli_helpers._PathCompleter)
        self.assertEqual(create_session.call_args.kwargs["bottom_toolbar"], "Controls: Tab complete")
        message = session.prompt.call_args.args[0]
        with patch.object(cli_helpers, "get_app") as app:
            app.return_value.renderer.height_is_known = True
            self.assertEqual(message(), "> DUT file: ")
            app.return_value.renderer.height_is_known = False
            self.assertEqual(message(), "Controls: Tab complete\n> DUT file: ")

    def test_testbench_path_prompts_render_completion_control(self):
        for editable in (False, True):
            for label in ("DUT file", "Testbench file"):
                for height_known in (True, False):
                    with self.subTest(editable=editable, label=label, height_known=height_known):
                        self._check_path_prompt_rendering(editable, label, height_known)

    def _check_path_prompt_rendering(self, editable, label, height_known):
        output = StringIO()
        terminal = Vt100_Output(output, get_size=lambda: Size(rows=24, columns=120), term="xterm", enable_cpr=False)
        get_height = patch.object(
            terminal,
            "get_rows_below_cursor_position",
            return_value=10,
            side_effect=None if height_known else NotImplementedError,
        )
        with get_height, create_pipe_input() as pipe_input:

            def make_session(**kwargs):
                return PromptSession(input=pipe_input, output=terminal, **kwargs)

            module = cli_helpers if editable else cli
            with (
                patch.object(module, "_interactive_terminal", return_value=True),
                patch.object(module, "PromptSession", side_effect=make_session),
            ):
                if editable:
                    pipe_input.send_text("\r")
                    self.assertEqual(cli_helpers._ask_path(label, "file.vhd", show_controls=True), "file.vhd")
                else:
                    pipe_input.send_text("file.vhd\r")
                    self.assertEqual(cli._ask_testbench_path(label), "file.vhd")
        rendered = output.getvalue()
        self.assertIn(f"> {label}:", rendered)
        self.assertIn("Controls: Tab complete", rendered)
        if height_known:
            self.assertLess(rendered.index(label), rendered.index("Controls:"))
        else:
            self.assertLess(rendered.index("Controls:"), rendered.index(label))

    def test_testbench_path_prompts_complete_files_with_tab(self):
        for editable in (False, True):
            for label in ("DUT file", "Testbench file"):
                with (
                    self.subTest(editable=editable, label=label),
                    TemporaryDirectory() as tempdir,
                    create_pipe_input() as pipe_input,
                ):
                    root = Path(tempdir)
                    target = root / "device.vhd"
                    target.touch()
                    prefix = str(root / "dev")

                    def make_session(**kwargs):
                        session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

                        def submit_completed_path(buffer):
                            if buffer.text == str(target):
                                pipe_input.send_text("\r")

                        session.default_buffer.on_text_changed += submit_completed_path
                        return session

                    module = cli_helpers if editable else cli
                    with (
                        patch.object(module, "_interactive_terminal", return_value=True),
                        patch.object(module, "PromptSession", side_effect=make_session),
                    ):
                        timeout = threading.Timer(5, lambda: pipe_input.send_text("\x03"))
                        timeout.start()
                        try:
                            if editable:
                                pipe_input.send_text("\t")
                                self.assertEqual(cli_helpers._ask_path(label, prefix, show_controls=True), str(target))
                            else:
                                pipe_input.send_text(prefix + "\t")
                                self.assertEqual(cli._ask_testbench_path(label), str(target))
                        finally:
                            timeout.cancel()

    def test_path_prompts_enter_selected_directory_with_tab(self):
        for kind in ("root", "source", "testbench", "edit-source", "edit-testbench"):
            for quoted in (False, True):
                with self.subTest(kind=kind, quoted=quoted):
                    self._check_path_prompt_drilldown(kind, quoted)

    def _check_path_prompt_drilldown(self, kind, quoted):
        with TemporaryDirectory() as tempdir, create_pipe_input() as pipe_input:
            root = Path(tempdir)
            directory = root / "src folder"
            target = directory / "nested"
            target.mkdir(parents=True)
            (root / "stuff").mkdir()
            quote = '"' if quoted else ""
            prefix = quote + str(root / "s")
            selected = quote + str(directory)
            stage = 0

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

                def select_completion(buffer):
                    nonlocal stage
                    state = buffer.complete_state
                    if stage == 0 and state is not None and state.original_document.text == prefix:
                        if len(state.completions) == 2:
                            stage = 1
                            pipe_input.send_text("\x1b[B")
                    elif (
                        stage == 2
                        and state is not None
                        and any(item.display_text == "nested/" for item in state.completions)
                    ):
                        stage = 3
                        pipe_input.send_text("\x1b[B" + quote + "\r")

                def enter_selected_directory(buffer):
                    nonlocal stage
                    if stage == 1 and buffer.text == selected:
                        stage = 2
                        pipe_input.send_text("\t")

                session.default_buffer.on_completions_changed += select_completion
                session.default_buffer.on_text_changed += enter_selected_directory
                return session

            module = cli if kind in ("source", "testbench") else cli_helpers
            with (
                patch.object(module, "_interactive_terminal", return_value=True),
                patch.object(module, "PromptSession", side_effect=make_session),
            ):
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\r"))
                timeout.start()
                try:
                    if kind == "root":
                        pipe_input.send_text(prefix)
                        result = new._ask_root(".")
                    elif kind.startswith("edit-"):
                        pipe_input.send_text(prefix)
                        label = "DUT file" if kind.endswith("source") else "Testbench file"
                        result = cli_helpers._ask_path(label, "", show_controls=True)
                    else:
                        pipe_input.send_text(prefix + "\t")
                        label = "DUT file" if kind == "source" else "Testbench file"
                        result = cli._ask_testbench_path(label)
                    self.assertEqual(Path(result), target, f"Completion stage: {stage}")
                    self.assertEqual(stage, 3)
                finally:
                    timeout.cancel()

    def test_command_selection_uses_prompt_marker(self):
        session = MagicMock()
        session.prompt.return_value = "create-project"
        with patch.object(cli, "PromptSession", return_value=session):
            self.assertEqual(cli._choose_command(), "create-project")
        session.prompt.assert_called_once_with("> Command: ", pre_run=cli._show_commands)

    def test_interactive_testbench_command_creates_file(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "tb_device.vhd"
            with (
                patch.object(cli, "_interactive_terminal", return_value=False),
                patch.object(cli_helpers, "_interactive_terminal", return_value=False),
                patch("builtins.input", side_effect=[str(source), str(output), "", "", "Create"]),
            ):
                self.assertEqual(cli.main(["create-testbench"]), 0)
            text = output.read_text(encoding="latin-1")
            self.assertIn("dut : entity work.device;", text)
            self.assertIn('run("first_test")', text)
            self.assertIn("Tests have yet to be added", text)
            self.assertNotIn("This test has yet to be implemented", text)

    def test_no_arguments_without_terminal_shows_usage(self):
        with patch.object(cli, "_interactive_terminal", return_value=False), self.assertRaises(SystemExit) as exc:
            cli.main([])
        self.assertEqual(exc.exception.code, 2)

    def test_cancel_command_selection(self):
        with (
            patch.object(cli, "_interactive_terminal", return_value=True),
            patch.object(cli, "_choose_command", side_effect=KeyboardInterrupt),
        ):
            self.assertEqual(cli.main([]), 130)

    def test_command_menu_can_be_selected_with_arrow_key(self):
        with create_pipe_input() as pipe_input:

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)
                sent = False

                def select_command(buffer):
                    nonlocal sent
                    state = buffer.complete_state
                    if not sent and state is not None and len(state.completions) == len(cli.COMMANDS):
                        sent = True
                        pipe_input.send_text("\x1b[B\r")

                session.default_buffer.on_completions_changed += select_command
                return session

            with patch.object(cli, "PromptSession", side_effect=make_session):
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\x03"))
                timeout.start()
                try:
                    self.assertEqual(cli._choose_command(), "create-project")
                finally:
                    timeout.cancel()


class TestSourcePrompt(unittest.TestCase):
    def test_tab_enters_selected_directory_and_completes_nested_source(self):
        for mode in ("relative", "quoted", "environment"):
            with self.subTest(mode=mode):
                self._check_directory_drilldown(mode)

    def _check_directory_drilldown(self, mode):
        with TemporaryDirectory() as tempdir, create_pipe_input() as pipe_input, patch.dict(os.environ):
            root = Path(tempdir)
            directory = root / "src folder"
            directory.mkdir()
            (directory / "device.vhd").touch()
            (root / "stuff").mkdir()
            os.environ["VUNIT_DRILLDOWN_ROOT"] = str(root)
            variable = "%VUNIT_DRILLDOWN_ROOT%" if os.name == "nt" else "$VUNIT_DRILLDOWN_ROOT"
            prefix = {"relative": "s", "quoted": '"s', "environment": os.path.join(variable, "s")}[mode]
            selected = prefix[:-1] + "src folder"
            closing_quote = '"' if mode == "quoted" else ""
            stage = 0

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

                def select_completion(buffer):
                    nonlocal stage
                    state = buffer.complete_state
                    if stage == 0 and state is not None and len(state.completions) == 2:
                        stage = 1
                        pipe_input.send_text("\x1b[B")
                    elif (
                        stage == 2
                        and state is not None
                        and any(item.display_text == "device.vhd" for item in state.completions)
                    ):
                        stage = 3
                        pipe_input.send_text("\x1b[B" + closing_quote + "\r")

                def enter_selected_directory(buffer):
                    nonlocal stage
                    if stage == 1 and buffer.text == selected:
                        stage = 2
                        pipe_input.send_text("\t")

                session.default_buffer.on_completions_changed += select_completion
                session.default_buffer.on_text_changed += enter_selected_directory
                return session

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["lib"], root)
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\x03"))
                timeout.start()
                try:
                    pipe_input.send_text(prefix + "\t")
                    self.assertEqual(new._path(prompt.ask(), root), directory / "device.vhd")
                    self.assertEqual(stage, 3)
                finally:
                    timeout.cancel()

    def test_tab_keeps_cycling_when_a_file_is_selected(self):
        with TemporaryDirectory() as tempdir, create_pipe_input() as pipe_input:
            root = Path(tempdir)
            (root / "src.vhd").touch()
            (root / "stuff.vhd").touch()
            stage = 0

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

                def select_completion(buffer):
                    nonlocal stage
                    state = buffer.complete_state
                    if stage == 0 and state is not None and len(state.completions) == 2:
                        stage = 1
                        pipe_input.send_text("\x1b[B")

                def cycle_selected_file(buffer):
                    nonlocal stage
                    if stage == 1 and buffer.text == "src.vhd":
                        stage = 2
                        pipe_input.send_text("\t")
                    elif stage == 2 and buffer.text == "stuff.vhd":
                        stage = 3
                        pipe_input.send_text("\r")

                session.default_buffer.on_completions_changed += select_completion
                session.default_buffer.on_text_changed += cycle_selected_file
                return session

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["lib"], root)
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\r"))
                timeout.start()
                try:
                    pipe_input.send_text("s\t")
                    self.assertEqual(prompt.ask(), "stuff.vhd")
                    self.assertEqual(stage, 3)
                finally:
                    timeout.cancel()

    def test_tab_enters_multiple_directory_levels(self):
        with TemporaryDirectory() as tempdir, create_pipe_input() as pipe_input:
            root = Path(tempdir)
            nested = root / "src" / "nested"
            nested.mkdir(parents=True)
            (nested / "device.vhd").touch()
            (root / "stuff").mkdir()
            stage = 0

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

                def select_completion(buffer):
                    nonlocal stage
                    state = buffer.complete_state
                    if stage == 0 and state is not None and len(state.completions) == 2:
                        stage = 1
                        pipe_input.send_text("\x1b[B")
                    elif (
                        stage == 2
                        and state is not None
                        and any(item.display_text == "nested/" for item in state.completions)
                    ):
                        stage = 3
                        pipe_input.send_text("\x1b[B")
                    elif (
                        stage == 4
                        and state is not None
                        and any(item.display_text == "device.vhd" for item in state.completions)
                    ):
                        stage = 5
                        pipe_input.send_text("\x1b[B\r")

                def enter_selected_directory(buffer):
                    nonlocal stage
                    if stage == 1 and Path(buffer.text) == Path("src"):
                        stage = 2
                        pipe_input.send_text("\t")
                    elif stage == 3 and Path(buffer.text) == Path("src") / "nested":
                        stage = 4
                        pipe_input.send_text("\t")

                session.default_buffer.on_completions_changed += select_completion
                session.default_buffer.on_text_changed += enter_selected_directory
                return session

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["lib"], root)
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\r"))
                timeout.start()
                try:
                    pipe_input.send_text("s\t")
                    self.assertEqual(Path(prompt.ask()), Path("src") / "nested" / "device.vhd")
                    self.assertEqual(stage, 5)
                finally:
                    timeout.cancel()

    def test_terminal_renders_source_toolbar(self):
        for height_known in (True, False):
            with self.subTest(height_known=height_known):
                output = StringIO()
                terminal = Vt100_Output(
                    output, get_size=lambda: Size(rows=24, columns=120), term="xterm", enable_cpr=False
                )
                get_height = patch.object(
                    terminal,
                    "get_rows_below_cursor_position",
                    return_value=10,
                    side_effect=None if height_known else NotImplementedError,
                )
                with get_height, create_pipe_input() as pipe_input:

                    def make_session(**kwargs):
                        return PromptSession(input=pipe_input, output=terminal, **kwargs)

                    with (
                        patch.object(new, "_interactive_terminal", return_value=True),
                        patch.object(new, "PromptSession", side_effect=make_session),
                    ):
                        prompt = new._SourcePrompt(["first", "second"], Path.cwd())
                        pipe_input.send_text("source.vhd\r")
                        self.assertEqual(prompt.ask(), "source.vhd")
                rendered = output.getvalue()
                self.assertIn("> Add source path (blank to finish):", rendered)
                self.assertIn("Ctrl-R toggle recursion", rendered)
                self.assertIn("Ctrl-L switch library", rendered)
                self.assertIn("Tab complete", rendered)
                if height_known:
                    self.assertLess(rendered.index("Add source path"), rendered.index("Controls:"))
                else:
                    self.assertLess(rendered.index("Controls:"), rendered.index("Add source path"))

    def test_terminal_toolbar_shows_only_available_controls(self):
        session = MagicMock()
        with patch.object(new, "_interactive_terminal", return_value=True):
            with patch.object(new, "PromptSession", return_value=session) as create_session:
                prompt = new._SourcePrompt(["first", "second"], Path.cwd())
            toolbar = create_session.call_args.kwargs["bottom_toolbar"]
            self.assertEqual(toolbar(), "Controls: Ctrl-R toggle recursion | Ctrl-L switch library | Tab complete")
            self.assertEqual(
                prompt._message(), "  Library: first | Mode: non-recursive\n> Add source path (blank to finish): "
            )

    def test_ctrl_r_toggles_recursion_without_losing_typed_path(self):
        with create_pipe_input() as pipe_input:

            def make_session(**kwargs):
                return PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["lib"], Path.cwd())
                self.assertEqual(
                    prompt._message(), "  Library: lib | Mode: non-recursive\n> Add source path (blank to finish): "
                )
                self.assertEqual(prompt._toolbar(), "Controls: Ctrl-R toggle recursion | Tab complete")
                pipe_input.send_text("source\x12s\r")
                self.assertEqual(prompt.ask(), "sources")
                self.assertTrue(prompt.recursive)
                self.assertEqual(
                    prompt._message(), "  Library: lib | Mode: recursive\n> Add source path (blank to finish): "
                )
                pipe_input.send_text("\x12other\r")
                self.assertEqual(prompt.ask(), "other")
                self.assertFalse(prompt.recursive)

    def test_redirected_input_can_toggle_recursion(self):
        with (
            patch.object(new, "_interactive_terminal", return_value=False),
            patch("builtins.input", side_effect=["\x12", "sources", "\x12", "other"]),
        ):
            prompt = new._SourcePrompt(["lib"], Path.cwd())
            self.assertEqual(prompt.ask(), "sources")
            self.assertTrue(prompt.recursive)
            self.assertEqual(prompt.ask(), "other")
            self.assertFalse(prompt.recursive)

    def test_ctrl_l_preserves_input_and_cycles_libraries(self):
        with create_pipe_input() as pipe_input:

            def make_session(**kwargs):
                return PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["first", "second", "third"], Path.cwd())
                pipe_input.send_text("source \x0c\u03b1.vhd\r")
                self.assertEqual(prompt.ask(), "source \u03b1.vhd")
                self.assertEqual(prompt.library, "second")
                pipe_input.send_text("\x0c\x0canother.vhd\r")
                self.assertEqual(prompt.ask(), "another.vhd")
                self.assertEqual(prompt.library, "first")
                pipe_input.send_text("ac\x1b[D\x0cb\r")
                self.assertEqual(prompt.ask(), "abc")
                self.assertEqual(prompt.library, "second")

    def test_redirected_input_can_switch_libraries(self):
        with (
            patch.object(new, "_interactive_terminal", return_value=False),
            patch("builtins.input", side_effect=["\x0c", '"a path.vhd"']) as read,
            patch("builtins.print") as output,
        ):
            prompt = new._SourcePrompt(["first", "second"], Path.cwd())
            self.assertEqual(
                prompt._toolbar(),
                "Controls: Ctrl-R toggle recursion | Ctrl-L switch library | enter control on its own line",
            )
            self.assertEqual(prompt.ask(), "a path.vhd")
            self.assertEqual(prompt.library, "second")
            self.assertEqual(
                read.call_args_list,
                [
                    call("  Library: first | Mode: non-recursive\n> Add source path (blank to finish): "),
                    call("  Library: second | Mode: non-recursive\n> Add source path (blank to finish): "),
                ],
            )
            self.assertEqual(output.call_count, 2)

    def test_ctrl_c_cancels_prompt(self):
        with create_pipe_input() as pipe_input:

            def make_session(**kwargs):
                return PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["first", "second"], Path.cwd())
                pipe_input.send_text("\x03")
                with self.assertRaises(KeyboardInterrupt):
                    prompt.ask()

    def test_ctrl_d_ends_prompt(self):
        with create_pipe_input() as pipe_input:

            def make_session(**kwargs):
                return PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["first", "second"], Path.cwd())
                pipe_input.send_text("\x04")
                with self.assertRaises(EOFError):
                    prompt.ask()

    def test_tab_completes_for_single_library(self):
        with TemporaryDirectory() as tempdir, create_pipe_input() as pipe_input:
            root = Path(tempdir)
            (root / "design.vhd").touch()

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

                def submit_completed_path(buffer):
                    if buffer.text == "design.vhd":
                        pipe_input.send_text("\r")

                session.default_buffer.on_text_changed += submit_completed_path
                return session

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["lib"], root)
                pipe_input.send_text("des\t")
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\x03"))
                timeout.start()
                try:
                    self.assertEqual(prompt.ask(), "design.vhd")
                finally:
                    timeout.cancel()

    def test_tab_completion_after_library_switch(self):
        with TemporaryDirectory() as tempdir, create_pipe_input() as pipe_input:
            root = Path(tempdir)
            (root / "source file.sv").touch()

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

                def submit_completed_path(buffer):
                    if buffer.text == '"source file.sv':
                        pipe_input.send_text('"\r')

                session.default_buffer.on_text_changed += submit_completed_path
                return session

            with (
                patch.object(new, "_interactive_terminal", return_value=True),
                patch.object(new, "PromptSession", side_effect=make_session),
            ):
                prompt = new._SourcePrompt(["first", "second"], root)
                pipe_input.send_text('\x0c"source f\t')
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\x03"))
                timeout.start()
                try:
                    self.assertEqual(prompt.ask(), "source file.sv")
                    self.assertEqual(prompt.library, "second")
                finally:
                    timeout.cancel()


class TestSourcePathCompleter(unittest.TestCase):
    def test_completes_hdl_files_and_directories_relative_to_root(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            (root / "design.vhd").touch()
            (root / "design.txt").touch()
            (root / "design_dir").mkdir()
            completer = new._SourcePathCompleter(root)
            completions = list(completer.get_completions(Document("des"), CompleteEvent(completion_requested=True)))
            self.assertEqual([completion.text for completion in completions], ["ign.vhd", "ign_dir"])

    def test_completes_quoted_and_environment_variable_paths(self):
        with TemporaryDirectory() as tempdir, patch.dict(os.environ, {"VUNIT_SOURCE_ROOT": tempdir}):
            root = Path(tempdir)
            (root / "design.vhd").touch()
            completer = new._SourcePathCompleter(root)
            variable = "%VUNIT_SOURCE_ROOT%" if os.name == "nt" else "$VUNIT_SOURCE_ROOT"
            for text in ['"des', os.path.join(variable, "des"), str(root / "des")]:
                completions = list(completer.get_completions(Document(text), CompleteEvent(completion_requested=True)))
                self.assertEqual([completion.text for completion in completions], ["ign.vhd"])

    def test_completes_paths_in_home_directory(self):
        with TemporaryDirectory() as tempdir:
            home_variable = "USERPROFILE" if os.name == "nt" else "HOME"
            with patch.dict(os.environ, {home_variable: tempdir}):
                root = Path(tempdir)
                (root / "design.vhd").touch()
                completer = new._SourcePathCompleter(root)
                text = os.path.join("~", "des")
                completions = list(completer.get_completions(Document(text), CompleteEvent(completion_requested=True)))
                self.assertEqual([completion.text for completion in completions], ["ign.vhd"])

    def test_editable_path_keeps_default_in_terminal(self):
        with create_pipe_input() as pipe_input:

            def make_session(**kwargs):
                return PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)

            with (
                patch.object(cli_helpers, "_interactive_terminal", return_value=True),
                patch.object(cli_helpers, "PromptSession", side_effect=make_session),
            ):
                pipe_input.send_text("\r")
                self.assertEqual(new._ask_path("Path", "existing.vhd"), "existing.vhd")


class TestRun(unittest.TestCase):
    def test_root_prompt_uses_bracketed_default_and_completion_controls(self):
        with patch.object(new, "_ask_path", return_value=".") as ask:
            self.assertEqual(new._ask_root("."), ".")
        ask.assert_called_once_with("Project root directory", ".", directories=True, show_controls=True, prefill=False)

    def test_root_prompt_renders_default_and_control_in_terminal(self):
        for height_known in (True, False):
            for answer, expected in (("", "."), ("project", "project")):
                with self.subTest(height_known=height_known, answer=answer):
                    output = StringIO()
                    terminal = Vt100_Output(
                        output, get_size=lambda: Size(rows=24, columns=120), term="xterm", enable_cpr=False
                    )
                    get_height = patch.object(
                        terminal,
                        "get_rows_below_cursor_position",
                        return_value=10,
                        side_effect=None if height_known else NotImplementedError,
                    )
                    with get_height, create_pipe_input() as pipe_input:

                        def make_session(**kwargs):
                            return PromptSession(input=pipe_input, output=terminal, **kwargs)

                        with (
                            patch.object(cli_helpers, "_interactive_terminal", return_value=True),
                            patch.object(cli_helpers, "PromptSession", side_effect=make_session),
                        ):
                            pipe_input.send_text(answer + "\r")
                            self.assertEqual(new._ask_root("."), expected)
                    rendered = output.getvalue()
                    self.assertIn("> Project root directory [.]:", rendered)
                    self.assertIn("Controls: Tab complete", rendered)
                    if height_known:
                        self.assertLess(rendered.index("Project root directory"), rendered.index("Controls:"))
                    else:
                        self.assertLess(rendered.index("Controls:"), rendered.index("Project root directory"))

    def test_root_prompt_completes_directory_with_tab(self):
        with TemporaryDirectory() as tempdir, create_pipe_input() as pipe_input:
            root = Path(tempdir)
            directory = root / "project"
            directory.mkdir()
            observed = []
            prefix = str(root / "pro")

            def make_session(**kwargs):
                session = PromptSession(input=pipe_input, output=DummyOutput(), **kwargs)
                sent = False

                def submit_completed_path(buffer):
                    observed.append(buffer.text)
                    if buffer.text.rstrip("/\\") == str(directory):
                        pipe_input.send_text("\r")

                def select_completion(buffer):
                    nonlocal sent
                    state = buffer.complete_state
                    if not sent and buffer.text == prefix and state is not None and state.completions:
                        sent = True
                        pipe_input.send_text("\t")

                session.default_buffer.on_text_changed += submit_completed_path
                session.default_buffer.on_completions_changed += select_completion
                return session

            with (
                patch.object(cli_helpers, "_interactive_terminal", return_value=True),
                patch.object(cli_helpers, "PromptSession", side_effect=make_session),
            ):
                timeout = threading.Timer(5, lambda: pipe_input.send_text("\r"))
                timeout.start()
                try:
                    pipe_input.send_text(prefix)
                    self.assertEqual(Path(new._ask_root(".")), directory, f"Input changes: {observed}")
                finally:
                    timeout.cancel()

    def test_root_prompt_with_redirected_input_uses_bracketed_default(self):
        with (
            patch.object(cli_helpers, "_interactive_terminal", return_value=False),
            patch("builtins.input", return_value="") as read,
        ):
            self.assertEqual(new._ask_root("."), ".")
        read.assert_called_once_with("> Project root directory [.]: ")

    def test_create_project_with_mixed_directory_modes(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            flat = root / "flat"
            recursive = root / "recursive"
            (flat / "nested").mkdir(parents=True)
            (recursive / "nested").mkdir(parents=True)
            (flat / "top.vhd").touch()
            (flat / "nested" / "ignored.sv").touch()
            (recursive / "nested" / "included.sv").touch()
            inputs = [str(root), "lib", "", str(flat), "\x12", str(recursive), "", "Create"]
            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch("builtins.input", side_effect=inputs),
                patch("builtins.print") as output,
            ):
                self.assertEqual(new.run(), 0)
            script = (root / "run.py").read_text(encoding="utf-8")
            self.assertIn('lib.add_source_files(root / "flat" / "*.vhd")', script)
            self.assertIn('lib.add_source_files(root / "recursive" / "**" / "*.sv")', script)
            self.assertNotIn('root / "flat" / "**"', script)
            summary = "\n".join(str(item) for args, _ in output.call_args_list for item in args)
            self.assertIn(f"{flat} (non-recursive)", summary)
            self.assertIn(f"{recursive} (recursive)", summary)

    def test_directory_selection_records_and_updates_recursion_per_library(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            directory = root / "src"
            nested = directory / "nested"
            nested.mkdir(parents=True)
            (directory / "top.vhd").touch()
            (nested / "deep.vhd").touch()
            locations = {"first": [], "second": []}
            inputs = [str(directory), "\x12", str(directory), "\x0c", str(directory), "\x12", str(directory), ""]
            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch("builtins.input", side_effect=inputs),
            ):
                new._collect_sources(root, locations)
            self.assertEqual(locations["first"], [new._SourceLocation(directory, True)])
            self.assertEqual(locations["second"], [new._SourceLocation(directory, False)])
            self.assertIn("(recursive)", new._source_description(locations["first"][0]))
            self.assertIn("(non-recursive)", new._source_description(locations["second"][0]))

    def test_nested_only_directory_requires_recursive_mode(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            nested = root / "src" / "nested"
            nested.mkdir(parents=True)
            (nested / "deep.vhd").touch()
            locations = {"lib": []}
            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch("builtins.input", side_effect=[str(root / "src"), "\x12", str(root / "src"), ""]),
                patch("builtins.print") as output,
            ):
                new._collect_sources(root, locations)
            self.assertEqual(locations["lib"], [new._SourceLocation(root / "src", True)])
            self.assertTrue(any("No supported HDL files" in str(call) for call in output.call_args_list))

    def test_project_preview_matches_created_file(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "source.vhd"
            source.touch()
            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch.object(new, "_choose_action", side_effect=["Preview", "Create"]),
                patch("builtins.input", side_effect=[str(root), "lib", "", str(source), ""]),
                patch("builtins.print") as output,
            ):
                self.assertEqual(new.run(), 0)
            previews = [
                args[0] for args, _ in output.call_args_list if args and str(args[0]).startswith("from pathlib")
            ]
            self.assertEqual(previews, [(root / "run.py").read_text(encoding="utf-8")])
            calls = output.call_args_list
            preview_index = next(index for index, item in enumerate(calls) if item.args and item.args[0] == previews[0])
            self.assertEqual(calls[preview_index - 1].args[0], "\n" + "─" * 60 + "\n")
            self.assertEqual(calls[preview_index + 1].args[0], "\n" + "─" * 60 + "\n")

    def test_preview_project_then_cancel_without_writing(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "source.vhd"
            source.touch()
            actions = iter(["Preview", "Cancel"])

            def choose(options):
                self.assertIn("Preview", options)
                self.assertFalse((root / "run.py").exists())
                return next(actions)

            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch.object(new, "_choose_action", side_effect=choose),
                patch("builtins.input", side_effect=[str(root), "lib", "", str(source), ""]),
                patch("builtins.print") as output,
            ):
                self.assertEqual(new.run(), 0)
            rendered = "\n".join(str(item) for args, _ in output.call_args_list for item in args)
            self.assertIn('lib.add_source_file(root / "source.vhd")', rendered)
            self.assertFalse((root / "run.py").exists())

    def test_assigns_paths_to_selected_libraries(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "source.vhd"
            source.touch()
            inputs = [str(root), "first", "second", "empty", "", str(source), "\x0c", str(source), str(source), "", "y"]
            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch("builtins.input", side_effect=inputs),
            ):
                self.assertEqual(new.run(), 0)
            vu = MagicMock()
            first, second, empty = MagicMock(), MagicMock(), MagicMock()
            vu.add_library.side_effect = [first, second, empty]
            with patch("vunit.VUnit") as vunit:
                vunit.from_argv.return_value = vu
                runpy.run_path(str(root / "run.py"))
            first.add_source_file.assert_called_once_with(source)
            second.add_source_file.assert_called_once_with(source)
            empty.add_source_file.assert_not_called()

    def test_cancel_does_not_create_script(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            with patch("builtins.input", side_effect=[str(root), "", "", "", "n"]):
                self.assertEqual(new.run(), 0)
            self.assertFalse((root / "run.py").exists())

    def test_existing_script_is_not_overwritten(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            script = root / "run.py"
            script.write_text("existing", encoding="utf-8")
            inputs = [str(root), str(root / "other"), "", "", "", "Cancel"]
            with patch("builtins.input", side_effect=inputs):
                self.assertEqual(new.run(), 0)
            self.assertEqual(script.read_text(encoding="utf-8"), "existing")
            self.assertFalse((root / "other").exists())

    def test_edit_libraries_retains_sources_and_requires_one(self):
        with TemporaryDirectory() as tempdir:
            source = Path(tempdir) / "source.vhd"
            locations = {"lib": [new._SourceLocation(source)]}
            actions = ["Remove lib", "Add library", "Rename lib", "Remove other", "Done"]
            with (
                patch.object(new, "_choose_action", side_effect=actions),
                patch("builtins.input", side_effect=["other", ""]),
            ):
                new._edit_libraries(locations)
            self.assertEqual(locations, {"lib": [new._SourceLocation(source)]})

    def test_edit_multiple_fields_and_sources_before_creating(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            destination = root / "project"
            old_source = root / "old.vhd"
            new_source = root / "new.vhd"
            old_source.touch()
            new_source.touch()
            actions = iter(
                [
                    "Edit project directory",
                    "Edit libraries",
                    "Rename lib",
                    "Rename lib",
                    "Done",
                    "Edit source paths",
                    f"Remove renamed: {old_source}",
                    "Add source paths",
                    "Done",
                    "Create",
                ]
            )

            def choose(options):
                self.assertFalse((destination / "run.py").exists())
                action = next(actions)
                self.assertIn(action, options)
                return action

            inputs = [str(root), "", "", str(old_source), "", str(destination), "work", "renamed", str(new_source), ""]
            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch.object(new, "_choose_action", side_effect=choose),
                patch("builtins.input", side_effect=inputs),
            ):
                self.assertEqual(new.run(), 0)
            script = (destination / "run.py").read_text(encoding="utf-8")
            self.assertIn('vu.add_library("renamed")', script)
            self.assertIn('"new.vhd"', script)
            self.assertNotIn('"old.vhd"', script)

    def test_retain_project_directory_default(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch.object(new, "_choose_action", side_effect=["Edit project directory", "Create"]),
                patch("builtins.input", side_effect=[str(root), "", "", "", ""]),
            ):
                self.assertEqual(new.run(), 0)
            self.assertTrue((root / "run.py").exists())

    def test_rechecks_overwrite_before_creation(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            script = root / "run.py"
            actions = iter(["Create", "Cancel"])

            def choose(_options):
                action = next(actions)
                if action == "Create":
                    script.write_text("existing", encoding="utf-8")
                return action

            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch.object(new, "_choose_action", side_effect=choose),
                patch("builtins.input", side_effect=[str(root), "", "", ""]),
            ):
                self.assertEqual(new.run(), 0)
            self.assertEqual(script.read_text(encoding="utf-8"), "existing")

    def test_rechecks_removed_source_before_creation(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "source.vhd"
            source.touch()
            actions = iter(["Create", "Cancel"])

            def choose(_options):
                action = next(actions)
                if action == "Create":
                    source.unlink()
                return action

            with (
                patch.object(new, "_interactive_terminal", return_value=False),
                patch.object(new, "_choose_action", side_effect=choose),
                patch("builtins.input", side_effect=[str(root), "", "", str(source), ""]),
            ):
                self.assertEqual(new.run(), 0)
            self.assertFalse((root / "run.py").exists())


class TestNewTestbench(unittest.TestCase):
    def test_review_path_editors_request_completion_controls(self):
        with (
            patch.object(
                create_testbench,
                "_choose_action",
                side_effect=["Edit source file", "Edit source library", "Edit testbench path", "Cancel"],
            ),
            patch.object(create_testbench, "_ask_path", side_effect=["source.vhd", "tb.vhd"]) as ask,
            patch.object(create_testbench, "_ask", return_value="rtl") as ask_library,
            patch.object(create_testbench, "validate_source"),
            patch.object(create_testbench, "validate_library"),
            patch.object(create_testbench, "validate_testbench"),
            patch("builtins.print") as output,
        ):
            self.assertEqual(create_testbench.review("old.vhd", "old_tb.vhd", "work"), 0)
        self.assertEqual(
            ask.call_args_list,
            [
                call("DUT file", "old.vhd", show_controls=True),
                call("Testbench file", "old_tb.vhd", show_controls=True),
            ],
        )
        ask_library.assert_called_once_with("DUT library", "work")
        output.assert_any_call(
            "\nDUT file: old.vhd\nDUT library: work\nTestbench file: old_tb.vhd\nTests: first_test (default)"
        )

    def test_testbench_preview_matches_created_file(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output_path = root / "tb_device.vhd"
            with (
                patch.object(create_testbench, "_choose_action", side_effect=["Preview", "Create"]),
                patch("builtins.print") as output,
            ):
                self.assertEqual(create_testbench.review(str(source), str(output_path), "rtl"), 0)
            previews = [args[0] for args, _ in output.call_args_list if args and str(args[0]).startswith("library ")]
            self.assertEqual(previews, [output_path.read_text(encoding="latin-1")])
            calls = output.call_args_list
            preview_index = next(index for index, item in enumerate(calls) if item.args and item.args[0] == previews[0])
            self.assertEqual(calls[preview_index - 1].args[0], "\n" + "─" * 60 + "\n")
            self.assertEqual(calls[preview_index + 1].args[0], "\n" + "─" * 60 + "\n")

    def test_edit_library_preview_then_cancel_without_writing(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output_path = root / "nested" / "tb_device.vhd"
            actions = ["Edit source library", "Edit source library", "Preview", "Cancel"]
            with (
                patch.object(create_testbench, "_choose_action", side_effect=actions),
                patch.object(create_testbench, "_ask", side_effect=["not-valid", "dut_lib"]),
                patch("builtins.print") as output,
            ):
                self.assertEqual(create_testbench.review(str(source), str(output_path), "work"), 0)
            rendered = "\n".join(str(item) for args, _ in output.call_args_list for item in args)
            self.assertIn("Invalid source library name", rendered)
            self.assertIn("library dut_lib;", rendered)
            self.assertIn("dut : entity dut_lib.device;", rendered)
            self.assertFalse(output_path.parent.exists())

    def test_selected_library_and_deduplicated_context(self):
        code = """library IEEE, vunit_lib, device_lib;
library ieee;
library VUNIT_LIB;
use ieee.std_logic_1164.all;
use IEEE.std_logic_1164.all;
use work.types_pkg.all;
context vunit_lib.vunit_context;
entity device is end entity;
"""
        entity, context = testbench_generator._entity_and_context(code)
        text = testbench_generator._make_testbench(entity, context, "tb_device", "device_lib")
        self.assertIn("dut : entity device_lib.device;", text)
        self.assertIn("use device_lib.types_pkg.all;", text)
        for clause in [
            "library ieee;",
            "library vunit_lib;",
            "library device_lib;",
            "use ieee.std_logic_1164.all;",
            "context vunit_lib.vunit_context;",
        ]:
            self.assertEqual(text.lower().count(clause), 1)

    def test_invalid_source_library_is_rejected(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "tb_device.vhd"
            self.assertEqual(create_testbench.run(source, output, "invalid-library"), 1)
            self.assertFalse(output.exists())

    def test_distinct_extended_identifiers_are_not_deduplicated(self):
        code = "library \\Device\\, \\device\\; library \\Device\\; entity item is end entity;"
        entity, context = testbench_generator._entity_and_context(code)
        text = testbench_generator._make_testbench(entity, context, "tb_item", "lib")
        self.assertEqual(text.count("library \\Device\\;"), 1)
        self.assertEqual(text.count("library \\device\\;"), 1)

    def test_review_creates_only_after_confirmation(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "nested" / "tb_device.vhd"

            def choose(options):
                self.assertIn("Create", options)
                self.assertFalse(output.parent.exists())
                return "Create"

            with patch.object(create_testbench, "_choose_action", side_effect=choose):
                self.assertEqual(create_testbench.review(str(source), str(output), "work"), 0)
            self.assertTrue(output.exists())

    def test_review_edits_fields_and_recovers_from_invalid_paths(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            old_source = root / "old.vhd"
            old_source.write_text("entity old is end entity;", encoding="latin-1")
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            old_output = root / "tb_old.vhd"
            output = root / "tb_device.vhd"
            existing = root / "existing.vhd"
            existing.write_text("unchanged", encoding="utf-8")
            actions = ["Edit source file", "Edit source file", "Edit testbench path", "Edit testbench path", "Create"]
            inputs = [str(root / "bad.sv"), str(source), str(existing), str(output)]
            with (
                patch.object(create_testbench, "_choose_action", side_effect=actions),
                patch.object(cli_helpers, "_interactive_terminal", return_value=False),
                patch("builtins.input", side_effect=inputs),
            ):
                self.assertEqual(create_testbench.review(str(old_source), str(old_output), "work"), 0)
            self.assertIn("dut : entity work.device;", output.read_text(encoding="latin-1"))
            self.assertFalse(old_output.exists())
            self.assertEqual(existing.read_text(encoding="utf-8"), "unchanged")

    def test_review_retain_default_and_cancel_without_writing(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "nested" / "tb_device.vhd"
            with (
                patch.object(create_testbench, "_choose_action", side_effect=["Edit source file", "Cancel"]),
                patch.object(cli_helpers, "_interactive_terminal", return_value=False),
                patch("builtins.input", return_value=""),
            ):
                self.assertEqual(create_testbench.review(str(source), str(output), "work"), 0)
            self.assertFalse(output.parent.exists())

    def test_review_revalidates_output_before_create(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "tb_device.vhd"
            actions = iter(["Create", "Cancel"])

            def choose(_options):
                action = next(actions)
                if action == "Create":
                    output.write_text("existing", encoding="utf-8")
                return action

            with patch.object(create_testbench, "_choose_action", side_effect=choose):
                self.assertEqual(create_testbench.review(str(source), str(output), "work"), 0)
            self.assertEqual(output.read_text(encoding="utf-8"), "existing")

    def test_review_revalidates_missing_source_before_create(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "tb_device.vhd"
            actions = iter(["Create", "Cancel"])

            def choose(_options):
                action = next(actions)
                if action == "Create":
                    source.unlink()
                return action

            with patch.object(create_testbench, "_choose_action", side_effect=choose):
                self.assertEqual(create_testbench.review(str(source), str(output), "work"), 0)
            self.assertFalse(output.exists())

    def test_generates_generic_port_maps_and_preserves_literals(self):
        source_text = """library ieee; library extra_lib;
    use ieee.std_logic_1164.all, ieee.numeric_std.all;
entity counter is
  generic (width, depth : positive := 8; label_g : string := "MiXeD"; runner_cfg : string := "DUT");
  port (clk, reset : in std_logic; data : out std_logic_vector(width - 1 downto 0));
end entity;
"""
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "counter.vhd"
            source.write_text(source_text, encoding="latin-1")
            output = root / "tb_counter.vhd"
            self.assertEqual(create_testbench.run(source, output), 0)
            text = output.read_text(encoding="latin-1")
            for expected in [
                "library ieee;",
                "library extra_lib;",
                "use ieee.std_logic_1164.all;",
                "use ieee.numeric_std.all;",
                "entity tb_counter is",
                "width : positive := 8",
                "depth : positive := 8",
                'label_g : string := "MiXeD"',
                'dut_runner_cfg : string := "DUT"',
                "signal clk : std_logic;",
                "signal reset : std_logic;",
                "signal data : std_logic_vector(width - 1 downto 0);",
                "dut : entity work.counter",
                "runner_cfg => dut_runner_cfg",
                "clk => clk",
                "reset => reset",
                "data => data",
                "test_runner : process",
                "test_runner_setup(runner, runner_cfg);",
                "while test_suite loop",
                'if run("first_test") then',
                "-- vunit: .todo",
                'error("Tests have yet to be added");',
                "test_runner_cleanup(runner);",
            ]:
                self.assertIn(expected, text)
            self.assertLess(text.index("test_runner : process"), text.index("dut : entity work.counter"))
            self.assertIn("test_runner_setup(runner, runner_cfg);\n\n    while test_suite loop", text)
            self.assertIn("    end loop;\n\n    test_runner_cleanup(runner);", text)
            self.assertIn("  end process;\n\n  dut : entity work.counter", text)

    def test_entity_without_generics_or_ports(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is end entity;", encoding="latin-1")
            output = root / "tb_device.vhd"
            self.assertEqual(create_testbench.run(source, output), 0)
            text = output.read_text(encoding="latin-1")
            self.assertIn("  end process;\n\n  dut : entity work.device;\nend architecture;", text)

    def test_single_line_entity_with_ports(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text("entity device is port (input_a : in bit; output_z : out bit); end;", encoding="latin-1")
            output = root / "tb_device.vhd"
            self.assertEqual(create_testbench.run(source, output), 0)
            text = output.read_text(encoding="latin-1")
            self.assertIn("signal input_a : bit;", text)
            self.assertIn("output_z => output_z", text)

    def test_port_names_that_conflict_with_testbench_names_remain_unique(self):
        code = "entity device is port (runner : in bit; dut : out bit); end entity;"
        entity, context = testbench_generator._entity_and_context(code)
        text = testbench_generator._make_testbench(entity, context, "tb_device")
        self.assertIn("signal runner_signal : bit;", text)
        self.assertIn("signal dut_signal : bit;", text)
        self.assertIn("runner => runner_signal", text)
        self.assertIn("dut => dut_signal", text)

    def test_string_default_with_parentheses_and_assignment(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            source.write_text(
                'entity device is generic (text_g : string := "MiX(Ab := C"; '
                "char_g : character := '('); end entity;",
                encoding="latin-1",
            )
            output = root / "tb_device.vhd"
            self.assertEqual(create_testbench.run(source, output), 0)
            text = output.read_text(encoding="latin-1")
            self.assertIn('text_g : string := "MiX(Ab := C"', text)
            self.assertIn("char_g : character := '('", text)

    def test_invalid_inputs_and_existing_output(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "device.vhd"
            output = root / "tb_device.vhd"
            self.assertEqual(create_testbench.run(root / "device.sv", output), 1)
            self.assertEqual(create_testbench.run(source, output), 1)
            source.write_text("entity first is end; entity second is end;", encoding="latin-1")
            self.assertEqual(create_testbench.run(source, output), 1)
            source.write_text("entity device is generic (type element_t); end entity;", encoding="latin-1")
            self.assertEqual(create_testbench.run(source, output), 1)
            source.write_text("entity device is end entity;", encoding="latin-1")
            self.assertEqual(create_testbench.run(source, root / "bad-name.vhd"), 1)
            self.assertEqual(create_testbench.run(source, root / "nested" / "device.vhd"), 1)
            output.write_text("existing", encoding="latin-1")
            self.assertEqual(create_testbench.run(source, output), 1)
            self.assertEqual(output.read_text(encoding="latin-1"), "existing")

    @unittest.skipUnless(shutil.which("ghdl"), "GHDL is not installed")
    def test_generated_testbench_runs_with_vunit(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            package = root / "types_pkg.vhd"
            package.write_text(
                "package types_pkg is constant default_width : positive := 8; end package;", encoding="latin-1"
            )
            source = root / "counter.vhd"
            source.write_text(
                "library ieee;\nuse ieee.std_logic_1164.all;\nuse work.types_pkg.all;\n"
                "entity counter is\n"
                '  generic (width : positive := default_width; label_g : string := "MiXeD");\n'
                "  port (clk : in std_logic; data : out std_logic_vector(width - 1 downto 0));\n"
                "end entity;\n"
                "architecture rtl of counter is begin data <= (others => '0'); end architecture;\n",
                encoding="latin-1",
            )
            testbench = root / "tb_counter.vhd"
            self.assertEqual(
                cli.main(
                    ["create-testbench", "--source", str(source), "--testbench", str(testbench), "--library", "dut_lib"]
                ),
                0,
            )
            script = (
                "import sys\n"
                "from vunit import VUnit\n"
                "vu = VUnit.from_argv(['--output-path', sys.argv[4]])\n"
                "vu.add_vhdl_builtins()\n"
                "dut = vu.add_library('dut_lib')\n"
                "dut.add_source_files(sys.argv[1:3])\n"
                "lib = vu.add_library('lib')\n"
                "lib.add_source_file(sys.argv[3])\n"
                "vu.main()\n"
            )
            result = subprocess.run(
                [sys.executable, "-c", script, str(package), str(source), str(testbench), str(root / "vunit_out")],
                input="",
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env={**os.environ, "VUNIT_SIMULATOR": "ghdl"},
                check=False,
            )
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn("tb_counter.first_test", result.stdout)
            self.assertIn("Tests have yet to be added", result.stdout)


class TestGeneratedScript(unittest.TestCase):
    def test_nonrecursive_and_recursive_patterns_use_matching_sources_and_builtins(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source_dir = root / "src"
            nested = source_dir / "nested"
            nested.mkdir(parents=True)
            (source_dir / "top.vhd").touch()
            (nested / "deep.sv").touch()

            flat = project_generator._make_run_script(root, {"lib": [new._SourceLocation(source_dir)]})
            self.assertIn('lib.add_source_files(root / "src" / "*.vhd")', flat)
            self.assertNotIn('"**"', flat)
            self.assertNotIn("vu.add_verilog_builtins()", flat)
            self.assertNotIn("*.sv", flat)

            recursive = project_generator._make_run_script(root, {"lib": [new._SourceLocation(source_dir, True)]})
            self.assertIn('lib.add_source_files(root / "src" / "**" / "*.vhd")', recursive)
            self.assertIn('lib.add_source_files(root / "src" / "**" / "*.sv")', recursive)
            self.assertIn("vu.add_verilog_builtins()", recursive)

    def test_validation_uses_the_selected_directory_mode(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            nested = root / "src" / "nested"
            nested.mkdir(parents=True)
            (nested / "deep.vhd").touch()
            source_dir = root / "src"
            self.assertFalse(new._validate_project(root, {"lib": [new._SourceLocation(source_dir)]}))
            self.assertTrue(new._validate_project(root, {"lib": [new._SourceLocation(source_dir, True)]}))

    def test_library_sources_and_builtins(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source_dir = root / "src"
            source_dir.mkdir()
            vhdl = source_dir / "design.vhd"
            verilog = source_dir / "test.sv"
            single = root / "common.vhdl"
            vhdl.touch()
            verilog.touch()
            single.touch()
            script = project_generator._make_run_script(
                root,
                {
                    "first": [new._SourceLocation(source_dir, True), new._SourceLocation(single)],
                    "second": [new._SourceLocation(verilog)],
                    "empty": [],
                },
            )
            script_path = root / "run.py"
            script_path.write_text(script, encoding="utf-8")
            self.assertIn('first.add_source_files(root / "src" / "**" / "*.vhd")', script)
            self.assertIn('first.add_source_file(root / "common.vhdl")', script)
            self.assertNotIn("def main", script)
            vu = MagicMock()
            first, second, empty = MagicMock(), MagicMock(), MagicMock()
            vu.add_library.side_effect = [first, second, empty]
            with patch("vunit.VUnit") as vunit:
                vunit.from_argv.return_value = vu
                runpy.run_path(str(script_path))

            self.assertEqual(vu.add_library.call_args_list, [call("first"), call("second"), call("empty")])
            self.assertEqual(
                first.add_source_files.call_args_list,
                [call(source_dir / "**" / "*.sv"), call(source_dir / "**" / "*.vhd")],
            )
            first.add_source_file.assert_called_once_with(single)
            second.add_source_file.assert_called_once_with(verilog)
            empty.add_source_files.assert_not_called()
            vu.add_vhdl_builtins.assert_called_once_with()
            vu.add_verilog_builtins.assert_called_once_with()
            vu.main.assert_called_once_with()

    def test_selects_builtins_and_preserves_extension_case(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source_dir = root / "sources"
            nested_dir = source_dir / "nested"
            nested_dir.mkdir(parents=True)
            (nested_dir / "test.VHD").touch()
            script = project_generator._make_run_script(root, {"lib": [new._SourceLocation(source_dir, True)]})
            self.assertIn('lib.add_source_files(root / "sources" / "**" / "*.VHD")', script)
            self.assertIn("vu.add_vhdl_builtins()", script)
            self.assertNotIn("vu.add_verilog_builtins()", script)

            verilog = root / "test.sv"
            verilog.touch()
            script = project_generator._make_run_script(root, {"lib": [new._SourceLocation(verilog)]})
            self.assertIn("vu.add_verilog_builtins()", script)
            self.assertNotIn("vu.add_vhdl_builtins()", script)

    def test_paths_with_unicode_and_glob_characters_are_added_as_files(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "test [a] \u03b1.vhd"
            source.touch()
            script = project_generator._make_run_script(root, {"lib": [new._SourceLocation(source)]})
            script_path = root / "run.py"
            script_path.write_text(script, encoding="utf-8")
            vu = MagicMock()
            with patch("vunit.VUnit") as vunit:
                vunit.from_argv.return_value = vu
                runpy.run_path(str(script_path))
            vu.add_library.return_value.add_source_file.assert_called_once_with(source)

    def test_different_drive_uses_absolute_path(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source = root / "other.vhd"
            with patch.object(new.os.path, "relpath", side_effect=ValueError):
                expression = project_generator._python_path(source, root)
            self.assertEqual(eval(expression, {"Path": Path}), source)

    def test_empty_library_and_python_identifier_conflicts(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            script = project_generator._make_run_script(root, {"root": [], "root_lib": [], "class": [], "vu": []})
            script_path = root / "run.py"
            script_path.write_text(script, encoding="utf-8")
            vu = MagicMock()
            with patch("vunit.VUnit") as vunit:
                vunit.from_argv.return_value = vu
                runpy.run_path(str(script_path))
            self.assertIn('root_lib_lib = vu.add_library("root")', script)
            self.assertIn('root_lib = vu.add_library("root_lib")', script)
            self.assertIn('class_lib = vu.add_library("class")', script)
            self.assertEqual(vu.add_library.call_count, 4)
            vu.add_vhdl_builtins.assert_not_called()
            vu.add_verilog_builtins.assert_not_called()
            vu.main.assert_called_once_with()

    @unittest.skipUnless(shutil.which("ghdl"), "GHDL is not installed")
    def test_generated_script_runs_vunit_with_recursive_sources(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source_dir = root / "src"
            nested = source_dir / "nested"
            nested.mkdir(parents=True)
            source = root / "common.vhd"
            source.write_text("package common is end package;", encoding="utf-8")
            (nested / "tb_example.vhd").write_text(
                "library vunit_lib;\ncontext vunit_lib.vunit_context;\n"
                "entity tb_example is generic (runner_cfg : string); end entity;\n"
                "architecture tb of tb_example is begin\n"
                "  main : process begin\n"
                "    test_runner_setup(runner, runner_cfg);\n"
                "    while test_suite loop\n"
                '      if run("dummy") then null; end if;\n'
                "    end loop;\n"
                "    test_runner_cleanup(runner);\n"
                "  end process;\n"
                "end architecture;\n",
                encoding="utf-8",
            )
            script_path = root / "run.py"
            script_path.write_text(
                project_generator._make_run_script(
                    root, {"lib": [new._SourceLocation(source_dir, True), new._SourceLocation(source)]}
                ),
                encoding="utf-8",
            )
            env = dict(os.environ, VUNIT_SIMULATOR="ghdl")
            env["PYTHONPATH"] = os.pathsep.join([str(Path(__file__).resolve().parents[2]), env.get("PYTHONPATH", "")])
            result = subprocess.run(
                [sys.executable, str(script_path), "--output-path", str(root / "vunit_out")],
                input="",
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("lib.tb_example.dummy", result.stdout)


class TestPreviewOption(unittest.TestCase):
    """The --preview option shows the generation plan without writing files."""

    @staticmethod
    def _run(arguments):
        output, errors = StringIO(), StringIO()
        with (
            patch("sys.stdout", output),
            patch("sys.stderr", errors),
            patch("builtins.input", side_effect=AssertionError("unexpected prompt")),
        ):
            code = cli.main(arguments)
        return code, output.getvalue(), errors.getvalue()

    @staticmethod
    def _testbench_files(root):
        source = root / "device.vhd"
        source.write_text("entity device is end entity;", encoding="latin-1")
        return source, root / "tb_device.vhd"

    def test_create_testbench_preview_lists_file_and_writes_nothing(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._testbench_files(Path(tempdir))
            code, text, _ = self._run(
                ["create-testbench", "--preview", "--source", str(source), "--testbench", str(output)]
            )
            self.assertEqual(code, 0)
            self.assertIn(f"Files to create:\n  {output}", text)
            self.assertIn("No files written.", text)
            self.assertNotIn("entity tb_device", text)
            self.assertFalse(output.exists())

    def test_create_project_preview_lists_file_and_writes_nothing(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir) / "project"
            code, text, _ = self._run(["create-project", "--preview", "--root", str(root), "--no-sources"])
            self.assertEqual(code, 0)
            self.assertIn(f"Files to create:\n  {root.resolve() / 'run.py'}", text)
            self.assertIn("No files written.", text)
            self.assertFalse(root.exists())

    def test_json_output_is_the_only_stdout_and_parses(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._testbench_files(Path(tempdir))
            code, text, errors = self._run(
                ["create-testbench", "--preview", "--json", "--source", str(source), "--testbench", str(output)]
            )
            self.assertEqual(code, 0)
            self.assertEqual(errors, "")
            self.assertEqual(json.loads(text), {"files": [{"path": str(output), "action": "create"}]})

            root = Path(tempdir) / "project"
            code, text, _ = self._run(["create-project", "--preview", "--json", "--root", str(root), "--no-sources"])
            self.assertEqual(
                json.loads(text), {"files": [{"path": str(root.resolve() / "run.py"), "action": "create"}]}
            )
            self.assertFalse(root.exists())

    def test_show_content_matches_created_files(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source, output = self._testbench_files(root)
            _, text, _ = self._run(
                [
                    "create-testbench",
                    "--preview",
                    "--json",
                    "--show-content",
                    "--source",
                    str(source),
                    "--testbench",
                    str(output),
                ]
            )
            planned = json.loads(text)["files"][0]
            self._run(["create-testbench", "--source", str(source), "--testbench", str(output)])
            self.assertEqual(planned["content"], output.read_text(encoding="latin-1"))

            project = root / "project"
            arguments = ["create-project", "--root", str(project), "--no-sources"]
            _, text, _ = self._run(arguments + ["--preview", "--json", "--show-content"])
            planned = json.loads(text)["files"][0]
            self._run(arguments)
            self.assertEqual(Path(planned["path"]), project.resolve() / "run.py")
            self.assertEqual(planned["content"], (project / "run.py").read_text(encoding="utf-8"))

    def test_show_content_prints_source_in_text_mode(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._testbench_files(Path(tempdir))
            _, text, _ = self._run(
                ["create-testbench", "--preview", "--show-content", "--source", str(source), "--testbench", str(output)]
            )
            self.assertIn("entity tb_device is", text)
            self.assertFalse(output.exists())

    def test_existing_files_are_reported_and_not_modified(self):
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source, output = self._testbench_files(root)
            output.write_text("existing", encoding="utf-8")
            code, text, errors = self._run(
                ["create-testbench", "--preview", "--json", "--source", str(source), "--testbench", str(output)]
            )
            self.assertEqual((code, text), (1, ""))
            self.assertIn("Will not overwrite existing", errors)
            self.assertEqual(output.read_text(encoding="utf-8"), "existing")

            (root / "run.py").write_text("existing", encoding="utf-8")
            code, text, errors = self._run(["create-project", "--preview", "--root", str(root), "--no-sources"])
            self.assertEqual((code, text), (1, ""))
            self.assertIn("Will not overwrite existing", errors)
            self.assertEqual((root / "run.py").read_text(encoding="utf-8"), "existing")

    def test_invalid_configuration_is_an_error(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._testbench_files(Path(tempdir))
            code, text, errors = self._run(
                [
                    "create-testbench",
                    "--preview",
                    "--source",
                    str(source),
                    "--testbench",
                    str(output),
                    "--library",
                    "1x",
                ]
            )
            self.assertEqual((code, text), (1, ""))
            self.assertIn("Invalid source library name", errors)
            code, _, errors = self._run(
                ["create-project", "--preview", "--root", tempdir, "--source", "lib", "missing.vhd"]
            )
            self.assertEqual(code, 1)
            self.assertIn("Error:", errors)

    def test_json_requires_complete_noninteractive_options(self):
        for arguments in (
            ["create-testbench", "--preview", "--json", "--source", "a.vhd"],
            ["create-project", "--preview", "--json"],
            ["create-project", "--preview", "--json", "--root", "."],
            ["create-testbench", "--json"],
            ["create-project", "--show-content"],
        ):
            with self.subTest(arguments=arguments), self.assertRaises(SystemExit) as exc:
                with patch("sys.stderr", StringIO()):
                    cli.main(arguments)
            self.assertEqual(exc.exception.code, 2)

    def test_interactive_preview_never_creates(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._testbench_files(Path(tempdir))
            output_stream = StringIO()
            with (
                patch("sys.stdout", output_stream),
                patch.object(cli_helpers, "_interactive_terminal", return_value=False),
                patch.object(create_testbench, "_choose_action", side_effect=["Preview"]) as choose,
            ):
                code = create_testbench.review(str(source), str(output), "work", cli_helpers.PreviewOptions())
            self.assertEqual(code, 0)
            self.assertNotIn("Create", choose.call_args.args[0])
            self.assertIn("No files written.", output_stream.getvalue())
            self.assertFalse(output.exists())


class TestNamedTests(unittest.TestCase):
    """The tests option of create-testbench."""

    NAMES = ["reset behavior", "write and read", "full and empty"]
    TODO_ERROR = '        -- vunit: .todo\n        error("This test has yet to be implemented");\n'

    @staticmethod
    def _files(root):
        source = root / "device.vhd"
        source.write_text("entity device is end entity;", encoding="latin-1")
        return source, root / "tb_device.vhd"

    @staticmethod
    def _cli(arguments):
        output, errors = StringIO(), StringIO()
        with (
            patch("sys.stdout", output),
            patch("sys.stderr", errors),
            patch("builtins.input", side_effect=AssertionError("unexpected prompt")),
        ):
            code = cli.main(arguments)
        return code, output.getvalue(), errors.getvalue()

    def _config(self, root, tests=None):
        source, output = self._files(root)
        config = {"source": source, "testbench": output}
        if tests is not None:
            config["tests"] = tests
        return config

    @staticmethod
    def _preview_text(config):
        return testbench_generator.preview(config)["files"][0]["content"]

    def test_single_test(self):
        with TemporaryDirectory() as tempdir:
            text = self._preview_text(self._config(Path(tempdir), ["only"]))
        self.assertIn('      if run("only") then\n' + self.TODO_ERROR + "      end if;", text)
        self.assertNotIn("first_test", text)

    def test_multiple_tests_with_whitespace_keep_names_and_order(self):
        with TemporaryDirectory() as tempdir:
            text = self._preview_text(self._config(Path(tempdir), self.NAMES))
        self.assertIn(
            "while test_suite loop\n"
            '      if run("reset behavior") then\n' + self.TODO_ERROR + '      elsif run("write and read") then\n'
            "" + self.TODO_ERROR + '      elsif run("full and empty") then\n' + self.TODO_ERROR + "      end if;\n"
            "    end loop;",
            text,
        )
        self.assertNotIn("first_test", text)

    def test_names_are_preserved_exactly(self):
        names = ["MiXeD Case", "  padded  ", "a,b", "x -- not a comment", "back\\slash", "it's (ok)", "café"]
        with TemporaryDirectory() as tempdir:
            text = self._preview_text(self._config(Path(tempdir), names))
        positions = [text.index(f'run("{name}")') for name in names]
        self.assertEqual(positions, sorted(positions))

    def test_no_tests_generates_first_test(self):
        for tests in (None, []):
            with self.subTest(tests=tests), TemporaryDirectory() as tempdir:
                text = self._preview_text(self._config(Path(tempdir), tests))
            self.assertIn(
                '      if run("first_test") then\n        -- vunit: .todo\n'
                '        error("Tests have yet to be added");\n      end if;',
                text,
            )
            self.assertNotIn("dummy", text)

    def test_invalid_names_are_rejected(self):
        invalid = {
            "empty": [""],
            "whitespace only": ["a", "   "],
            "duplicate": ["a", "b", "a"],
            "double quote": ['say "hi"'],
            "newline": ["a\nb"],
            "tab": ["a\tb"],
            "outside VHDL characters": ["€"],
            "single string": "abc",
        }
        for label, tests in invalid.items():
            with self.subTest(label), TemporaryDirectory() as tempdir:
                config = self._config(Path(tempdir), tests)
                with self.assertRaises(ValueError):
                    testbench_generator.preview(config)
                with self.assertRaises(ValueError):
                    testbench_generator.generate(config)
                self.assertFalse(config["testbench"].exists())

    def test_duplicates_are_case_sensitive(self):
        self.assertEqual(testbench_generator.validate_tests(["a", "A"]), ["a", "A"])

    def test_cli_quoted_arguments_are_separate_tests(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            code, _, _ = self._cli(
                ["create-testbench", "--source", str(source), "--testbench", str(output), "--tests"] + self.NAMES
            )
            text = output.read_text(encoding="latin-1")
        self.assertEqual(code, 0)
        self.assertEqual(text.count("run("), 3)
        self.assertEqual(text.count("-- vunit: .todo"), 3)
        for name in self.NAMES:
            self.assertIn(f'run("{name}")', text)

    def test_cli_tests_alone_prompts_only_for_paths(self):
        with (
            patch.object(create_testbench, "run", return_value=0) as create,
            patch.object(cli, "_ask_testbench_path", side_effect=["source.vhd", "tb.vhd"]),
            patch.object(cli, "_review_testbench", side_effect=AssertionError("unexpected review")),
        ):
            self.assertEqual(cli.main(["create-testbench", "--tests", "a b"]), 0)
        create.assert_called_once_with("source.vhd", "tb.vhd", "work", tests=["a b"])

    def test_cli_requires_a_name_after_tests(self):
        with patch("sys.stderr", StringIO()), self.assertRaises(SystemExit):
            cli.main(["create-testbench", "--source", "a.vhd", "--testbench", "tb.vhd", "--tests"])

    def test_cli_reports_invalid_names_without_creating_files(self):
        for tests in ([""], ["a", "a"], ["  "]):
            with self.subTest(tests=tests), TemporaryDirectory() as tempdir:
                source, output = self._files(Path(tempdir))
                code, text, _ = self._cli(
                    ["create-testbench", "--source", str(source), "--testbench", str(output), "--tests"] + tests
                )
                self.assertEqual(code, 1)
                self.assertIn("Error creating testbench:", text)
                self.assertFalse(output.exists())

    def test_cli_help_documents_tests(self):
        output = StringIO()
        with patch("sys.stdout", output), self.assertRaises(SystemExit):
            cli.main(["create-testbench", "--help"])
        self.assertIn("--tests NAME [NAME ...]", output.getvalue())
        self.assertIn("first_test", output.getvalue())

    def test_preview_matches_generation_and_writes_nothing(self):
        for tests in (self.NAMES, None):
            with self.subTest(tests=tests), TemporaryDirectory() as tempdir:
                root = Path(tempdir)
                source, output = self._files(root)
                options = ["--source", str(source), "--testbench", str(output)]
                if tests:
                    options += ["--tests"] + tests
                code, text, _ = self._cli(["create-testbench", "--preview", "--json", "--show-content"] + options)
                self.assertEqual(code, 0)
                self.assertEqual(list(root.iterdir()), [source])
                content = json.loads(text)["files"][0]["content"]
                self.assertIn("first_test" if tests is None else "reset behavior", content)
                self.assertEqual(self._cli(["create-testbench"] + options)[0], 0)
                self.assertEqual(output.read_text(encoding="latin-1"), content)

    def test_preview_text_output_with_names(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            code, text, _ = self._cli(
                ["create-testbench", "--preview", "--show-content", "--source", str(source), "--testbench", str(output)]
                + ["--tests"]
                + self.NAMES
            )
            self.assertEqual(code, 0)
            self.assertIn('run("write and read")', text)
            self.assertFalse(output.exists())

    def test_json_preview_error_is_on_stderr_only(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            code, text, errors = self._cli(
                ["create-testbench", "--preview", "--json", "--source", str(source), "--testbench", str(output)]
                + ["--tests", "a", "a"]
            )
            self.assertEqual((code, text), (1, ""))
            self.assertIn("Duplicate test name", errors)

    def test_existing_file_is_still_protected(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            output.write_text("keep", encoding="latin-1")
            code, _, _ = self._cli(
                ["create-testbench", "--source", str(source), "--testbench", str(output), "--tests", "a"]
            )
            self.assertEqual(code, 1)
            self.assertEqual(output.read_text(encoding="latin-1"), "keep")

    def test_interactive_default_generates_first_test(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            with (
                patch.object(create_testbench, "_choose_action", side_effect=["Create"]),
                patch("sys.stdout", StringIO()) as stdout,
            ):
                self.assertEqual(create_testbench.review(str(source), str(output), "work"), 0)
            self.assertIn("Tests: first_test (default)", stdout.getvalue())
            self.assertIn('run("first_test")', output.read_text(encoding="latin-1"))

    def test_interactive_add_and_remove_tests(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            actions = ["Add test"] * 5 + ["Remove test"] * 3 + ["Create"]
            answers = [
                "reset behavior",
                "write and read",
                "write and read",  # duplicate, rejected
                "   ",  # whitespace only, rejected
                "full and empty",
                "2",  # remove by number: write and read
                "nonexistent",  # rejected
                "full and empty",  # remove by name
            ]
            with (
                patch.object(create_testbench, "_choose_action", side_effect=actions),
                patch.object(create_testbench, "_ask", side_effect=answers),
                patch("sys.stdout", StringIO()) as stdout,
            ):
                self.assertEqual(create_testbench.review(str(source), str(output), "work"), 0)
            text = output.read_text(encoding="latin-1")
            self.assertEqual(text.count("run("), 1)
            self.assertIn('run("reset behavior")', text)
            self.assertIn("Duplicate test name", stdout.getvalue())
            self.assertIn("must not be empty", stdout.getvalue())
            self.assertIn("no such test: nonexistent", stdout.getvalue())

    def test_interactive_remove_without_tests_is_reported(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            with (
                patch.object(create_testbench, "_choose_action", side_effect=["Remove test", "Create"]),
                patch("sys.stdout", StringIO()) as stdout,
            ):
                self.assertEqual(create_testbench.review(str(source), str(output), "work"), 0)
            self.assertIn("There are no tests to remove.", stdout.getvalue())
            self.assertIn('run("first_test")', output.read_text(encoding="latin-1"))

    def test_interactive_preview_matches_created_file(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            with (
                patch.object(create_testbench, "_choose_action", side_effect=["Add test", "Preview", "Create"]),
                patch.object(create_testbench, "_ask", return_value="reset behavior"),
                patch("sys.stdout", StringIO()) as stdout,
            ):
                self.assertEqual(create_testbench.review(str(source), str(output), "work"), 0)
            created = output.read_text(encoding="latin-1")
            self.assertIn(created, stdout.getvalue())
            self.assertIn('run("reset behavior")', created)

    def test_review_with_preview_options_keeps_tests_and_writes_nothing(self):
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            with (
                patch.object(create_testbench, "_choose_action", side_effect=["Preview"]),
                patch("sys.stdout", StringIO()) as stdout,
            ):
                code = create_testbench.review(
                    str(source), str(output), "work", cli_helpers.PreviewOptions(show_content=True), tests=self.NAMES
                )
            self.assertEqual(code, 0)
            self.assertIn('run("full and empty")', stdout.getvalue())
            self.assertFalse(output.exists())

    @unittest.skipUnless(shutil.which("ghdl"), "GHDL is not installed")
    def test_vunit_discovers_attributes_fails_and_filters_unfinished_tests(self):
        names = self.NAMES + ["a,b", "mixed -- Case"]
        with TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            source, output = self._files(root)
            source.write_text(
                "entity device is end entity;\narchitecture a of device is begin end;\n", encoding="latin-1"
            )
            code, _, _ = self._cli(
                ["create-testbench", "--source", str(source), "--testbench", str(output), "--tests"] + names
            )
            self.assertEqual(code, 0)
            script = (
                "import sys\n"
                "from vunit import VUnit\n"
                "vu = VUnit.from_argv(sys.argv[4:] + ['--output-path', sys.argv[3]])\n"
                "vu.add_vhdl_builtins()\n"
                "lib = vu.add_library('lib')\n"
                "lib.add_source_files(sys.argv[1:3])\n"
                "vu.main()\n"
            )

            def run_vunit(*arguments):
                return subprocess.run(
                    [sys.executable, "-c", script, str(source), str(output), str(root / "out"), *arguments],
                    input="",
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    env={**os.environ, "VUNIT_SIMULATOR": "ghdl"},
                    check=False,
                )

            export = root / "export.json"
            run_vunit("--export-json", str(export), "--list")
            tests = {item["name"]: item["attributes"] for item in json.loads(export.read_text())["tests"]}
            self.assertEqual(tests, {f"lib.tb_device.{name}": {".todo": None} for name in names})
            result = run_vunit("--no-color")
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn(f"fail {len(names)} of {len(names)}", result.stdout)
            self.assertIn("This test has yet to be implemented", result.stdout)
            result = run_vunit("--no-color", "--without-attributes", ".todo")
            self.assertNotIn("Starting", result.stdout)

    def test_interactive_enter_on_first_prompt_finishes_with_placeholder_only(self):
        with patch("builtins.input", side_effect=[""]) as read:
            self.assertEqual(create_testbench.ask_tests(), [])
        self.assertEqual(read.call_args_list, [call("> Add test name [first_test]: ")])

    def test_interactive_prompts_collect_names_and_reprompt_on_errors(self):
        answers = ["reset behavior", "reset behavior", "write and read", ""]
        with patch("builtins.input", side_effect=answers), patch("sys.stdout", StringIO()) as stdout:
            self.assertEqual(create_testbench.ask_tests(), ["reset behavior", "write and read"])
        self.assertIn("Duplicate test name", stdout.getvalue())

    def test_interactive_prompts_can_enter_names_and_review_can_remove_one(self):
        with patch("builtins.input", side_effect=["first_test_a", "second", ""]):
            tests = create_testbench.ask_tests()
        self.assertEqual(tests, ["first_test_a", "second"])
        with TemporaryDirectory() as tempdir:
            source, output = self._files(Path(tempdir))
            with (
                patch.object(create_testbench, "_choose_action", side_effect=["Remove test", "Create"]),
                patch.object(create_testbench, "_ask", return_value="1"),
                patch("sys.stdout", StringIO()),
            ):
                self.assertEqual(create_testbench.review(str(source), str(output), "work", tests=tests), 0)
            text = output.read_text(encoding="latin-1")
            self.assertNotIn("first_test_a", text)
            self.assertIn('run("second")', text)
