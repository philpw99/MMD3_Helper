#Include <WinAPI.au3>
#include <SendMessage.au3>

; OnAutoItExitRegister("CleanupHook")
Global $ghHookDLL = 0, $gHookHandleCallWNDProc, $CALLWNDPROC_MSG, $TEST_MSG
Global $gbHookTesting = False, $gbHookWorks, $ghHookHandle
Global $gaClientResponse[3]	; For getting replies after sending a wm_copydata.

Global const $tagCOPYDATASTRUCT = 'ulong_ptr dwData;dword cbData;ptr lpData'

;http://msdn.microsoft.com/en-us/library/ms644990%28VS.85%29.aspx
;SetWindowsHookEx can be used to inject a DLL into another process. A 32-bit DLL cannot be injected
;into a 64-bit process, and a 64-bit DLL cannot be injected into a 32-bit process. If an application
;requires the use of hooks in other processes, it is required that a 32-bit application call
;SetWindowsHookEx to inject a 32-bit DLL into 32-bit processes, and a 64-bit application call
;SetWindowsHookEx to inject a 64-bit DLL into 64-bit processes. The 32-bit and 64-bit DLLs must
;have different names.
;This example is for installing CallWNDProc hooks only.


Func InitHook( $hGui )
	$ghHookHandle = SetCallWNDProcHook($hGui,"MsgHookProc", $WM_COPYDATA, 0 )	; Monitor all process's wm_copydata
	If @error Then Return SetError(@error)
EndFunc



; Function to send a wm_copydata text to a window by handle. $iData is optional
; Because both DMECore and MMD3Core use wchar, so no need to set the char option.
Func SendCommand($hFromWnd, $hToWnd, $sDataToSend, $iData = 1)
	Local $tData = DllStructCreate($tagCOPYDATASTRUCT)
	Local $iLen = StringLen($sDataToSend)
	If $iLen Then
	  $tData.cbData = ($iLen + 1)*2  ; wchar is 16bit.
	  Local $tStr = DllStructCreate('wchar str[' & $tData.cbData & ']')
	  $tStr.str = $sDataToSend
	  $tData.lpData = DllStructGetPtr($tStr)
	EndIf
	$tData.dwData = $iData
	; c("Sending From " & $hFromWnd & " To " & $hToWnd & " with Data " & $iData & " and String " & $sDataToSend)
	
	$gaClientResponse[0] = False 
	_SendMessage($hToWnd, $WM_COPYDATA, $hFromWnd, DllStructGetPtr($tData))

	Local $hTimer = TimerInit()
	; Wait for response for 0.5 seconds
	While TimerDiff($hTimer) < 500
	  If $gaClientResponse[0] Then
		 c( "Client response-> Data:" & $gaClientResponse[1] & " String:" & $gaClientResponse[2])
		 Return $gaClientResponse[2]
	  EndIf
	  Sleep(100)
	WEnd
	c("No data returned.")
EndFunc


