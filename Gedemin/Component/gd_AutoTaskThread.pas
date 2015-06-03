unit gd_AutoTaskThread;

interface

uses
  Windows, Classes, Controls, Contnrs, SysUtils, gdMessagedThread;

type
  TgdAutoTask = class(TObject)
  private
    FId: Integer;
    FName: String;
    FDescription: String;
    FExactDate: TDateTime;
    FMonthly: Integer;
    FWeekly: Integer;
    FDaily: Boolean;
    FStartTime: TTime;
    FEndTime: TTime;
    FPriority: Integer;
    FErrorMsg: String;

    FNextStartTime, FNextEndTime: TDateTime;

    procedure Log(const AMsg: String);
    procedure LogStartTask;
    procedure LogEndTask;
    procedure LogErrorMsg;

  protected
    function IsAsync: Boolean; virtual;
    procedure TaskExecute; virtual;
    function Compare(ATask: TgdAutoTask): Integer;

  public
    procedure Execute;
    procedure Schedule;

    property Id: Integer read FId write FId;
    property Name: String read FName write FName;
    property Description: String read FDescription write FDescription;
    property ExactDate: TDateTime read FExactDate write FExactDate;
    property Monthly: Integer read FMonthly write FMonthly;
    property Weekly: Integer read FWeekly write FWeekly;
    property Daily: Boolean read FDaily write FDaily;
    property StartTime: TTime read FStartTime write FStartTime;
    property EndTime: TTime read FEndTime write FEndTime;
    property Priority: Integer read FPriority write FPriority;
    property NextStartTime: TDateTime read FNextStartTime write FNextStartTime;
    property NextEndTime: TDateTime read FNextEndTime write FNextEndTime;
  end;

  TgdAutoFunctionTask = class(TgdAutoTask)
  private
    FFunctionKey: Integer;

  protected
    procedure TaskExecute; override;

  public
    property FunctionKey: Integer read FFunctionKey write FFunctionKey;
  end;

  TgdAutoCmdTask = class(TgdAutoTask)
  private
    FCmdLine: String;

  protected
    function IsAsync: Boolean; override;
    procedure TaskExecute; override;

  public
    property CmdLine: String read FCmdLine write FCmdLine;
  end;

  TgdAutoBackupTask = class(TgdAutoTask)
  private
    FBackupFile: String;

  protected
    function IsAsync: Boolean; override;
    procedure TaskExecute; override;

  public
    property BackupFile: String read FBackupFile write FBackupFile;
  end;

  TgdAutoTaskThread = class(TgdMessagedThread)
  private
    FTaskList: TObjectList;
    FNotificationContext: Integer;

    procedure LoadFromRelation;
    procedure FindAndExecuteTask;
    procedure UpdateTaskList;
    procedure SortTaskList;
    procedure RemoveExecuteOnceTask;

  protected
    procedure Timeout; override;
    function ProcessMessage(var Msg: TMsg): Boolean; override;

    procedure SendNotification(const AText: String);

  public
    constructor Create;
    destructor Destroy; override;

    procedure SetInitialDelay;
  end;

var
  gdAutoTaskThread: TgdAutoTaskThread;

implementation

uses
  at_classes, gdcBaseInterface, IBDatabase, IBSQL, rp_BaseReport_unit,
  scr_i_FunctionList, gd_i_ScriptFactory, ShellApi, gdcAutoTask, gd_security,
  gdNotifierThread_unit, gd_ProgressNotifier_unit, IBServices,
  gd_common_functions, gd_directories_const;

const
  WM_GD_FIND_AND_EXECUTE_TASK = WM_GD_THREAD_USER + 1;

{ TgdAutoTask }

procedure TgdAutoTask.TaskExecute;
begin
  //
end;

