program DIcEd;
{
  View/print all icons in a file--Print Manager
  Use print manager to print text windows
  More descriptive window titles
}

{ Shareware. Copyright David A. Lyons 1988
Version 1.0 (released 18-Sep-88)
Version 1.1 (released 24-Oct-88)
  --can't edit icon #0 by clicking on icon area
  --GS/OS Finder 1.2 icon filetypes added
Version 1.1.1 (released 5-Dec-88)
Version 1.2 (released 25-Feb-89)
  --lots more filetypes added (Jan 89 filetype notes)
  --repairs files on open if header signature bad
  --creates FONTS directory if not present
  --beautified menus (dimmed dividing lines)
  --when saving, asks to save changed children first
}

{$LongGlobals+}

uses Types, Locator, Memory, QuickDraw, QDAux, Events, Controls, Lists,  MiscTool,
     IntMath, TextTool, Windows, Menus, LineEdit, Dialogs, Scrap, StdFile, Desk,
     ProDOS16, GSOS, PrintEnv, SANE, Fonts, MessUnit,
     IconAccess, TMLUtils, CurUnit, dicedSetup, Filetypes, Guts, SFileStuff;

var
  Done:      Boolean;
  Event:     EventRecord;
  QuitParms: P16ParamBlk;
  oldSC,
  msgKind,
  ftype:     integer;
  oldfront:  ptr;
  iPathname,
  iFname:    String[128];
  saneWAP:   ptr;
  
procedure SaveToParent(w: WindowPtr; info: InfoPtr); forward;

procedure DoKey(k: char; mods: integer);
begin
  if FrontKind=kIconList then
    case band(ord(k),$7f) of
      8: if info^.CurrIcon>0 then begin
           BlinkItem(ilPrev);
           if band(mods,appleKey)<>0 then begin
             info^.currIcon := 1;
             HandleDlog(FrontWindow,0);
             InvalWindow(FrontWindow);
           end else
             HandleDlog(FrontWindow,ilPrev);
         end;
     21: if info^.CurrIcon < info^.NumIcons then begin
           BlinkItem(ilNext);
           if band(mods,appleKey)<>0 then begin
             info^.currIcon := info^.NumIcons;
             HandleDlog(FrontWindow,0);
             InvalWindow(FrontWindow);
           end else
             HandleDlog(FrontWindow,ilNext);
         end;
     13: if info^.CurrIcon<>0 then begin
           BlinkItem(ilEdit);
           HandleDlog(FrontWindow,ilEdit);
         end;
    end;
end;

procedure CopyIcon(iconH: handle);
var
  PicH: PicHndl;
  r: rect;
  w, ht: integer;
  pixmap: ptr;
  oldPort: GrafPortPtr;
  tempStr: String[20];
  MyLocInfo: LocInfo;
  ppInfo: PaintParam;
  tempPort: GrafPort;
begin
  HLock(handle(iconH)); {added 10/20/89 MD when Dave thought of it}
  ZeroScrap;
  PutScrap(GetHandleSize(iconH),iconDataScrap,iconH^);
  HUnlock(handle(iconH)); {also added 10/20/89, 3 days after the 7.0 quake}
  { Put a PICT version on the clipboard, too! }
  icGetIconDims(icGetIconFromData(iconH,currSize),w,ht);
  SetRect(r,0,0,w*2,ht);
  oldPort := GetPort;
  OpenPort(@tempPort);  SetPort(@tempPort);
  with MyLocInfo do begin
    width := 88;
    pixmap := NewHandle(MyID,4400,$C000+attrNoCross,nil)^;
    ptrToPixImage := pixmap;
    portSCB := $80;
    SetRect(boundsRect,0,0,88*4,50);
  end;
  SetPortLoc(MyLocInfo);
  SetSolidPenPat(3); PaintRect(BigRect);
  DrawIcon(QDIconRecordPtr(icGetIconFromData(iconH,isLarge))^,0,0,0);
  PicH := OpenPicture(r);
  with ppInfo do begin
    ptrToSourceLocInfo  := @MyLocInfo;
    ptrToDestLocInfo  := @MyLocInfo;
    ptrToSourceRect := @r;
    ptrToDestPoint := PointPtr(@r);
    mode    := 0;
    maskHandle := handle(GetClipHandle);
  end;
  PaintPixels(ppInfo);
  ClosePicture;
  HLock(handle(PicH));     {added 10/20/89 MD when Dave thought of this,too}
  PutScrap(GetHandleSize(handle(PicH)),1{pict},ptr(PicH^));
  HUnLock(handle(PicH)); {10/20/89 MD}
  KillPicture(PicH);
  DisposeHandle(FindHandle(pixmap));
  ClosePort(@tempPort);
  SetPort(oldPort);
