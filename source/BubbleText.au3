;coded by UEZ build 2014-09-27
#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

Switch $CmdLine[0]
   Case 0
	  Exit
   Case 1
	  ShowBubbleText( $CmdLine[1] )
   Case 2
	  ShowBubbleText( $CmdLine[1], $CmdLine[2] )
   Case 3
	  ShowBubbleText( $CmdLine[1], $CmdLine[2], $CmdLine[3] )
   Case 4
	  ShowBubbleText( $CmdLine[1], $CmdLine[2], $CmdLine[3], $CmdLine[4] )
   Case 5
	  ShowBubbleText( $CmdLine[1], $CmdLine[2], $CmdLine[3], $CmdLine[4], $CmdLine[5] )
   Case 6
	  ShowBubbleText( $CmdLine[1], $CmdLine[2], $CmdLine[3], $CmdLine[4], $CmdLine[5], $CmdLine[6] )
EndSwitch

Func ShowBubbleText($sText, $sTitle="BubbleText", $iLeft=500, $iTop=500, $iW=300, $iTimeOut=5)
   _GDIPlus_Startup()
   Local Const $iLines = Round( StringLen( $sText) / 20 )
   Local Const $iH = $iLines*50	; More text, more lines.
   Local Const $STM_SETIMAGE = 0x0172
   Local $guiBubble = GUICreate($sTitle, $iW, $iH, $iLeft, $iTop, $WS_POPUP)
   Local $hPic = GUICtrlCreatePic("", 0, 0, $iW, $iH)
   Local $hRegion = _WinAPI_CreateRoundRectRgn(0, 0, $iW + 1, $iH + 1, 20, 20)
   _WinAPI_SetWindowRgn($guiBubble, $hRegion)
   Local $hGDIBmp_Bg = CreateRoundCornerText( $sText, $iW, $iH, 7)
   _WinAPI_DeleteObject(GUICtrlSendMsg($hPic, $STM_SETIMAGE, $IMAGE_BITMAP, $hGDIBmp_Bg))
   _WinAPI_DeleteObject($hGDIBmp_Bg)
   ; Fade in
   WinSetTrans( $guiBubble, "", 0)
   GUISetState(@SW_SHOW, $guiBubble)
   Local $iTimer = TimerInit()
   $iTimeOut *= 1000	; Conver to ms

   For $i= 5 to 255 Step 25
	  WinSetTrans($guiBubble, "", $i)
	  Sleep(25)
   Next

   Do
	  Switch GUIGetMsg()
		 Case $GUI_EVENT_CLOSE
			_WinAPI_DeleteObject($hRegion)
			; _WinAPI_DeleteObject($hGDIBmp_Bg)
			GUIDelete()
			_GDIPlus_Shutdown()
			Return
	  EndSwitch

	  If TimerDiff($iTimer) > $iTimeOut Then
		 ; Fade out.
		 For $i= 255 to 5 Step -25
			WinSetTrans($guiBubble, "", $i)
			Sleep(25)
		 Next
		 _WinAPI_DeleteObject($hRegion)
		 ; _WinAPI_DeleteObject($hGDIBmp_Bg)
		 GUIDelete()
		 _GDIPlus_Shutdown()
		 Return
	  EndIf
   Until False
EndFunc

Func CreateRoundCornerText( $sText, $iW, $iH, $iRadius_Corner = 10 )
    Local $iColorOuter_Bg = 0xFF202020, $iColorInner_Bg = 0xFFFFFFFF
	Local $iSizeBorder_Bg = 5
	Local $sFont = "Comic Sans MS", $fFontSize = 20
	Local $iColor_FontBorder = 0xFF101010, $iColor_Font = 0xFFFFFFFF, $iSizeBorder_Ft = 2, $bGDIBitmap = True
    Local Const $hBitmap = _GDIPlus_BitmapCreateFromScan0($iW, $iH), $hGraphics = _GDIPlus_ImageGetGraphicsContext($hBitmap)
    _GDIPlus_GraphicsSetSmoothingMode($hGraphics, 4)
    #Region background
    Local Const $hPath = _GDIPlus_PathCreate()
    Local $iWidth = $iW - $iSizeBorder_Bg - 1, $iHeight = $iH - $iSizeBorder_Bg - 1
    _GDIPlus_PathAddArc($hPath, $iSizeBorder_Bg / 2, $iSizeBorder_Bg / 2, $iRadius_Corner * 2, $iRadius_Corner * 2, 180, 90) ;left upper corner
    _GDIPlus_PathAddArc($hPath, $iWidth - $iRadius_Corner * 2 + $iSizeBorder_Bg / 2, $iSizeBorder_Bg / 2, $iRadius_Corner * 2, $iRadius_Corner * 2, 270, 90) ;right upper corner
    _GDIPlus_PathAddArc($hPath, $iWidth - $iRadius_Corner * 2 + $iSizeBorder_Bg / 2, $iHeight - $iRadius_Corner * 2 + $iSizeBorder_Bg / 2, $iRadius_Corner * 2, $iRadius_Corner * 2, 0, 90) ;right bottom corner
    _GDIPlus_PathAddArc($hPath, $iSizeBorder_Bg / 2, $iHeight - $iRadius_Corner * 2 + $iSizeBorder_Bg / 2, $iRadius_Corner * 2, $iRadius_Corner * 2, 90, 90) ;left bottm corner
    _GDIPlus_PathCloseFigure($hPath)
    Local $hPen = _GDIPlus_PenCreate($iColorOuter_Bg, $iSizeBorder_Bg), $hBrush = _GDIPlus_BrushCreateSolid($iColorInner_Bg)
    _GDIPlus_GraphicsDrawPath($hGraphics, $hPath, $hPen)
    _GDIPlus_GraphicsFillPath($hGraphics, $hPath, $hBrush)
    #EndRegion background

    #Region text render
    _GDIPlus_PathReset($hPath)
    Local Const $hFormat = _GDIPlus_StringFormatCreate()
    Local Const $hFamily = _GDIPlus_FontFamilyCreate($sFont)
    Local Const $tLayout = _GDIPlus_RectFCreate(0, 0, $iW, $iH)
    _GDIPlus_StringFormatSetAlign($hFormat, 1)
    _GDIPlus_StringFormatSetLineAlign($hFormat, 1)
    _GDIPlus_GraphicsSetTextRenderingHint($hGraphics, 4)
    _GDIPlus_PathAddString($hPath, $sText, $tLayout, $hFamily, 0, $fFontSize, $hFormat)
    _GDIPlus_PenSetColor($hPen, $iColor_FontBorder)
    _GDIPlus_PenSetWidth($hPen, $iSizeBorder_Ft)
    _GDIPlus_BrushSetSolidColor($hBrush, $iColor_Font)
    _GDIPlus_GraphicsDrawPath($hGraphics, $hPath, $hPen)
    _GDIPlus_GraphicsFillPath($hGraphics, $hPath, $hBrush)
    #EndRegion text render

    _GDIPlus_StringFormatDispose($hFormat)
    _GDIPlus_FontFamilyDispose($hFamily)
    _GDIPlus_PathDispose($hPath)
    _GDIPlus_PenDispose($hPen)
    _GDIPlus_BrushDispose($hBrush)
    _GDIPlus_GraphicsDispose($hGraphics)
    If $bGDIBitmap Then
        Local Const $hGDIBmp_Bg = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)
        _GDIPlus_BitmapDispose($hBitmap)
        Return $hGDIBmp_Bg
    EndIf
    Return $hBitmap
EndFunc   ;==>_GDIPlus_BitmapCreateRoundCornerRectProgressbar