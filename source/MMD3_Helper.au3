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
#include <WinAPICom.au3>	; For sound detection.
#include <Process.au3>		; To get the process name
#include <Sound.au3>		; To get the length of a music file.
#include <Inet.au3>			; To get the random online quote
#include "Json.au3"

opt("MustDeclareVars", 1)

#include "TrayMenuEx.au3"

#Region Globals Initialization

Global Const $gsVersion = "v1.1.1"

; Registry path to save program settings.
Global Const $gsRegBase = "HKEY_CURRENT_USER\Software\MMD3_Helper"

; Language
Global $gsLang = "Eng", $goLang

; Global settings
Global $gsControlProg, $giActiveMonitor
Global $gsTrayStatus = ""
Global $giDanceWithBg, $giDanceRandomBg, $giCurrentBg
Global $ghMMD, $giProgPID, $ghMMDProg
Global $giRandomDanceWithSound, $gsSoundMonitorProg, $gbRandomDancePlaying = False
Global $giRandomDanceTimeLimit, $ghRandomDanceTimer	; for use with random dance with sound

Global $gbProgDancePlaying = False ; MMD program is playing a dance
Global $goDanceSong					; The item.json for that dance.
Global $giRandomIdleAction 		; 0 disable, 1 misc actions, 2 idle actions
Global $giIdleActionFrequency 	; 0 high, 1 medium, 2 low
Global $giBubbleText	; Dialog with bubble text.
Global $gsBubble = ""		; model, duration and text of bubble "model1:5|Hello Master!"
Global $gaGreetings[0]		; Greeting json objects, not load unless user want to use it.

; Signified a dance extra.json is going to be used.
; Global $gaMMD3Dances[51]  $gaMMD4Dances[0]

Global $gsDanceExtra = "", $ghDanceTimer, $gbDanceExtraPlaying = False
Global $gaDanceData, $giDanceItem, $gfDanceTime, $gsDancePath

Global $ghHelperHwnd = WinGetHandle( AutoItWinGetTitle(), "")
c ( "Helper handle:" & $ghHelperHwnd )
Global $giHelperPID = WinGetProcess($ghHelperHwnd)
c ( "Helper PID:" & $giHelperPID )
Global $gbMMDProgRunning = False 	; The MMD3 or DME is running?

Global $gsThemeLastModified = ""	; Theme.json last modified time in string.

; Model number and model object data created by json.
; action timer is the timer handle to see last time it did random action, ACTIONTIMELIMIT is how long to wait for the next action.
Global Enum $MODEL_NO, $MODEL_NAME, $MODEL_OBJ, $MODEL_ACTIONTIMER, $MODEL_ACTIONLENGTH, $MODEL_NEXTACTIONTIME, _ 
		$MODEL_X, $MODEL_Y, $MODEL_ZOOM, $MODEL_LINES
Global $giModelDataColumns = 10
Global $gaModels[0][$giModelDataColumns]		; Models loaded in memory.

Global Enum $MODEL_ITEM_HANDLE, $MODEL_ITEM_NAME
Global $gaModelMenuItems[0][2]		; Menu Item Handle and name, first one is always "Model List"
Global $giActiveModelIndex = -1		; -1 means active model is unknown.

; Load all the global data, constants...etc
#include "GlobalData.au3"

; Load forms below
; #include "Forms\Settings.au3"

LoadGlobalSettings()

; The following global data can be multi-lingal, so it's loaded here.
Global Const $gsAboutText = "MMD3 Helper " & $gsVersion & T(", written by Philip Wang.") _
						   &@CRLF& T("Extend the features of the Excellent DesktopMagicEngine, DesktopMMD3 and DesktopMMD4.")

; Run only a single instance
If AlreadyRunning() Then
   MsgBox(48,T("MMD3 Helper is still running."),T("MMD3 Helper is running. Maybe it had an error and froze. ") & @CRLF _
	  & T("You can use the 'task manager' to force-close it.") & @CRLF _
	  & T("Not recommend running two MMD3 Helper at the same time."),0)
   Exit
EndIf

; Get MMD3 or DME Handle and PID
SetHandleAndPID()
; Load other things.
Global $gaBgList, $gaIdleActions, $gaMiscActions
Global $gsLastActionCommand = ""	; To avoid background and effect loading.
LoadBackgroundList()

If Not LoadIdleActions() And $giRandomIdleAction > 0 Then
	MsgBox( 0, "Get the workshop item", "Sorry, but for idle actions to work, you need to subscribe to a workshop item. Click ok and I will open the item's page. " )
	ShellExecute( "https://steamcommunity.com/sharedfiles/filedetails/?id=2808595805" )
EndIf

; If enable random dance and MMD4, get the list of all MMD4 dances.
If $gsControlProg = "MMD4" and $giRandomDanceWithSound = 1 Then
	LoadMMD4Dances()
EndIf

;~ HotKeySet("^{F1}", "ShowArray")
;~ Func ShowArray()
;~ 	_ArrayDisplay($gaModels)
;~ EndFunc

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
; Set the title and title shadow for songs.
Global $lbTitleShadow = GUICtrlCreateLabel( "", 52, 51, 800, 75, -1, -1)
GUICtrlSetColor(-1,"0x000000")
GUICtrlSetFont( -1, 36, 700, 0, "NSimSun")
GUICtrlSetBkColor(-1,"-2")
Global $lbTitle = GUICtrlCreateLabel( "", 50, 50, 800, 75, -1, -1)
GUICtrlSetColor(-1,"0xC0C0C0")
GUICtrlSetFont( -1, 36, 700,0, "NSimSun")
GUICtrlSetBkColor(-1,"-2")
#Region Tray Menu Initialize

Global Const $gsIconPath = @ScriptDir & "\Icons\"
Global $hIcons[10]	; 10(0-9) bmps  for the tray menus
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
Global $traySubCmdStop = TrayCreateItem("Stop Dance and Background", $trayMenuCommands)
Global $traySubCmdShowActive = TrayCreateItem("Show Active Model", $trayMenuCommands)
$iMenuItem += 1

; For Random action when idling
Global $trayMenuIdleAction = TrayCreateMenu("MMD4 Idle Actions") ; $iRandomIdleAction
_TrayMenuAddImage($hIcons[2], $iMenuItem)
; submenu for idle action option
Global $traySubIdleDisable = TrayCreateItem("Disable", $trayMenuIdleAction, -1, $TRAY_ITEM_RADIO )
Global $traySubIdleMisc = TrayCreateItem("Misc Actions", $trayMenuIdleAction, -1, $TRAY_ITEM_RADIO )
Global $traySubIdleIdle = TrayCreateItem("Idle Actions", $trayMenuIdleAction, -1, $TRAY_ITEM_RADIO )
Switch $giRandomIdleAction
	Case 0
		TrayItemSetState($traySubIdleDisable, $TRAY_CHECKED)
	Case 1
		TrayItemSetState($traySubIdleMisc, $TRAY_CHECKED)
	Case 2
		TrayItemSetState($traySubIdleIdle, $TRAY_CHECKED)
EndSwitch
TrayCreateItem("", $trayMenuIdleAction)	; Seperator
Global $traySubIdleActionPath = TrayCreateItem("Specify Idle Action Path", $trayMenuIdleAction)
Global $traySubMenuIdlePeriod = TrayCreateMenu("Idle Action Frequency", $trayMenuIdleAction)
Global $traySubIdleFreqHigh = TrayCreateItem("High", $traySubMenuIdlePeriod, -1, $TRAY_ITEM_RADIO )
Global $traySubIdleFreqMedium = TrayCreateItem("Medium", $traySubMenuIdlePeriod, -1, $TRAY_ITEM_RADIO )
Global $traySubIdleFreqLow = TrayCreateItem("Low", $traySubMenuIdlePeriod, -1, $TRAY_ITEM_RADIO )
Switch $giIdleActionFrequency
	Case 0
		TrayItemSetState( $traySubIdleFreqHigh, $TRAY_CHECKED)
	Case 1
		TrayItemSetState( $traySubIdleFreqMedium, $TRAY_CHECKED)
	Case 2
		TrayItemSetState( $traySubIdleFreqLow, $TRAY_CHECKED)
EndSwitch

$iMenuItem += 1
Global $trayMenuChooseBg = TrayCreateMenu("Choose Background")
_TrayMenuAddImage($hIcons[3], $iMenuItem)
Global $traySubChkDanceBgDisable = TrayCreateItem("Disable Dancing with BG", $trayMenuChooseBg, -1, $TRAY_ITEM_RADIO)
Global $traySubChkRandomBg = TrayCreateItem("Random Background", $trayMenuChooseBg, -1, $TRAY_ITEM_RADIO ) 	; $giDanceRandomBg
; TrayCreateItem("", $trayMenuChooseBg)	; Seperator
Global $traySubBgItems[ $gaBgList[0]+1 ]
$traySubBgItems[0] = $gaBgList[0]	; set the number of bk at [0]. Now $gaBgList and $traySubBgItems are 1 to 1.

If $giDanceRandomBg = 1 Then TrayItemSetState($traySubChkRandomBg, $TRAY_CHECKED)
If $giDanceWithBg = 0 Then TrayItemSetState($traySubChkDanceBgDisable, $TRAY_CHECKED)

; Create the background menu list
For $i = 1 To $gaBgList[0]
	$traySubBgItems[$i] = TrayCreateItem( $gaBgList[$i], $trayMenuChooseBg, -1, $TRAY_ITEM_RADIO )
Next

