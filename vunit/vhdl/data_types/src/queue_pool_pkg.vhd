-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.integer_vector_ptr_pool_pkg.all;
use work.string_ptr_pool_pkg.all;
use work.queue_pkg.all;

package queue_pool_pkg is
  type queue_pool_t is record
    index_pool : integer_vector_ptr_pool_t;
    data_pool : string_ptr_pool_t;
  end record;
  constant null_queue_pool : queue_pool_t := (
    index_pool => null_integer_vector_ptr_pool,
    data_pool => null_string_ptr_pool);

  impure function new_queue_pool
  return queue_pool_t;

  impure function new_queue (
    pool : queue_pool_t
  ) return queue_t;

  procedure recycle (
    pool : queue_pool_t;
    variable queue : inout queue_t
  );
end package;

package body queue_pool_pkg is
  impure function new_queue_pool
  return queue_pool_t is begin
    return (
      index_pool => new_integer_vector_ptr_pool,
      data_pool  => new_string_ptr_pool
    );
  end;

  impure function new_queue (
    pool : queue_pool_t
  ) return queue_t is
    variable queue : queue_t;
  begin
    queue := (
      p_meta => new_integer_vector_ptr(pool.index_pool, 2),
      data => new_string_ptr(pool.data_pool, 0)
    );
    flush(queue);
    return queue;
  end;

  procedure recycle (
    pool : queue_pool_t;
    variable queue : inout queue_t
  ) is begin
    recycle(pool.index_pool, queue.p_meta);
    recycle(pool.data_pool, queue.data);
  end;
end package body;
