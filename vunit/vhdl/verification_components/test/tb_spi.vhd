library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.spi_pkg.all;
use work.sync_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;

entity tb_spi is
    generic (runner_cfg : string);
end entity tb_spi;

architecture a of tb_spi is

    constant master_spi : spi_master_t := new_spi_master;
    constant master_stream : stream_master_t := as_stream(master_spi);

    constant slave_spi : spi_slave_t := new_spi_slave;
    constant slave_stream : stream_slave_t := as_stream(slave_spi);

    signal sclk : std_logic;
    signal ss_n : std_logic;
    signal mosi : std_logic;
    signal miso : std_logic;

begin

    main : process
        variable data : std_logic_vector( 7 downto 0);
        variable reference_queue : queue_t := new_queue;
        variable reference : stream_reference_t;

        procedure test_frequency(frequency : natural) is
            variable start : time;
            variable got, expected : time;
        begin
            set_frequency(net, master_spi, frequency);
            wait for 10 ps;
            start := now;
            ss_n <= '0';
            push_stream(net, master_stream, x"77");
            wait_until_idle(net, as_sync(master_spi));
            ss_n <= '1';
            check_stream(net, slave_stream, x"77");
            got := now - start;
            expected := (8 * (1 sec)) / (frequency);
            check(abs (got - expected) <= 10 ns,
                "Unexpected frequency; got " & to_string(got) & " expected " & to_string(expected));
            wait for 10 ps;
        end procedure;

    begin

        test_runner_setup(runner, runner_cfg);
        ss_n <= '1';
        wait for 10 ps;

        if run("test single push and pop") then
            ss_n <= '0';
            push_stream(net, master_stream, x"77");
            wait_until_idle(net, as_sync(master_spi));
            wait for 10 ps;
            ss_n <= '1';
            pop_stream(net, slave_stream, data);
            check_equal(data, std_logic_vector'(x"77"), "pop stream data");
            wait for 10 ps;

        elsif run("test pop before push") then
            for i in 0 to 7 loop
                pop_stream(net, slave_stream, reference);
                push(reference_queue, reference);
            end loop;

            for i in 0 to 7 loop
                push_stream(net, master_stream,
                    std_logic_vector(to_unsigned(i+1, data'length)));
            end loop;

            ss_n <= '0';
            wait_until_idle(net, as_sync(master_spi));
            wait for 10 ps;
            ss_n <= '1';
            wait for 10 ps;
            for i in 0 to 7 loop
                reference := pop(reference_queue);
                await_pop_stream_reply(net, reference, data);
                check_equal(data, to_unsigned(i+1, data'length));
            end loop;

        elsif run("test frequency") then
            test_frequency(1000000);
            test_frequency(4000000);
            test_frequency(8000000);
        end if;

        test_runner_cleanup(runner);
    end process;
    
    test_runner_watchdog(runner, 10 ms);

    spi_master_inst: entity work.spi_master
        generic map (
            spi => master_spi
        )
        port map (
            sclk => sclk,
            mosi => mosi, 
            miso => miso
        );

    spi_slave_inst: entity work.spi_slave
        generic map (
            spi => slave_spi
        )
        port map (
            sclk => sclk,
            ss_n => ss_n,
            mosi => mosi,
            miso => miso
        );


end architecture a;