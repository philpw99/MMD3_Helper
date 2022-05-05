#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile_type=a3x
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
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
#include <File.au3>
#include <GDIPlus.au3>	; To get the jpeg dimension only
#include "Json.au3"

opt("MustDeclareVars", 1)

#include "TrayMenuEx.au3"

#Region Globals Initialization

Global Const $gsVersion = "v1.0.4"

; Registry path to save program settings.
Global Const $gsRegBase = "HKEY_CURRENT_USER\Software\MMD3_Helper"
Global $gsMessageLog = ""

; Language
Global $gsLang = "Eng", $goLang

; Global settings
Global $gsControlProg, $giActiveMonitor
Global $gsTrayStatus = ""
Global $giDanceWithBg, $giDanceRandomBg, $giCurrentBg
Global $ghMMD, $giProgPID, $ghMMDProg

; Signified a dance extra.json is going to be used.
Global $gsDanceExtra = "", $ghDanceTimer, $gbDanceExtraPlaying = False
Global $gaDanceData, $giDanceItem, $gfDanceTime, $gsDancePath

Global $ghHelperHwnd = WinGetHandle( AutoItWinGetTitle(), "")
c ( "Helper handle:" & $ghHelperHwnd )
Global $giHelperPID = WinGetProcess($ghHelperHwnd)
c ( "Helper PID:" & $giHelperPID )
Global $gbProgRunning = False 	; The MMD3 or DME is running?

; Model number and model object data created by json.
Global Enum $MODEL_NO, $MODEL_NAME, $MODEL_OBJ
Global $gaModels[0][3]		; Models loaded in memory.

Global Enum $MODEL_ITEM_HANDLE, $MODEL_ITEM_NAME
Global $gaModelMenuItems[0][2]		; Menu Item Handle and name, first one is always "Model List"
Global $giActiveModelNo = 0		; 0 means active model is unknown.

; These settings will be useful for playlist creation.
Global Const $gsMMD3Path = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMMD3"
Global Const $gsMMD3AssetPath = $gsMMD3Path & "\Appdata\Assets"
Global Const $gsMMD3WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1480480"
Global Const $gsDMEPath = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMagicEngine"
Global Const $gsDMEAssetPath = $gsDMEPath & "\Appdata\Assets"
Global Const $gsDMEWorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1096550"
Global Const $gsMMD4Path = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMMD4"
Global Const $gsMMD4AssetPath = $gsMMD4Path & "\Appdata\Assets"
Global Const $gsMMD4WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1968650"

; Load forms below
; #include "Forms\Settings.au3"

If Not LoadGlobalSettings() Then
	; Run the initial settings form.
	InitSettings()
	SaveSettings()
	MsgBox( 0, T("First time running"), T("Seems this is your first time running this program.") _
	 & @CRLF & T("So all the settings are reset."), 20 )
EndIf

Global Const $gsAboutText = "MMD3 Helper " & $gsVersion & T(", written by Philip Wang.") _
						   &@CRLF& T("Extend the features of the Excellent DesktopMagicEngine, DesktopMMD3 and DesktopMMD4.")

; Run only a single instance
If AlreadyRunning() Then
   MsgBox(48,T("MMD3 Helper is still running."),T("MMD3 Helper is running. Maybe it had an error and froze. ") & @CRLF _
	  & T("You can use the 'task manager' to force-close it.") & @CRLF _
	  & T("Not recommend running two MMD3 Helper at the same time."),0)
   Exit
EndIf

; Backgrounds and Effects
Global $gaBgList = _FileListToArray( @ScriptDir & "\Backgrounds", "*", $FLTA_FOLDERS )

; Get MMD3 or DME Handle and PID
SetHandleAndPID()
LoadBackgroundList()

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
GUISetIcon( "Icons\trayActive.ico", -1, $guiDummy )
GUISetBkColor(0, $guiDummy)	; Black background.
; c( "work area: x:" & $aWorkRect[0] &" y:" & $aWorkRect[1] & " w:" & $aWorkRect[2] & " h:" & $aWorkRect[3])
Global $picBackground = GUICtrlCreatePic( @ScriptDir & "\Images\empty.jpg", 0, 0) ; Just a place holder.
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
TrayCreateItem("")
Global $trayMenuStatus = TrayCreateMenu( TrayStatus() )					; 2  Icon set by TrayChangeStatusIcon()
Global $traySubMMD3 = TrayCreateItem("Monitor MMD3", $trayMenuStatus, -1, $TRAY_ITEM_RADIO )
Global $traySubDME = TrayCreateItem("Monitor DME", $trayMenuStatus, -1, $TRAY_ITEM_RADIO )
Global $traySubMMD4 = TrayCreateItem("Monitor MMD4", $trayMenuStatus, -1, $TRAY_ITEM_RADIO )
; Set the initial value
Switch $gsControlProg
	Case "MMD3"
		TrayItemSetState($traySubMMD3, $TRAY_CHECKED)
	Case "DME"
		TrayItemSetState($traySubDME, $TRAY_CHECKED)
	Case "MMD4"
		TrayItemSetState($traySubMMD4, $TRAY_CHECKED)
