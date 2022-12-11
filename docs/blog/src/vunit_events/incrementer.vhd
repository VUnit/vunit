-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.incrementer_pkg.all;

entity incrementer is
  generic(
    delay : positive := 1);
  port(
    clk : in std_logic;

    input_tdata  : in  std_logic_vector;
    input_tvalid : in  std_logic;
    input_tready : out std_logic;
    input_tlast  : in  std_logic := '1';

    output_tdata  : out std_logic_vector;
    output_tvalid : out std_logic := '0';
    output_tready : in  std_logic := '1';
    output_tlast  : out std_logic := '0';

    ctrl_arready : out std_logic                    := '0';
    ctrl_arvalid : in  std_logic                    := '0';
    ctrl_araddr  : in  std_logic_vector(7 downto 0) := x"00";

    ctrl_rready : in  std_logic                     := '0';
    ctrl_rvalid : out std_logic                     := '0';
    ctrl_rdata  : out std_logic_vector(31 downto 0) := (others => '0');
    ctrl_rresp  : out std_logic_vector(1 downto 0)  := "00";

    ctrl_awready : out std_logic                    := '0';
    ctrl_awvalid : in  std_logic                    := '0';
    ctrl_awaddr  : in  std_logic_vector(7 downto 0) := x"00";

    ctrl_wready : out std_logic                     := '0';
    ctrl_wvalid : in  std_logic                     := '0';
    ctrl_wdata  : in  std_logic_vector(31 downto 0) := (others => '0');
    ctrl_wstrb  : in  std_logic_vector(3 downto 0)  := x"0";

    ctrl_bvalid : out std_logic                    := '0';
    ctrl_bready : in  std_logic                    := '0';
    ctrl_bresp  : out std_logic_vector(1 downto 0) := "00");
begin
  assert input_tdata'length = output_tdata'length;
end;

architecture a of incrementer is
  type state_t is (idle,
                   writing,
                   write_response,
                   reading);

  signal increment : std_logic_vector(input_tdata'length - 1 downto 0) := (0 => '1', others => '0');
  signal n_samples : std_logic_vector(7 downto 0) := (others => '0');
  signal status_reg : std_logic_vector(input_tdata'length - 1 downto 0) := (others => '0');
  signal state     : state_t                                           := idle;
  signal addr      : std_logic_vector(ctrl_araddr'range);
begin
  main : process is
    type delay_line_t is array (natural range <>) of std_logic_vector(input_tdata'length + 1 downto 0);
    variable delay_line : delay_line_t(1 to delay + 1) := (others => (others => '0'));
  begin
    wait until rising_edge(clk);
    if not output_tvalid or output_tready then
      delay_line(1)          := input_tlast & (input_tvalid and input_tready) & input_tdata;
      delay_line(2 to delay) := delay_line(1 to delay - 1);
    end if;
    output_tlast  <= delay_line(delay)(input_tdata'length + 1);
    output_tvalid <= delay_line(delay)(input_tdata'length);
    output_tdata  <= delay_line(delay)(input_tdata'length - 1 downto 0) + increment;

    if output_tvalid and output_tready then
      n_samples <= n_samples + 1;
    end if;
  end process main;

  status_reg(n_samples'range) <= n_samples;

  input_tready <= not output_tvalid or output_tready;

  ctrl : process is
    constant axi_response_ok     : std_logic_vector(1 downto 0) := "00";
    constant axi_response_decerr : std_logic_vector(1 downto 0) := "11";

    -- Compare addresses of 32-bit words discarding byte address
    function cmp_word_address(byte_addr : std_logic_vector;
                              word_addr : natural) return boolean is
    begin
      return to_integer(byte_addr(byte_addr'left downto 2)) = word_addr/4;
    end;

  begin
    wait until rising_edge(clk);

    ctrl_arready <= '0';
    ctrl_awready <= '0';
    ctrl_wready  <= '0';
    ctrl_rvalid  <= '0';
    ctrl_rdata   <= (others => '0');

    case state is
      when idle =>

        if ctrl_arvalid then
          ctrl_arready <= '1';
          addr         <= ctrl_araddr;
          state        <= reading;

        elsif ctrl_awvalid then
          ctrl_awready <= '1';
          addr         <= ctrl_awaddr;
          state        <= writing;
        end if;

      when writing =>
        if ctrl_wvalid then
          ctrl_wready <= '1';

          ctrl_bvalid <= '1';
          ctrl_bresp  <= axi_response_ok;

          state <= write_response;

          -- Ignore byte write enable
          if cmp_word_address(addr, increment_reg_addr) then
            increment <= ctrl_wdata(increment'length - 1 downto 0);
          end if;
        end if;

      when write_response =>
        if ctrl_bready then
          ctrl_bvalid <= '0';
          state       <= idle;
        end if;

      when reading =>
        if not ctrl_rvalid then
          ctrl_rvalid <= '1';
          ctrl_rresp  <= axi_response_ok;

          if cmp_word_address(addr, increment_reg_addr) then
            ctrl_rdata(increment'range) <= increment;
          elsif cmp_word_address(addr, status_reg_addr) then
            ctrl_rdata(status_reg'range) <= status_reg;
          else
            ctrl_rresp <= axi_response_decerr;
          end if;

        elsif ctrl_rready then
          state <= idle;
        end if;
    end case;

  end process ctrl;
end;
