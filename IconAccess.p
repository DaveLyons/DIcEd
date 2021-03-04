{$CSEG IconAccess}
{$LongGlobals+}

UNIT IconAccess;      { Copyright 1988 David A. Lyons }
  
INTERFACE

uses Types, Memory, MiscTool, QuickDraw, QDAux;

type
  IconSize = ( isLarge, isSmall );
 { IntPtr = ^integer; }
  
procedure icStartUp(id: integer);
{ --- icon lists --- }
function  icCountIcons(h: handle): integer;
function  icGetIcon(h: handle; n: integer): handle;
procedure icDelIcon(h: handle; n: integer);
procedure icInsIcon(h: handle; after: integer; icon: handle);
function  icGetIconData(h: handle; n: integer): ptr;
function  icGetIconPtr(h: handle; n: integer; which: IconSize):
            ptr;
function  icVerify(h: handle): boolean; { returns true=repaired }
{ --- individual icons --- }
function  icGetIconFromData(h: handle; which: IconSize): ptr;
function  icGetIconFmDataP(icon: ptr; which: IconSize): ptr;
procedure icGetIconDims(icon: ptr; var x,y: integer);
procedure icSetIconDims(h: handle; siz: IconSize; x, y: integer);
procedure icShiftIcon(icon: ptr; dx, dy: integer; mask: boolean);
function  icGetPixel(icon: ptr; x, y: integer): integer;
procedure icSetPixel(icon: ptr; x, y, c: integer);
procedure icGetParms(icon: ptr; name, path: stringptr;
                     var typ, aux: integer);
procedure icSetParms(icon: ptr; name, path: stringptr;
                     typ, aux: integer);
procedure icSetColorFlag(icon: ptr; flag:boolean);
function  icGetColorFlag(icon: ptr): boolean;
procedure icPaintIcon(icon: ptr; mask: boolean;
             x, y, fatSize: integer);
           

IMPLEMENTATION

var
  icID: integer;
  icLocInfo: LocInfo;

function  AlertWindow(f:integer; sub:ptr; s:ptr): integer;
            tool 14,89;

procedure icStartUp(id: integer);
begin
  icID := id;
end;

function icVerify(h: handle): boolean;  { true = repaired file }
var
  L: longint;
  VerStr: string[130];
begin
  icVerify := false;
  L := longint(h^)+4;
  if intptr(L)^ <> 1 then begin
    InitCursor;
    VerStr := concat('34/This icon file''s header is damaged; the Finder will',
                     ' ignore the entire file./^Repair/Don''t Repair\0');
    if AlertWindow(1,nil,@VerStr[1])=0 then begin
      intptr(L)^ := 1;
      icVerify := true;
    end;
  end;
end;

function icCountIcons(h: handle): integer;
var
  n: integer;
  p: intptr;
begin
  n := 0;
  p := intptr(longint(h^)+26);
  while p^<>0 do begin
    p := intptr(longint(p)+p^);
    inc(n);
  end;
  icCountIcons := n;
end;

function icGetIconData(h: handle; n: integer): ptr;
var
  p: intptr;
begin
  p := intptr(longint(h^)+26);
  while (p^<>0) and (n>1) do begin
    p := intptr(longint(p)+p^);
    dec(n);
  end;
  if n>1 then p := nil;
  icGetIconData := ptr(p);
end;

function icGetIconPtr(h: handle; n: integer; which: IconSize): ptr;
var
  p: ptr;
begin
  p := ptr(longint(icGetIconData(h,n))+86);
  if which=isSmall then 
    p := ptr(longint(p)+8+2*intptr(longint(p)+2)^);
  icGetIconPtr := p;  
end;

function icGetIconFromData(h: handle; which: IconSize): ptr;
var
  p: ptr;
begin
  p := ptr(longint(h^)+86);
  if which=isSmall then 
    p := ptr(longint(p)+8+2*intptr(longint(p)+2)^);
  icGetIconFromData := p;
end;

function  icGetIconFmDataP(icon: ptr; which: IconSize): ptr;
var
  p: ptr;
begin
  p := ptr(longint(icon)+86);
  if which=isSmall then 
    p := ptr(longint(p)+8+2*intptr(longint(p)+2)^);
  icGetIconFmDataP := p;
end;

procedure icGetIconDims(icon: ptr; var x, y: integer);
begin
  x := intptr( longint(icon)+6 )^;
  y := intptr( longint(icon)+4 )^;
