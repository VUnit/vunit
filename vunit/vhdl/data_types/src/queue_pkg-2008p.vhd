-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use work.queue_pkg.all;
use work.codec_2008p_pkg.all;
use work.codec_builder_pkg.all;
use work.codec_builder_2008p_pkg.all;

package queue_2008p_pkg is
  procedure push (
    queue : queue_t;
    value : boolean_vector
  );

  impure function pop (
    queue : queue_t
  ) return boolean_vector;

  procedure peek (
    queue : queue_t;
    variable value : out boolean_vector;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return boolean_vector;

  alias push_boolean_vector is push[queue_t, boolean_vector];
  alias pop_boolean_vector is pop[queue_t return boolean_vector];
  alias peek_boolean_vector is peek[queue_t, boolean_vector, natural];
  alias peek_boolean_vector is peek[queue_t return boolean_vector];

  procedure push (
    queue : queue_t;
    value : integer_vector
  );

  impure function pop (
    queue : queue_t
  ) return integer_vector;

  procedure peek (
    queue : queue_t;
    variable value : out integer_vector;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return integer_vector;

  alias push_integer_vector is push[queue_t, integer_vector];
  alias pop_integer_vector is pop[queue_t return integer_vector];
  alias peek_integer_vector is peek[queue_t, integer_vector, natural];
  alias peek_integer_vector is peek[queue_t return integer_vector];

  procedure push (
    queue : queue_t;
    value : real_vector
  );

  impure function pop (
    queue : queue_t
  ) return real_vector;

  procedure peek (
    queue : queue_t;
    variable value : out real_vector;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return real_vector;

  alias push_real_vector is push[queue_t, real_vector];
  alias pop_real_vector is pop[queue_t return real_vector];
  alias peek_real_vector is peek[queue_t, real_vector, natural];
  alias peek_real_vector is peek[queue_t return real_vector];

  procedure push (
    queue : queue_t;
    value : time_vector
  );

  impure function pop (
    queue : queue_t
  ) return time_vector;

  procedure peek (
    queue : queue_t;
    variable value : out time_vector;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return time_vector;

  alias push_time_vector is push[queue_t, time_vector];
  alias pop_time_vector is pop[queue_t return time_vector];
  alias peek_time_vector is peek[queue_t, time_vector, natural];
  alias peek_time_vector is peek[queue_t return time_vector];

  procedure push (
    queue : queue_t;
    value : ufixed
  );

  impure function pop (
    queue : queue_t
  ) return ufixed;

  procedure peek (
    queue : queue_t;
    variable value : out ufixed;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return ufixed;

  alias push_ufixed is push[queue_t, ufixed];
  alias pop_ufixed is pop[queue_t return ufixed];
  alias peek_ufixed is peek[queue_t, ufixed, natural];
  alias peek_ufixed is peek[queue_t return ufixed];

  procedure push (
    queue : queue_t;
    value : sfixed
  );

  impure function pop (
    queue : queue_t
  ) return sfixed;

  procedure peek (
    queue : queue_t;
    variable value : out sfixed;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return sfixed;

  alias push_sfixed is push[queue_t, sfixed];
  alias pop_sfixed is pop[queue_t return sfixed];
  alias peek_sfixed is peek[queue_t, sfixed, natural];
  alias peek_sfixed is peek[queue_t return sfixed];

  procedure push (
    queue : queue_t;
    value : float
  );

  impure function pop (
    queue : queue_t
  ) return float;

  procedure peek (
    queue : queue_t;
    variable value : out float;
    variable offset : inout natural
  );

  impure function peek (
    queue : queue_t
  ) return float;

  alias push_float is push[queue_t, float];
  alias pop_float is pop[queue_t return float];
  alias peek_float is peek[queue_t, float, natural];
  alias peek_float is peek[queue_t return float];
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

  procedure peek (
    queue : queue_t;
    variable value : out boolean_vector;
    variable offset : inout natural
  ) is
    constant length : natural := value'length * boolean_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_boolean_vector, offset);
    peek_variable_string(queue, result, offset);
    -- offset := offset + value'length;
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return boolean_vector is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, vhdl_boolean_vector, offset);
    return decode(peek_variable_string(queue, offset));
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

  procedure peek (
    queue : queue_t;
    variable value : out integer_vector;
    variable offset : inout natural
  ) is
    constant length : natural := value'length * integer_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_integer_vector, offset);
    peek_variable_string(queue, result, offset);
    -- offset := offset + value'length;
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return integer_vector is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, vhdl_integer_vector, offset);
    return decode(peek_variable_string(queue, offset));
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

  procedure peek (
    queue : queue_t;
    variable value : out real_vector;
    variable offset : inout natural
  ) is
    constant length : natural := value'length * real_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_real_vector, offset);
    peek_variable_string(queue, result, offset);
    -- offset := offset + value'length;
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return real_vector is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, vhdl_real_vector, offset);
    return decode(peek_variable_string(queue, offset));
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

  procedure peek (
    queue : queue_t;
    variable value : out time_vector;
    variable offset : inout natural
  ) is
    constant length : natural := value'length * time_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_time_vector, offset);
    peek_variable_string(queue, result, offset);
    -- offset := offset + value'length;
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return time_vector is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, vhdl_time_vector, offset);
    return decode(peek_variable_string(queue, offset));
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

  procedure peek (
    queue : queue_t;
    variable value : out ufixed;
    variable offset : inout natural
  ) is
    constant length : natural := value'length * std_ulogic_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_ufixed, offset);
    peek_variable_string(queue, result, offset);
    -- offset := offset + value'length;
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return ufixed is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, ieee_ufixed, offset);
    return decode(peek_variable_string(queue, offset));
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

  procedure peek (
    queue : queue_t;
    variable value : out sfixed;
    variable offset : inout natural
  ) is
    constant length : natural := value'length * std_ulogic_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_sfixed, offset);
    peek_variable_string(queue, result, offset);
    -- offset := offset + value'length;
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return sfixed is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, ieee_sfixed, offset);
    return decode(peek_variable_string(queue, offset));
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

  procedure peek (
    queue : queue_t;
    variable value : out float;
    variable offset : inout natural
  ) is
    constant length : natural := value'length * std_ulogic_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_float, offset);
    peek_variable_string(queue, result, offset);
    -- offset := offset + value'length;
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return float is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, ieee_float, offset);
    return decode(peek_variable_string(queue, offset));
  end;
end package body;
