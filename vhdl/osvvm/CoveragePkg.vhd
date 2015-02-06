--
--  File Name:         CoveragePkg.vhd
--  Design Unit Name:  CoveragePkg
--  Revision:          STANDARD VERSION,  revision 2015.01
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis          SynthWorks
--     Matthias Alles     Creonic.    Inspired GetMinBinVal, GetMinPoint, GetCov
--     Jerry Kaczynski    Aldec.      Inspired GetBin function
--
--
--  Package Defines
--      Functional coverage modeling utilities and data structure
--
--  Developed by/for:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        11898 SW 128th Ave.  Tigard, Or  97223
--        http://www.SynthWorks.com
--
--  Latest standard version available at:
--        http://www.SynthWorks.com/downloads
--
--  Revision History:      For more details, see CoveragePkg_release_notes.pdf
--    Date      Version    Description
--    06/2010:  0.1        Initial revision
--    09/2010              Release in SynthWorks' VHDL Testbenches and Verification classes
--    02/2011:  1.0        Changed CoverBinType to facilitage long term support of cross coverage
--    02/2011:  1.1        Added GetMinCov, GetMaxCov, CountCovHoles, GetCovHole
--    04/2011:  2.0        Added protected type based data structure:  CovPType
--    06/2011:  2.1        Removed signal based coverage modeling
--    07/2011:  2.2        Added randomization with coverage goals (AtLeast), weight, and percentage thresholds
--    11/2011:  2.2a       Changed constants ALL_RANGE, ZERO_BIN, and ONE_BIN to have a 1 index
--    12/2011:  2.2b       Fixed minor inconsistencies on interface declarations.
--    01/2012:  2.3        Added Function GetBin from Jerry K.  Made write for RangeArrayType visible
--    01/2012:  2.4        Added Merging of bins
--    04/2013:  2013.04    Thresholding, CovTarget, Merging off by default,
--    5/2013    2013.05    Release with updated RandomPkg.  Minimal changes.
--    1/2014    2014.01    Merging of Cov Models, LastIndex
--    7/2014    2014.07    Bin Naming (for requirements tracking), WriteBin with Pass/Fail, GenBin[integer_vector]
--    12/2014   2014.07a   Fix memory leak in deallocate. Removed initialied pointers which can lead to leaks.
--    01/2015   2015.01    Use AlertLogPkg to count assertions and filter log messages
--
--  Development Notes:
--      The coverage procedures are named ICover to avoid conflicts with
--      future language changes which may add cover as a keyword
--      Procedure WriteBin writes each CovBin on a separate line, as such
--      it was inappropriate to overload either textio write or to_string
--      In the notes VHDL-2008 notes refers to
--      composites with unconstrained elements
--
--
--  Copyright (c) 2010 - 2015 by SynthWorks Design Inc.  All rights reserved.
--
--  Verbatim copies of this source file may be used and
--  distributed without restriction.
--
--  This source file is free software; you can redistribute it
--  and/or modify it under the terms of the ARTISTIC License
--  as published by The Perl Foundation; either version 2.0 of
--  the License, or (at your option) any later version.
--
--  This source is distributed in the hope that it will be
--  useful, but WITHOUT ANY WARRANTY; without even the implied
--  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
--  PURPOSE. See the Artistic License for details.
--
--  You should have received a copy of the license with this source.
--  If not download it from,
--     http://www.perlfoundation.org/artistic_license_2_0
--
--  Credits:
--    CovBinBaseType is inspired by a structure proposed in the
--    paper "Functional Coverage - without SystemVerilog!"
--    by Alan Fitch and Doug Smith.  Presented at DVCon 2010
--    However the approach in their paper uses entities and
--    architectures where this approach relies on functions
--    and procedures, so the usage models differ greatly however.
--

library ieee ;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;
use ieee.math_real.all ;
use std.textio.all ;

-- comment out following 2 lines with VHDL-2008.  Leave in for VHDL-2002
-- library ieee_proposed ;						          -- remove with VHDL-2008
-- use ieee_proposed.standard_additions.all ;   -- remove with VHDL-2008

use work.TranscriptPkg.all ;
use work.AlertLogPkg.all ; 
use work.RandomBasePkg.all ;
use work.RandomPkg.all ;
use work.NamePkg.all ;
use work.MessagePkg.all ;
use work.OsvvmGlobalPkg.all ;

package CoveragePkg is

  -- CovPType allocates bins that are multiples of MIN_NUM_BINS
  constant MIN_NUM_BINS : integer := 2**7 ;  -- power of 2

  type RangeType is record
    min : integer ;
    max : integer ;
  end record ;
  type RangeArrayType is array (integer range <>) of RangeType ;
  constant ALL_RANGE : RangeArrayType := (1=>(Integer'left, Integer'right)) ;

  procedure write ( file f :  text ;  BinVal : RangeArrayType ) ;
  procedure write ( variable buf : inout line ; constant BinVal : in RangeArrayType) ;

  -- CovBinBaseType.action values.
  -- Note that coverage counting depends on these values
  constant COV_COUNT   : integer := 1 ;
  constant COV_IGNORE  : integer := 0 ;
  constant COV_ILLEGAL : integer := -1 ;

  -- type OsvvmOptionsType is (OPT_DEFAULT, FALSE, TRUE) ;
  alias CovOptionsType is work.OsvvmGlobalPkg.OsvvmOptionsType ; 
  constant COV_OPT_INIT_PARM_DETECT : CovOptionsType := work.OsvvmGlobalPkg.OPT_INIT_PARM_DETECT ;
  -- For backward compatibility.  Don't add to other packages.  
  alias DISABLED is work.OsvvmGlobalPkg.DISABLED [return work.OsvvmGlobalPkg.OsvvmOptionsType ];  
  alias ENABLED is work.OsvvmGlobalPkg.ENABLED [return work.OsvvmGlobalPkg.OsvvmOptionsType ];  

-- Deprecated
  -- Used for easy manual entry.  Order: min, max, action
  -- Intentionally did not use a record to allow other input
  -- formats in the future with VHDL-2008 unconstrained arrays
  -- of unconstrained elements
  --  type CovBinManualType is array (natural range <>) of integer_vector(0 to 2) ;

  type CovBinBaseType is record
    BinVal    : RangeArrayType(1 to 1) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovBinType is array (natural range <>) of CovBinBaseType ;

  constant ALL_BIN     : CovBinType := (0 => ( BinVal => ALL_RANGE,  Action => COV_COUNT,   Count => 0, AtLeast => 1, Weight => 1 )) ;
  constant ALL_COUNT   : CovBinType := (0 => ( BinVal => ALL_RANGE,  Action => COV_COUNT,   Count => 0, AtLeast => 1, Weight => 1 )) ;
  constant ALL_ILLEGAL : CovBinType := (0 => ( BinVal => ALL_RANGE,  Action => COV_ILLEGAL, Count => 0, AtLeast => 0, Weight => 0 )) ;
  constant ALL_IGNORE  : CovBinType := (0 => ( BinVal => ALL_RANGE,  Action => COV_IGNORE,  Count => 0, AtLeast => 0, Weight => 0 )) ;
  constant ZERO_BIN    : CovBinType := (0 => ( BinVal => (1=>(0,0)), Action => COV_COUNT,   Count => 0, AtLeast => 1, Weight => 1 )) ;
  constant ONE_BIN     : CovBinType := (0 => ( BinVal => (1=>(1,1)), Action => COV_COUNT,   Count => 0, AtLeast => 1, Weight => 1 )) ;
  constant NULL_BIN    : CovBinType(work.RandomPkg.NULL_RANGE_TYPE) := (others => ( BinVal => ALL_RANGE,  Action => integer'high, Count => 0, AtLeast => integer'high, Weight => integer'high )) ;

  type CountModeType   is (COUNT_FIRST, COUNT_ALL) ;
  type IllegalModeType is (ILLEGAL_ON, ILLEGAL_FAILURE, ILLEGAL_OFF) ;
  type WeightModeType  is (AT_LEAST, WEIGHT, REMAIN, REMAIN_EXP, REMAIN_SCALED, REMAIN_WEIGHT ) ;


  -- In VHDL-2008 CovMatrix?BaseType and CovMatrix?Type will be subsumed
  -- by CovBinBaseType and CovBinType with RangeArrayType as an unconstrained array.
  type CovMatrix2BaseType is record
    BinVal    : RangeArrayType(1 to 2) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovMatrix2Type is array (natural range <>) of CovMatrix2BaseType ;

  type CovMatrix3BaseType is record
    BinVal    : RangeArrayType(1 to 3) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovMatrix3Type is array (natural range <>) of CovMatrix3BaseType ;

  type CovMatrix4BaseType is record
    BinVal    : RangeArrayType(1 to 4) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovMatrix4Type is array (natural range <>) of CovMatrix4BaseType ;

  type CovMatrix5BaseType is record
    BinVal    : RangeArrayType(1 to 5) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovMatrix5Type is array (natural range <>) of CovMatrix5BaseType ;

  type CovMatrix6BaseType is record
    BinVal    : RangeArrayType(1 to 6) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovMatrix6Type is array (natural range <>) of CovMatrix6BaseType ;

  type CovMatrix7BaseType is record
    BinVal    : RangeArrayType(1 to 7) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovMatrix7Type is array (natural range <>) of CovMatrix7BaseType ;

  type CovMatrix8BaseType is record
    BinVal    : RangeArrayType(1 to 8) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovMatrix8Type is array (natural range <>) of CovMatrix8BaseType ;

  type CovMatrix9BaseType is record
    BinVal    : RangeArrayType(1 to 9) ;
    Action    : integer ;
    Count     : integer ;
    AtLeast   : integer ;
    Weight    : integer ;
  end record ;
  type CovMatrix9Type is array (natural range <>) of CovMatrix9BaseType ;

  ------------------------------------------------------------
  function ToMinPoint (A : RangeArrayType) return integer ;
  function ToMinPoint (A : RangeArrayType) return integer_vector ;
  -- BinVal to Minimum Point

  ------------------------------------------------------------
  procedure ToRandPoint(
  -- BinVal to Random Point
  -- better as a function, however, inout not supported on functions
  ------------------------------------------------------------
    variable RV       : inout RandomPType ;
    constant BinVal   : in    RangeArrayType ;
    variable result   : out   integer
  ) ;

  ------------------------------------------------------------
  procedure ToRandPoint(
  -- BinVal to Random Point
  ------------------------------------------------------------
    variable RV       : inout RandomPType ;
    constant BinVal   : in    RangeArrayType ;
    variable result   : out   integer_vector
  ) ;


  ------------------------------------------------------------------------------------------
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  ------------------------------------------------------------------------------------------
  type CovPType is protected
    procedure FileOpenWriteBin (FileName : string; OpenKind : File_Open_Kind ) ;
    procedure FileCloseWriteBin ;
    procedure SetAlertLogID (A : AlertLogIDType) ;
    impure function GetAlertLogID return AlertLogIDType ;

    -- procedure FileOpenWriteCovDb (FileName : string; OpenKind : File_Open_Kind ) ;
    -- procedure FileCloseWriteCovDb ;
    procedure SetIllegalMode (A : IllegalModeType) ;
    procedure SetWeightMode (A : WeightModeType;  Scale : real := 1.0) ;
    procedure SetName (Name : String) ;
    impure function SetName (Name : String) return string ;
    impure function GetName return String ;
    procedure SetMessage (Message : String) ;
    procedure DeallocateName ; -- clear name
    procedure DeallocateMessage ; -- clear message
    procedure SetThresholding(A : boolean := TRUE ) ; -- 2.5
    procedure SetCovThreshold (Percent : real) ;
    procedure SetCovTarget (Percent : real) ; -- 2.5
    impure function GetCovTarget return real ; -- 2.5
    procedure SetMerging(A : boolean := TRUE ) ; -- 2.5
    procedure SetCountMode (A : CountModeType) ;
    procedure InitSeed (S  : string ) ;
    impure function InitSeed (S : string ) return string ;
    procedure InitSeed (I  : integer ) ;
    procedure SetSeed (RandomSeedIn : RandomSeedType ) ;
    impure function GetSeed return RandomSeedType ;

    ------------------------------------------------------------
    procedure SetReportOptions (
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) ;

    procedure SetBinSize (NewNumBins : integer) ;

    ------------------------------------------------------------
    procedure AddBins (
    ------------------------------------------------------------
      Name    : String ;
      AtLeast : integer ;
      Weight  : integer ;
      CovBin  : CovBinType
    ) ;
    procedure AddBins ( Name : String ; AtLeast : integer ; CovBin : CovBinType ) ;
    procedure AddBins ( Name : String ;  CovBin : CovBinType) ;
    procedure AddBins ( AtLeast : integer ; Weight  : integer ; CovBin : CovBinType ) ;
    procedure AddBins ( AtLeast : integer ; CovBin : CovBinType ) ;
    procedure AddBins ( CovBin : CovBinType ) ;

    ------------------------------------------------------------
    procedure AddCross(
    ------------------------------------------------------------
      Name       : string ;
      AtLeast    : integer ;
      Weight     : integer ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) ;

    ------------------------------------------------------------
    procedure AddCross(
      Name       : string ;
      AtLeast    : integer ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) ;

    ------------------------------------------------------------
    procedure AddCross(
      Name       : string ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) ;

    ------------------------------------------------------------
    procedure AddCross(
      AtLeast    : integer ;
      Weight     : integer ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) ;

    ------------------------------------------------------------
    procedure AddCross(
      AtLeast    : integer ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) ;

    ------------------------------------------------------------
    procedure AddCross(
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) ;


    procedure Deallocate ;

    procedure ICoverLast ;
    procedure ICover( CovPoint : integer) ;
    procedure ICover( CovPoint : integer_vector) ;

    procedure SetCovZero ;

    impure function IsInitialized return boolean ;
    impure function GetNumBins return integer ;
    impure function GetMinIndex return integer ;
    impure function GetMinCov return real ;       -- PercentCov
    impure function GetMinCount return integer ;  -- Count
    impure function GetMaxIndex return integer ;
    impure function GetMaxCov return real ;       -- PercentCov
    impure function GetMaxCount return integer ;  -- Count
    impure function CountCovHoles ( PercentCov : real ) return integer ;
    impure function CountCovHoles return integer ;
    impure function IsCovered return boolean ;
    impure function IsCovered ( PercentCov : real ) return boolean ;
    impure function GetCov ( PercentCov : real ) return real ;
    impure function GetCov return real ; -- PercentCov of entire model/all bins
    impure function GetItemCount return integer ;
    impure function GetTotalCovGoal ( PercentCov : real ) return integer ;
    impure function GetTotalCovGoal return integer ;
    impure function GetLastIndex return integer ;

    -- Return BinVal
    impure function GetBinVal ( BinIndex : integer ) return RangeArrayType ;
    impure function GetLastBinVal return RangeArrayType ;
    impure function RandCovBinVal ( PercentCov : real ) return RangeArrayType ;
    impure function RandCovBinVal return RangeArrayType ;
    impure function GetMinBinVal  return RangeArrayType ;
    impure function GetMaxBinVal  return RangeArrayType ;
    impure function GetHoleBinVal ( ReqHoleNum : integer ; PercentCov : real  ) return RangeArrayType ;
    impure function GetHoleBinVal ( PercentCov : real ) return RangeArrayType ;
    impure function GetHoleBinVal ( ReqHoleNum : integer := 1 ) return RangeArrayType ;

    -- Return Points
    impure function RandCovPoint return integer ;
    impure function RandCovPoint ( PercentCov : real ) return integer ;
    impure function RandCovPoint return integer_vector ;
    impure function RandCovPoint ( PercentCov : real ) return integer_vector ;
    impure function GetPoint ( BinIndex : integer ) return integer ;
    impure function GetPoint ( BinIndex : integer ) return integer_vector ;
    impure function GetMinPoint return integer ;
    impure function GetMinPoint return integer_vector ;
    impure function GetMaxPoint return integer ;
    impure function GetMaxPoint return integer_vector ;

    -- GetBin returns an internal value of the coverage data structure
    -- The return value may change as the package evolves
    -- Use it only for debugging.
    -- GetBinInfo is a for development only.
    impure function GetBinInfo ( BinIndex : integer ) return CovBinBaseType ;
    impure function GetBinValLength return integer ;
    impure function GetBin ( BinIndex : integer ) return CovBinBaseType ;
    impure function GetBin ( BinIndex : integer ) return CovMatrix2BaseType  ;
    impure function GetBin ( BinIndex : integer ) return CovMatrix3BaseType ;
    impure function GetBin ( BinIndex : integer ) return CovMatrix4BaseType ;
    impure function GetBin ( BinIndex : integer ) return CovMatrix5BaseType ;
    impure function GetBin ( BinIndex : integer ) return CovMatrix6BaseType ;
    impure function GetBin ( BinIndex : integer ) return CovMatrix7BaseType ;
    impure function GetBin ( BinIndex : integer ) return CovMatrix8BaseType ;
    impure function GetBin ( BinIndex : integer ) return CovMatrix9BaseType ;

    ------------------------------------------------------------
    procedure WriteBin (
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) ;

    ------------------------------------------------------------
    procedure WriteBin (  -- With LogLevel
      LogLevel        : LogType ;
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) ;

    ------------------------------------------------------------
    procedure WriteBin (
      FileName        : string;
      OpenKind        : File_Open_Kind := APPEND_MODE ;
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) ;

    ------------------------------------------------------------
    procedure WriteBin (  -- With LogLevel
      LogLevel        : LogType ;
      FileName        : string;
      OpenKind        : File_Open_Kind := APPEND_MODE ;
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) ;
    
    procedure WriteCovHoles ( LogLevel : LogType := ALWAYS ) ;
    procedure WriteCovHoles ( PercentCov : real ) ;
    procedure WriteCovHoles ( LogLevel : LogType ; PercentCov : real ) ;
    procedure WriteCovHoles ( FileName : string;  OpenKind : File_Open_Kind := APPEND_MODE ) ;
    procedure WriteCovHoles ( LogLevel : LogType ; FileName : string;  OpenKind : File_Open_Kind := APPEND_MODE ) ;
    procedure WriteCovHoles ( FileName : string;  PercentCov : real ; OpenKind : File_Open_Kind := APPEND_MODE ) ;
    procedure WriteCovHoles ( LogLevel : LogType ; FileName : string;  PercentCov : real ; OpenKind : File_Open_Kind := APPEND_MODE ) ;
    procedure DumpBin (LogLevel : LogType := DEBUG) ;  -- Development only

    procedure ReadCovDb (FileName : string; Merge : boolean := FALSE) ;
    procedure WriteCovDb (FileName : string; OpenKind : File_Open_Kind := WRITE_MODE ) ;
    impure function GetErrorCount return integer ;

    -- These support usage of cross coverage constants
    -- Also support the older AddBins(GenCross(...)) methodology
    -- which has been replaced by AddCross
    procedure AddBins (CovBin : CovMatrix2Type ; Name : String := "") ;
    procedure AddBins (CovBin : CovMatrix3Type ; Name : String := "") ;
    procedure AddBins (CovBin : CovMatrix4Type ; Name : String := "") ;
    procedure AddBins (CovBin : CovMatrix5Type ; Name : String := "") ;
    procedure AddBins (CovBin : CovMatrix6Type ; Name : String := "") ;
    procedure AddBins (CovBin : CovMatrix7Type ; Name : String := "") ;
    procedure AddBins (CovBin : CovMatrix8Type ; Name : String := "") ;
    procedure AddBins (CovBin : CovMatrix9Type ; Name : String := "") ;

------------------------------------------------------------
-- Remaining are Deprecated
--
    -- Deprecated.  Replaced by SetName with multi-line support
    procedure SetItemName (ItemNameIn : String) ;  -- deprecated

    -- Deprecated.  Consistency across packages
    impure function CovBinErrCnt return integer ;

-- Deprecated.  Due to name changes to promote greater consistency
    -- Maintained for backward compatibility.
    -- RandCovHole replaced by RandCovBinVal
    impure function RandCovHole ( PercentCov : real ) return RangeArrayType ;  -- Deprecated
    impure function RandCovHole return RangeArrayType ;  -- Deprecated

    -- GetCovHole replaced by GetHoleBinVal
    impure function GetCovHole ( ReqHoleNum : integer ; PercentCov : real ) return RangeArrayType ;
    impure function GetCovHole ( PercentCov : real ) return RangeArrayType ;
    impure function GetCovHole ( ReqHoleNum : integer := 1 ) return RangeArrayType ;


-- Deprecated/ Subsumed by versions with PercentCov Parameter
    -- Maintained for backward compatibility only and
    -- may be removed in the future.
    impure function GetMinCov return integer ;
    impure function GetMaxCov return integer ;
    impure function CountCovHoles ( AtLeast : integer ) return integer ;
    impure function IsCovered ( AtLeast : integer ) return boolean ;
    impure function RandCovBinVal ( AtLeast : integer ) return RangeArrayType ;
    impure function RandCovHole ( AtLeast : integer ) return RangeArrayType ;          -- Deprecated
    impure function RandCovPoint (AtLeast : integer ) return integer ;
    impure function RandCovPoint (AtLeast : integer ) return integer_vector ;
    impure function GetHoleBinVal ( ReqHoleNum : integer ; AtLeast : integer ) return RangeArrayType ;
    impure function GetCovHole ( ReqHoleNum : integer ; AtLeast : integer ) return RangeArrayType ;

    procedure WriteCovHoles ( AtLeast : integer ) ;
    procedure WriteCovHoles ( LogLevel : LogType ; AtLeast : integer ) ;
    procedure WriteCovHoles ( FileName : string;  AtLeast : integer ; OpenKind : File_Open_Kind := APPEND_MODE ) ;
    procedure WriteCovHoles ( LogLevel : LogType ; FileName : string;  AtLeast : integer ; OpenKind : File_Open_Kind := APPEND_MODE ) ;

    end protected CovPType ;
  ------------------------------------------------------------------------------------------
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  ------------------------------------------------------------------------------------------


  ------------------------------------------------------------
  -- Experimental.  Intended primarily for development.
  procedure CompareBins (
  ------------------------------------------------------------
    variable Bin1       : inout CovPType ;
    variable Bin2       : inout CovPType ;
    variable ErrorCount : inout integer
  ) ;

  ------------------------------------------------------------
  -- Experimental.  Intended primarily for development.
  procedure CompareBins (
  ------------------------------------------------------------
    variable Bin1       : inout CovPType ;
    variable Bin2       : inout CovPType 
  ) ;

  --
  --  Support for AddBins and AddCross
  --

  ------------------------------------------------------------
  function GenBin(
  ------------------------------------------------------------
    AtLeast       : integer ;
    Weight        : integer ;
    Min, Max      : integer ;
    NumBin        : integer
  ) return CovBinType ;

  -- Each item in range in a separate CovBin
  function GenBin(AtLeast : integer ;  Min, Max, NumBin : integer ) return CovBinType ;
  function GenBin(Min, Max, NumBin : integer ) return CovBinType ;
  function GenBin(Min, Max : integer) return CovBinType ;
  function GenBin(A : integer) return CovBinType ;

    ------------------------------------------------------------
  function GenBin(
  ------------------------------------------------------------
    AtLeast       : integer ;
    Weight        : integer ;
    A             : integer_vector
  ) return CovBinType ;

  function GenBin ( AtLeast : integer ;  A : integer_vector ) return CovBinType ;
  function GenBin ( A : integer_vector ) return CovBinType ;


  ------------------------------------------------------------
  function IllegalBin ( Min, Max, NumBin : integer ) return CovBinType ;
  ------------------------------------------------------------

  -- All items in range in a single CovBin
  function IllegalBin ( Min, Max : integer ) return CovBinType ;
  function IllegalBin ( A : integer ) return CovBinType ;

  
-- IgnoreBin should never have an AtLeast parameter
  ------------------------------------------------------------
  function IgnoreBin (Min, Max, NumBin : integer) return CovBinType ;
  ------------------------------------------------------------
  function IgnoreBin (Min, Max : integer) return CovBinType ;  -- All items in range in a single CovBin
  function IgnoreBin (A : integer) return CovBinType ;


  -- With VHDL-2008, there will be one GenCross that returns CovBinType
  -- and has inputs initialized to NULL_BIN - see AddCross
  ------------------------------------------------------------
  function GenCross(  -- 2
  -- Cross existing bins
  -- Use AddCross for adding values directly to coverage database
  -- Use GenCross for constants
  ------------------------------------------------------------
    AtLeast     : integer ;
    Weight      : integer ;
    Bin1, Bin2  : CovBinType
  ) return CovMatrix2Type ;

  function GenCross(AtLeast : integer ; Bin1, Bin2 : CovBinType) return CovMatrix2Type ;
  function GenCross(Bin1, Bin2 : CovBinType) return CovMatrix2Type ;


  ------------------------------------------------------------
  function GenCross(  -- 3
  ------------------------------------------------------------
    AtLeast           : integer ;
    Weight            : integer ;
    Bin1, Bin2, Bin3  : CovBinType
  ) return CovMatrix3Type ;

  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3 : CovBinType ) return CovMatrix3Type ;
  function GenCross( Bin1, Bin2, Bin3 : CovBinType ) return CovMatrix3Type ;


  ------------------------------------------------------------
  function GenCross(  -- 4
  ------------------------------------------------------------
    AtLeast                 : integer ;
    Weight                  : integer ;
    Bin1, Bin2, Bin3, Bin4  : CovBinType
  ) return CovMatrix4Type ;

  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4 : CovBinType ) return CovMatrix4Type ;
  function GenCross( Bin1, Bin2, Bin3, Bin4 : CovBinType ) return CovMatrix4Type ;


  ------------------------------------------------------------
  function GenCross(  -- 5
  ------------------------------------------------------------
    AtLeast                       : integer ;
    Weight                        : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5  : CovBinType
  ) return CovMatrix5Type ;

  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5 : CovBinType ) return CovMatrix5Type ;
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5 : CovBinType ) return CovMatrix5Type ;


  ------------------------------------------------------------
  function GenCross(  -- 6
  ------------------------------------------------------------
    AtLeast                             : integer ;
    Weight                              : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6  : CovBinType
  ) return CovMatrix6Type ;

  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5, Bin6 : CovBinType ) return CovMatrix6Type ;
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5, Bin6 : CovBinType ) return CovMatrix6Type ;


  ------------------------------------------------------------
  function GenCross(  -- 7
  ------------------------------------------------------------
    AtLeast                                   : integer ;
    Weight                                    : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7  : CovBinType
  ) return CovMatrix7Type ;

  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7 : CovBinType ) return CovMatrix7Type ;
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7 : CovBinType ) return CovMatrix7Type ;


  ------------------------------------------------------------
  function GenCross(  -- 8
  ------------------------------------------------------------
    AtLeast                                         : integer ;
    Weight                                          : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8  : CovBinType
  ) return CovMatrix8Type ;

  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8 : CovBinType ) return CovMatrix8Type ;
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8 : CovBinType ) return CovMatrix8Type ;


  ------------------------------------------------------------
  function GenCross(  -- 9
  ------------------------------------------------------------
    AtLeast                                               : integer ;
    Weight                                                : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9  : CovBinType
  ) return CovMatrix9Type ;

  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9 : CovBinType ) return CovMatrix9Type ;
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9 : CovBinType ) return CovMatrix9Type ;


  ------------------------------------------------------------
  procedure increment( signal Count : inout integer ) ;
  procedure increment( signal Count : inout integer ; enable : boolean ) ;
  procedure increment( signal Count : inout integer ; enable : std_ulogic ) ;


  ------------------------------------------------------------
  -- Utilities.  Remove if added to std.standard
  function to_integer ( B : boolean ) return integer ;
  function to_integer ( SL : std_logic ) return integer ;
  function to_integer_vector ( BV : boolean_vector ) return integer_vector ;
  function to_integer_vector ( SLV : std_logic_vector ) return integer_vector ;