procedure TgdAutoTask.Execute;
begin
  Assert(gdAutoTaskThread <> nil);

  gdAutoTaskThread.Synchronize(LogStartTask);

  FErrorMsg := '';

  gdAutoTaskThread.SendNotification('����������� ���������� ' + Name + '...');

  if IsAsync then
    TaskExecute
  else
    gdAutoTaskThread.Synchronize(TaskExecute);

  if FErrorMsg > '' then
  begin
    gdAutoTaskThread.SendNotification('������ ��� ���������� ����������: ' + FErrorMsg);
    gdAutoTaskThread.Synchronize(LogErrorMsg);
  end else
  begin
    gdAutoTaskThread.SendNotification('���������� "' + Name + '" ���������.');
    gdAutoTaskThread.Synchronize(LogEndTask);
  end;
end;

procedure TgdAutoTask.Schedule;
var
  Y, M, D, K: Word;
begin
  // �� ��������� ���������� ������ � ������
  // � ���������� ��������������� �������
  // (���� ������������ ����)
  // ������������ ��������� ��������� ����
  // ������� ������
  //
  // ��������:
  // ��� ������ ����� ��������� ���������
  // � 13 �� 14. ������ �� ���������� �� ��
  // ���� NextTime �����, ������ ����������� ������������
  // ��� �� ����. ��� ������ ������ ������� ��������
  // ��� ������� � ������� � ����. ���������,
  // ���� �������� ��� � ������� (�� ����� 15:00),
  // �� �������� �������� ����� ��� ������� ����������
  // ���������. ��. ����� ����� �� ����������!
  //
  // ���� �������� ��� ��������, �� ���������
  // ����� ������ ������� ��������� �������� �
  // ������� � ����.

  if FExactDate > 0 then
  begin
    FNextStartTime := FExactDate + FStartTime;
    FNextEndTime := FExactDate + FEndTime;
  end
  else if FDaily then
  begin
    if FNextStartTime > 0 then
    begin
      FNextStartTime := FNextStartTime + 1;
      FNextEndTime := FNextEndTime + 1;
    end else
    begin
      FNextStartTime := Date + FStartTime;
      FNextEndTime := Date + FEndTime;
    end;
  end
  else if FWeekly > 0 then
  begin
    if FNextStartTime > 0 then
    begin
      FNextStartTime := FNextStartTime + 7;
      FNextEndTime := FNextEndTime + 7;
    end else
    begin
      FNextStartTime := Date - DayOfWeek(Date) + 1 + FWeekly + FStartTime;
      FNextEndTime := FNextStartTime - FStartTime + FEndTime;
    end;
  end
  else if FMonthly > 0 then
  begin
    if FNextStartTime > 0 then
      FNextStartTime := IncMonth(FNextStartTime, 1)
    else begin
      DecodeDate(Date, Y, M, D);
      if (M in [4, 6, 9, 11]) and (FMonthly = 31) then
        K := 30
      else if (M = 2) and IsLeapYear(Y) and (FMonthly > 29) then
        K := 29
      else if (M = 2) and (not IsLeapYear(Y)) and (FMonthly > 28) then
        K := 28
      else
        K := FMonthly;
      FNextStartTime := EncodeDate(Y, M, K) + FStartTime;
    end;
    FNextEndTime := FNextStartTime - FStartTime + FEndTime
  end
  else if FMonthly < 0 then
  begin
    if FNextStartTime > 0 then
      FNextStartTime := IncMonth(FNextStartTime, 1)
    else begin
      DecodeDate(Date, Y, M, D);
      FNextStartTime := IncMonth(EncodeDate(Y, M, 1), 1) + FMonthly + FStartTime;
    end;
    FNextEndTime := FNextStartTime - FStartTime + FEndTime
  end;
end;

function TgdAutoTask.IsAsync: Boolean;
begin
  Result := False;
end;

function TgdAutoTask.Compare(ATask: TgdAutoTask): Integer;
begin
  if FNextStartTime < ATask.FNextStartTime then
    Result := -1
  else if FNextStartTime > ATask.FNextStartTime then
    Result := +1
  else if FPriority < ATask.FPriority then
    Result := -1
  else if FPriority > ATask.FPriority then
    Result := +1
  else
    Result := 0;      
end;

procedure TgdAutoTask.LogEndTask;
begin
  Log('Done');
end;

procedure TgdAutoTask.LogStartTask;
begin
  Log('Started');
end;

