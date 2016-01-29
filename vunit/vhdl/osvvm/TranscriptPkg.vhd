--
--  File Name:         TranscriptPkg.vhd
--  Design Unit Name:  TranscriptPkg
--  Revision:          STANDARD VERSION,  revision 2015.01
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--        Define file identifier TranscriptFile
--        provide subprograms to open, close, and print to it.
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

use std.textio.all ;
package TranscriptPkg is

  -- File Identifier to facilitate usage of one transcript file 
  file             TranscriptFile : text ;
  
  -- Cause compile errors if READ_MODE is passed to TranscriptOpen
  subtype WRITE_APPEND_OPEN_KIND is FILE_OPEN_KIND range WRITE_MODE to APPEND_MODE ; 
  
  -- Open and close TranscriptFile.  Function allows declarative opens 
  procedure        TranscriptOpen (Status: out FILE_OPEN_STATUS; ExternalName: STRING; OpenKind: WRITE_APPEND_OPEN_KIND := WRITE_MODE) ;
  procedure        TranscriptOpen (ExternalName: STRING; OpenKind: WRITE_APPEND_OPEN_KIND := WRITE_MODE) ;  
  impure function  TranscriptOpen (ExternalName: STRING; OpenKind: WRITE_APPEND_OPEN_KIND := WRITE_MODE) return FILE_OPEN_STATUS ;
  procedure        TranscriptClose ;  
  impure function  IsTranscriptOpen return boolean ; 
  alias            IsTranscriptEnabled is IsTranscriptOpen [return boolean] ;  
  
  -- Mirroring.  When using TranscriptPkw WriteLine and Print, uses both TranscriptFile and OUTPUT 
  procedure        SetTranscriptMirror (A : boolean := TRUE) ; 
  impure function  IsTranscriptMirrored return boolean ; 
  alias            GetTranscriptMirror is IsTranscriptMirrored [return boolean] ;

  -- Write to TranscriptFile when open.  Write to OUTPUT when not open or IsTranscriptMirrored
  procedure        WriteLine(buf : inout line)  ; 
  procedure        Print(s : string) ; 

end TranscriptPkg ;
  
--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////

package body TranscriptPkg is
  ------------------------------------------------------------
  type LocalBooleanPType is protected 
    procedure Set (A : boolean) ; 
    impure function get return boolean ; 
  end protected LocalBooleanPType ; 
  type LocalBooleanPType is protected body
    variable GlobalVar : boolean := FALSE ; 
    procedure Set (A : boolean) is
    begin
       GlobalVar := A ; 
    end procedure Set ; 
    impure function get return boolean is
    begin
      return GlobalVar ; 
    end function get ; 
  end protected body LocalBooleanPType ; 
  
  ------------------------------------------------------------
  shared variable TranscriptEnable : LocalBooleanPType ; 
  shared variable TranscriptMirror : LocalBooleanPType ; 

  ------------------------------------------------------------
  procedure TranscriptOpen (Status: out FILE_OPEN_STATUS; ExternalName: STRING; OpenKind: WRITE_APPEND_OPEN_KIND := WRITE_MODE) is
  ------------------------------------------------------------
  begin
    file_open(Status, TranscriptFile, ExternalName, OpenKind) ;
    TranscriptEnable.Set(TRUE) ;
  end procedure TranscriptOpen ; 
  
  ------------------------------------------------------------
  procedure TranscriptOpen (ExternalName: STRING; OpenKind: WRITE_APPEND_OPEN_KIND := WRITE_MODE) is
  ------------------------------------------------------------
  begin
    file_open(TranscriptFile, ExternalName, OpenKind) ;
    TranscriptEnable.Set(TRUE) ;
  end procedure TranscriptOpen ; 
  
  ------------------------------------------------------------
  impure function  TranscriptOpen (ExternalName: STRING; OpenKind: WRITE_APPEND_OPEN_KIND := WRITE_MODE) return FILE_OPEN_STATUS is
  ------------------------------------------------------------
    variable Status : FILE_OPEN_STATUS ; 
  begin
    file_open(Status, TranscriptFile, ExternalName, OpenKind) ;
    TranscriptEnable.Set(TRUE) ;
    return status ; 
  end function TranscriptOpen ;

  ------------------------------------------------------------
  procedure TranscriptClose is
  ------------------------------------------------------------
  begin
    if TranscriptEnable.Get then
      file_close(TranscriptFile) ;
    end if ; 
    TranscriptEnable.Set(FALSE) ;
  end procedure TranscriptClose ; 
  
  ------------------------------------------------------------
  impure function IsTranscriptOpen return boolean is
  ------------------------------------------------------------
  begin
    return TranscriptEnable.Get ;
  end function IsTranscriptOpen ;
  
  ------------------------------------------------------------
  procedure SetTranscriptMirror (A : boolean := TRUE) is 
  ------------------------------------------------------------
  begin
      TranscriptMirror.Set(A) ;
  end procedure SetTranscriptMirror ; 

  ------------------------------------------------------------
  impure function IsTranscriptMirrored return boolean is
  ------------------------------------------------------------
  begin
    return TranscriptMirror.Get ;
  end function IsTranscriptMirrored ;
    
  ------------------------------------------------------------
  procedure WriteLine(buf : inout line) is 
  ------------------------------------------------------------
  begin
    if not TranscriptEnable.Get then
      WriteLine(OUTPUT, buf) ; 
    elsif TranscriptMirror.Get then
--      TEE(TranscriptFile, buf) ; -- not supported in Cadence Incisive
      WriteLine(OUTPUT, buf) ; 
      WriteLine(TranscriptFile, buf) ; 
    else
      WriteLine(TranscriptFile, buf) ; 
    end if ; 
  end procedure WriteLine ; 

  ------------------------------------------------------------
  procedure Print(s : string) is 
  ------------------------------------------------------------
    variable buf : line ; 
  begin
    write(buf, s) ; 
    WriteLine(buf) ; 
  end procedure Print ; 

end package body TranscriptPkg ;
