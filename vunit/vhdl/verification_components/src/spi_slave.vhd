library ieee;
use ieee.std_logic_1164.all;

use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_pkg.reply;
use work.com_types_pkg.all;
use work.stream_slave_pkg.all;
use work.spi_pkg.all;
use work.queue_pkg.all;
use work.print_pkg.all;
use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.log_handler_pkg.all;

entity spi_slave is
generic (
    spi : spi_slave_t
);
port (
    sclk : in  std_logic := spi.p_cpol_mode;
    ss_n : in  std_logic := '0';
    mosi : in  std_logic;
    miso : out std_logic
);
end entity;

architecture a of spi_slave is

    constant din_queue : queue_t := new_queue;
    signal local_event : std_logic := '0';

begin

    main : process

        variable reply_msg, query_msg : msg_t;
        variable msg_type : msg_type_t;

    begin

        receive(net, spi.p_actor, query_msg);
        msg_type := message_type(query_msg);

        if msg_type = stream_pop_msg then
            reply_msg := new_msg;
            if not (length(din_queue) > 0) then
                wait on local_event until length(din_queue) > 0;
            end if;
            push_std_ulogic_vector(reply_msg, pop_std_ulogic_vector(din_queue));
            push_boolean(reply_msg, false);
            reply(net, query_msg, reply_msg);
        else
            unexpected_msg_type(msg_type);
        end if;

    end process;

    recv : process

        procedure spi_transaction(
            variable data : out std_logic_vector;
            signal sclk   : in  std_logic;
            signal mosi   : in  std_logic
        ) is
            variable din_vector : std_logic_vector(7 downto 0);
            variable bit_count  : natural := 7;
        begin
            while (ss_n = '0') loop
                if ((spi.p_cpha_mode = '0') and (spi.p_cpol_mode = '0')) then
                    wait until rising_edge(sclk) or ss_n = '1'; wait for 1 ps;
                elsif ((spi.p_cpha_mode = '0') and (spi.p_cpol_mode = '1')) then
                    wait until falling_edge(sclk) or ss_n = '1'; wait for 1 ps;
                elsif ((spi.p_cpha_mode = '1') and (spi.p_cpol_mode = '0')) then
                    wait until falling_edge(sclk) or ss_n = '1'; wait for 1 ps;
                elsif ((spi.p_cpha_mode = '1') and (spi.p_cpol_mode = '1')) then
                    wait until rising_edge(sclk) or ss_n = '1'; wait for 1 ps;
                end if;
                if (ss_n = '0') then
                    din_vector(bit_count) := mosi;
                    if (bit_count = 0) then
                        bit_count := 7;
                        debug("Received " & to_string(din_vector));
                        push_std_ulogic_vector(din_queue, din_vector);
                    else
                        bit_count := bit_count-1;
                    end if;
                end if;
            end loop;
        end procedure;

        variable data : std_logic_vector(7 downto 0);

    begin

        wait until ss_n = '0';
        spi_transaction(data, sclk, mosi);
        local_event <= '1';
        wait for 1 fs;
        local_event <= '0';
        wait for 1 fs;

    end process;

    -- Data loopback
    miso <= mosi;

end architecture;