procedure TgdAutoTask.LogErrorMsg;
begin
  Log(FErrorMsg);
end;

procedure TgdAutoTask.Log(const AMsg: String);
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(gdcBaseManager <> nil);
  Assert(IBLogin <> nil);

  q := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := gdcBaseManager.Database;
    Tr.StartTransaction;
    q.Transaction := Tr;
    q.SQL.Text :=
      'INSERT INTO gd_autotask_log (autotaskkey, eventtext, creationdate, creatorkey) ' +
      'VALUES (:atk, :etext, :cd, :ck)';
    q.ParamByName('atk').AsInteger := ID;
    q.ParamByName('etext').AsString := AMsg;
    q.ParamByName('cd').AsDateTime := Now;
    q.ParamByName('ck').AsInteger := IBLogin.ContactKey;
    q.ExecQuery;
    Tr.Commit;
  finally
    q.Free;
    Tr.Free;
  end;
end;

{ TgdAutoTaskThread }

constructor TgdAutoTaskThread.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  Priority := tpLowest;
  FNotificationContext := gdNotifierThread.GetNextContext;
end;

destructor TgdAutoTaskThread.Destroy;
begin
  inherited;
  FTaskList.Free;
end;

procedure TgdAutoTaskThread.LoadFromRelation;
var
  q: TIBSQL;
  Task: TgdAutoTask;
begin
  Assert(gdcBaseManager <> nil);
  Assert(IBLogin <> nil);

  q := TIBSQL.Create(nil);
  try
    q.Transaction := gdcBaseManager.ReadTransaction;
    q.SQL.Text :=
      'SELECT * FROM gd_autotask ' +
      'WHERE disabled = 0 ' +
      '  AND (userkey IS NULL OR userkey = :uk)';
    q.ParamByName('uk').AsInteger := IBLogin.UserKey;
    q.ExecQuery;

    while not q.EOF do
    begin
      if q.FieldByName('functionkey').AsInteger > 0 then
      begin
        Task := TgdAutoFunctionTask.Create;
        (Task as TgdAutoFunctionTask).FunctionKey := q.FieldbyName('functionkey').AsInteger;
      end else
      if q.FieldByName('cmdline').AsString > '' then
      begin
        Task := TgdAutoCmdTask.Create;
        (Task as TgdAutoCmdTask).CmdLine := q.FieldbyName('cmdline').AsString;
      end else
      if q.FieldByName('backupfile').AsString > '' then
      begin
        Task := TgdAutoBackupTask.Create;
        (Task as TgdAutoBackupTask).BackupFile := q.FieldbyName('backupfile').AsString;
      end else
        Task := nil;

      if Task <> nil then
      begin
        Task.Id := q.FieldbyName('id').AsInteger;
        Task.Name := q.FieldbyName('name').AsString;
        Task.Description := q.FieldbyName('description').AsString;
        Task.ExactDate := q.FieldbyName('exactdate').AsDateTime;
        Task.Monthly := q.FieldbyName('monthly').AsInteger;
        Task.Weekly := q.FieldbyName('weekly').AsInteger;
        Task.Daily := q.FieldbyName('daily').AsInteger <> 0;
        if q.FieldbyName('starttime').IsNull then
          Task.StartTime := 0
        else
          Task.StartTime := q.FieldbyName('starttime').AsTime;
        if q.FieldbyName('endtime').IsNull then
          Task.EndTime := 1
        else
          Task.EndTime := q.FieldbyName('endtime').AsTime;
        Task.Priority := q.FieldbyName('priority').AsInteger;
        Task.Schedule;

        if FTaskList = nil then
          FTaskList := TObjectList.Create(True);
        FTaskList.Add(Task);
      end;

      q.Next;
    end;
  finally
    q.Free;
  end;
end;

procedure TgdAutoTaskThread.Timeout;
begin
  if FTaskList = nil then
  begin
    SendNotification('�������� ������ ���������...');
    Synchronize(LoadFromRelation);
    if (FTaskList = nil) or (FTaskList.Count = 0) then
    begin
      SendNotification('��� ��������� ��� ����������.');
      ExitThread;
      exit;
    end;
  end;

  PostMsg(WM_GD_FIND_AND_EXECUTE_TASK);
