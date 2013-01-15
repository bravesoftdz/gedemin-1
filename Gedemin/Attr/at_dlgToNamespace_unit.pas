unit at_dlgToNamespace_unit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Db, DBClient, StdCtrls, IBDatabase, gsIBLookupComboBox, Grids, DBGrids,
  gsDBGrid, ActnList, dmDatabase_unit, gdcBaseInterface, gdcBase,
  DBCtrls, Buttons;

type
  TdlgToNamespace = class(TForm)
    lkup: TgsIBLookupComboBox;
    cdsLink: TClientDataSet;
    dsMain: TDataSource;
    bShowLink: TButton;
    dbgrListLink: TgsDBGrid;
    eLimit: TEdit;
    lLimit: TLabel;
    lMessage: TLabel;
    ActionList: TActionList;
    actShowLink: TAction;
    IBTransaction: TIBTransaction;
    cbAlwaysOverwrite: TCheckBox;                                      
    cbDontRemove: TCheckBox;
    btnOK: TBitBtn;
    actOK: TAction;
    cbIncludeSiblings: TCheckBox;
    btnCancel: TBitBtn;
    actCancel: TAction;
    btnDelete: TBitBtn;
    actClear: TAction;
    procedure FormCreate(Sender: TObject);
    procedure actShowLinkExecute(Sender: TObject);
    procedure actOKExecute(Sender: TObject);
    procedure actCancelExecute(Sender: TObject);
    procedure actClearExecute(Sender: TObject);
  private
    FgdcObject: TgdcBase;
    FIsAdded: Boolean;

    procedure GetNamespace(AnObject: TgdcBase; out AnID: Integer; out AName: String);
    procedure CreateList(AnObject: TgdcBase);
    procedure DeleteObjects;
    procedure AddObjects;
    procedure OnChecked(Sender: TObject; CheckID: String;
      var Checked: Boolean);

  protected
    procedure DoCreate; override;
    procedure DoDestroy; override;
    procedure CreateFields;
  public
    procedure Setup(AgdcObject: TgdcBase);
    procedure LoadSettings; virtual;
    procedure SaveSettings; virtual;
  end;

var
  dlgToNamespace: TdlgToNamespace;

implementation

uses
  at_classes, gd_security, at_sql_parser, IBSQL, Storages, gdcNamespace;

{$R *.DFM}

const
  DefCount = 60;

procedure TdlgToNamespace.FormCreate(Sender: TObject);
begin
  CreateFields;

  cdsLink.CreateDataSet;
  cdsLink.Open;
  cdsLink.EmptyDataSet;

  eLimit.Text := IntToStr(DefCount);
  dbgrListLink.CheckBox.CheckBoxEvent := OnChecked;
  cbAlwaysOverwrite.Checked := True;
  cbDontRemove.Checked := False;
  cbIncludeSiblings.Checked := False;
end;

procedure TdlgToNamespace.CreateFields;
begin
  cdsLink.FieldDefs.Add('ID', ftInteger, 0, True);
  cdsLink.FieldDefs.Add('Name', ftString, 60, False);
  cdsLink.FieldDefs.Add('Class', ftString, 40, True);
  cdsLink.FieldDefs.Add('SubType', ftString, 60, False);
  cdsLink.FieldDefs.Add('Namespacekey', ftInteger, 0, False);
  cdsLink.FieldDefs.Add('Namespace', ftString, 255, False);
end;

procedure TdlgToNamespace.Setup(AgdcObject: TgdcBase);
var
  ID: Integer;
  Name: String;
  q: TIBSQL;
