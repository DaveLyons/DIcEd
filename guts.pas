UNIT Guts;
{$CSEG Guts}
{$LongGlobals+}

INTERFACE

USES Types, Locator, Memory, MiscTool, QuickDraw, QDAux, Events, Controls,
     Windows, Menus, LineEdit, Dialogs, Scrap, StdFile, IntMath, Fonts, SANE,
     ProDOS16, GSOS, IconAccess, TMLUtils, CurUnit, Lists, Desk, dicedSetup;

function  FindIconWind(TheW: windowptr; n: integer): WindowPtr;
procedure DoFatSize(info: InfoPtr; wind: WindowPtr;
                     hor, vert: integer);
procedure DoDataSize(info: InfoPtr; wind: WindowPtr);
procedure DoSpreadSize(info: InfoPtr);
procedure ResizeControls(w: WindowPtr; info: infoptr);
function  GoodLocation(h,v: integer): rect;
function  ColorCtl(msg: integer; val: longint;
                  ctlh: CtlRecHndl): longint;
function  LocatePixel(var r: rect; MouseX, MouseY: integer;
                     var x, y: integer): boolean;
function  FatCtl
  (msg: integer; val: longint; ctlh: CtlRecHndl): longint;
procedure NewListWindow;
function  SpreadCtl(msg: integer; val: longint;
                   ctlh: CtlRecHndl): longint;
procedure UpdateEdit;
procedure NewIconWindow(wind: WindowPtr; iconNum: integer;
                         IconHand: handle);
procedure ReadIconFile(info: InfoPtr);
function  WriteIconFile(info: infoptr; kind: integer): integer;
function  SaveSourceHow: integer;
procedure MyIconUserItem(dlog: WindowPtr; item: integer);
procedure HandIconLstDlog(dlog: WindowPtr; ditem: integer);
procedure HandleDlog(dlog: WindowPtr; ditem: integer);
procedure EditAttributes;
procedure UndoToHere(w: WindowPtr);
procedure DoUndo(w: WindowPtr);
procedure BlinkItem(i: integer);
procedure ShowTricks;

IMPLEMENTATION

var
  AttrIcon: ptr;
  FTypeListH, FTypeScrollH: CtlRecHndl;
  FTypeListRef, FTypeScrollRef: longint;
  FTypeList: ListRec;

procedure MyInt2Hex(i:integer; s:univ ptr; l:integer); tool 11,34;
function  MyHex2Int(s: univ ptr; l: integer): integer; tool 11,36;
procedure MyGetIText(dlg:DialogPtr; i:integer; s:univ ptr); tool 21,31;

procedure UndoToHere(w: WindowPtr);
var
  i, i2: infoptr;
begin
  i := infoptr(GetWRefCon(w));
  i2 := i^.UndoInfo;
  if i2<>nil then begin
    if i2^.DataH<>nil then DisposeHandle(i2^.DataH);
    DisposeHandle(FindHandle(ptr(i2)));
  end;
  i2 := infoPtr(NewHandle(GetHandleSize(FindHandle(ptr(i))),MyID,
                          attrFixed+attrNoCross,nil)^); Die;
  BlockMove(ptr(i),ptr(i2),sizeof(InfoRec));
  i2^.DataH := NewHandle(GetHandleSize(i^.DataH),MyID,
                         attrNoCross,nil); Die;
  HandToHand(i^.DataH,i2^.DataH,GetHandleSize(i^.DataH));
  i^.UndoInfo := i2;
  i2^.UndoInfo := i;
end;

procedure DoUndo(w: WindowPtr);
var
  i: infoptr;
begin
  i := infoptr(GetWRefCon(w));
  if i^.UndoInfo <> nil then begin
    i := i^.UndoInfo;
    SetWRefCon(longint(i),w);
    if i^.kind = kIcon then
      ResizeControls(w,i)
    else begin
      InvalWindow(w);
      SetPort(w);
      EraseRect(BigRect);
    end;
  end;
end;

function FatCtl
  (msg: integer; val: longint; ctlh: CtlRecHndl): longint;
var
  r: rect;
  height, width, row, col, c: integer;
  w: WindowPtr;
  info: InfoPtr;
  icon: ptr;
  oldcur: CursorPtr;
