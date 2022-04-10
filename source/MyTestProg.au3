; This is the test for the Message system

#Include "GlobalHook.au3"
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <SendMessage.au3>
#include <String.au3>
#include <Array.au3>

; opt( "MustDeclareVars", 1)

Local $GuiHwnd = GUICreate("Form1", 500, 300, 47, 3)
Local $button1 = GUICtrlCreateButton("check", 16, 8,150,50)
Local $button2 = GUICtrlCreateButton("Rehook", 16, 60, 150, 50 )
Local $button3 = GUICtrlCreateButton("Send", 16, 120, 150, 50 )
Local $text1 = GUICtrlCreateEdit("", 200, 8 , 250, 280 )

Global const $tagCOPYDATASTRUCT = 'ulong_ptr dwData;dword cbData;ptr lpData'

GUISetState(@SW_SHOW)

Global $iCount = 0
Global $lParamGlobal, $iPIDGlobal

Global $aClientResponse[3]

; Load WM_Messages.txt
Global $aWM_Messages[0][2]
$hFile = FileOpen("WM_Messages.txt")
If @error Then ExitC( "Error opening wm_messages.txt" )

While True
   $sLine = FileReadLine($hFile)
   If @error Then ExitLoop  ; End of file
   $sLine = StringStripWS($sLine, 3)
   If $sLine Then
	  $i = UBound($aWM_Messages)+1
	  ReDim $aWM_Messages[$i][2]
	  $aLine = StringSplit( $sLine, " ")
	  If $aLine[0]= 2 Then
		 $aWM_Messages[$i-1][0] = Dec( StringTrimLeft($aLine[1],2) )
		 $aWM_Messages[$i-1][1] = $aLine[2]
	  EndIf
   EndIf
WEnd

Local $hProg = WinGetHandle("DMMDCore3", "")
If @error or $hProg=0 Then ExitC( "error getting program hwnd")
c( "Program hwnd:" & $hProg )

; Monitor only the messages from the DMMDCore3
$nMsgFilter= $WM_COPYDATA
$hHwndFilter=$hProg

Global $hHook = SetCallWNDProcHook($GuiHwnd,"MsgProc")
If @error Then ExitC("Set hook error: " & @error)

GUIRegisterMsg($WM_COPYDATA, _WM_CopyDataClient)

While 1
   Local $nMsg = GUIGetMsg()
   ; if $nMsg <> 0 Then c("Msg:"& $nMsg)

   Switch $nMsg
	  Case $button1
		 c( "Hook works:" & HookWorks() )
	  Case $button2
		 ReHook()
		 If @error Then c("error in rehook:" & @error )
	  Case $button3
		 SendCommand ( $hProg, GUICtrlRead( $text1), 1 )
		 c ( "Command sent.")
	  Case $GUI_EVENT_CLOSE
		 Exit
   EndSwitch
WEnd

; Get the response after sending data.
Func _WM_CopyDataClient($hWnd, $iMsg, $wParam, $lParam)
   Local $tData = DllStructCreate($tagCOPYDATASTRUCT, $lParam), $sString = ""
   If $tData.cbData Then
	  Local $tStr = DllStructCreate('wchar str[' & $tData.cbData - 1 & ']', $tData.lpData)
	  $sString = $tStr.str
	  c("Receive Data:" & $sString )
   EndIf
   $aClientResponse[0] = True
   $aClientResponse[1] = $tData.dwData
   $aClientResponse[2] = $sString

   Return 1
EndFunc

Func ExitC($str)
   ConsoleWrite( $str & @CRLF)
   Exit
EndFunc


Func MsgProc($hWnd,$Msg,$wParam,$lParam)
   ; wParam is the process id. lParam is the pointer to the data.
   $iPID = $wParam

   Local $MSG_Struct = Read_Lparama_FromProcessMemory($Msg,$iPID,$lParam)
   If @error Then ExitC( "error reading process.")

   Local $hProc = DllStructGetData($MSG_Struct ,4)
   ; if $hProc <> $hProg Then Return 0
   Local $iMsg = DllStructGetData($MSG_Struct ,3)
   Local $wParamMsg = DllStructGetData($MSG_Struct ,2)
   Local $lParamMsg = DllStructGetData($MSG_Struct ,1)

   ; For testing purpose
   if $bTesting And $iMsg = $Test_MSG Then
	  c( "Time: " & TimerDiff($hTimer) )
	  $bWorks = True
   EndIf
   ; If $iMsg <> 74 Then Return 0
   Local $sMsg, $iIndex
   $iIndex = _ArrayBinarySearch( $aWM_Messages, $iMsg )
   If @error Then
	  $sMsg = String( $iMsg )
   Else
	  $sMsg = $aWM_Messages[$iIndex][1]
   EndIf

   $iCount += 1
   c( "#" & $iCount & " hwnd:" & $hProc & " msg:" & $iMsg & " " & $sMsg & " wParam:" & $wParamMsg & " lParam:" & $lParamMsg & " PID:" & $iPID)

   If $iMsg = $WM_COPYDATA Then
	  ; Read WM_CopyData
	  if ($lParamMsg) Then c( "Data:" & GetWMCopyData($iPID, $lParamMsg) )
   EndIf

   $MSG_Struct = 0

   Return 0
