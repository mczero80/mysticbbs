Unit bbs_Edit_Ansi;

{$I M_OPS.PAS}

Interface

Uses
  m_FileIO,
  bbs_MsgBase_ANSI;

Type
  TEditorANSI = Class
    Owner        : Pointer;
    ANSI         : TMsgBaseANSI;
    WinY1        : Byte;
    WinY2        : Byte;
    WinX1        : Byte;
    WinX2        : Byte;
    WinSize      : Byte;
    RowSize      : Byte;
    CurX         : Byte;
    CurY         : SmallInt;
    CurAttr      : Byte;
    QuoteAttr    : Byte;
    CurLength    : Byte;
    TopLine      : LongInt;
    CurLine      : LongInt;
    InsertMode   : Boolean;
    DrawMode     : Boolean;
    GlyphMode    : Boolean;
    WrapMode     : Boolean;
    ClearEOL     : Boolean;
    LastLine     : LongInt;
    QuoteTopPage : SmallInt;
    QuoteCurLine : SmallInt;

    // old shit from copy over of quote/command functions
    save   : boolean;
    forced : boolean;
    done   : boolean;
    subj   : string;

    Constructor Create (Var O: Pointer);
    Destructor  Destroy; Override;

    Function    IsAnsiLine    (Line: LongInt) : Boolean;
    Function    IsBlankLine   (Var Line; LineSize: Byte) : Boolean;
    Function    GetLineLength (Var Line; LineSize: Byte) : Byte;
    Function    GetWrapPos    (Var Line; LineSize, WrapPos: Byte) : Byte;
    Procedure   TrimLeft      (Var Line; LineSize: Byte);
    Procedure   DeleteLine    (Line: LongInt);
    Procedure   InsertLine    (Line: LongInt);
    Function    GetLineText   (Line: Word) : String;
    Procedure   SetLineText   (Line: LongInt; Str: String);
    Procedure   FindLastLine;
    Procedure   Reformat;
    Procedure   LocateCursor;
    Procedure   ToggleInsert (Toggle: Boolean);
    Procedure   ReDrawTemplate (Reset: Boolean);
    Procedure   DrawPage (StartY, EndY: Byte; ExitEOF: Boolean);
    Procedure   ScrollUp;
    Procedure   ScrollDown (Draw: Boolean);
    Function    LineUp : Boolean;
    Function    LineDown (Reset: Boolean) : Boolean;
    Procedure   PageUp;
    Procedure   PageDown;
    Procedure   DrawLine (Line: LongInt; XP, YP: Byte);
    Procedure   DoEnter;
    Procedure   DoBackSpace;
    Procedure   DoDelete;
    Procedure   DoChar (Ch: Char);
    Function    Edit : Boolean;

    procedure quote;
    procedure quotewindow;
    procedure commands;
    procedure messageupload;
  End;

Implementation

Uses
  m_Strings,
  bbs_Core,
  bbs_Common,
  bbs_Ansi_MenuBox;

Constructor TEditorANSI.Create (Var O: Pointer);
Begin
  Inherited Create;

  Owner      := O;
  ANSI       := TMsgBaseANSI.Create(NIL, False);
  WinX1      := 1;
  WinX2      := 79;
  WinY1      := 2;
  WinY2      := 23;
  WinSize    := WinY2 - WinY1 + 1;
  RowSize    := WinX2 - WinX1 + 1;
  CurX       := 1;
  CurY       := 1;
  CurLine    := 1;
  TopLine    := 1;
  CurAttr    := 7;
  QuoteAttr  := 9;
  InsertMode := True;
  DrawMode   := False;
  GlyphMode  := False;
  WrapMode   := True;
  ClearEOL   := RowSize >= 79;
  LastLine   := 1;
End;

Destructor TEditorANSI.Destroy;
Begin
  Inherited Destroy;

  ANSI.Free;
End;

Function TEditorANSI.GetLineText (Line: Word) : String;
Var
  Count : Word;
Begin
  Result := '';

  For Count := 1 to GetLineLength(ANSI.Data[Line], RowSize) Do
    Result := Result + ANSI.Data[Line][Count].Ch;
End;

Procedure TEditorANSI.SetLineText (Line: LongInt; Str: String);
Var
  Count : Byte;
Begin
  FillChar (ANSI.Data[Line], SizeOf(ANSI.Data[Line]), 0);

  For Count := 1 to Length(Str) Do Begin
    ANSI.Data[Line][Count].Ch   := Str[Count];
    ANSI.Data[Line][Count].Attr := CurAttr;
  End;
End;

Procedure TEditorANSI.FindLastLine;
Begin
  LastLine := mysMaxMsgLines;

  While (LastLine > 1) And IsBlankLine(ANSI.Data[LastLine], 80) Do
    Dec(LastLine);
End;

