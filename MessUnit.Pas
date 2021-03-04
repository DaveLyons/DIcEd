UNIT MessUnit;
{$LongGlobals+}
{
  PUBLIC DOMAIN      20-Sep-89      v1.1

  Easy-to-use interface for reading a list of pathnames
  passed to an application by the Finder or another
  program selector.  This list is passed in the Message
  Center as described in the Tool Locator chapter of
  the Toolbox Reference, Volume 2.

  Modified September 1989 for TML Pascal II.
  
  To use:
    Call InitReadMC with a valid memory ID.  If it returns
    -1, no message was available.  If InitReadMC returns 0
     or 1, then a list of pathnames is available.  0 means
     the application should OPEN the files, and 1 means it
     should PRINT them.
     
     Repeatedly call ReadNextMC to get a pathname. It
     returns FALSE when there are no more pathnames to
     get.  (To clarify, False means the PREVIOUS call gave
     you the last available pathname.)

     Even if you are going to accept only one pathname from
     the MessageCenter (not recommended), you should still
     call ReadNextMC until it returns FALSE.  Otherwise some
     memory will needlessly be left allocated.
     
     Tip:  Be sure to allow for people fiddling with their
     icon files!  Do NOT assume that any pathname given to
     you by the MessageCenter will specify a file of the
     type you expect--check.
     
     Also, don't assume that the volumes containing the files
     are necessarily online when your application is launched.
     You may need to ask the user to insert the correct disk.

  by David A. Lyons a.k.a. DAL Systems
}

INTERFACE

USES Types, Locator, Memory;

function  InitReadMC(id: integer): integer;
function  ReadNextMC(s: StringPtr): boolean;

IMPLEMENTATION
type
  myMessageRec = RECORD
    messageNext: longint;
    messageType: integer;
    messageData: integer;
    fileNames: packed array[1..32000] of char;
  END;
  MessagePtr = ^myMessageRec;
  MessageH = ^MessagePtr;

var
  MsgHand:  MessageH;
  MsgIndex: integer;

function InitReadMC(id: integer): integer;
var
  err: integer;
begin
  InitReadMC := -1;
  MsgIndex := 0;
  MsgHand := MessageH(NewHandle(0,id,attrNoCross,nil));
  MessageCenter(getMessage,1,MessageRecHndl(MsgHand));
  err := _ToolErr;
  MessageCenter(deleteMessage,1,nil);
  if err=0 then
    InitReadMC := MsgHand^^.messageData
  else
    DisposeHandle(handle(MsgHand));
end;

function ReadNextMC(s: StringPtr): boolean;
var
  len: integer;
begin
  s^ := '**********';
  ReadNextMC := false;
  len := ord(MsgHand^^.FileNames[MsgIndex]);
  if len<>0 then begin
    ReadNextMC := true;
    BlockMove(@MsgHand^^.FileNames[MsgIndex],ptr(s),len+1);
    MsgIndex := MsgIndex + len + 1;
  end else
    DisposeHandle(handle(MsgHand));
end;

END.
