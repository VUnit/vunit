-------------------------------------------------------------------------------
-- Title      : uni_records_pkg
-- Project    : eMeRge
-------------------------------------------------------------------------------
-- File       : uni_records_pkg.vhd
-- Author     : Nick Demharter
-- Company    : Siemens Healthcare GmbH, Erlangen, Germany
-- Department : HC DI MR R&D SFP CRX
-------------------------------------------------------------------------------
-- Description: basic config regs file
-------------------------------------------------------------------------------
-- Copyright (c) 2018 by Siemens Healthcare GmbH
-------------------------------------------------------------------------------
-- History  :
-- Date        Version  Author          Description
--             01       Nick Demharter  basic version
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

package uni_records_pkg is

  type uni_phy_interface_record is record  -- record definition 
    d_H : std_logic_vector(31 downto 0);   -- data
    k_H : std_logic_vector(3 downto 0);    -- char
    l_H : std_logic;                       -- byte lock
  end record;

  type avalon_response_record is record             -- record for avalon response
    readdata_H    : std_logic_vector(31 downto 0);  -- avalon readdata
    waitrequest_H : std_logic;                      -- avalon waitrequest
    response_H    : std_logic_vector(1 downto 0);   -- avalon response 
  end record;

  type avalon_request_record is record
    begintransfer_H : std_logic;                      -- avalon begintransfer
    address_H       : std_logic_vector(31 downto 0);  -- avalon byte address signal
    byte_enable_H   : std_logic_vector(3 downto 0);   -- avalon byte enable signal
    read_H          : std_logic;                      -- avalon read signal
    write_H         : std_logic;                      -- avalon write signal
    writedata_H     : std_logic_vector(31 downto 0);  -- avalon writedata signal 
  end record;

  type avalon_streaming_record is record
    d_H : std_logic_vector(63 downto 0);  -- avalon st data signal
    c_H : std_logic_vector(3 downto 0);   -- avalon st channelselect signal
    v_H : std_logic;                      -- avalon st valid signal
  end record;

end uni_records_pkg;
