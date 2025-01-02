# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Templates common to all datatype codecs.
"""

from string import Template


class DatatypeCodecTemplate(object):
    """Templates when generating codecs"""

    to_string_declarations = Template(
        """\
  function to_string (
    constant data : $type)
    return string;

"""
    )

    codec_declarations = Template(
        """\
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
  procedure push(queue : queue_t; value : $type);
  impure function pop(queue : queue_t) return $type;
  alias push_$type is push[queue_t, $type];
  alias pop_$type is pop[queue_t return $type];
  procedure push(msg : msg_t; value : $type);
  impure function pop(msg : msg_t) return $type;
  alias push_$type is push[msg_t, $type];
  alias pop_$type is pop[msg_t return $type];

"""
    )