begin
  Assert(gdcBaseManager <> nil);
  Assert(AgdcObject <> nil);
  Assert(AgdcObject.RecordCount > 0);

  FgdcObject := AgdcObject;

  if not IBTransaction.InTransaction then
    IBTransaction.StartTransaction;
    
  FIsAdded := False;
  GetNamespace(FgdcObject, ID, Name);

  if ID <> -1 then
  begin
    FIsAdded := True;
    lkup.CurrentKeyInt := ID;
    q := TIBSQL.Create(nil);
    try
      q.Transaction := IBTransaction;
      q.SQL.Text := 'SELECT alwaysoverwrite, dontremove, includesiblings  FROM at_object WHERE xid = :xid AND dbid = :dbid';
      q.ParamByName('xid').AsInteger := FgdcObject.GetRuid.XID;
      q.ParamByName('dbid').AsInteger := FgdcObject.GetRuid.DBID;
      q.ExecQuery;

      if not q.EOF then
      begin
        cbAlwaysOverwrite.Checked := q.FieldByName('alwaysoverwrite').AsInteger = 1;
        cbDontRemove.Checked := q.FieldByName('dontremove').AsInteger = 1;
        cbIncludeSiblings.Checked := q.FieldByName('includesiblings').AsInteger = 1;
      end;
    finally
      q.Free;
    end;
  end;

  eLimit.Text := IntToStr(60);
end;

procedure TdlgToNamespace.DoCreate;
begin
  inherited;
  LoadSettings;
end;

procedure TdlgToNamespace.DoDestroy;
begin
  SaveSettings;
  inherited;
end;

procedure TdlgToNamespace.LoadSettings;
begin
  if Assigned(UserStorage) then
  begin
    UserStorage.LoadComponent(dbgrListLink, dbgrListLink.LoadFromStream);
  //  lkup.CurrentKeyInt := UserStorage.ReadInteger('dlgToNamespace', 'CurrentNamespace', -1);
  end;
end;

procedure TdlgToNamespace.SaveSettings;
begin
  if Assigned(UserStorage) then
  begin
    if dbgrListLink.SettingsModified then
      UserStorage.SaveComponent(dbgrListLink, dbgrListLink.SaveToStream);
   // UserStorage.WriteInteger('dlgToNamespace', 'CurrentNamespace', lkup.CurrentKeyInt);
  end;  
end;

procedure TdlgToNamespace.GetNamespace(AnObject: TgdcBase; out AnID: Integer; out AName: String);
var
  q: TIBSQL;
  RUID: TRUID;
begin
  Assert(AnObject <> nil);
  AnID := -1;
  AName := '';

  q := TIBSQL.Create(nil);
  try
    q.Transaction := IBTransaction;
    q.SQL.Text := 'SELECT n.id, n.name FROM at_object o ' +
      'LEFT JOIN at_namespace n ON o.namespacekey = n.id ' +
      'WHERE o.xid = :xid and o.dbid = :dbid';
    RUID := AnObject.GetRUID;
    q.ParamByName('xid').AsInteger := RUID.XID;
    q.ParamByName('dbid').AsInteger := RUID.DBID;
    q.ExecQuery;
    if not q.EOF then
    begin
      AnID := q.FieldByName('id').AsInteger;
      AName := q.FieldByName('name').AsString;
    end;
  finally
    q.Free;
  end;
end;

procedure TdlgToNamespace.DeleteObjects;
var
  q: TIBSQL;
  I: Integer;
  XID, DBID: TID;
begin
  q := TIBSQL.Create(nil);
  try
    q.Transaction := IBTransaction;
    q.SQL.Text := 'DELETE FROM at_object WHERE xid = :xid and dbid = :dbid';
    gdcBaseManager.GetRUIDByID(FgdcObject.ID, XID, DBID, IBTransaction);
    q.ParamByName('xid').AsInteger := XID;
    q.ParamByName('dbid').AsInteger := DBID;
    q.ExecQuery;

    q.Close;
    for I := 0 to dbgrListLink.CheckBox.CheckList.Count - 1 do
    begin
      if cdsLink.Locate('id', StrToInt(dbgrListLink.CheckBox.CheckList[I]), []) then
      begin
        gdcBaseManager.GetRUIDByID(cdsLink.FieldByName('id').AsInteger, XID, DBID, IBTransaction);
        q.ParamByName('xid').AsInteger := XID;
        q.ParamByName('dbid').AsInteger := DBID;
        q.ExecQuery;
        q.Close;
      end;
    end;
  finally
    q.Free;
  end;
