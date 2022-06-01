------------------------------------------------------------------------
--Code for special_storage 
--generated 2022-02-18 06:56:02
------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all; 
library uni;
use uni.uni_records_pkg.all;
library special;
use special.special_records_pkg.all;
library design_work;

ENTITY special_storage IS
    PORT(
        avs_clk_H               : IN     STD_LOGIC;
        avs_reset_L             : IN     STD_LOGIC;
        special_storage_request_H  : IN     avalon_request_record;
        special_storage_response_H : BUFFER avalon_response_record;
        setting2clear_H         : IN     STD_LOGIC_VECTOR(5 downto 0);
        storage_setting_special_H  : IN     STD_LOGIC_VECTOR(5 downto 0);
        cmd_clearAllSettings_H  : IN     STD_LOGIC;
        cmd_clearSetting_H      : IN     STD_LOGIC;
        input_Range_Fault_H     : IN std_logic; -- input beyond range
        inUse_In_Fault_H        : IN std_logic; -- input already in use
        protocol_Fault_H        : IN std_logic; -- wrong address
        rc_bit_Fault_H          : IN std_logic; -- rc bit does not match
        mode_Fault_H            : IN std_logic; -- wrong input mode
        output_Range_Fault_H    : IN std_logic; -- output beyond range
        inUse_Out_Fault_H       : IN std_logic; -- output already in use
        routing_Fault_H         : IN std_logic; -- no path between input and output
        faultVector_H           : buffer std_logic_vector(15 downto 0);
        fail_address_H          : buffer std_logic_vector(31 downto 0);
        fail_data_H             : buffer std_logic_vector(31 downto 0);
        led_programming_fault_L : buffer STD_LOGIC;
        inRam_H                 : buffer inRam_Out_record; -- addressed by special_setting_H
        outRam_H                : buffer outRam_Out_record; -- addressed by special_setting_H
        inRamRd_H               : buffer inRam_Out_record; -- addressed by special_storage_request_H.writedata_H(15 downto 12)
        outRamRd_H              : buffer outRam_Out_record -- addressed by special_storage_request_H.writedata_H(15 downto 12)
        );
END special_storage; 


architecture tcl2vhd OF  special_storage IS


   use design_work.PF_DPSRAM_SPECIAL;
   component  PF_DPSRAM_SPECIAL  
      port (
          -- inputs
          A_ADDR   : in  std_logic_vector (5 downto 0);
          A_BLK_EN : in  std_logic := '1';
          A_DIN    : in  std_logic_vector (19 downto 0);
          A_WEN    : in  std_logic := '0';
          B_ADDR   : in  std_logic_vector (5 downto 0);
          B_BLK_EN : in  std_logic := '1';
          B_DIN    : in  std_logic_vector (19 downto 0);
          B_WEN    : in  std_logic := '0';
          CLK      : in  std_logic := '0';
          -- outputs
          A_DOUT   : out std_logic_vector (19 downto 0);
          B_DOUT   : out std_logic_vector (19 downto 0)
          );
        end component;


signal A_BLK_EN_H : std_logic;
signal B_BLK_EN_H : std_logic;
signal writeStrobe_H : std_logic;
signal protocol_adr_H :  std_logic_vector (1 downto 0);
signal setting_adr_H :  std_logic_vector (5 downto 0);
signal input_channel_H :  std_logic_vector (7 downto 0);
signal output_channel_H : std_logic_vector (5 downto 0);
---------------------------------------------------------------------
-- inRam Data Definition: 
---------------------------------------------------------------------
--    index          description: 
--  1 downto  0      reserved 0
--            2      output_routing
--            3      reserved 0 (was fieldcam Bit)
--            4      reserved 0 (was PD Bit)
--            5      RC Bit
-- 11 downto  6      output channel
-- 15 downto 12      input mode
--           16      in_use statistics
--           17      input_routing, that is the input is really connected
-- 19 downto 18      reserved 0
---------------------------------------------------------------------
signal inRam_wrData_H   : std_logic_vector (19 downto 0);
signal inRam0_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam0_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam1_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam1_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam2_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam2_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam3_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam3_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam4_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam4_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam5_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam5_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam6_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam6_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam7_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam7_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam8_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam8_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam9_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam9_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam10_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam10_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam11_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam11_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam12_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam12_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam13_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam13_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam14_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam14_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam15_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam15_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam16_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam16_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam17_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam17_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam18_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam18_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam19_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam19_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam20_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam20_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam21_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam21_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam22_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam22_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam23_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam23_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam24_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam24_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam25_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam25_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam26_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam26_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam27_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam27_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam28_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam28_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam29_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam29_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam30_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam30_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam31_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam31_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam32_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam32_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam33_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam33_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam34_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam34_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam35_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam35_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam36_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam36_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam37_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam37_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam38_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam38_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam39_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam39_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam40_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam40_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam41_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam41_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam42_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam42_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam43_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam43_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam44_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam44_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam45_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam45_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam46_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam46_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam47_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam47_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam48_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam48_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal inRam49_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal inRam49_outData_H : std_logic_vector (19 downto 0); -- setting dependent
---------------------------------------------------------------------
-- outRam Data Definition: 
---------------------------------------------------------------------
--    index          description: 
--  6 downto  0      input channel
--            7      input_routing
--            8      RC Bit
-- 11 downto  9      reserved 0
-- 15 downto 12      input mode
-- 19 downto 18      reserved 0
---------------------------------------------------------------------
signal outRam_wrData_H   : std_logic_vector (19 downto 0);
signal outRam0_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam0_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam1_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam1_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam2_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam2_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam3_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam3_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam4_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam4_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam5_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam5_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam6_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam6_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam7_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam7_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam8_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam8_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam9_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam9_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam10_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam10_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam11_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam11_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam12_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam12_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam13_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam13_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam14_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam14_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam15_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam15_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam16_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam16_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam17_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam17_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam18_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam18_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam19_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam19_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam20_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam20_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam21_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam21_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam22_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam22_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam23_rdData_H  : std_logic_vector (19 downto 0); -- address dependent
signal outRam23_outData_H : std_logic_vector (19 downto 0); -- setting dependent
signal outRam_rdData_H : std_logic_vector (19 downto 0);
signal enInRamWrite_H : std_logic_vector (49 downto 0);
signal enOutRamWrite_H : std_logic_vector (23 downto 0);
SIGNAL wren_b               : std_logic;
SIGNAL data_b               : std_logic_vector(19 downto 0);
signal special_address_H : std_logic_vector (15 downto 0);

signal lockFault_H : std_logic;
signal lockFaultS_H : std_logic;

signal input_routing_H : std_logic;
signal output_routing_H : std_logic;
signal begintransferS_H, begintransferSS_H : std_logic;
signal rc_H : std_logic;
signal input_mode_H  : std_logic_vector(3 downto 0); -- mode bits
signal faultVectorC_H : std_logic_vector(15 downto 0);
signal old_storage_request_H : avalon_request_record;



begin  -- tcl2vhd

 A_BLK_EN_H  <= '1';
 B_BLK_EN_H  <= '1';
  wait_proc : process (avs_clk_H, avs_reset_L)
  begin  -- process wait_proc
    if avs_reset_L = '0' then                       -- asynchronous reset (active low)
      special_storage_response_H.waitrequest_H <= '0';
      special_storage_response_H.response_H      <= "11";
      begintransferS_H  <= '0';
      begintransferSS_H <= '0';
    elsif avs_clk_H'event and avs_clk_H = '1' then  -- rising clock edge
      special_storage_response_H.waitrequest_H <= '1';
      special_storage_response_H.response_H      <= "00";
      if special_storage_request_H.write_H = '1' then
        if begintransferS_H = '1' then
          special_storage_response_H.waitrequest_H <= '0';
        end if;
      end if;
      if special_storage_request_H.read_H = '1' then
        if begintransferSS_H = '1' then
          special_storage_response_H.waitrequest_H <= '0';
        end if;
      end if;
      begintransferS_H  <= special_storage_request_H.begintransfer_H;
      begintransferSS_H <= begintransferS_H;
    end if;
  end process wait_proc;

  writeStrobe_H    <= begintransferSS_H and special_storage_request_H.write_H;
  -- old RCCS Address is 16-bit word address, now use byte address --> shift address bits
  special_address_H <= special_storage_request_H.address_H(16 downto 1);  -- shift byte address to word address
  protocol_adr_H   <= special_address_H(15 downto 14);
  setting_adr_H    <= setting2clear_H           when cmd_clearSetting_H = '1' else 
                      setting2clear_H           when cmd_clearAllSettings_H = '1' else  
                      special_address_H(13 downto  8);
  input_channel_H  <= special_address_H( 7 downto  0); -- pd bit extends channel numbers from 128 to 256!
  output_channel_H <= special_storage_request_H.writedata_H(11 downto 6);
  rc_H             <= special_storage_request_H.writedata_H(5);
  input_mode_H     <= special_storage_request_H.writedata_H(15 downto 12);
