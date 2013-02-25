{$I M_OPS.PAS}

Unit MIS_Client_Telnet;

Interface

Uses
  {$IFDEF UNIX}
    Unix,
    Classes,
    Process,
    SysUtils,
    m_FileIO,
  {$ENDIF}
  {$IFDEF WINDOWS}
    Windows,
  {$ENDIF}
  m_io_Base,
  m_io_Sockets,
  m_FileIO,
  m_Strings,
  MIS_Common,
  MIS_NodeData,
  MIS_Server;

Function CreateTelnet (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
{ must match server create or there will be access violations }

Type
  TTelnetServer = Class(TServerClient)
    ND       : TNodeData;
//    Snooping : Boolean;
    Constructor Create (Owner: TServerManager; ND: TNodeData; CliSock: TIOSocket);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;
  End;

Implementation

Function CreateTelnet (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
Begin
  Result := TTelnetServer.Create(Owner, ND, CliSock);
End;

Constructor TTelnetServer.Create (Owner: TServerManager; ND: TNodeData; CliSock: TIOSocket);
Begin
  Inherited Create(Owner, CliSock);

  Self.ND  := ND;
//  Snooping := False;
End;

{$IFDEF WINDOWS}
Procedure TTelnetServer.Execute;
Var
  Cmd        : String;
  SI         : TStartupInfo;
  PI         : TProcessInformation;
  Num        : LongInt;
  NI         : TNodeInfoRec;
  PassHandle : LongInt;
Begin
  If Not DuplicateHandle (
    GetCurrentProcess,
    Client.FSocketHandle,
    GetCurrentProcess,
    @PassHandle,
    0,
    TRUE,
    DUPLICATE_SAME_ACCESS) Then Exit;

  Num := ND.GetFreeNode;
  Cmd := 'mystic.exe -n' + strI2S(Num) + ' -TID' + strI2S(PassHandle) + ' -IP' + Client.FPeerIP + ' -HOST' + Client.FPeerName + #0;

  FillChar(NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

  ND.SetNodeInfo(Num, NI);

  FillChar(SI, SizeOf(SI), 0);
  FillChar(PI, SizeOf(PI), 0);

  SI.dwFlags := STARTF_USESHOWWINDOW;

  If bbsConfig.inetTNHidden Then
    SI.wShowWindow := SW_HIDE
  Else
    SI.wShowWindow := SW_SHOWMINNOACTIVE;

  If CreateProcess(NIL, PChar(@Cmd[1]),
    NIL, NIL, True, Create_New_Console + Normal_Priority_Class, NIL, NIL, SI, PI) Then
      WaitForSingleObject (PI.hProcess, INFINITE);

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);

  FileErase (bbsConfig.DataPath + 'chat' + strI2S(Num) + '.dat');
End;
{$ENDIF}

{$IFDEF UNIX}
Procedure TTelnetServer.Execute;
Var
  Cmd    : String;
  Num    : LongInt;
  NI     : TNodeInfoRec;
  Proc   : TProcess;
  Buffer : TIOBuffer;
  bRead  : LongInt;
  bWrite : LongInt;
Begin
  Client.FTelnetServer := True;

  Proc := TProcess.Create(Nil);
  Num  := ND.GetFreeNode;

  Proc.CommandLine := 'mystic -n' + strI2S(Num) + ' -IP' + Client.FPeerIP + ' -HOST' + Client.FPeerName;
  Proc.Options     := [poUsePipes];

  FillChar(NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

  ND.SetNodeInfo(Num, NI);

  Proc.Execute;

  While Proc.Running Or (Proc.Output.NumBytesAvailable > 0) Do Begin
    If Proc.Output.NumBytesAvailable > 0 Then Begin
      bRead := Proc.Output.Read(Buffer, TIOBufferSize);
      Client.WriteBufEscaped (Buffer, bRead);
    End Else
    If Client.DataWaiting Then Begin
      bWrite := Client.ReadBuf(Buffer, TIOBufferSize);

      If bWrite < 0 Then Break;

      If bWrite > 0 Then Begin
        Proc.Input.Write(Buffer, bWrite);
      End;
    End Else
      Sleep(10);
  End;

  Proc.Free;

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);

  FileErase (bbsConfig.DataPath + 'chat' + strI2S(NI.Num) + '.dat');
End;
{$ENDIF}

Destructor TTelnetServer.Destroy;
Begin
  Inherited Destroy;
End;

End.
