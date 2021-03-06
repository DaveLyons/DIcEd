{$CSEG Filetypes}
{$LongGlobals+}
UNIT Filetypes;

INTERFACE

USES Types, Locator, Memory, MiscTool, QuickDraw, QDAux, Events, Controls,
     Windows, Menus, LineEdit, Dialogs, Scrap, StdFile, IntMath, Fonts, SANE,
     ProDOS16, GSOS, IconAccess, TMLUtils, CurUnit, Lists, Desk, dicedSetup;

procedure SetupFiletypes;
IMPLEMENTATION

procedure SetupFiletypes;
var
  i: integer;
begin
  for i := 1 to MaxFT do begin
    FT[i].memFlag := 0;
    FT[i].x := 0;
  end;
  i := 1;
  FT[i].t := $01; FT[i].memPtr := @'BAD (bad blocks)'; inc(i);
  FT[i].t := $04; FT[i].memPtr := @'TXT (plain text)'; inc(i);
  FT[i].t := $06; FT[i].memPtr := @'BIN (binary data)'; inc(i);
  FT[i].t := $08; FT[i].x := $4000;
                  FT[i].memPtr := @'Packed Hi-Res image'; inc(i);
  FT[i].t := $08; FT[i].x := $4001;
                  FT[i].memPtr := @'Packed DHR image'; inc(i);
  FT[i].t := $08; FT[i].memPtr := @'Apple II or /// pic'; inc(i);
  FT[i].t := $0B; FT[i].memPtr := @'WPF (Word Proc File)'; inc(i);
  FT[i].t := $0C; FT[i].memPtr := @'SOS (Apple /// System)'; inc(i);
  FT[i].t := $0F; FT[i].memPtr := @'DIR (folder)'; inc(i);
  FT[i].t := $16; FT[i].x := 1;
                  FT[i].memPtr := @'PFS:File document'; inc(i);
  FT[i].t := $16; FT[i].x := 2;
                  FT[i].memPtr := @'PFS:Write document'; inc(i);
  FT[i].t := $16; FT[i].x := 3;
                  FT[i].memPtr := @'PFS:Graph document'; inc(i);
  FT[i].t := $16; FT[i].x := 4;
                  FT[i].memPtr := @'PFS:Plan document'; inc(i);
  FT[i].t := $16; FT[i].x := $16;
                  FT[i].memPtr := @'PFS Internal Data'; inc(i);
  FT[i].t := $16; FT[i].memPtr := @'PFS Document'; inc(i);
  FT[i].t := $19; FT[i].memPtr := @'ADB (AppleWorks DB)'; inc(i);
  FT[i].t := $1A; FT[i].memPtr := @'AWP (AppleWorks WP)'; inc(i);
  FT[i].t := $1B; FT[i].memPtr := @'ASP (AppleWorks SP)'; inc(i);
  FT[i].t := $20; FT[i].memPtr := @'The Desktop Mgr file'; inc(i);
  FT[i].t := $29; FT[i].memPtr := @'SOS Dictionary'; inc(i);
  FT[i].t := $2a; FT[i].memPtr := @'Apple II source code'; inc(i);
  FT[i].t := $2b; FT[i].memPtr := @'Apple II object code'; inc(i);
  FT[i].t := $2c; FT[i].memPtr := @'A2 interpreted code'; inc(i);
  FT[i].t := $2d; FT[i].memPtr := @'A2 prog lang data'; inc(i);
  FT[i].t := $50; FT[i].memPtr := @'GS Word Processor file'; inc(i);
  FT[i].t := $50; FT[i].x := $8001;
                  FT[i].memPtr := @'DexluxeWrite Document'; inc(i);
  FT[i].t := $50; FT[i].x := $8010;
                  FT[i].memPtr := @'AWGS Word Proc file'; inc(i);
  FT[i].t := $51; FT[i].memPtr := @'GS Spreadsheet file'; inc(i);
  FT[i].t := $51; FT[i].x := $8010;
                  FT[i].memPtr := @'AWGS Spreadsheet file'; inc(i);
  FT[i].t := $52; FT[i].memPtr := @'GS Database file'; inc(i);
  FT[i].t := $52; FT[i].x := $8010;
                  FT[i].memPtr := @'AWGS Database file'; inc(i);
  FT[i].t := $52; FT[i].x := $8011;
                  FT[i].memPtr := @'AWGS DB template'; inc(i);
  FT[i].t := $53; FT[i].memPtr := @'Drawing file'; inc(i);
  FT[i].t := $53; FT[i].x := $8010;
                  FT[i].memPtr := @'AWGS Graphics file'; inc(i);
  FT[i].t := $54; FT[i].memPtr := @'GS Desktop Publ file'; inc(i);
  FT[i].t := $54; FT[i].x := $8010;
                  FT[i].memPtr := @'AWGS page layout'; inc(i);
  FT[i].t := $54; FT[i].x := $dd3e;
                  FT[i].memPtr := @'Medley Document'; inc(i);
  FT[i].t := $55; FT[i].memPtr := @'Hypermedia file'; inc(i);
  FT[i].t := $55; FT[i].x := $8001;
                  FT[i].memPtr := @'Tutor-Tech Hypermedia file'; inc(i);
  FT[i].t := $56; FT[i].memPtr := @'Educational Data'; inc(i);
  FT[i].t := $56; FT[i].x := $8001;
                  FT[i].memPtr := @'Tutor-Tech scores'; inc(i);
  FT[i].t := $57; FT[i].memPtr := @'Stationary'; inc(i);
  FT[i].t := $58; FT[i].memPtr := @'Help file'; inc(i);
  FT[i].t := $59; FT[i].memPtr := @'Communications file'; inc(i);
  FT[i].t := $59; FT[i].x := $8010;
                  FT[i].memPtr := @'AppleWorks GS CM file'; inc(i);
  FT[i].t := $5a; FT[i].memPtr := @'Configuration file'; inc(i);
  FT[i].t := $5a; FT[i].x := $8010;
                  FT[i].memPtr := @'AppleWorks GS config'; inc(i);
  FT[i].t := $5b; FT[i].memPtr := @'Animation file'; inc(i);
  FT[i].t := $6b; FT[i].memPtr := @'PC Transporter BIOS'; inc(i);
  FT[i].t := $6d; FT[i].memPtr := @'PC Transporter Driver'; inc(i);
  FT[i].t := $6e; FT[i].memPtr := @'PC Transporter Preboot'; inc(i);
  FT[i].t := $6f; FT[i].memPtr := @'PC Transporter Volume'; inc(i);
  FT[i].t := $a0; FT[i].memPtr := @'WordPerfect document'; inc(i);
  FT[i].t := $AB; FT[i].memPtr := @'GSBASIC Program'; inc(i);
  FT[i].t := $AC; FT[i].memPtr := @'GSBASIC Tool Defs'; inc(i);  
  FT[i].t := $AD; FT[i].memPtr := @'GSBASIC Data'; inc(i);
  FT[i].t := $B0; FT[i].x := 1; FT[i].memPtr := @'SRC: Text'; inc(i);
  FT[i].t := $B0; FT[i].x := 2; FT[i].memPtr := @'SRC: 6502 Asm'; inc(i);
  FT[i].t := $B0; FT[i].x := 3; FT[i].memPtr := @'SRC: 65816 Asm'; inc(i);
  FT[i].t := $B0; FT[i].x := 4; FT[i].memPtr := @'SRC: BASIC'; inc(i);
  FT[i].t := $B0; FT[i].x := 5; FT[i].memPtr := @'Byte Works Pascal'; inc(i);
  FT[i].t := $B0; FT[i].x := 6; FT[i].memPtr := @'SRC: exec script'; inc(i);
  FT[i].t := $B0; FT[i].x := 7; FT[i].memPtr := @'Byte Works Small C'; inc(i);
  FT[i].t := $B0; FT[i].x := 8; FT[i].memPtr := @'SRC: Byte Works C'; inc(i);
  FT[i].t := $B0; FT[i].x := 9; FT[i].memPtr := @'SRC: linker script'; inc(i);
  FT[i].t := $B0; FT[i].x :=10; FT[i].memPtr := @'SRC: APW C'; inc(i);
  FT[i].t := $B0; FT[i].x :=11; FT[i].memPtr := @'SRC: Pascal'; inc(i);
  FT[i].t := $B0; FT[i].x :=30; FT[i].memPtr := @'SRC: TML Pascal'; inc(i);
  FT[i].t := $B0; FT[i].memPtr := @'SRC (APW source)'; inc(i);
  FT[i].t := $B1; FT[i].memPtr := @'OBJ (object code)'; inc(i);
  FT[i].t := $B2; FT[i].memPtr := @'LIB (library)'; inc(i);
  FT[i].t := $B3; FT[i].memPtr := @'S16 (GS Application)'; inc(i);
  FT[i].t := $B4; FT[i].memPtr := @'RTL (run-time library)'; inc(i);
  FT[i].t := $B5; FT[i].memPtr := @'EXE (shell appl)'; inc(i);
  FT[i].t := $B6; FT[i].memPtr := @'PIF: Perm Init File'; inc(i);
  FT[i].t := $B6; FT[i].memPtr := @'STR: Startup file (PIF)'; inc(i);
  FT[i].t := $B7; FT[i].memPtr := @'TIF: Temp Init File'; inc(i);
  FT[i].t := $B8; FT[i].memPtr := @'NDA (New Desk Acc)'; inc(i);
  FT[i].t := $B9; FT[i].memPtr := @'CDA (Classic Desk Acc)'; inc(i);
  FT[i].t := $BA; FT[i].memPtr := @'TOL (toolset)'; inc(i);
  FT[i].t := $BB; FT[i].memPtr := @'DVR (device driver)'; inc(i);
  FT[i].t := $BB; FT[i].x := 1; FT[i].memPtr := @'DVR (printer driver)'; inc(i);
  FT[i].t := $BB; FT[i].x := 2; FT[i].memPtr := @'DVR (port driver)'; inc(i);
  FT[i].t := $BB; FT[i].x := 3; FT[i].memPtr := @'DVR (ATLK driver)'; inc(i);
  FT[i].t := $bc; FT[i].memPtr := @'GLF (Generic Load File)'; inc(i);
  FT[i].t := $bd; FT[i].memPtr := @'GS/OS File Sys Trans'; inc(i);
  FT[i].t := $BF; FT[i].memPtr := @'GS/OS Document'; inc(i);
  FT[i].t := $C0; FT[i].memPtr := @'PNT (packed picture)'; inc(i);
  FT[i].t := $C0; FT[i].x := 1; FT[i].memPtr := @'PNT (PackBytes)'; inc(i);
  FT[i].t := $C0; FT[i].x := 2; FT[i].memPtr := @'PNT (Apple Preferred)'; inc(i);
  FT[i].t := $C0; FT[i].x := 3; FT[i].memPtr := @'PNT (packed QD PICT)'; inc(i);
  FT[i].t := $C1; FT[i].memPtr := @'PIC (unpacked picture)'; inc(i);
  FT[i].t := $C1; FT[i].x := 1; FT[i].memPtr := @'PIC (unpacked QD PICT)'; inc(i);
  FT[i].t := $c2; FT[i].memPtr := @'Paintworks animation'; inc(i);
  FT[i].t := $c3; FT[i].memPtr := @'Paintworks Palette'; inc(i);
  FT[i].t := $c5; FT[i].memPtr := @'Object graphics'; inc(i);
  FT[i].t := $c5; FT[i].x := $8000;
                  FT[i].memPtr := @'Draw Plus document'; inc(i);
  FT[i].t := $c5; FT[i].x := $C000;
                  FT[i].memPtr := @'Arch.Des. file'; inc(i);
  FT[i].t := $c5; FT[i].x := $C001;
                  FT[i].memPtr := @'Arch.Des. Object'; inc(i);
  FT[i].t := $c5; FT[i].x := $C002;
                  FT[i].memPtr := @'Arch.Des. Custom Object'; inc(i);
  FT[i].t := $c5; FT[i].x := $C003;
                  FT[i].memPtr := @'Arch.Des. Clipbd Object'; inc(i);
  FT[i].t := $C8; FT[i].memPtr := @'FON (font)'; inc(i);
  FT[i].t := $C9; FT[i].memPtr := @'Finder data'; inc(i);
  FT[i].t := $CA; FT[i].memPtr := @'Finder icons'; inc(i);
  FT[i].t := $D5; FT[i].memPtr := @'Music Sequence'; inc(i);
  FT[i].t := $D5; FT[i].x := $8002;
                  FT[i].memPtr := @'Diversi-Tune Sequence'; inc(i);
  FT[i].t := $D6; FT[i].memPtr := @'MCS Instrument file'; inc(i);
  FT[i].t := $D6; FT[i].x := $8002;
                  FT[i].memPtr := @'Diversi-Tune Instr.'; inc(i);
  FT[i].t := $d7; FT[i].memPtr := @'MIDI File'; inc(i);
  FT[i].t := $d8; FT[i].memPtr := @'Sampled Sound/AIFF'; inc(i);
  FT[i].t := $d8; FT[i].x := 1;
                  FT[i].memPtr := @'Compressed Sound (ACE)'; inc(i);
  FT[i].t := $d8; FT[i].x := 2;
                  FT[i].memPtr := @'Sampled Instr. (ASIF)'; inc(i);
  FT[i].t := $E0; FT[i].memPtr := @'Telcom library'; inc(i);
  FT[i].t := $E0; FT[i].x := $8001;
                  FT[i].memPtr := @'ACU Compressed Data'; inc(i);
  FT[i].t := $E2; FT[i].memPtr := @'AppleTalk file'; inc(i);
  FT[i].t := $EF; FT[i].memPtr := @'Pascal partition'; inc(i);
  FT[i].t := $F0; FT[i].memPtr := @'CMD (command module)'; inc(i);
  FT[i].t := $F8; FT[i].memPtr := @'Merlin link file'; inc(i);
  FT[i].t := $F9; FT[i].memPtr := @'System file'; inc(i);
  FT[i].t := $FA; FT[i].memPtr := @'INTBASIC program'; inc(i);
  FT[i].t := $FB; FT[i].memPtr := @'INTBASIC variables'; inc(i);
  FT[i].t := $FC; FT[i].memPtr := @'BAS (Applesoft prog)'; inc(i);
  FT[i].t := $FD; FT[i].memPtr := @'VAR (Applesoft vars)'; inc(i);
  FT[i].t := $FE; FT[i].memPtr := @'REL (relocatable obj)'; inc(i);
  FT[i].t := $FF; FT[i].memPtr := @'SYS (ProDOS 8)'; inc(i);
  FT[i].t := $FFF1; FT[i].memPtr := @'SCSI partition'; inc(i);
  FT[i].t := $FFF2; FT[i].memPtr := @'CD-ROM partition'; inc(i);
  FT[i].t := $FFF3; FT[i].memPtr := @'HD partition'; inc(i);
  FT[i].t := $FFF4; FT[i].memPtr := @'Network Generic'; inc(i);
  FT[i].t := $FFF5; FT[i].memPtr := @'File server'; inc(i);
  FT[i].t := $FFF6; FT[i].memPtr := @'SCSI generic'; inc(i);
  FT[i].t := $FFF7; FT[i].memPtr := @'Tape Drive'; inc(i);
  FT[i].t := $FFF8; FT[i].memPtr := @'CD-ROM disc'; inc(i);
  FT[i].t := $FFF9; FT[i].memPtr := @'5.25" drive'; inc(i);
  FT[i].t := $FFFA; FT[i].memPtr := @'RAM disk'; inc(i);
  FT[i].t := $FFFB; FT[i].memPtr := @'3.5" disk'; inc(i);
  FT[i].t := $FFFC; FT[i].memPtr := @'5.25" disk'; inc(i);
  FT[i].t := $FFFD; FT[i].memPtr := @'Hard disk'; inc(i);
  FT[i].t := $FFFE; FT[i].memPtr := @'Full trash can'; inc(i);
  FT[i].t := $FFFF; FT[i].memPtr := @'Empty trash can'; inc(i);
  FT[i].t := $00; FT[i].memPtr := @'Anything else'; inc(i);
  NumTypes := i-1;
end;

END.
