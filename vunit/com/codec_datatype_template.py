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
  -- Printing function for the type $type
  function to_string(data : $type) return string;

"""
    )

    codec_declarations = Template(
        """\
  -----------------------------------------------------------------------------
  -- Codec package extension for the type $type
  -----------------------------------------------------------------------------

  function encode_$type(data : $type) return code_t;
  function decode_$type(code : code_t) return $type;
  alias encode is encode_$type[$type return code_t];
  alias decode is decode_$type[code_t return $type];
  procedure encode_$type(
    constant data  : in    $type;
    variable index : inout code_index_t;
    variable code  : inout code_t
  );
  procedure decode_$type(
    constant code   : in    code_t;
    variable index  : inout code_index_t;
    variable result : out   $type
  );
  alias encode is encode_$type[$type, code_index_t, code_t];
  alias decode is decode_$type[code_t, code_index_t, $type];


  -----------------------------------------------------------------------------
  -- Queue package extension for the type $type
  -----------------------------------------------------------------------------

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
