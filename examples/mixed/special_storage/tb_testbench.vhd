-- clean_up done
-- clean up   : by clean_dfl2lang_instrumented.tcl Version Version_22_02_22 
------------------------------------------------------------------------
-- Title      : tb_testbench 
------------------------------------------------------------------------
-- generated  : by dfl_file_helper.tcl (Version Version_22_02_22) 
-- generated  : 2022-03-03, 11:27:55.
-- Company    : Siemens Healthcare GmbH, Erlangen, Germany 
-- Department : SHS DI MR R&D SFP CRX 
------------------------------------------------------------------------------- 
-- Copyright (c) 2022 by Siemens Healthcare GmbH 
------------------------------------------------------------------------
--
-- ********* DO NOT EDIT THIS GENERATED FILE! *********
--
-- (or consistency with the graphical representation will be lost) 
--
------------------------------------------------------------------------
-- EGA Keys:
------------------------------------------------------------------------
--no texts found in design, no keys extracted
------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;




------------------------------------------------------------------------
--------------------------------ENTITY----------------------------------
------------------------------------------------------------------------

use IEEE.std_logic_misc.all; -- inserted by clean_dfl2lang
use IEEE.std_logic_arith.all; -- inserted by clean_dfl2lang
use IEEE.std_logic_signed.all; -- inserted by clean_dfl2lang
use IEEE.std_logic_unsigned.all; -- inserted by clean_dfl2lang
library design_work; -- library declaration libraries
library special;
use special.special_records_pkg.all;
library uni;
use uni.uni_records_pkg.all;
      
library vunit_lib;
context vunit_lib.vunit_context;

library tb_work;
     
entity tb_testbench is
     
  GENERIC (
      runner_cfg : string := "null";    -- VUNIT
      file_path  : string := "null";    -- VUNIT testbench path
      test_nr    : natural:= 1
  );
  port( led_downstream_link_ok_L       : out std_logic;
        led_downstream_link_training_L : out std_logic;
        led_upstream_link_ok_L         : out std_logic;
        led_upstream_link_training_L   : out std_logic
  );
end tb_testbench;
-- total of 4 ports

------------------------------------------------------------------------
----------------------------ARCHITECTURE--------------------------------
------------------------------------------------------------------------

architecture clean_dfl of tb_testbench is

  signal s_stop         : BOOLEAN := FALSE;  -- signal for VUnit to end simulation
  signal stimuli_finish : BOOLEAN := FALSE;
  

