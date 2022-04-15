#include-once


Func GuiSettings($bNew)
	Local $guiSettings = GUICreate("Settings",596,485,-1,-1,-1,-1)
	Local $bSaved = False 
	#include "Settings.isf"
	Local $sMMD3Path, $sMMD3WorkshopPath, $sDMEPath, $sDMEWorkshopPath
	Local $sControlProg, $sBackgroundShow
	; Local $guiSettings, $btnBrowseMMD3,  $btnBrowseMMD3Workshop
	; Local $btnBrowseDME, $btnBrowseDMEWorkshop, 
	; Local $radDisable, $radEnableRandom, $radEnableSpecified, $btnAssignMMD3, $btnAssignDME, $chkMoveToCenter
	; Local $btnSave, $btnCancel
	
	
	If Not $guiSettings Then Return SetError(1)
	
	If $bNew Then 
		; New initial settings.
		GUICtrlSetState( $radDisable, $GUI_CHECKED)
		GUICtrlSetState( $radMMD3, $GUI_CHECKED)
		$sMMD3Path = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMMD3"
		$sMMD3WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1480480"
		$sDMEPath = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMagicEngine"
		$sDMEWorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1096550"
	Else
		; Have existing settings.
		$sMMD3Path = RegRead( $gsRegBase, "MMD3Path")
		If @error Then $sMMD3Path = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMMD3"  ; Just in case
		$sMMD3WorkshopPath = RegRead( $gsRegBase, "MMD3WorkshopPath")
		If @error Then $sMMD3WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1480480" ; Just in case
		$sDMEPath = RegRead( $gsRegBase, "DMEPath")
		If @error Then $sDMEPath = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMagicEngine"  ; Just in case
		$sDMEWorkshopPath = RegRead( $gsRegBase, "DMEWorkshopPath")
		If @error Then $sMMD3WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1096550" ; Just in case
		
		; Set the default prog to control
		$sControlProg = RegRead( $gsRegBase, "ControlProgram" )
		
		
		
		; Set the background options
		$sBackgroundShow = RegRead( $gsRegBase, "BackgroundShow")
		Switch $sBackgroundShow
			Case "Disable"
				GUICtrlSetState( $radDisable, $GUI_CHECKED )
			Case "EnableRandom"
				GUICtrlSetState( $radEnableRandom, $GUI_CHECKED )
			Case "EnableSpecified"
				GUICtrlSetState( $radEnableSpecified, $GUI_CHECKED )
				GUICtrlSetState( $btnAssignMMD3, $GUI_ENABLE)
				GUICtrlSetState( $btnAssignDME, $GUI_ENABLE)
		EndSwitch
		If RegRead( $gsRegBase, "CenterWhenDance" ) = 1 Then 
			GUICtrlSetState( $chkMoveToCenter, $GUI_CHECKED )
		EndIf
	EndIf
	
	; Show the gui
	GUISetState(@SW_SHOW, $guiSettings)
	
	while True
		Local $nMsg = GUIGetMsg()
		Switch $nMsg
			Case 0
				ContinueLoop

			Case $btnBrowseMMD3
				Local $sExeFile = FileOpenDialog("Locate DesktopMMD3.exe", GetFolderFromPath($sMMD3Path), "Exe File(*.exe)",  $FD_FILEMUSTEXIST, "DesktopMMD3.exe" )
				If @error Then
					MsgBox(0, "Error", "Error in locating the exe file. Error:" & @error, 20)
					ContinueLoop
				EndIf
				$sMMD3Path = GetFolderFromPath( $sExeFile )

			Case $btnBrowseMMD3Workshop
				Local $sPath =  FileSelectFolder("Locate Workshop folder 1480480", "", 0, $sMMD3WorkshopPath )
				If @error Then 
					MsgBox(0, "Error", "Error in locating the 1480480 folder. Error:" & @error, 20)
					ContinueLoop
				EndIf
				$sMMD3WorkshopPath = $sPath

			Case $btnAssignMMD3, $btnAssignDME
				MsgBox( 0, "Not yet", "This feature is planned but not implemented yet.", 20)
				

			Case $radDisable
				GUICtrlSetState( $btnAssignMMD3, $GUI_DISABLE)
				GUICtrlSetState( $btnAssignDME, $GUI_DISABLE)
				$sBackgroundShow = "Disable"
			Case $radEnableRandom
				GUICtrlSetState( $btnAssignMMD3, $GUI_DISABLE)
				GUICtrlSetState( $btnAssignDME, $GUI_DISABLE)
				$sBackgroundShow = "EnableRandom"
			Case $radEnableSpecified
				GUICtrlSetState( $btnAssignMMD3, $GUI_ENABLE)
				GUICtrlSetState( $btnAssignDME, $GUI_ENABLE)
				$sBackgroundShow = "EnableSpecified"
			
			
			Case $btnSave
				; Save all settings.
	; Local $guiSettings, $sMMD3Path, $btnBrowseMMD3, $sWorkshopPath, $btnBrowseMMDWorkshop
	; Local $btnBrowseDME, $btnBrowseDMEWorkshop, $sDMEPath, $sDMEWorkshopPath
	; Local $radDisable, $radEnableRandom, $radEnableSpecified, $btnAssignMMD3, $btnAssignDME, $chkMoveToCenter
				Local $sRegKey = RegRead( $gsRegBase, "")
				if @error Then RegWrite( $gsRegBase )	; Simply create the base key
				; Write paths
				$gsMMD3Path = $sMMD3Path
				RegWrite( $gsRegBase, "MMD3Path", "REG_SZ", $gsMMD3Path )
				$gsMMD3WorkshopPath = $sMMD3WorkshopPath
				RegWrite( $gsRegBase, "MMD3WorkshopPath", "REG_SZ", $gsMMD3WorkshopPath )
				; Dance background setting
				$gsBackgroundShow =  $sBackgroundShow
				RegWrite( $gsRegBase, "BackgroundShow", "REG_SZ", $gsBackgroundShow )
				; Dance center setting
				If GUICtrlRead( $chkMoveToCenter) =  $GUI_CHECKED Then 
					RegWrite( $gsRegBase, "CenterWhenDance", "REG_DWORD", 1)
				Else
					RegWrite( $gsRegBase, "CenterWhenDance", "REG_DWORD", 0)
				EndIf
				
				MsgBox( 0, "Saved", "Settings are saved and effective.", 20)
				ExitLoop 
				$bSaved = True 
			Case $GUI_EVENT_CLOSE, $btnCancel
				ExitLoop
		EndSwitch
	Wend

	GUIDelete($guiSettings)
	Return $bSaved
EndFunc