Function TEditorANSI.IsAnsiLine (Line: LongInt) : Boolean;
Var
  Count : Byte;
Begin
  Result := False;

  If GetLineLength(ANSI.Data[Line], 80) >= Rowsize Then Begin
    Result := True;

    Exit;
  End;

  For Count := 1 to 80 Do
    If (Ord(ANSI.Data[Line][Count].Ch) < 32) or (Ord(ANSI.Data[Line][Count].Ch) > 128) Then Begin
      Result := True;

      Exit;
    End;
End;

Function TEditorANSI.IsBlankLine (Var Line; LineSize: Byte) : Boolean;
Var
  EndPos : Byte;
  Data   : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  EndPos := LineSize;

  While (EndPos > 0) and (Data[EndPos].Ch = #0) Do
    Dec (EndPos);

  Result := EndPos = 0;
End;

Procedure TEditorANSI.TrimLeft (Var Line; LineSize: Byte);
Var
  Data   : Array[1..255] of RecAnsiBufferChar absolute Line;
  EndPos : Byte;
Begin
  EndPos := 1;

  While (EndPos <= LineSize) and (Data[1].Ch = ' ') Do Begin
    Move (Data[2], Data[1], SizeOf(RecAnsiBufferChar) * (LineSize - 1));

    Data[LineSize].Ch := #0;

    Inc (EndPos);
  End;
End;

Procedure TEditorANSI.DeleteLine (Line: LongInt);
Var
  Count : LongInt;
Begin
  For Count := Line to mysMaxMsgLines - 1 Do
    ANSI.Data[Count] := ANSI.Data[Count + 1];

  FillChar (ANSI.Data[mysMaxMsgLines], SizeOf(RecAnsiBufferLine), #0);

  If LastLine > 1 Then Dec(LastLine);
End;

Procedure TEditorANSI.InsertLine (Line: LongInt);
Var
  Count : LongInt;
Begin
  For Count := mysMaxMsgLines DownTo Line + 1 Do
    ANSI.Data[Count] := ANSI.Data[Count - 1];

  FillChar(ANSI.Data[Line], SizeOf(RecAnsiBufferLine), #0);

  If LastLine < mysMaxMsgLines Then Inc(LastLine);
End;

Function TEditorANSI.GetWrapPos (Var Line; LineSize: Byte; WrapPos: Byte) : Byte;
Var
  Data : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  If GetLineLength(Line, LineSize) < WrapPos Then Begin
    Result := 0;

    Exit;
  End;

  Result := LineSize;

  While (Result > 0) and ((Data[Result].Ch <> ' ') or (Result > WrapPos)) Do
    Dec (Result);
End;

Function TEditorANSI.GetLineLength (Var Line; LineSize: Byte) : Byte;
Var
  Data : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  Result := LineSize;

  While (Result > 0) and (Data[Result].Ch = #0) Do
    Dec (Result);
End;

Procedure TEditorANSI.Reformat;
Var
  WrapData  : Array[1..255] of RecAnsiBufferChar;
  TempStr   : Array[1..255] of RecAnsiBufferChar;
  NewLine   : Array[1..255] of RecAnsiBufferChar;
  Count     : LongInt;
  LineSize  : Byte;
  StartY    : Byte;
  StartLine : LongInt;
  EndLine   : LongInt;
  First     : Boolean = True;

  Procedure Update;
  Var
    NewY : LongInt;
  Begin
    NewY := StartY + EndLine - StartLine + 1;

    If NewY > WinSize Then NewY := WinSize;

    If CurY > WinSize Then
      ScrollDown(True)
    Else
      DrawPage (StartY, NewY, True);
  End;

Begin
  FillChar (WrapData, SizeOf(WrapData), #0);

  Count     := CurLine;
  StartY    := CurY;
  StartLine := Count;

  While Count <= mysMaxMsgLines Do Begin
    If Count > LastLine Then LastLine := Count;

    FillChar (TempStr, SizeOf(TempStr), #0);
    Move     (Ansi.Data[Count], TempStr, SizeOf(Ansi.Data[Count]));

    If Not IsBlankLine(WrapData, 255) Then Begin
      If IsBlankLine(TempStr, 255) Then Begin
        If Count < LastLine Then Begin
          InsertLine(Count);
          EndLine := mysMaxMsgLines;
        End Else
          EndLine := Count;

        Move (WrapData, ANSI.Data[Count], SizeOf(Ansi.Data[Count]));

        Update;

        Exit;
      End;

      FillChar (NewLine, SizeOf(NewLine), #0);

      LineSize := GetLineLength(WrapData, 255);

      Move (WrapData, NewLine, LineSize * SizeOf(RecAnsiBufferChar));

      NewLine[LineSize + 1].Ch   := ' ';
      NewLine[LineSize + 1].Attr := WrapData[LineSize].Attr;

      Move (TempStr, NewLine[LineSize + 2], GetLineLength(TempStr, 255) * SizeOf(RecAnsiBufferChar));
      Move (NewLine, TempStr, SizeOf(NewLine));
    End;

    FillChar (WrapData, SizeOf(WrapData), #0);

    LineSize := GetWrapPos(TempStr, 255, RowSize);

    If LineSize > 0 Then Begin
      Move     (TempStr[LineSize], WrapData, (GetLineLength(TempStr, 255) - LineSize + 1) * SizeOf(RecAnsiBufferChar));
      FillChar (TempStr[LineSize], (255 - LineSize) * SizeOf(RecAnsiBufferChar), #0);

      TrimLeft (WrapData, 255);

      If First Then Begin
        If CurX > LineSize Then Begin
          CurX := CurX - LineSize;

          Inc (CurY);
          Inc (CurLine);
        End;

        First := False;
      End;
    End;

    FillChar (ANSI.Data[Count], SizeOf(ANSI.Data[Count]), #0);
    Move     (TempStr, ANSI.Data[Count], RowSize * SizeOf(RecAnsiBufferChar));

    If LineSize = 0 Then Begin
      EndLine := Count;

      Update;

      Exit;
    End;

    Inc (Count);
  End;
End;

Procedure TEditorANSI.ToggleInsert (Toggle: Boolean);
Begin
  If Toggle Then InsertMode := Not InsertMode;

  Session.io.AnsiColor  (Session.io.ScreenInfo[3].A);
  Session.io.AnsiGotoXY (Session.io.ScreenInfo[3].X, Session.io.ScreenInfo[3].Y);

  If InsertMode Then Session.io.BufAddStr('INS') else Session.io.BufAddStr('OVR'); { ++lang }
End;

Procedure TEditorANSI.ReDrawTemplate (Reset: Boolean);
Begin
  TBBSCore(Owner).io.AllowArrow := True;

  Session.io.PromptInfo[2] := Subj;

  Session.io.OutFile ('ansiedit', True, 0);

  WinX1    := 1;
  WinX2    := 79;
  WinY1    := Session.io.ScreenInfo[1].Y;
  WinY2    := Session.io.ScreenInfo[2].Y;

  WinSize  := WinY2 - WinY1 + 1;
  RowSize  := WinX2 - WinX1 + 1;
  ClearEOL := RowSize >= 79;

  If Reset Then Begin
    CurX      := 1;
    CurY      := 1;
    CurAttr   := Session.io.ScreenInfo[1].A;
    QuoteAttr := Session.io.ScreenInfo[2].A;

    FindLastLine;
  End;

  DrawPage(1, WinSize, False);

  ToggleInsert (False);
End;

Procedure TEditorANSI.LocateCursor;
Begin
  CurLength := GetLineLength(ANSI.Data[CurLine], RowSize);

  If CurX < 1         Then CurX := 1;
  If CurX > CurLength Then CurX := CurLength + 1;
  If CurY < 1         Then CurY := 1;

  While TopLine + CurY - 1 > LastLine Do
    Dec (CurY);

(*
  If Not DrawMode Then Begin
    If (CurX > 1) and (CurX = CurLength + 1) Then
      CurAttr := ANSI.Data[CurLine][CurX - 1].Attr
    Else
      CurAttr := ANSI.Data[CurLine][CurX].Attr;

    If CurAttr = 0 Then CurAttr := 7;
  End;
*)
  With TBBSCore(Owner).io Do Begin
    AnsiGotoXY (WinX1 + CurX - 1, WinY1 + CurY - 1);
    AnsiColor  (CurAttr);

    BufFlush;
  End;
End;

Procedure TEditorANSI.DrawPage (StartY, EndY: Byte; ExitEOF: Boolean);
Var
  CountY : LongInt;
Begin
  For CountY := StartY to EndY Do Begin
    If TopLine + CountY - 1 > LastLine + 1 Then Begin
      TBBSCore(Owner).io.AnsiGotoXY (WinX1, WinY1 + CountY - 1);
      TBBSCore(Owner).io.AnsiColor  (7);

      If ClearEOL Then
        TBBSCore(Owner).io.AnsiClrEOL
      Else
        TBBSCore(Owner).io.BufAddStr (strRep(' ', RowSize));
    End Else
    If TopLine + CountY - 1 = LastLine + 1 Then Begin
      TBBSCore(Owner).io.AnsiGotoXY (WinX1, WinY1 + CountY - 1);
      TBBSCore(Owner).io.AnsiColor  (8);
      TBBSCore(Owner).io.BufAddStr  (strPadC('(END)', RowSize, ' '));

      If ExitEOF Then Break;
    End Else
      DrawLine (TopLine + CountY - 1, 1, CountY);
  End;
End;

Procedure TEditorANSI.ScrollUp;
Var
  NewTop : LongInt;
Begin
  NewTop := TopLine - (WinSize DIV 2) + 1;

  If NewTop < 1 Then NewTop := 1;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage(1, WinSize, False);
End;

Procedure TEditorANSI.ScrollDown (Draw: Boolean);
Var
  NewTop : LongInt;
Begin
  NewTop := TopLine + (WinSize DIV 2) + 1;

  While NewTop >= mysMaxMsgLines Do
    Dec (NewTop, 2);

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  If Draw Then
    DrawPage(1, WinSize, False);
End;

Function TEditorANSI.LineUp : Boolean;
Begin
  Result := False;

  If CurLine = 1 Then Exit;

  Dec (CurLine);
  Dec (CurY);

  If CurX > GetLineLength(ANSI.Data[CurLine], 80) Then CurX := GetLineLength(ANSI.Data[CurLine], 80) + 1;

  If CurY < 1 Then Begin
    ScrollUp;

    Result := True;
  End;
End;

Function TEditorANSI.LineDown (Reset: Boolean) : Boolean;
Begin
  Result := False;

  If CurLine >= mysMaxMsgLines Then Exit;

  Inc (CurLine);
  Inc (CurY);

  If Reset Then CurX := 1;

  If CurX > GetLineLength(ANSI.Data[CurLine], 80) Then CurX := GetLineLength(ANSI.Data[CurLine], 80) + 1;

  If CurY > WinSize Then Begin
    Result := True;

    ScrollDown(True);
  End;
End;

Procedure TEditorANSI.DrawLine (Line: LongInt; XP, YP: Byte);
Var
  Count   : Byte;
  LineLen : Byte;
Begin
  TBBSCore(Owner).io.AnsiGotoXY (WinX1 + XP - 1, WinY1 + YP - 1);

  LineLen := GetLineLength(ANSI.Data[Line], RowSize);

  For Count := XP to LineLen Do Begin
    If ANSI.Data[Line][Count].Ch = #0 Then Begin
      TBBSCore(Owner).io.AnsiColor  (7);
      TBBSCore(Owner).io.BufAddChar (' ');
    End Else Begin
      TBBSCore(Owner).io.AnsiColor  (ANSI.Data[Line][Count].Attr);
      TBBSCore(Owner).io.BufAddChar (ANSI.Data[Line][Count].Ch);
    End;
  End;

  If LineLen < RowSize Then
    If ClearEOL Then Begin
      TBBSCore(Owner).io.AnsiColor (7);
      TBBSCore(Owner).io.AnsiClrEOL;
    End Else Begin
      TBBSCore(Owner).io.AnsiColor (7);
      TBBSCore(Owner).io.BufAddStr (strRep(' ', LineLen - RowSize));
    End;
End;

Procedure TEditorANSI.DoDelete;
Var
  JoinLen : Byte;
  JoinPos : Byte;
  JoinBuf : Array[1..255] of RecAnsiBufferChar;
Begin
  If CurX <= CurLength Then Begin
    Move (ANSI.Data[CurLine][CurX + 1], ANSI.Data[CurLine][CurX], (CurLength - 1) * SizeOf(RecAnsiBufferChar));

    ANSI.Data[CurLine][CurLength].Ch := #0;

    DrawLine (CurLine, CurX, CurY);
  End Else
  If CurLine < LastLine Then
    If (CurLength = 0) and (LastLine > 1) Then Begin
      DeleteLine (CurLine);
      DrawPage   (CurY, WinSize, False);
    End Else Begin
      JoinLen := GetLineLength(ANSI.Data[CurLine + 1], RowSize);

      If CurLength + JoinLen <= RowSize Then Begin
        Move       (ANSI.Data[CurLine + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * JoinLen);
        DeleteLine (CurLine + 1);
        DrawPage   (CurY, WinSize, False); //optimize
      End Else Begin
        JoinPos := GetWrapPos(ANSI.Data[CurLine + 1], RowSize, RowSize - CurLength);

        If JoinPos > 0 Then Begin
          Move     (ANSI.Data[CurLine + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (JoinPos - 1));

          FillChar (JoinBuf, SizeOf(JoinBuf), #0);
          Move     (ANSI.Data[CurLine + 1][JoinPos + 1], JoinBuf, (JoinLen - JoinPos + 1) * SizeOf(RecAnsiBufferChar));
          Move     (JoinBuf, ANSI.Data[CurLine + 1], RowSize * SizeOf(RecAnsiBufferChar));

          DrawPage (CurY, CurY + 1, True);
        End;
      End;

    End;
End;

Procedure TEditorANSI.DoBackSpace;
Var
  JoinPos : Byte;
  JoinBuf : Array[1..255] of RecAnsiBufferChar;
Begin
  If CurX > 1 Then Begin
    Dec  (CurX);
    Move (ANSI.Data[CurLine][CurX + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1));

    ANSI.Data[CurLine][80].Ch := #0;

    If CurX > GetLineLength(ANSI.Data[CurLine], 80) Then
      TBBSCore(Owner).io.OutBS(1, True)
    Else
      DrawLine (CurLine, CurX, CurY);
  End Else
  If CurLine > 1 Then Begin
    If GetLineLength(ANSI.Data[CurLine - 1], 80) + CurLength <= RowSize Then Begin
      CurX := GetLineLength(ANSI.Data[CurLine - 1], 80) + 1;

      Move (ANSI.Data[CurLine], ANSI.Data[CurLine - 1][CurX], SizeOf(RecAnsiBufferChar) * CurLength);

      DeleteLine (CurLine);

      If Not LineUp Then DrawPage (CurY, WinSize, False); //optimize
    End Else Begin
      JoinPos := GetWrapPos(ANSI.Data[CurLine], RowSize, RowSize - GetLineLength(ANSI.Data[CurLine - 1], RowSize));

      If JoinPos > 0 Then Begin
        CurX := GetLineLength(ANSI.Data[CurLine - 1], 80) + 1;

        Move     (ANSI.Data[CurLine], ANSI.Data[CurLine - 1][CurX], SizeOf(RecAnsiBufferChar) * (JoinPos - 1));
        FillChar (JoinBuf, SizeOf(JoinBuf), #0);
        Move     (ANSI.Data[CurLine][JoinPos + 1], JoinBuf, (CurLength - JoinPos + 1) * SizeOf(RecAnsiBufferChar));
        Move     (JoinBuf, ANSI.Data[CurLine], RowSize * SizeOf(RecAnsiBufferChar));

        If Not LineUp Then DrawPage (CurY, WinSize, False);
      End Else Begin
        LineUp;

        CurX := CurLength + 1;
      End;
    End;
  End;
End;

Procedure TEditorANSI.DoChar (Ch: Char);
Begin
  If InsertMode Then Begin
    Move (ANSI.Data[CurLine][CurX], ANSI.Data[CurLine][CurX + 1], SizeOf(RecAnsiBufferChar) * (CurLength - CurX + 1));

    ANSI.Data[CurLine][CurX].Ch   := Ch;
    ANSI.Data[CurLine][CurX].Attr := CurAttr;

    If CurLength < RowSize {-1} Then Begin
      If CurX <= CurLength Then
        DrawLine (CurLine, CurX, CurY)
      Else Begin
        TBBSCore(Owner).io.AnsiColor  (CurAttr);
        TBBSCore(Owner).io.BufAddChar (Ch);
      End;

      Inc (CurX);
    End Else Begin
      Inc (CurX);

      Reformat;
    End;
  End Else
  If CurX <= RowSize Then Begin
    ANSI.Data[CurLine][CurX].Ch   := Ch;
    ANSI.Data[CurLine][CurX].Attr := CurAttr;

    TBBSCore(Owner).io.AnsiColor  (CurAttr);
    TBBSCore(Owner).io.BufAddChar (Ch);

    Inc (CurX);
  End;
End;

Procedure TEditorANSI.PageUp;
Var
  NewTop : LongInt;
Begin
  If CurLine = 1 Then Exit;

  If TopLine = 1 Then Begin
    CurLine := 1;
    CurY    := 1;
    CurX    := 1;

    Exit;
  End;

  Dec (CurLine, WinSize);

  If CurLine < 1 Then Begin
    CurLine := 1;
    NewTop  := 1;
  End Else Begin
    NewTop := TopLine - WinSize;

    If NewTop < 1 Then NewTop := 1;
  End;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage(1, WinSize, False);
End;

Procedure TEditorANSI.PageDown;
Var
  NewTop : LongInt;
Begin
  If CurLine = LastLine Then Exit;

  If (LastLine > TopLine) And (LastLine <= TopLine + WinSize - 1) Then Begin
    CurLine := LastLine;
    CurY    := CurLine - TopLine + 1;
    CurX    := 1;

    Exit;
  End;

  Inc (CurLine, WinSize);

  If CurLine > LastLine Then CurLine := LastLine;

  NewTop := TopLine + WinSize;

  While NewTop >= LastLine - (WinSize DIV 2) Do
    Dec (NewTop);

  If NewTop < 1 Then NewTop := 1;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage(1, WinSize, False);
End;

Procedure TEditorANSI.DoEnter;
Var
  TempLine : RecAnsiBufferLine;
Begin
  If InsertMode and IsBlankLine(ANSI.Data[mysMaxMsgLines], 80) Then Begin
    If CurX > CurLength Then Begin
      InsertLine (CurLine + 1);

      If Not LineDown(True) Then DrawPage(CurY, WinSize, True);
    End Else Begin
      TempLine := ANSI.Data[CurLine];

      InsertLine (CurLine + 1);

      FillChar (ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1), #0);
      Move     (TempLine[CurX], ANSI.Data[CurLine + 1][1], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1));

      If Not LineDown(True) Then
        DrawPage (CurY - 1, WinSize, True);
    End;
  End Else
    LineDown(True);
End;

Procedure TEditorANSI.Quote;
Var
  InFile   : Text;
  Start    : Integer;
  Finish   : Integer;
  NumLines : Integer;
  Text     : Array[1..mysMaxMsgLines] of String[80];
  PI1      : String;
  PI2      : String;
Begin
  Assign (InFile, Session.TempPath + 'msgtmp');
  {$I-} Reset (InFile); {$I+}
  If IoResult <> 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(158));
    Exit;
  End;

  NumLines := 0;
  Session.io.AllowPause := True;

  While Not Eof(InFile) Do Begin
    Inc    (NumLines);
    ReadLn (InFile, Text[NumLines]);
  End;

  Close (InFile);

  PI1 := Session.io.PromptInfo[1];
  PI2 := Session.io.PromptInfo[2];

  Session.io.OutFullLn('|CL' + Session.GetPrompt(452));

  For Start := 1 to NumLines Do Begin
    Session.io.PromptInfo[1] := strI2S(Start);
    Session.io.PromptInfo[2] := Text[Start];

    Session.io.OutFullLn (Session.GetPrompt(341));

    If (Session.io.PausePtr >= Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
      Case Session.io.MorePrompt of
        'N' : Break;
        'C' : Session.io.AllowPause := False;
      End;
  End;

  Session.io.AllowPause := True;

  Session.io.OutFull (Session.GetPrompt(159));
  Start := strS2I(Session.io.GetInput(3, 3, 11, ''));

  Session.io.OutFull (Session.GetPrompt(160));

  Finish := strS2I(Session.io.GetInput(3, 3, 11, ''));

  If (Start > 0) and (Start <= NumLines) and (Finish <= NumLines) Then Begin
    If Finish = 0 Then Finish := Start;

    For NumLines := Start to Finish Do Begin
      If LastLine = mysMaxMsgLines Then Break;

      If Not IsBlankLine(Ansi.Data[CurLine], 80) Then Begin
        Inc (CurLine);
        Inc (CurY);

        InsertLine (CurLine);
      End;

      SetLineText (CurLine, Text[NumLines]);
      ANSI.SetLineColor (QuoteAttr, CurLine);

      If CurY > WinSize Then
        ScrollDown(False);
    End;
  End;

  If CurLine < mysMaxMsgLines Then Begin
    Inc (CurLine);
    Inc (CurY);

    InsertLine(CurLine);

    If CurY > WinSize Then
      ScrollDown(False);
  End;

  Session.io.PromptInfo[1] := PI1;
  Session.io.PromptInfo[2] := PI2;
End;

Procedure TEditorANSI.QuoteWindow;
Var
  QText      : Array[1..mysMaxMsgLines] of String[79];
  InFile     : Text;
  QuoteLines : Integer;
  NoMore     : Boolean;

  Procedure UpdateBar (On: Boolean);
  Begin
    Session.io.AnsiGotoXY (1, QuoteCurLine + Session.io.ScreenInfo[2].Y);

    If On Then
      Session.io.AnsiColor (Session.Theme.QuoteColor)
    Else
      Session.io.AnsiColor (Session.io.ScreenInfo[2].A);

    Session.io.BufAddStr (strPadR(QText[QuoteTopPage + QuoteCurLine], 79, ' '));
  End;

  Procedure UpdateWindow;
  Var
    Count : Integer;
  Begin
    Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[2].Y);
    Session.io.AnsiColor  (Session.io.ScreenInfo[2].A);

    For Count := QuoteTopPage to QuoteTopPage + 5 Do Begin
      If Count <= QuoteLines Then Session.io.BufAddStr (QText[Count]);

      Session.io.AnsiClrEOL;

      If Count <= QuoteLines Then Session.io.BufAddStr(#13#10);
    End;

    UpdateBar(True);
  End;

Var
  Ch          : Char;
  Added       : Boolean;
  QWinSize    : Byte;
  QWinDataPos : Byte;
  QWinData    : Array[1..15] of String[79];

  Procedure AddQuoteWin (S: String);
  Var
    Count : Byte;
  Begin
    If QWinDataPos < QWinSize Then Begin
      Inc (QWinDataPos);
    End Else Begin
      For Count := 2 to QWinSize Do
        QWinData[Count - 1] := QWinData[Count]
    End;

    QWinData[QWinDataPos] := S;
  End;

  Procedure DrawQWin;
  Var
    Count : Byte;
  Begin
    Session.io.AnsiColor (QuoteAttr);

    For Count := 1 to QWinSize + 1 Do Begin
      Session.io.AnsiGotoXY (WinX1, WinY1 + Count - 1);

      If Count <= QWinSize Then
        Session.io.BufAddStr(QWinData[Count]);

      Session.io.AnsiClrEOL;
    End;
  End;

Var
  Temp : Integer;
Begin
  Added := False;

  Assign (InFile, Session.TempPath + 'msgtmp');
  {$I-} Reset(InFile); {$I+}

  If IoResult <> 0 Then Exit;

  NoMore       := False;
  QWinDataPos  := 0;
  QuoteLines   := 0;

  While Not Eof(InFile) Do Begin
    Inc    (QuoteLines);
    ReadLn (InFile, QText[QuoteLines]);
  End;

  Close (InFile);

  Session.io.OutFile ('ansiquot', True, 0);

  FillChar (QWinData, SizeOf(QWinData), 0);

  QWinSize := Session.io.ScreenInfo[1].Y - WinY1 + 1;

  For Temp := CurLine - ((QWinSize DIV 2) + 1) To CurLine - 1 Do
    If Temp >= 1 Then AddQuoteWin(GetLineText(Temp));

  DrawQWin;
  UpdateWindow;

  Repeat
    Ch := Session.io.GetKey;

    If Session.io.IsArrow Then Begin
      Case Ch of
        #71 : If QuoteCurLine > 0 Then Begin
                QuoteTopPage := 1;
                QuoteCurLine := 0;

                UpdateWindow;
              End;
        #72 : Begin
                If QuoteCurLine > 0 Then Begin
                  UpdateBar(False);

                  Dec(QuoteCurLine);

                  UpdateBar(True);
                End Else
                If QuoteTopPage > 1 Then Begin
                  Dec (QuoteTopPage);

                  UpdateWindow;
                End;

                NoMore := False;
              End;
        #73,
        #75 : Begin
                If QuoteTopPage > 6 Then
                  Dec (QuoteTopPage, 6)
                Else Begin
                  QuoteTopPage := 1;
                  QuoteCurLine := 0;
                End;

                NoMore := False;

                UpdateWindow;
              End;
        #79 : Begin
                If QuoteLines <= 6 Then
                  QuoteCurLine := QuoteLines - QuoteTopPage
                Else Begin
                  QuoteTopPage := QuoteLines - 5;
                  QuoteCurLine := 5;
                End;

                UpdateWindow;
              End;
        #80 : If QuoteTopPage + QuoteCurLine < QuoteLines Then Begin
                If QuoteCurLine = 5 Then Begin
                  Inc (QuoteTopPage);

                  UpdateWindow;
                End Else Begin
                  UpdateBar(False);

                  Inc (QuoteCurLine);

                  UpdateBar(True);
                End;
              End;
        #77,
        #81 : Begin
                If QuoteLines <= 6 Then
                  QuoteCurLine := QuoteLines - QuoteTopPage
                Else
                If QuoteTopPage + 6 < QuoteLines - 6 Then
                  Inc (QuoteTopPage, 6)
                Else Begin
                  QuoteTopPage := QuoteLines - 5;
                  QuoteCurLine := 5;
                End;

                UpdateWindow;
              End;
      End;
    End Else
      Case Ch of
        #27 : Break;
        #13 : If (LastLine < mysMaxMsgLines) and (Not NoMore) Then Begin
                Added := True;

                If QuoteTopPage + QuoteCurLine = QuoteLines Then NoMore := True;

                InsertLine  (CurLine);
                SetLineText (CurLine, QText[QuoteTopPage + QuoteCurLine]);

                ANSI.SetLineColor (QuoteAttr, CurLine);

                Inc (CurLine);
                Inc (CurY);

                If CurY > WinSize Then
                  ScrollDown(False);

                AddQuoteWin(QText[QuoteTopPage + QuoteCurLine]);
                DrawQWin;

                If QuoteTopPage + QuoteCurLine < QuoteLines Then
                  If QuoteCurLine = 5 Then Begin
                    Inc (QuoteTopPage);

                    UpdateWindow;
                  End Else Begin
                    UpdateBar(False);

                    Inc (QuoteCurLine);

                    UpdateBar(True);
                  End;
              End;
      End;
  Until False;

  Session.io.OutFull('|16');

  If CurLine < mysMaxMsgLines Then Begin
    Inc (CurLine);
    Inc (CurY);

    InsertLine(CurLine);

    If CurY > WinSize Then
      ScrollDown(False);
  End;
End;

Procedure TEditorANSI.Commands;
Var
  Ch  : Char;
  Str : String;
Begin
  Done := False;
  Save := False;

  Repeat
    Session.io.OutFull (Session.GetPrompt(354));

    Ch := Session.io.OneKey ('?ACHQRSTU', True);

    Case Ch of
      '?' : Session.io.OutFullLn (Session.GetPrompt(355));
      'A' : If Forced Then Begin
              Session.io.OutFull (Session.GetPrompt(307));
              Exit;
            End Else Begin
              Done := Session.io.GetYN(Session.GetPrompt(356), False);
              Exit;
            End;
      'C' : Exit;
      'H' : Begin
              Session.io.OutFile ('fshelp', True, 0);
              Exit;
            End;
      'Q' : Begin
              If Session.User.ThisUser.UseLBQuote Then
                QuoteWindow
              Else
                Quote;
              Exit;
            End;
      'R' : Exit;
      'S' : Begin
              Save := True;
              Done := True;
            End;
      'T' : Begin
              Session.io.OutFull(Session.GetPrompt(463));
              Str := Session.io.GetInput(60, 60, 11, Subj);
              If Str <> '' Then Subj := Str;
              Session.io.PromptInfo[2] := Subj;
              Exit;
            End;
      'U' : Begin
              MessageUpload;
              Exit;
            End;
    End;
  Until Done;
End;

Procedure TEditorANSI.MessageUpload;
Var
  FN : String[100];
  T1 : String[30];
  T2 : String[60];
  OK : Boolean;
  F  : File;
  B  : Array[1..2048] of Char;
  BR : LongInt;
Begin
  OK := False;

  T1 := Session.io.PromptInfo[1];
  T2 := Session.io.PromptInfo[2];

  Session.io.OutFull (Session.GetPrompt(352));

  If Session.LocalMode Then Begin
    FN := Session.io.GetInput(70, 70, 11, '');

    If FN = '' Then Exit;

    OK := FileExist(FN);
  End Else Begin
    FN := Session.TempPath + Session.io.GetInput(70, 70, 11, '');

    If Session.FileBase.SelectProtocol(True, False) = 'Q' Then Exit;

    Session.FileBase.ExecuteProtocol(1, FN);

    OK := Session.FileBase.dszSearch(JustFile(FN));
  End;

  If OK Then Begin
    Assign (F, FN);
    Reset  (F, 1);

    While Not Eof(F) Do Begin
      BlockRead (F, B, SizeOf(B), BR);

      If BR = 0 Then Break;

      ANSI.ProcessBuf(B, BR);
    End;

    Close(F);
  End;

  If Not Session.LocalMode Then FileErase(FN);

  DirClean (Session.TempPath, 'msgtmp');

  Session.io.PromptInfo[1] := T1;
  Session.io.PromptInfo[2] := T2;

  FindLastLine;
End;

Function TEditorANSI.Edit : Boolean;
Var
  Ch : Char;
Begin
  Result       := False;
  QuoteCurLine := 0;
  QuoteTopPage := 1;

  ReDrawTemplate(True);

  Repeat
    LocateCursor;

    Ch := TBBSCore(Owner).io.GetKey;

    If Session.io.IsArrow Then Begin
      Case Ch of
        #71 : CurX := 1;
        #72 : LineUp;
        #73 : PageUp;
        #75 : If CurX > 1 Then Dec(CurX);
        #77 : If CurX <= RowSize Then Inc(CurX);
        #79 : CurX := CurLength + 1;
        #80 : If CurLine < LastLine Then LineDown(False);
        #81 : PageDown;
        #83 : DoDelete;
      End;
    End Else
      Case Ch of
        ^Q   : Begin
                 If Session.User.ThisUser.UseLBQuote Then
                   QuoteWindow
                 Else
                   Quote;

                 ReDrawTemplate(False);
               End;
        ^V   : ToggleInsert(True);
        ^Y   : If (CurLine < LastLine) or ((CurLine = LastLine) And Not IsBlankLine(ANSI.Data[CurLine], 80)) Then Begin
                 DeleteLine (CurLine);

                 If CurLine > LastLine Then
                   InsertLine (CurLine);

                 DrawPage (CurY, WinSize, False);
               End;
        ^Z,
        ^[   : Begin
                 Commands;

                 If (Not Save) and (Not Done) Then ReDrawTemplate(False);

                 Session.io.AllowArrow := True;
               End;
        #08  : DoBackSpace;
        #13  : DoEnter;
        #32..
        #254 : If (CurLength >= RowSize) and (GetWrapPos(ANSI.Data[CurLine], RowSize, RowSize) = 0) Then Begin
                 // dont do anything
               End Else
               If (CurX = 1) and (Ch = '/') Then Begin
                 Commands;

                 If (Not Save) and (Not Done) Then ReDrawTemplate(False);

                 Session.io.AllowArrow := True;
               End Else
                 DoChar(Ch);
      End;
  Until Done;

  Session.io.AllowArrow := False;

  If Save Then FindLastLine;

  Result := Save;

  Session.io.AnsiGotoXY (1, Session.User.ThisUser.ScreenSize);
End;

End.
