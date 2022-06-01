

library IEEE;
use IEEE.std_logic_1164.all;

package special_records_pkg is

type special_inRam_data_record is record
  input_mode_H     : std_logic_vector(3 downto 0);
  output_channel_H : std_logic_vector(5 downto 0);
  rc_H             : std_logic;
  output_routing_H : std_logic;
  input_routing_H  : std_logic;
  in_use_H         : std_logic;
end record;

type special_outRam_data_record is record
  input_mode_H  : std_logic_vector(3 downto 0);
  input_channel_H  : std_logic_vector(6 downto 0);
  input_routing_H  : std_logic;
  rc_H : std_logic;
end record;


  type inRam_Out_record is record
    out_0_H  : special_inRam_data_record;
    out_1_H  : special_inRam_data_record;
    out_2_H  : special_inRam_data_record;
    out_3_H  : special_inRam_data_record;
    out_4_H  : special_inRam_data_record;
    out_5_H  : special_inRam_data_record;
    out_6_H  : special_inRam_data_record;
    out_7_H  : special_inRam_data_record;
    out_8_H  : special_inRam_data_record;
    out_9_H  : special_inRam_data_record;
    out_10_H : special_inRam_data_record;
    out_11_H : special_inRam_data_record;
    out_12_H : special_inRam_data_record;
    out_13_H : special_inRam_data_record;
    out_14_H : special_inRam_data_record;
    out_15_H : special_inRam_data_record;
    out_16_H : special_inRam_data_record;
    out_17_H : special_inRam_data_record;
    out_18_H : special_inRam_data_record;
    out_19_H : special_inRam_data_record;
    out_20_H : special_inRam_data_record;
    out_21_H : special_inRam_data_record;
    out_22_H : special_inRam_data_record;
    out_23_H : special_inRam_data_record;
    out_24_H : special_inRam_data_record;
    out_25_H : special_inRam_data_record;
    out_26_H : special_inRam_data_record;
    out_27_H : special_inRam_data_record;
    out_28_H : special_inRam_data_record;
    out_29_H : special_inRam_data_record;
    out_30_H : special_inRam_data_record;
    out_31_H : special_inRam_data_record;
    out_32_H : special_inRam_data_record;
    out_33_H : special_inRam_data_record;
    out_34_H : special_inRam_data_record;
    out_35_H : special_inRam_data_record;
    out_36_H : special_inRam_data_record;
    out_37_H : special_inRam_data_record;
    out_38_H : special_inRam_data_record;
    out_39_H : special_inRam_data_record;
    out_40_H : special_inRam_data_record;
    out_41_H : special_inRam_data_record;
    out_42_H : special_inRam_data_record;
    out_43_H : special_inRam_data_record;
    out_44_H : special_inRam_data_record;
    out_45_H : special_inRam_data_record;
    out_46_H : special_inRam_data_record;
    out_47_H : special_inRam_data_record;
    out_48_H : special_inRam_data_record;  -- BC
    out_49_H : special_inRam_data_record;  -- AUX
  end record;

  type outRam_Out_record is record
    out_0_H  : special_outRam_data_record;
    out_1_H  : special_outRam_data_record;
    out_2_H  : special_outRam_data_record;
    out_3_H  : special_outRam_data_record;
    out_4_H  : special_outRam_data_record;
    out_5_H  : special_outRam_data_record;
    out_6_H  : special_outRam_data_record;
    out_7_H  : special_outRam_data_record;
    out_8_H  : special_outRam_data_record;
    out_9_H  : special_outRam_data_record;
    out_10_H : special_outRam_data_record;
    out_11_H : special_outRam_data_record;
    out_12_H : special_outRam_data_record;
    out_13_H : special_outRam_data_record;
    out_14_H : special_outRam_data_record;
    out_15_H : special_outRam_data_record;
    out_16_H : special_outRam_data_record;
    out_17_H : special_outRam_data_record;
    out_18_H : special_outRam_data_record;
    out_19_H : special_outRam_data_record;
    out_20_H : special_outRam_data_record;
    out_21_H : special_outRam_data_record;
    out_22_H : special_outRam_data_record;
    out_23_H : special_outRam_data_record;
  end record;

  type imx_record is record
    IMX0_index_H  : std_logic_vector(1 downto 0);
    enIMX0_H      : std_logic;
    IMX1_index_H  : std_logic_vector(1 downto 0);
    enIMX1_H      : std_logic;
    IMX2_index_H  : std_logic_vector(1 downto 0);
    enIMX2_H      : std_logic;
    IMX3_index_H  : std_logic_vector(1 downto 0);
    enIMX3_H      : std_logic;
    IMX4_index_H  : std_logic_vector(1 downto 0);
    enIMX4_H      : std_logic;
    IMX5_index_H  : std_logic_vector(1 downto 0);
    enIMX5_H      : std_logic;
    IMX6_index_H  : std_logic_vector(1 downto 0);
    enIMX6_H      : std_logic;
    IMX7_index_H  : std_logic_vector(1 downto 0);
    enIMX7_H      : std_logic;
    IMX8_index_H  : std_logic_vector(1 downto 0);
    enIMX8_H      : std_logic;
    IMX9_index_H  : std_logic_vector(1 downto 0);
    enIMX9_H      : std_logic;
    IMX10_index_H : std_logic_vector(1 downto 0);
    enIMX10_H     : std_logic;
    IMX11_index_H : std_logic_vector(1 downto 0);
    enIMX11_H     : std_logic;
    IMX12_index_H : std_logic_vector(1 downto 0);
    enIMX12_H     : std_logic;
    IMX13_index_H : std_logic_vector(1 downto 0);
    enIMX13_H     : std_logic;
    IMX14_index_H : std_logic_vector(1 downto 0);
    enIMX14_H     : std_logic;
    IMX15_index_H : std_logic_vector(1 downto 0);
    enIMX15_H     : std_logic;
    IMX16_index_H : std_logic_vector(1 downto 0);
    enIMX16_H     : std_logic;
    IMX17_index_H : std_logic_vector(1 downto 0);
    enIMX17_H     : std_logic;
    IMX18_index_H : std_logic_vector(1 downto 0);
    enIMX18_H     : std_logic;
    IMX19_index_H : std_logic_vector(1 downto 0);
    enIMX19_H     : std_logic;
    IMX20_index_H : std_logic_vector(1 downto 0);
    enIMX20_H     : std_logic;
    IMX21_index_H : std_logic_vector(1 downto 0);
    enIMX21_H     : std_logic;
    IMX22_index_H : std_logic_vector(1 downto 0);
    enIMX22_H     : std_logic;
    IMX23_index_H : std_logic_vector(1 downto 0);
    enIMX23_H     : std_logic;
    IMX24_index_H : std_logic_vector(1 downto 0);
    enIMX24_H     : std_logic;
    IMX25_index_H : std_logic_vector(1 downto 0);
    enIMX25_H     : std_logic;
    IMX26_index_H : std_logic_vector(1 downto 0);
    enIMX26_H     : std_logic;
    IMX27_index_H : std_logic_vector(1 downto 0);
    enIMX27_H     : std_logic;
    IMX28_index_H : std_logic_vector(1 downto 0);
    enIMX28_H     : std_logic;
    IMX29_index_H : std_logic_vector(1 downto 0);
    enIMX29_H     : std_logic;
    IMX30_index_H : std_logic_vector(1 downto 0);
    enIMX30_H     : std_logic;
    IMX31_index_H : std_logic_vector(1 downto 0);
    enIMX31_H     : std_logic;
    IMX32_index_H : std_logic_vector(1 downto 0);
    enIMX32_H     : std_logic;
    IMX33_index_H : std_logic_vector(1 downto 0);
    enIMX33_H     : std_logic;
    IMX34_index_H : std_logic_vector(1 downto 0);
    enIMX34_H     : std_logic;
    IMX35_index_H : std_logic_vector(1 downto 0);
    enIMX35_H     : std_logic;
    IMX36_index_H : std_logic_vector(1 downto 0);
    enIMX36_H     : std_logic;
    IMX37_index_H : std_logic_vector(1 downto 0);
    enIMX37_H     : std_logic;
    IMX38_index_H : std_logic_vector(1 downto 0);
    enIMX38_H     : std_logic;
    IMX39_index_H : std_logic_vector(1 downto 0);
    enIMX39_H     : std_logic;
    IMX40_index_H : std_logic_vector(1 downto 0);
    enIMX40_H     : std_logic;
    IMX41_index_H : std_logic_vector(1 downto 0);
    enIMX41_H     : std_logic;
    IMX42_index_H : std_logic_vector(1 downto 0);
    enIMX42_H     : std_logic;
    IMX43_index_H : std_logic_vector(1 downto 0);
    enIMX43_H     : std_logic;
    IMX44_index_H : std_logic_vector(1 downto 0);
    enIMX44_H     : std_logic;
    IMX45_index_H : std_logic_vector(1 downto 0);
    enIMX45_H     : std_logic;
    IMX46_index_H : std_logic_vector(1 downto 0);
    enIMX46_H     : std_logic;
    IMX47_index_H : std_logic_vector(1 downto 0);
    enIMX47_H     : std_logic;
    IMX48_index_H : std_logic_vector(1 downto 0);  -- BC
    enIMX48_H     : std_logic;
    IMX49_index_H : std_logic_vector(1 downto 0);  -- AUX
    enIMX49_H     : std_logic;
  end record;

  type omx_record is record
    OMX0_index_H : std_logic_vector(2 downto 0);
    enOMX0_L     : std_logic;
    OMX1_index_H : std_logic_vector(2 downto 0);
    enOMX1_L     : std_logic;
    OMX2_index_H : std_logic_vector(2 downto 0);
    enOMX2_L     : std_logic;
    OMX3_index_H : std_logic_vector(2 downto 0);
    enOMX3_L     : std_logic;
    OMX4_index_H : std_logic_vector(2 downto 0);
    enOMX4_L     : std_logic;
    OMX5_index_H : std_logic_vector(2 downto 0);
    enOMX5_L     : std_logic;
    OMX6_index_H : std_logic_vector(2 downto 0);
    enOMX6_L     : std_logic;
    OMX7_index_H : std_logic_vector(2 downto 0);
    enOMX7_L     : std_logic;
    OMX8_index_H : std_logic_vector(2 downto 0);
    enOMX8_L     : std_logic;
    OMX9_index_H : std_logic_vector(2 downto 0);
    enOMX9_L     : std_logic;
    OMX10_index_H : std_logic_vector(2 downto 0);
    enOMX10_L     : std_logic;
    OMX11_index_H : std_logic_vector(2 downto 0);
    enOMX11_L     : std_logic;
    OMX12_index_H : std_logic_vector(2 downto 0);
    enOMX12_L     : std_logic;
    OMX13_index_H : std_logic_vector(2 downto 0);
    enOMX13_L     : std_logic;
    OMX14_index_H : std_logic_vector(2 downto 0);
    enOMX14_L     : std_logic;
    OMX15_index_H : std_logic_vector(2 downto 0);
    enOMX15_L     : std_logic;
    OMX16_index_H : std_logic_vector(2 downto 0);
    enOMX16_L     : std_logic;
    OMX17_index_H : std_logic_vector(2 downto 0);
    enOMX17_L     : std_logic;
    OMX18_index_H : std_logic_vector(2 downto 0);
    enOMX18_L     : std_logic;
    OMX19_index_H : std_logic_vector(2 downto 0);
    enOMX19_L     : std_logic;
    OMX20_index_H : std_logic_vector(2 downto 0);
    enOMX20_L     : std_logic;
    OMX21_index_H : std_logic_vector(2 downto 0);
    enOMX21_L     : std_logic;
    OMX22_index_H : std_logic_vector(2 downto 0);
    enOMX22_L     : std_logic;
    OMX23_index_H : std_logic_vector(2 downto 0);
    enOMX23_L     : std_logic;
    OMX24_index_H : std_logic_vector(2 downto 0);
    enOMX24_L     : std_logic;
    OMX25_index_H : std_logic_vector(2 downto 0);
    enOMX25_L     : std_logic;
    OMX26_index_H : std_logic_vector(2 downto 0);
    enOMX26_L     : std_logic;
    OMX27_index_H : std_logic_vector(2 downto 0);
    enOMX27_L     : std_logic;
    OMX28_index_H : std_logic_vector(2 downto 0);
    enOMX28_L     : std_logic;
    OMX29_index_H : std_logic_vector(2 downto 0);
    enOMX29_L     : std_logic;
    OMX30_index_H : std_logic_vector(2 downto 0);
    enOMX30_L     : std_logic;
    OMX31_index_H : std_logic_vector(2 downto 0);
    enOMX31_L     : std_logic;
    OMX32_index_H : std_logic_vector(2 downto 0);
    enOMX32_L     : std_logic;
    OMX33_index_H : std_logic_vector(2 downto 0);
    enOMX33_L     : std_logic;
    OMX34_index_H : std_logic_vector(2 downto 0);
    enOMX34_L     : std_logic;
    OMX35_index_H : std_logic_vector(2 downto 0);
    enOMX35_L     : std_logic;
    OMX36_index_H : std_logic_vector(2 downto 0);
    enOMX36_L     : std_logic;
    OMX37_index_H : std_logic_vector(2 downto 0);
    enOMX37_L     : std_logic;
    OMX38_index_H : std_logic_vector(2 downto 0);
    enOMX38_L     : std_logic;
    OMX39_index_H : std_logic_vector(2 downto 0);
    enOMX39_L     : std_logic;
    OMX40_index_H : std_logic_vector(2 downto 0);
    enOMX40_L     : std_logic;
    OMX41_index_H : std_logic_vector(2 downto 0);
    enOMX41_L     : std_logic;
    OMX42_index_H : std_logic_vector(2 downto 0);
    enOMX42_L     : std_logic;
    OMX43_index_H : std_logic_vector(2 downto 0);
    enOMX43_L     : std_logic;
    OMX44_index_H : std_logic_vector(2 downto 0);
    enOMX44_L     : std_logic;
    OMX45_index_H : std_logic_vector(2 downto 0);
    enOMX45_L     : std_logic;
    OMX46_index_H : std_logic_vector(2 downto 0);
    enOMX46_L     : std_logic;
    OMX47_index_H : std_logic_vector(2 downto 0);
    enOMX47_L     : std_logic;
  end record;


  type matrix_input_record is record
       ch0 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch1 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch2 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch3 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch4 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch5 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch6 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch7 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch8 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch9 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch10 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch11 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch12 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch13 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch14 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch15 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch16 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch17 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch18 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch19 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch20 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch21 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch22 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch23 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch24 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch25 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch26 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch27 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch28 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch29 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch30 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch31 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch32 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch33 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch34 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch35 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch36 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch37 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch38 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch39 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch40 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch41 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch42 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch43 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch44 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch45 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch46 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch47 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch48 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
       ch49 : integer; -- Eingangssignal in die Schaltmatrix und Extensions
  end record;
  type matrix_intermediate_record is record
       ch0 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch1 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch2 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch3 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch4 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch5 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch6 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch7 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch8 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch9 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch10 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch11 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch12 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch13 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch14 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch15 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch16 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch17 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch18 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch19 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch20 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch21 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch22 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch23 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch24 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch25 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch26 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch27 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch28 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch29 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch30 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch31 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch32 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch33 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch34 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch35 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch36 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch37 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch38 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch39 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch40 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch41 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch42 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch43 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch44 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch45 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch46 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch47 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch48 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
       ch49 : integer; -- Signal zwischen 16er Matrix und Ausgangsmatrix
  end record;
  type matrix_output_record is record
       ch0 : integer; -- Ausgangssignal
       ch1 : integer; -- Ausgangssignal
       ch2 : integer; -- Ausgangssignal
       ch3 : integer; -- Ausgangssignal
       ch4 : integer; -- Ausgangssignal
       ch5 : integer; -- Ausgangssignal
       ch6 : integer; -- Ausgangssignal
       ch7 : integer; -- Ausgangssignal
       ch8 : integer; -- Ausgangssignal
       ch9 : integer; -- Ausgangssignal
       ch10 : integer; -- Ausgangssignal
       ch11 : integer; -- Ausgangssignal
       ch12 : integer; -- Ausgangssignal
       ch13 : integer; -- Ausgangssignal
       ch14 : integer; -- Ausgangssignal
       ch15 : integer; -- Ausgangssignal
       ch16 : integer; -- Ausgangssignal
       ch17 : integer; -- Ausgangssignal
       ch18 : integer; -- Ausgangssignal
       ch19 : integer; -- Ausgangssignal
       ch20 : integer; -- Ausgangssignal
       ch21 : integer; -- Ausgangssignal
       ch22 : integer; -- Ausgangssignal
       ch23 : integer; -- Ausgangssignal
  end record;


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- the records below are used for testbench checker
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  
  type inRam_Test_array is array (0 to 49) of special_inRam_data_record;
  type outRam_Test_array is array (0 to 23) of special_outRam_data_record;

  type inRam_Test_record is record
    input_H : inRam_Test_array;
  end record;

  type outRam_Test_record is record
    output_H : outRam_Test_array;
  end record;


  type special_in_mem_type is array (0 to 63) of inRam_Test_record;    -- structure to store the special settings
  type special_out_mem_type is array (0 to 63) of outRam_Test_record;  -- structure to store the special settings


end special_records_pkg;
