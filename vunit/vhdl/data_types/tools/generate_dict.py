# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from string import Template

api_template = """  procedure set_$data_type (
    dict       : dict_t;
    key        : string;
    value      : $full_data_type
  );

  impure function get_$data_type (
    dict : dict_t;
    key  : string
  ) return $full_data_type;

"""

alias_template = """  alias set is set_$data_type[dict_t, string, $full_data_type];
  alias get is get_$data_type[dict_t, string return $full_data_type];
"""

impl_template = """  procedure set_$data_type (
    dict       : dict_t;
    key        : string;
    value      : $full_data_type
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ${data_type_provider}_$data_type);
  end;

  impure function get_$data_type (
    dict : dict_t;
    key  : string
  ) return $full_data_type is
  begin
    return decode(p_get_with_type(dict, key, ${data_type_provider}_$data_type));
  end;

"""

test_template = """\

    elsif run("test set and get $full_data_type") then
      dict := new_dict;
      set_$data_type(dict, "key", $test_value);
      check(get_$data_type(dict, "key") = $test_value);
"""

combinations = [
    ("string", "vhdl", '"foo"'),
    ("integer", "vhdl", "17"),
    ("character", "vhdl", "'a'"),
    ("boolean", "vhdl", "true"),
    ("real", "vhdl", "1.23"),
    ("bit", "vhdl", "'1'"),
    ("std_ulogic", "ieee", "'1'"),
    ("severity_level", "vhdl", "error"),
    ("file_open_status", "vhdl", "open_ok"),
    ("file_open_kind", "vhdl", "read_mode"),
    ("bit_vector", "vhdl", '"101"'),
    ("std_ulogic_vector", "ieee", '"101"'),
    ("complex", "ieee", "(-17.17, 42.42)"),
    ("complex_polar", "ieee", "(17.17, 0.42)"),
    ("numeric_bit_unsigned", "ieee", '"101"', "ieee.numeric_bit.unsigned"),
    ("numeric_bit_signed", "ieee", '"101"', "ieee.numeric_bit.signed"),
    ("numeric_std_unsigned", "ieee", '"101"', "ieee.numeric_std.unsigned"),
    ("numeric_std_signed", "ieee", '"101"', "ieee.numeric_std.signed"),
    ("time", "vhdl", "17 ns"),
    ("boolean_vector", "vhdl", "(false, true)"),
    ("time_vector", "vhdl", "(17 ns, 21 ps)"),
    ("real_vector", "vhdl", "(17.17, 0.42)"),
    ("integer_vector", "vhdl", "(17, 42)"),
    ("ufixed", "ieee", "to_ufixed(17.17, 6, -9)"),
    ("sfixed", "ieee", "to_sfixed(-21.21, 6, -9)"),
    ("float", "ieee", "to_float(17.17)"),
]


def generate_api():
    api = ""
    for combination in combinations:
        template = Template(api_template)
        full_data_type = combination[3] if len(combination) == 4 else combination[0]
        api += template.substitute(data_type=combination[0], full_data_type=full_data_type)
    return api


def generate_alias():
    api = ""
    for combination in combinations:
        template = Template(alias_template)
        full_data_type = combination[3] if len(combination) == 4 else combination[0]
        api += template.substitute(data_type=combination[0], full_data_type=full_data_type)
    return api


def generate_impl():
    impl = ""
    for combination in combinations:
        template = Template(impl_template)
        full_data_type = combination[3] if len(combination) == 4 else combination[0]
        impl += template.substitute(
            data_type=combination[0], data_type_provider=combination[1], full_data_type=full_data_type
        )
    return impl


def generate_test():
    test = ""
    for combination in combinations:
        template = Template(test_template)
        full_data_type = combination[3] if len(combination) == 4 else combination[0]
        test += template.substitute(data_type=combination[0], test_value=combination[2], full_data_type=full_data_type)
    return test


def main():
    print("API:\n\n" + generate_api() + "\n")
    print("ALIAS:\n\n" + generate_alias() + "\n")
    print("IMPLEMENTATION:\n\n" + generate_impl() + "\n")
    print("TEST:\n\n" + generate_test() + "\n")


if __name__ == "__main__":
    main()
