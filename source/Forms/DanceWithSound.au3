
Func DanceWithSoundSettings()
	Local $guiDanceWithSound = GUICreate("Dance With Sound Settings",546,351,-1,-1,-1,-1)
	GUISetIcon("Icons\trayActive.ico")
	
	; Set up all the controls.
	#include "DanceWithSound.isf"
	
	GUICtrlSetData( $inpExeFile, $gsSoundMonitorProg)
	If $giRandomDanceWithSound = 1 Then 
		GUICtrlSetState($chkRandomWithSound, $GUI_CHECKED)
	EndIf
	
	GUISetState( @SW_SHOW, $guiDanceWithSound)

	; Disable the tray clicks
	TraySetClick(0)
	
	While True 
		Local $nMsg =  GUIGetMsg(), $sFile
		Switch $nMsg
			Case $chkRandomWithSound, $inpExeFile
				; Enable / Disable the whole feature.
				if GUICtrlRead($chkRandomWithSound) = $GUI_CHECKED Then 
					$giRandomDanceWithSound = 1
					If $gsControlProg = "MMD4" And UBound($gaMMD4Dances) = 0 Then 
						LoadMMD4Dances()
					EndIf
				Else 
					$giRandomDanceWithSound = 0
				EndIf
				SaveSettings()
				MsgBox(0, "Setting Saved.", "The new settings are saved.", 20)
			Case $btnBrowse
				$sFile = FileOpenDialog("Choose the .exe file", @ProgramFilesDir, "Exe files (*.exe)", $FD_FILEMUSTEXIST )
				If  @error then ContinueLoop  ; Fail to choose a file
				$sFile = GetFileFromPath($sFile)
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				MsgBox(0, "Setting Saved.", "The new settings are saved.", 20)
			Case $btnVLC
				$sFile = "vlc.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $btnWMP
				$sFile = "wmplayer.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $btnKMPlayer
				$sFile = "KMPlayer.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $btnPotPlayer
				$sFile = "PotPlayerMini64.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $btnWinAMP
				$sFile = "winamp.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $btnSpotify
				$sFile = "Spotify.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $btnFoobar
				$sFile = "foobar2000.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $btnItune
				$sFile = "iTunes.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $btnFireFox
				$sFile = "firefox.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()

			Case $btnChrome
				$sFile = "chrome.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()

			Case $btnOpera
				$sFile = "opera.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()

			Case $btnEdge
				$sFile = "msedge.exe"
				GUICtrlSetData($inpExeFile, $sFile)
				$gsSoundMonitorProg = $sFile
				SaveSettings()
				
			Case $GUI_EVENT_CLOSE
				ExitLoop
		EndSwitch
	Wend
	GUIDelete($guiDanceWithSound)
	
	; restore the tray icon functions.
	TraySetClick(9)
EndFunc 