-----------------------------------------------------------------------------------
-- process to generate the write strobe signals for the inRams
-----------------------------------------------------------------------------------
-- purpose: generates signal enInRamWrite_H
-- type   : combinational
-- inputs : writeStrobe_H, input_channel_H
-- outputs: 
enInRamWrite_control: process (cmd_clearAllSettings_H, cmd_clearSetting_H, input_channel_H, lockFault_H, writeStrobe_H)
begin  -- process enFifoWrite_control
  enInRamWrite_H         <= (others => '0');  -- default assignment
  if (cmd_clearSetting_H = '1') or 
     (cmd_clearAllSettings_H = '1') then 
     enInRamWrite_H <= (others => '1');
  elsif (writeStrobe_H and not lockFault_H) ='1' then
      if (conv_integer(input_channel_H) < 50)    then  -- standard if-special operation and range within 50 input channels
        if (rc_H  = '1')  then 
        -- mode has RC
          case (conv_integer(input_mode_H)) is 
            when 4 => enInRamWrite_H(conv_integer(input_channel_H)) <= writeStrobe_H and not lockFault_H; -- TIF testmode
            when 7 => enInRamWrite_H(conv_integer(input_channel_H)) <= writeStrobe_H and not lockFault_H; -- IMG
            when 12 => enInRamWrite_H(conv_integer(input_channel_H)) <= writeStrobe_H and not lockFault_H; -- ITM
            when 15 => enInRamWrite_H(conv_integer(input_channel_H)) <= writeStrobe_H and not lockFault_H; -- IMM (Pin 12)
            when others => null; 
          end case;                       -- (conv_integer(input_mode_H) 
        else
        -- mode has no RC
          case (conv_integer(input_mode_H)) is 
            when 5 => enInRamWrite_H(conv_integer(input_channel_H)) <= writeStrobe_H and not lockFault_H; -- EXT Testmode
            when 6 => enInRamWrite_H(conv_integer(input_channel_H)) <= writeStrobe_H and not lockFault_H; -- LON
            when 13 => enInRamWrite_H(conv_integer(input_channel_H)) <= writeStrobe_H and not lockFault_H; -- EXT Testmode
            when 14 => enInRamWrite_H(conv_integer(input_channel_H)) <= writeStrobe_H and not lockFault_H; -- LOM
            when others => null; 
          end case;                       -- (conv_integer(input_mode_H) 
        end if; -- if (rc_H  = '1')  
      end if; -- if (conv_integer(input_channel_H) < 50) 
  end if; -- if cmd_clearSetting_H = '1'
end process enInRamWrite_control;


inRam_wrData_H(1 downto  0) <= "00";
-- reuse bit 2 for storage of output routing stats
inRam_wrData_H(2) <= '0' when (cmd_clearSetting_H = '1') else 
                     '0' when (cmd_clearAllSettings_H = '1') else 
                     '1' when (output_routing_H = '1') else -- controls CBX2 connection
                     '0';              -- CBX2 routing mode

-- reuse bit 3 in setting RAM for storage of OptionsProtokoll
inRam_wrData_H(3) <= '0';              -- fieldcam usage bit, not supported in hirex

-- reuse bit 4 in setting RAM for storage of PD
inRam_wrData_H(4) <= '0' when (cmd_clearSetting_H = '1') else 
                     '0' when (cmd_clearAllSettings_H = '1') else 
                      '0'; -- not supported in iMpRess: special_address_H(7);

inRam_wrData_H(15 downto 5) <= (others => '0') when (cmd_clearSetting_H = '1') else 
                               (others => '0') when (cmd_clearAllSettings_H = '1') else 
                               special_storage_request_H.writedata_H(15 downto 5);
                               -- rc_H             <= special_storage_request_H.writedata_H(5);
                               -- output_channel_H <= special_storage_request_H.writedata_H(11 downto 6);
                               -- input_mode_H     <= special_storage_request_H.writedata_H(15 downto 12);

inRam_wrData_H(16) <= '0' when (cmd_clearSetting_H = '1') else  -- use this bit for usage statistics, set if input is programmed explicitly
                      '0' when (cmd_clearAllSettings_H = '1') else 
                      '1'; 

inRam_wrData_H(17) <= '0' when (cmd_clearSetting_H = '1') else  -- use this bit for usage statistics
                      '0' when (cmd_clearAllSettings_H = '1') else 
                      input_routing_H; -- active only for decoded input_routing modi

inRam_wrData_H(19 downto 18) <= "00";

wren_b <= '0';
data_b <= (others => '0');

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 0 related storage
-----------------------------------------------------------------------------------
--inRam_0 : PF_DPSRAM_SPECIAL 
-----------------------------
--inRam_0 : entity design_work.PF_DPSRAM_SPECIAL 
--inRam_0 : component design_work.PF_DPSRAM_SPECIAL  
--inRam_0 : PF_DPSRAM_SPECIAL -- verilog source
inRam_0 : PF_DPSRAM_SPECIAL -- verilog source
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(0),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam0_rdData_H(19 downto 0),
                B_DOUT   => inRam0_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 1 related storage
-----------------------------------------------------------------------------------
inRam_1 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(1),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam1_rdData_H(19 downto 0),
                B_DOUT   => inRam1_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 2 related storage
-----------------------------------------------------------------------------------
inRam_2 : PF_DPSRAM_SPECIAL  
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(2),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam2_rdData_H(19 downto 0),
                B_DOUT   => inRam2_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 3 related storage
-----------------------------------------------------------------------------------
inRam_3 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(3),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam3_rdData_H(19 downto 0),
                B_DOUT   => inRam3_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 4 related storage
-----------------------------------------------------------------------------------
inRam_4 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(4),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam4_rdData_H(19 downto 0),
                B_DOUT   => inRam4_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 5 related storage
-----------------------------------------------------------------------------------
inRam_5 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(5),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam5_rdData_H(19 downto 0),
                B_DOUT   => inRam5_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 6 related storage
-----------------------------------------------------------------------------------
inRam_6 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(6),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam6_rdData_H(19 downto 0),
                B_DOUT   => inRam6_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 7 related storage
-----------------------------------------------------------------------------------
inRam_7 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(7),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam7_rdData_H(19 downto 0),
                B_DOUT   => inRam7_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 8 related storage
-----------------------------------------------------------------------------------
inRam_8 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(8),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam8_rdData_H(19 downto 0),
                B_DOUT   => inRam8_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 9 related storage
-----------------------------------------------------------------------------------
inRam_9 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(9),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam9_rdData_H(19 downto 0),
                B_DOUT   => inRam9_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 10 related storage
-----------------------------------------------------------------------------------
inRam_10 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(10),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam10_rdData_H(19 downto 0),
                B_DOUT   => inRam10_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 11 related storage
-----------------------------------------------------------------------------------
inRam_11 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(11),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam11_rdData_H(19 downto 0),
                B_DOUT   => inRam11_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 12 related storage
-----------------------------------------------------------------------------------
inRam_12 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(12),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam12_rdData_H(19 downto 0),
                B_DOUT   => inRam12_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 13 related storage
-----------------------------------------------------------------------------------
inRam_13 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(13),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam13_rdData_H(19 downto 0),
                B_DOUT   => inRam13_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 14 related storage
-----------------------------------------------------------------------------------
inRam_14 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(14),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam14_rdData_H(19 downto 0),
                B_DOUT   => inRam14_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 15 related storage
-----------------------------------------------------------------------------------
inRam_15 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(15),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam15_rdData_H(19 downto 0),
                B_DOUT   => inRam15_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 16 related storage
-----------------------------------------------------------------------------------
inRam_16 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(16),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam16_rdData_H(19 downto 0),
                B_DOUT   => inRam16_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 17 related storage
-----------------------------------------------------------------------------------
inRam_17 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(17),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam17_rdData_H(19 downto 0),
                B_DOUT   => inRam17_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 18 related storage
-----------------------------------------------------------------------------------
inRam_18 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(18),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam18_rdData_H(19 downto 0),
                B_DOUT   => inRam18_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 19 related storage
-----------------------------------------------------------------------------------
inRam_19 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(19),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam19_rdData_H(19 downto 0),
                B_DOUT   => inRam19_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 20 related storage
-----------------------------------------------------------------------------------
inRam_20 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(20),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam20_rdData_H(19 downto 0),
                B_DOUT   => inRam20_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 21 related storage
-----------------------------------------------------------------------------------
inRam_21 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(21),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam21_rdData_H(19 downto 0),
                B_DOUT   => inRam21_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 22 related storage
-----------------------------------------------------------------------------------
inRam_22 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(22),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam22_rdData_H(19 downto 0),
                B_DOUT   => inRam22_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 23 related storage
-----------------------------------------------------------------------------------
inRam_23 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(23),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam23_rdData_H(19 downto 0),
                B_DOUT   => inRam23_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 24 related storage
-----------------------------------------------------------------------------------
inRam_24 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(24),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam24_rdData_H(19 downto 0),
                B_DOUT   => inRam24_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 25 related storage
-----------------------------------------------------------------------------------
inRam_25 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(25),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam25_rdData_H(19 downto 0),
                B_DOUT   => inRam25_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 26 related storage
-----------------------------------------------------------------------------------
inRam_26 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(26),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam26_rdData_H(19 downto 0),
                B_DOUT   => inRam26_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 27 related storage
-----------------------------------------------------------------------------------
inRam_27 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(27),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam27_rdData_H(19 downto 0),
                B_DOUT   => inRam27_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 28 related storage
-----------------------------------------------------------------------------------
inRam_28 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(28),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam28_rdData_H(19 downto 0),
                B_DOUT   => inRam28_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 29 related storage
-----------------------------------------------------------------------------------
inRam_29 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(29),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam29_rdData_H(19 downto 0),
                B_DOUT   => inRam29_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 30 related storage
-----------------------------------------------------------------------------------
inRam_30 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(30),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam30_rdData_H(19 downto 0),
                B_DOUT   => inRam30_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 31 related storage
-----------------------------------------------------------------------------------
inRam_31 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(31),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam31_rdData_H(19 downto 0),
                B_DOUT   => inRam31_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 32 related storage
-----------------------------------------------------------------------------------
inRam_32 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(32),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam32_rdData_H(19 downto 0),
                B_DOUT   => inRam32_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 33 related storage
-----------------------------------------------------------------------------------
inRam_33 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(33),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam33_rdData_H(19 downto 0),
                B_DOUT   => inRam33_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 34 related storage
-----------------------------------------------------------------------------------
inRam_34 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(34),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam34_rdData_H(19 downto 0),
                B_DOUT   => inRam34_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 35 related storage
-----------------------------------------------------------------------------------
inRam_35 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(35),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam35_rdData_H(19 downto 0),
                B_DOUT   => inRam35_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 36 related storage
-----------------------------------------------------------------------------------
inRam_36 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(36),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam36_rdData_H(19 downto 0),
                B_DOUT   => inRam36_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 37 related storage
-----------------------------------------------------------------------------------
inRam_37 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(37),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam37_rdData_H(19 downto 0),
                B_DOUT   => inRam37_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 38 related storage
-----------------------------------------------------------------------------------
inRam_38 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(38),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam38_rdData_H(19 downto 0),
                B_DOUT   => inRam38_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 39 related storage
-----------------------------------------------------------------------------------
inRam_39 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(39),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam39_rdData_H(19 downto 0),
                B_DOUT   => inRam39_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 40 related storage
-----------------------------------------------------------------------------------
inRam_40 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(40),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam40_rdData_H(19 downto 0),
                B_DOUT   => inRam40_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 41 related storage
-----------------------------------------------------------------------------------
inRam_41 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(41),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam41_rdData_H(19 downto 0),
                B_DOUT   => inRam41_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 42 related storage
-----------------------------------------------------------------------------------
inRam_42 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(42),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam42_rdData_H(19 downto 0),
                B_DOUT   => inRam42_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 43 related storage
-----------------------------------------------------------------------------------
inRam_43 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(43),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam43_rdData_H(19 downto 0),
                B_DOUT   => inRam43_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 44 related storage
-----------------------------------------------------------------------------------
inRam_44 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(44),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam44_rdData_H(19 downto 0),
                B_DOUT   => inRam44_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 45 related storage
-----------------------------------------------------------------------------------
inRam_45 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(45),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam45_rdData_H(19 downto 0),
                B_DOUT   => inRam45_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 46 related storage
-----------------------------------------------------------------------------------
inRam_46 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(46),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam46_rdData_H(19 downto 0),
                B_DOUT   => inRam46_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 47 related storage
-----------------------------------------------------------------------------------
inRam_47 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(47),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam47_rdData_H(19 downto 0),
                B_DOUT   => inRam47_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 48 related storage
-----------------------------------------------------------------------------------
inRam_48 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(48),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam48_rdData_H(19 downto 0),
                B_DOUT   => inRam48_outData_H(19 downto 0)
                );

-----------------------------------------------------------------------------------
-- settings RAM for RCCS input 49 related storage
-----------------------------------------------------------------------------------
inRam_49 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => inRam_wrData_H(19 downto 0),
                A_WEN    => enInRamWrite_H(49),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => inRam49_rdData_H(19 downto 0),
                B_DOUT   => inRam49_outData_H(19 downto 0)
                );


--        enSettingRead_H <= '1';

        special_storage_response_H.readdata_H(2 downto 0) <= "000"; -- unused bits ;