end;

function min(a, b: integer): integer;
begin
  if a<b then min := a else min := b;
end;

procedure icBlankOut(icon: ptr; x1, x2, y1, y2, c: integer);
var
  col, row: integer;
begin
  for col := x1 to x2 do
    for row := y1 to y2 do
      icSetPixel(icon,col,row,c);
end;

procedure icSetIconDims(h: handle; siz: iconSize; x, y: integer);
var
  oldx, oldy, row, col: integer;
  old:   handle;
  dSize, L, smallSize: longint;
  oldIcon, newIcon, smallAddr: ptr;
begin
HUnlock(h);
  x := band(x,$fffe);  { force width even }
  icGetIconDims(icGetIconFromData(h,siz),oldx,oldy);
  old := NewHandle(GetHandleSize(h),icID,attrNoCross,nil);
  if _ToolErr<>0 then SysFailMgr(_ToolErr,'icSetDims1');
  HandToHand(h,old,GetHandleSize(h));
  dSize := (x*y)-(oldx*oldy);
  L := longint(h^);  intptr(L)^ := intptr(L)^ + dSize;
  SetHandleSize(dSize+GetHandleSize(h),h);
  if _ToolErr<>0 then SysFailMgr(_ToolErr,'icSetDims2');
  { shift small icon if big one changed size }
  if siz=isLarge then begin
    smallAddr := icGetIconFromData(h,isSmall);
    smallSize := longint(old^)+GetHandleSize(old)-
                 longint(icGetIconFromData(old,isSmall));
    BlockMove(icGetIconFromData(old,isSmall),
              ptr(longint(smallAddr)+dSize),
              smallSize);
  end;
  { remap old pixels and fill rest with background color }
  oldIcon := icGetIconFromData(old,siz);
  newIcon := icGetIconFromData(h,siz);
  L := longint(newIcon)+6; intptr(L)^ := x;
  L := longint(newIcon)+4; intptr(L)^ := y;
  L := longint(newIcon)+2; intptr(L)^ := (x*y) div 2; { imSize }
  { copy image pixels }
  for row := 0 to min(oldy-1,y-1) do
    for col := 0 to min(oldx-1,x-1) do
      icSetPixel(newIcon,col,row,icGetPixel(oldIcon,col,row));
  icBlankOut(newIcon,oldx,x-1,0,y-1,$f);
  icBlankOut(newIcon,0,x-1,oldy,y-1,$f);
  { copy mask pixels }
  for row := 0 to min(oldy-1,y-1) do
    for col := 0 to min(oldx-1,x-1) do
      icSetPixel(newIcon,col,row+y,
                 icGetPixel(oldIcon,col,row+oldy));
  icBlankOut(newIcon,oldx,x-1,y,y-1+y,$0);
  icBlankOut(newIcon,0,x-1,oldy+y,y-1+y,$0);
  DisposeHandle(old);
end;

procedure icSetColorFlag(icon: ptr; flag: boolean);
var
  i: intptr;
begin
  i := intptr(icon);
  if flag then
    i^ := bor($8000,i^)
  else
    i^ := band($7fff,i^);
end;

function  icGetColorFlag(icon: ptr): boolean;
var
  i: intptr;
begin
  i := intptr(icon);
  icGetColorFlag := 0<>band($8000,i^);
end;

procedure icShiftIcon(icon: ptr; dx, dy: integer; mask: boolean);
var
  height, width,
  row, col, o, backcol: integer;
  origCur: CursorPtr;
begin
  origCur := GetCursorAdr;
  WaitCursor;
  icGetIconDims(icon,width,height);
  if mask then begin
    o := height; backcol := 0
  end else begin
    o := 0;      backcol := 15;
  end;
  { horizontal shifting }
  if dx>0 then begin
    for col := width-1 downto dx do
      for row := height-1 downto 0 do
        icSetPixel(icon,col,row+o,icGetPixel(icon,col-dx,row+o));
    for col := dx-1 downto 0 do
      for row := height-1 downto 0 do
        icSetPixel(icon,col,row+o,backcol);
  end else if dx<0 then begin
    dx := -dx;
    for col := 0 to width-dx-1 do
      for row := 0 to height-1 do
        icSetPixel(icon,col,row+o,icGetPixel(icon,col+dx,row+o));
    for col := width-dx to width-1 do
      for row := 0 to height-1 do
        icSetPixel(icon,col,row+o,backcol);
  end;
  { vertical shifting }
  if dy>0 then begin
    for row := height-1 downto dy do
      for col := width-1 downto 0 do
        icSetPixel(icon,col,row+o,icGetPixel(icon,col,row+o-dy));
    for row := 0 to dy-1 do
      for col := width-1 downto 0 do
        icSetPixel(icon,col,row+o,backcol);
  end else if dy<0 then begin
    dy := -dy;
    for row := 0 to height-1-dy do
      for col := 0 to width-1 do
        icSetPixel(icon,col,row+o,icGetPixel(icon,col,row+o+dy));
    for row := height-dy to height-1 do
      for col := 0 to width-1 do
        icSetPixel(icon,col,row+o,backcol);
  end;
  SetCursor(origCur^);