end;

function KillByIcon(TheW: WindowPtr; n: integer): boolean;
var
  w:    WindowPtr;
begin
  KillByIcon := true;
  w := FindIconWind(TheW,n);
  if w<>nil then
    if not CloseSomething(w) then
      KillByIcon := false;
end;

procedure AdjustNums(TheW: WindowPtr; n, delta: integer);
var
  w:    WindowPtr;
  info: infoptr;
begin
  w := FrontWindow;
  while w<>nil do begin
    if GetSysWFlag(w) then begin
      info := infoptr(GetWRefCon(w));
      if info^.kind = kIcon then
        if (info^.parent=TheW) and (info^.CurrIcon>n) then
          info^.CurrIcon := info^.CurrIcon + delta;
    end;
    if w<>nil then w := GetNextWindow(w);
  end;
end;

procedure ClearIcon(w: WindowPtr; info: InfoPtr;
                    h: handle; n: integer);
begin
  if KillByIcon(w,n) then begin
    UndoToHere(w);
    MarkDirty(w);
    icDelIcon(h,n);
    AdjustNums(w,n,-1);
    dec(info^.NumIcons);
    InvalWindow(w);
    HandleDlog(w,0);
  end;
end;

procedure PasteIcon(w: WindowPtr; info: InfoPtr;
                    h: handle; n: integer);
var
  iconH: handle;
  siz:   longint;
begin
  siz := GetScrapSize(iconDataScrap);
  if _ToolErr<>0 then siz := 0;
  if siz=0 then
    Note('No icon on clipboard; use Copy or Cut first.')
  else begin
    iconH := GetScrapHandle(iconDataScrap);
    icInsIcon(h,n,iconH);
    MarkDirty(w);
    AdjustNums(w,n,1);
    inc(info^.NumIcons);
    InvalWindow(w);
    HandleDlog(w,ilNext);
  end;
end;

procedure EditIconList(code: integer);
var
  info: InfoPtr;
  Icons: handle;
  iconH: handle;
begin
  info := InfoPtr(GetWRefCon(FrontWindow));
  Icons := info^.DataH;
  iconH := icGetIcon(Icons,info^.currIcon);
  case code of
    1: {undo} begin
         DoUndo(FrontWindow);
         HandleDlog(FrontWindow,0);
         InvalWindow(FrontWindow);
       end;
    2: {cut} if info^.CurrIcon=0 then
          SysBeep
        else begin
         CopyIcon(iconH);
         ClearIcon(FrontWindow,info,Icons,info^.CurrIcon);
       end;
    3: {copy}  if info^.CurrIcon=0 then
         SysBeep
       else
         CopyIcon(iconH);
    4: {paste} PasteIcon(FrontWindow,info,Icons,info^.CurrIcon);
    5: {clear} if info^.CurrIcon=0 then
         SysBeep
       else
         ClearIcon(FrontWindow,info,Icons,info^.currIcon);
  end;
  DisposeHandle(iconH);
end;

procedure EditSomething(code: integer);
var
  edited: boolean;
begin
  if FrontWindow=nil then exit;
  if GetSysWFlag(FrontWindow) then
    edited := SystemEdit(code)
  else if FrontKind=kViewFile then
    case code of
        1: { undo } ;
        2 { cut }, 3: { copy } begin
             ZeroScrap;
             PutScrap(GetHandleSize(info^.DataH),0,info^.DataH^);
           end;
        4: { paste };
        5: { clear };
    end
  else begin
    if FrontKind=kIconList then
      EditIconList(code)
    else if FrontKind=kIcon then
      case code of
        1: { undo } begin
             DoUndo(FrontWindow);
             InvalWindow(FrontWindow);
           end;
        2: note('Can''t Cut an Edit Icon window.');
        3: CopyIcon(info^.DataH);
        4: note('Can''t Paste to an Edit Icon window.');
        5: note('Can''t Clear an Edit Icon window.');
      end;
  end;
