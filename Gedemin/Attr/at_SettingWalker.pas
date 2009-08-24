
unit at_SettingWalker;

interface

uses
  Classes, DB, DBClient, SysUtils, gdcBaseInterface, gdcBase;

type
  TatSettingWalker = class;

  TgdcStartLoadingCallBack = procedure(Sender: TatSettingWalker;
    AnObjectSet: TgdcObjectSet) of object;
  TgdcObjectLoadCallBack = procedure(Sender: TatSettingWalker;
    const AClassName, ASubType: String;
    ADataSet: TDataSet; APrSet: TgdcPropertySet;
    const ASR: TgsStreamRecord) of object;
  {$IFDEF NEW_STREAM}
  TgdcStartLoadingNewCallBack = procedure(Sender: TatSettingWalker) of object;
  TgdcObjectLoadNewCallBack = procedure(Sender: TatSettingWalker;
    const AClassName, ASubType: String; ADataSet: TDataSet) of object;
  {$ENDIF}

  TatSettingWalker = class(TObject)
  private
    FStartLoading: TgdcStartLoadingCallBack;
    FObjectLoad: TgdcObjectLoadCallBack;
    {$IFDEF NEW_STREAM}
    FStartLoadingNew: TgdcStartLoadingNewCallBack;
    FObjectLoadNew: TgdcObjectLoadNewCallBack;
    {$ENDIF}
    FStream: TStream;
    FSettingObj: TgdcBase;

  public
    procedure ParseStream;

    property StartLoading: TgdcStartLoadingCallBack read FStartLoading
      write FStartLoading;
    property ObjectLoad: TgdcObjectLoadCallBack read FObjectLoad write FObjectLoad;
    {$IFDEF NEW_STREAM}
    property StartLoadingNew: TgdcStartLoadingNewCallBack read FStartLoadingNew write FStartLoadingNew;
    property ObjectLoadNew: TgdcObjectLoadNewCallBack read FObjectLoadNew write FObjectLoadNew;
    {$ENDIF}
    property Stream: TStream read FStream write FStream;
    property SettingObj: TgdcBase read FSettingObj write FSettingObj;
  end;

implementation

{$IFDEF NEW_STREAM}
uses
  gdcStreamSaver;
{$ENDIF NEW_STREAM}

{ TatSettingWalker }

procedure TatSettingWalker.ParseStream;

  function StreamReadString(St: TStream): String;
  var
    L: Integer;
  begin
    St.ReadBuffer(L, SizeOf(L));
    SetLength(Result, L);
    if L > 0 then
      St.ReadBuffer(Result[1], L);
  end;

var
  I: Integer;
  MS: TMemoryStream;
  LoadClassName, LoadSubType: String;
  CDS: TClientDataSet;
  OS: TgdcObjectSet;
  OldPos: Integer;
  stRecord: TgsStreamRecord;
  stVersion: string;
  PrSet: TgdcPropertySet;
  {$IFDEF NEW_STREAM}
  StreamLoadingOrderList: TgdcStreamLoadingOrderList;
  StreamDataObject: TgdcStreamDataObject;
  StreamWriterReader: TgdcStreamWriterReader;
  OrderElement: TStreamOrderElement;
  Obj: TgdcBase;
  StreamType: TgsStreamType;
  {$ENDIF NEW_STREAM}
begin
  {$IFDEF NEW_STREAM}
  // �������� ��� ������
  StreamType := GetStreamType(Stream);
  if StreamType = sttUnknown then
    Exit;

  // ������������ ����� ����� ��� ������ �������
  if StreamType <> sttBinaryOld then
  begin

    if Assigned(FStartLoadingNew) then
      FStartLoadingNew(Self);

    if Assigned(FObjectLoadNew) then
    begin
      StreamLoadingOrderList := TgdcStreamLoadingOrderList.Create;
      StreamDataObject := TgdcStreamDataObject.Create;
      PrSet := TgdcPropertySet.Create('', nil, '');
      try

        if StreamType = sttXML then
          StreamWriterReader := TgdcStreamXMLWriterReader.Create(StreamDataObject, StreamLoadingOrderList)
        else
          StreamWriterReader := TgdcStreamBinaryWriterReader.Create(StreamDataObject, StreamLoadingOrderList);

        // ��������� ������ �� ������
        try
          StreamWriterReader.LoadFromStream(Stream);
        finally
          StreamWriterReader.Free;
        end;

        while StreamLoadingOrderList.PopNextElement(OrderElement) do
        begin
          Obj := StreamDataObject.gdcObject[OrderElement.DSIndex];
          CDS := StreamDataObject.ClientDS[OrderElement.DSIndex];
          if CDS.Locate(Obj.GetKeyField(Obj.SubType), OrderElement.RecordID, []) then
            FObjectLoadNew(Self, Obj.ClassName, Obj.SubType, CDS)
          else
            raise Exception.Create('TatSettingWalker.ParseStream: � ������-�������� �� ������ ����������� ID');
        end;

      finally
        PrSet.Free;
        StreamDataObject.Free;
        StreamLoadingOrderList.Free;
      end;
    end;
  end
  else
  begin
  {$ENDIF NEW_STREAM}
    OS := TgdcObjectSet.Create(TgdcBase, '');
    PrSet := TgdcPropertySet.Create('', nil, '');
    try
      OS.LoadFromStream(Stream);

      if Assigned(FStartLoading) then
        FStartLoading(Self, OS);

      {try}
        while Stream.Position < Stream.Size do
        begin
          Stream.ReadBuffer(I, SizeOf(I));
          if I <> $55443322 then
            raise Exception.Create('error');

          OldPos := Stream.Position;
          SetLength(stVersion, Length(cst_WithVersion));
          Stream.ReadBuffer(stVersion[1], Length(cst_WithVersion));
          if stVersion = cst_WithVersion then
          begin
            Stream.ReadBuffer(stRecord.StreamVersion, SizeOf(stRecord.StreamVersion));
            if stRecord.StreamVersion >= 1 then
              Stream.ReadBuffer(stRecord.StreamDBID, SizeOf(stRecord.StreamDBID));
          end else
          begin
            stRecord.StreamVersion := 0;
            stRecord.StreamDBID := -1;
            Stream.Position := OldPos;
          end;

          LoadClassName := StreamReadString(Stream);
          LoadSubType := StreamReadString(Stream);

          if stRecord.StreamVersion >= 2 then
          begin
            PrSet.LoadFromStream(Stream);
          end;

          Stream.ReadBuffer(I, SizeOf(I));
          CDS := nil;
          MS := TMemoryStream.Create;
          try
            MS.CopyFrom(Stream, I);
            MS.Position := 0;
            CDS := TClientDataSet.Create(nil);
            CDS.LoadFromStream(MS);
            CDS.Open;

            if Assigned(FObjectLoad) then
              FObjectLoad(Self, LoadClassName, LoadSubType, CDS, PrSet, stRecord);
          finally
            CDS.Free;
            MS.Free;
          end;

        end;

      {except
        On E: EOutOfMemory do
        begin
          MessageBox(0,
            '��� ����������� ���� ������ ��������� ������������ ��������� ����������� ������.',
            '��������',
            MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
        end;
      end;}
    finally
      PrSet.Free;
      OS.Free;
    end;
  {$IFDEF NEW_STREAM}
  end;
  {$ENDIF NEW_STREAM}
end;

end.
