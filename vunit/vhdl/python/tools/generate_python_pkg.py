# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Generate python_pkg.vhd from python_pkg.vhd.in in this directory.

The template holds the parts of python_pkg that are written by hand. The
generated parts are the argument value types of call, the result types of eval
and call and the execution of Python files. They are mostly one overload per
type, which is why they are generated. The operations that are implemented by
the Python bridge (NVC, GHDL and Questa) are built on the p_ prefixed
primitives of python_ffi_pkg, which the VHPI variant of that package
implements by reporting a failure.
"""

from pathlib import Path
from string import Template

SRC_PATH = Path(__file__).parent.parent / "src"
TEMPLATE_PATH = Path(__file__).parent

# Like the operations of python_pkg, every operation takes the session it is
# performed in as its last parameter
SESSION = "session : python_session_t := default_session"

# The 10 arguments of call
ARGS = [f"arg{index}" for index in range(1, 11)]
ARG_PARAMETERS = f"{', '.join(ARGS)} : arg_t := null_arg"
ARG_ACTUALS = ", ".join(ARGS)
ARG_SIGNATURE = ", ".join(["string"] + ["arg_t"] * len(ARGS) + ["python_session_t"])

# Value types of arg and kwarg that are generated rather than declared in the
# template.
#
# vhdl:   the VHDL type
# impure: true when the functions must be impure
# fails:  true when the conversion can fail, which makes p_arg_value take the
#         name of the operation to report the value it cannot convert
# suffix: appended to the arg and kwarg names, empty for an overload
#
# The integer_array_t value is transferred by the Python bridge, which makes it
# available for NVC, GHDL and Questa only. The other values are built from the
# Python source text of the value alone and work on any simulator.
#
# The unsigned and signed values are passed to typed names, arg_unsigned and
# arg_signed, on purpose: plain overloads would make a string literal
# argument, arg("Hello"), ambiguous since a string literal belongs to every
# character array type. std_ulogic needs no such name, being a scalar, and
# std_ulogic_vector is deliberately not among the types at all. Such values
# are passed as arg(to_string(slv)) and arg_unsigned(unsigned(slv)).
ARG_VALUES = [
    dict(vhdl="real_vector", impure=False, fails=False, suffix=""),
    dict(vhdl="integer_vector_ptr_t", impure=True, fails=False, suffix=""),
    dict(vhdl="std_ulogic", impure=True, fails=True, suffix=""),
    dict(vhdl="unsigned", impure=True, fails=True, suffix="_unsigned"),
    dict(vhdl="signed", impure=True, fails=True, suffix="_signed"),
    dict(vhdl="integer_array_t", impure=True, fails=True, suffix=""),
]

# Result types of eval and call.
#
# name:     suffix of eval_<name> and call_<name>
# vhdl:     the VHDL type
# kind:     result kind passed to the bridge, see vunit/python_bridge/runtime.py
# value:    expression giving the result of a successful evaluation
# default:  value returned after a failure
# hand_written_eval/hand_written_call: true when the eval/call function is
#           declared in the template rather than generated. value and default
#           are only needed when the eval function is generated.
RESULTS = [
    dict(
        name="integer",
        vhdl="integer",
        kind="p_kind_integer",
        hand_written_eval=True,
        hand_written_call=True,
    ),
    dict(
        name="real",
        vhdl="real",
        kind="p_kind_real",
        hand_written_eval=True,
        hand_written_call=True,
    ),
    dict(
        name="integer_vector",
        vhdl="integer_vector",
        kind="p_kind_integer_vector",
        hand_written_eval=True,
        hand_written_call=True,
    ),
    dict(
        name="real_vector",
        vhdl="real_vector",
        kind="p_kind_real_vector",
        hand_written_eval=True,
        hand_written_call=False,
    ),
    dict(
        name="string",
        vhdl="string",
        kind="p_kind_string",
        hand_written_eval=True,
        hand_written_call=False,
    ),
    dict(
        name="integer_vector_ptr",
        vhdl="integer_vector_ptr_t",
        kind="p_kind_integer_vector",
        hand_written_eval=True,
        hand_written_call=False,
    ),
    dict(
        name="boolean",
        vhdl="boolean",
        kind="p_kind_boolean",
        value="p_result_integer /= 0",
        default="false",
        hand_written_eval=False,
        hand_written_call=False,
    ),
    dict(
        name="std_ulogic",
        vhdl="std_ulogic",
        kind="p_kind_std_ulogic",
        value="p_to_std_ulogic(p_result_string(1))",
        default="'U'",
        hand_written_eval=False,
        hand_written_call=False,
    ),
    dict(
        name="std_ulogic_vector",
        vhdl="std_ulogic_vector",
        kind="p_kind_std_ulogic_vector",
        value="p_to_std_ulogic_vector(p_result_string)",
        default='""',
        hand_written_eval=False,
        hand_written_call=False,
        # No eval/call alias: check_equal(eval("17"), 17) would otherwise be ambiguous
        # with check_equal(std_ulogic_vector, natural). Use the explicit names.
        alias_eval=False,
        alias_call=False,
    ),
    dict(
        name="integer_array",
        vhdl="integer_array_t",
        kind="p_kind_integer_array",
        value="p_result_integer_array",
        default="null_integer_array",
        hand_written_eval=False,
        hand_written_call=False,
        # No eval alias: length(eval(...)) would otherwise be ambiguous between
        # the integer_array_t and integer_vector_ptr_t results. Use eval_integer_array.
        alias_eval=False,
    ),
]

# Result types whose width is given by the actual of the result parameter
PROCEDURE_RESULTS = [
    dict(
        name="std_ulogic_vector",
        vhdl="std_ulogic_vector",
        kind="p_kind_std_ulogic_vector",
        value="p_to_std_ulogic_vector(p_result_string)",
    ),
    dict(
        name="signed",
        vhdl="signed",
        kind="p_kind_signed",
        value="signed(p_to_std_ulogic_vector(p_result_string))",
    ),
    dict(
        name="unsigned",
        vhdl="unsigned",
        kind="p_kind_unsigned",
        value="unsigned(p_to_std_ulogic_vector(p_result_string))",
    ),
]


def call_name(result):
    """
    Name of the call function of a result type. The integer one is named
    call_integer_w_arg by python_pkg.
    """
    return "call_integer_w_arg" if result["name"] == "integer" else f"call_{result['name']}"


# -------------------------------------------------------------------------
# arg and kwarg
# -------------------------------------------------------------------------
def arg_declarations():
    """
    Declarations of the generated arg and kwarg subprograms.
    """
    lines = []
    for value in ARG_VALUES:
        purity = "impure " if value["impure"] else ""
        suffix = value["suffix"]
        lines.append(f"  {purity}function arg{suffix}(value : {value['vhdl']}) return arg_t;")
        lines.append(f"  {purity}function kwarg{suffix}(kw : string; value : {value['vhdl']}) return arg_t;")
    return "\n".join(lines)


def arg_functions():
    """
    Bodies of the generated arg and kwarg subprograms. p_arg_value returns an
    empty string when the value cannot be converted, having reported it.
    """
    parts = []
    for value in ARG_VALUES:
        purity = "impure " if value["impure"] else ""
        value_type = value["vhdl"]
        suffix = value["suffix"]
        for name, parameters, result in [
            (f"arg{suffix}", f"value : {value_type}", "(p_positional_arg, text)"),
            (f"kwarg{suffix}", f"kw : string; value : {value_type}", "(kw, text)"),
        ]:
            operation = f', "{name}"' if value["fails"] else ""
            parts.append(
                f"""\
  {purity}function {name}({parameters}) return arg_t is
    constant text : string := p_arg_value(value{operation});
  begin
    if text = "" then
      return null_arg;
    end if;
    return {result};
  end;