; This is the function the DLL will call when a message is intercepted.
Func MsgHookProc($hWnd,$Msg,$wParam,$lParam)
	; wParam is the process id. lParam is the pointer to the data.
	; example of use:  Global $hHook = SetCallWNDProcHook($GuiHwnd,"MsgHookProc")
	Local $iPID = $wParam
	Local $MSG_Struct = Read_Lparama_FromProcessMemory($Msg,$iPID,$lParam)
	If @error Then Return	; Cannot set error for it.

	Local $hProc = DllStructGetData($MSG_Struct ,4)	; Get the message's win handle.
	; Filter out the messages.
 	If $gsControlProg = "MMD3" Then 
 		If $hProc <> $ghMMD3 And $hProc <> $guiDummy And Number($iPID) <> $giMMD3PID Then Return 0
 	Else ; DME
 		If $hProc <> $ghDME And $hProc <> $guiDummy And Number($iPID) <> $giDMEPID Then Return 0
 	EndIf

	; if $hProc <> $hProg Then Return 0
	Local $iMsg = DllStructGetData($MSG_Struct ,3)	; Get the message's WM number
	Local $wParamMsg = DllStructGetData($MSG_Struct ,2)  ; Get the message's wParam
	Local $lParamMsg = DllStructGetData($MSG_Struct ,1)  ; Get the message's lParam
	

	If $hProc <> $guiDummy Then 
		c( "Message from Hwnd:" & $hProc & " t:" & WinGetTitle($hProc) & " PID:" & $iPID & " WM:" & $iMsg & " wParam:" & $wParamMsg )
	EndIf 
	
	; For testing messages.
	if $gbHookTesting And $iMsg = $Test_MSG And $wParamMsg = 99999 Then
		$gbHookWorks = True
		Return 0
	EndIf

	If $iMsg = $WM_COPYDATA Then
		; Read WM_CopyData
		Local $sMessage
		If $gsControlProg = "MMD3" Then 
			If $hProc = $ghMMD3 Then 
				$sMessage = GetWMCopyData($iPID, $lParamMsg, True)  ; Using wchar
				ProcessMessage( "MMD3Core", $sMessage )
			Elseif Number($iPID) = $giMMD3PID Then 
				$sMessage = GetWMCopyData($iPID, $lParamMsg, False)  ; Using char
				ProcessMessage( "MMD3", $sMessage )
			EndIf
			
		Elseif $gsControlProg = "DME" Then 
			If $hProc = $ghDME Then 
				$sMessage = GetWMCopyData($iPID, $lParamMsg, True)   ; Using wchar
				ProcessMessage( "DMECore", $sMessage )
			Elseif Number($iPID) = $giDMEPID Then 
				$sMessage = GetWMCopyData($iPID, $lParamMsg, False)   ; Using char
				ProcessMessage( "DME", $sMessage )
			EndIf
		EndIf
	EndIf

	$MSG_Struct = 0	; release the memory

   Return 0
EndFunc

; Get the wm_copydata string.
Func _WM_CopyDataClient($hWnd, $iMsg, $wParam, $lParam)
   Local $tData = DllStructCreate($tagCOPYDATASTRUCT, $lParam), $sString = ""
   If $tData.cbData Then
	  Local $tStr = DllStructCreate('wchar str[' & $tData.cbData - 1 & ']', $tData.lpData)
	  $sString = $tStr.str
	  ; c("Receive Data:" & $sString )
   EndIf
   $gaClientResponse[0] = True
   $gaClientResponse[1] = $tData.dwData
   $gaClientResponse[2] = $sString

   Return 1
EndFunc

; Parameters:
; $hGuiHwnd: 	The win handle of a program to receive the message.
; $MsgFunction: The name of autoit function you want to pass the message to.
; $nMsgFilter: Default to be 0 (all), can set to an int number to receive only certain type of message.
; $hHwndFilter: Default to be 0 (all), can set to a number so only monitor a process with that winhandle.

Func SetCallWNDProcHook($hGuiHwnd, $MsgFunction, $nMsgFilter=0, $hHwndFilter=0 )
	if Not IsHWnd($hGuiHwnd) Then Return SetError(1,0,0)
	if Not $ghHookDLL Then $ghHookDLL = DllOpen("Hook32.dll")
	if @error Then
		c("Load dll error. Error :" & @error)
		Return SetError(1)
	EndIf

	; Receive message from the dll then send it to $MsgFunction
	Local $aRet = DllCall( $ghHookDLL, "UINT", "_MsgQueueID@0")
	If @error Then Return SetError(2)
	$CALLWNDPROC_MSG = $aRet[0]
	if Not $CALLWNDPROC_MSG Or Not GUIRegisterMsg($CALLWNDPROC_MSG,$MsgFunction) Then Return SetError(3,0,0)
	c( "msg queue:" & $CALLWNDPROC_MSG )

	$aRet = DllCall( $ghHookDLL, "UINT", "_TestMsgID@0")
	$TEST_MSG = $aRet[0]
	c( "Test msg queue:" & $TEST_MSG )

	$aRet = DllCall($ghHookDLL,"handle","_DllWindowsHookExW@12", "HWND", $hGuiHwnd, "UINT", $nMsgFilter, "HWND", $hHwndFilter )
	If @error Or Not $aRet[0] Then Return SetError(5,0,0)
	$gHookHandleCallWNDProc = $aRet[0]
	c( "HookHandle:" & $gHookHandleCallWNDProc )

	Return SetError(0,0,$gHookHandleCallWNDProc)

EndFunc

