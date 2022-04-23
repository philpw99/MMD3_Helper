#include <WinAPIGdi.au3>

; enum _PROCESS_DPI_AWARENESS
Global Const $PROCESS_DPI_UNAWARE = 0
Global Const $PROCESS_SYSTEM_DPI_AWARE = 1
Global Const $PROCESS_PER_MONITOR_DPI_AWARE = 2

; enum _MONITOR_DPI_TYPE
Global Const $MDT_EFFECTIVE_DPI = 0
Global Const $MDT_ANGULAR_DPI = 1
Global Const $MDT_RAW_DPI = 2
Global Const $MDT_DEFAULT = $MDT_EFFECTIVE_DPI

_WinAPI_SetProcessDpiAwareness($PROCESS_PER_MONITOR_DPI_AWARE)

$aMonitors = _WinAPI_EnumDisplayMonitors()
If Not IsArray($aMonitors) Then Exit MsgBox(0, "", "EnumDisplayMonitors error")

For $i = 1 To $aMonitors[0][0]
  $aDPI = _WinAPI_GetDpiForMonitor($aMonitors[$i][0], $MDT_DEFAULT)
  $_ = IsArray($aDPI) ? MsgBox(0, "", $aDPI[0] & ":" & $aDPI[1]) : MsgBox(0, "", "error")
Next

Func _WinAPI_SetProcessDpiAwareness($DPIAware)
  DllCall("Shcore.dll", "long", "SetProcessDpiAwareness", "int", $DPIAware)
  If @error Then Return SetError(1, 0, 0)
EndFunc

Func _WinAPI_GetDpiForMonitor($hMonitor, $dpiType)
  Local $X, $Y
  $aRet = DllCall("Shcore.dll", "long", "GetDpiForMonitor", "long", $hMonitor, "int", $dpiType, "uint*", $X, "uint*", $Y)
  If @error Or Not IsArray($aRet) Then Return SetError(1, 0, 0)
  Local $aDPI[2] = [$aRet[3],$aRet[4]]
  Return $aDPI
EndFunc