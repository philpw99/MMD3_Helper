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
#include <WinAPIsysinfoConstants.au3>
#include <TrayConstants.au3>
#include <Array.au3>
#include "Json.au3"

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
Global $gsControlProg, $giCenterWhenDance, $gsBackgroundShow
Global $giActiveMonitor
Global $giDanceWithProgram, $gsDanceMonitorProgram, $giDanceWithBackground

Global $ghMMD3, $ghDME, $giMMD3PID, $giDMEPID
Global $ghHelperHwnd = WinGetHandle( AutoItWinGetTitle(), "")
c ( "Helper handle:" & $ghHelperHwnd )
Global $giHelperPID = WinGetProcess($ghHelperHwnd)
c ( "Helper PID:" & $giHelperPID )
Global $bProgRunning = False 	; The MMD3 or DME is running?

; Model number and model object data created by json.
Global Enum $MODEL_NO, $MODEL_NAME, $MODEL_OBJ
Global $gaModels[0][3]		; Models loaded in memory.

Global Enum $MODEL_ITEM_HANDLE, $MODEL_ITEM_NAME
Global $gaModelMenuItems[1][2]		; Menu Item Handle and name, first one is always "Model List"
Global $giActiveModelNo = 0		; 0 means active model is unknown.


; Load forms below
; #include "Forms\Settings.au3"

If Not LoadGlobalSettings() Then
	; Run the initial settings form.
	MsgBox( 0, "First time running", "Seems this is your first time running this program." _
		 & @CRLF & "So all the settings are reset.", 20 )
	InitSettings()
	SaveSettings()
EndIf

; Get MMD3 or DME Handle and PID
SetHandleAndPID()

#EndRegion Globals

; Initialize GUI.
; Global $guiMain = GUICreate("MMD3/DME Helper",1150,850,-1,-1,-1,-1)
; If @error Then ExitC("Cannot create $guiMain")

; #include "Forms\Main.isf"
; GUISetState( @SW_SHOW, $guiMain )

; Use a dummy GUI for wallpaper.

Global $gaMonitors = GetMonitors()	; [0][0] is number of monitors, [n][0] is handle, [n][1] is tRec, [n][2] is text

Global $gaWorkRect = GetWorkArea()
Enum $MON_STARTX, $MON_STARTY, $MON_WIDTH, $MON_HEIGHT

Global $guiDummy = GUICreate( "", $gaWorkRect[$MON_WIDTH], $gaWorkRect[$MON_HEIGHT], $gaWorkRect[$MON_STARTX], $gaWorkRect[$MON_STARTY], $WS_POPUP )
; c( "work area: x:" & $aWorkRect[0] &" y:" & $aWorkRect[1] & " w:" & $aWorkRect[2] & " h:" & $aWorkRect[3])
Global $picBackground = GUICtrlCreatePic( @ScriptDir & "\Images\empty.jpg", $gaWorkRect[$MON_STARTX], $gaWorkRect[$MON_STARTY], $gaWorkRect[$MON_WIDTH], $gaWorkRect[$MON_HEIGHT], $SS_CENTERIMAGE)
Global $gbBackgroundOn = False	; No background initially

#Region Tray Menu Initialize

Global Const $gsIconPath = @ScriptDir & "\Icons\"

Global $hIcons[9]	; 9(0-8) bmps  for the tray menus

For $i = 0 to UBound($hIcons)-1
	$hIcons[$i] = _LoadImage($gsIconPath & $i & ".bmp", $IMAGE_BITMAP)
Next

; Initialize Tray using TrayMenuEx.au3

; Opt("TrayAutoPause", 0)  ; No pause in tray

Opt("TrayMenuMode", 3)	; The default tray menu items will not be shown and items are not checked when clicked.
; However, the program can change its check/uncheck status.

Local $iMenuItem = 0