end;

procedure OpenByName(name: stringptr; path: stringptr);
begin
  WatchCur;
  NewListWindow;
  if FrontKind<>0 then;
  info^.wTitle := concat(' ',name^,' ');
  SetWTitle(info^.wTitle,FrontWindow);  Die;
  info^.pathname := path^;
  ReadIconFile(info);
  info^.dirty := icVerify(info^.DataH);
  if info^.NumIcons>0 then info^.CurrIcon  := 1;
  UndoToHere(FrontWindow);
  HandleDlog(FrontWindow,0);
end;

function MyFilter(ent: DirEntryPtr): integer;
begin
  if ent^.filetype=ICN then
    MyFilter := 2
  else
    MyFilter := 1;
end;

procedure OpenSomething;
var
  r: rect;
begin
  ArrowCur;
  SFAllCaps(false);
  if WindowGlobal(1)<>0 then;
  SFGetFile(120,35,'Open what Icon file:',@MyFilter,
                   SFTypeListPtr(nil),myReply); Die;
  if WindowGlobal(-2)<>0 then;
  if myReply.good then OpenByName(@myReply.filename,@myReply.fullpathname);
end;

function GetSaveAsName(info: infoptr; kind: integer): boolean;
var
  dflt: String[20];
begin
{  dflt := copy(info^.wTitle,2,length(info^.wTitle)-2);  }
  BlockMove(@info^.wTitle[2], @dflt[1], length(info^.wTitle)-2);
  dflt[0] := chr(length(info^.wTitle)-2);
  {...ick...}
  case kind of
    1: dflt := concat(dflt, '.c');
    2: dflt := concat(dflt, '.asm');
    3: dflt := concat(dflt, '.s');
  end;
  SFPutFile(120,35,'Save Icon file as:',dflt,16,myReply);
    Die;
  GetSaveAsName := myReply.good;
  if myReply.good then begin
    if kind=0 then begin
      info^.wTitle := concat(' ',myReply.filename,' ');
      SetWTitle(info^.wTitle,FrontWindow);  Die;
    end;
    info^.pathname := myReply.fullpathname;
  end;
end;

function NumDirtyChildren(parent: WindowPtr): integer;
var
  aWindow: WindowPtr;
  p: InfoPtr;
  count: integer;
begin
  count := 0;
  aWindow := GetFirstWindow;
  while aWindow<>nil do begin
    p := InfoPtr(GetWRefCon(aWindow));
    if p<>nil then
      if p^.kind = kIcon then
        if p^.parent = parent then
          if p^.dirty then
            inc(count);
    aWindow := GetNextWindow(aWindow);
  end;
  NumDirtyChildren := count;
end;

procedure SaveTheChildren(parent: WindowPtr);
var
  aWindow: WindowPtr;
  p: InfoPtr;
  SaveStr: string[130];
begin
  SaveStr := concat('33/Save icons back to parent window before saving ',
                    'the file?/^Save Them/Don''t Save\0');
  if AlertWindow(1,nil,Ref(@SaveStr[1]))=1 then exit;

  aWindow := GetFirstWindow;
  while aWindow<>nil do begin
    p := InfoPtr(GetWRefCon(aWindow));
    if p<>nil then
      if p^.kind = kIcon then
        if p^.parent = parent then
          SaveToParent(aWindow,p);
    aWindow := GetNextWindow(aWindow);
  end;
end;

procedure DoSave(AsFlag: boolean; kind: integer);
var
  err: integer;
  thePath: string[128];
begin
  if FrontKind<>kIconList then exit;
  if kind=-1 then exit;  { in case SaveSourceHow cancelled?}
  if NumDirtyChildren(FrontWindow)<>0 then
    SaveTheChildren(FrontWindow);
  thePath := info^.pathname;
  if (length(info^.pathname)=0) or AsFlag then
    if not GetSaveAsName(info,kind) then exit;
  if length(info^.pathname)<>0 then begin
    WatchCur;
    err := WriteIconFile(info,kind);
    if err=0 then begin
      if kind=0 then MarkClean(FrontWindow);
    end else
      ReportError('Unable to save file', err);
  end;
  if kind<>0 then info^.pathname := thePath;