EndFunc

Func SendCommand($hWnd, $sDataToSend, $iData)
   Local $tData = DllStructCreate($tagCOPYDATASTRUCT)
   Local $iLen = StringLen($sDataToSend)
   If $iLen Then
	  $tData.cbData = ($iLen + 1)*2
	  Local $tStr = DllStructCreate('wchar str[' & $tData.cbData & ']')
	  $tStr.str = $sDataToSend
	  ; DllStructSetData( $tStr, "str", $sDataToSend )
	  $tData.lpData = DllStructGetPtr($tStr)
   EndIf
   $tData.dwData = $iData
   c("Sending From " & $GuiHwnd & " To " & $hProg & " with Data " & $iData & " and String " & $sDataToSend)

   _SendMessage($hProg, $WM_COPYDATA, $GuiHwnd, DllStructGetPtr($tData))

   Local $hTimer = TimerInit()
   ; Wait for response for 5 seconds
   While TimerDiff($hTimer) < 1000
	  If $aClientResponse[0] Then
		 c( "Client response-> Data:" & $aClientResponse[1] & " String:" & $aClientResponse[2])
		 Return $aClientResponse[2]
	  EndIf
	  Sleep(20)
   WEnd
   c("No data returned.")
EndFunc

Func CheckAdminRights()
   If IsAdmin() Then
	  If Not _WinAPI_ChangeWindowMessageFilterEx(0, $WM_COPYDATA, $MSGFLT_ALLOW) Then Return SetError(1)
	  c("Warning : messages are now allowed with lower privilege windows")
   EndIf
EndFunc


Func GetWMCopyData($ProcessID,$LPARAMA)
   Local $iSYNCHRONIZE = (0x00100000),$iSTANDARD_RIGHTS_REQUIRED = (0x000F0000)
   Local $iPROCESS_ALL_ACCESS  = ($iSTANDARD_RIGHTS_REQUIRED + $iSYNCHRONIZE + 0xFFF)
   Local $hProcess , $LparamaStruct , $LparamaStructPtr , $LparamaStructSize , $iRead
   Local $hProcess = _WinAPI_OpenProcess($iPROCESS_ALL_ACCESS,False,$ProcessID)
   if @error Then Return SetError(@error,1,$LparamaStruct)

   ; Save the lParam and PID for later send command
   $lParamGlobal = $LPARAMA
   $iPIDGlobal = $ProcessID
   ; Local $tagMSG = "LPARAM lParam;WPARAM wParam;UINT message;HWND hwnd"

   $LparamaStruct = DllStructCreate($tagCOPYDATASTRUCT)
   $LparamaStructSize = DllStructGetSize($LparamaStruct)

   $LparamaStructPtr = DllStructGetPtr($LparamaStruct)
   _WinAPI_ReadProcessMemory($hProcess,$LPARAMA,$LparamaStructPtr,$LparamaStructSize,$iRead)
   ; c( "Data copied: " & $iRead)
   ; c( "cbData:" & $LparamaStruct.cbData & " lpData:" & $LparamaStruct.lpData )
   ; Set the buffer to copy
   $sBuffer = DllStructCreate( "wchar[" & $LparamaStruct.cbData & "]" )
   $pBuffer = DllStructGetPtr( $sBuffer )
   _WinAPI_ReadProcessMemory( $hProcess, $LparamaStruct.lpData, $pBuffer, $LparamaStruct.cbData, $iRead )
   ; c( "Data copied: " & $iRead)
   ; c( "Data string: " & DllStructGetData( $sBuffer, 1) )

   Return DllStructGetData( $sBuffer, 1)
EndFunc

Func _WinAPI_ReadProcessMemoryEx($iProcessID, $pPointer, $sStructTag)
    Local $iSYNCHRONIZE = (0x00100000), $iSTANDARD_RIGHTS_REQUIRED = (0x000F0000)
    Local $iPROCESS_ALL_ACCESS = ($iSTANDARD_RIGHTS_REQUIRED + $iSYNCHRONIZE + 0xFFF)
    Local $hProcess, $Struct, $StructPtr, $StructSize, $Read

    $hProcess = _WinAPI_OpenProcess($iPROCESS_ALL_ACCESS, False, $iProcessID)
    If @error Then Return SetError(@error, 1, $Struct)

    $Struct = DllStructCreate($sStructTag)
    $StructSize = DllStructGetSize($Struct)
    $StructPtr = DllStructGetPtr($Struct)

    _WinAPI_ReadProcessMemory($hProcess, $pPointer, $StructPtr, $StructSize, $Read)
    _WinAPI_CloseHandle($hProcess)

    Return SetError(@error, $Read, $Struct)
EndFunc   ;==>_WinAPI_ReadProcessMemoryEx

Func c($str)
   ConsoleWrite($str&@CRLF)
EndFunc