end;

function TgdAutoTaskThread.ProcessMessage(var Msg: TMsg): Boolean;
begin
  case Msg.Message of
    WM_GD_FIND_AND_EXECUTE_TASK:
    begin
      FindAndExecuteTask;

      if (FTaskList = nil) or (FTaskList.Count = 0) then
      begin
        SendNotification('��� ���������� ���������.');
        ExitThread;
      end;

      Result := True;
    end;
  else
    Result := False;
  end;
end;

procedure TgdAutoTaskThread.SendNotification(const AText: String);
begin
  gdNotifierThread.Add(AText, FNotificationContext, 4000);
end;

procedure TgdAutoTaskThread.SetInitialDelay;
begin
  Resume;
  SetTimeOut(5 {* 60} * 1000);
  SendNotification('������ ��������� ����� 5 ������.');
end;

procedure TgdAutoTaskThread.FindAndExecuteTask;
var
  AT: TgdAutoTask;
begin
  Synchronize(UpdateTaskList);

  if (FTaskList = nil) or (FTaskList.Count = 0) then
    exit;

  AT := FTaskList[0] as TgdAutoTask;

  if AT.NextStartTime <= Now then
  begin
    if AT.NextEndTime >= Now then
      AT.Execute;

    if AT.ExactDate = 0 then
      AT.Schedule
    else
      Synchronize(RemoveExecuteOnceTask);

    PostMsg(WM_GD_FIND_AND_EXECUTE_TASK);
  end else
  begin
    SetTimeOut(Round((AT.NextStartTime - Now) * MSecsPerDay));
    SendNotification('���������� ���������� "' + AT.Name + '" ��������� �� ' +
      FormatDateTime('hh:nn dd.mm.yyyy', AT.NextStartTime));
  end;
end;

procedure TgdAutoTaskThread.UpdateTaskList;
var
  q: TIBSQL;
  C: Integer;
begin
  Assert(gdcBaseManager <> nil);
  Assert(IBLogin <> nil);

  SortTaskList;
  C := 0;
  q := TIBSQL.Create(nil);
  try
    q.Transaction := gdcBaseManager.ReadTransaction;
    q.SQL.Text :=
      'SELECT t.disabled, t.userkey, l.creationdate ' +
      'FROM gd_autotask t LEFT JOIN gd_autotask_log l ' +
      '  ON t.id = l.autotaskkey AND l.creationdate >= :et ' +
      'WHERE t.id = :id';

    while C < FTaskList.Count do
    begin
      q.Close;
      q.ParamByName('id').AsInteger := (FTaskList[0] as TgdAutoTask).ID;
      q.ParamByName('et').AsDateTime := (FTaskList[0] as TgdAutoTask).NextStartTime;
      q.ExecQuery;

      if q.EOF or (q.FieldbyName('disabled').AsInteger <> 0)
        or ((q.FieldByName('userkey').AsInteger <> 0) and
          (q.FieldbyName('userkey').AsInteger <> IBLogin.UserKey)) then
      begin
        FTaskList.Delete(0);
        continue;
      end;

      if q.FieldByName('creationdate').IsNull then
        break;

      if (FTaskList[0] as TgdAutoTask).ExactDate > 0 then
        FTaskList.Delete(0)
      else begin
        (FTaskList[0] as TgdAutoTask).Schedule;
        SortTaskList;
        Inc(C);
      end;
    end;
  finally
    q.Free;
  end;
end;

procedure TgdAutoTaskThread.SortTaskList;
var
  I, J: Integer;
begin
  for I := 0 to FTaskList.Count - 2 do
    for J := I + 1 to FTaskList.Count - 1 do
      if (FTaskList[I] as TgdAutoTask).Compare(FTaskList[I] as TgdAutoTask) < 0 then
        FTaskList.Exchange(J, I);
end;