begin
  case msg of
     0: begin
          oldcur := GetCursorAdr;  WaitCursor;
          r := ctlh^^.ctlRect;
          w := WindowPtr(GetCtlRefCon(ctlh));
          info := infoptr(GetWRefCon(w));
          HLock(info^.DataH);
          icon := icGetIconFromData(info^.DataH,currSize);
          icGetIconDims(icon,width,height);
{ *** start of "slow.fatbits" *** }
          SetPenSize(FatWidth-2,1);
          if ctlh^^.CtrlFlag=0 then { main icon }
            for row := height-1 downto 0 do
              for col := width-1 downto 0 do begin
                c := icGetPixel(icon,col,row);
                if c<>15 then begin
                  SetDithColor(c);
                  MoveTo(r.left+FatWidth*col,r.top+FatHeight*row);
                  Line(0,FatHeight-2);
                end;
              end
          else begin { mask }
            SetDithColor(0);
            for row := height-1 downto 0 do
              for col := width-1 downto 0 do begin
                c := icGetPixel(icon,col,row+height);
                if c<>0 then begin
                  MoveTo(r.left+FatWidth*col,r.top+FatHeight*row);
                  Line(0,FatHeight-2);
                end;
              end;
          end;
          SetPenSize(1,1);
{ *** end of "slow.fatbits" *** }
          HUnlock(info^.DataH);  SetCursor(oldcur^);
        end;
    12: FatCtl := sizeof(CtlRec);
     4: FatCtl := 0; { dispose }
  end;
end;

function LocatePixel(var r: rect; MouseX, MouseY: integer;
                     var x, y: integer): boolean;
var
  pt: point;
begin
  pt.h := MouseX; pt.v := MouseY;
  x := (MouseX-r.left) div FatWidth;
  y := (MouseY-r.top) div FatHeight;
  LocatePixel := PtInRect(pt,r) and (x>=0) and (y>=0);
end;

function ColorCtl(msg:integer; val:longint; ctlh:CtlRecHndl):longint;
var
  x, y: integer;
  r, box: rect;
begin
  case msg of
     0, 9: begin  { draw, newValue }
          box := ctlh^^.ctlRect;
          box.right := box.right - 1;
          box.bottom := box.top + 15;
          SetDithColor(GetCtlValue(ctlh)); PaintRect(box);
          SetPenSize(2,1);
            SetDithColor(0); FrameRect(box);
          SetPenSize(1,1);
          for y := 0 to 7 do for x := 0 to 1 do begin
            SetRect(r,0,0,16,8);
            OffsetRect(r,16*x,16+8*y);
            OffsetRect(r,box.left,box.top);
            SetDithColor(y+8*x); PaintRect(r);
            SetDithColor(0);     SetPenSize(2,1);
            FrameRect(r);        SetPenSize(1,1);
          end;
        end;
     2: begin { testCtl }
          ColorCtl := 0;
          box := ctlh^^.ctlRect;
          for y := 0 to 7 do for x := 0 to 1 do begin
            SetRect(r,0,0,16,8);
            OffsetRect(r,16*x,16+8*y);
            OffsetRect(r,box.left,box.top);
            if PtInRect(Point(val),r) then
              ColorCtl := 32+(8*x)+y;
          end;
        end;
    12: ColorCtl := sizeof(CtlRec); { recSize }
     4: ColorCtl := 0; { dispCtl }
  end;
end;

procedure MyIconUserItem(dlog: WindowPtr; item: integer);
var
  IconPtr: ptr;
  info: InfoPtr;
  r: rect;
  which: IconSize;
  itype, iaux: integer;
  iname: String[20];
  ipath: String[70];
  wid, h: integer;
begin
  if item=ilSmallIcon then which := isSmall else which := isLarge;   
  info := InfoPtr(GetWRefCon(dlog));
  GetDItemBox(dlog,item,r);
  if which=isLarge then EraseRect(r);
  if info^.CurrIcon<>0 then begin
    IconPtr := icGetIconPtr(info^.DataH,info^.CurrIcon,which);
    DrawIcon(QDIconRecordPtr(IconPtr)^,0,r.left,r.top);
    if which=isLarge then begin
      icGetParms(icGetIconData(info^.DataH,info^.CurrIcon),
                 @iname,@ipath,itype,iaux);
      icGetIconDims(IconPtr,wid,h);
      OffsetRect(r,0,h+13);
      MoveTo(r.left,r.top);
      DrawString('Type='); DrawFType(itype,iaux);
      MoveTo(r.left,r.top+12);
      DrawString('Name='); DrawString(iname);
      MoveTo(r.left,r.top+24);
      DrawString('Appl='); DrawString(ipath);
    end;
  end;
end;

function GoodLocation(h,v: integer): rect;
var
  r: rect;
begin
  SetRect(r,0,0,h,v);
  OffsetRect(r,NewWinRect.left,NewWinRect.top);
  OffsetRect(NewWinRect,30,10);
  if NewWinRect.top>90 then SetRect(NewWinRect,60,35,100,100);
  GoodLocation := r;
end;

procedure BlinkItem(i: integer);
var
  c: CtlRecHndl;
begin
  c := GetControlDItem(FrontWindow,i);
  HiliteControl(1,c);
  HiliteControl(0,c);
end;

procedure HandIconLstDlog(dlog: WindowPtr; ditem: integer);
var
  info: InfoPtr;
  r: rect;
  w: WindowPtr;
