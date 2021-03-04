UNIT PrintEnv;

INTERFACE

USES Types,  Memory, MiscTool, IntMath, TextTool, ProDOS16;

procedure PrintEnvelope;

IMPLEMENTATION

procedure WriteSysInfo;
var
  A, X, Y, P: integer;
  result: FWRec;
  s: string[10];
  pver: P16ParamBlk;
  procedure MyInt2Dec(v: integer; s: univ ptr; len, f: integer); tool 11,38;
begin
  WriteString('[ROM v');
  result := FWEntry(A,X,Y,$FE1F);
  s[0] := chr(3);
  MyInt2Dec(band(Y,$00ff),@s[1],3,0);
  if s[1]<>' ' then WriteChar(integer(s[1]));
  if s[2]<>' ' then WriteChar(integer(s[2]));
  if s[3]<>' ' then WriteChar(integer(s[3]));
  WriteString(',');
  s[0] := chr(5);
  MyInt2Dec(TotalMem div 1024,@s[1],5,0);
  WriteString(s);
  WriteString('K RAM, GS/OS v');
  P16GetVersion(pver);
  WriteChar(integer('0')+band(pver.version div $100,$7f));
  WriteChar(integer('.'));
  WriteChar(integer('0')+loword(pver.version));
  if band(pver.version,$8000)<>0 then WriteChar(integer('p'));
  WriteChar(integer(']'));
end;

procedure ww(s: Str255);
begin
  WriteString('        ');
  WriteLine(s);
end;

procedure BlankL(n: integer);
var
  i: integer;
begin
  for i := 1 to n do
    ww('  |                                                                        |');
end;

procedure PrintIt;
begin
WriteLine('');
ww('  |                       tape envelope closed here                        |');
BlankL(1);
ww('  |                         step five:  fold back                          |');
ww('  |------------------------------------------------------------------------|');
BlankL(2);
ww('  |  ___________________                                       place       |');
ww('  |  ___________________                                       stamp       |');
ww('  |  ___________________                                       here        |');
BlankL(5);
ww('  |                               DAL  Systems                             |');
ww('  |                               P.O. Box 875                             |');
ww('s |                          Cupertino, CA 95015-0875                      | s');
ww('t |                                              USA                       | t');
ww('e |                                                                        | e');
ww('p |                                                                        | p');
ww('  |                                                                        |');
ww('  |                                                                        |');
ww('t |                                                                        | t');
ww('w |------------------------------------------------------------------------| h');
ww('o |                         step four:  fold back                          | r');
ww('  |                                                                        | e');
ww('  |                                                                        | e');
ww('f |                                                                        |');
ww('o |                                                                        |');
ww('l |                                                                        | f');
ww('d |                                                                        | o');
ww('  |                                                                        | l');
ww('b |                                                                        | d');
ww('a |                                                                        |');
ww('c |                                                                        | b');
ww('k |                                                                        | a');
ww('  |                                                                        | c');
ww('  |                                                                        | k');
BlankL(5);
ww('  |------------------------------------------------------------------------|');
ww('  |                          step one:  fold back                          |');
WriteLine('');
WriteString('           DIcEd v1.3   15-Jul-89  ');
WriteSysInfo;  WriteLine(' #200');
WriteLine('');
ww('        Your name: _____________________________________________');
WriteLine('');
ww('          Address: _____________________________________________');
WriteLine('');
ww('                   _____________________________________________');
WriteLine('');
ww('         E-mail:   _____________________________________________');
WriteLine('');
ww('                You can write comments on the back of this sheet.');
ww('                      Put your $15 check behind this panel.');
WriteChar(12);  WriteChar(13);
end;

procedure PrintEnvelope;
begin
  SetOutputDevice(0,1);
  SetOutGlobals($7f,$00);
  InitTextDev(1);
  PrintIt;
  SetOutputDevice(0,3);
  InitTextDev(1);
end;

END.
