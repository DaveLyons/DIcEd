{$LongGlobals+}
{$CSEG SFile}
UNIT SFileStuff;

INTERFACE

USES Types, Locator, Memory, MiscTool, QuickDraw, QDAux, Events, Controls,
     Windows, Menus, LineEdit, Dialogs, Scrap, StdFile, IntMath, Fonts, SANE,
     ProDOS16, GSOS, IconAccess, TMLUtils, CurUnit, Lists, Desk, DIcedSetup,
     Guts;

procedure ViewSomething;
procedure DoHelp;
procedure DoTransfer;
procedure DoRename;
procedure DoDelete;
procedure ExtractFname(path,name: stringptr);
function  GetFileType(path: stringptr): integer;
procedure ViewByName(name, path: stringptr);

IMPLEMENTATION

var
  sfItemList: array[1..9] of record
    id: integer;
    r: rect;
    kind: integer;
    title: StringPtr;
    v, f: integer;
    ref: longint;
  end;
  MyStdFileList: record
    bounds: rect;
    int1: integer;
    long1: longint;
    items: array[1..9] of ptr;
  end;

procedure MyGetIText(dlg:DialogPtr; i:integer; s:univ ptr); tool 21,31;

procedure nilSFproc(dlg: WindowPtr; var item: integer);
begin
end;

procedure MySFGetFile(xtra: stringptr; msg: str255;
                      var replyRec: SFReplyRec);
var
  i: integer;
  procedure mySFPGetFile(x,y:integer; msg: str255; proc, tList, template,
      hook: univ ptr;  replyrec: SFReplyRecPtr); tool $17, $0b;
begin
  SetRect(MyStdFileList.bounds,0,0,400,114);
  MyStdFileList.int1 := -1;
  MyStdFileList.long1 := 0;
  for i := 1 to 8 do begin
    MyStdFileList.items[i] := ptr(@sfItemList[i]);
    sfItemList[i].id := i;
    sfItemList[i].kind := buttonItem;
    sfItemList[i].v := 0;
    sfItemList[i].f := 0;
    sfItemList[i].ref := 0;
  end;
  MyStdFileList.items[9] := nil;
  with sfItemList[1] do begin
    SetRect(r,265,53,375,65);
    title := xtra;
  end;
  with sfItemList[2] do begin
    SetRect(r,265,71,375,83);
    title := @'Close';
  end;
  with sfItemList[3] do begin
    SetRect(r,265,27,375,39);
    title := @'Disk';
  end;
  with sfItemList[4] do begin
    SetRect(r,265,97,375,109);
    title := @'Cancel';
  end;
  with sfItemList[5] do begin
    SetRect(r,214,28,238,110);
    title := nil;
    f := 3;
    kind := scrollBarItem;
  end;
  with sfItemList[6] do begin
    SetRect(r,15{49},12,395,24);
    title := nil;
    kind := userItem;
  end;
  with sfItemList[7] do begin
    SetRect(r,15,28,215,110);
    title := nil;
    kind := userItem;
  end;
  with sfItemList[8] do begin
    SetRect(r,15,0,395,12);
    title := nil;
    kind := userItem+$8000;
  end;
  mySFPGetFile(120,35,msg,nil,SFTypeListPtr(nil),@MyStdFileList,
             @nilSFproc, @replyRec);
end;

procedure ExtractFname(path, name: stringptr);
var
  left, right, len: integer;
begin
  right := length(path^);
  if path^[right] = '/' then dec(right);
  left := right;
  while (left>0) and (path^[left]<>'/') do dec(left);
  if path^[left] = '/' then inc(left);
  len := right-left+1;
  BlockMove(@path^[left], @name^[1], len);
  name^[0] := chr(len);
end;

function  GetFileType(path: stringptr): integer;
var
  p: P16ParamBlk;
begin
  GetFileType := -1;
  p.pathname1 := path;
  P16GetFileInfo(p);
  if _ToolErr=0 then GetFileType := p.fileType;
end;

