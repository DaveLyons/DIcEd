{$CSEG CurUnit}
{$LongGlobals+}

UNIT CurUnit;

INTERFACE

USES Types, Memory, QuickDraw, QDAux, GSOS, TMLUtils;
   
{ HOW TO USE THIS UNIT:
    Call BeginCursor to start building a cursor.  mode=128 for
    640 mode, 0 for 320 mode (just use GetMasterSCB if the current
    screen mode is the one you want)
    
    Call BuildCursor "height" times for the cursor image, then
    "height" more times for the mask.
    
    Call the FinishCursor function, which returns a pointer to
    the cursor.  The value returned can later be passed to
    SetCursor.  
}
procedure BeginCursor(mode, height, width, hotx, hoty, id: integer);
procedure BuildCursor(s: str255);
function  FinishCursor: CursorPtr;
procedure ArrowCur;
procedure PencilCur;
procedure WatchCur;
procedure PalmCur;
procedure ReplCur;
procedure InitCurUnit(id: integer);

IMPLEMENTATION

var
  curH: handle;
  flag640: boolean;
  w, Divisor: integer;
  hx, hy: integer; { hot spot of cursor }
  PixPerWord: integer;
  cursors: array[0..5] of CursorPtr;

procedure AppendData(h: handle; size: integer; data: univ ptr);
var
  oldsize: longint;
begin
  oldsize := GetHandleSize(h);
  SetHandleSize(oldsize+size,h);
  BlockMove(data, ptr(longint(h^)+oldsize), size);
end;

procedure BeginCursor(mode, height, width, hotx, hoty, id: integer);
begin
  curH := NewHandle(0, id, attrNoCross, nil);
  flag640 := band(mode,$80)<>0;
  hx := hotx;
  hy := hoty;
  if flag640 then PixPerWord := 8 else PixPerWord := 4;
  if flag640 then Divisor := 4 else Divisor := 16;
  w := (width div PixPerWord) + 1;
  if (width mod PixPerWord)<>0 then inc(w);
  AppendData(curH, sizeof(integer), @height);
  AppendData(curH, sizeof(integer), @w);
end;

function DigVal(c: char): integer;
begin
  if (c>='0') and (c<='9') then
    DigVal := ord(c)-ord('0')
  else
    if (c>='a') and (c<='f') then
      DigVal := ord(c)-ord('a')+10
    else
      if(c>='A') and (c<='F') then
        DigVal := ord(c)-ord('A')+10
      else
        DigVal := 0;
end;

function ByteSwap(x: integer): integer;
begin
  ByteSwap := ($100*band(x,$00ff)) + (band(x,$ff00) div $100);
end;

procedure BuildCursor(s: str255);
var
  OneLine:  array[0..63] of integer;
  i, j, word, fac, len: integer;
begin
  len := length(s);
  for i := 0 to 63 do OneLine[i] := 0;
  for i := 0 to w-2 do begin
    fac := $10000 div Divisor;
    word := 0;
    for j := PixPerWord*i+1 to PixPerWord*(i+1) do begin
      if j<=len then word := word + fac*DigVal(s[j]);
      fac := fac div Divisor;
    end;
    OneLine[i] := ByteSwap(word);
  end;
  AppendData(curH,w*2,@OneLine);
end;

function FinishCursor: CursorPtr;
begin
  AppendData(curH,sizeof(integer),@hy);
  AppendData(curH,sizeof(integer),@hx);
  HLock(curH);
  FinishCursor := CursorPtr(curH^);
end;

{ ---  Level 2 stuff: cursor usage --- }

