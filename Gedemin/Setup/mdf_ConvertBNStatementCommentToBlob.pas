unit mdf_ConvertBNStatementCommentToBlob;

interface

uses
  IBDatabase, gdModify;

procedure ConvertBNStatementCommentToBlob(IBDB: TIBDatabase; Log: TModifyLog);
procedure ConvertDatePeriodComponent(IBDB: TIBDatabase; Log: TModifyLog);

implementation

uses
  Classes, DB, IBSQL, IBBlob, SysUtils, mdf_MetaData_unit, jclStrings;

procedure ConvertBNStatementCommentToBlob(IBDB: TIBDatabase; Log: TModifyLog);
const
  STATEMENT_RELATION_NAME = 'BN_BANKSTATEMENTLINE';
  COMMENT_FIELD_NAME      = 'COMMENT';
  NEW_DOMAIN_NAME         = 'DBLOBTEXT80_1251';
var
  FTransaction: TIBTransaction;
  FIBSQL: TIBSQL;
  I: Integer;
  TempCommentFieldName: String;
begin
  FTransaction := TIBTransaction.Create(nil);
  FIBSQL := TIBSQL.Create(nil);
  try
    FTransaction.DefaultDatabase := IBDB;
    try
      FTransaction.StartTransaction;
      FIBSQL.Transaction := FTransaction;
      FIBSQL.ParamCheck := False;

      // ���� ���������� ��� ���������� ����
      for I := 0 to 999 do
      begin
        TempCommentFieldName := COMMENT_FIELD_NAME + IntToStr(I);
        if FieldExist2(STATEMENT_RELATION_NAME, TempCommentFieldName, FTransaction) then
          TempCommentFieldName := ''
        else
          Break;
      end;

      if TempCommentFieldName = '' then
        raise Exception.Create('���������� ������������� ���� � ' + STATEMENT_RELATION_NAME);

      FIBSQL.SQL.Text := 'ALTER TABLE ' + STATEMENT_RELATION_NAME  +
        ' ALTER ' + COMMENT_FIELD_NAME + ' TO ' + TempCommentFieldName;
      FIBSQL.ExecQuery;

      FTransaction.Commit;
      FTransaction.StartTransaction;

      // ������� ���� � ����� ����� ������
      AddField2(STATEMENT_RELATION_NAME, COMMENT_FIELD_NAME, NEW_DOMAIN_NAME, FTransaction);

      FTransaction.Commit;
      FTransaction.StartTransaction;

      FIBSQL.SQL.Text := 'UPDATE ' + STATEMENT_RELATION_NAME + ' SET ' +
        COMMENT_FIELD_NAME + '=' + TempCommentFieldName;
      FIBSQL.ExecQuery;

      // ������ ��������� ����
      DropField2(STATEMENT_RELATION_NAME, TempCommentFieldName, FTransaction);

      FIBSQL.SQL.Text :=
        'UPDATE OR INSERT INTO fin_versioninfo ' +
        '  VALUES (126, ''0000.0001.0000.0157'', ''05.11.2010'', ''Relation field BN_BANKSTATEMENTLINE.COMMENT has been extended'') ' +
        '  MATCHING (id)';
      FIBSQL.ExecQuery;
      FIBSQL.Close;

      FTransaction.Commit;
    except
      on E: Exception do
      begin
        Log('��������� ������: ' + E.Message);
        if FTransaction.InTransaction then
          FTransaction.Rollback;
        raise;
      end;
    end;
  finally
    FIBSQL.Free;
    FTransaction.Free;
  end;
end;

procedure ConvertDatePeriodComponent(IBDB: TIBDatabase; Log: TModifyLog);
var
  FTransaction: TIBTransaction;
  FIBSQL, qUpdate: TIBSQL;
  SL: TStringList;
  S: String;