Global $trayTitle = TrayCreateItem( "About MMD3/MDE Helper " & $gsVersion)	; $iMenuItem = 0
TrayCreateItem("")														; 1
Global $trayMenuStatus = TrayCreateMenu( TrayStatus() )					; 2  Icon set by TrayChangeStatusIcon()
Global $traySubMMD3 = TrayCreateItem("Monitor MMD3", $trayMenuStatus, -1, $TRAY_ITEM_RADIO )
Global $traySubMDE = TrayCreateItem("Monitor MDE", $trayMenuStatus, -1, $TRAY_ITEM_RADIO )
If $gsControlProg = "MMD3" Then
	TrayItemSetState($traySubMMD3, $TRAY_CHECKED)
Else
	TrayItemSetState($traySubMDE, $TRAY_CHECKED)
EndIf
$iMenuItem = 3

Global $trayMenuModels = TrayCreateMenu("ActiveModel:")	; Active model name.The subitems are all loaded models.
_TrayMenuAddImage($hIcons[0], $iMenuItem)
$gaModelMenuItems[0][$MODEL_ITEM_HANDLE] = TrayCreateItem("Model List", $trayMenuModels)
$gaModelMenuItems[0][$MODEL_ITEM_NAME] = "Model List"	; First item text
RefreshModelListMenu()	; Add the model list by $aModelItems
$iMenuItem += 1

Global $trayMenuCommands = TrayCreateMenu("Model Commands")		; Send common or custom commands to a model.
_TrayMenuAddImage($hIcons[1], $iMenuItem)
Global $traySubCmdStop = TrayCreateItem("Stop", $trayMenuCommands)
Global $traySubCmdShowActive = TrayCreateItem("Show Active Model", $trayMenuCommands)
Global $traySubCmdStartRandom = TrayCreateItem("Start Random Dance", $trayMenuCommands)
$iMenuItem += 1

Global $trayMenuPlayList = TrayCreateMenu("Active Play List:")		; Add / remove / Play the songs in play list.
_TrayMenuAddImage($hIcons[4], $iMenuItem)
Global $traySubStartPlaylist = TrayCreateItem("Start Active Playlist", $trayMenuPlayList)
Global $traySubStopPlaylist = TrayCreateItem("Stop Active Playlist", $trayMenuPlayList)
Global $traySubManagePlaylist = TrayCreateItem("Manage Play Lists", $trayMenuPlayList)
$iMenuItem += 1

Global $trayMenuSettings = TrayCreateMenu("Settings")	; If a program play sound, active model random dances.
_TrayMenuAddImage($hIcons[5], $iMenuItem)
Global $traySubChkDanceWithProgram = TrayCreateItem("Dance with a Program's Music/Sound", $trayMenuSettings)	; $giDanceWithProgram
Global $traySubChkDanceWithBackground = TrayCreateItem("Dance with Background", $trayMenuSettings)				; $giDanceWithBackground
Global $traySubDanceSettings = TrayCreateItem("Dance Settings", $trayMenuSettings)

Global $traySubMenuActiveMonitor = TrayCreateMenu("Show Background on Monitor", $trayMenuSettings)
Global $trayMonitors[ $gaMonitors[0][0] ]
For $i = 1 To $gaMonitors[0][0]
	$trayMonitors[$i-1] = TrayCreateItem( $gaMonitors[$i][2], $traySubMenuActiveMonitor, -1, $TRAY_ITEM_RADIO )
Next
TrayItemSetState($trayMonitors[$giActiveMonitor-1] , $TRAY_CHECKED )	 ; Set the active monitor.
$iMenuItem += 1

TrayCreateItem("")
$iMenuItem += 1
Global $trayExit = TrayCreateItem("Exit")
_TrayMenuAddImage($hIcons[6], $iMenuItem)

TrayChangeStatusIcon()


#EndRegion Tray Menu

; Now do the hooking
#include "GlobalHook.au3"
InitHook($guiDummy)
If @error Then 
	c("error in initialze hook. Error:" & @error)
	Exit
EndIf

#Region Main Loop
Local $hTimer1Sec = TimerInit()

while True
	Local $nTrayMsg = TrayGetMsg()
	Switch $nTrayMsg
		Case $trayTitle
			About()
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
GUIDelete($guiDummy)
CleanupHook()
Exit 