procedure TgdAutoTaskThread.RemoveExecuteOnceTask;
begin
  Assert(gdcBaseManager <> nil);

  if (FTaskList <> nil) and (FTaskList.Count > 0)
    and ((FTaskList[0] as TgdAutoTask).ExactDate > 0) then
  try
    gdcBaseManager.ExecSingleQuery(
      'UPDATE gd_autotask SET disabled = 1 WHERE id = ' +
        IntToStr((FTaskList[0] as TgdAutoTask).ID));
  except
    // small chance that there would be a deadlock
    // but we don't care      
  end;
end;

{ TgdAutoFunctionTask }

procedure TgdAutoFunctionTask.TaskExecute;
var
  F: TrpCustomFunction;
  P: Variant;
begin
  F := glbFunctionList.FindFunction(Self.FFunctionKey);
  if Assigned(F) then
  try
    try
      P := VarArrayOf([]);
      if ScriptFactory.InputParams(F, P) then
        ScriptFactory.ExecuteFunction(F, P);
    except
      on E: Exception do
        FErrorMsg := E.Message;
    end;
  finally
    glbFunctionList.ReleaseFunction(F);
  end;
end;

{ TgdAutoCmdTask }

function TgdAutoCmdTask.IsAsync: Boolean;
begin
  Result := True;
end;

procedure TgdAutoCmdTask.TaskExecute;
var
  ExecInfo: TShellExecuteInfo;
begin
  FillChar(ExecInfo, SizeOf(ExecInfo), 0);
  ExecInfo.cbSize := SizeOf(ExecInfo);
  ExecInfo.Wnd := 0;
  ExecInfo.lpVerb := 'open';
  ExecInfo.lpFile := PChar(FCmdLine);
  ExecInfo.lpParameters := nil;
  ExecInfo.lpDirectory := nil;
  ExecInfo.nShow := SW_SHOWNORMAL;
  ExecInfo.fMask := SEE_MASK_FLAG_NO_UI;

  if not ShellExecuteEx(@ExecInfo) then
    FErrorMsg := SysErrorMessage(GetLastError);
end;

{ TgdAutoBackupTask }

function TgdAutoBackupTask.IsAsync: Boolean;
begin
  Result := True;
end;

procedure TgdAutoBackupTask.TaskExecute;
var
  FN, FE: String;
  Res: OleVariant;
  IBService: TIBBackupService;
  Port: Integer;
  Server, FileName: String;
begin
  try
    gdcBaseManager.ExecSingleQueryResult(
      'SELECT ibpassword FROM gd_user WHERE ibname=''SYSDBA'' ',
      Unassigned, Res);

    if (not VarIsEmpty(Res)) {and (not Application.Terminated)} then
    begin
      ParseDatabaseName(IBLogin.DatabaseName, Server, Port, FileName);

      IBService := TIBBackupService.Create(nil);
      try
        IBService.ServerName := Server;

        if IBService.ServerName > '' then
          IBService.Protocol := TCP
        else
          IBService.Protocol := Local;

        IBService.LoginPrompt := False;
        IBService.Params.Clear;
        IBService.Params.Add('user_name=' + SysDBAUserName);
        IBService.Params.Add('password=' + Res[0, 0]);
        try
          IBService.Active := True;
          if not IBService.Active then
            FErrorMsg := '���������� ��������� ������ ��������� �����������/�������������� ������.'
        except
          IBService.Active := False;
          exit;
        end;

        IBService.Verbose := False;
        IBService.Options := [NoGarbageCollection];
        IBService.DatabaseName := FileName;

        FN := BackupFile;
        FE := ExtractFileExt(FN);
        SetLength(FN, Length(FN) - Length(FE));
        FN := FN + FormatDateTime('yyyymmdd', Now);
        if FE > '.' then
          FN := FN + FE;

        IBService.BackupFile.Add(FN);

        try
          IBService.ServiceStart;
          while (not IBService.Eof)
            and (IBService.IsServiceRunning) do
          begin
            IBService.GetNextLine;
          end;

          IBService.Active := False;
        except
          on E: Exception do
          begin
            FErrorMsg := E.Message;
          end;
        end;

      finally
        IBService.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      FErrorMsg := E.Message;
    end;
  end;
end;


initialization
  gdAutoTaskThread := nil;
end.
