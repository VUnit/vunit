# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the machine-readable VHDL and Python API reference generator.

Uses small, inline vhdl-dump-ast syntax trees (no vhdl-dump-ast binary
invoked -- unit CI has no cargo toolchain) and a small Python module
defined in this file (no Sphinx build). The tree shapes mirror what
"vhdl-dump-ast --trivia --no-pretty" actually produces, verified by hand
against real output from vunit/vhdl/**/src/*.vhd during implementation.
"""

import copy
import sys
import unittest
from pathlib import Path

from tools import build_api_reference as bar

# ---------------------------------------------------------------------------
# Tiny syntax-tree builders, matching vhdl-dump-ast's JSON shape:
#   Node:  {"Node": {"kind": ..., "children": [...]}}
#   Token: {"Token": {"kind": ..., "text": ..., "leading_trivia": [...]}}
# ---------------------------------------------------------------------------

SPACE = [{"Spaces": 1}]
NONE = []


def node(kind, *children):
    return {"Node": {"kind": kind, "children": list(children)}}


def token(kind, text, trivia=SPACE):
    return {"Token": {"kind": kind, "text": text, "leading_trivia": copy.deepcopy(trivia)}}


def kw(name, trivia=SPACE):
    """A keyword token, e.g. kw("Procedure") -> Token({"Keyword": "Procedure"}, "procedure")."""
    return token({"Keyword": name}, name.lower(), trivia)


def ident(text, trivia=SPACE):
    return token("Identifier", text, trivia)


def op_name(text, trivia=SPACE):
    return token("StringLiteral", f'"{text}"', trivia)


def punct(kind, text, trivia=NONE):
    return token(kind, text, trivia)


def identifier_list(*names, first_trivia=SPACE):
    kids = []
    for i, name in enumerate(names):
        kids.append(ident(name, trivia=first_trivia if i == 0 else NONE))
        if i < len(names) - 1:
            kids.append(punct("Comma", ","))
    return node("IdentifierList", *kids)


def simple_name(text, trivia=SPACE):
    return node("Name", node("NameDesignatorPrefix", ident(text, trivia)))


def subtype(name, *extra, trivia=SPACE):
    return node("SubtypeIndication", simple_name(name, trivia), *extra)


def initial_value(expr, trivia=SPACE):
    return node("InitialValue", punct("ColonEq", ":=", trivia), expr)


def literal(text, literal_kind="AbstractLiteral", trivia=SPACE):
    return node("LiteralExpression", token(literal_kind, text, trivia))


def parameter(names, subtype_node, class_kw=None, mode_kw=None, default=None, is_file=False):
    kids = []
    if class_kw is not None:
        kids.append(kw(class_kw))
    id_list_trivia = NONE if class_kw is not None else SPACE
    kids.append(
        identifier_list(*names, first_trivia=id_list_trivia)
        if isinstance(names, (list, tuple))
        else identifier_list(names, first_trivia=id_list_trivia)
    )
    kids.append(punct("Colon", ":", SPACE))
    if mode_kw is not None:
        kids.append(kw(mode_kw))
    kids.append(subtype_node)
    if default is not None:
        kids.append(default)
    return node("InterfaceFileDeclaration" if is_file else "InterfaceObjectDeclaration", *kids)


def parameter_list(*params):
    if not params:
        return None
    kids = []
    for i, param in enumerate(params):
        kids.append(param)
        if i < len(params) - 1:
            kids.append(punct("SemiColon", ";"))
    return node(
        "ParameterList",
        node(
            "ParenthesizedInterfaceList",
            punct("LeftPar", "(", SPACE),
            node("InterfaceList", *kids),
            punct("RightPar", ")", NONE),
        ),
    )


def procedure_decl(name, params=(), doc_trivia=NONE, operator=False):
    name_tok = op_name(name) if operator else ident(name)
    kids = [kw("Procedure", trivia=doc_trivia)]
    kids.append(name_tok)
    plist = parameter_list(*params)
    if plist is not None:
        kids.append(plist)
    spec = node("ProcedureSpecification", *kids)
    return node("SubprogramDeclaration", spec, punct("SemiColon", ";"))


def function_decl(name, params=(), return_type="natural", impure=False, doc_trivia=NONE, operator=False):
    name_tok = op_name(name) if operator else ident(name)
    kids = []
    if impure:
        kids.append(kw("Impure", trivia=doc_trivia))
        kids.append(kw("Function"))
    else:
        kids.append(kw("Function", trivia=doc_trivia))
    kids.append(name_tok)
    plist = parameter_list(*params)
    if plist is not None:
        kids.append(plist)
    kids.append(kw("Return"))
    kids.append(simple_name(return_type))
    spec = node("FunctionSpecification", *kids)
    return node("SubprogramDeclaration", spec, punct("SemiColon", ";"))


def alias_decl(name, target, signature_types=(), return_type=None, has_signature=False):
    kids = [kw("Alias"), ident(name), kw("Is"), simple_name(target)]
    if has_signature:
        type_mark_kids = []
        for i, t in enumerate(signature_types):
            type_mark_kids.append(simple_name(t, trivia=SPACE if i == 0 else NONE))
            if i < len(signature_types) - 1:
                type_mark_kids.append(punct("Comma", ","))
        if return_type is not None:
            type_mark_kids.append(node("ReturnType", kw("Return"), simple_name(return_type)))
        sig_kids = [
            punct("LeftSquare", "[", SPACE),
            node("TypeMarkList", *type_mark_kids),
            punct("RightSquare", "]", NONE),
        ]
        kids.append(node("Signature", *sig_kids))
    kids.append(punct("SemiColon", ";"))
    return node("AliasDeclaration", *kids)


def constant_decl(names, subtype_node, default=None, doc_trivia=NONE):
    kids = [
        kw("Constant", trivia=doc_trivia),
        identifier_list(*names) if isinstance(names, (list, tuple)) else identifier_list(names),
    ]
    kids.append(punct("Colon", ":", SPACE))
    kids.append(subtype_node)
    if default is not None:
        kids.append(default)
    kids.append(punct("SemiColon", ";"))
    return node("ConstantDeclaration", *kids)


def subtype_decl(name, subtype_node, doc_trivia=NONE):
    return node(
        "SubtypeDeclaration",
        kw("Subtype", trivia=doc_trivia),
        ident(name),
        kw("Is"),
        subtype_node,
        punct("SemiColon", ";"),
    )


def object_decl(decl_kind, names, subtype_node, doc_trivia=NONE, shared=False):
    kids = []
    if shared:
        kids.append(kw("Shared", trivia=doc_trivia))
        kids.append(kw("Variable"))
    else:
        first_kw = {"SignalDeclaration": "Signal", "VariableDeclaration": "Variable", "FileDeclaration": "File"}[
            decl_kind
        ]
        kids.append(kw(first_kw, trivia=doc_trivia))
    kids.append(identifier_list(*names) if isinstance(names, (list, tuple)) else identifier_list(names))
    kids.append(punct("Colon", ":", SPACE))
    kids.append(subtype_node)
    kids.append(punct("SemiColon", ";"))
    return node(decl_kind, *kids)


def full_type_decl(name, def_node, doc_trivia=NONE):
    return node(
        "FullTypeDeclaration", kw("Type", trivia=doc_trivia), ident(name), kw("Is"), def_node, punct("SemiColon", ";")
    )


def record_element(names, subtype_node):
    kids = [
        identifier_list(*names) if isinstance(names, (list, tuple)) else identifier_list(names),
        punct("Colon", ":", SPACE),
        subtype_node,
        punct("SemiColon", ";"),
    ]
    return node("ElementDeclaration", *kids)


def record_type(*elements):
    return node(
        "RecordTypeDefinition",
        node("RecordTypeDefinitionPreamble", kw("Record")),
        node("RecordElementDeclarations", *elements),
        node("RecordTypeDefinitionEpilogue", kw("End"), kw("Record")),
    )


def enumeration_type(*literals):
    list_kids = []
    for i, lit in enumerate(literals):
        lit_kind = "CharacterLiteral" if lit.startswith("'") else "Identifier"
        list_kids.append(token(lit_kind, lit, trivia=SPACE if i == 0 else NONE))
        if i < len(literals) - 1:
            list_kids.append(punct("Comma", ","))
    return node(
        "EnumerationTypeDefinition",
        punct("LeftPar", "(", SPACE),
        node("EnumerationList", *list_kids),
        punct("RightPar", ")", NONE),
    )


def protected_type(*members):
    return node(
        "ProtectedTypeDeclaration",
        node("ProtectedPreamble", kw("Protected")),
        node("ProtectedTypeDeclarativePart", *members),
    )


def other_type(*tokens_or_nodes):
    return node("UnboundedArrayDefinition", *tokens_or_nodes)


def package_tree(name, decls=(), preamble_trivia=NONE, name_body=""):
    preamble = node("PackagePreamble", kw("Package", trivia=preamble_trivia), ident(name), kw("Is"))
    decl_part = node("PackageDeclarativePart", *decls)
    epilogue = node("PackageEpilogue", kw("End"), kw("Package"), punct("SemiColon", ";"))
    pkg = node("PackageDeclaration", preamble, decl_part, epilogue)
    return {"kind": "DesignFile", "children": [pkg]}


def comment_trivia(*lines, blank_before=False, leading=SPACE):
    """leading_trivia for a token immediately preceded by one or more '--' comment lines."""
    trivia = []
    if blank_before:
        trivia.append({"LineFeeds": 2})
    for i, line in enumerate(lines):
        if i > 0:
            trivia.append({"LineFeeds": 1})
        trivia.append({"LineComment": {"encoding": "utf-8", "value": list(f"-- {line}".encode())}})
    trivia.append({"LineFeeds": 1})
    trivia.extend(leading)
    return trivia


# ---------------------------------------------------------------------------
# Low-level helpers: text_of, doc comments, line numbers
# ---------------------------------------------------------------------------


class TestTextOf(unittest.TestCase):
    def test_joins_tokens_with_space_only_where_trivia_present(self):
        # "natural range 0 to 3" -- every token here is separated by a real space
        tree = subtype(
            "natural",
            node("RangeConstraint", kw("Range"), node("BinaryExpression", literal("0"), kw("To"), literal("3"))),
        )
        self.assertEqual(bar.text_of(tree), "natural range 0 to 3")

    def test_dotted_name_has_no_spaces(self):
        # "ieee.numeric_bit.unsigned" -- dots and following identifiers carry no leading trivia
        tree = node(
            "Name",
            node("NameDesignatorPrefix", ident("ieee")),
            node("SelectedName", punct("Dot", ".", NONE), token("Identifier", "numeric_bit", NONE)),
            node("SelectedName", punct("Dot", ".", NONE), token("Identifier", "unsigned", NONE)),
        )
        self.assertEqual(bar.text_of(tree), "ieee.numeric_bit.unsigned")

    def test_joins_multiple_elements(self):
        a = node("Node", ident("a"))
        b = node("Node", ident("b", trivia=SPACE))
        self.assertEqual(bar.text_of(a, b), "a b")


class TestDocComments(unittest.TestCase):
    def test_comment_block_directly_above(self):
        decl = procedure_decl("p", doc_trivia=comment_trivia("Returns the length", "of the queue"))
        self.assertEqual(bar.leading_doc(decl), "Returns the length\nof the queue")

    def test_blank_line_ends_the_block(self):
        decl = procedure_decl("p", doc_trivia=comment_trivia("Unrelated comment", blank_before=True))
        # A blank line right after the comment (before the declaration) means
        # there is no comment directly above: nothing left after the reset.
        trivia = [
            {"LineComment": {"encoding": "utf-8", "value": list(b"-- Unrelated comment")}},
            {"LineFeeds": 2},
        ] + SPACE
        decl = procedure_decl("p", doc_trivia=trivia)
        self.assertIsNone(bar.leading_doc(decl))

    def test_no_comment_gives_none(self):
        decl = procedure_decl("p")
        self.assertIsNone(bar.leading_doc(decl))

    def test_license_header_excluded_from_package_doc(self):
        preamble_trivia = comment_trivia(
            "This Source Code Form is subject to the terms of the Mozilla Public", "License, v. 2.0."
        )
        preamble = node("PackagePreamble", kw("Package", trivia=preamble_trivia), ident("my_pkg"), kw("Is"))
        self.assertIsNone(bar.package_doc(preamble))

    def test_non_license_comment_kept_for_package_doc(self):
        preamble_trivia = comment_trivia("A package for testing")
        preamble = node("PackagePreamble", kw("Package", trivia=preamble_trivia), ident("my_pkg"), kw("Is"))
        self.assertEqual(bar.package_doc(preamble), "A package for testing")


class TestLineNumbers(unittest.TestCase):
    def test_line_advances_on_line_feeds(self):
        tree = {
            "kind": "DesignFile",
            "children": [
                node(
                    "X",
                    ident("a", trivia=NONE),
                    ident("b", trivia=[{"LineFeeds": 1}]),
                    ident("c", trivia=[{"LineFeeds": 2}]),
                ),
            ],
        }
        lines = bar.annotate_lines(tree)
        toks = list(bar._tokens(tree))
        self.assertEqual([lines[id(bar.token_of(t))] for t in toks], [1, 2, 4])

    def test_line_number_of_declaration_name(self):
        decl = procedure_decl("p", doc_trivia=[{"LineFeeds": 3}] + SPACE)
        tree = package_tree("my_pkg", decls=[decl])
        lines = bar.annotate_lines(tree)
        pkg = bar.find_all(tree, "PackageDeclaration")[0]
        package = bar.convert_package(pkg, lines, "f.vhd", "f.vhd")
        self.assertEqual(package["subprograms"][0]["line"], 4)


# ---------------------------------------------------------------------------
# Subprograms
# ---------------------------------------------------------------------------


class TestConvertSubprogram(unittest.TestCase):
    def _lines_for(self, tree):
        return bar.annotate_lines(tree)

    def test_procedure_has_no_pure_flag(self):
        decl = procedure_decl("proc_set", params=[parameter(["target"], subtype("rec_t"))])
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        self.assertEqual(entry["kind"], "procedure")
        self.assertIsNone(entry["pure"])
        self.assertFalse(entry["operator"])
        self.assertEqual(entry["parameters"][0]["type"], "rec_t")
        self.assertEqual(entry["parameters"][0]["class"], "constant")
        self.assertEqual(entry["parameters"][0]["mode"], "in")

    def test_function_pure_flag_and_return_type(self):
        for impure, expected_pure in ((True, False), (False, True)):
            with self.subTest(impure=impure):
                decl = function_decl(
                    "func_get", params=[parameter(["target"], subtype("rec_t"))], return_type="integer", impure=impure
                )
                tree = {"kind": "DesignFile", "children": [decl]}
                entry = bar.convert_subprogram(decl, self._lines_for(tree))
                self.assertEqual(entry["kind"], "function")
                self.assertEqual(entry["pure"], expected_pure)
                self.assertEqual(entry["return_type"], "integer")

    def test_operator_identifier_is_flagged(self):
        decl = function_decl("+", params=[parameter(["l", "r"], subtype("rec_t"))], return_type="rec_t", operator=True)
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        self.assertTrue(entry["operator"])
        self.assertEqual(entry["name"], "+")
        self.assertEqual(len(entry["parameters"]), 2)

    def test_parameter_default_value(self):
        default = initial_value(literal("0"))
        decl = procedure_decl(
            "proc_set", params=[parameter(["value"], subtype("integer"), mode_kw="In", default=default)]
        )
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        self.assertEqual(entry["parameters"][0]["default"], "0")

    def test_signal_and_variable_parameter_classes(self):
        params = [
            parameter(["net"], subtype("t"), class_kw="Signal", mode_kw="Inout"),
            parameter(["pass_"], subtype("boolean"), class_kw="Variable", mode_kw="Out"),
        ]
        decl = procedure_decl("p", params=params)
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        self.assertEqual(entry["parameters"][0]["class"], "signal")
        self.assertEqual(entry["parameters"][0]["mode"], "inout")
        self.assertEqual(entry["parameters"][1]["class"], "variable")

    def test_out_mode_defaults_to_variable_class(self):
        # VHDL rule: an omitted object class defaults to "constant" for mode
        # "in", but to "variable" for "out"/"inout".
        decl = procedure_decl("p", params=[parameter(["stat"], subtype("checker_stat_t"), mode_kw="Out")])
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        self.assertEqual(entry["parameters"][0]["class"], "variable")
        self.assertEqual(entry["parameters"][0]["mode"], "out")

    def test_file_parameter(self):
        decl = procedure_decl("setup", params=[parameter(["f"], subtype("text"), is_file=True)])
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        param = entry["parameters"][0]
        self.assertEqual(param["class"], "file")
        self.assertEqual(param["mode"], "inout")

    def test_multi_identifier_parameter_shares_one_type(self):
        decl = procedure_decl(
            "notify",
            params=[parameter(["event1", "event2"], subtype("any_event_t"), class_kw="Signal", mode_kw="Inout")],
        )
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        self.assertEqual([p["name"] for p in entry["parameters"]], ["event1", "event2"])
        self.assertEqual([p["type"] for p in entry["parameters"]], ["any_event_t", "any_event_t"])

    def test_constrained_parameter_type(self):
        subtype_node = subtype(
            "std_logic_vector",
            node(
                "ConstraintExpression",
                punct("LeftPar", "(", NONE),
                literal("7", trivia=NONE),
                kw("Downto"),
                literal("0"),
                punct("RightPar", ")", NONE),
            ),
        )
        decl = procedure_decl("p", params=[parameter(["data"], subtype_node)])
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        self.assertEqual(entry["parameters"][0]["type"], "std_logic_vector(7 downto 0)")

    def test_doc_comment(self):
        decl = procedure_decl("p", doc_trivia=comment_trivia("Does a thing."))
        tree = {"kind": "DesignFile", "children": [decl]}
        entry = bar.convert_subprogram(decl, self._lines_for(tree))
        self.assertEqual(entry["doc"], "Does a thing.")


# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------


class TestConvertAlias(unittest.TestCase):
    def _entry(self, decl):
        tree = {"kind": "DesignFile", "children": [decl]}
        return bar.convert_alias(decl, bar.annotate_lines(tree))[0]

    def test_subprogram_alias_with_signature_and_return_type(self):
        decl = alias_decl("alias_get", "func_get", signature_types=["rec_t"], return_type="integer", has_signature=True)
        entry = self._entry(decl)
        self.assertEqual(entry["name"], "alias_get")
        self.assertEqual(entry["target"], "func_get")
        self.assertEqual(entry["signature"], ["rec_t"])
        self.assertEqual(entry["return_type"], "integer")

    def test_procedure_alias_has_no_return_type(self):
        decl = alias_decl("alias_set", "proc_set", signature_types=["rec_t", "integer"], has_signature=True)
        entry = self._entry(decl)
        self.assertEqual(entry["signature"], ["rec_t", "integer"])
        self.assertIsNone(entry["return_type"])

    def test_type_alias_has_no_signature(self):
        decl = alias_decl("null_vec_ptr", "null_ptr")
        entry = self._entry(decl)
        self.assertEqual(entry["target"], "null_ptr")
        self.assertEqual(entry["signature"], [])
        self.assertIsNone(entry["return_type"])


# ---------------------------------------------------------------------------
# Types, subtypes, constants, objects
# ---------------------------------------------------------------------------


class TestConvertType(unittest.TestCase):
    def _entry(self, decl):
        tree = {"kind": "DesignFile", "children": [decl]}
        return bar.convert_type(decl, bar.annotate_lines(tree), "f.vhd")[0]

    def test_record_type(self):
        decl = full_type_decl("rec_t", record_type(record_element(["a"], subtype("integer"))))
        entry = self._entry(decl)
        self.assertEqual(entry["kind"], "record")
        self.assertEqual(entry["elements"], [{"name": "a", "type": "integer"}])

    def test_record_type_multiple_identifiers_per_element(self):
        decl = full_type_decl("rec_t", record_type(record_element(["a", "b"], subtype("integer"))))
        entry = self._entry(decl)
        self.assertEqual(entry["elements"], [{"name": "a", "type": "integer"}, {"name": "b", "type": "integer"}])

    def test_enumeration_type(self):
        decl = full_type_decl("color_t", enumeration_type("red", "green", "blue"))
        entry = self._entry(decl)
        self.assertEqual(entry["kind"], "enumeration")
        self.assertEqual(entry["literals"], ["red", "green", "blue"])

    def test_protected_type_with_methods(self):
        method = procedure_decl("set", params=[parameter(["value"], subtype("integer"))])
        decl = full_type_decl("protected_t", protected_type(method))
        entry = self._entry(decl)
        self.assertEqual(entry["kind"], "protected")
        self.assertEqual(len(entry["subprograms"]), 1)
        self.assertEqual(entry["subprograms"][0]["name"], "set")
        self.assertIsNone(entry["subprograms"][0]["doc"])

    def test_protected_type_method_doc(self):
        method = procedure_decl(
            "set", params=[parameter(["value"], subtype("integer"))], doc_trivia=comment_trivia("Sets the value.")
        )
        decl = full_type_decl("protected_t", protected_type(method))
        entry = self._entry(decl)
        self.assertEqual(entry["subprograms"][0]["doc"], "Sets the value.")

    def test_protected_type_unhandled_member_raises(self):
        bogus_member = node("ConstantDeclaration", kw("Constant"), ident("x"), punct("SemiColon", ";"))
        decl = full_type_decl("protected_t", protected_type(bogus_member))
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            self._entry(decl)
        self.assertIn("ConstantDeclaration", str(ctx.exception))

    def test_other_types(self):
        array_def = other_type(
            kw("Array"),
            punct("LeftPar", "(", SPACE),
            kw("Natural", trivia=NONE),
            kw("Range"),
            punct("Box", "<>", SPACE),
            punct("RightPar", ")", NONE),
            kw("Of"),
            simple_name("rec_t"),
        )
        decl = full_type_decl("vec_t", array_def)
        entry = self._entry(decl)
        self.assertEqual(entry["kind"], "other")
        self.assertEqual(entry["definition"], "array (natural range <>) of rec_t")


class TestConvertSubtypeConstantObject(unittest.TestCase):
    def _lines(self, decl):
        return bar.annotate_lines({"kind": "DesignFile", "children": [decl]})

    def test_subtype(self):
        rng = node("RangeConstraint", kw("Range"), node("BinaryExpression", literal("0"), kw("To"), literal("15")))
        decl = subtype_decl("small_t", subtype("integer", rng))
        entry = bar.convert_subtype(decl, self._lines(decl))[0]
        self.assertEqual(entry["definition"], "integer range 0 to 15")

    def test_constant_with_value(self):
        decl = constant_decl(["c_max"], subtype("integer"), default=initial_value(literal("15")))
        entry = bar.convert_constant(decl, self._lines(decl))[0]
        self.assertEqual(entry["type"], "integer")
        self.assertEqual(entry["value"], "15")

    def test_deferred_constant_has_no_value(self):
        decl = constant_decl(["c_deferred"], subtype("boolean"))
        entry = bar.convert_constant(decl, self._lines(decl))[0]
        self.assertIsNone(entry["value"])

    def test_constant_multiple_identifiers(self):
        decl = constant_decl(["a", "b"], subtype("integer"), default=initial_value(literal("1")))
        entries = bar.convert_constant(decl, self._lines(decl))
        self.assertEqual([e["name"] for e in entries], ["a", "b"])
        self.assertEqual([e["value"] for e in entries], ["1", "1"])

    def test_objects(self):
        for decl_kind, object_class, shared in (
            ("SignalDeclaration", "signal", False),
            ("VariableDeclaration", "shared variable", True),
            ("FileDeclaration", "file", False),
        ):
            with self.subTest(kind=decl_kind):
                decl = object_decl(decl_kind, ["x"], subtype("std_logic"), shared=shared)
                entry = bar.convert_object(decl, self._lines(decl))[0]
                self.assertEqual(entry["class"], object_class)
                self.assertEqual(entry["type"], "std_logic")

    def test_doc_comment_on_constant(self):
        decl = constant_decl(["c"], subtype("integer"), doc_trivia=comment_trivia("A constant."))
        entry = bar.convert_constant(decl, self._lines(decl))[0]
        self.assertEqual(entry["doc"], "A constant.")


# ---------------------------------------------------------------------------
# Package assembly
# ---------------------------------------------------------------------------


class TestConvertPackage(unittest.TestCase):
    def test_private_package_flag(self):
        for name, private in (("data_types_private_pkg", True), ("queue_pkg", False)):
            with self.subTest(name=name):
                tree = package_tree(name)
                lines = bar.annotate_lines(tree)
                pkg_node = bar.find_all(tree, "PackageDeclaration")[0]
                package = bar.convert_package(pkg_node, lines, "f.vhd", "f.vhd")
                self.assertEqual(package["private"], private)

    def test_p_prefixed_names_not_flagged_private(self):
        decl = constant_decl(["p_internal"], subtype("integer"), default=initial_value(literal("1")))
        tree = package_tree("queue_pkg", decls=[decl])
        lines = bar.annotate_lines(tree)
        pkg_node = bar.find_all(tree, "PackageDeclaration")[0]
        package = bar.convert_package(pkg_node, lines, "f.vhd", "f.vhd")
        self.assertFalse(package["private"])
        self.assertEqual(package["constants"][0]["name"], "p_internal")

    def test_unhandled_declaration_kind_raises(self):
        bogus = node("ComponentDeclaration", ident("c"), punct("SemiColon", ";"))
        tree = package_tree("my_pkg", decls=[bogus])
        lines = bar.annotate_lines(tree)
        pkg_node = bar.find_all(tree, "PackageDeclaration")[0]
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.convert_package(pkg_node, lines, "/a/my_pkg.vhd", "my_pkg.vhd")
        self.assertIn("ComponentDeclaration", str(ctx.exception))
        self.assertIn("/a/my_pkg.vhd", str(ctx.exception))

    def test_declarations_land_in_the_right_bucket(self):
        decls = [
            procedure_decl("p"),
            alias_decl("a", "p"),
            constant_decl(["c"], subtype("integer"), default=initial_value(literal("1"))),
            subtype_decl("s", subtype("integer")),
            full_type_decl("t", enumeration_type("a")),
            object_decl("SignalDeclaration", ["sig"], subtype("std_logic")),
        ]
        tree = package_tree("my_pkg", decls=decls)
        lines = bar.annotate_lines(tree)
        pkg_node = bar.find_all(tree, "PackageDeclaration")[0]
        package = bar.convert_package(pkg_node, lines, "f.vhd", "f.vhd")
        self.assertEqual(len(package["subprograms"]), 1)
        self.assertEqual(len(package["aliases"]), 1)
        self.assertEqual(len(package["constants"]), 1)
        self.assertEqual(len(package["subtypes"]), 1)
        self.assertEqual(len(package["types"]), 1)
        self.assertEqual(len(package["objects"]), 1)

    def test_package_doc(self):
        tree = package_tree("my_pkg", preamble_trivia=comment_trivia("A package for testing"))
        lines = bar.annotate_lines(tree)
        pkg_node = bar.find_all(tree, "PackageDeclaration")[0]
        package = bar.convert_package(pkg_node, lines, "f.vhd", "f.vhd")
        self.assertEqual(package["doc"], "A package for testing")


class TestConvertPackageFile(unittest.TestCase):
    def test_finds_package_by_name_and_sets_source(self):
        tree = package_tree("queue_pkg")
        package = bar.convert_package_file(
            tree,
            Path("/repo/vunit/vhdl/data_types/src/queue_pkg.vhd"),
            "queue_pkg",
            "vunit/vhdl/data_types/src/queue_pkg.vhd",
        )
        self.assertIsNotNone(package)
        self.assertEqual(package["name"], "queue_pkg")
        self.assertEqual(package["source"], "vunit/vhdl/data_types/src/queue_pkg.vhd")
        self.assertEqual(package["library"], "vunit_lib")

    def test_missing_package_returns_none(self):
        tree = package_tree("queue_pkg")
        package = bar.convert_package_file(tree, Path("/repo/f.vhd"), "other_pkg", "f.vhd")
        self.assertIsNone(package)


# ---------------------------------------------------------------------------
# Package scope, completeness
# ---------------------------------------------------------------------------


class TestPackageScope(unittest.TestCase):
    def _make_tree(self, tmp_path, files):
        for relpath, content in files.items():
            path = tmp_path / relpath
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def test_finds_package_declaration_files(self):
        tmp_path = Path(self._tmp_dir())
        self._make_tree(tmp_path, {"vunit/vhdl/data_types/src/queue_pkg.vhd": "package queue_pkg is\nend package;\n"})
        found = bar.find_package_files(tmp_path)
        self.assertEqual([name for _, name in found], ["queue_pkg"])

    def test_excludes_package_body(self):
        tmp_path = Path(self._tmp_dir())
        self._make_tree(
            tmp_path,
            {
                "vunit/vhdl/foo/src/foo_pkg.vhd": "package foo_pkg is\nend package;\npackage body foo_pkg is\nend package body;\n"
            },
        )
        found = bar.find_package_files(tmp_path)
        self.assertEqual([name for _, name in found], ["foo_pkg"])

    def test_excludes_package_instantiation(self):
        tmp_path = Path(self._tmp_dir())
        self._make_tree(
            tmp_path,
            {
                "vunit/vhdl/foo/src/foo_pkg.vhd": (
                    "package foo_generic_pkg is\nend package;\n"
                    "package foo_pkg is new work.foo_generic_pkg generic map (t => integer);\n"
                )
            },
        )
        found = bar.find_package_files(tmp_path)
        self.assertEqual([name for _, name in found], ["foo_generic_pkg"])

    def test_excludes_osvvm(self):
        tmp_path = Path(self._tmp_dir())
        self._make_tree(tmp_path, {"vunit/vhdl/osvvm/src/SomePkg.vhd": "package SomePkg is\nend package;\n"})
        found = bar.find_package_files(tmp_path)
        self.assertEqual(found, [])

    _tmp_dirs = []

    def _tmp_dir(self):
        import tempfile

        tmp = tempfile.mkdtemp(prefix="vunit-api-scope-")
        self._tmp_dirs.append(tmp)
        return tmp

    def tearDown(self):
        import shutil

        for tmp in self._tmp_dirs:
            shutil.rmtree(tmp, ignore_errors=True)
        self._tmp_dirs = []


class TestCompleteness(unittest.TestCase):
    def test_passes_when_sets_match(self):
        bar.check_completeness(["a", "b"], ["b", "a"])

    def test_raises_listing_missing_and_extra(self):
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.check_completeness(["a", "c"], ["a", "b"])
        message = str(ctx.exception)
        self.assertIn("'b'", message)
        self.assertIn("'c'", message)


# ---------------------------------------------------------------------------
# Error handling: missing binary, version pin, non-zero exit
# ---------------------------------------------------------------------------


class TestErrorHandling(unittest.TestCase):
    def test_vhdl_dump_ast_not_on_path(self):
        import shutil
        from unittest import mock

        with mock.patch.object(shutil, "which", return_value=None):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.check_vhdl_dump_ast_available()
        self.assertEqual(
            str(ctx.exception),
            "vhdl-dump-ast is required to build the API reference; install it with "
            "`cargo install vhdl-dump-ast --version 0.1.0 --locked` or set VUNIT_DOCS_SKIP_API=1",
        )

    def test_version_mismatch_raises(self):
        import subprocess
        from unittest import mock

        fake = subprocess.CompletedProcess(
            args=["vhdl-dump-ast", "--version"], returncode=0, stdout="vhdl-dump-ast 0.2.0\n", stderr=""
        )
        with mock.patch.object(subprocess, "run", return_value=fake):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.check_vhdl_dump_ast_version()
        message = str(ctx.exception)
        self.assertIn("0.2.0", message)
        self.assertIn("syntax tree format", message)

    def test_correct_version_returns_version_string(self):
        import subprocess
        from unittest import mock

        fake = subprocess.CompletedProcess(
            args=["vhdl-dump-ast", "--version"], returncode=0, stdout="vhdl-dump-ast 0.1.0\n", stderr=""
        )
        with mock.patch.object(subprocess, "run", return_value=fake):
            self.assertEqual(bar.check_vhdl_dump_ast_version(), "vhdl-dump-ast 0.1.0")

    def test_nonzero_exit_names_file_and_first_stderr_line(self):
        import subprocess
        from unittest import mock

        fake = subprocess.CompletedProcess(
            args=["vhdl-dump-ast"], returncode=2, stdout="", stderr="12..18 unexpected token\nmore detail\n"
        )
        with mock.patch.object(subprocess, "run", return_value=fake):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.run_vhdl_dump_ast(Path("somefile.vhd"))
        message = str(ctx.exception)
        self.assertIn("somefile.vhd", message)
        self.assertIn("unexpected token", message)


# ---------------------------------------------------------------------------
# Python API (unchanged code, still tested)
# ---------------------------------------------------------------------------


class SampleClass:
    """A sample class for the Python API test."""

    def method_one(self, value):
        """Doubles value."""
        return value * 2

    @property
    def read_only(self):
        """A read-only property."""
        return 1

    def _private_method(self):
        pass


def sample_function(a, b=1):
    """Adds a and b."""
    return a + b


class TestPythonApi(unittest.TestCase):
    def test_finds_autoclass_and_automodule_targets(self):
        import tempfile

        tmp_path = Path(tempfile.mkdtemp(prefix="vunit-api-rst-"))
        docs = tmp_path / "docs"
        docs.mkdir()
        (docs / "vunit.rst").write_text(
            ".. autoclass:: vunit.ui.VUnit()\n\n.. autoclass:: vunit.ui.library.Library()\n"
            "   :exclude-members: package\n",
            encoding="utf-8",
        )
        (docs / "ui.rst").write_text(".. automodule:: vunit.vunit_cli\n", encoding="utf-8")
        (docs / "opts.rst").write_text(
            ".. automodule:: tests.unit.test_api_reference\n   :members:\n", encoding="utf-8"
        )
        targets = bar.find_python_targets(tmp_path)
        as_dict = {(directive, dotted): has_members for directive, dotted, has_members in targets}
        self.assertEqual(as_dict[("autoclass", "vunit.ui.VUnit")], False)
        self.assertEqual(as_dict[("autoclass", "vunit.ui.library.Library")], False)
        self.assertEqual(as_dict[("automodule", "vunit.vunit_cli")], False)
        self.assertEqual(as_dict[("automodule", "tests.unit.test_api_reference")], True)

    def test_class_object_collects_public_members_defined_on_the_class(self):
        obj = bar.build_class_object(f"{__name__}.SampleClass", SampleClass)
        self.assertEqual(obj["kind"], "class")
        members = {m["name"]: m for m in obj["members"]}
        self.assertIn("method_one", members)
        self.assertIn("read_only", members)
        self.assertNotIn("_private_method", members)
        self.assertEqual(members["read_only"]["kind"], "property")
        self.assertEqual(members["method_one"]["kind"], "method")
        self.assertIn("(self, value)", members["method_one"]["signature"])
        self.assertEqual(members["method_one"]["doc"], "Doubles value.")

    def test_module_object_without_members_option_has_no_members(self):
        obj = bar.build_module_object(__name__, sys.modules[__name__], has_members=False)
        self.assertEqual(obj["kind"], "module")
        self.assertEqual(obj["members"], [])

    def test_module_object_with_members_option_collects_classes_and_functions(self):
        obj = bar.build_module_object(__name__, sys.modules[__name__], has_members=True)
        names = {m["name"] for m in obj["members"]}
        self.assertIn("SampleClass", names)
        self.assertIn("sample_function", names)

    def test_no_public_objects_found_raises(self):
        import types

        empty_module = types.ModuleType("vunit_test_empty_module")
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.build_module_object("vunit_test_empty_module", empty_module, has_members=True)
        self.assertIn("vunit_test_empty_module", str(ctx.exception))

    def test_import_dotted_class(self):
        obj = bar.import_dotted(f"{__name__}.SampleClass")
        self.assertIs(obj, SampleClass)


if __name__ == "__main__":
    unittest.main()