#Region Main Functions

; $sProg can be "MMD3", "MMD3Core","DME" or "DMECore"
; $sMessage is the text they received.
Func ProcessMessage($sProg, $sMessage)
	c( $sProg & ":" & @CRLF & "-----" & @crlf & $sMessage & @CRLF & @CRLF )
	Switch $sProg
		Case "MMD3Core"
			Select 	; Handle the command message from mmd3core.
				Case StringStartsWith( $sMessage, "loadModel:model" )
					Local $iModelNo = Int( StringBtw( $sMessage, "loadModel:model", ":{" ) )
					Local $sJson = "{" & StringBtw( $sMessage, "{", "" )
					c( "json to decode:" & $sJson)
					AddModel( $iModelNo, $sJson )
					
			EndSelect 
		Case "MMD3"
			Select ; Handle the messages from mmd3
				Case StringStartsWith($sMessage, "active:model")
					Local $iNumber = Int( StringBtw($sMessage, "model", "|") )
					SetActiveModelFromMessage($iNumber)
				Case StringStartsWith($sMessage, "remove_model:")
					Local $iNumber = Int( StringBtw($sMessage, "model:model", "|") )
					RemoveModelFromMessage($iNumber)
			EndSelect
	EndSwitch
	
EndFunc

Func RemoveModelFromMessage($iNumber)
	; A model was removed by mmd3
	Local $iCount = UBound($gaModels), $bFound = False , $iIndex
	If $iCount = 0 Then
		$giActiveModelNo = 0
		Return  ; no data anyway
	EndIf
	
	For $i = 0 to $iCount -1
		if $gaModels[$i][$MODEL_NO] = $iNumber Then 
			; Found a match
			$bFound = True
			$iIndex = $i
			ExitLoop
		EndIf
	Next
	
	If $bFound Then
		; Found the model to delete. number is $iIndex
		If $iIndex = 0 Then
			If $iCount = 1 Then
				; Last model to be removed
				$giActiveModelNo = 0
			Else
				$giActiveModelNo = $gaModels[1][$MODEL_NO] ; Next model's number
			EndIf
		ElseIf $iIndex = $iCount-1 Then ; Last model
			$giActiveModelNo = $gaModels[$iIndex-1][$MODEL_NO]
		Else
			$giActiveModelNo = $gaModels[$iIndex+1][$MODEL_NO]	; Next model's number
		EndIf
		_ArrayDelete($gaModels, $iIndex)
		; Set the items again.
		RefreshModelListMenu()
	Else 
		; Not found. Do nothing.
		
	EndIf
	
EndFunc


Func SetActiveModelFromMessage($iNumber)
	c( "Set active:" & $iNumber & " current:" & $giActiveModelNo)
	If Not IsInt($iNumber) Then Return
	If $iNumber = $giActiveModelNo Then Return
	Local $iCount = UBound($gaModels), $bFound = False 
	If $iCount = 0 Then
		; No models loaded, need to add it.
		AddModel($iNumber)
		RefreshModelListMenu()
		Return
	EndIf
	For $i = 0 to $iCount -1
		if $gaModels[$i][$MODEL_NO] = $iNumber Then 
			; Found a match
			$giActiveModelNo = $iNumber
			$bFound = True 
			ExitLoop
		EndIf
	Next
	If $bFound Then
		; Found the model.
		$giActiveModelNo = $iNumber
	Else 
		; Not found, need to add it to the array
		AddModel($iNumber)
	EndIf
	RefreshModelListMenu()
	; There is no need to do the waving.
EndFunc

Func SetActiveModelFromMenu($iNumber)
	If Not IsInt($iNumber) Then Return SetError(1)
	$giActiveModelNo = $iNumber
	If $gsControlProg = "MMD3" Then
		SendCommand( $ghHelperHwnd, $ghMMD3, "model" & $iNumber & ":active" )
	Else
		SendCommand( $ghHelperHwnd, $ghDME, "model" & $iNumber & ":active" )
	EndIf
