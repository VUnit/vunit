-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use work.codec_2008p_pkg.all;
use work.data_types_private_pkg.all;
use work.queue_pkg.all;

package queue_2008p_pkg is
  procedure push (
    queue : queue_t;
    value : boolean_vector
  );

  impure function pop (
    queue : queue_t
  ) return boolean_vector;

  alias push_boolean_vector is push[queue_t, boolean_vector];
  alias pop_boolean_vector is pop[queue_t return boolean_vector];

  procedure push (
    queue : queue_t;
    value : integer_vector
  );

  impure function pop (
    queue : queue_t
  ) return integer_vector;

  alias push_integer_vector is push[queue_t, integer_vector];
  alias pop_integer_vector is pop[queue_t return integer_vector];

  procedure push (
    queue : queue_t;
    value : real_vector
  );

  impure function pop (
    queue : queue_t
  ) return real_vector;

  alias push_real_vector is push[queue_t, real_vector];
  alias pop_real_vector is pop[queue_t return real_vector];

  procedure push (
    queue : queue_t;
    value : time_vector
  );

  impure function pop (
    queue : queue_t
  ) return time_vector;

  alias push_time_vector is push[queue_t, time_vector];
  alias pop_time_vector is pop[queue_t return time_vector];

  procedure push (
    queue : queue_t;
    value : ufixed
  );

  impure function pop (
    queue : queue_t
  ) return ufixed;

  alias push_ufixed is push[queue_t, ufixed];
  alias pop_ufixed is pop[queue_t return ufixed];

  procedure push (
    queue : queue_t;
    value : sfixed
  );

  impure function pop (
    queue : queue_t
  ) return sfixed;

  alias push_sfixed is push[queue_t, sfixed];
  alias pop_sfixed is pop[queue_t return sfixed];

  procedure push (
    queue : queue_t;
    value : float
  );

  impure function pop (
    queue : queue_t
  ) return float;

  alias push_float is push[queue_t, float];
  alias pop_float is pop[queue_t return float];
end package;

package body queue_2008p_pkg is
  procedure push (
    queue : queue_t;
    value : boolean_vector
  ) is begin
    push_type(queue, vhdl_boolean_vector);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return boolean_vector is begin
    check_type(queue, vhdl_boolean_vector);
    return decode(pop_variable_string(queue));
  end;

  procedure push (
    queue : queue_t;
    value : integer_vector
  ) is begin
    push_type(queue, vhdl_integer_vector);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return integer_vector is begin
    check_type(queue, vhdl_integer_vector);
    return decode(pop_variable_string(queue));
  end;

  procedure push (
    queue : queue_t;
    value : real_vector
  ) is begin
    push_type(queue, vhdl_real_vector);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return real_vector is begin
    check_type(queue, vhdl_real_vector);
    return decode(pop_variable_string(queue));
  end;

  procedure push (
    queue : queue_t;
    value : time_vector
  ) is begin
    push_type(queue, vhdl_time_vector);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return time_vector is begin
    check_type(queue, vhdl_time_vector);
    return decode(pop_variable_string(queue));
  end;

  procedure push (
    queue : queue_t;
    value : ufixed
  ) is begin
    push_type(queue, ieee_ufixed);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ufixed is begin
    check_type(queue, ieee_ufixed);
    return decode(pop_variable_string(queue));
  end;

  procedure push (
    queue : queue_t;
    value : sfixed
  ) is begin
    push_type(queue, ieee_sfixed);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return sfixed is begin
    check_type(queue, ieee_sfixed);
    return decode(pop_variable_string(queue));
  end;

  procedure push (
    queue : queue_t;
    value : float
  ) is begin
    push_type(queue, ieee_float);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return float is begin
    check_type(queue, ieee_float);
    return decode(pop_variable_string(queue));
  end;
end package body;