-- reuse bit 3 in setting RAM for storage of OptionsProtokoll
        special_storage_response_H.readdata_H(3) <= '1' when (setting_adr_H = storage_setting_special_H) else 
                       '0';
-- reuse bit 4 in setting RAM for storage of PD
        -- read setting RAM  
        special_storage_response_H.readdata_H(15 downto 4) <= inRam0_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 0) else
                                                           inRam1_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 1) else
                                                           inRam2_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 2) else
                                                           inRam3_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 3) else
                                                           inRam4_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 4) else
                                                           inRam5_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 5) else
                                                           inRam6_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 6) else
                                                           inRam7_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 7) else
                                                           inRam8_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 8) else
                                                           inRam9_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 9) else
                                                           inRam10_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 10) else
                                                           inRam11_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 11) else
                                                           inRam12_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 12) else
                                                           inRam13_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 13) else
                                                           inRam14_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 14) else
                                                           inRam15_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 15) else
                                                           inRam16_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 16) else
                                                           inRam17_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 17) else
                                                           inRam18_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 18) else
                                                           inRam19_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 19) else
                                                           inRam20_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 20) else
                                                           inRam21_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 21) else
                                                           inRam22_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 22) else
                                                           inRam23_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 23) else
                                                           inRam24_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 24) else
                                                           inRam25_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 25) else
                                                           inRam26_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 26) else
                                                           inRam27_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 27) else
                                                           inRam28_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 28) else
                                                           inRam29_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 29) else
                                                           inRam30_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 30) else
                                                           inRam31_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 31) else
                                                           inRam32_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 32) else
                                                           inRam33_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 33) else
                                                           inRam34_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 34) else
                                                           inRam35_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 35) else
                                                           inRam36_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 36) else
                                                           inRam37_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 37) else
                                                           inRam38_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 38) else
                                                           inRam39_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 39) else
                                                           inRam40_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 40) else
                                                           inRam41_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 41) else
                                                           inRam42_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 42) else
                                                           inRam43_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 43) else
                                                           inRam44_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 44) else
                                                           inRam45_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 45) else
                                                           inRam46_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 46) else
                                                           inRam47_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 47) else
                                                           inRam48_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 48) else
                                                           inRam49_rdData_H(15 downto 4) when (conv_integer(input_channel_H) = 49) else
                                                           conv_std_logic_vector(0,12);

        special_storage_response_H.readdata_H(31 downto 16) <= X"0000";
-----------------------------------------------------------------------------------
-- process to generate the write strobe signals for the outRams
-----------------------------------------------------------------------------------
-- purpose: generates signal enOutRamWrite_H
-- type   : combinational
-- inputs : writeStrobe_H, wrData_H
-- outputs: 
enOutRamWrite_control: process (cmd_clearAllSettings_H, cmd_clearSetting_H, lockFault_H, special_storage_request_H.writedata_H(11 downto 6), writeStrobe_H)
begin  -- process enFifoWrite_control
  enOutRamWrite_H <= (others => '0');  -- default assignment
  if (cmd_clearSetting_H = '1') or
     (cmd_clearAllSettings_H = '1') then 
     enOutRamWrite_H <= (others => '1');
  elsif (writeStrobe_H and not lockFault_H) ='1' then
     if (conv_integer(special_storage_request_H.writedata_H(11 downto 6)) < 24)    then  -- standard if-special operation and range within 24 output channels
      if ((rc_H  = '1') and not (conv_integer(input_mode_H) = 0)) or 
         (conv_integer(input_mode_H) = 5)  then -- test mode has no RC
        if (conv_integer(input_channel_H) < 50)    then  -- standard if-special operation and range within 50 input channels
          enOutRamWrite_H(conv_integer(special_storage_request_H.writedata_H(11 downto 6))) <= '1';
        end if; -- if (conv_integer(input_channel_H) < 50) 
      end if; -- if (rc_H  = '1') and not (conv_integer(input_mode_H) = 0) 
     end if; -- if (conv_integer(special_storage_request_H.writedata_H(11 downto 6)) < 24) 
  end if;
end process enOutRamWrite_control;

outRam_wrData_H(6 downto 0) <= "0000000" when (cmd_clearSetting_H = '1') else 
                               "0000000" when (cmd_clearAllSettings_H = '1') else 
                               special_address_H( 6 downto  0); -- store input channel associated with output channel
outRam_wrData_H(7) <= '0' when (cmd_clearSetting_H = '1') else -- controls inUse_Out_H and hence OLO_H
                      '0' when (cmd_clearAllSettings_H = '1') else 
                      '1' when (input_routing_H = '1') else                       -- set only for routing modi including OFT
                      '0';                                                                -- use this bit for usage statistics
outRam_wrData_H(8) <= '0' when (cmd_clearSetting_H = '1') else 
                      '0' when (cmd_clearAllSettings_H = '1') else 
                      special_storage_request_H.writedata_H(5);           -- store routing control bit
outRam_wrData_H(11 downto 9)  <= (others => '0');
outRam_wrData_H(15 downto 12) <= (others => '0') when (cmd_clearSetting_H = '1') else  -- store operating mode
                               (others => '0') when (cmd_clearAllSettings_H = '1') else 
                               special_storage_request_H.writedata_H(15 downto 12);

outRam_wrData_H(19 downto 16) <= conv_std_logic_vector(0,4);
-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 0 related storage
-----------------------------------------------------------------------------------
outRam_0 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(0),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam0_rdData_H(19 downto 0),
                B_DOUT   => outRam0_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 1 related storage
-----------------------------------------------------------------------------------
outRam_1 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(1),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam1_rdData_H(19 downto 0),
                B_DOUT   => outRam1_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 2 related storage
-----------------------------------------------------------------------------------
outRam_2 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(2),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam2_rdData_H(19 downto 0),
                B_DOUT   => outRam2_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 3 related storage
-----------------------------------------------------------------------------------
outRam_3 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(3),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam3_rdData_H(19 downto 0),
                B_DOUT   => outRam3_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 4 related storage
-----------------------------------------------------------------------------------
outRam_4 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(4),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam4_rdData_H(19 downto 0),
                B_DOUT   => outRam4_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 5 related storage
-----------------------------------------------------------------------------------
outRam_5 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(5),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam5_rdData_H(19 downto 0),
                B_DOUT   => outRam5_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 6 related storage
-----------------------------------------------------------------------------------
outRam_6 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(6),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam6_rdData_H(19 downto 0),
                B_DOUT   => outRam6_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 7 related storage
-----------------------------------------------------------------------------------
outRam_7 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(7),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam7_rdData_H(19 downto 0),
                B_DOUT   => outRam7_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 8 related storage
-----------------------------------------------------------------------------------
outRam_8 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(8),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam8_rdData_H(19 downto 0),
                B_DOUT   => outRam8_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 9 related storage
-----------------------------------------------------------------------------------
outRam_9 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(9),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam9_rdData_H(19 downto 0),
                B_DOUT   => outRam9_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 10 related storage
-----------------------------------------------------------------------------------
outRam_10 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(10),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam10_rdData_H(19 downto 0),
                B_DOUT   => outRam10_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 11 related storage
-----------------------------------------------------------------------------------
outRam_11 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(11),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam11_rdData_H(19 downto 0),
                B_DOUT   => outRam11_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 12 related storage
-----------------------------------------------------------------------------------
outRam_12 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(12),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam12_rdData_H(19 downto 0),
                B_DOUT   => outRam12_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 13 related storage
-----------------------------------------------------------------------------------
outRam_13 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(13),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam13_rdData_H(19 downto 0),
                B_DOUT   => outRam13_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 14 related storage
-----------------------------------------------------------------------------------
outRam_14 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(14),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam14_rdData_H(19 downto 0),
                B_DOUT   => outRam14_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 15 related storage
-----------------------------------------------------------------------------------
outRam_15 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(15),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam15_rdData_H(19 downto 0),
                B_DOUT   => outRam15_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 16 related storage
-----------------------------------------------------------------------------------
outRam_16 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(16),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam16_rdData_H(19 downto 0),
                B_DOUT   => outRam16_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 17 related storage
-----------------------------------------------------------------------------------
outRam_17 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(17),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam17_rdData_H(19 downto 0),
                B_DOUT   => outRam17_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 18 related storage
-----------------------------------------------------------------------------------
outRam_18 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(18),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam18_rdData_H(19 downto 0),
                B_DOUT   => outRam18_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 19 related storage
-----------------------------------------------------------------------------------
outRam_19 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(19),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam19_rdData_H(19 downto 0),
                B_DOUT   => outRam19_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 20 related storage
-----------------------------------------------------------------------------------
outRam_20 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(20),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam20_rdData_H(19 downto 0),
                B_DOUT   => outRam20_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 21 related storage
-----------------------------------------------------------------------------------
outRam_21 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(21),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam21_rdData_H(19 downto 0),
                B_DOUT   => outRam21_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 22 related storage
-----------------------------------------------------------------------------------
outRam_22 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(22),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam22_rdData_H(19 downto 0),
                B_DOUT   => outRam22_outData_H(19 downto 0)
                );
        ---

-----------------------------------------------------------------------------------
-- settings RAM for RCCS output 23 related storage
-----------------------------------------------------------------------------------
outRam_23 : PF_DPSRAM_SPECIAL 
        port map( 
                -- a-side of RAM used for communication
                -- b-side of RAM used for functional works
                -- inputs
                A_ADDR   => setting_adr_H(5 downto 0),
                A_BLK_EN => A_BLK_EN_H,
                A_DIN    => outRam_wrData_H(19 downto 0),
                A_WEN    => enOutRamWrite_H(23),
                B_ADDR   => storage_setting_special_H(5 downto 0),
                B_BLK_EN => B_BLK_EN_H,
                B_DIN    => data_b,
                B_WEN    => wren_b,
                CLK      => avs_clk_H,
                -- outputs
                A_DOUT   => outRam23_rdData_H(19 downto 0),
                B_DOUT   => outRam23_outData_H(19 downto 0)
                );
        ---

outRam_rdData_H <= outRam0_rdData_H when (conv_integer(output_channel_H) = 0) else 
                   outRam1_rdData_H when (conv_integer(output_channel_H) = 1) else 
                   outRam2_rdData_H when (conv_integer(output_channel_H) = 2) else 
                   outRam3_rdData_H when (conv_integer(output_channel_H) = 3) else 
                   outRam4_rdData_H when (conv_integer(output_channel_H) = 4) else 
                   outRam5_rdData_H when (conv_integer(output_channel_H) = 5) else 
                   outRam6_rdData_H when (conv_integer(output_channel_H) = 6) else 
                   outRam7_rdData_H when (conv_integer(output_channel_H) = 7) else 
                   outRam8_rdData_H when (conv_integer(output_channel_H) = 8) else 
                   outRam9_rdData_H when (conv_integer(output_channel_H) = 9) else 
                   outRam10_rdData_H when (conv_integer(output_channel_H) = 10) else 
                   outRam11_rdData_H when (conv_integer(output_channel_H) = 11) else 
                   outRam12_rdData_H when (conv_integer(output_channel_H) = 12) else 
                   outRam13_rdData_H when (conv_integer(output_channel_H) = 13) else 
                   outRam14_rdData_H when (conv_integer(output_channel_H) = 14) else 
                   outRam15_rdData_H when (conv_integer(output_channel_H) = 15) else 
                   outRam16_rdData_H when (conv_integer(output_channel_H) = 16) else 
                   outRam17_rdData_H when (conv_integer(output_channel_H) = 17) else 
                   outRam18_rdData_H when (conv_integer(output_channel_H) = 18) else 
                   outRam19_rdData_H when (conv_integer(output_channel_H) = 19) else 
                   outRam20_rdData_H when (conv_integer(output_channel_H) = 20) else 
                   outRam21_rdData_H when (conv_integer(output_channel_H) = 21) else 
                   outRam22_rdData_H when (conv_integer(output_channel_H) = 22) else 
                   outRam23_rdData_H when (conv_integer(output_channel_H) = 23) else 
                   (others => '0'); 