begin
  SetPort(dlog);
  info := InfoPtr(GetWRefCon(dlog));
  if (ditem=ilIcon) or (ditem=ilSmallIcon) then
    if info^.currIcon<>0 then begin
      ditem := ilEdit;
      BlinkItem(ditem);
    end;
  if ditem=ilEdit then
  begin
    w := FindIconWind(dlog,info^.CurrIcon);
    if w<>nil then
      SelectWindow(w)
    else
      NewIconWindow(dlog,info^.CurrIcon,
                    icGetIcon(info^.DataH,info^.CurrIcon));
    UndoToHere(dlog);
  end;
  if ditem=ilNext then inc(info^.CurrIcon);
  if ditem=ilPrev then dec(info^.CurrIcon);
  if (ditem=ilNext) or (ditem=ilPrev) then begin
    GetDItemBox(dlog,ilIcon,r);      InvalRect(r);
    GetDItemBox(dlog,ilSmallIcon,r); InvalRect(r);
  end;
  if info^.CurrIcon > info^.NumIcons then
    info^.CurrIcon := info^.NumIcons;
  info^.WhichIcon := concat('#', DecNum(info^.CurrIcon),
                    ' of ', DecNum(info^.NumIcons) );
  SetIText(dlog,ilText,info^.WhichIcon);
  GetDItemBox(dlog,ilText,r);  InvalRect(r);
  if (info^.CurrIcon<=0) then
    HiliteControl(255,GetControlDItem(dlog,ilPrev))
  else
    HiliteControl(0,GetControlDItem(dlog,ilPrev));
  if (info^.CurrIcon>=info^.NumIcons) then
    HiliteControl(255,GetControlDItem(dlog,ilNext))
  else
    HiliteControl(0,GetControlDItem(dlog,ilNext));
  if (info^.CurrIcon=0) then
    HiliteControl(255,GetControlDItem(dlog,ilEdit))
  else
    HiliteControl(0,GetControlDItem(dlog,ilEdit));
end;

procedure HandleDlog(dlog: WindowPtr; ditem: integer);
begin
  info := InfoPtr(GetWRefCon(dlog));
  case info^.Kind of
    kIconList: HandIconLstDlog(dlog,ditem);
  end;
end;

procedure DoFatSize(info: InfoPtr; wind: WindowPtr;
                     hor, vert: integer);
var
  w, h: integer;
  r: rect;
begin
  if info^.FatCtl <>nil then DisposeControl(info^.FatCtl);
  if info^.MaskCtl<>nil then DisposeControl(info^.MaskCtl);
  icGetIconDims(icGetIconFromData(info^.DataH,currSize), w, h);
  SetRect(r,0,0,w*FatWidth,h*FatHeight);
  OffsetRect(r,hor,vert);
  OffsetRect(r,w*FatWidth+24,0);
  info^.MaskCtl :=
    NewControl(Wind,r,@'',1,0,0,0,@FatCtl,longint(Wind),nil);
  OffsetRect(r,-(w*FatWidth+24),0);
  info^.FatCtl :=
    NewControl(Wind,r,@'',0,0,0,0,@FatCtl,longint(Wind),nil);
  SetRect(r,0,0,10,5);
  OffsetRect(r,info^.FatCtl^^.ctlRect.right,info^.FatCtl^^.ctlRect.bottom);
  info^.FatGrowRect := r;
end;

procedure DoDataSize(info: InfoPtr; wind: WindowPtr);
var
  r: rect;
begin
  r := info^.SpreadCtl^^.ctlRect;
  UnionRect(r,info^.MaskCtl^^.ctlRect,r);
  UnionRect(r,info^.ColorCtl^^.ctlRect,r);
  SetDataSize(r.right+10,r.bottom+15,wind);
end;

procedure DoSpreadSize(info: InfoPtr);
var
  w, h: integer;
  r: rect;
begin
  icGetIconDims(icGetIconFromData(info^.DataH,currSize),w,h);
  r := info^.SpreadCtl^^.ctlRect;
  r.right  := r.left + 8*(8+2*w);
  r.bottom := r.top  + h + 2;
  info^.SpreadCtl^^.ctlRect := r;
end;

procedure ResizeControls(w: WindowPtr; info: InfoPtr);
begin
  if info^.kind=kIcon then begin
    StartDrawing(w);
    EraseRect(BigRect);
    InvalRect(BigRect);
    DoSpreadSize(info);
    DoFatSize(info,w,90,info^.SpreadCtl^^.ctlRect.bottom+14);
    MoveControl(info^.ColorCtl^^.ctlRect.left,
               info^.SpreadCtl^^.ctlRect.bottom+14,
               info^.ColorCtl);
    DoDataSize(info,w);
    SetOrigin(0,0);
  end;
end;

function FindIconWind(TheW: windowptr; n: integer): WindowPtr;
var
  w:    WindowPtr;
  info: infoptr;
