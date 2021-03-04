UNIT ProDOS16;
INTERFACE
USES    Types;         { for the standard Memory types }

{ This file defines the interface to the ProDOS16.
  
  Version:      1.0
  
  Based on Apple IIGS System Disk version 1.1
  
  Written by:   Tom Leonard
                TML Systems, Inc.
                4241 Baymeadows Rd., Suite 23
                Jacksonville, FL  32217
                
  Copyright (c) 1986,1987 by TML Systems, Inc. All Rights Reserved.

  This document is the property of and copyrighted by TML Systems, Inc.
  It may not be reproduced in any form without the express written
  permission of TML Systems except as allowed by your TML Pascal
  license agreement.  All permitted copies of this document must contain
  TML Systems, Inc. copyright notice.
}

CONST   noErr           = 0;
        eofErr          = 76;

TYPE    P16ParamBlk =
            record
               case integer of
{ File Housekeeping Calls }
                  0: { for Create, SetFileInfo and GetFileInfo }
                     (pathname1:        StringPtr;
                      access:           Integer;
                      fileType:         Integer;
                      auxType:          LongInt;
                      storageType:      Integer;        { only for Create }
                      createDate:       Integer;
                      createTime:       Integer;
                      modDate:          Integer;        { only for Set/GetFileInfo }
                      modTime:          Integer;        { only for Set/GetFileInfo }
                      blocksUsed:       LongInt);       { only for GetFileInfo }

                  1: { for Destroy }
                     (deletepathname:   StringPtr);

                  2: { for ChangePath }
                     (oldpathname:      StringPtr;
                      newpathname:      StringPtr);

                  3: { for Volume }
                     (devName:          StringPtr;
                      volName:          StringPtr;
                      totalBlocks:      LongInt;
                      freeBlocks:       LongInt;
                      fileSysId:        Integer);
                      
                  4: { for SetPrefix and GetPrefix }
                     (prefixNum:        Integer;
                      prefix:           StringPtr);
                      
                  5: { for ClearBackupBit }
                     (clearpathname:    StringPtr);
{ File Access Calls }
                  6: (refNum:           Integer;        { common field }
                      case integer of
                         0: { for Open }
                            (pathname2:         StringPtr;
                             ioBuffer:          Handle);
       
                         1: { for NewLine }
                            (enableMask:        integer;
                             newlineChar:       Char);
       
                         2: { for Read and Write }
                            (dataBuffer:        Ptr;
                             requestCount:      LongInt;
                             transferCount:     LongInt);
       
                         3: { for Close and Flush}
                            ( );
                            
                         4: { for SetMark and GetMark }
                            (position:          LongInt);
       
                         5: { for SetEof and GetEof }
                            (eof:               LongInt);
                     );

                  7: { for SetLevel and GetLevel }
                     (level:            Integer);
{ Device Calls }
                  8: { for GetDevNum }
                     (deviceName:       StringPtr;
                      deviceNum:        Integer);

                  9: { for ReadBlock and WriteBlock }
                     (devNum:           Integer;
                      blockBuffer:      Ptr;
                      blockNum:         LongInt);
{ Environment Calls }
                  10:{ for GetPathname and GetBootVol }
                     (pathName:         StringPtr);

                  11:{ for Quit }
                     (chainPath:        StringPtr;
                      returnFlag:       Integer;
                      futureUse:        Integer);
                      
                  12:{ for GetVersion }
                     (version:          Integer);
                     
{ Interrupt Control Calls }
                  13:{ for AllocInterrupt and DeallocInterrupt }
                     (intNum:           Integer;
                      intCode:          ProcPtr);
                     
            end;


{ File Housekeeping Calls }

PROCEDURE P16Create(var p: P16ParamBlk);               GSOS $1;
PROCEDURE P16Destroy(var p: P16ParamBlk);             GSOS $2;
PROCEDURE P16ChangePath(var p: P16ParamBlk);       GSOS $4;
PROCEDURE P16SetFileInfo(var p: P16ParamBlk);      GSOS $5;
PROCEDURE P16GetFileInfo(var p: P16ParamBlk);      GSOS $6;
PROCEDURE P16Volume(var p: P16ParamBlk);              GSOS $8;
PROCEDURE P16SetPrefix(var p: P16ParamBlk);          GSOS $9;
PROCEDURE P16GetPrefix(var p: P16ParamBlk);           GSOS $A;
PROCEDURE P16ClearBackupBit(var p: P16ParamBlk);   GSOS $B;

{ File Access Calls }

PROCEDURE P16Open(var p: P16ParamBlk);             GSOS $10;
PROCEDURE P16NewLine(var p: P16ParamBlk);       GSOS $11;
PROCEDURE P16Read(var p: P16ParamBlk);             GSOS $12;
PROCEDURE P16Write(var p: P16ParamBlk);           GSOS $13;
PROCEDURE P16Close(var p: P16ParamBlk);          GSOS $14;
PROCEDURE P16Flush(var p: P16ParamBlk);           GSOS $15;
PROCEDURE P16SetMark(var p: P16ParamBlk);       GSOS $16;
PROCEDURE P16GetMark(var p: P16ParamBlk);       GSOS $17;
PROCEDURE P16SetEof(var p: P16ParamBlk);         GSOS $18;
PROCEDURE P16GetEof(var p: P16ParamBlk);          GSOS $19;
PROCEDURE P16SetLevel(var p: P16ParamBlk);      GSOS $1A;
PROCEDURE P16GetLevel(var p: P16ParamBlk);      GSOS $1B;

{ Device Calls }

PROCEDURE P16GetDevNum(var p: P16ParamBlk);     GSOS $20;
PROCEDURE P16ReadBlock(var p: P16ParamBlk);      GSOS $22;
PROCEDURE P16Writeblock(var p: P16ParamBlk);     GSOS $23;

{ Environment Calls }

PROCEDURE P16GetPathname(var p: P16ParamBlk);    GSOS $27;
PROCEDURE P16GetBootVol(var p: P16ParamBlk);      GSOS $28;
PROCEDURE P16Quit(var p: P16ParamBlk);                  GSOS $29;
PROCEDURE P16GetVersion(var p: P16ParamBlk);      GSOS $2A;

{ Interrupt Control Calls }

PROCEDURE P16AllocInterrupt(var p: P16ParamBlk);        External;
PROCEDURE P16DeallocInterrupt(var p: P16ParamBlk);      External;

IMPLEMENTATION

END.