EndFunc


Func AddModel($Number, $sJson = "")
	; Add a model to the list by simply a number, or a Json string for more detail
	Local $iCount = UBound($gaModels)
	ReDim $gaModels[$iCount + 1][3]
	$gaModels[$iCount][$MODEL_NO] = $Number
	If $sJson <> "" Then 
		$gaModels[$iCount][$MODEL_OBJ] = Json_Decode($sJson)
		if @error Then c("Json decode error. Error:" & @error)
		$gaModels[$iCount][$MODEL_NAME] = $gaModels[$iCount][$MODEL_OBJ].Item("name")
	Else
		$gaModels[$iCount][$MODEL_NAME] = "Model " & $Number
	EndIf
	$giActiveModelNo = $Number	; The new model will become the active one.
	; Now refresh the model list sub menu
	RefreshModelListMenu()
EndFunc

Func RefreshModelListMenu()
	Local $iCount = UBound($gaModelMenuItems)
	; The first row is always "Model List:"
	If $iCount > 1 Then 	; Has items
		For $i = 1 to $iCount-1	; Delete all the existing items.
			TrayItemDelete($gaModelMenuItems[$i][$MODEL_ITEM_HANDLE])
		Next
	EndIf
	$iCount = UBound($gaModels)
	if $iCount > 0 Then
		ReDim $gaModelMenuItems[$iCount + 1][2]
		For $i = 0 to $iCount-1
			; Add tray menu items
			$gaModelMenuItems[$i+1][$MODEL_ITEM_HANDLE] = TrayCreateItem( $gaModels[$i][$MODEL_NAME], $trayMenuModels, $TRAY_ITEM_RADIO)
			If $gaModels[$i][$MODEL_NO] = $giActiveModelNo Then									; If the active model number matches
				TrayItemSetState($gaModelMenuItems[$i+1][$MODEL_ITEM_HANDLE], $TRAY_CHECKED)	; Set it to be checked.
			EndIf
		Next
	EndIf
EndFunc


Func StringStartsWith($sFull, $sPart, $bCaseSensitive = False)
	If $bCaseSensitive Then 
		Return StringLower( StringLeft($sFull, StringLen($sPart)) ) = StringLower($sPart)
	Else 
		Return StringLeft($sFull, StringLen($sPart)) = $sPart
	EndIf
EndFunc

Func StringBtw($sFull, $str1, $str2, $case = 1)	; Default: case sensitive.
	Local $iPos1 = StringInStr($sFull, $str1, $case), $iPos2
	If $iPos1 = 0 Then Return SetError(1)	; $str1 Not found
	$iPos1 += StringLen($str1)
	If $str2 = "" Then
		$iPos2 = StringLen($sFull)
	Else
		$iPos2 = StringinStr( $sFull, $str2, $case, 1, $iPos1 )
		If $iPos2 = 0 Then Return SetError(2) ; $str2 not found
	EndIf
	Return StringMid( $sFull, $iPos1, $iPos2-$iPos1+1 )
EndFunc

Func InitSettings()
	$gsMMD3Path = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMMD3"
	$gsMMD3AssetPath = $gsMMD3Path & "\Appdata\Assets"
	$gsMMD3WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1480480"
	$gsDMEPath = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMagicEngine"
	$gsDMEAssetPath = $gsDMEPath & "\Appdata\Assets"
	$gsDMEWorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1096550"

	$gsBackgroundShow = "Disable"
	$giCenterWhenDance = 0
	$gsControlProg = "MMD3"
	$giActiveMonitor = 1
	$giDanceWithProgram = 0
	$gsDanceMonitorProgram = ""
	$giDanceWithBackground = 0		; 0 : disable , 1: enable. If enabled, the details are in sqlite file: helper.db
	; Helper.db will have Dance->Background | Model -> Background | All Background  data.
EndFunc