end;

procedure DoNewIcon;
var
  w: WindowPtr;
begin
  w := FrontWindow;
  if FrontKind=kIconList then begin
    MarkDirty(w);
    icInsIcon(info^.DataH,info^.CurrIcon,StandardIconH);
    AdjustNums(FrontWindow,info^.CurrIcon,1);
    inc(info^.NumIcons);
    InvalWindow(w);
    HandleDlog(w,ilNext);
  end;
end;

procedure SetIconSize(Size: IconSize);
var
  w: WindowPtr;
begin
  currSize := Size;
  CheckMItem( Size=isSmall, SmallItem);
  CheckMItem( Size=isLarge, LargeItem);
  { inval all open edit windows }
  w := FrontWindow;
  while w<>nil do begin
    if GetSysWFlag(w) then begin
      info := infoptr(GetWRefCon(w));
      if (info^.kind = kIcon) then
        ResizeControls(w,info);
    end;
    if w<>nil then w := GetNextWindow(w);
  end;
end;

procedure SetFatSize(item: integer);
var
  w: WindowPtr;
  i: integer;
begin
  case item of
    Fat1Item: begin FatWidth := 6; FatHeight := 3 end;
    Fat2Item: begin FatWidth := 8; FatHeight := 4 end;
    Fat3Item: begin FatWidth := 10; FatHeight := 5 end;
    Fat4Item: begin FatWidth := 14; FatHeight := 7 end;
  end;
  for i := Fat1Item to Fat4Item do
    CheckMItem(i=item, i);
  { inval all open edit windows }
  w := FrontWindow;
  while w<>nil do begin
    if GetSysWFlag(w) then begin
      info := infoptr(GetWRefCon(w));
      if (info^.kind = kIcon) then
        ResizeControls(w,info);
    end;
    if w<>nil then w := GetNextWindow(w);
  end;
end;

{$CSEG MoreMain}
procedure CopyOption(toImage: boolean);
var
  height, width, row, col, pix: integer;
  icon: ptr;
  r: rect;
begin
  if FrontKind<>kIcon then exit;
  WatchCur;
  UndoToHere(FrontWindow);
  HLock(info^.DataH);
  icon := icGetIconFromData(info^.DataH,currSize);
  icGetIconDims(icon,width,height);
  if toImage then begin { copy mask to image }
    for row := 0 to height-1 do
      for col := 0 to width-1 do begin
        pix := icGetPixel(icon,col,row+height);
        if pix<>0 then pix := 0 else pix := 15;
        icSetPixel(icon,col,row,pix);
      end;
  end else begin { copy image to mask }
    for row := 0 to height-1 do
      for col := 0 to width-1 do begin
        pix := icGetPixel(icon,col,row);
        if pix<>15 then pix := 15 else pix := 0;
        icSetPixel(icon,col,row+height,pix);
      end;
  end;
  HUnlock(info^.DataH);
  StartDrawing(FrontWindow);
  if not toImage then
    r := info^.MaskCtl^^.ctlRect
  else
    r := info^.FatCtl^^.ctlRect;
  InvalRect(r);
  EraseRect(r);
  InvalRect(info^.SpreadCtl^^.ctlRect);
  SetOrigin(0,0);
  MarkDirty(FrontWindow);
end;

procedure FillIcon(theMask: boolean);
var
  height, width, row, col, pix, offset: integer;
  icon: ptr;
  r: rect;
begin
  if FrontKind<>kIcon then exit;
  WatchCur;
  HLock(info^.DataH);
  icon := icGetIconFromData(info^.DataH,currSize);
  pix := GetCtlValue(info^.ColorCtl)-32;
  icGetIconDims(icon,width,height);
  offset := 0;
  if theMask then begin
    offset := height;
    if pix=0 then pix := 15 else pix := 0;
  end;
  for row := 0 to height-1 do
    for col := 0 to width-1 do
      icSetPixel(icon,col,row+offset,pix);
  HUnlock(info^.DataH);
  StartDrawing(FrontWindow);
  if theMask then
    r := info^.MaskCtl^^.ctlRect
  else
    r := info^.FatCtl^^.ctlRect;
  InvalRect(r);
  EraseRect(r);
  InvalRect(info^.SpreadCtl^^.ctlRect);
  SetOrigin(0,0);
  MarkDirty(FrontWindow);