end;

procedure TdlgToNamespace.AddObjects;
var
  I: Integer;
  q: TIBSQL;
  XID, DBID: TID;
begin
  q := TIBSQL.Create(nil);
  try
    q.Transaction := IBTransaction;
    q.SQL.Text :=
      'UPDATE OR INSERT INTO at_object ' +
      '  (namespacekey, objectname, objectclass, subtype, xid, dbid, ' +
      '  alwaysoverwrite, dontremove, includesiblings) ' +
      'VALUES (:NSK, :ON, :OC, :ST, :XID, :DBID, :OW, :DR, :IS) ' +
      'MATCHING (xid, dbid) ';
    q.ParamByName('NSK').AsInteger := lkup.CurrentKeyInt;
    q.ParamByName('ON').AsString := FgdcObject.FieldByName(FgdcObject.GetListField(FgdcObject.SubType)).AsString;
    q.ParamByName('OC').AsString := FgdcObject.ClassName;
    q.ParamByName('ST').AsString := FgdcObject.SubType;
    gdcBaseManager.GetRUIDByID(FgdcObject.ID, XID, DBID, IBTransaction);
    q.ParamByName('XID').AsInteger := XID;;
    q.ParamByName('DBID').AsInteger := DBID;
    q.ParamByName('OW').AsInteger := Integer(cbAlwaysOverwrite.Checked);
    q.ParamByName('DR').AsInteger := Integer(cbDontRemove.Checked);
    q.ParamByName('IS').AsInteger := Integer(cbIncludeSiblings.Checked);
    q.ExecQuery;

    q.Close;

    for I := 0 to dbgrListLink.CheckBox.CheckList.Count - 1 do
    begin
      if cdsLink.Locate('id', StrToInt(dbgrListLink.CheckBox.CheckList[I]), []) then
      begin
        q.ParamByName('NSK').AsInteger := lkup.CurrentKeyInt;
        q.ParamByName('ON').AsString := cdsLink.FieldByName('name').AsString;
        q.ParamByName('OC').AsString := cdsLink.FieldByName('class').AsString;
        q.ParamByName('ST').AsString := cdsLink.FieldByName('subtype').AsString;
        gdcBaseManager.GetRUIDByID(cdsLink.FieldByName('id').AsInteger, XID, DBID, IBTransaction);

        q.ParamByName('XID').AsInteger := XID;
        q.ParamByName('DBID').AsInteger := DBID;
        q.ExecQuery;
        q.Close;
      end;
    end;
  finally
    q.Free;
  end;
end;

procedure TdlgToNamespace.actShowLinkExecute(Sender: TObject);
begin
  cdsLink.EmptyDataSet;
  CreateList(FgdcObject);
end;

procedure TdlgToNamespace.actOKExecute(Sender: TObject);
begin
  if lkup.CurrentKey > '' then
    AddObjects
  else
    if FIsAdded then
      DeleteObjects;

  if IBTransaction.InTransaction then
    IBTransaction.Commit;
  ModalResult := mrOk;
end;

procedure TdlgToNamespace.OnChecked(Sender: TObject; CheckID: String;
  var Checked: Boolean);
