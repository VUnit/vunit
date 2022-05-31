
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;            -- inserted by clean_dfl2lang
use IEEE.std_logic_arith.all;           -- inserted by clean_dfl2lang
use IEEE.std_logic_signed.all;          -- inserted by clean_dfl2lang
use IEEE.std_logic_unsigned.all;        -- inserted by clean_dfl2lang
library uni;
use uni.uni_records_pkg.all;

entity stim4testbench is
    port (    stimuli_finish         : out boolean;
    
    -- pins for care FPGA
    clk_uni_N_L          : buffer std_logic;
    clk_uni_P_H          : buffer std_logic;
    fpga_CLKIN_P_H       : buffer std_logic;
    fpga_CLKIN_N_L       : buffer std_logic;
    -- pins for parc CPLD
    clk_100MHz_PARC_H    : buffer std_logic;
    enSupplyP_1_H        : in     std_logic;
    enSupplyP_2_H        : in     std_logic;
    PwrGood_IN_H         : buffer std_logic;
    PwrGood_1st_H        : buffer std_logic;
    PwrGood_2nd_H        : buffer std_logic;
    POWOK_H              : in     std_logic;
    N32V_Current_Fault_H : buffer std_logic;
    delayed_plls_lock_H  : buffer std_logic;
    all_plls_locked_H    : in     std_logic;
    input_clk_fail_L     : buffer std_logic;
    DEVRST_L             : in     std_logic;
    flash_r_L            : in     std_logic
    );
end stim4testbench;

architecture nick of stim4testbench is
  
  signal stop_condition : boolean := false;  -- ends the simulation in batch mode

begin  -- nick

-- purpose: generates PwrGood_1st_H
-- type   : combinational
-- inputs : enSupplyP_1_H
-- outputs: 
  pgd1 : process
  begin  -- process pgd1
    PwrGood_1st_H <= '0';
    loop
      if enSupplyP_1_H = '1' then
        PwrGood_1st_H <= transport '1' after 100 ns;
      else
        PwrGood_1st_H <= transport '0' after 100 ns;
      end if;
      wait for 100 ns;
    end loop;
  end process pgd1;

  pgd2 : process
  begin  -- process pgd2
    PwrGood_2nd_H <= '0';
    loop
      if enSupplyP_2_H = '1' then
        PwrGood_2nd_H <= transport '1' after 100 ns;
      else
        PwrGood_2nd_H <= transport '0' after 100 ns;
      end if;
      wait for 100 ns;
    end loop;
  end process pgd2;

  del_pll_lock : process
  begin  -- process del_pll_lock
    delayed_plls_lock_H <= '0';
    loop
      wait until all_plls_locked_H = '1';
      delayed_plls_lock_H <= '1' after 10 us;
      wait until not (all_plls_locked_H = '1');
      delayed_plls_lock_H <= '0';
    end loop;

  end process del_pll_lock;

-- purpose: sequential stimuli
-- type   : combinational
-- inputs : 
-- outputs: 
  stimproc : process
  begin  -- process stimproc
    PwrGood_IN_H         <= '0';
    N32V_Current_Fault_H <= '0';
    input_clk_fail_L     <= '1';
    wait for 1 us;
    PwrGood_IN_H         <= '1';

    wait for 180 us;                    -- give it a bit to settle all

    assert false report "successfully executed all stimuli" severity note;
    stimuli_finish <= true;
    stop_condition <= true;

    wait;                               -- forever
  end process stimproc;



  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  -- clock generation system (both 100 MHz from system clock)
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  fpga_clock_prog : process
  begin  -- process slock_prog
    fpga_CLKIN_P_H    <= '0';
    fpga_CLKIN_N_L    <= '1';
    clk_100MHz_PARC_H <= '0';
    wait for 2 ns;
    fpga_CLKIN_P_H    <= '1';
    fpga_CLKIN_N_L    <= '0';
    clk_100MHz_PARC_H <= '1';
    wait for 5 ns;
    fpga_CLKIN_P_H    <= '0';
    fpga_CLKIN_N_L    <= '1';
    clk_100MHz_PARC_H <= '0';
    wait for 3 ns;
  end process fpga_clock_prog;

  uni_clock_prog : process
  begin  -- process slock_prog
    clk_uni_P_H <= '0';
    clk_uni_N_L <= '1';
    wait for 5 ns;
    clk_uni_P_H <= '1';
    clk_uni_N_L <= '0';
    wait for 5 ns;
  end process uni_clock_prog;

  

end nick;