; Seperator
TrayCreateItem("", $trayMenuChooseBg)
; Open bg folder
Global $traySubOpenBgFolder = TrayCreateItem("Open Background Folders", $trayMenuChooseBg)
Global $traySubGetMoreBg = TrayCreateItem("Get More Backgrounds...", $trayMenuChooseBg)
$iMenuItem += 1

; Bubble text fun !
Global $trayMenuBubbleText = TrayCreateMenu("Bubble Text Interaction")
_TrayMenuAddImage($hIcons[9], $iMenuItem)
Global $traySubBubbleDisable = TrayCreateItem("Disable MidMouse Button Text", $trayMenuBubbleText, -1, $TRAY_ITEM_RADIO)
Global $traySubBubbleGreetings = TrayCreateItem("Random Greetings", $trayMenuBubbleText, -1, $TRAY_ITEM_RADIO)
Global $traySubBubbleQuotes = TrayCreateItem("Random Quotes Online", $trayMenuBubbleText, -1, $TRAY_ITEM_RADIO)
Global $traySubBubbleJokes = TrayCreateItem("Random Jokes Online" , $trayMenuBubbleText, -1, $TRAY_ITEM_RADIO)
; Global $traySubBubbleRandom =  TrayCreateItem("Random Message Random Time", $trayMenuBubbleText, -1, $TRAY_ITEM_RADIO)

Switch $giBubbleText
	Case 0	; disable
		TrayItemSetState($traySubBubbleDisable, $TRAY_CHECKED)
	Case 1	; random greetings
		TrayItemSetState($traySubBubbleGreetings, $TRAY_CHECKED)
	Case 2	; random quotes
		TrayItemSetState($traySubBubbleQuotes, $TRAY_CHECKED)
	Case 3	; random Jokes
		TrayItemSetState($traySubBubbleJokes, $TRAY_CHECKED)
EndSwitch
; 0 disable, 1 random greeting, 2 random quote, 3 random message random time.

$iMenuItem += 1
Global $trayMenuSettings = TrayCreateMenu("Settings")	; If a program play sound, active model random dances.
_TrayMenuAddImage($hIcons[5], $iMenuItem)


; For Random dancing when a program is playing sound
Global $traySubChkDanceWithSound = TrayCreateItem("Dance with a Program's Music/Sound", $trayMenuSettings)	; $giRandomDanceWithSound
if $giRandomDanceWithSound = 1 Then TrayItemSetState($traySubChkDanceWithSound, $TRAY_CHECKED)




; Show background on which screen
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