Func SaveSettings()
	RegWrite( $gsRegBase, "MMD3Path", "REG_SZ", $gsMMD3Path )
	RegWrite( $gsRegBase, "MMD3WorkshopPath", "REG_SZ", $gsMMD3WorkshopPath )
	RegWrite( $gsRegBase, "DMEPath", "REG_SZ", $gsDMEPath )
	RegWrite( $gsRegBase, "DMEWorkshopPath", "REG_SZ", $gsDMEWorkshopPath )
	
	RegWrite( $gsRegBase, "BackgroundShow", "REG_SZ", $gsBackgroundShow )
	RegWrite( $gsRegBase, "CenterWhenDance", "REG_DWORD", $giCenterWhenDance )
	RegWrite( $gsRegBase, "ControlProgram", "REG_SZ", $gsControlProg )
	RegWrite( $gsRegBase, "ActiveMonitor", "REG_DWORD", $giActiveMonitor )
	RegWrite( $gsRegBase, "DanceWithProgram", "REG_DWORD", $giDanceWithProgram )
	RegWrite( $gsRegBase, "DanceMonitorProgram", "REG_SZ", $gsDanceMonitorProgram )
	RegWrite( $gsRegBase, "DanceWithBackground", "REG_DWORD", $giDanceWithBackground )
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
	$giCenterWhenDance = RegRead($gsRegBase, "CenterWhenDance") ; true or false
	$giActiveMonitor = RegRead($gsRegBase, "ActiveMonitor") 
	$giDanceWithProgram = RegRead($gsRegBase, "DanceWithProgram")
	$gsDanceMonitorProgram = RegRead($gsRegBase, "DanceMonitorProgram")
	$giDanceWithBackground = RegRead($gsRegBase, "DanceWithBackground")
	Return True	; loaded
EndFunc

Func ShowBackground( $sBgFile )
	GUICtrlSetImage( $picBackground, $sBgFile ) 
	GUISetState( @SW_SHOW, $guiDummy)
	$gbBackgroundOn = True
EndFunc

Func SetBackground()
	; Set the background position and size based on active monitory
	$gaWorkRect = GetWorkArea()
	GUISetCoord ( $gaWorkRect[$MON_STARTX], $gaWorkRect[$MON_STARTY], $gaWorkRect[$MON_WIDTH], $gaWorkRect[$MON_HEIGHT] , $guiDummy)
	$picBackground = GUICtrlSetPos( $picBackground, $gaWorkRect[$MON_STARTX], $gaWorkRect[$MON_STARTY], $gaWorkRect[$MON_WIDTH], $gaWorkRect[$MON_HEIGHT] )
EndFunc

Func HideBackground()
	GUISetState( @SW_HIDE, $guiDummy )
	GUICtrlSetImage( $picBackground, @ScriptDir & "\Images\empty.jpg" )
	$gbBackgroundOn = False 
EndFunc

; Get the working visible area of the desktop, this doesn't include the area covered by the taskbar.
Func GetWorkArea()
	; The active monitor's work area
	Local $aMonitors = GetMonitorWorkAreas()	; get all screen's work areas
	Local $aScreen[4]
	$aScreen[0] = $aMonitors[$giActiveMonitor][1] ; start x
	$aScreen[1] = $aMonitors[$giActiveMonitor][2] ; start y
	$aScreen[2] = $aMonitors[$giActiveMonitor][3] - $aMonitors[$giActiveMonitor][1] ; width
	$aScreen[3] = $aMonitors[$giActiveMonitor][4] - $aMonitors[$giActiveMonitor][2] ; height
	Return $aScreen		; reture data is [x,y,width,height]
EndFunc   ;==>GetWorkArea

Func TrayChangeStatusIcon()
	If $bProgRunning Then 
		TraySetIcon("Icons\trayActive.ico")
		_TrayMenuAddImage($hIcons[7], 2)
	Else 
		TraySetIcon("Icons\trayInactive.ico")
		_TrayMenuAddImage($hIcons[8], 2)
	EndIf 
EndFunc

Func TrayStatus()
	Return "Status: " & $gsControlProg & ( $bProgRunning ? " is active." : " is not active.")
EndFunc

