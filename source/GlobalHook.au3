#Include <WinAPI.au3>
OnAutoItExitRegister("CleanupHook")
Global $hDLL = 0, $HookHandleCallWNDProc, $CALLWNDPROC_MSG, $TEST_MSG
Global $bTesting = False, $bWorks, $hTimer

; $nMsgFilter: Default to be 0 (all), can set to an int number to receive only certain type of message.
; $hHwndFilter: Default to be 0 (all), can set to a number so only monitor a process with that winhandle.
Global $nMsgFilter=0, $hHwndFilter=0

;http://msdn.microsoft.com/en-us/library/ms644990%28VS.85%29.aspx
;SetWindowsHookEx can be used to inject a DLL into another process. A 32-bit DLL cannot be injected
;into a 64-bit process, and a 64-bit DLL cannot be injected into a 32-bit process. If an application
;requires the use of hooks in other processes, it is required that a 32-bit application call
;SetWindowsHookEx to inject a 32-bit DLL into 32-bit processes, and a 64-bit application call
;SetWindowsHookEx to inject a 64-bit DLL into 64-bit processes. The 32-bit and 64-bit DLLs must
;have different names.
;This example is for installing CallWNDProc hooks only.


; Parameters:
; $hGuiHwnd: 	The win handle of a program to receive the message.
; $MsgFunction: The name of autoit function you want to pass the message to.

Func SetCallWNDProcHook($hGuiHwnd, $MsgFunction )

   if Not IsHWnd($hGuiHwnd) Then Return SetError(1,0,0)
   if Not $hDLL Then $hDLL = DllOpen("Hook32.dll")

   ; Receive message from the dll then send it to $MsgFunction
   Local $RT = DllCall( $hDLL, "UINT", "_MsgQueueID@0")
   If @error Then ExitC("Error getting registering message")
   $CALLWNDPROC_MSG = $RT[0]
   if Not $CALLWNDPROC_MSG Or Not GUIRegisterMsg($CALLWNDPROC_MSG,$MsgFunction) Then Return SetError(3,0,0)
   c( "msg queue:" & $CALLWNDPROC_MSG )

   $RT = DllCall( $hDLL, "UINT", "_TestMsgID@0")
   $TEST_MSG = $RT[0]
   c( "Test msg queue:" & $TEST_MSG )

   $RT = DllCall($hDLL,"handle","_DllWindowsHookExW@12", "HWND", $hGuiHwnd, "UINT", $nMsgFilter, "HWND", $hHwndFilter )
   If @error Or Not $RT[0] Then Return SetError(5,0,0)
   $HookHandleCallWNDProc = $RT[0]
   c( "HookHandle:" & $HookHandleCallWNDProc )

   Return SetError(0,0,$HookHandleCallWNDProc)

EndFunc

Func HookWorks()
   ; It should send a test message to the $MsgFunction
   if Not $hDLL Then $hDLL = DllOpen("Hook32.dll")
   $bTesting = True
   $bWorks = False
   $hTimer = TimerInit()
   Local $RT = DllCall( $hDLL, "BOOL", "_HookTest@0")
   If @error Or Not $RT[0] Then Return SetError(1)
   ; now the $MsgFunction should receive a message of 99999.
   sleep(100)
   Return $bWorks
EndFunc

Func ReHook()
   Local $RT = DllCall($hDLL,"handle","_ReHook@0")
   If @error Or Not $RT[0] Then Return SetError(@error,0,0)
   $HookHandleCallWNDProc = $RT[0]
   c( "New HookHandle:" & $HookHandleCallWNDProc )
EndFunc

Func RegisterWindowMessage($lpString)
   Local $RT = DllCall("User32.dll","int","RegisterWindowMessageW","WSTR",$lpString)
   if @error Then Return SetError(1,0,0)
   Return SetError(_WinAPI_GetLastError(),0,$RT[0])
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
   if ($HookHandleCallWNDProc) Then _WinAPI_UnhookWindowsHookEx($HookHandleCallWNDProc)
   If ($CALLWNDPROC_MSG) Then GUIRegisterMsg( $CALLWNDPROC_MSG, "")
EndFunc

