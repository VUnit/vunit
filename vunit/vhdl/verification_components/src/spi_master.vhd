library ieee;
use ieee.std_logic_1164.all;

use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_pkg.reply;
use work.com_types_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.sync_pkg.all;
use work.spi_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;
use work.print_pkg.all;
use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.log_handler_pkg.all;

entity spi_master is
generic (
    spi : spi_master_t
);
port (
    sclk : out std_logic := spi.p_cpol_mode;
    mosi : out std_logic := spi.p_idle_state;
    miso : in  std_logic
);
end entity;

architecture a of spi_master is

    constant din_queue : queue_t := new_queue;

begin

    main : process
    
        procedure spi_transaction(
            dout          : std_logic_vector;
            frequency     : integer;
            signal sclk   : out std_logic;
            signal mosi   : out std_logic;
            signal miso   : in  std_logic
        ) is
            constant half_bit_time : time := (10**9 / (frequency*2)) * 1 ns;
            variable din  : std_logic_vector(dout'length-1 downto 0);
            variable clk  : std_logic := spi.p_cpol_mode;
        begin
            debug("Transmitting " & to_string(dout));
            sclk <= clk;
            mosi <= dout(dout'length-1);
            if (spi.p_cpha_mode = '0') then
                wait for half_bit_time;
            end if;
            clk := not clk;
            sclk <= clk;
            if (spi.p_cpha_mode = '0') then
                din(dout'length-1) := miso;
            end if;
            for b in dout'length-2 downto 0 loop
                wait for half_bit_time;
                clk := not clk;    
                sclk <= clk;
                if (spi.p_cpha_mode = '0') then
                    mosi <= dout(b);
                else
                    din(b) := miso;
                end if;
                wait for half_bit_time;
                clk := not clk;    
                sclk <= clk;
                if (spi.p_cpha_mode = '1') then
                    mosi <= dout(b);
                else
                    din(b) := miso;
                end if;
            end loop;
            wait for half_bit_time;
            sclk <= spi.p_cpol_mode;
            push_std_ulogic_vector(din_queue, din);
        end procedure;

        variable query_msg : msg_t;
        variable reply_msg : msg_t;
        variable frequency : natural := spi.p_frequency;
        variable msg_type : msg_type_t;
        variable din : std_logic_vector(7 downto 0);

    begin

        receive(net, spi.p_actor, query_msg);
        msg_type := message_type(query_msg);

        handle_sync_message(net, msg_type, query_msg);

        if    msg_type = stream_push_msg then
            spi_transaction(pop_std_ulogic_vector(query_msg), frequency, sclk, mosi, miso);
        elsif msg_type = stream_pop_msg then
            if (length(din_queue) > 0) then
                reply_msg := new_msg;
                push_std_ulogic_vector(reply_msg, pop_std_ulogic_vector(din_queue));
                push_boolean(reply_msg, false);
                reply(net, query_msg, reply_msg);
            else
                unexpected_msg_type(msg_type);
            end if;
        elsif msg_type = spi_set_frequency_msg then
            frequency := pop(query_msg);
        else
            unexpected_msg_type(msg_type);
        end if;

    end process;

end architecture;
