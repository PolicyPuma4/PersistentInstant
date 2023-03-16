; Repository https://github.com/PolicyPuma4/PersistentInstant

#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetMainIcon shell32_260.ico

;@Ahk2Exe-Obey U_bits, = %A_PtrSize% * 8
;@Ahk2Exe-Obey U_type, = "%A_IsUnicode%" ? "Unicode" : "ANSI"
;@Ahk2Exe-ExeName %A_ScriptName~\.[^\.]+$%_%U_type%_%U_bits%

FILE_MAP_READ := 0x4
A_LocalAppData := EnvGet("LOCALAPPDATA")

getPortSecret() {
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

    return {
        port: SubStr(string, 9, 5),
        secret: SubStr(string, 25, 32),
    }
}

enableInstantReplay(portSecret) {
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Open("POST", "http://localhost:" portSecret.port "/ShadowPlay/v.1.0/InstantReplay/Enable", false)
    whr.SetRequestHeader("X_LOCAL_SECURITY_COOKIE", portSecret.secret)
    whr.SetRequestHeader("Content-Type", "application/json")
    whr.Send("{`"status`":true}")
}

arg := A_Args.Length ? A_Args[1] : ""
installPath := A_LocalAppData "\Programs\PersistentInstant"
installFullPath := installPath "\PersistentInstant.exe"
if (arg = "uninstall") {
    RegWrite("`"C:\Windows\System32\cmd.exe`" /C RMDIR /S /Q `"" installPath "`"", "REG_SZ", "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "PersistentInstant")
    FileDelete(A_Programs "\PersistentInstant.lnk")
    FileDelete(A_Programs "\Startup\PersistentInstant.lnk")
    RegDeleteKey("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PersistentInstant")
    MsgBox("I can't believe you've done this! Just for that you're going to have to restart your system to complete what you have started!", "PersistentInstant")

    ExitApp
}

if (not A_ScriptDir = installPath) {
    if (FileExist(installFullPath)) {
        MsgBox("Slow down there bud! A version of me is already installed, uninstall the old me before you try the new me!", "PersistentInstant")

        ExitApp
    }

    DirCreate(installPath)
    FileCopy(A_ScriptFullPath, installFullPath)
    FileCreateShortcut(installFullPath, A_Programs "\PersistentInstant.lnk")
    FileCreateShortcut(installFullPath, A_Programs "\Startup\PersistentInstant.lnk")

    RegWrite("`"" installFullPath "`"", "REG_SZ", "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PersistentInstant", "DisplayIcon")
    RegWrite("PersistentInstant", "REG_SZ", "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PersistentInstant", "DisplayName")
    RegWrite(installPath, "REG_SZ", "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PersistentInstant", "InstallLocation")
    RegWrite(0x00000001, "REG_DWORD", "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PersistentInstant", "NoModify")
    RegWrite(0x00000001, "REG_DWORD", "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PersistentInstant", "NoRepair")
    RegWrite("`"" installFullPath "`" uninstall", "REG_SZ", "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PersistentInstant", "UninstallString")

    Run(installFullPath)
    MsgBox("Welcome aboard! This is a comfy system! I hope you don't mind me chilling out in the system tray.", "PersistentInstant")

    ExitApp
}

if (not FileExist("allowlist.txt")) {
    FileAppend("`"C:\Windows\system32\wwahost.exe`" -ServerName:Netflix.App.wwa`n`"C:\Program Files\WindowsApps\AmazonVideo.PrimeVideo_1.0.84.0_x64__pwbj9vvecjh7j\PrimeVideo.exe`" -ServerName:App.AppX21qthfa64w8vh9emhw9pfwse20vpg5n9.mca`n", "allowlist.txt")
}

A_IconTip := "PersistentInstant"
A_TrayMenu.Add()
A_TrayMenu.Add("Edit allow list", editAllowList)

editAllowList(*) {
    Run("notepad.exe " installPath "\allowlist.txt")
}

allowedProcesses := StrSplit(FileRead("allowlist.txt"), "`n", "`r")

sleepTime := 1 * 60 * 1000
loop {
    if (A_Index > 1) {
        Sleep(sleepTime)
    }

    isEnabled := RegRead("HKEY_CURRENT_USER\SOFTWARE\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS", "{1B1D3DAA-601D-49E5-8508-81736CA28C6D}", "")
    if (isEnabled) {
        continue
    }

    isAllowed := false
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process") {
        for allowedProcess in allowedProcesses {
            if (not allowedProcess) {
                continue
            }

            if (InStr(process.CommandLine, allowedProcess) = 1) {
                isAllowed := true
                break
            }

            if (InStr(process.ExecutablePath, allowedProcess) = 1) {
                isAllowed := true
                break
            }
        }

        if (isAllowed) {
            break
        }
    }

    if (isAllowed) {
        continue
    }

    portSecret := getPortSecret()
    if (not portSecret) {
        continue
    }

    enableInstantReplay(portSecret)
}