Func HookWorks()
   ; It should send a test message to the $MsgFunction
   if Not $ghHookDLL Then $ghHookDLL = DllOpen("Hook32.dll")
   $gbHookTesting = True
   $gbHookWorks = False

   Local $aRet = DllCall( $ghHookDLL, "BOOL", "_HookTest@0")
   If @error Or Not $aRet[0] Then Return SetError(1)
   ; now the $MsgFunction should receive a message from the testing msg queue.
   sleep(10)	; 10 ms is too long already, usually takes 0.1 ms.
   $gbHookTesting = False 
   Return $gbHookWorks
EndFunc

Func ReHook()
   Local $aRet = DllCall($ghHookDLL,"handle","_ReHook@0")
   If @error Or Not $aRet[0] Then Return SetError(@error,0,0)
   $gHookHandleCallWNDProc = $aRet[0]
   c( "New HookHandle:" & $gHookHandleCallWNDProc )
EndFunc

Func GetWMCopyData($ProcessID,$LPARAMA, $bWchar)
   Local $iSYNCHRONIZE = (0x00100000),$iSTANDARD_RIGHTS_REQUIRED = (0x000F0000)
   Local $iPROCESS_ALL_ACCESS  = ($iSTANDARD_RIGHTS_REQUIRED + $iSYNCHRONIZE + 0xFFF)
   Local $LparamaStruct , $LparamaStructPtr , $LparamaStructSize , $iRead
   Local $hProcess = _WinAPI_OpenProcess($iPROCESS_ALL_ACCESS,False,$ProcessID)
   if @error Then Return SetError(@error,1,$LparamaStruct)

   Local $LparamaStruct = DllStructCreate($tagCOPYDATASTRUCT)
   Local $LparamaStructSize = DllStructGetSize($LparamaStruct)

   Local $LparamaStructPtr = DllStructGetPtr($LparamaStruct)
   _WinAPI_ReadProcessMemory($hProcess,$LPARAMA,$LparamaStructPtr,$LparamaStructSize,$iRead)
   ; c( "Data copied: " & $iRead)
   ; c( "cbData:" & $LparamaStruct.cbData & " lpData:" & $LparamaStruct.lpData )
   ; Set the buffer to copy
   Local $sBuffer = DllStructCreate( ($bWchar? "wchar[" : "char[") & $LparamaStruct.cbData & "]" )
   Local $pBuffer = DllStructGetPtr( $sBuffer )
   _WinAPI_ReadProcessMemory( $hProcess, $LparamaStruct.lpData, $pBuffer, $LparamaStruct.cbData, $iRead )
   ; c( "Data copied: " & $iRead)
   ; c( "Data string: " & DllStructGetData( $sBuffer, 1) )

   Return DllStructGetData( $sBuffer, 1)
EndFunc

Func RegisterWindowMessage($lpString)
   Local $aRet = DllCall("User32.dll","int","RegisterWindowMessageW","WSTR",$lpString)
   if @error Then Return SetError(1,0,0)
   Return SetError(_WinAPI_GetLastError(),0,$aRet[0])
EndFunc

Func Read_Lparama_FromProcessMemory($Msg,$ProcessID,$LPARAMA)
   Local $iSYNCHRONIZE = (0x00100000),$iSTANDARD_RIGHTS_REQUIRED = (0x000F0000)
   Local $iPROCESS_ALL_ACCESS  = ($iSTANDARD_RIGHTS_REQUIRED + $iSYNCHRONIZE + 0xFFF)
   Local $hProcess , $LparamaStruct , $LparamaStructPtr , $LparamaStructSize , $iRead
   Local $hProcess = _WinAPI_OpenProcess($iPROCESS_ALL_ACCESS,False,$ProcessID)
   if @error Then Return SetError(@error,1,$LparamaStruct)

   Local $tagMSG = "LPARAM lParam;WPARAM wParam;UINT message;HWND hwnd"
   $LparamaStruct = DllStructCreate($tagMSG)
   $LparamaStructSize = DllStructGetSize($LparamaStruct)

   $LparamaStructPtr = DllStructGetPtr($LparamaStruct)
   _WinAPI_ReadProcessMemory($hProcess,$LPARAMA,$LparamaStructPtr,$LparamaStructSize,$iRead)
   Return SetError(@error,2,$LparamaStruct)
EndFunc

Func CleanupHook()
   if ($gHookHandleCallWNDProc) Then _WinAPI_UnhookWindowsHookEx($gHookHandleCallWNDProc)
   If ($CALLWNDPROC_MSG) Then GUIRegisterMsg( $CALLWNDPROC_MSG, "")
EndFunc