end;

procedure ShiftFat(w:WindowPtr; ctl:CtlRecHndl; x,y:integer);
var
  r, limit, slop: rect;
  patt: pattern;
  i, deltaX, deltaY: integer;
  delta: longint;
begin
  UndoToHere(w);
  for i := 0 to 15 do patt[i] := $cccc;
  r := Ctl^^.ctlRect;
  limit := r;  InsetRect(limit,r.left-r.right,r.top-r.bottom);
  slop := limit;   InsetRect(slop,-20,-10);
  delta := DragRect(nil,patt,x,y,r,limit,slop,0);
  deltaX := hiword(delta);
  if deltaX<0 then
    deltaX := deltaX - (FatWidth div 2)
  else
    deltaX := deltaX + (FatWidth div 2);
  deltaX := deltaX div FatWidth;
  deltaY := loword(delta);
  if deltaY<0 then
    deltaY := deltaY - (FatHeight div 2)
  else
    deltaY := deltaY + (FatHeight div 2);
  deltaY := deltaY div FatHeight;
  icShiftIcon(icGetIconFromData(info^.DataH,currSize),
              deltaX,deltaY,ctl=info^.MaskCtl);
  StartDrawing(w); {v1.1.1}
  InvalRect(ctl^^.ctlRect);  EraseRect(ctl^^.ctlRect);
  InvalRect(info^.SpreadCtl^^.ctlRect);
  MarkDirty(w);
end;

procedure ResizeFat(info: infoptr; pt: point);
var
  r, limit, slop: rect;
  patt: pattern;
  i, h, w:    integer;
begin
  UndoToHere(FrontWindow);
  for i := 0 to 15 do patt[i] := $cccc;
  r := info^.FatCtl^^.ctlRect;
  icGetIconDims(icGetIconFromData(info^.DataH,currSize),w,h);
  SetRect(limit,(8-w)*FatWidth,(8-h)*FatHeight,(64-w)*FatWidth,(64-h)*FatHeight);
  SetRect(slop,-1000,-1000,1000,1000);
  if 0<>DragRect(nil,patt,pt.h,pt.v,r,limit,slop,$34) then ;
  WaitCursor;
  icSetIconDims(info^.DataH, currSize,
                band($fffe,(r.right-r.left) div FatWidth),
                (r.bottom-r.top) div FatHeight);
  ResizeControls(FrontWindow,info);
  MarkDirty(FrontWindow);
end;

procedure ReplaceColor(w: WindowPtr; x, y: integer);
var
  pixX, pixY, SearchCol, ReplCol, wid, h: integer;
  r: rect;
  icon: ptr;
  info: infoptr;
begin
  WatchCur;
  info := infoptr(GetWRefCon(w));
  UndoToHere(w);
  StartDrawing(w);
  r := info^.FatCtl^^.ctlRect;
  icon := icGetIconFromData(info^.DataH,currSize);
  icGetIconDims(icon,wid,h);
  if LocatePixel(r,x,y,pixX,pixY) then begin
    SearchCol := icGetPixel(icon,pixX,pixY);
    ReplCol   := GetCtlValue(info^.ColorCtl)-32;
    for pixY := 0 to h-1 do
      for pixX := 0 to wid-1 do
        if icGetPixel(icon,pixX,pixY)=SearchCol then
          icSetPixel(icon,pixX,pixY,ReplCol);
    MarkDirty(w);
    StartDrawing(w);  {v1.1.1}
    InvalRect(info^.SpreadCtl^^.ctlRect);
    InvalRect(r);
    EraseRect(r);
  end;
  SetOrigin(0,0);
end;

procedure DoPrintText;
var
  h: handle;