procedure UpdateView;
var
  r: rect;
  len: longint;
  p, ScanPtr: ptr;
  TxtIdx, LineLen, vPos, yLimit, y, i: integer;
  info: infoptr;
  H: handle;
begin
  info := InfoPtr(GetWRefCon(GetPort));
  H := info^.DataH;
  if H<>nil then begin
    HLock(H);
    p := H^;
    len := GetHandleSize(H);
    vPos := LoWord(longint(GetContentOrigin(GetPort)));
    vPos := vPos div LineHeight;
    i := vPos div LineGroupSize;
    if i<>0 then dec(i);
    y := LineHeight * (LineGroupSize * i + 1);
    GetPortRect(r);
    yLimit := r.bottom+LineHeight+2;
    if i>MaxStarts then i := MaxStarts;
    TxtIdx := info^.LineStarts[i];
    if TxtIdx<>-1 then
      while y<yLimit do begin
        MoveTo(6,y);  y := y + LineHeight;
        if TxtIdx<len then begin
          ScanPtr := ptr(longint(p)+TxtIdx);
          LineLen := scaneq(loword(len)-TxtIdx,$0D,ScanPtr^);
          DrawText(ptr(longint(p)+TxtIdx),LineLen);
          TxtIdx := TxtIdx + LineLen + 1;
        end;
      end;
    HUnlock(H);
  end;
end;

function ReadTextFile(path: StringPtr): handle;
var
  p, pSIZE: P16ParamBlk;
  myHand: handle;
begin
  ReadTextFile := nil;
  WatchCur;
  p.pathname2 := path;
  P16Open(p);
  if _ToolErr<>0 then exit;
  pSIZE.refnum := p.refnum;
  P16GetEof(pSIZE);  Die;
  myHand := NewHandle(pSIZE.eof, MyID, attrNoCross, nil);  Die;
  HLock(myHand);
  p.dataBuffer := myHand^;
  p.requestCount := pSIZE.eof;
  P16Read(p);   Die;
  HUnlock(myHand);
  P16Close(p);  Die;
  ReadTextFile := MyHand;
end;

procedure CalcLineStarts(info: infoPtr; w: windowptr);
var
  base, p, max, ScanPtr: ptr;
  i, line, LineLen: integer;
begin
  i := 0;  line := 0;
  p := info^.DataH^;
  base := p;
  max := ptr(longint(p)+GetHandleSize(info^.DataH));
  while(longint(p)<longint(max)) do begin
    if (line mod LineGroupSize) = 0 then begin
      if i<=MaxStarts then
        info^.LineStarts[i] := loword(longint(p)-longint(base));
      inc(i);
    end;
    ScanPtr := p;
    LineLen := scaneq(loword(longint(max)-longint(p)),$0d,ScanPtr^);
    p := ptr(longint(p) + LineLen+ 1);
    inc(line);
  end;
  SetDataSize(1000,LineHeight*LineGroupSize*(i+1),w);
  while i<=MaxStarts do begin
    info^.LineStarts[i] := -1;
    inc(i);
  end;
end;

procedure ViewByName(name, path: stringptr);
var
  Wind: WindowPtr;
  r: rect;
begin
  info := NewInfoPtr(kViewFile);
  info^.wTitle := concat(' ',name^, ' ');
  info^.pathname := path^;
  fillchar(nwParms,sizeof(ParamList),0);
  with nwParms do begin
    paramLength     := sizeof(nwParms);
    wFrameBits           := $DD80;
    wTitle           := @info^.wTitle;
    wContDefProc     := @UpdateView;
    wPosition        := GoodLocation(550,130);
    wDataH           := 10000;
    wDataW           := 550;
    wScrollVer       := 15;
    wScrollHor       := 40;
    wPlane           := WindowPtr(-1);
    wColor           := @MyWColors;
  end;
  Wind := NewWindow(nwParms);     Die;
  SetWRefCon(longint(info),Wind);
  info^.DataH := ReadTextFile(path);
  CalcLineStarts(info,Wind);
  SetPort(Wind);
  SetFontFlags(2);
  ShowWindow(Wind);