"""
            )
    return "\n".join(parts).rstrip("\n")


# -------------------------------------------------------------------------
# eval
# -------------------------------------------------------------------------
def eval_declarations():
    """
    Declarations of the generated eval functions and of the eval procedures.
    """
    lines = []
    for result in RESULTS:
        if result["hand_written_eval"]:
            continue
        lines.append(f"  impure function eval_{result['name']}(")
        lines.append(f"    expr : string; {SESSION}")
        lines.append(f"  ) return {result['vhdl']};")
        if result.get("alias_eval", True):
            lines.append(f"  alias eval is eval_{result['name']}[string, python_session_t return {result['vhdl']}];")
        lines.append("")
    for result in PROCEDURE_RESULTS:
        lines.append(f"  procedure eval_{result['name']}(")
        lines.append(f"    expr : string; result : out {result['vhdl']}; {SESSION}")
        lines.append("  );")
    return "\n".join(lines)


def eval_subprograms():
    """
    Bodies of the generated eval functions and of the eval procedures.
    """
    parts = []
    for result in RESULTS:
        if result["hand_written_eval"]:
            continue
        parts.append(
            f"""\
  impure function eval_{result['name']}(
    expr : string; {SESSION}
  ) return {result['vhdl']} is
  begin
    if p_eval(expr, {result['kind']}, -1, p_eval_operation(expr, session), session) then
      return {result['value']};
    end if;
    return {result['default']};
  end;