procedure BuildAllCursors(id: integer);
begin
  WaitCursor;
  cursors[1] := GetCursorAdr;
  InitCursor;
  HideCursor;
  cursors[0] := GetCursorAdr;
  { build Pencil cursor }
  BeginCursor(GetMasterSCB,13,18,3,1,id);
  BuildCursor('000000000000000000');
  BuildCursor('003300000000000000');
  BuildCursor('003333000000000000');
  BuildCursor('003333330000000000');
  BuildCursor('003300003300000000');
  BuildCursor('003300000033000000');
  BuildCursor('000033000033000000');
  BuildCursor('000033000000330000');
  BuildCursor('000000330033330000');
  BuildCursor('000000333300003300');
  BuildCursor('000000003300003300');
  BuildCursor('000000003333330000');
  BuildCursor('000000000000000000');
  { --- mask --- }
  BuildCursor('033330000000000000');
  BuildCursor('333333000000000000');
  BuildCursor('333333330000000000');
  BuildCursor('333333333300000000');
  BuildCursor('333333333333000000');
  BuildCursor('333333333333330000');
  BuildCursor('003333333333330000');
  BuildCursor('003333333333333300');
  BuildCursor('000033333333333300');
  BuildCursor('000033333333333333');
  BuildCursor('000000333333333333');
  BuildCursor('000000333333333300');
  BuildCursor('000000033333333000');
  cursors[2] := FinishCursor;
  { build Palm cursor }
  BeginCursor(GetMasterSCB,12,26,10,1,id);
  BuildCursor('00000000000000000000000000');
  BuildCursor('00000000000033000000000000');
  BuildCursor('00000000333300333300000000');
  BuildCursor('00000033003300330033000000');
  BuildCursor('00003333003300330033330000');
  BuildCursor('00330033000000000033003300');
  BuildCursor('00330000330000000000003300');
  BuildCursor('00003300000000000000330000');
  BuildCursor('00000033000000000000330000');
  BuildCursor('00000000330000000033000000');
  BuildCursor('00000000330000000033000000');
  BuildCursor('00000000000000000000000000');
  { --- mask --- }
  BuildCursor('00000000000033000000000000');
  BuildCursor('00000000003333330000000000');
  BuildCursor('00000033333333333333000000');
  BuildCursor('00003333333333333333330000');
  BuildCursor('00333333333333333333333300');
  BuildCursor('33333333333333333333333333');
  BuildCursor('33333333333333333333333333');
  BuildCursor('00333333333333333333333300');
  BuildCursor('00003333333333333333333300');
  BuildCursor('00000033333333333333330000');
  BuildCursor('00000033333333333333330000');
  BuildCursor('00000033333333333333330000');
  cursors[3] := FinishCursor;
  { build Replace-color cursor }
  BeginCursor(GetMasterSCB,11,30,16,5,id);
  BuildCursor('000000000000000000000000000000');
  BuildCursor('003300000000000000000000003300');
  BuildCursor('003333000000000000000000333300');
  BuildCursor('003300330000000000000033003300');
  BuildCursor('003300003300000000003300003300');
  BuildCursor('003300000033000000330000003300');
  BuildCursor('003300003300000000003300003300');
  BuildCursor('003300330000000000000033003300');
  BuildCursor('003333000000000000000000333300');
  BuildCursor('003300000000000000000000003300');
  BuildCursor('000000000000000000000000000000');
  { mask }
  BuildCursor('003300000000000000000000003300');
  BuildCursor('333333000000000000000000333333');
  BuildCursor('333333330000000000000033333333');
  BuildCursor('333333333300000000003333333333');
  BuildCursor('333333333333000000333333333333');
  BuildCursor('333333333333000000333333333333');
  BuildCursor('333333333333000000333333333333');
  BuildCursor('333333333300000000003333333333');
  BuildCursor('333333330000000000000033333333');
  BuildCursor('333333000000000000000000333333');
  BuildCursor('003300000000000000000000003300');
  cursors[4] := FinishCursor;
end;

procedure MyCursor(cursor: CursorPtr);
begin
  if CursorPtr(cursor)<>GetCursorAdr then
    SetCursor(CursorPtr(cursor)^);
  ShowCursor;
end;

procedure ArrowCur;  begin MyCursor(cursors[0]) end;
procedure WatchCur;  begin MyCursor(cursors[1]) end;
procedure PencilCur; begin MyCursor(cursors[2]) end;
procedure PalmCur;   begin MyCursor(cursors[3]) end;
procedure ReplCur;   begin MyCursor(cursors[4]) end;

procedure InitCurUnit(id: integer);
begin
  BuildAllCursors(id);
end;

END.