------------------------------------------------------------------------
------------------------------SIGNALS-----------------------------------
------------------------------------------------------------------------

  signal CARE_debug_H                   : std_logic_vector(7 downto 0);
  signal CCC_NE_FB_CLK_H                : std_logic;
  signal CCC_SE_CLKOUT_H                : std_logic;
  signal DEVRST_L                       : std_logic;
  signal IO_CFG_INTF_H                  : std_logic;
  signal ISX0_cs_L                      : std_logic;
  signal ISX0_reset_L                   : std_logic;
  signal ISX0_sck_H                     : std_logic;
  signal ISX0_sdi_H                     : std_logic_vector(3 downto 0);
  signal ISX0_sdo_H                     : std_logic_vector(3 downto 0);
  signal ISX1_cs_L                      : std_logic;
  signal ISX1_reset_L                   : std_logic;
  signal ISX1_sck_H                     : std_logic;
  signal ISX1_sdi_H                     : std_logic_vector(3 downto 0);
  signal ISX1_sdo_H                     : std_logic_vector(3 downto 0);
  signal ISX_0_rvlclk_H                 : std_logic;
  signal ISX_1_rvlclk_H                 : std_logic;
  signal N32V_Current_Fault_H           : std_logic;
  signal PARC_debug_H                   : std_logic_vector(9 downto 0);
  signal POWEN_L                        : std_logic;
  signal POWOK_H                        : std_logic;
  signal PwrGood_1st_H                  : std_logic;
  signal PwrGood_2nd_H                  : std_logic;
  signal PwrGood_IN_H                   : std_logic;
  signal PwrGood_V12P0_IN_H             : std_logic;
  signal PwrGood_V1P8_IN_H              : std_logic;
  signal PwrGood_V24N0_IN_L             : std_logic;
  signal PwrGood_V6P5_IN_H              : std_logic;
  signal SCK_H                          : std_logic;
  signal SDI_H                          : std_logic;
  signal SDO_H                          : std_logic;
  signal SPI_EN_H                       : std_logic;
  signal SS_L                           : std_logic;
  signal TUC_cs_L                       : std_logic;
  signal TUC_rvlclk_H                   : std_logic;
  signal TUC_sck_H                      : std_logic;
  signal TUC_sdi_H                      : std_logic_vector(1 downto 0);
  signal TUC_sdo_H                      : std_logic_vector(1 downto 0);
  signal all_plls_locked_H              : std_logic;
  signal avt_clkout_H                   : std_logic;
  signal avt_g2u_clk_H                  : std_logic;
  signal avt_g2u_control_H              : std_logic;
  signal avt_g2u_data_H                 : std_logic_vector(7 downto 0);
  signal avt_g2u_reset_L                : std_logic;
  signal avt_pll_lock_H                 : std_logic;
  signal avt_u2g_clk_H                  : std_logic;
  signal avt_u2g_control_H              : std_logic;
  signal avt_u2g_data_H                 : std_logic_vector(7 downto 0);
  signal avt_u2g_reset_L                : std_logic;
  signal ca2dn_D_N_L                    : std_logic;
  signal ca2dn_D_P_H                    : std_logic;
  signal ca2up_D_N_L                    : std_logic;
  signal ca2up_D_P_H                    : std_logic;
  signal cc_en_i2c_buffer_L             : std_logic_vector(3 downto 0);
  signal cc_i2c_irq_H                   : std_logic_vector(3 downto 0);
  signal cc_i2c_sck_H                   : std_logic_vector(3 downto 0);
  signal cc_i2c_tx_sdat_H               : std_logic_vector(3 downto 0);
  signal clk_100MHz_PARC_H              : std_logic;
  signal clk_uni_N_L                    : std_logic;
  signal clk_uni_P_H                    : std_logic;
  signal coil_sense_cs_L                : std_logic;
  signal coil_sense_sck_H               : std_logic;
  signal coil_sense_sdi_H               : std_logic;
  signal coil_sense_sdo_H               : std_logic;
  signal delayed_plls_lock_H            : std_logic;
  signal en_SFP_power_H                 : std_logic;
  signal en_SupplyN_1_L                 : std_logic;
  signal en_SupplyN_2_L                 : std_logic;
  signal en_SupplyP_1_H                 : std_logic;
  signal en_SupplyP_2_H                 : std_logic;
  signal en_pwr_buffer_H                : std_logic;
  signal flash_r_L                      : std_logic;
  signal fpga_CLKIN_N_L                 : std_logic;
  signal fpga_CLKIN_P_H                 : std_logic;
  signal g2u_cold_reset_L               : std_logic;
  signal g2u_dnstr_pma_reset_L          : std_logic;
  signal g2u_pll_reset_H                : std_logic;
  signal g2u_upstr_pma_reset_L          : std_logic;
  signal input_clk_fail_L               : std_logic;
  signal lc_10V_ok_H                    : std_logic_vector(3 downto 0);
  signal lc_3V_ok_H                     : std_logic_vector(3 downto 0);
  signal lc_P3V_Current_Fault_L         : std_logic_vector(3 downto 0);
  signal lc_en_3V_H                     : std_logic_vector(3 downto 0);
  signal lc_plugged_H                   : std_logic_vector(3 downto 0);
  signal led_FAB_SPI_OWNER_L            : std_logic;
  signal led_all_plls_lock_L            : std_logic;
  signal led_busy_H                     : std_logic;
  signal led_cfg_green_L                : std_logic;
  signal led_cfg_red_L                  : std_logic;
  signal led_input_clk_fail_L           : std_logic;
  signal led_input_power_fail_L         : std_logic;
  signal led_power_OK_L                 : std_logic;
  signal led_power_fail_L               : std_logic;
  signal led_programming_fault_L        : std_logic;
  signal parc_cs_L                      : std_logic;
  signal parc_irq_H                     : std_logic;
  signal parc_pll_clockout_H            : std_logic;
  signal parc_sck_H                     : std_logic;
  signal parc_sdi_H                     : std_logic;
  signal parc_sdo_H                     : std_logic;
  signal plug_can_transmit_H            : std_logic_vector(3 downto 0);
  signal pwr_SCK_H                      : std_logic;
  signal pwr_SDA_H                      : std_logic;
  signal pwr_fans_dead_L                : std_logic;
  signal pwr_irq_L                      : std_logic;
  signal pwr_sense_cs_L                 : std_logic;
  signal pwr_sense_sck_H                : std_logic;
  signal pwr_sense_sdi_H                : std_logic;
  signal pwr_sense_sdo_H                : std_logic;
  signal pwr_spare_L                    : std_logic;
  signal pwr_warning_L                  : std_logic;
  signal slot_ID_H                      : std_logic_vector(4 downto 0);
  signal test_SCK_H                     : std_logic;
  signal test_SDI_H                     : std_logic;
  signal test_SDO_H                     : std_logic;
  signal test_cs_L                      : std_logic;
  signal tmp121_clk_H                   : std_logic_vector(7 downto 0);
  signal tmp121_cs_L                    : std_logic_vector(7 downto 0);
  signal tmp121_so_H                    : std_logic_vector(7 downto 0);
  signal tuc_reset_L                    : std_logic;
  signal u2g_config_success_H           : std_logic;
  signal u2g_dnst_tx_clk_stable_H       : std_logic;
  signal u2g_pll_locked_H               : std_logic;
  signal u2g_uni_pll_lock_H             : std_logic;
  signal u2g_upst_tx_clk_stable_H       : std_logic;
 