end;

function icGetPixel(icon: ptr; x, y: integer): integer;
var
  width, height, rowSize, i: integer;
  aByte: integer;
begin
  icGetIconDims(icon,width,height);
  if (x>=width) or (y>=(2*height)) then
    icGetPixel := $f
  else begin
    rowSize := 1+((width-1) div 2);
    aByte := intptr(longint(icon)+8+(rowSize*y) + (x div 2) )^;
    aByte := band($ff,aByte);
    if not odd(x) then aByte := aByte div 16;
    icGetPixel := band(15,aByte);
  end;
end;

procedure icSetPixel(icon: ptr; x, y, c: integer);
var
  width, rowSize, i: integer;
  aBytePtr: intptr;
begin
  width := intptr(longint(icon)+6)^;
  rowSize := 1+((width-1) div 2);
  aBytePtr := intptr(longint(icon)+8+(rowSize*y) + (x div 2) );
  if odd(x) then
    aBytePtr^ := bor(c,band(aBytePtr^,$fff0))
  else
    aBytePtr^ := bor(c*16,band(aBytePtr^,$ff0f));
end;

function icGetIcon(h: handle; n: integer): handle;
var
  icon: handle;
  ip: intptr;
begin
  ip := intptr(icGetIconData(h,n));
  icon := NewHandle(ip^, icID, attrNoCross, nil);
  BlockMove(ptr(ip),icon^,ip^);
  icGetIcon := icon;
end;

procedure icDelIcon(h: handle; n: integer);
var
  p1: ptr;
  hsize, delta: longint;
begin
  p1    := icGetIconData(h,n);
  delta := intptr(p1)^;
  hsize := GetHandleSize(h);
  BlockMove(ptr(longint(p1)+delta),p1,
            longint(h^)+hsize-longint(p1)-delta);
  SetHandleSize(hsize-delta,h);
  if _ToolErr<>0 then SysFailMgr(_ToolErr,'icDelIcon');
end;

procedure icInsIcon(h: handle; after: integer; icon: handle);
var
  p1: ptr;
  hsize, isize: longint;
begin
  HUnlock(h);
  hsize := GetHandleSize(h);
  isize := intptr(icon^)^;  { GetHandleSize(icon); }
  SetHandleSize(hsize+isize,h);
  if _ToolErr<>0 then SysFailMgr(_ToolErr,'icInsIcon');
  p1 := ptr(longint(icGetIconData(h,after+1)));
  BlockMove(p1,ptr(longint(p1)+isize),
            longint(h^)+hsize-longint(p1));
  HandToPtr(icon,p1,isize);
end;

procedure icGetParms(icon: ptr; name, path: univ ptr;
                     var typ, aux: integer);
begin
  BlockMove(ptr(longint(icon)+66),name,16);
  BlockMove(ptr(longint(icon)+2),path,64);
  typ := intptr(longint(icon)+82)^;
  aux := intptr(longint(icon)+84)^;
end;

procedure icSetParms(icon: ptr; name, path: stringptr; typ, aux: integer);
var
  p: longint;
begin
  if ord(name^[0])>15 then name^[0]:=chr(15);
  if ord(path^[0])>63 then path^[0]:=chr(63);
  BlockMove(ptr(name),ptr(longint(icon)+66),16);
  BlockMove(ptr(path),ptr(longint(icon)+2),64);
  p := longint(icon)+82;  intptr(p)^ := typ;
  p := longint(icon)+84;  intptr(p)^ := aux;
end;

procedure icPaintIcon(icon: ptr; mask: boolean;
             x, y, fatSize: integer);
begin
  { %%% }
end;

END.