begin
  FindIconWind := nil;
  w := FrontWindow;
  while w<>nil do begin
    if GetSysWFlag(w) then begin
      info := infoptr(GetWRefCon(w));
      if info^.kind = kIcon then
        if (info^.Parent=TheW) and (info^.CurrIcon=n) then
          FindIconWind := w;
    end;
    if w<>nil then w := GetNextWindow(w);
  end;
end;

procedure NewListWindow;
var
  ListWind: WindowPtr;
  r: rect;
  L: longint;
begin
  info := NewInfoPtr(kIconList);
  ListWind := NewModelessDialog(GoodLocation(350,107),' Untitled ',
                WindowPtr(-1), $dd80, longint(info), ZoomRect);
      Die;
  SetFrameColor(@MyWColors,ListWind);
  SetWRefCon(longint(info),ListWind);
  info^.DataH := NewHandle(28,MyID,attrNoCross,nil); Die;
  fillchar(info^.DataH^^,28,0);
  L := longint(info^.DataH^)+4; intptr(L)^ := 1; {v1.1.1}
  info^.NumIcons := 0;
  info^.CurrIcon := 0;
  SetRect(r,15,15,80,30);
  NewDItem(ListWind,ilPrev,r,buttonItem,@'Prev',0,0,nil); Die;
  OffsetRect(r,75,0);
  NewDItem(ListWind,ilNext,r,buttonItem,@'Next',0,0,nil); Die;
  OffsetRect(r,75,0);
  NewDItem(ListWind,ilEdit,r,buttonItem,@'Edit',0,1,nil); Die;
  SetRect(r,250,15,350,30);
  NewDItem(ListWind,ilText,r,statText+itemDisable,@'',0,0,nil);
    Die;
  SetRect(r,30,50,600,200);
  OffsetRect(r,150,0);
  NewDItem(ListWind,ilSmallIcon,r,userItem,@MyIconUserItem,
     0,0,nil);  Die;
  OffsetRect(r,-150,0);
  NewDItem(ListWind,ilIcon,r,userItem,@MyIconUserItem,0,0,nil);
    Die;
  ShowWindow(ListWind);
  HandleDlog(ListWind,0);
  UndoToHere(ListWind);
end;

function SpreadCtl(msg: integer; val: longint;
                   ctlh: CtlRecHndl): longint;
var
  r, r2: rect;
  mode, width, w, h: integer;
  iconH: handle;
  icon:  ptr;
  wind:  windowptr;
  info:  infoptr;
begin
  case msg of
    0: begin { drawCtl }
         wind  := windowptr(GetCtlRefCon(ctlh));
         info  := infoptr(GetWRefCon(wind));
         iconH := info^.DataH;
         HLock(iconH);
         icon := icGetIconFromData(iconH,currSize);
         icGetIconDims(icon,w,h);
         width := 6+2*w;
         r := ctlh^^.ctlRect;
         r.right := r.left + width + 2;
         SetDithColor(13);
         for mode := 0 to 7 do begin
           InsetRect(r,0,-1);
           PaintRect(r);
           InsetRect(r,0,1);
           DrawIcon(QDIconRecordPtr(icon)^,mode,r.left,r.top);
           OffsetRect(r,width+2,0);
         end;
         PenNormal;
         HUnlock(iconH);
       end;
    12: SpreadCtl := sizeof(CtlRec);
     4: SpreadCtl := 0; { dispose }
  end;
end;

procedure UpdateEdit;
var
  info: InfoPtr;
  ctlh: CtlRecHndl;
  r:    rect;
  h, w: integer;
  height, width: string[5];
begin
  info := infoptr(GetWRefCon(GetPort));
  SetPenSize(2,1);
  { frame the SpreadCtl }
  r := info^.SpreadCtl^^.ctlRect;
  InsetRect(r,-4,-2);
  FrameRect(r);
  { decorate the MaskCtl }
  ctlh := info^.MaskCtl;
  r := ctlh^^.ctlRect;
  r.top  := r.top-2;   r.bottom := r.bottom+1;
  r.left := r.left-3;  r.right  := r.right+1;
  FrameRect(r);
  MoveTo(r.left+5,r.top);
  DrawString('Mask');
  ctlh := info^.FatCtl;
  r := ctlh^^.ctlRect;
  r.top  := r.top-2;   r.bottom := r.bottom+1;
  r.left := r.left-3;  r.right  := r.right+1;
  FrameRect(r);
  MoveTo(r.left+5,r.top);
  DrawString('Image');
  SetSolidPenPat(0); SetPenSize(2,1);
  FrameRect(info^.FatGrowRect); SetPenSize(1,1);
  icGetIconDims(icGetIconFromData(info^.DataH,currSize),h,w);
  r := ctlh^^.ctlRect;
  width [2] := chr(0); Int2Dec(w,@width,2,false);
  height[2] := chr(0); Int2Dec(h,@height,2,false);
  MoveTo(r.left+5,r.bottom+10);
  DrawCString(@width); DrawString('x'); DrawCString(@height);
  DrawControls(GetPort);