---------------automatically generated internal signals-----------------
-----------Buffers are placed at the end of the architecture------------

  signal led_downstream_link_ok_LOP     : std_logic;
  signal led_downstream_link_training_LOP : std_logic;
  signal led_upstream_link_ok_LOP       : std_logic;
  signal led_upstream_link_training_LOP : std_logic;

------------------------------------------------------------------------
-----------------------------COMPONENTS---------------------------------
------------------------------------------------------------------------


  signal cfg_regs_if_reset_out_n_reset_to_slave_n_H : std_logic;
  signal inRamRd_H                                  : inRam_Out_record;
  signal inUse_In_Fault_H                           : std_logic;
  signal inUse_Out_Fault_H                          : std_logic;
  signal input_Range_Fault_H                        : std_logic;
  signal mode_Fault_H                               : std_logic;
  signal outRamRd_H                                 : outRam_Out_record;
  signal output_Range_Fault_H                       : std_logic;
  signal protocol_Fault_H                           : std_logic;
  signal rc_bit_Fault_H                             : std_logic;
  signal special_storage_request_H                     : avalon_request_record;
  signal special_storage_response_H                    : avalon_response_record;
  signal routing_Fault_H                            : std_logic;
  signal sel_cpld_H                                 : std_logic;
  signal storage32bit_request_H                     : avalon_request_record;
  signal storage32bit_response_H                    : avalon_response_record;
  signal storage_if_reset_out_n_reset_to_slave_n_H  : std_logic;
 
---------------automatically generated internal signals-----------------
-----------Buffers are placed at the end of the architecture------------

  signal cpld_request_HOP                           : avalon_request_record;
  signal fail_address_HOP                           : std_logic_vector(31 downto 0);
  signal fail_data_HOP                              : std_logic_vector(31 downto 0);
  signal faultVector_HOP                            : std_logic_vector(15 downto 0);
  signal inRam_HOP                                  : inRam_Out_record;
  signal led_programming_fault_LOP                  : std_logic;
  signal outRam_HOP                                 : outRam_Out_record;
  signal special_cfg_request_HOP                       : avalon_request_record;
  signal special_response_HOP                          : avalon_response_record;

  signal avl_clk_H               :  std_logic;
  signal avl_reset_L             :  std_logic;
  signal cmd_clearAllSettings_H  :  std_logic;
  signal cmd_clearsetting_h      :  std_logic;
  signal setting2clear_h         : std_logic_vector (5 downto 0); 
  signal storage_setting_special_h  : std_logic_vector (5 downto 0); 

use design_work.special_storage; -- component specific use statement