EndSwitch

$iMenuItem = 3

Global $trayMenuModels = TrayCreateMenu("ActiveModel:")	; Active model name.The subitems are all loaded models.
_TrayMenuAddImage($hIcons[0], $iMenuItem)
TrayCreateItem("Model List", $trayMenuModels)
TrayCreateItem("", $trayMenuModels)
RefreshModelListMenu()	; Add the model list by $aModelItems

$iMenuItem += 1

Global $trayMenuCommands = TrayCreateMenu("Model Commands")		; Send common or custom commands to a model.
_TrayMenuAddImage($hIcons[1], $iMenuItem)
Global $traySubCmdStop = TrayCreateItem("Stop", $trayMenuCommands)
Global $traySubCmdShowActive = TrayCreateItem("Show Active Model", $trayMenuCommands)
Global $traySubCmdStartRandom = TrayCreateItem("Start Random Dance", $trayMenuCommands)
Global $traySubCmdShowLog = TrayCreateItem("Show Message Log", $trayMenuCommands)
Global $traySubCmdClearLog = TrayCreateItem("Clear Message Log", $trayMenuCommands)
$iMenuItem += 1

Global $trayMenuPlayList = TrayCreateMenu("Active Play List:")		; Add / remove / Play the songs in play list.
_TrayMenuAddImage($hIcons[4], $iMenuItem)

Global $traySubPlaylistStart = TrayCreateItem("Start Active Playlist", $trayMenuPlayList)
Global $traySubPlaylistStop = TrayCreateItem("Stop Active Playlist", $trayMenuPlayList)
Global $traySubPlaylistManage = TrayCreateItem("Manage Play Lists", $trayMenuPlayList)
Global $traySubPlaylistAdd = TrayCreateItem("Add to Active Playlist", $trayMenuPlayList)

$iMenuItem += 1
Global $trayMenuChooseBg = TrayCreateMenu("Choose Background")
_TrayMenuAddImage($hIcons[3], $iMenuItem)
Global $traySubChkRandomBg = TrayCreateItem("Random Background", $trayMenuChooseBg, -1, $TRAY_ITEM_RADIO ) 	; $giDanceRandomBg
If $giDanceRandomBg = 1 Then TrayItemSetState($traySubChkRandomBg, $TRAY_CHECKED)
; TrayCreateItem("", $trayMenuChooseBg)	; Seperator
Global $traySubBgItems[ $gaBgList[0]+1 ]
$traySubBgItems[0] = $gaBgList[0]	; set the number of bk at [0]. Now $gaBgList and $traySubBgItems are 1 to 1.
; Create the background menu list
For $i = 1 To $gaBgList[0]
	$traySubBgItems[$i] = TrayCreateItem( $gaBgList[$i], $trayMenuChooseBg, -1, $TRAY_ITEM_RADIO )
Next
; Seperator
TrayCreateItem("", $trayMenuChooseBg)
; Open bg folder
Global $traySubOpenBgFolder = TrayCreateItem("Open Background Folders", $trayMenuChooseBg)

$iMenuItem += 1
Global $trayMenuSettings = TrayCreateMenu("Settings")	; If a program play sound, active model random dances.
_TrayMenuAddImage($hIcons[5], $iMenuItem)
; Global $traySubChkDanceWithProgram = TrayCreateItem("Dance with a Program's Music/Sound", $trayMenuSettings)	; $giDanceWithProgram
Global $traySubChkDanceWithBg = TrayCreateItem("Enable Dance with Background/Effect", $trayMenuSettings)				; $giDanceWithBg
If $giDanceWithBg = 1 Then TrayItemSetState($traySubChkDanceWithBg, $TRAY_CHECKED)

