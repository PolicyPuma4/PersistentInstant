; Repository https://github.com/PolicyPuma4/PersistentInstant

#Requires AutoHotkey v2.0

;@Ahk2Exe-SetMainIcon shell32_260.ico

;@Ahk2Exe-Obey U_bits, = %A_PtrSize% * 8
;@Ahk2Exe-Obey U_type, = "%A_IsUnicode%" ? "Unicode" : "ANSI"
;@Ahk2Exe-ExeName %A_ScriptName~\.[^\.]+$%_%U_type%_%U_bits%

hMutex := DllCall("CreateMutex", "Int", 0, "Int", 0, "Str", "PersistentInstant")
OnExit((*) => DllCall("ReleaseMutex", "Ptr", hMutex))

FILE_MAP_READ := 0x4
A_LocalAppData := EnvGet("LOCALAPPDATA")


setInstantReplay(status) {
    hMapFile := DllCall("OpenFileMapping", "Ptr", FILE_MAP_READ, "Int", 0, "Str", "{8BA1E16C-FC54-4595-9782-E370A5FBE8DA}")
    if not hMapFile {
        return
    }

    pBuf := DllCall("MapViewOfFile", "Ptr", hMapFile, "Int", FILE_MAP_READ, "Int", 0, "Int", 0, "Int", 0)
    if not pBuf {
        DllCall("CloseHandle", "Ptr", hMapFile)
        return
    }

    string := StrGet(pBuf,, "UTF-8")

    DllCall("UnmapViewOfFile", "Ptr", pBuf)
    DllCall("CloseHandle", "Ptr", hMapFile)

    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Open("POST", "http://localhost:" SubStr(string, 9, 5) "/ShadowPlay/v.1.0/InstantReplay/Enable", false)
    whr.SetRequestHeader("X_LOCAL_SECURITY_COOKIE", SubStr(string, 25, 32))
    whr.SetRequestHeader("Content-Type", "application/json")
    whr.Send("{`"status`":" (status ? "true" : "false") "}")
}


if (not FileExist("denylist.txt")) {
    FileAppend("`"C:\Windows\system32\wwahost.exe`" -ServerName:Netflix.App.wwa`r`n`"C:\Program Files\WindowsApps\AmazonVideo.PrimeVideo_1.0.84.0_x64__pwbj9vvecjh7j\PrimeVideo.exe`" -ServerName:App.AppX21qthfa64w8vh9emhw9pfwse20vpg5n9.mca`r`n", "denylist.txt")
}

if (not FileExist("allowlist.txt")) {
    FileAppend("`r`n", "allowlist.txt")
}

A_IconTip := "PersistentInstant"
A_TrayMenu.Add()
A_TrayMenu.Add("Edit deny list", menuHandler)
A_TrayMenu.Add("Edit allow list", menuHandler)


menuHandler(itemName, *) {
    if (itemName = "Edit deny list") {
        Run("notepad.exe denylist.txt")
    }

    if (itemName = "Edit allow list") {
        Run("notepad.exe allowlist.txt")
    }
}


deny := StrSplit(Trim(FileRead("denylist.txt"), "`r`n"), "`r`n")
allow := StrSplit(Trim(FileRead("allowlist.txt"), "`r`n"), "`r`n")


exists(items) {
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process") {
        for item in items {
            if (InStr(process.CommandLine, item) = 1) {
                return process.ProcessId
            }

            if (InStr(process.ExecutablePath, item) = 1) {
                return process.ProcessId
            }
        }
    }
}


monitoringProcess := false
sleepTime := 1 * 60 * 1000
loop {
    if (A_Index > 1) {
        Sleep(sleepTime)
    }

    isEnabled := RegRead("HKEY_CURRENT_USER\SOFTWARE\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS", "{1B1D3DAA-601D-49E5-8508-81736CA28C6D}", "")
    if (isEnabled) {
        if (allow.Length and not ProcessExist(monitoringProcess)) {
            setInstantReplay(false)
        }

        continue
    }

    if (allow.Length) {
        monitoringProcess := exists(allow)
        if monitoringProcess {
            setInstantReplay(true)
        }

        continue
    }

    if (exists(deny)) {
        continue
    }

    setInstantReplay(true)
}