component special_storage
  port   ( avs_clk_h                     : in std_logic; 
           avs_reset_l                   : in std_logic; 
           cmd_clearallsettings_h        : in std_logic; 
           cmd_clearsetting_h            : in std_logic; 
           fail_address_h                : buffer std_logic_vector (31 downto 0); 
           fail_data_h                   : buffer std_logic_vector (31 downto 0); 
           faultvector_h                 : buffer std_logic_vector (15 downto 0); 
           input_range_fault_h           : in std_logic;  -- input beyond range
           inram_h                       : buffer inram_out_record;  -- addressed by special_setting_H
           inramrd_h                     : buffer inram_out_record;  -- addressed by special_storage_request_H.writedata_H(15 downto 12)
           inuse_in_fault_h              : in std_logic;  -- input already in use
           inuse_out_fault_h             : in std_logic;  -- output already in use
           led_programming_fault_l       : buffer std_logic; 
           mode_fault_h                  : in std_logic;  -- wrong input mode
           output_range_fault_h          : in std_logic;  -- output beyond range
           outram_h                      : buffer outram_out_record;  -- addressed by special_setting_H
           outramrd_h                    : buffer outram_out_record;  -- addressed by special_storage_request_H.writedata_H(15 downto 12)
           protocol_fault_h              : in std_logic;  -- wrong address
           rc_bit_fault_h                : in std_logic;  -- rc bit does not match
           special_storage_request_h        : in avalon_request_record; 
           special_storage_response_h       : buffer avalon_response_record; 
           routing_fault_h               : in std_logic;  -- no path between input and output
           setting2clear_h               : in std_logic_vector (5 downto 0); 
           storage_setting_special_h        : in std_logic_vector (5 downto 0)); 
end component special_storage;



component pullup
  generic( y_width  : INTEGER :=  2);
  port   ( y        : out std_logic_vector (y_width-1 downto 0)); 
end component pullup;



use design_work.stim4testbench; -- component specific use statement

component stim4testbench
  port   ( stimuli_finish                 : out boolean;
           all_plls_locked_h          : in std_logic; 
           clk_100mhz_parc_h          : buffer std_logic; 
           clk_uni_n_l                : buffer std_logic; 
           clk_uni_p_h                : buffer std_logic; 
           delayed_plls_lock_h        : buffer std_logic; 
           devrst_l                   : in std_logic; 
           ensupplyp_1_h              : in std_logic; 
           ensupplyp_2_h              : in std_logic; 
           flash_r_l                  : in std_logic; 
           fpga_clkin_n_l             : buffer std_logic; 
           fpga_clkin_p_h             : buffer std_logic; 
           input_clk_fail_l           : buffer std_logic; 
           n32v_current_fault_h       : buffer std_logic; 
           powok_h                    : in std_logic; 
           pwrgood_1st_h              : buffer std_logic; 
           pwrgood_2nd_h              : buffer std_logic; 
           pwrgood_in_h               : buffer std_logic); 
end component stim4testbench;



------------------------------------------------------------------------
-----------------------------INSTANCES----------------------------------
------------------------------------------------------------------------

begin

  p_vunit : process                  -- VUnit control process
  begin
      wait for 0 ns;
      test_runner_setup(runner, runner_cfg);
      info("Directory containing testbench: " & tb_path(runner_cfg));
      info("Test output directory: " & output_path(runner_cfg));
      info("Test case nr: " & to_string(test_nr));
  
      while test_suite loop
        if    run("test4")  then wait until s_stop = true;
        end if;  
      end loop;
--      
      test_runner_cleanup(runner);
  end process;

special_storage_1 : special_storage
         port map  ( avs_clk_h               => avl_clk_h, 
                     avs_reset_l             => avl_reset_l, 
                     cmd_clearallsettings_h  => cmd_clearallsettings_h, 
                     cmd_clearsetting_h      => cmd_clearsetting_h, 
                     fail_address_h          => fail_address_HOP(31 downto 0), 
                     fail_data_h             => fail_data_HOP(31 downto 0), 
                     faultvector_h           => faultVector_HOP(15 downto 0), 
                     input_range_fault_h     => input_range_fault_h, 
                     inram_h                 => inRam_HOP, 
                     inramrd_h               => inramrd_h, 
                     inuse_in_fault_h        => inuse_in_fault_h, 
                     inuse_out_fault_h       => inuse_out_fault_h, 
                     led_programming_fault_l => led_programming_fault_LOP, 
                     mode_fault_h            => mode_fault_h, 
                     output_range_fault_h    => output_range_fault_h, 
                     outram_h                => outRam_HOP, 
                     outramrd_h              => outramrd_h, 
                     protocol_fault_h        => protocol_fault_h, 
                     rc_bit_fault_h          => rc_bit_fault_h, 
                     special_storage_request_h  => special_storage_request_h, 
                     special_storage_response_h => special_storage_response_h, 
                     routing_fault_h         => routing_fault_h, 
                     setting2clear_h         => setting2clear_h (5 downto 0), 
                     storage_setting_special_h  => storage_setting_special_h (5 downto 0)); 

 
PullUp_1 : PullUp
       generic map ( y_width => 4)
         port map  ( y       => cc_i2c_sck_h (3 downto 0)); 
  
 
