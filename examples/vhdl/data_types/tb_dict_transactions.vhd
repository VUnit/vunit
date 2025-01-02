-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.data_types_context;

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_dict_transactions is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_dict_transactions is
  -- Dicts are references to data. These references can be declared as global constants to make
  -- the dict accessible to any process. We're not saying that different processes communicating
  -- through a global variable / shared dict is always a good thing to do, but it's possible.
  constant global : dict_t := new_dict;

  -- Queues can also be shared as global constants. This will enable another and safer mode of
  -- sharing dicts as we will see later on
  constant transaction_queue : queue_t := new_queue;

  signal clk : std_logic := '0';
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    -- Here we're using the global dict as a way to figure out when the test is finished
    -- and can be terminated. This works because the pending transactions value is set
    -- to 10 before the first rising edge of clk. Global dicts can easily lead to
    -- data races if one is not careful. There are better ways to signal completion but this
    -- is an example of dicts so that's why we're using it.
    wait until rising_edge(clk) and get(global, "pending transactions") = 0;

    test_runner_cleanup(runner);
  end process;

  transaction_producer : process
    variable transaction : dict_t;
    variable rnd : RandomPType;
  begin
    -- There is one overloaded set procedure for each type. You can also use the type specific alias,
    -- in this case set_integer. Type specific aliases also exist for the get functions, get_integer for example.
    set(global, "pending transactions", rnd.RandInt(10, 100));

    generate_random_read_and_write_transactions: for i in 1 to get(global, "pending transactions") loop
      -- Dicts can contain a mix of data types. In this case the dict represents a bus initiator
      -- read or write transaction. All transactions have an integer address and write transactions
      -- also have a std_ulogic_vector data word.
      transaction := new_dict;
      set(transaction, "address", rnd.RandInt(0, 2 ** 20 - 1));
      if rnd.RandBool then
        set(transaction, "data", rnd.RandSlv(32));
      end if;

      -- Dicts can be used with other complex data types, for example pushed into a queue. push_ref
      -- will set the transaction to null_dict which means that the ownership of the data is handed
      -- over to the consumer. By having only one owner of the dict at any time we avoid the data race
      -- risk associated with shared data like the global dict
      push_ref(transaction_queue, transaction);
    end loop;
    wait;
  end process;

  transaction_consumer : process
    variable transaction : dict_t;
    variable address : natural;
  begin
    wait until rising_edge(clk) and not is_empty(transaction_queue);

    transaction := pop_ref(transaction_queue);

    -- dicts are type safe. If one tries to read the address as a std_ulogic_vector the result is an error:
    --
    -- "Stored value for address is of type integer but get function for std_ulogic_vector was called.
    --
    -- It's also possible to be explicit by using get_integer
    address := get(transaction, "address");

    if has_key(transaction, "data") then
      info("Writing 0x" & to_hstring(get_std_ulogic_vector(transaction, "data")) & " to address " & to_string(address));

      -- Handle write transaction

    else
      info("Reading from address " & to_string(address));

      -- Handle read transaction

    end if;

    set(global, "pending transactions", get(global, "pending transactions") - 1);
    deallocate(transaction); -- Garbage collection
  end process;

  clk <= not clk after 1 ns;
end architecture;
