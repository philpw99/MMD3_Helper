; GlobalData.au3
; Here store all the static global data, constants...

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
Global Const $gsMMD4IdleActionPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1968650\2808241801"

; This is to establish MMD3 random dance data
Global $gaMMD3Dances[51]
For $i = 1 to 19
	$gaMMD3Dances[$i-1] = "Slow_Rhythm_Dance " & StringFormat("%02i", $i)
Next

For $i = 1 to 15
	$gaMMD3Dances[$i + 18] = "Mid_Rhythm_Dance " & StringFormat("%02i", $i)
Next

For $i = 1 to 17
	$gaMMD3Dances[$i + 33] = "High_Rhythm_Dance " & StringFormat("%02i", $i)
Next

; This is for DME random dances
Global $gaDMEDances[59]
For $i = 1 to 19
	$gaDMEDances[$i-1] = "Slow_Rhythm_Dance_" & StringFormat("%02i", $i)
Next

For $i = 1 to 15
	$gaDMEDances[$i + 18] = "Mid_Rhythm_Dance_" & StringFormat("%02i", $i)
Next

For $i = 1 to 17
	$gaDMEDances[$i + 33] = "High_Rhythm_Dance_" & StringFormat("%02i", $i)
Next

For $i = 1 to 8
	$gaDMEDances[$i + 50] = "Short_Dance_" & StringFormat("%02i", $i)
Next

; This is for MMD4 random dance data, the data will get auto filled on runtime.
Global $gaMMD4Dances[0]			

; Below is for a program's Sound Detection
Global Const $CLSCTX_INPROC_SERVER = 0x01 + 0x02 + 0x04 + 0x10
Global Enum $geRender, $geCapture, $geAll, $geDataFlow_enum_count
Global Enum $geAudioSessionStateInactive, $geAudioSessionStateActive, $geAudioSessionStateExpired
Global Const $geMultimedia = 1

Global Const $gsCLSID_MMDeviceEnumerator = "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
Global Const $gsIID_IMMDeviceEnumerator = "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
Global Const $gsTagIMMDeviceEnumerator = _
        "EnumAudioEndpoints hresult(int;dword;ptr*);" & _
        "GetDefaultAudioEndpoint hresult(int;int;ptr*);" & _
        "GetDevice hresult(wstr;ptr*);" & _
        "RegisterEndpointNotificationCallback hresult(ptr);" & _
        "UnregisterEndpointNotificationCallback hresult(ptr)"


Global Const $gsIID_IAudioMeterInformation = "{C02216F6-8C67-4B5B-9D00-D008E73E0064}"
Global Const $gsTagIAudioMeterInformation = "GetPeakValue hresult(float*);" & _
        "GetMeteringChannelCount hresult(dword*);" & _
        "GetChannelsPeakValues hresult(dword;float*);" & _
        "QueryHardwareSupport hresult(dword*);"


Global Const $gsIID_IMMDevice = "{D666063F-1587-4E43-81F1-B948E807363F}"
Global Const $gsTagIMMDevice = _
        "Activate hresult(clsid;dword;ptr;ptr*);" & _
        "OpenPropertyStore hresult(dword;ptr*);" & _
        "GetId hresult(wstr*);" & _
        "GetState hresult(dword*)"


Global Const $gsIID_IAudioSessionManager2 = "{77aa99a0-1bd6-484f-8bc7-2c654c9a9b6f}"
Global Const $gsTagIAudioSessionManager = "GetAudioSessionControl hresult(ptr;dword;ptr*);" & _
        "GetSimpleAudioVolume hresult(ptr;dword;ptr*);"
Global Const $gsTagIAudioSessionManager2 = $gsTagIAudioSessionManager & "GetSessionEnumerator hresult(ptr*);" & _
        "RegisterSessionNotification hresult(ptr);" & _
        "UnregisterSessionNotification hresult(ptr);" & _
        "RegisterDuckNotification hresult(wstr;ptr);" & _
        "UnregisterDuckNotification hresult(ptr)"


Global Const $gsIID_IAudioSessionEnumerator = "{e2f5bb11-0570-40ca-acdd-3aa01277dee8}"
Global Const $gsTagIAudioSessionEnumerator = "GetCount hresult(int*);GetSession hresult(int;ptr*)"

Global Const $gsIID_IAudioSessionControl = "{f4b1a599-7266-4319-a8ca-e70acb11e8cd}"
Global Const $gsTagIAudioSessionControl = "GetState hresult(int*);GetDisplayName hresult(wstr*);" & _
        "SetDisplayName hresult(wstr);GetIconPath hresult(wstr*);" & _
        "SetIconPath hresult(wstr;ptr);GetGroupingParam hresult(ptr*);" & _
        "SetGroupingParam hresult(ptr;ptr);RegisterAudioSessionNotification hresult(ptr);" & _
        "UnregisterAudioSessionNotification hresult(ptr);"


Global Const $gsIID_IAudioSessionControl2 = "{bfb7ff88-7239-4fc9-8fa2-07c950be9c6d}"
Global Const $gsTagIAudioSessionControl2 = $gsTagIAudioSessionControl & "GetSessionIdentifier hresult(wstr*);" & _
        "GetSessionInstanceIdentifier hresult(wstr*);" & _
        "GetProcessId hresult(dword*);IsSystemSoundsSession hresult();" & _
        "SetDuckingPreferences hresult(bool);"