PullUp_2 : PullUp
       generic map ( y_width => 1)
         port map  ( y(0)    => pwr_sda_h); 
  
 
PullUp_3 : PullUp
       generic map ( y_width => 1)
         port map  ( y(0)    => pwr_sck_h); 
  
 
PullUp_4 : PullUp
       generic map ( y_width => 4)
         port map  ( y       => cc_i2c_tx_sdat_h (3 downto 0)); 
  
 
-- clean_dfl2lang replaced false_1
pwr_irq_l <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_10
test_sck_h <= '0'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_11
test_cs_l <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_2
pwr_warning_l <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_3
pwr_fans_dead_l <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_4
plug_can_transmit_h(3 downto 0) <= (others => '0'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_5
cc_i2c_irq_h(3 downto 0) <= (others => '0'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_6
lc_3v_ok_h(3 downto 0) <= (others => '0'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_7
lc_plugged_h(3 downto 0) <= (others => '0'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_8
lc_p3v_current_fault_l(3 downto 0) <= (others => '1'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced false_9
tuc_sdo_h(1 downto 0) <= (others => '0'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced konstante_1
slot_id_h(4 downto 0) <=  conv_std_logic_vector(1,5); -- inserted by clean_dfl2lang
  
 
stim4testbench_1 : stim4testbench
         port map  ( stimuli_finish       => stimuli_finish,
                     all_plls_locked_h    => all_plls_locked_h, 
                     clk_100mhz_parc_h    => clk_100mhz_parc_h, 
                     clk_uni_n_l          => clk_uni_n_l, 
                     clk_uni_p_h          => clk_uni_p_h, 
                     delayed_plls_lock_h  => delayed_plls_lock_h, 
                     devrst_l             => devrst_l, 
                     ensupplyp_1_h        => en_supplyp_1_h, 
                     ensupplyp_2_h        => en_supplyp_2_h, 
                     flash_r_l            => flash_r_l, 
                     fpga_clkin_n_l       => fpga_clkin_n_l, 
                     fpga_clkin_p_h       => fpga_clkin_p_h, 
                     input_clk_fail_l     => input_clk_fail_l, 
                     n32v_current_fault_h => n32v_current_fault_h, 
                     powok_h              => powok_h, 
                     pwrgood_1st_h        => pwrgood_1st_h, 
                     pwrgood_2nd_h        => pwrgood_2nd_h, 
                     pwrgood_in_h         => pwrgood_in_h); 
  
 
-- clean_dfl2lang replaced true_1
isx1_sdo_h(3 downto 0) <= (others => '1'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_10
spi_en_h <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_11
io_cfg_intf_h <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_12
powen_l <= '0'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_14
pwrgood_v6p5_in_h <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_15
pwrgood_v1p8_in_h <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_16
pwrgood_v24n0_in_l <= '0'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_17
pwrgood_v12p0_in_h <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_18
test_sdi_h <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_2
isx0_sdo_h(3 downto 0) <= (others => '1'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_3
tmp121_so_h(7 downto 0) <= (others => '1'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_4
coil_sense_sdo_h <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_5
pwr_spare_l <= '0'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_6
pwr_sense_sdo_h <= '1'; -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_7
lc_10v_ok_h(3 downto 0) <= (others => '1'); -- inserted by clean_dfl2lang
  
 
-- clean_dfl2lang replaced true_9
sdi_h <= '1'; -- inserted by clean_dfl2lang
--------------------------------BUFFERS----------------------------------

	led_downstream_link_ok_L <= led_downstream_link_ok_LOP;
	led_downstream_link_training_L <= led_downstream_link_training_LOP;
	led_upstream_link_ok_L <= led_upstream_link_ok_LOP;
	led_upstream_link_training_L <= led_upstream_link_training_LOP;
 

  
  -----------------------------------------------------------------------------
  -- runner
  -----------------------------------------------------------------------------
  -- the tests shall not run more than 1 ms
  -- test_runner_watchdog(runner, 1 ms);

  ------------------------------------------------
  -- PROCESS: p_main
  ------------------------------------------------
  p_main: process

  begin

     -- Finish the simulation
     -- s_stop <= true; --get_error_status; -- true;
     wait until stimuli_finish;
     s_stop <= stimuli_finish; 

     wait for 1 us;
     std.env.stop;

     wait;  -- to stop completely

  end process p_main;

end architecture;
  