; Initialize COM usage.
_WinAPI_CoInitialize()

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
				Global $gaModels[0][$giModelDataColumns]
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
				Global $gaModels[0][$giModelDataColumns]
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
				Global $gaModels[0][$giModelDataColumns]
				RefreshModelListMenu()
				If $giRandomDanceWithSound = 1 And UBound($gaMMD4Dances) = 0 Then
					LoadMMD4Dances()
				EndIf
			EndIf

		Case $traySubChkDanceBgDisable
			$giDanceWithBg = 0
			$giCurrentBg = 0
			SaveSettings()
			If $gbDanceExtraPlaying Then StopDanceExtra()
			

		Case $traySubChkDanceWithSound
			; GUI to set the dance with sound
			DanceWithSoundSettings()
			; Set the menu item status according to the new settings.
			If $giRandomDanceWithSound = 1 Then
				TrayItemSetState( $traySubChkDanceWithSound, $TRAY_CHECKED)
			Else
				TrayItemSetState( $traySubChkDanceWithSound, $TRAY_UNCHECKED)
			EndIf
		
		Case $traySubBubbleDisable		; Text disable
			$giBubbleText = 0
			SaveSettings()
		Case $traySubBubbleGreetings	; Random greetings
			$giBubbleText = 1
			SaveSettings()
		Case $traySubBubbleQuotes		; Random quotes
			$giBubbleText = 2
			SaveSettings()
		Case $traySubBubbleJokes		; Random messages at random times
			$giBubbleText = 3
			SaveSettings()
		
		Case $traySubChkRandomBg
			; Enable random background
			$giDanceWithBg = 1
			$giDanceRandomBg = 1
			$giCurrentBg = 0 	; No current bg
			SaveSettings()
			If $gbProgDancePlaying Then 
				; MMD is doing a dance, show the background immediately.
				$gsDanceExtra = "RANDOM"
			EndIf
			
		Case $traySubOpenBgFolder
			; Open the background folder
			ShellExecute( @ScriptDir & "\Backgrounds\" )

		Case $traySubGetMoreBg
			ShellExecute( "https://github.com/philpw99/MMD3_Helper/tree/main/source/Background%20Collection" )

		Case $traySubIdleDisable
			$giRandomIdleAction = 0
			SaveSettings()
		Case $traySubIdleMisc
			$giRandomIdleAction = 1
			If UBound($gaMiscActions) = 0 Then
				If Not LoadIdleActions() Then
					TrayItemSetState( $traySubIdleDisable, $TRAY_CHECKED)
					$giRandomIdleAction = 0
					MsgBox( 0, "Get the workshop item", "Sorry, but for idle actions to work, you need to subscribe to a workshop item. Click ok and I will open the item's page. " )
					ShellExecute( "https://steamcommunity.com/sharedfiles/filedetails/?id=2808595805" )
				EndIf
			EndIf
			SaveSettings()
		Case $traySubIdleIdle
			$giRandomIdleAction = 2
			If UBound($gaIdleActions) = 0 Then
				If Not LoadIdleActions() Then
					TrayItemSetState( $traySubIdleDisable, $TRAY_CHECKED)
					$giRandomIdleAction = 0
					MsgBox( 0, "Get the workshop item", "Sorry, but for idle actions to work, you need to subscribe to a workshop item. Click ok and I will open the item's page. " )
					ShellExecute( "https://steamcommunity.com/sharedfiles/filedetails/?id=2808595805" )
				EndIf
			EndIf
			SaveSettings()
			
		Case $traySubIdleActionPath
			Local $sActionPath = FileSelectFolder("Choose your own idle motion folder", $gsMMD4WorkshopPath)
			If $sActionPath <> "" Then
				$gsMMD4IdleActionPath = $sActionPath
				RegWrite($gsRegBase, "MMD4ActionPath", "REG_SZ", $gsMMD4IdleActionPath)
				LoadIdleActions()
			EndIf
		
		Case $traySubIdleFreqHigh
			$giIdleActionFrequency = 0
			SaveSettings()
		Case $traySubIdleFreqMedium
			$giIdleActionFrequency = 1
			SaveSettings()
		Case $traySubIdleFreqLow
			$giIdleActionFrequency = 2
			SaveSettings()
			
		Case $traySubCmdStop
			StopDance()
		Case $traySubCmdShowActive
			If $giActiveModelIndex <> -1 Then 
				SendCommand( $ghHelperHwnd, $ghMMD, "model" & $gaModels[$giActiveModelIndex][$MODEL_NO] & ".active" )
			EndIf 
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
			$giDanceWithBg = 1
			$giDanceRandomBg = 0
			$giCurrentBg = $i
			If $gbDanceExtraPlaying or $gbProgDancePlaying Then
				; Switch to current bg
				$gsDanceExtra = @ScriptDir & "\Backgrounds\" & $gaBgList[$i] & "\extra.json"
				StartDanceExtra()
				$gsDanceExtra = ""
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

	If $giRandomIdleAction > 0 And $gsControlProg = "MMD4" Then
		; Check to see if a model's VMD is finished
		For $i = 0 to UBound($gaModels)-1
			If  $gaModels[$i][$MODEL_ACTIONLENGTH] <> 0 Then
				; This model is Doing VMD
				Local $iTime = TimerDiff($gaModels[$i][$MODEL_ACTIONTIMER])
				If $iTime > $gaModels[$i][$MODEL_ACTIONLENGTH] Then
					; the VMD is over.
					If (Not $gbProgDancePlaying) And (Not $gbRandomDancePlaying) Then ; If the models are dancing, no need to send stop.
						c( "Sent:" & $gaModels[$i][$MODEL_NO] & ".DanceEnd")
						SendCommand( $ghHelperHwnd, $ghMMD, "model" & $gaModels[$i][$MODEL_NO] & ".DanceEnd" )
					EndIf
					$gaModels[$i][$MODEL_ACTIONLENGTH] = 0  ; Done!
				EndIf
			EndIf
		Next
	EndIf
	
	; Check $gsBubble
	If $gsBubble <> "" Then
		Local $iActiveNo = $gaModels[$giActiveModelIndex][$MODEL_NO]
		Switch $gsBubble
			Case "RandomGreeting"
				BubbleRandomGreeting( $iActiveNo )
			Case "RandomQuote"
				BubbleRandomQuote( $iActiveNo )
			Case "RandomJoke"
				BubbleRandomJoke( $iActiveNo )
			Case Else
				PlayBubble()
		EndSwitch
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
; remove any COM usage.
_WinAPI_CoUninitialize()
Exit

#Region Main Functions
;	Loading other GUIs
#include "Forms\DanceWithSound.au3"

Func LoadGreetings()
	; get the Greetings.json
	Local $sText = FileRead( @ScriptDir & "\Texts\Greetings.json" )
	If @error Then Return SetError( e(1, @ScriptLineNumber) )
	$gaGreetings = Json_Decode($sText)
	If UBound($gaGreetings) = 0 Then Return SetError( e(2, @ScriptLineNumber) )
EndFunc

Func GetModelIndexByNo($iNumber)
	For $i = 0 To UBound($gaModels) -1
		If $iNumber = $gaModels[$i][$MODEL_NO] Then Return $i
	Next
	Return -1	; Not found
EndFunc

Func SetBubble( $sText, $iModelNo, $iTimeOut = 5)
	if $giBubbleText = 0 Then Return 
	; ModelNo should be the "active:model1|*_*|" number
	$gsBubble = $iModelNo & "_" & $iTimeOut & "|" & $sText
	; Now the bubble text is set, it will be played by PlayBubble()
	c( "set bubble text:" & $gsBubble)
EndFunc

Func PlayBubble()
	Local $iPos = StringInStr($gsBubble, "_", 1)
	Local $iModelNo = Int( StringLeft($gsBubble, $iPos-1) )
	Local $sTimeOut = StringBtw($gsBubble, "_", "|" )
	
	Local $iIndex = GetModelIndexByNo($iModelNo)
	If $iIndex = -1 then
		c("error in bubble text:" & $gsBubble)
		$gsBubble = ""
		Return SetError(e(1, @ScriptLineNumber))	; not found
	EndIf
	
	Local $oModel = $gaModels[$iIndex][$MODEL_OBJ]
	; Now reduce the y for the text
	Local $sText = StringAfter( $gsBubble, "|" )
	Local $iLines, $aLines = StringSplit( $sText, @CRLF, $STR_ENTIRESPLIT)
	If $aLines[0] > 0 Then
		$iLines = $aLines[0]
		For $i = 1 to $aLines[0]
			$iLines += Floor( StringLen($aLines[$i]) / 20 )		; long lines will be split, plus crlf
		Next
	Else
		$iLines = Floor( StringLen($aLines[$i]) / 20 ) + 1		; just split the lines
	EndIf
	
	; Save the lines info, in case the model is being moved.
	$gaModels[$iIndex][$MODEL_LINES] = $iLines
	
	Local $aPos = CalcBubblePosition( Number($oModel.Item("x")), Number($oModel.Item("y")), Number($oModel.Item("zoom") ) , $iLines )

	c( "bubble pos x:" & $aPos[0] & " y:" & $aPos[1] & " lines:" & $gaModels[$iIndex][$MODEL_LINES] )
	c( "Say:" & $sText )
	
	RunBubbleExe( $aPos[0], $aPos[1], $sText , "BubbleModel" & $iModelNo, 300, $sTimeOut )
	$gsBubble = ""
EndFunc 

Func RunBubbleExe( $x, $y, $sText, $sTitle, $iWidth = 300, $sTimeOut = "5" )
	Run(@ScriptDir & "\autoit3.exe" & " BubbleText.a3x " & q(_URIEncode($sText)) & " " & q($sTitle) & " " & $x & " " & $y & " " & $iWidth & " " & $sTimeOut )
	; WinActivate($ghMMD)	; Set the focus back
EndFunc

Func _URIEncode($sData)
    ; Prog@ndy
    Local $aData = StringSplit(BinaryToString(StringToBinary($sData,4),1),"")
    Local $nChar
    $sData=""
    For $i = 1 To $aData[0]
        ; ConsoleWrite($aData[$i] & @CRLF)
        $nChar = Asc($aData[$i])
        Switch $nChar
            Case 45, 46, 48 To 57, 65 To 90, 95, 97 To 122, 126
                $sData &= $aData[$i]
            Case 32
                $sData &= "+"
            Case Else
                $sData &= "%" & Hex($nChar,2)
        EndSwitch
    Next
    Return $sData
EndFunc

Func _URIDecode($sData)
    ; Prog@ndy
    Local $aData = StringSplit(StringReplace($sData,"+"," ",0,1),"%")
    $sData = ""
    For $i = 2 To $aData[0]
        $aData[1] &= Chr(Dec(StringLeft($aData[$i],2))) & StringTrimLeft($aData[$i],2)
    Next
    Return BinaryToString(StringToBinary($aData[1],1),4)
EndFunc

Func q($str)
	Return '"' & $str & '"'
EndFunc

Func LoadModelsFromTheme()
	; This will get the model info from theme.json
	Local $sThemeFile 
	If $gsControlProg = "DME" Then 
		$sThemeFile = $gsDMEThemeFile
	ElseIf $gsControlProg = "MMD3" Then
		$sThemeFile = $gsMMD3ThemeFile
	ElseIf $gsControlProg = "MMD4" Then
		$sThemeFile = $gsMMD4ThemeFile
	EndIf
	Local $sLastModified = FileGetTime($sThemeFile, $FT_MODIFIED , $FT_STRING )
	
	If $gbMMDProgRunning Then 
		; MMD program is running
		If ( Not $sLastModified = $gsThemeLastModified ) Or UBound($gaModels) = 0 Then 
			; It was modified or empty before, read the file
			Local $sFileText = FileRead($sThemeFile)
			Local $oData = Json_Decode($sFileText)
			If Not IsObj($oData) Then Return SetError(e(1,@ScriptLineNumber))
			Local $oModels = $oData.Item("model")
			If Not IsObj($oModels) Then Return SetError(e(1,@ScriptLineNumber))
			
			; $aModels is the new array that will replace $gaModels
			Local $i = 0, $aModels[0][$giModelDataColumns]
			For $sModel In $oModels
				; $sModel: model1, model2...
				Local $oModel = $oModels.Item($sModel)
				$i += 1
				ReDim $aModels[$i][$giModelDataColumns]
				Local $iModelNo = Number( StringMid($sModel, 6) )
				
				Local $iSearch = GetModelIndexByNo($iModelNo)
				If $iSearch <> -1 And $gaModels[$iSearch][$MODEL_NAME] = $oModel.Item("name") Then 
					; Same model, different obj data
					$aModels[$i-1][$MODEL_NO] = $iModelNo
					$aModels[$i-1][$MODEL_NAME] = $oModel.Item("name")
					$aModels[$i-1][$MODEL_OBJ] = $oModel
					$aModels[$i-1][$MODEL_ACTIONTIMER] = $gaModels[$iSearch][$MODEL_ACTIONTIMER]
					$aModels[$i-1][$MODEL_ACTIONLENGTH] = $gaModels[$iSearch][$MODEL_ACTIONLENGTH]
					$aModels[$i-1][$MODEL_NEXTACTIONTIME] = $gaModels[$iSearch][$MODEL_NEXTACTIONTIME]
					$aModels[$i-1][$MODEL_X] = Number( $oModel.Item("x") )
					$aModels[$i-1][$MODEL_Y] = Number( $oModel.Item("y") )
					$aModels[$i-1][$MODEL_ZOOM] = Number( $oModel.Item("zoom") )
					$aModels[$i-1][$MODEL_LINES] = $gaModels[$iSearch][$MODEL_LINES]
				Else
					; Not match, just add it.
					$aModels[$i-1][$MODEL_NO] = $iModelNo
					$aModels[$i-1][$MODEL_NAME] = $oModel.Item("name")
					$aModels[$i-1][$MODEL_OBJ] = $oModel
					$aModels[$i-1][$MODEL_ACTIONLENGTH] = 0
					$aModels[$i-1][$MODEL_X] = 0
					$aModels[$i-1][$MODEL_Y] = 0
					$aModels[$i-1][$MODEL_ZOOM] = 1
				EndIf
			Next
			; Done adding all the models from them.json. Set the new array.
			$gaModels = $aModels
			; $giActiveModelIndex = $i
			If UBound($gaModels) > 0 Then RefreshModelListMenu()
		EndIf
	ElseIf UBound($gaModels) <> 0 Then 
		; Not running any more, but the data is still not clear
		ReDim $gaModels[0][$giModelDataColumns]
	EndIf
EndFunc


Func CalcBubblePosition($x, $y, $zoom, $lines = 1)
	; Calculate the position of bubble text
	; Get monitor x and y
	If $gsControlProg = "MMD3" Then 
		$x = -$x
		$zoom = $zoom / 3.5 * 2.5
	ElseIf $gsControlProg = "DME" Then 
		$x = -$x
		$zoom = $zoom / 3.2 * 2.5
	EndIf

	Local $aData = $gaMonitors[$giActiveMonitor][1]
	Local $aRec[4]
	For $j = 1 to 4
		$aRec[$j-1] = DllStructGetData( $aData, $j)
	Next
	
	Local $w = $aRec[2] -$aRec[0], $h = $aRec[3] -$aRec[1]
	
	Local $iScrLeft = $aRec[0], $iScrTop = $aRec[1]
	c( "x:" & $x & " y:" & $y & " w:" & $w & " h:" & $h)
	; Left
	Local $iLeft = $iScrLeft + $w * ( $x / 8.66 + 0.5) - 100
	If $iLeft < $iScrLeft Then 
		; too much on the left
		$iLeft = $iScrLeft + 100
	ElseIf $iLeft + 500 > $aRec[2] Then 
		; Too much on the right
		$iLeft = $aRec[2] - 500
	EndIf
	
	; Top
	Local $iTop = $iScrTop + $h - $y * $h / 5 - $zoom*$h/2.5 - $lines * 40 - 40
	If $gsControlProg = "MMD4" Then $iTop -= 70		; Patch work.

	If $iTop < $iScrTop Then 
		$iTop = $iScrTop + 100
	ElseIf $iTop + 200 > $aRec[3] Then 
		$iTop = $aRec[3] - 400
	EndIf
	
	Local $aPos[2] = [Floor($iLeft), Floor($iTop)]
	return $aPos
EndFunc

Func LoadMMD4Dances()
	; This function will get the list of all MMD4 dances in the local workshop folder
	Global $gsMMD4Dances[0]		; clear the array first.
	Local $sPath = $gsSteamPath & "\steamapps\workshop\content\1968650"
	Local $aFolders = _FileListToArray( $sPath, "*", $FLTA_FOLDERS )
	If @error Then
		c("Error getting MMD4 workshop folder:" & @error)
		Return
	EndIf

	For $i = 1 To UBound($aFolders)-1
		Local $aFiles = _FileListToArray($sPath & "\" & $aFolders[$i] , "*.vmd", $FLTA_FILES, True )
		If @error=4 Then
			ContinueLoop	; File not found.
		ElseIf @error=1 Then
		  c("error in getting a subfolder in MMD4.")
		  ExitLoop
		EndIf
		; One or more files found
		Local $iCount = UBound( $gaMMD4Dances )
		ReDim $gaMMD4Dances[ $iCount+$aFiles[0] ]
		For $j=1 to $aFiles[0]
			$gaMMD4Dances[$iCount+$j-1]=$aFiles[$j]
		Next
	Next
EndFunc


; Get the list of PIDs that have sound playing.
; If no sound, return an empty array.
Func GetAppsPlayingSound()
    Local $pIAudioSessionManager2 = 0
    Local $pIAudioSessionEnumerator = 0
    Local $nSessions = 0


    Local $aApp[0]
    Local $pIAudioSessionControl2 = 0
    Local $oIAudioSessionControl2 = 0
    Local $oIAudioMeterInformation = 0
    Local $iProcessID = 0
    Local $fPeakValue = 0
    Local $iState = 0
    Local $iVolume = 0

    Static $oMMDeviceEnumerator = 0
    Static $pIMMDevice = 0
    Static $oMMDevice = 0
    Static $oIAudioSessionManager2 = 0
	Static $oIAudioSessionEnumerator = 0


	$oMMDeviceEnumerator = ObjCreateInterface($gsCLSID_MMDeviceEnumerator, $gsIID_IMMDeviceEnumerator, $gsTagIMMDeviceEnumerator)
	If @error Then
		c("error in Creating $oMMDeviceEnumerator")
		Return $aApp
	EndIf

	Local $iRet = $oMMDeviceEnumerator.GetDefaultAudioEndpoint($geRender, $geMultimedia, $pIMMDevice)
	If $iRet < 0 Then
	   c("Error in GetDefaultAudioEndpoint")
	   Return $aApp
	EndIf

	$oMMDevice = ObjCreateInterface($pIMMDevice, $gsIID_IMMDevice, $gsTagIMMDevice)
	If @error Then
		c("Error in creating $oMMDevice")
		Return $aApp
	EndIf

	$oMMDevice.Activate($gsIID_IAudioSessionManager2, $CLSCTX_INPROC_SERVER, 0, $pIAudioSessionManager2)
	$oIAudioSessionManager2 = ObjCreateInterface($pIAudioSessionManager2, $gsIID_IAudioSessionManager2, $gsTagIAudioSessionManager2)
	if @error Then
		c("error creating $oIAudioSessionManager2")
		Return $aApp
	EndIf

	$oIAudioSessionManager2.GetSessionEnumerator($pIAudioSessionEnumerator)
	$oIAudioSessionEnumerator = ObjCreateInterface($pIAudioSessionEnumerator, $gsIID_IAudioSessionEnumerator, $gsTagIAudioSessionEnumerator)
	if @error Then
		c("error creating $oIAudioSessionEnumerator")
		Return $aApp
	EndIf

	If Not IsObj( $oIAudioSessionEnumerator ) Then
		c("Error using $oIAudioSessionEnumerator")
		Return $aApp
	EndIf

	$oIAudioSessionEnumerator.GetCount($nSessions)

	For $i = 0 To $nSessions - 1
		$oIAudioSessionEnumerator.GetSession($i, $pIAudioSessionControl2)
		$oIAudioSessionControl2 = ObjCreateInterface($pIAudioSessionControl2, $gsIID_IAudioSessionControl2, $gsTagIAudioSessionControl2)
		$oIAudioSessionControl2.GetState($iState)
		If $iState = $geAudioSessionStateActive Then
			$oIAudioSessionControl2.GetProcessId($iProcessID)
			$oIAudioMeterInformation = ObjCreateInterface($pIAudioSessionControl2, $gsIID_IAudioMeterInformation, $gsTagIAudioMeterInformation)
			$oIAudioSessionControl2.AddRef
			$oIAudioMeterInformation.GetPeakValue($fPeakValue)
			If $fPeakValue > 0 Then
				; Has sound, add it to the list.
				Local $iCount = UBound($aApp)
				ReDim $aApp[$iCount + 1]
				$aApp[$iCount] = $iProcessID	; Add the PID to the array.
			EndIf
		EndIf
		$fPeakValue = 0
		$iState = 0
		$iProcessID = 0
		$oIAudioMeterInformation = 0
		$oIAudioSessionControl2 = 0
	Next

;~ 	$oIAudioSessionEnumerator = 0
;~ 	$oIAudioSessionManager2 = 0
;~ 	$oMMDevice = 0
;~ 	$oMMDeviceEnumerator = 0

;	If UBound($aApp) = 0 Then $aApp = 0
	Return $aApp

EndFunc   ;==> GetAppsPlayingSound

Func T($str)
	; Implement different languages using dictionary
	If $gsLang = "Eng" Then Return $str
	Return $goLang.Item($str)
EndFunc

Func NotDoneYet()
	MsgBox(0, "Not Done Yet", "This feature is not implemented yet. Maybe wait for the next version?" )
EndFunc

Func LoadBackgroundList()
	Global $gaBgList = _FileListToArray( @ScriptDir & "\Backgrounds", "*", $FLTA_FOLDERS )
EndFunc

Func LoadIdleActions()
	; MMD4 idle actions
	If FileExists( $gsMMD4IdleActionPath) Then
		Global $gaMiscActions = _FileListToArray( $gsMMD4IdleActionPath & "\Misc", "*.vmd", $FLTA_FILES)
		Global $gaIdleActions = _FileListToArray( $gsMMD4IdleActionPath & "\Idle", "*.vmd", $FLTA_FILES)
		Return True ; success
	Else
		Return False
	EndIf
EndFunc

Func StartDanceNext()
	; run the next dance extra
	$giDanceItem += 1
	If $giDanceItem >= UBound($gaDanceData) Then
		; It should have been stopped. So here is just in case.
		StopDanceExtra(True)	; fast stop
		Return SetError(e(1,@ScriptLineNumber))
	EndIf

	c( "Playing dance:" & $giDanceItem )
	Local $oDance = $gaDanceData[$giDanceItem]
	If Not IsObj($oDance) Then Return SetError(e(1,@ScriptLineNumber))

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

	If Not FileExists($sEffectFile) Then SetError(e(1,@ScriptLineNumber))

	Local $oEffect = Json_Decode( FileRead( $sEffectFile) ) ; Get the effect settings from file.
	If Not IsObj($oEffect) Then Return SetError(e(2,@ScriptLineNumber))

	; Set effect string
	$oEffect.Item("path") = $sEffectFolder & "\"
	$oEffect.Item("src") = $sEffectFolder & "\" & $oEffect.Item("src")
	Local $sEffectString = "loadEffect:effect:" & Json_Encode( $oEffect )

	; c( "effect to send:" & $sEffectString )
	SendCommand( $ghHelperHwnd, $ghMMD, $sEffectString )
	; For some reason, MMD4 lost the hook after sending the effect
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
	$gaDanceData = Json_Decode( FileRead( $gsDanceExtra ) )	; Should be the extra.json file
	If UBound($gaDanceData) = 0 or Not IsObj($gaDanceData[0]) Then
		c( "error in $gsDanceExtra:" & $gsDanceExtra)
		$gsDanceExtra = ""
		Return SetError(e(1,@ScriptLineNumber))
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
		; c( "Effect to show:" & $sEffect)
		ShowEffect(  $sEffect )
	EndIf
EndFunc


; $sProg can be "MMD3", "MMD3Core","DME" or "DMECore"
; $sMessage is the text they received.
Func ProcessMessage($sProg, $sMessage)
	c( $sProg & ":" & @CRLF & "-----" & @crlf & $sMessage & @CRLF & @CRLF )

	Switch $sProg
		Case "MMD3Core", "DMECore"
			Select 	; Handle the command messages from mmd3core and DMECore.
				Case StringLeft( $sMessage,15) = "loadModel:model"
					; No more tracking the models here. Model tracking by using theme.json
					; Load a new model.
					; Local $iModelNo = Int( StringBtw( $sMessage, "loadModel:model", ":{" ) )
					; Local $sJson = "{" & StringBtw( $sMessage, "{", "" )
					; c( "json to decode:" & $sJson)
					; AddModel( $iModelNo, $sJson )
				Case StringInStr($sMessage, ".DanceReady", 1) <> 0
					$gbProgDancePlaying = True		; Prog MMD is playing a dance
					If $giDanceWithBg = 1 Then
						; Time to start a dance. Check if Extra.json exist.
						Local $sPath = GetFolderFromPath( StringAfter($sMessage, "|") )
						$goDanceSong = Json_Decode( FileRead( $sPath & "\item.json") )
						If FileExists( $sPath & "\extra.json" ) Then ; The one with specified background/effects takes the priority
							$gsDanceExtra = $sPath & "\extra.json"  ; Once $gsDanceExtra is set. It will be processed by the main loop.
						ElseIf $giDanceWithBg = 1 Then
							$gsDanceExtra = "RANDOM"		; Start random background / effect
						EndIf
					EndIf

				Case StringInStr($sMessage, "DanceEnd", 1) <> 0
					c("Dance stop")
					$gbProgDancePlaying = False
					If $gbDanceExtraPlaying Then $gsDanceExtra = "STOP"
					$goDanceSong = ""

				Case $sMessage = "mouseMidClick"
					; Say the greeting.
					If $giActiveModelIndex <> -1 And Not $gbDanceExtraPlaying And Not $gbProgDancePlaying Then
						Local $sBubbleTitle = "BubbleModel" & $gaModels[$giActiveModelIndex][$MODEL_NO]
						Local $hBubble = WinGetHandle($sBubbleTitle, "")
						If @error Then ; Not found, so create a new bubble.
							Switch $giBubbleText
								Case 1
									$gsBubble = "RandomGreeting"
								Case 2
									$gsBubble = "RandomQuote"
								Case 3
									$gsBubble = "RandomJoke"
							EndSwitch
						EndIf 
					EndIf 
			EndSelect
		Case "MMD4Core"
			Select 	; Handle the command messages from mmd4core.
				Case StringLeft( $sMessage,15) = "loadModel:model"
					; No more tracking the models here. Model tracking by using theme.json
					; Load a new model.
 					; Local $iModelNo = Int( StringBtw( $sMessage, "loadModel:model", ":{" ) )
					; Local $sJson = "{" & StringBtw( $sMessage, "{", "" )
					; c( "json to decode:" & $sJson)
					; AddModel( $iModelNo, $sJson )

				Case StringInStr($sMessage, ".DanceReadyAll", 1) <> 0
					$gbProgDancePlaying = True		; Prog MMD is playing a dance
					If $giDanceWithBg = 1 Then
						; Time to start a dance. Check if Extra.json exist.
						Local $sPath = GetFolderFromPath( StringAfter($sMessage, "|") )
						; Set the global object of current song.
						$goDanceSong = Json_Decode( FileRead( $sPath & "\item.json") )
						If FileExists( $sPath & "\extra.json" ) Then ; The one with specified background/effects takes the priority
							$gsDanceExtra = $sPath & "\extra.json"  ; Once $gsDanceExtra is set. It will be processed by the main loop.
						ElseIf $giDanceWithBg = 1 Then
							$gsDanceExtra = "RANDOM"		; Start random background / effect
						EndIf
					EndIf

				Case StringInStr($sMessage, "DanceEnd", 1) <> 0
					; c("Dance stop")
					If $gbProgDancePlaying Then
						; Reset all the models for random moves, only for MMD4
						If $giRandomIdleAction > 0 Then
							Local $iCount = UBound($gaModels)
							If $iCount > 0 Then
								For $i = 0 to $iCount -1
									; Reset all their timers.
									$gaModels[$i][$MODEL_ACTIONTIMER] = TimerInit()
								Next
							EndIf
						EndIf
						$gbProgDancePlaying = False
						
					EndIf
					If $gbDanceExtraPlaying Then $gsDanceExtra = "STOP"
					$goDanceSong = ""
				
				Case $sMessage = "mouseMidClick"
					; Say the greeting.
					If $giActiveModelIndex <> -1 And Not $gbDanceExtraPlaying And Not $gbProgDancePlaying Then
						Local $sBubbleTitle = "BubbleModel" & $gaModels[$giActiveModelIndex][$MODEL_NO]
						Local $hBubble = WinGetHandle($sBubbleTitle, "")
						If @error Then ; Not found, so create a new bubble.
							Switch $giBubbleText
								Case 1
									$gsBubble = "RandomGreeting"
								Case 2
									$gsBubble = "RandomQuote"
								Case 3
									$gsBubble = "RandomJoke"
							EndSwitch
						EndIf 
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
				Case StringStartsWith($sMessage, "properties:model")
					; Set properties for a model
					SetModelProperty($sMessage)
					; no matter x,y,zoom change. bubble text need to move
					Local $iModelNo = Int( StringBtw($sMessage, "model", ".") )
					Local $hBubble = WinGetHandle("BubbleModel" & $iModelNo)
					If Not @error Then 
						Local $iIndex = GetModelIndexByNo($iModelNo)
						If $iIndex <> -1 Then
							Local $iTextLines = $gaModels[$iIndex][$MODEL_LINES]
							c("TextLines:" & $iTextLines )
							Local $aPos = CalcBubblePosition( $gaModels[$iIndex][$MODEL_X], $gaModels[$iIndex][$MODEL_Y], _ 
										$gaModels[$iIndex][$MODEL_ZOOM], $iTextLines )
							WinMove($hBubble, "", $aPos[0], $aPos[1])
						EndIf
					EndIf
			EndSelect

	EndSwitch

EndFunc

Func BubbleRandomGreeting($iModelNo)
	If UBound($gaGreetings) = 0 Then 
		LoadGreetings()
		If @error Then Return ; Error
	EndIf
	Local $iCount = UBound($gaGreetings)
	Local $bWorks = False 
	
	Local $sPeriod
	Select
		Case @HOUR > 5 and @HOUR < 12
			$sPeriod = "Morning"
		Case @HOUR > 11 and @HOUR < 18
			$sPeriod = "Afternoon"
		Case @HOUR > 17
			$sPeriod = "Night"
	EndSelect
	
	Do 
		Local $oGreeting = $gaGreetings[Random(0, $iCount-1, 1)]
		If $oGreeting.Item("Period") = "All" Or $oGreeting.Item("Period") = $sPeriod Then $bWorks = True 
		If $oGreeting.Item("Date") = "All" Or $oGreeting.Item("Date") = @MON & "/" & @MDAY Then
			$bWorks = $bWorks And True
		Else
			$bWorks = False
		EndIf
	Until $bWorks
	; Now say the greeting
	SetBubble($oGreeting.Item("Say"), $iModelNo, $oGreeting.Item("TimeOut") )
EndFunc

Func BubbleRandomQuote($iModelNo)
	Local $bText = InetRead("https://api.quotable.io/random", $INET_IGNORESSL )
	If @error Then
		c("error getting quote online")
		Return
	EndIf
	Local $sText = BinaryToString($bText)
	; c( "text return:" & $sText)
	Local $oQuote = Json_Decode($sText)
	If Not IsObj($oQuote) Then
		c("$oQuote is not an object")
		Return ; Error
	EndIf
	$sText = $oQuote.Item("content") & @CRLF & " -- " & $oQuote.Item("author")
	c("$sText:" & $sText)
	Local $iReadTime = 2 * ( Floor(StringLen($sText) / 20) + 1 )
	c("time:" & $iReadTime)
	SetBubble($sText, $iModelNo, $iReadTime)
EndFunc

Func BubbleRandomJoke($iModelNo)
	Local Const $HTTP_STATUS_OK = 200
	;;Instantiate a WinHttpRequest object
	Local $WinHttpReq = ObjCreate("winhttp.winhttprequest.5.1")
	Local $id = Random( 0, 309, 1)	; random range
	Local $url = "https://jokeapi-v2.p.rapidapi.com/joke/Any?format=json&idRange=" & $id & "-" & String($id+10) & "&blacklistFlags=racist"
	$WinHttpReq.Open("GET", $url, false)
	if @error Then Return SetError( e(1, @ScriptLineNumber) )
	
	$WinHttpReq.SetRequestHeader( "Content-Type", "application/json")
	$WinHttpReq.SetRequestHeader( "X-Rapidapi-Host", "jokeapi-v2.p.rapidapi.com" )
	$WinHttpReq.SetRequestHeader( "X-RapidAPI-Key", "2f3b011dc6msh8f16a2e0b3970a8p15ab50jsna154630ffcba")

	;;Initialize an HTTP request.
	$WinHttpReq.send()
	if @error Then Return SetError( e(2, @ScriptLineNumber) )
	   
	;;Get all response headers
	If $WinHttpReq.Status <> $HTTP_STATUS_OK Then
	  c( "Error with http status:" & $WinHttpReq.Status)
	  return SetError( e( 3, @ScriptLineNumber) )
	EndIf
	
	Local $sText = $WinHttpReq.ResponseText
	Local $oJoke = Json_Decode( $sText )
	If Not IsObj($oJoke) Then Return SetError( e(3, @ScriptLineNumber))
	
	If $oJoke.Item("type") = "twopart" Then 
		$sText = $oJoke.Item("setup") & @CRLF & @CRLF & $oJoke.Item("delivery")
	Else 
		$sText = $oJoke.Item("joke")
	EndIf
	Local $iReadTime = 2 * ( Floor(StringLen($sText) / 20) + 1 )
	SetBubble($sText, $iModelNo, $iReadTime)
EndFunc

Func SetModelProperty( $sMessage)
	Local $iModelNo = Int( StringBtw( $sMessage, "model", "." ) )
	If $iModelNo = 0 Then Return  ; Error
	Local $sText = StringBtw($sMessage, ".", "|")
	Local $oModel = Json_Decode($sText)
	If Not IsObj($oModel) Then Return ; Error
	Local $iIndex = GetModelIndexByNo($iModelNo)
	If $iIndex = -1 Then Return ; Error
	If $oModel.Item("x") Then 
		$gaModels[$iIndex][$MODEL_X] = Number( $oModel.Item("x") )
		c( "Set model x :" & $gaModels[$iIndex][$MODEL_X])
	EndIf
	If $oModel.Item("y") Then 
		$gaModels[$iIndex][$MODEL_Y] = Number( $oModel.Item("y") )
		c( "Set model y :" & $gaModels[$iIndex][$MODEL_Y])
	EndIf
	If $oModel.Item("zoom") Then
		$gaModels[$iIndex][$MODEL_ZOOM] = Number( $oModel.Item("zoom") )
		c( "Set model zoom :" & $gaModels[$iIndex][$MODEL_ZOOM])
	EndIf
EndFunc

Func GetModelNoFromMsg( $sMessage, $delimiter )
	; It will return the 1 from like "xxxx:model1."
	Local $iPos = StringInStr($sMessage, "model", 1) + 5
	If $iPos = 5 Then Return 0; Error, "model" not found 
	Local $iPos2 = StringInStr($sMessage, $Delimiter, 1, 1, $iPos + 5)
	If $iPos2 = 0 Then Return 0; Error
	Return Number( StringMid($sMessage, $iPos, $iPos2-$iPos) )
EndFunc


Func StringAfter( $String, $Delimiter)
	Local $iPos = StringInStr( $String, $Delimiter, 2)
	If $iPos = 0 Then return ""
	Return StringMid($String, $iPos + 1)
EndFunc

Func RemoveModelFromMessage($iNumber)
	; A model was removed by mmd3 or mmd4 or dme
	Local $iCount = UBound($gaModels)
	If $iCount = 0 Then
		$giActiveModelIndex = -1
		Return  ; no data anyway
	EndIf

	Local $iIndex = GetModelIndexByNo($iNumber)
	If $iIndex <> -1 Then
		; Found the model to delete. number is $iIndex
		If $iIndex = 0 Then
			; First in the list
			If $iCount = 1 Then
				; Last model to be removed
				$giActiveModelIndex = -1
			Else
				$giActiveModelIndex = 0 ; Next model's index is also 0
			EndIf
		ElseIf $iIndex = $iCount-1 Then ; Last model
			$giActiveModelIndex = $iIndex-1
		Else
			$giActiveModelIndex = $iIndex	; Next model's index is the same
		EndIf
		_ArrayDelete($gaModels, $iIndex)
		; Set the items again.
		If $giActiveModelIndex = -1 Then 
			TrayItemSetText($trayMenuModels, "Active Model: None")
		Else
			TrayItemSetText($trayMenuModels, "Active Model: " & $gaModels[$giActiveModelIndex][$MODEL_NAME]) 
		EndIf 
		RefreshModelListMenu()
	Else
		; Not found. Do nothing.
	EndIf
EndFunc


Func SetActiveModelFromMessage($iNumber)
	c( "Set active:" & $iNumber & " current index:" & $giActiveModelIndex)
	If Not IsInt($iNumber) Then
		c("set active model not an int.")
		Return 
	EndIf
	; If $iNumber = $giActiveModelIndex Then Return
	Local $iCount = UBound($gaModels)
	Local $sName
	If $iCount = 0 Then
		; No models loaded. Maybe just give it some time.
		; Sleep(100)
		; AddModel($iNumber)
		LoadModelsFromTheme()
	EndIf
	
	Local $iIndex = GetModelIndexByNo( $iNumber )
	If $iIndex = -1 Then 
		; Error, number not in the model list
		$giActiveModelIndex = -1
		TrayItemSetText($trayMenuModels, "Active Model: None")
		Return 
	EndIf
	
	$giActiveModelIndex = $iIndex
	c( "Set new active model index:" & $giActiveModelIndex)
	TrayItemSetText($trayMenuModels, "Active Model: " & $gaModels[$giActiveModelIndex][$MODEL_NAME] )
	RefreshModelListMenu()
EndFunc

Func SetActiveModelFromMenu($iNumber)
	; No, you cannot set active model from the menu.
	; So it will only wave at you, nothing more.
	If Not IsInt($iNumber) Then Return SetError(e(1,@ScriptLineNumber))
	; $giActiveModelIndex = $iNumber
	SendCommand( $ghHelperHwnd, $ghMMD, "model" & $iNumber & ".active" )
EndFunc


Func AddModel($Number, $sJson = "")
	; Add a model to the list by simply a number, or a Json string for more detail
	Local $iCount = UBound($gaModels)
	ReDim $gaModels[$iCount + 1][$giModelDataColumns]
	$gaModels[$iCount][$MODEL_NO] = $Number
	If $sJson <> "" Then
		$gaModels[$iCount][$MODEL_OBJ] = Json_Decode($sJson)
		if @error Then c("Json decode error. Error:" & @error)
		$gaModels[$iCount][$MODEL_NAME] = $gaModels[$iCount][$MODEL_OBJ].Item("name")
	Else
		$gaModels[$iCount][$MODEL_NAME] = "Model " & $Number
	EndIf
	$giActiveModelIndex = $Number	; The new model will become the active one.
	$gaModels[$iCount][$MODEL_ACTIONLENGTH] = 0
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
			If $i = $giActiveModelIndex Then									; If the active model number matches
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
	If $iPos1 = 0 Then Return SetError(e(1,@ScriptLineNumber))	; $str1 Not found
	$iPos1 += StringLen($str1)
	If $str2 = "" Then
		$iPos2 = StringLen($sFull)
	Else
		$iPos2 = StringinStr( $sFull, $str2, $case, 1, $iPos1 )
		If $iPos2 = 0 Then Return SetError(e(2,@ScriptLineNumber)) ; $str2 not found
	EndIf
	Return StringMid( $sFull, $iPos1, $iPos2-$iPos1+1 )
EndFunc

Func LoadLanguage()
	If $gsLang = "Eng" Then Return
	$goLang = ObjCreate('Scripting.Dictionary')
	Local $hFile = FileOpen(@ScriptDir & "\Languages\" & $gsLang & ".txt")
	If @error Then Return SetError(e(1,@ScriptLineNumber))

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
	$gsControlProg = "MMD4"
	$giActiveMonitor = 1
	$giDanceWithBg = 0		; 0 : disable , 1: enable.
	$giDanceRandomBg = 0
	$giRandomDanceWithSound = 0
	$gsSoundMonitorProg = "vlc.exe"
	$giRandomIdleAction = 0		; 0 disable, 1 misc actions, 2 idle actions
	$giIdleActionFrequency = 1	; 0 high, 1 medium, 2 low
	$giBubbleText = 0 	; 0 disable, 1 enable
EndFunc

Func SaveSettings()
	RegWrite( $gsRegBase, "ControlProgram", "REG_SZ", $gsControlProg )
	RegWrite( $gsRegBase, "Language", "REG_SZ", $gsLang )
	RegWrite( $gsRegBase, "ActiveMonitor", "REG_DWORD", $giActiveMonitor )
	RegWrite( $gsRegBase, "DanceWithBackground", "REG_DWORD", $giDanceWithBg )
	RegWrite( $gsRegBase, "DanceRandomBackground", "REG_DWORD", $giDanceRandomBg )
	RegWrite( $gsRegBase, "RandomDanceWithSound", "REG_DWORD", $giRandomDanceWithSound )
	RegWrite( $gsRegBase, "SoundMonitorProgram", "REG_SZ", $gsSoundMonitorProg )
	RegWrite( $gsRegBase, "MMD4IdleAction", "REG_DWORD", $giRandomIdleAction )
	RegWrite( $gsRegBase, "IdleActionFrequency", "REG_DWORD", $giIdleActionFrequency )
	RegWrite( $gsRegBase, "BubbleText", "REG_DWORD", $giBubbleText)
EndFunc

Func LoadGlobalSettings()
	; return: Load successful  true/false
	Local $bAllOK = True 
	$gsControlProg = RegRead($gsRegBase, "ControlProgram") ; "MMD3" or "DME"
	If @error Then 
		$gsControlProg = "MMD4"
		$bAllOK = False
	EndIf
	$gsLang = RegRead($gsRegBase, "Language")	; Eng or Chs or Cht
	If @error Then 
		$gsLang = "Eng"
		$bAllOK = False
	EndIf
	If $gsLang <> "Eng" Then LoadLanguage()

	$giActiveMonitor = RegRead($gsRegBase, "ActiveMonitor")
	If @error Then
		$giActiveMonitor = 1
		$bAllOK = False
	EndIf
	$giDanceWithBg = RegRead($gsRegBase, "DanceWithBackground")
	If @error Then 
		$giDanceWithBg = 0
		$bAllOK = False
	EndIf
	$giDanceRandomBg = RegRead($gsRegBase, "DanceRandomBackground")
	If @error Then
		$bAllOK = False
		$giDanceRandomBg = 0
	EndIf
	$giRandomDanceWithSound = RegRead($gsRegBase, "RandomDanceWithSound")
	If @error Then 
		$bAllOK = False
		$giRandomDanceWithSound = 0
	EndIf
	$gsSoundMonitorProg = RegRead($gsRegBase, "SoundMonitorProgram")
	If @error Then
		$bAllOK = False
		$gsSoundMonitorProg = "VLC.exe"
	EndIf
	$giRandomIdleAction = RegRead($gsRegBase, "MMD4IdleAction")
	If @error Then
		$bAllOK = False
		$giRandomIdleAction = 0
	EndIf
	
	Local $sActionPath = RegRead($gsRegBase, "MMD4ActionPath")
	If Not @error And $sActionPath <> "" Then 
		; It already have a default global value, but it can also specify here.
		$gsMMD4IdleActionPath = $sActionPath
	EndIf
	
	$giIdleActionFrequency = RegRead($gsRegBase, "IdleActionFrequency")
	If @error Then 
		$bAllOK = False 
		$giIdleActionFrequency = 1 	; Medium frequency
	EndIf
	
	$giBubbleText = RegRead($gsRegBase, "BubbleText")
	If @error Then 
		$bAllOK = False 
		$giBubbleText = 0
	EndIf
	
	If Not $bAllOK Then SaveSettings()
EndFunc

; This function returns the proper dimension for picBackground
Func CalcBackgroundPos($iX, $iY)
	Local $fRatio = $iX / $iY
	Local $iScreenX = $gaWorkRect[$MON_WIDTH], $iScreenY = $gaWorkRect[$MON_HEIGHT]
	Local $fPicScale = $iScreenX / $iX
	Local $iOutX, $iOutY = Floor( $iY * $fPicScale )
	Local $iLeft = 0, $iTop = 0
	If $iOutY > $iScreenY Then
		; Height is too much. This is a possible portrait picture
		If ($iScreenX - $iScreenY*$fRatio) < ($iScreenX / 3) Then
			; The left space is less than 1/6 of whole screen. So set it full screen
			$iOutX = $iScreenX
		Else
			; Portrait picture.
			$iOutX = Floor( $iScreenY * $fRatio )
			$iLeft = Floor( ($iScreenX - $iOutX) / 2 )
			$iOutY = $iScreenY
		EndIf
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
	; if @error Then Return SetError(e(1,@ScriptLineNumber))

	; Local $aSize = CalcBackgroundPos($aDim[0], $aDim[1])

	; Now set the position of pic control, GUI should have set on the full work area.
	; GUICtrlSetPos($picBackground, $aSize[0], $aSize[1], $aSize[2], $aSize[3])
	; GUICtrlSetImage( $picBackground, $sBgFile )

	_GUICtrlStatic_SetPicture($picBackground, $sBgFile)
	If @error Then Return SetError(e(1,@ScriptLineNumber))

	$gbBackgroundOn = True
	; Set the dancer to the front.
	WinActivate($ghMMD)

EndFunc

; This function fade in and show the background. Change guiDummy to visible
Func ShowBackground( $sBgFile )
	; Local $aDim = GetJpegDimension($sBgFile)
	; If @error Then Return SetError(e(1,@ScriptLineNumber))
	; Create it again to get the dimension of the picture
	;c( "picture size: " & $aDim[0] & "x" & $aDim[1] )
	;Local $aSize = CalcBackgroundPos($aDim[0], $aDim[1])

	; c( "BackgroundRect:" & $aSize[0] & ", " & $aSize[1] & ", " & $aSize[2] & ", " & $aSize[3] )
	; Now set the position of pic control, GUI should have set on the full work area.
	; GUICtrlSetPos($picBackground, $aSize[0], $aSize[1], $aSize[2], $aSize[3])
	; GUICtrlSetImage( $picBackground, $sBgFile )

	_GUICtrlStatic_SetPicture($picBackground, $sBgFile)
	If @error Then Return SetError(e(1,@ScriptLineNumber))
	
	; Set the title if available
	If IsObj($goDanceSong) Then 
		GUICtrlSetData( $lbTitleShadow, $goDanceSong.Item("name") )
		GUICtrlSetData( $lbTitle, $goDanceSong.Item("name") )
	EndIf
	
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
	GUICtrlSetData( $lbTitleShadow, "" )
	GUICtrlSetData( $lbTitle, "" )
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
	If $gbMMDProgRunning Then
		TraySetIcon("Icons\trayActive.ico")
		_TrayMenuAddImage($hIcons[7], 2)
	Else
		TraySetIcon("Icons\trayInactive.ico")
		_TrayMenuAddImage($hIcons[8], 2)
	EndIf
	TraySetToolTip( TrayStatus() )
EndFunc

Func TrayStatus()
	Return "Status: " & $gsControlProg & ( $gbMMDProgRunning ? " is active." : " is not active.")
EndFunc

Func SetHandleAndPID()
	; It will check if the control program is running and set the Hwnd and PID
	Local $iPID
	Switch $gsControlProg
		Case "MMD3"
			$ghMMD = WinGetHandle( "DMMDCore3", "")
			If @error Then
				$gbMMDProgRunning = False
			Else
				$gbMMDProgRunning = True
				$iPID = WinGetProcess("DesktopMMD3", "")
				If $iPID <> $giProgPID Then
					$giProgPID = $iPID
					c ( "MMD3Core hwnd:" & $ghMMD & " MMD3 PID:" & $giProgPID )
				EndIf
			EndIf
		Case "DME"
			$ghMMD = WinGetHandle( "[REGEXPTITLE:DMMDCore$]", "")
			If @error Then ; Program is not running
				$gbMMDProgRunning = False
			Else
				$gbMMDProgRunning = True
				$iPID = WinGetProcess( "DesktopMagicEngine", "")
				If $iPID <> $giProgPID Then
					$giProgPID = $iPID
					c ( "DMEcore hwnd:" & $ghMMD & " DME PID:" & $giProgPID )
				EndIf
			EndIf
		Case "MMD4"
			$ghMMD = WinGetHandle( "DMMD4Core", "")
			If @error Then ; Program is not running
				$gbMMDProgRunning = False
			Else
				$gbMMDProgRunning = True
				$iPID = WinGetProcess( "DesktopMMD4", "")
				If $iPID <> $giProgPID Then
					$giProgPID = $iPID
					c ( "MMD4Core hwnd:" & $ghMMD & " MMD4 PID:" & $giProgPID )
				EndIf
			EndIf
	EndSwitch
 	Return $gbMMDProgRunning
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
	; c( "MMDCore Hwnd:" & $ghMMD & "  MMD Prog PID:" & $giProgPID )
	CheckStatus()			; Set the status text.
	If $giRandomDanceWithSound = 1 And (Not $gbProgDancePlaying) And $gbMMDProgRunning Then
		MonitorProgSound()
	EndIf

	If $giRandomIdleAction > 0 And (Not $gbRandomDancePlaying) And (Not $gbProgDancePlaying) And UBound($gaModels) > 0 And $gbMMDProgRunning Then
		MMD4RandomAction()
	EndIf
	
	If $gbMMDProgRunning Then 
		LoadModelsFromTheme()
	ElseIf UBound($gaModels) > 0 Then 
		; MMD is not running, so clean up the data
		ReDim $gaModels[0][$giModelDataColumns]
	EndIf
EndFunc

Func MMD4RandomAction()
	; This is for MMD4 only
	Local $sActionFile, $iNewTime
	If $gsControlProg <> "MMD4" Then Return
	If UBound($gaMiscActions) = 0 Then
		If Not LoadIdleActions() Then Return
	EndIf
	; Now check each model and see if their idle is due
	For $i = 0 to UBound( $gaModels )-1
		If ModelTimeUp($i) Then
			; New random action
			c("Times up for model " & $i & " gbProgDancePlaying:" & $gbProgDancePlaying)
			If $giRandomIdleAction = 1 Then
				$sActionFile = "\Misc\"
				$sActionFile &= $gaMiscActions[Random(1, $gaMiscActions[0], 1)]
			ElseIf $giRandomIdleAction = 2 Then
				$sActionFile = "\Idle\"
				$sActionFile &= $gaIdleActions[Random(1, $gaIdleActions[0], 1)]
			EndIf
			; Set new time interval
			Switch $giIdleActionFrequency
				Case 0	; high
					$iNewTime = Floor( Random( 5, 10) * 1000 ) ; between 1,000 and 5,000
				Case 1	; medium
					$iNewTime = Floor( Random( 10, 20) * 1000 ) ; between 5,000 and 15,000
				Case 2	; Low
					$iNewTime = Floor( Random( 20, 30) * 1000 ) ; between 15,000 and 30,000
			EndSwitch
			$gaModels[$i][$MODEL_ACTIONTIMER] = TimerInit()

			; Get the length of vmd play time.
			Local $iFrames = GetVMDFrameCount($gsMMD4IdleActionPath & $sActionFile)
			Local $iVMDTime = Floor( $iFrames * 33.33 ) + 100	 ; Convert to total milliseconds, plus 0.1 second.
			$gaModels[$i][$MODEL_ACTIONLENGTH] = $iVMDTime
			$gaModels[$i][$MODEL_NEXTACTIONTIME] = $iNewTime + $iVMDTime

			StartAction("model" & $gaModels[$i][$MODEL_NO], $gsMMD4IdleActionPath & $sActionFile)
			c("action time:" & $gaModels[$i][$MODEL_ACTIONLENGTH] &  " Next action time:" & $gaModels[$i][$MODEL_NEXTACTIONTIME] )
		EndIf
	Next
EndFunc

Func StartAction($sModel, $sVMDFile)
	; First: loop, Second: Disable IK, Third: EC
	; Somehow the third one need to be 0 to play.
	Local $sFirst = "0", $sSecond = "1", $sThird = "0"
	; Local $sCommand = $sFirst & "_" & $sSecond & "_" & $sThird & "|" & $sVMDFile

	; $gsLastActionCommand = $sModel & ".DanceReady:" & $sCommand
	$gsLastActionCommand = $sModel & ".testDance:" & $sVMDFile		; Test dance seems easier.
	c( "Action to MMD:" & $gsLastActionCommand)
	SendCommand($ghHelperHwnd, $ghMMD, $gsLastActionCommand)
	Sleep(100)
	; SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceStart:0") ; 0 means only 1 model dancing.
EndFunc

Func GetVMDFrameCount($sVMDFile)
	; Get the total frame count in a VMD file.
	; Too lazy to get the last frame number, use the one in file name instead.
	Local $iPos = StringInStr($sVMDFile, "_", 1, -1)
	Return StringMid($sVMDFile, $iPos+1, StringLen($sVMDFile)-$iPos-4 )
EndFunc

Func ModelTimeUp($iModelNo)
	Local $hTimer = $gaModels[$iModelNo][$MODEL_ACTIONTIMER]
	If Not $hTimer Then Return True
	Local $iTime = TimerDiff($hTimer)
	If $iTime > $gaModels[$iModelNo][$MODEL_NEXTACTIONTIME] Then Return True
	Return False
EndFunc

Func MonitorProgSound()
	; Global $gbRandomDancePlaying
	; Global $giRandomDanceTimeLimit, $ghRandomDanceTimer

	; Get the array of PIDs that's playing sound.
	Local $aApps = GetAppsPlayingSound()
	If UBound($aApps) = 0 Then
		; No music is playing at all.
		If $gbRandomDancePlaying Then
			$gbRandomDancePlaying = False
			; Stop the background and effect
			StopDance()
		EndIf
	Else
		; Some sound is playing.
		Local $iPID = ProcessExists($gsSoundMonitorProg)
		If $iPID = 0 Then
			; Monitored prog is not running.
			If $gbRandomDancePlaying Then
				$gbRandomDancePlaying = False
				; Stop the background and effect
				StopDance()
			EndIf
		Else
			; Monitored prog is running.
			Local $iCount = UBound($aApps)
			For $i = 0 to $iCount -1
				Local $sProcessName = _ProcessGetName ( $aApps[$i] )
				If $sProcessName = $gsSoundMonitorProg Then
					; The prog is playing sound.
					If Not $gbRandomDancePlaying Then
						$gbRandomDancePlaying = True
						StartRandomDancing()
					Else
						; Check to see if the current one expire
						If $giRandomDanceTimeLimit < TimerDiff($ghRandomDanceTimer) Then
							; Current one expire, start a new random dance.
							StartRandomDancing()
						EndIf
					EndIf
				Else
					; The prog is not playing sound.
					If $gbRandomDancePlaying Then
						$gbRandomDancePlaying = False
						StopDance()
					EndIf

				EndIf
			Next
		EndIf
	EndIf

EndFunc

Func StartRandomDancing()
	; Global $giRandomDanceTimeLimit, $ghRandomDanceTimer
	$gbRandomDancePlaying = True
	Switch $gsControlProg

		Case "MMD4"
			Local $iCount = UBound($gaMMD4Dances)
			If $iCount = 0 Then
				LoadMMD4Dances()	; Just in case
				$iCount = UBound($gaMMD4Dances)
			EndIf

			If $gbRandomDancePlaying Then
				; Stop the previous random dance.
				SendCommand( $ghHelperHwnd, $ghMMD, "DanceEnd")
			EndIf
			; Randomly choose a dance.
			Local $sDanceFile = $gaMMD4Dances[Random(0, $iCount-1, 1)]
			c("start random dance:" & $sDanceFile)
			StartDance($sDanceFile)

		Case "MMD3"
			Local $iCount = UBound($gaMMD3Dances)
			Local $sDance = $gaMMD3Dances[ Random(0, $iCount-1, 1) ]
			Local $sModel
			If UBound($gaModels = 0) Then
				; No model detected yet.
				$sModel = "model1"
			Else
				$sModel = "model" & $giActiveModelIndex
			EndIf

			if $gbRandomDancePlaying Then
				; Stope the previous random dance
				SendCommand( $ghHelperHwnd, $ghMMD, $sModel & ".DanceEnd:1")
			EndIf

			SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceReadyAll:0_0|" & $sDance )
			Sleep(100)

			; Each random dance will last 60 seconds
			$giRandomDanceTimeLimit = 60000
			$ghRandomDanceTimer = TimerInit()

			SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceStart:1" )

		Case "DME"
			Local $iCount = UBound($gaDMEDances)
			Local $sDance = $gaDMEDances[ Random(0, $iCount-1, 1) ]
			Local $sModel
			If UBound($gaModels = 0) Then
				; No model detected yet.
				$sModel = "model1"
			Else
				$sModel = "model" & $giActiveModelIndex
			EndIf

			if $gbRandomDancePlaying Then
				; Stope the previous random dance
				SendCommand( $ghHelperHwnd, $ghMMD, $sModel & ".DanceEnd:1")
			EndIf

			SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceReadyAll:0_0|" & $sDance )
			Sleep(100)

			; Each random dance will last 60 seconds
			$giRandomDanceTimeLimit = 60000
			$ghRandomDanceTimer = TimerInit()

			SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceStart:1" )
	EndSwitch

EndFunc

Func StartDance($sDanceFile)
	; Launch a dance with a dance file. This cannot be used for built-in.
	; The dance file needs to be full path
	Switch $gsControlProg
		Case "MMD4"
			; Get the info about a dance.
			c("file:" & GetFolderFromPath($sDanceFile) & "\item.json")
			Local $sInfo = FileRead( GetFolderFromPath($sDanceFile) & "\item.json")
			if @error Then Return SetError(e(1,@ScriptLineNumber))
			Local $oInfo = Json_Decode($sInfo)
			If @error or Not IsObj($oInfo) Then Return SetError(e(2,@ScriptLineNumber))
			Local $sFirst = "1", $sSecond = "0", $sThird = "0"
			; if $oInfo.Item("isFile") = True Then $sFirst = "1"
			If $oInfo.Item("disabledIK") Then $sSecond = "1"
			if $oInfo.Item("ec") Then $sThird = "1"
			Local $sCommand = $sFirst & "_" & $sSecond & "_" & $sThird & "|" & GetFolderFromPath($sDanceFile) & "\" & $oInfo.Item("src")
			c("Command:" & $sCommand)
			Local $sModel
			If UBound($gaModels) = 0 Then
				; No model detected yet.
				$sModel = "model1"
			Else
				; Set it to the active model.
				$sModel = "model" & $gaModels[$giActiveModelIndex][$MODEL_NO]
			EndIf
			SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceReadyAll:" & $sCommand)
			; For random dance only
			; Global $giRandomDanceTimeLimit, $ghRandomDanceTimer
			If $gbRandomDancePlaying Then
				; Get the milliseconds of the music length
				c("audio file: " & GetFolderFromPath($sDanceFile) & "\" & $oInfo.Item("audio") )
				Local $aSound = _SoundOpen( GetFolderFromPath($sDanceFile) & "\" & $oInfo.Item("audio") )
				If @error Then
					; Error in opening that file, just give it 1 second for next random song.
					$giRandomDanceTimeLimit = 1000
				Else
					; Successfully open the sound file.
					$giRandomDanceTimeLimit = _SoundLength( $aSound , 2)
				EndIf

				$ghRandomDanceTimer = TimerInit()
				c("Random Dance Limit:" & Floor($giRandomDanceTimeLimit / 1000) )
			EndIf

			Sleep(100)
			SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceStart:1")

		Case "MMD3", "DME"
			; Get the info about a dance.
			Local $sInfo = FileRead( GetFolderFromPath( $sDanceFile ) & "\item.json")
			if @error Then Return SetError(e(1,@ScriptLineNumber))
			Local $oInfo = Json_Decode($sInfo)
			If @error or Not IsObj($oInfo) Then Return SetError(e(2,@ScriptLineNumber))

			Local $sFirst = "0", $sSecond = "0"	; Only the second digit is meaningful
			if $oInfo.Item("initialRotation") <> "" Then
				$sFirst = $oInfo.Item("initialRotation")
			EndIf
			if $oInfo.Item("ec") = True Then $sSecond = "1"
			Local $sCommand = $sFirst & "_" & $sSecond & "|" & GetFolderFromPath($sDanceFile) & "\" & $oInfo.Item("src")
			Local $sModel
			If UBound($gaModels) = 0 Then
				; No model detected yet.
				$sModel = "model1"
			Else
				; Set it to the active model.
				$sModel = "model" & $gaModels[$giActiveModelIndex][$MODEL_NO]
			EndIf
			SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceReadyAll:" & $sCommand)

			; For random dance only
			; Global $giRandomDanceTimeLimit, $ghRandomDanceTimer
			If $gbRandomDancePlaying Then
				; Get the milliseconds of the music length

				Local $aSound = _SoundOpen( GetFolderFromPath($sDanceFile) & "\" & $oInfo.Item("audio") )
				If @error Then
					; Error in opening that file, just give it 1 second for next random song.
					$giRandomDanceTimeLimit = 1000
				Else
					; Successfully open the sound file.
					$giRandomDanceTimeLimit = _SoundLength( $aSound , 2)
				EndIf
				c("Random Dance Limit:" & Floor($giRandomDanceTimeLimit / 1000) )
				$ghRandomDanceTimer = TimerInit()
			EndIf

			Sleep(100)
			SendCommand($ghHelperHwnd, $ghMMD, $sModel & ".DanceStart:1")

	EndSwitch
EndFunc


Func StopDance()
	Switch $gsControlProg
		Case "MMD4"
			SendCommand( $ghHelperHwnd, $ghMMD, "DanceEnd")
		Case "MMD3", "MDE"
			If UBound($gaModels) = 0 Then
				SendCommand( $ghHelperHwnd, $ghMMD, "model1.DanceEnd:1" )
			Else
				SendCommand( $ghHelperHwnd, $ghMMD, "model" & $gaModels[0][$MODEL_NO] & ".DanceEnd:1" )
			EndIf
	EndSwitch
	If $gbDanceExtraPlaying Then
		StopDanceExtra()
	EndIf
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
	  Return SetError(e(1,@ScriptLineNumber))
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
		Return SetError(e(1,@ScriptLineNumber))
	EndIf
	Return $aData
EndFunc

Func e($err, $line)
	c("Error at line:" & $line & " Error:" & $err)
	return $err
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