fault_registers: process (avs_clk_H)
  begin  -- process fault_registers
     if avs_clk_H'event and avs_clk_H = '1' then  -- rising clock edge
        lockFaultS_H <= lockFault_H;
        led_programming_fault_L <= not lockFault_H; -- controls led that signals programming error
        if special_storage_response_H.waitrequest_H = '0' then
          old_storage_request_H <= special_storage_request_H;
        end if;
        if not((cmd_clearAllSettings_H = '1') or (avs_reset_L = '0')) then
          if (lockFault_H = '1') and (lockFaultS_H = '0') then -- only log first error
            faultVector_H   <= faultVectorC_H;
            fail_address_H  <= old_storage_request_H.address_H(31 downto 0);    -- system address
            fail_data_H     <= old_storage_request_H.writedata_H(31 downto 0);   -- write data
          end if;    -- if lockFault_H = '0'
        else
            faultVector_H   <= (others => '0');
            fail_address_H  <= (others => '0');
            fail_data_H     <= (others => '0');
        end if;      -- if cmd_clearAllSettings_H = '1'  
     end if; -- if avs_clk_H'event and avs_clk_H = '1'  
  end process fault_registers;

  faultVectorC_H <= "00000000"  &   -- this is the set term for lock_fault
                   input_Range_Fault_H  & output_Range_Fault_H  & rc_bit_Fault_H & mode_Fault_H & 
                   protocol_Fault_H & routing_Fault_H & inUse_Out_Fault_H & inUse_In_Fault_H;

  lockFault_H <= '0' when (cmd_clearAllSettings_H = '1') or (avs_reset_L = '0') else -- clear has prio
                 '1' when (or_reduce(faultVectorC_H) = '1') else -- set term to activate error lock!
                  lockFaultS_H; -- hold term to keep locked even if error condition disappears

  input_routing_H <= '1' when ((rc_H = '1') and -- RC Bit set
                               ((inRam_wrData_H(15 downto 12) = X"4") or -- INT
                                (inRam_wrData_H(15 downto 12) = X"7") or -- IMG
                                (inRam_wrData_H(15 downto 12) = X"C") or -- ITM
                                (inRam_wrData_H(15 downto 12) = X"F"))   -- IMM (PT-LO+RX)
                              ) else -- routing control set
                     '1' when ((rc_H = '0') and -- RC Bit clear
                               ((inRam_wrData_H(15 downto 12) = X"5") or -- ETL
                                (inRam_wrData_H(15 downto 12) = X"D"))   -- ETM
                              ) else -- routing control clear
                     '0'; -- PAT0, PAT1, LOM, LON, ETM, OFF



  output_routing_H <= '1' when ((rc_H = '1') and -- RC Bit set
                               ((inRam_wrData_H(15 downto 12) = X"4") or -- INT
                                (inRam_wrData_H(15 downto 12) = X"7") or -- IMG
                                (inRam_wrData_H(15 downto 12) = X"C") or -- ITM
                                (inRam_wrData_H(15 downto 12) = X"F"))   -- IMM (PT-LO+RX)
                              ) else -- routing control dependent
                     '0'; -- PAT0, PAT1, LOM, LON, ETM, ETL, OFF



