{$CSEG Setup}
{$LongGlobals+}

UNIT dicedSetup;

INTERFACE

USES Types, Locator, Memory, MiscTool, QuickDraw, QDAux, Events, Controls,
     Windows, Menus, LineEdit, Dialogs, Scrap, StdFile, IntMath, Fonts, SANE,
     ProDOS16, GSOS, IconAccess, TMLUtils, CurUnit, Lists, Desk;

const
  MaxFT = 150;
  iconDataScrap = $4945;  { no official IconData scrap type }
  ilNext = 10;
  ilPrev = 11;
  ilEdit = 12;
  ilIcon = 14;
  ilSmallIcon = 15;
  ilText = 16;
  ICN = $CA;
   
  kIconList = $7771;  { icon list window }
  kIcon     = $7772;  { single icon edit window }
  kClipbd   = $7773;  { clipboard display window }
  kLayout   = $7774;  { multiple-icon layout--not used }
  kViewFile = $7775;  { view a text file }
  MaxStarts = 399;    { LineStarts array size }
  LineGroupSize = 5;
  LineHeight = 10;    { Eek!  A hard-coded font height. }

  AppleMenu   = 300;
    AboutItem    = 301;
    HelpItem     = 302;
    SpecialKItem = 303;
        
  FileMenu    = 400;
    QuitItem     = 401;
    NewItem      = 403;
    OpenItem     = 402;
    SaveItem     = 410;
    SaveAsItem   = 411;
    SaveSrcItem  = 412;
    CloseItem    = 255;
    CloseAllItem = 405;
    PrintTxtItem = 406;
    TransferItem = 450;

  EditMenu    = 500;
    UndoItem   = 250;
    CutItem    = 251;
    CopyItem   = 252;
    PasteItem  = 253;
    ClearItem  = 254;
    ShowCItem  = 506;

  IconMenu = 600;
    NewIconItem = 601;
    EditAtrItem = 650;
    ToMaskItem  = 611;
    ToImageItem = 612;
    fImageItem  = 691;
    fMaskItem   = 692;

  ViewMenu = 800;
    LargeItem   = 621;
    SmallItem   = 622;
    Fat1Item    = 625;
    Fat2Item    = 626;
    Fat3Item    = 627;
    Fat4Item    = 628;

  SpecialMenu = 900;
    NextWItem    = 901;
    DeleteItem   = 903;
    RenameItem   = 904;
    ViewTextItem = 905;
    PrintEnvItem = 906;
   
