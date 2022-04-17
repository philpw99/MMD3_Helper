#include-once


Func GuiSettings($bNew)
	Local $guiSettings = GUICreate("Settings",538,585,-1,-1,-1,-1)
	GUISetIcon("Icons\tray.ico")
	
	Local $bSaved = False 
	#include "Settings.isf"
	Local $sMMD3Path, $sMMD3WorkshopPath, $sDMEPath, $sDMEWorkshopPath
	Local $sControlProg, $sBackgroundShow
	; Local $guiSettings, $btnBrowseMMD3,  $btnBrowseMMD3Workshop
	; Local $btnBrowseDME, $btnBrowseDMEWorkshop, 
	; Local $radDisable, $radEnableRandom, $radEnableSpecified, $btnAssignMMD3, $btnAssignDME, $chkMoveToCenter
	; Local $radMMD3, $radDME
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
		$sControlProg = "MMD3"
		$sBackgroundShow = "Disable"
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
		If @error Then $sControlProg = "MMD3"	; Just in case.
		
		If $sControlProg = "MMD3" Then 
			GUICtrlSetState($radMMD3, $GUI_CHECKED)
		Else 
			GUICtrlSetState($radDME, $GUI_CHECKED)
		EndIf
		
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
		; Center model when dance option.
		If RegRead( $gsRegBase, "CenterWhenDance" ) = 1 Then 
			GUICtrlSetState( $chkMoveToCenter, $GUI_CHECKED )
		EndIf

	EndIf
	
	; Disable the tray clicks
	TraySetClick(0)
	
	; Show the gui
	GUISetState(@SW_SHOW, $guiSettings)
	
	while True
		Local $nMsg = GUIGetMsg()
		Switch $nMsg
			Case 0
				ContinueLoop

			Case $btnBrowseMMD3
				Local $sExeFile = FileOpenDialog("Locate DesktopMMD3.exe", $sMMD3Path, "Exe File(*.exe)",  $FD_FILEMUSTEXIST, "DesktopMMD3.exe" )
				If @error Then ContinueLoop

				$sMMD3Path = GetFolderFromPath( $sExeFile )

			Case $btnBrowseMMD3Workshop
				Local $sPath =  FileSelectFolder("Locate Workshop folder 1480480", $sMMD3WorkshopPath )
				If @error Then ContinueLoop

				$sMMD3WorkshopPath = $sPath
				
			Case $btnBrowseDME
				Local $sExeFile = FileOpenDialog("Locate DesktopMMD3.exe", $sDMEPath, "Exe File(*.exe)",  $FD_FILEMUSTEXIST, "DesktopMagicEngine.exe" )
				If @error Then ContinueLoop

				$sDMEPath = GetFolderFromPath( $sExeFile )

			Case $btnBrowseDMEWorkshop
				Local $sPath =  FileSelectFolder("Locate Workshop folder 1096550", $sDMEWorkshopPath )
				If @error Then ContinueLoop

				$sDMEWorkshopPath = $sPath

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
			
			Case $radMMD3
				$sControlProg = "MMD3"
				Local $sFile = $sMMD3Path & "\DesktopMMD3.exe"
				If Not FileExists($sFile) Then 
					MsgBox( 0, "Error", "DesktopMMD3.exe doesn't exist.", 20)
					GUICtrlSetState($radMMD3, $GUI_UNCHECKED)
					ContinueLoop
				EndIf

			Case $radDME
				$sControlProg = "DME"
				Local $sFile = $sDMEPath & "\DesktopMagicEngine.exe"
				If Not FileExists($sFile) Then 
					MsgBox( 0, "Error", "DesktopMagicEngine.exe doesn't exist.", 20)
					GUICtrlSetState($radDME, $GUI_UNCHECKED)
					ContinueLoop
				EndIf
				
			Case $btnReset
				GUICtrlSetState( $radDisable, $GUI_CHECKED)
				GUICtrlSetState( $radMMD3, $GUI_CHECKED)
				$sMMD3Path = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMMD3"
				$sMMD3WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1480480"
				$sDMEPath = "C:\Program Files (x86)\Steam\steamapps\common\DesktopMagicEngine"
				$sDMEWorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1096550"
				$sControlProg = "MMD3"
				$sBackgroundShow = "Disable"
			
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
				$gsMMD3AssetPath = $gsMMD3Path & "\Appdata\Assets"
				$gsMMD3WorkshopPath = $sMMD3WorkshopPath
				RegWrite( $gsRegBase, "MMD3WorkshopPath", "REG_SZ", $gsMMD3WorkshopPath )
				
				$gsDMEPath = $sDMEPath
				RegWrite( $gsRegBase, "DMEPath", "REG_SZ", $gsDMEPath )
				$gsDMEAssetPath = $gsDMEPath & "\Appdata\Assets"
				$gsDMEWorkshopPath = $sDMEWorkshopPath
				RegWrite( $gsRegBase, "DMEWorkshopPath", "REG_SZ", $gsDMEWorkshopPath )

				; Dance background setting
				$gsBackgroundShow =  $sBackgroundShow
				RegWrite( $gsRegBase, "BackgroundShow", "REG_SZ", $gsBackgroundShow )
				; Dance center setting
				
				If GUICtrlRead( $chkMoveToCenter) =  $GUI_CHECKED Then 
					RegWrite( $gsRegBase, "CenterWhenDance", "REG_DWORD", 1)
					$gsCenterWhenDance = 1
				Else
					RegWrite( $gsRegBase, "CenterWhenDance", "REG_DWORD", 0)
					$gsCenterWhenDance = 0
				EndIf
				
				; Default control program.
				$gsControlProg = $sControlProg
				RegWrite( $gsRegBase, "ControlProgram", "REG_SZ", $gsControlProg )
				
				
				MsgBox( 0, "Saved", "Settings are saved and effective.", 20)
				$bSaved = True 
				ExitLoop
			Case $GUI_EVENT_CLOSE, $btnCancel
				ExitLoop
		EndSwitch
	Wend
	
	; restore the tray icon functions.
	TraySetClick(9)

	GUIDelete($guiSettings)
	Return $bSaved
EndFunc