end package CoveragePkg ;

--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////

package body CoveragePkg is
  ------------------------------------------------------------
  function inside (
  -- package local
  ------------------------------------------------------------
    CovPoint : integer ;
    BinVal   : RangeType
  ) return boolean is
  begin
    return CovPoint >= BinVal.min and CovPoint <= BinVal.max ;
  end function inside ;


  ------------------------------------------------------------
  function inside (
  -- package local
  ------------------------------------------------------------
    CovPoint : integer_vector ;
    BinVal   : RangeArrayType
  ) return boolean is
    alias iCovPoint : integer_vector(BinVal'range) is CovPoint ;
  begin
    for i in BinVal'range loop
      if not (iCovPoint(i) >= BinVal(i).min and iCovPoint(i) <= BinVal(i).max) then
        return FALSE ;
      end if ;
    end loop ;
    return TRUE ;
  end function inside ;


  ------------------------------------------------------------
  function inside (
  -- package local, used by InsertBin
  -- True when BinVal1 is inside BinVal2
  ------------------------------------------------------------
    BinVal1  : RangeArrayType ;
    BinVal2  : RangeArrayType
  ) return boolean is
    alias iBinVal2 : RangeArrayType(BinVal1'range) is BinVal2 ;
  begin
    for i in BinVal1'range loop
      if not (BinVal1(i).min >= iBinVal2(i).min and BinVal1(i).max <= iBinVal2(i).max) then
        return FALSE ;
      end if ;
    end loop ;
    return TRUE ;
  end function inside ;


  ------------------------------------------------------------
  procedure write (
    variable buf : inout line ;
    CovPoint     : integer_vector
  ) is
  -- package local.  called by ICover
  ------------------------------------------------------------
    alias iCovPoint : integer_vector(1 to CovPoint'length) is CovPoint ;
  begin
    write(buf, "(" & integer'image(iCovPoint(1)) ) ;
    for i in 2 to iCovPoint'right loop
      write(buf, "," & integer'image(iCovPoint(i)) ) ;
    end loop ;
    swrite(buf, ")") ;
  end procedure write ;

  ------------------------------------------------------------
  procedure write ( file f :  text ;  BinVal : RangeArrayType ) is
  -- called by WriteBin and WriteCovHoles
  ------------------------------------------------------------
  begin
    for i in BinVal'range loop
      if BinVal(i).min = BinVal(i).max then
        write(f, "(" & integer'image(BinVal(i).min) & ") " ) ;
      elsif  (BinVal(i).min = integer'left) and (BinVal(i).max = integer'right) then
        write(f, "(ALL) " ) ;
      else
        write(f, "(" & integer'image(BinVal(i).min) & " to " &
                       integer'image(BinVal(i).max) & ") " ) ;
      end if ;
    end loop ;
  end procedure write ;

  ------------------------------------------------------------
  procedure write (
  -- called by WriteBin and WriteCovHoles
  ------------------------------------------------------------
    variable buf    : inout line ;
    constant BinVal : in    RangeArrayType
  ) is
  ------------------------------------------------------------
  begin
    for i in BinVal'range loop
      if BinVal(i).min = BinVal(i).max then
        write(buf, "(" & integer'image(BinVal(i).min) & ") " ) ;
      elsif  (BinVal(i).min = integer'left) and (BinVal(i).max = integer'right) then
        swrite(buf, "(ALL) " ) ;
      else
        write(buf, "(" & integer'image(BinVal(i).min) & " to " &
                       integer'image(BinVal(i).max) & ") " ) ;
      end if ;
    end loop ;
  end procedure write ;


  ------------------------------------------------------------
  procedure WriteBinVal (
  -- package local for now
  ------------------------------------------------------------
    variable buf    : inout line ;
    constant BinVal : in    RangeArrayType
  ) is
  begin
    for i in BinVal'range loop
      write(buf, BinVal(i).min) ;
      write(buf, ' ') ;
      write(buf, BinVal(i).max) ;
      write(buf, ' ') ;
    end loop ;
  end procedure WriteBinVal ;


  ------------------------------------------------------------
  -- package local
  procedure EmptyOrCommentLine (
  -- Better as Function, but not supported in VHDL functions
  ------------------------------------------------------------
    variable L     : InOut line ;
    variable Empty : out   boolean
  ) is
    variable Valid : boolean ;
    variable Char  : character ;
    constant NBSP  : CHARACTER := CHARACTER'val(160);  -- space character
  begin
    Empty := TRUE ;

    -- if line empty (null or 0 length), Empty = TRUE
    if L = null or L.all'length = 0 then
      return ;
    end if ;

    -- if line starts with '#', empty = TRUE
    if L.all(1) = '#' then
      return ;
    end if ;

    -- if line starts with '--', empty = TRUE
    if L.all'length >= 2 and L.all(1) = '-' and L.all(2) = '-' then
      return ;
    end if ;

    -- Otherwise, remove white space and check for end of line
    -- Code borrowed from David Bishop, skip_whitespace
    WhiteSpLoop : while L /= null and L.all'length > 0 loop
      if (L.all(1) = ' ' or L.all(1) = NBSP or L.all(1) = HT) then
        read (L, Char, Valid) ;
      else
        Empty := FALSE ;
        exit WhiteSpLoop ;
      end if ;
    end loop WhiteSpLoop ;
  end procedure EmptyOrCommentLine ;

  ------------------------------------------------------------
  -- package local for now
  procedure read (
  -- if public, also create one that does not use valid flag
  ------------------------------------------------------------
    variable buf    : inout line ;
    variable BinVal : out   RangeArrayType ;
    variable Valid  : out   boolean
  ) is
    variable ReadValid : boolean ;
  begin
    for i in BinVal'range loop
      read(buf, BinVal(i).min, ReadValid) ;
      exit when not ReadValid ;
      read(buf, BinVal(i).max, ReadValid) ;
      exit when not ReadValid ;
    end loop ;
    Valid := ReadValid ;
  end procedure read ;


  -- ------------------------------------------------------------
  function BinLengths (
  -- package local, used by AddCross, GenCross
  -- ------------------------------------------------------------
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
    Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
 ) return integer_vector is
   variable result : integer_vector(1 to 20) := (others => 0 ) ;
   variable i : integer := result'left ;
   variable Len : integer ;
  begin
    loop
      case i is
        when  1 =>  Len := Bin1'length ;
        when  2 =>  Len := Bin2'length ;
        when  3 =>  Len := Bin3'length ;
        when  4 =>  Len := Bin4'length ;
        when  5 =>  Len := Bin5'length ;
        when  6 =>  Len := Bin6'length ;
        when  7 =>  Len := Bin7'length ;
        when  8 =>  Len := Bin8'length ;
        when  9 =>  Len := Bin9'length ;
        when 10 =>  Len := Bin10'length ;
        when 11 =>  Len := Bin11'length ;
        when 12 =>  Len := Bin12'length ;
        when 13 =>  Len := Bin13'length ;
        when 14 =>  Len := Bin14'length ;
        when 15 =>  Len := Bin15'length ;
        when 16 =>  Len := Bin16'length ;
        when 17 =>  Len := Bin17'length ;
        when 18 =>  Len := Bin18'length ;
        when 19 =>  Len := Bin19'length ;
        when 20 =>  Len := Bin20'length ;
        when others =>  Len := 0 ;
      end case ;
      result(i) := Len ;
      exit when Len = 0 ;
      i := i + 1 ;
      exit when i = 21 ;
    end loop ;
    return result(1 to (i-1)) ;
  end function BinLengths ;


  -- ------------------------------------------------------------
  function CalcNumCrossBins ( BinLens : integer_vector ) return integer is
  -- package local, used by AddCross
  -- ------------------------------------------------------------
    variable result : integer := 1 ;
  begin
    for i in BinLens'range loop
      result := result * BinLens(i) ;
    end loop ;
    return result ;
  end function CalcNumCrossBins ;


  -- ------------------------------------------------------------
  procedure IncBinIndex (
  -- package local, used by AddCross
  -- ------------------------------------------------------------
    variable BinIndex : inout integer_vector ;
    constant BinLens  : in    integer_vector
  ) is
    alias aBinIndex : integer_vector(1 to BinIndex'length) is BinIndex ;
    alias aBinLens  : integer_vector(aBinIndex'range) is BinLens ;
  begin
    -- increment right most one, then if overflow, increment next
    -- assumes bins numbered from 1 to N.  - assured by ConcatenateBins
    for i in aBinIndex'reverse_range loop
      aBinIndex(i) := aBinIndex(i) + 1 ;
      exit when aBinIndex(i) <= aBinLens(i) ;
      aBinIndex(i) := 1 ;
    end loop ;
  end procedure IncBinIndex ;


  -- ------------------------------------------------------------
  function ConcatenateBins (
  -- package local, used by AddCross
  -- ------------------------------------------------------------
    BinIndex : integer_vector ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
    Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
  ) return CovBinType is
    alias aBin1  : CovBinType (1 to Bin1'length) is Bin1 ;
    alias aBin2  : CovBinType (1 to Bin2'length) is Bin2 ;
    alias aBin3  : CovBinType (1 to Bin3'length) is Bin3 ;
    alias aBin4  : CovBinType (1 to Bin4'length) is Bin4 ;
    alias aBin5  : CovBinType (1 to Bin5'length) is Bin5 ;
    alias aBin6  : CovBinType (1 to Bin6'length) is Bin6 ;
    alias aBin7  : CovBinType (1 to Bin7'length) is Bin7 ;
    alias aBin8  : CovBinType (1 to Bin8'length) is Bin8 ;
    alias aBin9  : CovBinType (1 to Bin9'length) is Bin9 ;
    alias aBin10 : CovBinType (1 to Bin10'length) is Bin10 ;
    alias aBin11 : CovBinType (1 to Bin11'length) is Bin11 ;
    alias aBin12 : CovBinType (1 to Bin12'length) is Bin12 ;
    alias aBin13 : CovBinType (1 to Bin13'length) is Bin13 ;
    alias aBin14 : CovBinType (1 to Bin14'length) is Bin14 ;
    alias aBin15 : CovBinType (1 to Bin15'length) is Bin15 ;
    alias aBin16 : CovBinType (1 to Bin16'length) is Bin16 ;
    alias aBin17 : CovBinType (1 to Bin17'length) is Bin17 ;
    alias aBin18 : CovBinType (1 to Bin18'length) is Bin18 ;
    alias aBin19 : CovBinType (1 to Bin19'length) is Bin19 ;
    alias aBin20 : CovBinType (1 to Bin20'length) is Bin20 ;
    alias aBinIndex : integer_vector(1 to BinIndex'length) is BinIndex ;
    variable result : CovBinType(aBinIndex'range) ;
  begin
    for i in aBinIndex'range loop
      case i is
        when  1 =>  result(i) := aBin1(aBinIndex(i)) ;
        when  2 =>  result(i) := aBin2(aBinIndex(i)) ;
        when  3 =>  result(i) := aBin3(aBinIndex(i)) ;
        when  4 =>  result(i) := aBin4(aBinIndex(i)) ;
        when  5 =>  result(i) := aBin5(aBinIndex(i)) ;
        when  6 =>  result(i) := aBin6(aBinIndex(i)) ;
        when  7 =>  result(i) := aBin7(aBinIndex(i)) ;
        when  8 =>  result(i) := aBin8(aBinIndex(i)) ;
        when  9 =>  result(i) := aBin9(aBinIndex(i)) ;
        when 10 =>  result(i) := aBin10(aBinIndex(i)) ;
        when 11 =>  result(i) := aBin11(aBinIndex(i)) ;
        when 12 =>  result(i) := aBin12(aBinIndex(i)) ;
        when 13 =>  result(i) := aBin13(aBinIndex(i)) ;
        when 14 =>  result(i) := aBin14(aBinIndex(i)) ;
        when 15 =>  result(i) := aBin15(aBinIndex(i)) ;
        when 16 =>  result(i) := aBin16(aBinIndex(i)) ;
        when 17 =>  result(i) := aBin17(aBinIndex(i)) ;
        when 18 =>  result(i) := aBin18(aBinIndex(i)) ;
        when 19 =>  result(i) := aBin19(aBinIndex(i)) ;
        when 20 =>  result(i) := aBin20(aBinIndex(i)) ;
        when others =>  Alert(OSVVM_ALERTLOG_ID, "CoveragePkg.AddCross: More than 20 bins not supported", FAILURE) ;
      end case ;
    end loop ;
    return result ;
  end function ConcatenateBins ;


  ------------------------------------------------------------
  function MergeState( CrossBins : CovBinType) return integer is
  -- package local, Used by AddCross, GenCross
  ------------------------------------------------------------
    variable resultState : integer ;
  begin
    resultState := COV_COUNT ;
    for i in CrossBins'range loop
      if CrossBins(i).action = COV_ILLEGAL then
        return COV_ILLEGAL ;
      end if ;
      if CrossBins(i).action = COV_IGNORE then
        resultState := COV_IGNORE ;
      end if ;
    end loop ;
    return resultState ;
  end function MergeState ;


  ------------------------------------------------------------
  function MergeBinVal( CrossBins : CovBinType) return RangeArrayType is
  -- package local, Used by AddCross, GenCross
  ------------------------------------------------------------
    alias aCrossBins : CovBinType(1 to CrossBins'length) is CrossBins ;
    variable BinVal : RangeArrayType(aCrossBins'range) ;
  begin
    for i in aCrossBins'range loop
      BinVal(i to i) := aCrossBins(i).BinVal ;
    end loop ;
    return BinVal ;
  end function MergeBinVal ;


  ------------------------------------------------------------
  function MergeAtLeast(
  -- package local, Used by AddCross, GenCross
  ------------------------------------------------------------
    Action    : in integer ;
    AtLeast   : in integer ;
    CrossBins : in CovBinType
  ) return integer is
    variable Result : integer := AtLeast ;
  begin
    if Action /= COV_COUNT then
      return 0 ;
    end if ;
    for i in CrossBins'range loop
      if CrossBins(i).Action = Action then
        Result := maximum (Result, CrossBins(i).AtLeast) ;
      end if ;
    end loop ;
    return result ;
  end function MergeAtLeast ;


  ------------------------------------------------------------
  function MergeWeight(
  -- package local, Used by AddCross, GenCross
  ------------------------------------------------------------
    Action    : in integer ;
    Weight    : in integer ;
    CrossBins : in CovBinType
  ) return integer is
    variable Result : integer := Weight ;
  begin
    if Action /= COV_COUNT then
      return 0 ;
    end if ;
    for i in CrossBins'range loop
      if CrossBins(i).Action = Action then
        Result := maximum (Result, CrossBins(i).Weight) ;
      end if ;
    end loop ;
    return result ;
  end function MergeWeight ;


  ------------------------------------------------------------
  function ToMinPoint (A : RangeArrayType) return integer is
  -- Used in testing
  ------------------------------------------------------------
  begin
    return A(A'left).min ;
  end function ToMinPoint ;


  ------------------------------------------------------------
  function ToMinPoint (A : RangeArrayType) return integer_vector is
  -- Used in testing
  ------------------------------------------------------------
    variable result : integer_vector(A'range) ;
  begin
    for i in A'range loop
      result(i) := A(i).min ;
    end loop ;
    return result ;
  end function ToMinPoint ;


  ------------------------------------------------------------
  procedure ToRandPoint(
  ------------------------------------------------------------
    variable RV       : inout RandomPType ;
    constant BinVal   : in    RangeArrayType ;
    variable result   : out   integer
  ) is
  begin
    result := RV.RandInt(BinVal(BinVal'left).min, BinVal(BinVal'left).max) ;
  end procedure ToRandPoint ;


  ------------------------------------------------------------
  procedure ToRandPoint(
  ------------------------------------------------------------
    variable RV       : inout RandomPType ;
    constant BinVal   : in    RangeArrayType ;
    variable result   : out   integer_vector
  ) is
    variable VectorVal : integer_vector(BinVal'range) ;
  begin
    for i in BinVal'range loop
      VectorVal(i) := RV.RandInt(BinVal(i).min, BinVal(i).max) ;
    end loop ;
    result := VectorVal ;
  end procedure ToRandPoint ;

  ------------------------------------------------------------
  -- Local.  Get first word from a string
  function GetWord (Message : string) return string is
  ------------------------------------------------------------
    alias aMessage : string( 1 to Message'length) is Message ;
  begin
    for i in aMessage'range loop
      if aMessage(i) = ' ' or aMessage(i) = HT then
        return aMessage(1 to i-1) ;
      end if ;
    end loop ;
    return aMessage ;
  end function GetWord ;

  ------------------------------------------------------------------------------------------
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  ------------------------------------------------------------------------------------------
  type CovPType is protected body

    -- Name Data Structure
    variable CovNameVar    : NamePType ;
    variable CovMessageVar : MessagePType ;

    -- CoverageBin Data Structures
    type RangeArrayPtrType is access RangeArrayType ;

    type CovBinBaseTempType is record
      BinVal        : RangeArrayPtrType ;
      Action        : integer ;
      Count         : integer ;
      AtLeast       : integer ;
      Weight        : integer ;
      PercentCov    : real ;
      OrderCount    : integer ;
      Name          : line ;
    end record CovBinBaseTempType ;
    type CovBinTempType is array (natural range <>) of CovBinBaseTempType ;
    type CovBinPtrType is access CovBinTempType ;

    variable CovBinPtr  : CovBinPtrType ;
    variable NumBins    : integer := 0 ;
    variable BinValLength  : integer := 1 ;
    variable OrderCount : integer := 0 ;  -- for statistics
    variable ItemCount : integer := 0 ;  -- Count of randomizations
    variable LastIndex : integer := 1 ;  -- Index of last randomization

    -- Internal Modes and Names
    variable IllegalMode   : IllegalModeType := ILLEGAL_ON ;
    variable IllegalModeLevel : AlertType    := ERROR ; 
    variable WeightMode    : WeightModeType  := AT_LEAST ;
    variable WeightScale   : real            := 1.0 ;

    variable ThresholdingEnable : boolean := FALSE ; -- thresholding disabled by default
    variable CovThreshold  : real := 45.0 ;
    variable CovTarget     : real := 100.0 ;

    variable MergingEnable : boolean := FALSE ; -- merging disabled by default
    variable CountMode     : CountModeType   := COUNT_FIRST ;

    -- Randomization Variable
    variable RV : RandomPType ;
    variable RvSeedInit : boolean := FALSE ;

    file WriteBinFile : text ;
    variable WriteBinFileInit : boolean := FALSE ;
    variable UsingLocalFile   : boolean := FALSE ;
    variable AlertLogIDVar    : AlertLogIDType := OSVVM_ALERTLOG_ID ;

    -- file WriteCovDbFile : text ;
    -- variable WriteCovDbFileInit : boolean := FALSE ;

    -- Local WriteBin and WriteCovHoles formatting settings, defaults determined by CoverageGlobals
    variable WritePassFailVar   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
    variable WriteBinInfoVar    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
    variable WriteCountVar      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
    variable WriteAnyIllegalVar : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
    variable WritePrefixVar     : NamePType ;
    variable PassNameVar        : NamePType ;
    variable FailNameVar        : NamePType ;
    

    ------------------------------------------------------------
    procedure FileOpenWriteBin (FileName : string; OpenKind : File_Open_Kind ) is
    ------------------------------------------------------------
    begin
      WriteBinFileInit := TRUE ;
      file_open( WriteBinFile , FileName , OpenKind );
    end procedure FileOpenWriteBin ;

    ------------------------------------------------------------
    procedure FileCloseWriteBin is
    ------------------------------------------------------------
    begin
      WriteBinFileInit := FALSE ;
      file_close( WriteBinFile) ;
    end procedure FileCloseWriteBin ;

    ------------------------------------------------------------
    procedure SetAlertLogID (A : AlertLogIDType) is
    ------------------------------------------------------------
    begin
      AlertLogIDVar := A ;
    end procedure SetAlertLogID ;
    
    ------------------------------------------------------------
    impure function GetAlertLogID return AlertLogIDType is
    ------------------------------------------------------------
    begin
      return AlertLogIDVar ; 
    end function GetAlertLogID ;
    
    
--      ------------------------------------------------------------
--      procedure FileOpen (FileName : string; OpenKind : File_Open_Kind ) is
--      ------------------------------------------------------------
--      begin
--        WriteCovDbFileInit := TRUE ;
--        file_open( WriteCovDbFile , FileName , OpenKind );
--      end procedure FileOpenWriteCovDb ;
--
--      ------------------------------------------------------------
--      procedure FileCloseWriteCovDb is
--      ------------------------------------------------------------
--      begin
--        WriteCovDbFileInit := FALSE ;
--        file_close( WriteCovDbFile );
--      end procedure FileCloseWriteCovDb ;

    ------------------------------------------------------------
    procedure SetName (Name : String) is
    ------------------------------------------------------------
    begin
      CovNameVar.Set(Name) ;
      if not RvSeedInit then  -- Init seed if not initialized
        RV.InitSeed(Name) ;
        RvSeedInit := TRUE ;
      end if ;
    end procedure SetName ;

    ------------------------------------------------------------
    impure function SetName (Name : String) return string is
    ------------------------------------------------------------
    begin
      CovNameVar.Set(Name) ;
      if not RvSeedInit then  -- Init seed if not initialized
        RV.InitSeed(Name) ;
        RvSeedInit := TRUE ;
      end if ;
      return Name ; 
    end function SetName ;

    ------------------------------------------------------------
    impure function GetName return String is
    ------------------------------------------------------------
    begin
      if CovNameVar.IsSet then
        return CovNameVar.Get ;
      elsif CovMessageVar.IsSet then
        return GetWord(string'(CovMessageVar.Get(1))) ;
      else
        return "" ;
      end if ;
    end function GetName ;

    ------------------------------------------------------------
    procedure SetMessage (Message : String) is
    ------------------------------------------------------------
    begin
      CovMessageVar.Set(Message) ;
      if not RvSeedInit then  -- Init seed if not initialized
        RV.InitSeed(Message) ;
        RvSeedInit := TRUE ;
      end if ;
    end procedure SetMessage ;

    ------------------------------------------------------------
    procedure SetIllegalMode (A : IllegalModeType) is
    ------------------------------------------------------------
    begin
      IllegalMode := A ;
      if IllegalMode = ILLEGAL_FAILURE then 
        IllegalModeLevel := FAILURE ; 
      else 
        IllegalModeLevel := ERROR ; 
      end if ; 
    end procedure SetIllegalMode ;

    ------------------------------------------------------------
    procedure SetWeightMode (A : WeightModeType;  Scale : real := 1.0) is
    ------------------------------------------------------------
      variable buf : line ;
    begin
      WeightMode := A ;
      WeightScale := Scale ;

      if (WeightMode = REMAIN_EXP) and (WeightScale > 2.0) then
        Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.SetWeightMode: WeightScale > 2.0 and large Counts can cause RandCovPoint to fail due to integer values out of range", WARNING) ;
      end if ;
      if (WeightScale < 1.0) and (WeightMode = REMAIN_WEIGHT or WeightMode = REMAIN_SCALED) then
        Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.SetWeightMode: WeightScale must be > 1.0 when WeightMode = REMAIN_WEIGHT or WeightMode = REMAIN_SCALED", FAILURE) ;
        WeightScale := 1.0 ;
      end if;
      if WeightScale <= 0.0 then
        Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.SetWeightMode: WeightScale must be > 0.0", FAILURE) ;
        WeightScale := 1.0 ;
      end if;
    end procedure SetWeightMode ;

    ------------------------------------------------------------
    -- pt local for now -- file formal parameter not allowed with a public method
    procedure WriteBinName ( file f : text ; S : string ; Prefix : string := "%% " ) is
    ------------------------------------------------------------
      variable MessageCount : integer ;
      variable buf : line ;
    begin
      MessageCount := CovMessageVar.GetCount ;
      if MessageCount = 0 then
        if Prefix'length + S'length > 0 then  -- everything except WriteCovDb
          write(buf, Prefix & S & GetName) ; -- Print name when no message
          writeline(f, buf) ;
          -- write(f, Prefix & S & LF);
        end if ;
      else
        write(buf, Prefix & S & string'(CovMessageVar.Get(1))) ;
        writeline(f, buf) ;
        for i in 2 to MessageCount loop
          write(buf, Prefix & string'(CovMessageVar.Get(i))) ;
          writeline(f, buf) ;
        end loop ;
      end if ;
    end procedure WriteBinName ;

    ------------------------------------------------------------
    procedure DeallocateMessage is
    ------------------------------------------------------------
    begin
      CovMessageVar.Deallocate ;
    end procedure DeallocateMessage ;

    ------------------------------------------------------------
    procedure DeallocateName is
    ------------------------------------------------------------
    begin
      CovNameVar.Clear ;
    end procedure DeallocateName ;

    ------------------------------------------------------------
    procedure SetThresholding (A : boolean := TRUE ) is
    ------------------------------------------------------------
    begin
      ThresholdingEnable := A ;
    end procedure SetThresholding ;

    ------------------------------------------------------------
    procedure SetCovThreshold (Percent : real) is
    ------------------------------------------------------------
    begin
      ThresholdingEnable := TRUE ;
      if Percent >= 0.0 then
        CovThreshold := Percent + 0.0001 ; -- used in less than
      else
        CovThreshold := 0.0001 ; -- used in less than
        Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.SetCovThreshold: Invalid Threshold Value " & real'image(Percent), FAILURE) ;
      end if ;
    end procedure SetCovThreshold ;

    ------------------------------------------------------------
    procedure SetCovTarget (Percent : real) is
    ------------------------------------------------------------
    begin
      CovTarget := Percent ;
    end procedure SetCovTarget ;

    ------------------------------------------------------------
    impure function GetCovTarget return real is
    ------------------------------------------------------------
    begin
      return CovTarget ;
    end function GetCovTarget ;

    ------------------------------------------------------------
    procedure SetMerging (A : boolean := TRUE ) is
    ------------------------------------------------------------
    begin
      MergingEnable := A ;
    end procedure SetMerging ;

    ------------------------------------------------------------
    procedure SetCountMode (A : CountModeType) is
    ------------------------------------------------------------
    begin
      CountMode := A ;
    end procedure SetCountMode ;

    ------------------------------------------------------------
    procedure InitSeed (S : string ) is
    ------------------------------------------------------------
    begin
      RV.InitSeed(S) ;
      RvSeedInit := TRUE ;
    end procedure InitSeed ;

    ------------------------------------------------------------
    impure function InitSeed (S : string ) return string is
    ------------------------------------------------------------
    begin
      RV.InitSeed(S) ;
      RvSeedInit := TRUE ;
      return S ; 
    end function InitSeed ;

    ------------------------------------------------------------
    procedure InitSeed (I : integer ) is
    ------------------------------------------------------------
    begin
      RV.InitSeed(I) ;
      RvSeedInit := TRUE ;
    end procedure InitSeed ;

    ------------------------------------------------------------
    procedure SetSeed (RandomSeedIn : RandomSeedType ) is
    ------------------------------------------------------------
    begin
      RV.SetSeed(RandomSeedIn) ;
      RvSeedInit := TRUE ;
    end procedure SetSeed ;

    ------------------------------------------------------------
    impure function GetSeed return RandomSeedType is
    ------------------------------------------------------------
    begin
      return RV.GetSeed ;
    end function GetSeed ;

    ------------------------------------------------------------
    procedure SetReportOptions (
    ------------------------------------------------------------
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) is
    begin
      if WritePassFail /= COV_OPT_INIT_PARM_DETECT then
        WritePassFailVar   := WritePassFail ;
      end if ;
      if WriteBinInfo /= COV_OPT_INIT_PARM_DETECT then
        WriteBinInfoVar    := WriteBinInfo ;
      end if ;
      if WriteCount /= COV_OPT_INIT_PARM_DETECT then
        WriteCountVar      := WriteCount ;
      end if ;
      if WriteAnyIllegal /= COV_OPT_INIT_PARM_DETECT then
        WriteAnyIllegalVar := WriteAnyIllegal ;
      end if ;
      if WritePrefix /= OSVVM_STRING_INIT_PARM_DETECT then
        WritePrefixVar.Set(WritePrefix) ; 
      end if ;
      if PassName /= OSVVM_STRING_INIT_PARM_DETECT then
        PassNameVar.Set(PassName) ; 
      end if ;
      if FailName /= OSVVM_STRING_INIT_PARM_DETECT then
        FailNameVar.Set(FailName) ; 
      end if ;
    end procedure SetReportOptions ;


    ------------------------------------------------------------
    procedure SetBinSize (NewNumBins : integer) is
    -- Sets a CovBin to a particular size
    -- Use for small bins to save space or large bins to
    -- suppress the resize and copy as a CovBin autosizes.
    ------------------------------------------------------------
      variable oldCovBinPtr : CovBinPtrType ;
    begin
      if CovBinPtr = NULL then
        CovBinPtr := new CovBinTempType(1 to NewNumBins) ;
      elsif NewNumBins > CovBinPtr'length then
        -- make message bigger
        oldCovBinPtr := CovBinPtr ;
        CovBinPtr := new CovBinTempType(1 to NewNumBins) ;
        CovBinPtr.all(1 to NumBins) := oldCovBinPtr.all(1 to NumBins) ;
        deallocate(oldCovBinPtr) ;
      end if ;
    end procedure SetBinSize ;

    ------------------------------------------------------------
    -- pt local
    procedure CheckBinValLength( CurBinValLength : integer ; Caller : string ) is
    begin
      if NumBins = 0 then
        BinValLength := CurBinValLength ; -- number of points in cross
      else
        AlertIf(BinValLength /= CurBinValLength, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg." & Caller & ": Cross coverage bins of different dimensions prohibited", FAILURE) ; 
      end if;
    end procedure CheckBinValLength ;

    ------------------------------------------------------------
    --  pt local
    impure function NormalizeNumBins( ReqNumBins : integer ) return integer is
      variable NormNumBins : integer := MIN_NUM_BINS ;
    begin
      while NormNumBins < ReqNumBins loop
        NormNumBins := NormNumBins + MIN_NUM_BINS ;
      end loop ;
      return NormNumBins ;
    end function NormalizeNumBins ;


    ------------------------------------------------------------
    --  pt local
    procedure GrowBins (ReqNumBins : integer) is
      variable oldCovBinPtr : CovBinPtrType ;
      variable NewNumBins   : integer ;
    begin
      NewNumBins := NumBins + ReqNumBins ;
      if CovBinPtr = NULL then
        CovBinPtr := new CovBinTempType(1 to NormalizeNumBins(NewNumBins)) ;
      elsif NewNumBins > CovBinPtr'length then
        -- make message bigger
        oldCovBinPtr := CovBinPtr ;
        CovBinPtr := new CovBinTempType(1 to NormalizeNumBins(NewNumBins)) ;
        CovBinPtr.all(1 to NumBins) := oldCovBinPtr.all(1 to NumBins) ;
        deallocate(oldCovBinPtr) ;
      end if ;
    end procedure GrowBins ;


    ------------------------------------------------------------
    --  pt local, called by InsertBin
    -- Finds index of bin if it is inside an existing bins
    procedure FindBinInside(
      BinVal       : RangeArrayType ;
      Position     : out integer ;
      FoundInside  : out boolean
    ) is
    begin
      Position     := NumBins + 1 ;
      FoundInside  := FALSE ;
      FindLoop : for i in NumBins downto 1 loop
        -- skip this CovBin if CovPoint is not in it
        next FindLoop when not inside(BinVal, CovBinPtr(i).BinVal.all) ;
        Position := i ;
        FoundInside := TRUE ;
        exit ;
      end loop ;
    end procedure FindBinInside ;

    ------------------------------------------------------------
    --  pt local
    -- Inserts values into a new bin.
    -- Called by InsertBin
    procedure InsertNewBin(
      BinVal       : RangeArrayType ;
      Action       : integer ;
      Count        : integer ;
      AtLeast      : integer ;
      Weight       : integer ;
      Name         : string ;
      PercentCov   : real := 0.0
    ) is
    begin
      NumBins := NumBins + 1 ;
      CovBinPtr.all(NumBins).BinVal      := new RangeArrayType'(BinVal) ;
      CovBinPtr.all(NumBins).Action      := Action ;
      CovBinPtr.all(NumBins).Count       := Count ;
      CovBinPtr.all(NumBins).AtLeast     := AtLeast ;
      CovBinPtr.all(NumBins).Weight      := Weight ;
      CovBinPtr.all(NumBins).Name        := new String'(Name) ;
      CovBinPtr.all(NumBins).PercentCov  := PercentCov ;
      CovBinPtr.all(NumBins).OrderCount  := 0 ;  --- Metrics for evaluating randomization order Temp
    end procedure InsertNewBin ;


    ------------------------------------------------------------
    --  pt local
    -- Inserts values into a new bin.
    -- Called by InsertBin
    procedure MergeBin (
      Position     : Natural ;
      Count        : integer ;
      AtLeast      : integer ;
      Weight       : integer
    ) is
    begin
      CovBinPtr.all(Position).Count   := CovBinPtr.all(Position).Count + Count ;
      CovBinPtr.all(Position).AtLeast := CovBinPtr.all(Position).AtLeast + AtLeast ;
      CovBinPtr.all(Position).Weight  := CovBinPtr.all(Position).Weight + Weight ;
      CovBinPtr.all(Position).PercentCov :=
        real(CovBinPtr.all(Position).Count)*100.0/maximum(real(CovBinPtr.all(Position).AtLeast), 1.0) ;
    end procedure MergeBin ;


    ------------------------------------------------------------
    --  pt local
    -- All insertion comes here
    -- Enforces the general insertion use model:
    --   Earlier bins supercede later bins - except with COUNT_ALL
    --   Add Illegal and Ignore bins first to remove regions of larger count bins
    --   Later ignore bins can be used to miss an illegal catch-all
    --   Add Illegal bins last as a catch-all to find things that missed other bins
    procedure InsertBin(
      BinVal       : RangeArrayType ;
      Action       : integer ;
      Count        : integer ;
      AtLeast      : integer ;
      Weight       : integer ;
      Name         : string ;
      PercentCov   : real := 0.0
    ) is
      variable Position : integer ;
      variable FoundInside : boolean ;
    begin
      if not MergingEnable then
        InsertNewBin(BinVal, Action, Count, AtLeast, Weight, Name, PercentCov) ;

      else -- handle merging
-- future optimization, FindBinInside only checks against Ignore and Illegal bins
        FindBinInside(BinVal, Position, FoundInside) ;

        if not FoundInside then
          InsertNewBin(BinVal, Action, Count, AtLeast, Weight, Name, PercentCov) ;

        elsif Action = COV_COUNT then
-- when check only ignore and illegal bins, only action is to drop
          if CovBinPtr.all(Position).Action /= COV_COUNT then
            null ; -- drop count bin when it is inside a Illegal or Ignore bin

          elsif CovBinPtr.all(Position).BinVal.all = BinVal and CovBinPtr.all(Position).Name.all = Name then
            -- Bins match, so merge the count values
            MergeBin (Position, Count, AtLeast, Weight) ;
          else
            -- Bins overlap, but do not match, insert new bin
            InsertNewBin(BinVal, Action, Count, AtLeast, Weight, Name, PercentCov) ;
          end if;

        elsif Action = COV_IGNORE then
-- when check only ignore and illegal bins, only action is to report error
          if CovBinPtr.all(Position).Action = COV_COUNT then
            InsertNewBin(BinVal, Action, Count, AtLeast, Weight, Name, PercentCov) ;
          else
            Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.InsertBin (AddBins/AddCross):  ignore bin dropped.  It is a subset of prior bin", ERROR) ;
          end if;

        elsif Action = COV_ILLEGAL then
-- when check only ignore and illegal bins, only action is to report error
          if CovBinPtr.all(Position).Action = COV_COUNT then
            InsertNewBin(BinVal, Action, Count, AtLeast, Weight, Name, PercentCov) ;
          else
            Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.InsertBin (AddBins/AddCross):  illegal bin dropped.  It is a subset of prior bin", ERROR) ;
          end if;
        end if ;
      end if ; -- merging enabled
    end procedure InsertBin ;


    ------------------------------------------------------------
    procedure AddBins (
    ------------------------------------------------------------
      Name    : String ;
      AtLeast : integer ;
      Weight  : integer ;
      CovBin  : CovBinType
    ) is
      variable calcAtLeast : integer ;
      variable calcWeight  : integer ;
    begin
      CheckBinValLength( 1, "AddBins") ;
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        if CovBin(i).Action = COV_COUNT then
          calcAtLeast := maximum(AtLeast, CovBin(i).AtLeast) ;
          calcWeight  := maximum(Weight, CovBin(i).Weight) ;
        else
          calcAtLeast := 0 ;
          calcWeight  := 0 ;
        end if ;
        InsertBin(
          BinVal   => CovBin(i).BinVal,
          Action   => CovBin(i).Action,
          Count    => CovBin(i).Count,
          AtLeast  => calcAtLeast,
          Weight   => calcWeight,
          Name     => Name
        ) ;
      end loop ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins ( Name : String ; AtLeast : integer ; CovBin : CovBinType ) is
    ------------------------------------------------------------
    begin
      AddBins(Name, AtLeast, 0, CovBin) ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins (Name : String ;  CovBin : CovBinType) is
    ------------------------------------------------------------
    begin
      AddBins(Name, 0, 0, CovBin) ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins ( AtLeast : integer ; Weight  : integer ; CovBin : CovBinType ) is
    ------------------------------------------------------------
    begin
      AddBins("", AtLeast, Weight, CovBin) ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins ( AtLeast : integer ; CovBin : CovBinType ) is
    ------------------------------------------------------------
    begin
      AddBins("", AtLeast, 0, CovBin) ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins ( CovBin : CovBinType  ) is
    ------------------------------------------------------------
    begin
      AddBins("", 0, 0, CovBin) ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddCross(
    ------------------------------------------------------------
      Name       : string ;
      AtLeast    : integer ;
      Weight     : integer ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) is
      constant BIN_LENS : integer_vector :=
          BinLengths(
             Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
             Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20
           ) ;
      constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
      variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
      variable CrossBins    : CovBinType(BinIndex'range) ;
      variable calcAction, calcCount, calcAtLeast, calcWeight : integer ;
      variable calcBinVal   : RangeArrayType(BinIndex'range) ;
    begin
      CheckBinValLength( BIN_LENS'length, "AddCross") ;
      GrowBins(NUM_NEW_BINS) ;
      calcCount := 0 ;
      for MatrixIndex in 1 to NUM_NEW_BINS loop
        CrossBins := ConcatenateBins(BinIndex,
             Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
             Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20
           ) ;
        calcAction   := MergeState(CrossBins) ;
        calcBinVal   := MergeBinVal(CrossBins) ;
        calcAtLeast  := MergeAtLeast( calcAction, AtLeast, CrossBins) ;
        calcWeight   := MergeWeight ( calcAction, Weight,  CrossBins) ;
        InsertBin(calcBinVal, calcAction, calcCount, calcAtLeast, calcWeight, Name) ;
        IncBinIndex( BinIndex, BIN_LENS) ; -- increment right most one, then if overflow, increment next
      end loop ;
    end procedure AddCross ;


    ------------------------------------------------------------
    procedure AddCross(
    ------------------------------------------------------------
      Name       : string ;
      AtLeast    : integer ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) is
    begin
      AddCross(Name, AtLeast, 0,
           Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
           Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20
        ) ;
    end procedure AddCross ;


    ------------------------------------------------------------
    procedure AddCross(
    ------------------------------------------------------------
      Name       : string ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) is
    begin
      AddCross(Name, 0, 0,
           Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
           Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20
        ) ;
    end procedure AddCross ;


    ------------------------------------------------------------
    procedure AddCross(
    ------------------------------------------------------------
      AtLeast    : integer ;
      Weight     : integer ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) is
    begin
      AddCross("", AtLeast, Weight,
           Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
           Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20
        ) ;
    end procedure AddCross ;


    ------------------------------------------------------------
    procedure AddCross(
    ------------------------------------------------------------
      AtLeast    : integer ;
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) is
    begin
      AddCross("", AtLeast, 0,
           Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
           Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20
        ) ;
    end procedure AddCross ;


    ------------------------------------------------------------
    procedure AddCross(
    ------------------------------------------------------------
      Bin1, Bin2 : CovBinType ;
      Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11, Bin12, Bin13,
      Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20 : CovBinType := NULL_BIN
    ) is
    begin
      AddCross("", 0, 0,
           Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9, Bin10, Bin11,
           Bin12, Bin13, Bin14, Bin15, Bin16, Bin17, Bin18, Bin19, Bin20
        ) ;
    end procedure AddCross ;


    ------------------------------------------------------------
    procedure Deallocate is
    ------------------------------------------------------------
    begin
      for i in 1 to NumBins loop
        deallocate(CovBinPtr(i).BinVal) ;
        deallocate(CovBinPtr(i).Name) ;
      end loop ;
      deallocate(CovBinPtr) ;
      DeallocateName ;
      DeallocateMessage ;
      -- Restore internal variables to their default values
      NumBins := 0 ;
      OrderCount := 0 ;
      BinValLength := 1 ;
      IllegalMode   := ILLEGAL_ON ;
      WeightMode    := AT_LEAST ;
      WeightScale   := 1.0 ;
      ThresholdingEnable := FALSE ;
      CovThreshold  := 45.0 ;
      CovTarget     := 100.0 ;
      MergingEnable := FALSE ;
      CountMode     := COUNT_FIRST ;
      -- RvSeedInit    := FALSE ;
      WritePassFailVar   := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfoVar    := COV_OPT_INIT_PARM_DETECT ;
      WriteCountVar      := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegalVar := COV_OPT_INIT_PARM_DETECT ;
      WritePrefixVar.deallocate ; 
      PassNameVar.deallocate ; 
      FailNameVar.deallocate ; 
    end procedure deallocate ;


    ------------------------------------------------------------
    -- Local
    procedure ICoverIndex( Index : integer ; CovPoint : integer_vector ) is
    ------------------------------------------------------------
      variable buf : line ;
    begin
      -- Update Count, PercentCov
      CovBinPtr(Index).Count := CovBinPtr(Index).Count + CovBinPtr(Index).action ;
      CovBinPtr(Index).PercentCov := real(CovBinPtr(Index).Count)*100.0/maximum(real(CovBinPtr(Index).AtLeast), 1.0) ;
      -- OrderCount handling - Statistics
      OrderCount := OrderCount + 1 ;
      CovBinPtr(Index).OrderCount := OrderCount + CovBinPtr(Index).OrderCount ;
      if CovBinPtr(Index).action = COV_ILLEGAL and IllegalMode /= ILLEGAL_OFF then
        if CovPoint = NULL_INTV then
          alert(AlertLogIDVar, "CoverageModel " & GetName & " Value randomized (ICoverLast) is in an illegal bin.", IllegalModeLevel) ; 
        else
          write(buf, CovPoint) ; 
          alert(AlertLogIDVar, "CoverageModel " & GetName & " Value " & buf.all & " is in an illegal bin.", IllegalModeLevel) ; 
          deallocate(buf) ; 
        end if ; 
      end if ; 
    end procedure ICoverIndex ;


    ------------------------------------------------------------
    procedure ICoverLast is
    ------------------------------------------------------------
    begin
     ICoverIndex(LastIndex, NULL_INTV) ;
    end procedure ICoverLast ;


    ------------------------------------------------------------
    procedure ICover ( CovPoint : integer) is
    ------------------------------------------------------------
    begin
     ICover((1=> CovPoint)) ;
    end procedure ICover ;


    ------------------------------------------------------------
    procedure ICover( CovPoint : integer_vector) is
    ------------------------------------------------------------
      variable Found : boolean := FALSE ;
    begin
      if CountMode = COUNT_FIRST and inside(CovPoint, CovBinPtr(LastIndex).BinVal.all) then
        ICoverIndex(LastIndex, CovPoint) ;
        Found := TRUE ;
      end if;
      if not Found then
        CovLoop : for i in 1 to NumBins loop
          -- skip this CovBin if CovPoint is not in it
          next CovLoop when not inside(CovPoint, CovBinPtr(i).BinVal.all) ;
          -- Mark Covered
          ICoverIndex(i, CovPoint) ;
          exit CovLoop when CountMode = COUNT_FIRST ;   -- only find first one
        end loop CovLoop ;
      end if ;
     end procedure ICover ;


    ------------------------------------------------------------
    procedure SetCovZero is
    ------------------------------------------------------------
    begin
      for i in 1 to NumBins loop
        CovBinPtr(i).Count := 0 ;
        CovBinPtr(i).PercentCov := 0.0 ;
        CovBinPtr(i).OrderCount := 0 ;
      end loop ;
      OrderCount := 0 ;
    end procedure SetCovZero ;


    ------------------------------------------------------------
    impure function IsInitialized return boolean is
    ------------------------------------------------------------
    begin
      return NumBins > 0 ;
    end function IsInitialized ;


    ------------------------------------------------------------
    impure function GetNumBins return integer is
    ------------------------------------------------------------
    begin
      return NumBins ;
    end function GetNumBins ;


    ------------------------------------------------------------
    impure function GetMinIndex return integer is
    ------------------------------------------------------------
      variable MinCov : real := real'right ;  -- big number
      variable MinIndex : integer := NumBins ;
    begin
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).PercentCov < MinCov then
          MinCov := CovBinPtr(i).PercentCov ;
          MinIndex := i ;
        end if ;
      end loop CovLoop ;
      return MinIndex ;
    end function GetMinIndex ;


    ------------------------------------------------------------
    impure function GetMinCov return real is
    ------------------------------------------------------------
      variable MinCov : real := real'right ;  -- big number
    begin
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).PercentCov < MinCov then
          MinCov := CovBinPtr(i).PercentCov ;
        end if ;
      end loop CovLoop ;
      return MinCov ;
    end function GetMinCov ;


    ------------------------------------------------------------
    impure function GetMinCount return integer is
    ------------------------------------------------------------
      variable MinCount : integer := integer'right ;  -- big number
    begin
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count < MinCount then
          MinCount := CovBinPtr(i).Count ;
        end if ;
      end loop CovLoop ;
      return MinCount ;
    end function GetMinCount ;



    ------------------------------------------------------------
    impure function GetMaxIndex return integer is
    ------------------------------------------------------------
      variable MaxCov : real := 0.0 ;
      variable MaxIndex : integer := NumBins ;
    begin
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).PercentCov > MaxCov then
          MaxCov := CovBinPtr(i).PercentCov ;
          MaxIndex := i ;
        end if ;
      end loop CovLoop ;
      return MaxIndex ;
    end function GetMaxIndex ;


    ------------------------------------------------------------
    impure function GetMaxCov return real is
    ------------------------------------------------------------
      variable MaxCov : real := 0.0 ;
    begin
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).PercentCov > MaxCov then
          MaxCov := CovBinPtr(i).PercentCov ;
        end if ;
      end loop CovLoop ;
      return MaxCov ;
    end function GetMaxCov ;


    ------------------------------------------------------------
    impure function GetMaxCount return integer is
    ------------------------------------------------------------
      variable MaxCount : integer := 0 ;
    begin
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count > MaxCount then
          MaxCount := CovBinPtr(i).Count ;
        end if ;
      end loop CovLoop ;
      return MaxCount ;
    end function GetMaxCount ;


    ------------------------------------------------------------
    impure function CountCovHoles ( PercentCov : real ) return integer is
    ------------------------------------------------------------
      variable HoleCount : integer := 0 ;
    begin
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).PercentCov < PercentCov then
          HoleCount := HoleCount + 1 ;
        end if ;
      end loop CovLoop ;
      return HoleCount ;
    end function CountCovHoles ;


    ------------------------------------------------------------
    impure function CountCovHoles return integer is
    ------------------------------------------------------------
    begin
      return CountCovHoles(CovTarget) ;
    end function CountCovHoles ;


    ------------------------------------------------------------
    impure function IsCovered ( PercentCov : real ) return boolean is
    ------------------------------------------------------------
    begin
      -- AlertIf(NumBins < 1, OSVVM_ALERTLOG_ID, "IsCovered: Empty Coverage Model", failure) ;
      return CountCovHoles(PercentCov) = 0 ;
    end function IsCovered ;


    ------------------------------------------------------------
    impure function IsCovered return boolean is
    ------------------------------------------------------------
    begin
      -- AlertIf(NumBins < 1, OSVVM_ALERTLOG_ID, "IsCovered: Empty Coverage Model", failure) ;
      return CountCovHoles(CovTarget) = 0 ;
    end function IsCovered ;


    ------------------------------------------------------------
    impure function GetCov ( PercentCov : real ) return real is
    ------------------------------------------------------------
      variable TotalCovGoal, TotalCovCount, ScaledCovGoal : integer := 0 ;
    begin
      BinLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT then
          ScaledCovGoal := integer(ceil(PercentCov * real(CovBinPtr(i).AtLeast)/100.0)) ;
          TotalCovGoal := TotalCovGoal + ScaledCovGoal ;
          if CovBinPtr(i).Count <= ScaledCovGoal then
            TotalCovCount := TotalCovCount + CovBinPtr(i).Count ;
          else
            -- do not count the extra values that exceed their cov goal
            TotalCovCount := TotalCovCount + ScaledCovGoal ;
          end if ;
        end if ;
      end loop BinLoop ;
      return 100.0 * real(TotalCovCount) / real(TotalCovGoal) ;
    end function GetCov ;


    ------------------------------------------------------------
    impure function GetCov return real is
    ------------------------------------------------------------
      variable TotalCovGoal, TotalCovCount : integer := 0 ;
    begin
      return GetCov( CovTarget ) ;
    end function GetCov ;


    ------------------------------------------------------------
    impure function GetItemCount return integer is
    ------------------------------------------------------------
    begin
      return ItemCount ;
    end function GetItemCount ;


    ------------------------------------------------------------
    impure function GetTotalCovGoal ( PercentCov : real ) return integer is
    ------------------------------------------------------------
      variable TotalCovGoal, ScaledCovGoal : integer := 0 ;
    begin
      BinLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT then
          ScaledCovGoal := integer(ceil(PercentCov * real(CovBinPtr(i).AtLeast)/100.0)) ;
          TotalCovGoal := TotalCovGoal + ScaledCovGoal ;
        end if ;
      end loop BinLoop ;
      return TotalCovGoal ;
    end function GetTotalCovGoal ;


    ------------------------------------------------------------
    impure function GetTotalCovGoal return integer is
    ------------------------------------------------------------
    begin
      return GetTotalCovGoal(CovTarget) ;
    end function GetTotalCovGoal ;


    ------------------------------------------------------------
    impure function GetLastIndex return integer is
    ------------------------------------------------------------
    begin
      return LastIndex ;
    end function GetLastIndex ;


    ------------------------------------------------------------
    impure function GetHoleBinVal ( ReqHoleNum : integer ; PercentCov : real  ) return RangeArrayType is
    ------------------------------------------------------------
      variable HoleCount : integer := 0 ;
      variable buf : line ;
    begin
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).PercentCov < PercentCov then
          HoleCount := HoleCount + 1 ;
          if HoleCount = ReqHoleNum  then
           return CovBinPtr(i).BinVal.all ;
          end if ;
        end if ;
      end loop CovLoop ;
      Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.GetHoleBinVal did not find hole.  " &
                     "HoleCount = " & integer'image(HoleCount) &
                     "ReqHoleNum = " & integer'image(ReqHoleNum), ERROR
      ) ;
      return CovBinPtr(NumBins).BinVal.all ;

    end function GetHoleBinVal ;

    ------------------------------------------------------------
    impure function GetHoleBinVal ( PercentCov : real  ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return GetHoleBinVal(1, PercentCov) ;
    end function GetHoleBinVal ;


    ------------------------------------------------------------
    impure function GetHoleBinVal ( ReqHoleNum : integer := 1 ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return GetHoleBinVal(ReqHoleNum, CovTarget) ;
    end function GetHoleBinVal ;


    ------------------------------------------------------------
    impure function CalcWeight ( BinIndex : integer ; MaxCovPercent : real  ) return integer is
    --  pt local
    ------------------------------------------------------------
    begin
      case WeightMode is
        when AT_LEAST =>    -- AtLeast
          return CovBinPtr(BinIndex).AtLeast ;

        when WEIGHT =>       -- Weight
          return CovBinPtr(BinIndex).Weight ;

        when REMAIN =>       -- (Adjust * AtLeast) - Count
          return integer( Ceil( MaxCovPercent * real(CovBinPtr(BinIndex).AtLeast)/100.0)) -
                          CovBinPtr(BinIndex).Count ;

        when REMAIN_EXP =>       -- Weight * (REMAIN **WeightScale)
          -- Experimental may be removed
-- CAUTION:  for large numbers and/or WeightScale > 2.0, result can be > 2**31 (max integer value)
          -- both Weight and WeightScale default to 1
            return CovBinPtr(BinIndex).Weight *
                    integer( Ceil (
                      ( (MaxCovPercent * real(CovBinPtr(BinIndex).AtLeast)/100.0) -
                            real(CovBinPtr(BinIndex).Count) ) ** WeightScale ) );

        when REMAIN_SCALED =>   -- (WeightScale * Adjust * AtLeast) - Count
          -- Experimental may be removed
          -- Biases remainder toward AT_LEAST value.
          -- WeightScale must be > 1.0
          return integer( Ceil( WeightScale * MaxCovPercent * real(CovBinPtr(BinIndex).AtLeast)/100.0)) -
                          CovBinPtr(BinIndex).Count ;

        when REMAIN_WEIGHT =>     -- Weight * ((WeightScale * Adjust * AtLeast) - Count)
          -- Experimental may be removed
          -- WeightScale must be > 1.0
          return   CovBinPtr(BinIndex).Weight * (
                   integer( Ceil( WeightScale * MaxCovPercent * real(CovBinPtr(BinIndex).AtLeast)/100.0)) -
                            CovBinPtr(BinIndex).Count) ;

      end case ;
    end function CalcWeight ;


    ------------------------------------------------------------
    impure function RandHoleIndex ( CovTargetPercent : real ) return integer is
    --  pt local
    ------------------------------------------------------------
      variable WeightVec : integer_vector(0 to NumBins-1) ;  -- Prep for change to DistInt
      variable MaxCovPercent : real ;
      variable MinCovPercent : real ;
    begin
      ItemCount := ItemCount + 1 ;
      MinCovPercent := GetMinCov ;
      if ThresholdingEnable then
        MaxCovPercent := MinCovPercent + CovThreshold ;
        if MinCovPercent < CovTargetPercent then
          -- Clip at CovTargetPercent until reach CovTargetPercent
          MaxCovPercent := minimum(MaxCovPercent, CovTargetPercent);
        end if ;
      else
        if MinCovPercent < CovTargetPercent then
          MaxCovPercent := CovTargetPercent ;
        else
          -- Done, Enable all bins
          MaxCovPercent := GetMaxCov + 1.0 ;
          -- MaxCovPercent := real'right ;  -- weight scale issues
        end if ;
      end if ;
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).PercentCov < MaxCovPercent then
          -- Calculate Weight based on WeightMode
          --   Scale to current percentage goal:  MaxCov which can be < or > 100.0
          WeightVec(i-1) := CalcWeight(i, MaxCovPercent) ;
        else
          WeightVec(i-1) := 0 ;
        end if ;
      end loop CovLoop ;
      -- DistInt returns integer range 0 to Numbins-1
      -- Caution:  DistInt can fail when sum(WeightVec) > 2**31
      --           See notes in CalcWeight for REMAIN_EXP
      LastIndex := 1 + RV.DistInt( WeightVec )  ; -- return range 1 to NumBins
      return LastIndex ;
    end function RandHoleIndex ;


    ------------------------------------------------------------
    impure function GetBinVal ( BinIndex : integer ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return CovBinPtr( BinIndex ).BinVal.all ;
    end function GetBinVal ;


    ------------------------------------------------------------
    impure function GetLastBinVal return RangeArrayType is
    ------------------------------------------------------------
    begin
      return CovBinPtr( LastIndex ).BinVal.all ;
    end function GetLastBinVal ;


    ------------------------------------------------------------
    impure function RandCovBinVal ( PercentCov : real ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return CovBinPtr( RandHoleIndex(PercentCov) ).BinVal.all ;  -- GetBinVal
    end function RandCovBinVal ;


    ------------------------------------------------------------
    impure function RandCovBinVal  return RangeArrayType is
    ------------------------------------------------------------
    begin
      -- use global coverage target
      return CovBinPtr( RandHoleIndex( CovTarget ) ).BinVal.all ;  -- GetBinVal
    end function RandCovBinVal ;


    ------------------------------------------------------------
    impure function GetMinBinVal  return RangeArrayType is
    ------------------------------------------------------------
    begin
      -- use global coverage target
      return GetBinVal( GetMinIndex ) ;
    end function GetMinBinVal ;


    ------------------------------------------------------------
    impure function GetMaxBinVal  return RangeArrayType is
    ------------------------------------------------------------
    begin
      -- use global coverage target
      return GetBinVal( GetMaxIndex ) ;
    end function GetMaxBinVal ;


    ------------------------------------------------------------
--    impure function RandCovPoint( BinVal : RangeArrayType ) return integer_vector is
    impure function ToRandPoint( BinVal : RangeArrayType ) return integer_vector is
    --  pt local
    ------------------------------------------------------------
      variable CovPoint : integer_vector(BinVal'range) ;
      variable normCovPoint : integer_vector(1 to BinVal'length) ;
    begin
      for i in BinVal'range loop
        CovPoint(i) := RV.RandInt(BinVal(i).min, BinVal(i).max) ;
      end loop ;
      normCovPoint := CovPoint ;
      return normCovPoint ;
    end function ToRandPoint ;


    ------------------------------------------------------------
    impure function ToRandPoint( BinVal : RangeArrayType ) return integer is
    --  pt local
    ------------------------------------------------------------
    begin
      return RV.RandInt(BinVal(BinVal'left).min, BinVal(BinVal'left).max) ;
    end function ToRandPoint ;


    ------------------------------------------------------------
    impure function RandCovPoint return integer is
    ------------------------------------------------------------
    begin
      return ToRandPoint(RandCovBinVal(CovTarget)) ;
    end function RandCovPoint ;


    ------------------------------------------------------------
    impure function RandCovPoint ( PercentCov : real ) return integer is
    ------------------------------------------------------------
    begin
      return ToRandPoint(RandCovBinVal(PercentCov)) ;
    end function RandCovPoint ;


    ------------------------------------------------------------
    impure function RandCovPoint return integer_vector is
    ------------------------------------------------------------
    begin
      return ToRandPoint(RandCovBinVal(CovTarget)) ;
    end function RandCovPoint ;


    ------------------------------------------------------------
    impure function RandCovPoint ( PercentCov : real ) return integer_vector is
    ------------------------------------------------------------
    begin
      return ToRandPoint(RandCovBinVal(PercentCov)) ;
    end function RandCovPoint ;


    ------------------------------------------------------------
    impure function GetPoint ( BinIndex : integer ) return integer is
    ------------------------------------------------------------
    begin
      return ToRandPoint(GetBinVal(BinIndex)) ;
    end function GetPoint ;


    ------------------------------------------------------------
    impure function GetPoint ( BinIndex : integer ) return integer_vector is
    ------------------------------------------------------------
    begin
      return ToRandPoint(GetBinVal(BinIndex)) ;
    end function GetPoint ;


    ------------------------------------------------------------
    impure function GetMinPoint return integer is
    ------------------------------------------------------------
    begin
      return ToRandPoint(GetBinVal( GetMinIndex )) ;
    end function GetMinPoint ;


    ------------------------------------------------------------
    impure function GetMinPoint return integer_vector is
    ------------------------------------------------------------
    begin
      return ToRandPoint(GetBinVal( GetMinIndex )) ;
    end function GetMinPoint ;


    ------------------------------------------------------------
    impure function GetMaxPoint return integer is
    ------------------------------------------------------------
    begin
      return ToRandPoint(GetBinVal( GetMaxIndex )) ;
    end function GetMaxPoint ;


    ------------------------------------------------------------
    impure function GetMaxPoint return integer_vector is
    ------------------------------------------------------------
    begin
      return ToRandPoint(GetBinVal( GetMaxIndex )) ;
    end function GetMaxPoint ;


    -- ------------------------------------------------------------
    -- Intended as a stand in until we get a more general GetBin
    impure function GetBinInfo ( BinIndex : integer ) return CovBinBaseType is
    -- ------------------------------------------------------------
      variable result : CovBinBaseType ;
    begin
      result.BinVal  := ALL_RANGE;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBinInfo ;


    -- ------------------------------------------------------------
    -- Intended as a stand in until we get a more general GetBin
    impure function GetBinValLength return integer is
    -- ------------------------------------------------------------
    begin
      return BinValLength ;
    end function GetBinValLength ;


-- Eventually the multiple GetBin functions will be replaced by a
-- a single GetBin that returns CovBinBaseType with BinVal as an
-- unconstrained element
    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovBinBaseType is
    -- ------------------------------------------------------------
      variable result : CovBinBaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;


    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovMatrix2BaseType is
    -- ------------------------------------------------------------
      variable result : CovMatrix2BaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;


    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovMatrix3BaseType is
    -- ------------------------------------------------------------
      variable result : CovMatrix3BaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;


    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovMatrix4BaseType is
    -- ------------------------------------------------------------
      variable result : CovMatrix4BaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;


    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovMatrix5BaseType is
    -- ------------------------------------------------------------
      variable result : CovMatrix5BaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;


    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovMatrix6BaseType is
    -- ------------------------------------------------------------
      variable result : CovMatrix6BaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;


    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovMatrix7BaseType is
    -- ------------------------------------------------------------
      variable result : CovMatrix7BaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;


    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovMatrix8BaseType is
    -- ------------------------------------------------------------
      variable result : CovMatrix8BaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;


    -- ------------------------------------------------------------
    impure function GetBin ( BinIndex : integer ) return CovMatrix9BaseType is
    -- ------------------------------------------------------------
      variable result : CovMatrix9BaseType ;
    begin
      result.BinVal  := CovBinPtr(BinIndex).BinVal.all;
      result.Action  := CovBinPtr(BinIndex).Action;
      result.Count   := CovBinPtr(BinIndex).Count;
      result.AtLeast := CovBinPtr(BinIndex).AtLeast;
      result.Weight  := CovBinPtr(BinIndex).Weight;
      return result ;
    end function GetBin ;

    ------------------------------------------------------------
    --  pt local for now -- file formal parameter not allowed with method
    procedure WriteBin (
      file f : text ;
      WritePassFail   : CovOptionsType ;
      WriteBinInfo    : CovOptionsType ;
      WriteCount      : CovOptionsType ;
      WriteAnyIllegal : CovOptionsType ;
      WritePrefix     : string ;
      PassName        : string ;
      FailName        : string
    ) is
    ------------------------------------------------------------
      variable buf : line ;
    begin
      if NumBins < 1 then
        if WriteBinFileInit or UsingLocalFile then
          swrite(buf, WritePrefix & " " & FailName & " ") ;
          swrite(buf, GetName) ;
          swrite(buf, "WriteBin: Coverage model is empty.  Nothing to print.") ;
          writeline(f, buf) ;
        end if ; 
        Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.WriteBin: Coverage model is empty.  Nothing to print.", FAILURE) ;
        return ;
      end if ;
      -- Models with Bins
      WriteBinName(f, "WriteBin: ", WritePrefix) ;
      for i in 1 to NumBins loop      -- CovBinPtr.all'range
        if CovBinPtr(i).action = COV_COUNT or
           (CovBinPtr(i).action = COV_ILLEGAL and IsEnabled(WriteAnyIllegal)) or
           CovBinPtr(i).count < 0  -- Illegal bin with errors
        then
          -- WriteBin Info
          swrite(buf, WritePrefix) ;
          if CovBinPtr(i).Name.all /= "" then
            swrite(buf, CovBinPtr(i).Name.all & "  ") ;
          end if ;
          if IsEnabled(WritePassFail) then
            -- For illegal bins, AtLeast = 0 and count is negative.
            if CovBinPtr(i).count >= CovBinPtr(i).AtLeast then
              swrite(buf, PassName & ' ') ;
            else
              swrite(buf, FailName & ' ') ;
            end if ;
          end if ;
          if IsEnabled(WriteBinInfo) then
            if CovBinPtr(i).action = COV_COUNT then
              swrite(buf, "Bin:") ;
            else
              swrite(buf, "Illegal Bin:") ;
            end if;
            write(buf, CovBinPtr(i).BinVal.all) ;
          end if ;
          if IsEnabled(WriteCount) then
            write(buf, "  Count = " & integer'image(abs(CovBinPtr(i).count))) ;
            write(buf, "  AtLeast = " & integer'image(CovBinPtr(i).AtLeast)) ;
            if WeightMode = WEIGHT or WeightMode = REMAIN_WEIGHT then
              -- Print Weight only when it is used
              write(buf, "  Weight = " & integer'image(CovBinPtr(i).Weight)) ;
            end if ;
          end if ;
          writeline(f, buf) ;
        end if ;
      end loop ;
      swrite(buf, "") ;
      writeline(f, buf) ;
    end procedure WriteBin ;

    ------------------------------------------------------------
    procedure WriteBin (
    ------------------------------------------------------------
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) is
      constant rWritePassFail   : CovOptionsType := ResolveCovWritePassFail(WritePassFail,     WritePassFailVar) ;
      constant rWriteBinInfo    : CovOptionsType := ResolveCovWriteBinInfo(WriteBinInfo,       WriteBinInfoVar  ) ;
      constant rWriteCount      : CovOptionsType := ResolveCovWriteCount(WriteCount,           WriteCountVar    ) ;
      constant rWriteAnyIllegal : CovOptionsType := ResolveCovWriteAnyIllegal(WriteAnyIllegal, WriteAnyIllegalVar) ;
      constant rWritePrefix     : string      := ResolveOsvvmWritePrefix(WritePrefix,       WritePrefixVar.GetOpt) ;
      constant rPassName        : string      := ResolveOsvvmPassName(PassName,             PassNameVar.GetOpt  ) ;
      constant rFailName        : string      := ResolveOsvvmFailName(FailName,             FailNameVar.GetOpt  ) ;
    begin
      if WriteBinFileInit then  -- WriteBin File defined Coverage Model (deprecated)
        WriteBin (
          f               => WriteBinFile,
          WritePassFail   => rWritePassFail,
          WriteBinInfo    => rWriteBinInfo,
          WriteCount      => rWriteCount,
          WriteAnyIllegal => rWriteAnyIllegal,
          WritePrefix     => rWritePrefix,
          PassName        => rPassName,
          FailName        => rFailName
        ) ;
      elsif IsTranscriptEnabled then 
        WriteBin (
          f               => TranscriptFile,
          WritePassFail   => rWritePassFail,
          WriteBinInfo    => rWriteBinInfo,
          WriteCount      => rWriteCount,
          WriteAnyIllegal => rWriteAnyIllegal,
          WritePrefix     => rWritePrefix,
          PassName        => rPassName,
          FailName        => rFailName
        ) ;
      else
        WriteBin (
          f               => OUTPUT,
          WritePassFail   => rWritePassFail,
          WriteBinInfo    => rWriteBinInfo,
          WriteCount      => rWriteCount,
          WriteAnyIllegal => rWriteAnyIllegal,
          WritePrefix     => rWritePrefix,
          PassName        => rPassName,
          FailName        => rFailName
        ) ;
      end if ;
      
    end procedure WriteBin ;
    
    
    ------------------------------------------------------------
    procedure WriteBin (  -- With LogLevel
    ------------------------------------------------------------
      LogLevel        : LogType ;
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) is
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        WriteBin (
          WritePassFail   => WritePassFail,
          WriteBinInfo    => WriteBinInfo,
          WriteCount      => WriteCount,
          WriteAnyIllegal => WriteAnyIllegal,
          WritePrefix     => WritePrefix,
          PassName        => PassName,
          FailName        => FailName
        ) ;
      end if ; 
    end procedure WriteBin ;  -- With LogLevel


    ------------------------------------------------------------
    procedure WriteBin (
    ------------------------------------------------------------
      FileName        : string;
      OpenKind        : File_Open_Kind := APPEND_MODE ;
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) is
      file LocalWriteBinFile : text open OpenKind is FileName ;
      constant rWritePassFail   : CovOptionsType := ResolveCovWritePassFail(WritePassFail,     WritePassFailVar) ;
      constant rWriteBinInfo    : CovOptionsType := ResolveCovWriteBinInfo(WriteBinInfo,       WriteBinInfoVar  ) ;
      constant rWriteCount      : CovOptionsType := ResolveCovWriteCount(WriteCount,           WriteCountVar    ) ;
      constant rWriteAnyIllegal : CovOptionsType := ResolveCovWriteAnyIllegal(WriteAnyIllegal, WriteAnyIllegalVar) ;
      constant rWritePrefix     : string      := ResolveOsvvmWritePrefix(WritePrefix,       WritePrefixVar.GetOpt) ;
      constant rPassName        : string      := ResolveOsvvmPassName(PassName,             PassNameVar.GetOpt  ) ;
      constant rFailName        : string      := ResolveOsvvmFailName(FailName,             FailNameVar.GetOpt  ) ;
    begin
      UsingLocalFile := TRUE ; 
      WriteBin (
        f               => LocalWriteBinFile,
        WritePassFail   => rWritePassFail,
        WriteBinInfo    => rWriteBinInfo,
        WriteCount      => rWriteCount,
        WriteAnyIllegal => rWriteAnyIllegal,
        WritePrefix     => rWritePrefix,
        PassName        => rPassName,
        FailName        => rFailName
      );
      UsingLocalFile := FALSE ; 
    end procedure WriteBin ;


    ------------------------------------------------------------
    procedure WriteBin (  -- With LogLevel
    ------------------------------------------------------------
      LogLevel        : LogType ;
      FileName        : string;
      OpenKind        : File_Open_Kind := APPEND_MODE ;
      WritePassFail   : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteBinInfo    : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteCount      : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WriteAnyIllegal : CovOptionsType := COV_OPT_INIT_PARM_DETECT ;
      WritePrefix     : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName        : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName        : string := OSVVM_STRING_INIT_PARM_DETECT
    ) is
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        UsingLocalFile := TRUE ; 
        WriteBin (
          FileName        => FileName,
          OpenKind        => OpenKind,
          WritePassFail   => WritePassFail,
          WriteBinInfo    => WriteBinInfo,
          WriteCount      => WriteCount,
          WriteAnyIllegal => WriteAnyIllegal,
          WritePrefix     => WritePrefix,
          PassName        => PassName,
          FailName        => FailName
        ) ;
        UsingLocalFile := FALSE ; 
      end if ; 
    end procedure WriteBin ;  -- With LogLevel


    ------------------------------------------------------------
    -- Development only
    --  pt local for now -- file formal parameter not allowed with method
    procedure DumpBin ( file f : text ) is
    ------------------------------------------------------------
      variable buf : line ;
    begin
      WriteBinName(f, "DumpBin: ") ;
      -- if NumBins < 1 then
      --   Write(f, "%%FATAL, Coverage Model is empty.  Nothing to print." & LF ) ;
      -- end if ;
      for i in 1 to NumBins loop      -- CovBinPtr.all'range
        swrite(buf, "%% ") ;
        if CovBinPtr(i).Name.all /= "" then
          swrite(buf, CovBinPtr(i).Name.all & "  ") ;
        end if ;
        swrite(buf, "Bin:") ;
        write(buf, CovBinPtr(i).BinVal.all) ;
        case CovBinPtr(i).action is
          when COV_COUNT   =>   swrite(buf, "    Count = ") ;
          when COV_IGNORE  =>   swrite(buf, "   Ignore = ") ;
          when COV_ILLEGAL =>   swrite(buf, "  Illegal = ") ;
          when others      =>   swrite(buf, "  BOGUS BOGUS BOGUS = ") ;
        end case ;
        write(buf, CovBinPtr(i).count) ;
        -- write(f, "   Count = " & integer'image(CovBinPtr(i).count)) ;
        write(buf, "   AtLeast = " & integer'image(CovBinPtr(i).AtLeast)) ;
        write(buf, "   Weight = " & integer'image(CovBinPtr(i).Weight)) ;
        write(buf, "   OrderCount = " & integer'image(CovBinPtr(i).OrderCount)) ;
        if CovBinPtr(i).count > 0 then
          write(buf, "   Normalized OrderCount = " & integer'image(CovBinPtr(i).OrderCount/CovBinPtr(i).count)) ;
        end if ;
        writeline(f, buf) ;
      end loop ;
      swrite(buf, "") ;
      writeline(f,buf) ;
    end procedure DumpBin ;


    ------------------------------------------------------------
    procedure DumpBin (LogLevel : LogType := DEBUG) is
    ------------------------------------------------------------
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        if WriteBinFileInit then
          DumpBin(WriteBinFile) ;
        elsif IsTranscriptEnabled then 
          DumpBin(TranscriptFile) ;
        else
          DumpBin(OUTPUT) ;
        end if ;
      end if ;
    end procedure DumpBin ;


    ------------------------------------------------------------
    --  pt local
    procedure WriteCovHoles ( file f : text;  PercentCov : real := 100.0 ) is
    ------------------------------------------------------------
      variable buf : line ;
    begin
      if NumBins < 1 then
        if WriteBinFileInit or UsingLocalFile then
          -- Duplicate Alert in specified file
          swrite(buf, "%% FAILURE  CoverageModel") ;
          swrite(buf, GetName) ;
          swrite(buf, "CoveragePkg.WriteCovHoles, FATAL, coverage model empty.  Nothing to print.") ;
          writeline(f, buf) ;
        end if ; 
        Alert(AlertLogIDVar, "CoverageModel " & GetName & " coverage model empty.  Nothing to print. In CoveragePkg.WriteCovHoles", FAILURE) ;
        return ;
      end if ;
      -- Models with Bins
      WriteBinName(f, "WriteCovHoles: ") ;
      CovLoop : for i in 1 to NumBins loop
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).PercentCov < PercentCov then
          swrite(buf, "%% ") ;
          if CovBinPtr(i).Name.all /= "" then
            swrite(buf, CovBinPtr(i).Name.all & "  ") ;
          end if ;
          swrite(buf, "Bin:") ;
          write(buf, CovBinPtr(i).BinVal.all) ;
          write(buf, "  Count = " & integer'image(CovBinPtr(i).Count)) ;
          write(buf, "  AtLeast = " & integer'image(CovBinPtr(i).AtLeast)) ;
          if WeightMode = WEIGHT or WeightMode = REMAIN_WEIGHT then
            -- Print Weight only when it is used
            write(buf, "  Weight = " & integer'image(CovBinPtr(i).Weight)) ;
          end if ;
          writeline(f, buf) ;
        end if ;
      end loop CovLoop ;
      swrite(buf, "") ;
      writeline(f, buf) ;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    procedure WriteCovHoles ( LogLevel : LogType := ALWAYS ) is
    ------------------------------------------------------------
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        if WriteBinFileInit then
          WriteCovHoles(WriteBinFile, CovTarget) ;
        elsif IsTranscriptEnabled then 
          WriteCovHoles(TranscriptFile, CovTarget) ;
        else
          WriteCovHoles(OUTPUT, CovTarget) ;
        end if;
      end if;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    procedure WriteCovHoles ( PercentCov : real ) is
    ------------------------------------------------------------
    begin
      if WriteBinFileInit then
        WriteCovHoles(WriteBinFile, PercentCov) ;
      elsif IsTranscriptEnabled then 
        WriteCovHoles(TranscriptFile, PercentCov) ;
      else
        WriteCovHoles(OUTPUT, PercentCov) ;
      end if;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    procedure WriteCovHoles ( LogLevel : LogType ; PercentCov : real ) is
    ------------------------------------------------------------
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        WriteCovHoles(PercentCov) ;
      end if;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    procedure WriteCovHoles ( FileName : string;  OpenKind : File_Open_Kind := APPEND_MODE ) is
    ------------------------------------------------------------
      file CovHoleFile : text open OpenKind is FileName ;
    begin
      UsingLocalFile := TRUE ; 
      WriteCovHoles(CovHoleFile, CovTarget) ;
      UsingLocalFile := FALSE ; 
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    procedure WriteCovHoles ( LogLevel : LogType ; FileName : string;  OpenKind : File_Open_Kind := APPEND_MODE ) is
    ------------------------------------------------------------
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        WriteCovHoles(FileName, OpenKind) ;
      end if;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    procedure WriteCovHoles ( FileName : string;  PercentCov : real ; OpenKind : File_Open_Kind := APPEND_MODE ) is
    ------------------------------------------------------------
      file CovHoleFile : text open OpenKind is FileName ;
    begin
        UsingLocalFile := TRUE ; 
        WriteCovHoles(CovHoleFile, PercentCov) ;
        UsingLocalFile := FALSE ; 
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    procedure WriteCovHoles ( LogLevel : LogType ; FileName : string;  PercentCov : real ; OpenKind : File_Open_Kind := APPEND_MODE ) is
    ------------------------------------------------------------
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        WriteCovHoles(FileName, PercentCov, OpenKind) ;
      end if;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    --  pt local
    impure function FindExactBin (
    -- find an exact match to a bin wrt BinVal, Action, AtLeast, Weight, and Name
    ------------------------------------------------------------
      Merge   : boolean ;
	    BinVal  : RangeArrayType ;
      Action  : integer ;
      AtLeast : integer ;
      Weight  : integer ;
      Name    : string
    ) return integer is
    begin
      if Merge then
        for i in 1 to NumBins loop
          if (BinVal = CovBinPtr(i).BinVal.all) and (Action = CovBinPtr(i).Action) and
             (AtLeast = CovBinPtr(i).AtLeast) and (Weight = CovBinPtr(i).Weight) and
             (Name = CovBinPtr(i).Name.all) then
            return i ;
          end if;
        end loop ;
      end if ;
      return 0 ;
    end function FindExactBin ;


    ------------------------------------------------------------
    --  pt local
    procedure read (
    ------------------------------------------------------------
      buf         : inout line ;
      NamePtr     : inout line ;
      NameLength  : in integer ;
      ReadValid   : out boolean
    ) is
      variable Name : string(1 to NameLength) ;
    begin
      if NameLength > 0 then
        read(buf, Name, ReadValid) ;
        NamePtr := new string'(Name) ;
      else
        ReadValid := TRUE ;
        NamePtr := new string'("") ;
      end if ;
    end procedure read ;


    ------------------------------------------------------------
    --  pt local
    procedure ReadCovVars (file CovDbFile : text; Good : out boolean ) is
    ------------------------------------------------------------
      variable buf              : line ;
      variable Empty            : boolean ;
      variable ReadValid        : boolean ;
      variable GoodLoop1        : boolean ;

      variable iSeed            : RandomSeedType ;
      variable iIllegalMode     : integer ;
      variable iWeightMode      : integer ;
      variable iWeightScale     : real ;
      variable iCovThreshold    : real ;
      variable iCountMode       : integer ;
      variable iNumberOfMessages   : integer ;
      variable iThresholdingEnable    : boolean ;
      variable iCovTarget       : real ;
      variable iMergingEnable   : boolean ;

    begin
      -- ReadLoop0 : while not EndFile(CovDbFile) loop
      ReadLoop0 : loop   -- allows emulation of "return when"
        -- ReadLine to Get Coverage Model Name, skip blank and comment lines, fails when file empty
        exit when AlertIf(EndFile(CovDbFile), AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: No Coverage Data to read", FAILURE) ; 
        ReadLine(CovDbFile, buf) ;
        EmptyOrCommentLine(buf, Empty) ;
        next when Empty ;

        if buf.all /= "Coverage_Model_Not_Named" then
          SetName(buf.all) ;
        end if ;

        exit ReadLoop0 ;
      end loop ReadLoop0 ;


      -- ReadLoop1 : while not EndFile(CovDbFile) loop
      ReadLoop1 : loop
        -- ReadLine to Get Variables, skip blank and comment lines, fails when file empty
        exit when AlertIf(EndFile(CovDbFile), AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Coverage DB File Incomplete", FAILURE) ; 
        ReadLine(CovDbFile, buf) ;
        EmptyOrCommentLine(buf, Empty) ;
        next when Empty ;

        read(buf, iSeed, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading Seed", FAILURE) ;
        RV.SetSeed( iSeed ) ;
        RvSeedInit := TRUE ;

        read(buf, iCovThreshold, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading CovThreshold", FAILURE) ;
        CovThreshold := iCovThreshold ;

        read(buf, iIllegalMode, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading IllegalMode", FAILURE) ;
        SetIllegalMode(IllegalModeType'val( iIllegalMode )) ;

        read(buf, iWeightMode, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading WeightMode", FAILURE) ;
        WeightMode := WeightModeType'val( iWeightMode ) ;

        read(buf, iWeightScale, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading WeightScale", FAILURE) ;
        WeightScale := iWeightScale  ;

        read(buf, iCountMode, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading CountMode", FAILURE) ;
        CountMode := CountModeType'val( iCountMode ) ;

        read(buf, iThresholdingEnable, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading CountMode", FAILURE) ;
        ThresholdingEnable := iThresholdingEnable ;

        read(buf, iCovTarget, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading CountMode", FAILURE) ;
        CovTarget := iCovTarget ;

        read(buf, iMergingEnable, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading CountMode", FAILURE) ;
        MergingEnable := iMergingEnable ;

        exit ReadLoop1 ;
      end loop ReadLoop1 ;

      GoodLoop1 := ReadValid ;

      -- ReadLoop2 : while not EndFile(CovDbFile) loop
      ReadLoop2 : while ReadValid loop
        -- ReadLine to Coverage Model Header WriteBin Message, skip blank and comment lines, fails when file empty
        exit when AlertIf(EndFile(CovDbFile), AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Coverage DB File Incomplete", FAILURE) ; 
        ReadLine(CovDbFile, buf) ;
        EmptyOrCommentLine(buf, Empty) ;
        next when Empty ;

        read(buf, iNumberOfMessages, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading NumberOfMessages", FAILURE) ;

        for i in 1 to iNumberOfMessages loop
          exit when AlertIf(EndFile(CovDbFile), AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: End of File while reading Messages", FAILURE) ;
          ReadLine(CovDbFile, buf) ;
          SetMessage(buf.all) ;
        end loop ;

        exit ReadLoop2 ;
      end loop ReadLoop2 ;

      Good := ReadValid and  GoodLoop1 ;
    end procedure ReadCovVars ;


    ------------------------------------------------------------
    --  pt local
    procedure ReadCovDbInfo (
    ------------------------------------------------------------
      File     CovDbFile     :       text ;
      variable NumRangeItems : out integer ;
      variable NumLines      : out integer ;
      variable Good          : out boolean
    ) is
      variable buf           : line ;
      variable ReadValid     : boolean ;
      variable Empty         : boolean ;
    begin

      ReadLoop : loop
        -- ReadLine to RangeItems NumLines, skip blank and comment lines, fails when file empty
        exit when AlertIf(EndFile(CovDbFile), AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Coverage DB File Incomplete", FAILURE) ; 
        ReadLine(CovDbFile, buf) ;
        EmptyOrCommentLine(buf, Empty) ;
        next when Empty ;

        read(buf, NumRangeItems, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading NumRangeItems", FAILURE) ;
        read(buf, NumLines, ReadValid) ;
        exit when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading NumLines", FAILURE) ; 
        exit ;
      end loop ReadLoop ;
      Good := ReadValid ;
    end procedure ReadCovDbInfo ;


    ------------------------------------------------------------
    --  pt local
    procedure ReadCovDbDataBase (
    ------------------------------------------------------------
      File     CovDbFile     :     text ;
      constant NumRangeItems : in  integer ;
      constant NumLines      : in  integer ;
      constant Merge         : in  boolean ;
      variable Good          : out boolean
    )  is
      variable buf         : line ;
      variable Empty       : boolean ;
      variable ReadValid   : boolean ;
      -- Format:  Action Count min1 max1 min2 max2 ....
      variable Action      : integer ;
      variable Count       : integer ;
      variable BinVal      : RangeArrayType(1 to NumRangeItems) ;
      variable index       : integer ;
      variable AtLeast     : integer ;
      variable Weight      : integer ;
      variable PercentCov  : real ;
      variable NameLength  : integer ;
      variable SkipBlank   : character ;
      variable NamePtr     : line ;
    begin
      GrowBins(NumLines) ;
      ReadLoop : for i in 1 to NumLines loop
      
        GetValidLineLoop: loop 
          exit ReadLoop when AlertIf(EndFile(CovDbFile), AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg..ReadCovDb:  Did not read specified number of lines", FAILURE) ;
          ReadLine(CovDbFile, buf) ;
          EmptyOrCommentLine(buf, Empty) ;
          next GetValidLineLoop when Empty ;  -- replace with EmptyLine(buf)
          exit GetValidLineLoop ; 
        end loop ; 

        read(buf, Action, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading Action", FAILURE) ;
        read(buf, Count, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading Count", FAILURE) ;
        read(buf, AtLeast, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading AtLeast", FAILURE) ;
        read(buf, Weight, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading Weight", FAILURE) ;
        read(buf, PercentCov, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading PercentCov", FAILURE) ;
        read(buf, BinVal, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading BinVal", FAILURE) ;
        read(buf, NameLength, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading Bin Name Length", FAILURE) ;
        read(buf, SkipBlank, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading Bin Name Length", FAILURE) ;
        read(buf, NamePtr, NameLength, ReadValid) ;
        exit ReadLoop when AlertIfNot(ReadValid, AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.ReadCovDb: Failed while reading Bin Name", FAILURE) ;
        index := FindExactBin(Merge, BinVal, Action, AtLeast, Weight, NamePtr.all) ;
        if index > 0 then
          -- Bin is an exact match so only merge the count values
          CovBinPtr(index).Count := CovBinPtr(index).Count + Count ;
          CovBinPtr(index).PercentCov := real(CovBinPtr(index).Count)*100.0/maximum(real(CovBinPtr(index).AtLeast), 1.0) ;
        else
          InsertNewBin(BinVal, Action, Count, AtLeast, Weight, NamePtr.all, PercentCov) ;
        end if ;
        deallocate(NamePtr) ;
      end loop ReadLoop ;
      Good := ReadValid ;
    end ReadCovDbDataBase ;


    ------------------------------------------------------------
    -- pt local
    procedure ReadCovDb (File CovDbFile : text; Merge : boolean := FALSE) is
    ------------------------------------------------------------
      -- Format:  Action Count min1 max1 min2 max2
      -- file CovDbFile         : text open READ_MODE is FileName ;
      variable NumRangeItems : integer ;
      variable NumLines      : integer ;
      variable ReadValid    : boolean ;
    begin
      if not Merge then
        Deallocate ;  -- remove any old bins
      end if ;

      ReadLoop : loop
        -- Read coverage private variables to the file
        ReadCovVars(CovDbFile, ReadValid) ;
        exit when not ReadValid ;

        -- Get Coverage dimensions and number of items in file.
        ReadCovDbInfo(CovDbFile, NumRangeItems, NumLines, ReadValid) ;
        exit when not ReadValid ;

        -- Read the file
        ReadCovDbDataBase(CovDbFile, NumRangeItems, NumLines, Merge, ReadValid) ;
        exit ;
      end loop ReadLoop ;
    end ReadCovDb ;


    ------------------------------------------------------------
    procedure ReadCovDb (FileName : string; Merge : boolean := FALSE) is
    ------------------------------------------------------------
      -- Format:  Action Count min1 max1 min2 max2
      file CovDbFile         : text open READ_MODE is FileName ;
    begin
      ReadCovDb(CovDbFile, Merge) ;
    end procedure ReadCovDb ;


    ------------------------------------------------------------
    --  pt local
    procedure WriteCovDbVars (file CovDbFile : text ) is
    ------------------------------------------------------------
      variable buf       : line ;
    begin
      -- write coverage private variables to the file
      if CovNameVar.IsSet then
        write(buf, GetName) ;
      else
        swrite(buf, "Coverage_Model_Not_Named") ;
      end if ;
      writeline(CovDbFile, buf) ;

      write(buf, RV.GetSeed ) ;
      write(buf, ' ') ;
      write(buf, CovThreshold) ;
      write(buf, ' ') ;
      write(buf, IllegalModeType'pos(IllegalMode)) ;
      write(buf, ' ') ;
      write(buf, WeightModeType'pos(WeightMode)) ;
      write(buf, ' ') ;
      write(buf, WeightScale) ;
      write(buf, ' ') ;
      write(buf, CountModeType'pos(CountMode)) ;
      write(buf, ' ') ;
      write(buf, ThresholdingEnable) ; -- boolean
      write(buf, ' ') ;
      write(buf, CovTarget) ; -- Real
      write(buf, ' ') ;
      write(buf, MergingEnable) ; -- boolean
      write(buf, ' ') ;
      writeline(CovDbFile, buf) ;
      write(buf, CovMessageVar.GetCount ) ;
      writeline(CovDbFile, buf) ;
      WriteBinName(CovDbFile, "", "") ;
    end procedure WriteCovDbVars ;


    ------------------------------------------------------------
    --  pt local
    procedure WriteCovDb (file CovDbFile : text ) is
    ------------------------------------------------------------
      -- Format:  Action Count min1 max1 min2 max2
      variable buf       : line ;
    begin
      -- write Cover variables to the file
      WriteCovDbVars( CovDbFile ) ;

      -- write NumRangeItems, NumLines
      write(buf, CovBinPtr(1).BinVal'length) ;
      write(buf, ' ') ;
      write(buf, NumBins) ;
      write(buf, ' ') ;
      writeline(CovDbFile, buf) ;
      -- write coverage to a file
      writeloop : for LineCount in 1 to NumBins loop
        write(buf, CovBinPtr(LineCount).Action) ;
        write(buf, ' ') ;
        write(buf, CovBinPtr(LineCount).Count) ;
        write(buf, ' ') ;
        write(buf, CovBinPtr(LineCount).AtLeast) ;
        write(buf, ' ') ;
        write(buf, CovBinPtr(LineCount).Weight) ;
        write(buf, ' ') ;
        write(buf, CovBinPtr(LineCount).PercentCov) ;
        write(buf, ' ') ;
        WriteBinVal(buf, CovBinPtr(LineCount).BinVal.all) ;
        write(buf, ' ') ;
        write(buf, CovBinPtr(LineCount).Name'length) ;
        write(buf, ' ') ;
        write(buf, CovBinPtr(LineCount).Name.all) ;
        writeline(CovDbFile, buf) ;
      end loop WriteLoop ;
    end procedure WriteCovDb ;


    ------------------------------------------------------------
    procedure WriteCovDb (FileName : string; OpenKind : File_Open_Kind := WRITE_MODE ) is
    ------------------------------------------------------------
      -- Format:  Action Count min1 max1 min2 max2
      file CovDbFile : text open OpenKind is FileName ;
    begin
      if NumBins >= 1 then 
        WriteCovDb(CovDbFile) ;
      else
        Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.WriteCovDb when no bins defined ", FAILURE) ; 
      end if ; 
    end procedure WriteCovDb ;


--     ------------------------------------------------------------
--     procedure WriteCovDb is
--     ------------------------------------------------------------
--     begin
--       if WriteCovDbFileInit then
--         WriteCovDb(WriteCovDbFile) ;
--       else
--         report "CoveragePkg: WriteCovDb file not specified" severity failure ;
--       end if ;
--     end procedure WriteCovDb ;


    ------------------------------------------------------------
    impure function GetErrorCount return integer is
    ------------------------------------------------------------
      variable ErrorCnt : integer := 0 ;
    begin
      if NumBins < 1 then
        return 1 ;  -- return error if model empty
      else
        for i in 1 to NumBins loop
          if CovBinPtr(i).count < 0 then -- illegal CovBin
            ErrorCnt := ErrorCnt + CovBinPtr(i).count ;
          end if ;
        end loop ;
        return - ErrorCnt ;
      end if ;
    end function GetErrorCount ;

    ------------------------------------------------------------
    -- These support the older AddBins(GenCross(...)) methodology
    -- which has been replaced by AddCross
    ------------------------------------------------------------
    procedure AddBins (CovBin : CovMatrix2Type ; Name : String := "") is
    ------------------------------------------------------------
    begin
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        InsertBin(
          CovBin(i).BinVal, CovBin(i).Action, CovBin(i).Count,
          CovBin(i).AtLeast, CovBin(i).Weight, Name
        ) ;
      end loop ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins (CovBin : CovMatrix3Type ; Name : String := "") is
    ------------------------------------------------------------
    begin
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        InsertBin(
          CovBin(i).BinVal, CovBin(i).Action, CovBin(i).Count,
          CovBin(i).AtLeast, CovBin(i).Weight, Name
        ) ;
      end loop ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins (CovBin : CovMatrix4Type ; Name : String := "") is
    ------------------------------------------------------------
    begin
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        InsertBin(
          CovBin(i).BinVal, CovBin(i).Action, CovBin(i).Count,
          CovBin(i).AtLeast, CovBin(i).Weight, Name
        ) ;
      end loop ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins (CovBin : CovMatrix5Type ; Name : String := "") is
    ------------------------------------------------------------
    begin
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        InsertBin(
          CovBin(i).BinVal, CovBin(i).Action, CovBin(i).Count,
          CovBin(i).AtLeast, CovBin(i).Weight, Name
        ) ;
      end loop ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins (CovBin : CovMatrix6Type ; Name : String := "") is
    ------------------------------------------------------------
    begin
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        InsertBin(
          CovBin(i).BinVal, CovBin(i).Action, CovBin(i).Count,
          CovBin(i).AtLeast, CovBin(i).Weight, Name
        ) ;
      end loop ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins (CovBin : CovMatrix7Type ; Name : String := "") is
    ------------------------------------------------------------
    begin
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        InsertBin(
          CovBin(i).BinVal, CovBin(i).Action, CovBin(i).Count,
          CovBin(i).AtLeast, CovBin(i).Weight, Name
        ) ;
      end loop ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins (CovBin : CovMatrix8Type ; Name : String := "") is
    ------------------------------------------------------------
    begin
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        InsertBin(
          CovBin(i).BinVal, CovBin(i).Action, CovBin(i).Count,
          CovBin(i).AtLeast, CovBin(i).Weight, Name
        ) ;
      end loop ;
    end procedure AddBins ;


    ------------------------------------------------------------
    procedure AddBins (CovBin : CovMatrix9Type ; Name : String := "") is
    ------------------------------------------------------------
    begin
      GrowBins(CovBin'length) ;
      for i in CovBin'range loop
        InsertBin(
          CovBin(i).BinVal, CovBin(i).Action, CovBin(i).Count,
          CovBin(i).AtLeast, CovBin(i).Weight, Name
        ) ;
      end loop ;
    end procedure AddBins ;

-- ------------------------------------------------------------
-- ------------------------------------------------------------
-- Deprecated.  Due to name changes to promote greater consistency
-- Maintained for backward compatibility.
-- ------------------------------------------------------------

    ------------------------------------------------------------
    impure function CovBinErrCnt return integer is
    -- Deprecated.  Name changed to ErrorCount for package to package consistency
    ------------------------------------------------------------
    begin
      return GetErrorCount ;
    end function CovBinErrCnt ;

    ------------------------------------------------------------
    -- Deprecated.  Same as RandCovBinVal
    impure function RandCovHole ( PercentCov : real ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return RandCovBinVal(PercentCov)  ;
    end function RandCovHole ;

    ------------------------------------------------------------
    -- Deprecated.  Same as RandCovBinVal
    impure function RandCovHole return RangeArrayType is
    ------------------------------------------------------------
    begin
      return RandCovBinVal  ;
    end function RandCovHole ;

    -- GetCovHole replaced by GetHoleBinVal
    ------------------------------------------------------------
    -- Deprecated.  Same as GetHoleBinVal
    impure function GetCovHole ( ReqHoleNum : integer ; PercentCov : real ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return GetHoleBinVal(ReqHoleNum, PercentCov) ;
    end function GetCovHole ;

    ------------------------------------------------------------
    -- Deprecated.  Same as GetHoleBinVal
    impure function GetCovHole ( PercentCov : real ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return GetHoleBinVal(PercentCov) ;
    end function GetCovHole ;

    ------------------------------------------------------------
    -- Deprecated.  Same as GetHoleBinVal
    impure function GetCovHole ( ReqHoleNum : integer := 1 ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return GetHoleBinVal(ReqHoleNum) ;
    end function GetCovHole ;

-- ------------------------------------------------------------
-- ------------------------------------------------------------
-- Deprecated / Subsumed by versions with PercentCov Parameter
-- Maintained for backward compatibility only and
-- may be removed in the future.
-- ------------------------------------------------------------

    ------------------------------------------------------------
    -- Deprecated.  Replaced by SetMessage with multi-line support
    procedure SetItemName (ItemNameIn : String) is
    ------------------------------------------------------------
    begin
      SetMessage(ItemNameIn) ;
    end procedure SetItemName ;


    ------------------------------------------------------------
    -- Deprecated.  Same as GetMinCount
    impure function GetMinCov return integer is
    ------------------------------------------------------------
    begin
      return GetMinCount ;
    end function GetMinCov ;


    ------------------------------------------------------------
    -- Deprecated.  Same as GetMaxCount
    impure function GetMaxCov return integer is
    ------------------------------------------------------------
    begin
      return GetMaxCount ;
    end function GetMaxCov ;


    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov
    impure function CountCovHoles ( AtLeast : integer ) return integer is
    ------------------------------------------------------------
      variable HoleCount : integer := 0 ;
    begin
      CovLoop : for i in 1 to NumBins loop
--         if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count < minimum(AtLeast, CovBinPtr(i).AtLeast) then
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count < AtLeast then
          HoleCount := HoleCount + 1 ;
        end if ;
      end loop CovLoop ;
      return HoleCount ;
    end function CountCovHoles ;


    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov
    impure function IsCovered ( AtLeast : integer ) return boolean is
    ------------------------------------------------------------
    begin
      return CountCovHoles(AtLeast) = 0 ;
    end function IsCovered ;


    ------------------------------------------------------------
    impure function CalcWeight ( BinIndex : integer ; MaxAtLeast : integer  ) return integer is
    --  pt local
    ------------------------------------------------------------
    begin
      case WeightMode is
        when AT_LEAST =>
          return CovBinPtr(BinIndex).AtLeast ;

        when WEIGHT =>
          return CovBinPtr(BinIndex).Weight ;

        when REMAIN =>
          return MaxAtLeast - CovBinPtr(BinIndex).Count ;

        when REMAIN_SCALED =>
          -- Experimental may be removed
          return integer( Ceil( WeightScale * real(MaxAtLeast))) -
                          CovBinPtr(BinIndex).Count ;

        when REMAIN_WEIGHT =>
          -- Experimental may be removed
          return CovBinPtr(BinIndex).Weight * (
                   integer( Ceil( WeightScale * real(MaxAtLeast))) -
                   CovBinPtr(BinIndex).Count ) ;

        when others =>
          Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.CalcWeight Selected Weight Mode not Supported with depricated RandCovPoint(AtLeast), see RandCovPoint(PercentCov)", FAILURE) ; 
          return MaxAtLeast - CovBinPtr(BinIndex).Count ;

      end case ;
    end function CalcWeight ;


    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov
    -- If keep this, need to be able to scale AtLeast Value
    impure function RandHoleIndex ( AtLeast : integer ) return integer is
    --  pt local
    ------------------------------------------------------------
      variable WeightVec : integer_vector(0 to NumBins-1) ;  -- Prep for change to DistInt
      variable MinCount, AdjAtLeast, MaxAtLeast : integer ;
    begin
      ItemCount := ItemCount + 1 ;
      MinCount := GetMinCov ;
      -- iAtLeast := integer(ceil(CovTarget * real(AtLeast)/100.0)) ;
      if ThresholdingEnable then
        AdjAtLeast := MinCount + integer(CovThreshold) + 1 ;
        if MinCount < AtLeast then
          -- Clip at AtLeast until reach AtLeast
          AdjAtLeast := minimum(AdjAtLeast, AtLeast) ;
        end if ;
      else
        if MinCount < AtLeast then
          AdjAtLeast := AtLeast ;  -- Valid
        else
          -- Done, Enable all bins
          -- AdjAtLeast := integer'right ;  -- Get All
          AdjAtLeast := GetMaxCov + 1 ;  -- Get All
        end if ;
      end if;
      MaxAtLeast := AdjAtLeast ;
      CovLoop : for i in 1 to NumBins loop
--         if not ThresholdingEnable then
--           -- When not thresholding, consider bin Bin.AtLeast
--           -- iBinAtLeast := integer(ceil(CovTarget * real(CovBinPtr(i).AtLeast)/100.0)) ;
--           MaxAtLeast := maximum(AdjAtLeast, CovBinPtr(i).AtLeast) ;
--         end if ;
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count < MaxAtLeast then
          WeightVec(i-1) := CalcWeight(i, MaxAtLeast ) ; -- CovBinPtr(i).Weight ;
        else
          WeightVec(i-1) := 0 ;
        end if ;
      end loop CovLoop ;
      -- DistInt returns integer range 0 to Numbins-1
      LastIndex := 1 + RV.DistInt( WeightVec )  ; -- return range 1 to NumBins
      return LastIndex ;
    end function RandHoleIndex ;

    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov
    impure function RandCovBinVal (AtLeast : integer ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return CovBinPtr( RandHoleIndex(AtLeast) ).BinVal.all ;  -- GetBinVal
    end function RandCovBinVal ;

-- Maintained for backward compatibility.  Repeated until aliases work for methods
    ------------------------------------------------------------
    -- Deprecated+  New versions use PercentCov.  Name change.
    impure function RandCovHole (AtLeast : integer ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return RandCovBinVal(AtLeast) ;  -- GetBinVal
    end function RandCovHole ;

    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov
    impure function RandCovPoint (AtLeast : integer ) return integer is
    ------------------------------------------------------------
      variable BinVal : RangeArrayType(1 to 1) ;
    begin
      BinVal := RandCovBinVal(AtLeast) ;
      return RV.RandInt(BinVal(1).min, BinVal(1).max) ;
    end function RandCovPoint ;

    ------------------------------------------------------------
    impure function RandCovPoint (AtLeast : integer ) return integer_vector is
    ------------------------------------------------------------
    begin
      return ToRandPoint(RandCovBinVal(AtLeast)) ;
    end function RandCovPoint ;

    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov
    impure function GetHoleBinVal ( ReqHoleNum : integer ; AtLeast : integer ) return RangeArrayType is
    ------------------------------------------------------------
      variable HoleCount : integer := 0 ;
      variable buf : line ;
    begin
      CovLoop : for i in 1 to NumBins loop
--        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count < minimum(AtLeast, CovBinPtr(i).AtLeast) then
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count < AtLeast then
          HoleCount := HoleCount + 1 ;
          if HoleCount = ReqHoleNum  then
           return CovBinPtr(i).BinVal.all ;
          end if ;
        end if ;
      end loop CovLoop ;
      Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.GetHoleBinVal did not find hole.  " &
                     "HoleCount = " & integer'image(HoleCount) &
                     "ReqHoleNum = " & integer'image(ReqHoleNum), ERROR
      ) ;
      return CovBinPtr(NumBins).BinVal.all ;
    end function GetHoleBinVal ;

    ------------------------------------------------------------
    -- Deprecated+.  New versions use PercentCov.  Name Change.
    impure function GetCovHole ( ReqHoleNum : integer ; AtLeast : integer ) return RangeArrayType is
    ------------------------------------------------------------
    begin
      return GetHoleBinVal(ReqHoleNum, AtLeast) ;
    end function GetCovHole ;


    ------------------------------------------------------------
    --  pt local
    -- Deprecated.  New versions use PercentCov.
    procedure WriteCovHoles ( file f : text;  AtLeast : integer ) is
    ------------------------------------------------------------
      -- variable minAtLeast : integer ;
      variable buf : line ;
    begin
      WriteBinName(f, "WriteCovHoles: ") ;
      if NumBins < 1 then
        if WriteBinFileInit or UsingLocalFile then
          -- Duplicate Alert in specified file
          swrite(buf, "%% FAILURE CoverageModel ") ;
          swrite(buf, GetName) ;
          swrite(buf, "CoverageModel " & GetName & " CoveragePkg.WriteCovHoles: coverage model is empty.  Nothing to print.") ;
          writeline(f, buf) ;
        end if ; 
        Alert(AlertLogIDVar, "CoverageModel " & GetName & " CoveragePkg.WriteCovHoles: coverage model is empty.  Nothing to print.", FAILURE) ;
      end if ;
      CovLoop : for i in 1 to NumBins loop
--        minAtLeast := minimum(AtLeast,CovBinPtr(i).AtLeast) ;
--         if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count < minAtLeast then
        if CovBinPtr(i).action = COV_COUNT and CovBinPtr(i).Count < AtLeast then
          swrite(buf, "%% Bin:") ;
          write(buf, CovBinPtr(i).BinVal.all) ;
          write(buf, "  Count = " & integer'image(CovBinPtr(i).Count)) ;
          write(buf, "  AtLeast = " & integer'image(CovBinPtr(i).AtLeast)) ;
          if WeightMode = WEIGHT or WeightMode = REMAIN_WEIGHT then
            -- Print Weight only when it is used
            write(buf, "  Weight = " & integer'image(CovBinPtr(i).Weight)) ;
          end if ;
          writeline(f, buf) ;
        end if ;
      end loop CovLoop ;
      swrite(buf, "") ;
      writeline(f, buf) ;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov.
    procedure WriteCovHoles ( AtLeast : integer ) is
    ------------------------------------------------------------
    begin
      if WriteBinFileInit then
        WriteCovHoles(WriteBinFile, AtLeast) ;
      elsif IsTranscriptEnabled then 
        WriteCovHoles(TranscriptFile, AtLeast) ;
      else
        WriteCovHoles(OUTPUT, AtLeast) ;
      end if;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov.
    procedure WriteCovHoles ( LogLevel : LogType ; AtLeast : integer ) is
    ------------------------------------------------------------
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        WriteCovHoles(AtLeast) ; 
      end if;
    end procedure WriteCovHoles ;


    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov.
    procedure WriteCovHoles ( FileName : string;  AtLeast : integer ; OpenKind : File_Open_Kind := APPEND_MODE ) is
    ------------------------------------------------------------
      file CovHoleFile : text open OpenKind is FileName ;
    begin
      WriteCovHoles(CovHoleFile, AtLeast) ;
    end procedure WriteCovHoles ;

    ------------------------------------------------------------
    -- Deprecated.  New versions use PercentCov.
    procedure WriteCovHoles ( LogLevel : LogType ; FileName : string;  AtLeast : integer ; OpenKind : File_Open_Kind := APPEND_MODE ) is
    ------------------------------------------------------------
    begin
      if IsLoggingEnabled(AlertLogIDVar, LogLevel) then
        WriteCovHoles(FileName, AtLeast, OpenKind) ;
      end if;
    end procedure WriteCovHoles ;

  end protected body CovPType ;

  ------------------------------------------------------------------------------------------
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  --  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  CovPType  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  ------------------------------------------------------------------------------------------

  ------------------------------------------------------------
  -- Experimental.  Intended primarily for development.
  procedure CompareBins (
  ------------------------------------------------------------
    variable Bin1       : inout CovPType ;
    variable Bin2       : inout CovPType ;
    variable ErrorCount : inout integer
  ) is
    variable NumBins1, NumBins2 : integer ;
    variable BinInfo1, BinInfo2 : CovBinBaseType ;
    variable BinVal1, BinVal2 : RangeArrayType(1 to Bin1.GetBinValLength) ;
    variable buf : line ;
    variable iAlertLogID : AlertLogIDType ;
  begin
    iAlertLogID := Bin1.GetAlertLogID ;
    
    NumBins1 := Bin1.GetNumBins ;
    NumBins2 := Bin2.GetNumBins ;

    if (NumBins1 /= NumBins2) then
      ErrorCount := ErrorCount + 1 ;
      print("CoverageModels " & Bin1.GetName & " and " & Bin2.GetName & 
            " CoveragePkg.CompareBins, Bins have different lengths") ; 
      return ;
    end if ;

    for i in 1 to NumBins1 loop
      BinInfo1 := Bin1.GetBinInfo(i) ;
      BinInfo2 := Bin2.GetBinInfo(i) ;
      BinVal1  := Bin1.GetBinVal(i) ;
      BinVal2  := Bin2.GetBinVal(i) ;
      if BinInfo1 /= BinInfo2 or BinVal1 /= BinVal2 then
        write(buf, "%% Bin:" & integer'image(i) & " miscompare." & LF) ;
        -- writeline(OUTPUT, buf) ;
        swrite(buf, "%% Bin1: ") ;
        write(buf, BinVal1) ;
        write(buf, "   Action = " & integer'image(BinInfo1.action)) ;
        write(buf, "   Count = " & integer'image(BinInfo1.count)) ;
        write(buf, "   AtLeast = " & integer'image(BinInfo1.AtLeast)) ;
        write(buf, "   Weight = " & integer'image(BinInfo1.Weight) & LF ) ;
        -- writeline(OUTPUT, buf) ;
        swrite(buf, "%% Bin2: ") ;
        write(buf, BinVal2) ;
        write(buf, "   Action = " & integer'image(BinInfo2.action)) ;
        write(buf, "   Count = " & integer'image(BinInfo2.count)) ;
        write(buf, "   AtLeast = " & integer'image(BinInfo2.AtLeast)) ;
        write(buf, "   Weight = " & integer'image(BinInfo2.Weight) & LF ) ;
        -- writeline(OUTPUT, buf) ;
        ErrorCount := ErrorCount + 1 ;
        writeline(buf) ; 
        -- Alert(iAlertLogID, buf.all, ERROR) ; 
        -- deallocate(buf) ;
      end if ;
    end loop ;
  end procedure CompareBins ;
  
  
  ------------------------------------------------------------
  -- Experimental.  Intended primarily for development.
  procedure CompareBins (
  ------------------------------------------------------------
    variable Bin1       : inout CovPType ;
    variable Bin2       : inout CovPType 
  ) is
    variable ErrorCount : integer ;
    variable iAlertLogID : AlertLogIDType ;
  begin
    CompareBins(Bin1, Bin2, ErrorCount) ; 
    iAlertLogID := Bin1.GetAlertLogID ;
    AlertIf(ErrorCount /= 0, "CoverageModels " & Bin1.GetName & " and " & Bin2.GetName & 
                               " miscompared.  CoveragePkg.CompareBins") ; 
  end procedure CompareBins ; 

  ------------------------------------------------------------
  -- package local, Used by GenBin, IllegalBin, and IgnoreBin
  function MakeBin(
  ------------------------------------------------------------
    Min, Max      : integer ;
    NumBin        : integer ;
    AtLeast       : integer ;
    Weight        : integer ;
    Action        : integer
  ) return CovBinType is
    variable iCovBin : CovBinType(1 to NumBin) ;
    variable TotalBins : integer ; -- either real or integer
    variable rMax, rCurMin, rNextMin, rNumItemsInBin, rRemainingBins : real ; -- must be real
  begin
    if Min > Max then
      Alert(OSVVM_ALERTLOG_ID, "CoveragePkg.MakeBin (GenBin, IllegalBin, IgnoreBin): Min must be <= Max", FAILURE) ;
      return NULL_BIN ;

    elsif NumBin <= 0 then
      Alert(OSVVM_ALERTLOG_ID, "CoveragePkg.MakeBin (GenBin, IllegalBin, IgnoreBin): NumBin must be <= 0", FAILURE) ;
      return NULL_BIN ;

    elsif NumBin = 1 then
      iCovBin(1) := (
        BinVal => (1 => (Min, Max)),
        Action => Action,
        Count => 0,
        Weight => Weight,
        AtLeast => AtLeast
      ) ;
      return iCovBin ;

    else
      rCurMin := real(Min) ;
      rMax    := real(Max) ;
      rRemainingBins :=  (minimum( real(NumBin), rMax - rCurMin + 1.0 )) ;
      TotalBins := integer(rRemainingBins)  ;
      for i in iCovBin'range loop
        exit when rRemainingBins = 0.0 ;
        rNumItemsInBin := trunc((rMax - rCurMin + 1.0) / rRemainingBins) ; -- can be too large
        rNextMin := rCurMin + rNumItemsInBin ;  -- can be 2**31
        iCovBin(i) := (
          BinVal => (1 => (integer(rCurMin), integer(rNextMin - 1.0))),
          Action => Action,
          Count => 0,
          Weight => Weight,
          AtLeast => AtLeast
        ) ;
        rCurMin := rNextMin ;
        rRemainingBins := rRemainingBins - 1.0 ;
      end loop ;
      return iCovBin(1 to TotalBins) ;
    end if ;
  end function MakeBin ;


  ------------------------------------------------------------
  -- package local, Used by GenBin, IllegalBin, and IgnoreBin
  function MakeBin(
  ------------------------------------------------------------
    A             : integer_vector ;
    AtLeast       : integer ;
    Weight        : integer ;
    Action        : integer
  ) return CovBinType is
    alias    NewA      : integer_vector(1 to A'length) is A ;
    variable iCovBin   : CovBinType(1 to A'length) ;
  begin

    if A'length <= 0 then
      Alert(OSVVM_ALERTLOG_ID, "CoveragePkg.MakeBin (GenBin, IllegalBin, IgnoreBin): integer_vector parameter must have values", FAILURE) ; 
      return NULL_BIN ;

    else
      for i in NewA'Range loop
        iCovBin(i) := (
          BinVal => (i => (NewA(i), NewA(i)) ),
          Action => Action,
          Count => 0,
          Weight => Weight,
          AtLeast => AtLeast
        ) ;
      end loop ;
      return iCovBin ;
    end if ;
  end function MakeBin ;


  ------------------------------------------------------------
  function GenBin(
  ------------------------------------------------------------
    AtLeast       : integer ;
    Weight        : integer ;
    Min, Max      : integer ;
    NumBin        : integer
  ) return CovBinType is
  begin
    return  MakeBin(
              Min      => Min,
              Max      => Max,
              NumBin   => NumBin,
              AtLeast  => AtLeast,
              Weight   => Weight,
              Action   => COV_COUNT
            ) ;
  end function GenBin ;


  ------------------------------------------------------------
  function GenBin( AtLeast : integer ;  Min, Max, NumBin : integer ) return CovBinType is
  ------------------------------------------------------------
  begin
    return  MakeBin(
              Min      => Min,
              Max      => Max,
              NumBin   => NumBin,
              AtLeast  => AtLeast,
              Weight   => 1,
              Action   => COV_COUNT
            ) ;
  end function GenBin ;


  ------------------------------------------------------------
  function GenBin( Min, Max, NumBin : integer ) return CovBinType is
  ------------------------------------------------------------
  begin
    return  MakeBin(
              Min      => Min,
              Max      => Max,
              NumBin   => NumBin,
              AtLeast  => 1,
              Weight   => 1,
              Action   => COV_COUNT
            ) ;
  end function GenBin ;


  ------------------------------------------------------------
  function GenBin ( Min, Max : integer) return CovBinType is
  ------------------------------------------------------------
  begin
    -- create a separate CovBin for each value
    -- AtLeast and Weight = 1 (must use longer version to specify)
    return  MakeBin(
              Min      => Min,
              Max      => Max,
              NumBin   => Max - Min + 1,
              AtLeast  => 1,
              Weight   => 1,
              Action   => COV_COUNT
            ) ;
  end function GenBin ;


  ------------------------------------------------------------
  function GenBin ( A : integer ) return CovBinType is
  ------------------------------------------------------------
  begin
    -- create a single CovBin for A.
    -- AtLeast and Weight = 1 (must use longer version to specify)
    return  MakeBin(
              Min      => A,
              Max      => A,
              NumBin   => 1,
              AtLeast  => 1,
              Weight   => 1,
              Action   => COV_COUNT
            ) ;
  end function GenBin ;


  ------------------------------------------------------------
  function GenBin(
  ------------------------------------------------------------
    AtLeast       : integer ;
    Weight        : integer ;
    A             : integer_vector
  ) return CovBinType is
  begin
    return  MakeBin(
              A        => A,
              AtLeast  => AtLeast,
              Weight   => Weight,
              Action   => COV_COUNT
            ) ;
  end function GenBin ;


  ------------------------------------------------------------
  function GenBin ( AtLeast : integer ;  A : integer_vector ) return CovBinType is
  ------------------------------------------------------------
  begin
    return  MakeBin(
              A        => A,
              AtLeast  => AtLeast,
              Weight   => 1,
              Action   => COV_COUNT
            ) ;
  end function GenBin ;


  ------------------------------------------------------------
  function GenBin ( A : integer_vector ) return CovBinType is
  ------------------------------------------------------------
  begin
    return  MakeBin(
              A        => A,
              AtLeast  => 1,
              Weight   => 1,
              Action   => COV_COUNT
            ) ;
  end function GenBin ;


  ------------------------------------------------------------
  function IllegalBin ( Min, Max, NumBin : integer ) return CovBinType is
  ------------------------------------------------------------
  begin
    return  MakeBin(
              Min      => Min,
              Max      => Max,
              NumBin   => NumBin,
              AtLeast  => 0,
              Weight   => 0,
              Action   => COV_ILLEGAL
            ) ;
  end function IllegalBin ;

  ------------------------------------------------------------
  function IllegalBin ( Min, Max : integer ) return CovBinType is
  ------------------------------------------------------------
  begin
    -- default, generate one CovBin with the entire range of values
    return  MakeBin(
              Min      => Min,
              Max      => Max,
              NumBin   => 1,
              AtLeast  => 0,
              Weight   => 0,
              Action   => COV_ILLEGAL
            ) ;
  end function IllegalBin ;


  ------------------------------------------------------------
  function IllegalBin ( A : integer ) return CovBinType is
  ------------------------------------------------------------
  begin
    return  MakeBin(
              Min      => A,
              Max      => A,
              NumBin   => 1,
              AtLeast  => 0,
              Weight   => 0,
              Action   => COV_ILLEGAL
            ) ;
  end function IllegalBin ;


-- IgnoreBin should never have an AtLeast parameter
  ------------------------------------------------------------
  function IgnoreBin (Min, Max, NumBin : integer) return CovBinType is
  ------------------------------------------------------------
  begin
    return  MakeBin(
              Min      => Min,
              Max      => Max,
              NumBin   => NumBin,
              AtLeast  => 0,
              Weight   => 0,
              Action   => COV_IGNORE
            ) ;
  end function IgnoreBin ;


  ------------------------------------------------------------
  function IgnoreBin (Min, Max : integer) return CovBinType is
  ------------------------------------------------------------
  begin
    -- default, generate one CovBin with the entire range of values
    return  MakeBin(
              Min      => Min,
              Max      => Max,
              NumBin   => 1,
              AtLeast  => 0,
              Weight   => 0,
              Action   => COV_IGNORE
            ) ;
  end function IgnoreBin ;


  ------------------------------------------------------------
  function IgnoreBin (A : integer) return CovBinType is
  ------------------------------------------------------------
  begin
    return  MakeBin(
              Min      => A,
              Max      => A,
              NumBin   => 1,
              AtLeast  => 0,
              Weight   => 0,
              Action   => COV_IGNORE
            ) ;
  end function IgnoreBin ;


  ------------------------------------------------------------
  function GenCross(  -- 2
  -- Cross existing bins
  -- Use AddCross for adding values directly to coverage database
  -- Use GenCross for constants
  ------------------------------------------------------------
    AtLeast     : integer ;
    Weight      : integer ;
    Bin1, Bin2  : CovBinType
  ) return CovMatrix2Type is
    constant BIN_LENS : integer_vector := BinLengths(Bin1, Bin2) ;
    constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
    variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
    variable CrossBins    : CovBinType(BinIndex'range) ;
    variable Action       : integer ;
    variable iCovMatrix   : CovMatrix2Type(1 to NUM_NEW_BINS) ;
  begin
    for MatrixIndex in iCovMatrix'range loop
      CrossBins := ConcatenateBins(BinIndex, Bin1, Bin2) ;
      Action       := MergeState(CrossBins) ;
      iCovMatrix(MatrixIndex).action  := Action ;
      iCovMatrix(MatrixIndex).count   := 0 ;
      iCovMatrix(MatrixIndex).BinVal  := MergeBinVal(CrossBins) ;
      iCovMatrix(MatrixIndex).AtLeast := MergeAtLeast( Action, AtLeast, CrossBins) ;
      iCovMatrix(MatrixIndex).Weight  := MergeWeight ( Action, Weight,  CrossBins) ;
      IncBinIndex( BinIndex, BIN_LENS ) ; -- increment right most one, then if overflow, increment next
    end loop ;
    return iCovMatrix ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(AtLeast : integer ; Bin1, Bin2 : CovBinType) return CovMatrix2Type is
  -- Cross existing bins  -- use AddCross instead
  ------------------------------------------------------------
  begin
    return GenCross(AtLeast, 0, Bin1, Bin2) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(Bin1, Bin2 : CovBinType) return CovMatrix2Type is
  -- Cross existing bins  -- use AddCross instead
  ------------------------------------------------------------
  begin
    return GenCross(0, 0, Bin1, Bin2) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(  -- 3
  ------------------------------------------------------------
    AtLeast           : integer ;
    Weight            : integer ;
    Bin1, Bin2, Bin3  : CovBinType
  ) return CovMatrix3Type is
    constant BIN_LENS : integer_vector := BinLengths(Bin1, Bin2, Bin3) ;
    constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
    variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
    variable CrossBins    : CovBinType(BinIndex'range) ;
    variable Action       : integer ;
    variable iCovMatrix   : CovMatrix3Type(1 to NUM_NEW_BINS) ;
  begin
    for MatrixIndex in iCovMatrix'range loop
      CrossBins := ConcatenateBins(BinIndex, Bin1, Bin2, Bin3) ;
      Action       := MergeState(CrossBins) ;
      iCovMatrix(MatrixIndex).action  := Action ;
      iCovMatrix(MatrixIndex).count   := 0 ;
      iCovMatrix(MatrixIndex).BinVal  := MergeBinVal(CrossBins) ;
      iCovMatrix(MatrixIndex).AtLeast := MergeAtLeast( Action, AtLeast, CrossBins) ;
      iCovMatrix(MatrixIndex).Weight  := MergeWeight ( Action, Weight,  CrossBins) ;
      IncBinIndex( BinIndex, BIN_LENS ) ; -- increment right most one, then if overflow, increment next
    end loop ;
    return iCovMatrix ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3 : CovBinType ) return CovMatrix3Type is
  ------------------------------------------------------------
  begin
    return GenCross(AtLeast, 0, Bin1, Bin2, Bin3) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( Bin1, Bin2, Bin3 : CovBinType ) return CovMatrix3Type is
  ------------------------------------------------------------
  begin
    return GenCross(0, 0, Bin1, Bin2, Bin3) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(  -- 4
  ------------------------------------------------------------
    AtLeast                 : integer ;
    Weight                  : integer ;
    Bin1, Bin2, Bin3, Bin4  : CovBinType
  ) return CovMatrix4Type is
    constant BIN_LENS : integer_vector := BinLengths(Bin1, Bin2, Bin3, Bin4) ;
    constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
    variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
    variable CrossBins    : CovBinType(BinIndex'range) ;
    variable Action       : integer ;
    variable iCovMatrix   : CovMatrix4Type(1 to NUM_NEW_BINS) ;
  begin
    for MatrixIndex in iCovMatrix'range loop
      CrossBins := ConcatenateBins(BinIndex, Bin1, Bin2, Bin3, Bin4) ;
      Action       := MergeState(CrossBins) ;
      iCovMatrix(MatrixIndex).action  := Action ;
      iCovMatrix(MatrixIndex).count   := 0 ;
      iCovMatrix(MatrixIndex).BinVal  := MergeBinVal(CrossBins) ;
      iCovMatrix(MatrixIndex).AtLeast := MergeAtLeast( Action, AtLeast, CrossBins) ;
      iCovMatrix(MatrixIndex).Weight  := MergeWeight ( Action, Weight,  CrossBins) ;
      IncBinIndex( BinIndex, BIN_LENS ) ; -- increment right most one, then if overflow, increment next
    end loop ;
    return iCovMatrix ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4 : CovBinType ) return CovMatrix4Type is
  ------------------------------------------------------------
  begin
    return GenCross(AtLeast, 0, Bin1, Bin2, Bin3, Bin4) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( Bin1, Bin2, Bin3, Bin4 : CovBinType ) return CovMatrix4Type is
  ------------------------------------------------------------
  begin
    return GenCross(0, 0, Bin1, Bin2, Bin3, Bin4) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(  -- 5
  ------------------------------------------------------------
    AtLeast                       : integer ;
    Weight                        : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5  : CovBinType
  ) return CovMatrix5Type is
    constant BIN_LENS : integer_vector := BinLengths(Bin1, Bin2, Bin3, Bin4, Bin5) ;
    constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
    variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
    variable CrossBins    : CovBinType(BinIndex'range) ;
    variable Action       : integer ;
    variable iCovMatrix   : CovMatrix5Type(1 to NUM_NEW_BINS) ;
  begin
    for MatrixIndex in iCovMatrix'range loop
      CrossBins := ConcatenateBins(BinIndex, Bin1, Bin2, Bin3, Bin4, Bin5) ;
      Action       := MergeState(CrossBins) ;
      iCovMatrix(MatrixIndex).action  := Action ;
      iCovMatrix(MatrixIndex).count   := 0 ;
      iCovMatrix(MatrixIndex).BinVal  := MergeBinVal(CrossBins) ;
      iCovMatrix(MatrixIndex).AtLeast := MergeAtLeast( Action, AtLeast, CrossBins) ;
      iCovMatrix(MatrixIndex).Weight  := MergeWeight ( Action, Weight,  CrossBins) ;
      IncBinIndex( BinIndex, BIN_LENS ) ; -- increment right most one, then if overflow, increment next
    end loop ;
    return iCovMatrix ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5 : CovBinType ) return CovMatrix5Type is
  ------------------------------------------------------------
  begin
    return GenCross(AtLeast, 0, Bin1, Bin2, Bin3, Bin4, Bin5) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5 : CovBinType ) return CovMatrix5Type is
  ------------------------------------------------------------
  begin
    return GenCross(0, 0, Bin1, Bin2, Bin3, Bin4, Bin5) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(  -- 6
  ------------------------------------------------------------
    AtLeast                             : integer ;
    Weight                              : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6  : CovBinType
  ) return CovMatrix6Type is
    constant BIN_LENS : integer_vector := BinLengths(Bin1, Bin2, Bin3, Bin4, Bin5, Bin6) ;
    constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
    variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
    variable CrossBins    : CovBinType(BinIndex'range) ;
    variable Action       : integer ;
    variable iCovMatrix   : CovMatrix6Type(1 to NUM_NEW_BINS) ;
  begin
    for MatrixIndex in iCovMatrix'range loop
      CrossBins := ConcatenateBins(BinIndex, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6) ;
      Action       := MergeState(CrossBins) ;
      iCovMatrix(MatrixIndex).action  := Action ;
      iCovMatrix(MatrixIndex).count   := 0 ;
      iCovMatrix(MatrixIndex).BinVal  := MergeBinVal(CrossBins) ;
      iCovMatrix(MatrixIndex).AtLeast := MergeAtLeast( Action, AtLeast, CrossBins) ;
      iCovMatrix(MatrixIndex).Weight  := MergeWeight ( Action, Weight,  CrossBins) ;
      IncBinIndex( BinIndex, BIN_LENS ) ; -- increment right most one, then if overflow, increment next
    end loop ;
    return iCovMatrix ;

  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5, Bin6 : CovBinType ) return CovMatrix6Type is
  ------------------------------------------------------------
  begin
    return GenCross(AtLeast, 0, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5, Bin6 : CovBinType ) return CovMatrix6Type is
  ------------------------------------------------------------
  begin
    return GenCross(0, 0, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(  -- 7
  ------------------------------------------------------------
    AtLeast                                   : integer ;
    Weight                                    : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7  : CovBinType
  ) return CovMatrix7Type is
    constant BIN_LENS : integer_vector := BinLengths(Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7) ;
    constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
    variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
    variable CrossBins    : CovBinType(BinIndex'range) ;
    variable Action       : integer ;
    variable iCovMatrix   : CovMatrix7Type(1 to NUM_NEW_BINS) ;
  begin
    for MatrixIndex in iCovMatrix'range loop
      CrossBins := ConcatenateBins(BinIndex, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7) ;
      Action       := MergeState(CrossBins) ;
      iCovMatrix(MatrixIndex).action  := Action ;
      iCovMatrix(MatrixIndex).count   := 0 ;
      iCovMatrix(MatrixIndex).BinVal  := MergeBinVal(CrossBins) ;
      iCovMatrix(MatrixIndex).AtLeast := MergeAtLeast( Action, AtLeast, CrossBins) ;
      iCovMatrix(MatrixIndex).Weight  := MergeWeight ( Action, Weight,  CrossBins) ;
      IncBinIndex( BinIndex, BIN_LENS ) ; -- increment right most one, then if overflow, increment next
    end loop ;
    return iCovMatrix ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7 : CovBinType ) return CovMatrix7Type is
  ------------------------------------------------------------
  begin
    return GenCross(AtLeast, 0, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7 : CovBinType ) return CovMatrix7Type is
  ------------------------------------------------------------
  begin
    return GenCross(0, 0, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(  -- 8
  ------------------------------------------------------------
    AtLeast                                         : integer ;
    Weight                                          : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8  : CovBinType
  ) return CovMatrix8Type is
    constant BIN_LENS : integer_vector := BinLengths(Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8) ;
    constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
    variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
    variable CrossBins    : CovBinType(BinIndex'range) ;
    variable Action       : integer ;
    variable iCovMatrix   : CovMatrix8Type(1 to NUM_NEW_BINS) ;
  begin
    for MatrixIndex in iCovMatrix'range loop
      CrossBins := ConcatenateBins(BinIndex, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8) ;
      Action       := MergeState(CrossBins) ;
      iCovMatrix(MatrixIndex).action  := Action ;
      iCovMatrix(MatrixIndex).count   := 0 ;
      iCovMatrix(MatrixIndex).BinVal  := MergeBinVal(CrossBins) ;
      iCovMatrix(MatrixIndex).AtLeast := MergeAtLeast( Action, AtLeast, CrossBins) ;
      iCovMatrix(MatrixIndex).Weight  := MergeWeight ( Action, Weight,  CrossBins) ;
      IncBinIndex( BinIndex, BIN_LENS ) ; -- increment right most one, then if overflow, increment next
    end loop ;
    return iCovMatrix ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8 : CovBinType ) return CovMatrix8Type is
  ------------------------------------------------------------
  begin
    return GenCross(AtLeast, 0, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8 : CovBinType ) return CovMatrix8Type is
  ------------------------------------------------------------
  begin
    return GenCross(0, 0, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross(  -- 9
  ------------------------------------------------------------
    AtLeast                                               : integer ;
    Weight                                                : integer ;
    Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9  : CovBinType
  ) return CovMatrix9Type is
    constant BIN_LENS : integer_vector := BinLengths(Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9) ;
    constant NUM_NEW_BINS : integer := CalcNumCrossBins(BIN_LENS) ;
    variable BinIndex     : integer_vector(1 to BIN_LENS'length) := (others => 1) ;
    variable CrossBins    : CovBinType(BinIndex'range) ;
    variable Action       : integer ;
    variable iCovMatrix   : CovMatrix9Type(1 to NUM_NEW_BINS) ;
  begin
    for MatrixIndex in iCovMatrix'range loop
      CrossBins := ConcatenateBins(BinIndex, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9) ;
      Action       := MergeState(CrossBins) ;
      iCovMatrix(MatrixIndex).action  := Action ;
      iCovMatrix(MatrixIndex).count   := 0 ;
      iCovMatrix(MatrixIndex).BinVal  := MergeBinVal(CrossBins) ;
      iCovMatrix(MatrixIndex).AtLeast := MergeAtLeast( Action, AtLeast, CrossBins) ;
      iCovMatrix(MatrixIndex).Weight  := MergeWeight ( Action, Weight,  CrossBins) ;
      IncBinIndex( BinIndex, BIN_LENS ) ; -- increment right most one, then if overflow, increment next
    end loop ;
    return iCovMatrix ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( AtLeast : integer ; Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9 : CovBinType ) return CovMatrix9Type is
  ------------------------------------------------------------
  begin
    return GenCross(AtLeast, 0, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9) ;
  end function GenCross ;


  ------------------------------------------------------------
  function GenCross( Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9 : CovBinType ) return CovMatrix9Type is
  ------------------------------------------------------------
  begin
    return GenCross(0, 0, Bin1, Bin2, Bin3, Bin4, Bin5, Bin6, Bin7, Bin8, Bin9) ;
  end function GenCross ;


  ------------------------------------------------------------
  procedure increment( signal Count : inout integer ) is
  ------------------------------------------------------------
  begin
    Count <= Count + 1 ;
  end procedure increment ;


  ------------------------------------------------------------
  procedure increment( signal Count : inout integer ; enable : boolean ) is
  ------------------------------------------------------------
  begin
    if enable then
      Count <= Count + 1 ;
    end if ;
  end procedure increment ;


  ------------------------------------------------------------
  procedure increment( signal Count : inout integer ; enable : std_ulogic ) is
  ------------------------------------------------------------
  begin
    if to_x01(enable) = '1' then
      Count <= Count + 1 ;
    end if ;
  end procedure increment ;


  ------------------------------------------------------------
  function to_integer ( B : boolean ) return integer is
  ------------------------------------------------------------
  begin
    if B then
      return 1 ;
    else
      return 0 ;
    end if ;
  end function to_integer ;


  ------------------------------------------------------------
  function to_integer ( SL : std_logic ) return integer is
  -------------------------------------------------------------
  begin
    case SL is
      when '1' | 'H' =>  return 1 ;
      when '0' | 'L' =>  return 0 ;
      when others    =>  return -1 ;
    end case ;
  end function to_integer ;


  ------------------------------------------------------------
  function to_integer_vector ( BV : boolean_vector ) return integer_vector is
  ------------------------------------------------------------
    variable result : integer_vector(BV'range) ;
  begin
    for i in BV'range loop
      result(i) := to_integer(BV(i)) ;
    end loop ;
    return result ;
  end function to_integer_vector ;


  ------------------------------------------------------------
  function to_integer_vector ( SLV : std_logic_vector ) return integer_vector is
  -------------------------------------------------------------
    variable result : integer_vector(SLV'range) ;
  begin
    for i in SLV'range loop
      result(i) := to_integer(SLV(i)) ;
    end loop ;
    return result ;
  end function to_integer_vector ;

end package body CoveragePkg ;