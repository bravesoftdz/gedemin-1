�
 TDLGEDITTEMPLATE 0�  TPF0TdlgEditTemplatedlgEditTemplateLeft� Top� BorderStylebsDialogCaption��������� �������ClientHeight� ClientWidth�Color	clBtnFaceFont.CharsetRUSSIAN_CHARSET
Font.ColorclWindowTextFont.Height�	Font.NameMS Sans Serif
Font.Style OldCreateOrderPositionpoScreenCenterOnCreate
FormCreatePixelsPerInchx
TextHeight TLabelLabel1Left
TopWidthgHeightCaption������������  TLabelLabel2Left
Top+WidthCHeightCaption��������  TLabelLabel3Left
ToppWidthXHeightCaption��� �������  TDBEditdbeNameLeft� Top
Width� Height	DataFieldNAME
DataSource
dsTemplateTabOrder   TDBEditdbeDescriptionLeft� Top'Width� HeightBAutoSize	DataFieldDESCRIPTION
DataSource
dsTemplateTabOrder  TDBLookupComboBox	dblcbTypeLeft� ToplWidth� Height	DataFieldTEMPLATETYPE
DataSource
dsTemplateKeyFieldTemplateType	ListFieldDescriptionType
ListSourcedsTemplateTypeTabOrder  TButtonbtnOkLeft� Top� Width]HeightCaptionOKDefault	TabOrderOnClick
btnOkClick  TButton	btnCancelLeftOTop� Width\HeightCancel	Caption������ModalResultTabOrder  TButtonbtnEditTemplateLeft�ToplWidthHeightActionactEditTemplateTabOrder  TButtonbtnHelpLeft
Top� Width\HeightActionactHelpTabOrder  TButtonbtnRigthLeftlTop� Width]HeightActionactRightTabOrder  
TIBDataSetibdsTemplateTransactionibtrTemplateBufferChunks�CachedUpdatesDeleteSQL.Stringsdelete from rp_reporttemplatewhere  ID = :OLD_ID InsertSQL.Stringsinsert into rp_reporttemplateD  (ID, NAME, DESCRIPTION, TEMPLATEDATA, TEMPLATETYPE, AFULL, ACHAG, AVIEW,    RESERVED)valuesC  (:ID, :NAME, :DESCRIPTION, :TEMPLATEDATA, :TEMPLATETYPE, :AFULL, :ACHAG,    :AVIEW, :RESERVED) RefreshSQL.StringsSelect   *from rp_reporttemplate where
  ID = :ID SelectSQL.StringsSELECT  *FROM  rp_reporttemplateWHERE
  id = :id ModifySQL.Stringsupdate rp_reporttemplateset  ID = :ID,  NAME = :NAME,  DESCRIPTION = :DESCRIPTION,  TEMPLATEDATA = :TEMPLATEDATA,  TEMPLATETYPE = :TEMPLATETYPE,  AFULL = :AFULL,  ACHAG = :ACHAG,  AVIEW = :AVIEW,  RESERVED = :RESERVEDwhere  ID = :OLD_ID LeftpTop(  TIBTransactionibtrTemplateActiveParams.Stringsread_committedrec_versionnowait AutoStopActionsaNoneLeftpTop  TClientDataSetcdsTemplateType
Aggregates Params LeftpTopH TStringFieldcdsTemplateTypeTemplateType	FieldNameTemplateType  TStringFieldcdsTemplateTypeDescriptionType	FieldNameDescriptionType   TDataSourcedsTemplateTypeDataSetcdsTemplateTypeLeftPTopH  TDataSource
dsTemplateDataSetibdsTemplateOnDataChangedsTemplateDataChangeLeftPTop(  TActionListActionList1LeftPTop TActionactEditTemplateCaption...	OnExecuteactEditTemplateExecuteOnUpdateactEditTemplateUpdate  TActionactHelpCaption�������  TActionactRightCaption�����    