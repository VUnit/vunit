--
--  File Name:         AlertLogPkg_body_BVUL.vhd
--  Design Unit Name:  AlertLogPkg
--  Revision:          STANDARD VERSION,  revision 2015.01
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--        Alert handling and log filtering (verbosity control)
--        Alert handling provides a method to count failures, errors, and warnings
--          To accumlate counts, a data structure is created in a shared variable
--          It is of type AlertLogStructPType which is defined in AlertLogBasePkg
--        Log filtering provides verbosity control for logs (display or do not display)
--        AlertLogPkg provides a simplified interface to the shared variable 
--          
--
--  Developed for:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        11898 SW 128th Ave.  Tigard, Or  97223
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date       Version    Description
--    01/2015:   2015.01    Initial revision
--
--
--  Copyright (c) 2015 by SynthWorks Design Inc.  All rights reserved.
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




--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////

use work.NamePkg.all ;

package body AlertLogPkg is

  -- instead of justify(to_upper(to_string())), just look up the upper case, left justified values
  type     AlertNameType is array(AlertType) of string(1 to 7) ; 
  constant ALERT_NAME : AlertNameType := (WARNING => "WARNING", ERROR => "ERROR  ", FAILURE => "FAILURE") ;  -- , NEVER => "NEVER  "
  type     LogNameType is array(LogType) of string(1 to 7) ; 
  constant LOG_NAME : LogNameType := (DEBUG => "DEBUG  ", FINAL => "FINAL  ", INFO => "INFO   ", ALWAYS => "ALWAYS ") ; -- , NEVER => "NEVER  "

  -- Local
  constant NUM_PREDEFINED_AL_IDS : AlertLogIDType := 2 ;  -- Not including base
  
  type AlertToSeverityType is array (AlertType) of severity_level ; 
  constant ALERT_TO_SEVERITY : AlertToSeverityType := (WARNING => WARNING, ERROR => ERROR, FAILURE => FAILURE) ;  -- , NEVER => "NEVER  "

 
  ------------------------------------------------------------
  procedure Alert( 
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ; 
    Message      : string  ; 
    Level        : AlertType := ERROR
  ) is
  begin
    report Message &   "AlertLogID = " & to_string(AlertLogID) severity ALERT_TO_SEVERITY(Level) ; 
  end procedure alert ; 

  ------------------------------------------------------------
  procedure Alert( Message : string ; Level : AlertType := ERROR ) is 
  ------------------------------------------------------------
  begin
    Alert(ALERT_DEFAULT_ID , Message, Level) ; 
  end procedure alert ; 
  
  ------------------------------------------------------------
  procedure AlertIf( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    if condition then
      Alert(AlertLogID , Message, Level) ; 
    end if ; 
  end procedure AlertIf ; 

  ------------------------------------------------------------
  procedure AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    if condition then
      Alert(ALERT_DEFAULT_ID , Message, Level) ; 
    end if ; 
  end procedure AlertIf ;  
  
  ------------------------------------------------------------
  -- useful with exit conditions in a loop:  exit when alert( not ReadValid, failure, "Read Failed") ; 
  impure function  AlertIf( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    if condition then
      Alert(AlertLogID , Message, Level) ; 
    end if ; 
    return condition ; 
  end function AlertIf ;  
  
  ------------------------------------------------------------
  impure function  AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    if condition then
      Alert(ALERT_DEFAULT_ID, Message, Level) ; 
    end if ; 
    return condition ; 
  end function AlertIf ;   
  
  ------------------------------------------------------------
  procedure AlertIfNot( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    if not condition then
      Alert(AlertLogID, Message, Level) ; 
    end if ; 
  end procedure AlertIfNot ; 

  ------------------------------------------------------------
  procedure AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    if not condition then
      Alert(ALERT_DEFAULT_ID, Message, Level) ; 
    end if ; 
  end procedure AlertIfNot ;  
  
  ------------------------------------------------------------
  -- useful with exit conditions in a loop:  exit when alert( not ReadValid, failure, "Read Failed") ; 
  impure function  AlertIfNot( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    if not condition then
      Alert(AlertLogID, Message, Level) ; 
    end if ; 
    return not condition ; 
  end function AlertIfNot ;  
  
  ------------------------------------------------------------
  impure function  AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    if not condition then
      Alert(ALERT_DEFAULT_ID, Message, Level) ; 
    end if ; 
    return not condition ; 
  end function AlertIfNot ;   
  
  ------------------------------------------------------------
  procedure SetAlertLogJustify is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetAlertLogJustify ; 
  
  ------------------------------------------------------------
  procedure ReportAlerts ( Name : string := OSVVM_STRING_INIT_PARM_DETECT ; AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID ; ExternalErrors : AlertCountType := (others => 0) ) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure ReportAlerts ; 

  ------------------------------------------------------------
  procedure ReportAlerts ( Name : String ; AlertCount : AlertCountType ) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure ReportAlerts ; 

  ------------------------------------------------------------
  procedure ClearAlerts is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure ClearAlerts ; 

  ------------------------------------------------------------
  function "+" (L, R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ; 
  begin
    Result(FAILURE) := L(FAILURE) + R(FAILURE) ; 
    Result(ERROR)   := L(ERROR)   + R(ERROR) ; 
    Result(WARNING) := L(WARNING) + R(WARNING) ; 
    return Result ; 
  end function "+" ;

  ------------------------------------------------------------
  function "-" (L, R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ; 
  begin
    Result(FAILURE) := L(FAILURE) - R(FAILURE) ; 
    Result(ERROR)   := L(ERROR)   - R(ERROR) ; 
    Result(WARNING) := L(WARNING) - R(WARNING) ; 
    return Result ; 
  end function "-" ;

  ------------------------------------------------------------
  function "-" (R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ; 
  begin
    Result(FAILURE) := - R(FAILURE) ; 
    Result(ERROR)   := - R(ERROR) ; 
    Result(WARNING) := - R(WARNING) ; 
    return Result ; 
  end function "-" ;
  
  ------------------------------------------------------------
  impure function SumAlertCount(AlertCount: AlertCountType) return integer is
  ------------------------------------------------------------
  begin
    return AlertCount(FAILURE) + AlertCount(ERROR) + AlertCount(WARNING) ; 
  end function SumAlertCount ; 

  ------------------------------------------------------------
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return (0, 0, 0) ; 
  end function GetAlertCount ; 
    
  ------------------------------------------------------------
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return 0 ; 
  end function GetAlertCount ; 

  ------------------------------------------------------------
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return (0, 0, 0) ; 
  end function GetEnabledAlertCount ; 
    
  ------------------------------------------------------------
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return 0 ;
  end function GetEnabledAlertCount ; 

  ------------------------------------------------------------
  impure function GetDisabledAlertCount return AlertCountType is
  ------------------------------------------------------------
   begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return (0, 0, 0) ; 
  end function GetDisabledAlertCount ; 

  ------------------------------------------------------------
  impure function GetDisabledAlertCount return integer is
  ------------------------------------------------------------
   begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return 0 ; 
  end function GetDisabledAlertCount ; 

  ------------------------------------------------------------
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return (0, 0, 0) ; 
  end function GetDisabledAlertCount ; 
  
  ------------------------------------------------------------
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return integer is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return 0 ; 
  end function GetDisabledAlertCount ; 
  
  ------------------------------------------------------------
  procedure log( 
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ; 
    Message      : string ; 
    Level        : LogType := ALWAYS
  ) is
  begin
    report Message &   "AlertLogID = " & to_string(AlertLogID) & "  Level = " & to_string(Level) ; 
  end procedure log ;
  
  ------------------------------------------------------------
  procedure log( Message : string ; Level : LogType := ALWAYS) is
  ------------------------------------------------------------
  begin
    Log(LOG_DEFAULT_ID, Message, Level) ; 
  end procedure log ;
    
  ------------------------------------------------------------
  impure function IsLoggingEnabled(AlertLogID : AlertLogIDType ; Level : LogType) return boolean is
  ------------------------------------------------------------
  begin
-- returns true when log level is enabled
alert("AlertLogPkg:  procedure must be implemented", FAILURE) ; 
--    return AlertLogStruct.IsLoggingEnabled(AlertLogID, Level) ;
    return FALSE ; 
  end function IsLoggingEnabled ; 
    
  ------------------------------------------------------------
  impure function IsLoggingEnabled(Level : LogType) return boolean is
  ------------------------------------------------------------
  begin
-- returns true when log level is enabled
alert("AlertLogPkg:  procedure must be implemented", FAILURE) ; 
--    return AlertLogStruct.IsLoggingEnabled(LOG_DEFAULT_ID, Level) ;
    return FALSE ; 
  end function IsLoggingEnabled ; 
    
  ------------------------------------------------------------
  procedure SetAlertLogName(Name : string ) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetAlertLogName ;
  
  ------------------------------------------------------------
  procedure InitializeAlertLogStruct is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure InitializeAlertLogStruct ;
  
  ------------------------------------------------------------
  procedure DeallocateAlertLogStruct is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure DeallocateAlertLogStruct ; 

  ------------------------------------------------------------
  impure function FindAlertLogID(Name : string ) return AlertLogIDType is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return 0 ; 
  end function FindAlertLogID ;
  
  ------------------------------------------------------------
  impure function GetAlertLogID(Name : string ; ParentID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertLogIDType is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return 0 ; 
  end function GetAlertLogID ;
  
  ------------------------------------------------------------
  procedure SetGlobalAlertEnable (A : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetGlobalAlertEnable ;
  
  ------------------------------------------------------------
  -- Set using constant.  Set before code runs.
  impure function SetGlobalAlertEnable (A : boolean := TRUE) return boolean is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return A ;  
  end function SetGlobalAlertEnable ;

  ------------------------------------------------------------
  procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetAlertStopCount ;    

  ------------------------------------------------------------
  procedure SetAlertStopCount(Level : AlertType ;  Count : integer) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetAlertStopCount ;    

  ------------------------------------------------------------
  procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetAlertEnable ;    

  ------------------------------------------------------------
  procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetAlertEnable ;    
  
  ------------------------------------------------------------
  procedure SetLogEnable(Level : LogType ;  Enable : boolean) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetLogEnable ;    

  ------------------------------------------------------------
  procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetLogEnable ;    

  ------------------------------------------------------------
  procedure SetAlertLogOptions (
  ------------------------------------------------------------
    FailOnWarning         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ; 
    FailOnDisabledErrors  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    ReportHierarchy       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertLevel       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertName        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertTime        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogLevel         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogName          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogTime          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    AlertPrefix           : string := OSVVM_STRING_INIT_PARM_DETECT ;
    LogPrefix             : string := OSVVM_STRING_INIT_PARM_DETECT ;
    ReportPrefix          : string := OSVVM_STRING_INIT_PARM_DETECT ;
    DoneName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    PassName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    FailName              : string := OSVVM_STRING_INIT_PARM_DETECT 
  ) is
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
  end procedure SetAlertLogOptions ;
    
  ------------------------------------------------------------
  impure function GetAlertReportPrefix return string is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return "" ; 
  end function GetAlertReportPrefix ;
  
  ------------------------------------------------------------
  impure function GetAlertDoneName return string is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return "" ; 
  end function GetAlertDoneName ;

  ------------------------------------------------------------
  impure function GetAlertPassName return string is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return "" ; 
  end function GetAlertPassName ;

  ------------------------------------------------------------
  impure function GetAlertFailName return string is
  ------------------------------------------------------------
  begin
    alert("AlertLogPkg:  procedure not implemented for BVUL") ; 
    return "" ; 
  end function GetAlertFailName ;
 
end package body AlertLogPkg ;