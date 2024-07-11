library ieee;
use ieee.std_logic_1164.all;

context work.com_context;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.sync_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.queue_pkg.all;

package spi_pkg is

    type spi_master_t is record
        p_actor      : actor_t;
        p_cpol_mode  : std_logic;
        p_cpha_mode  : std_logic;
        p_idle_state : std_logic;
        p_frequency  : natural;
    end record;

    type spi_slave_t is record
        p_actor     : actor_t;
        p_cpol_mode : std_logic;
        p_cpha_mode : std_logic;
    end record;

    procedure set_frequency(
        signal net : inout network_t;
        spi_master : spi_master_t;
        frequency  : natural
    );

    constant default_cpol_mode  : std_logic := '0';
    constant default_cpha_mode  : std_logic := '0';
    constant default_idle_state : std_logic := '0';
    constant default_frequency  : natural := 1000000;
    
    impure function new_spi_master(
        cpol_mode         : std_logic := default_cpol_mode;
        cpha_mode         : std_logic := default_cpha_mode;
        idle_state        : std_logic := default_idle_state;
        initial_frequency : natural   := default_frequency
    ) return spi_master_t;

    impure function new_spi_slave(
        cpol_mode : std_logic := default_cpol_mode;
        cpha_mode : std_logic := default_cpha_mode
    ) return spi_slave_t;

    impure function as_stream(spi_master : spi_master_t) return stream_master_t;
    impure function as_stream(spi_master : spi_master_t) return stream_slave_t;
    impure function as_stream(spi_slave  : spi_slave_t)  return stream_master_t;
    impure function as_stream(spi_slave  : spi_slave_t)  return stream_slave_t;
    impure function as_sync  (spi_master : spi_master_t) return sync_handle_t;
    impure function as_sync  (spi_slave  : spi_slave_t)  return sync_handle_t;

    constant spi_set_frequency_msg : msg_type_t := new_msg_type("spi set frequency");
    
end package spi_pkg;

package body spi_pkg is
    
    impure function new_spi_master(
        cpol_mode         : std_logic := default_cpol_mode;
        cpha_mode         : std_logic := default_cpha_mode;
        idle_state        : std_logic := default_idle_state;
        initial_frequency : natural   := default_frequency
    ) return spi_master_t is
    begin
        return (
            p_actor      => new_actor,
            p_cpol_mode  => cpol_mode,
            p_cpha_mode  => cpha_mode,
            p_idle_state => default_idle_state,
            p_frequency  => initial_frequency
        );
    end function new_spi_master;

    impure function new_spi_slave(
        cpol_mode : std_logic := default_cpol_mode;
        cpha_mode : std_logic := default_cpha_mode
    ) return spi_slave_t is
    begin
        return (
            p_actor     => new_actor,
            p_cpol_mode => cpol_mode,
            p_cpha_mode => cpha_mode
        );
    end function new_spi_slave;

    impure function as_stream(spi_master : spi_master_t) return stream_master_t is
    begin
        return stream_master_t'(p_actor => spi_master.p_actor);
    end function as_stream;

    impure function as_stream(spi_master : spi_master_t) return stream_slave_t is
    begin
        return stream_slave_t'(p_actor => spi_master.p_actor);
    end function as_stream;

    impure function as_stream(spi_slave  : spi_slave_t) return stream_master_t is
    begin
        return stream_master_t'(p_actor => spi_slave.p_actor);
    end function as_stream;

    impure function as_stream(spi_slave  : spi_slave_t) return stream_slave_t is
    begin
        return stream_slave_t'(p_actor => spi_slave.p_actor);
    end function as_stream;
    
    impure function as_sync(spi_master : spi_master_t) return sync_handle_t is
    begin
        return spi_master.p_actor;
    end function as_sync;

    impure function as_sync(spi_slave  : spi_slave_t) return sync_handle_t is
    begin
        return spi_slave.p_actor;
    end function as_sync;

    procedure set_frequency(
        signal net : inout network_t;
        spi_master : spi_master_t;                    
        frequency  : natural
    ) is
        variable msg : msg_t := new_msg(spi_set_frequency_msg);
    begin
        push(msg, frequency);
        send(net,spi_master.p_actor,msg);
    end procedure set_frequency;

end package body spi_pkg;