begin
  if (not cdsLink.FieldByName('namespacekey').IsNull) and not FIsAdded then
  begin
    Checked := False;
    Application.MessageBox(PChar('������ �������� ������!'#13#10 +
      '������ ��� ������ � ������������ ���� ''' + cdsLink.FieldByName('namespace').AsString + '''!'),
      '��������',
      MB_OK or MB_ICONHAND or MB_TASKMODAL);
  end;
end;

procedure TdlgToNamespace.CreateList(AnObject: TgdcBase);

  procedure GetBindedObjectsForTable(const ATableName: String);
  const
    NotSavedField = ';LB;RB;CREATORKEY;EDITORKEY;';
  var
    R: TatRelation;
    I, ID: Integer;
    C: TgdcFullClass;
    Obj: TgdcBase;
    F: TField;
    Name: String;
  begin
    R := atDatabase.Relations.ByRelationName(ATableName);
    Assert(R <> nil);

    for I := 0 to R.RelationFields.Count - 1 do
    begin
      if cdsLink.RecordCount >= DefCount then
        break;

      if AnsiPos(';' + Trim(R.RelationFields[I].FieldName) + ';', NotSavedField) > 0 then
        continue;

      F := AnObject.FindField(R.RelationName, R.RelationFields[I].FieldName);
      if (F = nil) or F.IsNull or (F.DataType <> ftInteger) then
      begin
        continue;
      end;

      if R.RelationFields[I].gdClass <> nil then
      begin
        C.gdClass := CgdcBase(R.RelationFields[I].gdClass);
        C.SubType := R.RelationFields[I].gdSubType;
      end else
      begin
        C.gdClass := nil;
        C.SubType := '';
      end;

      if (C.gdClass = nil) and (R.RelationFields[I].References <> nil) then
      begin
        C := GetBaseClassForRelationByID(R.RelationFields[I].References.RelationName,
          AnObject.FieldByName(R.RelationName, R.RelationFields[I].FieldName).AsInteger,
          IBTransaction);
      end;

      if (C.gdClass <> nil) and
        (not (FgdcObject.ClassType.InheritsFrom(C.gdClass) and (F.AsInteger = FgdcObject.ID))) then
      begin
        Obj := C.gdClass.CreateSingularByID(nil,
          IBTransaction.DefaultDatabase,
          IBTransaction,
          F.AsInteger,
          C.SubType);
        try
          if not cdsLink.Locate('id', Obj.ID, []) then
          begin
            cdsLink.Insert;
            cdsLink.FieldByName('id').AsInteger := Obj.ID;
            cdsLink.FieldByName('Name').AsString := Obj.FieldByName(Obj.GetListField(Obj.SubType)).AsString;
            cdsLink.FieldByname('Class').AsString := Obj.ClassName;
            cdsLink.FieldByName('SubType').AsString := Obj.SubType;
            GetNamespace(Obj, ID, Name);
            if ID > -1 then
            begin
              cdsLink.FieldByName('Namespacekey').AsInteger := ID;
              cdsLink.FieldByName('namespace').AsString := Name;
            end;
            cdsLink.Post; 
          end;
          CreateList(Obj);
        finally
          Obj.Free;
        end;
      end;
    end;
  end;

var
  LinkTableList: TStringList;
  LT: TStrings;
  I: Integer;
begin
  Assert(atDatabase <> nil);

  LinkTableList := TStringList.Create;
  LT := TStringList.Create;
  try
    (LT as TStringList).Duplicates := dupIgnore;
    GetTablesName(AnObject.SelectSQL.Text, LT);
    LinkTableList.Clear;
    LinkTableList.Add(AnObject.GetListTable(FgdcObject.SubType));

    for I := 0 to LT.Count - 1 do
    begin
      if (LinkTableList.IndexOf(LT[I]) = -1)
        and (AnObject.ClassType.InheritsFrom(GetBaseClassForRelation(LT[I]).gdClass))
      then
        LinkTableList.Add(LT[I]);
    end;

    for I := 0 to LinkTableList.Count - 1 do
      GetBindedObjectsForTable(LinkTableList[I]);

    if FgdcObject.SetTable > '' then
      GetBindedObjectsForTable(AnObject.SetTable);
  finally
    LT.Free;
    LinkTableList.Free;
  end;
end;

procedure TdlgToNamespace.actCancelExecute(Sender: TObject);
begin
  if IBTransaction.InTransaction then
    IBTransaction.Rollback;
  ModalResult := mrCancel;
end;

procedure TdlgToNamespace.actClearExecute(Sender: TObject);
begin
  lkup.CurrentKey := '';
end;

end.
