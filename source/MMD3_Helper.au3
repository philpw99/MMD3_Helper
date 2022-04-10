;*****************************************
;MMD3_Helper.au3 by Philip Wang
;Created with ISN AutoIt Studio v. 1.13
;*****************************************
; DllCall("User32.dll","bool","SetProcessDPIAware")
#include "Forms\Main.isf"

GUISetState()
while True 
	$nMsg = GUIGetMsg()
	Switch $nMsg
		Case 0
			ContinueLoop 
		Case $GUI_EVENT_CLOSE
			ExitScript()
	EndSwitch
	
Wend



Func Bingo()
	MsgBox(0, "bingo", "You got it.")
EndFunc

Func ExitScript()
	GUIDelete($guiMain)
	Exit
EndFunc