unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, ComCtrls, Windows, DateUtils, sqlite3conn, SqlDb, sqlite3dyn;

type

  { TForm1 }

  TForm1 = class(TForm)
    CheckBox1: TCheckBox;
    ListView1: TListView;
    SQLite3Connection1: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    StatusBar1: TStatusBar;
    Timer1: TTimer;
    procedure CheckBox1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

var
  LastActiveCaption: string;
  LastActiveTime: TDateTime;
  AppDir: string;

function GetActiveCaption: string;
var
  Handle: THandle;
  Len: longint;
  Title: string;
begin
  Result := '';
  Handle := GetForegroundWindow;
  if Handle <> 0 then
  begin
    Len := GetWindowTextLength(Handle) + 1;
    SetLength(Title, Len);
    GetWindowText(Handle, PChar(Title), Len);
    GetActiveCaption := TrimRight(Title);
  end;
end;

//function GetProcessMemorySize(_sProcessName: string): cardinal;
//var
//  l_nWndHandle, l_nProcID, l_nTmpHandle: HWND;
//  l_pPMC: PPROCESS_MEMORY_COUNTERS;
//  l_pPMCSize: cardinal;
//begin
//  l_nWndHandle := FindWindow(nil, PChar(_sProcessName));

//  if l_nWndHandle <> 0 then
//  begin
//    l_pPMCSize := SizeOf(PROCESS_MEMORY_COUNTERS);

//    GetMem(l_pPMC, l_pPMCSize);
//    l_pPMC^.cb := l_pPMCSize;

//    GetWindowThreadProcessId(l_nWndHandle, @l_nProcID);
//    l_nTmpHandle := OpenProcess(PROCESS_ALL_ACCESS, False, l_nProcID);

//    if (GetProcessMemoryInfo(l_nTmpHandle, l_pPMC, l_pPMCSize)) then
//      Result := l_pPMC^.WorkingSetSize
//    else
//      Result := 0;

//    FreeMem(l_pPMC);
//  end
//  else
//    RaiseLastOSError;
//end;

//function GetProcessAddress(_sProcessName: string): string;
//var
//  l_nWndHandle, l_nProcID, l_nTmpHandle: HWND;
//  l_pPMC: PPROCESS_MEMORY_COUNTERS;
//  PID: cardinal;
//  hProcess: THandle;
//  path: array[0..MAX_PATH - 1] of char;
//begin
//  l_nWndHandle := FindWindow(nil, PChar(_sProcessName));

//  if l_nWndHandle <> 0 then
//  begin
//    GetWindowThreadProcessId(l_nWndHandle, @PID);
//    hProcess := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, PID);
//    if hProcess <> 0 then
//    try
//      if GetModuleFileNameEx(hProcess, 0, Path, MAX_PATH) = 0 then
//        RaiseLastOSError;
//      Result := Path;
//    finally
//      CloseHandle(hProcess)
//    end
//    else
//      RaiseLastOSError;
//  end
//  else
//    RaiseLastOSError;
//end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  ActiveCaption: string;
  ActiveTime: TDateTime;
begin
  ActiveTime := Now();
  ActiveCaption := GetActiveCaption;
  if CompareStr(ActiveCaption, LastActiveCaption) <>
    0 {And (SecondsBetween(ActiveTime, LastActiveTime)> 5)} then
  begin
    if ListView1.Items.Count > 0 then
    begin
      SQLQuery1.Close;
      SQLQuery1.SQL.Clear;
      SQLQuery1.SQL.Add(
        'Insert Into Logs(Start,Stop,Interval,Caption) Values (:Start,:Stop,:Interval,:Caption);');
      SQLQuery1.ParamByName('Start').AsString :=
        ListView1.Items[ListView1.Items.Count - 1].SubItems[0];
      SQLQuery1.ParamByName('Stop').AsString :=
        ListView1.Items[ListView1.Items.Count - 1].SubItems[1];
      SQLQuery1.ParamByName('Interval').AsString :=
        StringReplace(ListView1.Items[ListView1.Items.Count - 1].SubItems[2],
        ' s', '', [rfIgnoreCase]);
      SQLQuery1.ParamByName('Caption').AsString :=
        ListView1.Items[ListView1.Items.Count - 1].SubItems[3];
      SQLQuery1.ExecSQL;
      SQLTransaction1.Commit;
      SQLQuery1.Close;
    end;
    with ListView1.Items.Add do
    begin
      Caption := IntToStr(ListView1.Items.Count);
      SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', ActiveTime));
      SubItems.Add('...');
      SubItems.Add('0 s');
      SubItems.Add(ActiveCaption);
    end;
    LastActiveCaption := ActiveCaption;
    LastActiveTime := ActiveTime;
  end;
  ListView1.Items[ListView1.Items.Count - 1].SubItems[1] :=
    FormatDateTime('yyyy-mm-dd hh:nn:ss', ActiveTime);
  ListView1.Items[ListView1.Items.Count - 1].SubItems[2] :=
    Format('%d s', [SecondsBetween(ActiveTime, LastActiveTime)]);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  NewFile: boolean;
begin
  AppDir := ExcludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0)));
  try
    {$IfDef Win32}
    sqlite3conn.SQLiteLibraryName := AppDir + '\x32-sqlite3.dll';
    {$EndIf}
    {$IFDEF Win64}
    sqlite3conn.SQLiteLibraryName := AppDir + '\x64-sqlite3.dll';
    {$ENDIF}
  except
    {$IfDef Windows}
    MessageDlg('Library sqlite3.dll not found!', mtError, [mbOK], 0);
    {$EndIf}
    Application.Terminate;
  end;

  SQLite3Connection1.DatabaseName := AppDir + '\acm2.sqlite';
  NewFile := not FileExists(SQLite3Connection1.DatabaseName);

  SQLQuery1.PacketRecords := -1;
  SQLite3Connection1.Connected := True;
  if NewFile then
  begin
    SQLite3Connection1.ExecuteDirect('CREATE TABLE "Logs" ' +
      '("Id" Integer PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE, ' +
      '"Start" DATETIME, "Stop" Datetime, "Interval" INTEGER, "Caption" VARCHAR);');
    SQLTransaction1.Commit;
  end;

  LastActiveCaption := '';
  LastActiveTime := IncSecond(Now(), -5);
  Timer1Timer(Sender);
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
begin
  Timer1.Enabled := CheckBox1.Checked;
end;

end.
