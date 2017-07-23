# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

"""
Templates common to all datatype codecs.
"""

from string import Template


class DatatypeCodecTemplate(object):
    """Templates when generating codecs"""

    to_string_declarations = Template("""\
  function to_string (
    constant data : $type)
    return string;

""")

    codec_declarations = Template("""\
  function encode (
    constant data : $type)
    return string;
  alias encode_$type is encode[$type return string];
  function decode (
    constant code : string)
    return $type;
  alias decode_$type is decode[string return $type];
  procedure decode (
    constant code   : string;
    variable index : inout positive;
    variable result : out $type);
  alias decode_$type is decode[string, positive, $type];

""")