end;

procedure NewIconWindow(wind: WindowPtr; iconNum: integer;
                         IconHand: handle);
var
  ListWind: WindowPtr;
  r: rect;
  wid, ht: integer;
begin
  info := NewInfoPtr(kIcon);
  info^.parent   := wind;
  info^.CurrIcon := iconNum;
  info^.DataH    := IconHand;
  info^.wTitle   := ' Edit Icon ';
  fillchar(nwParms,sizeof(ParamList),0);
  with nwParms do begin
    paramLength     := sizeof(nwParms);
    wFrameBits           := $DD80; {invisible}
    wTitle           := @info^.wTitle;
    wContDefProc     := @UpdateEdit;
    wPosition        := GoodLocation(375,120);
    wDataH           := 1000;
    wDataW           := 1000;
    wScrollVer       := 15;
    wScrollHor       := 40;
    wPlane           := WindowPtr(-1);
    wColor           := @MyWColors;
  end;
  Wind := NewWindow(nwParms);     Die;
  SetOriginMask($fffe,Wind);
  SetWRefCon(longint(info),Wind); Die;
  icGetIconDims(icGetIconFromData(info^.DataH,currSize),wid,ht);
  SetRect(r,0,0,8*(7+2*wid),ht+1);  OffsetRect(r,90,5);
  info^.SpreadCtl := NewControl(Wind,r,@'',0,0,0,0,@SpreadCtl,
                                longint(Wind),nil);
  HiliteControl(255,info^.SpreadCtl);
  DoFatSize(info,Wind,90,info^.SpreadCtl^^.ctlRect.bottom+14);
  { create color palette control }
  SetRect(r,0,0,33,83);
  OffsetRect(r,26,info^.FatCtl^^.ctlRect.top);
  info^.ColorCtl :=
    NewControl(Wind,r,@'',0,0,0,0,@ColorCtl,longint(info),nil);
  SetCtlValue(32+0,info^.ColorCtl); { black }
  SetRect(r,13,8,78,23);
  info^.SaveCtl :=
    NewControl(Wind,r,@'Save',0,0,0,0,nil{button},0,nil); Die;
  DoDataSize(info,wind);
  MarkClean(Wind);
  ShowWindow(Wind);
  UndoToHere(Wind);
end;

procedure ReadIconFile(info: InfoPtr);
var
  p, pSIZE: P16ParamBlk;
  myHand: handle;
begin
  WatchCur;
  p.pathname2 := @info^.pathname;
  P16Open(p);        Die;
  pSIZE.refnum := p.refnum;
  P16GetEof(pSIZE);  Die;
  myHand := info^.DataH;
  SetHandleSize(pSIZE.eof,myHand);
  HLock(info^.DataH);
  p.dataBuffer := myHand^;
  p.requestCount := pSIZE.eof;
  P16Read(p);   Die;
  HUnlock(info^.DataH);
  P16Close(p);  Die;
  info^.NumIcons := icCountIcons(myHand);
end;

function WriteIconF(info: infoptr): integer;
var
  p, pSIZE: P16ParamBlk;
  err: integer;
begin
  p.pathname1   := @info^.pathname;
  p.access      := $C3;
  p.fileType    := ICN;
  p.auxType     := 0;
  p.storageType := 1;
  p.createDate  := 0;
  p.createTime  := 0;
  P16Create(p);
  WriteIconF := _ToolErr;
  if (_ToolErr<>0) and (_ToolErr<>$47) then exit;
  p.pathname2 := @info^.pathname;
  P16Open(p);
  WriteIconF := _ToolErr; if _ToolErr<>0 then exit;
  { --- write the data to the file --- }
  HLock(info^.DataH);
  p.dataBuffer   := info^.DataH^;
  p.requestCount := GetHandleSize(info^.DataH);
  P16Write(p);
  err := _ToolErr;
  HUnlock(info^.DataH);
  { --- truncate file to what we just wrote --- }
  pSIZE.refnum := p.refnum;
  P16GetMark(pSIZE);
  P16SetEof(pSIZE);
  { --- close file --- }
  P16Close(p);
  WriteIconF := err; if err<>0 then exit;
  WriteIconF := _ToolErr; if _ToolErr<>0 then exit;
end;

function WriteAsC(info: infoptr): integer;
var
  p, pSIZE: P16ParamBlk;
  err, i, count, byte: integer;
  b1, b2, pp: longint;
  F: text;
  HexDig: string[17];