end;

procedure DoRename;
var
  p: P16ParamBlk;
  newp: String[16];
  dlg: DialogPtr;
  r: rect;
begin
  newp := '*****';
  MySFGetFile(@'Rename','Choose file to rename:',myReply);
  if myReply.good then begin
    newp := myReply.filename;
    { get new pathname }
    SetRect(r,120,40,520,65);
    dlg := NewModalDialog(r,true,0); Die;
    SetRect(r,235,5,310,20);
    NewDItem(dlg,1,r,buttonItem,@'OK',0,0,nil); Die;
    SetRect(r,325,5,385,20);
    NewDItem(dlg,2,r,buttonItem,@'Cancel',0,0,nil); Die;
    SetRect(r,10,7,90,18);
    NewDItem(dlg,3,r,statText+itemDisable,@'New name =',
             0,0,nil); Die;
    SetRect(r,90,6,220,19);
    NewDItem(dlg,4,r,editLine+itemDisable,@newp,15,0,nil); Die;
    if ModalDialog(nil)=1 then begin
      MyGetIText(dlg,4,@newp);
      { do the rename }
      p.oldpathname := @myReply.fullpathname;
      p.newpathname := @newp;
      P16ChangePath(p);
      if _ToolErr<>0 then
        ReportError('Error renaming file',_ToolErr);
    end; { OK clicked }
    CloseDialog(dlg);
  end;
end;

procedure DoDelete;
var
  p: P16ParamBlk;
  sub: array[1..1] of StringPtr;
  aStr: string[80];
begin
  MySFGetFile(@'Delete','Choose file to delete:',myReply);
  if myReply.good then begin
    aStr := '34@Permanently destroy "*0"?@^#2@#3\0';
    sub[1] := @myReply.fullpathname;
    if AlertWindow(1,@sub,Ref(@aStr[1]))=0 then begin
      p.deletepathname := @myReply.fullpathname;
      P16Destroy(p);
      if _ToolErr<>0 then
        ReportError('Error deleteing file',_ToolErr);
    end;
  end;
end;

procedure DoHelp;
begin
  ViewByName(@'DIcEd Help', @'1/diced.help');
end;

function ViewFilter(ent: DirEntryPtr): integer;
begin
  if (ent^.filetype=$04) or (ent^.filetype=$B0) then
    ViewFilter := 2
  else
    ViewFilter := 1;
end;

procedure ViewSomething;
var
  r: rect;
begin
  ArrowCur;
  SFAllCaps(false);
  if WindowGlobal(1)<>0 then;
  SFGetFile(120,35,'Choose text file to view:',@ViewFilter,
                   SFTypeListPtr(nil),myReply); Die;
  if WindowGlobal(-2)<>0 then;
  if myReply.good then
    ViewByName(@myReply.filename,@myReply.fullpathname);
end;

function ApplFilter(ent: DirEntryPtr): integer;
begin
  if (ent^.filetype=$B3) or (ent^.filetype=$FF) then
    ApplFilter := 2
  else
    ApplFilter := 1;
end;

procedure DoTransfer;
var
  H: handle;
  p: P16ParamBlk;
begin
  ArrowCur;
  SFAllCaps(false);
  if WindowGlobal(1)<>0 then;
  SFGetFile(120,35,'Choose next application:',@ApplFilter,
                   SFTypeListPtr(nil),myReply); Die;
  if WindowGlobal(-2)<>0 then;
  if myReply.good then
    if CloseEverything then begin
      ShutDownGSTools;
      H := FindHandle(GetWAP(0,10)); Die;
      SANEShutDown;
      DisposeHandle(H); Die;
      DisposeHandle(FindHandle(@p)); { dispose of stack }
      p.chainPath  := @myReply.Fullpathname;
      p.returnFlag := 0;
      p.futureUse  := 0;
      P16Quit(p);  Die;
    end;
end;

END.
