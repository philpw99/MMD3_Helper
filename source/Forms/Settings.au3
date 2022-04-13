#include-once


Func GuiSettings($bNew)
	Local $guiSettings = GUICreate("Settings",596,485,-1,-1,-1,-1)
	Local $bSaved = False 
	#include "Settings.isf"
	; Local $guiSettings, $inpMMD3Path, $btnBrowseMMD3, $inpWorkshopPath, $btnBrowseWorkshop
	; Local $radDisable, $radEnableRandom, $radEnableSpecified, $btnAssign, $chkMoveToCenter
	; Local $btnSave, $btnCancel
	
	If Not $guiSettings Then Return SetError(1)
	
	If $bNew Then 
		; New initial settings.
		GUICtrlSetState( $radDisable, $GUI_CHECKED)
	Else
		; Have existing settings.
		GUICtrlSetData( $inpMMD3Path, RegRead( $gsRegBase, "MMD3Path") )
		GUICtrlSetData( $inpWorkshopPath, RegRead( $gsRegBase, "WorkshopPath") )
		; Set the background options
		$gsBackgroundShow = RegRead( $gsRegBase, "BackgroundShow")
		Switch $gsBackgroundShow
			Case "Disable"
				GUICtrlSetState( $radDisable, $GUI_CHECKED )
			Case "EnableRandom"
				GUICtrlSetState( $radEnableRandom, $GUI_CHECKED )
			Case "EnableSpecified"
				GUICtrlSetState( $radEnableSpecified, $GUI_CHECKED )
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
				Local $sExeFile = FileOpenDialog("Locate DesktopMMD3.exe", @ProgramFilesDir, "Exe File(*.exe)",  $FD_FILEMUSTEXIST, "DesktopMMD3.exe" )
				If @error Then
					MsgBox(0, "Error", "Error in locating the exe file. Error:" & @error, 20)
					ContinueLoop
				EndIf
				GUICtrlSetData( $inpMMD3Path, $sExeFile )

			Case $btnBrowseWorkshop
				Local $sWorkshopPath =  FileSelectFolder("Locate Workshop folder 1480480", "", 0, _ 
					"C:\Program Files (x86)\Steam\steamapps\workshop\content\1480480")
				If @error Then 
					MsgBox(0, "Error", "Error in locating the 1480480 folder. Error:" & @error, 20)
					ContinueLoop
				EndIf
				GUICtrlSetData( $inpWorkshopPath, $sWorkshopPath)

			Case $btnAssign
				MsgBox( 0, "Not yet", "This feature is planned but not implemented yet.", 20)
				
			Case $btnSave
				; Save all settings.
	; Local $guiSettings, $inpMMD3Path, $btnBrowseMMD3, $inpWorkshopPath, $btnBrowseWorkshop
	; Local $radDisable, $radEnableRandom, $radEnableSpecified, $btnAssign, $chkMoveToCenter
				Local $sRegKey = RegRead( $gsRegBase, "")
				if @error Then RegWrite( $gsRegBase )	; Simply create the main key
				
				$gsMMD3Path = GUICtrlRead( $inpMMD3Path )
				RegWrite( $gsRegBase, "MMD3Path", "REG_SZ", $gsMMD3Path )
				$gsWorkshopPath = GUICtrlRead($inpWorkshopPath)
				RegWrite( $gsRegBase, "WorkshopPath", "REG_SZ", $gsWorkshopPath )
				If GUICtrlRead( $radDisable) = $GUI_CHECKED Then
					$gsBackgroundShow = "Disable"
				ElseIf GUICtrlRead( $radEnableRandom ) =  $GUI_CHECKED Then 
					$gsBackgroundShow = "EnableRandom"
				ElseIf GUICtrlRead($radEnableSpecified) = $GUI_CHECKED Then 
					$gsBackgroundShow = "EnableSpecified"
				EndIf
				RegWrite( $gsRegBase, "BackgroundShow", "REG_SZ", $gsBackgroundShow )
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