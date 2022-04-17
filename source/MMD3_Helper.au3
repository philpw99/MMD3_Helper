;*****************************************
;MMD3_Helper.au3 by Philip Wang
;Created with ISN AutoIt Studio v. 1.13
;*****************************************

; DllCall("User32.dll","bool","SetProcessDPIAware")

#include <StaticConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#Include <GuiButton.au3>
#include <GuiTab.au3>
#include <EditConstants.au3>
#include <WinAPIProc.au3>

opt("MustDeclareVars", 1)

#include "TrayMenuEx.au3"


#Region Globals Initialization

; Run only a single instance
If AlreadyRunning() Then
   MsgBox(48,"MMD3 Helper is still running.","MMD3 Helper is running. Maybe it had an error and froze. " & @CRLF _
	  & "You can use the 'task manager' to force-close it." & @CRLF _
	  & "Not recommend running two MMD3 Helper at the same time.",0)
   Exit
EndIf

Global Const $gsVersion = "v1.0.0"
Global Const $gsAboutText = "MMD3 Helper " & $gsVersion & ", written by Philip Wang." _
						   &@CRLF& "Extend the features of the Excellent DesktopMMD3."
						   
; Registry path to save program settings.
Global Const $gsRegBase = "HKEY_CURRENT_USER\Software\MMD3_Helper"

; Global settings
Global $gsMMD3Path, $gsMMD3AssetPath, $gsMMD3WorkshopPath
Global $gsDMEPath, $gsDMEAssetPath, $gsDMEWorkshopPath
Global $gsControlProg, $gsCenterWhenDance, $gsBackgroundShow

Global $ghMMD3, $ghDME, $giMMD3PID, $giDMEPID
Global $ghHelperHwnd = WinGetHandle( AutoItWinGetTitle(), "")
If Not IsHWnd( $ghHelperHwnd) Then
	c("type:" & VarGetType($ghHelperHwnd) )
	ExitC("Not a hwnd.")
EndIf
	
Global $giHelperPID = WinGetProcess($ghHelperHwnd)

Global $aModels[1] = [0]  ; First one is number of models in the array. No model means 0.

; Load forms below
#include "Forms\Settings.au3"

If Not LoadGlobalSettings() Then
   ; Run the initial settings form.
   MsgBox( 0, "First time running", "Seems this is your first time running this program." _
		 & @CRLF & "Please check the settings and save.", 20 )
   Local $bSave = GuiSettings(True)
   If @error Then ExitC("Error setting new global settings.")
   ; If return is true, setting is saved. If not saved, false.
   if Not $bSave Then Exit 
EndIf

; Get MMD3 Handles
; $bGotIt =  GetMMD3Handles()
; Get DME handles.

If $gsControlProg = "MMD3" Then 
	$ghMMD3 = WinGetHandle( "DMMDCore3", "")
	If @error Then ; Program is not running
		Run( $gsMMD3Path & "\DesktopMMD3.exe", $gsMMD3Path)
		If @error Then ; Program not exist
			MsgBox( 0, "Error", "Cannot run DesktopMMD3.exe. Need to change settings.", 20 )
			GuiSettings(False)
			Exit
		EndIf
		$ghMMD3 = WinWait( "DMMDCore3", "", 30)
		$giMMD3PID = WinGetProcess( "DekstopMMD3", "")
	EndIf
Else ; DME
	Global $ghDME = WinGetHandle( "DMMDCore", "")
	If @error Then ; Program is not running
		Run( $gsDMEPath & "\DesktopMagicEngine.exe", $gsDMEPath)
		If @error Then ; Program not exist
			MsgBox( 0, "Error", "Cannot run DesktopMagicEngine.exe. Need to change settings.", 20 )
			GuiSettings(False)
			Exit
		EndIf
		$ghDME = WinWait( "DMMDCore", "", 30)
		$giDMEPID = WinGetProcess( "DekstopMagicEngine", "")
	EndIf
EndIf

#EndRegion Globals

; Initialize GUI.  ( Update: No main gui, I prefer tray icons.)
; Global $guiMain = GUICreate("MMD3/DME Helper",1150,850,-1,-1,-1,-1)
; If @error Then ExitC("Cannot create $guiMain")

; #include "Forms\Main.isf"
; GUISetState( @SW_SHOW, $guiMain )

#Region Tray Menu Initialize
TraySetIcon("Icons\tray.ico")

Global Const $gsIconPath = @ScriptDir & "\Icons\"
Local $hIcons[7]	; 20 (0-19) bmps  for the tray menus
For $i = 0 to UBound($hIcons)-1
	$hIcons[$i] = _LoadImage($gsIconPath & $i & ".bmp", $IMAGE_BITMAP)
Next

; Initialize Tray using TrayMenuEx.au3

; Opt("TrayAutoPause", 0)  ; No pause in tray
Opt("TrayMenuMode", 3)	; The default tray menu items will not be shown and items are not checked when selected.

Local $iMenuItem = 0

