object FoldersFrame: TFoldersFrame
  Left = 0
  Top = 0
  Width = 660
  Height = 350
  TabOrder = 0
  Visible = False
  OnResize = FrameResize
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 660
    Height = 350
    Align = alClient
    BevelOuter = bvNone
    Caption = 'pnlMain'
    TabOrder = 0
    object Splitter1: TSplitter
      Left = 321
      Top = 0
      Width = 3
      Height = 350
      Cursor = crHSplit
    end
    object pnlLeft: TPanel
      Left = 0
      Top = 0
      Width = 321
      Height = 350
      Align = alLeft
      BevelOuter = bvNone
      Caption = 'pnlLeft'
      TabOrder = 0
      object pnlCaptionLeft: TPanel
        Left = 0
        Top = 0
        Width = 321
        Height = 20
        Align = alTop
        Alignment = taLeftJustify
        BevelOuter = bvLowered
        TabOrder = 0
      end
      object sgFolder1: TStringGrid
        Left = 0
        Top = 20
        Width = 321
        Height = 330
        Align = alClient
        ColCount = 3
        DefaultRowHeight = 18
        DefaultDrawing = False
        FixedCols = 0
        RowCount = 2
        GridLineWidth = 0
        Options = [goFixedVertLine, goFixedHorzLine, goColSizing, goRowSelect]
        TabOrder = 1
        OnClick = sgFolder1Click
        OnDblClick = sgFolder1DblClick
        OnDrawCell = sgFolder1DrawCell
        OnTopLeftChanged = sgFolder1TopLeftChanged
      end
    end
    object pnlRight: TPanel
      Left = 324
      Top = 0
      Width = 336
      Height = 350
      Align = alClient
      BevelOuter = bvNone
      Caption = 'pnlRight'
      TabOrder = 1
      object pnlCaptionRight: TPanel
        Left = 0
        Top = 0
        Width = 336
        Height = 20
        Align = alTop
        Alignment = taLeftJustify
        BevelOuter = bvLowered
        TabOrder = 0
      end
      object sgFolder2: TStringGrid
        Left = 0
        Top = 20
        Width = 336
        Height = 330
        Align = alClient
        ColCount = 3
        DefaultRowHeight = 18
        DefaultDrawing = False
        FixedCols = 0
        RowCount = 2
        GridLineWidth = 0
        Options = [goFixedVertLine, goFixedHorzLine, goColSizing, goRowSelect]
        TabOrder = 1
        OnClick = sgFolder1Click
        OnDblClick = sgFolder1DblClick
        OnDrawCell = sgFolder1DrawCell
        OnTopLeftChanged = sgFolder1TopLeftChanged
      end
    end
  end
end