begin
  if (FrontKind<>kViewFile) and (FrontKind<>kClipbd) then exit;
  WatchCur;
  if FrontKind=kClipbd then begin
    h := GetScrapHandle(textScrap);
    if _ToolErr<>0 then exit;
  end else
    h := info^.DataH;
  SetOutputDevice(0,1);
  SetOutGlobals($7f,$00);
  InitTextDev(1);
  TextWriteBlock(h^,0,GetHandleSize(h));
  WriteChar(12);
  SetOutputDevice(0,3);
  InitTextDev(1);
end;

function DoQuit: boolean;
var
  QuitStr:  String[70];
begin
  DoQuit := false;
  ArrowCur;
  QuitStr := '23/Do you really want to quit DIcEd?/^Quit/Resume\0';
  if AlertWindow(1,nil,Ref(@QuitStr[1]))=0 then
    DoQuit := CloseEverything;
end;

procedure ProcessMenu(codeWord : Longint);
var
  menuNum, itemNum: Integer;
begin
  menuNum := HiWord(codeWord);
  itemNum := LoWord(codeWord);
  case itemNum of
    AboutItem:    DoAbout;
    HelpItem:     DoHelp;
    SpecialKItem: ShowTricks;
    NewItem:      NewListWindow;
    OpenItem:     OpenSomething;
    SaveItem:     DoSave(false,0);
    SaveAsItem:   DoSave(true,0);
    SaveSrcItem:  DoSave(true,SaveSourceHow);
    QuitItem:     Done := DoQuit;
    UndoItem:     EditSomething(1);
    CutItem:      EditSomething(2);
    CopyItem:     EditSomething(3);
    PasteItem:    EditSomething(4);
    ClearItem:    EditSomething(5);
    NextWItem:    DoNextWindow;
    CloseItem:    if CloseSomething(FrontWindow) then;
    CloseAllItem: if CloseEverything then;
    ShowCItem:    ShowClipboard;
    LargeItem:    SetIconSize(isLarge);
    SmallItem:    SetIconSize(isSmall);
    Fat1Item, Fat2Item, Fat3Item, Fat4Item: SetFatSize(itemNum);
    ToMaskItem:   CopyOption(false);
    ToImageItem:  CopyOption(true);
    NewIconItem:  DoNewIcon;
    EditAtrItem:  EditAttributes;
    fMaskItem:    FillIcon(true);
    fImageItem:   FillIcon(false);
    ViewTextItem: ViewSomething;
    RenameItem:   DoRename;
    DeleteItem:   DoDelete;
    TransferItem: DoTransfer;
    PrintTxtItem: DoPrintText;
    PrintEnvItem: begin WatchCur; PrintEnvelope end;
  end; { Case ItemNum }
  HiliteMenu(false,menuNum);
end;

procedure ChooseCursor(ev: EventRecord);
var
  cur: integer;
  pt: point;
begin
  cur := 0;
  if FrontKind=kIcon then begin
    StartDrawing(FrontWindow);
    pt := ev.where;  GlobalToLocal(pt);
    if PtInRect(pt,info^.FatCtl^^.ctlRect) or
       PtInRect(pt,info^.MaskCtl^^.ctlRect) then
      if PtInRgn(ev.where, GetContentRgn(FrontWindow)) then
        if band(ev.modifiers,shiftKey)<>0 then
          cur := 3
        else if (band(ev.modifiers,optionKey)<>0) and
                PtInRect(pt,info^.FatCtl^^.ctlRect) then
          cur := 4
        else
          cur := 1;
    SetOrigin(0,0);
  end;
  if not FrontIsNDA then
    case cur of
      0: ArrowCur;
      1: PencilCur;
      3: PalmCur;
      4: ReplCur;
    end;
end;

procedure HandleNull;
begin
  if GetScrapCount<>oldSC then begin
    StartDrawing(ClipWind);
    InvalRect(BigRect);
    SetOrigin(0,0);
  end;
  oldSC := GetScrapCount;
  FiddleMenus;
end; { HandleNull }

procedure SaveToParent(w: WindowPtr; info: InfoPtr);
var
  ListH: handle;
  parentInfo: InfoPtr;