Global $trayTitle = TrayCreateItem("MMD3 / MDE Helper " & $gsVersion )
; $iMenuItem += 1
TrayCreateItem("")
$iMenuItem = 2
Global $trayMenuModels = TrayCreateMenu("ActiveModel:")	; Active model name.The subitems are all loaded models.
_TrayMenuAddImage($hIcons[0], $iMenuItem)
$iMenuItem += 1
Global $trayMenuCommands = TrayCreateMenu("Model Commands")		; Send common or custom commands to a model.
_TrayMenuAddImage($hIcons[1], $iMenuItem)
$iMenuItem += 1
Global $trayMenuDanceMonitor = TrayCreateMenu("Dance Monitor")	; If a program play sound, active model random dances.
_TrayMenuAddImage($hIcons[2], $iMenuItem)
$iMenuItem += 1
Global $trayMenuDanceBK = TrayCreateMenu("Dance Background") ; Specify dance background, or random, but not from
_TrayMenuAddImage($hIcons[3], $iMenuItem)
$iMenuItem += 1
Global $trayMenuPlayList = TrayCreateMenu("Play List")		; Add / remove / Play the songs in play list.
_TrayMenuAddImage($hIcons[4], $iMenuItem)
$iMenuItem += 1
Global $traySettings = TrayCreateItem("Settings")
_TrayMenuAddImage($hIcons[5], $iMenuItem)
$iMenuItem += 1
TrayCreateItem("")
$iMenuItem += 1
Global $trayExit = TrayCreateItem("Exit")
_TrayMenuAddImage($hIcons[6], $iMenuItem)

; No need for those icons any more
_IconDestroy($hIcons)

#EndRegion Tray Menu

; Now do the hooking
#include "GlobalHook.au3"
InitHook($ghHelperHwnd)
If @error Then 
	c("error in initialze hook. Error:" & @error)
	Exit
EndIf

#Region Main Loop
Local $hTimer1Sec = TimerInit()

while True
	Local $nTrayMsg = TrayGetMsg()
	Switch $nTrayMsg
		Case 0
			ContinueLoop
		Case $trayTitle
			About()
		Case $traySettings
			GuiSettings(False)	; Not new settings.
		Case $trayExit
			ExitLoop
	EndSwitch
	
	; Check things every second.
	if TimerDiff($hTimer1Sec)> 1000 Then 
		CheckEverySecond()
		$hTimer1Sec = TimerInit()
	EndIf
Wend

#EndRegion Main Loop

; Clean up process.
CleanupHook()
Exit

#Region Main Functions

Func CheckEverySecond()
	If Not HookWorks() Then ReHook()
EndFunc

Func About()
	MsgBox(0, "About MMD3/DME Helper " & $gsVersion, $gsAboutText )
EndFunc

Func LoadGlobalSettings()
	; return: Load successful  true/false
	$gsControlProg = RegRead($gsRegBase, "ControlProgram") ; "MMD3" or "DME"
	If @error Then Return False
	$gsMMD3Path = RegRead($gsRegBase, "MMD3Path")	; Location of DesktopMMD3.exe
	$gsMMD3AssetPath = $gsMMD3Path & "\AppData\Assets" ; Should be MMD3Path\AppData\Assets\
	$gsMMD3WorkshopPath = RegRead($gsRegBase, "MMD3WorkshopPath") ; Download and installed workshop items path.
	$gsDMEPath = RegRead($gsRegBase, "DMEPath")
	$gsDMEAssetPath = $gsDMEPath & "\AppData\Assets"
	$gsDMEWorkshopPath = RegRead($gsRegBase, "DMEWorkshopPath")
	$gsBackgroundShow = RegRead($gsRegBase, "BackgroundShow") ; Disable, EnableRandom or EnableSpecified
	$gsCenterWhenDance = RegRead($gsRegBase, "CenterWhenDance") ; 0 or 1
	Return True	; loaded
EndFunc

Func AlreadyRunning()
	Local $aPID = ProcessList("AutoIt3.exe")
	If @error or $aPID[0][0] = 0 then Return False
	For $i = 1 to $aPID[0][0]
		; Skip this one.
		If $aPID[$i][1] = @AutoItPID Then ContinueLoop
		; Get full path by pid
		Local $sPath = _WinAPI_GetProcessFileName($aPID[$i][1])
		If StringInStr($sPath, "MMD3_Helper") <> 0 Then Return True
	Next
	Return False
EndFunc

Func GetFolderFromPath($FullPath)
	; Get the folder and drive from a full path string without the last "\"
	StringLeft( $FullPath, StringInStr($FullPath, "\", 1, -1) -1 )
EndFunc

Func GetFileFromPath($FullPath)
	; Get the file name from a full path string.
	StringMid( $FullPath, StringInStr($FullPath, "\", 1, -1) + 1)
EndFunc

Func c($str)
   ConsoleWrite($str&@CRLF)
EndFunc

Func MsgExit($str)
   MsgBox(0, "Error", $str, 20)
   Exit
EndFunc

Func ExitC($str)
   c($str)
   Exit
EndFunc
#EndRegion