---------------------------------------------------------------------
-- record assignments 
---------------------------------------------------------------------
  inRam_H.out_0_H.input_mode_H     <= inRam0_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_0_H.output_channel_H <= inRam0_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_0_H.rc_H             <= inRam0_outData_H(5); -- request dependent ram output in record
  inRam_H.out_0_H.output_routing_H <= inRam0_outData_H(2); -- request dependent ram output in record
  inRam_H.out_0_H.input_routing_H  <= inRam0_outData_H(17); -- request dependent ram output in record
  inRam_H.out_0_H.in_use_H         <= inRam0_outData_H(16); -- request dependent ram output in record
  inRam_H.out_1_H.input_mode_H     <= inRam1_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_1_H.output_channel_H <= inRam1_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_1_H.rc_H             <= inRam1_outData_H(5); -- request dependent ram output in record
  inRam_H.out_1_H.output_routing_H <= inRam1_outData_H(2); -- request dependent ram output in record
  inRam_H.out_1_H.input_routing_H  <= inRam1_outData_H(17); -- request dependent ram output in record
  inRam_H.out_1_H.in_use_H         <= inRam1_outData_H(16); -- request dependent ram output in record
  inRam_H.out_2_H.input_mode_H     <= inRam2_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_2_H.output_channel_H <= inRam2_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_2_H.rc_H             <= inRam2_outData_H(5); -- request dependent ram output in record
  inRam_H.out_2_H.output_routing_H <= inRam2_outData_H(2); -- request dependent ram output in record
  inRam_H.out_2_H.input_routing_H  <= inRam2_outData_H(17); -- request dependent ram output in record
  inRam_H.out_2_H.in_use_H         <= inRam2_outData_H(16); -- request dependent ram output in record
  inRam_H.out_3_H.input_mode_H     <= inRam3_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_3_H.output_channel_H <= inRam3_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_3_H.rc_H             <= inRam3_outData_H(5); -- request dependent ram output in record
  inRam_H.out_3_H.output_routing_H <= inRam3_outData_H(2); -- request dependent ram output in record
  inRam_H.out_3_H.input_routing_H  <= inRam3_outData_H(17); -- request dependent ram output in record
  inRam_H.out_3_H.in_use_H         <= inRam3_outData_H(16); -- request dependent ram output in record
  inRam_H.out_4_H.input_mode_H     <= inRam4_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_4_H.output_channel_H <= inRam4_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_4_H.rc_H             <= inRam4_outData_H(5); -- request dependent ram output in record
  inRam_H.out_4_H.output_routing_H <= inRam4_outData_H(2); -- request dependent ram output in record
  inRam_H.out_4_H.input_routing_H  <= inRam4_outData_H(17); -- request dependent ram output in record
  inRam_H.out_4_H.in_use_H         <= inRam4_outData_H(16); -- request dependent ram output in record
  inRam_H.out_5_H.input_mode_H     <= inRam5_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_5_H.output_channel_H <= inRam5_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_5_H.rc_H             <= inRam5_outData_H(5); -- request dependent ram output in record
  inRam_H.out_5_H.output_routing_H <= inRam5_outData_H(2); -- request dependent ram output in record
  inRam_H.out_5_H.input_routing_H  <= inRam5_outData_H(17); -- request dependent ram output in record
  inRam_H.out_5_H.in_use_H         <= inRam5_outData_H(16); -- request dependent ram output in record
  inRam_H.out_6_H.input_mode_H     <= inRam6_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_6_H.output_channel_H <= inRam6_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_6_H.rc_H             <= inRam6_outData_H(5); -- request dependent ram output in record
  inRam_H.out_6_H.output_routing_H <= inRam6_outData_H(2); -- request dependent ram output in record
  inRam_H.out_6_H.input_routing_H  <= inRam6_outData_H(17); -- request dependent ram output in record
  inRam_H.out_6_H.in_use_H         <= inRam6_outData_H(16); -- request dependent ram output in record
  inRam_H.out_7_H.input_mode_H     <= inRam7_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_7_H.output_channel_H <= inRam7_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_7_H.rc_H             <= inRam7_outData_H(5); -- request dependent ram output in record
  inRam_H.out_7_H.output_routing_H <= inRam7_outData_H(2); -- request dependent ram output in record
  inRam_H.out_7_H.input_routing_H  <= inRam7_outData_H(17); -- request dependent ram output in record
  inRam_H.out_7_H.in_use_H         <= inRam7_outData_H(16); -- request dependent ram output in record
  inRam_H.out_8_H.input_mode_H     <= inRam8_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_8_H.output_channel_H <= inRam8_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_8_H.rc_H             <= inRam8_outData_H(5); -- request dependent ram output in record
  inRam_H.out_8_H.output_routing_H <= inRam8_outData_H(2); -- request dependent ram output in record
  inRam_H.out_8_H.input_routing_H  <= inRam8_outData_H(17); -- request dependent ram output in record
  inRam_H.out_8_H.in_use_H         <= inRam8_outData_H(16); -- request dependent ram output in record
  inRam_H.out_9_H.input_mode_H     <= inRam9_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_9_H.output_channel_H <= inRam9_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_9_H.rc_H             <= inRam9_outData_H(5); -- request dependent ram output in record
  inRam_H.out_9_H.output_routing_H <= inRam9_outData_H(2); -- request dependent ram output in record
  inRam_H.out_9_H.input_routing_H  <= inRam9_outData_H(17); -- request dependent ram output in record
  inRam_H.out_9_H.in_use_H         <= inRam9_outData_H(16); -- request dependent ram output in record
  inRam_H.out_10_H.input_mode_H     <= inRam10_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_10_H.output_channel_H <= inRam10_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_10_H.rc_H             <= inRam10_outData_H(5); -- request dependent ram output in record
  inRam_H.out_10_H.output_routing_H <= inRam10_outData_H(2); -- request dependent ram output in record
  inRam_H.out_10_H.input_routing_H  <= inRam10_outData_H(17); -- request dependent ram output in record
  inRam_H.out_10_H.in_use_H         <= inRam10_outData_H(16); -- request dependent ram output in record
  inRam_H.out_11_H.input_mode_H     <= inRam11_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_11_H.output_channel_H <= inRam11_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_11_H.rc_H             <= inRam11_outData_H(5); -- request dependent ram output in record
  inRam_H.out_11_H.output_routing_H <= inRam11_outData_H(2); -- request dependent ram output in record
  inRam_H.out_11_H.input_routing_H  <= inRam11_outData_H(17); -- request dependent ram output in record
  inRam_H.out_11_H.in_use_H         <= inRam11_outData_H(16); -- request dependent ram output in record
  inRam_H.out_12_H.input_mode_H     <= inRam12_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_12_H.output_channel_H <= inRam12_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_12_H.rc_H             <= inRam12_outData_H(5); -- request dependent ram output in record
  inRam_H.out_12_H.output_routing_H <= inRam12_outData_H(2); -- request dependent ram output in record
  inRam_H.out_12_H.input_routing_H  <= inRam12_outData_H(17); -- request dependent ram output in record
  inRam_H.out_12_H.in_use_H         <= inRam12_outData_H(16); -- request dependent ram output in record
  inRam_H.out_13_H.input_mode_H     <= inRam13_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_13_H.output_channel_H <= inRam13_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_13_H.rc_H             <= inRam13_outData_H(5); -- request dependent ram output in record
  inRam_H.out_13_H.output_routing_H <= inRam13_outData_H(2); -- request dependent ram output in record
  inRam_H.out_13_H.input_routing_H  <= inRam13_outData_H(17); -- request dependent ram output in record
  inRam_H.out_13_H.in_use_H         <= inRam13_outData_H(16); -- request dependent ram output in record
  inRam_H.out_14_H.input_mode_H     <= inRam14_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_14_H.output_channel_H <= inRam14_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_14_H.rc_H             <= inRam14_outData_H(5); -- request dependent ram output in record
  inRam_H.out_14_H.output_routing_H <= inRam14_outData_H(2); -- request dependent ram output in record
  inRam_H.out_14_H.input_routing_H  <= inRam14_outData_H(17); -- request dependent ram output in record
  inRam_H.out_14_H.in_use_H         <= inRam14_outData_H(16); -- request dependent ram output in record
  inRam_H.out_15_H.input_mode_H     <= inRam15_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_15_H.output_channel_H <= inRam15_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_15_H.rc_H             <= inRam15_outData_H(5); -- request dependent ram output in record
  inRam_H.out_15_H.output_routing_H <= inRam15_outData_H(2); -- request dependent ram output in record
  inRam_H.out_15_H.input_routing_H  <= inRam15_outData_H(17); -- request dependent ram output in record
  inRam_H.out_15_H.in_use_H         <= inRam15_outData_H(16); -- request dependent ram output in record
  inRam_H.out_16_H.input_mode_H     <= inRam16_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_16_H.output_channel_H <= inRam16_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_16_H.rc_H             <= inRam16_outData_H(5); -- request dependent ram output in record
  inRam_H.out_16_H.output_routing_H <= inRam16_outData_H(2); -- request dependent ram output in record
  inRam_H.out_16_H.input_routing_H  <= inRam16_outData_H(17); -- request dependent ram output in record
  inRam_H.out_16_H.in_use_H         <= inRam16_outData_H(16); -- request dependent ram output in record
  inRam_H.out_17_H.input_mode_H     <= inRam17_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_17_H.output_channel_H <= inRam17_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_17_H.rc_H             <= inRam17_outData_H(5); -- request dependent ram output in record
  inRam_H.out_17_H.output_routing_H <= inRam17_outData_H(2); -- request dependent ram output in record
  inRam_H.out_17_H.input_routing_H  <= inRam17_outData_H(17); -- request dependent ram output in record
  inRam_H.out_17_H.in_use_H         <= inRam17_outData_H(16); -- request dependent ram output in record
  inRam_H.out_18_H.input_mode_H     <= inRam18_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_18_H.output_channel_H <= inRam18_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_18_H.rc_H             <= inRam18_outData_H(5); -- request dependent ram output in record
  inRam_H.out_18_H.output_routing_H <= inRam18_outData_H(2); -- request dependent ram output in record
  inRam_H.out_18_H.input_routing_H  <= inRam18_outData_H(17); -- request dependent ram output in record
  inRam_H.out_18_H.in_use_H         <= inRam18_outData_H(16); -- request dependent ram output in record
  inRam_H.out_19_H.input_mode_H     <= inRam19_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_19_H.output_channel_H <= inRam19_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_19_H.rc_H             <= inRam19_outData_H(5); -- request dependent ram output in record
  inRam_H.out_19_H.output_routing_H <= inRam19_outData_H(2); -- request dependent ram output in record
  inRam_H.out_19_H.input_routing_H  <= inRam19_outData_H(17); -- request dependent ram output in record
  inRam_H.out_19_H.in_use_H         <= inRam19_outData_H(16); -- request dependent ram output in record
  inRam_H.out_20_H.input_mode_H     <= inRam20_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_20_H.output_channel_H <= inRam20_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_20_H.rc_H             <= inRam20_outData_H(5); -- request dependent ram output in record
  inRam_H.out_20_H.output_routing_H <= inRam20_outData_H(2); -- request dependent ram output in record
  inRam_H.out_20_H.input_routing_H  <= inRam20_outData_H(17); -- request dependent ram output in record
  inRam_H.out_20_H.in_use_H         <= inRam20_outData_H(16); -- request dependent ram output in record
  inRam_H.out_21_H.input_mode_H     <= inRam21_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_21_H.output_channel_H <= inRam21_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_21_H.rc_H             <= inRam21_outData_H(5); -- request dependent ram output in record
  inRam_H.out_21_H.output_routing_H <= inRam21_outData_H(2); -- request dependent ram output in record
  inRam_H.out_21_H.input_routing_H  <= inRam21_outData_H(17); -- request dependent ram output in record
  inRam_H.out_21_H.in_use_H         <= inRam21_outData_H(16); -- request dependent ram output in record
  inRam_H.out_22_H.input_mode_H     <= inRam22_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_22_H.output_channel_H <= inRam22_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_22_H.rc_H             <= inRam22_outData_H(5); -- request dependent ram output in record
  inRam_H.out_22_H.output_routing_H <= inRam22_outData_H(2); -- request dependent ram output in record
  inRam_H.out_22_H.input_routing_H  <= inRam22_outData_H(17); -- request dependent ram output in record
  inRam_H.out_22_H.in_use_H         <= inRam22_outData_H(16); -- request dependent ram output in record
  inRam_H.out_23_H.input_mode_H     <= inRam23_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_23_H.output_channel_H <= inRam23_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_23_H.rc_H             <= inRam23_outData_H(5); -- request dependent ram output in record
  inRam_H.out_23_H.output_routing_H <= inRam23_outData_H(2); -- request dependent ram output in record
  inRam_H.out_23_H.input_routing_H  <= inRam23_outData_H(17); -- request dependent ram output in record
  inRam_H.out_23_H.in_use_H         <= inRam23_outData_H(16); -- request dependent ram output in record
  inRam_H.out_24_H.input_mode_H     <= inRam24_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_24_H.output_channel_H <= inRam24_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_24_H.rc_H             <= inRam24_outData_H(5); -- request dependent ram output in record
  inRam_H.out_24_H.output_routing_H <= inRam24_outData_H(2); -- request dependent ram output in record
  inRam_H.out_24_H.input_routing_H  <= inRam24_outData_H(17); -- request dependent ram output in record
  inRam_H.out_24_H.in_use_H         <= inRam24_outData_H(16); -- request dependent ram output in record
  inRam_H.out_25_H.input_mode_H     <= inRam25_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_25_H.output_channel_H <= inRam25_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_25_H.rc_H             <= inRam25_outData_H(5); -- request dependent ram output in record
  inRam_H.out_25_H.output_routing_H <= inRam25_outData_H(2); -- request dependent ram output in record
  inRam_H.out_25_H.input_routing_H  <= inRam25_outData_H(17); -- request dependent ram output in record
  inRam_H.out_25_H.in_use_H         <= inRam25_outData_H(16); -- request dependent ram output in record
  inRam_H.out_26_H.input_mode_H     <= inRam26_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_26_H.output_channel_H <= inRam26_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_26_H.rc_H             <= inRam26_outData_H(5); -- request dependent ram output in record
  inRam_H.out_26_H.output_routing_H <= inRam26_outData_H(2); -- request dependent ram output in record
  inRam_H.out_26_H.input_routing_H  <= inRam26_outData_H(17); -- request dependent ram output in record
  inRam_H.out_26_H.in_use_H         <= inRam26_outData_H(16); -- request dependent ram output in record
  inRam_H.out_27_H.input_mode_H     <= inRam27_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_27_H.output_channel_H <= inRam27_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_27_H.rc_H             <= inRam27_outData_H(5); -- request dependent ram output in record
  inRam_H.out_27_H.output_routing_H <= inRam27_outData_H(2); -- request dependent ram output in record
  inRam_H.out_27_H.input_routing_H  <= inRam27_outData_H(17); -- request dependent ram output in record
  inRam_H.out_27_H.in_use_H         <= inRam27_outData_H(16); -- request dependent ram output in record
  inRam_H.out_28_H.input_mode_H     <= inRam28_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_28_H.output_channel_H <= inRam28_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_28_H.rc_H             <= inRam28_outData_H(5); -- request dependent ram output in record
  inRam_H.out_28_H.output_routing_H <= inRam28_outData_H(2); -- request dependent ram output in record
  inRam_H.out_28_H.input_routing_H  <= inRam28_outData_H(17); -- request dependent ram output in record
  inRam_H.out_28_H.in_use_H         <= inRam28_outData_H(16); -- request dependent ram output in record
  inRam_H.out_29_H.input_mode_H     <= inRam29_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_29_H.output_channel_H <= inRam29_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_29_H.rc_H             <= inRam29_outData_H(5); -- request dependent ram output in record
  inRam_H.out_29_H.output_routing_H <= inRam29_outData_H(2); -- request dependent ram output in record
  inRam_H.out_29_H.input_routing_H  <= inRam29_outData_H(17); -- request dependent ram output in record
  inRam_H.out_29_H.in_use_H         <= inRam29_outData_H(16); -- request dependent ram output in record
  inRam_H.out_30_H.input_mode_H     <= inRam30_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_30_H.output_channel_H <= inRam30_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_30_H.rc_H             <= inRam30_outData_H(5); -- request dependent ram output in record
  inRam_H.out_30_H.output_routing_H <= inRam30_outData_H(2); -- request dependent ram output in record
  inRam_H.out_30_H.input_routing_H  <= inRam30_outData_H(17); -- request dependent ram output in record
  inRam_H.out_30_H.in_use_H         <= inRam30_outData_H(16); -- request dependent ram output in record
  inRam_H.out_31_H.input_mode_H     <= inRam31_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_31_H.output_channel_H <= inRam31_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_31_H.rc_H             <= inRam31_outData_H(5); -- request dependent ram output in record
  inRam_H.out_31_H.output_routing_H <= inRam31_outData_H(2); -- request dependent ram output in record
  inRam_H.out_31_H.input_routing_H  <= inRam31_outData_H(17); -- request dependent ram output in record
  inRam_H.out_31_H.in_use_H         <= inRam31_outData_H(16); -- request dependent ram output in record
  inRam_H.out_32_H.input_mode_H     <= inRam32_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_32_H.output_channel_H <= inRam32_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_32_H.rc_H             <= inRam32_outData_H(5); -- request dependent ram output in record
  inRam_H.out_32_H.output_routing_H <= inRam32_outData_H(2); -- request dependent ram output in record
  inRam_H.out_32_H.input_routing_H  <= inRam32_outData_H(17); -- request dependent ram output in record
  inRam_H.out_32_H.in_use_H         <= inRam32_outData_H(16); -- request dependent ram output in record
  inRam_H.out_33_H.input_mode_H     <= inRam33_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_33_H.output_channel_H <= inRam33_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_33_H.rc_H             <= inRam33_outData_H(5); -- request dependent ram output in record
  inRam_H.out_33_H.output_routing_H <= inRam33_outData_H(2); -- request dependent ram output in record
  inRam_H.out_33_H.input_routing_H  <= inRam33_outData_H(17); -- request dependent ram output in record
  inRam_H.out_33_H.in_use_H         <= inRam33_outData_H(16); -- request dependent ram output in record
  inRam_H.out_34_H.input_mode_H     <= inRam34_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_34_H.output_channel_H <= inRam34_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_34_H.rc_H             <= inRam34_outData_H(5); -- request dependent ram output in record
  inRam_H.out_34_H.output_routing_H <= inRam34_outData_H(2); -- request dependent ram output in record
  inRam_H.out_34_H.input_routing_H  <= inRam34_outData_H(17); -- request dependent ram output in record
  inRam_H.out_34_H.in_use_H         <= inRam34_outData_H(16); -- request dependent ram output in record
  inRam_H.out_35_H.input_mode_H     <= inRam35_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_35_H.output_channel_H <= inRam35_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_35_H.rc_H             <= inRam35_outData_H(5); -- request dependent ram output in record
  inRam_H.out_35_H.output_routing_H <= inRam35_outData_H(2); -- request dependent ram output in record
  inRam_H.out_35_H.input_routing_H  <= inRam35_outData_H(17); -- request dependent ram output in record
  inRam_H.out_35_H.in_use_H         <= inRam35_outData_H(16); -- request dependent ram output in record
  inRam_H.out_36_H.input_mode_H     <= inRam36_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_36_H.output_channel_H <= inRam36_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_36_H.rc_H             <= inRam36_outData_H(5); -- request dependent ram output in record
  inRam_H.out_36_H.output_routing_H <= inRam36_outData_H(2); -- request dependent ram output in record
  inRam_H.out_36_H.input_routing_H  <= inRam36_outData_H(17); -- request dependent ram output in record
  inRam_H.out_36_H.in_use_H         <= inRam36_outData_H(16); -- request dependent ram output in record
  inRam_H.out_37_H.input_mode_H     <= inRam37_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_37_H.output_channel_H <= inRam37_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_37_H.rc_H             <= inRam37_outData_H(5); -- request dependent ram output in record
  inRam_H.out_37_H.output_routing_H <= inRam37_outData_H(2); -- request dependent ram output in record
  inRam_H.out_37_H.input_routing_H  <= inRam37_outData_H(17); -- request dependent ram output in record
  inRam_H.out_37_H.in_use_H         <= inRam37_outData_H(16); -- request dependent ram output in record
  inRam_H.out_38_H.input_mode_H     <= inRam38_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_38_H.output_channel_H <= inRam38_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_38_H.rc_H             <= inRam38_outData_H(5); -- request dependent ram output in record
  inRam_H.out_38_H.output_routing_H <= inRam38_outData_H(2); -- request dependent ram output in record
  inRam_H.out_38_H.input_routing_H  <= inRam38_outData_H(17); -- request dependent ram output in record
  inRam_H.out_38_H.in_use_H         <= inRam38_outData_H(16); -- request dependent ram output in record
  inRam_H.out_39_H.input_mode_H     <= inRam39_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_39_H.output_channel_H <= inRam39_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_39_H.rc_H             <= inRam39_outData_H(5); -- request dependent ram output in record
  inRam_H.out_39_H.output_routing_H <= inRam39_outData_H(2); -- request dependent ram output in record
  inRam_H.out_39_H.input_routing_H  <= inRam39_outData_H(17); -- request dependent ram output in record
  inRam_H.out_39_H.in_use_H         <= inRam39_outData_H(16); -- request dependent ram output in record
  inRam_H.out_40_H.input_mode_H     <= inRam40_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_40_H.output_channel_H <= inRam40_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_40_H.rc_H             <= inRam40_outData_H(5); -- request dependent ram output in record
  inRam_H.out_40_H.output_routing_H <= inRam40_outData_H(2); -- request dependent ram output in record
  inRam_H.out_40_H.input_routing_H  <= inRam40_outData_H(17); -- request dependent ram output in record
  inRam_H.out_40_H.in_use_H         <= inRam40_outData_H(16); -- request dependent ram output in record
  inRam_H.out_41_H.input_mode_H     <= inRam41_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_41_H.output_channel_H <= inRam41_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_41_H.rc_H             <= inRam41_outData_H(5); -- request dependent ram output in record
  inRam_H.out_41_H.output_routing_H <= inRam41_outData_H(2); -- request dependent ram output in record
  inRam_H.out_41_H.input_routing_H  <= inRam41_outData_H(17); -- request dependent ram output in record
  inRam_H.out_41_H.in_use_H         <= inRam41_outData_H(16); -- request dependent ram output in record
  inRam_H.out_42_H.input_mode_H     <= inRam42_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_42_H.output_channel_H <= inRam42_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_42_H.rc_H             <= inRam42_outData_H(5); -- request dependent ram output in record
  inRam_H.out_42_H.output_routing_H <= inRam42_outData_H(2); -- request dependent ram output in record
  inRam_H.out_42_H.input_routing_H  <= inRam42_outData_H(17); -- request dependent ram output in record
  inRam_H.out_42_H.in_use_H         <= inRam42_outData_H(16); -- request dependent ram output in record
  inRam_H.out_43_H.input_mode_H     <= inRam43_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_43_H.output_channel_H <= inRam43_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_43_H.rc_H             <= inRam43_outData_H(5); -- request dependent ram output in record
  inRam_H.out_43_H.output_routing_H <= inRam43_outData_H(2); -- request dependent ram output in record
  inRam_H.out_43_H.input_routing_H  <= inRam43_outData_H(17); -- request dependent ram output in record
  inRam_H.out_43_H.in_use_H         <= inRam43_outData_H(16); -- request dependent ram output in record
  inRam_H.out_44_H.input_mode_H     <= inRam44_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_44_H.output_channel_H <= inRam44_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_44_H.rc_H             <= inRam44_outData_H(5); -- request dependent ram output in record
  inRam_H.out_44_H.output_routing_H <= inRam44_outData_H(2); -- request dependent ram output in record
  inRam_H.out_44_H.input_routing_H  <= inRam44_outData_H(17); -- request dependent ram output in record
  inRam_H.out_44_H.in_use_H         <= inRam44_outData_H(16); -- request dependent ram output in record
  inRam_H.out_45_H.input_mode_H     <= inRam45_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_45_H.output_channel_H <= inRam45_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_45_H.rc_H             <= inRam45_outData_H(5); -- request dependent ram output in record
  inRam_H.out_45_H.output_routing_H <= inRam45_outData_H(2); -- request dependent ram output in record
  inRam_H.out_45_H.input_routing_H  <= inRam45_outData_H(17); -- request dependent ram output in record
  inRam_H.out_45_H.in_use_H         <= inRam45_outData_H(16); -- request dependent ram output in record
  inRam_H.out_46_H.input_mode_H     <= inRam46_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_46_H.output_channel_H <= inRam46_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_46_H.rc_H             <= inRam46_outData_H(5); -- request dependent ram output in record
  inRam_H.out_46_H.output_routing_H <= inRam46_outData_H(2); -- request dependent ram output in record
  inRam_H.out_46_H.input_routing_H  <= inRam46_outData_H(17); -- request dependent ram output in record
  inRam_H.out_46_H.in_use_H         <= inRam46_outData_H(16); -- request dependent ram output in record
  inRam_H.out_47_H.input_mode_H     <= inRam47_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_47_H.output_channel_H <= inRam47_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_47_H.rc_H             <= inRam47_outData_H(5); -- request dependent ram output in record
  inRam_H.out_47_H.output_routing_H <= inRam47_outData_H(2); -- request dependent ram output in record
  inRam_H.out_47_H.input_routing_H  <= inRam47_outData_H(17); -- request dependent ram output in record
  inRam_H.out_47_H.in_use_H         <= inRam47_outData_H(16); -- request dependent ram output in record
  inRam_H.out_48_H.input_mode_H     <= inRam48_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_48_H.output_channel_H <= inRam48_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_48_H.rc_H             <= inRam48_outData_H(5); -- request dependent ram output in record
  inRam_H.out_48_H.output_routing_H <= inRam48_outData_H(2); -- request dependent ram output in record
  inRam_H.out_48_H.input_routing_H  <= inRam48_outData_H(17); -- request dependent ram output in record
  inRam_H.out_48_H.in_use_H         <= inRam48_outData_H(16); -- request dependent ram output in record
  inRam_H.out_49_H.input_mode_H     <= inRam49_outData_H(15 downto 12); -- request dependent ram output in record
  inRam_H.out_49_H.output_channel_H <= inRam49_outData_H(11 downto  6); -- request dependent ram output in record
  inRam_H.out_49_H.rc_H             <= inRam49_outData_H(5); -- request dependent ram output in record
  inRam_H.out_49_H.output_routing_H <= inRam49_outData_H(2); -- request dependent ram output in record
  inRam_H.out_49_H.input_routing_H  <= inRam49_outData_H(17); -- request dependent ram output in record
  inRam_H.out_49_H.in_use_H         <= inRam49_outData_H(16); -- request dependent ram output in record

  outRam_H.out_0_H.input_mode_H    <= outRam0_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_0_H.input_channel_H <= outRam0_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_0_H.input_routing_H <= outRam0_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_0_H.rc_H            <= outRam0_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_1_H.input_mode_H    <= outRam1_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_1_H.input_channel_H <= outRam1_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_1_H.input_routing_H <= outRam1_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_1_H.rc_H            <= outRam1_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_2_H.input_mode_H    <= outRam2_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_2_H.input_channel_H <= outRam2_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_2_H.input_routing_H <= outRam2_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_2_H.rc_H            <= outRam2_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_3_H.input_mode_H    <= outRam3_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_3_H.input_channel_H <= outRam3_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_3_H.input_routing_H <= outRam3_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_3_H.rc_H            <= outRam3_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_4_H.input_mode_H    <= outRam4_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_4_H.input_channel_H <= outRam4_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_4_H.input_routing_H <= outRam4_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_4_H.rc_H            <= outRam4_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_5_H.input_mode_H    <= outRam5_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_5_H.input_channel_H <= outRam5_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_5_H.input_routing_H <= outRam5_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_5_H.rc_H            <= outRam5_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_6_H.input_mode_H    <= outRam6_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_6_H.input_channel_H <= outRam6_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_6_H.input_routing_H <= outRam6_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_6_H.rc_H            <= outRam6_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_7_H.input_mode_H    <= outRam7_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_7_H.input_channel_H <= outRam7_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_7_H.input_routing_H <= outRam7_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_7_H.rc_H            <= outRam7_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_8_H.input_mode_H    <= outRam8_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_8_H.input_channel_H <= outRam8_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_8_H.input_routing_H <= outRam8_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_8_H.rc_H            <= outRam8_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_9_H.input_mode_H    <= outRam9_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_9_H.input_channel_H <= outRam9_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_9_H.input_routing_H <= outRam9_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_9_H.rc_H            <= outRam9_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_10_H.input_mode_H    <= outRam10_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_10_H.input_channel_H <= outRam10_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_10_H.input_routing_H <= outRam10_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_10_H.rc_H            <= outRam10_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_11_H.input_mode_H    <= outRam11_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_11_H.input_channel_H <= outRam11_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_11_H.input_routing_H <= outRam11_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_11_H.rc_H            <= outRam11_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_12_H.input_mode_H    <= outRam12_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_12_H.input_channel_H <= outRam12_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_12_H.input_routing_H <= outRam12_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_12_H.rc_H            <= outRam12_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_13_H.input_mode_H    <= outRam13_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_13_H.input_channel_H <= outRam13_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_13_H.input_routing_H <= outRam13_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_13_H.rc_H            <= outRam13_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_14_H.input_mode_H    <= outRam14_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_14_H.input_channel_H <= outRam14_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_14_H.input_routing_H <= outRam14_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_14_H.rc_H            <= outRam14_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_15_H.input_mode_H    <= outRam15_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_15_H.input_channel_H <= outRam15_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_15_H.input_routing_H <= outRam15_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_15_H.rc_H            <= outRam15_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_16_H.input_mode_H    <= outRam16_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_16_H.input_channel_H <= outRam16_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_16_H.input_routing_H <= outRam16_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_16_H.rc_H            <= outRam16_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_17_H.input_mode_H    <= outRam17_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_17_H.input_channel_H <= outRam17_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_17_H.input_routing_H <= outRam17_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_17_H.rc_H            <= outRam17_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_18_H.input_mode_H    <= outRam18_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_18_H.input_channel_H <= outRam18_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_18_H.input_routing_H <= outRam18_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_18_H.rc_H            <= outRam18_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_19_H.input_mode_H    <= outRam19_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_19_H.input_channel_H <= outRam19_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_19_H.input_routing_H <= outRam19_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_19_H.rc_H            <= outRam19_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_20_H.input_mode_H    <= outRam20_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_20_H.input_channel_H <= outRam20_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_20_H.input_routing_H <= outRam20_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_20_H.rc_H            <= outRam20_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_21_H.input_mode_H    <= outRam21_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_21_H.input_channel_H <= outRam21_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_21_H.input_routing_H <= outRam21_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_21_H.rc_H            <= outRam21_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_22_H.input_mode_H    <= outRam22_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_22_H.input_channel_H <= outRam22_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_22_H.input_routing_H <= outRam22_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_22_H.rc_H            <= outRam22_outData_H( 8); -- request dependent ram output in record
  outRam_H.out_23_H.input_mode_H    <= outRam23_outData_H(15 downto 12); -- request dependent ram output in record
  outRam_H.out_23_H.input_channel_H <= outRam23_outData_H( 6 downto  0); -- request dependent ram output in record
  outRam_H.out_23_H.input_routing_H <= outRam23_outData_H( 7); -- request dependent ram output in record
  outRam_H.out_23_H.rc_H            <= outRam23_outData_H( 8); -- request dependent ram output in record

  inRamRd_H.out_0_H.input_mode_H     <= inRam0_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_0_H.output_channel_H <= inRam0_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_0_H.rc_H             <= inRam0_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_0_H.output_routing_H <= inRam0_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_0_H.input_routing_H  <= inRam0_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_0_H.in_use_H         <= inRam0_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_1_H.input_mode_H     <= inRam1_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_1_H.output_channel_H <= inRam1_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_1_H.rc_H             <= inRam1_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_1_H.output_routing_H <= inRam1_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_1_H.input_routing_H  <= inRam1_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_1_H.in_use_H         <= inRam1_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_2_H.input_mode_H     <= inRam2_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_2_H.output_channel_H <= inRam2_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_2_H.rc_H             <= inRam2_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_2_H.output_routing_H <= inRam2_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_2_H.input_routing_H  <= inRam2_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_2_H.in_use_H         <= inRam2_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_3_H.input_mode_H     <= inRam3_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_3_H.output_channel_H <= inRam3_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_3_H.rc_H             <= inRam3_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_3_H.output_routing_H <= inRam3_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_3_H.input_routing_H  <= inRam3_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_3_H.in_use_H         <= inRam3_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_4_H.input_mode_H     <= inRam4_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_4_H.output_channel_H <= inRam4_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_4_H.rc_H             <= inRam4_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_4_H.output_routing_H <= inRam4_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_4_H.input_routing_H  <= inRam4_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_4_H.in_use_H         <= inRam4_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_5_H.input_mode_H     <= inRam5_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_5_H.output_channel_H <= inRam5_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_5_H.rc_H             <= inRam5_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_5_H.output_routing_H <= inRam5_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_5_H.input_routing_H  <= inRam5_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_5_H.in_use_H         <= inRam5_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_6_H.input_mode_H     <= inRam6_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_6_H.output_channel_H <= inRam6_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_6_H.rc_H             <= inRam6_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_6_H.output_routing_H <= inRam6_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_6_H.input_routing_H  <= inRam6_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_6_H.in_use_H         <= inRam6_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_7_H.input_mode_H     <= inRam7_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_7_H.output_channel_H <= inRam7_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_7_H.rc_H             <= inRam7_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_7_H.output_routing_H <= inRam7_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_7_H.input_routing_H  <= inRam7_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_7_H.in_use_H         <= inRam7_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_8_H.input_mode_H     <= inRam8_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_8_H.output_channel_H <= inRam8_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_8_H.rc_H             <= inRam8_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_8_H.output_routing_H <= inRam8_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_8_H.input_routing_H  <= inRam8_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_8_H.in_use_H         <= inRam8_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_9_H.input_mode_H     <= inRam9_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_9_H.output_channel_H <= inRam9_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_9_H.rc_H             <= inRam9_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_9_H.output_routing_H <= inRam9_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_9_H.input_routing_H  <= inRam9_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_9_H.in_use_H         <= inRam9_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_10_H.input_mode_H     <= inRam10_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_10_H.output_channel_H <= inRam10_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_10_H.rc_H             <= inRam10_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_10_H.output_routing_H <= inRam10_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_10_H.input_routing_H  <= inRam10_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_10_H.in_use_H         <= inRam10_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_11_H.input_mode_H     <= inRam11_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_11_H.output_channel_H <= inRam11_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_11_H.rc_H             <= inRam11_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_11_H.output_routing_H <= inRam11_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_11_H.input_routing_H  <= inRam11_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_11_H.in_use_H         <= inRam11_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_12_H.input_mode_H     <= inRam12_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_12_H.output_channel_H <= inRam12_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_12_H.rc_H             <= inRam12_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_12_H.output_routing_H <= inRam12_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_12_H.input_routing_H  <= inRam12_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_12_H.in_use_H         <= inRam12_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_13_H.input_mode_H     <= inRam13_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_13_H.output_channel_H <= inRam13_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_13_H.rc_H             <= inRam13_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_13_H.output_routing_H <= inRam13_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_13_H.input_routing_H  <= inRam13_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_13_H.in_use_H         <= inRam13_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_14_H.input_mode_H     <= inRam14_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_14_H.output_channel_H <= inRam14_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_14_H.rc_H             <= inRam14_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_14_H.output_routing_H <= inRam14_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_14_H.input_routing_H  <= inRam14_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_14_H.in_use_H         <= inRam14_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_15_H.input_mode_H     <= inRam15_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_15_H.output_channel_H <= inRam15_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_15_H.rc_H             <= inRam15_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_15_H.output_routing_H <= inRam15_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_15_H.input_routing_H  <= inRam15_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_15_H.in_use_H         <= inRam15_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_16_H.input_mode_H     <= inRam16_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_16_H.output_channel_H <= inRam16_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_16_H.rc_H             <= inRam16_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_16_H.output_routing_H <= inRam16_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_16_H.input_routing_H  <= inRam16_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_16_H.in_use_H         <= inRam16_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_17_H.input_mode_H     <= inRam17_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_17_H.output_channel_H <= inRam17_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_17_H.rc_H             <= inRam17_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_17_H.output_routing_H <= inRam17_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_17_H.input_routing_H  <= inRam17_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_17_H.in_use_H         <= inRam17_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_18_H.input_mode_H     <= inRam18_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_18_H.output_channel_H <= inRam18_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_18_H.rc_H             <= inRam18_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_18_H.output_routing_H <= inRam18_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_18_H.input_routing_H  <= inRam18_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_18_H.in_use_H         <= inRam18_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_19_H.input_mode_H     <= inRam19_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_19_H.output_channel_H <= inRam19_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_19_H.rc_H             <= inRam19_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_19_H.output_routing_H <= inRam19_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_19_H.input_routing_H  <= inRam19_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_19_H.in_use_H         <= inRam19_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_20_H.input_mode_H     <= inRam20_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_20_H.output_channel_H <= inRam20_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_20_H.rc_H             <= inRam20_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_20_H.output_routing_H <= inRam20_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_20_H.input_routing_H  <= inRam20_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_20_H.in_use_H         <= inRam20_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_21_H.input_mode_H     <= inRam21_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_21_H.output_channel_H <= inRam21_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_21_H.rc_H             <= inRam21_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_21_H.output_routing_H <= inRam21_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_21_H.input_routing_H  <= inRam21_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_21_H.in_use_H         <= inRam21_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_22_H.input_mode_H     <= inRam22_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_22_H.output_channel_H <= inRam22_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_22_H.rc_H             <= inRam22_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_22_H.output_routing_H <= inRam22_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_22_H.input_routing_H  <= inRam22_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_22_H.in_use_H         <= inRam22_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_23_H.input_mode_H     <= inRam23_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_23_H.output_channel_H <= inRam23_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_23_H.rc_H             <= inRam23_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_23_H.output_routing_H <= inRam23_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_23_H.input_routing_H  <= inRam23_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_23_H.in_use_H         <= inRam23_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_24_H.input_mode_H     <= inRam24_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_24_H.output_channel_H <= inRam24_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_24_H.rc_H             <= inRam24_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_24_H.output_routing_H <= inRam24_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_24_H.input_routing_H  <= inRam24_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_24_H.in_use_H         <= inRam24_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_25_H.input_mode_H     <= inRam25_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_25_H.output_channel_H <= inRam25_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_25_H.rc_H             <= inRam25_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_25_H.output_routing_H <= inRam25_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_25_H.input_routing_H  <= inRam25_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_25_H.in_use_H         <= inRam25_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_26_H.input_mode_H     <= inRam26_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_26_H.output_channel_H <= inRam26_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_26_H.rc_H             <= inRam26_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_26_H.output_routing_H <= inRam26_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_26_H.input_routing_H  <= inRam26_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_26_H.in_use_H         <= inRam26_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_27_H.input_mode_H     <= inRam27_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_27_H.output_channel_H <= inRam27_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_27_H.rc_H             <= inRam27_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_27_H.output_routing_H <= inRam27_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_27_H.input_routing_H  <= inRam27_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_27_H.in_use_H         <= inRam27_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_28_H.input_mode_H     <= inRam28_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_28_H.output_channel_H <= inRam28_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_28_H.rc_H             <= inRam28_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_28_H.output_routing_H <= inRam28_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_28_H.input_routing_H  <= inRam28_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_28_H.in_use_H         <= inRam28_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_29_H.input_mode_H     <= inRam29_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_29_H.output_channel_H <= inRam29_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_29_H.rc_H             <= inRam29_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_29_H.output_routing_H <= inRam29_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_29_H.input_routing_H  <= inRam29_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_29_H.in_use_H         <= inRam29_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_30_H.input_mode_H     <= inRam30_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_30_H.output_channel_H <= inRam30_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_30_H.rc_H             <= inRam30_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_30_H.output_routing_H <= inRam30_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_30_H.input_routing_H  <= inRam30_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_30_H.in_use_H         <= inRam30_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_31_H.input_mode_H     <= inRam31_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_31_H.output_channel_H <= inRam31_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_31_H.rc_H             <= inRam31_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_31_H.output_routing_H <= inRam31_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_31_H.input_routing_H  <= inRam31_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_31_H.in_use_H         <= inRam31_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_32_H.input_mode_H     <= inRam32_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_32_H.output_channel_H <= inRam32_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_32_H.rc_H             <= inRam32_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_32_H.output_routing_H <= inRam32_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_32_H.input_routing_H  <= inRam32_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_32_H.in_use_H         <= inRam32_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_33_H.input_mode_H     <= inRam33_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_33_H.output_channel_H <= inRam33_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_33_H.rc_H             <= inRam33_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_33_H.output_routing_H <= inRam33_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_33_H.input_routing_H  <= inRam33_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_33_H.in_use_H         <= inRam33_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_34_H.input_mode_H     <= inRam34_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_34_H.output_channel_H <= inRam34_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_34_H.rc_H             <= inRam34_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_34_H.output_routing_H <= inRam34_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_34_H.input_routing_H  <= inRam34_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_34_H.in_use_H         <= inRam34_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_35_H.input_mode_H     <= inRam35_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_35_H.output_channel_H <= inRam35_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_35_H.rc_H             <= inRam35_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_35_H.output_routing_H <= inRam35_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_35_H.input_routing_H  <= inRam35_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_35_H.in_use_H         <= inRam35_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_36_H.input_mode_H     <= inRam36_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_36_H.output_channel_H <= inRam36_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_36_H.rc_H             <= inRam36_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_36_H.output_routing_H <= inRam36_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_36_H.input_routing_H  <= inRam36_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_36_H.in_use_H         <= inRam36_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_37_H.input_mode_H     <= inRam37_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_37_H.output_channel_H <= inRam37_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_37_H.rc_H             <= inRam37_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_37_H.output_routing_H <= inRam37_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_37_H.input_routing_H  <= inRam37_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_37_H.in_use_H         <= inRam37_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_38_H.input_mode_H     <= inRam38_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_38_H.output_channel_H <= inRam38_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_38_H.rc_H             <= inRam38_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_38_H.output_routing_H <= inRam38_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_38_H.input_routing_H  <= inRam38_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_38_H.in_use_H         <= inRam38_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_39_H.input_mode_H     <= inRam39_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_39_H.output_channel_H <= inRam39_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_39_H.rc_H             <= inRam39_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_39_H.output_routing_H <= inRam39_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_39_H.input_routing_H  <= inRam39_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_39_H.in_use_H         <= inRam39_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_40_H.input_mode_H     <= inRam40_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_40_H.output_channel_H <= inRam40_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_40_H.rc_H             <= inRam40_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_40_H.output_routing_H <= inRam40_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_40_H.input_routing_H  <= inRam40_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_40_H.in_use_H         <= inRam40_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_41_H.input_mode_H     <= inRam41_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_41_H.output_channel_H <= inRam41_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_41_H.rc_H             <= inRam41_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_41_H.output_routing_H <= inRam41_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_41_H.input_routing_H  <= inRam41_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_41_H.in_use_H         <= inRam41_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_42_H.input_mode_H     <= inRam42_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_42_H.output_channel_H <= inRam42_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_42_H.rc_H             <= inRam42_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_42_H.output_routing_H <= inRam42_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_42_H.input_routing_H  <= inRam42_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_42_H.in_use_H         <= inRam42_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_43_H.input_mode_H     <= inRam43_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_43_H.output_channel_H <= inRam43_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_43_H.rc_H             <= inRam43_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_43_H.output_routing_H <= inRam43_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_43_H.input_routing_H  <= inRam43_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_43_H.in_use_H         <= inRam43_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_44_H.input_mode_H     <= inRam44_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_44_H.output_channel_H <= inRam44_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_44_H.rc_H             <= inRam44_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_44_H.output_routing_H <= inRam44_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_44_H.input_routing_H  <= inRam44_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_44_H.in_use_H         <= inRam44_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_45_H.input_mode_H     <= inRam45_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_45_H.output_channel_H <= inRam45_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_45_H.rc_H             <= inRam45_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_45_H.output_routing_H <= inRam45_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_45_H.input_routing_H  <= inRam45_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_45_H.in_use_H         <= inRam45_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_46_H.input_mode_H     <= inRam46_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_46_H.output_channel_H <= inRam46_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_46_H.rc_H             <= inRam46_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_46_H.output_routing_H <= inRam46_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_46_H.input_routing_H  <= inRam46_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_46_H.in_use_H         <= inRam46_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_47_H.input_mode_H     <= inRam47_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_47_H.output_channel_H <= inRam47_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_47_H.rc_H             <= inRam47_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_47_H.output_routing_H <= inRam47_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_47_H.input_routing_H  <= inRam47_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_47_H.in_use_H         <= inRam47_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_48_H.input_mode_H     <= inRam48_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_48_H.output_channel_H <= inRam48_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_48_H.rc_H             <= inRam48_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_48_H.output_routing_H <= inRam48_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_48_H.input_routing_H  <= inRam48_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_48_H.in_use_H         <= inRam48_rdData_H(16); -- request dependent ram output in record
  inRamRd_H.out_49_H.input_mode_H     <= inRam49_rdData_H(15 downto 12); -- request dependent ram output in record
  inRamRd_H.out_49_H.output_channel_H <= inRam49_rdData_H(11 downto  6); -- request dependent ram output in record
  inRamRd_H.out_49_H.rc_H             <= inRam49_rdData_H(5); -- request dependent ram output in record
  inRamRd_H.out_49_H.output_routing_H <= inRam49_rdData_H(2); -- request dependent ram output in record
  inRamRd_H.out_49_H.input_routing_H  <= inRam49_rdData_H(17); -- request dependent ram output in record
  inRamRd_H.out_49_H.in_use_H         <= inRam49_rdData_H(16); -- request dependent ram output in record

  outRamRd_H.out_0_H.input_mode_H    <= outRam0_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_0_H.input_channel_H <= outRam0_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_0_H.input_routing_H <= outRam0_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_0_H.rc_H            <= outRam0_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_1_H.input_mode_H    <= outRam1_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_1_H.input_channel_H <= outRam1_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_1_H.input_routing_H <= outRam1_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_1_H.rc_H            <= outRam1_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_2_H.input_mode_H    <= outRam2_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_2_H.input_channel_H <= outRam2_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_2_H.input_routing_H <= outRam2_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_2_H.rc_H            <= outRam2_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_3_H.input_mode_H    <= outRam3_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_3_H.input_channel_H <= outRam3_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_3_H.input_routing_H <= outRam3_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_3_H.rc_H            <= outRam3_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_4_H.input_mode_H    <= outRam4_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_4_H.input_channel_H <= outRam4_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_4_H.input_routing_H <= outRam4_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_4_H.rc_H            <= outRam4_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_5_H.input_mode_H    <= outRam5_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_5_H.input_channel_H <= outRam5_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_5_H.input_routing_H <= outRam5_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_5_H.rc_H            <= outRam5_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_6_H.input_mode_H    <= outRam6_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_6_H.input_channel_H <= outRam6_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_6_H.input_routing_H <= outRam6_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_6_H.rc_H            <= outRam6_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_7_H.input_mode_H    <= outRam7_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_7_H.input_channel_H <= outRam7_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_7_H.input_routing_H <= outRam7_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_7_H.rc_H            <= outRam7_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_8_H.input_mode_H    <= outRam8_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_8_H.input_channel_H <= outRam8_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_8_H.input_routing_H <= outRam8_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_8_H.rc_H            <= outRam8_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_9_H.input_mode_H    <= outRam9_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_9_H.input_channel_H <= outRam9_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_9_H.input_routing_H <= outRam9_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_9_H.rc_H            <= outRam9_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_10_H.input_mode_H    <= outRam10_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_10_H.input_channel_H <= outRam10_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_10_H.input_routing_H <= outRam10_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_10_H.rc_H            <= outRam10_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_11_H.input_mode_H    <= outRam11_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_11_H.input_channel_H <= outRam11_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_11_H.input_routing_H <= outRam11_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_11_H.rc_H            <= outRam11_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_12_H.input_mode_H    <= outRam12_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_12_H.input_channel_H <= outRam12_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_12_H.input_routing_H <= outRam12_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_12_H.rc_H            <= outRam12_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_13_H.input_mode_H    <= outRam13_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_13_H.input_channel_H <= outRam13_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_13_H.input_routing_H <= outRam13_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_13_H.rc_H            <= outRam13_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_14_H.input_mode_H    <= outRam14_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_14_H.input_channel_H <= outRam14_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_14_H.input_routing_H <= outRam14_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_14_H.rc_H            <= outRam14_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_15_H.input_mode_H    <= outRam15_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_15_H.input_channel_H <= outRam15_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_15_H.input_routing_H <= outRam15_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_15_H.rc_H            <= outRam15_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_16_H.input_mode_H    <= outRam16_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_16_H.input_channel_H <= outRam16_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_16_H.input_routing_H <= outRam16_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_16_H.rc_H            <= outRam16_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_17_H.input_mode_H    <= outRam17_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_17_H.input_channel_H <= outRam17_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_17_H.input_routing_H <= outRam17_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_17_H.rc_H            <= outRam17_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_18_H.input_mode_H    <= outRam18_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_18_H.input_channel_H <= outRam18_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_18_H.input_routing_H <= outRam18_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_18_H.rc_H            <= outRam18_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_19_H.input_mode_H    <= outRam19_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_19_H.input_channel_H <= outRam19_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_19_H.input_routing_H <= outRam19_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_19_H.rc_H            <= outRam19_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_20_H.input_mode_H    <= outRam20_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_20_H.input_channel_H <= outRam20_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_20_H.input_routing_H <= outRam20_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_20_H.rc_H            <= outRam20_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_21_H.input_mode_H    <= outRam21_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_21_H.input_channel_H <= outRam21_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_21_H.input_routing_H <= outRam21_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_21_H.rc_H            <= outRam21_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_22_H.input_mode_H    <= outRam22_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_22_H.input_channel_H <= outRam22_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_22_H.input_routing_H <= outRam22_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_22_H.rc_H            <= outRam22_rdData_H( 8); -- request dependent ram output in record
  outRamRd_H.out_23_H.input_mode_H    <= outRam23_rdData_H(15 downto 12); -- request dependent ram output in record
  outRamRd_H.out_23_H.input_channel_H <= outRam23_rdData_H( 6 downto  0); -- request dependent ram output in record
  outRamRd_H.out_23_H.input_routing_H <= outRam23_rdData_H( 7); -- request dependent ram output in record
  outRamRd_H.out_23_H.rc_H            <= outRam23_rdData_H( 8); -- request dependent ram output in record

        ---

END tcl2vhd;