begin
  ParentInfo := infoptr(GetWRefCon(info^.parent));
  UndoToHere(w);
  UndoToHere(info^.parent);
  ListH := handle(ParentInfo^.DataH);
  icDelIcon(ListH,info^.CurrIcon);
  icInsIcon(ListH,info^.CurrIcon-1,info^.DataH);
  MarkClean(w);
  InvalWindow(info^.parent);
  MarkDirty(info^.parent);
end;

procedure DrawPixel(r: rect; x, y, color: integer);
begin
  SetPenSize(FatWidth-2,1);
  SetDithColor(color);
  MoveTo(r.left+FatWidth*x,r.top+FatHeight*y);
  Line(0,FatHeight-2);
  SetPenSize(1,1);
end;

procedure ClickedFat(w: WindowPtr; ctlh: CtlRecHndl;
                     x, y: integer);
var
  pixX, pixY, oldx, oldy, color, color2, offset, dummy: integer;
  r: rect;
  icon: ptr;
  info: infoptr;
  pt: point;
  restoring: boolean;
begin
  info := infoptr(GetWRefCon(w));
  StartDrawing(w);
  r := ctlh^^.ctlRect;
  icon := icGetIconFromData(info^.DataH,currSize);
  if ctlh=info^.FatCtl then
    offset := 0
  else
    icGetIconDims(icon,dummy,offset);
  if LocatePixel(r,x,y,pixX,pixY) then begin
    color := GetCtlValue(info^.ColorCtl)-32;
    if offset<>0 then begin
      color := icGetPixel(icon,pixX,pixY+offset);
      color2 := 15-color;
    end else
      color2 := color;
    oldx := -1;  oldy := -1;
    restoring := (color = icGetPixel(icon,pixX,pixY+offset))
                 and (offset=0); { can't re-click to undo mask }
    if band(Event.modifiers,appleKey)<>0 then begin
      color := icGetPixel(icon,pixX,pixY+offset);
      if offset<>0 then
        if color=0 then color := 15 else color := 0;
      SetCtlValue(32+color,info^.ColorCtl);
      UndoToHere(w);
    end else begin
      repeat
        if LocatePixel(r,x,y,pixX,pixY) then begin
          if (pixX<>oldx) or (pixY<>oldY) then begin
            if restoring then begin
              color := icGetPixel(
                 icGetIconFromData(info^.UndoInfo^.DataH,currSize),
                 pixX,pixY+offset);
              color2 := color;
              if offset<>0 then color := 15-color2;
            end;
            DrawPixel(r,pixX,pixY,color);
            icSetPixel(icon,pixX,pixY+offset,color2);
          end;
          oldx := pixX; oldy := pixY;
        end;
      GetMouse(pt);  x := pt.h;  y := pt.v;
      until not Button(0);
      MarkDirty(w);
      StartDrawing(w);
      InvalRect(info^.SpreadCtl^^.ctlRect);
    end;
  end;
  SetOrigin(0,0);
end;

procedure CtrlWasHit(w: WindowPtr; Ctl: CtlRecHndl;
                     part: integer; e: EventRecord);
var
  info: InfoPtr;
begin
  info := infoptr(GetWRefCon(w));
  if Ctl=info^.SaveCtl then SaveToParent(w,info)
  else if Ctl=info^.ColorCtl then begin
    SetCtlValue(part,Ctl);
    UndoToHere(w);
  end else if (Ctl=info^.FatCtl) or (Ctl=info^.MaskCtl) then begin
    GlobalToLocal(e.where);
    if band(e.modifiers,shiftKey)<>0 then begin
      UndoToHere(w);
      ShiftFat(w,Ctl,e.where.h,e.where.v)
    end else
      if (Ctl=info^.FatCtl) and (band(e.modifiers,optionKey)<>0) then
        ReplaceColor(w,e.where.h,e.where.v)
      else
        ClickedFat(w,Ctl,e.where.h,e.where.v);
  end;
end;

procedure HandleClick(event: EventRecord);
var
  w: WindowPtr;
  Ctl: CtlRecHndl;
  x, y, part, c: integer;
begin
  w := WindowPtr(event.wmTaskData);
  StartDrawing(w);
  x := event.where.h;
  y := event.where.v;
  if FrontKind<>0 then ;  { force 'info' to be set }
  part := FindControl(Ctl,x,y,w);
  if part<>0 then begin
    if Ctl=info^.SaveCtl then
      part := TrackControl(x,y,nil,Ctl);
    if part<>0 then CtrlWasHit(w,Ctl,part,event);
  end else begin { not in control }
    GlobalToLocal(event.where);
    if PtInRect(event.where,info^.FatGrowRect) then
      ResizeFat(info,event.where);
  end; { not in control }
  SetOrigin(0,0);
end;

{$CSEG Main3}
procedure ActDeact(event: EventRecord);
begin
  info := InfoPtr(GetWRefCon(WindowPtr(event.message)));
  if info^.kind=kIcon then begin
    if odd(event.modifiers) and info^.dirty then
      HiliteControl(0,info^.SaveCtl)
    else
      HiliteControl(255,info^.SaveCtl);
    DrawOneCtl(info^.SaveCtl);
  end;
  if info^.kind=kIconList then
    DrawControls(WindowPtr(event.message));
end;

procedure MainEventLoop;
var
  code, ditem:  integer;
  dlog, w:  WindowPtr;
begin
  Event.wmTaskMask := $0fff; { no cRedraw, no handle edit items }
  repeat
    if (FrontWindow=nil) or (FrontWindow=WindowPtr(4)) then
      SetRect(NewWinRect,30,30,300,150);
    HandleNull;
    code := TaskMaster(-1, Event);  Die;
    ChooseCursor(Event);
    if ptr(FrontWindow) <> oldfront then begin
      if FrontIsNDA then EnableEdits;
    end;
    oldfront := ptr(FrontWindow);
    if code<>0 then
      if IsDialogEvent(Event) then
        if DialogSelect(Event,dlog,ditem) then
          HandleDlog(dlog,ditem);
    case code of
      { Event Manager Events }
 {     NullEvent: ;  }
      keyDownEvt, autoKeyEvt:
        DoKey(char(LoWord(Event.message)),Event.modifiers);
      activateEvt: ActDeact(event);
      $19, wInMenuBar: ProcessMenu(Event.wmTaskData);
      wInContent:   begin
        info := InfoPtr(GetWRefCon(WindowPtr(event.wmTaskData)));
        if info<>nil then
          if (info^.kind=kIcon) then
            HandleClick(Event);
      end;
      wInGoAway: if CloseSomething(FrontWindow) then;
    end;
  until Done;
end; { of MainEventLoop }

begin
  Done   := false;
  oldSC  := -1;
  oldfront := nil;
  if StartUpGSTools then begin
    SetRect(ZoomRect,20,20,620,180);
    SetRect(BigRect,0,0,10000,10000);
    SetRect(NewWinRect,30,30,300,150);
    with MyWColors do begin
      FrameColor := $0000;
      TitleColor := $0f00;
      TBarColor  := $020f;
      GrowColor  := $f0f0;
      InfoColor  := $00f0;
    end;
    InitCurUnit(MyID);
    WatchCur;
    SetUpMenus;
    SetupFiletypes;
    SetIconSize(isLarge);
    SetFatSize(Fat2Item);
    BuildStdIcon;
    icStartup(MyID+$200);
    InitClipWind;
    msgKind := InitReadMC(MyID);
    if msgKind=1 then begin
      note('Sorry!  This version of DIcEd can''t print.');
      while ReadNextMC(@iPathname) do { nothing } ;
    end;
    if msgKind=0 then
      while ReadNextMC(@iPathname) do begin
        ExtractFname(@iPathname,@iFname);
        ftype := GetFileType(@iPathname);
        case ftype of
          $04, $B0: ViewByName(@iFname, @iPathname);
          ICN:      OpenByName(@iFname, @iPathname);
        end;
      end;
    MainEventLoop;
  end;
  ShutDownGSTools;
  { TML 1.50A cleanup routine is buggy, so do following: }
  saneWAP := GetWAP(0,10);
  SANEShutdown;
  if saneWAP<>nil then
    if hiword(longint(saneWAP))=0 then
      DisposeHandle(FindHandle(saneWAP));
  QuitParms.chainPath  := StringPtr(nil);
  QuitParms.returnFlag := 0;
  QuitParms.futureUse  := 0;
  P16Quit(QuitParms);
end.