begin
  HexDig := '0123456789ABCDEF';
  rewrite(F,info^.pathname);
  WriteAsC := IOResult; if IOResult<>0 then exit;
  { --- write the data to the file --- }
  HLock(info^.DataH);
  for i := 1 to info^.NumIcons do begin
    b1 := longint(icGetIconPtr(info^.DataH,i,isLarge));
    b2 := longint(icGetIconPtr(info^.DataH,i,isSmall))-1;
    writeln(F,'static char Icon', i:1, '[] = {');
    for count := 0 to loword(b2-b1) do begin
      pp := b1+count;
      if (count mod 8) = 0 then begin
        if count<>0 then writeln(F);
        write(F,'  ');
      end;
      byte := band($00ff,intptr(pp)^);
      write(F, '0x',
               HexDig[(byte div 16)+1],
               HexDig[(byte mod 16)+1]);
      if count=loword(b2-b1) then
        writeln(F)
      else
        write(F, ', ');
    end;
    writeln(F,'};');
    writeln(F);
  end;
  HUnlock(info^.DataH);
  err := IOResult;
  Close(F);
  WriteAsC := err; if err<>0 then exit;
  WriteAsC := IOResult; if IOResult<>0 then exit;
end;

function WriteAsASM(info: infoptr): integer;
var
  p, pSIZE: P16ParamBlk;
  err, i, count, byte: integer;
  b1, b2, pp: longint;
  F: text;
  HexDig: string[17];
