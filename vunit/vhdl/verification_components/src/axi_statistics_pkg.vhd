-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.axi_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;
use work.integer_vector_ptr_pkg.all;

package axi_statistics_pkg is
  type axi_statistics_t is record
    -- Private
    p_count_by_burst_length : integer_vector_ptr_t;
  end record;
  constant null_axi_statistics : axi_statistics_t := (p_count_by_burst_length => null_ptr);

  -- Get the maximum burst length that occured
  impure function max_burst_length(stat : axi_statistics_t) return natural;

  -- Get the minimum burst length that occured
  impure function min_burst_length(stat : axi_statistics_t) return natural;

  -- Get the number of bursts that occured with specific length
  impure function get_num_burst_with_length(stat : axi_statistics_t;
                                            burst_length : natural) return natural;

  -- Get the number of bursts
  impure function num_bursts(stat : axi_statistics_t) return natural;

  -- Free dynamically allocated memory
  procedure deallocate(variable stat : inout axi_statistics_t);

  -- Private
  impure function new_axi_statistics return axi_statistics_t;
  procedure add_burst_length(stat : axi_statistics_t;
                             burst_length : natural);
  impure function copy(stat : axi_statistics_t) return axi_statistics_t;
  procedure clear(stat : axi_statistics_t);
end package;


package body axi_statistics_pkg is
  constant ptr_pool : integer_vector_ptr_pool_t := new_integer_vector_ptr_pool;

  impure function new_axi_statistics return axi_statistics_t is
    variable stat : axi_statistics_t;
  begin
    stat := (p_count_by_burst_length => new_integer_vector_ptr(ptr_pool,
                                                               min_length => max_axi4_burst_length + 1));
    clear(stat);
    return stat;
  end;

  procedure clear(stat : axi_statistics_t) is
  begin
    -- Clear re-used integer_vector_ptr
    for i in 0 to length(stat.p_count_by_burst_length) - 1 loop
      set(stat.p_count_by_burst_length, i, 0);
    end loop;
  end;

  procedure add_burst_length(stat : axi_statistics_t;
                             burst_length : natural) is

  begin
    set(stat.p_count_by_burst_length, burst_length,
        get(stat.p_count_by_burst_length, burst_length) + 1);
  end;

  impure function max_burst_length(stat : axi_statistics_t) return natural is
  begin
    for i in length(stat.p_count_by_burst_length)-1 downto 0 loop
      if get_num_burst_with_length(stat, i) > 0 then
        return i;
      end if;
    end loop;

    return 0;
  end;

  impure function min_burst_length(stat : axi_statistics_t) return natural is
  begin
    for i in 0 to length(stat.p_count_by_burst_length)-1 loop
      if get_num_burst_with_length(stat, i) > 0 then
        return i;
      end if;
    end loop;

    return 0;
  end;

  impure function get_num_burst_with_length(stat : axi_statistics_t;
                                            burst_length : natural) return natural is
  begin
    if burst_length >= length(stat.p_count_by_burst_length) then
      return 0;
    else
      return get(stat.p_count_by_burst_length, burst_length);
    end if;
  end;

  impure function num_bursts(stat : axi_statistics_t) return natural is
    variable sum : natural := 0;
  begin
    for i in 0 to max_axi4_burst_length loop
      sum := sum + get_num_burst_with_length(stat, i);
    end loop;
    return sum;
  end;

  impure function copy(stat : axi_statistics_t) return axi_statistics_t is
    constant stat2 : axi_statistics_t := new_axi_statistics;
  begin
    for i in 0 to length(stat.p_count_by_burst_length)-1 loop
      set(stat2.p_count_by_burst_length, i, get(stat.p_count_by_burst_length, i));
    end loop;
    return stat2;
  end;

  procedure deallocate(variable stat : inout axi_statistics_t) is
  begin
    if stat /= null_axi_statistics then
      recycle(ptr_pool, stat.p_count_by_burst_length);
      stat := null_axi_statistics;
    end if;
  end;
end package body;
