; List the available monitor and ask to choose one.
Func ChooseMonitor()

	$guiChooseMonitor = GUICreate("Choose Monitor",320,220,-1,-1,-1,-1)
	#include "ChooseMonitor.isf"
	; local $lstMonitors, $btnChoose
	$aMonitors = GetMonitors()
	
	Local $sList = ""
	For $i = 1 to UBound($aMonitors)-1
		Local $sItem = "Monitor " & $i & ": " & ( $aMonitors[$i][3] -$aMonitors[$i][1] ) & "x" & ($aMonitors[$i][4] -$aMonitors[$i][2]) & ($aMonitors[$i][5] = 1 ? " Primary Display" : " Secondary Display" )
		
		If $sList = "" Then
			$sList = $sItem
		Else
			$sList = $sList & "|" & $sItem
		EndIf
	Next
	GUICtrlSetData($lstMonitors, $sList)
	
	While True
		Local $nMsg = GUIGetMsg()
		Switch $nMsg
			
			Case 0
				ContinueLoop 
			Case $btnChoose
				$sChoosen = GUICtrlRead($lstMonitors)
				$giActiveMonitor = Number(StringMid($sChoosen, 9, 1))
				c( "Chosen monitor:" & $giActiveMonitor)
				SetBackground()
			Case $GUI_EVENT_CLOSE
				GUIDelete($guiChooseMonitor)
				Return SetError(1)		; Cancelled.
		EndSwitch
	Wend
	
EndFunc 

; Get all monitor's screen data.
; Return array: [ ; [ monitor handle, startx, starty, endx, endy, Primary(0 or 1), Detail Text ]
Func GetMonitors()

   Local $aData = _WinAPI_EnumDisplayMonitors()
   If IsArray($aData) Then
		ReDim $aData[$aData[0][0] + 1][7]
		For $i = 1 To $aData[0][0]
			Local $aMon = _WinAPI_GetMonitorInfo($aData[$i][0])	 ;$aData[$i][0] contains the handle
			For $j = 1 to 4
				$aData[$i][$j] = DllStructGetData($aMon[0], $j)
			Next
			$aData[$i][5] = $aMon[2]	; Primary
			"Monitor " & $i & ": " & ( $aData[$i][3] -$aData[$i][1] ) & "x" & ($aData[$i][4] -$aData[$i][2]) _ 
				& ($aData[$i][5] = 1 ? " Primary Display" : " Secondary Display" )
		Next
   Else
	  Return SetError(1)
   EndIf
   Return $aData
EndFunc