"""
        )
    for result in PROCEDURE_RESULTS:
        parts.append(
            f"""\
  procedure eval_{result['name']}(
    expr : string; result : out {result['vhdl']}; {SESSION}
  ) is
  begin
    if p_eval(expr, {result['kind']}, result'length, p_eval_operation(expr, session), session) then
      result := {result['value']};
    end if;
  end;
"""
        )
    return "\n".join(parts).rstrip("\n")


# -------------------------------------------------------------------------
# call
# -------------------------------------------------------------------------
def call_declarations():
    """
    Declarations of the generated call functions and of the call procedures.
    """
    lines = []
    for result in RESULTS:
        if result["hand_written_call"]:
            continue
        name = call_name(result)
        lines.append(f"  impure function {name}(")
        lines.append(f"    identifier : string; {ARG_PARAMETERS};")
        lines.append(f"    {SESSION}")
        lines.append(f"  ) return {result['vhdl']};")
        if result.get("alias_call", True):
            lines.append(f"  alias call is {name}[")
            lines.append(f"    {ARG_SIGNATURE} return {result['vhdl']}];")
        lines.append("")
    for result in PROCEDURE_RESULTS:
        lines.append(f"  procedure call_{result['name']}(")
        lines.append(f"    identifier : string; result : out {result['vhdl']};")
        lines.append(f"    {ARG_PARAMETERS};")
        lines.append(f"    {SESSION}")
        lines.append("  );")
    return "\n".join(lines)


def call_subprograms():
    """
    Bodies of the generated call functions and of the call procedures. A call
    is the evaluation of the Python expression calling the identifier with the
    given arguments.
    """
    parts = []
    for result in RESULTS:
        if result["hand_written_call"]:
            continue
        parts.append(
            f"""\
  impure function {call_name(result)}(
    identifier : string; {ARG_PARAMETERS};
    {SESSION}
  ) return {result['vhdl']} is
  begin
    return eval_{result['name']}(
      p_to_call_str(identifier, {ARG_ACTUALS}), session
    );
  end;
"""
        )
    for result in PROCEDURE_RESULTS:
        parts.append(
            f"""\
  procedure call_{result['name']}(
    identifier : string; result : out {result['vhdl']};
    {ARG_PARAMETERS};
    {SESSION}
  ) is
  begin
    eval_{result['name']}(
      p_to_call_str(identifier, {ARG_ACTUALS}), result, session
    );
  end;
"""
        )
    return "\n".join(parts).rstrip("\n")


def generate_package():
    """
    Generate python_pkg from the template and the generated declarations.
    """
    template = (TEMPLATE_PATH / "python_pkg.vhd.in").read_text(encoding="utf-8")
    return Template(template).substitute(
        arg_declarations=arg_declarations(),
        arg_functions=arg_functions(),
        eval_declarations=eval_declarations(),
        call_declarations=call_declarations(),
        eval_subprograms=eval_subprograms(),
        call_subprograms=call_subprograms(),
    )


def main():
    (SRC_PATH / "python_pkg.vhd").write_text(generate_package(), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