begin
  HexDig := '0123456789ABCDEF';
  rewrite(F,info^.pathname);
  WriteAsASM := IOResult; if IOResult<>0 then exit;
  { --- write the data to the file --- }
  HLock(info^.DataH);
  for i := 1 to info^.NumIcons do begin
    b1 := longint(icGetIconPtr(info^.DataH,i,isLarge));
    b2 := longint(icGetIconPtr(info^.DataH,i,isSmall))-1;
    writeln(F,'Icon', i:1, '     anop');
    for count := 0 to loword(b2-b1) do begin
      pp := b1+count;
      if (count mod 16) = 0 then begin
        if count<>0 then writeln(F,'''');
        write(F,'          dc    h''');
      end;
      byte := band($00ff,intptr(pp)^);
      write(F, HexDig[(byte div 16)+1],
               HexDig[(byte mod 16)+1]);
    end;
    writeln(F,'''');
    writeln(F);
  end;
  HUnlock(info^.DataH);
  err := IOResult;
  Close(F);
  WriteAsASM := err; if err<>0 then exit;
  WriteAsASM := IOResult; if IOResult<>0 then exit;
end;

function WriteAsMerlin(info: infoptr): integer;
var
  p, pSIZE: P16ParamBlk;
  err, i, count, byte: integer;
  b1, b2, pp: longint;
  F: text;
  HexDig: string[17];
begin
  HexDig := '0123456789ABCDEF';
  rewrite(F,info^.pathname);
  WriteAsMerlin := IOResult; if IOResult<>0 then exit;
  { --- write the data to the file --- }
  HLock(info^.DataH);
  for i := 1 to info^.NumIcons do begin
    b1 := longint(icGetIconPtr(info^.DataH,i,isLarge));
    b2 := longint(icGetIconPtr(info^.DataH,i,isSmall))-1;
    writeln(F,'Icon', i:1, ' equ *');
    for count := 0 to loword(b2-b1) do begin
      pp := b1+count;
      if (count mod 16) = 0 then begin
        if count<>0 then writeln(F);
        write(F,' hex ');
      end;
      byte := band($00ff,intptr(pp)^);
      write(F, HexDig[(byte div 16)+1],
               HexDig[(byte mod 16)+1]);
    end;
    writeln(F);
  end;
  HUnlock(info^.DataH);
  err := IOResult;
  Close(F);
  WriteAsMerlin := err; if err<>0 then exit;
  WriteAsMerlin := IOResult; if IOResult<>0 then exit;
end;

function WriteIconFile(info: infoptr; kind: integer): integer;
begin
  case kind of
    0: WriteIconFile := WriteIconF(info);
    1: WriteIconFile := WriteAsC(info);
    2: WriteIconFile := WriteAsASM(info);
    3: WriteIconFile := WriteAsMerlin(info);
  end;
end;

function SaveSourceHow: integer;
var
  dlg: DialogPtr;
  r: rect;
  hit: integer;
begin
  ArrowCur;
  if WindowGlobal(1)<>0 then;
  SetRect(r,160,40,410,150);
  dlg := NewModalDialog(r,true,0);
  {--- OK/Cancel buttons ---}
  SetRect(r,20,85,90,100);
  NewDItem(dlg,1,r,buttonItem,@'OK',0,0,nil);
  OffsetRect(r,140,0);
  NewDItem(dlg,2,r,buttonItem,@'Cancel',0,0,nil);
  {--- title ---}
  SetRect(r,20,15,200,26);
  NewDItem(dlg,3,r,statText+itemDisable,@'Save source for:',0,0,nil);
  {--- radio buttons ---}
  SetRect(r,40,35,200,47);
  NewDItem(dlg,11,r,radioItem,@'APW C',1,5,nil);
  OffsetRect(r,0,13);
  NewDItem(dlg,12,r,radioItem,@'APW/ORCA Assembler',0,5,nil);
  OffsetRect(r,0,13);
  NewDItem(dlg,13,r,radioItem,@'Merlin Assembler',0,5,nil);
  OffsetRect(r,0,13);
  {--- do the dialog ---}
  SaveSourceHow := -1;
  repeat
    hit := ModalDialog(nil);
    if hit>10 then SetDItemValue(1,dlg,hit);
  until (hit=1) or (hit=2);
  if hit=1 then
    if GetDItemValue(dlg,11)<>0 then SaveSourceHow := 1 else
    if GetDItemValue(dlg,12)<>0 then SaveSourceHow := 2 else
    if GetDItemValue(dlg,13)<>0 then SaveSourceHow := 3;
  CloseDialog(dlg);
  if WindowGlobal(-2)<>0 then;
end;

procedure DrawAttrIcon(dlg: dialogptr; item: integer);
var
  r: rect;
  w, h: integer;
begin
  GetDItemBox(dlg,item,r);
  icGetIconDims(AttrIcon,w,h);
  OffsetRect(r,(r.right-r.left) div 2 - w,
               (r.bottom-r.top-h) div 2);
  DrawIcon(QDIconRecordPtr(AttrIcon)^,0,band(r.left,$fffe),r.top);
end;

procedure ZeroRefCons;
begin
  SetCtlRefCon(0,FTypeListH);
  SetCtlRefCon(0,FTypeScrollH);
end;

procedure RestoreRefCons;
begin
  SetCtlRefCon(FTypeListRef,FTypeListH);
  SetCtlRefCon(FTypeScrollRef,FTypeScrollH);
end;

function MyFTypeFilter(dlg: dialogPtr; var ev: EventRecord; var item: longint): integer;
var
  ctrl: CtlRecHndl;
  s: string[10];
  mem: FTMemRecPtr;
begin
  MyFTypeFilter := 0;
  if ev.what=mouseDownEvt then begin
    if FindControl(ctrl,ev.where.h,ev.where.v,dlg)<>0 then;
    if (ctrl=FTypeListH) or (ctrl=FTypeScrollH) then begin
      RestoreRefCons;
      if TrackControl(ev.where.h,ev.where.v,procptr(-1),ctrl)<>0 then
        if ctrl=FTypeListH then begin
          mem := FTMemRecPtr(NextMember(nil,@FTypeList));
          if mem<>nil then begin
            s[0]:=chr(4);
            MyInt2Hex(mem^.t,@s[1],4);
            SetIText(dlg,8,s);
            MyInt2Hex(mem^.x,@s[1],4);
            SetIText(dlg,10,s);
          end;
      end;
      ZeroRefCons;
      MyFTypeFilter := 1;
    end;
  end;
end;

procedure EditInfo(icon: ptr);
var
  hit, itype, iaux: integer;
  iname: String[20];
  ipath: String[70];
  s: String[10];
  dlg: DialogPtr;
  r: rect;
  i: integer;
begin
  ArrowCur;
  if WindowGlobal(1)<>0 then;
  SetRect(r,14,45,626,150);
  dlg := NewModalDialog(r,true,0);
  SetPort(dlg);
  {--- OK button ---}
  SetRect(r,520,17,590,32);
  NewDItem(dlg,1,r,buttonItem,@'OK',0,0,nil);
  {--- Cancel button ---}
  OffsetRect(r,0,20);
  NewDItem(dlg,2,r,buttonItem,@'Cancel',0,0,nil);
  {--- Color check box ---}
  SetRect(r,520,57,590,72);
  NewDItem(dlg,50,r,checkItem,@'Color',0,0,nil);
  if icGetColorFlag(icGetIconFmDataP(icon,currSize)) then
    SetDItemValue(1,dlg,50);
  {--- application pathname ---}
  icGetParms(icon,@iname,@ipath,itype,iaux);
  SetRect(r,20,72,580,82);
  NewDItem(dlg,3,r,statText+itemDisable,
           @'Application pathname:',0,0,nil);
  SetRect(r,20,82,590,95);
  NewDItem(dlg,4,r,editLine+itemDisable,@'',63,0,nil);
  SetIText(dlg,4,ipath);
  {--- filename ---}
  SetRect(r,20,57,110,68);
  NewDItem(dlg,5,r,statText+itemDisable,@'Filename:',0,0,nil);
  SetRect(r,120,56,285,69);
  NewDItem(dlg,6,r,editLine+itemDisable,@'',15,0,nil);
  SetIText(dlg,6,iname);
  {--- aux type ---}
  SetRect(r,150,36,240,49);
  NewDItem(dlg,9,r,statText+itemDisable,@'aux type: $',0,0,nil);
  SetRect(r,240,35,285,48);
  NewDItem(dlg,10,r,editLine+itemDisable,@'',4,0,nil);
  {--- filetype ---}
  SetRect(r,150,11,240,22);
  NewDItem(dlg,7,r,statText+itemDisable,@'filetype: $',0,0,nil);
  SetRect(r,240,10,285,23);
  NewDItem(dlg,8,r,editLine+itemDisable,@'',4,0,nil);
  s[0]:=chr(4);
  MyInt2Hex(itype,@s[1],4);
  SetIText(dlg,8,s);
  MyInt2Hex(iaux,@s[1],4);
  SetIText(dlg,10,s);
  {--- icon item ---}
  SetRect(r,6,5,148,50);
  AttrIcon := icGetIconFmDataP(icon,currSize);
  NewDItem(dlg,11,r,userItem+itemDisable,@DrawAttrIcon,0,0,nil);
  {--- scrolling list of filetypes ---}
  SetRect(FTypeList.listRect,300,10,480,72);
  with FTypeList do begin
    listSize := NumTypes;
    listView := 6;
    listType := 2; { single-select Pascal strings }
    listStart := 1;
    listDraw := nil;
    listMemHeight := 10;
    listMemSize := sizeof(FTMemRec);
    listPointer := MemRecPtr(@FT[1]);
    listScrollClr := nil;
  end;
  FTypeListH     := CtlRecHndl(CreateList(dlg,@FTypeList));
  FTypeScrollH   := ListCtlRecHndl(FTypeListH)^^.ctlListBar;
  FTypeListRef   := GetCtlRefCon(FTypeListH);
  FTypeScrollRef := GetCtlRefCon(FTypeScrollH);
  if ResetMember(@FTypeList)<>nil then;
  for i := 1 to NumTypes do
    if (FT[i].t=itype) and (FT[i].x=iaux) then
      SelectMember(@FT[i],@FTypeList);
  ZeroRefCons;
  {--- do the modal dialog ---}
  repeat
    hit := ModalDialog(procptr(longint(@MyFTypeFilter)+$80000000));
    if hit=50 then SetDItemValue(1-GetDItemValue(dlg,50),dlg,50);
  until (hit=1) or (hit=2);
  if hit=1 then begin
    MyGetIText(dlg,6,@iname);
    MyGetIText(dlg,4,@ipath);
    MyGetIText(dlg,8,@s);
    itype := MyHex2Int(@s[1],ord(s[0]));
    MyGetIText(dlg,10,@s);
    iaux  := MyHex2Int(@s[1],ord(s[0]));
    icSetParms(icon, @iname, @ipath, itype, iaux);
    icSetColorFlag(icGetIconFmDataP(icon,currSize),
                   0<>GetDItemValue(dlg,50));
    CloseDialog(dlg);
    MarkDirty(FrontWindow);
    InvalWindow(FrontWindow);
    SetPort(FrontWindow);
    EraseRect(BigRect);
  end else
    CloseDialog(dlg);
  if WindowGlobal(-2)<>0 then;
  SetPort(FrontWindow);
end;

procedure EditAttributes;
var
  icon: ptr;
begin
  if FrontKind=kIcon then begin
    HLock(info^.DataH);
    UndoToHere(FrontWindow);
    icon := info^.DataH^;
    EditInfo(icon);
    HUnlock(info^.DataH);
  end else if FrontKind=kIconList then begin
    if FindIconWind(FrontWindow,info^.CurrIcon)<>nil then begin
      Note('This icon is already open in its own window.  Please edit its attributes there.');
    end else if info^.CurrIcon<>0 then begin
      HLock(info^.dataH);
      icon := icGetIconData(info^.DataH,info^.CurrIcon);
      UndoToHere(FrontWindow);
      EditInfo(icon);
      HUnlock(info^.dataH);
    end;
  end;
end;

procedure ShowTricks;
var
  r:          Rect;
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
  MoveTo(50,20); SetTextFace(1);
  DrawString('Special keys in Edit Icon windows');
  SetTextFace(0);
  MoveTo(14,40);  DrawString('Apple key:');
  MoveTo(40,51);    DrawString('click on a pixel to select a color');
  MoveTo(14,67);  DrawString('Shift key (Hand cursor):');
  MoveTo(40,78);    DrawString(' repositions icon or mask');
  MoveTo(14,94); DrawString('Option key (Bow-tie cursor):');
  MoveTo(40,105);   DrawString('click replaces all pixels of one');
  MoveTo(40,116);   DrawString('color with the current color');
  ArrowCur;
  repeat until ModalDialog(nil)=1;
  SetPort(oldPort);
  CloseDialog(aboutDlog);
  if WindowGlobal(-2)<>0 then;
end;

END.