begin
  FTransaction := TIBTransaction.Create(nil);
  FIBSQL := TIBSQL.Create(nil);
  qUpdate := TIBSQL.Create(nil);
  SL := TStringList.Create;
  try
    FTransaction.DefaultDatabase := IBDB;
    try
      FTransaction.StartTransaction;
      FIBSQL.Transaction := FTransaction;
      qUpdate.Transaction := FTransaction;

      qUpdate.SQL.Text := 'UPDATE gd_function SET script = :s WHERE id = :id';

      FIBSQL.SQL.Text := 'SELECT id, script FROM gd_function';
      FIBSQL.ExecQuery;

      while not FIBSQL.EOF do
      begin
        S := FIBSQL.FieldByName('script').AsString;

        S := StringReplace(S, 'F.FindComponent("xdeStart").Text = Params(0)', 'F.DateBegin = Params(0)',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S, 'F.FindComponent("xdeFinish").Text = Params(1)', 'F.DateEnd = Params(1)',
          [rfReplaceAll, rfIgnoreCase]);

        S := StringReplace(S, 'F.FindComponent("xdeStart").Date = BeginDate', 'F.DateBegin = BeginDate',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S, 'F.FindComponent("xdeFinish").Date = EndDate', 'F.DateEnd = EndDate',
          [rfReplaceAll, rfIgnoreCase]);

        S := StringReplace(S, 'OwnerForm.FindComponent("xdeStart").Text +', 'OwnerForm.DateBegin &',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S, 'OwnerForm.FindComponent("xdeFinish").Text +', 'OwnerForm.DateEnd &',
          [rfReplaceAll, rfIgnoreCase]);

        S := StringReplace(S, 'OwnerForm.GetComponent("xdeStart").Text +', 'OwnerForm.DateBegin &',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S, 'OwnerForm.GetComponent("xdeFinish").Text +', 'OwnerForm.DateEnd &',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S, '+ OwnerForm.GetComponent("xdeFinish").Text', '& OwnerForm.DateEnd',
          [rfReplaceAll, rfIgnoreCase]);

        S := StringReplace(S, 'AccountForm.GetComponent("xdeStart").Date =', 'AccountForm.DateBegin =',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S, 'AccountForm.GetComponent("xdeFinish").Date =', 'AccountForm.DateEnd =',
          [rfReplaceAll, rfIgnoreCase]);

        S := StringReplace(S, 'a(1) = OwnerForm.FindComponent("xdeStart").Text', 'a(1) = OwnerForm.DateBegin',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S, 'a(2) = OwnerForm.FindComponent("xdeFinish").Text', 'a(2) = OwnerForm.DateEnd',
          [rfReplaceAll, rfIgnoreCase]);

        S := StringReplace(S, 'DateBegin = OwnerForm.FindComponent("xdeStart").date', 'DateBegin = OwnerForm.DateBegin',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S, 'DateEnd = OwnerForm.FindComponent("xdeFinish").date', 'DateEnd = OwnerForm.DateEnd',
          [rfReplaceAll, rfIgnoreCase]);

        S := StringReplace(S,
          'AdditionalInfo.FieldByName("DateBegin").AsString = OwnerForm.FindComponent("xdeStart").Text',
          'AdditionalInfo.FieldByName("DateBegin").AsDateTime = OwnerForm.DateBegin',
          [rfReplaceAll, rfIgnoreCase]);
        S := StringReplace(S,
          'AdditionalInfo.FieldByName("DateEnd").AsString = OwnerForm.FindComponent("xdeFinish").Text',
          'AdditionalInfo.FieldByName("DateEnd").AsDateTime = OwnerForm.DateEnd',
          [rfReplaceAll, rfIgnoreCase]);

        if StrIPos('DateBegin = DateSerial(Year, Month, 1)', S) > 0 then
        begin
          S := StringReplace(S, 'OwnerForm.FindComponent("xdeStart").date = DateBegin', 'OwnerForm.DateBegin = DateBegin',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'OwnerForm.FindComponent("xdeFinish").date = DateEnd', 'OwnerForm.DateEnd = DateEnd',
            [rfReplaceAll, rfIgnoreCase]);
        end;

        if StrIPos('a(2) = xdeStart.Text + " - " + xdeFinish.Text', S) > 0 then
        begin
          S := StringReplace(S, 'set xdeStart = OwnerForm.FindComponent("xdeStart")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'set xdeFinish = OwnerForm.FindComponent("xdeFinish")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'a(2) = xdeStart.Text + " - " + xdeFinish.Text', 'a(2) = OwnerForm.DateBegin & " - " & OwnerForm.DateEnd',
            [rfReplaceAll, rfIgnoreCase]);
        end;

        if StrIPos('IBDataSet.ParamByName("begindate").AsDateTime = xdeStart.Date', S) > 0 then
        begin
          S := StringReplace(S, 'set xdeStart = Sender.OwnerForm.FindComponent("xdeStart")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'set xdeFinish = Sender.OwnerForm.FindComponent("xdeFinish")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'IBDataSet.ParamByName("begindate").AsDateTime = xdeStart.Date',
            'IBDataSet.ParamByName("begindate").AsDateTime = Sender.OwnerForm.DateBegin',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'IBDataSet.ParamByName("enddate").AsDateTime = xdeFinish.Date',
            'IBDataSet.ParamByName("enddate").AsDateTime = Sender.OwnerForm.DateEnd',
            [rfReplaceAll, rfIgnoreCase]);
        end;

        if StrIPos('DataSet.ParamByName("begindate").AsDateTime = xdeStart.Date', S) > 0 then
        begin
          S := StringReplace(S, 'set xdeStart = Sender.OwnerForm.FindComponent("xdeStart")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'set xdeFinish = Sender.OwnerForm.FindComponent("xdeFinish")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'DataSet.ParamByName("begindate").AsDateTime = xdeStart.Date',
            'DataSet.ParamByName("begindate").AsDateTime = Sender.OwnerForm.DateBegin',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'DataSet.ParamByName("enddate").AsDateTime = xdeFinish.Date',
            'DataSet.ParamByName("enddate").AsDateTime = Sender.OwnerForm.DateEnd',
            [rfReplaceAll, rfIgnoreCase]);
        end;

        if StrIPos('SQL.ParamByName("datebegin").AsDateTime = xdeStart.DateTime', S) > 0 then
        begin
          S := StringReplace(S, 'set xdeStart = OwnerForm.FindComponent("xdeStart")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'set xdeFinish = OwnerForm.FindComponent("xdeFinish")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'SQL.ParamByName("datebegin").AsDateTime = xdeStart.DateTime',
            'SQL.ParamByName("datebegin").AsDateTime = OwnerForm.DateBegin',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'SQL.ParamByName("dateend").AsDateTime = xdeFinish.DateTime',
            'SQL.ParamByName("dateend").AsDateTime = OwnerForm.DateEnd',
            [rfReplaceAll, rfIgnoreCase]);
        end;

        if StrIPos('q.ParamByName("begindate").AsDateTime = xdeStart.Date', S) > 0 then
        begin
          S := StringReplace(S, 'set xdeStart = OwnerForm.FindComponent("xdeStart")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'set xdeFinish = OwnerForm.FindComponent("xdeFinish")', '',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'q.ParamByName("begindate").AsDateTime = xdeStart.Date',
            'q.ParamByName("begindate").AsDateTime = OwnerForm.DateBegin',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'q.ParamByName("enddate").AsDateTime = xdeFinish.Date',
            'q.ParamByName("enddate").AsDateTime = OwnerForm.DateEnd',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'Addition.FieldByName("datebegin").AsDateTime = xdeStart.Date',
            'Addition.FieldByName("datebegin").AsDateTime = OwnerForm.DateBegin',
            [rfReplaceAll, rfIgnoreCase]);
          S := StringReplace(S, 'Addition.FieldByName("dateend").AsDateTime = xdeFinish.Date',
            'Addition.FieldByName("dateend").AsDateTime = OwnerForm.DateEnd',
            [rfReplaceAll, rfIgnoreCase]);
        end;

        if (FIBSQL.FieldByName('script').AsString <> S) then
        begin
          qUpdate.ParamByName('id').AsInteger := FIBSQL.FieldByName('id').AsInteger;
          qUpdate.ParamByName('s').AsString := S;
          qUpdate.ExecQuery;
        end;

        FIBSQL.Next;
      end;

      FIBSQL.Close;
      FIBSQL.SQL.Text := 'delete from gd_storage_data where name containing ''xdeStart(TxDateEdit)'' ';
      FIBSQL.ExecQuery;

      FIBSQL.Close;
      FIBSQL.SQL.Text := 'delete from gd_storage_data where name containing ''xdeFinish(TxDateEdit)'' ';
      FIBSQL.ExecQuery;

      FIBSQL.SQL.Text :=
        'UPDATE OR INSERT INTO fin_versioninfo ' +
        '  VALUES (127, ''0000.0001.0000.0158'', ''08.11.2010'', ''Replacing references to xdeStart, xdeFinish components across macros'') ' +
        '  MATCHING (id)';
      FIBSQL.ExecQuery;
      FIBSQL.Close;

      FTransaction.Commit;
    except
      on E: Exception do
      begin
        Log('��������� ������: ' + E.Message);
        if FTransaction.InTransaction then
          FTransaction.Rollback;
        raise;
      end;
    end;
  finally
    SL.Free;
    qUpdate.Free;
    FIBSQL.Free;
    FTransaction.Free;
  end;
end;

end.