Func SetHandleAndPID()
	; It will check if the control program is running and set the Hwnd and PID
	Local $iPID
	If $gsControlProg = "MMD3" Then 
		$ghMMD3 = WinGetHandle( "DMMDCore3", "")
		If @error Then
			$bProgRunning = False 
		Else
			$bProgRunning = True
			$iPID = WinGetProcess("DesktopMMD3", "")
			If $iPID <> $giMMD3PID Then 
				$giMMD3PID = $iPID
				c ( "MMD3core hwnd:" & $ghMMD3 & " MMD3 PID:" & $giMMD3PID )
			EndIf 
		EndIf
	Else ; DME
		Global $ghDME = WinGetHandle( "DMMDCore", "")
		If @error Then ; Program is not running
			$bProgRunning = False
		Else 
			$iPID = WinGetProcess( "DesktpMagicEngine", "")
			If $iPID <> $giDMEPID Then 
				$giDMEPID = $iPID
				c ( "DMEcore hwnd:" & $ghDME & " DME PID:" & $giDMEPID )
			EndIf 
		EndIf
	EndIf
	
 	Return $bProgRunning
EndFunc

Func SetStatus()
 	If TrayItemGetText( $trayMenuStatus ) <> TrayStatus() Then
 		c("change title")
 		TrayItemSetText( $trayMenuStatus, TrayStatus() )
		TrayChangeStatusIcon()
 	EndIf
EndFunc

Func CheckEverySecond()
	Local $bHook = HookWorks()
	if @error Then ExitC ("Error in checking hook. Error:" & @error)
	If Not $bHook Then ReHook()
	SetHandleAndPID()	; Check to see if MMD3 or DME still running.
	SetStatus()			; Set the status text.
EndFunc

Func About()
	MsgBox(0, "About MMD3/DME Helper " & $gsVersion, $gsAboutText )
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

; Returns all monitors working areas
; Return array: MonitorHandle, startX, startY, EndX, EndY
; The x and y are in program's virtual coordinates, not physical pixels.
Func GetMonitorWorkAreas()
   Local $aData = _WinAPI_EnumDisplayMonitors()
   If IsArray($aData) Then
	  ReDim $aData[$aData[0][0] + 1][5]
	  For $i = 1 To $aData[0][0]
		 Local $aMon = _WinAPI_GetMonitorInfo($aData[$i][0])	 ;$aData[$i][0] contains the handle
		 For $j = 1 to 4
			$aData[$i][$j] = DllStructGetData($aMon[1], $j)
		 Next
	  Next
   Else
	  Return SetError(1)
   EndIf
   Return $aData
EndFunc

; Get all monitor's screen data.
; Return array: [0] is number of monitors, [1] is first monitor's details.
Func GetMonitors()
	Const $MDT_EFFECTIVE_DPI = 0
	Const $MDT_ANGULAR_DPI = 1
	Const $MDT_RAW_DPI = 2
	Const $MDT_DEFAULT = $MDT_ANGULAR_DPI

	Local $aData = _WinAPI_EnumDisplayMonitors()
	If IsArray($aData) Then
		ReDim $aData[$aData[0][0] + 1][3]	; [0][0] is number, [1][0] is handle, [1][1] is tRec, [1][2] is text
		For $i = 1 To $aData[0][0]
			Local $aRec[4]
			For $j = 1 to 4
				$aRec[$j-1] = DllStructGetData( $aData[$i][1], $j)
			Next
			Local $x = $aRec[2] -$aRec[0], $y = $aRec[3] -$aRec[1]
			; Get the scale
			Local $scale
			Local $aRet = DllCall("Shcore.dll", "long", "GetScaleFactorForMonitor", "long", $aData[$i][0], "uint*", $scale)
			; return value in $aRet[2]
			$x = Round( $x * $aRet[2] / 100)
			$y = Round( $y * $aRet[2] / 100)
			$aData[$i][2] = "Monitor " & $i & ": " & $x & "x" & $y
		Next
	Else
		Return SetError(1)
	EndIf
	Return $aData
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