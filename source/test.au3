#Include <WinAPI.au3>
#include <Array.au3>

$iPID = 4260
$aHwnd  = _GetHwndFromPID($iPID)

_ArrayDisplay($aHwnd)
   ;Function for getting HWND from PID
Func _GetHwndFromPID($PID)
	Local $hWnd[0]
	$winlist = WinList()
	  For $i = 1 To $winlist[0][0]
		 If $winlist[$i][0] <> "" Then
			 $iPID2 = WinGetProcess($winlist[$i][1])
			 If $iPID2 = $PID Then
				ReDim $hWnd[UBound($hWnd)+1]
				 $hWnd[UBound($hWnd)-1] = $winlist[$i][1]
			 EndIf
		 EndIf
	 Next

	Return $hWnd
EndFunc;==>_GetHwndFromPID