Global $traySubMenuActiveMonitor = TrayCreateMenu("Show Background on Monitor", $trayMenuSettings)
Global $trayMonitors[ $gaMonitors[0][0] ]
; List monitors
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

		Case $traySubMMD3
			If $gsControlProg <> "MMD3" Then
				$gsControlProg = "MMD3"
				; TrayItemSetState($traySubMMD3, $TRAY_CHECKED)
				SetHandleAndPID()
				$gsTrayStatus = ""	; Reset the status text
				CheckStatus()
				SaveSettings()
				LoadBackgroundList()	; Update the file and folder list of backgrounds and effects
				; Clean the model list
				Global $gaModels[0][3]
				RefreshModelListMenu()
			EndIf
		Case $traySubDME
			If $gsControlProg <> "DME" Then
				$gsControlProg = "DME"
				SetHandleAndPID()
				$gsTrayStatus = ""	; Reset the status text
				CheckStatus()
				SaveSettings()
				LoadBackgroundList()	; Update the file and folder list of backgrounds and effects
				; Clear the model list
				Global $gaModels[0][3]
				RefreshModelListMenu()
			EndIf
		Case $traySubMMD4
			If $gsControlProg <> "MMD4" Then
				$gsControlProg = "MMD4"
				SetHandleAndPID()
				$gsTrayStatus = ""	; Reset the status text
				CheckStatus()
				SaveSettings()
				LoadBackgroundList()	; Update the file and folder list of backgrounds and effects
				; Clear the model list
				Global $gaModels[0][3]
				RefreshModelListMenu()
			EndIf

		Case $traySubChkDanceWithBg
			If $giDanceWithBg = 0 Then
				; Enable dance with Background / Effects.
				TrayItemSetState($traySubChkDanceWithBg, $TRAY_CHECKED)
				$giDanceWithBg = 1
				TrayItemSetState($traySubChkRandomBg, $TRAY_CHECKED)
				$giDanceRandomBg = 1
			Else
				; Disable dance with Background / Effects.
				TrayItemSetState($traySubChkDanceWithBg, $TRAY_UNCHECKED)
				$giDanceWithBg = 0
				TrayItemSetState($traySubChkRandomBg, $TRAY_UNCHECKED)
				$giDanceRandomBg = 0
			EndIf
			SaveSettings()
		Case $traySubChkRandomBg
			; Enable random background
			$giDanceRandomBg = 1
			$giCurrentBg = 0 	; No current bg
			SaveSettings()
		Case $traySubOpenBgFolder
			; Open the background folder
			ShellExecute( @ScriptDir & "\Backgrounds\" )
		Case $traySubCmdShowLog
			; Show the recent messsage/command log
			FileWrite( @TempDir & "\messagelog.txt", $gsMessageLog)
			ShellExecute( @TempDir & "\messagelog.txt")
		Case $traySubCmdClearLog
			; Clear the message/command log
			$gsMessageLog = ""
			
		Case $traySubCmdStop
			SendCommand( $ghHelperHwnd, $ghMMD, "model" & $giActiveModelNo & ".Interrupt" )
			If $gbDanceExtraPlaying Then StopDanceExtra()
		Case $traySubCmdShowActive
			SendCommand( $ghHelperHwnd, $ghMMD, "model" & $giActiveModelNo & ".active" )
		Case $traySubCmdStartRandom
			NotDoneYet()
		Case $traySubPlaylistStart, $traySubPlaylistStop, $traySubPlaylistManage
			NotDoneYet()
		Case $trayTitle
			About()
		Case $trayExit
			ExitLoop
	EndSwitch

	; Check model list menu
	For $i = 0 to UBound($gaModelMenuItems)-1
		If $nTrayMsg = $gaModelMenuItems[$i][$MODEL_ITEM_HANDLE] Then
			; choose the model, it will be active.
			SetActiveModelFromMenu($gaModels[$i][$MODEL_NO])
		EndIf
	Next

	; Check background list items
	For $i = 1 to $traySubBgItems[0]
		If $nTrayMsg = $traySubBgItems[$i] Then
			$giDanceRandomBg = 0
			$giCurrentBg = $i
			If $gbDanceExtraPlaying Then
				; Switch to current bg
				$gsDanceExtra = @ScriptDir & "\Backgrounds\" & $gaBgList[$i] & "\extra.json"
				StartDanceExtra()
			EndIf
		EndIf
	Next

	; Check $gsDanceExtra
	If $gsDanceExtra <> "" Then
		If $gsDanceExtra = "STOP" Then
			StopDanceExtra(False)	; Slow fade out
		ElseIf $gsDanceExtra = "RANDOM" Then
			; Start a random background/effct $gaBgList, $gaEffectList
			If $giDanceRandomBg = 1 Then
				; Choose a random background
				Local $sRandomFolder = @ScriptDir & "\Backgrounds\" & $gaBgList[ Random( 1, $gaBgList[0], 1) ]
				$gsDanceExtra = $sRandomFolder & "\extra.json"
				StartDanceExtra()
			ElseIf $giCurrentBg <> 0 Then
				; Go with the desinated background
				$gsDanceExtra = @ScriptDir & "\Backgrounds\" & $gaBgList[$giCurrentBg] & "\extra.json"
				StartDanceExtra()
			EndIf
		Else
			c("DanceExtra:" & $gsDanceExtra & "|" )
			; Start a new extra
			; Save the Extra string first

			if $gbDanceExtraPlaying Then
				Local $sExtra = $gsDanceExtra
				StopDanceExtra(True)	; Fast switch.
				; Restore the extra
				$gsDanceExtra = $sExtra
			EndIf
			StartDanceExtra()
		EndIf
	EndIf

	; Check active monitor click
	For $i = 1 To $gaMonitors[0][0]
		if $nTrayMsg = $trayMonitors[$i-1] Then
			; Set the active monitor
			$giActiveMonitor = $i
			SetBackgroundRect()
		EndIf
	Next

	; Check during the extra playing
	; check to see if a dance extra is ending.
	If $gbDanceExtraPlaying Then
	; Check to see if the dance is over.
		if TimerDiff($ghDanceTimer) > $gfDanceTime Then
			; Times up for this item
			If $giDanceItem+1 >= UBound($gaDanceData) Then
				StopDanceExtra(False)	; Slow fade out
			Else
				; Next item in extra.json
				StartDanceNext()
			EndIf
		EndIf
	EndIf


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
If $gbDanceExtraPlaying Then StopDanceExtra()
Exit

#Region Main Functions

Func T($str)
	; Implement different languages using dictionary
	If $gsLang = "Eng" Then Return $str
	Return $goLang.Item($str)
EndFunc

Func NotDoneYet()
	MsgBox(0, "Not Done Yet", "This feature is not implemented yet. Maybe wait for the next version?" )
EndFunc

Func LoadBackgroundList()
	$gaBgList = _FileListToArray( @ScriptDir & "\Backgrounds", "*", $FLTA_FOLDERS )
EndFunc

Func StartDanceNext()
	; run the next dance extra
	$giDanceItem += 1
	If $giDanceItem >= UBound($gaDanceData) Then
		; It should have been stopped. So here is just in case.
		StopDanceExtra(True)	; fast stop
		Return Error(1, @ScriptLineNumber)
	EndIf

	c( "Playing dance:" & $giDanceItem )
	Local $oDance = $gaDanceData[$giDanceItem]
	If Not IsObj($oDance) Then Return Error(1, @ScriptLineNumber)

	c("Next Dance seconds:" & $oDance.Item("Time") )

	$gfDanceTime = $oDance.Item("Time") * 1000	; Convert to milliseconds
	$ghDanceTimer = TimerInit()	; Start new timer count.

	If $oDance.Item("Background") = "" Then
		; It's empty. Keep the existing background. This item might just want to change the effect.
	Else
		Local $sPicFile = $gsDancePath & "\" & $oDance.Item("Background")
		_GUICtrlStatic_SetPicture( $picBackground, $sPicFile)
	EndIf

	If $oDance.Item("Effect") = "" Then
		; No effects
		SendCommand( $ghHelperHwnd, $ghMMD, "effect.remove" )
	Else
		; Load an effect by folder
		ShowEffect(  $gsDancePath & "\" & $oDance.Item("Effect") )
	EndIf

EndFunc

Func ShowEffect($sEffectFolder)
	Local $sEffectFile = $sEffectFolder & "\" & $gsControlProg & ".json"
;~ 	Switch $gsControlProg
;~ 		Case "MMD3"
;~ 			$sEffectFile = $sEffectFolder & "\MMD3.json"
;~ 		Case "MDE"
;~ 			$sEffectFile = $sEffectFolder & "\MDE.json"
;~ 		Case "MMD4"
;~ 			$sEffectFile = $sEffectFolder & "\MMD4.json"
;~ 		Case Else
;~ 			$sEffectFile = $sEffectFolder & "\item.json"
;~ 	EndSwitch

	If Not FileExists($sEffectFile) Then Return Error(1, @ScriptLineNumber)

	Local $oEffect = Json_Decode( FileRead( $sEffectFile) ) ; Get the effect settings from file.
	If Not IsObj($oEffect) Then Return Error(2, @ScriptLineNumber)

	; Set effect string
	$oEffect.Item("path") = $sEffectFolder & "\"
	$oEffect.Item("src") = $sEffectFolder & "\" & $oEffect.Item("src")
	Local $sEffectString = "loadEffect:effect:" & Json_Encode( $oEffect )

	c( "effect to send:" & $sEffectString )
	SendCommand( $ghHelperHwnd, $ghMMD, $sEffectString )
EndFunc

Func StopDanceExtra($bFast = False)
	$gbDanceExtraPlaying = False
	$gsDanceExtra = ""
	$gaDanceData = ""
	$gsDancePath = ""
	$giDanceItem = 0
	$gfDanceTime = 0

	SendCommand( $ghHelperHwnd, $ghMMD, "effect.remove" )
	HideBackground($bFast)	; It will take a while for this to finish. So it's the last thing to do.
	; Reset all the dance data.
EndFunc

Func StartDanceExtra()
	; Run the dance extra for the first time.
	; Global $gsDanceExtra, $ghDanceTimer, $gaDanceData,$giDanceItem,$gfDanceTime
	$gsDancePath = GetFolderFromPath( $gsDanceExtra )	; Store the path of dance.
	$gaDanceData = Json_Decode( FileRead( $gsDanceExtra ) )
	If UBound($gaDanceData) = 0 or Not IsObj($gaDanceData[0]) Then
		c( "error in $gsDanceExtra:" & $gsDanceExtra)
		$gsDanceExtra = ""
		Return Error(1, @ScriptLineNumber)
	EndIf

	$gsDanceExtra = ""

	$giDanceItem = 0	; Currently using the first item in the extra's array.
	Local $oDance = $gaDanceData[0]

	; Should be only 3 values : Time, Background and Effect
	; Time is number of seconds of the song, Background is the picture full path
	; Effect is the full effect string.
	$gbDanceExtraPlaying = True		; Notify the main loop the dance extra is running.
	$ghDanceTimer = TimerInit()		; Start the timer.

	c("Dance seconds:" & $oDance.Item("Time") )
	$gfDanceTime = $oDance.Item("Time") * 1000	; Convert to milliseconds
	if $gfDanceTime = 0 Then $gfDanceTime = 9999999	; Just in case.

	Local $sBack = $oDance.Item("Background")
	If $sBack <> "" Then
		; Set screen background
		If StringMid($sBack, 2, 1) <> ":" Then
			; relative path
			$sBack = $gsDancePath & "\" & $sBack
		EndIf
		c( "background to show:" & $sBack)
		ShowBackground($sBack)
	EndIf
	Local $sEffect = $oDance.Item("Effect")	; Show effect's folder.
	If  $sEffect <> "" Then
		If StringMid($sEffect, 2, 1) <> ":" Then
			; Relative path.
			$sEffect = $gsDancePath & "\" & $sEffect
		EndIf
		c( "Effect to show:" & $sEffect)
		ShowEffect(  $sEffect )
	EndIf
EndFunc


; $sProg can be "MMD3", "MMD3Core","DME" or "DMECore"
; $sMessage is the text they received.
Func ProcessMessage($sProg, $sMessage)
	c( $sProg & ":" & @CRLF & "-----" & @crlf & $sMessage & @CRLF & @CRLF )
	
	$gsMessageLog &= @CRLF & "-----" & @CRLF & "From " & $sProg & ":" & @CRLF & $sMessage
	If StringLen($gsMessageLog) > 50000 Then $gsMessageLog = StringLeft($gsMessageLog, 40000) ; Keep the last 40k
	
	Switch $sProg
		Case "MMD3Core", "DMECore", "MMD4Core"
			Select 	; Handle the command message from mmd3core.
				Case StringStartsWith( $sMessage, "loadModel:model" )
					; Load a new model.
					Local $iModelNo = Int( StringBtw( $sMessage, "loadModel:model", ":{" ) )
					Local $sJson = "{" & StringBtw( $sMessage, "{", "" )
					; c( "json to decode:" & $sJson)
					AddModel( $iModelNo, $sJson )
				Case $giDanceWithBg = 1
					If StringInStr($sMessage, ".DanceReady", 1) <> 0 Then
						; Time to start a dance. Check if Extra.json exist.
						Local $sPath = GetFolderFromPath( StringAfter($sMessage, "|") )
						If FileExists( $sPath & "\extra.json" ) Then ; The one with specified background/effects takes the priority
							$gsDanceExtra = $sPath & "\extra.json"  ; Once $gsDanceExtra is set. It will be processed by the main loop.
						ElseIf $giDanceWithBg = 1 Then
							$gsDanceExtra = "RANDOM"		; Start random background / effect
						EndIf
					ElseIf StringInStr($sMessage, "DanceEnd", 1) <> 0 Then
						; User stop a dance.
						$gsDanceExtra = "STOP"
					EndIf
			EndSelect
		Case "MMD3", "DME", "MMD4"
			Select ; Handle the messages from mmd3
				Case StringStartsWith($sMessage, "active:model")
					; Set active model
					Local $iNumber = Int( StringBtw($sMessage, "model", "|") )
					SetActiveModelFromMessage($iNumber)
				Case StringStartsWith($sMessage, "remove_model:")
					; Remove a model.
					Local $iNumber = Int( StringBtw($sMessage, "model:model", "|") )
					RemoveModelFromMessage($iNumber)
			EndSelect

	EndSwitch
	
EndFunc

Func StringAfter( $String, $Delimiter)
	Local $iPos = StringInStr( $String, $Delimiter, 2)
	If $iPos = 0 Then return ""
	Return StringMid($String, $iPos + 1)
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
	Local $sName
	If $iCount = 0 Then
		; No models loaded, need to add it.
		AddModel($iNumber)
		TrayItemSetText($trayMenuModels, "Active Model: Model " & $iNumber)
		RefreshModelListMenu()
		Return
	EndIf
	For $i = 0 to $iCount -1
		if $gaModels[$i][$MODEL_NO] = $iNumber Then
			; Found a match
			$giActiveModelNo = $iNumber
			$bFound = True
			TrayItemSetText($trayMenuModels, "Active Model: " & $gaModels[$i][$MODEL_NAME] )
			ExitLoop
		EndIf
	Next
	If $bFound Then
		; Found the model.
		$giActiveModelNo = $iNumber
	Else
		; Not found, need to add it to the array
		AddModel($iNumber)
		TrayItemSetText($trayMenuModels, "Active Model: Model " & $iNumber)
	EndIf
	RefreshModelListMenu()
	; There is no need to do the waving.
EndFunc

Func SetActiveModelFromMenu($iNumber)
	; No, you cannot set active model from the menu.
	; So it will only wave at you, nothing more.
	If Not IsInt($iNumber) Then Return Error(1, @ScriptLineNumber)
	; $giActiveModelNo = $iNumber
	SendCommand( $ghHelperHwnd, $ghMMD, "model" & $iNumber & ".active" )
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
	If $iCount > 0 Then 	; Has items
		For $i = 0 to $iCount-1	; Delete all the existing items.
			TrayItemDelete($gaModelMenuItems[$i][$MODEL_ITEM_HANDLE])
		Next
	EndIf

	$iCount = UBound($gaModels)
	if $iCount > 0 Then
		ReDim $gaModelMenuItems[$iCount][2]
		For $i = 0 to $iCount-1
			; Add tray menu items
			$gaModelMenuItems[$i][$MODEL_ITEM_HANDLE] = TrayCreateItem( $gaModels[$i][$MODEL_NAME], $trayMenuModels, -1, $TRAY_ITEM_RADIO)
			If $gaModels[$i][$MODEL_NO] = $giActiveModelNo Then									; If the active model number matches
				TrayItemSetState($gaModelMenuItems[$i][$MODEL_ITEM_HANDLE], $TRAY_CHECKED)	; Set it to be checked.
				TrayItemSetText($trayMenuModels, "Active Model: " & $gaModels[$i][$MODEL_NAME])
			EndIf
		Next
	Else
		TrayItemSetText($trayMenuModels, "Active Model: None")
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
	If $iPos1 = 0 Then Return Error(1, @ScriptLineNumber)	; $str1 Not found
	$iPos1 += StringLen($str1)
	If $str2 = "" Then
		$iPos2 = StringLen($sFull)
	Else
		$iPos2 = StringinStr( $sFull, $str2, $case, 1, $iPos1 )
		If $iPos2 = 0 Then Return Error(2, @ScriptLineNumber) ; $str2 not found
	EndIf
	Return StringMid( $sFull, $iPos1, $iPos2-$iPos1+1 )
EndFunc

Func LoadLanguage()
	If $gsLang = "Eng" Then Return
	$goLang = ObjCreate('Scripting.Dictionary')
	Local $hFile = FileOpen(@ScriptDir & "\Languages\" & $gsLang & ".txt")
	If @error Then Return Error(1, @ScriptLineNumber)
	
	While True 
		Local $sLine = FileReadLine($hFile)
		If @error Then ExitLoop	; Exit the whole thing, it's the end of the file.
		Local $iPos = StringInStr($sLine, Chr(9))	; First tab pos
		Local $iPos2 = StringInStr($sLine, chr(9), 1, -1)	; Last tab pos
		If $iPos = 0 Then ContinueLoop ; Read the next line
		$goLang.Add( StringLeft($sLine, $iPos-1), StringMid( $sLine, $iPos2 + 1) )
	WEnd 
EndFunc

Func InitSettings()
	; This settings will be saved
	$gsLang = "Eng"
	$gsControlProg = "MMD3"
	$giActiveMonitor = 1
	$giDanceWithBg = 1		; 0 : disable , 1: enable.
	$giDanceRandomBg = 1
EndFunc

Func SaveSettings()
	RegWrite( $gsRegBase, "ControlProgram", "REG_SZ", $gsControlProg )
	RegWrite( $gsRegBase, "Language", "REG_SZ", $gsLang )
	RegWrite( $gsRegBase, "ActiveMonitor", "REG_DWORD", $giActiveMonitor )
	RegWrite( $gsRegBase, "DanceWithBackground", "REG_DWORD", $giDanceWithBg )
	RegWrite( $gsRegBase, "DanceRandomBackground", "REG_DWORD", $giDanceRandomBg )
EndFunc

Func LoadGlobalSettings()
	; return: Load successful  true/false
	$gsControlProg = RegRead($gsRegBase, "ControlProgram") ; "MMD3" or "DME"
	If @error Then Return False
	$gsLang = RegRead($gsRegBase, "Language")	; Eng or Chs or Cht
	If @error Then Return False
	If $gsLang <> "Eng" Then LoadLanguage()
	
	$giActiveMonitor = RegRead($gsRegBase, "ActiveMonitor")
	If @error Then Return False
	$giDanceWithBg = RegRead($gsRegBase, "DanceWithBackground")
	If @error Then Return False
	$giDanceRandomBg = RegRead($gsRegBase, "DanceRandomBackground")
	If @error Then Return False
	Return True	; loaded
EndFunc

; This function returns the proper dimension for picBackground
Func CalcBackgroundPos($iX, $iY)
	Local $fRatio = $iX / $iY
	Local $iScreenX = $gaWorkRect[$MON_WIDTH], $iScreenY = $gaWorkRect[$MON_HEIGHT]
	Local $fPicScale = $iScreenX / $iX
	Local $iOutX, $iOutY = Floor( $iY * $fPicScale )
	Local $iLeft = 0, $iTop = 0
	If $iOutY > $iScreenY Then
		; Height is too much
		; This is a portrait picture
		$iOutX = Floor( $iScreenY * $fRatio )
		$iOutY = $iScreenY
		$iLeft = Floor( ($iScreenX - $iOutX) / 2 )
	Else
		; Height is not enough for screen.So center it vertically
		$iOutX = $iScreenX
		$iTop = Floor ( ( $iScreenY -$iOutY ) / 2 )
	EndIf
	Local $aRet[4] = [$iLeft, $iTop, $iOutX, $iOutY]
	Return $aRet
EndFunc

; This function switch the background immediately without fade in. No change in guiDummy
Func SwitchBackground( $sBgFile)
	; Local $aDim = GetJpegDimension($sBgFile)
	; if @error Then Return Error(1, @ScriptLineNumber)

	; Local $aSize = CalcBackgroundPos($aDim[0], $aDim[1])

	; Now set the position of pic control, GUI should have set on the full work area.
	; GUICtrlSetPos($picBackground, $aSize[0], $aSize[1], $aSize[2], $aSize[3])
	; GUICtrlSetImage( $picBackground, $sBgFile )

	_GUICtrlStatic_SetPicture($picBackground, $sBgFile)
	If @error Then Return Error(1, @ScriptLineNumber)

	$gbBackgroundOn = True
	; Set the dancer to the front.
	WinActivate($ghMMD)

EndFunc

; This function fade in and show the background. Change guiDummy to visible
Func ShowBackground( $sBgFile )
	; Local $aDim = GetJpegDimension($sBgFile)
	; If @error Then Return Error(1, @ScriptLineNumber)
	; Create it again to get the dimension of the picture
	;c( "picture size: " & $aDim[0] & "x" & $aDim[1] )
	;Local $aSize = CalcBackgroundPos($aDim[0], $aDim[1])

	; c( "BackgroundRect:" & $aSize[0] & ", " & $aSize[1] & ", " & $aSize[2] & ", " & $aSize[3] )
	; Now set the position of pic control, GUI should have set on the full work area.
	; GUICtrlSetPos($picBackground, $aSize[0], $aSize[1], $aSize[2], $aSize[3])
	; GUICtrlSetImage( $picBackground, $sBgFile )

	_GUICtrlStatic_SetPicture($picBackground, $sBgFile)
	If @error Then Return Error(1, @ScriptLineNumber)

	; Fade in
	WinSetTrans($guiDummy, "", 0 )
	GUISetState( @SW_SHOW, $guiDummy)
	For $i = 5 to 255 step 25	; Change background alpha 10 times in 1 sec.
		WinSetTrans($guiDummy, "", $i )
		Sleep(100)
	Next
	$gbBackgroundOn = True
	; Set the dancer to the front.
	WinActivate($ghMMD)

EndFunc

Func _GUICtrlStatic_SetPicture($Control, $File, $KeepRatio = False)

    Local Const $STM_SETIMAGE = 0x0172
    Local Const $IMAGE_BITMAP = 0
    Local $iImgX, $iImgY

    IF NOT FileExists($File) Then Return SetError(1)

    _GDIPlus_Startup()

    Local $hOrigImage = _GDIPlus_ImageLoadFromFile($File)
    $iImgX = _GDIPlus_ImageGetWidth($hOrigImage)
    $iImgY = _GDIPlus_ImageGetHeight($hOrigImage)
	Local $aSize = CalcBackgroundPos($iImgX, $iImgY)
	; Local $iLeft = $aSize[0], $iTop = $aSize[1]
	Local $SizeX = $aSize[2], $SizeY = $aSize[3]

	GUICtrlSetPos($Control, $aSize[0], $aSize[1], $aSize[2], $aSize[3])

    Local $hResizedBitmap = _CreateBitmap($SizeX, $SizeY)
    Local $hResizedImage = _GDIPlus_BitmapCreateFromHBITMAP($hResizedBitmap)
    Local $hGraphics = _GDIPlus_ImageGetGraphicsContext($hResizedImage)

    Local $DestX = 0
    Local $DestY = 0
    Local $FSizeX = $SizeX
    Local $FSizeY = $SizeY

    IF $KeepRatio Then
        Local $iWidth = _GDIPlus_ImageGetWidth($hOrigImage)
        Local $iHeight = _GDIPlus_ImageGetHeight($hOrigImage)
        Local $picRatio = $iWidth / $iHeight

        IF $picRatio >= 1 Then
            $FsizeY = $FsizeX / $picRatio
            If $FsizeY > $SizeY Then
                $FSizeY = $SizeY
                $FSizeX = $FSizeY * $picRatio
            EndIf
        EndIF
        IF $picRatio <= 1 Then
            $FsizeX = $FsizeY * $picRatio
            If $FsizeX > $SizeX Then
                $FSizeX = $SizeX
                $FSizeY = $FSizeX / $picRatio
            EndIf
        EndIF

        $DestX = ($SizeX - $FSizeX) / 2
        $DestY = ($SIzeY - $FSizeY) / 2
    EndIF

    _GDIPlus_GraphicsDrawImageRect($hGraphics, $hOrigImage, $DestX,$DestY,$FSizeX, $FSizeY)

    Local $hBitmap = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hResizedImage,0x00000000)
    If NOT IsHwnd($Control) Then $Control = GUICtrlGetHandle($Control)



    Local $oldBitmap = _SendMessage($Control,$STM_SETIMAGE,$IMAGE_BITMAP,$hBitmap,0,"wparam","lparam","hwnd")
    IF $oldBitmap <> 0 Then
        _WinAPI_DeleteObject($oldBitmap)
    EndIf

    _GDIPlus_ImageDispose($hOrigImage)
    _GDIPlus_ImageDispose($hResizedImage)
    _GDIPlus_GraphicsDispose($hGraphics)
    _WinAPI_DeleteObject($hResizedBitmap)

    _GDIPlus_Shutdown()
EndFUnc

Func _CreateBitmap($iW, $iH)
    Local $hWnd, $hDDC, $hCDC, $hBMP
    $hWnd = _WinAPI_GetDesktopWindow()
    $hDDC = _WinAPI_GetDC($hWnd)
    $hCDC = _WinAPI_CreateCompatibleDC($hDDC)
    $hBMP = _WinAPI_CreateCompatibleBitmap($hDDC, $iW, $iH)
    _WinAPI_ReleaseDC($hWnd, $hDDC)
    _WinAPI_DeleteDC($hCDC)
    Return $hBMP
EndFunc   ;==>_CreateBitmap

Func SetBackgroundRect()
	; Set the background position and size based on active monitor
	$gaWorkRect = GetWorkArea()
	GUISetCoord ( $gaWorkRect[$MON_STARTX], $gaWorkRect[$MON_STARTY], $gaWorkRect[$MON_WIDTH], $gaWorkRect[$MON_HEIGHT] , $guiDummy)
	GUISetBkColor(0, $guiDummy)
	; $picBackground = GUICtrlSetPos( $picBackground, 0, 0, $gaWorkRect[$MON_WIDTH], $gaWorkRect[$MON_HEIGHT] )
EndFunc

Func HideBackground($bFast = False)
	; Fade out.
	If Not $bFast Then
		For $i = 250 to 0 Step -25
			WinSetTrans($guiDummy, "", $i)
			Sleep(100)
		Next
	EndIf
  	GUISetState( @SW_HIDE, $guiDummy )
	; GUICtrlSetImage( $picBackground, @ScriptDir & "\Images\empty.jpg" )
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
	If $gbProgRunning Then
		TraySetIcon("Icons\trayActive.ico")
		_TrayMenuAddImage($hIcons[7], 2)
	Else
		TraySetIcon("Icons\trayInactive.ico")
		_TrayMenuAddImage($hIcons[8], 2)
	EndIf
	TraySetToolTip( TrayStatus() )
EndFunc

Func TrayStatus()
	Return "Status: " & $gsControlProg & ( $gbProgRunning ? " is active." : " is not active.")
EndFunc

Func SetHandleAndPID()
	; It will check if the control program is running and set the Hwnd and PID
	Local $iPID
	Switch $gsControlProg
		Case "MMD3"
			$ghMMD = WinGetHandle( "DMMDCore3", "")
			If @error Then
				$gbProgRunning = False
			Else
				$gbProgRunning = True
				$iPID = WinGetProcess("DesktopMMD3", "")
				If $iPID <> $giProgPID Then
					$giProgPID = $iPID
					c ( "MMD3Core hwnd:" & $ghMMD & " MMD3 PID:" & $giProgPID )
				EndIf
			EndIf
		Case "DME"
			$ghMMD = WinGetHandle( "[REGEXPTITLE:DMMDCore$]", "")
			If @error Then ; Program is not running
				$gbProgRunning = False
			Else
				$gbProgRunning = True
				$iPID = WinGetProcess( "DesktopMagicEngine", "")
				If $iPID <> $giProgPID Then
					$giProgPID = $iPID
					c ( "DMEcore hwnd:" & $ghMMD & " DME PID:" & $giProgPID )
				EndIf
			EndIf
		Case "MMD4"
			$ghMMD = WinGetHandle( "DMMD4Core", "")
			If @error Then ; Program is not running
				$gbProgRunning = False
			Else
				$gbProgRunning = True
				$iPID = WinGetProcess( "DesktopMMD4", "")
				If $iPID <> $giProgPID Then
					$giProgPID = $iPID
					c ( "MMD4Core hwnd:" & $ghMMD & " MMD4 PID:" & $giProgPID )
				EndIf
			EndIf
	EndSwitch
 	Return $gbProgRunning
EndFunc

Func CheckStatus()
 	If $gsTrayStatus <> TrayStatus() Then
 		TrayItemSetText( $trayMenuStatus, TrayStatus() )
		TrayChangeStatusIcon()
		$gsTrayStatus = TrayStatus()
 	EndIf
EndFunc

Func CheckEverySecond()
	Local $bHook = HookWorks()
	if @error Then ExitC ("Error in checking hook. Error:" & @error)
	If Not $bHook Then ReHook()
	SetHandleAndPID()	; Check to see if MMD3 or DME still running.
	CheckStatus()			; Set the status text.

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
	  Return Error(1, @ScriptLineNumber)
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
		Return Error(1, @ScriptLineNumber)
	EndIf
	Return $aData
EndFunc

Func Error($err, $line)
	c("Error at line:" & $line & " Error:" & $err)
	SetError( $err )
EndFunc

Func GetFolderFromPath($FullPath)
	; Get the folder and drive from a full path string without the last "\"
	return StringLeft( $FullPath, StringInStr($FullPath, "\", 1, -1) -1 )
EndFunc

Func GetFileFromPath($FullPath)
	; Get the file name from a full path string.
	return StringMid( $FullPath, StringInStr($FullPath, "\", 1, -1) + 1)
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