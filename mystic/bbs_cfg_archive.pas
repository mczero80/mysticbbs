Unit bbs_cfg_Archive;

{$I M_OPS.PAS}

Interface

Procedure Configuration_ArchiveEditor;

Implementation

Uses
  m_FileIO,
  m_Strings,
  bbs_Common,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm;

Procedure EditArchive (Var Arc: RecArchive);
Var
  Box      : TAnsiMenuBox;
  Form     : TAnsiMenuForm;
  Topic    : String;
Begin
  Topic := '';
  Box   := TAnsiMenuBox.Create;
  Form  := TAnsiMenuForm.Create;

  Box.Header := ' Archive Editor: ' + Arc.Desc + ' ';

  Box.Open (13, 5, 67, 15);

  Form.HelpSize := 0;

  VerticalLine (28, 7, 13);

  Form.AddBol  ('A', ' Active '         , 20,  7, 30,  7,  8, 3, @Arc.Active, '');
  Form.AddStr  ('X', ' Extension '      , 17,  8, 30,  8, 11, 4, 4, @Arc.Ext, '');
  Form.AddTog  ('O', ' OS '             , 24,  9, 30,  9,  4, 7, 0, 2, 'Windows Linux OSX', @Arc.OSType, '');
  Form.AddStr  ('D', ' Description '    , 15, 10, 30, 10, 13, 30, 30, @Arc.Desc, '');
  Form.AddStr  ('P', ' Pack Cmd '       , 18, 11, 30, 11, 10, 35, 80, @Arc.Pack, '');
  Form.AddStr  ('U', ' Unpack Cmd '     , 16, 12, 30, 12, 12, 35, 80, @Arc.Unpack, '');
  Form.AddStr  ('V', ' View Cmd '       , 18, 13, 30, 13, 10, 35, 80, @Arc.View, '');

  Form.Execute;
  Box.Close;

  Form.Free;
  Box.Free;
End;

Procedure Configuration_ArchiveEditor;
Var
  Box  : TAnsiMenuBox;
  List : TAnsiMenuList;
  F    : TBufFile;
  Arc  : RecArchive;

  // SORT THIS LIST BY NON CASE SENSITIVE ARCHIVE EXTENSION
  Procedure MakeList;
  Var
    OS : String;
  Begin
    List.Clear;

    F.Reset;
    While Not F.Eof Do Begin
      F.Read (Arc);

      Case Arc.OSType of
        0 : OS := 'Windows';
        1 : OS := 'Linux  ';
        2 : OS := 'OSX';
      End;

      List.Add (strPadR(YesNoStr[Arc.Active], 5, ' ') + strPadR(Arc.Ext, 7, ' ') + OS + '   ' + Arc.Desc, 0);
    End;

    List.Add ('', 2);
  End;

Begin
  F := TBufFile.Create(SizeOf(RecArchive));

  F.Open (Config.DataPath + 'archive.dat', fmOpenCreate, fmReadWrite + fmDenyNone, SizeOf(RecArchive));

  Box  := TAnsiMenuBox.Create;
  List := TAnsiMenuList.Create;

  Box.Header    := ' Archive Editor ';
  List.NoWindow := True;
  List.LoChars  := #01#04#13#27;

  Box.Open (13, 5, 67, 20);

  WriteXY (15,  6, 112, 'Use  Ext    OSID      Description');
  WriteXY (15,  7, 112, strRep('�', 51));
  WriteXY (15, 18, 112, strRep('�', 51));
  WriteXY (18, 19, 112, '(CTRL/A) Add   (CTRL/D) Delete   (ENTER) Edit');

  Repeat
    MakeList;

    List.Open (13, 7, 67, 18);
    List.Close;

    Case List.ExitCode of
      #04 : If List.Picked < List.ListMax Then
              If ShowMsgBox(1, 'Delete this entry?') Then Begin
                F.RecordDelete (List.Picked);
                MakeList;
              End;
      #01 : Begin
              F.RecordInsert (List.Picked);

              Arc.OSType := OSType;
              Arc.Active := False;
              Arc.Desc   := 'New archive';
              Arc.Ext    := 'NEW';
              Arc.Pack   := '';
              Arc.Unpack := '';
              Arc.View   := '';

              F.Write (Arc);

              MakeList;
            End;
      #13 : If List.Picked <> List.ListMax Then Begin
              F.Seek (List.Picked - 1);
              F.Read (Arc);

              EditArchive(Arc);

              F.Seek  (List.Picked - 1);
              F.Write (Arc);
            End;
      #27 : Break;
    End;
  Until False;

  F.Close;
  F.Free;

  Box.Close;
  List.Free;
  Box.Free;
End;

End.