type
  FTMemRec = record
    memPtr: StringPtr;
    memFlag, t, x: integer;
  end;
  FTMemRecPtr = ^FTMemRec;

  DirEntryPtr = ^DirEntry;
  DirEntry = packed record
               filename:  String[15];
               filetype:  Byte;
             end;

  InfoPtr = ^InfoRec;
  InfoRec = record
    kind:      integer;
    dirty:     boolean;    { all kinds of windows }
    UndoInfo:  infoPtr;
    pathname:  String[128];
    wTitle:    String[40];
    DataH:     handle;     { icon or icon list }
    parent:    WindowPtr;  { window of file owning this icon }
    NumIcons:  integer;    { for lists only }
    CurrIcon:  integer;    { index into list--lists and edits }
    WhichIcon: string[30]; { #xxx of yyy }
    { more info? path, name, type, aux }
    SaveCtl, ColorCtl, FatCtl, MaskCtl, SpreadCtl: CtlRecHndl;
    FatGrowRect: rect;     { resize rect on FatCtl }
    LineStarts: array[0..MaxStarts] of integer; { for text files }
  end;

var
  FatWidth, FatHeight: integer;  
  ClipWind:       WindowPtr;
  MyID:           Integer;
  nwParms:        ParamList;
  StandardIconH:  handle;
  BigRect:        rect;
  info:           InfoPtr;  { ptr to info rec of front window }  
  currSize:       IconSize;
  ZoomRect, NewWinRect: rect;
  myReply:        SFReplyRec;
  FT:             array[1..MaxFT] of FTMemRec;
  NumTypes:       integer;
  MyWColors:      WindColor;

procedure Die;
function  StartupGSTools: boolean;
procedure ShutdownGSTools;
procedure SetupMenus;
procedure Death(code: integer; msg: StringPtr);
procedure BuildStdIcon;
procedure DoAbout;
procedure DrawFtype(ftype, aux: integer);
procedure InitClipWind;
procedure ShowClipboard;
function  DecNum(n: integer): string;
procedure DrawInt(n: longint; b, digs: integer);
function  NewInfoPtr(K: integer): InfoPtr;
procedure InvalWindow(w: WindowPtr);
procedure Note(s: Str255);
procedure ReportError(msg: str255; err: integer);
function  FrontIsNDA: boolean;
procedure MarkClean(w: WindowPtr);
procedure MarkDirty(w: WindowPtr);
function  FrontKind: integer;
function  CloseEverything: boolean;
function  CloseSomething(w: WindowPtr): boolean;
function  OkayToClose(w: WindowPtr): boolean;
procedure DoNextWindow;
procedure FiddleMenus;
procedure EnableEdits;
procedure SetDithColor(c: integer);


IMPLEMENTATION

const
   ScreenMode = $80;    { 640 mode }
   MaxX       = 640;        

var
  AppleMenuStr,
  FileMenuStr,
  EditMenuStr,
  IconStr,
  ViewStr,
  SpecialStr:     String;
  
  DithPatterns: array[0..15] of Pattern;

procedure MyWriteString(s: univ StringPtr); tool 12,28;
procedure MyDrawString(s: univ StringPtr);  tool 4,165;
{ function  AlertWindow(f:integer; sub:ptr; s:ptr): integer;
            tool 14,89; }
procedure SystemDeath( code: integer; msg: StringPtr );
            tool 3,21;

procedure SetDithColor(c: integer);
begin
  SetPenPat(DithPatterns[band(c,$0f)]);
end;

procedure Die;
var
  e: integer;
begin
  e := band($00ff,_ToolErr);
  if e<>0 then begin
    EMShutDown;
    SystemDeath(e,nil);
  end;
end;

procedure Death(code: integer; msg: StringPtr);
begin
  if band($00ff,code)<>0 then begin
    EMShutDown;
    SystemDeath(code,msg);
  end;
end;

function FrontKind: integer;
var
  fw: WindowPtr;
begin
  info := nil;
  fw := FrontWindow;
  if fw=nil then
    FrontKind := 0
  else
    if GetSysWFlag(fw) then
      FrontKind := 0
    else begin
      info := InfoPtr(GetWRefCon(fw));
      if info<>nil then
        FrontKind := info^.kind;
    end;
end;

procedure MarkDirty(w: WindowPtr);
var
  info: infoptr;
begin
  StartDrawing(w);
  info := infoptr(GetWRefCon(w));
  info^.dirty := true;
  if info^.kind = kIcon then
    HiliteControl(0,info^.SaveCtl);
  SetOrigin(0,0);
end;

procedure MarkClean(w: WindowPtr);
var
  info: infoptr;
begin
  StartDrawing(w);
  info := infoptr(GetWRefCon(w));
  info^.dirty := false;
  if info^.kind = kIcon then
    HiliteControl(255,info^.SaveCtl);
  SetOrigin(0,0);
end;

procedure DoNextWindow;
var
  fw: WindowPtr;
begin
  fw := FrontWindow;
  if fw<>nil then begin
    SendBehind(WindowPtr(-2),fw);
    SelectWindow(FrontWindow);
    InitCursor;
  end;
end;

{ OkayToClose -- returns true if window is Clean or user says
   it's ok to lose the changes }
function OkayToClose(w: WindowPtr): boolean;
var
  PrStr: string[70];
  Subst: array[1..1] of StringPtr;
  S: Str255;
begin
  OkayToClose := true;
  if GetSysWFlag(w) then begin
    info := infoptr(GetWRefCon(w));
    if info^.dirty then begin
      ArrowCur;
      PrStr := '33/Okay to lose changes to "*0"?/#2/^#3\0';
      BlockMove(ptr(GetWTitle(w)),@S,38);
    {  S := Copy(S,2,length(S)-2); }
      BlockMove(@S[2],@S[1],length(S)-2);
      s[0] := chr(ord(s[0])-2);
      Subst[1] := @S;
      if AlertWindow(1,@Subst,Ref(@PrStr[1]))=1 then
         OkayToClose := false;
    end;
  end;
end;

function ClosedChildren(w: WindowPtr): boolean;
var
  aWindow: WindowPtr;
  p: InfoPtr;
begin
  ClosedChildren := true;
  aWindow := GetFirstWindow;
  while aWindow<>nil do begin
    p := InfoPtr(GetWRefCon(aWindow));
    if p<>nil then begin
      if p^.kind = kIcon then
        if p^.parent = w then
          if not OkayToClose(aWindow) then begin
            ClosedChildren := false;
            aWindow := nil;
          end else begin
            if p^.UndoInfo<>nil then begin
              if p^.UndoInfo^.DataH<>nil then DisposeHandle(p^.UndoInfo^.DataH);
              DisposeHandle(FindHandle(ptr(p^.UndoInfo)));
            end;
            if p^.DataH<>nil then DisposeHandle(p^.DataH);
            DisposeHandle(FindHandle(ptr(p)));
            CloseWindow(aWindow); { Edit windows aren't dialogs }
          end;
    end;
    if aWindow<>nil then aWindow := GetNextWindow(aWindow);
  end;
end;

function CloseSomething(w: WindowPtr): boolean;
var
  p: InfoPtr;
  k: integer;
begin
  CloseSomething := true;
  if GetSysWFlag(w) then
    CloseNDAByWinPtr(w)
  else if w=ClipWind then
    HideWindow(ClipWind)
  else begin
    p := InfoPtr(GetWRefCon(w));
    k := p^.kind;
    if OkayToClose(w) then begin
      if ClosedChildren(w) then begin
        if p^.DataH<>nil then DisposeHandle(p^.DataH);
        if p^.UndoInfo<>nil then begin
          if p^.UndoInfo^.DataH<>nil then DisposeHandle(p^.UndoInfo^.DataH);
          DisposeHandle(FindHandle(ptr(p^.UndoInfo)));
        end;
        DisposeHandle(FindHandle(Ptr(p))); Die;
        if k=kIconList then
          CloseDialog(w)
        else
          CloseWindow(w);
      end else
        CloseSomething := false
    end else
      CloseSomething := false
  end;
end;

function CloseEverything: boolean;
var
  continue: boolean;
begin
  WatchCur;
  continue := true;
  while (FrontWindow<>nil) and continue do
    continue := CloseSomething(FrontWindow);
  CloseEverything := continue;
end;

procedure DrawInt(n: longint; b, digs: integer);
var
  s     : string[10];
  DigStr: String[17];
begin
  if n<0 then n := n + $10000;
  DigStr := '0123456789ABCDEF';
  s[0] := char(digs);
  while digs>0 do begin
    s[digs] := DigStr[(n mod b)+1];
    n := n div b;
    dec(digs);
  end;
  DrawString(s);
end;

function DecNum(n: integer): string;
var
  s: string[10];
  digs: integer;
begin
  digs := 3;
  s[0] := char(digs);
  while digs>0 do begin
    s[digs] := char((n mod 10)+ord('0'));
    n := n div 10;
    dec(digs);
  end;
  DecNum := s;
end;

function FrontIsNDA: boolean;
var
  w: WindowPtr;
begin
  FrontIsNDA := false;
  w := FrontWindow;
  if w<>nil then
    if GetSysWFlag(w) then
      FrontIsNDA := true;
end;

procedure InvalWindow(w: WindowPtr);
var
  p: GrafPortPtr;
begin
  p := GetPort;
  SetPort(w);
  InvalRect(BigRect);
  SetPort(p);
end;

procedure Note(s: Str255);
begin
  ArrowCur;
  s := concat('30/', s, '/^#0\0');
  if AlertWindow(1,nil,Ref(@s[1]))=0 then ;
end;

procedure ReportError(msg: str255; err: integer);
var
  txt: str255;
  HexErr: string[5];
  procedure MyInt2Hex(i:integer;s:univ ptr;L:integer); tool 11,34;
begin
  MyInt2Hex(err,@HexErr[1],4);  HexErr[0]:=chr(4);
  if err=$2b then txt := concat(msg,' (disk is write protected)')
  else if err=$27 then txt := concat(msg,' (disk error)')
  else if err=$45 then txt := concat(msg,' (disk not found)')
  else if err=$44 then txt := concat(msg,' (folder not found)')
  else if err=$4E then txt := concat(msg,' (file locked)')
  else if err=$40 then txt := concat(msg,' (bad file name)')
  else if err=$48 then txt := concat(msg,' (too many files on disk [not in folders])')
  else if err=$49 then txt := concat(msg,' (disk is full)')
  else txt := concat(msg,' (Error=',HexErr,')');
  Note(txt);
end;

function NewInfoPtr(K: integer): InfoPtr;
var
  p: InfoPtr;
begin
  p := InfoPtr(NewHandle(sizeof(InfoRec),MyID,attrBank+attrNoCross,nil)^);
    Die;
  fillchar(p^,sizeof(InfoRec),0);
  p^.kind := k;  
  NewInfoPtr := p;
end;

procedure tDie;
var
  e: integer;
begin
  e := _ToolErr;
  if e<>0 then begin
    EMShutDown;
    Death(e,@'DIcEd requires System Disk >=3.2! ');
  end;
end;

function CreateFontsDir: boolean;
var
  CreateStr: string[150];
  p: P16ParamBlk;
begin
  CreateFontsDir := true;
  p.pathname1 := @'*/system/fonts';
  P16GetFileInfo(p);
  if (_ToolErr=$44) or (_ToolErr=$46) then begin
    InitCursor;
    CreateStr := concat('32/There is no FONTS folder in your SYSTEM',
                        ' folder./^Create/Quit\0');
    if AlertWindow(1,nil,Ref(@CreateStr[1]))=1 then
      CreateFontsDir := false
    else begin
      with p do begin
        access      := $E3;
        fileType    := $0f;
        auxType     := 0;
        storageType := $0d;
        createDate  := 0;
        createTime  := 0;
      end;
      P16Create(p);
      if _ToolErr<>0 then CreateFontsDir := false;
    end;
  end;
end;

function StartUpGSTools: boolean;
var
  ZP: integer;
  ToolZP: handle;
  i, j, c: integer;
begin
  c := 0;
  for i := 0 to 15 do begin
    for j := 1 to 32 do
      DithPatterns[i][j] := c;
    c := c + $11;
  end;
  StartUpGSTools := true;
  TLStartUp;  Die;
  MyID := MMStartUp + $100;  Die;
  MTStartUp;

  ToolZP := NewHandle($900,MyID,attrBank+attrFixed+attrLocked,nil);
      Die;
  ZP := LoWord(longint(ToolZP^));

  QDStartUp(ZP,ScreenMode+$C000,160,MyID);  Die;
  EMStartUp(ZP+$300,20,0,MaxX,0,200,MyID);  Die;

 {  SetBackColor(0);  SetForeColor(15);       }
 {  MoveTo(12,12);    DrawString('Hang on!'); }

  { Now load RAM based tools }
  LoadOneTool(14,$202); tDie; { window mgr    }
  LoadOneTool(15,$201); tDie; { menu mgr      }
  LoadOneTool(16,$205); tDie; { control mgr   }
  LoadOneTool(18,$100); tDie; { qd aux        }
  LoadOneTool(20,$100); tDie; { line edit     }
  LoadOneTool(21,$101); tDie; { dialog mgr    }
  LoadOneTool(22,$100); tDie; { scrap mgr     }
  LoadOneTool(23,$101); tDie; { std file      }
  LoadOneTool(27,$100); tDie; { font manager  }
  LoadOneTool(28,$100); tDie; { list manager  }

  WindStartUp(MyID);         Die;
  RefreshDesktop(nil);       Die;
  CtlStartUp (MyID,ZP+$400); Die;
  MenuStartUp(MyID,ZP+$500); Die;
  ScrapStartUp;              Die;
  QDAuxStartup;              Die;
  LEStartUp(MyID,ZP+$600);   Die;
  DialogStartUp(MyID);       Die;
  ListStartup;               Die;
  if CreateFontsDir then begin
    FMStartUp(MyID,ZP+$800);   Die;
  end else begin
    StartUpGSTools := false;
    exit;
  end;
  SFStartUp(MyID,ZP+$700);   Die;
  DeskStartUp;               Die;
end; { of StartUpGSTools }

procedure ShutDownGSTools;
begin
  DeskShutDown;     { Die; }
  SFShutDown;       { Die; }
  FMShutDown;       { Die; }
  ListShutDown;     { Die; }
  DialogShutDown;   { Die; }
  LEShutDown;       { Die; }
  ScrapShutDown;    { Die; }
  QDAuxShutdown;    { Die; }
  MenuShutDown;     { Die; }
  WindShutDown;     { Die; } 
  CtlShutDown;      { Die; }
  EMShutDown;       { Die; }
  QDShutDown;       { Die; }
  MTShutDown;       { Die; }
  MMShutDown(band($F0FF,MyID));  { Die; }
  TLShutDown;                      { Die; }
end; { of ShutDownGSTools}

procedure SetUpMenus;
var
  Height: Integer;
begin
  AppleMenuStr := concat(
    '>>@\XN300\0',
    '==About DIcEd...\N301\0',
    '==Special Keys...\N303\0',
    '==DIcEd Help\*?/N302\0',
    '==-\DN980\0',
    '.');

  FileMenuStr := concat(
    '>>  File  \N400\0',
    '==New\N403*Nn\0',
    '==Open...\N402*Oo\0',
    '==-\DN981\0',
    '==Close\N255*Kk\0',
    '==Close All\N405\0',
    '==Save\N410*Ss\0',
    '==Save As...\N411\0',
    '==Save As Source...\N412\0',
    '==-\DN983\0',
    '==Print Text (slot 1)\N406*Pp\0',
    '==-\DN984\0',
    '==Transfer to...\N450\0',
    '==Quit\N401*Qq\0',
    '.');
                           
  EditMenuStr   :=  concat('>>  Edit  \N500\0',
    '==Undo\*ZzN250\0',
    '==-\DN985\0',
    '==Cut\*XxN251\0',
    '==Copy\*CcN252\0',
    '==Paste\*VvN253\0',
    '==Clear\N254\0',
    '==-\DN986\0',
    '==Show Clipboard\N506\0',
    '.');

  IconStr := concat(
    '>>  Icon  \N600\0',
    '==New Icon\N601*Ii\0',
    '==Edit Attributes...\N650*Ee\0',
    '==-\DN987\0',
    '==Copy Image to Mask\N611\0',
    '==Copy Mask to Image\N612\0',
    '==Fill Image\N691\0',
    '==Fill Mask\N692\0',
    '.');

  ViewStr := concat(
    '>>  View  \N800\0',
    '==by Large Icon\N621\0',
    '==by Small Icon\N622\0',
    '==-\DN988\0',
    '==Plump Pixels\N625\0',
    '==Fat Pixels\N626\0',
    '==Fatter Pixels\N627\0',
    '==Mongo Pixels\N628\0',
    '.');

  SpecialStr := concat(
    '>>  Special  \N900\0',
    '==View text file...\N905\0',
    '==Delete file...\N903\0',
    '==Rename file...\N904\0',
    '==-\DN989\0',
    '==Next Window\*WwN901\0',
    '==-\DN990\0',
    '==Print Shareware Envelope\N906\0',
    '.');
                    
  SetMTitleStart(10);
  InsertMenu(NewMenu(@SpecialStr[1]),0);   Die;  { Special Menu }
  InsertMenu(NewMenu(@ViewStr[1]),0);      Die;  { View Menu }
  InsertMenu(NewMenu(@IconStr[1]),0);      Die;  { Icon Menu }
  InsertMenu(NewMenu(@EditMenuStr[1]),0);  Die;  { Edit Menu }
  InsertMenu(NewMenu(@FileMenuStr[1]),0);  Die;  { File Menu }
  InsertMenu(NewMenu(@AppleMenuStr[1]),0); Die;  { Apple Menu }
  FixAppleMenu(AppleMenu);  if FixMenuBar<>0 then;
  DrawMenuBar;
end;

procedure MyStuffHex(var p: ptr; s: Str255; num: integer);
var
  i: integer;
begin
  for i := 1 to num do begin
    StuffHex(p,s);
    p := ptr(longint(p)+(length(s) div 2));
  end;
end;

procedure BuildStdIcon;
var
  p: ptr;
begin
  StandardIconH := NewHandle($1A6,MyID,attrNoCross,nil); Die;
  HLock(StandardIconH);
  p := StandardIconH^;
  MyStuffHex(p,'A6010064000000000000000000000000',1);
  MyStuffHex(p,'00000000000000000000000000000000',3);
  MyStuffHex(p,'0000012A000000000000000000000000',1);
  MyStuffHex(p,'00000000000000008000100010000000',1);
  MyStuffHex(p,'0000000000FF0FFFFFFFFFFF0F0F0FFF',1);
  MyStuffHex(p,'FFFFFFFF0FF00FFFFFFFFFFF00000FFF',1);
  MyStuffHex(p,'FFFFFFFFFFF00FFFFFFFFFFFFFF00FFF',5);
  MyStuffHex(p,'FFFFFFFFFFF00000000000000000FFFF',1);
  MyStuffHex(p,'FFFFFFFFFF00FFFFFFFFFFFFFFF0FFFF',1);
  MyStuffHex(p,'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',6);
  MyStuffHex(p,'FFFFFFFFFFFFFFFFFFFFFFFFFFFF0000',1);
  MyStuffHex(p,'2000080008000000000F0FFFFFF00FFF',1);
  MyStuffHex(p,'FFF00FFFFFF00FFFFFF00FFFFFF00FFF',1);
  MyStuffHex(p,'FFF000000000FFFFFFF0FFFFFFFFFFFF',1);
  MyStuffHex(p,'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',1);
  MyStuffHex(p,'FFFFFFFFFFFF',1);
  HUnlock(StandardIconH);
end;

procedure DrawFreek;
var
  s: string[10];
begin
  s[9] := chr(0);
  Int2Dec(FreeMem div 1024,@s,9,false);
  DrawCString(@s);  DrawString('K free');
end;

procedure DoAbout;
var
  r:          Rect;
  s: string[50];
  aboutDlog:  DialogPtr;
  oldPort:    WindowPtr;
begin
  if WindowGlobal(1)<>0 then;
  oldPort := GetPort;
  SetRect(r,140,28,500,182);
  aboutDlog := NewModalDialog(r,true,0); Die;
  SetRect(r,130,130,210,145);
  NewDItem(aboutDlog,1,r,10,@'OK',0,0,nil); Die;
  SetBackColor(15); SetForeColor(0);
  SetPort(WindowPtr(aboutDlog));
  { title and version and date }
  SetTextFace(1);
    MoveTo(14,15);  DrawString('DIcEd');
  SetTextFace(0);
  DrawString('--Desktop Icon Editor v1.3p  [10-May-89]');
  s := 'Copyright David A. Lyons 1988-9';
  { copyright notice }
  MoveTo(72,30);  DrawString(s);
  MoveTo(72,30); TextBounds(@s[1],length(s),r);
  InsetRect(r,-4,-2);  SetPenSize(2,1);
  FrameRect(r);        SetPenSize(1,1);
  { decorative bar }
  SetDithColor(1);
  MoveTo(40,43); SetPenSize(1,3); Line(280,0); SetPenSize(1,1);
  SetSolidPenPat(3);
  { address }
  MoveTo(14,60);  DrawString('Shareware for $15 from:');
  MoveTo(14,75);  DrawString('DAL Systems');
  MoveTo(14,84);  DrawString('P.O. Box 875');
  MoveTo(14,93);  DrawString('Cupertino, CA 95015-0875');
  MoveTo(162,75); DrawString('CompuServe: 72177,3233');
  MoveTo(162,84); DrawString('GEnie mail: D.LYONS2');
  MoveTo(162,93); DrawString('America Online: Dave Lyons');
  MoveTo(25,113); DrawString('Try DIcEd free for ten days.  See help.');
  MoveTo(240,143); DrawFreeK;
  { wait for OK with arrow cursor }
  ArrowCur;
  repeat until ModalDialog(nil)=1;
  SetPort(oldPort);
  CloseDialog(aboutDlog); Die;
  if WindowGlobal(-2)<>0 then;
end;

procedure DrawFtype(ftype, aux: integer);
var
  i: integer;
  done: boolean;
begin
  i := 1;
  done := false;
  while not done do begin
    if i>NumTypes then
      done := true
    else
      if (ftype=FT[i].t) and (aux=FT[i].x) then
        done := true
      else
        inc(i);
  end;
  if i>NumTypes then begin
    DrawString('$');  DrawInt(ftype,16,4);
    DrawString('; ');
    DrawString('$');  DrawInt(aux,16,4);
  end else
    DrawString(FT[i].memPtr^);
end;

procedure UpdateClip;
var
  TextHand, IconHand: Handle;
  tLength, pLength, iLength, p: longint;
  PicHand: PicHndl;
  r: rect;
begin
  PicHand  := PicHndl(GetScrapHandle(picscrap));
  TextHand := GetScrapHandle(textscrap);
  IconHand := GetScrapHandle(iconDataScrap);
  pLength  := GetScrapSize(picscrap);
  if _ToolErr<>0 then pLength := 0;
  tLength := GetScrapSize(textscrap);
  if _ToolErr<>0 then tLength := 0;
  iLength := GetScrapSize(iconDataScrap);
  if _ToolErr<>0 then iLength := 0;
  EraseRect(BigRect);
  if iLength<>0 then begin
    p := longint(IconHand^);
    MoveTo(10,10); DrawString('Type=');
                   DrawFtype(intptr(p+82)^,intptr(p+84)^);
    MoveTo(10,22); DrawString('Name=');
                   MyDrawString(ptr(p+66));
    MoveTo(10,34); DrawString('Appl=');
                   MyDrawString(ptr(p+2));
    DrawIcon(QDIconRecordPtr(icGetIconFromData(IconHand,isLarge))^,0,10,50);
  end else if pLength<>0 then begin { draw picture }
    r := PicHand^^.PicFrame;
    OffsetRect(r,band(-r.left,$fffe),-r.top);
    OffsetRect(r,10,6);
    DrawPicture(PicHand,r);
  end else if tLength<>0 then begin
    SetForeColor(0); SetBackColor(15);
    HLock(TextHand);
    SetRect(r,10,6,10000,10000);
    if tLength>$800 then WaitCursor;
    LETextBox2(TextHand^,tLength,r,0);
    HUnlock(TextHand);
  end; { draw text }
end;

procedure InitClipWind;
begin
  fillchar(nwParms,sizeof(ParamList),0);
  with nwParms do begin
    paramLength     := sizeof(nwParms);
    wFrameBits       := $DD80;
    wTitle               := @' Clipboard ';
    wContDefProc   := @UpdateClip;
    SetRect(wPosition,400,110,600,185);
    wDataH           := 1000;
    wDataW           := 1000;
    wScrollVer       := 15;
    wScrollHor       := 40;
    wPlane           := WindowPtr(-1);
    wColor           := @MyWColors;
  end;
  ClipWind := NewWindow(nwParms);  Die;
  SetWRefCon(longint(NewInfoPtr(kClipbd)),ClipWind);
  SetOriginMask($fffe,ClipWind);   Die;
end;

procedure ShowClipboard;
begin
  SelectWindow(ClipWind);
  ShowWindow  (ClipWind);
end;

procedure mEnable(item: integer);
begin
  if band(GetMenuFlag(item),$0080)<>0 then begin
    SetMenuFlag($ff7f,item);
    DrawMenuBar;
  end;
end;

procedure mDisable(item: integer);
begin
  if band(GetMenuFlag(item),$0080)=0 then begin
    SetMenuFlag($0080,item);
    DrawMenuBar;
  end;
end;

procedure Enable(item: integer);
begin
  if band(GetMItemFlag(item),$0080)<>0 then
    SetMItemFlag($ff7f,item);
end;

procedure Disable(item: integer);
begin
  if band(GetMItemFlag(item),$0080)=0 then
    SetMItemFlag($0080,item);
end;

procedure SetMenu(item: integer; okay: boolean);
begin
  if okay then Enable(item) else Disable(item);
end;

procedure mSetMenu(item: integer; okay: boolean);
begin
  if okay then mEnable(item) else mDisable(item);
end;

procedure FiddleMenus;
var
  kind: integer;
  s, cliptext: longint;
begin
  kind := FrontKind;
  mSetMenu(IconMenu, (kind=kIconList) or (kind=kIcon));
  SetMenu(CloseItem,    FrontWindow<>nil);
  SetMenu(CloseAllItem, FrontWindow<>nil);
  SetMenu(SaveItem,     Kind=kIconList);
  SetMenu(SaveAsItem,   Kind=kIconList);
  SetMenu(SaveSrcItem,  Kind=kIconList);
  SetMenu(NewIconItem,  kind=kIconList);
  SetMenu(EditAtrItem,
      (kind=kIcon) or
      ((kind=kIconList) and (info^.currIcon<>0)));
  SetMenu(ToMaskItem,   kind=kIcon);
  SetMenu(ToImageItem,  kind=kIcon);
  SetMenu(fImageItem,   kind=kIcon);
  SetMenu(fMaskItem,    kind=kIcon);
  SetMenu(NextWItem,    FrontWindow<>nil);
  if FrontWindow=nil then begin
    Disable(UndoItem);  Disable(CutItem);
    Disable(CopyItem);  Disable(ClearItem);
    Disable(PasteItem);
  end;
  if kind=kIcon then begin
    Disable(PasteItem);  Disable(ClearItem);
    Disable(CutItem);
    Enable(CopyItem);    Enable(UndoItem);
  end else if kind=kIconList then begin
    Enable(UndoItem);
    SetMenu(CutItem,   info^.currIcon<>0);
    SetMenu(CopyItem,  info^.currIcon<>0);
    s := GetScrapSize(iconDataScrap);
    if _ToolErr<>0 then s := 0;
    SetMenu(PasteItem, s<>0);
    SetMenu(ClearItem, info^.currIcon<>0);
  end else if kind=kViewFile then begin
    Disable(UndoItem);  Disable(PasteItem);
    Disable(CutItem);   Disable(ClearItem);
    Enable(CopyItem);
  end else if kind=kClipbd then begin
    Disable(UndoItem);  Disable(CopyItem);  Disable(PasteItem);
    Disable(CutItem);   Disable(ClearItem);
  end;
  cliptext := 0;
  if kind=kClipbd then begin
    cliptext := GetScrapSize(textScrap);
    if _ToolErr<>0 then cliptext := 0;
  end;
  SetMenu(PrintTxtItem, (kind=kViewFile) or (cliptext<>0));
end;

procedure EnableEdits;
begin
  Enable(UndoItem);  Enable(CutItem);
  Enable(CopyItem);  Enable(ClearItem);
  Enable(PasteItem);
end;

END.
